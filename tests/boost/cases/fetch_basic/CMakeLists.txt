# Boost fetched (none findable): builds a program using several Boost libraries, installs Boost,
# writes Boost_CONFIG_FILE_CONTENTS for the downstream case.
cmake_minimum_required(VERSION 3.25)
project(fofb_fetch_basic LANGUAGES CXX)
include(${CMAKE_CURRENT_LIST_DIR}/../isolate.cmake)
set(CMAKE_CXX_STANDARD 17)

# iostreams is required but not linked: exercises Boost_MODULAR_TARGETS_NOT_BUILT_BY_INSTALL
set(Boost_REQUIRED_COMPONENTS headers container_hash random serialization spirit test filesystem iostreams)
set(Boost_FETCH_IF_MISSING ON)
set(Boost_OLDEST_BOOST_VERSION 1.81)
include(${vg_cmake_kit_SOURCE_DIR}/modules/FindOrFetchBoost.cmake)

# under MSVC Boost.Assert adds its debugger visualizer from libs/assert/extra to the interface sources; do the same
# elsewhere so that its installation is tested on every platform
if (NOT MSVC)
  target_sources(boost_assert PUBLIC ${boost_SOURCE_DIR}/libs/assert/extra/boost_assert.natvis)
endif()

include(${CMAKE_CURRENT_LIST_DIR}/../result.cmake)
fofb_print_result("RESULT")
file(WRITE ${CMAKE_BINARY_DIR}/boost-snippet.cmake "${Boost_CONFIG_FILE_CONTENTS}")

add_executable(fofb_main main.cpp)
target_link_libraries(fofb_main PRIVATE Boost::container_hash Boost::random Boost::serialization Boost::spirit
                      Boost::filesystem Boost::unit_test_framework)
# same artificial dependence the consumer packages add
foreach(_t IN LISTS Boost_MODULAR_TARGETS_NOT_BUILT_BY_INSTALL)
  if (TARGET boost_${_t})
    add_dependencies(fofb_main boost_${_t})
  endif()
endforeach()
