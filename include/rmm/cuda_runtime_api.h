// MIT License
//
// Copyright (C) 2025 Advanced Micro Devices, Inc. All rights reserved.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

#pragma once

// chipStar compatibility: include cuda_runtime.h first to get cuda* function definitions
#ifdef __HIP_PLATFORM_SPIRV__
  #pragma clang diagnostic push
  #pragma clang diagnostic ignored "-Wstatic-non-static-function"
  #include <cuspv/cuda_runtime.h>
#endif

#include <hip/hip_runtime_api.h>

// chipStar compatibility: Define hipHostAlloc constants that libhipcxx expects
// These must be defined before any libhipcxx headers are included
#ifdef __HIP_PLATFORM_SPIRV__
  #ifndef hipHostAllocDefault
    #define hipHostAllocDefault 0x00
  #endif
  #ifndef hipHostAllocPortable
    #define hipHostAllocPortable 0x01
  #endif
  #ifndef hipHostAllocMapped
    #define hipHostAllocMapped 0x02
  #endif
  #ifndef hipHostAllocWriteCombined
    #define hipHostAllocWriteCombined 0x04
  #endif
#endif

#define CUDART_VERSION 0

// chipStar compatibility: Define missing CUDA error codes that rocThrust expects
#ifdef __HIP_PLATFORM_SPIRV__
  #ifndef cudaErrorMemoryValueTooLarge
    #define cudaErrorMemoryValueTooLarge hipErrorUnknown
  #endif
  #ifndef cudaErrorECCUncorrectable
    #define cudaErrorECCUncorrectable hipErrorECCNotCorrectable
  #endif
  #ifndef cudaErrorApiFailureBase
    #define cudaErrorApiFailureBase hipErrorUnknown
  #endif
  #ifndef cudaErrorLaunchTimeout
    #define cudaErrorLaunchTimeout hipErrorLaunchTimeOut
  #endif
  #ifndef cudaErrorUnmapBufferObjectFailed
    #define cudaErrorUnmapBufferObjectFailed hipErrorMapBufferObjectFailed
  #endif
  #ifndef cudaErrorInvalidHostPointer
    #define cudaErrorInvalidHostPointer hipErrorInvalidValue
  #endif
  #ifndef cudaErrorStartupFailure
    #define cudaErrorStartupFailure hipErrorUnknown
  #endif
  #ifndef cudaErrorInvalidTexture
    #define cudaErrorInvalidTexture hipErrorInvalidValue
  #endif
  #ifndef cudaErrorInvalidTextureBinding
    #define cudaErrorInvalidTextureBinding hipErrorInvalidValue
  #endif
  #ifndef cudaErrorInvalidChannelDescriptor
    #define cudaErrorInvalidChannelDescriptor hipErrorInvalidValue
  #endif
  #ifndef cudaErrorAddressOfConstant
    #define cudaErrorAddressOfConstant hipErrorInvalidValue
  #endif
  #ifndef cudaErrorTextureFetchFailed
    #define cudaErrorTextureFetchFailed hipErrorUnknown
  #endif
  #ifndef cudaErrorTextureNotBound
    #define cudaErrorTextureNotBound hipErrorUnknown
  #endif
  #ifndef cudaErrorSynchronizationError
    #define cudaErrorSynchronizationError hipErrorUnknown
  #endif
  #ifndef cudaErrorInvalidFilterSetting
    #define cudaErrorInvalidFilterSetting hipErrorInvalidValue
  #endif
  #ifndef cudaErrorInvalidNormSetting
    #define cudaErrorInvalidNormSetting hipErrorInvalidValue
  #endif
  #ifndef cudaErrorMixedDeviceExecution
    #define cudaErrorMixedDeviceExecution hipErrorUnknown
  #endif
  #ifndef cudaErrorCudartUnloading
    #define cudaErrorCudartUnloading hipErrorUnknown
  #endif
  #ifndef cudaErrorNotYetImplemented
    #define cudaErrorNotYetImplemented hipErrorNotSupported
  #endif
