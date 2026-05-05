CUDA osimage configuration
==========================

CUDA packages are installed through xCAT's ``otherpkgs``.  Replace
``<osver>``, ``<arch>``, and ``<distro>`` below with your values
(e.g., ``rocky10.1``, ``x86_64``, ``rhel10``).

Diskful nodes (RHEL)
------------------

#. Create a copy of the base install osimage for CUDA::

    lsdef -t osimage -z <osver>-<arch>-install-compute \
      | sed 's/install-compute:/install-cuda:/' \
      | mkdef -z

#. Add the CUDA repository to the ``pkgdir`` attribute.

   For online setups, use the NVIDIA repository URL directly::

    chdef -t osimage <osver>-<arch>-install-cuda -p \
      pkgdir=https://developer.download.nvidia.com/compute/cuda/repos/<distro>/<arch>

   For offline setups with a local mirror::

    chdef -t osimage <osver>-<arch>-install-cuda -p \
      pkgdir=/install/cuda/<distro>/<arch>

#. Create a pkglist file for the CUDA packages::

    mkdir -p /install/custom/install/rh
    echo "cuda" > /install/custom/install/rh/cuda.pkglist

   Or for runtime-only installations::

    echo "cuda-runtime-13-2" > /install/custom/install/rh/cuda-runtime.pkglist

#. Set the pkglist on the osimage::

    chdef -t osimage <osver>-<arch>-install-cuda \
      pkglist=/install/custom/install/rh/cuda.pkglist

.. note::

   For diskful installations, the CUDA packages should be installed via the
   ``pkglist`` attribute so that the required reboot after driver installation
   happens naturally at the end of the OS install.

Diskful nodes (Ubuntu)
----------------------

#. Create a copy of the base install osimage::

    lsdef -t osimage -z <osver>-<arch>-install-compute \
      | sed 's/install-compute:/install-cuda:/' \
      | mkdef -z

#. Add the CUDA repository.

   For online setups::

    chdef -t osimage <osver>-<arch>-install-cuda -p \
      otherpkgdir=https://developer.download.nvidia.com/compute/cuda/repos/<distro>/<arch>

   For offline setups::

    chdef -t osimage <osver>-<arch>-install-cuda -p \
      otherpkgdir=/install/cuda/<distro>/<arch>

#. Create an otherpkgs.pkglist file::

    mkdir -p /install/custom/install/ubuntu
    echo "cuda" > /install/custom/install/ubuntu/cuda.otherpkgs.pkglist

#. Set it on the osimage::

    chdef -t osimage <osver>-<arch>-install-cuda \
      otherpkglist=/install/custom/install/ubuntu/cuda.otherpkgs.pkglist

Diskless nodes
--------------

For diskless (stateless) nodes, the CUDA packages must be installed via
``otherpkglist`` (not ``pkglist``). The reboot requirement for CUDA drivers
does not apply since diskless nodes reload the image on each boot.

#. Create a copy of the netboot osimage::

    lsdef -t osimage -z <osver>-<arch>-netboot-compute \
      | sed 's/netboot-compute:/netboot-cuda:/' \
      | mkdef -z

#. Add the CUDA repo to ``otherpkgdir``.

   For online setups::

    chdef -t osimage <osver>-<arch>-netboot-cuda -p \
      otherpkgdir=https://developer.download.nvidia.com/compute/cuda/repos/<distro>/<arch>

   For offline setups with a local mirror::

    chdef -t osimage <osver>-<arch>-netboot-cuda -p \
      otherpkgdir=/install/cuda/<distro>/<arch>

#. Create an otherpkgs.pkglist::

    mkdir -p /install/custom/netboot/rh
    echo "cuda" > /install/custom/netboot/rh/cuda.otherpkgs.pkglist

#. Set it and rebuild the image::

    chdef -t osimage <osver>-<arch>-netboot-cuda \
      otherpkglist=/install/custom/netboot/rh/cuda.otherpkgs.pkglist

    genimage <osver>-<arch>-netboot-cuda
    packimage <osver>-<arch>-netboot-cuda

POWER9 setup
-------------

NVIDIA POWER9 CUDA drivers need additional configuration. See:
https://docs.nvidia.com/cuda/cuda-installation-guide-linux/index.html#power9-setup

xCAT includes a sample script ``cuda_power9_setup`` to handle this.

For diskful nodes::

    chdef <noderange> -p postscripts=cuda_power9_setup

For diskless nodes, add it to the osimage postinstall script::

    cp /opt/xcat/share/xcat/netboot/rh/compute.<osver>.<arch>.postinstall \
      /install/custom/netboot/rh/cuda.<osver>.<arch>.postinstall

    echo "/install/postscripts/cuda_power9_setup" >> \
      /install/custom/netboot/rh/cuda.<osver>.<arch>.postinstall

    chdef -t osimage <osver>-<arch>-netboot-cuda \
      postinstall=/install/custom/netboot/rh/cuda.<osver>.<arch>.postinstall

Post-installation configuration
--------------------------------

NVIDIA recommends setting PATH and LD_LIBRARY_PATH for CUDA. xCAT provides
a sample postscript ``config_cuda`` for this::

    chdef <noderange> -p postscripts=config_cuda

To set GPU attributes on each boot (these do not persist across reboots),
create a postscript that runs ``nvidia-smi`` commands. For example, to enable
persistence mode::

    nvidia-smi -pm 1
