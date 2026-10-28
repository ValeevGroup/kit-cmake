# -*- mode: cmake -*-

# FindOrFetchBoost: imports Boost >= Boost_OLDEST_BOOST_VERSION via its CMake config package (BoostConfig.cmake),
# or, if no Boost is found and Boost_FETCH_IF_MISSING is ON, builds Boost from source via FetchContent.
#
# definitions:
# - "component": name of a Boost library as given in Boost_{REQUIRED,OPTIONAL}_COMPONENTS, e.g. container_hash;
#   component X corresponds to target Boost::X, except component "test" <-> target Boost::unit_test_framework
# - Boost installs come in two flavors:
#   - built by b2: defines Boost::headers (all header-only libraries) and one target per compiled library;
#     before 1.92 such BoostConfig.cmake rejects header-only components, so for those this module defines
#     Boost::X as an alias-like INTERFACE target linking Boost::headers (what 1.92+ b2 configs do natively)
#   - built by the Boost CMake harness (vcpkg, a Boost fetched and installed by this module): one CMake package
#     boost_X per library, header-only or not
#
# input variables:
# Boost_REQUIRED_COMPONENTS: list of required components
# Boost_OPTIONAL_COMPONENTS: list of optional components
# Boost_OLDEST_BOOST_VERSION: oldest acceptable version of a found Boost
# Boost_FETCH_IF_MISSING: if ON, will download and build Boost if it is not found
# BOOST_EXCLUDE_LIBRARIES: libraries not to configure when building Boost from source
#
# hints:
# Boost_ROOT (or BOOST_ROOT): preferred installation prefix
# BOOST_INCLUDEDIR: preferred include directory, e.g. <prefix>/include; used as Boost_ROOT=<prefix> if Boost_ROOT not given
#
# errors (never fall back to fetching in these cases):
# - a Boost was found but lacks some of Boost_REQUIRED_COMPONENTS
# - only an install of Boost built by an older version of this module (per-library boost_X configs, no
#   BoostConfig.cmake) was found; it must be reinstalled
#
# output variables:
# Boost_BUILT_FROM_SOURCE: ON if Boost was built from source
# Boost_USE_CONFIG: ON if Boost was found (always via its config file)
# Boost_CONFIG: if Boost_USE_CONFIG is ON, the config file used
# Boost_IS_MODULARIZED: ON; target Boost::X exists for every found component X
# Boost_FOUND_COMPONENTS: list of components that were found
# Boost_FOUND_TARGETS: list of targets (X in Boost::X) that were found
# Boost_MODULAR_TARGETS_NOT_BUILT_BY_INSTALL: CACHE variable, now always empty (all installed Boost libraries are
#   built by the default target); kept for compatibility
# Boost_CONFIG_FILE_CONTENTS: CMake code to paste into the package config file of the project, imports the same Boost

set(vgkit_boost_fetch_version 1.92.0)
set(vgkit_boost_fetch_sha256 9bed76128d4e46755dbe818487788c6fceb6f72b378f4daa49b7e1e600d9088d)

# kept for compatibility; the installed Boost targets are now built by the default target
set(Boost_MODULAR_TARGETS_NOT_BUILT_BY_INSTALL "" CACHE STRING "list of Boost targets not built by install target" FORCE)

# converts component _comp to list of targets defined by the component
# target name x means TARGET Boost::x is defined
macro(component_to_targets _comp _targets)
    if (${${_comp}} STREQUAL test)
        set(${_targets} unit_test_framework)
    else()
        set(${_targets} ${${_comp}})
    endif()
endmacro()

