# `linux_test/` — CGRA4ML Userspace Test Programs

This folder contains three standalone C test programs and a shell script for smoke-testing the CGRA4ML kernel driver from userspace. All programs talk to the driver through `/dev/cgra4ml` using the IOCTL and `mmap` interface defined in `cgra4ml_ioctl.h`.

---

## File Overview

```
linux_test/
├── Makefile          # Builds all test binaries
├── run_smoke.sh      # Runs register/DMA smoke tests in sequence
├── ioctl_test.c      # Queries buffer info and hardware status via IOCTL
├── reg_test.c        # Register-level read/write smoke test
├── dma_buf_test.c    # Maps DMA buffers and verifies read/write access
└── inference.c       # Full model inference (loads wbx.bin, runs bundle loop)
```

---

## Dependencies

The test programs include headers from the driver folder. Ensure the path is accessible:

```
linux_test/
    └── ioctl_test.c  → #include "cgra4ml_ioctl.h"  (from ../linux_driver)
    └── reg_test.c    → #include "cgra4ml_regs.h"   (from ../linux_driver)
```

The `Makefile` sets `-I../linux_driver` so these are resolved automatically.

---

## Build

```bash
cd linux_test
make
```

This produces four executables: `ioctl_test`, `reg_test`, `dma_buf_test`, `inference`.

To clean:
```bash
make clean
```

---

## Test Programs

### `ioctl_test.c` — Buffer Info + Status Query

**What it does:**
1. Opens `/dev/cgra4ml`.
2. Issues `CGRA4ML_IOC_GET_BUFS` to retrieve physical (DMA bus) addresses and sizes of all five buffers (`weights`, `input`, `output`, `ocm0`, `ocm1`) plus the register window size.
3. Issues `CGRA4ML_IOC_DUMP_STATUS` to read the packed hardware status register.
4. Prints everything to stdout.

**Example output:**
```
CGRA4ML buffer info:
  weights phys: 0x70000000 size: 16777216
  input   phys: 0x71000000 size: 16777216
  output  phys: 0x72000000 size: 16777216
  ocm0    phys: 0x73000000 size: 1048576
  ocm1    phys: 0x73100000 size: 1048576
  reg size: 65536
status packed: 0x00000101
  W_DONE = 1
  X_DONE = 1
  O_DONE = 0
```

**Purpose:** Confirms the driver loaded successfully, DMA memory was allocated, and the hardware registers are accessible.

---

### `reg_test.c` — Register Read/Write Smoke Test

**What it does:**
1. Opens `/dev/cgra4ml`.
2. Calls `CGRA4ML_IOC_HW_RESET` to put hardware in a known state.
3. Reads a set of key registers (`START`, `DONE_READ0/1`, `W_DONE`, `X_DONE`, `O_DONE`) and prints their values.
4. Writes the value `1` to `N_BUNDLES`, then reads it back to confirm write-through.

**Registers tested:**

| Register       | Expected after reset  |
|----------------|-----------------------|
| `START`        | `0x00000000`          |
| `DONE_READ0`   | `0x00000001`          |
| `DONE_READ1`   | `0x00000001`          |
| `W_DONE`       | `0x00000000`          |
| `X_DONE`       | `0x00000000`          |
| `O_DONE`       | `0x00000000`          |
| `N_BUNDLES`    | `0x00000001` (written)|

**Purpose:** Verifies the register read/write IOCTL path works and the AXI-Lite register interface is correctly wired. This is typically the first test run after loading the driver.

---

### `dma_buf_test.c` — DMA Buffer mmap Test

**What it does:**
1. Opens `/dev/cgra4ml`.
2. Calls `CGRA4ML_IOC_GET_BUFS` to get buffer sizes.
3. Uses `mmap()` with `offset = index * PAGE_SIZE` to map `weights`, `input`, and `output` buffers into userspace.
4. Writes test byte patterns into the first 256 bytes of `weights` (`0xA0..0xAF` repeated) and `input` (`0x10..0x1F` repeated), zeroes `output`.
5. Reads back and prints the first 16 bytes of each buffer to confirm the mapping is live and coherent.
6. `munmap`s all three buffers and closes the device.

**mmap offset convention:**

| Buffer    | Index | `mmap` offset = `index × PAGE_SIZE` |
|-----------|-------|--------------------------------------|
| `weights` | 0     | `0 × 4096 = 0x0000`                 |
| `input`   | 1     | `1 × 4096 = 0x1000`                 |
| `output`  | 2     | `2 × 4096 = 0x2000`                 |
| `ocm0`    | 3     | `3 × 4096 = 0x3000`                 |
| `ocm1`    | 4     | `4 × 4096 = 0x4000`                 |

**Example output:**
```
Writing test patterns into coherent buffers
weights[0..15]: a0 a1 a2 a3 a4 a5 a6 a7 a8 a9 aa ab ac ad ae af
input[0..15]:   10 11 12 13 14 15 16 17 18 19 1a 1b 1c 1d 1e 1f
```

