import os,sys


def startit(editor,filename):
    os.system(editor + " " + filename + "&")

def open_editor(filename):
    editor = os.environ.get('EDITOR')
    if editor != None:
        startit(editor,file)
    elif os.system("which emacs")==0:
        startit("emacs",filename)
    elif os.system("which gedit")==0:
        startit("gedit",filename)
    else:
        startit("xdg-open",filename)
