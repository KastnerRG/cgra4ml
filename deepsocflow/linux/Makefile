PROJECT_ROOT  ?= $(CURDIR)/../..
KERNEL_DIR    ?= $(PROJECT_ROOT)/linux-xlnx
CROSS_COMPILE ?= aarch64-linux-gnu-
WORKDIR       ?= run/work
BOOTGEN       ?= /opt/Xilinx/2025.2/Vivado/bin/bootgen
EDF_SDT_DIR   ?= hw_project_sdt
EDF_FW_DIR    ?= cgra4ml-fw

.PHONY: kernel_prepare driver lib linux_example bundle bootgen linux clean

kernel_prepare:
	git clone --depth 1 -b xlnx_rebase_v6.12_LTS_2025.1 \
		https://github.com/Xilinx/linux-xlnx.git $(KERNEL_DIR)
	$(MAKE) -C $(KERNEL_DIR) ARCH=arm64 CROSS_COMPILE=$(CROSS_COMPILE) xilinx_defconfig
	$(MAKE) -C $(KERNEL_DIR) ARCH=arm64 CROSS_COMPILE=$(CROSS_COMPILE) modules_prepare
	cd $(KERNEL_DIR) && scripts/config --set-str CONFIG_LOCALVERSION "-xilinx"
	$(MAKE) -C $(KERNEL_DIR) ARCH=arm64 CROSS_COMPILE=$(CROSS_COMPILE) modules_prepare

driver: driver/cgra4ml_main.c driver/Makefile
	$(MAKE) -C $(KERNEL_DIR) ARCH=arm64 CROSS_COMPILE=$(CROSS_COMPILE) \
		KBUILD_MODPOST_WARN=1 M=$(CURDIR)/driver modules

lib:
	$(MAKE) -C test CC=$(CROSS_COMPILE)gcc libinference.so
	cp test/libinference.so $(PROJECT_ROOT)/$(WORKDIR)/

linux_example: lib
	$(CROSS_COMPILE)gcc -Wall -Wextra -O2 \
		-I$(PROJECT_ROOT)/deepsocflow/c \
		-I$(CURDIR)/driver \
		-I$(PROJECT_ROOT)/$(WORKDIR) \
		-o $(CURDIR)/linux_example \
		$(CURDIR)/linux_example.c \
		-Ltest -linference \
		-Wl,-rpath,'$$ORIGIN' -lm

bundle: lib linux_example
	@mkdir -p $(PROJECT_ROOT)/deploy
	@for f in \
		test/libinference.so \
		linux_example \
		linux_example.py \
		driver/cgra4ml_drv.ko \
		$(PROJECT_ROOT)/$(WORKDIR)/vectors/wbx.bin \
		$(PROJECT_ROOT)/$(WORKDIR)/$(EDF_FW_DIR); do \
		if [ -e $$f ]; then \
			cp -r $$f $(PROJECT_ROOT)/deploy/ && echo "  + $$f"; \
		else \
			echo "  - $$f (not found, skipped)"; \
		fi; \
	done

bootgen:
	echo "all: { $(abspath $(PROJECT_ROOT)/$(WORKDIR)/$(EDF_SDT_DIR)/design_1_wrapper.bit) }" \
		> $(PROJECT_ROOT)/$(WORKDIR)/convert.bif
	$(BOOTGEN) -arch zynqmp -image $(PROJECT_ROOT)/$(WORKDIR)/convert.bif \
		-process_bitstream bin -w
	rm -f $(PROJECT_ROOT)/$(WORKDIR)/convert.bif
	mv $(PROJECT_ROOT)/$(WORKDIR)/$(EDF_SDT_DIR)/design_1_wrapper.bit.bin \
		$(PROJECT_ROOT)/$(WORKDIR)/$(EDF_FW_DIR)/design_1_wrapper.bit.bin

linux: driver bootgen bundle
	@echo "\nAll Linux artifacts built and ready in deploy/"
	@echo "To deploy to board:"
	@echo "  scp -r deploy <user>@<ip>:"

clean:
	$(MAKE) -C test clean
	rm -f linux_example
