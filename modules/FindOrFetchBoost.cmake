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
# Boost_MODULAR_TARGETS_NOT_BUILT_BY_INSTALL: CACHE variable containing the list of targets that
#   are not built automatically when the "install" target is built; if Boost_BUILT_FROM_SOURCE is ON,
#   for each target X in this list user will want to add an artificial dependence of their target(s)
#   on target boost_X
# Boost_CONFIG_FILE_CONTENTS: CMake code to paste into the package config file of the project, imports the same Boost

set(vgkit_boost_fetch_version 1.92.0)
set(vgkit_boost_fetch_sha256 9bed76128d4e46755dbe818487788c6fceb6f72b378f4daa49b7e1e600d9088d)

set(Boost_MODULAR_TARGETS_NOT_BUILT_BY_INSTALL "filesystem;iostreams;unit_test_framework" CACHE STRING "list of Boost targets not built by install target")

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
    endif()
    list(APPEND _miss ${_c})
  endforeach()
  set(${_missing} ${${_missing}} ${_miss} PARENT_SCOPE)
endfunction()
]=])
cmake_language(EVAL CODE "${_vgkit_boost_helpers}")

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

if (NOT Boost_BUILT_FROM_SOURCE)
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
    set(__vgkit_boost_prefixes ${Boost_ROOT} ${CMAKE_PREFIX_PATH} $ENV{CMAKE_PREFIX_PATH})
    if (NOT DEFINED CMAKE_FIND_USE_CMAKE_SYSTEM_PATH OR CMAKE_FIND_USE_CMAKE_SYSTEM_PATH)
      list(APPEND __vgkit_boost_prefixes ${CMAKE_SYSTEM_PREFIX_PATH})
    endif()
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
      message(FATAL_ERROR "FindOrFetchBoost: found an old kit-fetched Boost at ${__vgkit_boost_oldkit} (per-library CMake configs only, no BoostConfig.cmake); reinstall it, and packages built against it, with the current kit, or point Boost_ROOT/CMAKE_PREFIX_PATH at another Boost")
    endif()
    if (NOT Boost_FETCH_IF_MISSING)
      message(FATAL_ERROR "FindOrFetchBoost: Boost >= ${Boost_OLDEST_BOOST_VERSION} not found; set Boost_ROOT or CMAKE_PREFIX_PATH, or set Boost_FETCH_IF_MISSING=ON to build Boost ${vgkit_boost_fetch_version} as part of the project")
    endif()
    set(__vgkit_boost_fetch ON)
  endif()
endif()

if (__vgkit_boost_fetch)
  # TEMPORARY (until Task 2): previous fetch implementation
