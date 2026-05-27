"""
Minimal Python/PYNQ-side wrapper for /dev/cgra4ml.
"""

import fcntl
import mmap
import os
import struct

CGRA4ML_IOCTL_MAGIC = ord("G")

_IOC_NRBITS = 8
_IOC_TYPEBITS = 8
_IOC_SIZEBITS = 14
_IOC_DIRBITS = 2

_IOC_NRSHIFT = 0
_IOC_TYPESHIFT = _IOC_NRSHIFT + _IOC_NRBITS
_IOC_SIZESHIFT = _IOC_TYPESHIFT + _IOC_TYPEBITS
_IOC_DIRSHIFT = _IOC_SIZESHIFT + _IOC_SIZEBITS

_IOC_NONE = 0
_IOC_WRITE = 1
_IOC_READ = 2

def _IOC(direction, type_, nr, size):
    return ((direction << _IOC_DIRSHIFT) |
            (type_ << _IOC_TYPESHIFT) |
            (nr << _IOC_NRSHIFT) |
            (size << _IOC_SIZESHIFT))

def _IOR(type_, nr, size):
    return _IOC(_IOC_READ, type_, nr, size)

def _IOW(type_, nr, size):
    return _IOC(_IOC_WRITE, type_, nr, size)

def _IOWR(type_, nr, size):
    return _IOC(_IOC_READ | _IOC_WRITE, type_, nr, size)

SIZE_REG_ACCESS = 8
SIZE_BUF_INFO = 40
SIZE_START_CONFIG = 8
SIZE_U32 = 4

CGRA4ML_IOC_READ_REG    = _IOWR(CGRA4ML_IOCTL_MAGIC, 0x01, SIZE_REG_ACCESS)
CGRA4ML_IOC_WRITE_REG   = _IOW (CGRA4ML_IOCTL_MAGIC, 0x02, SIZE_REG_ACCESS)
CGRA4ML_IOC_GET_BUFS    = _IOR (CGRA4ML_IOCTL_MAGIC, 0x03, SIZE_BUF_INFO)
CGRA4ML_IOC_HW_RESET    = _IOC (_IOC_NONE, CGRA4ML_IOCTL_MAGIC, 0x04, 0)
CGRA4ML_IOC_HW_START    = _IOW (CGRA4ML_IOCTL_MAGIC, 0x05, SIZE_START_CONFIG)
CGRA4ML_IOC_WAIT_DONE   = _IOR (CGRA4ML_IOCTL_MAGIC, 0x06, SIZE_U32)
CGRA4ML_IOC_DUMP_STATUS = _IOR (CGRA4ML_IOCTL_MAGIC, 0x07, SIZE_U32)

REG_START        = 0x00
REG_DONE_READ0   = 0x04
REG_DONE_READ1   = 0x08
REG_DONE_WRITE0  = 0x0C
REG_DONE_WRITE1  = 0x10
REG_OCM_BASE0    = 0x14
REG_OCM_BASE1    = 0x18
REG_WEIGHTS_BASE = 0x1C
REG_BUNDLE_DONE  = 0x20
REG_N_BUNDLES    = 0x24
REG_W_DONE       = 0x28
REG_X_DONE       = 0x2C
REG_O_DONE       = 0x30
REG_PARAM_BASE   = 0x40

MMAP_WEIGHTS = 0
MMAP_INPUT   = 1
MMAP_OUTPUT  = 2
MMAP_OCM0    = 3
MMAP_OCM1    = 4

class CGRA4ML:
    def __init__(self, dev="/dev/cgra4ml"):
        self.dev = dev
        self.fd = os.open(dev, os.O_RDWR | os.O_SYNC)

    def close(self):
        if self.fd is not None:
            os.close(self.fd)
            self.fd = None

    def read_reg(self, offset):
        buf = bytearray(struct.pack("II", offset, 0))
        fcntl.ioctl(self.fd, CGRA4ML_IOC_READ_REG, buf, True)
        _, value = struct.unpack("II", buf)
        return value

    def write_reg(self, offset, value):
        buf = struct.pack("II", offset, value)
        fcntl.ioctl(self.fd, CGRA4ML_IOC_WRITE_REG, buf)

    def reset(self):
        fcntl.ioctl(self.fd, CGRA4ML_IOC_HW_RESET)

    def start(self, n_bundles):
        buf = struct.pack("II", n_bundles, 0)
        fcntl.ioctl(self.fd, CGRA4ML_IOC_HW_START, buf)

    def status(self):
        buf = bytearray(struct.pack("I", 0))
        fcntl.ioctl(self.fd, CGRA4ML_IOC_DUMP_STATUS, buf, True)
        value, = struct.unpack("I", buf)
        return {
            "raw": value,
            "w_done": value & 0xff,
            "x_done": (value >> 8) & 0xff,
            "o_done": (value >> 16) & 0xff,
        }

    def wait_done(self):
        buf = bytearray(struct.pack("I", 0))
        fcntl.ioctl(self.fd, CGRA4ML_IOC_WAIT_DONE, buf, True)
        value, = struct.unpack("I", buf)
        return value

    def buffers(self):
        buf = bytearray(40)
        fcntl.ioctl(self.fd, CGRA4ML_IOC_GET_BUFS, buf, True)
        weights_phys, input_phys, output_phys, ocm0_phys, ocm1_phys, weights_size, input_size, output_size, ocm_size, reg_size = struct.unpack("QQQQQIIIII", buf)

        return {
            "weights_phys": weights_phys,
            "input_phys": input_phys,
            "output_phys": output_phys,
            "ocm0_phys": ocm0_phys,
            "ocm1_phys": ocm1_phys,
            "weights_size": weights_size,
            "input_size": input_size,
            "output_size": output_size,
            "ocm_size": ocm_size,
            "reg_size": reg_size,
        }

    def mmap_buffer(self, index, size):
        page = mmap.PAGESIZE
        return mmap.mmap(self.fd, size, mmap.MAP_SHARED,
                         mmap.PROT_READ | mmap.PROT_WRITE,
                         offset=index * page)

    def __enter__(self):
        return self

    def __exit__(self, exc_type, exc, tb):
        self.close()

if __name__ == "__main__":
    with CGRA4ML() as cgra:
        print("Buffers:")
        for k, v in cgra.buffers().items():
            print(f"  {k}: {hex(v) if isinstance(v, int) else v}")

        print("Status:", cgra.status())
        print("START register:", hex(cgra.read_reg(REG_START)))
