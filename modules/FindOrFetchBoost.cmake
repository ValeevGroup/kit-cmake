# -*- mode: cmake -*-

# definitions:
# - "library": e.g. Boost.PropertyTree, corresponds to the contents of subdirectory contained in libs/
# - "component": Boost package components given via
#   - COMPONENTS and OPTIONAL_COMPONENTS) to the find_package command used to import Boost in CMake, or
#   - Boost_INCLUDE_LIBRARIES variable passed to the Boost CMake harness used by the FetchContent command to build Boost
#     from source
# - "target": an IMPORTED CMake target defined by Boost, e.g. Boost::headers

# facts:
# - every library X (Boost.X) is usually also a component X, but
#   - some correspond to multiple components or versioned components (e.g. Boost.Python is a library that corresponds to components pythonXY and numpyXY,
#     where XY is the Python version), and some correspond to no components or a part of a component (e.g. ccomponent
#     "headers"  contains all header-only libraries
#   - basically, original Boost CMake toolkit (i.e., the FindBoost CMake module) had 1 component (boost)
#     for all header-onlu libraries and one component for each non-header-only library
#   - modular Boost CMake harness has at least component per library (header-only or otherwise),
#     but sometimes more than 1
# - every component X usually correspond to IMPORTED target Boost::X ; exceptions include:
#   - Boost::boost is not a component; Boost::headers is an alias for Boost::boost
#   - targets Boost::numeric_{conversion,interval,odeint,ublas} are defined by component numeric

# input variables:
# Boost_REQUIRED_COMPONENTS: list of required components; these are components defined by the modular Boost (not by the old cmake harness)
# Boost_OPTIONAL_COMPONENTS: list of optional components; these are components defined by the modular Boost (not by the old cmake harness)
# Boost_FETCH_IF_MISSING: if set to ON, will download and build Boost if it is not found

# hints:
# BOOST_ROOT: preferred installation prefix (see https://cmake.org/cmake/help/latest/module/FindBoost.html)
# BOOST_INCLUDEDIR: preferred include directory e.g. <prefix>/include. (see https://cmake.org/cmake/help/latest/module/FindBoost.html)

# output variables:
# Boost_BUILT_FROM_SOURCE: ON if Boost was built from source
# Boost_USE_CONFIG: if Boost_BUILT_FROM_SOURCE is ON, this indicates whether found Boost via config mode
# Boost_CONFIG: if Boost_BUILT_FROM_SOURCE and Boost_USE_CONFIG are ON, this specifies the config file used
# Boost_IS_MODULARIZED: if Boost targets are modularized (i.e. not the old cmake harness)
# Boost_FOUND_COMPONENTS: list of modular components that were found
# Boost_FOUND_TARGETS: list of modular targets (X in Boost::X or boost_X) that were found
# Boost_FOUND_COMPONENTS_NONMODULAR: list of non-modular components that were found
# Boost_FOUND_TARGETS_NONMODULAR: list of non-modular targets (X in Boost::X) that were found
# Boost_MODULAR_TARGETS_NOT_BUILT_BY_INSTALL: CACHE variable containing the list of modular targets that
#   are not built automatically when the "install" target is built; if Boost_BUILT_FROM_SOURCE is ON,
#   for each target X in this list user will want to add an artificial dependence of their target(s)
#   on target boost_X

# list of all non-modular components
set(Boost_ALL_COMPONENTS_NONMODULAR
        headers
        # see https://www.boost.org/doc/libs/master/more/getting_started/unix-variants.html#header-only-libraries
        chrono
        context
        graph
        filesystem
        iostreams
        locale
        log
        math_tr1
        math_c99
        mpi
        program_options
        python
        random
        regex
        serialization
        thread
        timer
        wave
   )

# list of all modular components
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
        iterator
        io
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

set(Boost_MODULAR_TARGETS_NOT_BUILT_BY_INSTALL "filesystem;unit_test_framework" CACHE STRING "list of Boost targets not built by install target")

# converts modular component _comp to list of targets defined by the component
# target name x means TARGET Boost::x is defined
macro(component_to_targets _comp _targets)
    if (${${_comp}} STREQUAL test)
        set(${_targets} unit_test_framework)
    else()
        set(${_targets} ${${_comp}})
    endif()
endmacro()

macro(intersection _out _in1 _in2)
    set(${_out})
    foreach(x IN LISTS ${_in1})
        if(x IN_LIST ${_in2})
            list(APPEND ${_out} ${x})
        endif()
    endforeach()
endmacro()

