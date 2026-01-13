# CHIP-SPV Build Notes (Verified)

## Environment Setup
```bash
module load llvm/21.0 oneapi/2025.0.4
export HIP_PATH=~/install-temp/chipStar
export PATH=~/install-temp/chipStar/bin:$PATH
```

## Build Order (dependencies matter!)
1. chipStar (core, no CHIP-SPV deps)
2. rocPRIM (depends on chipStar)
3. hipCUB (depends on chipStar, rocPRIM)
4. rocThrust (depends on chipStar, rocPRIM)
5. H4I-MKLShim (depends on Intel MKL/oneAPI)
6. H4I-HipBLAS (depends on chipStar, H4I-MKLShim)
7. H4I-HipSOLVER (depends on chipStar, H4I-MKLShim)
8. H4I-HipFFT (depends on chipStar, H4I-MKLShim)
9. rocRAND (depends on chipStar) - shared and static supported
10. rocSPARSE (depends on chipStar, rocPRIM) - NEEDS FIX
11. hipSPARSE (depends on chipStar, rocSPARSE)
12. hipMM (depends on chipStar, rocPRIM, rocThrust, hipCUB)

### NOT BUILDABLE (not ported to SPIR-V):
- hipRAND - no chipStar branch, amd_detail code not ported

---

## 1. chipStar
**Branch:** main  
**Notes:** Requires submodule init. Uses ninja by default.

```bash
git clone git@github.com:CHIP-SPV/chipStar.git
cd chipStar
git submodule update --init --recursive
mkdir build && cd build
cmake .. -DCMAKE_INSTALL_PREFIX=~/install-temp/chipStar
ninja
ninja install
```

---

## 2. rocPRIM
**Branch:** chipStar  
**Notes:** Header-only library.

```bash
git clone git@github.com:CHIP-SPV/rocPRIM.git
cd rocPRIM && git checkout chipStar
mkdir build && cd build
cmake .. \
  -DCMAKE_CXX_COMPILER=hipcc \
  -DCMAKE_INSTALL_PREFIX=~/install-temp/rocPRIM \
  -DBUILD_TEST=OFF \
  -DBUILD_BENCHMARK=OFF
ninja install
```

---

## 3. hipCUB
**Branch:** chipStar  
**Notes:** Header-only. Needs rocPRIM.

```bash
git clone git@github.com:CHIP-SPV/hipCUB.git
cd hipCUB && git checkout chipStar
mkdir build && cd build
cmake .. \
  -DCMAKE_CXX_COMPILER=hipcc \
  -DCMAKE_INSTALL_PREFIX=~/install-temp/hipCUB \
  -DCMAKE_PREFIX_PATH=~/install-temp/rocPRIM \
  -DBUILD_TEST=OFF \
  -DBUILD_BENCHMARK=OFF
ninja install
```

---

## 4. rocThrust
**Branch:** chipStar  
**Notes:** Header-only. Needs rocPRIM.

```bash
git clone git@github.com:CHIP-SPV/rocThrust.git
cd rocThrust && git checkout chipStar
mkdir build && cd build
cmake .. \
  -DCMAKE_CXX_COMPILER=hipcc \
  -DCMAKE_INSTALL_PREFIX=~/install-temp/rocThrust \
  -DCMAKE_PREFIX_PATH=~/install-temp/rocPRIM \
  -DBUILD_TEST=OFF \
  -DBUILD_BENCHMARKS=OFF \
  -DBUILD_EXAMPLES=OFF
ninja install
```

---

## 5. H4I-MKLShim
**Branch:** develop  
**Notes:** Requires Intel MKL (oneapi module). Uses clang++ NOT hipcc.

```bash
git clone git@github.com:CHIP-SPV/H4I-MKLShim.git
cd H4I-MKLShim
mkdir build && cd build
cmake .. \
  -DCMAKE_CXX_COMPILER=clang++ \
  -DCMAKE_INSTALL_PREFIX=~/install-temp/H4I-MKLShim
ninja
ninja install
```

---

## 6. H4I-HipBLAS
**Branch:** develop  
**Notes:** Requires H4I-MKLShim. Must use CLANG_COMPILER_PATH for the LLVM clang.

```bash
git clone git@github.com:CHIP-SPV/H4I-HipBLAS.git
cd H4I-HipBLAS && git checkout develop
mkdir build && cd build
cmake .. \
  -DCLANG_COMPILER_PATH=/path/to/llvm/bin/clang++ \
  -DCMAKE_INSTALL_PREFIX=~/install-temp/H4I-HipBLAS \
  -DCMAKE_PREFIX_PATH=~/install-temp/H4I-MKLShim \
  -DBUILD_TESTING=OFF
ninja
ninja install
```

---

## 7. H4I-HipSOLVER
**Branch:** develop  
**Notes:** Requires H4I-MKLShim. Must use CLANG_COMPILER_PATH for the LLVM clang.

