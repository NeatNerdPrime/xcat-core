Verify CUDA Installation
========================

The following verification steps only apply to the ``cuda`` (full) installations and require nodes with physical NVIDIA GPU hardware.

#. Verify driver version by looking at: ``/proc/driver/nvidia/version``: ::

    cat /proc/driver/nvidia/version

#. Verify the CUDA Toolkit version ::

    nvcc -V

#. Verify running CUDA GPU jobs by compiling the samples and executing the ``deviceQuery`` or ``bandwidthTest`` programs.

   * Compile the samples: ::

        git clone https://github.com/NVIDIA/cuda-samples.git
        cd cuda-samples/Samples/1_Utilities/deviceQuery
        make

   * Run the ``deviceQuery`` sample: ::

        ./deviceQuery

     A successful run will end with ``Result = PASS``.

   * Run the ``bandwidthTest`` sample: ::

        cd ../bandwidthTest
        make
        ./bandwidthTest

     A successful run will end with ``Result = PASS``.

    NOTE: The CUDA Samples are not meant for performance measurements. Results may vary when GPU Boost is enabled.