#endif

// types
#ifndef cudaError_t
#  define cudaError_t hipError_t
#endif
#ifndef cudaEvent_t
#  define cudaEvent_t hipEvent_t
#endif
#ifndef cudaMemPool_t
#  define cudaMemPool_t hipMemPool_t
#endif
#ifndef cudaStream_t
#  define cudaStream_t hipStream_t
#endif
#ifndef cudaMemPoolAttr
#  define cudaMemPoolAttr hipMemPoolAttr
#endif
#ifndef cudaMemPoolProps
#  define cudaMemPoolProps hipMemPoolProps
#endif
#ifndef cudaMemAllocationHandleType
#  define cudaMemAllocationHandleType hipMemAllocationHandleType
#endif
#ifndef cudaPointerAttributes
#  define cudaPointerAttributes hipPointerAttribute_t
#endif
// macros, enum constant definitions
// NOTE: C++ `constexpr` might cause redefinition errors while #define only results in a warning in this case.
//       Such redefinitions might happen when a code includes multiple "reverse hipfication" header files
//       like this one from a number of other projects. Therefore, we prefer to use #define.
#ifndef cudaStreamLegacy
#  define cudaStreamLegacy ((hipStream_t) nullptr)
#endif
#ifndef cudaStreamPerThread
#  define cudaStreamPerThread hipStreamPerThread
#endif
#ifndef cudaMemcpyDefault
#  define cudaMemcpyDefault hipMemcpyDefault
#endif
#ifndef cudaMemPoolAttrReleaseThreshold
#  define cudaMemPoolAttrReleaseThreshold hipMemPoolAttrReleaseThreshold
#endif
#ifndef cudaDevAttrMemoryPoolSupportedHandleTypes
#  define cudaDevAttrMemoryPoolSupportedHandleTypes hipDeviceAttributeMemoryPoolSupportedHandleTypes
#endif
#ifndef cudaDevAttrMemoryPoolsSupported
#  define cudaDevAttrMemoryPoolsSupported hipDeviceAttributeMemoryPoolsSupported
#endif
#ifndef cudaDevAttrPageableMemoryAccess
#  define cudaDevAttrPageableMemoryAccess hipDeviceAttributePageableMemoryAccess
#endif
#ifndef cudaDevAttrL2CacheSize
#  define cudaDevAttrL2CacheSize hipDeviceAttributeL2CacheSize
#endif
#ifndef cudaErrorInvalidValue
#  define cudaErrorInvalidValue hipErrorInvalidValue
#endif
#ifndef cudaErrorMemoryAllocation
#  define cudaErrorMemoryAllocation hipErrorMemoryAllocation
#endif
#ifndef cudaSuccess
#  define cudaSuccess hipSuccess
#endif
#ifndef cudaMemAllocationTypePinned
#  define cudaMemAllocationTypePinned hipMemAllocationTypePinned
#endif
#ifndef cudaMemPoolAttrReleaseThreshold
#  define cudaMemPoolAttrReleaseThreshold hipMemPoolAttrReleaseThreshold
#endif
#ifndef cudaMemHandleTypeNone
#  define cudaMemHandleTypeNone hipMemHandleTypeNone
#endif
#ifndef cudaMemLocationTypeDevice
#  define cudaMemLocationTypeDevice hipMemLocationTypeDevice
#endif
#ifndef cudaMemPoolReuseAllowOpportunistic
#  define cudaMemPoolReuseAllowOpportunistic hipMemPoolReuseAllowOpportunistic
#endif
#ifndef cudaEventDisableTiming
#  define cudaEventDisableTiming hipEventDisableTiming
#endif
#ifndef cudaMemoryTypeDevice
#  define cudaMemoryTypeDevice hipMemoryTypeDevice
#endif
#ifndef cudaMemoryTypeHost
#  define cudaMemoryTypeHost hipMemoryTypeHost
#endif
#ifndef cudaMemoryTypeManaged
#  define cudaMemoryTypeManaged hipMemoryTypeManaged
#endif
#ifndef cudaMemoryTypeUnregistered
#  define cudaMemoryTypeUnregistered hipMemoryTypeUnregistered
#endif
// functions
#ifndef cudaDeviceGetAttribute
#  ifndef __HIP_PLATFORM_SPIRV__
#    define cudaDeviceGetAttribute hipDeviceGetAttribute
#  endif
#endif
#ifndef cudaDeviceGetDefaultMemPool
#  define cudaDeviceGetDefaultMemPool hipDeviceGetDefaultMemPool
#endif
#ifndef cudaDeviceSynchronize
#  ifndef __HIP_PLATFORM_SPIRV__
#    define cudaDeviceSynchronize hipDeviceSynchronize
#  endif
#endif

