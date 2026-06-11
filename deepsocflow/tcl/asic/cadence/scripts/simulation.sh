#!/usr/bin/env bash
##############################################################################
# Script    : simulation.sh
# Purpose   : Run DeepSoCFlow simulation
##############################################################################
#
# First-time setup (run once from the repo root):
#   pip install .
#   mkdir -p run/work
#   cd run/work
#   python ../example.py
#
# Subsequent runs (from the repo root):
#   pip install .
#   cd run/work
#   python ../example.py
#
# This script automates the above — invoke it from scripts/:
#   bash simulation.sh [options]
# It navigates to the repo root, runs the simulation, then returns here
# so you can invoke simulation.sh again without changing directory.
#
# Options:
#   --sim       Simulator backend                                  (default: verilator)
#               e.g. verilator | xrun (xcelium) | vcs (synopsys)
#   --sim-type  Simulation type                                    (default: fpga)
#               e.g. fpga | asic
#   --sram-gen  Generate SRAMs before simulation                   (default: False)
#               e.g. True | False
#   --freq      Target clock frequency in MHz                      (default: 250)
#   --run       EDA run counter — selects which run outputs to use (default: 1)
#   --runtype   EDA run type for netlist selection                 (default: rtl)
#               e.g. rtl | synthesis | pnr
#
# Examples:
#   for verilator
#   bash ./simulation.sh 
#   for xcelium
#   bash ./simulation.sh --sim xrun --sim-type fpga --sram-gen False --freq 1000 --run 1 --runtype rtl
#######################################################################################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

SIM="verilator"
SIM_TYPE="fpga"
SRAM_GEN="False"
FREQ=250
RUN=1
RUNTYPE="rtl"

while [[ $# -gt 0 ]]; do
    case $1 in
        --sim)       SIM="$2";      shift 2 ;;
        --sim-type)  SIM_TYPE="$2"; shift 2 ;;
        --sram-gen)  SRAM_GEN="$2"; shift 2 ;;
        --freq)      FREQ="$2";     shift 2 ;;
        --run)       RUN="$2";      shift 2 ;;
        --runtype)   RUNTYPE="$2";  shift 2 ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

cd "$SCRIPT_DIR/../../../../../"
pip install .
mkdir -p run/work
cd run/work
python ../example.py --sim "$SIM" --sim-type "$SIM_TYPE" --sram-gen "$SRAM_GEN" --freq "$FREQ" --run "$RUN" --runtype "$RUNTYPE"

cd "$SCRIPT_DIR"