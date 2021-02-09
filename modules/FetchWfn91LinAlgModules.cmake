# - fetches github.com/wavefunction91/linalg-cmake-modules

cmake_minimum_required (VERSION 3.11.0)  # FetchContent
include(FetchContent)
FetchContent_Declare(
        wavefunction91_linalg_kit
        QUIET
        GIT_REPOSITORY      https://github.com/wavefunction91/linalg-cmake-modules.git
        GIT_TAG    81fa1754dc592a0b6bde98abd650a8270d74fa1b
        SOURCE_DIR ${CMAKE_CURRENT_LIST_DIR}/wfn91-linalg
)
FetchContent_GetProperties(wavefunction91_linalg_kit)
if(NOT wavefunction91_linalg_kit_POPULATED)
    FetchContent_MakeAvailable(wavefunction91_linalg_kit)
    list(APPEND CMAKE_MODULE_PATH "${wavefunction91_linalg_kit_SOURCE_DIR}")
endif(NOT wavefunction91_linalg_kit_POPULATED)
