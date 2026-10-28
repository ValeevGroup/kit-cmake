# Generic FindOrFetchBoost case. Inputs (-D): CASE_REQUIRED, CASE_OPTIONAL (;-lists of components),
# CASE_FETCH (ON/OFF), CASE_FLOOR (oldest Boost version), CASE_CHECK_SHIM (ON to assert shim target shape).
cmake_minimum_required(VERSION 3.25)
project(fofb_case LANGUAGES CXX)
include(${CMAKE_CURRENT_LIST_DIR}/../isolate.cmake)

set(Boost_REQUIRED_COMPONENTS "${CASE_REQUIRED}")
set(Boost_OPTIONAL_COMPONENTS "${CASE_OPTIONAL}")
set(Boost_FETCH_IF_MISSING ${CASE_FETCH})
set(Boost_OLDEST_BOOST_VERSION ${CASE_FLOOR})
include(${vg_cmake_kit_SOURCE_DIR}/modules/FindOrFetchBoost.cmake)

include(${CMAKE_CURRENT_LIST_DIR}/../result.cmake)
fofb_print_result("RESULT")
file(WRITE ${CMAKE_BINARY_DIR}/boost-snippet.cmake "${Boost_CONFIG_FILE_CONTENTS}")

if (CASE_CHECK_SHIM)
  get_target_property(_ll Boost::container_hash INTERFACE_LINK_LIBRARIES)
  if (NOT _ll STREQUAL "Boost::headers")
    message(FATAL_ERROR "CHECK: Boost::container_hash links '${_ll}', expected Boost::headers")
  endif()
  get_target_property(_g Boost::random IMPORTED_GLOBAL)
  if (NOT _g)
    message(FATAL_ERROR "CHECK: Boost::random is not IMPORTED_GLOBAL")
  endif()
  message(STATUS "CHECK shim OK")
endif()
