CUDA repository setup
=====================

NVIDIA hosts package repositories at::

    https://developer.download.nvidia.com/compute/cuda/repos/<distro>/<arch>/

Where ``<distro>`` is one of ``rhel6``, ``rhel7``, ``rhel8``, ``rhel9``,
``rhel10``, ``sles11``, ``sles12``, ``sles15``, ``ubuntu1404``, ``ubuntu1604``,
``ubuntu1804``, ``ubuntu2004``, ``ubuntu2204``, ``ubuntu2404``, ``ubuntu2604``
and ``<arch>`` is ``x86_64``, ``ppc64le`` (RHEL 7-8, Ubuntu 14.04-16.04), or
``sbsa`` (ARM).

.. note::

   Older Ubuntu releases (14.04, 16.04) use ``ppc64el`` instead of
   ``ppc64le`` in the repository URL path.

Online setup
------------

If nodes have network access, point ``otherpkgdir`` at the NVIDIA URL directly::

    chdef -t osimage <osimage> -p \
      otherpkgdir=https://developer.download.nvidia.com/compute/cuda/repos/<distro>/<arch>

The ``otherpkgs`` postscript will configure this as a package repository on
the node during provisioning.

Offline setup (air-gapped clusters)
------------------------------------

For clusters without internet access, mirror the NVIDIA repository to a
local directory under ``/install`` on the management node.

RHEL
^^^^

Use ``dnf download`` (or ``yumdownloader`` on RHEL 7) on a system with internet
access to download the CUDA packages and their dependencies::

    mkdir -p /install/cuda/<distro>/<arch>
    dnf download --resolve --destdir /install/cuda/<distro>/<arch> cuda
    createrepo /install/cuda/<distro>/<arch>

For EPEL dependencies such as ``dkms``::

    dnf download --resolve --destdir /install/cuda/<distro>/<arch> dkms
    createrepo /install/cuda/<distro>/<arch>

SLES
^^^^

Use ``zypper download`` on a system with internet access::

    mkdir -p /install/cuda/<distro>/<arch>
    zypper --pkg-cache-dir /install/cuda/<distro>/<arch> download cuda
    createrepo /install/cuda/<distro>/<arch>

For a runtime-only installation, replace ``cuda`` with
``cuda-runtime-<major>-<minor>`` (e.g., ``cuda-runtime-13-2``).

Ubuntu
^^^^^^

Use ``apt download`` on a system with internet access::

    mkdir -p /install/cuda/<distro>/<arch>
    cd /install/cuda/<distro>/<arch>
    apt download cuda $(apt-cache depends --recurse --no-recommends \
        --no-suggests --no-conflicts --no-breaks --no-replaces \
        --no-enhances cuda | grep "^\w" | sort -u)
    dpkg-scanpackages . /dev/null | gzip -9c > Packages.gz

.. note::

   The offline approach requires downloading packages on a system running
   the same OS version and architecture as the target nodes. Transfer the
   resulting directory to the management node under ``/install``.
