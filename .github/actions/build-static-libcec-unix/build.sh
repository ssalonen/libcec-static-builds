#! /usr/bin/env bash

set -euxo pipefail

path="$1"
build_type="$2"

case "$build_type" in
  'debug')
    cmake_build_type='Debug'
    ;;

  'release')
    cmake_build_type='RelWithDebInfo'
    ;;

  *)
    echo "invalid build type"
    exit 1
    ;;
esac

# from https://stackoverflow.com/questions/28678505/add-command-arguments-using-inline-if-statement-in-bash
args=()
[[ "$HAVE_LINUX_API" == "true" ]] && args+=( '-DHAVE_LINUX_API=1' )
args+=( "-DHAVE_P8_USB=1" "-DHAVE_P8_USB_DETECT=1" "-D" "CMAKE_BUILD_TYPE=$cmake_build_type" "-D" "BUILD_STATIC_LIB=True" "-D" "CMAKE_CXX_STANDARD=11" "-Wno-dev" )
echo "${args[@]}"

cd "$path"
# generate "build system" and then build
# first for platform
mkdir platform_build
cmake -S src/platform -B platform_build "${args[@]}"
env 'p8-platform_ROOT=./platform_build' cmake --build platform_build
# same for all
env 'p8-platform_ROOT=./platform_build' 'p8-platform_DIR=./platform_build/build' 'p8-platform_INCLUDE_DIRS=./platform_build/include' 'p8-platform_LIBRARY=./platform_build/build/libp8-platform.a' cmake -S . -B build "${args[@]}"
env 'p8-platform_ROOT=./platform_build' 'p8-platform_DIR=./platform_build/build' 'p8-platform_INCLUDE_DIRS=./platform_build/include' 'p8-platform_LIBRARY=./platform_build/build/libp8-platform.a' cmake --build build

mkdir -p dist/include
ls -R build
find build \( -name '*.a' -o -name '*.so' -o -name '*.dylib' \) -print -exec cp {} dist \;
find include -name '*.h' -print -exec cp --parents {} dist \;