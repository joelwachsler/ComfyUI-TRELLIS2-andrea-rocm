# ComfyUI-TRELLIS2

## Installation

Three options, in order of speed → reliability:

1. **ComfyUI Manager (recommended)** — search for `TRELLIS2` in the Manager and click Install from the highest version displayed. If that doesn't work, try nightly.
2. **Manager via Git URL** — in ComfyUI Manager: "Install via Git URL" with `https://github.com/PozzettiAndrea/ComfyUI-TRELLIS2.git`.
3. **Manual (most reliable)**:
   ```bash
   cd ComfyUI/custom_nodes
   git clone https://github.com/PozzettiAndrea/ComfyUI-TRELLIS2.git
   cd ComfyUI-TRELLIS2
   pip install -r requirements.txt --upgrade
   python install.py
   ```

## ROCm (AMD GPU) Installation

Tested on **AMD Radeon 8060S** (gfx1151) with ROCm 7.2 / PyTorch 2.12.0+rocm7.2.

Some dependencies are CUDA-only and must be built from source for ROCm:

```bash
# 1. Clone this fork
cd ComfyUI/custom_nodes
git clone https://github.com/joelwachsler/ComfyUI-TRELLIS2-andrea-rocm.git
cd ComfyUI-TRELLIS2-andrea-rocm

# 2. Install pip dependencies
pip install easydict timm plyfile zstandard opencv-python-headless

# 3. Build CUDA extension packages from source for ROCm
BUILD_TARGET=rocm GPU_ARCHS=gfx1151 pip install . --no-build-isolation

# 4. Build CuMesh
./build_rocm_packages.sh  # pass GPU arch if not gfx1151

# 5. Build flex_gemm
git clone https://github.com/JeffreyXiang/FlexGEMM.git
BUILD_TARGET=rocm GPU_ARCHS=gfx1151 pip install ./FlexGEMM --no-build-isolation

# 6. Install o-voxel (from TRELLIS.2 source)
git clone https://github.com/microsoft/TRELLIS.2.git
BUILD_TARGET=rocm GPU_ARCHS=gfx1151 pip install ./TRELLIS.2/o-voxel/ --no-build-isolation --no-deps

# 7. Create symlinks (_ap / _vb aliases)
PACKAGES_DIR=$(python -c "import site; print(site.getsitepackages()[0])")
ln -sf $PACKAGES_DIR/flex_gemm $PACKAGES_DIR/flex_gemm_ap
ln -sf $PACKAGES_DIR/cumesh $PACKAGES_DIR/cumesh_vb
ln -sf $PACKAGES_DIR/o_voxel $PACKAGES_DIR/o_voxel_vb_ap
```

### Known Limitations on ROCm
- **drtk** (CUDA-only) — falls back to pure-PyTorch UV rasterizer (slower but functional)
- **nvdiffrast** (CUDA-only) — texture baking uses the PyTorch fallback path
- **Tiled sparse conv** disabled — source-built `flex_gemm` lacks `SubMConv3dFunction.tiled_forward`

### Environment Variables
Add these to your ComfyUI service to prevent deadlocks:
```
FLEX_GEMM_USE_AUTOTUNE_CACHE=0
FLEX_GEMM_AUTOSAVE_AUTOTUNE_CACHE=0
```

> **Please report any problems** you hit during installation or use of my nodes — open a [Discussion](https://github.com/PozzettiAndrea/ComfyUI-TRELLIS2/discussions) or [Issue](https://github.com/PozzettiAndrea/ComfyUI-TRELLIS2/issues). Very grateful for your help! 🙏

---


<div align="center">
<a href="https://pozzettiandrea.github.io/ComfyUI-TRELLIS2/">
<img src="https://pozzettiandrea.github.io/ComfyUI-TRELLIS2/gallery-preview.png" alt="Workflow Test Gallery" width="800">
</a>
<br>
<b><a href="https://pozzettiandrea.github.io/ComfyUI-TRELLIS2/">View Live Test Gallery →</a></b>
</div>

ComfyUI custom nodes for [TRELLIS.2](https://github.com/microsoft/TRELLIS.2) - Microsoft's state-of-the-art image-to-3D generation model.

Generate high-quality 3D meshes with PBR (Physically Based Rendering) materials from a single image.



## Example Workfloww

![tpose](docs/tpose.png)

![rmbg](docs/rmbg.png)


https://github.com/user-attachments/assets/e28e4a74-b119-4303-8e30-63361f26aa88

## Community

Questions or feature requests? Open a [Discussion](https://github.com/PozzettiAndrea/ComfyUI-TRELLIS2/discussions) on GitHub.

Join the [Comfy3D Discord](https://discord.gg/bcdQCUjnHE) for help, updates, and chat about 3D workflows in ComfyUI.

## Credits

- [TRELLIS.2](https://github.com/microsoft/TRELLIS.2) by Microsoft Research

## Contributing

Contributions are welcome! Please feel free to submit issues and pull requests.