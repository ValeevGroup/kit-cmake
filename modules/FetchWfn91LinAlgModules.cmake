# - fetches github.com/wavefunction91/linalg-cmake-modules

# prerequisites:
# 1. cmake with FetchContent
cmake_minimum_required (VERSION 3.11.0)
# 2. wavefunction91_linalg_kit try_compile's C code
get_property(_enabled_languages GLOBAL PROPERTY ENABLED_LANGUAGES)
if (NOT C IN_LIST _enabled_languages)
    enable_language(C)
endif(NOT C IN_LIST _enabled_languages)

# download wavefunction91_linalg_kit, if needed
include(FetchContent)
FetchContent_Declare(
        wavefunction91_linalg_kit
        QUIET
        GIT_REPOSITORY      https://github.com/wavefunction91/linalg-cmake-modules.git
        GIT_TAG    81fa1754dc592a0b6bde98abd650a8270d74fa1b
)
FetchContent_GetProperties(wavefunction91_linalg_kit)
if(NOT wavefunction91_linalg_kit_POPULATED)
    FetchContent_MakeAvailable(wavefunction91_linalg_kit)
    list(APPEND CMAKE_MODULE_PATH "${wavefunction91_linalg_kit_SOURCE_DIR}")
endif(NOT wavefunction91_linalg_kit_POPULATED)
