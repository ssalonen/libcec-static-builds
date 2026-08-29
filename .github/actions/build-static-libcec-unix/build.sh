#! /usr/bin/env bash

set -exo pipefail

path="$1"
build_type="$2"

case "$build_type" in
  debug) cmake_build_type=Debug ;;
  release) cmake_build_type=RelWithDebInfo ;;
  *) echo "invalid build type: $build_type" >&2; exit 1 ;;
esac

cd "$path"

toolchain_args=()
if [ -f /opt/toolchain.cmake ]; then
  toolchain_args+=(-DCMAKE_TOOLCHAIN_FILE=/opt/toolchain.cmake)
fi

# libCEC 8 builds either a static or a shared library per CMake build tree.
# Use isolated build/install prefixes so each release archive contains the
# intended library kind rather than merely headers.
common_args=(
  "${toolchain_args[@]}"
  -DCMAKE_BUILD_TYPE="$cmake_build_type"
  -DDISABLE_CLIENT=ON
  -DSKIP_PYTHON_WRAPPER=1
  -DDISABLE_BUILDINFO=ON
  -DHAVE_LINUX_API="${HAVE_LINUX_API:-0}"
)

cmake -S . -B static-build \
  "${common_args[@]}" \
  -DBUILD_SHARED_LIBS=OFF \
  -DCMAKE_INSTALL_PREFIX="$PWD/static-install"
cmake --build static-build --parallel
cmake --install static-build

cmake -S . -B dynamic-build \
  "${common_args[@]}" \
  -DBUILD_SHARED_LIBS=ON \
  -DCMAKE_INSTALL_PREFIX="$PWD/dynamic-install"
cmake --build dynamic-build --parallel
cmake --install dynamic-build

mkdir -p static-dist/include dynamic-dist/include
find static-install -type f -name '*.a' -print -exec cp {} static-dist/ \;
find dynamic-install -type f \( -name '*.so' -o -name '*.so.*' -o -name '*.dylib' \) -print -exec cp {} dynamic-dist/ \;
# Preserve the linker-facing unversioned name (e.g. libcec.so) as a regular
# file, so consumers can pass LIBCEC_LIB_DIR directly to -lcec.
find dynamic-install/lib -maxdepth 1 -type l \( -name '*.so*' -o -name '*.dylib' \) -print -exec cp -L {} dynamic-dist/ \;
cp -a static-install/include/. static-dist/include/
cp -a dynamic-install/include/. dynamic-dist/include/

test -n "$(find static-dist -maxdepth 1 -type f -name '*.a' -print -quit)"
test -n "$(find dynamic-dist -maxdepth 1 -type f \( -name '*.so' -o -name '*.so.*' -o -name '*.dylib' \) -print -quit)"
