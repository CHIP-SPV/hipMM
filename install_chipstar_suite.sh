#!/bin/bash
#
# CHIP-SPV Full Suite Installation Script
# Installs chipStar and all dependent libraries for Aurora
#
set -e

# CHIP-SPV Repository URLs with Dependencies
# ============================================
# Build order matters! Dependencies listed in comments.

# Core - no CHIP-SPV deps, requires LLVM with llvm-spirv
CHIPSTAR_REPO="git@github.com:CHIP-SPV/chipStar.git"
CHIPSTAR_BRANCH="main"

# Primitives - depends on: chipStar
ROC_PRIM_REPO="git@github.com:CHIP-SPV/rocPRIM.git"
ROC_PRIM_BRANCH="chipStar"

# CUB wrapper - depends on: chipStar, rocPRIM
HIP_CUB_REPO="git@github.com:CHIP-SPV/hipCUB.git"
HIP_CUB_BRANCH="chipStar"

# Thrust - depends on: chipStar, rocPRIM
ROC_THRUST_REPO="git@github.com:CHIP-SPV/rocThrust.git"
ROC_THRUST_BRANCH="chipStar"

# Random number generators - depends on: chipStar
HIP_RAND_REPO="git@github.com:CHIP-SPV/hipRAND.git"
HIP_RAND_BRANCH="develop"

# ROCm random - depends on: chipStar, hipRAND
ROC_RAND_REPO="git@github.com:CHIP-SPV/rocRAND.git"
ROC_RAND_BRANCH="chipStar"

# Sparse matrix - depends on: chipStar
HIP_SPARSE_REPO="git@github.com:CHIP-SPV/hipSPARSE.git"
HIP_SPARSE_BRANCH="develop"

# MKL Shim layer - depends on: Intel MKL (system)
H4I_MKL_SHIM_REPO="git@github.com:CHIP-SPV/H4I-MKLShim.git"
H4I_MKL_SHIM_BRANCH="main"

# HIP Utils - shared utilities for H4I libs
H4I_HIP_UTILS_REPO="git@github.com:CHIP-SPV/H4I-HipUtils.git"
H4I_HIP_UTILS_BRANCH="main"

# hipBLAS - depends on: chipStar, H4I-MKLShim
H4I_HIP_BLAS_REPO="git@github.com:CHIP-SPV/H4I-HipBLAS.git"
H4I_HIP_BLAS_BRANCH="develop"

# hipSOLVER - depends on: chipStar, H4I-MKLShim
H4I_HIP_SOLVER_REPO="git@github.com:CHIP-SPV/H4I-HipSOLVER.git"
H4I_HIP_SOLVER_BRANCH="main"

# hipFFT - depends on: chipStar
H4I_HIP_FFT_REPO="git@github.com:CHIP-SPV/H4I-HipFFT.git"
H4I_HIP_FFT_BRANCH="main"

# Memory Manager (RMM) - depends on: chipStar, rocThrust (for tests)
HIP_MM_REPO="git@github.com:CHIP-SPV/hipMM.git"
HIP_MM_BRANCH="chipStar"

# Configuration
INSTALL_BASE="$HOME/install/HIP"
MODULE_BASE="$HOME/modulefiles/HIP"
SRC_BASE="$HOME/chipStar-install"
JOBS=$(nproc)
DATE=$(date +%Y.%m.%d)

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Step 0: Setup directories
setup_dirs() {
    log_info "Creating directories..."
    mkdir -p "$SRC_BASE"
    mkdir -p "$INSTALL_BASE"
    mkdir -p "$MODULE_BASE"
    mkdir -p "$MODULE_BASE/chipStar"
    cd "$SRC_BASE"
}

# Step 1: Set cmake generator and verify LLVM
setup_env() {
    log_info "Setting up environment..."
    export CMAKE_GENERATOR="Unix Makefiles"
    
    # Check clang++ is in PATH
    if ! command -v clang++ &> /dev/null; then
        log_error "clang++ not found in PATH. Please load LLVM module or add to PATH."
        log_error "Example: module load llvm/21.0"
        exit 1
    fi
    
    # Check llvm-spirv translator is available (chipStar uses this, not clang SPIRV backend)
    if ! command -v llvm-spirv &> /dev/null; then
        log_error "llvm-spirv not found in PATH."
        log_error "chipStar requires the LLVM-SPIRV translator."
        log_error "Please use an LLVM installation that includes llvm-spirv."
        exit 1
    fi
    
    log_info "Using clang++: $(which clang++)"
    log_info "Using llvm-spirv: $(which llvm-spirv)"
    log_info "LLVM version: $(clang++ --version | head -1)"
    
    # Setup module path for subsequent builds
    module use ~/modulefiles 2>/dev/null || true
}