# helpers used here and by the code in Boost_CONFIG_FILE_CONTENTS
set(_vgkit_boost_helpers [=[
# components that are compiled libraries in some Boost >= 1.81 built by b2, i.e. can be passed to b2's
# BoostConfig.cmake; all other components are header-only (cf. __boost_hdronly_libraries in boost_install's
# BoostConfig.cmake, Boost 1.92)
set(vgkit_boost_compiled_components atomic charconv chrono cobalt container context contract coroutine date_time
    exception fiber filesystem graph graph_parallel iostreams json locale log mpi nowide process program_options
    python random regex serialization system test thread timer type_erasure url wave)
# compiled libraries whose header-only part is what packages use; distributions package b2-built Boost such that
# the compiled part may be absent (e.g. Ubuntu's libboost-container-dev, libboost-test-dev), then Boost::X links
# Boost::headers (Boost.Test is then used via boost/test/included)
set(vgkit_boost_headeronly_usable_components container test)

macro(vgkit_boost_shim_headeronly _tgt)
  if (NOT TARGET Boost::${_tgt})
    add_library(Boost::${_tgt} INTERFACE IMPORTED GLOBAL)
    set_property(TARGET Boost::${_tgt} APPEND PROPERTY INTERFACE_LINK_LIBRARIES Boost::headers)
  endif()
endmacro()

# vgkit_boost_resolve_components(<missing-var> <component>...): for the found Boost (Boost_VERSION, Boost_DIR)
# makes sure that Boost::<target> is defined for each component; appends the components the install lacks to <missing-var>
function(vgkit_boost_resolve_components _missing)
  set(_miss)
  foreach(_c IN LISTS ARGN)
    if (_c STREQUAL "test")
      set(_t unit_test_framework)
    else()
      set(_t ${_c})
    endif()
    if (TARGET Boost::${_t})
      continue()
    endif()
    if (NOT _c IN_LIST vgkit_boost_compiled_components)
      # CMake-harness installs have a package per header-only library
      find_package(boost_${_t} ${Boost_VERSION} EXACT CONFIG QUIET PATHS "${Boost_DIR}/.." NO_DEFAULT_PATH)
      if (TARGET Boost::${_t})
        continue()
      endif()
      # ... b2 installs do not, and have no boost_config package either
      find_package(boost_config ${Boost_VERSION} EXACT CONFIG QUIET PATHS "${Boost_DIR}/.." NO_DEFAULT_PATH)
      if (NOT boost_config_FOUND)
        vgkit_boost_shim_headeronly(${_t})
        continue()
      endif()
    elseif (_c IN_LIST vgkit_boost_headeronly_usable_components)
      find_package(boost_config ${Boost_VERSION} EXACT CONFIG QUIET PATHS "${Boost_DIR}/.." NO_DEFAULT_PATH)
      if (NOT boost_config_FOUND)
        get_target_property(_incs Boost::headers INTERFACE_INCLUDE_DIRECTORIES)
        foreach(_inc IN LISTS _incs)
          if (IS_DIRECTORY "${_inc}/boost/${_c}")
            vgkit_boost_shim_headeronly(${_t})
            break()
          endif()
        endforeach()
        if (TARGET Boost::${_t})
          continue()
        endif()
      endif()
    endif()
    list(APPEND _miss ${_c})
  endforeach()
  set(${_missing} ${${_missing}} ${_miss} PARENT_SCOPE)
endfunction()
]=])
cmake_language(EVAL CODE "${_vgkit_boost_helpers}")

# per-invocation state (an invocation in a subproject inherits the variables of its parent's invocation)
unset(__vgkit_boost_fetch)

# requested components, sans headers (always required)
set(__vgkit_boost_required ${Boost_REQUIRED_COMPONENTS})
set(__vgkit_boost_optional ${Boost_OPTIONAL_COMPONENTS})
list(REMOVE_ITEM __vgkit_boost_required headers)
list(REMOVE_ITEM __vgkit_boost_optional headers)
list(REMOVE_DUPLICATES __vgkit_boost_required)
list(REMOVE_DUPLICATES __vgkit_boost_optional)
foreach(__comp IN LISTS __vgkit_boost_required)
  list(REMOVE_ITEM __vgkit_boost_optional ${__comp})
endforeach()

if (DEFINED BOOST_ROOT AND NOT DEFINED Boost_ROOT)
  set(Boost_ROOT "${BOOST_ROOT}")
