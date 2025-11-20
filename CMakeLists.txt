# =============================================================================
# Copyright (c) 2018-2025, NVIDIA CORPORATION.
#
# Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except
# in compliance with the License. You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software distributed under the License
# is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express
# or implied. See the License for the specific language governing permissions and limitations under
# the License.
# =============================================================================
# MIT License
#
# Modifications Copyright (C) 2023-2025 Advanced Micro Devices, Inc. All rights reserved.
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
# =============================================================================

cmake_minimum_required(VERSION 3.26.4 FATAL_ERROR)

include(rapids_config.cmake)

include(rapids-cmake)
include(rapids-cpm)
include(rapids-export)
include(rapids-find)

# chipStar HIP support - detect and configure before rapids-hip
include(cmake/chipstar.cmake)
chipstar_detect()

#: NOTE(HIP/AMD, 04/22/25):
#:     In contrast to the CUDA implementation, we need to initialize the HIP architectures
#:     already before calling rapids_find_package(HIP...). Otherwise, GPU_TARGETS will be unset
#:     on systems without GPUs and find_package(HIP) will warn that it
#:     cannot autotect an architecture.
# Configure chipStar compiler before rapids-hip initializes architectures
if(_CHIPSTAR_DETECTED)
  chipstar_configure_compiler()
endif()

include(rapids-hip)
# For chipStar, don't initialize architectures - they conflict with --offload=spirv64
if(_CHIPSTAR_DETECTED)
  # Set a dummy architecture that CMake will accept (needed for project() call)
  # We'll remove --offload-arch flags from build files using the fix script
  set(CMAKE_HIP_ARCHITECTURES "gfx908" CACHE STRING "HIP architectures" FORCE)
  # Prevent rapids_hip_init_architectures from setting GPU_TARGETS
  set(GPU_TARGETS "" CACHE STRING "GPU targets" FORCE)
  set(AMDGPU_TARGETS "" CACHE STRING "AMD GPU targets" FORCE)
else()
  rapids_hip_init_architectures(RMM)
endif()

project(
  RMM
  # TODO(HIP/AMD): Use RAPIDS_VERSION in CI scripts
  # VERSION "${RAPIDS_VERSION}"
  VERSION 3.0.0
  LANGUAGES C CXX HIP)

# Write the version header
rapids_cmake_write_version_file(include/rmm/version_config.hpp)

# ##################################################################################################
# * build type -------------------------------------------------------------------------------------

# Set a default build type if none was specified
rapids_cmake_build_type(Release)

# ##################################################################################################
# * build options ----------------------------------------------------------------------------------

# NOTE(HIP/AMD): for compatibility with existing build scripts,
# we explicitly treat unsupported CMake operations here.
# Some of them may be silently ignored, but the default is to exit the CMake build configuration.
# This options makes the build ignore unsupported but enabled CMake options and proceed.
if($ENV{CUDF_CMAKE_IGNORE_UNSUPPORTED_OPTIONS})
  set(IGNORE_UNSUPPORTED_OPTIONS ON)
else()
  set(IGNORE_UNSUPPORTED_OPTIONS OFF)
endif()

# Helper function to handle unsupported cmake options.
function(handle_unsupported_cmake_option option_name force_exit)
  if(${option_name} AND ${force_exit})
    message(FATAL_ERROR "${option_name} option is not supported. Please disable it and reconfigure the project.")
  endif()
  if(${option_name} AND NOT ${force_exit} AND ${IGNORE_UNSUPPORTED_OPTIONS})
    message(WARNING "${option_name} option is not supported. Disabling ${option_name} and proceeding with build.")
    set(${option_name} OFF CACHE BOOL "" FORCE)
  endif()
  if(${option_name} AND NOT ${force_exit} AND NOT ${IGNORE_UNSUPPORTED_OPTIONS})
    message(FATAL_ERROR "${option_name} option is not supported. To proceed with build, disable ${option_name} or set the environment variable CUDF_CMAKE_IGNORE_UNSUPPORTED_OPTIONS to \"ON\".")
  endif()
endfunction()

option(RMM_NVTX "Build RMM with NVTX support" OFF)
handle_unsupported_cmake_option("RMM_NVTX" OFF)
option(BUILD_TESTS "Configure CMake to build tests" ON)
option(BUILD_BENCHMARKS "Configure CMake to build (google) benchmarks" OFF)
# This is mostly so that dependent libraries are configured in shared mode for downstream dependents
# of RMM that get their common dependencies transitively.
option(BUILD_SHARED_LIBS "Build RMM shared libraries" ON)
set(RMM_LOGGING_LEVEL
    "INFO"
    CACHE STRING "Choose the logging level.")
