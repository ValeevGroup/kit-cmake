project(fofb_superbuild_sub LANGUAGES CXX)
set(Boost_REQUIRED_COMPONENTS headers random serialization test callable_traits)
include(${vg_cmake_kit_SOURCE_DIR}/modules/FindOrFetchBoost.cmake)
fofb_print_result("RESULT sub")