endif()
if (DEFINED BOOST_INCLUDEDIR AND NOT DEFINED Boost_ROOT)
  get_filename_component(Boost_ROOT "${BOOST_INCLUDEDIR}/.." ABSOLUTE)
endif()

# Boost built from source by an earlier invocation (e.g. by the parent project) is reused
if (TARGET boost_headers)
  get_target_property(__vgkit_boost_headers_imported boost_headers IMPORTED)
  if (NOT __vgkit_boost_headers_imported)
    set(Boost_BUILT_FROM_SOURCE ON)
  endif()
endif()

# prefixes searched by the probes below for Boost installs that find_package must not (or cannot) use
set(__vgkit_boost_prefixes ${Boost_ROOT} ${CMAKE_PREFIX_PATH} $ENV{CMAKE_PREFIX_PATH})
if (NOT DEFINED CMAKE_FIND_USE_CMAKE_SYSTEM_PATH OR CMAKE_FIND_USE_CMAKE_SYSTEM_PATH)
  list(APPEND __vgkit_boost_prefixes ${CMAKE_SYSTEM_PREFIX_PATH})
endif()

# a Boost installed by this module for another project contains only the libraries that project used; if it lacks
# some requested here, build Boost from source again (installing adds the missing libraries) instead of rejecting it
if (NOT Boost_BUILT_FROM_SOURCE AND Boost_FETCH_IF_MISSING)
  foreach(__prefix IN LISTS __vgkit_boost_prefixes)
    file(GLOB __markers "${__prefix}/lib*/cmake/Boost-${vgkit_boost_fetch_version}/vgkit-fetched-boost")
    if (__markers)
      list(GET __markers 0 __marker)
      get_filename_component(__cmakedir "${__marker}" DIRECTORY)
      get_filename_component(__cmakedir "${__cmakedir}" DIRECTORY)
      set(__vgkit_boost_partial)
      foreach(__comp IN LISTS __vgkit_boost_required __vgkit_boost_optional)
        component_to_targets(__comp __targets)
        file(GLOB __pkg "${__cmakedir}/boost_${__targets}-${vgkit_boost_fetch_version}*")
        if (NOT __pkg)
          list(APPEND __vgkit_boost_partial ${__comp})
        endif()
      endforeach()
      if (__vgkit_boost_partial)
        message(STATUS "FindOrFetchBoost: Boost ${vgkit_boost_fetch_version} installed by FindOrFetchBoost at ${__cmakedir} does not contain ${__vgkit_boost_partial}; will build Boost from source")
        set(__vgkit_boost_fetch ON)
      endif()
      break()
    endif()
  endforeach()
endif()

