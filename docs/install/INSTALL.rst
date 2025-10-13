.. MIT License
..
.. Copyright (C) 2025 Advanced Micro Devices, Inc. All rights reserved.
..
.. Permission is hereby granted, free of charge, to any person obtaining a copy
.. of this software and associated documentation files (the "Software"), to deal
.. in the Software without restriction, including without limitation the rights
.. to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
.. copies of the Software, and to permit persons to whom the Software is
.. furnished to do so, subject to the following conditions:
..
.. The above copyright notice and this permission notice shall be included in all
.. copies or substantial portions of the Software.
..
.. THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
.. IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
.. FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
.. AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
.. LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
.. OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
.. SOFTWARE.

Installing hipMM
================

.. important::

   You can install hipMM via AMD PyPI (recommended for regular users) or build
   and install it from source (for developers).

Requirements
------------

hipMM requires ROCm 7.0.0 or later running on a ROCm-supported operating
system. Using Ubuntu 22.04 or later is recommended. See `hipMM supported
environments, features, and
interfaces <docs/install/hipMM-support.rst>`__ for more details,
including supported GPU architectures.

The steps in this guide require a Conda installation. A minimal free
version of Conda is `Miniforge <https://conda-forge.org/download/>`__.

Install hipMM via AMD PyPI
--------------------------

Packaged versions of hipMM and its dependencies are distributed via `AMD
PyPI <https://pypi.amd.com/simple>`__. This section discusses how to
install hipMM via this package index.

We recommend to install hipMM into a Conda environment that contains a
recent ``libstdcxx-ng`` package. Given the below minimal environment
(``conda/environments/rocm-70_install-x86_64.yaml``):

.. code:: yaml

   channels:
     - conda-forge
   dependencies:
   - python=3.12
   - libstdcxx-ng
   - pip
   - pip:
      - --pre
      - --extra-index-url=https://pypi.amd.com/simple
      - rocm-llvm-python~=7.0.0
      - hip-python~=7.0.0
      - hip-python-as-cuda~=7.0.0
      - numba-hip~=0.1.3
      - amd-cupy~=13.4
      - amd-hipmm==3.0.0
   name: hipmm

We can install both the environment and hipMM in it with a single
command:

.. code:: bash

   conda env create -f conda/environments/rocm-70_install-x86_64.yaml

After activating environment ``hipmm``, you can use ``import hipmm`` in
your Python code.

Verify correct installation
~~~~~~~~~~~~~~~~~~~~~~~~~~~

To verify the correctness of the installation, run:

.. code:: bash

   conda activate hipmm

   python3

Then enter the following code commands:

.. code:: python

   import hipmm

   print(hipmm.__version__)

You should see output that is similar to:

.. code:: text

   Python 3.12.11 | packaged by conda-forge | (main, Jun  4 2025, 14:45:31) [GCC 13.3.0] on linux
   Type "help", "copyright", "credits" or "license" for more information.
   >>> import hipmm
   >>> print(hipmm.__version__)
   '3.0.00'
