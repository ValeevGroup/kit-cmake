# Fake CMake-harness-style BoostConfig.cmake: every component is its own boost_<c> package;
# this install lacks boost_container_hash.
find_package(boost_headers 1.90.0 EXACT CONFIG REQUIRED HINTS "${CMAKE_CURRENT_LIST_DIR}/..")
foreach(_c IN LISTS Boost_FIND_COMPONENTS)
  find_package(boost_${_c} 1.90.0 EXACT CONFIG QUIET HINTS "${CMAKE_CURRENT_LIST_DIR}/..")
  set(Boost_${_c}_FOUND ${boost_${_c}_FOUND})
  if(NOT boost_${_c}_FOUND AND Boost_FIND_REQUIRED_${_c})
    set(Boost_FOUND FALSE)
    set(Boost_NOT_FOUND_MESSAGE "Failed to find required component ${_c}")
  endif()
endforeach()
