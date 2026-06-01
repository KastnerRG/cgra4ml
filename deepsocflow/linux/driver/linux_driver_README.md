# `linux_driver/` — CGRA4ML Linux Kernel Driver

This folder contains a **Linux platform driver** for the CGRA4ML hardware accelerator.
It exposes the accelerator to userspace via `/dev/cgra4ml`, giving applications the ability to control the hardware registers and access DMA-coherent memory buffers.

---

## File Overview

```
linux_driver/
├── Makefile          # Kernel module build system
├── cgra4ml.dts       # Example device-tree snippet (FPGA board integration)
├── cgra4ml_priv.h    # Internal shared structs (cgra4ml_dev, cgra4ml_dma_buf)
├── cgra4ml_regs.h    # AXI-Lite register map (byte offsets)
├── cgra4ml_ioctl.h   # IOCTL interface (shared with userspace)
├── cgra4ml_main.c    # Driver entry point: probe/remove, file_operations
├── cgra4ml_hw.c      # Register read/write, HW reset, start, status polling
└── cgra4ml_dma.c     # DMA buffer allocation, mmap, and info reporting
```

---

## Architecture

```
 Userspace (/dev/cgra4ml)
        │
        │  open / ioctl / mmap
        ▼
┌──────────────────────────────────┐
│        cgra4ml_main.c            │
│  file_operations: open, ioctl,   │
│  mmap, release                   │
│                                  │
│  probe()  → allocates buffers,   │
│             maps registers,       │
│             registers miscdev     │
│  remove() → cleans up            │
└───────┬──────────────┬───────────┘
        │              │
        ▼              ▼
┌──────────────┐  ┌──────────────────┐
│ cgra4ml_hw.c │  │  cgra4ml_dma.c   │
│              │  │                  │
│ read_reg()   │  │ alloc_all()      │
│ write_reg()  │  │ free_all()       │
│ hw_reset()   │  │ mmap()           │
│ hw_start()   │  │ fill_info()      │
│ hw_status()  │  └──────────────────┘
│ wait_done()  │
└──────────────┘
```

---

## Key Components

### `cgra4ml_priv.h` — Shared Private Types
Defines the two core structs used throughout the driver:

- **`cgra4ml_dma_buf`** — Tracks one DMA buffer (CPU virtual address, DMA bus address, size, name).
- **`cgra4ml_dev`** — The main device context, holding: the device pointer, MMIO register pointer, miscdevice handle, a mutex, a wait queue, and all five DMA buffer descriptors (`weights`, `input`, `output`, `ocm0`, `ocm1`).

---

### `cgra4ml_regs.h` — Register Map
Defines byte-offset constants for every AXI-Lite control register, mirroring the layout in `deepsocflow/c/runtime.h`. Key registers:

| Register Constant         | Description                        |
|---------------------------|------------------------------------|
| `CGRA4ML_REG_START`       | Write `1` to begin inference       |
| `CGRA4ML_REG_N_BUNDLES`   | Number of bundles to execute       |
| `CGRA4ML_REG_W_DONE`      | Weights DMA done flag              |
| `CGRA4ML_REG_X_DONE`      | Input (activations) done flag      |
| `CGRA4ML_REG_O_DONE`      | Output done flag — inference complete |
| `CGRA4ML_REG_OCM_BASE0/1` | Base addresses for on-chip memory  |
| `CGRA4ML_REG_WEIGHTS_BASE`| Base address for weights buffer    |

---

### `cgra4ml_ioctl.h` — Userspace Interface (shared header)
Defines all IOCTL commands and their argument structs. This header is **included by both the kernel driver and userspace test programs**.

| IOCTL Command              | Direction | Argument Struct              | Purpose                        |
|----------------------------|-----------|------------------------------|--------------------------------|
| `CGRA4ML_IOC_READ_REG`     | Read/Write | `cgra4ml_reg_access`        | Read one AXI register          |
| `CGRA4ML_IOC_WRITE_REG`    | Write      | `cgra4ml_reg_access`        | Write one AXI register         |
| `CGRA4ML_IOC_GET_BUFS`     | Read       | `cgra4ml_buf_info`          | Get physical addresses + sizes |
| `CGRA4ML_IOC_HW_RESET`     | None       | —                            | Reset hardware state           |
| `CGRA4ML_IOC_HW_START`     | Write      | `cgra4ml_start_config`      | Start inference (N bundles)    |
| `CGRA4ML_IOC_WAIT_DONE`    | Read       | `u32` status                | Poll-wait until O_DONE is set  |
| `CGRA4ML_IOC_DUMP_STATUS`  | Read       | `u32` status                | Non-blocking status snapshot   |

