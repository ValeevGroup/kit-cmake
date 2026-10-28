# Tests for kit-cmake modules. Each test configures a small project in a fresh binary dir.
#   cmake -S tests -B build-tests && ctest --test-dir build-tests -L hermetic
cmake_minimum_required(VERSION 3.25)
project(kit_cmake_tests NONE)
enable_testing()

get_filename_component(KIT_DIR "${PROJECT_SOURCE_DIR}/.." ABSOLUTE)
set(CASES "${PROJECT_SOURCE_DIR}/boost/cases")
set(FAKES "${PROJECT_SOURCE_DIR}/boost/fake-prefixes")
# cases hide system/Homebrew/registry packages (after project(), see cases/isolate.cmake) so only the
# given prefix is visible; list-valued case arguments are comma-separated

# vgkit_boost_case(NAME n SOURCE dir LABEL l [PREFIX p] [BINARY b] [ARGS ...] REGEX re [FAIL_REGEX re] [DEPENDS t])
function(vgkit_boost_case)
  cmake_parse_arguments(C "" "NAME;SOURCE;LABEL;PREFIX;BINARY;REGEX;FAIL_REGEX;DEPENDS" "ARGS" ${ARGN})
  if (NOT C_BINARY)
    set(C_BINARY "${CMAKE_CURRENT_BINARY_DIR}/${C_NAME}")
  endif()
  set(_prefix)
  if (C_PREFIX)
    set(_prefix "-DCMAKE_PREFIX_PATH=${FAKES}/${C_PREFIX}")
  endif()
  string(REPLACE ";" "," _args "${C_ARGS}")
  add_test(NAME ${C_NAME}
           COMMAND ${CMAKE_COMMAND} -S ${CASES}/${C_SOURCE} -B ${C_BINARY}
                   -Dvg_cmake_kit_SOURCE_DIR=${KIT_DIR} ${_prefix} ${C_ARGS})
  set_tests_properties(${C_NAME} PROPERTIES LABELS ${C_LABEL} PASS_REGULAR_EXPRESSION "${C_REGEX}")
  # PASS_REGULAR_EXPRESSION ignores the exit code: cases expected to succeed must also not report errors
  if (C_REGEX MATCHES "RESULT")
    if (C_FAIL_REGEX)
      set(C_FAIL_REGEX "CMake Error|${C_FAIL_REGEX}")
    else()
      set(C_FAIL_REGEX "CMake Error")
    endif()
  endif()
  if (C_FAIL_REGEX)
    set_tests_properties(${C_NAME} PROPERTIES FAIL_REGULAR_EXPRESSION "${C_FAIL_REGEX}")
  endif()
  if (C_DEPENDS)
    set_tests_properties(${C_NAME} PROPERTIES DEPENDS ${C_DEPENDS})
  endif()
endfunction()

set(NOFETCH "FetchContent'ing Boost|Fetching Boost")

# --- found: pre-1.92 b2 install; header-only components get shim targets; no fetch
vgkit_boost_case(NAME found_b2 SOURCE generic LABEL hermetic PREFIX b2-1.83
  ARGS "-DCASE_REQUIRED=headers,container_hash,numeric_conversion,random" -DCASE_OPTIONAL=serialization
       -DCASE_FETCH=ON -DCASE_FLOOR=1.81 -DCASE_CHECK_SHIM=ON
  REGEX "RESULT built=OFF modular=ON version=1.83.0 targets=[^\n]*container_hash[^\n]*numeric_conversion[^\n]*random[^\n]*serialization.*CHECK shim OK"
  FAIL_REGEX "${NOFETCH}")
# second configure of the same binary dir gives the same result
vgkit_boost_case(NAME found_b2_reconfigure SOURCE generic LABEL hermetic PREFIX b2-1.83
  BINARY ${CMAKE_CURRENT_BINARY_DIR}/found_b2 DEPENDS found_b2
  ARGS "-DCASE_REQUIRED=headers,container_hash,numeric_conversion,random" -DCASE_OPTIONAL=serialization
       -DCASE_FETCH=ON -DCASE_FLOOR=1.81 -DCASE_CHECK_SHIM=ON
  REGEX "RESULT built=OFF modular=ON version=1.83.0 targets=[^\n]*container_hash.*CHECK shim OK"
  FAIL_REGEX "${NOFETCH}")
