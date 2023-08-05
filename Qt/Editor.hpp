#pragma once

#include "../common/OS_disk_proc.h"

#include "FocusSniffers.h"
#include <Qsci/qscilexerproperties.h>


namespace radium{

class Editor : public FocusSnifferQsciScintilla{

  public:

  QString _filename = "";
  
  QString last_search;

  Editor(QWidget *parent = NULL, QsciLexer *lexer = NULL)
    : FocusSnifferQsciScintilla(parent)
  {
    QFont font;
    auto default_pointsize = font.pointSize();
    font.fromString("Cousine [monotype],20,-1,5,50,0,0,0,0,0,Regular");
    font.setStyleName("Regular");
    font.setPointSize(default_pointsize);    
    
    minimizeMargins(this);

    setMarginLineNumbers(1, true);
    setMarginType(1, QsciScintilla::NumberMargin);

    if (lexer==NULL)
      lexer = new QsciLexerProperties(parent);

    lexer->setFont(font);
    
    setLexer(lexer);

    updateMarginWidth();

    connect(
            this, &QsciScintilla::linesChanged,
            this, &radium::Editor::updateMarginWidth
            );
  }


  void minimizeMargins(QWidget *widget){
#if 0 // Didn't work. I guess qscnintinittlilla doesn't set parent object for all widget children. Changed the source code of qacnintil instead.
    const QList<QObject*> list = widget->children();

    for(auto *element : list){
      widget->children();
      QWidget *widget = dynamic_cast<QWidget*>(element);
      if(widget!=NULL){
        QLayout *layout = widget->layout();
        if (layout!=NULL){
          layout->setSpacing(0);
          layout->setContentsMargins(0,0,0,0);
          for (int i = 0; i < layout->count(); ++i){
            QSpacerItem *item = layout->itemAt(i)->spacerItem();
            if (item!=NULL)
              item->changeSize(0,0, QSizePolicy::Fixed, QSizePolicy::Fixed);
            QWidget *w = layout->itemAt(i)->widget();
            if (w!=NULL)
              minimizeMargins(w);
          }
        }
        
        QFrame *frame = dynamic_cast<QFrame*>(widget);
        if (frame!=NULL){
          frame->setLineWidth(0);
          frame->setMidLineWidth(0);
          frame->setFrameShape(QFrame::NoFrame);
        }
        
        minimizeMargins(widget);
      }
    }
#endif
  }
  
  void search(QString s){
    findFirst(s,
              false,
              false,
              false,
              true
              );
    last_search = s;
  }

  void my_find(void){
    const char *s = GFX_GetString(root->song->tracker_windows, NULL, "Search for (F3 to repeat): ", true);
    if (s!=NULL && strlen(s)>0)
      search(s);
    setFocus(Qt::OtherFocusReason);
  }

  void my_findNext(void){
    search(last_search);
  }
  
  void keyPressEvent ( QKeyEvent * event ) override {

    if(event->key()==Qt::Key_Escape)
      set_editor_focus();

    else if (event->key()==Qt::Key_F3 && last_search != "")
      my_findNext();
    
    else if (event->key()==Qt::Key_F3 || (event->key()==Qt::Key_F && (event->modifiers() & Qt::ControlModifier))) {
      printf("Ctrl+F\n");      
      my_find();
      
    } else if (event->key()==Qt::Key_S && (event->modifiers() & Qt::ControlModifier)) {
      printf("Ctrl+S\n");
      save("");
      
    }else if(event->key()==Qt::Key_Play) {
      playBlockFromStart(-1);

    }else if(event->key()==Qt::Key_Stop) {
      playStop();

    }else if(event->key()==Qt::Key_MediaPlay) {
      if (isPlaying())
        playStop();
      else
        playBlockFromCurrent(-1);

    }else if(event->key()==Qt::Key_MediaStop) {
      playStop();

    }else if(event->key()==Qt::Key_MediaPause) {
      if (isPlaying())
        playStop();
      else
        playBlockFromCurrent(-1);

    }else if(event->key()==Qt::Key_MediaTogglePlayPause) {
      if (isPlaying())
        playStop();
      else
        playBlockFromCurrent(-1);
      
    }else if(event->key()==Qt::Key_VolumeDown) {
      volumeDown();

    }else if(event->key()==Qt::Key_VolumeUp) {
      volumeUp();

    }else if(event->key()==Qt::Key_VolumeMute) {
      mute();

    }else
      FocusSnifferQsciScintilla::keyPressEvent(event);
  }

  void load(filepath_t filename){
    disk_t *disk = DISK_open_for_reading(filename);

    if (disk==NULL){
      GFX_Message2(NULL, true, "File not found (%S)", filename.id);
      return;
    }

    QString text = DISK_read_qstring_file(disk);
      
    if (DISK_close_and_delete(disk)==false) {
      GFX_Message2(NULL, true, "Unable to read from %S", filename.id);
      return;
    }

    _filename = STRING_get_qstring(filename.id);
    
    setText(text);
  }

  void load(QString filename){
    load(make_filepath(filename));
  }

  void setFile(filepath_t filename, bool load_if_exists){
    _filename = STRING_get_qstring(filename.id);
    
    if (load_if_exists && DISK_file_exists(filename))
      load(filename);
  }

  void save(QString filename = ""){
    if (filename=="")
      filename = _filename;
    
    disk_t *disk = DISK_open_for_writing(filename);
    
    //GFX_Message(NULL, "   fff filename: -%s-, %p",filename.toUtf8().constData(), disk);
    if (disk==NULL){
      GFX_Message2(NULL, true, "Unable to open %S for writing", STRING_create(filename));
      return;
    }

    QString code = text();
    bool success = DISK_write_qstring(disk, code);
    
    if (DISK_close_and_delete(disk)==false)
      return;

    if (!success)
      GFX_Message2(NULL, true, "Error. Writing to %S failed: \"%s\"", STRING_create(filename), DISK_get_error(disk));

    _filename = filename;
  }

  void save(filepath_t filename = createIllegalFilepath()){
    if (isLegalFilepath(filename))
      save(STRING_get_qstring(filename.id));
    else
      save(QString(""));
  }


  void updateMarginWidth(void){
    int num_lines_log10 = ceil(log10(lines()));

    QString test = " ";
    
    for(int i = 0 ; i < R_MAX(3, num_lines_log10) ; i++)
      test += "9";
    
    setMarginWidth(1, test);
  }

  void wheelEvent(QWheelEvent *event_) override {
    if (event_->modifiers() & Qt::ControlModifier){                
      if (event_->angleDelta().y() > 0){                                     
        zoomIn(1);
        zoomguess++;
      }else{
        zoomOut(1);
        zoomguess--;
      }
      if (zoomguess < -10)
        zoomguess = -10;
      if (zoomguess > 30)
        zoomguess = 30;
      
      updateMarginWidth();
    } else {
      QsciScintilla::wheelEvent(event_);
      //set_editor_focus();
    }
  }

};
  
}

// call these two before and after creating a radium::Editor instance to fix colors.
extern void pre_create_editor(void);
extern void post_create_editor(void);

