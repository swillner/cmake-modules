#  Copyright (C) 2017 Sven Willner <sven.willner@gmail.com>
#
#  This program is free software: you can redistribute it and/or modify
#  it under the terms of the GNU Affero General Public License as published
#  by the Free Software Foundation, either version 3 of the License, or
#  (at your option) any later version.
#
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU Affero General Public License for more details.
#
#  You should have received a copy of the GNU Affero General Public License
#  along with this program.  If not, see <http://www.gnu.org/licenses/>.

set(HELPER_MODULES_PATH ${CMAKE_CURRENT_LIST_DIR})
include(CMakeParseArguments)

function(add_doxygen_documentation PATH TARGET)
  find_package(Doxygen)
  if(DOXYGEN_FOUND)
    configure_file(${CMAKE_CURRENT_SOURCE_DIR}/${PATH}/Doxyfile.in ${CMAKE_CURRENT_BINARY_DIR}/${PATH}/Doxyfile @ONLY)
    add_custom_target(
      ${TARGET}
      ${DOXYGEN_EXECUTABLE} ${CMAKE_CURRENT_BINARY_DIR}/${PATH}/Doxyfile
      WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}
      COMMENT "Generating documentation..."
      VERBATIM
    )
  endif(DOXYGEN_FOUND)
endfunction()

function(set_advanced_cpp_warnings TARGET)
  if(ARGN GREATER 1)
    option(CXX_WARNINGS ON)
  else()
    option(CXX_WARNINGS OFF)
  endif()
  if(CXX_WARNINGS)
    target_compile_options(${TARGET} PRIVATE -Wall -pedantic -Wextra -Wno-reorder)
  endif()
endfunction()

function(set_default_build_type BUILD_TYPE)
  if(${CMAKE_VERSION} VERSION_GREATER "3.8.0")
    cmake_policy(SET CMP0069 NEW) # for INTERPROCEDURAL_OPTIMIZATION
  endif()
  if(NOT CMAKE_BUILD_TYPE)
    set(CMAKE_BUILD_TYPE
        ${BUILD_TYPE}
        CACHE STRING "Choose the type of build, options are: Debug Release RelWithDebInfo MinSizeRel Profile." FORCE
    )
  endif()
  set(CMAKE_CXX_FLAGS_PROFILE
      "-pg"
      CACHE STRING "Flags used by the compiler during profile builds." FORCE
  )
  set(CMAKE_C_FLAGS_PROFILE
      "-pg"
      CACHE STRING "Flags used by the compiler during profile builds." FORCE
  )
  set(CMAKE_EXE_LINKER_FLAGS_PROFILE
      "-pg"
      CACHE STRING "Flags used by the linker during profile builds." FORCE
  )
  set(CMAKE_Fortran_FLAGS_PROFILE
      "-pg"
      CACHE STRING "Flags used by the compiler during profile builds." FORCE
  )
  set(CMAKE_MODULE_LINKER_FLAGS_PROFILE
      "-pg"
      CACHE STRING "Flags used by the linker during profile builds." FORCE
  )
  set(CMAKE_SHARED_LINKER_FLAGS_PROFILE
      "-pg"
      CACHE STRING "Flags used by the linker during profile builds." FORCE
  )
  set(CMAKE_STATIC_LINKER_FLAGS_PROFILE
      "-pg"
      CACHE STRING "Flags used by the linker during profile builds." FORCE
  )
  mark_as_advanced(
    CMAKE_CXX_FLAGS_PROFILE
    CMAKE_C_FLAGS_PROFILE
    CMAKE_EXE_LINKER_FLAGS_PROFILE
    CMAKE_Fortran_FLAGS_PROFILE
    CMAKE_MODULE_LINKER_FLAGS_PROFILE
    CMAKE_SHARED_LINKER_FLAGS_PROFILE
    CMAKE_STATIC_LINKER_FLAGS_PROFILE
  )
endfunction()

function(set_build_type_specifics TARGET)
  if(CMAKE_BUILD_TYPE STREQUAL "Release"
     OR CMAKE_BUILD_TYPE STREQUAL "RelWithDebInfo"
     OR CMAKE_BUILD_TYPE STREQUAL "MinSizeRel"
     OR CMAKE_BUILD_TYPE STREQUAL "Profile"
  )
    if(${CMAKE_VERSION} VERSION_GREATER "3.8.0")
      message(STATUS "Enabling interprocedural optimization")
      set_property(TARGET ${TARGET} PROPERTY INTERPROCEDURAL_OPTIMIZATION TRUE)
    endif()
    target_compile_definitions(${TARGET} PUBLIC NDEBUG)
  else()
    target_compile_definitions(${TARGET} PRIVATE DEBUG)
  endif()