# installed consumer re-finds Boost from the snippet alone (no prefix given)
vgkit_boost_case(NAME found_b2_downstream SOURCE downstream LABEL hermetic DEPENDS found_b2
  ARGS -DCASE_SNIPPET=${CMAKE_CURRENT_BINARY_DIR}/found_b2/boost-snippet.cmake
       "-DCASE_TARGETS=headers,container_hash,numeric_conversion,random,serialization"
  REGEX "RESULT downstream=OK")
# fetch disabled, missing optional components are simply absent
vgkit_boost_case(NAME found_b2_optional_missing SOURCE generic LABEL hermetic PREFIX b2-1.83
  ARGS -DCASE_REQUIRED=headers "-DCASE_OPTIONAL=container_hash,iostreams" -DCASE_FETCH=OFF -DCASE_FLOOR=1.81
  REGEX "RESULT built=OFF modular=ON version=1.83.0 targets=headers;container_hash\n"
  FAIL_REGEX "lacks|${NOFETCH}")
# b2 install packaged without the compiled part of Boost.Container (e.g. Ubuntu without libboost-container-dev):
# its header-only part is usable, so Boost::container -> Boost::headers
vgkit_boost_case(NAME found_b2_container_headers SOURCE generic LABEL hermetic PREFIX b2-1.83
  ARGS "-DCASE_REQUIRED=headers,container" -DCASE_FETCH=OFF -DCASE_FLOOR=1.81
  REGEX "RESULT built=OFF modular=ON version=1.83.0 targets=headers;container\n")
# ... and an installed consumer re-finds that Boost (container is not asked of the b2 config as a required component)
vgkit_boost_case(NAME found_b2_container_downstream SOURCE downstream LABEL hermetic DEPENDS found_b2_container_headers
  ARGS -DCASE_SNIPPET=${CMAKE_CURRENT_BINARY_DIR}/found_b2_container_headers/boost-snippet.cmake
       "-DCASE_TARGETS=headers,container"
  REGEX "RESULT downstream=OK")
# ... but other missing compiled libraries of a b2 install are an error
vgkit_boost_case(NAME found_b2_compiled_missing SOURCE generic LABEL hermetic PREFIX b2-1.83
  ARGS "-DCASE_REQUIRED=headers,regex" -DCASE_FETCH=ON -DCASE_FLOOR=1.81
  REGEX "lacks[ \n]+required[ \n]+component\\(s\\)[ \n]+regex"
  FAIL_REGEX "${NOFETCH}")
# subproject asks for a target its parent's find_package imported as a dependency
vgkit_boost_case(NAME found_superbuild SOURCE found_superbuild LABEL hermetic PREFIX b2-1.83
  REGEX "RESULT sub built=OFF modular=ON version=1.83.0 targets=headers;container;serialization")
# CMake-harness install lacking a required component: error, never fetch
vgkit_boost_case(NAME found_cmake_incomplete SOURCE generic LABEL hermetic PREFIX cmake-incomplete-1.90
  ARGS "-DCASE_REQUIRED=headers,container_hash" -DCASE_FETCH=ON -DCASE_FLOOR=1.81
  REGEX "lacks[ \n]+required[ \n]+component\\(s\\)[ \n]+container_hash"
  FAIL_REGEX "${NOFETCH}")
# install made by the old kit (per-library configs only): error, never fetch
vgkit_boost_case(NAME found_oldkit SOURCE generic LABEL hermetic PREFIX oldkit-1.84
  ARGS "-DCASE_REQUIRED=headers,container_hash" -DCASE_FETCH=ON -DCASE_FLOOR=1.81
  REGEX "old[ \n]+kit-fetched[ \n]+Boost.*boost_headers-1\\.84\\.0.*remove"
  FAIL_REGEX "${NOFETCH}")
# b2 install older than the floor: plain "not found" (the old-kit probe must not misfire)
vgkit_boost_case(NAME found_too_old SOURCE generic LABEL hermetic PREFIX b2-1.80
  ARGS -DCASE_REQUIRED=headers -DCASE_FETCH=OFF -DCASE_FLOOR=1.81
  REGEX "Boost >= 1\\.81 not[ \n]+found"
  FAIL_REGEX "lacks|old kit")
# all components optional (TTG with TTG_FETCH_BOOST=OFF) and no Boost: continue without Boost
vgkit_boost_case(NAME notfound_all_optional SOURCE generic LABEL hermetic
  ARGS "-DCASE_OPTIONAL=callable_traits,serialization" -DCASE_FETCH=OFF -DCASE_FLOOR=1.81
  REGEX "RESULT built=OFF modular=OFF version= targets=\n")