if (NOT Boost_BUILT_FROM_SOURCE AND NOT __vgkit_boost_fetch)
  set(__vgkit_boost_find_components)
  foreach(__comp IN LISTS __vgkit_boost_required __vgkit_boost_optional)
    if (__comp IN_LIST vgkit_boost_compiled_components)
      component_to_targets(__comp __targets)
      list(APPEND __vgkit_boost_find_components ${__targets})
    endif()
  endforeach()
  # all components are optional here, missing required components are diagnosed below rather than treated as Boost not found
  find_package(Boost ${Boost_OLDEST_BOOST_VERSION} CONFIG QUIET OPTIONAL_COMPONENTS ${__vgkit_boost_find_components})

  if (Boost_FOUND)
    set(Boost_USE_CONFIG ON)
    set(__vgkit_boost_missing)
    vgkit_boost_resolve_components(__vgkit_boost_missing ${__vgkit_boost_required})
    if (__vgkit_boost_missing)
      message(FATAL_ERROR "FindOrFetchBoost: found Boost ${Boost_VERSION} at ${Boost_DIR} lacks required component(s) ${__vgkit_boost_missing}; install them or point Boost_ROOT/CMAKE_PREFIX_PATH at a complete Boost")
    endif()
    vgkit_boost_resolve_components(__vgkit_boost_missing ${__vgkit_boost_optional})
  else()
    # look for Boost installed by an older version of this module: per-library configs only, no BoostConfig.cmake
    set(__vgkit_boost_oldkit)
    foreach(__prefix IN LISTS __vgkit_boost_prefixes)
      file(GLOB __cfgs "${__prefix}/lib*/cmake/boost_headers-*/boost_headers-config.cmake")
      foreach(__cfg IN LISTS __cfgs)
        get_filename_component(__dir "${__cfg}" DIRECTORY)
        file(GLOB __umbrella "${__dir}/../*/BoostConfig.cmake" "${__dir}/../*/boost-config.cmake")
        if (NOT __umbrella)
          set(__vgkit_boost_oldkit "${__dir}")
          break()
        endif()
      endforeach()
      if (__vgkit_boost_oldkit)
        break()
      endif()
    endforeach()
    if (__vgkit_boost_oldkit)
      get_filename_component(__oldkit_prefix "${__vgkit_boost_oldkit}/../../.." ABSOLUTE)
      get_filename_component(__install_prefix "${CMAKE_INSTALL_PREFIX}" ABSOLUTE)
      if (Boost_FETCH_IF_MISSING AND __oldkit_prefix STREQUAL __install_prefix)
        # rebuilding into the prefix the old Boost was installed to: the new install supersedes it
        message(WARNING "FindOrFetchBoost: found an old kit-fetched Boost at ${__vgkit_boost_oldkit} in the install prefix; will build Boost ${vgkit_boost_fetch_version} from source and install it there")
      else()
        message(FATAL_ERROR "FindOrFetchBoost: found an old kit-fetched Boost at ${__vgkit_boost_oldkit} (per-library CMake configs only, no BoostConfig.cmake), which cannot be used; remove it (${__oldkit_prefix}/lib/cmake/boost_*, ${__oldkit_prefix}/include/boost, ${__oldkit_prefix}/lib/libboost_*) and reinstall the packages built against it, or point Boost_ROOT/CMAKE_PREFIX_PATH at another Boost")
      endif()
    endif()
    # nothing required (headers is required only if asked for explicitly): continue without Boost
    if (NOT Boost_FETCH_IF_MISSING AND NOT __vgkit_boost_required AND NOT "headers" IN_LIST Boost_REQUIRED_COMPONENTS)
      message(STATUS "FindOrFetchBoost: Boost >= ${Boost_OLDEST_BOOST_VERSION} not found; all requested components are optional, continuing without Boost")
      set(Boost_BUILT_FROM_SOURCE OFF)
      set(Boost_USE_CONFIG OFF)
      set(Boost_IS_MODULARIZED OFF)
      set(Boost_FOUND_COMPONENTS)
      set(Boost_FOUND_TARGETS)
      set(Boost_CONFIG_FILE_CONTENTS "")
      return()
    endif()
    if (NOT Boost_FETCH_IF_MISSING)
      message(FATAL_ERROR "FindOrFetchBoost: Boost >= ${Boost_OLDEST_BOOST_VERSION} not found; set Boost_ROOT or CMAKE_PREFIX_PATH, or set Boost_FETCH_IF_MISSING=ON to build Boost ${vgkit_boost_fetch_version} as part of the project")
    endif()
    set(__vgkit_boost_fetch ON)
  endif()
endif()

