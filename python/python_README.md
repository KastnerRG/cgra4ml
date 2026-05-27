# `python/` — CGRA4ML Python / PYNQ Wrapper

This folder provides a pure-Python class, `CGRA4ML`, that wraps the `/dev/cgra4ml` device file and exposes the full driver interface — register access, hardware control, DMA buffer mapping — through a clean, Pythonic API. It is designed for use on PYNQ boards or any ARM Linux system with the kernel driver loaded.

---

## File Overview

```
python/
└── cgra4ml_pynq.py    # Self-contained Python wrapper class + __main__ demo
```

---

## Requirements

- Linux system with `cgra4ml_drv.ko` loaded (`/dev/cgra4ml` present)
- Python 3.6+
- Standard library only — no external dependencies (`fcntl`, `mmap`, `os`, `struct`)

---

## Class: `CGRA4ML`

```python
from cgra4ml_pynq import CGRA4ML
```

### Constructor / Destructor

```python
cgra = CGRA4ML(dev="/dev/cgra4ml")   # open the device
cgra.close()                          # close and release

# Preferred: use as a context manager
with CGRA4ML() as cgra:
    ...
```

---

### Method Reference

#### Register Access

| Method                          | Description                                           |
|---------------------------------|-------------------------------------------------------|
| `cgra.read_reg(offset)`         | Read a 32-bit AXI-Lite register at byte `offset`. Returns `int`. |
| `cgra.write_reg(offset, value)` | Write `value` (32-bit) to register at byte `offset`.  |

Byte offset constants are defined at module level (e.g. `REG_START = 0x00`, `REG_N_BUNDLES = 0x24`). See the **Register Constants** section below.

---

#### Hardware Control

| Method                  | Description                                                       |
|-------------------------|-------------------------------------------------------------------|
| `cgra.reset()`          | Issues `CGRA4ML_IOC_HW_RESET` — clears START, done flags, etc.   |
| `cgra.start(n_bundles)` | Issues `CGRA4ML_IOC_HW_START` — resets HW, programs base addresses, asserts START for `n_bundles` bundles. |
| `cgra.wait_done()`      | Blocks until O_DONE is asserted (or driver timeout). Returns packed status `int`. |
| `cgra.status()`         | Non-blocking status snapshot. Returns a `dict`:                   |

```python
{
  "raw":    0x00010101,   # raw packed u32
  "w_done": 1,            # bits [7:0]   — weights DMA done
  "x_done": 1,            # bits [15:8]  — input DMA done
  "o_done": 1,            # bits [23:16] — output/inference done
}
```

---

#### DMA Buffer Info

```python
info = cgra.buffers()
```

Returns a `dict` with physical (DMA bus) addresses and sizes of all five buffers:

```python
{
  "weights_phys": 0x70000000,
  "input_phys":   0x71000000,
  "output_phys":  0x72000000,
  "ocm0_phys":    0x73000000,
  "ocm1_phys":    0x73100000,
  "weights_size": 16777216,
  "input_size":   16777216,
  "output_size":  16777216,
  "ocm_size":     1048576,
  "reg_size":     65536,
}
```

---

#### DMA Buffer mmap

```python
buf = cgra.mmap_buffer(index, size)
```

Returns a `mmap.mmap` object mapped to the selected DMA buffer. Supports standard `bytes`-like operations and `memoryview`.

**Buffer index constants (module-level):**

| Constant       | Value | Buffer    |
|----------------|-------|-----------|
| `MMAP_WEIGHTS` | `0`   | weights   |
| `MMAP_INPUT`   | `1`   | input     |
| `MMAP_OUTPUT`  | `2`   | output    |
| `MMAP_OCM0`    | `3`   | ocm0      |
| `MMAP_OCM1`    | `4`   | ocm1      |

---

## Register Constants

These module-level constants are byte offsets matching `cgra4ml_regs.h`:

| Constant            | Offset  | Description                      |
|---------------------|---------|----------------------------------|
| `REG_START`         | `0x00`  | Write `1` to begin inference     |
| `REG_DONE_READ0`    | `0x04`  | Signal read-port 0 is ready      |
| `REG_DONE_READ1`    | `0x08`  | Signal read-port 1 is ready      |
| `REG_DONE_WRITE0`   | `0x0C`  | Signal write-port 0 is done      |
| `REG_DONE_WRITE1`   | `0x10`  | Signal write-port 1 is done      |
| `REG_OCM_BASE0`     | `0x14`  | OCM bank 0 base DMA address      |
| `REG_OCM_BASE1`     | `0x18`  | OCM bank 1 base DMA address      |
| `REG_WEIGHTS_BASE`  | `0x1C`  | Weights buffer base DMA address  |
| `REG_BUNDLE_DONE`   | `0x20`  | Bundle-done handshake            |
| `REG_N_BUNDLES`     | `0x24`  | Number of bundles to run         |
| `REG_W_DONE`        | `0x28`  | Weights load done flag           |
| `REG_X_DONE`        | `0x2C`  | Input load done flag             |
| `REG_O_DONE`        | `0x30`  | Output/inference done flag       |
| `REG_PARAM_BASE`    | `0x40`  | Base of parameter registers      |

