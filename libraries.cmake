#  Copyright (C) 2018 Sven Willner <sven.willner@gmail.com>
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

function(add_system_paths)
  if(DEFINED ENV{LIBRARY_PATH})
    string(REPLACE ":" ";" LIBRARY_PATH $ENV{LIBRARY_PATH})
    set(CMAKE_LIBRARY_PATH
        ${CMAKE_LIBRARY_PATH} ${LIBRARY_PATH}
        PARENT_SCOPE
    )
  endif()
  if(DEFINED ENV{LD_LIBRARY_PATH})
    string(REPLACE ":" ";" LD_LIBRARY_PATH $ENV{LD_LIBRARY_PATH})
    set(CMAKE_LIBRARY_PATH
        ${CMAKE_LIBRARY_PATH} ${LD_LIBRARY_PATH}
        PARENT_SCOPE
    )
  endif()
endfunction()

function(include_custom_library NAME HEADER_FILE)
  include(FindPackageHandleStandardArgs)
  find_path(${NAME}_INCLUDE_DIR NAMES ${HEADER_FILE})
  find_library(${NAME}_LIBRARY NAMES ${NAME})
  find_package_handle_standard_args(${NAME} DEFAULT_MSG ${NAME}_INCLUDE_DIR ${NAME}_LIBRARY)
  mark_as_advanced(${NAME}_INCLUDE_DIR ${NAME}_LIBRARY)
  set(${NAME}_LIBRARIES ${${NAME}_LIBRARY})
  set(${NAME}_INCLUDE_DIRS ${${NAME}_INCLUDE_DIR})
  if(${NAME}_FOUND)
    add_library(${NAME} UNKNOWN IMPORTED)
    set_target_properties(${NAME} PROPERTIES INTERFACE_INCLUDE_DIRECTORIES "${${NAME}_INCLUDE_DIRS}")
    set_target_properties(${NAME} PROPERTIES IMPORTED_LINK_INTERFACE_LANGUAGES "C")
    set_target_properties(${NAME} PROPERTIES IMPORTED_LOCATION "${${NAME}_LIBRARIES}")
  endif()
endfunction()

