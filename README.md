x393
=====

![x393 Block Diagram](x393_diagram.png)

FPGA code for Elphel 393 camera, created with [VDT plugin](https://git.elphel.com/Elphel/vdt-plugin). It runs on Xilinx Zynq 7030 SoC (FPGA plus dual ARM).

[Documentation](https://docs.elphel.com/x393) is generated with Doxygen-based Doxverilog.

Run ./INIT_PROJECT in the top directory to copy initial .project and .pydevproject files for Eclipse

Simulation of this project requires some files from the Xilinx proprietary _unisims_ library (list of dependencies
is in this [blog post](https://blog.elphel.com/2016/03/free-fpga-reimplement-the-primitives-models/)).
[VDT plugin](https://git.elphel.com/Elphel/vdt-plugin) README file describes steps needed after installation of Xilinx software
(unisims library is not distributed separately). 

Python program used on the target and during Cocotb simulation requires Python numpy module, on Ubuntu you may
install it with
```
sudo apt-get install python-numpy
```
