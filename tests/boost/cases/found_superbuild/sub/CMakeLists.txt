project(fofb_found_superbuild_sub LANGUAGES CXX)
set(Boost_REQUIRED_COMPONENTS headers container serialization)
include(${vg_cmake_kit_SOURCE_DIR}/modules/FindOrFetchBoost.cmake)
fofb_print_result("RESULT sub")