# Step 2: Clone or update repository
clone_or_update() {
    local repo_url="$1"
    local dir_name="$2"
    local branch="${3:-}"
    
    if [ -d "$dir_name" ]; then
        log_info "Updating $dir_name..."
        cd "$dir_name"
        git fetch origin
        if [ -n "$branch" ]; then
            git checkout "$branch"
            git pull origin "$branch"
        else
            git pull
        fi
        cd ..
    else
        log_info "Cloning $dir_name..."
        if [ -n "$branch" ]; then
            git clone -b "$branch" "$repo_url" "$dir_name"
        else
            git clone "$repo_url" "$dir_name"
        fi
    fi
}

# Step 3: Build chipStar
build_chipstar() {
    log_info "Building chipStar..."
    cd "$SRC_BASE"
    
    clone_or_update "git@github.com:CHIP-SPV/chipStar.git" "chipStar" "main"
    
    cd chipStar
    git submodule update --init --recursive
    
    rm -rf build && mkdir build && cd build
    
    cmake .. \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX="$INSTALL_BASE/chipStar/main" \
        -DCHIP_BUILD_TESTS=OFF
    
    make -j$JOBS
    make install
    
    # Generate module
    cat > "$MODULE_BASE/chipStar/main.lua" << EOF
-- -*- lua -*-
local install_dir = "$INSTALL_BASE/chipStar/main"

setenv("HIP_DIR", install_dir .. "/lib/cmake/hip")
setenv("HIP_PATH", install_dir)

prepend_path("CMAKE_PREFIX_PATH", install_dir)
prepend_path("PATH", install_dir .. "/bin")
prepend_path("LD_LIBRARY_PATH", install_dir .. "/lib")
prepend_path("LD_LIBRARY_PATH", install_dir .. "/lib64")
prepend_path("LIBRARY_PATH", install_dir .. "/lib")
prepend_path("LIBRARY_PATH", install_dir .. "/lib64")
prepend_path("CPATH", install_dir .. "/include")
EOF
    
    log_info "chipStar installed to $INSTALL_BASE/chipStar/main"
}

# Step 4: Build rocPRIM
build_rocprim() {
    log_info "Building rocPRIM..."
    cd "$SRC_BASE"
    
    # Load chipStar module
    module load HIP/chipStar/main
    
    clone_or_update "git@github.com:CHIP-SPV/rocPRIM.git" "rocPRIM" "chipStar"
    
    cd rocPRIM
    rm -rf build && mkdir build && cd build
    
    cmake .. \
        -DCMAKE_CXX_COMPILER=hipcc \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX="$INSTALL_BASE/rocPRIM/$DATE" \
        -DBUILD_TEST=OFF \
        -DBUILD_BENCHMARK=OFF
    
    make -j$JOBS
    make install
    
    # Generate module
    cat > "$MODULE_BASE/rocPRIM.lua" << EOF
-- -*- lua -*-
local install_dir = "$INSTALL_BASE/rocPRIM/$DATE"

setenv("ROCPRIM_DIR", install_dir .. "/lib/cmake/rocprim")
setenv("rocprim_DIR", install_dir .. "/lib/cmake/rocprim")

prepend_path("CMAKE_PREFIX_PATH", install_dir)
prepend_path("CPATH", install_dir .. "/include")
prepend_path("LD_LIBRARY_PATH", install_dir .. "/lib")
prepend_path("LIBRARY_PATH", install_dir .. "/lib")
EOF
    
    log_info "rocPRIM installed to $INSTALL_BASE/rocPRIM/$DATE"
}