endfunction()

function(set_advanced_options)
  find_program(CCACHE_FOUND ccache)
  if(CCACHE_FOUND)
    option(USE_CCACHE "Use ccache" OFF)
    if(USE_CCACHE)
      set_property(GLOBAL PROPERTY RULE_LAUNCH_COMPILE ccache)
      set_property(GLOBAL PROPERTY RULE_LAUNCH_LINK ccache)
    endif()
    mark_as_advanced(USE_CCACHE)
  endif()

  option(PREFER_STATIC_LINKING "Prefer static linking" OFF)
  if(PREFER_STATIC_LINKING)
    set(CMAKE_FIND_LIBRARY_SUFFIXES
        "${CMAKE_STATIC_LIBRARY_SUFFIX};${CMAKE_SHARED_LIBRARY_SUFFIX}"
        PARENT_SCOPE
    )
  endif()
  mark_as_advanced(PREFER_STATIC_LINKING)
endfunction()

function(get_depends_properties RESULT_NAME TARGET PROPERTIES)
  foreach(PROPERTY ${PROPERTIES})
    set(RESULT_${PROPERTY})
  endforeach()
  get_target_property(TARGET_TYPE ${TARGET} TYPE)
  if(TARGET_TYPE STREQUAL "EXECUTABLE")
    get_target_property(LIBRARIES ${TARGET} LINK_LIBRARIES)
  else()
    get_target_property(LIBRARIES ${TARGET} INTERFACE_LINK_LIBRARIES)
  endif()
  if(LIBRARIES)
    foreach(LIBRARY ${LIBRARIES})
      if(TARGET ${LIBRARY})
        get_depends_properties(TMP ${LIBRARY} "${PROPERTIES}")
        foreach(PROPERTY ${PROPERTIES})
          set(RESULT_${PROPERTY} ${RESULT_${PROPERTY}} ${TMP_${PROPERTY}})
        endforeach()
      endif()
    endforeach()
  endif()
  foreach(PROPERTY ${PROPERTIES})
    get_target_property(TMP ${TARGET} ${PROPERTY})
    if(TMP)
      set(RESULT_${PROPERTY} ${RESULT_${PROPERTY}} ${TMP})
    endif()
    set(${RESULT_NAME}_${PROPERTY}
        ${RESULT_${PROPERTY}}
        PARENT_SCOPE
    )
  endforeach()
endfunction()

function(get_all_include_directories RESULT_NAME TARGET)
  get_depends_properties(RESULT ${TARGET} "INTERFACE_INCLUDE_DIRECTORIES;INTERFACE_SYSTEM_INCLUDE_DIRECTORIES")
  set(RESULT ${RESULT_INTERFACE_INCLUDE_DIRECTORIES} ${RESULT_INTERFACE_SYSTEM_INCLUDE_DIRECTORIES})
  get_target_property(INCLUDE_DIRECTORIES ${TARGET} INCLUDE_DIRECTORIES)
  if(INCLUDE_DIRECTORIES)
    set(RESULT ${RESULT} ${INCLUDE_DIRECTORIES})
  endif()
  if(RESULT)
    list(REMOVE_DUPLICATES RESULT)
  endif()
  set(${RESULT_NAME}
      ${RESULT}
      PARENT_SCOPE
  )
endfunction()

function(get_all_compile_definitions RESULT_NAME TARGET)
  get_depends_properties(RESULT ${TARGET} "INTERFACE_COMPILE_DEFINITIONS")
  set(RESULT ${RESULT_INTERFACE_COMPILE_DEFINITIONS})
  get_target_property(COMPILE_DEFINITIONS ${TARGET} COMPILE_DEFINITIONS)
  if(COMPILE_DEFINITIONS)
    set(RESULT ${RESULT} ${COMPILE_DEFINITIONS})
  endif()
  if(RESULT)
    list(REMOVE_DUPLICATES RESULT)
  endif()
  set(${RESULT_NAME}
      ${RESULT}
      PARENT_SCOPE
  )
endfunction()

