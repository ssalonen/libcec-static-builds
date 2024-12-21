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



cd "$path"

# if /opt/toolchain.cmake exists, it is used for cmake cross-compilation
# cross-rs docker images have this
[ -f /opt/toolchain.cmake ] && toolchain_arg=( '-DCMAKE_TOOLCHAIN_FILE=/opt/toolchain.cmake' )

# first p8-platform
mkdir platform_build
PLATFORMBUILD=$(readlink -f platform_build)
cmake \
  -DCMAKE_INSTALL_PREFIX=platform_build \
  "${toolchain_arg:+$toolchain_arg}" \
  -S src/platform -B platform_build
# Build & install
env "p8-platform_ROOT=$PLATFORMBUILD" cmake --build platform_build --target install



# libcec next
libcec_define_args=()
[[ "$HAVE_LINUX_API" = "true" ]] && libcec_define_args+=( '-DHAVE_LINUX_API=1' )
libcec_define_args+=(  \
 -DSKIP_PYTHON_WRAPPER=1 \
 -D"p8-platform_ROOT=$PLATFORMBUILD" \
 -D"p8-platform_DIR=$PLATFORMBUILD/lib/p8-platform" \
 -D"p8-platform_INCLUDE_DIRS=$PLATFORMBUILD/include" \
 -D"p8-platform_LIBRARY=$PLATFORMBUILD/lib/libp8-platform.a" \
 -DCMAKE_VERBOSE_MAKEFILE=ON \
 -DCMAKE_INSTALL_PREFIX=build \
 -DHAVE_P8_USB=1 \
 -DHAVE_P8_USB_DETECT=1 \
 -DCMAKE_BUILD_TYPE=$cmake_build_type \
 -DCMAKE_CXX_STANDARD=11 \
 -Wno-dev )

echo "libcec_define_args: ${libcec_define_args[@]}"

cmake \
 "${libcec_define_args[@]}" \
 "${toolchain_arg:+$toolchain_arg}" \
 -S . -B build


env "p8-platform_ROOT=$PLATFORMBUILD" \
  cmake --build build --target install

ls -R platform_build

mkdir -p static-dist/include

find build -name 'libcec-static.a' -print -exec cp {} static-dist \;
find include -name '*.h' -print -exec cp --parents {} static-dist \;