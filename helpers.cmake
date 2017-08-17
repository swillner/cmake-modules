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

function(get_depends_properties RESULT_NAME TARGET PROPERTIES)
  foreach(PROPERTY ${PROPERTIES})
    set(RESULT_${PROPERTY})
  endforeach()
  get_target_property(INTERFACE_LINK_LIBRARIES ${TARGET} INTERFACE_LINK_LIBRARIES)
  if(INTERFACE_LINK_LIBRARIES)
    foreach(INTERFACE_LINK_LIBRARY ${INTERFACE_LINK_LIBRARIES})
      if(TARGET ${INTERFACE_LINK_LIBRARY})
        get_depends_properties(TMP ${INTERFACE_LINK_LIBRARY} "${PROPERTIES}")
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
    set(${RESULT_NAME}_${PROPERTY} ${RESULT_${PROPERTY}} PARENT_SCOPE)
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
  set(${RESULT_NAME} ${RESULT} PARENT_SCOPE)
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
  set(${RESULT_NAME} ${RESULT} PARENT_SCOPE)
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
        set(COMMANDS)
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
          file(RELATIVE_PATH FILE ${CMAKE_CURRENT_SOURCE_DIR} ${FILE})
          add_custom_command(
            OUTPUT ${ARGS_NAME}/${FILE}
            COMMAND ${${ARGS_COMMAND}_PATH} ${LOCAL_ARGS}
            WORKING_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}"
            COMMENT "Running ${ARGS_NAME} on ${FILE}..."
            VERBATIM)
          set_source_files_properties(${ARGS_NAME}/${FILE} PROPERTIES SYMBOLIC TRUE)
          set(COMMANDS ${COMMANDS} ${ARGS_NAME}/${FILE})
        endforeach()
        add_custom_target(
          ${ARGS_NAME}
          DEPENDS ${COMMANDS}
          COMMENT "Running ${ARGS_NAME} on ${TARGET}...")
      else()
        add_custom_target(
          ${ARGS_NAME}
          COMMAND ${${ARGS_COMMAND}_PATH} ${ARGS}
          WORKING_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}"
          COMMENT "Running ${ARGS_NAME} on ${TARGET}..."
          VERBATIM)
      endif()
    endif()
  endif()
endfunction()

function(add_cpp_tools TARGET)
  set(CPP_TARGETS)

  add_on_source(${TARGET}
    NAME ${TARGET}_clang_format
    COMMAND clang-format
    ARGUMENTS -i --style=file ALL_SOURCEFILES)
  if(TARGET ${TARGET}_clang_format)
    set(CPP_TARGETS ${CPP_TARGETS} ${TARGET}_clang_format)
  endif()

  add_on_source(${TARGET}
    NAME ${TARGET}_clang_tidy
    COMMAND clang-tidy
    ARGUMENTS -quiet SOURCEFILE -- -std=c++11 INCLUDES DEFINITIONS)
  if(TARGET ${TARGET}_clang_tidy)
    set(CPP_TARGETS ${CPP_TARGETS} ${TARGET}_clang_tidy)
  endif()

  add_on_source(${TARGET}
    NAME ${TARGET}_clang_tidy_fix
    COMMAND clang-tidy
    ARGUMENTS -quiet -fix -format-style=file SOURCEFILE -- -std=c++11 INCLUDES DEFINITIONS)

  add_on_source(${TARGET}
    NAME ${TARGET}_cppcheck
    COMMAND cppcheck
    ARGUMENTS INCLUDES DEFINITIONS --quiet --template=gcc --enable=all ALL_SOURCEFILES)
  if(TARGET ${TARGET}_cppcheck)
    set(CPP_TARGETS ${CPP_TARGETS} ${TARGET}_cppcheck)
  endif()

  add_on_source(${TARGET}
    NAME ${TARGET}_cppclean
    COMMAND cppclean
    ARGUMENTS INCLUDES ALL_SOURCEFILES)
  if(TARGET ${TARGET}_cppclean)
    set(CPP_TARGETS ${CPP_TARGETS} ${TARGET}_cppclean)
  endif()

  add_on_source(${TARGET}
    NAME ${TARGET}_iwyu
    COMMAND iwyu
    ARGUMENTS -std=c++11 -I/usr/include/clang/3.8/include INCLUDES DEFINITIONS SOURCEFILE)
  if(TARGET ${TARGET}_iwyu)
    set(CPP_TARGETS ${CPP_TARGETS} ${TARGET}_iwyu)
  endif()

  if(CPP_TARGETS)
    add_custom_target(${TARGET}_cpp_tools
      DEPENDS ${CPP_TARGETS})
  endif()
endfunction()

function(get_git_version RESULT_NAME)
  if(EXISTS "${CMAKE_SOURCE_DIR}/.git" AND IS_DIRECTORY "${CMAKE_SOURCE_DIR}/.git")
    cmake_parse_arguments(ARGS "" "DIFF_OUTPUT_VARIABLE;DIFF_HASH_OUTPUT_VARIABLE" "" ${ARGN})
    find_program(HAVE_GIT git)
    mark_as_advanced(HAVE_GIT)
    if(HAVE_GIT)
      execute_process(
        COMMAND git describe --tags --dirty --always
        OUTPUT_VARIABLE GIT_OUTPUT
        OUTPUT_STRIP_TRAILING_WHITESPACE)
      string(REGEX REPLACE "^v([0-9]+\\.[0-9]+)\\.(0-)?([0-9]*)((-.+)?)$" "\\1.\\3\\4" GIT_OUTPUT "${GIT_OUTPUT}")
      set(${RESULT_NAME} ${GIT_OUTPUT} PARENT_SCOPE)
      if(ARGS_DIFF_OUTPUT_VARIABLE)
        message(STATUS "${ARGS_DIFF_OUTPUT_VARIABLE}") # TODO
        execute_process(
          COMMAND git diff HEAD --no-color
          OUTPUT_VARIABLE GIT_DIFF
          OUTPUT_STRIP_TRAILING_WHITESPACE)
        set(${ARGS_DIFF_OUTPUT_VARIABLE} ${GIT_DIFF} PARENT_SCOPE)
        if(GIT_DIFF AND ARGS_DIFF_HASH_OUTPUT_VARIABLE)
          string(MD5 GIT_DIFF_HASH "${GIT_DIFF}")
          string(SUBSTRING "${GIT_DIFF_HASH}" 0 12 GIT_DIFF_HASH)
          set(${ARGS_DIFF_HASH_OUTPUT_VARIABLE} ${GIT_DIFF_HASH} PARENT_SCOPE)
        endif()
      endif()
    endif()
  endif()
endfunction()
