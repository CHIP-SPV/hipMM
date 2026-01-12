#!/bin/bash
# Reproducer script that demonstrates the issue and fix

echo "=== Testing without CCCL headers (should fail) ==="
/space/pvelesko/install/llvm/21.0/bin/clang++ \
  -I./include \
  -x hip --offload=spirv64 \
  -nohipwrapperinc \
  --hip-path=/space/pvelesko/install/HIP/chipStar/main \
  -include /space/pvelesko/install/HIP/chipStar/main/include/hip/spirv_fixups.h \
  test_reproducer.cpp 2>&1 | grep -E "fatal error.*cuda/stream_ref" || echo "Error not found (may have other errors)"

echo ""
echo "=== Testing with CCCL headers (should work) ==="
CCCL_INCLUDE=/space/pvelesko/chipStar/hipMM/build/_deps/libhipcxx-src/include
/space/pvelesko/install/llvm/21.0/bin/clang++ \
  -I./include \
  -I$CCCL_INCLUDE \
  -D_LIBCUDACXX_ALLOW_UNSUPPORTED_ARCHITECTURE \
  -x hip --offload=spirv64 \
  -nohipwrapperinc \
  --hip-path=/space/pvelesko/install/HIP/chipStar/main \
  -include /space/pvelesko/install/HIP/chipStar/main/include/hip/spirv_fixups.h \
  -L/space/pvelesko/install/HIP/chipStar/main/lib \
  -lCHIP -no-hip-rt -locml_host_math_funcs \
  test_reproducer.cpp -o test_reproducer 2>&1 | head -20

if [ -f test_reproducer ]; then
    echo "SUCCESS: Binary created"
    rm -f test_reproducer
else
    echo "FAILED: Binary not created"
fi