# Step 5: Build hipCUB
build_hipcub() {
    log_info "Building hipCUB..."
    cd "$SRC_BASE"
    
    module load HIP/chipStar/main HIP/rocPRIM
    
    clone_or_update "git@github.com:CHIP-SPV/hipCUB.git" "hipCUB" "chipStar"
    
    cd hipCUB
    rm -rf build && mkdir build && cd build
    
    cmake .. \
        -DCMAKE_CXX_COMPILER=hipcc \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX="$INSTALL_BASE/hipCUB/$DATE" \
        -DBUILD_TEST=OFF \
        -DBUILD_BENCHMARK=OFF
    
    make -j$JOBS
    make install
    
    # Create CUB compatibility wrappers for rocThrust
    mkdir -p "$INSTALL_BASE/hipCUB/$DATE/include/cub/detail"
    
    cat > "$INSTALL_BASE/hipCUB/$DATE/include/cub/util_namespace.cuh" << 'CUBEOF'
// CUB compatibility wrapper for hipCUB
#pragma once
#include <hipcub/config.hpp>

#define CUB_NS_PREFIX HIPCUB_BEGIN_NAMESPACE
#define CUB_NS_POSTFIX HIPCUB_END_NAMESPACE
#define CUB_NS_QUALIFIER hipcub

#define CUB_NAMESPACE_BEGIN namespace cub {
#define CUB_NAMESPACE_END }

#define CUB_RUNTIME_FUNCTION __host__ __device__

namespace cub = hipcub;
CUBEOF

    cat > "$INSTALL_BASE/hipCUB/$DATE/include/cub/util_debug.cuh" << 'CUBEOF'
// CUB compatibility wrapper for hipCUB
#pragma once
#include <hipcub/config.hpp>

#define CubDebug(e) (e)
#define CubDebugExit(e) (e)

#ifndef CUB_STDERR
#define CUB_STDERR 0
#endif
CUBEOF

    cat > "$INSTALL_BASE/hipCUB/$DATE/include/cub/detail/detect_cuda_runtime.cuh" << 'CUBEOF'
// CUB compatibility wrapper for hipCUB
#pragma once

#define CUB_RUNTIME_ENABLED
CUBEOF

    # Generate module
    cat > "$MODULE_BASE/hipCUB.lua" << EOF
-- -*- lua -*-
local install_dir = "$INSTALL_BASE/hipCUB/$DATE"

setenv("HIPCUB_DIR", install_dir)
setenv("hipcub_DIR", install_dir .. "/lib/cmake/hipcub")

prepend_path("CMAKE_PREFIX_PATH", install_dir)
prepend_path("CPATH", install_dir .. "/include")
prepend_path("LD_LIBRARY_PATH", install_dir .. "/lib")
prepend_path("LIBRARY_PATH", install_dir .. "/lib")
EOF
    
    log_info "hipCUB installed to $INSTALL_BASE/hipCUB/$DATE"
}

# Step 6: Build rocThrust
build_rocthrust() {
    log_info "Building rocThrust..."
    cd "$SRC_BASE"
    
    module load HIP/chipStar/main HIP/rocPRIM HIP/hipCUB
    
    clone_or_update "git@github.com:CHIP-SPV/rocThrust.git" "rocThrust" "chipStar"
    
    cd rocThrust
    rm -rf build && mkdir build && cd build
    
    cmake .. \
        -DCMAKE_CXX_COMPILER=hipcc \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX="$INSTALL_BASE/rocThrust/$DATE" \
        -DBUILD_TEST=OFF \
        -DBUILD_BENCHMARK=OFF
    
    make -j$JOBS
    make install
    
    # Generate module
    cat > "$MODULE_BASE/rocThrust.lua" << EOF
-- -*- lua -*-
local install_dir = "$INSTALL_BASE/rocThrust/$DATE"

setenv("ROCTHRUST_DIR", install_dir .. "/lib/cmake/rocthrust")
setenv("rocthrust_DIR", install_dir .. "/lib/cmake/rocthrust")

prepend_path("CMAKE_PREFIX_PATH", install_dir)
prepend_path("CPATH", install_dir .. "/include")
prepend_path("LD_LIBRARY_PATH", install_dir .. "/lib")
prepend_path("LIBRARY_PATH", install_dir .. "/lib")
EOF
    
    log_info "rocThrust installed to $INSTALL_BASE/rocThrust/$DATE"
}

