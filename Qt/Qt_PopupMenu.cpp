/* Copyright 2012 Kjetil S. Matheussen

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA. */

#if USE_QT_MENU

#include <QStack>
#include <QAction>
#include <QWidgetAction>
#include <QCheckBox>
#include <QButtonGroup>
#include <QRadioButton>
#include <QMenu>
#include <QProxyStyle>
#include <QStyleFactory>


#define RADIUM_ACCESS_SEQBLOCK_AUTOMATION 1

#include "../common/nsmtracker.h"
#include "../common/visual_proc.h"

#include "../embedded_scheme/s7extra_proc.h"

#include "../api/api_gui_proc.h"

#include "../api/api_proc.h"

#include "EditorWidget.h"



QPointer<QWidget> g_current_parent_before_qmenu_opened; // Only valid if g_curr_popup_qmenu != NULL
QPointer<QMenu> g_curr_popup_qmenu;

int64_t g_last_hovered_menu_entry_guinum = -1;



namespace{

  class MyQAction;
  static int g_myactions_counter = 0;
  static QHash<int, QPointer<MyQAction>> g_curr_visible_actions;

  static bool _has_keyboard_focus = false; // Must be global since more than one QMenu may open simultaneously. (not supposed to happen, but it does happen)



  struct MyProxyStyle: public QProxyStyle {
    MyProxyStyle(){
      static QStyle *base_style = QStyleFactory::create("Fusion");
      setBaseStyle(base_style); // Trying to fix style on OSX and Windows. Not necessary on Linux, for some reason.
    }

#if 0
    void drawPrimitive(PrimitiveElement element, const QStyleOption *option, QPainter *painter, const QWidget *widget) const {
      static QStyle *windows_style = QStyleFactory::create("Windows");

      printf("   Element: %d (radio: %d)\n", element, QStyle::PE_IndicatorRadioButton);
      
      if (element == QStyle::PE_IndicatorRadioButton){
        windows_style->drawPrimitive(element, option, painter, widget);
      } else {          
        QProxyStyle::drawPrimitive(element, option, painter, widget);
      }
    }
#endif
    
    virtual int pixelMetric(QStyle::PixelMetric metric, const QStyleOption* option = 0, const QWidget* widget = 0 ) const {
      if (metric==QStyle::PM_SmallIconSize && root!=NULL && root->song!=NULL && root->song->tracker_windows!=NULL)
        return root->song->tracker_windows->fontheight*4;
      else
        return QProxyStyle::pixelMetric( metric, option, widget ); // return default values for the rest
    }    
  };

  static MyProxyStyle g_my_proxy_style;



  
  struct Callbacker : public QObject{
    Q_OBJECT;
  public:
    QPointer<QMenu> qmenu;    
    int num;
    func_t *callback; // TODO: Investige if this is gc-safe. (and if it is, it should be changed, because this seems messy. Probably cleaner to gc-protect/unprotect here.)
    std::function<void(int,bool)> callback3;
    int *result;

    bool is_checkable;

    Callbacker(QMenu *qmenu, int num, bool is_async, func_t *callback, std::function<void(int,bool)> callback3, int *result, bool is_checkable)
      : qmenu(qmenu)
      , num(num)
      , callback(callback)
      , callback3(callback3)
      , result(result)
      , is_checkable(is_checkable)
    {
      R_ASSERT(is_async==true); // Lots of trouble with non-async menus. (triggers qt bugs)
      
      if(is_async)
        R_ASSERT(result==NULL);
    }

  private:
    bool checked = false;

    bool run_have_run = false;

    void run_and_delete(bool checked){
      R_ASSERT_RETURN_IF_FALSE(run_have_run==false);
      run_have_run = true;

      this->checked = checked;
      
      qmenu->close();
      
      if (result != NULL)
        *result = num;

      if (callback!=NULL || callback3!=NULL) {
        
        connect(qmenu.data(), SIGNAL(destroyed(QObject*)), this, SLOT(menu_destroyed(QObject*)) );

      } else {

        delete this;
        
      }
    }

