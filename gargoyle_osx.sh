#!/bin/sh

SYSLIBS=/usr/lib
MACPORTS=/usr/local/lib
GARGDIST=build/dist
DYLIBSLIST=support/dylibs
BUNDLE=Gargoyle.app/Contents

count=0
for lib in `cat $DYLIBSLIST`
do
  if [[ -e "$MACPORTS/$lib" ]];
  then
    LIBPATHS[$count]="$MACPORTS/$lib";
  elif  [[ -e "$SYSLIBS/$lib" ]];
  then
    LIBPATHS[$count]="$SYSLIBS/$lib";
  else
    echo "Unable to find dylib $lib in $MACPORTS or $SYSLIBS"
    exit;
  fi
  count=$((${count}+1))
done

rm -rf Gargoyle.app
mkdir -p $BUNDLE/MacOS
mkdir -p $BUNDLE/Frameworks
mkdir -p $BUNDLE/Resources
mkdir -p $BUNDLE/PlugIns

rm -rf $GARGDIST
jam install

for file in `ls $GARGDIST`
do
  for libpath in "${LIBPATHS[@]}"
  do
    lib=`basename $libpath`
    install_name_tool -change $libpath @executable_path/../Frameworks/$lib $GARGDIST/$file
  done
  install_name_tool -change @executable_path/libgarglk.dylib @executable_path/../Frameworks/libgarglk.dylib $GARGDIST/$file
done

install_name_tool -id @executable_path/../Frameworks/libgarglk.dylib $GARGDIST/libgarglk.dylib

for file in `ls $GARGDIST | grep -v .dylib | grep -v gargoyle`
do
  echo "Copying to $BUNDLE/PlugIns: $GARGDIST/$file"
  cp -f $GARGDIST/$file $BUNDLE/PlugIns
done

for libpath in "${LIBPATHS[@]}"
do
  echo "Copying to $BUNDLE/Frameworks: $libpath"
  cp $libpath $BUNDLE/Frameworks
done
chmod 644 $BUNDLE/Frameworks/*

for dylibpath in "${LIBPATHS[@]}"
do
  dylib=`basename $dylibpath`
  for libpath in "${LIBPATHS[@]}"
  do
    lib=`basename $libpath`
    install_name_tool -change $libpath @executable_path/../Frameworks/$lib $BUNDLE/Frameworks/$dylib
  done
  install_name_tool -id @executable_path/../Frameworks/$dylib $BUNDLE/Frameworks/$dylib
done

cp -f garglk/launcher.plist $BUNDLE/Info.plist
cp -f $GARGDIST/gargoyle $BUNDLE/MacOS/Gargoyle
cp -f $GARGDIST/libgarglk.dylib $BUNDLE/Frameworks
cp -f garglk/launchmac.nib $BUNDLE/Resources/MainMenu.nib
cp -f garglk/garglk.ini $BUNDLE/Resources
cp -f garglk/*.icns $BUNDLE/Resources
cp -f licenses/* $BUNDLE/Resources

mkdir $BUNDLE/Resources/Fonts
cp fonts/LiberationMono*.ttf $BUNDLE/Resources/Fonts
cp fonts/LinLibertine*.otf $BUNDLE/Resources/Fonts

hdiutil create -ov -srcfolder Gargoyle.app/ gargoyle-2015.1-mac.dmg
