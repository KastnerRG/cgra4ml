IBEX_CONFIG ?= small

FUSESOC_CONFIG_OPTS = $(shell ./util/ibex_config.py $(IBEX_CONFIG) fusesoc_opts)
SYSTEM_DIR = examples/sw/simple_system/hello_test

simple-system-program = $(SYSTEM_DIR)/hello_test.vmem
Vibex_simple_system = build/lowrisc_ibex_ibex_simple_system_0/sim-verilator/Vibex_simple_system
$(Vibex_simple_system):
	@echo "$@ not found"
	@echo "Run \"make build-simple-system\" to create the dependency"
	@false

all: help

print:
	cat ibex_simple_system.log

wave:
	gtkwave sim.fst &

# INDEX = (0x00104000 - 0x00100000)/4 = 0x1000
run: sw-simple-hello | $(Vibex_simple_system)
	srec_cat ../run/work/vectors/wbx.bin -binary -offset 0x4000 -byte-swap 4 -o wbx.vmem -vmem 32
	build/lowrisc_ibex_ibex_simple_system_0/sim-verilator/Vibex_simple_system -t \
		--meminit=ram,$(simple-system-program) \
		--meminit=ram,wbx.vmem
	cat ibex_simple_system.log

build:
	fusesoc --cores-root=. run --target=sim --setup --build \
		lowrisc:ibex:ibex_simple_system \
		$(FUSESOC_CONFIG_OPTS)

sw-simple-hello: $(simple-system-program)
$(simple-system-program): $(SYSTEM_DIR)/hello_test.c $(SYSTEM_DIR)/sa.h
	cd $(SYSTEM_DIR) && $(MAKE)

run-clean:
	$(MAKE) -C $(SYSTEM_DIR) clean
	rm -f ibex_simple_system.log
	rm -f wbx.vmem

.PHONY: build $(simple-system-program) run print



# Use a parallel run (make -j N) for a faster build
build-all: build-riscv-compliance build build-arty-100 \
      build-csr-test

# RISC-V compliance
.PHONY: build-riscv-compliance
build-riscv-compliance:
	fusesoc --cores-root=. run --target=sim --setup --build \
		lowrisc:ibex:ibex_riscv_compliance \
		$(FUSESOC_CONFIG_OPTS)

# Arty A7 FPGA example
# Use the following targets (depending on your hardware):
# - "build-arty-35"
# - "build-arty-100"
# - "program-arty"
arty-sw-program = examples/sw/led/led.vmem
sw-led: $(arty-sw-program)

.PHONY: $(arty-sw-program)
$(arty-sw-program):
	cd examples/sw/led && $(MAKE)

.PHONY: build-arty-35
build-arty-35: sw-led
	fusesoc --cores-root=. run --target=synth --setup --build \
		lowrisc:ibex:top_artya7 --part xc7a35ticsg324-1L

.PHONY: build-arty-100
build-arty-100: sw-led
	fusesoc --cores-root=. run --target=synth --setup --build \
		lowrisc:ibex:top_artya7 --part xc7a100tcsg324-1

.PHONY: program-arty
program-arty:
	fusesoc --cores-root=. run --target=synth --run \
		lowrisc:ibex:top_artya7


# Lint check
.PHONY: lint-core-tracing
lint-core-tracing:
	fusesoc --cores-root . run --target=lint lowrisc:ibex:ibex_core_tracing \
		$(FUSESOC_CONFIG_OPTS)


# CS Registers testbench
# Use the following targets:
# - "build-csr-test"
# - "run-csr-test"
.PHONY: build-csr-test
build-csr-test:
	fusesoc --cores-root=. run --target=sim --setup --build \
	      --tool=verilator lowrisc:ibex:tb_cs_registers
Vtb_cs_registers = \
      build/lowrisc_ibex_tb_cs_registers_0/sim-verilator/Vtb_cs_registers
$(Vtb_cs_registers):
	@echo "$@ not found"
	@echo "Run \"make build-csr-test\" to create the dependency"
	@false

.PHONY: run-csr-test
run-csr-test: | $(Vtb_cs_registers)
	fusesoc --cores-root=. run --target=sim --run \
	      --tool=verilator lowrisc:ibex:tb_cs_registers

# Echo the parameters passed to fusesoc for the chosen IBEX_CONFIG
.PHONY: test-cfg
test-cfg:
	@echo $(FUSESOC_CONFIG_OPTS)

.PHONY: python-lint
python-lint:
	$(MAKE) -C util lint

.PHONY: clean
clean:
	rm -rf build
	$(MAKE) -C examples/sw/simple_system/hello_test clean
	rm -f ibex_simple_system.log
	rm -f wbx.vmem


.PHONY: image start kill enter

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
		-v $(PWD)/../:/work \
		-w /work/ibex-soc \
		$(IMAGE) bash -lc 'fusesoc library add sa_ip /work || true; tail -f /dev/null'

enter:
	docker exec -it $(CONTAINER) bash

kill:
	docker kill $(CONTAINER) || true
	docker rm   $(CONTAINER) || true
