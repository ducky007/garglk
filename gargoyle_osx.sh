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

# Copy all our dylibs into /Frameworks.
for libpath in "${LIBPATHS[@]}"
do
  echo "Copying to $BUNDLE/Frameworks: $libpath"
  cp $libpath $BUNDLE/Frameworks
done

# Make them all writable, since we're going to have to adjust their
# linking paths.
chmod 644 $BUNDLE/Frameworks/*

# Go through the interpreter binaries. For each one, adjust the linking path
# of its dylibs to point to the Frameworks directory (instead of 
# /usr/local/lib or what have you).

for file in `ls $GARGDIST`
do
  for libpath in `otool -L $GARGDIST/$file | sed -E -n 's/[[:space:]]([/][^[:space:]]+[.]dylib) .*$/\1/p' | grep -E -v '/libSystem|/libobjc|/libc[+][+]'`
  do
    lib=`basename $libpath`
    if [[ -e "$BUNDLE/Frameworks/$lib" ]];
    then
      install_name_tool -change $libpath @executable_path/../Frameworks/$lib $GARGDIST/$file;
    else
      echo "Frameworks does not contain $lib ($libpath)"
      exit;
    fi
  done

  install_name_tool -change @executable_path/libgarglk.dylib @executable_path/../Frameworks/libgarglk.dylib $GARGDIST/$file
done

# Adjust the path of libgarglk within itself.
install_name_tool -id @executable_path/../Frameworks/libgarglk.dylib $GARGDIST/libgarglk.dylib

# Copy the interpreters to the /PlugIns directory.
for file in `ls $GARGDIST | grep -v .dylib | grep -v gargoyle`
do
  echo "Copying to $BUNDLE/PlugIns: $GARGDIST/$file"
  cp -f $GARGDIST/$file $BUNDLE/PlugIns
done

# Adjust the linking paths of the dylibs within the dylibs themselves.
for dylibpath in "${LIBPATHS[@]}"
do
  dylib=`basename $dylibpath`

  for libpath in `otool -L $BUNDLE/Frameworks/$dylib | sed -E -n 's/[[:space:]]([/][^[:space:]]+[.]dylib) .*$/\1/p' | grep -E -v '/libSystem|/libobjc|/libc[+][+]'`
  do
    lib=`basename $libpath`
    if [[ -e "$BUNDLE/Frameworks/$lib" ]];
    then
      install_name_tool -change $libpath @executable_path/../Frameworks/$lib $BUNDLE/Frameworks/$dylib
    else
      echo "Frameworks does not contain $lib ($libpath)"
      exit;
    fi
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
