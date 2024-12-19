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
[[ "$HAVE_LINUX_API" = "true" ]] && args+=( '-DHAVE_LINUX_API=1' )
args+=( "-DHAVE_P8_USB=1" "-DHAVE_P8_USB_DETECT=1" "-D" "CMAKE_BUILD_TYPE=$cmake_build_type" "-D" "BUILD_STATIC_LIB=True" "-D" "CMAKE_CXX_STANDARD=11" "-Wno-dev" )
echo "${args[@]}"

cd "$path"
# generate "build system" and then build

# first for platform
mkdir platform_build
PLATFORMBUILD=$(readlink -f platform_build)
cmake -DCMAKE_INSTALL_PREFIX=platform_build -S src/platform -B platform_build
# Also install
env "p8-platform_ROOT=$PLATFORMBUILD" cmake --build platform_build --target install

# same for libcec
cmake --trace \
 -D"SKIP_PYTHON_WRAPPER=1" \
 -D"p8-platform_ROOT=$PLATFORMBUILD" \
 -D"p8-platform_DIR=$PLATFORMBUILD/build" \
 -D"p8-platform_INCLUDE_DIRS=$PLATFORMBUILD/include" \
 -D"p8-platform_LIBRARY=$PLATFORMBUILD/libp8-platform.a" \
 -DCMAKE_VERBOSE_MAKEFILE=ON -DCMAKE_INSTALL_PREFIX=build "${args[@]}" \
 -S . -B build


mkdir -p dist/include

env "p8-platform_ROOT=$PLATFORMBUILD" \
  cmake --build build --target install
 

find build \( -name '*.a' -o -name '*.so' -o -name '*.dylib' \) -print -exec cp {} dist \;
find include -name '*.h' -print -exec cp --parents {} dist \;