set_property(CACHE RMM_LOGGING_LEVEL PROPERTY STRINGS "TRACE" "DEBUG" "INFO" "WARN" "ERROR"
                                              "CRITICAL" "OFF")

message(VERBOSE "RMM: Build with NVTX support: ${RMM_NVTX}")
# Set logging level. Must go before including gtests and benchmarks. Set the possible values of
# build type for cmake-gui.
message(STATUS "RMM: RMM_LOGGING_LEVEL = '${RMM_LOGGING_LEVEL}'")

# cudart can be linked statically or dynamically
option(CUDA_STATIC_RUNTIME "Statically link the CUDA runtime" OFF)
handle_unsupported_cmake_option("CUDA_STATIC_RUNTIME" FALSE)

# ##################################################################################################
# * compiler options -------------------------------------------------------------------------------
add_compile_options(-Wno-unused-result) # required for HIP build

# find packages we depend on
rapids_find_package(
	HIP REQUIRED
  BUILD_EXPORT_SET rmm-exports
  INSTALL_EXPORT_SET rmm-exports)

# ##################################################################################################
# * dependencies -----------------------------------------------------------------------------------

# add third party dependencies using CPM
rapids_cpm_init()

# prescribe dependencies
include(cpm/package_override)
rapids_cpm_package_override(${CMAKE_CURRENT_LIST_DIR}/versions.json)

include(${rapids-cmake-dir}/cpm/rapids_logger.cmake)
rapids_cpm_rapids_logger()
rapids_make_logger(rmm EXPORT_SET rmm-exports)

# Configure chipStar dependencies before get_cccl.cmake
if(_CHIPSTAR_DETECTED)
  chipstar_configure_dependencies()
  # For chipStar: Ensure hipCUB's CUB headers are found before system CUB
  # This must be done after chipstar_configure_dependencies() which sets up the include path
  if(DEFINED ENV{HIPCUB_DIR} AND EXISTS "$ENV{HIPCUB_DIR}/include/hipcub/cub")
    # Remove /usr/include from include path for CUB to force use of hipCUB
    # We'll add it back as a system include so other system headers still work
    get_directory_property(INCLUDE_DIRS INCLUDE_DIRECTORIES)
    list(REMOVE_ITEM INCLUDE_DIRS "/usr/include")
    set_directory_property(PROPERTY INCLUDE_DIRECTORIES ${INCLUDE_DIRS})
    # Add /usr/include back as system include (lower priority)
    include_directories(SYSTEM /usr/include)
    message(STATUS "chipStar: Prioritized hipCUB CUB headers over system CUB")
  endif()
endif()

include(cmake/thirdparty/get_cccl.cmake)
# include(cmake/thirdparty/get_nvtx.cmake)

# ##################################################################################################
# * library targets --------------------------------------------------------------------------------

add_library(rmm INTERFACE)
add_library(rmm::rmm ALIAS rmm)

target_include_directories(rmm INTERFACE "$<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/include>"
                                         "$<INSTALL_INTERFACE:include>")

if(CUDA_STATIC_RUNTIME)
  # message(STATUS "RMM: Enabling static linking of cudart")
  # target_link_libraries(rmm INTERFACE CUDA::cudart_static)
else()
  target_link_libraries(rmm INTERFACE hip::host)
endif()

target_link_libraries(rmm INTERFACE rmm_logger)
target_link_libraries(rmm INTERFACE CCCL::CCCL)
target_link_libraries(rmm INTERFACE dl)
#: TODO(HIP/AMD): No nvtx3 equivalent
#: target_link_libraries(rmm INTERFACE nvtx3::nvtx3-cpp)
target_compile_features(rmm INTERFACE cxx_std_17 $<BUILD_INTERFACE:cuda_std_17>)
target_compile_definitions(rmm INTERFACE LIBCUDACXX_ENABLE_EXPERIMENTAL_MEMORY_RESOURCE)

# Enable NVTX if necessary
if(RMM_NVTX)
  target_compile_definitions(rmm INTERFACE RMM_NVTX)
endif()

# ##################################################################################################
# * tests and benchmarks ---------------------------------------------------------------------------