    void run_callbacks(void){
      if (callback != NULL){
        if (is_checkable)
          S7CALL(void_int_bool, callback, num, checked);
        else
          S7CALL(void_int, callback, num);
      }
        
      if (callback3)
        callback3(num, checked);
    }

  public:
    
    void run_checked(bool checked){
      R_ASSERT(is_checkable);
      this->checked = checked;
      run_callbacks();
    }
    
    void run_and_delete_checked(bool checked){
      R_ASSERT(is_checkable);
      run_and_delete(checked);
    }
    
    void run_and_delete_clicked(void){
      R_ASSERT(false==is_checkable);
      run_and_delete(false);
    }

  private:

    int num_callback_tries = 0;
    
    void call_callback_and_delete(void){
      num_callback_tries++;
      
      if (false==qmenu.isNull()){

        printf("Num callback tries: %d\n", num_callback_tries);
        
        R_ASSERT_NON_RELEASE(false); // This line can probably be commented away. If Qt hasn't deleted the menu right after calling the menu_destroyed slot, that's an issue in qt and probably nothing we can do anything about here.

        if (num_callback_tries < 100)
          schedule_call_callback_and_delete(50); // try again. Wait a little bit more this time to avoid clogging up CPU in case we never succeed.
        else
          R_ASSERT(false); // After 5 seconds we give up.

      } else {

        run_callbacks();
        
        delete this;
      }
    }

    void schedule_call_callback_and_delete(int ms){
      QTimer::singleShot(ms, [this] {
          this->call_callback_and_delete();
        });
    }

  private slots:
    void menu_destroyed(QObject*){
      schedule_call_callback_and_delete(1);  // Must wait a little bit since Qt seems to be in a state right now where calling g_curr_popup_qmenu->hide() will crash the program (or do other bad things) (5.10).
    }
  };

  static QPointer<QWidget> g_last_hovered_widget;
  
  class MyQAction : public QWidgetAction {
    Q_OBJECT

    Callbacker *_callbacker;
    
  public:

    int64_t _guinum;
    QWidget *_widget = NULL;
    
    QAbstractButton *_checkbox = NULL; // can be either QCheckBox or QRadioButton
    
    bool _success = true;

    MyQAction(const QIcon &icon, const QString &text, const QString &shortcut, Callbacker *callbacker, bool is_checkbox, bool is_checked, bool is_radiobutton, bool is_first, bool is_last, QObject *parent = NULL)
      : QWidgetAction(parent)
      , _callbacker(callbacker)
    {
      int entryid = g_myactions_counter++;
      
      g_curr_visible_actions[entryid] = this;
      
      static func_t *s_func = NULL;
      
#if defined(RELEASE)
      if (s_func==NULL)
#endif
        s_func = s7extra_get_func_from_funcname("FROM_C-create-menu-entry-widget");

      _guinum = S7CALL(int_int_charpointer_charpointer_bool_bool_bool_bool_bool, s_func, entryid, text.toUtf8().constData(), shortcut.toUtf8().constData(), is_checkbox, is_checked, is_radiobutton, is_first, is_last);

      if (_guinum > 0){
        _widget = API_gui_get_widget(_guinum);
        setDefaultWidget(_widget);        
      } else
        _success = false;

      if (_widget!=NULL && is_checkbox){
        _checkbox = _widget->findChild<QAbstractButton*>("checkbox");
        if(_checkbox==NULL)
          R_ASSERT(false);
        else
          connect(_checkbox, SIGNAL(toggled(bool)), this, SLOT(toggled(bool)));        
      }
    }

  public slots:

    // This one is called when toggling the checkbox itself, not just the whole widget (outside the checkbox)
    void toggled(bool checked){
      printf("   TOGGLED: %d\n", checked);
      _callbacker->run_checked(checked);
    }
  };
  