set(Boost_ALL_COMPONENTS
        algorithm
        align
        any
        atomic
        array
        assert
        bind
        chrono
        circular_buffer
        compute
        concept_check
        config
        container
        container_hash
        conversion
        core
        date_time
        describe
        detail
        dynamic_bitset
        endian
        exception
        filesystem
        function
        functional
        function_types
        fusion
        headers
        integer
        intrusive
        io
        iostreams
        iterator
        lexical_cast
        logic
        math
        move
        mp11
        mpl
        multiprecision
        multi_index
        numeric_conversion
        numeric_interval
        #numeric_odeint
        numeric_ublas
        optional
        parameter
        phoenix
        pool
        predef
        preprocessor
        property_tree
        proto
        random
        range
        ratio
        regex
        serialization
        smart_ptr
        spirit
        static_assert
        system
        test
        thread
        throw_exception
        tokenizer
        tti
        tuple
        typeof
        type_index
        type_traits
        unordered
        utility
        uuid
        variant
        variant2
        winapi)
  message(WARNING "FetchContent'ing Boost")

  # Boost can only be build once in a source tree
  if (Boost_POPULATED)
      message(FATAL_ERROR "Boost was not found by project ${PROJECT_NAME} and Boost_FETCH_IF_MISSING=ON, but someone already build Boost via FetchContent with components \"${__missing_required_modular_boost_components}\" required by this project are missing; add these components to the original FetchContent stanza")
  endif()

  include (FetchContent)
  cmake_minimum_required (VERSION 3.25.0)  # for ExternalProject_add's SYSTEM option

  set(BOOST_SUPERPROJECT_VERSION 1.84.0)
  FetchContent_Declare(
          Boost
          URL https://github.com/boostorg/boost/releases/download/boost-${BOOST_SUPERPROJECT_VERSION}/boost-${BOOST_SUPERPROJECT_VERSION}.tar.xz
          URL_HASH MD5=893b5203b862eb9bbd08553e24ff146a
          DOWNLOAD_EXTRACT_TIMESTAMP ON
          EXCLUDE_FROM_ALL
          SYSTEM
  )

  if (NOT DEFINED BOOST_INCLUDE_LIBRARIES)
      set(BOOST_INCLUDE_LIBRARIES headers)
  else()
      list(APPEND BOOST_INCLUDE_LIBRARIES headers)
  endif()
  if (DEFINED Boost_REQUIRED_COMPONENTS)
      list(APPEND BOOST_INCLUDE_LIBRARIES ${Boost_REQUIRED_COMPONENTS})
  endif()
  if (DEFINED Boost_OPTIONAL_COMPONENTS)
      list(APPEND BOOST_INCLUDE_LIBRARIES ${Boost_OPTIONAL_COMPONENTS})
  endif()
  list(REMOVE_DUPLICATES BOOST_INCLUDE_LIBRARIES)
  message(WARNING "FetchContent Boost package with the following components: ${BOOST_INCLUDE_LIBRARIES}")
  # for now build everything
  set(BOOST_INCLUDE_LIBRARIES_CURRENT ${BOOST_INCLUDE_LIBRARIES})
  unset(BOOST_INCLUDE_LIBRARIES)

  FetchContent_GetProperties(Boost)

  if(NOT Boost_POPULATED)

    message(STATUS "Fetching Boost")
    FetchContent_MakeAvailable(Boost)
    message(STATUS "Fetching Boost done")

    # unity build not supported for some Boost libraries
    foreach (unity_broken_lib locale serialization)
      if (TARGET boost_${unity_broken_lib})
        message(STATUS "Will disable unity-build for boost_${unity_broken_lib}")
        set_property(TARGET boost_${unity_broken_lib} PROPERTY UNITY_BUILD OFF)
      endif()
    endforeach()

  endif()

  # TODO figure out how to deduce the list of dependent components
  # for now just use all of them, i.e. Boost_ALL_COMPONENTS
  set(BOOST_INCLUDE_LIBRARIES ${BOOST_INCLUDE_LIBRARIES_CURRENT})
  set(BOOST_INCLUDE_LIBRARIES_FULL "headers;${BOOST_INCLUDE_LIBRARIES};${Boost_ALL_COMPONENTS}")
  list(REMOVE_DUPLICATES BOOST_INCLUDE_LIBRARIES_FULL)
  if (DEFINED BOOST_EXCLUDE_LIBRARIES)
    list(REMOVE_ITEM BOOST_INCLUDE_LIBRARIES_FULL ${BOOST_EXCLUDE_LIBRARIES})
  endif()

  # Boost install is only enabled when Boost is the top-level project, and there is no way to override
  # this, so here we invoke boost_install commands ourselves; this requires setting some variables that are set
  # by BoostRoot.cmake
  set(BOOST_SKIP_INSTALL_RULES OFF)
  set(BOOST_SUPERPROJECT_SOURCE_DIR "${Boost_SOURCE_DIR}")
  set(BOOST_INSTALL_CMAKEDIR "lib/cmake")
  if (DEFINED PROJECT_VERSION)
      set(ACTUAL_PROJECT_VERSION ${PROJECT_VERSION})
  endif(DEFINED PROJECT_VERSION)
  set(PROJECT_VERSION ${BOOST_SUPERPROJECT_VERSION})
  foreach(lib IN LISTS BOOST_INCLUDE_LIBRARIES_FULL)

      # deduce the location of headers ... for some libraries it does not match the basic pattern
      set(__HEADER_DIRECTORY "${BOOST_SUPERPROJECT_SOURCE_DIR}/libs/${lib}/include")
      if (lib STREQUAL numeric_conversion)
          set(__HEADER_DIRECTORY ${BOOST_SUPERPROJECT_SOURCE_DIR}/libs/numeric/conversion/include)
      endif()
      if (lib STREQUAL numeric_interval)
          set(__HEADER_DIRECTORY ${BOOST_SUPERPROJECT_SOURCE_DIR}/libs/numeric/interval/include)
      endif()
      if (lib STREQUAL numeric_odeint)
          set(__HEADER_DIRECTORY ${BOOST_SUPERPROJECT_SOURCE_DIR}/libs/numeric/odeint/include)
      endif()
      if (lib STREQUAL numeric_ublas)
          set(__HEADER_DIRECTORY ${BOOST_SUPERPROJECT_SOURCE_DIR}/libs/numeric/ublas/include)
      endif()

      # convert the list of components to a list of targets
      component_to_targets(lib __lib_targets)
      # convert target T to boost_T
      set(__lib_targets_w_boost_prepended )
      foreach(__target IN LISTS __lib_targets)
          list(APPEND __lib_targets_w_boost_prepended boost_${__target})
      endforeach()

      boost_install(TARGETS "${__lib_targets_w_boost_prepended}" VERSION "${BOOST_SUPERPROJECT_VERSION}" HEADER_DIRECTORY "${__HEADER_DIRECTORY}")

      # Create the targets file in build tree also
      foreach(__target IN LISTS __lib_targets_w_boost_prepended)
          export(EXPORT ${__target}-targets
                 NAMESPACE Boost::
                 FILE "${PROJECT_BINARY_DIR}/${__target}-targets.cmake")
      endforeach()
  endforeach()

  if (DEFINED ACTUAL_PROJECT_VERSION)
      set(PROJECT_VERSION ${ACTUAL_PROJECT_VERSION})
  else(DEFINED ACTUAL_PROJECT_VERSION)
      unset(PROJECT_VERSION)
  endif(DEFINED ACTUAL_PROJECT_VERSION)

  # result
  set(Boost_BUILT_FROM_SOURCE ON)
  set(Boost_IS_MODULARIZED ON)

