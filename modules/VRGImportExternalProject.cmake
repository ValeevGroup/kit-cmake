include(ExternalProject)

# Function to build a project from a git repo using ExternalProject_Add and import selected targets
#
# Parameters:
#   NAME                - Name of the external project
#   GIT_REPOSITORY      - URL to check out the project from
#   GIT_TAG             - Git tag/branch/commit to checkout (optional)
#   VERSION             - Version of the external project (optional)
#   TARGETS             - List of targets to import from the external project
#   INCLUDE_DIRS        - List of include directories to add to imported targets
#   EXTRA_CMAKE_ARGS    - Extra arguments to pass to the CMake configure step (optional)
#   DEPENDS             - List of other external projects this depends on (optional)
#   BUILD_BYPRODUCTS    - List of build byproducts (Ninja only)
#
function(VRGImportExternalProject)
  # Parse arguments
  set(options "")
  set(oneValueArgs NAME GIT_REPOSITORY VERSION GIT_TAG)
  set(multiValueArgs TARGETS INCLUDE_DIRS EXTRA_CMAKE_ARGS DEPENDS BUILD_BYPRODUCTS)
  cmake_parse_arguments(ARG "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

  # Validate required arguments
  if(NOT ARG_NAME)
    message(FATAL_ERROR "import_external_project: NAME parameter is required")
  endif()
  if(NOT ARG_GIT_REPOSITORY)
    message(FATAL_ERROR "import_external_project: GIT_REPOSITORY parameter is required")
  endif()
  if(NOT ARG_TARGETS)
    message(FATAL_ERROR "import_external_project: At least one target must be specified in TARGETS")
  endif()

  # Set default values for optional parameters
  if(NOT ARG_VERSION)
    set(ARG_VERSION "unknown")
  endif()

  # Define directories for the external project
  set(EP_SOURCE_DIR "${FETCHCONTENT_BASE_DIR}/${ARG_NAME}-src")
  set(EP_BINARY_DIR "${FETCHCONTENT_BASE_DIR}/${ARG_NAME}-build")
  set(EP_INSTALL_DIR ${CMAKE_INSTALL_PREFIX})

  # Basic ExternalProject_Add arguments
  set(EP_ARGS
    # extra args
    CMAKE_ARGS
      -DCMAKE_INSTALL_PREFIX:PATH=<INSTALL_DIR>
      -DCMAKE_BUILD_TYPE=${CMAKE_BUILD_TYPE}
      -DCMAKE_CXX_COMPILER=${CMAKE_CXX_COMPILER}
      -DCMAKE_C_COMPILER=${CMAKE_C_COMPILER}
      ${ARG_EXTRA_CMAKE_ARGS}
    # Don't update on each build
    UPDATE_COMMAND ""
  )

  if(ARG_GIT_TAG)
    list(APPEND EP_ARGS GIT_TAG ${ARG_GIT_TAG})
  endif()

  if(ARG_DEPENDS)
    list(APPEND EP_ARGS DEPENDS ${ARG_DEPENDS})
  endif()

  if (ARG_BUILD_BYPRODUCTS)
    list(APPEND EP_ARGS BUILD_BYPRODUCTS ${ARG_BUILD_BYPRODUCTS})
  endif()

  # Add the external project
  ExternalProject_Add(
          ${ARG_NAME}
          GIT_REPOSITORY ${ARG_GIT_REPOSITORY}
          SOURCE_DIR ${EP_SOURCE_DIR}
          BINARY_DIR ${EP_BINARY_DIR}
          INSTALL_DIR ${EP_INSTALL_DIR}
          PREFIX ${FETCHCONTENT_BASE_DIR}
          STAMP_DIR ${FETCHCONTENT_BASE_DIR}/${ARG_NAME}-ep-artifacts
          TMP_DIR ${FETCHCONTENT_BASE_DIR}/${ARG_NAME}-ep-artifacts   # needed in case CMAKE_INSTALL_PREFIX is not writable
          LIST_SEPARATOR ::
          UPDATE_DISCONNECTED 1
          BUILD_COMMAND ${CMAKE_COMMAND} --build . -v
          INSTALL_COMMAND ${CMAKE_COMMAND} -E echo "External project ${ARG_NAME} will be installed during the main project's installation."
          ${EP_ARGS})

  # Create an interface library for each target we want to import
  foreach(TARGET_NAME ${ARG_TARGETS})
    add_library(${TARGET_NAME} INTERFACE)

    # Add include directories
    foreach(INCLUDE_DIR ${ARG_INCLUDE_DIRS})
      target_include_directories(${TARGET_NAME} INTERFACE
        $<BUILD_INTERFACE:${EP_SOURCE_DIR}/${INCLUDE_DIR}>
        $<BUILD_INTERFACE:${EP_BINARY_DIR}/${INCLUDE_DIR}>
        $<INSTALL_INTERFACE:${EP_INSTALL_DIR}/${INCLUDE_DIR}>
      )
    endforeach()

    # Make sure the external project is built before any targets that use it
    add_dependencies(${TARGET_NAME} ${ARG_NAME})

    # Set imported locations for compiled libraries
    # This approach handles both static and shared libraries
    if(WIN32)
      set(LIB_PREFIX "")
      set(STATIC_LIB_SUFFIX ".lib")
      set(SHARED_LIB_SUFFIX ".dll")
    else()
      set(LIB_PREFIX "lib")
      set(STATIC_LIB_SUFFIX ".a")
      set(SHARED_LIB_SUFFIX ".so")
      if(APPLE)
        set(SHARED_LIB_SUFFIX ".dylib")
      endif()
    endif()

    # Try to find the library in standard locations
    # First check for a shared library
    set(IMPORTED_LOCATION
      "${EP_INSTALL_DIR}/lib/${LIB_PREFIX}${TARGET_NAME}${SHARED_LIB_SUFFIX}")

    # If shared library doesn't exist, try static library
    if(NOT EXISTS "${IMPORTED_LOCATION}")
      set(IMPORTED_LOCATION
        "${EP_INSTALL_DIR}/lib/${LIB_PREFIX}${TARGET_NAME}${STATIC_LIB_SUFFIX}")
    endif()

    # Set the imported location property if we found the library
    # Note: The library may not exist yet since it's built by ExternalProject_Add
    set_target_properties(${TARGET_NAME} PROPERTIES
      IMPORTED_LOCATION "${IMPORTED_LOCATION}"
    )

    # Print a message for each imported target
    message(STATUS "Imported target '${TARGET_NAME}' from ${ARG_NAME} (version=${ARG_VERSION})")
  endforeach()

endfunction()

# Example usage:
# VRGImportExternalProject(
#   NAME            json
#   GIT_REPOSITORY  https://github.com/nlohmann/json
#   GIT_TAG         v3.11.2
#   TARGETS         nlohmann_json
#   INCLUDE_DIRS    include
#   EXTRA_CMAKE_ARGS
#     -DJSON_BuildTests=OFF
#     -DJSON_MultipleHeaders=ON
# )