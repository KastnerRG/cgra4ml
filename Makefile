.PHONY: image start kill enter ibuild irun iclean vivado kernel_prepare driver test_app bundle edf_sdt edf_overlay edf hw edf_deploy driver_install test_install

# Default parameters
FREQ_MHZ ?= 250
AXI_WIDTH ?= 64
ADDR_WIDTH ?= 32
AXIL_WIDTH ?= 32
TRACE ?= 1
OPTIMIZE ?= 0

# Testing

TEST := param_test
WORKDIR := run/work
RUN_DIR := run
DATA_DIR := $(WORKDIR)/data

# Cross-compilation
CROSS_COMPILE ?= aarch64-linux-gnu-
KERNEL_DIR    ?= $(CURDIR)/linux-xlnx

# Board store
BOARDSTORE_REPO  := https://github.com/Xilinx/XilinxBoardStore.git
BOARDSTORE_BRANCH:= 2024.2
BOARDSTORE       := $(RUN_DIR)/XilinxBoardStore

# FPGA board IP / user
BOARD_IP   ?= 192.168.2.10
BOARD_USER ?= amd-edf

# Vivado project name (must match vivado_flow.tcl)
PROJECT_NAME ?= dsf_zcu104

# EDF tool paths
SDTGEN = $(XILINX_VIVADO)/bin/sdtgen
LOPPER = $(XILINX_VIVADO)/bin/lopper
DTC    = $(XILINX_VIVADO)/bin/dtc

# EDF board configuration
EDF_BOARD_DTS_zcu104         = zcu104-reva
EDF_OVERLAY_TARGET_zcu104    = cortexa53_0
EDF_BOARD_DTS                = $(EDF_BOARD_DTS_zcu104)
EDF_OVERLAY_TARGET           = $(EDF_OVERLAY_TARGET_zcu104)
EDF_SDT_DIR                  = hw_project_sdt
EDF_FW_DIR                   = cgra4ml-fw

clean:
	rm -rf $(WORKDIR)*
	$(MAKE) -C ibex-soc clean 2>/dev/null || true
	rm -rf build *.vstf *.log *.ses .qverify .visualizer
	rm -rf $(KERNEL_DIR)

$(WORKDIR):
	mkdir -p $(WORKDIR)

$(DATA_DIR): | $(WORKDIR)
	mkdir -p $(DATA_DIR)

#----------------- FPGA FLOW ------------------

$(BOARDSTORE):
	@if [ ! -d "$(BOARDSTORE)" ]; then \
		echo "Cloning Xilinx BoardStore..."; \
		git clone --branch $(BOARDSTORE_BRANCH) --depth 1 "$(BOARDSTORE_REPO)" "$(BOARDSTORE)"; \
	else \
		echo "BoardStore already exists at $(BOARDSTORE)"; \
	fi

vivado: $(WORKDIR) $(BOARDSTORE)
	@if [ ! -f $(WORKDIR)/config_hw.tcl ]; then \
		echo "ERROR: config_hw.tcl not found. Run your Python script first (e.g., cd run/work && python ../example.py)"; \
		exit 1; \
	fi
	cd $(WORKDIR) && vivado -mode batch -source $(subst \,\\,$(abspath $(RUN_DIR)))/vivado_flow.tcl

#----------------- EDF / DEFERRED PL LOAD ------------------

.PHONY: edf_sdt
edf_sdt:
	@if [ ! -f $(WORKDIR)/$(PROJECT_NAME)/design_1_wrapper.xsa ]; then \
		echo "ERROR: XSA not found. Run 'make vivado' first."; \
		exit 1; \
	fi
	mkdir -p $(WORKDIR)/$(EDF_SDT_DIR)
	cd $(WORKDIR) && $(SDTGEN) $(abspath $(RUN_DIR))/gen_sdt.tcl \
		$(PROJECT_NAME)/design_1_wrapper.xsa \
		$(EDF_SDT_DIR) \
		$(EDF_BOARD_DTS)

.PHONY: edf_overlay
edf_overlay:
	@if [ ! -d $(WORKDIR)/$(EDF_SDT_DIR) ]; then \
		echo "ERROR: SDT directory not found. Run 'make edf_sdt' first."; \
		exit 1; \
	fi
	mkdir -p $(WORKDIR)/$(EDF_FW_DIR)
	cd $(WORKDIR) && LOPPER_DTC_FLAGS="-b 0 -@" $(LOPPER) --enhanced \
		-O $(EDF_FW_DIR) -f $(EDF_SDT_DIR)/system-top.dts \
		-- xlnx_overlay_dt $(EDF_OVERLAY_TARGET) full
	sed -i 's/\&fpga{/\&fpga_full{/' $(WORKDIR)/$(EDF_FW_DIR)/pl.dtsi
	sed -i 's/firmware-name = ".*"/firmware-name = "sa_accel.bit"/' $(WORKDIR)/$(EDF_FW_DIR)/pl.dtsi
	sed -i '/zyxclmm_drm/,/^	};/d' $(WORKDIR)/$(EDF_FW_DIR)/pl.dtsi
	printf '\t\tassigned-clocks = <&zynqmp_clk 0x47>;\n\t\tassigned-clock-rates = <100000000>;\n' > /tmp/ac.tmp && \
	sed -i '/xlnx,name = "top_0";/r /tmp/ac.tmp' $(WORKDIR)/$(EDF_FW_DIR)/pl.dtsi && \
	rm -f /tmp/ac.tmp
	$(DTC) -I dts -O dtb -o $(WORKDIR)/$(EDF_FW_DIR)/pl.dtbo $(WORKDIR)/$(EDF_FW_DIR)/pl.dtsi
	cp $(WORKDIR)/$(EDF_SDT_DIR)/design_1_wrapper.bit $(WORKDIR)/$(EDF_FW_DIR)/sa_accel.bit
	cp $(RUN_DIR)/shell.json $(WORKDIR)/$(EDF_FW_DIR)/