  class CheckableAction : public MyQAction {
    Q_OBJECT

    Callbacker *callbacker;
    
  public:

    ~CheckableAction(){
      //printf("I was deleted: %s\n",text.toUtf8().constData());
    }

    CheckableAction(QIcon icon, const QString & text_b, const QString &shortcut, bool is_on, bool is_radiobutton, bool is_first, bool is_last, Callbacker *callbacker)
      : MyQAction(icon, text_b, shortcut, callbacker, true, is_on, is_radiobutton, is_first, is_last, callbacker->qmenu)
      , callbacker(callbacker)
    {
      setCheckable(true);
      setChecked(is_on);
      connect(this, SIGNAL(toggled(bool)), this, SLOT(toggled(bool)));
    }

  public slots:
    void toggled(bool checked){
      callbacker->run_and_delete_checked(checked);
    }
  };

  class ClickableAction : public MyQAction
  {
    Q_OBJECT;
    
    Callbacker *callbacker;
    
  public:

    ~ClickableAction(){
      //printf("I was deleted: %s\n",text.toUtf8().constData());
    }
    
    ClickableAction(QIcon icon, const QString & text, const QString &shortcut, bool is_first, bool is_last, Callbacker *callbacker)
      : MyQAction(icon, text, shortcut, callbacker, false, false, false, is_first, is_last, callbacker->qmenu)
      , callbacker(callbacker)
    {
      connect(this, SIGNAL(triggered()), this, SLOT(triggered()));      
    }

  public slots:
    void triggered(){
      callbacker->run_and_delete_clicked();
    }
  };

  class ClickableIconAction : public QAction
  {
    Q_OBJECT;
    
    Callbacker *callbacker;
    
  public:

    ~ClickableIconAction(){
      //printf("I was deleted: %s\n",text.toUtf8().constData());
    }
    
    ClickableIconAction(QIcon icon, const QString & text, Callbacker *callbacker)
      : QAction(icon, text, callbacker->qmenu)
      , callbacker(callbacker)
    {
      connect(this, SIGNAL(triggered()), this, SLOT(triggered()));      
    }

  public slots:
    void triggered(){
      callbacker->run_and_delete_clicked();
    }
  };

  struct MyQMenu : public QMenu{
    MyQMenu(QWidget *parent, QString title)
      : QMenu(title, parent)
    {
    }
    
    void keyPressEvent(QKeyEvent *event) override{
      //printf("KEY press event. Num actions: %d\n", actions().size());
      
      bool custom_treat
        = ((event->modifiers() & Qt::ShiftModifier) && (event->key()==Qt::Key_Up || event->key()==Qt::Key_Down))
        || (event->key()==Qt::Key_PageUp || event->key()==Qt::Key_PageDown)
        || (event->key()==Qt::Key_Home || event->key()==Qt::Key_End);

      if (custom_treat && actions().size() > 0) {

        bool is_down = event->key()==Qt::Key_Down || event->key()==Qt::Key_PageDown;
        int inc = is_down ? 1 : -1;
        
        auto *curr_action = activeAction();
        QAction *new_action = NULL;

        if (event->key()==Qt::Key_Home) {
          
          new_action = actions().first();
          
        } else if (event->key()==Qt::Key_End) {
          
          new_action = actions().last();
          
        } else if (is_down && curr_action==actions().last()) {

          new_action = actions().first();

        } else if (!is_down && curr_action==actions().first()) {

          new_action = actions().last();
            
        } else {
            
          int pos = 0;
            
          if (curr_action!=NULL) {
              
            for(auto *action : actions()){
              //printf("%d: %p (%p)\n", pos, action, curr_action);
                
              if (curr_action==action)
                break;
                
              pos++;
            }
          }

          int new_pos = pos + inc*10;
          //printf("new_pos: %d. size: %d\n", new_pos, actions().size());

          int safety = 0;
          do{
            
            if (new_pos >= actions().size())
              new_action = actions().last();
              
            else if (new_pos < 0)
              new_action = actions().first();
            
            else
              new_action = actions().at(new_pos);

            //printf("new_pos: %d. is_enabled: %d (%p). Curr enabled: %d\n", new_pos, new_action!=NULL && new_action->isEnabled(), new_action, curr_action->isEnabled());
            
            new_pos += inc;
            
            if (new_pos > actions().size())
              new_pos = 0;
            if (new_pos < 0)
              new_pos = actions().size();
            
            safety++;
            if (safety > 1000)
              break;
            
          }while(new_action==NULL || new_action->isVisible()==false || new_action->isSeparator()==true || new_action->isEnabled()==false);
          
        }

        if (new_action!=NULL)
          setActiveAction(new_action);
        
        event->accept();

        return;
      }
      
      QMenu::keyPressEvent(event);
    }

  };
  
