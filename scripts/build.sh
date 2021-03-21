#!/bin/bash
set -e
################## SETUP BEGIN
THREAD_COUNT=$(sysctl hw.ncpu | awk '{print $2}')
HOST_ARC=$( uname -m )
XCODE_ROOT=$( xcode-select -print-path )
ICU_VER=maint/maint-68
################## SETUP END
DEVSYSROOT=$XCODE_ROOT/Platforms/iPhoneOS.platform/Developer
SIMSYSROOT=$XCODE_ROOT/Platforms/iPhoneSimulator.platform/Developer
ICU_VER_NAME=icu4c-${ICU_VER//\//-}
BUILD_DIR="$( cd "$( dirname "./" )" >/dev/null 2>&1 && pwd )"
INSTALL_DIR="$BUILD_DIR/product"

################### BUILD FOR MAC OSX
ICU_BUILD_FOLDER=$ICU_VER_NAME-build
ICU4C_FOLDER=icu/icu4c

#explicit 68.2
cd icu
git reset --hard 84e1f26ea77152936e70d53178a816dbfbf69989
cd ..

if [ ! -f $ICU_BUILD_FOLDER.success ]; then
echo preparing build folder $ICU_BUILD_FOLDER ...
if [ -d $ICU_BUILD_FOLDER ]; then
    rm -rf $ICU_BUILD_FOLDER
fi
cp -r $ICU4C_FOLDER $ICU_BUILD_FOLDER

echo "building icu (mac osx)..."
pushd $ICU_BUILD_FOLDER/source

./runConfigureICU MacOSX --enable-static --disable-shared prefix=$INSTALL_DIR CXXFLAGS="--std=c++17"
make -j$THREAD_COUNT
make install
popd
touch $ICU_BUILD_FOLDER.success 
fi

################### BUILD FOR SIM
ICU_IOS_SIM_BUILD_FOLDER=$ICU_VER_NAME-ios.sim-build
if [ ! -f $ICU_IOS_SIM_BUILD_FOLDER.success ]; then
echo preparing build folder $ICU_IOS_SIM_BUILD_FOLDER ...
if [ -d $ICU_IOS_SIM_BUILD_FOLDER ]; then
    rm -rf $ICU_IOS_SIM_BUILD_FOLDER
fi
cp -r $ICU4C_FOLDER $ICU_IOS_SIM_BUILD_FOLDER
echo "building icu (iOS: iPhoneSimulator)..."
pushd $ICU_IOS_SIM_BUILD_FOLDER/source

COMMON_CFLAGS="-isysroot $SIMSYSROOT/SDKs/iPhoneSimulator.sdk -I$SIMSYSROOT/SDKs/iPhoneSimulator.sdk/usr/include/ -miphoneos-version-min=9.0"
./configure --disable-tools --disable-extras --disable-tests --disable-samples --disable-dyload --enable-static --disable-shared prefix=$INSTALL_DIR --host=$HOST_ARC-apple-darwin --with-cross-build=$BUILD_DIR/$ICU_BUILD_FOLDER/source CFLAGS="$COMMON_CFLAGS" CXXFLAGS="$COMMON_CFLAGS -c -stdlib=libc++ -Wall --std=c++17" LDFLAGS="-stdlib=libc++ -L$SIMSYSROOT/SDKs/iPhoneSimulator.sdk/usr/lib/ -isysroot $SIMSYSROOT/SDKs/iPhoneSimulator.sdk -Wl,-dead_strip -lstdc++"

make -j$THREAD_COUNT
popd
touch $ICU_IOS_SIM_BUILD_FOLDER.success 
fi

################### BUILD FOR DEV
ICU_IOS_BUILD_FOLDER=$ICU_VER_NAME-ios.dev-build
if [ ! -f $ICU_IOS_BUILD_FOLDER.success ]; then
echo preparing build folder $ICU_IOS_BUILD_FOLDER ...
if [ -d $ICU_IOS_BUILD_FOLDER ]; then
    rm -rf $ICU_IOS_BUILD_FOLDER
fi
cp -r $ICU4C_FOLDER $ICU_IOS_BUILD_FOLDER
echo "building icu (iOS: iPhoneOS)..."
pushd $ICU_IOS_BUILD_FOLDER/source

COMMON_CFLAGS="-arch arm64 -arch armv7 -fembed-bitcode-marker -isysroot $DEVSYSROOT/SDKs/iPhoneOS.sdk -I$DEVSYSROOT/SDKs/iPhoneOS.sdk/usr/include/ -miphoneos-version-min=9.0"
./configure --disable-tools --disable-extras --disable-tests --disable-samples --disable-dyload --enable-static --disable-shared prefix=$INSTALL_DIR --host=arm-apple-darwin --with-cross-build=$BUILD_DIR/$ICU_BUILD_FOLDER/source CFLAGS="$COMMON_CFLAGS" CXXFLAGS="$COMMON_CFLAGS -c -stdlib=libc++ -Wall --std=c++17" LDFLAGS="-stdlib=libc++ -L$DEVSYSROOT/SDKs/iPhoneOS.sdk/usr/lib/ -isysroot $DEVSYSROOT/SDKs/iPhoneOS.sdk -Wl,-dead_strip -lstdc++"
make -j$THREAD_COUNT
popd
touch $ICU_IOS_BUILD_FOLDER.success 
fi

if [ -d $INSTALL_DIR/frameworks ]; then
    rm -rf $INSTALL_DIR/frameworks
fi
mkdir $INSTALL_DIR/frameworks

xcodebuild -create-xcframework -library $INSTALL_DIR/lib/libicudata.a -library $ICU_IOS_SIM_BUILD_FOLDER/source/lib/libicudata.a -library $ICU_IOS_BUILD_FOLDER/source/lib/libicudata.a -output $INSTALL_DIR/frameworks/icudata.xcframework

xcodebuild -create-xcframework -library $INSTALL_DIR/lib/libicui18n.a -library $ICU_IOS_SIM_BUILD_FOLDER/source/lib/libicui18n.a -library $ICU_IOS_BUILD_FOLDER/source/lib/libicui18n.a -output $INSTALL_DIR/frameworks/icui18n.xcframework

xcodebuild -create-xcframework -library $INSTALL_DIR/lib/libicuio.a -library $ICU_IOS_SIM_BUILD_FOLDER/source/lib/libicuio.a -library $ICU_IOS_BUILD_FOLDER/source/lib/libicuio.a -output $INSTALL_DIR/frameworks/icuio.xcframework

xcodebuild -create-xcframework -library $INSTALL_DIR/lib/libicuuc.a -library $ICU_IOS_SIM_BUILD_FOLDER/source/lib/libicuuc.a -library $ICU_IOS_BUILD_FOLDER/source/lib/libicuuc.a -output $INSTALL_DIR/frameworks/icuuc.xcframework

if [ -d $INSTALL_DIR/universal ]; then
    rm -rf $INSTALL_DIR/universal
fi
mkdir $INSTALL_DIR/universal

lipo -create -output $INSTALL_DIR/universal/libicudata.a $ICU_IOS_SIM_BUILD_FOLDER/source/lib/libicudata.a $ICU_IOS_BUILD_FOLDER/source/lib/libicudata.a

lipo -create -output $INSTALL_DIR/universal/libicui18n.a $ICU_IOS_SIM_BUILD_FOLDER/source/lib/libicui18n.a $ICU_IOS_BUILD_FOLDER/source/lib/libicui18n.a

lipo -create -output $INSTALL_DIR/universal/libicuio.a $ICU_IOS_SIM_BUILD_FOLDER/source/lib/libicuio.a $ICU_IOS_BUILD_FOLDER/source/lib/libicuio.a

lipo -create -output $INSTALL_DIR/universal/libicuuc.a $ICU_IOS_SIM_BUILD_FOLDER/source/lib/libicuuc.a $ICU_IOS_BUILD_FOLDER/source/lib/libicuuc.a
