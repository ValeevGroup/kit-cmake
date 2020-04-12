############## Only usable on UNIX platforms
if (NOT UNIX)
  message(FATAL_ERROR "_gnu.cmake is only usable on UNIX platforms")
endif(NOT UNIX)

# on MacOS assume Brew
if (APPLE)
  if (DEFINED ENV{GCC_VERSION})
    if ("$ENV{GCC_VERSION}" AND EXISTS "/usr/local/bin/gcc-$ENV{GCC_VERSION}")
      set(_cmake_c_compiler /usr/local/bin/gcc-$ENV{GCC_VERSION})
    endif()
    if ("$ENV{GCC_VERSION}" AND EXISTS "/usr/local/bin/g++-$ENV{GCC_VERSION}")
      set(_cmake_cxx_compiler /usr/local/bin/g++-$ENV{GCC_VERSION})
    endif()
    if ("$ENV{GCC_VERSION}" AND EXISTS "/usr/local/bin/gfortran-$ENV{GCC_VERSION}")
      set(_cmake_fortran_compiler /usr/local/bin/gfortran-$ENV{GCC_VERSION})
    endif()
  else(DEFINED ENV{GCC_VERSION})
    if (EXISTS /usr/local/bin/gcc)
      set(_cmake_c_compiler /usr/local/bin/gcc)
    endif()
    if (EXISTS /usr/local/bin/g++)
      set(_cmake_cxx_compiler /usr/local/bin/g++)
    endif()
    if (EXISTS /usr/local/bin/gfortran)
      set(_cmake_cxx_compiler /usr/local/bin/gfortran)
    endif()
  endif(DEFINED ENV{GCC_VERSION})
endif(APPLE)
# if no special definition found, assume it's in PATH
if (NOT DEFINED _cmake_c_compiler)
  set(_cmake_c_compiler gcc)
endif(NOT DEFINED _cmake_c_compiler)
if (NOT DEFINED _cmake_cxx_compiler)
  set(_cmake_cxx_compiler g++)
endif(NOT DEFINED _cmake_cxx_compiler)
if (NOT DEFINED _cmake_fortran_compiler)
  set(_cmake_fortran_compiler gfortran)
endif(NOT DEFINED _cmake_fortran_compiler)

set(CMAKE_C_COMPILER "${_cmake_c_compiler}" CACHE STRING "C compiler")
set(CMAKE_CXX_COMPILER "${_cmake_cxx_compiler}" CACHE STRING "C++ compiler")
set(CMAKE_Fortran_COMPILER "${_cmake_fortran_compiler}" CACHE STRING "Fortran compiler")
