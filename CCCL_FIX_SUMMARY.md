# CCCL Header Dependency Fix

## Problem Reproduced

Created `test_reproducer.cpp`:
```cpp
#include <rmm/device_vector.hpp>

int main(void)
{
   rmm::device_vector<double> vector(10);
   return 0;
}
```

**Error without CCCL headers:**
```
./include/rmm/cuda_stream_view.hpp:44:10: fatal error: 'cuda/stream_ref' file not found
   44 | #include <cuda/stream_ref>
      |          ^~~~~~~~~~~~~~~~~
```

## Root Cause

RMM headers require CCCL (libhipcxx) headers:
- `cuda/stream_ref` - used in `cuda_stream_view.hpp`
- `cuda/memory_resource` - used extensively
- `cuda/std/span` - used in `prefetch.hpp`
- `cuda/std/type_traits` - used in various adaptors

When compiling directly with `hipcc` (not via CMake), CCCL headers are not automatically available because:
- CMake projects get CCCL via `CCCL::CCCL` target dependency
- Direct compilation requires explicit include path

## Solution

Add CCCL include directory to `CPATH` environment variable in the module.

### Where to find CCCL headers:

**Current Status:** CCCL headers are NOT currently installed with chipStar HIP or hipMM.

**Options:**

1. **Install CCCL separately and add to module:**
   - Install CCCL/libhipcxx headers to a location like `$chipStar_install_dir/include/cuda/`
   - Add to module: `prepend-path CPATH $chipStar_install_dir/include`

2. **Bundle CCCL with hipMM installation:**
   - Copy CCCL headers during hipMM install: `cp -r build/_deps/libhipcxx-src/include/cuda $install_dir/include/`
   - Add to module: `prepend-path CPATH $hipMM_install_dir/include`

3. **Bundle CCCL with chipStar HIP (recommended):**
   - Include CCCL headers in chipStar HIP installation
   - Add to HIP module: `prepend-path CPATH $HIP_PATH/include` (if cuda/ is under include/)

### Module Fix:

Add to the hipMM module file:
```tcl
# Add CCCL include directory to CPATH
prepend-path CPATH $chipStar_install_dir/include/cuda
# OR if CCCL is separate:
# prepend-path CPATH $CCCL_INSTALL_DIR/include
```

### Verification:

After adding to CPATH, the following should work:
```bash
hipcc test_reproducer.cpp
```

## Test Results

✅ **Confirmed error reproduction:**
- Without CCCL: `fatal error: 'cuda/stream_ref' file not found`
- With CCCL: Compilation proceeds (may have other warnings/errors from header conflicts, but CCCL dependency is resolved)

## Additional Notes

- CCCL is header-only (no libraries to link)
- Tests work because they use CMake which provides `CCCL::CCCL` target
- Direct `hipcc` compilation needs explicit include path via `CPATH` or `-I` flag