#ifndef cudaDriverGetVersion
#  ifndef __HIP_PLATFORM_SPIRV__
#    define cudaDriverGetVersion hipDriverGetVersion
#  endif
#endif

#ifndef cudaEventCreateWithFlags
#  ifndef __HIP_PLATFORM_SPIRV__
#    define cudaEventCreateWithFlags hipEventCreateWithFlags
#  endif
#endif
#ifndef cudaEventDestroy
#  define cudaEventDestroy hipEventDestroy
#endif
#ifndef cudaEventRecord
#  define cudaEventRecord hipEventRecord
#endif
#ifndef cudaEventSynchronize
#  define cudaEventSynchronize hipEventSynchronize
#endif

#ifndef cudaFree
#  define cudaFree hipFree
#endif
#ifndef cudaFreeAsync
#  define cudaFreeAsync hipFreeAsync
#endif
#ifndef cudaFreeHost
#  define cudaFreeHost hipHostFree
#endif

#ifndef cudaGetDevice
#  ifdef __HIP_PLATFORM_SPIRV__
#    // chipStar: cudaGetDevice is already defined as static inline in cuda_runtime.h
#    // Just ensure it's available by including the header
#  else
#    define cudaGetDevice hipGetDevice
#  endif
#endif
#ifndef cudaGetDeviceCount
#  ifdef __HIP_PLATFORM_SPIRV__
#    // chipStar: cudaGetDeviceCount is already defined as static inline in cuda_runtime.h
#  else
#    define cudaGetDeviceCount hipGetDeviceCount
#  endif
#endif

#ifndef cudaGetErrorName
#  ifdef __HIP_PLATFORM_SPIRV__
#    // chipStar: cudaGetErrorName is already defined as static inline in cuda_runtime.h
#  else
#    define cudaGetErrorName hipGetErrorName
#  endif
#endif
#ifndef cudaGetErrorString
#  ifdef __HIP_PLATFORM_SPIRV__
#    // chipStar: cudaGetErrorString is already defined as static inline in cuda_runtime.h
#  else
#    define cudaGetErrorString hipGetErrorString
#  endif
#endif
#ifndef cudaGetLastError
#  ifndef __HIP_PLATFORM_SPIRV__
#    define cudaGetLastError hipGetLastError
#  endif
#endif

#ifndef cudaMallocAsync
#  define cudaMallocAsync hipMallocAsync
#endif
#ifndef cudaMalloc
#  define cudaMalloc hipMalloc
#endif
#ifndef cudaMallocFromPoolAsync
#  define cudaMallocFromPoolAsync hipMallocFromPoolAsync
#endif
#ifndef cudaMallocHost
#  define cudaMallocHost hipHostMalloc
#endif
#ifndef cudaMallocManaged
#  define cudaMallocManaged hipMallocManaged
#endif

#ifndef cudaHostAlloc
  #define cudaHostAlloc hipHostAlloc