```bash
git clone git@github.com:CHIP-SPV/H4I-HipSOLVER.git
cd H4I-HipSOLVER
mkdir build && cd build
cmake .. \
  -DCLANG_COMPILER_PATH=/path/to/llvm/bin/clang++ \
  -DCMAKE_INSTALL_PREFIX=~/install-temp/H4I-HipSOLVER \
  -DCMAKE_PREFIX_PATH=~/install-temp/H4I-MKLShim
ninja
ninja install
```

---

## 8. H4I-HipFFT
**Branch:** develop  
**Notes:** Requires H4I-MKLShim. Uses CMAKE_CXX_COMPILER=hipcc.

```bash
git clone git@github.com:CHIP-SPV/H4I-HipFFT.git
cd H4I-HipFFT
mkdir build && cd build
cmake .. \
  -DCMAKE_CXX_COMPILER=hipcc \
  -DCMAKE_INSTALL_PREFIX=~/install-temp/H4I-HipFFT \
  -DCMAKE_PREFIX_PATH=~/install-temp/H4I-MKLShim
ninja
ninja install
```

---

## 9. rocRAND
**Branch:** chipStar  
**Notes:** Disable ASM incbin. Shared and static libraries both supported.

```bash
git clone git@github.com:CHIP-SPV/rocRAND.git
cd rocRAND && git checkout chipStar
mkdir build && cd build
cmake .. \
  -DCMAKE_CXX_COMPILER=hipcc \
  -DCMAKE_INSTALL_PREFIX=~/install-temp/rocRAND \
  -DBUILD_TEST=OFF \
  -DBUILD_BENCHMARK=OFF \
  -DROCRAND_HAVE_ASM_INCBIN=OFF \
  -DBUILD_SHARED_LIBS=ON   # or OFF for static
ninja
ninja install
```

---

## 10. rocSPARSE
**Branch:** chipStar  
**Notes:** Needs bug fix - add `#include <algorithm>` to `library/src/include/utility.h`

```bash
git clone git@github.com:CHIP-SPV/rocSPARSE.git
cd rocSPARSE && git checkout chipStar

# FIX: Add missing include
sed -i 's/#include "logging.h"/#include "logging.h"\n#include <algorithm>/' library/src/include/utility.h

mkdir build && cd build
cmake .. \
  -DCMAKE_CXX_COMPILER=hipcc \
  -DCMAKE_INSTALL_PREFIX=~/install-temp/rocSPARSE \
  -DCMAKE_PREFIX_PATH=~/install-temp/rocPRIM \
  -DBUILD_CLIENTS_TESTS=OFF \
  -DBUILD_CLIENTS_BENCHMARKS=OFF \
  -DBUILD_CLIENTS_SAMPLES=OFF
ninja
ninja install
```

---

## 10. hipSPARSE
**Branch:** develop  
**Notes:** Requires rocSPARSE.

```bash
git clone git@github.com:CHIP-SPV/hipSPARSE.git
cd hipSPARSE
mkdir build && cd build
cmake .. \
  -DCMAKE_CXX_COMPILER=hipcc \
  -DCMAKE_INSTALL_PREFIX=~/install-temp/hipSPARSE \
  -DCMAKE_PREFIX_PATH=~/install-temp/rocSPARSE \
  -DBUILD_CLIENTS_TESTS=OFF \
  -DBUILD_CLIENTS_SAMPLES=OFF
ninja
ninja install
```

---

## 11. hipMM
**Branch:** chipStar  
**Notes:** Requires rocPRIM, rocThrust, hipCUB. Auto-patches libhipcxx for SPIRV.

```bash
git clone git@github.com:CHIP-SPV/hipMM.git
cd hipMM && git checkout chipStar
mkdir build && cd build
cmake .. \
  -DCMAKE_CXX_COMPILER=hipcc \
  -DCMAKE_INSTALL_PREFIX=~/install-temp/hipMM \
  -DCMAKE_PREFIX_PATH="~/install-temp/rocPRIM;~/install-temp/rocThrust;~/install-temp/hipCUB" \
  -DBUILD_TESTS=OFF
ninja
ninja install
```

---

## Summary

| Library | Status | Branch | Compiler |
|---------|--------|--------|----------|
| chipStar | OK | main | default |
| rocPRIM | OK | chipStar | hipcc |
| hipCUB | OK | chipStar | hipcc |
| rocThrust | OK | chipStar | hipcc |
| rocRAND | OK | chipStar | hipcc |
| rocSPARSE | OK* | chipStar | hipcc |
| hipSPARSE | OK | develop | hipcc |
| H4I-MKLShim | OK | develop | clang++ |
| H4I-HipBLAS | OK | develop | CLANG_COMPILER_PATH |
| H4I-HipSOLVER | OK | develop | CLANG_COMPILER_PATH |
| H4I-HipFFT | OK | develop | hipcc |
| hipMM | OK | chipStar | hipcc |
| hipRAND | FAIL | develop | - |

*rocSPARSE requires fix: add `#include <algorithm>` to utility.h