**Purpose:** Confirms DMA coherent memory is correctly mapped and accessible from userspace — a prerequisite for loading model weights and input tensors before starting inference.

---

### `inference.c` — Full Model Inference

**What it does:**
1. Opens `/dev/cgra4ml`.
2. Issues `CGRA4ML_IOC_GET_BUFS` to get the weights buffer physical address and size.
3. `mmap`s the weights DMA buffer (index 0) into userspace — this buffer holds the entire `Memory_st` struct (~58 KB).
4. Loads `wbx.bin` (weights + bias + input pixels) into `Memory_st->w` via `fread`.
5. Calls `run(linux_mp)` — the same bundle loop from `deepsocflow/c/runtime.h`:
   - `model_setup()` writes AXI-Lite registers via IOCTL (OCM base, weights base, bundle parameters)
   - The bundle loop iterates all 7 bundles, coordinating with hardware via register handshake
   - CPU post-processes engine output (bias, activation, pooling, softmax, tiling)
6. Calls `print_output()` to print the final 10 class probabilities as `y[i]: val/1000`.
7. Cleans up and exits.

**Implementation strategy:**

The C preprocessor macros in `deepsocflow/c/deepsocflow_linux.h` intercept every hardware access from `runtime.h`:

| Baremetal operation | Linux replacement |
|---|---|
| `fb_write_reg32(addr, val)` | `ioctl(fd, CGRA4ML_IOC_WRITE_REG, ...)` |
| `fb_read_reg32(addr)` | `ioctl(fd, CGRA4ML_IOC_READ_REG, ...)` |
| `fb_addr_64to32(ptr)` | `weights_phys + (ptr - mp)` |
| `flush_cache(...)` | no-op (DMA-coherent memory) |
| `mem_phy.field` | `mp->field` (function parameter) |

This allows the entire bundle loop (~280 lines of complex nested loops with pooling, softmax, tiling) to run unmodified on Linux.

**Usage:**

```bash
./inference [wbx_path]
```

Default `wbx_path` is `./wbx.bin` if not specified.

**Example output:**
```
CGRA4ML Linux inference
  Memory_st      : 0xffff9e200000  (virtual)
  weights phys   : 0x69100000
  weights size   : 16777216
  sizeof(Memory_st): 58552
  loading wbx    : wbx.bin
  running inference...
--- output ---
y[0]: 105/1000
y[1]: 56/1000
y[2]: 56/1000
y[3]: 56/1000
y[4]: 56/1000
y[5]: 366/1000
y[6]: 56/1000
y[7]: 56/1000
y[8]: 134/1000
y[9]: 56/1000
```

The highest value (`y[5]: 366/1000`) is the predicted class. Compare against the Python golden reference: `int(1000 * y_exp.txt_value)`.

**Purpose:** Demonstrates the full inference pipeline working end-to-end on Linux — the same C firmware that runs in Verilator simulation and Xilinx baremetal now runs unmodified on a Linux-driven FPGA.

---

## Smoke Test Script — `run_smoke.sh`

Runs all three tests in sequence with status checks:

```bash
chmod +x run_smoke.sh
./run_smoke.sh
```

**Steps executed:**
```
[1] Building user tests      → make
[2] Checking device          → ls -l /dev/cgra4ml
[3] Running ioctl test       → ./ioctl_test
[4] Running register test    → ./reg_test
[5] Running DMA buffer test  → ./dma_buf_test
```

The script uses `set -e`, so it stops immediately on any failure. A clean run ending in `CGRA4ML Linux smoke test finished.` confirms the full driver interface is working.

---

## Test Flow Diagram

```
run_smoke.sh                          inference (standalone)
    │                                       │
    ├─[1]─ make ──────────────────────── builds ioctl_test, reg_test,
    │                                       dma_buf_test, inference
    │
    ├─[2]─ ls /dev/cgra4ml ───────────────────── confirms driver is loaded
    │
    ├─[3]─ ioctl_test
    │         open /dev/cgra4ml
    │         ioctl(GET_BUFS)   → print DMA buffer physical addresses & sizes
    │         ioctl(DUMP_STATUS) → print W/X/O_DONE fields
    │         close
    │
    ├─[4]─ reg_test
    │         open /dev/cgra4ml
    │         ioctl(HW_RESET)          → reset hardware
    │         ioctl(READ_REG, START)   → read & print
    │         ioctl(READ_REG, W_DONE)  → read & print
    │         ... (more registers)
    │         ioctl(WRITE_REG, N_BUNDLES, 1) → write
    │         ioctl(READ_REG, N_BUNDLES)     → read back & verify
    │         close
    │
    └─[5]─ dma_buf_test
              open /dev/cgra4ml
              ioctl(GET_BUFS) → get sizes
              mmap(WEIGHTS)   → map into userspace
              mmap(INPUT)     → map into userspace
              mmap(OUTPUT)    → map into userspace
              write patterns → weights[0..255], input[0..255]
              read back & print first 16 bytes of each
              munmap × 3
              close
```
