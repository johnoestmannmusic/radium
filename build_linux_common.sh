#!/bin/bash

set -e

export PYTHONEXE=`./find_python_path.sh`

export RADIUM_BIN="bin/radium_linux.bin"

# find_moc_and_uic_path.sh has been tested on fedora 11, fedora 17, ubuntu 12, and mint 13.
#export MOC="`./find_moc_and_uic_paths.sh moc`"
#export UIC="`./find_moc_and_uic_paths.sh uic`"

# Uncomment next line for debug build.
#export BUILDTYPE=RELEASE

export JACKOPT="-DNO_JACK_METADATA"
export JACK_LDFLAGS="-ljack"

if ! env |grep RADIUM_QT_VERSION ; then
    echo "Must define RADIUM_QT_VERSION to either 4 or 5. For instance: \"BUILDTYPE=RELEASE RADIUM_QT_VERSION=5 ./build_linux.sh -j7\""
    exit -1
fi

if ! env |grep BUILDTYPE ; then
    echo "Must define BUILDTYPE to DEBUG or RELEASE. For instance: \"BUILDTYPE=RELEASE RADIUM_QT_VERSION=5 ./build_linux.sh -j7\""
    exit -1
fi


# Don't include faustdev (by default) in debug builds since it increases linker time and increases startup time when running under gdb.
#
if [[ $BUILDTYPE == RELEASE ]]
then
    if ! env |grep IS_LINUX_BINARY ; then
        export INCLUDE_FAUSTDEV="jadda"
    fi
fi

#export INCLUDE_FAUSTDEV="jadda"

# Always compile pddev. Most of it is placed in a dynamic library, so it doesn't contribute to higher link time or startup time.
export INCLUDE_PDDEV="jadda"


#if ! env |grep OPTIMIZE ; then
export OPTIMIZE="-O2 -mfpmath=sse -msse2 $RADIUM_RELEASE_CFLAGS"
#fi

export CPUOPT=
#"$OPTIMIZE" # Some files are so CPU intensive that we need to turn on optimizations even in debug mode, at least when running in valgrind.
#export CPUOPT=

#export CCC="clang++ -mfpmath=sse -msse2"
export CCC="g++ -mfpmath=sse -msse2"
export CC="gcc -mfpmath=sse -msse2"
#export CC="clang -Wno-gnu-designator -mfpmath=sse -msse2 -Wenum-conversion "
export GCC="gcc -mfpmath=sse -msse2"
export CLANGCC="clang++ -mfpmath=sse -msse2"
export LINKER=g++

export FPIC="-fPIC"

export TARGET_OS=linux

export PKG=pkg-config
export PYPATH=`$PYTHONEXE -c "import sys;print sys.prefix+'/include/python'+sys.version[:3]"`

# static Qt4:
#RQTDIR=/home/kjetil/qt-everywhere-opensource-src-4.8.6
#export QT_CFLAGS="-DQT_STATIC -DQT3_SUPPORT -I$RQTDIR/include/Qt3Support -I$RQTDIR/include/QtCore -I$RQTDIR/include/QtGui -I$RQTDIR/include/QtNetwork -I$RQTDIR/include/QtSql -I$RQTDIR/include/QtOpenGL -Ibin/packages/qhttpserver-master/src"
#export QT_LDFLAGS="$RQTDIR/lib/libQt3Support.a $RQTDIR/lib/libQtSql.a $RQTDIR/lib/libQtOpenGL.a $RQTDIR/lib/libQtGui.a $RQTDIR/lib/libQtNetwork.a $RQTDIR/lib/libQtCore.a -lSM -lICE -lfreetype -lfontconfig -lXrender -lpng -lglib-2.0 -lgobject-2.0"

QT_QMAKE_BIN_PATH=`./find_moc_and_uic_paths.sh qmake`
QT_INCLUDE_PATH=`$QT_QMAKE_BIN_PATH -query QT_INSTALL_HEADERS`
export QT_UI_CFLAGS="-I $QT_INCLUDE_PATH/QtUiTools" # Doing this instead of using pkg since there are bugs in the dependencies of the pkg file in some versions of Qt. (same with the lib file below)
export QT_UI_LDFLAGS="`$QT_QMAKE_BIN_PATH -query QT_INSTALL_LIBS`/libQt5UiTools.a"


VL_PATH="bin/packages/Visualization-Library-master"
#VL_QTLIB="$VL_PATH/src/vlQt$RADIUM_QT_VERSION/lib/libVLQt$RADIUM_QT_VERSION.a"
export VL_CFLAGS="-DVL_STATIC_LINKING -Wall -I$VL_PATH/src -I$VL_PATH/src/3rdparty/Khronos -I$VL_PATH/src/examples"
export VL_LIBS="$VL_PATH/src/vlVG/lib/libVLVG.a $VL_PATH/src/vlGraphics/lib/libVLGraphics.a $VL_PATH/src/vlCore/lib/libVLCore.a `$PKG --libs freetype2` -lGL -lGLU"
# $VL_QTLIB