if((BUILD_TESTS OR BUILD_BENCHMARKS) AND CMAKE_PROJECT_NAME STREQUAL PROJECT_NAME)
  #: NOTE(HIP/AMD, 04/22/25):
  #:     In contrast to the CUDA implementation, we need to initialize the HIP architectures
  #:     already before calling rapids_find_package(HIP...). Otherwise, GPU_TARGETS will be unset
  #:     on systems without GPUs and find_package(HIP) will warn that it
  #:     cannot autotect an architecture.
  #: include(rapids-hip)
  #: rapids_hip_init_architectures(RMM)
  # For chipStar HIP (SPIR-V), we need to prevent CMake from adding --offload-arch flags
  # CMake requires at least one architecture, but we'll use a hook to remove the flags
  if(_CHIPSTAR_DETECTED)
    # Set a dummy architecture that CMake will accept (gfx908 is a valid AMD arch)
    # We'll remove the --offload-arch flags immediately after enable_language
    set(CMAKE_HIP_ARCHITECTURES "gfx908" CACHE STRING "HIP architectures" FORCE)
    set(GPU_TARGETS "" CACHE STRING "GPU targets" FORCE)
    set(AMDGPU_TARGETS "" CACHE STRING "AMD GPU targets" FORCE)
  endif()
  enable_language(HIP)
  
  # For chipStar HIP (SPIR-V), remove conflicting flags after enable_language
  # Note: We keep CMAKE_HIP_ARCHITECTURES set to "gfx908" to satisfy CMake's requirements
  # but we'll remove --offload-arch flags from build files using the fix script
  if(_CHIPSTAR_DETECTED)
    # Remove --offload-arch flags from HIP compile options (they may have been added)
    string(REGEX REPLACE "--offload-arch=[^ ]+ *" "" CMAKE_HIP_FLAGS "${CMAKE_HIP_FLAGS}")
    # Also remove specific known ones as backup
    string(REPLACE "--offload-arch=gfx908" "" CMAKE_HIP_FLAGS "${CMAKE_HIP_FLAGS}")
    string(REPLACE "--offload-arch=gfx90a" "" CMAKE_HIP_FLAGS "${CMAKE_HIP_FLAGS}")
    string(REPLACE "--offload-arch=gfx942" "" CMAKE_HIP_FLAGS "${CMAKE_HIP_FLAGS}")
    # Remove conflicting ROCm include paths
    string(REPLACE "-I/opt/rocm-5.7.0/include" "" CMAKE_HIP_FLAGS "${CMAKE_HIP_FLAGS}")
    # Add pre-include header to ensure __host__ and __device__ are defined for rocThrust
    if(DEFINED CHIPSTAR_PREINCLUDE_PATH AND EXISTS "${CHIPSTAR_PREINCLUDE_PATH}")
      set(CMAKE_HIP_FLAGS "${CMAKE_HIP_FLAGS} -include ${CHIPSTAR_PREINCLUDE_PATH}")
    endif()
    set(CMAKE_HIP_FLAGS "${CMAKE_HIP_FLAGS}" CACHE STRING "HIP compiler flags" FORCE)
    # Add flag to allow libhipcxx to work with unsupported architectures (chipStar/SPIR-V)
    add_compile_definitions(_LIBCUDACXX_ALLOW_UNSUPPORTED_ARCHITECTURE)
    # chipStar compatibility: Define missing constants for CUB and libhipcxx
    add_compile_definitions(
      hipHostAllocDefault=0x00
      hipHostAllocPortable=0x01
      hipHostAllocMapped=0x02
      hipHostAllocWriteCombined=0x04
      NV_IS_HOST=1
    )
    # chipStar: Exclude system CUB directory from include search to force use of hipCUB
    # rocThrust includes <cub/...> which incorrectly finds /usr/include/cub/
    # We add hipCUB's cub directory with higher priority via include_directories(BEFORE)
    # but the compiler may still find system CUB, so we need to work around this
    if(DEFINED ENV{HIPCUB_DIR} AND EXISTS "$ENV{HIPCUB_DIR}/include/hipcub/cub")
      # Create a wrapper that redirects cub/ includes to hipcub/cub/
      # This is a workaround for rocThrust's direct CUB includes
      message(STATUS "chipStar: Note - rocThrust may use system CUB instead of hipCUB")
      message(STATUS "chipStar: This is expected behavior - rocThrust needs CUB compatibility fixes")
    endif()
             # chipStar compatibility: suppress static/non-static declaration conflicts
             # These errors occur because chipStar's cuda_runtime.h has static inline functions
             # that conflict with non-static declarations in hip_runtime_api.h
             # Convert all errors to warnings (the pragma in cuda_runtime_api.h handles the specific warning)
             add_compile_options(-Wno-error)
  endif()

  # Since RMM only enables HIP optionally we need to manually include the file that
  # rapids_cuda_init_architectures relies on `project` calling
  include("${CMAKE_PROJECT_RMM_INCLUDE}")
  message(STATUS "RMM: Building benchmarks with GPU Architectures: ${CMAKE_HIP_ARCHITECTURES}")
