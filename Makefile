.PHONY: clean vivado edf_sdt edf_overlay edf hw \
	smoke_test verify_ibex smoke_ibex \
	kernel_prepare driver lib linux_example bundle bootgen linux \
	image start kill enter ibuild irun iclean iprint

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

# Vivado project name (must match vivado_flow.tcl)
PROJECT_NAME ?= dsf_zcu104

# EDF tool paths
SDTGEN = $(XILINX_VIVADO)/bin/sdtgen
LOPPER = $(XILINX_VIVADO)/bin/lopper
DTC      = $(XILINX_VIVADO)/bin/dtc
BOOTGEN  = $(XILINX_VIVADO)/bin/bootgen

# EDF board configuration (derived from PROJECT_NAME)
BOARD_NAME        = $(subst dsf_,,$(PROJECT_NAME))
EDF_OVERLAY_TARGET = cortexa53-zynqmp
EDF_BOARD_DTS      = $(BOARD_NAME)-reva
EDF_SDT_DIR        = hw_project_sdt
EDF_FW_DIR         = cgra4ml-fw

clean:
	rm -rf $(WORKDIR)
	$(MAKE) -C ibex-soc clean || true
	rm -rf build *.vstf *.log *.ses .qverify .visualizer
	rm -rf $(KERNEL_DIR)
	rm -rf deploy

$(WORKDIR):
	mkdir -p $(WORKDIR)

$(DATA_DIR): | $(WORKDIR)
	mkdir -p $(DATA_DIR)

#----------------- FPGA FLOW ------------------

$(BOARDSTORE):
	@if [ ! -d "$(BOARDSTORE)" ]; then \
		@git clone --branch $(BOARDSTORE_BRANCH) --depth 1 "$(BOARDSTORE_REPO)" "$(BOARDSTORE)"; \

vivado: $(WORKDIR) $(BOARDSTORE)
	@if [ ! -f $(WORKDIR)/config_hw.tcl ]; then \
		echo "ERROR: config_hw.tcl not found. Run your Python script first (e.g., cd run/work && python ../example.py)"; \
		exit 1; \
	fi
	cd $(WORKDIR) && vivado -mode batch -source $(subst \,\\,$(abspath $(RUN_DIR)))/vivado_flow.tcl

#----------------- EDF / DEFERRED PL LOAD ------------------

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

edf_overlay:
	@if [ ! -d $(WORKDIR)/$(EDF_SDT_DIR) ]; then \
		echo "ERROR: SDT directory not found. Run 'make edf_sdt' first."; \
		exit 1; \
	fi
	mkdir -p $(WORKDIR)/$(EDF_FW_DIR)
	cd $(WORKDIR) && LOPPER_DTC_FLAGS="-b 0 -@" $(LOPPER) --enhanced \
		-O $(EDF_FW_DIR) -f $(EDF_SDT_DIR)/system-top.dts \
		-- xlnx_overlay_dt $(EDF_OVERLAY_TARGET) full
	$(DTC) -I dts -O dtb -o $(WORKDIR)/$(EDF_FW_DIR)/pl.dtbo $(WORKDIR)/$(EDF_FW_DIR)/pl.dtsi
	cp $(RUN_DIR)/shell.json $(WORKDIR)/$(EDF_FW_DIR)/

edf: edf_sdt edf_overlay

hw: vivado edf bootgen

smoke_test: $(WORKDIR)
	cd $(WORKDIR) && python -m pytest -s ../$(TEST).py

verify_ibex: $(WORKDIR)
	cd ibex-soc && python check_output.py

smoke_ibex: $(WORKDIR)
	$(MAKE) TEST=ibex_test smoke_test iclean ibuild irun verify_ibex

#----------------- LINUX ------------------

LINUX_VARS = PROJECT_ROOT=$(CURDIR) \
	KERNEL_DIR=$(KERNEL_DIR) \
	CROSS_COMPILE=$(CROSS_COMPILE) \
	WORKDIR=$(WORKDIR) \
	BOOTGEN=$(BOOTGEN) \
	EDF_SDT_DIR=$(EDF_SDT_DIR) \
	EDF_FW_DIR=$(EDF_FW_DIR)

kernel_prepare driver lib linux_example bundle bootgen:
	$(MAKE) -C deepsocflow/linux $(LINUX_VARS) $@

linux:
	$(MAKE) -C deepsocflow/linux $(LINUX_VARS) linux


#----------------- DOCKER ------------------

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
