#
# SPDX-FileCopyrightText: 2025 Eduard Valeyev <eduard@valeyev.net>
#
# SPDX-License-Identifier: BSD-2-Clause
#

include(CheckCXXSourceCompiles)
include(CMakePushCheckState)

# if TBB_FOUND is true will check for usable <execution> without TBB, then with TBB
macro(vgkit_check_cxx_execution_header _prefix)

  ##############################################
  # compilation checks
  ##############################################
  set(_prereq_list "_STANDALONE")
  if (TARGET TBB::tbb)
    list(APPEND _prereq_list _WITH_TBB)
  endif ()

  foreach (_prereq ${_prereq_list})
    cmake_push_check_state()

    if (_prereq STREQUAL _WITH_TBB)
      list(APPEND CMAKE_REQUIRED_LIBRARIES TBB::tbb)
    endif ()

    CHECK_CXX_SOURCE_COMPILES(
        "
  #include <algorithm>
  #include <vector>
  #include <execution>
  int main(int argc, char** argv) {
    std::vector<int> v{0,1,2};
    std::for_each(std::execution::par_unseq, begin(v), end(v),
                  [](auto&& i) {i *= 2;});
    return 0;
  }
  " ${_prefix}_HAS_EXECUTION_HEADER${_prereq})

    cmake_pop_check_state()
    if (${_prefix}_HAS_EXECUTION_HEADER${_prereq})
      break()
    endif ()

  endforeach (_prereq)

endmacro(vgkit_check_cxx_execution_header)

# Non-Apple Clang (e.g. Homebrew LLVM) may use its own libc++ headers
# but link against the system's older libc++.  This causes linker errors
# for symbols (like std::__1::__hash_memory) that exist in the newer headers
# but not the system library.  Detect the mismatch and, if possible, derive
# -L/-rpath flags pointing to the toolchain's own libc++.
#
# Usage:
#   vgkit_check_libcxx_linker_mismatch()                    # detect only, warn if mismatch found
#   vgkit_check_libcxx_linker_mismatch(MODIFY_GLOBAL_FLAGS) # detect and fix via global linker flags
#
# The MODIFY_GLOBAL_FLAGS option should only be used by the top-level project;
# subprojects and package configs should call without it and let the top-level
# project handle global linker state.
macro(vgkit_check_libcxx_linker_mismatch)

  set(_clmm_modify_global FALSE)
  foreach(_clmm_arg ${ARGN})
    if (_clmm_arg STREQUAL "MODIFY_GLOBAL_FLAGS")
      set(_clmm_modify_global TRUE)
    endif()
  endforeach()

  if (CMAKE_CXX_COMPILER_ID STREQUAL "Clang" AND
      NOT CMAKE_CXX_COMPILER_ID STREQUAL "AppleClang")
    cmake_push_check_state(RESET)
    check_cxx_source_compiles("
#include <unordered_map>
#include <string>
int main() { std::unordered_map<std::string,int> m; m[\"k\"]=1; return 0; }
" VGKIT_LIBCXX_LINKS_${PROJECT_NAME})
    cmake_pop_check_state()

    if (NOT VGKIT_LIBCXX_LINKS_${PROJECT_NAME})
      # Derive libc++ lib dir: -print-resource-dir gives <root>/lib/clang/<ver>
      execute_process(
        COMMAND ${CMAKE_CXX_COMPILER} -print-resource-dir
        OUTPUT_VARIABLE _clang_resource_dir OUTPUT_STRIP_TRAILING_WHITESPACE)
      cmake_path(GET _clang_resource_dir PARENT_PATH _clang_lib_dir)   # <root>/lib/clang
      cmake_path(GET _clang_lib_dir PARENT_PATH _clang_lib_dir)        # <root>/lib
      set(_clang_libcxx_dir "${_clang_lib_dir}/c++")

      if (EXISTS "${_clang_libcxx_dir}/libc++.dylib" OR
          EXISTS "${_clang_libcxx_dir}/libc++.so")
        cmake_push_check_state(RESET)
        set(CMAKE_REQUIRED_LINK_OPTIONS
          "-L${_clang_libcxx_dir}" "-Wl,-rpath,${_clang_libcxx_dir}")
        check_cxx_source_compiles("
#include <unordered_map>
#include <string>
int main() { std::unordered_map<std::string,int> m; m[\"k\"]=1; return 0; }
" VGKIT_LIBCXX_LINKS_WITH_FLAGS_${PROJECT_NAME})
        cmake_pop_check_state()

        if (VGKIT_LIBCXX_LINKS_WITH_FLAGS_${PROJECT_NAME})
          if (_clmm_modify_global)
            message(STATUS "libc++ linker mismatch detected; adding -L${_clang_libcxx_dir} to global linker flags")
            string(APPEND CMAKE_EXE_LINKER_FLAGS
              " -L${_clang_libcxx_dir} -Wl,-rpath,${_clang_libcxx_dir}")
            string(APPEND CMAKE_SHARED_LINKER_FLAGS
              " -L${_clang_libcxx_dir} -Wl,-rpath,${_clang_libcxx_dir}")
          else()
            message(WARNING
              "Clang's libc++ headers do not match the linked libc++ library. "
              "Call vgkit_check_libcxx_linker_mismatch(MODIFY_GLOBAL_FLAGS) from your "
              "top-level CMakeLists.txt, or manually add to "
              "CMAKE_EXE_LINKER_FLAGS / CMAKE_SHARED_LINKER_FLAGS:\n"
              "  -L${_clang_libcxx_dir} -Wl,-rpath,${_clang_libcxx_dir}")
          endif()
        else()
          message(FATAL_ERROR
            "Clang's libc++ headers do not match the linked libc++ library, "
            "and adding -L${_clang_libcxx_dir} did not help. "
            "Set CMAKE_EXE_LINKER_FLAGS and CMAKE_SHARED_LINKER_FLAGS to point "
            "to the matching libc++.")
        endif()
      else()
        message(FATAL_ERROR
          "Clang's libc++ headers do not match the linked libc++ library, "
          "and no libc++ was found in ${_clang_libcxx_dir}. "
          "Set CMAKE_EXE_LINKER_FLAGS and CMAKE_SHARED_LINKER_FLAGS to point "
          "to the matching libc++.")
      endif()
      unset(_clang_resource_dir)
      unset(_clang_lib_dir)
      unset(_clang_libcxx_dir)
    endif()
  endif()

  unset(_clmm_modify_global)

endmacro(vgkit_check_libcxx_linker_mismatch)

# P0522R0 (relaxed matching of template template arguments) is required by
# code that passes class templates with defaulted parameters (e.g.
# small_vector<T, N=...>) to template template parameters expecting fewer
# args (e.g. template <class> class Container).
#
# - GCC has supported this since GCC 7 (default in all C++17 modes)
# - LLVM Clang enabled it by default in Clang 19; earlier versions need
#   -frelaxed-template-template-args
# - AppleClang 17+ works; AppleClang 16 and earlier do not support it at all
#
# This macro tests whether P0522R0 works out of the box and, if not, tries
# adding -frelaxed-template-template-args.
#
# Sets VGKIT_P0522R0_COMPILE_FLAG in the caller's scope to the compile
# option needed (empty string if P0522R0 works natively).  The caller
# decides how to apply it (e.g. target_compile_options on specific targets).
# On failure, emits FATAL_ERROR.
macro(vgkit_check_p0522r0)

  set(VGKIT_P0522R0_COMPILE_FLAG)

  cmake_push_check_state(RESET)
  check_cxx_source_compiles("
template <class T, int N = 10> struct SmallVec {};
template <template <class> class C> void f() { C<int> v; }
int main() { f<SmallVec>(); return 0; }
" VGKIT_CXX_HAS_P0522R0)
  cmake_pop_check_state()

  if (NOT VGKIT_CXX_HAS_P0522R0)
    cmake_push_check_state(RESET)
    set(CMAKE_REQUIRED_FLAGS "-frelaxed-template-template-args")
    check_cxx_source_compiles("
template <class T, int N = 10> struct SmallVec {};
template <template <class> class C> void f() { C<int> v; }
int main() { f<SmallVec>(); return 0; }
" VGKIT_CXX_HAS_P0522R0_WITH_FLAG)
    cmake_pop_check_state()

    if (VGKIT_CXX_HAS_P0522R0_WITH_FLAG)
      set(VGKIT_P0522R0_COMPILE_FLAG "-frelaxed-template-template-args")
      message(STATUS "P0522R0 requires -frelaxed-template-template-args")
    else()
      message(FATAL_ERROR
        "Compiler does not support P0522R0 (relaxed template template argument matching), "
        "even with -frelaxed-template-template-args. Use a newer compiler "
        "(GCC >= 7, Clang >= 19, or AppleClang >= 17).")
    endif()
  endif()

endmacro(vgkit_check_p0522r0)