function(add_on_source TARGET)
  cmake_parse_arguments(ARGS "" "COMMAND;NAME" "ARGUMENTS" ${ARGN})
  if(ARGS_COMMAND)
    if(NOT ARGS_NAME)
      set(ARGS_NAME ${TARGET}_${ARGS_COMMAND})
    endif()
    find_program(${ARGS_COMMAND}_PATH ${ARGS_COMMAND})
    mark_as_advanced(${ARGS_COMMAND}_PATH)
    if(${ARGS_COMMAND}_PATH)
      set(ARGS)
      set(PER_SOURCEFILE FALSE)

      foreach(ARG ${ARGS_ARGUMENTS})
        if(${ARG} STREQUAL "INCLUDES")
          get_all_include_directories(INCLUDE_DIRECTORIES ${TARGET})
          if(INCLUDE_DIRECTORIES)
            foreach(INCLUDE_DIRECTORY ${INCLUDE_DIRECTORIES})
              set(ARGS ${ARGS} "-I${INCLUDE_DIRECTORY}")
            endforeach()
          endif()
        elseif(${ARG} STREQUAL "DEFINITIONS")
          get_all_compile_definitions(COMPILE_DEFINITIONS ${TARGET})
          if(COMPILE_DEFINITIONS)
            foreach(COMPILE_DEFINITION ${COMPILE_DEFINITIONS})
              set(ARGS ${ARGS} "-D${COMPILE_DEFINITION}")
            endforeach()
          endif()
        elseif(${ARG} STREQUAL "ALL_SOURCEFILES")
          get_target_property(SOURCES ${TARGET} SOURCES)
          set(ARGS ${ARGS} ${SOURCES})
        elseif(${ARG} STREQUAL "SOURCEFILE")
          set(ARGS ${ARGS} ${ARG})
          set(PER_SOURCEFILE TRUE)
        else()
          set(ARGS ${ARGS} ${ARG})
        endif()
      endforeach()

      if(PER_SOURCEFILE)
        get_target_property(SOURCES ${TARGET} SOURCES)
        add_custom_target(${ARGS_NAME} COMMENT "Running ${ARGS_NAME} on ${TARGET}...")
        foreach(FILE ${SOURCES})
          set(LOCAL_ARGS)
          foreach(ARG ${ARGS})
            if(${ARG} STREQUAL "SOURCEFILE")
              set(LOCAL_ARGS ${LOCAL_ARGS} ${FILE})
            else()
              set(LOCAL_ARGS ${LOCAL_ARGS} ${ARG})
            endif()
          endforeach()
          file(GLOB FILE ${FILE})
          if(FILE)
            file(RELATIVE_PATH FILE ${CMAKE_CURRENT_SOURCE_DIR} ${FILE})
            add_custom_command(
              TARGET ${ARGS_NAME}
              COMMAND ${${ARGS_COMMAND}_PATH} ${LOCAL_ARGS}
              WORKING_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}"
              COMMENT "Running ${ARGS_NAME} on ${FILE}..."
              VERBATIM
            )
            set_source_files_properties(${ARGS_NAME}/${FILE} PROPERTIES SYMBOLIC TRUE)
          endif()
        endforeach()
      else()
        add_custom_target(
          ${ARGS_NAME}
          COMMAND ${${ARGS_COMMAND}_PATH} ${ARGS}
          WORKING_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}"
          COMMENT "Running ${ARGS_NAME} on ${TARGET}..."
          VERBATIM
        )
      endif()
    endif()
  endif()
endfunction()

function(add_cpp_tools TARGET)
  cmake_parse_arguments(ARGS "" "STD" "" ${ARGN})
  if(NOT ARGS_STD)
    set(ARGS_STD "c++11")
  endif()

  set(CPP_TARGETS)

  add_on_source(
    ${TARGET}
    NAME ${TARGET}_clang_format
    COMMAND clang-format
    ARGUMENTS -i --style=file ALL_SOURCEFILES
  )
  if(TARGET ${TARGET}_clang_format)
    set(CPP_TARGETS ${CPP_TARGETS} ${TARGET}_clang_format)
  endif()

  add_on_source(
    ${TARGET}
    NAME ${TARGET}_clang_tidy
    COMMAND clang-tidy
    ARGUMENTS -quiet SOURCEFILE -- -std=${ARGS_STD} INCLUDES DEFINITIONS
  )
  if(TARGET ${TARGET}_clang_tidy)
    set(CPP_TARGETS ${CPP_TARGETS} ${TARGET}_clang_tidy)

    add_on_source(
      ${TARGET}
      NAME ${TARGET}_clang_tidy_fix
      COMMAND clang-tidy
      ARGUMENTS -quiet
                -fix
                -format-style=file
                SOURCEFILE
                --
                -std=${ARGS_STD}
                INCLUDES
                DEFINITIONS
    )
  endif()

  add_on_source(
    ${TARGET}
    NAME ${TARGET}_cppcheck
    COMMAND cppcheck
    ARGUMENTS INCLUDES DEFINITIONS --quiet --template=gcc --enable=all ALL_SOURCEFILES
  )
  if(TARGET ${TARGET}_cppcheck)
    set(CPP_TARGETS ${CPP_TARGETS} ${TARGET}_cppcheck)
  endif()

  add_on_source(
    ${TARGET}
    NAME ${TARGET}_cppclean
    COMMAND cppclean
    ARGUMENTS INCLUDES SOURCEFILE
  )

  add_on_source(
    ${TARGET}
    NAME ${TARGET}_vera
    COMMAND vera++
    ARGUMENTS --warning --no-duplicate --show-rule ALL_SOURCEFILES
  )
  if(TARGET ${TARGET}_vera)
    set(CPP_TARGETS ${CPP_TARGETS} ${TARGET}_vera)
  endif()

  get_target_property(INCLUDE_DIRECTORIES ${TARGET} INCLUDE_DIRECTORIES)
  add_on_source(
    ${TARGET}
    NAME ${TARGET}_flint
    COMMAND flint++
    ARGUMENTS -v -r ALL_SOURCEFILES ${INCLUDE_DIRECTORIES}
  )
  if(TARGET ${TARGET}_flint)
    set(CPP_TARGETS ${CPP_TARGETS} ${TARGET}_flint)
  endif()

  if(CPP_TARGETS)
    add_custom_target(${TARGET}_cpp_tools DEPENDS ${CPP_TARGETS})
  endif()
