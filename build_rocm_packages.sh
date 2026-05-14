#!/usr/bin/env bash
# build_rocm_packages.sh
# Build CuMesh (cumesh_vb) and other CUDA-only packages for ROCm from source.
# Usage: ./build_rocm_packages.sh [python] [gpu_archs]
set -euo pipefail

PYTHON="${1:-python3}"
GPU_ARCHS="${2:-gfx1151}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="/tmp/trellis2-rocm-build"

echo "[build-rocm] Python: $PYTHON | GPU archs: $GPU_ARCHS | Build dir: $BUILD_DIR"
mkdir -p "$BUILD_DIR"

# --------------------------------------------------
# CuMesh
# --------------------------------------------------
CUMESH_DIR="$BUILD_DIR/CuMesh"
if [ ! -d "$CUMESH_DIR" ]; then
    echo "[build-rocm] Cloning CuMesh..."
    git clone --recursive https://github.com/JeffreyXiang/CuMesh.git "$CUMESH_DIR"
fi

cd "$CUMESH_DIR"

if [ ! -f ".rocm_patched" ]; then
    echo "[build-rocm] Applying ROCm patches..."
    "$PYTHON" -c "
import os
root = '$CUMESH_DIR'

# 1. dtypes.cuh: Vec3f default constructor needs __host__ for hipcub
with open(os.path.join(root, 'src/dtypes.cuh')) as f:
    c = f.read()
c = c.replace('__device__ __forceinline__ Vec3f();', '__host__ __device__ __forceinline__ Vec3f();')
c = c.replace('__device__ __forceinline__ Vec3f::Vec3f() {', '__host__ __device__ __forceinline__ Vec3f::Vec3f() {')
with open(os.path.join(root, 'src/dtypes.cuh'), 'w') as f:
    f.write(c)
print('  dtypes.cuh patched')

# 2. clean_up.cu: use rocprim::tuple for HIP decomposer
with open(os.path.join(root, 'src/clean_up.cu')) as f:
    c = f.read()
# Replace the int3_decomposer struct
old = '''struct int3_decomposer
{
    __host__ __device__ ::cuda::std::tuple<int&, int&, int&> operator()(int3& key) const
    {
        return {key.x, key.y, key.z};
    }
};'''
new = '''struct int3_decomposer
{
    __host__ __device__
    #ifdef __HIPCC__
    rocprim::tuple<int&, int&, int&> operator()(int3& key) const
    {
        return rocprim::tuple<int&, int&, int&>(key.x, key.y, key.z);
    }
    #else
    ::cuda::std::tuple<int&, int&, int&> operator()(int3& key) const
    {
        return {key.x, key.y, key.z};
    }
    #endif
};'''
if old in c:
    c = c.replace(old, new)
    with open(os.path.join(root, 'src/clean_up.cu'), 'w') as f:
        f.write(c)
    print('  clean_up.cu patched')
else:
    print('  clean_up.cu: pattern not found or already patched')

# 3. setup.py: skip --extended-lambda for HIP
with open(os.path.join(root, 'setup.py')) as f:
    c = f.read()
old_setup = '''                \"--extended-lambda\",'''
new_setup = '''            ] + ([] if IS_HIP else [\"--extended-lambda\"]) + ['''
# Check if already patched
if 'IS_HIP else' not in c:
    c = c.replace(old_setup, new_setup)
    with open(os.path.join(root, 'setup.py'), 'w') as f:
        f.write(c)
    print('  setup.py patched')
else:
    print('  setup.py already patched')
"
    touch .rocm_patched
    echo "[build-rocm] Patches applied"
fi

echo "[build-rocm] Building CuMesh..."
BUILD_TARGET=rocm GPU_ARCHS="$GPU_ARCHS" "$PYTHON" -m pip install \
    --no-build-isolation --no-deps --force-reinstall "$CUMESH_DIR"

echo "[build-rocm] CuMesh build complete"

# Create cumesh_vb symlink
PACKAGES_DIR=$( "$PYTHON" -c "import site; print(site.getsitepackages()[0])" )
if [ ! -L "$PACKAGES_DIR/cumesh_vb" ] && [ ! -d "$PACKAGES_DIR/cumesh_vb" ]; then
    ln -sf "$PACKAGES_DIR/cumesh" "$PACKAGES_DIR/cumesh_vb"
    echo "[build-rocm] Created cumesh_vb -> cumesh symlink"
fi

# Verify
echo "[build-rocm] Verifying..."
"$PYTHON" -c "
import cumesh_vb as CuMesh; print('cumesh_vb OK')
CuMesh.CuMesh(); print('CuMesh() OK')
from cumesh_vb import _C; print('_C OK')
from cumesh_vb.bvh import cuBVH; print('cuBVH OK')
from cumesh_vb.remeshing import remesh_narrow_band_dc; print('remeshing OK')
"
echo "[build-rocm] Success!"
