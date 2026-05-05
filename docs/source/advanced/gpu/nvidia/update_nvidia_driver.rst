Update NVIDIA Driver
=====================

If the user wants to update the newer NVIDIA driver on the system,  follow the :doc:`CUDA repository setup </advanced/gpu/nvidia/repo_setup>` document to create another repository for the new driver.

The following example assumes the new driver is in ``/install/cuda/<distro>/<arch>/nvidia_new``.

Diskful
-------

#.  Change pkgdir for the cuda image: ::

      chdef -t osimage -o <osver>-<arch>-install-cuda \
        pkgdir=/install/cuda/<distro>/<arch>/nvidia_new

#.  Use xdsh command to remove all the NVIDIA rpms: ::

      xdsh <noderange> "dnf remove *nvidia* -y"

#.  Run updatenode command to update NVIDIA driver on the compute node: ::

      updatenode <noderange> -S

#.  Reboot compute node: ::

      rpower <noderange> off
      rpower <noderange> on

#.  Verify the newer driver level: ::

      nvidia-smi | grep Driver

Diskless
--------

To update a new NVIDIA driver on diskless compute nodes, re-generate the osimage pointing to the new NVIDIA driver repository and reboot the node to load the diskless image.

Refer to :doc:`CUDA osimage configuration </advanced/gpu/nvidia/osimage_setup>` for specific instructions.
