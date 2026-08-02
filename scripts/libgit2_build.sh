#!/bin/bash

# Builds libgit2 as an iOS xcframework, statically linked against libssh2 and
# the OpenSSL libcrypto libssh2 needs. HTTPS goes through SecureTransport, so
# OpenSSL is only ever reached by the SSH transport, which is how the
# ObjectiveGit framework this replaces was put together.
#
# This caps HTTPS at TLS 1.2, which libgit2 hardcodes in its SecureTransport
# stream. Raising it is not possible: SecureTransport on iOS rejects
# kTLSProtocol13 with errSSLIllegalParam, and libgit2 aborts the connection
# when that call fails, so patching the constant breaks HTTPS outright. TLS 1.3
# would mean switching to OpenSSL, and shipping and maintaining a CA bundle
# with it, since OpenSSL cannot read the trust store of the system.

set -euox pipefail

OPENSSL_VERSION="openssl-3.5.7"
LIBSSH2_VERSION="libssh2-1.11.1"
LIBGIT2_VERSION="v1.9.6"

IOS_DEPLOYMENT_TARGET="13.0"

ROOT_PATH="$(pwd)/libgit2"
CHECKOUT_PATH="$ROOT_PATH/checkout"
BUILD_PATH="$ROOT_PATH/build"
INSTALL_PATH="$ROOT_PATH/install"
HEADER_PATH="$ROOT_PATH/include"
OUTPUT_PATH="$ROOT_PATH/dist"

JOBS="$(sysctl -n hw.ncpu)"

mkdir -p "$CHECKOUT_PATH" "$BUILD_PATH" "$INSTALL_PATH" "$OUTPUT_PATH"

checkout() {
  local url="$1" tag="$2" path="$3"
  if [ ! -d "$path" ]; then
    git clone --depth 1 --branch "$tag" "$url" "$path"
  fi
}

checkout https://github.com/openssl/openssl.git "$OPENSSL_VERSION" "$CHECKOUT_PATH/openssl"
checkout https://github.com/libssh2/libssh2.git "$LIBSSH2_VERSION" "$CHECKOUT_PATH/libssh2"
checkout https://github.com/libgit2/libgit2.git "$LIBGIT2_VERSION" "$CHECKOUT_PATH/libgit2"

# CMake needs the platform spelled out for every dependency, and has to be kept
# from looking outside the slice being built when resolving the previous ones.
cmake_configure() {
  local source="$1" build="$2" sdk="$3" arch="$4" prefix="$5"
  shift 5
  cmake -S "$source" -B "$build" \
    -DCMAKE_SYSTEM_NAME=iOS \
    -DCMAKE_OSX_SYSROOT="$sdk" \
    -DCMAKE_OSX_ARCHITECTURES="$arch" \
    -DCMAKE_OSX_DEPLOYMENT_TARGET="$IOS_DEPLOYMENT_TARGET" \
    -DCMAKE_INSTALL_PREFIX="$prefix" \
    -DCMAKE_PREFIX_PATH="$prefix" \
    -DCMAKE_FIND_ROOT_PATH="$prefix" \
    -DCMAKE_BUILD_TYPE=Release \
    -DBUILD_SHARED_LIBS=OFF \
    "$@"
}

