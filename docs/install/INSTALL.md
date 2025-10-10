<!---
    MIT License

    Copyright (C) 2025 Advanced Micro Devices, Inc. All rights reserved.

    Permission is hereby granted, free of charge, to any person obtaining a copy
    of this software and associated documentation files (the "Software"), to deal
    in the Software without restriction, including without limitation the rights
    to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
    copies of the Software, and to permit persons to whom the Software is
    furnished to do so, subject to the following conditions:

    The above copyright notice and this permission notice shall be included in all
    copies or substantial portions of the Software.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
    IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
    FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
    AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
    LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
    OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
    SOFTWARE.
-->

# Installing hipMM

> **IMPORTANT:**
> You can install hipMM via AMD PyPI (recommended for regular users) or build
> and install it from source (for developers).

## Requirements

hipMM requires ROCm 7.0.0 or later running on a ROCm-supported operating system. Using Ubuntu 22.04
or later is recommended.
See [hipMM supported environments, features, and interfaces ](docs/install/hipMM-support.rst)
for more details, including supported GPU architectures.

The following ROCm components must be installed:

- [hipBLAS](https://rocm.docs.amd.com/projects/hipBLAS/en/latest/index.html)
- [hipFFT](https://rocm.docs.amd.com/projects/hipFFT/en/latest/index.html)
- [hipRAND](https://rocm.docs.amd.com/projects/hipRAND/en/latest/index.html)
- [rocRAND](https://rocm.docs.amd.com/projects/rocRAND/en/latest/index.html)
- [hipSPARSE](https://rocm.docs.amd.com/projects/hipSPARSE/en/latest/)

The steps in this guide require a Conda installation.
A minimal free version of Conda is [Miniforge](https://conda-forge.org/download/).

## Install hipMM via AMD PyPI

Packaged versions of hipMM and its dependencies are distributed via
[AMD PyPI](https://pypi.amd.com/simple). This section discusses how to install
hipMM via this package index.

We recommend to install hipMM into a Conda environment that contains a recent `libstdcxx-ng`
package. Given the below minimal environment (`hipmm.yaml`):

```yaml
name: hipmm
channels:
  - conda-forge
dependencies:
  - python=3.12
  - libstdcxx-ng
  - pip
  - pip:
    - --pre
    - --extra-index-url=https://pypi.amd.com/simple
    - amd-hipmm==3.0.0
```

We can install both the environment and hipMM in it with a single command:

```bash
conda env create -f hipmm.yaml
```

After activating environment `hipmm`, you can use `import hipmm` in your Python code.
