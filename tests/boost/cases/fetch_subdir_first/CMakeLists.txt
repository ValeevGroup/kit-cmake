# the top-level project does not use FindOrFetchBoost itself (e.g. FetchContent'ing TiledArray); a subproject fetches Boost
cmake_minimum_required(VERSION 3.25)
project(fofb_subdir_first LANGUAGES CXX)
include(${CMAKE_CURRENT_LIST_DIR}/../isolate.cmake)
include(${CMAKE_CURRENT_LIST_DIR}/../result.cmake)
add_subdirectory(sub)
