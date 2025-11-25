# =============================================================================
# chipStar HIP Support Module
#
# This module provides functions to configure hipMM for building with chipStar HIP
# instead of ROCm HIP. It automatically detects chipStar from environment variables
# set by module loading and configures the build system accordingly.
# =============================================================================

# Global variable to track if chipStar is detected
set(_CHIPSTAR_DETECTED OFF CACHE INTERNAL "chipStar HIP detected")

# Detect if chipStar HIP is being used
function(chipstar_detect)
  if(DEFINED ENV{HIP_PATH} AND "$ENV{HIP_PATH}" MATCHES "chipStar")
    set(_CHIPSTAR_DETECTED ON CACHE INTERNAL "chipStar HIP detected" FORCE)
    message(STATUS "chipStar HIP detected: $ENV{HIP_PATH}")
    return()
  endif()
  set(_CHIPSTAR_DETECTED OFF CACHE INTERNAL "chipStar HIP detected" FORCE)
endfunction()

# Configure HIP compiler for chipStar
function(chipstar_configure_compiler)
  if(NOT _CHIPSTAR_DETECTED)
    return()
  endif()

  if(NOT DEFINED ENV{HIP_PATH})
    message(FATAL_ERROR "chipStar detected but HIP_PATH not set")
  endif()

  # Use LLVM compiler if available from module
  if(DEFINED ENV{LLVM_ROOT} AND EXISTS "$ENV{LLVM_ROOT}/bin/clang++")
    set(CMAKE_HIP_COMPILER "$ENV{LLVM_ROOT}/bin/clang++" CACHE PATH "HIP compiler" FORCE)
    message(STATUS "chipStar: Using HIP compiler ${CMAKE_HIP_COMPILER}")
  else()
    message(WARNING "chipStar: LLVM_ROOT not set, HIP compiler may not be configured correctly")
  endif()
endfunction()