  struct MyMainQMenu : public MyQMenu{
    Q_OBJECT

  public:
    
    func_t *_callback;

    MyMainQMenu(QWidget *parent, QString title, bool is_async, func_t *callback)
      : MyQMenu(parent, title)
      , _callback(callback)
    {
      
      R_ASSERT(is_async==true); // Lots of trouble with non-async menus. (triggers qt bugs)
      
      if(_callback!=NULL)
        s7extra_protect(_callback);

      connect(this, SIGNAL(hovered(QAction*)), this, SLOT(hovered(QAction*)));
    }
    
    ~MyMainQMenu(){
      if(_callback!=NULL)
        s7extra_unprotect(_callback);      
    }

    void showEvent(QShowEvent *event) override {
      if (_has_keyboard_focus==false){
        obtain_keyboard_focus_counting();
        _has_keyboard_focus = true;
      }
    }

    void hideEvent(QHideEvent *event) override {
      if (_has_keyboard_focus==true){
        release_keyboard_focus_counting();
        _has_keyboard_focus = false;
      }
    }

    void closeEvent(QCloseEvent *event) override{
      if (_has_keyboard_focus==true){
        release_keyboard_focus_counting();
        _has_keyboard_focus = false;
      }
    }
  

    /*
    void actionEvent(QActionEvent *e) override{
      printf("   ACTION EVENT called: %p\n", e);
      QMenu::actionEvent(e);
    }
    */

  public slots:
    
    void hovered(QAction *action){
      MyQAction *myaction = dynamic_cast<MyQAction*>(action);
      
      if (g_last_hovered_widget.data() != NULL)
        g_last_hovered_widget->update();
      
      if (myaction!=NULL){
        
        myaction->_widget->update();
        
        g_last_hovered_menu_entry_guinum = myaction->_guinum;
        g_last_hovered_widget = myaction->_widget;
                    
      } else {

        g_last_hovered_menu_entry_guinum = -1;
        g_last_hovered_widget = NULL;
        
      }
      
      //printf("  QMENU::HOVERED action: %p. myaction: %p\n", action, myaction);
    }
      

  };


}


static void setStyleRecursively(QWidget *widget, QStyle *style){
  if (widget != NULL){
    widget->setStyle(style);
    
    for(auto *c : widget->children())
      setStyleRecursively(dynamic_cast<QWidget*>(c), style);
  }
}

