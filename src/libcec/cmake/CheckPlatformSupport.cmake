# - Check for platform support and set variables and definitions
#
# This module sets the following variables
#       PLATFORM_LIBREQUIRES      dependencies
#       LIB_INFO                  supported features and compilation information
#       LIB_DESTINATION           destination for the .so/.dll files
#       HAVE_P8_USB               ON if Pulse-Eight devices are supported
#       HAVE_P8_USB_DETECT        ON if Pulse-Eight devices can be auto-detected
#
# The following variables are set automatically, if not defined by user
#       HAVE_DRM_EDID_PARSER      ON if DRM EDID parsing is supported, otherwise OFF
#       HAVE_LIBUDEV              ON if udev is supported, otherwise OFF
#       HAVE_RANDR                ON if xrandr is supported, otherwise OFF
#       HAVE_RPI_API              ON if Raspberry Pi is supported, otherwise OFF
#
# The following variables must be defined to enable suppport for various features
#       HAVE_TDA995X_API          ON to enable NXP TDA995x support
#       HAVE_EXYNOS_API           ON to enable Exynos SoC support
#       HAVE_LINUX_API            ON to enable Linux kernel CEC framework support
#       HAVE_AOCEC_API            ON to enable AOCEC (Odroid C2/Amlogic S905) SoC support
#       HAVE_IMX_API              ON to enable iMX.6 SoC support
#       RPI_INCLUDE_DIR           PATH to Raspberry Pi includes
#       RPI_LIB_DIR               PATH to Raspberry Pi libs
#       HAVE_TEGRA_API            ON if Tegra is supported
#

set(PLATFORM_LIBREQUIRES "")

include(CheckFunctionExists)
include(CheckSymbolExists)
include(FindPkgConfig)

# defaults
# Pulse-Eight devices are always supported
set(HAVE_P8_USB          ON  CACHE BOOL "p8 usb-cec supported" FORCE)
# Raspberry Pi libs and headers are in a non-standard path on some distributions
set(RPI_INCLUDE_DIR      ""  CACHE FILEPATH "path to Raspberry Pi includes")
set(RPI_LIB_DIR          ""  CACHE FILEPATH "path to Raspberry Pi libs")

if(WIN32)
  # Windows
  add_definitions(-DTARGET_WINDOWS -DNOMINMAX -D_CRT_SECURE_NO_WARNINGS -D_WINSOCKAPI_)
  set(LIB_DESTINATION ".")

  set(CMAKE_MSVC_RUNTIME_LIBRARY "MultiThreaded$<$<CONFIG:Debug>:Debug>DLL")

  if("${MSVC_C_ARCHITECTURE_ID}" STREQUAL "X86")
    set(LIB_INFO "${LIB_INFO} (x86)")
    add_definitions(-D_USE_32BIT_TIME_T)
    # force python2 for eventghost
    set(PYTHON_USE_VERSION 2)
  elseif("${MSVC_C_ARCHITECTURE_ID}" STREQUAL "x64")
    check_symbol_exists(_X64_ Windows.h WIN64)
    check_symbol_exists(_AMD64_ Windows.h AMD64)
    if (DEFINED WIN64 OR DEFINED AMD64)
      set(LIB_INFO "${LIB_INFO} (x64)")
    endif()
  elseif("${MSVC_C_ARCHITECTURE_ID}" STREQUAL "ARM")
    set(LIB_INFO "${LIB_INFO} (arm)")
  elseif("${MSVC_C_ARCHITECTURE_ID}" STREQUAL "ARM64")
    set(LIB_INFO "${LIB_INFO} (arm64)")    
  else()
    message(FATAL_ERROR "Unknown architecture id: ${MSVC_C_ARCHITECTURE_ID}")
  endif()

  set(HAVE_P8_USB_DETECT ON CACHE INTERNAL "p8 usb-cec detection supported")

  list(APPEND CEC_SOURCES_PLATFORM platform/windows/os-edid.cpp
                                   platform/windows/serialport.cpp)
  list(APPEND CEC_SOURCES LibCECDll.cpp
                          libcec.rc)
