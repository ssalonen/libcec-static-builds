project(libcec)
cmake_minimum_required(VERSION 3.12.0)

set(LIBCEC_VERSION_MAJOR 6)
set(LIBCEC_VERSION_MINOR 0)
set(LIBCEC_VERSION_PATCH 2)

# libCEC
add_subdirectory(src/libcec)

# version number
configure_file(${CMAKE_CURRENT_SOURCE_DIR}/include/version.h.in
               ${CMAKE_CURRENT_SOURCE_DIR}/include/version.h)

