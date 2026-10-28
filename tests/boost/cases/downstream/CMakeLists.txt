# Plays an installed consumer's *-config.cmake: includes the Boost_CONFIG_FILE_CONTENTS an
# upstream case wrote (CASE_SNIPPET) and checks that the targets in CASE_TARGETS exist.
cmake_minimum_required(VERSION 3.25)
project(fofb_downstream LANGUAGES CXX)
include(${CMAKE_CURRENT_LIST_DIR}/../isolate.cmake)
include(${CASE_SNIPPET})
foreach(_t IN LISTS CASE_TARGETS)
  if (NOT TARGET Boost::${_t})
    message(FATAL_ERROR "CHECK: downstream lacks Boost::${_t}")
  endif()
endforeach()
message(STATUS "RESULT downstream=OK")