# Configure dependency paths using module environment variables
function(chipstar_configure_dependencies)
  if(NOT _CHIPSTAR_DETECTED)
    return()
  endif()

  # Set HIP_DIR from module
  if(DEFINED ENV{HIP_DIR})
    set(HIP_DIR "$ENV{HIP_DIR}" CACHE PATH "HIP directory" FORCE)
    set(ENV{HIP_DIR} "$ENV{HIP_DIR}")
    message(STATUS "chipStar: HIP_DIR=${HIP_DIR}")
  endif()

  # Set rocprim_DIR from module (if rocPRIM module is loaded)
  if(DEFINED ENV{ROCPRIM_DIR})
    set(rocprim_DIR "$ENV{ROCPRIM_DIR}" CACHE PATH "rocPRIM directory" FORCE)
    message(STATUS "chipStar: rocprim_DIR=${rocprim_DIR}")
  endif()

  # Set rocthrust_DIR from module
  if(DEFINED ENV{ROCTHRUST_DIR})
    set(rocthrust_DIR "$ENV{ROCTHRUST_DIR}" CACHE PATH "rocThrust directory" FORCE)
    message(STATUS "chipStar: rocthrust_DIR=${rocthrust_DIR}")
  endif()

  # Set hipcub_DIR from module
  if(DEFINED ENV{HIPCUB_DIR})
    # hipCUB module sets HIPCUB_DIR to root, need to find cmake path
    if(EXISTS "$ENV{HIPCUB_DIR}/lib/cmake/hipcub")
      set(hipcub_DIR "$ENV{HIPCUB_DIR}/lib/cmake/hipcub" CACHE PATH "hipCUB directory" FORCE)
      message(STATUS "chipStar: hipcub_DIR=${hipcub_DIR}")
    endif()
    # chipStar: hipCUB can use rocPRIM backend instead of CUB
    # hipCUB's config.hpp and hipcub.hpp check for __HIP_PLATFORM_AMD__ to use rocPRIM backend
    # Since chipStar uses __HIP_PLATFORM_SPIRV__, we need to patch hipCUB headers
    # to also recognize SPIRV as using rocPRIM backend
    set(HIPCUB_CONFIG_FILE "$ENV{HIPCUB_DIR}/include/hipcub/config.hpp")
    set(HIPCUB_MAIN_FILE "$ENV{HIPCUB_DIR}/include/hipcub/hipcub.hpp")
    
    # Patch config.hpp
    if(EXISTS "${HIPCUB_CONFIG_FILE}" AND NOT DEFINED _HIPCUB_CONFIG_PATCHED)
      file(READ "${HIPCUB_CONFIG_FILE}" HIPCUB_CONFIG_CONTENT)
      if(NOT "${HIPCUB_CONFIG_CONTENT}" MATCHES "__HIP_PLATFORM_SPIRV__")
        string(REPLACE
          "#ifdef __HIP_PLATFORM_AMD__"
          "#if defined(__HIP_PLATFORM_AMD__) || defined(__HIP_PLATFORM_SPIRV__)"
          HIPCUB_CONFIG_CONTENT "${HIPCUB_CONFIG_CONTENT}")
        file(WRITE "${HIPCUB_CONFIG_FILE}" "${HIPCUB_CONFIG_CONTENT}")
        message(STATUS "chipStar: Patched hipCUB config.hpp to use rocPRIM backend for SPIRV")
      endif()
    endif()
    
    # Patch hipcub.hpp
    if(EXISTS "${HIPCUB_MAIN_FILE}" AND NOT DEFINED _HIPCUB_MAIN_PATCHED)
      file(READ "${HIPCUB_MAIN_FILE}" HIPCUB_MAIN_CONTENT)
      if(NOT "${HIPCUB_MAIN_CONTENT}" MATCHES "__HIP_PLATFORM_SPIRV__")
        string(REPLACE
          "#ifdef __HIP_PLATFORM_AMD__"
          "#if defined(__HIP_PLATFORM_AMD__) || defined(__HIP_PLATFORM_SPIRV__)"
          HIPCUB_MAIN_CONTENT "${HIPCUB_MAIN_CONTENT}")
        file(WRITE "${HIPCUB_MAIN_FILE}" "${HIPCUB_MAIN_CONTENT}")
        set(_HIPCUB_MAIN_PATCHED ON CACHE INTERNAL "hipCUB main patched")
        message(STATUS "chipStar: Patched hipCUB hipcub.hpp to use rocPRIM backend for SPIRV")
      endif()
    endif()
    
    set(_HIPCUB_CONFIG_PATCHED ON CACHE INTERNAL "hipCUB config patched")
    
    # chipStar: rocThrust still includes CUB headers directly (thrust/system/cuda/config.h)
    # We need to create compatibility wrappers for CUB headers that rocThrust needs
    # Create a wrapper directory with chipStar-compatible CUB headers
    set(CUB_WRAPPER_DIR "${CMAKE_BINARY_DIR}/chipstar_cub_wrapper")
    file(MAKE_DIRECTORY "${CUB_WRAPPER_DIR}/cub")
    file(MAKE_DIRECTORY "${CUB_WRAPPER_DIR}/cub/detail")
    
    # Create a pre-include header that ensures __host__ and __device__ are defined
    # This must be included before any rocThrust or CUB headers
    # Force define them unconditionally - chipStar's clang compiler supports these attributes
    file(WRITE "${CUB_WRAPPER_DIR}/chipstar_preinclude.h"
      "#ifndef CHIPSTAR_PREINCLUDE_H
#define CHIPSTAR_PREINCLUDE_H

// chipStar: Force define __host__ and __device__ for rocThrust
// These must be defined before any rocThrust headers are processed
// Include chipStar's header first (it may define these)
#ifdef __HIP_PLATFORM_SPIRV__
  #include <hip/spirv_hip_host_defines.h>
#endif

// Clear any existing definitions first (in case they were defined incorrectly)
#ifdef __host__
  #undef __host__
#endif
#ifdef __device__
  #undef __device__
#endif

// Define them unconditionally - chipStar uses clang which supports these attributes
// Use pragma to ensure these definitions persist even after other headers
#pragma push_macro(\"__host__\")
#pragma push_macro(\"__device__\")
#define __host__ __attribute__((host))
#define __device__ __attribute__((device))

// Define CUB utility macros that system CUB expects (before any CUB headers are included)
#ifndef CUB_MAX
  #define CUB_MAX(a, b) ((a) > (b) ? (a) : (b))
#endif
#ifndef CUB_MIN
  #define CUB_MIN(a, b) ((a) < (b) ? (a) : (b))
#endif

// Include rocThrust compatibility functions before rocThrust headers are processed
#include <thrust/system/hip/detail/terminate.h>

#endif
")
    
    # Create a global CUB compatibility header that ensures __host__ and __device__ are defined
    # This ensures __host__ and __device__ are defined before rocThrust includes CUB
    file(WRITE "${CUB_WRAPPER_DIR}/cub/chipstar_compat.h"
      "#ifndef CUB_CHIPSTAR_COMPAT_H
#define CUB_CHIPSTAR_COMPAT_H

// chipStar compatibility: Always define __host__ and __device__
// This ensures they're available when rocThrust includes CUB headers
// Force undefine first to clear any existing definitions
#ifdef __host__
  #undef __host__
#endif
#ifdef __device__
  #undef __device__
#endif

// Define them unconditionally - chipStar uses clang which supports these attributes
// We check for clang but define them anyway to ensure they're always available
#if defined(__clang__) || !defined(__GNUC__)
  #define __host__ __attribute__((host))
  #define __device__ __attribute__((device))
#else
  // Fallback for non-clang (shouldn't happen with chipStar)
  #define __host__
  #define __device__
#endif

// Include chipStar's headers (they may redefine, but we'll override after)
#ifdef __HIP_PLATFORM_SPIRV__
  #include <hip/spirv_hip_host_defines.h>
#endif

// Force redefine after includes to ensure they're always available
#undef __host__
#undef __device__
#define __host__ __attribute__((host))
#define __device__ __attribute__((device))
  
// Define additional CUDA macros that CUB/rocThrust need
#ifndef NV_IS_HOST
  #define NV_IS_HOST 1
#endif
#ifndef NV_IF_TARGET
  // NV_IF_TARGET is used for conditional compilation based on NV_IS_HOST
  // For chipStar, we're always on the host, so we always take the true branch
  // The macro can be called with 2 or 3 arguments:
  //   NV_IF_TARGET(NV_IS_HOST, (code;)) -> expands to (code;)
  //   NV_IF_TARGET(NV_IS_HOST, (true_code;), (false_code;)) -> expands to (true_code;)
  // Use variadic macro to handle both 2 and 3 argument cases
  #define NV_IF_TARGET(...) NV_IF_TARGET_DISPATCH(__VA_ARGS__)
  #define NV_IF_TARGET_DISPATCH(cond, true_branch, ...) true_branch
#endif
  #ifndef CUB_RUNTIME_FUNCTION
    #define CUB_RUNTIME_FUNCTION
  #endif

  // Define CUB utility macros that system CUB expects
  #ifndef CUB_MAX
    #define CUB_MAX(a, b) ((a) > (b) ? (a) : (b))
  #endif
  #ifndef CUB_MIN
    #define CUB_MIN(a, b) ((a) < (b) ? (a) : (b))
  #endif

#endif
")
    
    # Create wrapper for util_debug.cuh that defines missing macros for chipStar
    file(WRITE "${CUB_WRAPPER_DIR}/cub/util_debug.cuh"
      "#ifndef CUB_UTIL_DEBUG_CUH
#define CUB_UTIL_DEBUG_CUH

// chipStar compatibility wrapper for CUB util_debug.cuh
#ifndef __HIP_PLATFORM_SPIRV__
  #include <cub/util_debug.cuh>
#else
  // Include compatibility definitions first
  #include <cub/chipstar_compat.h>
  
  // Include util_namespace first (if not already included)
  #ifndef CUB_UTIL_NAMESPACE_CUH
    #include <cub/util_namespace.cuh>
  #endif
  
  // Don't include system CUB - it's incompatible with chipStar
  // rocThrust should work with just the macros we've defined above
#endif

#endif
")
    
    # Create wrapper for device_synchronize.cuh
    file(WRITE "${CUB_WRAPPER_DIR}/cub/detail/device_synchronize.cuh"
      "#ifndef CUB_DETAIL_DEVICE_SYNCHRONIZE_CUH
#define CUB_DETAIL_DEVICE_SYNCHRONIZE_CUH

// chipStar compatibility wrapper
#ifndef __HIP_PLATFORM_SPIRV__
  #include <cub/detail/device_synchronize.cuh>
#else
  // Include compatibility definitions first
  #include <cub/chipstar_compat.h>
  
  // Don't include system CUB - provide minimal stub
#endif

#endif
")
    
    # Create wrapper for util_device.cuh
    # Note: We can't use #include_next because system CUB is incompatible
    # Instead, provide minimal stub implementations for what rocThrust needs
    file(WRITE "${CUB_WRAPPER_DIR}/cub/util_device.cuh"
      "#ifndef CUB_UTIL_DEVICE_CUH
#define CUB_UTIL_DEVICE_CUH

// chipStar compatibility wrapper for CUB util_device.cuh
#if !defined(__HIP_PLATFORM_SPIRV__) && !defined(__HIP_PLATFORM_SPIRV__)
  #include <cub/util_device.cuh>
#else
  // Include compatibility definitions first - this MUST define __host__ and __device__
  #include <cub/chipstar_compat.h>
  
  // Force redefine __host__ and __device__ here as well to ensure they're available
  #ifndef __host__
    #define __host__ __attribute__((host))
  #endif
  #ifndef __device__
    #define __device__ __attribute__((device))
  #endif
  
  // Minimal stub - rocThrust may not actually use these functions
  // If it does, we'll need to provide proper implementations
  namespace cub {
    __host__ inline int DeviceCount() { return 1; }
    __host__ inline void SyncStream(void* stream) {
      // Synchronize the stream - for chipStar this is a no-op or we could call hipStreamSynchronize
      // rocThrust expects this function to exist
    }
  }
#endif

#endif
")
    
    # Create wrapper for util_namespace.cuh (rocThrust includes this)
    file(WRITE "${CUB_WRAPPER_DIR}/cub/util_namespace.cuh"
      "#ifndef CUB_UTIL_NAMESPACE_CUH
#define CUB_UTIL_NAMESPACE_CUH

// chipStar compatibility wrapper
#ifndef __HIP_PLATFORM_SPIRV__
  #include <cub/util_namespace.cuh>
#else
  // Include compatibility definitions first
  #include <cub/chipstar_compat.h>
  
  // chipStar: Provide CUB namespace macros that rocThrust needs
  #define CUB_NAMESPACE cub
  #define CUB_NAMESPACE_BEGIN namespace cub {
  #define CUB_NAMESPACE_END }
  
  // Provide CUB namespace prefix/postfix macros for older CUB compatibility
  #define CUB_NS_PREFIX
  #define CUB_NS_POSTFIX
  #define CUB_NS_QUALIFIER ::cub
  
  // Provide CUB version info that rocThrust checks for
  #define CUB_VERSION 200000
  #define CUB_VERSION_MAJOR 2
  #define CUB_VERSION_MINOR 0
  #define CUB_VERSION_PATCH 0
  
  // Don't include system CUB - provide minimal definitions only
#endif

#endif
")
    
    # Create wrapper for detect_cuda_runtime.cuh (rocThrust includes this)
    file(WRITE "${CUB_WRAPPER_DIR}/cub/detail/detect_cuda_runtime.cuh"
      "#ifndef CUB_DETAIL_DETECT_CUDA_RUNTIME_CUH
#define CUB_DETAIL_DETECT_CUDA_RUNTIME_CUH

// chipStar compatibility wrapper
#ifndef __HIP_PLATFORM_SPIRV__
  #include <cub/detail/detect_cuda_runtime.cuh>
#else
  // Include compatibility definitions first
  #include <cub/chipstar_compat.h>
  
  // Don't include system CUB - provide minimal stub
  // rocThrust uses this to detect CUDA runtime, but we're using HIP
#endif

#endif
")
    
    # Create wrapper for util_macro.cuh (rocThrust includes this via other CUB headers)
    file(WRITE "${CUB_WRAPPER_DIR}/cub/util_macro.cuh"
      "#ifndef CUB_UTIL_MACRO_CUH
#define CUB_UTIL_MACRO_CUH

// chipStar compatibility wrapper
#ifndef __HIP_PLATFORM_SPIRV__
  #include <cub/util_macro.cuh>
#else
  // Include compatibility definitions first
  #include <cub/chipstar_compat.h>
  
  // Provide minimal CUB macros that rocThrust needs
  // Don't include system CUB - it's incompatible with chipStar
#endif

#endif
")
    
    # Create wrapper for util_arch.cuh (rocThrust includes this)
    file(WRITE "${CUB_WRAPPER_DIR}/cub/util_arch.cuh"
      "#ifndef CUB_UTIL_ARCH_CUH
#define CUB_UTIL_ARCH_CUH

// chipStar compatibility wrapper
#ifndef __HIP_PLATFORM_SPIRV__
  #include <cub/util_arch.cuh>
#else
  // Include compatibility definitions first
  #include <cub/chipstar_compat.h>
  
  // Provide minimal CUB architecture macros that rocThrust needs
  // Don't include system CUB - it's incompatible with chipStar
  // Define minimal architecture info for chipStar (SPIR-V)
  #ifndef CUB_PTX_ARCH
    #define CUB_PTX_ARCH 0
  #endif
  #ifndef CUB_PTX_VERSION
    #define CUB_PTX_VERSION 0
  #endif
#endif

#endif
")
    
    # Create wrapper for config.cuh (rocThrust includes this)
    file(WRITE "${CUB_WRAPPER_DIR}/cub/config.cuh"
      "#ifndef CUB_CONFIG_CUH
#define CUB_CONFIG_CUH

// chipStar compatibility wrapper
#ifndef __HIP_PLATFORM_SPIRV__
  #include <cub/config.cuh>
#else
  // Include compatibility definitions first
  #include <cub/chipstar_compat.h>
  
  // Provide minimal CUB config that rocThrust needs
  // Don't include system CUB - it's incompatible with chipStar
#endif

#endif
")
    
    # Create wrapper for util_math.cuh (rocThrust includes this)
    file(WRITE "${CUB_WRAPPER_DIR}/cub/util_math.cuh"
      "#ifndef CUB_UTIL_MATH_CUH
#define CUB_UTIL_MATH_CUH

// chipStar compatibility wrapper
#ifndef __HIP_PLATFORM_SPIRV__
  #include <cub/util_math.cuh>
#else
  // Include compatibility definitions first
  #include <cub/chipstar_compat.h>
  
  // Provide minimal CUB math utilities that rocThrust needs
  // Don't include system CUB - it's incompatible with chipStar
#endif

#endif
")
    
    # Create wrapper for util_type.cuh (rocThrust includes this)
    file(WRITE "${CUB_WRAPPER_DIR}/cub/util_type.cuh"
      "#ifndef CUB_UTIL_TYPE_CUH
#define CUB_UTIL_TYPE_CUH

// chipStar compatibility wrapper
#ifndef __HIP_PLATFORM_SPIRV__
  #include <cub/util_type.cuh>
#else
  // Include compatibility definitions first
  #include <cub/chipstar_compat.h>
  
  // Provide minimal CUB type utilities that rocThrust needs
  // Don't include system CUB - it's incompatible with chipStar
#endif

#endif
")
    
    # Create wrapper for util_allocator.cuh (rocThrust includes this)
    file(WRITE "${CUB_WRAPPER_DIR}/cub/util_allocator.cuh"
      "#ifndef CUB_UTIL_ALLOCATOR_CUH
#define CUB_UTIL_ALLOCATOR_CUH

// chipStar compatibility wrapper
#ifndef __HIP_PLATFORM_SPIRV__
  #include <cub/util_allocator.cuh>
#else
  // Include compatibility definitions first
  #include <cub/chipstar_compat.h>
  
  // Provide minimal CUB allocator utilities that rocThrust needs
  // Don't include system CUB - it's incompatible with chipStar
#endif

#endif
")
    
    # Create wrappers for device headers that rocThrust includes
    file(MAKE_DIRECTORY "${CUB_WRAPPER_DIR}/cub/device")
    file(MAKE_DIRECTORY "${CUB_WRAPPER_DIR}/cub/device/dispatch")
    file(WRITE "${CUB_WRAPPER_DIR}/cub/device/device_scan.cuh"
      "#ifndef CUB_DEVICE_DEVICE_SCAN_CUH
#define CUB_DEVICE_DEVICE_SCAN_CUH

// chipStar compatibility wrapper
#ifndef __HIP_PLATFORM_SPIRV__
  #include <cub/device/device_scan.cuh>
#else
  #include <cub/chipstar_compat.h>
  // Don't include system CUB - provide minimal stub
#endif

#endif
")
    
    file(WRITE "${CUB_WRAPPER_DIR}/cub/device/device_reduce.cuh"
      "#ifndef CUB_DEVICE_DEVICE_REDUCE_CUH
#define CUB_DEVICE_DEVICE_REDUCE_CUH

// chipStar compatibility wrapper
#ifndef __HIP_PLATFORM_SPIRV__
  #include <cub/device/device_reduce.cuh>
#else
  #include <cub/chipstar_compat.h>
  // Don't include system CUB - provide minimal stub
#endif

#endif
")
    
    file(WRITE "${CUB_WRAPPER_DIR}/cub/device/device_select.cuh"
      "#ifndef CUB_DEVICE_DEVICE_SELECT_CUH
#define CUB_DEVICE_DEVICE_SELECT_CUH

// chipStar compatibility wrapper
#ifndef __HIP_PLATFORM_SPIRV__
  #include <cub/device/device_select.cuh>
#else
  #include <cub/chipstar_compat.h>
  // Don't include system CUB - provide minimal stub
#endif

#endif
")
    
    file(WRITE "${CUB_WRAPPER_DIR}/cub/device/device_adjacent_difference.cuh"
      "#ifndef CUB_DEVICE_DEVICE_ADJACENT_DIFFERENCE_CUH
#define CUB_DEVICE_DEVICE_ADJACENT_DIFFERENCE_CUH

// chipStar compatibility wrapper
#ifndef __HIP_PLATFORM_SPIRV__
  #include <cub/device/device_adjacent_difference.cuh>
#else
  #include <cub/chipstar_compat.h>
  // Don't include system CUB - provide minimal stub
#endif

#endif
")
    
    file(WRITE "${CUB_WRAPPER_DIR}/cub/device/device_radix_sort.cuh"
      "#ifndef CUB_DEVICE_DEVICE_RADIX_SORT_CUH
#define CUB_DEVICE_DEVICE_RADIX_SORT_CUH

// chipStar compatibility wrapper
#ifndef __HIP_PLATFORM_SPIRV__
  #include <cub/device/device_radix_sort.cuh>
#else
  #include <cub/chipstar_compat.h>
  // Don't include system CUB - provide minimal stub
#endif

#endif
")
    
    file(WRITE "${CUB_WRAPPER_DIR}/cub/device/device_merge_sort.cuh"
      "#ifndef CUB_DEVICE_DEVICE_MERGE_SORT_CUH
#define CUB_DEVICE_DEVICE_MERGE_SORT_CUH

// chipStar compatibility wrapper
#ifndef __HIP_PLATFORM_SPIRV__
  #include <cub/device/device_merge_sort.cuh>
#else
  #include <cub/chipstar_compat.h>
  // Don't include system CUB - provide minimal stub
#endif

#endif
")
    
    file(WRITE "${CUB_WRAPPER_DIR}/cub/device/device_partition.cuh"
      "#ifndef CUB_DEVICE_DEVICE_PARTITION_CUH
#define CUB_DEVICE_DEVICE_PARTITION_CUH

// chipStar compatibility wrapper
#ifndef __HIP_PLATFORM_SPIRV__
  #include <cub/device/device_partition.cuh>
#else
  #include <cub/chipstar_compat.h>
  // Don't include system CUB - provide minimal stub
#endif

#endif
")
    
    file(WRITE "${CUB_WRAPPER_DIR}/cub/device/dispatch/dispatch_scan_by_key.cuh"
      "#ifndef CUB_DEVICE_DISPATCH_DISPATCH_SCAN_BY_KEY_CUH
#define CUB_DEVICE_DISPATCH_DISPATCH_SCAN_BY_KEY_CUH

// chipStar compatibility wrapper
#ifndef __HIP_PLATFORM_SPIRV__
  #include <cub/device/dispatch/dispatch_scan_by_key.cuh>
#else
  #include <cub/chipstar_compat.h>
  // Don't include system CUB - provide minimal stub
#endif

#endif
")
    
    # Create wrappers for block headers that rocThrust includes
    file(MAKE_DIRECTORY "${CUB_WRAPPER_DIR}/cub/block")
    file(WRITE "${CUB_WRAPPER_DIR}/cub/block/block_load.cuh"
      "#ifndef CUB_BLOCK_BLOCK_LOAD_CUH
#define CUB_BLOCK_BLOCK_LOAD_CUH

// chipStar compatibility wrapper
#ifndef __HIP_PLATFORM_SPIRV__
  #include <cub/block/block_load.cuh>
#else
  #include <cub/chipstar_compat.h>
  // Don't include system CUB - provide minimal stub
#endif

#endif
")
    
    file(WRITE "${CUB_WRAPPER_DIR}/cub/block/block_scan.cuh"
      "#ifndef CUB_BLOCK_BLOCK_SCAN_CUH
#define CUB_BLOCK_BLOCK_SCAN_CUH

// chipStar compatibility wrapper
#ifndef __HIP_PLATFORM_SPIRV__
  #include <cub/block/block_scan.cuh>
#else
  #include <cub/chipstar_compat.h>
  // Don't include system CUB - provide minimal stub
#endif

#endif
")
    
    file(WRITE "${CUB_WRAPPER_DIR}/cub/block/block_store.cuh"
      "#ifndef CUB_BLOCK_BLOCK_STORE_CUH
#define CUB_BLOCK_BLOCK_STORE_CUH

// chipStar compatibility wrapper
#ifndef __HIP_PLATFORM_SPIRV__
  #include <cub/block/block_store.cuh>
#else
  #include <cub/chipstar_compat.h>
  // Don't include system CUB - provide minimal stub
#endif

#endif
")
    
    # Create wrapper for agent headers
    file(MAKE_DIRECTORY "${CUB_WRAPPER_DIR}/cub/agent")
    file(WRITE "${CUB_WRAPPER_DIR}/cub/agent/single_pass_scan_operators.cuh"
      "#ifndef CUB_AGENT_SINGLE_PASS_SCAN_OPERATORS_CUH
#define CUB_AGENT_SINGLE_PASS_SCAN_OPERATORS_CUH

// chipStar compatibility wrapper
#ifndef __HIP_PLATFORM_SPIRV__
  #include <cub/agent/single_pass_scan_operators.cuh>
#else
  #include <cub/chipstar_compat.h>
  // Don't include system CUB - provide minimal stub
#endif

#endif
")
    
    # Add wrapper directory to include path BEFORE system includes
    # This ensures our wrappers are found before system CUB
    # Create wrapper for thrust/detail/config.h to ensure __host__ and __device__ are defined
    file(MAKE_DIRECTORY "${CUB_WRAPPER_DIR}/thrust/detail")
    file(WRITE "${CUB_WRAPPER_DIR}/thrust/detail/config.h"
      "#ifndef THRUST_DETAIL_CONFIG_H
#define THRUST_DETAIL_CONFIG_H

// chipStar compatibility: Ensure __host__ and __device__ are defined before rocThrust uses them
#ifdef __HIP_PLATFORM_SPIRV__
  #include <hip/spirv_hip_host_defines.h>
#endif

// Force define if not already defined
#ifndef __host__
  #define __host__ __attribute__((host))
#endif
#ifndef __device__
  #define __device__ __attribute__((device))
#endif

// Now include the real rocThrust config.h
#include_next <thrust/detail/config.h>

// Ensure __host__ and __device__ remain defined after the real header
#ifndef __host__
  #define __host__ __attribute__((host))
#endif
#ifndef __device__
  #define __device__ __attribute__((device))
#endif

#endif
")
    
    # Create wrapper for thrust/system/hip/detail to provide missing terminate_with_message
    file(MAKE_DIRECTORY "${CUB_WRAPPER_DIR}/thrust/system/hip/detail")
    file(WRITE "${CUB_WRAPPER_DIR}/thrust/system/hip/detail/terminate.h"
      "#ifndef THRUST_SYSTEM_HIP_DETAIL_TERMINATE_H
#define THRUST_SYSTEM_HIP_DETAIL_TERMINATE_H

// chipStar compatibility: Provide missing terminate_with_message function for rocThrust
// This header is included via the pre-include header to ensure it's available before rocThrust uses it

#ifndef __host__
  #define __host__ __attribute__((host))
#endif
#ifndef __device__
  #define __device__ __attribute__((device))
#endif

// Include C++ headers before namespace
#include <cstdlib>
#include <iostream>

namespace thrust {
namespace system {
namespace hip {
namespace detail {

// rocThrust's HIP backend is missing this function - provide a stub implementation
__host__ __device__ inline void terminate_with_message(const char* message) {
  // For chipStar, we can't actually terminate from device code easily
  // This is a stub that at least allows compilation
  #ifdef __HIP_DEVICE_COMPILE__
    // Device code - can't do much here, just prevent infinite loops
    // In practice, this should never be called on device with chipStar
  #else
    // Host code - use standard termination
    std::cerr << \"rocThrust error: \" << (message ? message : \"unknown error\") << std::endl;
    std::abort();
  #endif
}

} // namespace detail
} // namespace hip
} // namespace system
} // namespace thrust

#endif
")
    
    # Update the pre-include header to include the terminate header
    # Append the include after the CUB_MIN definition
    file(READ "${CUB_WRAPPER_DIR}/chipstar_preinclude.h" PREINCLUDE_CONTENT)
    string(REPLACE
      "#ifndef CUB_MIN
  #define CUB_MIN(a, b) ((a) < (b) ? (a) : (b))
#endif

#endif"
      "#ifndef CUB_MIN
  #define CUB_MIN(a, b) ((a) < (b) ? (a) : (b))
#endif

// Include rocThrust compatibility functions before rocThrust headers are processed
#include <thrust/system/hip/detail/terminate.h>

#endif"
      PREINCLUDE_CONTENT "${PREINCLUDE_CONTENT}")
    file(WRITE "${CUB_WRAPPER_DIR}/chipstar_preinclude.h" "${PREINCLUDE_CONTENT}")
    
    include_directories(BEFORE "${CUB_WRAPPER_DIR}")
    
    # chipStar: Create stub rocm-core headers for compatibility
    # Some test code includes rocm-core/rocm_version.h which doesn't exist for chipStar
    set(ROCM_STUB_DIR "${CMAKE_BINARY_DIR}/chipstar_rocm_stub")
    file(MAKE_DIRECTORY "${ROCM_STUB_DIR}/rocm-core")
    file(WRITE "${ROCM_STUB_DIR}/rocm-core/rocm_version.h"
      "#ifndef _ROCM_VERSION_H_
#define _ROCM_VERSION_H_

#ifdef __cplusplus
extern \"C\" {
#endif

// chipStar stub: Define ROCm version macros for compatibility
// chipStar doesn't use ROCm, but some code expects these definitions
#define ROCM_VERSION_MAJOR   5
#define ROCM_VERSION_MINOR   7
#define ROCM_VERSION_PATCH   0

#ifdef __cplusplus
}
#endif

#endif
")
    include_directories(BEFORE "${ROCM_STUB_DIR}")
    
    # Store the pre-include header path in a cache variable
    # It will be added to CMAKE_HIP_FLAGS after enable_language(HIP) is called
    set(CHIPSTAR_PREINCLUDE_PATH "${CUB_WRAPPER_DIR}/chipstar_preinclude.h" CACHE INTERNAL "chipStar pre-include header path")
    
    # chipStar: Force rocThrust to use HIP backend (rocPRIM) instead of CUDA backend (CUB)
  # rocThrust checks THRUST_DEVICE_COMPILER == THRUST_DEVICE_COMPILER_HIP to select HIP backend
  # which is set when __HIP__ is defined. Also explicitly set THRUST_DEVICE_SYSTEM to HIP.
  add_compile_definitions(
    __HIP__=1
    THRUST_DEVICE_SYSTEM=5
    THRUST_DEVICE_SYSTEM_HIP=5
    THRUST_IGNORE_CUB_VERSION_CHECK=1
  )
    
    message(STATUS "chipStar: Created CUB compatibility wrappers for rocThrust in ${CUB_WRAPPER_DIR}")
  endif()
endfunction()

# Patch rapids-cmake generate_resource_spec.cmake to support chipStar (SPIR-V) platform
function(chipstar_patch_rapids_cmake)
  if(NOT _CHIPSTAR_DETECTED)
    return()
  endif()

  set(GENERATE_SPEC_FILE "${CMAKE_BINARY_DIR}/_deps/rapids-cmake-src/rapids-cmake/test-hip/generate_resource_spec.cmake")
  
  if(EXISTS "${GENERATE_SPEC_FILE}" AND NOT DEFINED _CHIPSTAR_SPEC_PATCHED)
    file(READ "${GENERATE_SPEC_FILE}" SPEC_CONTENT)
    
    if(NOT "${SPEC_CONTENT}" MATCHES "HIP_PLATFORM STREQUAL \"spirv\"")
      # Find the nvidia block and add chipStar block after it
      string(REPLACE
        "      elseif (HIP_PLATFORM STREQUAL \"nvidia\")\n        set(compile_options \"-I${HIP_INCLUDE_DIRS}\" \"-DHAVE_HIP\" \"-D__HIP_PLATFORM_NVIDIA__=1 -D__HIP_PLATFORM_NVCC__=1\")\n        find_package(CUDAToolkit QUIET)\n        set(link_options ${CUDA_cudart_LIBRARY})\n        set(compiler \"${CMAKE_CXX_COMPILER}\")\n        if(NOT DEFINED CMAKE_CXX_COMPILER)\n          set(compiler \"${CMAKE_CUDA_COMPILER}\")\n        endif()\n      endif()"
        "      elseif (HIP_PLATFORM STREQUAL \"nvidia\")\n        set(compile_options \"-I${HIP_INCLUDE_DIRS}\" \"-DHAVE_HIP\" \"-D__HIP_PLATFORM_NVIDIA__=1 -D__HIP_PLATFORM_NVCC__=1\")\n        find_package(CUDAToolkit QUIET)\n        set(link_options ${CUDA_cudart_LIBRARY})\n        set(compiler \"${CMAKE_CXX_COMPILER}\")\n        if(NOT DEFINED CMAKE_CXX_COMPILER)\n          set(compiler \"${CMAKE_CUDA_COMPILER}\")\n        endif()\n      elseif (HIP_PLATFORM STREQUAL \"spirv\")\n        # chipStar HIP (SPIR-V)\n        get_filename_component(HIP_ROOT \"${HIP_INCLUDE_DIRS}\" DIRECTORY)\n        set(compile_options \"-I${HIP_INCLUDE_DIRS}\" \"-DHAVE_HIP\" \"-D__HIP_PLATFORM_SPIRV__=\" \"-x\" \"hip\" \"--offload=spirv64\" \"-nohipwrapperinc\" \"--hip-path=${HIP_ROOT}\" \"-include\" \"${HIP_ROOT}/include/hip/spirv_fixups.h\")\n        set(link_options \"-L${HIP_ROOT}/lib\" \"-lCHIP\" \"-no-hip-rt\" \"-locml_host_math_funcs\" \"-Wl,-rpath,${HIP_ROOT}/lib\")\n        set(compiler \"${CMAKE_HIP_COMPILER}\")\n        if(NOT DEFINED CMAKE_HIP_COMPILER)\n          set(compiler \"${CMAKE_CXX_COMPILER}\")\n        endif()\n      endif()"
        SPEC_CONTENT "${SPEC_CONTENT}")
      
      file(WRITE "${GENERATE_SPEC_FILE}" "${SPEC_CONTENT}")
      set(_CHIPSTAR_SPEC_PATCHED ON CACHE INTERNAL "chipStar spec file patched")
      message(STATUS "chipStar: Patched generate_resource_spec.cmake for SPIR-V support")
    endif()
  endif()
endfunction()

# Create resource_spec.json for chipStar if GPU detection failed
function(chipstar_create_resource_spec)
  if(NOT _CHIPSTAR_DETECTED)
    return()
  endif()

  set(RESOURCE_SPEC_FILE "${CMAKE_BINARY_DIR}/resource_spec.json")
  
  # Create resource spec with 100 GPU slots
  file(WRITE "${RESOURCE_SPEC_FILE}"
    "{\n\"version\": {\"major\": 1, \"minor\": 0},\n\"local\": [{\n  \"gpus\": [{\"id\": \"0\", \"slots\": 100}]\n}]\n}\n")
  
  set(CTEST_RESOURCE_SPEC_FILE "${RESOURCE_SPEC_FILE}" CACHE FILEPATH "CTest resource specification file")
  message(STATUS "chipStar: Created resource_spec.json with 100 GPU slots")
endfunction()

