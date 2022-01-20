# -*- mode: cmake -*-

###################
# Find dependencies related to ScaLAPACK
###################

if( NOT TARGET scalapackpp::scalapackpp )
  find_package( scalapackpp CONFIG QUIET HINTS ${SCALAPACKPP_ROOT_DIR} )
endif()

if( TARGET scalapackpp::scalapackpp )
  message(STATUS "Found scalapackpp CONFIG at ${scalapackpp_CONFIG}")
else()
  message(STATUS "Could not find scalapackpp! Building..." )
  cmake_minimum_required(VERSION 3.14.0)  # for FetchContent_MakeAvailable
  include(FetchContent)

  include(${CMAKE_CURRENT_LIST_FILE}/versions.cmake)

  FetchContent_Declare( scalapackpp
    GIT_REPOSITORY      https://github.com/wavefunction91/scalapackpp.git
    GIT_TAG             ${VGCMAKEKIT_TRACKED_SCALAPACKPP_TAG}
  )
  FetchContent_MakeAvailable( scalapackpp )

  # propagate MPI_CXX_SKIP_MPICXX=ON
  if (DEFINED MPI_CXX_COMPILE_DEFINITIONS)
    target_compile_definitions( blacspp     PRIVATE ${MPI_CXX_COMPILE_DEFINITIONS} )
    target_compile_definitions( scalapackpp PRIVATE ${MPI_CXX_COMPILE_DEFINITIONS} )
  endif()

  # set {blacspp,scalapackpp}_CONFIG to the install location so that we know where to find it
  set(blacspp_CONFIG ${CMAKE_INSTALL_PREFIX}/${CMAKE_INSTALL_LIBDIR}/cmake/blacspp/blacspp-config.cmake)
  set(scalapackpp_CONFIG ${CMAKE_INSTALL_PREFIX}/${CMAKE_INSTALL_LIBDIR}/cmake/scalapackpp/scalapackpp-config.cmake)
endif()