vgkit_boost_case(NAME notfound_nofetch SOURCE generic LABEL hermetic
  ARGS -DCASE_REQUIRED=headers -DCASE_FETCH=OFF -DCASE_FLOOR=1.81
  REGEX "Boost >= 1\\.81 not[ \n]+found.*Boost_FETCH_IF_MISSING=ON")

# --- fetched (slow: downloads and builds Boost)
set(FB ${CMAKE_CURRENT_BINARY_DIR}/fetch_basic)
vgkit_boost_case(NAME fetch_basic SOURCE fetch_basic LABEL fetch
  REGEX "RESULT built=ON modular=ON version=1.92.0 targets=[^\n]*spirit")
add_test(NAME fetch_basic_build COMMAND ${CMAKE_COMMAND} --build ${FB} --config Release --parallel 6)
add_test(NAME fetch_basic_run COMMAND ${FB}/fofb_main)
add_test(NAME fetch_basic_install COMMAND ${CMAKE_COMMAND} --install ${FB} --config Release --prefix ${FB}/inst)
add_test(NAME fetch_basic_installed_files COMMAND ${CMAKE_COMMAND}
  "-DGLOBS=${FB}/inst/lib/cmake/Boost-1.92.0/BoostConfig.cmake,${FB}/inst/lib/*boost_filesystem*,${FB}/inst/lib/*boost_serialization*,${FB}/inst/lib/*boost_unit_test_framework*,${FB}/inst/lib/*boost_iostreams*,${FB}/inst/share/boost-1.92.0/assert/boost_assert.natvis"
  -P ${PROJECT_SOURCE_DIR}/boost/check_files.cmake)
set_tests_properties(fetch_basic_build fetch_basic_run fetch_basic_install fetch_basic_installed_files PROPERTIES LABELS fetch)
set_tests_properties(fetch_basic_build PROPERTIES DEPENDS fetch_basic)
set_tests_properties(fetch_basic_run fetch_basic_install PROPERTIES DEPENDS fetch_basic_build)
set_tests_properties(fetch_basic_installed_files PROPERTIES DEPENDS fetch_basic_install PASS_REGULAR_EXPRESSION "RESULT files=OK")
# installed consumer re-finds the installed Boost from the snippet
vgkit_boost_case(NAME fetch_downstream SOURCE downstream LABEL fetch DEPENDS fetch_basic_install
  ARGS -DCMAKE_PREFIX_PATH=${FB}/inst -DCASE_SNIPPET=${FB}/boost-snippet.cmake
       "-DCASE_TARGETS=headers,container_hash,spirit,unit_test_framework,iostreams"
  REGEX "RESULT downstream=OK")
vgkit_boost_case(NAME fetch_superbuild SOURCE fetch_superbuild LABEL fetch
  REGEX "RESULT top built=ON[^\n]*version=1.92.0.*RESULT sub built=ON[^\n]*random[^\n]*serialization[^\n]*unit_test_framework[^\n]*callable_traits"
  FAIL_REGEX "already")
vgkit_boost_case(NAME fetch_superbuild_reconfigure SOURCE fetch_superbuild LABEL fetch DEPENDS fetch_superbuild
  REGEX "RESULT sub built=ON[^\n]*callable_traits" FAIL_REGEX "already")
# libraries requested only by the subproject are built and installed too
set(FS ${CMAKE_CURRENT_BINARY_DIR}/fetch_superbuild)
# Boost's default install layout is "versioned" (headers in include/boost-1_92) on Windows, "system" elsewhere
if (WIN32)
  set(_boost_incdir include/boost-1_92)
else()
  set(_boost_incdir include)
endif()
add_test(NAME fetch_superbuild_build COMMAND ${CMAKE_COMMAND} --build ${FS} --config Release --parallel 6)
add_test(NAME fetch_superbuild_install COMMAND ${CMAKE_COMMAND} --install ${FS} --config Release --prefix ${FS}/inst)
add_test(NAME fetch_superbuild_installed_files COMMAND ${CMAKE_COMMAND}
  "-DGLOBS=${FS}/inst/lib/cmake/Boost-1.92.0/BoostConfig.cmake,${FS}/inst/lib/cmake/boost_callable_traits-1.92.0/*,${FS}/inst/lib/*boost_serialization*,${FS}/inst/lib/*boost_unit_test_framework*,${FS}/inst/${_boost_incdir}/boost/algorithm/string.hpp"
  -P ${PROJECT_SOURCE_DIR}/boost/check_files.cmake)