endfunction()

function(add_git_version TARGET)
  cmake_parse_arguments(ARGS "" "DPREFIX;FALLBACK_VERSION;NAMESPACE" "" ${ARGN})
  if(NOT ARGS_DPREFIX)
    string(MAKE_C_IDENTIFIER "${TARGET}" ARGS_DPREFIX)
    string(TOUPPER ${ARGS_DPREFIX} ARGS_DPREFIX)
  endif()
  if(NOT ARGS_NAMESPACE)
    string(MAKE_C_IDENTIFIER "${TARGET}" ARGS_NAMESPACE)
    string(TOLOWER ${ARGS_NAMESPACE} ARGS_NAMESPACE)
  endif()

  file(
    WRITE ${CMAKE_CURRENT_BINARY_DIR}/include/version.h
    "\
#ifndef ${ARGS_DPREFIX}_VERSION_H
#define ${ARGS_DPREFIX}_VERSION_H

namespace ${ARGS_NAMESPACE} {

extern const char* version;
extern const char* git_diff;
constexpr bool has_diff = false;

}  // namespace ${ARGS_NAMESPACE}

#endif"
  )
  set_source_files_properties(
    ${CMAKE_CURRENT_BINARY_DIR}/include/version.h PROPERTIES GENERATED TRUE HEADER_FILE_ONLY TRUE
  )
  target_include_directories(${TARGET} PRIVATE ${CMAKE_CURRENT_BINARY_DIR}/include)

  file(
    WRITE ${CMAKE_CURRENT_BINARY_DIR}/src/version.cpp
    "\
namespace ${ARGS_NAMESPACE} {

const char* version = \"${ARGS_FALLBACK_VERSION}\";
const char* git_diff = \"\";

}  // namespace ${ARGS_NAMESPACE}
"
  )
  set_source_files_properties(${CMAKE_CURRENT_BINARY_DIR}/src/version.cpp PROPERTIES GENERATED TRUE)
  target_sources(${TARGET} PUBLIC ${CMAKE_CURRENT_BINARY_DIR}/src/version.cpp)

  if(EXISTS "${CMAKE_SOURCE_DIR}/.git" AND IS_DIRECTORY "${CMAKE_SOURCE_DIR}/.git")
    find_program(HAVE_GIT git)
    mark_as_advanced(HAVE_GIT)
    if(HAVE_GIT)
      add_custom_target(
        ${TARGET}_version ALL
        COMMAND
          ${CMAKE_COMMAND} -DARGS_BINARY_DIR=${CMAKE_CURRENT_BINARY_DIR} -DARGS_DPREFIX=${ARGS_DPREFIX}
          -DARGS_NAMESPACE=${ARGS_NAMESPACE} -DARGS_SOURCE_DIR=${CMAKE_CURRENT_SOURCE_DIR} -P
          ${HELPER_MODULES_PATH}/git_version.cmake
      )
      add_dependencies(${TARGET} ${TARGET}_version)
    else()
      if(NOT ARGS_FALLBACK_VERSION)
        message(FATAL_ERROR "Could not get version: Git not found")
      endif()
    endif()
  else()
    if(NOT ARGS_FALLBACK_VERSION)
      message(FATAL_ERROR "Could not get version: Not in a git repository")
    endif()
  endif()
endfunction()