else()
  # not Windows
  set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -Wall -Wextra -Wno-missing-field-initializers -Wno-deprecated-copy")
  list(APPEND CEC_SOURCES_PLATFORM platform/posix/os-edid.cpp
                                   platform/posix/serialport.cpp)
  set(LIB_DESTINATION "${CMAKE_INSTALL_LIBDIR}")

  # always try DRM on Linux if other methods fail
  if(NOT CMAKE_SYSTEM_NAME MATCHES "FreeBSD")
    set(HAVE_DRM_EDID_PARSER ON CACHE BOOL "drm edid parser supported")
  endif()

  # flock
  check_include_files(sys/file.h HAVE_SYS_FILE_HEADER)
  check_function_exists(flock HAVE_FLOCK)

  # udev
  # IMPORTED_TARGET can deal with custom directories (e.g. arch specific library location)
  # Will define PkgConfig::UDEV variables
  # https://stackoverflow.com/a/57224542
  pkg_check_modules(UDEV IMPORTED_TARGET udev)
  if (UDEV_FOUND)
    set(PLATFORM_LIBREQUIRES "${PLATFORM_LIBREQUIRES} ${UDEV_LIBRARIES}")
  else()
    # fall back to finding libudev.pc
    pkg_check_modules(UDEV IMPORTED_TARGET libudev)
    if (UDEV_FOUND)
      set(PLATFORM_LIBREQUIRES "${PLATFORM_LIBREQUIRES} ${UDEV_LIBRARIES}")
      list(APPEND CMAKE_REQUIRED_LIBRARIES "${UDEV_LIBRARIES}")
    else()
      # fall back to finding libudev.pc
      pkg_check_modules(UDEV libudev)
      if (UDEV_FOUND)
        set(PLATFORM_LIBREQUIRES "${PLATFORM_LIBREQUIRES} libudev")
        list(APPEND CMAKE_REQUIRED_LIBRARIES "libudev")
      endif()
    endif()
  endif()

  # xrandr
  if(NOT DEFINED HAVE_RANDR OR HAVE_RANDR)
    check_include_files("X11/Xlib.h;X11/Xatom.h;X11/extensions/Xrandr.h" HAVE_RANDR_HEADERS)
    check_library_exists(Xrandr XRRGetScreenResources "" HAVE_RANDR_LIB)
    if (HAVE_RANDR_HEADERS AND HAVE_RANDR_LIB)
      list(APPEND CEC_SOURCES_PLATFORM platform/X11/randr-edid.cpp)
    endif()
  endif()

  # raspberry pi
  if(NOT DEFINED HAVE_RPI_API OR HAVE_RPI_API)
    find_library(RPI_BCM_HOST bcm_host "${RPI_LIB_DIR}")
    check_library_exists(bcm_host bcm_host_init "${RPI_LIB_DIR}" HAVE_RPI_LIB)
    if (HAVE_RPI_LIB)
      SET(HAVE_RPI_API ON CACHE BOOL "raspberry pi supported" FORCE)
      find_library(RPI_VCOS vcos "${RPI_LIB_DIR}")
      find_library(RPI_VCHIQ_ARM vchiq_arm "${RPI_LIB_DIR}")
      include_directories(${RPI_INCLUDE_DIR} ${RPI_INCLUDE_DIR}/interface/vcos/pthreads ${RPI_INCLUDE_DIR}/interface/vmcs_host/linux)

      set(CEC_SOURCES_ADAPTER_RPI adapter/RPi/RPiCECAdapterDetection.cpp
                                  adapter/RPi/RPiCECAdapterCommunication.cpp
                                  adapter/RPi/RPiCECAdapterMessageQueue.cpp)
      source_group("Source Files\\adapter\\RPi" FILES ${CEC_SOURCES_ADAPTER_RPI})
      list(APPEND CEC_SOURCES ${CEC_SOURCES_ADAPTER_RPI})
    endif()
  endif()

  # TDA995x
  if(NOT DEFINED HAVE_TDA995X_API OR HAVE_TDA995X_API)
    check_include_files("tda998x_ioctl.h;comps/tmdlHdmiCEC/inc/tmdlHdmiCEC_Types.h" HAVE_TDA995X_API_INC)
    if (HAVE_TDA995X_API_INC)
      set(CEC_SOURCES_ADAPTER_TDA995x adapter/TDA995x/TDA995xCECAdapterDetection.cpp
                                      adapter/TDA995x/TDA995xCECAdapterCommunication.cpp)
      source_group("Source Files\\adapter\\TDA995x" FILES ${CEC_SOURCES_ADAPTER_TDA995x})
      list(APPEND CEC_SOURCES ${CEC_SOURCES_ADAPTER_TDA995x})
    endif()
  endif()

  # Exynos
  if (HAVE_EXYNOS_API)
    set(CEC_SOURCES_ADAPTER_EXYNOS adapter/Exynos/ExynosCECAdapterDetection.cpp
                                   adapter/Exynos/ExynosCECAdapterCommunication.cpp)
    source_group("Source Files\\adapter\\Exynos" FILES ${CEC_SOURCES_ADAPTER_EXYNOS})
    list(APPEND CEC_SOURCES ${CEC_SOURCES_ADAPTER_EXYNOS})
  endif()

  # Linux
  if (HAVE_LINUX_API)
    set(CEC_SOURCES_ADAPTER_LINUX adapter/Linux/LinuxCECAdapterDetection.cpp
                                  adapter/Linux/LinuxCECAdapterCommunication.cpp)
    source_group("Source Files\\adapter\\Linux" FILES ${CEC_SOURCES_ADAPTER_LINUX})
    list(APPEND CEC_SOURCES ${CEC_SOURCES_ADAPTER_LINUX})
  endif()

  # Tegra
  if (HAVE_TEGRA_API)
    set(CEC_SOURCES_ADAPTER_TEGRA adapter/Tegra/TegraCECAdapterDetection.cpp
                                  adapter/Tegra/TegraCECAdapterCommunication.cpp)
    source_group("Source Files\\adapter\\Tegra" FILES ${CEC_SOURCES_ADAPTER_TEGRA})
    list(APPEND CEC_SOURCES ${CEC_SOURCES_ADAPTER_TEGRA})
  endif()

  # AOCEC
  if (HAVE_AOCEC_API)
    set(CEC_SOURCES_ADAPTER_AOCEC adapter/AOCEC/AOCECAdapterDetection.cpp
                                   adapter/AOCEC/AOCECAdapterCommunication.cpp)
    source_group("Source Files\\adapter\\AOCEC" FILES ${CEC_SOURCES_ADAPTER_AOCEC})
    list(APPEND CEC_SOURCES ${CEC_SOURCES_ADAPTER_AOCEC})
  endif()

  # i.MX6
  if (HAVE_IMX_API)
    set(CEC_SOURCES_ADAPTER_IMX adapter/IMX/IMXCECAdapterCommunication.cpp
                                adapter/IMX/IMXCECAdapterDetection.cpp)
    source_group("Source Files\\adapter\\IMX" FILES ${CEC_SOURCES_ADAPTER_IMX})
    list(APPEND CEC_SOURCES ${CEC_SOURCES_ADAPTER_IMX})
  endif()