# Step 7: Build hipBLAS (H4I-HipBLAS)
build_hipblas() {
    log_info "Building H4I-HipBLAS..."
    cd "$SRC_BASE"
    
    module load HIP/chipStar/main
    
    clone_or_update "git@github.com:CHIP-SPV/H4I-HipBLAS.git" "H4I-HipBLAS" "main"
    
    cd H4I-HipBLAS
    rm -rf build && mkdir build && cd build
    
    cmake .. \
        -DCMAKE_CXX_COMPILER=hipcc \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX="$INSTALL_BASE/H4I-HipBLAS/$DATE"
    
    make -j$JOBS
    make install
    
    # Generate module
    cat > "$MODULE_BASE/H4I-HipBLAS.lua" << EOF
-- -*- lua -*-
local install_dir = "$INSTALL_BASE/H4I-HipBLAS/$DATE"

prepend_path("CMAKE_PREFIX_PATH", install_dir)
prepend_path("CPATH", install_dir .. "/include")
prepend_path("LD_LIBRARY_PATH", install_dir .. "/lib")
prepend_path("LD_LIBRARY_PATH", install_dir .. "/lib64")
prepend_path("LIBRARY_PATH", install_dir .. "/lib")
prepend_path("LIBRARY_PATH", install_dir .. "/lib64")
EOF
    
    log_info "H4I-HipBLAS installed to $INSTALL_BASE/H4I-HipBLAS/$DATE"
}

# Step 8: Build hipRAND
build_hiprand() {
    log_info "Building hipRAND..."
    cd "$SRC_BASE"
    
    module load HIP/chipStar/main
    
    clone_or_update "git@github.com:CHIP-SPV/hipRAND.git" "hipRAND" "chipStar"
    
    cd hipRAND
    rm -rf build && mkdir build && cd build
    
    cmake .. \
        -DCMAKE_CXX_COMPILER=hipcc \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX="$INSTALL_BASE/hipRAND/$DATE" \
        -DBUILD_TEST=OFF \
        -DBUILD_BENCHMARK=OFF
    
    make -j$JOBS
    make install
    
    # Generate module
    cat > "$MODULE_BASE/hipRAND.lua" << EOF
-- -*- lua -*-
local install_dir = "$INSTALL_BASE/hipRAND/$DATE"

prepend_path("CMAKE_PREFIX_PATH", install_dir)
prepend_path("CPATH", install_dir .. "/include")
prepend_path("LD_LIBRARY_PATH", install_dir .. "/lib")
prepend_path("LIBRARY_PATH", install_dir .. "/lib")
EOF
    
    log_info "hipRAND installed to $INSTALL_BASE/hipRAND/$DATE"
}

# Step 9: Build rocRAND
build_rocrand() {
    log_info "Building rocRAND..."
    cd "$SRC_BASE"
    
    module load HIP/chipStar/main
    
    clone_or_update "git@github.com:CHIP-SPV/rocRAND.git" "rocRAND" "chipStar"
    
    cd rocRAND
    rm -rf build && mkdir build && cd build
    
    cmake .. \
        -DCMAKE_CXX_COMPILER=hipcc \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX="$INSTALL_BASE/rocRAND/$DATE" \
        -DBUILD_TEST=OFF \
        -DBUILD_BENCHMARK=OFF \
        -DROCRAND_HAVE_ASM_INCBIN=OFF \
        -DBUILD_SHARED_LIBS=ON
    
    make -j$JOBS
    make install
    
    # Generate module
    cat > "$MODULE_BASE/rocRAND.lua" << EOF
-- -*- lua -*-
local install_dir = "$INSTALL_BASE/rocRAND/$DATE"

prepend_path("CMAKE_PREFIX_PATH", install_dir)
prepend_path("CPATH", install_dir .. "/include")
prepend_path("LD_LIBRARY_PATH", install_dir .. "/lib")
prepend_path("LIBRARY_PATH", install_dir .. "/lib")
EOF
    
    log_info "rocRAND installed to $INSTALL_BASE/rocRAND/$DATE"
}

