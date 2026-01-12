# Reply to Colleen - CCCL Header Dependency Issue

## The Problem

Russell's compilation error occurs because RMM headers depend on CCCL (CUDA C++ Core Libraries) headers, specifically `cuda/stream_ref` and `cuda/memory_resource`. These are header-only libraries that need to be in the compiler's include path.

When using CMake with `find_package(rmm)`, CCCL headers are automatically provided via the `CCCL::CCCL` target. However, when compiling directly with `hipcc`, CCCL headers must be explicitly available.

## The Solution

CCCL headers need to be installed and added to the module's `CPATH` environment variable.

### Option 1: Install CCCL headers with hipMM (Recommended)

During hipMM installation, copy CCCL headers to the install directory:

```bash
# After hipMM install, copy CCCL headers
cp -r $hipMM_build_dir/_deps/libhipcxx-src/include/cuda $hipMM_install_dir/include/
```

Then in the hipMM module file, add:
```tcl
prepend-path CPATH $hipMM_install_dir/include
```

### Option 2: Install CCCL headers with chipStar HIP

Copy CCCL headers to chipStar HIP installation:
```bash
cp -r $hipMM_build_dir/_deps/libhipcxx-src/include/cuda $HIP_PATH/include/
```

Then the existing HIP module's `CPATH` setting should pick them up automatically.

## What the hipcc command should look like

Once CCCL headers are in `CPATH` (via module), the command should work as-is:

```bash
hipcc test.cpp
```

The module's `CPATH` setting will automatically provide the include path.

If CCCL is not in `CPATH`, you can explicitly add it:
```bash
hipcc -I$hipMM_install_dir/include test.cpp
# OR if CCCL is separate:
hipcc -I$hipMM_install_dir/include -I$CCCL_install_dir/include test.cpp
```

## Verification

After adding CCCL to the module, Russell's test should compile:
```bash
hipcc test.cpp
# Should no longer get: fatal error: 'cuda/stream_ref' file not found
```

## Additional Notes

- CCCL is header-only (no libraries to link)
- The error only occurs with direct `hipcc` compilation, not with CMake projects
- Unit tests pass because they use CMake which provides CCCL automatically