endif()

# rt
check_library_exists(rt clock_gettime "" HAVE_RT)

# check for dlopen
check_library_exists(dl dlopen "" HAVE_DLOPEN)

set(LIB_INFO "${LIB_INFO}, features: P8_USB")

if (HAVE_DRM_EDID_PARSER)
  set(LIB_INFO "${LIB_INFO}, DRM")
else()
  set(HAVE_DRM_EDID_PARSER OFF CACHE BOOL "DRM EDID parser supported")
endif()

if (UDEV_FOUND)
  SET(HAVE_LIBUDEV ON CACHE BOOL "udev supported")
  set(HAVE_P8_USB_DETECT ON CACHE INTERNAL "p8 USB-CEC detection supported")
elseif (HAVE_LIBUDEV)
  message(FATAL_ERROR "udev library not found")
else()
  SET(HAVE_LIBUDEV OFF CACHE BOOL "udev supported")
endif()

if (CMAKE_SYSTEM_NAME STREQUAL "Linux")
  set(HAVE_P8_USB_DETECT ON CACHE INTERNAL "p8 USB-CEC detection supported")
elseif (NOT DEFINED HAVE_P8_USB_DETECT)
  set(HAVE_P8_USB_DETECT OFF CACHE INTERNAL "p8 USB-CEC detection supported")
endif()

if (HAVE_P8_USB_DETECT)
  set(LIB_INFO "${LIB_INFO}, P8_detect")
endif()

if (HAVE_RANDR_HEADERS AND HAVE_RANDR_LIB)
  SET(HAVE_RANDR ON CACHE BOOL "xrandr supported")
  set(LIB_INFO "${LIB_INFO}, randr")
elseif (HAVE_RANDR)
  message(FATAL_ERROR "randr headers or library not found")
else()
  SET(HAVE_RANDR OFF CACHE BOOL "xrandr supported")
endif()

if (HAVE_RPI_LIB)
  SET(HAVE_RPI_API ON CACHE BOOL "Raspberry Pi supported")
  set(LIB_INFO "${LIB_INFO}, RPi")
elseif (HAVE_RPI_API)
  message(FATAL_ERROR "Raspberry Pi library not found")
else()
  SET(HAVE_RPI_API OFF CACHE BOOL "Raspberry Pi supported")
endif()

if (HAVE_TDA995X_API_INC)
  SET(HAVE_TDA995X_API ON CACHE BOOL "NXP TDA995x supported")
  set(LIB_INFO "${LIB_INFO}, TDA995x")
elseif (HAVE_TDA995X_API)
  message(FATAL_ERROR "tda995x headers not found")
else()
  SET(HAVE_TDA995X_API OFF CACHE BOOL "TDA995x supported")
endif()

if (HAVE_EXYNOS_API)
  set(LIB_INFO "${LIB_INFO}, Exynos")
else()
  SET(HAVE_EXYNOS_API OFF CACHE BOOL "Exynos supported")
endif()

if (HAVE_LINUX_API)
  set(LIB_INFO "${LIB_INFO}, Linux_kernel_API")
else()
  SET(HAVE_LINUX_API OFF CACHE BOOL "Linux kernel CEC framework supported")
endif()

if (HAVE_AOCEC_API)
  set(LIB_INFO "${LIB_INFO}, AOCEC")
else()
  SET(HAVE_AOCEC_API OFF CACHE BOOL "AOCEC (Odroid C2/Amlogic S905) SoC supported")
endif()

if (HAVE_IMX_API)
  set(LIB_INFO "${LIB_INFO}, 'i.MX6'")
else()
  SET(HAVE_IMX_API OFF CACHE BOOL "i.MX6 SoC supported")
endif()

if (HAVE_TEGRA_API)
  set(LIB_INFO "${LIB_INFO}, Tegra")
else()
  SET(HAVE_EXYNOS_API OFF CACHE BOOL "Tegra supported")
endif()

SET(SKIP_PYTHON_WRAPPER 0 CACHE STRING "Define to 1 to not generate the Python wrapper")

message(STATUS "Not generating Python wrapper")
