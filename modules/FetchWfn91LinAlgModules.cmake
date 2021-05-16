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
        GIT_REPOSITORY  https://github.com/ajaypanyala/linalg-cmake-modules.git 
        GIT_TAG         f6629057033a9dd31416b259f83233340106fa78 
)
FetchContent_GetProperties(wavefunction91_linalg_kit)
if(NOT wavefunction91_linalg_kit_POPULATED)
    FetchContent_Populate(wavefunction91_linalg_kit)
    list(APPEND CMAKE_MODULE_PATH "${wavefunction91_linalg_kit_SOURCE_DIR}")
endif(NOT wavefunction91_linalg_kit_POPULATED)