set_tests_properties(fetch_superbuild_build fetch_superbuild_install fetch_superbuild_installed_files PROPERTIES LABELS fetch)
set_tests_properties(fetch_superbuild_build PROPERTIES DEPENDS fetch_superbuild_reconfigure)
set_tests_properties(fetch_superbuild_install PROPERTIES DEPENDS fetch_superbuild_build)
set_tests_properties(fetch_superbuild_installed_files PROPERTIES DEPENDS fetch_superbuild_install PASS_REGULAR_EXPRESSION "RESULT files=OK")

# --- the Boost installed on this system (skipped if none); SYSTEM_BOOST_PREFIX points at a non-default location
set(_system_args)
if (SYSTEM_BOOST_PREFIX)
  set(_system_args -DCMAKE_PREFIX_PATH=${SYSTEM_BOOST_PREFIX})
endif()
vgkit_boost_case(NAME system_boost SOURCE system_boost LABEL system ARGS ${_system_args}
  REGEX "RESULT built=OFF modular=ON version=[0-9.]+ targets=[^\n]*container_hash[^\n]*numeric_conversion")
set_tests_properties(system_boost PROPERTIES SKIP_REGULAR_EXPRESSION "SKIP: no system Boost")
add_test(NAME system_boost_build COMMAND ${CMAKE_COMMAND} --build ${CMAKE_CURRENT_BINARY_DIR}/system_boost --config Release)
set_tests_properties(system_boost_build PROPERTIES LABELS system DEPENDS system_boost)

# shared Boost libraries: their installed configs also require their private (LINK_LIBRARIES) Boost dependencies
set(FSH ${CMAKE_CURRENT_BINARY_DIR}/fetch_shared)
vgkit_boost_case(NAME fetch_shared SOURCE fetch_basic LABEL fetch ARGS -DBUILD_SHARED_LIBS=ON
  REGEX "RESULT built=ON modular=ON version=1.92.0")
add_test(NAME fetch_shared_build COMMAND ${CMAKE_COMMAND} --build ${FSH} --config Release --parallel 6)
add_test(NAME fetch_shared_install COMMAND ${CMAKE_COMMAND} --install ${FSH} --config Release --prefix ${FSH}/inst)
set_tests_properties(fetch_shared_build fetch_shared_install PROPERTIES LABELS fetch)
set_tests_properties(fetch_shared_build PROPERTIES DEPENDS fetch_shared)
set_tests_properties(fetch_shared_install PROPERTIES DEPENDS fetch_shared_build)
vgkit_boost_case(NAME fetch_shared_downstream SOURCE downstream LABEL fetch DEPENDS fetch_shared_install
  ARGS -DCMAKE_PREFIX_PATH=${FSH}/inst -DCASE_SNIPPET=${FSH}/boost-snippet.cmake
       "-DCASE_TARGETS=headers,random,serialization,filesystem,iostreams"
  REGEX "RESULT downstream=OK")

# Boost fetched by a subproject while the top-level project never includes the module
vgkit_boost_case(NAME fetch_subdir_first SOURCE fetch_subdir_first LABEL fetch
  REGEX "RESULT sub built=ON modular=ON version=1.92.0")

# a Boost fetched and installed for one package lacks components a later package needs: fetch, do not error
vgkit_boost_case(NAME fetch_after_partial_install SOURCE generic LABEL fetch DEPENDS fetch_superbuild_install
  ARGS -DCMAKE_PREFIX_PATH=${FS}/inst "-DCASE_REQUIRED=headers,random,program_options" -DCASE_FETCH=ON -DCASE_FLOOR=1.81
  REGEX "RESULT built=ON modular=ON version=1.92.0 targets=headers;random;program_options"
  FAIL_REGEX "lacks")

# old kit-fetched Boost in the prefix this project installs into (rebuilding into the same prefix): warn and
# build Boost from source, the install supersedes it
vgkit_boost_case(NAME fetch_over_oldkit_in_install_prefix SOURCE generic LABEL fetch PREFIX oldkit-1.84
  ARGS -DCMAKE_INSTALL_PREFIX=${FAKES}/oldkit-1.84 "-DCASE_REQUIRED=headers,container_hash" -DCASE_FETCH=ON -DCASE_FLOOR=1.81
  REGEX "old kit-fetched Boost.*RESULT built=ON modular=ON version=1.92.0")
