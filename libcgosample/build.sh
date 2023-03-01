#!/bin/bash
set -e

cd "$(dirname "$0")"

BUILD_ROOT="$(pwd)/build"

xcf() {
  libname="$1"
  incdir="$2"
  name="${3:-$libname}"
  xcf="$name.xcframework"

  mkdir -p "$BUILD_ROOT/frameworks"
  rm -rf "$BUILD_ROOT/frameworks/$xcf"

  libdir="$(mktemp -d -t xclibs)"
  headerdir="$(mktemp -d -t xcheaders)"
  list=""
  for arch in tvos/arm64 ios/arm64; do
    if [ -f "$BUILD_ROOT/$arch/lib/$libname.a" ]; then
    mkdir -p "$headerdir/$arch"
    cp -a $BUILD_ROOT/$arch/include/$incdir "$headerdir/$arch/"
    list="$list -library $BUILD_ROOT/$arch/lib/$libname.a -headers $headerdir/$arch"
    fi
  done

  if [ -f "$BUILD_ROOT/macosx/x86_64/lib/$libname.a" ]; then
  mkdir -p "$headerdir/macosx"
  cp -a $BUILD_ROOT/macosx/arm64/include/$incdir "$headerdir/macosx/"
  lipo "$BUILD_ROOT/macosx/x86_64/lib/$libname.a" "$BUILD_ROOT/macosx/arm64/lib/$libname.a" -create -output "$libdir/$libname.a"
  list="$list -library $libdir/$libname.a -headers $headerdir/macosx"
  fi

  if [ -f "$BUILD_ROOT/tvosim/x86_64/lib/$libname.a" ]; then
  mkdir -p "$headerdir/tvosim" "$libdir/tvosim"
  cp -a $BUILD_ROOT/tvosim/arm64/include/$incdir "$headerdir/tvosim/"
  lipo "$BUILD_ROOT/tvosim/x86_64/lib/$libname.a" "$BUILD_ROOT/tvosim/arm64/lib/$libname.a" -create -output "$libdir/tvosim/$libname.a"
  list="$list -library $libdir/tvosim/$libname.a -headers $headerdir/tvosim"
  fi

  if [ -f "$BUILD_ROOT/iosim/x86_64/lib/$libname.a" ]; then
  mkdir -p $headerdir/iosim $libdir/iosim
  cp -a $BUILD_ROOT/iosim/arm64/include/$incdir $headerdir/iosim/
  lipo "$BUILD_ROOT/iosim/x86_64/lib/$libname.a" "$BUILD_ROOT/iosim/arm64/lib/$libname.a" -create -output $libdir/iosim/$libname.a
  list="$list -library $libdir/iosim/$libname.a -headers $headerdir/iosim"
  fi

  xcodebuild -create-xcframework $list -output "$BUILD_ROOT/frameworks/$xcf"
  rm -rf "$headerdir"
  rm -rf "$libdir"
}

export PATH="$PATH:/opt/homebrew/bin"

for sdk in ${SDKS:-macosx macosxm1 iphoneos iphonesimulator iphonesimulatorm1 appletvos appletvsimulator appletvsimulatorm1}; do
  sdkname=$(echo $sdk | sed -e 's,m1$,,g')
  SDKPATH="$(xcodebuild -sdk $sdkname -version Path)"
  if [ $sdk = "appletvsimulatorm1" ]; then
    ARCH=arm64
    GOARCH=$ARCH
    SDKPREFIX=tvos-simulator
    PLATFORM=tvosim
    GOOS=ios
  elif [ $sdk = "iphonesimulatorm1" ]; then
    ARCH=arm64
    GOARCH=$ARCH
    SDKPREFIX=ios-simulator
    PLATFORM=iosim
    GOOS=ios
  elif [[ $sdk == appletv* ]]; then
    ARCH=$(test "$sdk" = "appletvos" && echo arm64 || echo x86_64)
    GOARCH=$ARCH
    SDKPREFIX=$(test "$sdk" = "appletvos" && echo tvos || echo tvos-simulator)
    PLATFORM=$(test "$sdk" = "appletvos" && echo tvos || echo tvosim)
    GOOS=ios
    TAGS="ios"
  elif [ $sdk = "macosxm1" ]; then
    ARCH=arm64
    GOARCH=$ARCH
    SDKPREFIX=ios
    PLATFORM=macosx
    GOOS=darwin
    TAGS=""
  elif [ $sdk = "macosx" ]; then
    ARCH=x86_64
    GOARCH=amd64
    SDKPREFIX=ios
    PLATFORM=macosx
    GOOS=darwin
    TAGS="ios"
  else
    ARCH=$(test "$sdk" = "iphoneos" && echo arm64 || echo x86_64)
    GOARCH=$ARCH
    SDKPREFIX=$(test "$sdk" = "iphoneos" && echo ios || echo ios-simulator)
    PLATFORM=$(test "$sdk" = "iphoneos" && echo ios || echo iosim)
    GOOS=ios
    TAGS="ios"
  fi

  export PATH="$(xcode-select -p)/Toolchains/XcodeDefault.xctoolchain/usr/bin/:$PATH"
  export CFLAGS="-isysroot $SDKPATH -arch $ARCH -ggdb"
  export CC="$(xcrun -sdk $SDKPATH -f clang)"
  export AR="$(xcrun -sdk $SDKPATH -f ar)"

  if [ "$sdk" = "macosx" ]; then
    export CFLAGS="$CFLAGS -target x86_64-apple-ios13.1-macabi"
  elif [ "$sdk" = "macosxm1" ]; then
    export CFLAGS="$CFLAGS -target aarch64-apple-ios-macabi"
  else
    export CFLAGS="$CFLAGS -m$SDKPREFIX-version-min=13.0.0"
  fi

  if [ "$GOARCH" = "x86_64" ]; then
    GOARCH=amd64
  fi

  # export LDFLAGS="$CFLAGS -L$BUILD_ROOT/$PLATFORM/$ARCH/lib"

  mkdir -p $BUILD_ROOT/$PLATFORM/$ARCH/include $BUILD_ROOT/$PLATFORM/$ARCH/lib
  set -x
  env CGO_ENABLED=1 GOOS="$GOOS" CGO_CFLAGS="$CFLAGS" CGO_LDFLAGS="$LDFLAGS" CC="$CC" GOARCH="$GOARCH" go build -trimpath -buildmode=c-archive -tags="$TAGS" -o $BUILD_ROOT/$PLATFORM/$ARCH/lib/libcgosample.a .
  mv $BUILD_ROOT/$PLATFORM/$ARCH/lib/*.h $BUILD_ROOT/$PLATFORM/$ARCH/include
  set +x
  cd "$LIBCHANNELS_ROOT"
done



xcf libcgosample 'libcgosample*.h' libcgosample
