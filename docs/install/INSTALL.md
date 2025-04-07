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

---
myst:
  html_meta:
    "description": "ROCm Data Science (ROCm-DS) library for Data Frames."
    "keywords": "ROCm, ROCm-DS, Data Science, RAPIDS, AMD, CUDA, Data Frames, SDK"
---

# Building and Installing hipMM

**NOTE:** `hipMM` supports only AMD GPUs. Use the NVIDIA RAPIDS&reg; package for
NVIDIA GPUs.

hipMM is not distributed as a prebuilt package via Conda. You must build
and install it as described here.

## Install Conda

`hipMM` must be built inside of a predefined Conda environment to ensure that
it is working properly. You can install Conda with
[miniconda](https://www.anaconda.com/docs/getting-started/miniconda/install#quickstart-install-instructions),
or the full [Anaconda distribution](https://www.anaconda.com/download).

## Building hipMM from Source

### Get hipMM Dependencies

* You must have a full ROCm 6.4.0 installation on your system. See
  [ROCm installation](https://rocm.docs.amd.com/projects/install-on-linux/en/latest/)
  for more information. This guide assumes that the ROCm path is `/opt/rocm`.
* hipMM is supported only on Ubuntu 22.04
* GPU requirements: gfx942 or gfx90a
* `gcc` : version 9.3+
* `cmake` : version 3.26.4+
* hipMM requires Python versions 3.9 or 3.10 and the following Python packages:

  - `scikit-build`
  - `hip-python`
  - `hip-python-as-cuda`
  - `cython`

For more details, see [pyproject.toml](../../python/pyproject.toml)

### Steps to build hipMM from source

To install hipMM from source, ensure the dependencies are met and follow the steps below:

1. Clone the repository and submodules

   ```bash
   $ git clone --recurse-submodules https://github.com/ROCM-DS/hipMM.git
   $ cd hipMM
   ```

2. Create the conda development environment `hipmm_dev`

   ```bash
   # create the conda environment (assuming in base `hipMM` directory)
   $ conda env create --name hipmm_dev --file conda/environments/all_rocm_arch-x86_64.yaml
   # activate the environment
   $ conda activate hipmm_dev
   ```

3. Install ROCm dependencies that are not yet distributed via a conda channel.
   You must install HIP-Python and the optional Numba HIP dependency via the
   Github-distributed `numba-hip` package. Select dependencies of Numba HIP
   that agree with your ROCm installation by providing a parameter
   `rocm-${ROCM_MAJOR}-${ROCM-MINOR}-${ROCM-PATCH}` (example: `rocm-6-4-0`) in
   square brackets:

   **IMPORTANT:** Some `hipMM` dependencies are currently distributed via:
   https://test.pypi.org/simple`

   Prior to running `pip install`, you should specify
   `https://test.pypi.org/simple` as an additional global extra index URL.

   **Note:** Simply specifying the `--extra-index-url` command line option does
   not have the same effect.

   ```bash
   (hipmm_dev) $ pip install --upgrade pip
   (hipmm_dev) $ previous_urls=$(pip config get global.extra-index-url)  # optional, save previous URLs
   (hipmm_dev) $ pip config set global.extra-index-url "${previous_urls} https://test.pypi.org/simple"  # add extra URL
   (hipmm_dev) $ pip install numba-hip[rocm-${ROCM_MAJOR}-${ROCM-MINOR}-${ROCM-PATCH}]@git+https://github.com/rocm/numba-hip.git
   # example: pip install numba-hip[rocm-6-4-0]@git+https://github.com/rocm/numba-hip.git
   (hipmm_dev) $ pip config set global.extra-index-url "${previous_urls}"  # optional, restore previous URLs
   ```

4. Build and install `librmm` and `rmm` using `build.sh`.

   The `build.sh` command creates the `build` directory at the root of cloned
   hipMM git repository. Use `build.sh -h` to display the help text for the
   script. You can build and install `librmm` and `rmm` separately, and you can
   also build without installing using the `-n` option.

   **Note:** When building and installing `librmm` only, you can do this
   outside of the conda environment as described in Step 5.

   ```bash
   (hipmm_dev) $ export CXX="hipcc"    # Cython CXX compiler, adjust according to your setup.
   (hipmm_dev) $ export CMAKE_PREFIX_PATH="${CMAKE_PREFIX_PATH}:/opt/rocm/lib/cmake"     # Locate ROCm CMake packages
   (hipmm_dev) $ ./build.sh librmm rmm     # Build and install librmm and rmm (can also use the default ./build.sh)
   ```

   **Note:** When rebuilding it is recommended to remove previous build files.
   When you are using the `./build.sh` script, this can be accomplished by
   additionally specifying `clean`. For example: `./build.sh clean rmm`.

5. Build, install, and test the `rmm` python package, in the `python` folder:

   ```bash
   (hipmm_dev) $ python setup.py build_ext --inplace
   (hipmm_dev) $ python setup.py install
   (hipmm_dev) $ pytest -v
   ```

6. Build the `rmm` python package and create a binary wheel, in the `python`
   folder:

   ```bash
   (hipmm_dev) $ python3 setup.py bdist_wheel
   ```

Done! You have completed the build process, and are ready to develop for the
hipMM OSS project.

## Installing the hipMM Python wheel

When you install the hipMM-ROCm Python wheel, you can again specify the ROCm
version of the dependencies via the optional dependency key
`rocm-${ROCM_MAJOR}_${ROCM_MINOR}-${ROCM-PATCH}`. Again, you need to specify an
extra `pip` index URL to make it possible for `pip` to find some dependencies.

```bash
$ previous_urls=$(pip config get global.extra-index-url)  # optional, save previous URLs
$ pip config set global.extra-index-url "${previous_urls} https://test.pypi.org/simple"
$ pip install ${path_to_wheel}.whl[rocm-${ROCM_MAJOR}_${ROCM_MINOR}-${ROCM-PATCH}]
# example: pip install hipMM/python/dist/amd_hipmm-1.0.0b1-cp310-cp310-linux_x86_64.whl[rocm-6-4-0]
$ pip config set global.extra-index-url "${previous_urls}"  # optional, restore previous URLs
```

**IMPORTANT:** Each hipMM-ROCm wheel is built for a particular ROCm version
with `hipMM` dependencies for that version of ROCm. Using the wheel with an
incompatible ROCm installation or specifying dependencies that are not
compatible with the ROCm installation can result in errors.

## Installing librmm using CMake and make

As an alternative to the above process, you can build and install `librmm`
using `CMake` and `make` commands, and then run tests.

**Note:** `conda remove -n hipmm_dev --all`

As shown in the following commands, when compiling for AMD GPUs you must export
the `CXX` environment variable before building so that the Cython build process
uses a HIP-enabled C++ compiler.

You should also provide the location of ROCm CMake scripts to `CMake` using the
`CMAKE_PREFIX_PATH` CMake/environment variable.

```bash
(hipmm_dev) $ export CXX="hipcc"                                # Cython CXX compiler, adjust according to your setup.
(hipmm_dev) $ export CMAKE_PREFIX_PATH="${CMAKE_PREFIX_PATH}:/opt/rocm/lib/cmake" # ROCm CMake packages
(hipmm_dev) $ mkdir build                                       # make a build directory
(hipmm_dev) $ cd build                                          # enter the build directory
(hipmm_dev) $ cmake .. -DCMAKE_INSTALL_PREFIX=$CONDA_PREFIX     # configure CMake installation path, which must be writeable
(hipmm_dev) $ make -j                                           # install the header only library librmm.so ... '-j' will start a parallel job using the number of physical cores available on your system
(hipmm_dev) $ make install                                      # install the header only library librmm.so to the CMake installation path
```

Optionally run tests:

```bash
(hipmm_dev) $ cd build  # if you are not already in build directory
(hipmm_dev) $ make test  # this optional command will run the hipMM C++ unit tests.
```

## Caching third-party dependencies

hipMM uses [CPM.cmake](https://github.com/TheLartians/CPM.cmake) to handle
third-party dependencies like `spdlog`, `Thrust`, `GoogleTest`,
`GoogleBenchmark`. In general you won't have to worry about third-party
dependencies. If `CMake` finds an appropriate version on your system,
it uses it. Otherwise those dependencies will be downloaded as part of the
build.

**Note:** You can help by setting `CMAKE_PREFIX_PATH` to point to the
installed location of the third-party software.

If you frequently start new builds from scratch, consider setting the
environment variable `CPM_SOURCE_CACHE` to an external download
directory to avoid repeated downloads of the third-party dependencies.