# Boost added via FetchContent with EXCLUDE_FROM_ALL contributes no install rules, and installing all of it would
# require building every compiled library. Hence, at the end of configuring the top-level project, install (with
# Boost's own boost_install) the libraries requested by all FindOrFetchBoost invocations plus their Boost
# dependencies, and make sure that these are built by the default target.
function(__vgkit_boost_install)
  # runs in the scope of the top-level directory, where the variables of the invocation that fetched Boost
  # may not be visible
  get_property(_version GLOBAL PROPERTY VGKIT_BOOST_FETCH_VERSION)
  get_property(_comps GLOBAL PROPERTY VGKIT_BOOST_INSTALL_COMPONENTS)
  set(_todo boost_headers)
  foreach(_c IN LISTS _comps)
    component_to_targets(_c _t)
    list(APPEND _todo boost_${_t})
  endforeach()
  set(_closure)
  while(_todo)
    list(POP_FRONT _todo _tgt)
    if (_tgt IN_LIST _closure OR NOT TARGET ${_tgt})
      continue()
    endif()
    list(APPEND _closure ${_tgt})
    # the installed config of a compiled library also requires its private Boost dependencies
    get_target_property(_deps ${_tgt} INTERFACE_LINK_LIBRARIES)
    get_target_property(_type ${_tgt} TYPE)
    if (NOT _type STREQUAL "INTERFACE_LIBRARY")
      get_target_property(_private_deps ${_tgt} LINK_LIBRARIES)
      list(APPEND _deps ${_private_deps})
    endif()
    string(REGEX MATCHALL "Boost::[A-Za-z0-9_]+" _deps "${_deps}")
    foreach(_d IN LISTS _deps)
      if (TARGET ${_d})
        get_target_property(_real ${_d} ALIASED_TARGET)
        if (NOT _real)
          set(_real ${_d})
        endif()
        list(APPEND _todo ${_real})
      endif()
    endforeach()
  endwhile()

  FetchContent_GetProperties(Boost SOURCE_DIR _src)
  set(BOOST_SKIP_INSTALL_RULES OFF)
  set(BOOST_SUPERPROJECT_SOURCE_DIR "${_src}")
  string(REPLACE "." ";" _v "${_version}")
  list(GET _v 0 PROJECT_VERSION_MAJOR)
  list(GET _v 1 PROJECT_VERSION_MINOR)
  set(PROJECT_VERSION ${_version})  # used by boost_install for version files; local to this function
  list(APPEND CMAKE_MODULE_PATH "${_src}/tools/cmake/include")
  include("${_src}/tools/cmake/include/BoostInstall.cmake")
  foreach(_tgt IN LISTS _closure)
    get_target_property(_type ${_tgt} TYPE)
    if (NOT _type STREQUAL "INTERFACE_LIBRARY")
      set_property(TARGET ${_tgt} PROPERTY EXCLUDE_FROM_ALL OFF)
    endif()
    # as BoostRoot.cmake does: headers from include/, extra/ holds debugger visualizers (e.g. .natvis that
    # Boost adds to the interface sources under MSVC, whose paths must be relocated to the install tree)
    get_target_property(_dir ${_tgt} SOURCE_DIR)
    set(_args)
    if (IS_DIRECTORY "${_dir}/include")
      list(APPEND _args HEADER_DIRECTORY "${_dir}/include")
    endif()
    if (IS_DIRECTORY "${_dir}/extra")
      list(APPEND _args EXTRA_DIRECTORY "${_dir}/extra")
    endif()
    boost_install(TARGETS ${_tgt} VERSION ${_version} ${_args})
  endforeach()
  # as done by Boost's BoostRoot.cmake when Boost is the top-level project
  set(_cfgdir "${BOOST_INSTALL_CMAKEDIR}/Boost-${_version}")
  install(FILES "${_src}/tools/cmake/config/BoostConfig.cmake" DESTINATION "${_cfgdir}")
  write_basic_package_version_file("${CMAKE_BINARY_DIR}/vgkit-boost/BoostConfigVersion.cmake"
          VERSION ${_version} COMPATIBILITY SameMajorVersion ARCH_INDEPENDENT)
  install(FILES "${CMAKE_BINARY_DIR}/vgkit-boost/BoostConfigVersion.cmake" DESTINATION "${_cfgdir}")
  # marks this Boost install as made by FindOrFetchBoost, so that it can be extended rather than rejected when
  # a later project needs libraries that were not installed
  file(WRITE "${CMAKE_BINARY_DIR}/vgkit-boost/vgkit-fetched-boost" "Boost ${_version} installed by kit-cmake's FindOrFetchBoost\n")
  install(FILES "${CMAKE_BINARY_DIR}/vgkit-boost/vgkit-fetched-boost" DESTINATION "${_cfgdir}")