# elements in _in1 that are not in _in2
macro(difference _out _in1 _in2)
    set(${_out})
    foreach(x IN LISTS ${_in1})
        if(NOT(x IN_LIST ${_in2}))
            list(APPEND ${_out} ${x})
        endif()
    endforeach()
endmacro()

# Limit scope of the search if BOOST_ROOT or BOOST_INCLUDEDIR is provided.
if (BOOST_ROOT OR BOOST_INCLUDEDIR)
    set(Boost_NO_SYSTEM_PATHS TRUE)
endif()

intersection(Boost_REQUIRED_COMPONENTS_NONMODULAR Boost_REQUIRED_COMPONENTS Boost_ALL_COMPONENTS_NONMODULAR)
intersection(Boost_OPTIONAL_COMPONENTS_NONMODULAR Boost_OPTIONAL_COMPONENTS Boost_ALL_COMPONENTS_NONMODULAR)
# Boost_REQUIRED_COMPONENTS_NONMODULAR may intersect with Boost_OPTIONAL_COMPONENTS_NONMODULAR, exclude those components from Boost_OPTIONAL_COMPONENTS_NONMODULAR
difference(Boost_OPTIONAL_COMPONENTS_NONMODULAR_NOT_IN_REQUIRES Boost_OPTIONAL_COMPONENTS_NONMODULAR Boost_REQUIRED_COMPONENTS_NONMODULAR)
set(Boost_OPTIONAL_COMPONENTS_NONMODULAR ${Boost_OPTIONAL_COMPONENTS_NONMODULAR_NOT_IN_REQUIRES})

# detect which Boost targets I already have
foreach(__comp headers ${Boost_REQUIRED_COMPONENTS_NONMODULAR} ${Boost_OPTIONAL_COMPONENTS_NONMODULAR})
    component_to_targets(__comp __targets)
    foreach(tgt IN LISTS __targets)
        if (TARGET Boost::${tgt})
            set(vgck_imported_boost_${tgt} 0)
        else()
            set(vgck_imported_boost_${tgt} 1)
        endif()
    endforeach()
endforeach()

# try config first
# OPTIONAL_COMPONENTS in FindBoost available since 3.11
cmake_minimum_required(VERSION 3.11.0)
# if Boost was loaded via config file or have not found Boost yet
if (DEFINED Boost_CONFIG OR NOT TARGET Boost::headers)
  find_package(Boost ${Boost_OLDEST_BOOST_VERSION} QUIET CONFIG COMPONENTS ${Boost_REQUIRED_COMPONENTS_NONMODULAR} OPTIONAL_COMPONENTS ${Boost_OPTIONAL_COMPONENTS_NONMODULAR})
endif()
if (NOT DEFINED Boost_CONFIG AND NOT TARGET Boost::headers)
    find_package(Boost ${Boost_OLDEST_BOOST_VERSION} QUIET COMPONENTS ${Boost_REQUIRED_COMPONENTS_NONMODULAR} OPTIONAL_COMPONENTS ${Boost_OPTIONAL_COMPONENTS_NONMODULAR})
    if (TARGET Boost::headers)
        set(Boost_USE_CONFIG FALSE)
    endif(TARGET Boost::headers)
else()
    set(Boost_USE_CONFIG TRUE)
endif()

# Boost::* targets by default are not GLOBAL, so to allow users of LINALG_LIBRARIES to safely use them we need to make them global
# more discussion here: https://gitlab.kitware.com/cmake/cmake/-/issues/17256
foreach(__comp headers ${Boost_REQUIRED_COMPONENTS_NONMODULAR} ${Boost_OPTIONAL_COMPONENTS_NONMODULAR})
    component_to_targets(__comp __targets)
    foreach(tgt IN LISTS __targets)
        if (TARGET Boost::${tgt} AND vgck_imported_boost_${tgt})
            get_target_property(_boost_tgt_${tgt}_is_imported_global Boost::${tgt} IMPORTED_GLOBAL)
            if (NOT _boost_tgt_${tgt}_is_imported_global)
                set_target_properties(Boost::${tgt} PROPERTIES IMPORTED_GLOBAL TRUE)
            endif()
            unset(_boost_tgt_${tgt}_is_imported_global)
        endif()
    endforeach()
endforeach()

# detect which components are missing
set(__missing_nonmodular_boost_components )  # there should not be any if find_package succeeded, i.e. Boost_FOUND is true
foreach(__comp IN LISTS Boost_REQUIRED_COMPONENTS_NONMODULAR)
    component_to_targets(__comp __targets)
    foreach(tgt IN LISTS __targets)
        if (NOT TARGET Boost::${tgt})
            list(APPEND __missing_nonmodular_boost_components ${__comp})
        endif()
    endforeach()
