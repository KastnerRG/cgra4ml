#!/usr/bin/env bash
set -e

echo "[1] Building user tests"
make

echo "[2] Checking device"
ls -l /dev/cgra4ml

echo "[3] Running ioctl test"
./ioctl_test

echo "[4] Running register test"
./reg_test

echo "[5] Running DMA buffer mmap test"
./dma_buf_test

echo "CGRA4ML Linux smoke test finished."