endfunction()

if (__vgkit_boost_fetch)
  message(STATUS "FindOrFetchBoost: Boost not found, building Boost ${vgkit_boost_fetch_version} from source")
  if (CMAKE_VERSION VERSION_LESS 3.25.0)  # for FetchContent's SYSTEM option
    message(FATAL_ERROR "FindOrFetchBoost: building Boost from source requires CMake 3.25 or later")
  endif()

  include(FetchContent)
  # Boost can only be built once in a build tree
  FetchContent_GetProperties(Boost)
  if (Boost_POPULATED)
    message(FATAL_ERROR "FindOrFetchBoost: Boost was not found by project ${PROJECT_NAME} and Boost_FETCH_IF_MISSING=ON, but Boost was already populated via FetchContent without being added to the build")
  endif()

  FetchContent_Declare(
          Boost
          URL https://github.com/boostorg/boost/releases/download/boost-${vgkit_boost_fetch_version}/boost-${vgkit_boost_fetch_version}-cmake.tar.xz
          URL_HASH SHA256=${vgkit_boost_fetch_sha256}
          DOWNLOAD_EXTRACT_TIMESTAMP ON
          EXCLUDE_FROM_ALL
          SYSTEM
  )

  # configure all of Boost (minus BOOST_EXCLUDE_LIBRARIES): in a superbuild projects added later may need
  # libraries the first one did not ask for, and Boost can be added only once; libraries are built only if used
  set(__vgkit_boost_include_libraries "${BOOST_INCLUDE_LIBRARIES}")
  unset(BOOST_INCLUDE_LIBRARIES)
  FetchContent_MakeAvailable(Boost)
  set(BOOST_INCLUDE_LIBRARIES "${__vgkit_boost_include_libraries}")
  set_property(GLOBAL PROPERTY VGKIT_BOOST_FETCH_VERSION ${vgkit_boost_fetch_version})
  cmake_language(DEFER DIRECTORY "${CMAKE_SOURCE_DIR}" ID vgkit_boost_install CALL __vgkit_boost_install)

  # unity build not supported for some Boost libraries
  foreach (unity_broken_lib locale serialization)
    if (TARGET boost_${unity_broken_lib})
      set_property(TARGET boost_${unity_broken_lib} PROPERTY UNITY_BUILD OFF)
    endif()
  endforeach()

  set(Boost_BUILT_FROM_SOURCE ON)
endif(__vgkit_boost_fetch)

if (Boost_BUILT_FROM_SOURCE)
  set(Boost_VERSION ${vgkit_boost_fetch_version})
  set(Boost_USE_CONFIG OFF)
  set(__vgkit_boost_missing)
  foreach(__comp IN LISTS __vgkit_boost_required)
    component_to_targets(__comp __targets)
    if (NOT TARGET Boost::${__targets})
      list(APPEND __vgkit_boost_missing ${__comp})
    endif()
  endforeach()
  set_property(GLOBAL APPEND PROPERTY VGKIT_BOOST_INSTALL_COMPONENTS ${__vgkit_boost_required} ${__vgkit_boost_optional})
  if (__vgkit_boost_missing)
    message(FATAL_ERROR "FindOrFetchBoost: Boost built from source lacks required component(s) ${__vgkit_boost_missing}; are they excluded via BOOST_EXCLUDE_LIBRARIES?")
  endif()
  if (NOT TARGET Boost::boost)
    add_library(Boost::boost ALIAS boost_headers)
  endif()
endif()