endforeach()
set(__missing_modular_boost_components )
foreach(__comp IN LISTS Boost_REQUIRED_COMPONENTS)
    component_to_targets(__comp __targets)
    foreach(tgt IN LISTS __targets)
        if (NOT TARGET Boost::${tgt})
            list(APPEND __missing_modular_boost_components ${__comp})
        endif()
    endforeach()
endforeach()

# if Boost was loaded via find_package check if have all REQUIRED components
if (Boost_FOUND)
    if (__missing_nonmodular_boost_components)
        message(FATAL_ERROR "Boost was discovered successfully via find_package(Boost) but components \"${__missing_nonmodular_boost_components}\" required by ${PROJECT_NAME} were not found")
    endif()
endif()

if (NOT Boost_FOUND AND __missing_modular_boost_components AND Boost_FETCH_IF_MISSING)

  # Boost can only be build once in a source tree
  if (Boost_POPULATED)
      message(FATAL_ERROR "Boost was not found by project ${PROJECT_NAME} and Boost_FETCH_IF_MISSING=ON, but someone already build Boost via FetchContent with components \"${__missing_modular_boost_components}\" required by this project are missing; add these components to the original FetchContent stanza")
  endif()

  include (FetchContent)
  cmake_minimum_required (VERSION 3.14.0)  # for FetchContent_MakeAvailable

  set(BOOST_SUPERPROJECT_VERSION 1.84.0)
  FetchContent_Declare(
          Boost
          URL https://github.com/boostorg/boost/releases/download/boost-${BOOST_SUPERPROJECT_VERSION}/boost-${BOOST_SUPERPROJECT_VERSION}.tar.xz
          URL_MD5 893b5203b862eb9bbd08553e24ff146a
          DOWNLOAD_EXTRACT_TIMESTAMP ON
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
    FetchContent_Populate(Boost)
    message(STATUS "Fetching Boost done")
    FetchContent_GetProperties(Boost
            SOURCE_DIR Boost_SOURCE_DIR
            BINARY_DIR Boost_BINARY_DIR
    )

    message(STATUS "Configuring Boost: downloaded to ${Boost_SOURCE_DIR}, to be built in ${Boost_BINARY_DIR}")
    add_subdirectory(${Boost_SOURCE_DIR} ${Boost_BINARY_DIR} EXCLUDE_FROM_ALL)
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

endif(NOT Boost_FOUND AND __missing_modular_boost_components AND Boost_FETCH_IF_MISSING)

# extract components that were found
set(Boost_FOUND_COMPONENTS_NONMODULAR )
set(Boost_FOUND_COMPONENTS )
set(Boost_FOUND_TARGETS_NONMODULAR )
set(Boost_FOUND_TARGETS )
foreach(__comp headers ${Boost_REQUIRED_COMPONENTS_NONMODULAR} ${Boost_OPTIONAL_COMPONENTS_NONMODULAR})
    component_to_targets(__comp __targets)
    foreach(tgt IN LISTS __targets)
        if (TARGET Boost::${tgt})
            list(APPEND Boost_FOUND_COMPONENTS_NONMODULAR ${__comp})
            list(APPEND Boost_FOUND_TARGETS_NONMODULAR ${tgt})
        endif()
    endforeach()
endforeach()
list(REMOVE_DUPLICATES Boost_FOUND_COMPONENTS_NONMODULAR)
list(REMOVE_DUPLICATES Boost_FOUND_TARGETS_NONMODULAR)
foreach(__comp headers ${Boost_REQUIRED_COMPONENTS} ${Boost_OPTIONAL_COMPONENTS})
    component_to_targets(__comp __targets)
    foreach(tgt IN LISTS __targets)
        if (TARGET Boost::${tgt})
            list(APPEND Boost_FOUND_COMPONENTS ${__comp})
            list(APPEND Boost_FOUND_TARGETS ${tgt})
        endif()
    endforeach()
endforeach()
list(REMOVE_DUPLICATES Boost_FOUND_COMPONENTS)
list(REMOVE_DUPLICATES Boost_FOUND_TARGETS)

# Boost::boost is an alias for Boost::headers defined by boost-config.cmake
if (Boost_IS_MODULARIZED AND NOT TARGET Boost::boost AND TARGET boost_headers)
    add_library(Boost::boost ALIAS boost_headers)
endif()

set(Boost_CONFIG_FILE_CONTENTS
"
# converts modular component _comp to list of targets defined by the component
# target name x means TARGET Boost::x is defined .. this is provided just in case on needs to map comonents to targets
macro(component_to_targets _comp _targets)
    if (\${\${_comp}} STREQUAL test)
        set(\${_targets} unit_test_framework)
    else()
        set(\${_targets} \${\${_comp}})
    endif()
endmacro()

#########################################
# import boost components, if any missing
#########################################
set(Boost_IS_MODULARIZED ${Boost_IS_MODULARIZED})
if (Boost_IS_MODULARIZED)
  set(Boost_FOUND_COMPONENTS ${Boost_FOUND_COMPONENTS})
  set(Boost_FOUND_TARGETS ${Boost_FOUND_TARGETS})
else(Boost_IS_MODULARIZED)
  set(Boost_FOUND_COMPONENTS ${Boost_FOUND_COMPONENTS_NONMODULAR})
  set(Boost_FOUND_TARGETS ${Boost_FOUND_TARGETS_NONMODULAR})
endif(Boost_IS_MODULARIZED)

set(Boost_DEPS_LIBRARIES_NOT_FOUND_CHECK \"NOT;TARGET;Boost::headers\")
foreach(_tgt \${Boost_FOUND_TARGETS})
  list(APPEND Boost_DEPS_LIBRARIES_NOT_FOUND_CHECK \"OR;NOT;TARGET;Boost::\${_tgt}\")
endforeach(_tgt)

if(\${Boost_DEPS_LIBRARIES_NOT_FOUND_CHECK})
  include( CMakeFindDependencyMacro )
  set(Boost_BUILT_FROM_SOURCE ${Boost_BUILT_FROM_SOURCE})
  if (NOT Boost_BUILT_FROM_SOURCE)
    set(Boost_USE_CONFIG ${Boost_USE_CONFIG})
    # OPTIONAL_COMPONENTS in FindBoost available since 3.11
    cmake_minimum_required(VERSION 3.11.0)
    if (Boost_USE_CONFIG)
      set(Boost_CONFIG ${Boost_CONFIG})
      if (NOT Boost_CONFIG OR NOT EXISTS \${Boost_CONFIG})
        message(FATAL_ERROR \"Expected Boost config file at \${Boost_CONFIG}; directory moved since BTAS configuration?\")
      endif()
      get_filename_component(Boost_DIR \${Boost_CONFIG} DIRECTORY)
      find_dependency(Boost QUIET REQUIRED OPTIONAL_COMPONENTS \${Boost_FOUND_COMPONENTS} PATHS \${Boost_DIR} NO_DEFAULT_PATH)
    else (Boost_USE_CONFIG)
      set(BOOST_INCLUDEDIR ${Boost_INCLUDE_DIR})
      set(BOOST_LIBRARYDIR ${Boost_LIBRARY_DIR_RELEASE})
      if (NOT BOOST_LIBRARYDIR OR NOT EXISTS \${BOOST_LIBRARYDIR})
        set(BOOST_LIBRARYDIR ${Boost_LIBRARY_DIR_DEBUG})
      endif()
      set(Boost_NO_SYSTEM_PATHS OFF)
      if (BOOST_LIBRARYDIR AND BOOST_INCLUDEDIR)
        if (EXISTS \${BOOST_LIBRARYDIR} AND EXISTS \${BOOST_INCLUDEDIR})
          set(Boost_NO_SYSTEM_PATHS ON)
        endif()
      endif()
      find_dependency(Boost QUIET REQUIRED OPTIONAL_COMPONENTS \${Boost_FOUND_COMPONENTS})
    endif (Boost_USE_CONFIG)
  else(NOT Boost_BUILT_FROM_SOURCE)
    foreach(_tgt IN LISTS Boost_FOUND_TARGETS)
      if (NOT TARGET Boost::\${_tgt})
        find_dependency(boost_\${_tgt} QUIET CONFIG REQUIRED)
      endif()
    endforeach(_tgt)
  endif(NOT Boost_BUILT_FROM_SOURCE)
endif(\${Boost_DEPS_LIBRARIES_NOT_FOUND_CHECK})

"
)

# postcond check
if (NOT TARGET Boost::headers)
  message(FATAL_ERROR "FindOrFetchBoost could not find components listed in Boost_{REQUIRED,OPTIONAL}_COMPONENTS available; set Boost_FETCH_IF_MISSING=ON to build Boost as part of the project")
endif(NOT TARGET Boost::headers)