---

### `cgra4ml_main.c` — Driver Core
- **`cgra4ml_probe()`**: Called when the kernel matches the device tree node. Maps registers with `devm_ioremap_resource`, allocates all five DMA buffers, registers a `miscdevice` at `/dev/cgra4ml`, then calls `hw_reset()` + `hw_program_base_addrs()`.
- **`cgra4ml_ioctl()`**: Dispatches all IOCTL commands under a `mutex_lock`, copies arguments to/from userspace with `copy_from_user` / `copy_to_user`.
- **`cgra4ml_mmap()`**: Delegates to `cgra4ml_dma_mmap()`, using `vm_pgoff` as the buffer index.
- **Module parameters** (tunable via `insmod` or `/sys/module/`):

| Parameter         | Default   | Description                      |
|-------------------|-----------|----------------------------------|
| `weights_size`    | 16 MB     | DMA weights buffer size          |
| `input_size`      | 16 MB     | DMA input buffer size            |
| `output_size`     | 16 MB     | DMA output buffer size           |
| `ocm_size`        | 1 MB      | Each OCM bank buffer size        |
| `wait_timeout_ms` | 5000 ms   | Inference completion timeout     |

---

### `cgra4ml_hw.c` — Hardware Control
- **`cgra4ml_hw_reset()`** — Clears START, sets DONE_READ flags, clears W/X/O_DONE.
- **`cgra4ml_hw_start(n_bundles)`** — Calls reset, programs base addresses, sets N_BUNDLES, asserts START.
- **`cgra4ml_hw_wait_done(timeout_ms)`** — Busy-polls `O_DONE` with 100–500 µs sleeps until the flag is set or the deadline expires.
- **`cgra4ml_hw_status()`** — Returns a packed `u32`: `W_DONE[7:0] | X_DONE[15:8] | O_DONE[23:16]`.

---

### `cgra4ml_dma.c` — DMA Buffer Management
Allocates five coherent DMA buffers using `dma_alloc_coherent` (cache-coherent, 32-bit DMA mask). Buffer indices for `mmap` are:

| Index | `CGRA4ML_MMAP_*` | Buffer    |
|-------|------------------|-----------|
| 0     | `MMAP_WEIGHTS`   | weights   |
| 1     | `MMAP_INPUT`     | input     |
| 2     | `MMAP_OUTPUT`    | output    |
| 3     | `MMAP_OCM0`      | ocm0      |
| 4     | `MMAP_OCM1`      | ocm1      |

The userspace `mmap()` call uses `offset = index * PAGE_SIZE` to select a buffer.

---

### `cgra4ml.dts` — Device Tree Node
Drop this snippet into your PetaLinux `system-user.dtsi`. Update `reg` to match your Vivado Address Editor assignment.

```dts
cgra4ml@b0000000 {
    compatible = "ucsd,cgra4ml-1.0";
    reg = <0xB0000000 0x00010000>;
    dma-coherent;
};
```
The driver also accepts `"kastner,cgra4ml-1.0"` as a compatible string.

---

## Build

### Native (on PYNQ / PetaLinux board)
```bash
cd linux_driver
make
sudo insmod cgra4ml_drv.ko
```

### Cross-compile
```bash
make ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- KDIR=/path/to/linux/build
```

### Clean
```bash
make clean
```

---

## Data Flow: Inference Lifecycle

```
1. insmod cgra4ml_drv.ko
        └─ probe(): ioremap registers, alloc DMA buffers, register /dev/cgra4ml

2. Userspace open("/dev/cgra4ml")

3. ioctl(GET_BUFS)       → get physical addresses and sizes of all buffers

4. mmap(fd, MMAP_WEIGHTS) → map weights buffer into userspace virtual memory
   mmap(fd, MMAP_INPUT)   → map input buffer
   mmap(fd, MMAP_OUTPUT)  → map output buffer

5. Userspace writes model weights → weights buffer (via mmap'd pointer)
   Userspace writes input tensor  → input buffer  (via mmap'd pointer)

6. ioctl(HW_START, n_bundles)
        └─ hw_reset() → program_base_addrs() → write N_BUNDLES → assert START

7. ioctl(WAIT_DONE)      → polls O_DONE register (up to wait_timeout_ms)

8. Userspace reads output tensor ← output buffer (via mmap'd pointer)

9. close(fd)
```
