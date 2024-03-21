#
# SPDX-FileCopyrightText: 2024 Eduard Valeyev <eduard@valeyev.net>
#
# SPDX-License-Identifier: BSD-2-Clause
#

cmake_minimum_required(VERSION 3.24)  # for FETCHCONTENT_TRY_FIND_PACKAGE_MODE
include(FetchContent)

#
# VRGFindOrFetchPackage(NAME URL TAG <optional args>) - uses find_package to try finding package, if not found will use
#                           FetchContent to fetch a package from a source repo
#
# mandatory arguments:
# NAME - name of the package, given as the first argument to FetchContent_Declare
# URL - URL of the source repository; given as the value of the VCS_REPOSITORY argument of FetchContent_Declare (where VCS=GIT by default, unless overridden by the optional VCS argument)
# TAG - TAG of the source repository; given as the value of the VCS_TAG argument of FetchContent_Declare
#
# optional arguments:
# DISABLE_FIND_PACKAGE - if set, will not use find_package to try finding the package
# ADD_SUBDIR - if set and find_package failed, will add the package source tree as a subdirectory of the current project (see add_subdirectory)
# ADD_SUBDIR_EXCLUDE_FROM_ALL - if set and ADD_SUBDIR is set, will give EXCLUDE_FROM_ALL option to add_subdirectory
# VCS V - if set and find_package failed, will use V in place of GIT in GIT_REPOSITORY and GIT_TAG arguments of FetchContent_Declare
# FIND_PACKAGE_ARGS "ARG1;[ARG2]" - if DISABLE_FIND_PACKAGE is not set, pass these arguments to find_package
# CONFIG_SUBDIR VAR1=VALUE1 [VAR2=VALUE2] - if find_package failed and ADD_SUBDIR is set,  this specifies a list of CACHE variables to be set before add_subdirectory is called

# based on https://github.com/ceres-solver/ceres-solver/issues/451#issue-399000672
function(VRGFindOrFetchPackage name url tag)
    set(options DISABLE_FIND_PACKAGE ADD_SUBDIR ADD_SUBDIR_EXCLUDE_FROM_ALL)
    set(svargs VCS FIND_PACKAGE_ARGS)
    set(mvargs CONFIG_SUBDIR)
    cmake_parse_arguments(PARSE_ARGV 3 VRGFFP "${options}" "${svargs}" "${mvargs}")

    if (NOT DEFINED VRGFFP_VCS)
        set(VRGFFP_VCS "GIT")
    endif()
    set(fcd_args ${name}
            ${VRGFFP_VCS}_REPOSITORY ${url}
            ${VRGFFP_VCS}_TAG        ${tag}
            GIT_PROGRESS     ON)
    if (NOT DEFINED VRGFFP_DISABLE_FIND_PACKAGE)
        list(APPEND fcd_args FIND_PACKAGE_ARGS)
        if (DEFINED VRGFFP_FIND_PACKAGE_ARGS)
            list(APPEND fcd_args ${VRGFFP_FIND_PACKAGE_ARGS})
        endif()
    endif()

    FetchContent_Declare(
            ${fcd_args}
    )
    FetchContent_GetProperties(${name})
    if(NOT ${name}_POPULATED)
        message(STATUS "Setting up ${name} from ${url}")
        FetchContent_Populate(${name})
        if(VRGFFP_ADD_SUBDIR)
            foreach(config ${VRGFFP_CONFIG_SUBDIR})
                string(REPLACE "=" ";" configkeyval ${config})
                list(LENGTH configkeyval len)
                if (len GREATER_EQUAL 2)
                    list(GET configkeyval 0 configkey)
                    list(SUBLIST configkeyval 1 -1 configvals)
                    string(REPLACE ";" "=" configval "${configvals}")
                else()
                    message(FATAL_ERROR "Invalid config: ${configkeyval}")
                endif()
                message(STATUS "Set ${configkey} = ${configval}")
                set(${configkey} ${configval} CACHE INTERNAL "" FORCE)
            endforeach()
            set(${name}_SOURCE_DIR ${${name}_SOURCE_DIR} PARENT_SCOPE)
            set(${name}_BINARY_DIR ${${name}_BINARY_DIR} PARENT_SCOPE)
            if (VRGFFP_ADD_SUBDIR_EXCLUDE_FROM_ALL)
                add_subdirectory(${${name}_SOURCE_DIR} ${${name}_BINARY_DIR} EXCLUDE_FROM_ALL)
            else()
                add_subdirectory(${${name}_SOURCE_DIR} ${${name}_BINARY_DIR})
            endif()
        endif()
    endif()
endfunction(VRGFindOrFetchPackage)