#$VL_PATH/src/vlGraphics/plugins/freetype/lib/libFreeType.a 

export GCDIR="bin/packages/gc-7.4.4"

# jack midi not working very well since the player is now run inside the jack audio thread.
#export RTMIDI_CFLAGS="-D__UNIX_JACK__ -D__LINUX_ALSA__  -D__RTMIDI_DEBUG__"
export RTMIDI_CFLAGS="-D__LINUX_ALSA__  -D__RTMIDI_DEBUG__"
export RTMIDI_LDFLAGS="-lpthread -lasound -ljack"

#export OS_OPTS="-DTEST_GC"
export OS_OPTS="-Werror=array-bounds -msse2 -fno-omit-frame-pointer -DFOR_LINUX `$PKG --cflags Qt5X11Extras`"
#export OS_OPTS="-Werror=array-bounds -march=native"

if env |grep INCLUDE_FAUSTDEV ; then
    export OS_OPTS="$OS_OPTS -DWITH_FAUST_DEV"
fi

if env |grep INCLUDE_PDDEV ; then
    export OS_OPTS="$OS_OPTS -DWITH_PD"
fi

PYTHONLIBPATH=`$PYTHONEXE -c "import sys;print '-L'+sys.prefix+'/lib'"`
PYTHONLIBNAME=`$PYTHONEXE -c "import sys;print '-lpython'+sys.version[:3]"`

LLVM_OPTS=`llvm-config --cppflags`

MAYBELLVM=`llvm-config --libdir`/libLLVM-`llvm-config --version`.so
if [ -f $MAYBELLVM ]; then
    LLVMLIBS=-lLLVM-`llvm-config --version`
else
    LLVMLIBS=`llvm-config --libs`
fi

if env |grep INCLUDE_FAUSTDEV ; then
    FAUSTLDFLAGS="bin/packages/QScintilla_gpl-2.9.2/Qt4Qt5/libqscintilla2.a bin/packages/faust2/compiler/libfaust.a `$PKG --libs uuid` `llvm-config --ldflags` $LLVMLIBS -lcrypto -lncurses"
else    
    FAUSTLDFLAGS=""
fi
# _debug

if env |grep INCLUDE_PDDEV ; then
    PDLDFLAGS="bin/packages/libpd-master/libs/libpds.a"
else    
    PDLDFLAGS=""
fi

if ! env |grep RADIUM_BFD_CFLAGS ; then
    export RADIUM_BFD_CFLAGS=""
fi

if ! env |grep RADIUM_BFD_LDFLAGS ; then
    export RADIUM_BFD_LDFLAGS="-Wl,-Bstatic -lbfd -Wl,-Bdynamic"
fi

export OS_LDFLAGS="$FAUSTLDFLAGS $PDLDFLAGS pluginhost/Builds/Linux/build/libMyPluginHost.a -lasound -llrdf -pthread -lrt -lX11 $GCDIR/.libs/libgc.a  $PYTHONLIBPATH $PYTHONLIBNAME bin/packages/libgig/src/.libs/libgig.a bin/packages/fluidsynth-1.1.6/src/.libs/libfluidsynth.a `$PKG --libs dbus-1` `$PKG --libs sndfile` `$PKG --libs samplerate` `$PKG --libs Qt5X11Extras` -lXext `$PKG --libs glib-2.0` -lxcb -lxcb-keysyms $RADIUM_BFD_LDFLAGS -lz -liberty -lutil -ldl -lgmp -lmpfr -lmpc"

# 

# 

#-L${HOME}/boost_1_60_0/stage/lib -Wl,-Bstatic -lboost_thread -lboost_system -Wl,-Bdynamic"

export OS_DEPS="pluginhost/Builds/Linux/build/libMyPluginHost.a"

#bin/packages/qhttpserver-master/lib/libqhttpserver.a

#  -lz -libery -lintl

export OBJ_WIN=""
export OBJ_MACOSX=""

mkdir -p linux_objs

#if ! file mmd2load.o |grep Linux ; then
#    rm -f *.o
#    cp -p linux_objs/*.o . 2>/dev/null | true
#fi

if ! file $RADIUM_BIN |grep Linux ; then
    echo "  Non-linux build detected. Deleting binaries."
    rm -f bin/radium
    rm -f $RADIUM_BIN
    rm -f bin/radium_crashreporter
    rm -f bin/radium_error_message
fi

make buildtype.opt --stop
make flagopts.opt --stop
make radium $@ --stop
#make pluginhost/Builds/Linux/build/libMyPluginHost.a

cp -f bin/run_radium_linux.sh bin/radium

#cp -p *.o linux_objs/ 2>/dev/null | true