# Step 10: Build hipSPARSE
build_hipsparse() {
    log_info "Building hipSPARSE..."
    cd "$SRC_BASE"
    
    module load HIP/chipStar/main
    
    clone_or_update "git@github.com:CHIP-SPV/hipSPARSE.git" "hipSPARSE" "chipStar"
    
    cd hipSPARSE
    rm -rf build && mkdir build && cd build
    
    cmake .. \
        -DCMAKE_CXX_COMPILER=hipcc \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX="$INSTALL_BASE/hipSPARSE/$DATE" \
        -DBUILD_CLIENTS_TESTS=OFF \
        -DBUILD_CLIENTS_SAMPLES=OFF
    
    make -j$JOBS
    make install
    
    # Generate module
    cat > "$MODULE_BASE/hipSPARSE.lua" << EOF
-- -*- lua -*-
local install_dir = "$INSTALL_BASE/hipSPARSE/$DATE"

prepend_path("CMAKE_PREFIX_PATH", install_dir)
prepend_path("CPATH", install_dir .. "/include")
prepend_path("LD_LIBRARY_PATH", install_dir .. "/lib")
prepend_path("LIBRARY_PATH", install_dir .. "/lib")
EOF
    
    log_info "hipSPARSE installed to $INSTALL_BASE/hipSPARSE/$DATE"
}

# Step 11: Build hipMM
build_hipmm() {
    log_info "Building hipMM..."
    cd "$SRC_BASE"
    
    module load HIP/chipStar/main HIP/rocPRIM HIP/hipCUB HIP/rocThrust
    
    clone_or_update "git@github.com:CHIP-SPV/hipMM.git" "hipMM" "chipStar"
    
    cd hipMM
    rm -rf build && mkdir build && cd build
    
    cmake .. \
        -DCMAKE_CXX_COMPILER=hipcc \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX="$INSTALL_BASE/hipMM/$DATE" \
        -DBUILD_TESTS=OFF \
        -DBUILD_BENCHMARKS=OFF
    
    make -j$JOBS
    make install
    
    # Generate module
    cat > "$MODULE_BASE/hipMM.lua" << EOF
-- -*- lua -*-
local install_dir = "$INSTALL_BASE/hipMM/$DATE"

prepend_path("CMAKE_PREFIX_PATH", install_dir)
prepend_path("CPATH", install_dir .. "/include")
prepend_path("LD_LIBRARY_PATH", install_dir .. "/lib")
prepend_path("LIBRARY_PATH", install_dir .. "/lib")
prepend_path("PKG_CONFIG_PATH", install_dir .. "/lib/pkgconfig")
setenv("hipMM_ROOT", install_dir)
EOF
    
    log_info "hipMM installed to $INSTALL_BASE/hipMM/$DATE"
}

# Print summary
print_summary() {
    echo ""
    echo "=============================================="
    echo "CHIP-SPV Suite Installation Complete!"
    echo "=============================================="
    echo ""
    echo "Installation prefix: $INSTALL_BASE"
    echo "Module files: $MODULE_BASE"
    echo ""
    echo "To use, add to your shell:"
    echo "  module use $MODULE_BASE"
    echo ""
    echo "Then load modules:"
    echo "  module load llvm/21.0"
    echo "  module load HIP/chipStar/main"
    echo "  module load HIP/rocPRIM HIP/hipCUB HIP/rocThrust"
    echo "  module load HIP/hipMM"
    echo ""
    echo "Test with:"
    echo "  hipcc --version"
    echo ""
}

# Main execution
main() {
    log_info "Starting CHIP-SPV Suite Installation"
    log_info "Date: $DATE"
    log_info "Install base: $INSTALL_BASE"
    
    setup_dirs
    setup_env
    
    # Build in dependency order
    build_chipstar
    build_rocprim
    build_hipcub
    build_rocthrust
    build_hipblas
    build_hiprand
    build_rocrand
    build_hipsparse
    build_hipmm
    
    print_summary
}

# Allow running individual components
case "${1:-all}" in
    chipstar)   setup_dirs; setup_env; build_chipstar ;;
    rocprim)    setup_dirs; setup_env; build_rocprim ;;
    hipcub)     setup_dirs; setup_env; build_hipcub ;;
    rocthrust)  setup_dirs; setup_env; build_rocthrust ;;
    hipblas)    setup_dirs; setup_env; build_hipblas ;;
    hiprand)    setup_dirs; setup_env; build_hiprand ;;
    rocrand)    setup_dirs; setup_env; build_rocrand ;;
    hipsparse)  setup_dirs; setup_env; build_hipsparse ;;
    hipmm)      setup_dirs; setup_env; build_hipmm ;;
    all)        main ;;
    *)
        echo "Usage: $0 [component]"
        echo "Components: chipstar, rocprim, hipcub, rocthrust, hipblas, hiprand, rocrand, hipsparse, hipmm, all"
        exit 1
        ;;
esac