.PHONY: edf
edf: edf_sdt edf_overlay

.PHONY: hw
hw: vivado edf

smoke_test: $(WORKDIR)
	cd $(WORKDIR) && python -m pytest -s ../$(TEST).py

verify_ibex: $(WORKDIR)
	cd ibex-soc && python check_output.py

smoke_ibex: $(WORKDIR)
	make TEST=ibex_test smoke_test iclean ibuild irun verify_ibex

#----------------- KERNEL DRIVER & TEST APP ------------------

.PHONY: kernel_prepare
kernel_prepare:
	git clone --depth 1 -b xlnx_rebase_v6.12_LTS_2025.1 \
		https://github.com/Xilinx/linux-xlnx.git $(KERNEL_DIR)
	$(MAKE) -C $(KERNEL_DIR) ARCH=arm64 CROSS_COMPILE=$(CROSS_COMPILE) xilinx_defconfig
	$(MAKE) -C $(KERNEL_DIR) ARCH=arm64 CROSS_COMPILE=$(CROSS_COMPILE) modules_prepare
	cd $(KERNEL_DIR) && scripts/config --set-str CONFIG_LOCALVERSION "-xilinx"
	$(MAKE) -C $(KERNEL_DIR) ARCH=arm64 CROSS_COMPILE=$(CROSS_COMPILE) modules_prepare

.PHONY: driver
driver: deepsocflow/linux/driver/cgra4ml_main.c deepsocflow/linux/driver/Makefile
	$(MAKE) -C $(KERNEL_DIR) ARCH=arm64 CROSS_COMPILE=$(CROSS_COMPILE) \
		KBUILD_MODPOST_WARN=1 M=$(CURDIR)/deepsocflow/linux/driver modules

.PHONY: test_app
test_app:
	$(MAKE) -C linux_test CC=$(CROSS_COMPILE)gcc

.PHONY: lib
lib: $(WORKDIR)
	$(MAKE) -C linux_test CC=$(CROSS_COMPILE)gcc libinference.so
	cp linux_test/libinference.so $(WORKDIR)/

.PHONY: bundle
BUNDLE_DIR := deploy
bundle: lib test_app
	@mkdir -p $(BUNDLE_DIR)
	@for f in \
		linux_test/libinference.so \
		linux_test/inference \
		python/run_inference.py \
		deepsocflow/linux/driver/cgra4ml_drv.ko \
		run/work/wbx.bin; do \
		if [ -f $$f ]; then \
			cp $$f $(BUNDLE_DIR)/ && echo "  ✓ $$f"; \
		else \
			echo "  - $$f (not found, skipped)"; \
		fi; \
	done
	@echo "\n--- deploy/ ready ---"
	@echo "To deploy:  scp -r $(BUNDLE_DIR) $(BOARD_USER)@$(BOARD_IP):/home/$(BOARD_USER)/"

.PHONY: driver_install
driver_install: deepsocflow/linux/driver/cgra4ml_drv.ko
	scp $< $(BOARD_USER)@$(BOARD_IP):/tmp/


# Docker

USR       := $(shell id -un)
UID       := $(shell id -u)
GID       := $(shell id -g)
IMAGE     := $(USR)/cgra4ml-ibex:dev
CONTAINER := cgra4ml-ibex-$(USR)
HOSTNAME  := cgraibex
SHORTUSR  := $(shell id -un | cut -c1-4)

image:
	docker build \
		-f Dockerfile \
		--build-arg UID=$(UID) \
		--build-arg GID=$(GID) \
		--build-arg USERNAME=$(SHORTUSR) \
		-t $(IMAGE) .

start:
	docker run -d --name $(CONTAINER) \
		-h $(HOSTNAME) \
		--tty --interactive \
		-v $(PWD):/work \
		-w /work \
		$(IMAGE) bash -lc 'fusesoc library add sa_ip /work || true; tail -f /dev/null'

enter:
	docker exec -it $(CONTAINER) bash

kill:
	docker kill $(CONTAINER) || true
	docker rm   $(CONTAINER) || true

# Ibex

ibuild:
	${MAKE} -C ibex-soc build

irun:
	${MAKE} -C ibex-soc run

iclean:
	${MAKE} -C ibex-soc clean

iprint:
	${MAKE} -C ibex-soc print
