## README

When building this package for conda there will still be a base dependency on the glibc of the build system. Therefore, make sure your build system has a glibc version that is lower or equal to the system where you eventually intend to deploy the package.

To build this package on the Minerva cluster, make sure to request an interactive node:

> bsub -P AllocationAccount -q interactive -n 8 -W 60 -R span[hosts=1] -XF -Is /bin/bash