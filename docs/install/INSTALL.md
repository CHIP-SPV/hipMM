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

# Installing hipMM

> **NOTE:**
> `hipMM` supports only AMD GPUs. Use the NVIDIA RAPIDS package for NVIDIA GPUs.

> **NOTE:**
> Currently, it is not possible to install `hipMM` via `conda`.

<!-- ### Conda

hipMM can be installed with Conda ([miniconda](https://conda.io/miniconda.html), or the full
[Anaconda distribution](https://www.anaconda.com/download)) from the `rapidsai` channel:

```bash
# NOTE: Conda installation not supported for hipMM for AMD GPUs.
# conda install -c rapidsai -c conda-forge -c nvidia rmm cuda-version=11.8
```

We also provide [nightly Conda packages](https://anaconda.org/rapidsai-nightly) built from the HEAD
of our latest development branch.

Note: hipMM is supported only on Linux, and only tested with Python versions 3.9 and 3.10.


Note: The hipMM package from Conda requires building with GCC 9 or later. Otherwise, your application may fail to build.

See the [Get RAPIDS version picker](https://rapids.ai/start.html) for more OS and version info. -->

## Building from Source

### Get hipMM Dependencies

Compiler requirements:

* `gcc`                    version 9.3+
* ROCm HIP SDK compilers   version 5.6.0+, recommended is 6.3.0+
* `cmake`                  version 3.26.4+

GPU requirements:

* ROCm HIP SDK 5.6.0+, recommended is 6.3.0+

Python requirements:
* `scikit-build`
* `hip-python`
* `hip-python-as-cuda`
* `cython`

For more details, see [pyproject.toml](python/pyproject.toml)


### Script to build hipMM from source

To install hipMM from source, ensure the dependencies are met and follow the steps below:

- Clone the repository and submodules
```bash
$ git clone --recurse-submodules https://github.com/ROCM/hipMM.git
$ cd rmm
```

- Create the conda development environment `rmm_dev`
```bash
# create the conda environment (assuming in base `rmm` directory)
$ conda env create --name rmm_dev --file conda/environments/all_rocm_arch-x86_64.yaml
# activate the environment
$ conda activate rmm_dev
```

- Install ROCm dependencies that are not yet distributed via a conda channel. We install HIP Python and the optional Numba HIP dependency via the Github-distributed `numba-hip` package. We select dependencies of Numba HIP that agree with our ROCm installation by providing a parameter `rocm-${ROCM_MAJOR}-${ROCM-MINOR}-${ROCM-PATCH}`
(example: `rocm-6-1-2`) in square brackets:

> **IMPORTANT:**
> Some hipMM dependencies are currently distributed via: https://test.pypi.org/simple
> We need to specify 'https://test.pypi.org/simple' as additional global extra index URL.
> To append the URL and not overwrite what else is specified already, we combine `pip
> config set` and `pip config get` as shown below. We further restore the original URLs.
> (Note that specifying the `--extra-index-url` command line option does not have
> the same effect.)

```bash
(rmm_dev) $ pip install --upgrade pip
(rmm_dev) $ previous_urls=$(pip config get global.extra-index-url)
(rmm_dev) $ pip config set global.extra-index-url "${previous_urls} https://test.pypi.org/simple"
(rmm_dev) $ pip install numba-hip[rocm-${ROCM_MAJOR}-${ROCM-MINOR}-${ROCM-PATCH}]@git+https://github.com/rocm/numba-hip.git
# example: pip install numba-hip[rocm-6-1-2]@git+https://github.com/rocm/numba-hip.git
(rmm_dev) $ pip config set global.extra-index-url "${previous_urls}" # restore urls
```

> **IMPORTANT:**
> When compiling for AMD GPUs, we always need to set the environment variable `CXX` before building so that the Cython build process uses a HIP C++ compiler.
>
> Example:
>
> `(rmm_dev) $ export CXX=hipcc`
>
> We further need to provide the location of the ROCm CMake scripts to CMake via the `CMAKE_PREFIX_PATH` CMake or environment variable. We append via the `:` char to not modify configurations performeed by the active Conda environment.
>
> Example:
>
> `(rmm_dev) $ export CMAKE_PREFIX_PATH="${CMAKE_PREFIX_PATH}:/opt/rocm/lib/cmake"`
>

- Build and install `librmm` using cmake & make.

```bash

(rmm_dev) $ export CXX="hipcc"                                # Cython CXX compiler, adjust according to your setup.
(rmm_dev) $ export CMAKE_PREFIX_PATH="${CMAKE_PREFIX_PATH}:/opt/rocm/lib/cmake" # ROCm CMake packages
(rmm_dev) $ mkdir build                                       # make a build directory
(rmm_dev) $ cd build                                          # enter the build directory
(rmm_dev) $ cmake .. -DCMAKE_INSTALL_PREFIX=/install/path     # configure cmake ... use $CONDA_PREFIX if you're using Anaconda
(rmm_dev) $ make -j                                           # compile the library librmm.so ... '-j' will start a parallel job using the number of physical cores available on your system
(rmm_dev) $ make install                                      # install the library librmm.so to '/install/path'
```

- Building and installing `librmm` and `rmm` using build.sh. Build.sh creates build dir at root of
  git repository.

```bash

(rmm_dev) $ export CXX="hipcc"                                # Cython CXX compiler, adjust according to your setup.
(rmm_dev) $ export CMAKE_PREFIX_PATH="${CMAKE_PREFIX_PATH}:/opt/rocm/lib/cmake" # ROCm CMake packages
(rmm_dev) $ ./build.sh -h                                     # Display help and exit
(rmm_dev) $ ./build.sh -n librmm                              # Build librmm without installing
(rmm_dev) $ ./build.sh -n rmm                                 # Build rmm without installing
(rmm_dev) $ ./build.sh -n librmm rmm                          # Build librmm and rmm without installing
(rmm_dev) $ ./build.sh librmm rmm                             # Build and install librmm and rmm
```

> [!Note]
> Before rebuilding, it is recommended to remove previous build files.
> When you are using the `./build.sh` script, this can be accomplished
> by additionally specifying `clean` (example: `./build.sh clean rmm`).

- To run tests (Optional):
```bash
(rmm_dev) $ cd build (if you are not already in build directory)
$ make test
```

- Build, install, and test the `rmm` python package, in the `python` folder:
```bash
(rmm_dev) $ export CXX="hipcc" # Cython CXX compiler, adjust according to your setup.
(rmm_dev) $ export CMAKE_PREFIX_PATH="${CMAKE_PREFIX_PATH}:/opt/rocm/lib/cmake" # ROCm CMake packages
(rmm_dev) $ python setup.py build_ext --inplace
(rmm_dev) $ python setup.py install
(rmm_dev) $ pytest -v
```

- Build the `rmm` python package and create a binary wheel, in the `python` folder:
```bash
(rmm_dev) $ export CXX="hipcc" # Cython CXX compiler, adjust according to your setup.
(rmm_dev) $ export CMAKE_PREFIX_PATH="${CMAKE_PREFIX_PATH}:/opt/rocm/lib/cmake" # ROCm CMake packages
(rmm_dev) $ python3 setup.py bdist_wheel
```

Done! You are ready to develop for the hipMM OSS project.

### Installing a hipMM Python wheel

When you install the hipMM-ROCm Python wheel, you can again specify the ROCm version of the dependencies via the optional dependency key `rocm-${ROCM_MAJOR}_${ROCM_MINOR}-${ROCM-PATCH}`. Again, you need to specify an extra `pip` index URL to make it possible for `pip` to find some dependencies.

```bash
$ previous_urls=$(pip config get global.extra-index-url)
$ pip config set global.extra-index-url "${previous_urls} https://test.pypi.org/simple"

$ pip install ${path_to_wheel}.whl[rocm-${ROCM_MAJOR}_${ROCM_MINOR}-${ROCM-PATCH}]
# example: pip install ${path_to_wheel}.whl[rocm-6-1-2]
```

> **IMPORTANT:**
> Each hipMM-ROCm wheel has been built against a particular ROCm version.
> The ROCm dependency key helps you to install hipMM dependencies for this
> particular ROCm version. Using the wheel with an incompatible
> ROCm installation or specifying dependencies that are not compatible
> with the ROCm installation assumed by the hipMM wheel,
> will likely result in issues.

### Caching third-party dependencies

hipMM uses [CPM.cmake](https://github.com/TheLartians/CPM.cmake) to
handle third-party dependencies like spdlog, Thrust, GoogleTest,
GoogleBenchmark. In general you won't have to worry about it. If CMake
finds an appropriate version on your system, it uses it (you can
help it along by setting `CMAKE_PREFIX_PATH` to point to the
installed location). Otherwise those dependencies will be downloaded as
part of the build.

If you frequently start new builds from scratch, consider setting the
environment variable `CPM_SOURCE_CACHE` to an external download
directory to avoid repeated downloads of the third-party dependencies.