# collect found components/targets; make imported targets global so that dependents in other directories can use them
# (more discussion here: https://gitlab.kitware.com/cmake/cmake/-/issues/17256)
set(Boost_FOUND_COMPONENTS headers)
set(Boost_FOUND_TARGETS headers)
foreach(__comp IN LISTS __vgkit_boost_required __vgkit_boost_optional)
  component_to_targets(__comp __targets)
  if (TARGET Boost::${__targets})
    list(APPEND Boost_FOUND_COMPONENTS ${__comp})
    list(APPEND Boost_FOUND_TARGETS ${__targets})
  endif()
endforeach()
# only targets imported in this directory can be promoted; this includes the dependencies of the found components
# (targets imported by an invocation in a parent directory were promoted by that invocation)
set(__vgkit_boost_imported)
if (NOT CMAKE_VERSION VERSION_LESS 3.21)  # IMPORTED_TARGETS directory property
  get_directory_property(__vgkit_boost_imported IMPORTED_TARGETS)
endif()
foreach(__tgt IN LISTS __vgkit_boost_imported)
  if (__tgt MATCHES "^Boost::")
    get_target_property(__global ${__tgt} IMPORTED_GLOBAL)
    if (NOT __global)
      set_target_properties(${__tgt} PROPERTIES IMPORTED_GLOBAL TRUE)
    endif()
  endif()
endforeach()
set(Boost_IS_MODULARIZED ON)

set(__vgkit_boost_targets_missing_check "NOT;TARGET;Boost::headers")
foreach(__tgt IN LISTS Boost_FOUND_TARGETS)
  list(APPEND __vgkit_boost_targets_missing_check "OR;NOT;TARGET;Boost::${__tgt}")
endforeach()
set(__vgkit_boost_found_nonheaders ${Boost_FOUND_COMPONENTS})
list(REMOVE_ITEM __vgkit_boost_found_nonheaders headers)
if (Boost_BUILT_FROM_SOURCE)
  set(__vgkit_boost_found_targets_nonheaders ${Boost_FOUND_TARGETS})
  list(REMOVE_ITEM __vgkit_boost_found_targets_nonheaders headers)
  set(Boost_CONFIG_FILE_CONTENTS "
# import Boost ${vgkit_boost_fetch_version}, built from source and installed along with this package
if(${__vgkit_boost_targets_missing_check})
  include(CMakeFindDependencyMacro)
  find_dependency(Boost ${vgkit_boost_fetch_version} EXACT CONFIG COMPONENTS ${__vgkit_boost_found_targets_nonheaders})
endif()
")
else()
  set(__vgkit_boost_find_found)
  foreach(__comp IN LISTS __vgkit_boost_found_nonheaders)
    if (__comp IN_LIST vgkit_boost_compiled_components)
      component_to_targets(__comp __targets)
      list(APPEND __vgkit_boost_find_found ${__targets})
    endif()
  endforeach()
  get_filename_component(__vgkit_boost_config_dir "${Boost_CONFIG}" DIRECTORY)
  set(Boost_CONFIG_FILE_CONTENTS "
# import Boost ${Boost_VERSION} found at configure time
if(${__vgkit_boost_targets_missing_check})
  include(CMakeFindDependencyMacro)
  if (NOT EXISTS \"${Boost_CONFIG}\")
    message(FATAL_ERROR \"Expected Boost config file at ${Boost_CONFIG}; Boost moved since this package was configured?\")
  endif()
  # compiled components are optional here: some may be provided by Boost::headers (see vgkit_boost_resolve_components)
  find_dependency(Boost ${Boost_VERSION} EXACT CONFIG PATHS \"${__vgkit_boost_config_dir}\" NO_DEFAULT_PATH OPTIONAL_COMPONENTS ${__vgkit_boost_find_found})
${_vgkit_boost_helpers}
  set(_vgkit_boost_missing)
  vgkit_boost_resolve_components(_vgkit_boost_missing ${__vgkit_boost_found_nonheaders})
  if (_vgkit_boost_missing)
    message(FATAL_ERROR \"Boost at ${Boost_CONFIG} lacks component(s) \${_vgkit_boost_missing}\")
  endif()
endif()
")
endif()
