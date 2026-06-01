#!/usr/bin/env python3
import ctypes, os, sys, argparse

ap = argparse.ArgumentParser()
ap.add_argument("--wbx", default="wbx.bin")
ap.add_argument("--dev", default="/dev/cgra4ml")
args = ap.parse_args()

lib = ctypes.CDLL(os.path.join(os.getcwd(), "libinference.so"))
lib.host_setup.argtypes = [ctypes.c_char_p, ctypes.c_char_p]
lib.host_setup.restype = ctypes.c_void_p
lib.run.argtypes = [ctypes.c_void_p]
lib.run.restype = None
lib.print_output.argtypes = [ctypes.c_void_p]
lib.print_output.restype = None
lib.host_cleanup.argtypes = [ctypes.c_void_p]
lib.host_cleanup.restype = None

print("Welcome to DeepSoCFlow!")
mp = lib.host_setup(args.dev.encode(), os.path.join(os.getcwd(), args.wbx).encode())
if not mp:
    raise SystemExit("host_setup failed")
lib.run(mp)
lib.print_output(mp)
lib.host_cleanup(mp)
