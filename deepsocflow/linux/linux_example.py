#!/usr/bin/env python3
"""
runner.py - CGRA4ML Linux inference runner (Python version)

Loads wbx.bin (weights + input), runs inference on the CGRA accelerator,
and prints the output class probabilities.

Usage:
    python3 runner.py [--wbx wbx.bin] [--dev /dev/cgra4ml]
"""

import ctypes
import os
import sys
import argparse

# ---- Parse command line arguments ----

ap = argparse.ArgumentParser()
ap.add_argument("--wbx", default="wbx.bin")
ap.add_argument("--dev", default="/dev/cgra4ml")
args = ap.parse_args()

# ---- Load libinference.so ----

lib = ctypes.CDLL(os.path.join(os.getcwd(), "libinference.so"))

# ---- Configure function signatures ----

lib.host_setup.argtypes = [ctypes.c_char_p, ctypes.c_char_p]
lib.host_setup.restype = ctypes.c_void_p
lib.run.argtypes = [ctypes.c_void_p]
lib.run.restype = None
lib.print_output.argtypes = [ctypes.c_void_p]
lib.print_output.restype = None
lib.host_cleanup.argtypes = [ctypes.c_void_p]
lib.host_cleanup.restype = None

# ---- Run inference ----

print("CGRA4ML Linux inference")
print("  running inference...")

mp = lib.host_setup(args.dev.encode(), os.path.join(os.getcwd(), args.wbx).encode())
if not mp:
    raise SystemExit("host_setup failed")

lib.run(mp)
print("\n--- output ---")
lib.print_output(mp)

lib.host_cleanup(mp)
