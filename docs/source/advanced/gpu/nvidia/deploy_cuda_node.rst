Deploy CUDA nodes
=================

Diskful
-------

Provision diskful nodes using the CUDA osimage::

    nodeset <noderange> osimage=<osver>-<arch>-install-cuda
    rsetboot <noderange> net
    rpower <noderange> boot

Diskless
--------

Provision diskless nodes using the CUDA osimage::

    nodeset <noderange> osimage=<osver>-<arch>-netboot-cuda
    rsetboot <noderange> net
    rpower <noderange> boot