endif(__vgkit_boost_fetch)

if (Boost_BUILT_FROM_SOURCE)
  set(__vgkit_boost_missing)
  foreach(__comp IN LISTS __vgkit_boost_required)
    component_to_targets(__comp __targets)
    if (NOT TARGET Boost::${__targets})
      list(APPEND __vgkit_boost_missing ${__comp})
    endif()
  endforeach()
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
foreach(__tgt IN LISTS Boost_FOUND_TARGETS)
  get_target_property(__imported Boost::${__tgt} IMPORTED)
  if (__imported)
    get_target_property(__global Boost::${__tgt} IMPORTED_GLOBAL)
    if (NOT __global)
      set_target_properties(Boost::${__tgt} PROPERTIES IMPORTED_GLOBAL TRUE)
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
  find_dependency(Boost ${Boost_VERSION} EXACT CONFIG PATHS \"${__vgkit_boost_config_dir}\" NO_DEFAULT_PATH COMPONENTS ${__vgkit_boost_find_found})
${_vgkit_boost_helpers}
  set(_vgkit_boost_missing)
  vgkit_boost_resolve_components(_vgkit_boost_missing ${__vgkit_boost_found_nonheaders})
  if (_vgkit_boost_missing)
    message(FATAL_ERROR \"Boost at ${Boost_CONFIG} lacks component(s) \${_vgkit_boost_missing}\")
  endif()
endif()
")
endif()