static QMenu *create_qmenu(
                           const vector_t &v,
                           bool is_async,
                           func_t *callback2,
                           std::function<void(int,bool)> callback3,
                           int *result
                           )
{
  R_ASSERT(is_async==true); // Lots of trouble with non-async menus. (triggers qt bugs)

  g_myactions_counter = 0;
  g_curr_visible_actions.clear();
  
  MyMainQMenu *menu = new MyMainQMenu(NULL, "", is_async, callback2);
  menu->setAttribute(Qt::WA_DeleteOnClose);

  MyQMenu *curr_menu = menu;
  
  QStack<MyQMenu*> parents;
  QStack<int> n_submenuess;
  int n_submenues=0;

  QActionGroup *radio_buttons = NULL;
  QButtonGroup *radio_buttons2 = NULL;
  
  for(int i=0;i<v.num_elements;i++) {
    
    QString text = (const char*)v.elements[i];
    
    if (text.startsWith("----")) {
      
      auto *separator = curr_menu->addSeparator();

      for(int i = 3 ; i < text.size() ; i++)
        if (text[i] != '-'){
          separator->setText(text.mid(i));
          break;
        }
      
    } else {
      
      if (n_submenues==getMaxSubmenuEntries()){
        auto *new_menu = new MyQMenu(curr_menu, "Next");
        curr_menu->addMenu(new_menu);
        curr_menu = new_menu;
        //curr_menu->setStyleSheet("QMenu { menu-scrollable: 1; }");
        n_submenues=0;
      }
      
      QAction *action = NULL;
      
      
      bool disabled = false;
      bool is_checkable = false;
      bool is_checked = false;

      QString icon_filename;
      QString shortcut;
      
    parse_next:

      if (text.startsWith("[disabled]")){
        text = text.right(text.size() - 10);
        disabled = true;
        goto parse_next;
      }
      
      if (text.startsWith("[check on]")){
        text = text.right(text.size() - 10);
        is_checkable = true;
        is_checked = true;
        goto parse_next;
      }

      if (text.startsWith("[check off]")){
        text = text.right(text.size() - 11);
        is_checkable = true;
        is_checked = false;
        goto parse_next;
      }

      if (text.startsWith("[icon]")){
        text = text.right(text.size() - 6);
        int pos = text.indexOf(" ");
        if (pos <= 0){
          R_ASSERT(false);
        } else {
          QString encoded = text.left(pos);
          icon_filename = QByteArray::fromBase64(encoded.toUtf8());
          text = text.right(text.size() - pos - 1);
          //printf("  text: -%s-. encoded: -%s-. Filename: -%s-\n", text.toUtf8().constData(), encoded.toUtf8().constData(), icon_filename.toUtf8().constData());
        }
        goto parse_next;
      }

      if (text.startsWith("[shortcut]")){
        text = text.right(text.size() - 10);
        int pos = text.indexOf("[/shortcut]");
        if (pos <= 0){
          R_ASSERT(false);
        } else {
          shortcut = text.left(pos);
          text = text.right(text.size() - pos - 11);
          //printf("shortcut: -%s-. text: -%s-\n", shortcut.toUtf8().constData(), text.toUtf8().constData());
        }
        goto parse_next;
      }
      
      if (text.startsWith("[submenu start]")){
        
        n_submenuess.push(n_submenues);
        n_submenues = -1;
        parents.push(curr_menu);
        auto *new_menu = new MyQMenu(curr_menu, text.right(text.size() - 15));
        curr_menu->addMenu(new_menu);
        curr_menu = new_menu;
        //curr_menu->setStyleSheet("QMenu { menu-scrollable: 1; }");
        
      } else if (text.startsWith("[submenu end]")){
        
        MyQMenu *parent = parents.pop();
        if (parent==NULL)
          handleError("parent of [submenu end] is not a QMenu");
        else
          curr_menu = parent;
        n_submenues = n_submenuess.pop();

      } else if (text.startsWith("[radiobuttons start]")){
        
        radio_buttons = new QActionGroup(curr_menu);
        radio_buttons2 = new QButtonGroup(curr_menu);
        
      } else if (text.startsWith("[radiobuttons end]")){
        
        R_ASSERT_NON_RELEASE(radio_buttons!=NULL);
        R_ASSERT_NON_RELEASE(radio_buttons2!=NULL);
        
        if (radio_buttons!=NULL && radio_buttons->actions().size()==0){
          delete radio_buttons;
          if (radio_buttons2!=NULL){
            R_ASSERT(radio_buttons2->buttons().size()==0);
            delete radio_buttons2;
          } else
            R_ASSERT(false);
        }
        
        radio_buttons = NULL;
        radio_buttons2 = NULL;
        
      } else {

        QIcon icon;

        if (icon_filename != ""){

          static QHash<QString, QIcon> icon_map;

          if (icon_map.contains(icon_filename)) {

            icon = icon_map[icon_filename];

          } else {
            QColor background(180,180,190,200);

            icon
              = icon_filename.startsWith("<<<<<<<<<<envelope_icon")
              ? ENVELOPE_get_icon(icon_filename,
                                  get_system_fontheight()*4, get_system_fontheight()*4,
                                  background.darker(200), background, QColor(40,20,45,150)
                                  )
              : QIcon(icon_filename);

            if(icon.isNull())
              handleError("Could not load \"%s\".", icon_filename.toUtf8().constData());
            else
              icon_map[icon_filename] = icon;

          }
        }

        bool is_first = n_submenues==0;
        bool is_last = n_submenues==v.num_elements-1 || n_submenues==getMaxSubmenuEntries()-1;

        if (!is_last){
          if (i < v.num_elements-1){
            QString text = (const char*)v.elements[i+1];
            if(text.startsWith("[submenu end]"))
              is_last=true;
          }
        }
        
        if (!icon.isNull()) {

          action = new ClickableIconAction(icon, text, new Callbacker(menu, i, is_async, callback2, callback3, result, is_checkable));
                    
        } else if (is_checkable) {

          auto *hepp = new CheckableAction(icon, text, shortcut, is_checked, radio_buttons != NULL, is_first, is_last, new Callbacker(menu, i, is_async, callback2, callback3, result, is_checkable));
          if (hepp->_success==false){
            radio_buttons=NULL;
            goto finished_parsing;
          }
          
          action = hepp;
          if (radio_buttons != NULL){
            radio_buttons->addAction(action);
            if (radio_buttons2 != NULL){
              if (hepp->_checkbox != NULL)
                radio_buttons2->addButton(hepp->_checkbox);
            }else{
              R_ASSERT(false);
            }              
          }else{
            R_ASSERT(radio_buttons2==NULL);
          }
          
        } else {

          auto *hepp = new ClickableAction(icon, text, shortcut, is_first, is_last, new Callbacker(menu, i, is_async, callback2, callback3, result, is_checkable));
          if (hepp->_success==false)
            goto finished_parsing;
          
          action = hepp;
        }
      }
      
      if (action != NULL){
        action->setData(i);
        curr_menu->addAction(action);  // are these actions automatically freed in ~QMenu? (yes, seems so) (they are probably freed because they are children of the qmenu)
      }
      
      if (disabled)
        action->setDisabled(true);      
    }

    n_submenues++;
  }

 finished_parsing:
  
  if (menu->actions().size() > 0)
    menu->setActiveAction(menu->actions().at(0));

  R_ASSERT_NON_RELEASE(radio_buttons==NULL);
  R_ASSERT_NON_RELEASE(radio_buttons2==NULL);
  
  if (radio_buttons!=NULL && radio_buttons->actions().size()==0){
    R_ASSERT_NON_RELEASE(false);
    delete radio_buttons;
  }

  if (radio_buttons2!=NULL && radio_buttons2->buttons().size()==0){
    R_ASSERT_NON_RELEASE(false);
    delete radio_buttons2;
  }

  /*
  for(auto style : QStyleFactory::keys())
    printf("  STYLE: -%s\n", style.toUtf8().constData());
  */
  
  setStyleRecursively(menu, &g_my_proxy_style);

  /*
  menu->setStyleSheet("QMenu::indicator:exclusive:checked {  background-color: #ff00ff; }"
                      "QMenu::indicator:exclusive:unchecked {  background-color: #00ffff; }"
                      );
  */
  return menu;
}

