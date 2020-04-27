####### Compilers
include(${CMAKE_CURRENT_LIST_DIR}/_llvm.cmake)
include(${CMAKE_CURRENT_LIST_DIR}/_mpi.cmake)

####### Compile flags
include(${CMAKE_CURRENT_LIST_DIR}/_std_c_flags.cmake)
include(${CMAKE_CURRENT_LIST_DIR}/_std_cxx_flags.cmake)

####### Eigen
include(${CMAKE_CURRENT_LIST_DIR}/_eigen.cmake)

####### Boost
include(${CMAKE_CURRENT_LIST_DIR}/_boost.cmake)

####### BLAS/LAPACK Libraries
set(INTEGER4 TRUE CACHE BOOL "Set Fortran integer size to 4 bytes")
set(BUILD_SHARED_LIBS OFF CACHE BOOL "Build shared libraries")
include(${CMAKE_CURRENT_LIST_DIR}/_accelerate.cmake)

####### Platform-specific bits
set(ENABLE_MKL OFF CACHE BOOL "Whether to enable the use of Intel MKL")
set(BTAS_USE_CBLAS_LAPACKE OFF CACHE BOOL "Whether BTAS needs CBLAS/LAPACKE")
