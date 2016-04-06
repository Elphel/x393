#!/bin/sh
#mkdir -p /lib/modules
#ln -sf /usr/local/lib /lib/modules/4.0.0-xilinx
insmod /usr/local/lib/fpgajtag.ko
#mknod  -m 0666 /dev/fjtag              c 132   2
mknod  -m 0666 /dev/fpgaresetjtag      c 132   0
mknod  -m 0666 /dev/jtagraw            c 132   0
mknod  -m 0666 /dev/fpgaconfjtag       c 132   1
mknod  -m 0666 /dev/sfpgaconfjtag      c 132   2
mknod  -m 0666 /dev/afpgaconfjtag      c 132   3
#mknod  -m 0666 /dev/fpgabscan          c 132   5 
#mknod  -m 0666 /dev/sfpgabscan         c 132   6
#mknod  -m 0666 /dev/afpgabscan         c 132   7

mknod  -m 0666 /dev/sfpgaconfjtag0     c 132   8
mknod  -m 0666 /dev/sfpgaconfjtag1     c 132   9
mknod  -m 0666 /dev/sfpgaconfjtag2     c 132   10
mknod  -m 0666 /dev/sfpgaconfjtag3     c 132   11

mknod  -m 0666 /dev/sfpgabscan0        c 132   12
mknod  -m 0666 /dev/sfpgabscan1        c 132   13
mknod  -m 0666 /dev/sfpgabscan2        c 132   14
mknod  -m 0666 /dev/sfpgabscan3        c 132   15


#	@$(MKNOD) -m 0666           $(DEV)/fpgaresetjtag      c 132   0
#	@$(MKNOD) -m 0666           $(DEV)/jtagraw            c 132   0
#	@$(MKNOD) -m 0666           $(DEV)/fpgaconfjtag       c 132   1
#	@$(MKNOD) -m 0666           $(DEV)/sfpgaconfjtag      c 132   2
#	@$(MKNOD) -m 0666           $(DEV)/afpgaconfjtag      c 132   3
#	@$(MKNOD) -m 0666           $(DEV)/fpgabscan          c 132   5
#	@$(MKNOD) -m 0666           $(DEV)/sfpgabscan         c 132   6
#	@$(MKNOD) -m 0666           $(DEV)/afpgabscan         c 132   7