function(include_nlopt TARGET DEFAULT)
  include(CMakeParseArguments)
  cmake_parse_arguments(ARGS "" "GIT_TAG;SOURCE_DIR" "" ${ARGN})
  option(INTERNAL_NLOPT "statically include NLopt from GitHub" ${DEFAULT})
  if(INTERNAL_NLOPT)
    include(ExternalProject)
    if(ARGS_GIT_TAG)
      set(GIT_REPOSITORY https://github.com/stevengj/nlopt.git)
      message(STATUS "Including NLopt from GitHub")
    else()
      if(ARGS_SOURCE_DIR)
        set(ARGS_SOURCE_DIR ${CMAKE_SOURCE_DIR}/${ARGS_SOURCE_DIR})
      else()
        message(FATAL_ERROR "Provide GIT_TAG or SOURCE_DIR")
      endif()
    endif()
    if(NOT TARGET nlopt)
      externalproject_add(
        nlopt
        SOURCE_DIR ${ARGS_SOURCE_DIR}
        GIT_REPOSITORY ${GIT_REPOSITORY}
        GIT_TAG ${GIT_TAG}
        INSTALL_COMMAND ""
        CMAKE_ARGS -DBUILD_SHARED_LIBS=OFF
                   -DCMAKE_BUILD_TYPE=Release
                   -DNLOPT_CXX=OFF
                   -DNLOPT_FORTRAN=OFF
                   -DNLOPT_GUILE=OFF
                   -DNLOPT_MATLAB=OFF
                   -DNLOPT_OCTAVE=OFF
                   -DNLOPT_PYTHON=OFF
                   -DNLOPT_SWIG=OFF
                   -DNLOPT_TESTS=OFF
      )
    endif()
    externalproject_get_property(nlopt SOURCE_DIR)
    externalproject_get_property(nlopt BINARY_DIR)
    include_directories(${SOURCE_DIR}/src/api)
    add_dependencies(${TARGET} nlopt)
    target_link_libraries(
      ${TARGET} PRIVATE ${BINARY_DIR}/${CMAKE_STATIC_LIBRARY_PREFIX}nlopt${CMAKE_STATIC_LIBRARY_SUFFIX}
    )
  else()
    find_package(NLOPT REQUIRED)
    message(STATUS "NLopt include directory: ${NLOPT_INCLUDE_DIR}")
    message(STATUS "NLopt library: ${NLOPT_LIBRARY}")
    target_link_libraries(${TARGET} PRIVATE nlopt)
  endif()
endfunction()

function(include_netcdf_cxx4 TARGET DEFAULT)
  find_package(NETCDF REQUIRED)
  message(STATUS "NetCDF include directory: ${NETCDF_INCLUDE_DIR}")
  message(STATUS "NetCDF library: ${NETCDF_LIBRARY}")
  include(CMakeParseArguments)
  cmake_parse_arguments(ARGS "" "GIT_TAG;SOURCE_DIR" "" ${ARGN})
  option(INTERNAL_NETCDF_CXX "statically include NetCDF C++4 from GitHub" ${DEFAULT})
  if(INTERNAL_NETCDF_CXX)
    include(ExternalProject)
    if(ARGS_GIT_TAG)
      set(GIT_REPOSITORY https://github.com/Unidata/netcdf-cxx4)
      message(STATUS "Including NetCDF C++4 from GitHub")
    else()
      if(ARGS_SOURCE_DIR)
        set(ARGS_SOURCE_DIR ${CMAKE_SOURCE_DIR}/${ARGS_SOURCE_DIR})
      else()
        message(FATAL_ERROR "Provide GIT_TAG or SOURCE_DIR")
      endif()
    endif()
    if(NOT TARGET netcdf_c++4)
      string(REPLACE ";" "$<SEMICOLON>" CMAKE_LIBRARY_PATH_STR "${CMAKE_LIBRARY_PATH}")
      externalproject_add(
        netcdf_c++4
        SOURCE_DIR ${ARGS_SOURCE_DIR}
        GIT_REPOSITORY ${GIT_REPOSITORY}
        GIT_TAG ${ARGS_GIT_TAG}
        INSTALL_COMMAND ""
        CMAKE_ARGS -DBUILD_SHARED_LIBS=OFF -DBUILD_TESTING=OFF -DCMAKE_BUILD_TYPE=Release -DNCXX_ENABLE_TESTS=OFF
                   -DCMAKE_LIBRARY_PATH=${CMAKE_LIBRARY_PATH_STR}
      )
    endif()
    externalproject_get_property(netcdf_c++4 SOURCE_DIR)
    externalproject_get_property(netcdf_c++4 BINARY_DIR)
    include_directories(${SOURCE_DIR}/cxx4)
    add_dependencies(${TARGET} netcdf_c++4)
    target_link_libraries(
      ${TARGET} PRIVATE ${BINARY_DIR}/cxx4/${CMAKE_STATIC_LIBRARY_PREFIX}netcdf-cxx4${CMAKE_STATIC_LIBRARY_SUFFIX}
    )
  else()
    find_package(NETCDF_CPP4 REQUIRED)
    message(STATUS "NetCDF C++4 include directory: ${NETCDF_CPP4_INCLUDE_DIR}")
    message(STATUS "NetCDF C++4 library: ${NETCDF_CPP4_LIBRARY}")
    target_link_libraries(${TARGET} PRIVATE netcdf_c++4)
  endif()
  target_link_libraries(${TARGET} PRIVATE netcdf)
endfunction()

function(include_yaml_cpp TARGET DEFAULT)
  include(CMakeParseArguments)
  cmake_parse_arguments(ARGS "" "GIT_TAG;SOURCE_DIR" "" ${ARGN})
  option(INTERNAL_YAML_CPP "statically include yaml-cpp from GitHub" ${DEFAULT})
  if(INTERNAL_YAML_CPP)
    include(ExternalProject)
    if(ARGS_GIT_TAG)
      set(GIT_REPOSITORY https://github.com/jbeder/yaml-cpp)
      message(STATUS "Including yaml-cpp from GitHub")
    else()
      if(ARGS_SOURCE_DIR)
        set(ARGS_SOURCE_DIR ${CMAKE_SOURCE_DIR}/${ARGS_SOURCE_DIR})
      else()
        message(FATAL_ERROR "Provide GIT_TAG or SOURCE_DIR")
      endif()
    endif()
    if(NOT TARGET yaml-cpp)
      externalproject_add(
        yaml-cpp
        SOURCE_DIR ${ARGS_SOURCE_DIR}
        GIT_REPOSITORY ${GIT_REPOSITORY}
        GIT_TAG ${ARGS_GIT_TAG}
        INSTALL_COMMAND ""
        CMAKE_ARGS -DCMAKE_BUILD_TYPE=Release -DYAML_BUILD_SHARED_LIBS=OFF -DYAML_CPP_BUILD_CONTRIB=OFF
                   -DYAML_CPP_BUILD_TESTS=OFF -DYAML_CPP_BUILD_TOOLS=OFF
      )
    endif()
    externalproject_get_property(yaml-cpp SOURCE_DIR)
    externalproject_get_property(yaml-cpp BINARY_DIR)
    include_directories(${SOURCE_DIR}/include)
    add_dependencies(${TARGET} yaml-cpp)
    target_link_libraries(
      ${TARGET} PRIVATE ${BINARY_DIR}/${CMAKE_STATIC_LIBRARY_PREFIX}yaml-cpp${CMAKE_STATIC_LIBRARY_SUFFIX}
    )
  else()
    find_package(YAML_CPP REQUIRED)
    message(STATUS "yaml-cpp include directory: ${YAML_CPP_INCLUDE_DIR}")
    message(STATUS "yaml-cpp library: ${YAML_CPP_LIBRARY}")
    target_link_libraries(${TARGET} PRIVATE yaml-cpp)
  endif()
endfunction()
