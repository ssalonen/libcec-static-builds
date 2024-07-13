cmake_minimum_required(VERSION 3.29)
project(p8-platform
  VERSION 2.1.1
  DESCRIPTION "Pulse-Eight platform support library"
  LANGUAGES CXX
)

set(CMAKE_MODULE_PATH ${CMAKE_MODULE_PATH} ${PROJECT_SOURCE_DIR})

find_package(Threads REQUIRED)
include(UseMultiArch.cmake)
include(CheckAtomic.cmake)
set(CMAKE_POSITION_INDEPENDENT_CODE on)

if(WIN32)
  set(PLAT_SOURCES src/windows/dlfcn-win32.cpp
    src/windows/os-threads.cpp)
endif()

add_library(p8-platform)
target_include_directories(p8-platform PUBLIC ${CMAKE_CURRENT_SOURCE_DIR} PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/src)
target_sources(p8-platform PRIVATE src/util/StringUtils.cpp ${PLAT_SOURCES})
target_compile_options(p8-platform PRIVATE "-w")

function(add_framework target scope framework)
  find_library(${framework}_FRAMEWORK ${framework})

  if("${framework}_FRAMEWORK" STREQUAL "")
    message(FATAL_ERROR "can't find ${framework} framework")
  else()
    message(STATUS "found ${framework} framework: ${${framework}_FRAMEWORK}")
  endif()

  target_link_libraries(${target} ${scope} ${${framework}_FRAMEWORK})
endfunction()

if(${CMAKE_SYSTEM_NAME} MATCHES "Darwin")
  add_framework(p8-platform PRIVATE Foundation)
  add_framework(p8-platform PRIVATE CoreVideo)
  add_framework(p8-platform PRIVATE IoKit)
endif()

set_target_properties(p8-platform
  PROPERTIES
  VERSION ${p8-platform_VERSION_MAJOR}.${p8-platform_VERSION_MINOR}.${p8-platform_VERSION_PATCH}
  SOVERSION ${p8-platform_VERSION_MAJOR})

if(WIN32)
  if(MSVC)
    # generate pdb in release mode too
    set_target_properties(p8-platform
      PROPERTIES
      COMPILE_PDB_NAME_DEBUG p8-platform${CMAKE_DEBUG_POSTFIX}
      COMPILE_PDB_NAME_RELEASE p8-platform
      COMPILE_PDB_NAME_MINSIZEREL p8-platform
      COMPILE_PDB_NAME_RELWITHDEBINFO p8-platform)

    if(${WIN64})
      # default setting that got removed in recent vs versions, generates a warning if set
      string(REPLACE "/arch:SSE2" "" CMAKE_CXX_FLAGS ${CMAKE_CXX_FLAGS})
    endif(${WIN64})
  endif(MSVC)

  if(NOT ${WIN64})
    add_definitions(-D_USE_32BIT_TIME_T)
  endif(NOT ${WIN64})
endif(WIN32)

install(TARGETS p8-platform DESTINATION ${CMAKE_INSTALL_LIBDIR})
install(FILES src/os.h DESTINATION include/p8-platform)

if(WIN32)
  install(FILES src/windows/dlfcn-win32.h
    src/windows/os-socket.h
    src/windows/os-threads.h
    src/windows/os-types.h
    DESTINATION include/p8-platform/windows)
else(WIN32)
  install(FILES src/posix/os-socket.h
    src/posix/os-threads.h
    src/posix/os-types.h
    DESTINATION include/p8-platform/posix)
endif(WIN32)

install(FILES src/sockets/cdevsocket.h
  src/sockets/socket.h
  src/sockets/tcp.h
  DESTINATION include/p8-platform/sockets)
install(FILES src/threads/atomics.h
  src/threads/mutex.h
  src/threads/threads.h
  DESTINATION include/p8-platform/threads)
install(FILES src/util/atomic.h
  src/util/buffer.h
  src/util/StringUtils.h
  src/util/StdString.h
  src/util/timeutils.h
  src/util/util.h
  DESTINATION include/p8-platform/util)

if(MSVC)
  # install generated pdb
  install(FILES $<TARGET_FILE_DIR:p8-platform>/p8-platform.pdb
    DESTINATION "${CMAKE_INSTALL_LIBDIR}")
endif(MSVC)

if(NOT WIN32)
  configure_file(p8-platform.pc.in p8-platform.pc @ONLY)
  install(FILES ${CMAKE_BINARY_DIR}/p8-platform.pc
    DESTINATION ${CMAKE_INSTALL_LIBDIR}/pkgconfig)
endif(NOT WIN32)

# config mode
configure_file(p8-platform-config.cmake.in
  p8-platform-config.cmake @ONLY)
install(FILES ${CMAKE_BINARY_DIR}/p8-platform-config.cmake
  DESTINATION ${CMAKE_INSTALL_LIBDIR}/p8-platform)
