# CGRA4ML Linux kernel driver Makefile
#
# Native PYNQ/PetaLinux build:
#   make
#
# Cross build example:
#   make ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- KDIR=/path/to/linux/build

obj-m += cgra4ml_drv.o

cgra4ml_drv-objs := \
    cgra4ml_main.o \
    cgra4ml_hw.o \
    cgra4ml_dma.o

KDIR ?= /lib/modules/$(shell uname -r)/build
PWD  := $(shell pwd)

ccflags-y += -Wall -Wextra

all:
	$(MAKE) -C $(KDIR) M=$(PWD) modules

clean:
	$(MAKE) -C $(KDIR) M=$(PWD) clean
	rm -f *.o *.ko *.mod *.mod.c *.symvers *.order .*.cmd
