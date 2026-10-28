# fake per-library config: Boost::headers only
if(NOT TARGET Boost::headers)
  add_library(Boost::headers INTERFACE IMPORTED)
endif()
