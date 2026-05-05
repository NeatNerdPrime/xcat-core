NVIDIA CUDA
===========

CUDA (Compute Unified Device Architecture) is a parallel computing platform and programming model created by NVIDIA.  It can be used to increase computing performance by leveraging the Graphics Processing Units (GPUs).

For more information, see NVIDIAs website: https://developer.nvidia.com/cuda-zone

xCAT supports CUDA installation for both diskful and diskless nodes using the ``otherpkgs`` mechanism.  The following OS and architecture combinations are supported by NVIDIA's CUDA repository:

.. list-table::
   :header-rows: 1

   * - OS family
     - x86_64
     - ppc64le
     - sbsa (ARM)
   * - RHEL 6
     - Yes
     -
     -
   * - RHEL 7
     - Yes
     - Yes
     -
   * - RHEL 8
     - Yes
     - Yes
     - Yes
   * - RHEL 9
     - Yes
     -
     - Yes
   * - RHEL 10
     - Yes
     -
     - Yes
   * - SLES 11
     - Yes
     -
     -
   * - SLES 12
     - Yes
     -
     -
   * - SLES 15
     - Yes
     -
     - Yes
   * - Ubuntu 14.04
     - Yes
     - Yes
     -
   * - Ubuntu 16.04
     - Yes
     - Yes
     -
   * - Ubuntu 18.04
     - Yes
     -
     - Yes
   * - Ubuntu 20.04
     - Yes
     -
     - Yes
   * - Ubuntu 22.04
     - Yes
     -
     - Yes
   * - Ubuntu 24.04
     - Yes
     -
     - Yes
   * - Ubuntu 26.04
     - Yes
     -
     - Yes

Within the NVIDIA CUDA Toolkit, installing the ``cuda`` package will install both the ``cuda-runtime`` and the ``cuda-toolkit``.  The ``cuda-toolkit`` is intended for developing CUDA programs and monitoring CUDA jobs.  If your particular installation requires only running GPU jobs, it's recommended to install only the ``cuda-runtime-<major>-<minor>`` package (e.g., ``cuda-runtime-13-2``).

.. toctree::
   :maxdepth: 2

   repo_setup
   osimage_setup
   deploy_cuda_node
   verify_cuda_install
   management
   update_nvidia_driver
