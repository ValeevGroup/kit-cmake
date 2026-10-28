# cmake -DGLOBS=<g1,g2,...> -P check_files.cmake: each glob must match a file
string(REPLACE "," ";" GLOBS "${GLOBS}")
foreach(_g IN LISTS GLOBS)
  file(GLOB _m "${_g}")
  if (NOT _m)
    message(FATAL_ERROR "CHECK: nothing matches ${_g}")
  endif()
endforeach()
message(STATUS "RESULT files=OK")
