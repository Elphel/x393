#!/bin/bash
# Updates vrlg.py to include predefines for pydev. Needed when new parameters are added to the Verilog header files
./test_mcntrl.py @cargs_test <<< $'pydev_predefines\nexit\n'
