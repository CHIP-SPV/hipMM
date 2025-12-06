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
    
    # chipStar requires clang++ for both HIP and C++ compilation
    # Set C++ compiler to clang++ as well since HIP flags may be applied to C++ files
    if(NOT DEFINED CMAKE_CXX_COMPILER OR CMAKE_CXX_COMPILER MATCHES "g\\+\\+|c\\+\\+")
      set(CMAKE_CXX_COMPILER "$ENV{LLVM_ROOT}/bin/clang++" CACHE PATH "C++ compiler" FORCE)
      message(STATUS "chipStar: Setting C++ compiler to ${CMAKE_CXX_COMPILER} (required for chipStar)")
    endif()
    
    # Also set C compiler to clang for consistency
    if(NOT DEFINED CMAKE_C_COMPILER OR CMAKE_C_COMPILER MATCHES "gcc|cc")
      if(EXISTS "$ENV{LLVM_ROOT}/bin/clang")
        set(CMAKE_C_COMPILER "$ENV{LLVM_ROOT}/bin/clang" CACHE PATH "C compiler" FORCE)
        message(STATUS "chipStar: Setting C compiler to ${CMAKE_C_COMPILER}")
      endif()
    endif()
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
  elseif(DEFINED HIP_INCLUDE_DIRS)
    # Use HIP_INCLUDE_DIRS if HIP_DIR is not set (HIP was found via find_package)
    get_filename_component(HIP_ROOT "${HIP_INCLUDE_DIRS}" DIRECTORY)
    set(HIP_DIR "${HIP_ROOT}" CACHE PATH "HIP directory" FORCE)
    message(STATUS "chipStar: HIP_DIR=${HIP_DIR} (from HIP_INCLUDE_DIRS)")
  elseif(DEFINED ENV{HIP_PATH})
    set(HIP_DIR "$ENV{HIP_PATH}" CACHE PATH "HIP directory" FORCE)
    message(STATUS "chipStar: HIP_DIR=${HIP_DIR} (from HIP_PATH)")
  endif()
  
  # Ensure chipStar's CUDA headers (cuspv/) are found
  # chipStar provides CUDA headers under cuspv/ namespace
  # Exclude spdlog from chipStar's include to avoid conflicts with downloaded fmt
  if(DEFINED HIP_DIR AND EXISTS "${HIP_DIR}/include")
    # Create a wrapper directory that excludes spdlog
    # We'll create symlinks to all subdirectories except spdlog
    set(CHIPSTAR_CUDA_HEADER_DIR "${CMAKE_BINARY_DIR}/chipstar_cuda_headers")
    file(MAKE_DIRECTORY "${CHIPSTAR_CUDA_HEADER_DIR}")
    
    # Get all subdirectories in chipStar's include
    file(GLOB CHIPSTAR_INCLUDE_DIRS "${HIP_DIR}/include/*")
    foreach(INCLUDE_DIR ${CHIPSTAR_INCLUDE_DIRS})
      get_filename_component(DIR_NAME ${INCLUDE_DIR} NAME)
      # Skip spdlog to avoid conflicts with downloaded fmt
      if(NOT DIR_NAME STREQUAL "spdlog")
        # Create symlink to preserve the directory structure
        execute_process(
          COMMAND ${CMAKE_COMMAND} -E create_symlink "${INCLUDE_DIR}" "${CHIPSTAR_CUDA_HEADER_DIR}/${DIR_NAME}"
          RESULT_VARIABLE SYMLINK_RESULT
        )
      endif()
    endforeach()
    
    include_directories(BEFORE "${CHIPSTAR_CUDA_HEADER_DIR}")
    message(STATUS "chipStar: Added CUDA headers include directory (excluding spdlog): ${HIP_DIR}/include")
  elseif(DEFINED HIP_INCLUDE_DIRS)
    include_directories(BEFORE "${HIP_INCLUDE_DIRS}")
    message(STATUS "chipStar: Added CUDA headers include directory: ${HIP_INCLUDE_DIRS}")
  elseif(DEFINED ENV{HIP_PATH} AND EXISTS "$ENV{HIP_PATH}/include")
    include_directories(BEFORE "$ENV{HIP_PATH}/include")
    message(STATUS "chipStar: Added CUDA headers include directory from HIP_PATH: $ENV{HIP_PATH}/include")
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
    
    # Note: hipCUB now has native __HIP_PLATFORM_SPIRV__ support - no patching needed

    # chipStar: Force rocThrust to use HIP backend (rocPRIM) instead of CUDA backend (CUB)
    # rocThrust checks THRUST_DEVICE_COMPILER == THRUST_DEVICE_COMPILER_HIP to select HIP backend
    # which is set when __HIP__ is defined. Also explicitly set THRUST_DEVICE_SYSTEM to HIP.
    add_compile_definitions(
      __HIP__=1
      THRUST_DEVICE_SYSTEM=5
      THRUST_DEVICE_SYSTEM_HIP=5
      THRUST_IGNORE_CUB_VERSION_CHECK=1
    )
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

