# hide system/Homebrew/registry packages from find_package so only CMAKE_PREFIX_PATH is searched;
# include after project() so compilers/build tools are still found
set(CMAKE_FIND_USE_CMAKE_SYSTEM_PATH OFF)
set(CMAKE_FIND_USE_SYSTEM_ENVIRONMENT_PATH OFF)
set(CMAKE_FIND_USE_PACKAGE_REGISTRY OFF)
set(CMAKE_FIND_USE_SYSTEM_PACKAGE_REGISTRY OFF)
# CASE_* list arguments arrive comma-separated
foreach(_v CASE_REQUIRED CASE_OPTIONAL CASE_TARGETS)
  string(REPLACE "," ";" ${_v} "${${_v}}")
endforeach()