build_slice() {
  local slice="$1" sdk="$2" arch="$3" openssl_target="$4"
  local prefix="$INSTALL_PATH/$slice"
  local min_flag

  if [ "$sdk" = "iphoneos" ]; then
    min_flag="-mios-version-min=$IOS_DEPLOYMENT_TARGET"
  else
    min_flag="-mios-simulator-version-min=$IOS_DEPLOYMENT_TARGET"
  fi

  # OpenSSL has its own build system and cannot produce a fat library, so every
  # architecture is configured separately. Only libcrypto is used afterwards.
  # The target already carries the architecture and picks the assembly for it;
  # anything not starting with a dash would be read as a second target.
  # OpenSSL takes by far the longest and is pinned, so an existing install is
  # reused. Remove the install directory to force it to be built again.
  local openssl_build="$BUILD_PATH/$slice/openssl"
  if [ ! -f "$prefix/lib/libcrypto.a" ]; then
    rm -rf "$openssl_build"
    mkdir -p "$openssl_build"
    (
      cd "$openssl_build"
      "$CHECKOUT_PATH/openssl/Configure" "$openssl_target" \
        --prefix="$prefix" \
        --openssldir="$prefix" \
        no-shared no-tests no-apps no-docs \
        "$min_flag"
      make -j"$JOBS"
      make install_dev
    )
  fi

  cmake_configure "$CHECKOUT_PATH/libssh2" "$BUILD_PATH/$slice/libssh2" "$sdk" "$arch" "$prefix" \
    -DBUILD_STATIC_LIBS=ON \
    -DBUILD_EXAMPLES=OFF \
    -DBUILD_TESTING=OFF \
    -DENABLE_ZLIB_COMPRESSION=ON \
    -DCRYPTO_BACKEND=OpenSSL \
    -DOPENSSL_ROOT_DIR="$prefix" \
    -DOPENSSL_USE_STATIC_LIBS=ON
  cmake --build "$BUILD_PATH/$slice/libssh2" --target install -j "$JOBS"

  # regcomp_l, which CMake picks by default on Apple platforms, is marked
  # unavailable on iOS, so the PCRE bundled with libgit2 is used instead.
  cmake_configure "$CHECKOUT_PATH/libgit2" "$BUILD_PATH/$slice/libgit2" "$sdk" "$arch" "$prefix" \
    -DBUILD_TESTS=OFF \
    -DBUILD_CLI=OFF \
    -DBUILD_EXAMPLES=OFF \
    -DBUILD_FUZZERS=OFF \
    -DUSE_SSH=libssh2 \
    -DUSE_HTTPS=SecureTransport \
    -DUSE_ICONV=ON \
    -DREGEX_BACKEND=builtin \
    -DUSE_THREADS=ON
  cmake --build "$BUILD_PATH/$slice/libgit2" --target install -j "$JOBS"

  # One archive per slice, so that consumers only have to link a single library.
  libtool -static -o "$prefix/lib/libgit2_combined.a" \
    "$prefix/lib/libgit2.a" \
    "$prefix/lib/libssh2.a" \
    "$prefix/lib/libcrypto.a"
}

build_slice "ios-arm64" "iphoneos" "arm64" "ios64-xcrun"
build_slice "iossimulator-arm64" "iphonesimulator" "arm64" "iossimulator-arm64-xcrun"
build_slice "iossimulator-x86_64" "iphonesimulator" "x86_64" "iossimulator-x86_64-xcrun"

# The simulator slice of an xcframework holds both architectures in one archive.
SIMULATOR_LIBRARY="$BUILD_PATH/iossimulator/libgit2_combined.a"
mkdir -p "$(dirname "$SIMULATOR_LIBRARY")"
lipo -create \
  "$INSTALL_PATH/iossimulator-arm64/lib/libgit2_combined.a" \
  "$INSTALL_PATH/iossimulator-x86_64/lib/libgit2_combined.a" \
  -output "$SIMULATOR_LIBRARY"

# The headers are identical across slices, and the module map is what lets the
# library be imported from Swift.
rm -rf "$HEADER_PATH"
mkdir -p "$HEADER_PATH"
cp "$INSTALL_PATH/ios-arm64/include/git2.h" "$HEADER_PATH"
cp -R "$INSTALL_PATH/ios-arm64/include/git2" "$HEADER_PATH"
cat > "$HEADER_PATH/module.modulemap" <<'MODULEMAP'
module Libgit2 {
    header "git2.h"
    export *
}
MODULEMAP

rm -rf "$OUTPUT_PATH/libgit2.xcframework"
xcodebuild -create-xcframework \
  -library "$INSTALL_PATH/ios-arm64/lib/libgit2_combined.a" -headers "$HEADER_PATH" \
  -library "$SIMULATOR_LIBRARY" -headers "$HEADER_PATH" \
  -output "$OUTPUT_PATH/libgit2.xcframework"
