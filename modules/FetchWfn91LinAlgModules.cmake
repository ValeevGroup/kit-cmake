# - fetches github.com/ajaypanyala/linalg-cmake-modules

# prerequisites:
# 1. cmake with FetchContent
cmake_minimum_required (VERSION 3.11.0)
# 2. linalg-cmake-modules try_compile's C code
get_property(_enabled_languages GLOBAL PROPERTY ENABLED_LANGUAGES)
if (NOT C IN_LIST _enabled_languages)
    enable_language(C)
endif(NOT C IN_LIST _enabled_languages)

# download linalg-cmake-modules, if needed
include(FetchContent)
FetchContent_Declare(
        linalg-cmake-modules
        QUIET
        GIT_REPOSITORY  https://github.com/ValeevGroup/linalg-cmake-modules.git
        GIT_TAG         916be6da6702eb2d5ed1f921764256d75dc78dfd
)
FetchContent_GetProperties(linalg-cmake-modules)
if(NOT linalg-cmake-modules_POPULATED)
    FetchContent_Populate(linalg-cmake-modules)
    list(APPEND CMAKE_MODULE_PATH "${linalg-cmake-modules_SOURCE_DIR}")
endif(NOT linalg-cmake-modules_POPULATED)