void GFX_HoverMenuEntry(int entryid){
  if (g_curr_visible_actions.contains(entryid)){
    
    MyQAction *action = g_curr_visible_actions[entryid].data();
    if(action==NULL){
      R_ASSERT_NON_RELEASE(false);
      return;
    }
    
    action->activate(QAction::Hover);
    
  } else {

    g_last_hovered_menu_entry_guinum = -1;
    
  }
}

static int64_t GFX_QtMenu(
                          const vector_t &v,
                          func_t *callback2,
                          std::function<void(int,bool)> callback3,
                          bool is_async,
                          bool program_state_is_valid
                          )
{
  R_ASSERT_RETURN_IF_FALSE2(is_async==true, -1); // Lots of trouble with non-async menus. (triggers qt bugs)
  
  if(is_async){
    R_ASSERT(callback2!=NULL || callback3);
    R_ASSERT_RETURN_IF_FALSE2(program_state_is_valid, -1);
  }

  int result = -1;
  
  QMenu *menu = create_qmenu(v, is_async,  callback2, callback3, is_async ? NULL : &result);
  //printf("                CREATED menu %p", menu);
  
  if (is_async){

    safeMenuPopup(menu);
    return API_get_gui_from_existing_widget(menu);
    
  } else {
    
    QAction *action = safeMenuExec(menu, program_state_is_valid);
    (void)action;

    if (result >= v.num_elements){
      //R_ASSERT(false);
      return -1;
    }

    return result;
  }
}
int64_t GFX_Menu3(
              const vector_t &v,
              std::function<void(int,bool)> callback3
              )
{
  return GFX_QtMenu(v, NULL, callback3, true, true);
}

