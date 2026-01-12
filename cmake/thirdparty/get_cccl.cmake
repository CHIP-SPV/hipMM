# =============================================================================
# Copyright (c) 2023, NVIDIA CORPORATION.
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

# Use CPM to find or clone CCCL
function(find_and_configure_cccl)

  # Find rocthrust and rocprim before CCCL tries to find them via CPM
  # This ensures they're available when CPMFindPackage runs in subprocess
  # HIP must be found first since rocprim depends on it
  # Set HIP_DIR before any find_dependency(HIP) calls to ensure chipStar HIP is used
  if(DEFINED ENV{HIP_DIR})
    set(HIP_DIR "$ENV{HIP_DIR}" CACHE PATH "HIP directory" FORCE)
    # Also set as normal variable and environment variable so find_dependency can find it
    set(HIP_DIR "$ENV{HIP_DIR}")
    set(ENV{HIP_DIR} "$ENV{HIP_DIR}")
    find_package(HIP PATHS "$ENV{HIP_DIR}" NO_DEFAULT_PATH)
    message(STATUS "HIP found: ${HIP_FOUND}, HIP_DIR: ${HIP_DIR}")
  endif()
  if(DEFINED ENV{ROCPRIM_DIR})
    set(rocprim_DIR "$ENV{ROCPRIM_DIR}" CACHE PATH "rocPRIM directory" FORCE)
    # Set HIP_DIR in environment before finding rocprim so its find_dependency(HIP) uses chipStar
    if(DEFINED ENV{HIP_DIR})
      set(ENV{HIP_DIR} "$ENV{HIP_DIR}")
    endif()
    find_package(rocprim PATHS "$ENV{ROCPRIM_DIR}" NO_DEFAULT_PATH)
    message(STATUS "rocprim found: ${rocprim_FOUND}, rocprim_DIR: ${rocprim_DIR}")
  endif()
  if(DEFINED ENV{ROCTHRUST_DIR})
    set(rocthrust_DIR "$ENV{ROCTHRUST_DIR}" CACHE PATH "rocThrust directory" FORCE)
    if(NOT TARGET roc::rocthrust)
      find_package(rocthrust 3.3.0 PATHS "$ENV{ROCTHRUST_DIR}" NO_DEFAULT_PATH)
      message(STATUS "rocthrust found: ${rocthrust_FOUND}, rocthrust_DIR: ${rocthrust_DIR}")
    endif()
  endif()
  
  # Find hipCUB if available
  if(DEFINED ENV{HIPCUB_DIR})
    # hipCUB module sets HIPCUB_DIR to root, try to find cmake path
    if(EXISTS "$ENV{HIPCUB_DIR}/lib/cmake/hipcub")
      set(hipcub_DIR "$ENV{HIPCUB_DIR}/lib/cmake/hipcub" CACHE PATH "hipCUB directory" FORCE)
      find_package(hipcub PATHS "$ENV{HIPCUB_DIR}/lib/cmake/hipcub" NO_DEFAULT_PATH)
      message(STATUS "hipcub found: ${hipcub_FOUND}, hipcub_DIR: ${hipcub_DIR}")
    endif()
  endif()

  include(${rapids-cmake-dir}/cpm/cccl.cmake)
  rapids_cpm_cccl(BUILD_EXPORT_SET rmm-exports INSTALL_EXPORT_SET rmm-exports)

  # Apply chipStar/SPIR-V patch to libhipcxx for chrono support
  if(DEFINED libhipcxx_SOURCE_DIR)
    set(_config_file "${libhipcxx_SOURCE_DIR}/include/cuda/std/detail/libcxx/include/__config")
    if(EXISTS "${_config_file}")
      file(READ "${_config_file}" _config_content)
      if(NOT _config_content MATCHES "__HIP_PLATFORM_SPIRV__")
        message(STATUS "Patching libhipcxx __config for chipStar/SPIR-V chrono support")
        string(REPLACE
          "#        define _LIBCUDACXX_HIP_TSC_NANOSECONDS_PER_CYCLE 10 // (1/_LIBCUDACXX_HIP_TSC_CLOCKRATE)
//       The clock rate on other architectures"
          "#        define _LIBCUDACXX_HIP_TSC_NANOSECONDS_PER_CYCLE 10 // (1/_LIBCUDACXX_HIP_TSC_CLOCKRATE)
// chipStar/SPIR-V: Assume 100 MHz clock rate for timing APIs
#      elif defined(__HIP_PLATFORM_SPIRV__) || defined(__SPIRV__)
#        define _LIBCUDACXX_HIP_TSC_CLOCKRATE 100000000
#        define _LIBCUDACXX_HIP_TSC_NANOSECONDS_PER_CYCLE 10
//       The clock rate on other architectures"
          _config_content "${_config_content}")
        file(WRITE "${_config_file}" "${_config_content}")
      endif()
    endif()
  endif()

endfunction()

find_and_configure_cccl()