#endif
#ifndef cudaHostAllocDefault
  #ifdef __HIP_PLATFORM_SPIRV__
    // chipStar: Define hipHostAlloc constants if not available
    #ifndef hipHostAllocDefault
      #define hipHostAllocDefault 0x00
    #endif
    #ifndef hipHostAllocPortable
      #define hipHostAllocPortable 0x01
    #endif
    #ifndef hipHostAllocMapped
      #define hipHostAllocMapped 0x02
    #endif
    #ifndef hipHostAllocWriteCombined
      #define hipHostAllocWriteCombined 0x04
    #endif
  #endif
  #define cudaHostAllocDefault hipHostAllocDefault
#endif

#ifndef cudaMemGetInfo
#  define cudaMemGetInfo hipMemGetInfo
#endif
#ifndef cudaMemPoolCreate
#  define cudaMemPoolCreate hipMemPoolCreate
#endif
#ifndef cudaMemPoolDestroy
#  define cudaMemPoolDestroy hipMemPoolDestroy
#endif
#ifndef cudaMemPoolSetAttribute
#  define cudaMemPoolSetAttribute hipMemPoolSetAttribute
#endif

#ifndef cudaMemcpyAsync
#  define cudaMemcpyAsync hipMemcpyAsync
#endif
#ifndef cudaMemsetAsync
#  define cudaMemsetAsync hipMemsetAsync
#endif

#ifndef cudaSetDevice
#  ifndef __HIP_PLATFORM_SPIRV__
#    define cudaSetDevice hipSetDevice
#  endif
#endif

#ifndef cudaStreamCreate
#  ifndef __HIP_PLATFORM_SPIRV__
#    define cudaStreamCreate hipStreamCreate
#  endif
#endif
#ifndef cudaStreamDestroy
#  ifndef __HIP_PLATFORM_SPIRV__
#    define cudaStreamDestroy hipStreamDestroy
#  endif
#endif
#ifndef cudaStreamSynchronize
#  ifndef __HIP_PLATFORM_SPIRV__
#    define cudaStreamSynchronize hipStreamSynchronize
#  else
#    // chipStar: hipStreamSynchronize is already defined as static inline in cuda_runtime.h
#    // Use the static inline version instead of the macro
#  endif
#endif

#ifndef cudaStreamWaitEvent
#  ifndef __HIP_PLATFORM_SPIRV__
#    define cudaStreamWaitEvent(a,b,c) hipStreamWaitEvent(a,b,c)
#  endif
#endif
#ifndef cudaEventCreate
#  ifndef __HIP_PLATFORM_SPIRV__
#    define cudaEventCreate hipEventCreate
#  endif
#endif
#ifndef cudaPointerGetAttributes
#  define cudaPointerGetAttributes hipPointerGetAttributes
#endif
#ifndef cudaEventElapsedTime
#  define cudaEventElapsedTime hipEventElapsedTime
#endif

#ifndef cudaStreamQuery
#  ifndef __HIP_PLATFORM_SPIRV__
#    define cudaStreamQuery hipStreamQuery
#  endif
#endif

#ifndef cudaMemPrefetchAsync
#  define cudaMemPrefetchAsync hipMemPrefetchAsync
#endif

#ifndef cudaMemAdvise
# define cudaMemAdvise hipMemAdvise
#endif

// chipStar compatibility: restore diagnostics at end of file
#ifdef __HIP_PLATFORM_SPIRV__
  #pragma clang diagnostic pop
#endif

#ifndef cudaMemAdviseSetPreferredLocation
#  define cudaMemAdviseSetPreferredLocation hipMemAdviseSetPreferredLocation
#endif

#ifndef cudaCpuDeviceId
#  define cudaCpuDeviceId hipCpuDeviceId
#endif

#ifndef cudaInvalidDeviceId
#  define cudaInvalidDeviceId hipInvalidDeviceId
#endif

#ifndef cudaMemRangeGetAttribute
#  define cudaMemRangeGetAttribute hipMemRangeGetAttribute
#endif