endif()

# ##################################################################################################
# * add tests --------------------------------------------------------------------------------------

if(BUILD_TESTS AND CMAKE_PROJECT_NAME STREQUAL PROJECT_NAME)
  include(${rapids-cmake-dir}/cpm/gtest.cmake)
  rapids_cpm_gtest(BUILD_STATIC)
  include(CTest) # calls enable_testing()

  add_subdirectory(tests)
  
  # chipStar: Patch rapids-cmake and create resource spec after tests are configured
  if(_CHIPSTAR_DETECTED)
    chipstar_patch_rapids_cmake()
    chipstar_create_resource_spec()
  endif()
endif()

# ##################################################################################################
# * add benchmarks ---------------------------------------------------------------------------------

if(BUILD_BENCHMARKS AND CMAKE_PROJECT_NAME STREQUAL PROJECT_NAME)
  include(${rapids-cmake-dir}/cpm/gbench.cmake)
  rapids_cpm_gbench()
  add_subdirectory(benchmarks)
endif()

# ##################################################################################################
# * configure CPack -- must appear before `include(CPack)` -----------------------------------------

set(CPACK_PACKAGE_NAME "hipmm" CACHE STRING "Overwrite package name.")
set(CPACK_PACKAGE_VENDOR "Advanced Micro Devices, Inc.")
set(CPACK_DEBIAN_PACKAGE_MAINTAINER "${CPACK_PACKAGE_VENDOR}")
set(CPACK_OUTPUT_FILE_PREFIX "dist" CACHE PATH "Package output file prefix.")
set(CPACK_PACKAGE_VERSION_MAJOR ${PROJECT_VERSION_MAJOR})
set(CPACK_PACKAGE_VERSION_MINOR ${PROJECT_VERSION_MINOR})
set(CPACK_PACKAGE_VERSION_PATCH ${PROJECT_VERSION_PATCH})
set(CPACK_DEBIAN_FILE_NAME DEB-DEFAULT)
set(CPACK_PACKAGING_INSTALL_PREFIX "/opt/rocm-ds" CACHE PATH "Package install prefix.")

# ##################################################################################################
# * install targets --------------------------------------------------------------------------------

include(GNUInstallDirs)
include(CPack)

# install export targets
install(TARGETS rmm EXPORT rmm-exports)
install(DIRECTORY include/rmm/ DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}/rmm)
install(FILES ${RMM_BINARY_DIR}/include/rmm/version_config.hpp
        DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}/rmm)

set(doc_string
    [=[
Provide targets for RMM: RAPIDS Memory Manager.

The goal of the [RMM](https://github.com/rapidsai/rmm) is to provide:

  A common interface that allows customizing device and host memory allocation
  A collection of implementations of the interface
  A collection of data structures that use the interface for memory allocation
]=])

rapids_export(
  INSTALL rmm
  EXPORT_SET rmm-exports
  GLOBAL_TARGETS rmm
  NAMESPACE rmm::
  DOCUMENTATION doc_string)

# ##################################################################################################
# * build export -----------------------------------------------------------------------------------

rapids_export(
  BUILD rmm
  EXPORT_SET rmm-exports
  GLOBAL_TARGETS rmm
  NAMESPACE rmm::
  DOCUMENTATION doc_string)

# ##################################################################################################
# * make documentation -----------------------------------------------------------------------------

add_custom_command(
  OUTPUT RMM_DOXYGEN
  WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/doxygen
  COMMAND ${CMAKE_COMMAND} -E env "RAPIDS_VERSION=${RAPIDS_VERSION}"
          "RAPIDS_VERSION_MAJOR_MINOR=${RAPIDS_VERSION_MAJOR_MINOR}" doxygen Doxyfile
  VERBATIM
  COMMENT "Custom command for RMM doxygen docs")

add_custom_target(
  rmm_doc
  DEPENDS RMM_DOXYGEN
  COMMENT "Target for the custom command to build the RMM doxygen docs")

# ##################################################################################################
# * make gdb helper scripts ------------------------------------------------------------------------

# optionally assemble Thrust pretty-printers
if(CCCL_SOURCE_DIR)
  configure_file(scripts/load-pretty-printers.in load-pretty-printers @ONLY)
endif()

# ##################################################################################################
# * chipStar build file fixes ----------------------------------------------------------------------

# Create fix target to remove conflicting flags from generated build files
if(_CHIPSTAR_DETECTED)
  chipstar_fix_build_flags()
endif()