int64_t GFX_Menu2(
              struct Tracker_Windows *tvisual,
              ReqType reqtype,
              const char *seltext,
              const vector_t v,
              func_t *callback,
              bool is_async,
              bool program_state_is_valid
              )
{
  R_ASSERT_RETURN_IF_FALSE2(is_async==true, -1); // Lots of trouble with non-async menus. (triggers qt bugs)
  
  if(is_async){
    R_ASSERT_RETURN_IF_FALSE2(callback!=NULL, -1);
    R_ASSERT_RETURN_IF_FALSE2(program_state_is_valid, 1);
  }
  
  if(reqtype==NULL || v.num_elements>20 || is_async || callback!=NULL){
    std::function<void(int,bool)> empty_callback3;
    return GFX_QtMenu(v, callback, empty_callback3, is_async, program_state_is_valid);
  }else
    return GFX_ReqTypeMenu(tvisual,reqtype,seltext,v, program_state_is_valid);
}


int GFX_Menu(
             struct Tracker_Windows *tvisual,
             ReqType reqtype,
             const char *seltext,
             const vector_t v,
             bool program_state_is_valid
             )
{
  bool created_reqtype = reqtype==NULL;

  if (created_reqtype)
    reqtype = GFX_OpenReq(tvisual,-1, -1, "");
  
  int ret = GFX_ReqTypeMenu(tvisual,reqtype,seltext,v, program_state_is_valid);

  if (created_reqtype)
    GFX_CloseReq(tvisual, reqtype);

  return ret;
  
  //return GFX_Menu2(tvisual, reqtype, seltext, v, NULL, false, program_state_is_valid);
}

// The returned vector can be used as argument for GFX_Menu.
vector_t GFX_MenuParser(const char *texts, const char *separator){
  vector_t ret = {};
  
  QStringList splitted = QString(texts).split(separator);
  
  for(int i=0 ; i<splitted.size() ; i++){
    QString trimmed = splitted[i].trimmed();
    if (trimmed != "")
      VECTOR_push_back(&ret, talloc_strdup(trimmed.toUtf8().constData()));
  }

  return ret;
}

#include "mQt_PopupMenu.cpp"

#endif // USE_QT_MENU