---

## IOCTL Implementation Details

The module re-implements the Linux `_IOC` / `_IOR` / `_IOW` / `_IOWR` macros in Python to compute the correct IOCTL numbers that match the kernel driver. This avoids needing any C extension or ctypes wrapper.

Key sizes used:

| Struct                  | Python format  | Size  |
|-------------------------|----------------|-------|
| `cgra4ml_reg_access`    | `"II"`         | 8 B   |
| `cgra4ml_buf_info`      | `"QQQQQIIIII"` | 40 B  |
| `cgra4ml_start_config`  | `"II"`         | 8 B   |
| `u32` (status)          | `"I"`          | 4 B   |

---

## Usage Examples

### Read a register
```python
with CGRA4ML() as cgra:
    val = cgra.read_reg(REG_START)
    print(f"START = {hex(val)}")
```

### Run a full inference
```python
import numpy as np
from cgra4ml_pynq import CGRA4ML, MMAP_WEIGHTS, MMAP_INPUT, MMAP_OUTPUT

with CGRA4ML() as cgra:
    info = cgra.buffers()

    # Map buffers
    w_buf  = cgra.mmap_buffer(MMAP_WEIGHTS, info["weights_size"])
    in_buf = cgra.mmap_buffer(MMAP_INPUT,   info["input_size"])
    out_buf = cgra.mmap_buffer(MMAP_OUTPUT, info["output_size"])

    # Load weights and input (example: numpy arrays)
    weights_bytes = weights_array.astype(np.int8).tobytes()
    input_bytes   = input_array.astype(np.int8).tobytes()

    w_buf[:len(weights_bytes)]  = weights_bytes
    in_buf[:len(input_bytes)]   = input_bytes

    # Start inference
    cgra.start(n_bundles=42)

    # Wait for completion
    cgra.wait_done()

    # Read output
    raw = bytes(out_buf[:output_size])
    output_array = np.frombuffer(raw, dtype=np.int8)
```

### Quick status check
```python
with CGRA4ML() as cgra:
    s = cgra.status()
    print(f"W={s['w_done']} X={s['x_done']} O={s['o_done']}")
```

---

## Data Flow

```
Python script
    │
    ├── CGRA4ML.__init__()
    │       └── os.open("/dev/cgra4ml", O_RDWR | O_SYNC)
    │
    ├── buffers()
    │       └── fcntl.ioctl(fd, CGRA4ML_IOC_GET_BUFS)
    │               → struct.unpack("QQQQQIIIII", 40-byte response)
    │
    ├── mmap_buffer(MMAP_WEIGHTS, size)
    │       └── mmap.mmap(fd, size, offset=0 * PAGE_SIZE)
    │               → Python mmap object backed by coherent DMA memory
    │
    ├── mmap_buffer(MMAP_INPUT, size)
    │       └── mmap.mmap(fd, size, offset=1 * PAGE_SIZE)
    │
    │   [write weights and inputs via mmap objects]
    │
    ├── start(n_bundles)
    │       └── fcntl.ioctl(fd, CGRA4ML_IOC_HW_START, struct.pack("II", n, 0))
    │               → kernel: reset → program_base_addrs → set N_BUNDLES → START=1
    │
    ├── wait_done()
    │       └── fcntl.ioctl(fd, CGRA4ML_IOC_WAIT_DONE, 4-byte buf)
    │               → kernel: busy-poll O_DONE register → return status
    │
    ├── mmap_buffer(MMAP_OUTPUT, size)  [read outputs]
    │
    └── close() / __exit__()
            └── os.close(fd)
```

---

## Running the Built-in Demo

The module includes a `__main__` block for a quick sanity check:

```bash
python3 cgra4ml_pynq.py
```

Output:
```
Buffers:
  weights_phys: 0x70000000
  input_phys:   0x71000000
  ...
Status: {'raw': 256, 'w_done': 0, 'x_done': 1, 'o_done': 0}
START register: 0x0
```
