.PHONY: image start kill enter ibuild irun iclean vivado kernel_prepare driver test_app

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
driver: linux_driver/cgra4ml_main.c linux_driver/Makefile
	$(MAKE) -C $(KERNEL_DIR) ARCH=arm64 CROSS_COMPILE=$(CROSS_COMPILE) \
		KBUILD_MODPOST_WARN=1 M=$(CURDIR)/linux_driver modules

.PHONY: test_app
test_app:
	$(MAKE) -C linux_test

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