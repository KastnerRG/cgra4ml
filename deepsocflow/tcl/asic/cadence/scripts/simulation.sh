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
#   --sim             Simulator backend                                  (default: verilator)
#                     e.g. verilator | xrun (xcelium) | vcs (synopsys)
#   --sim-type        Simulation type                                    (default: fpga)
#                     e.g. fpga | asic
#   --sram-gen        Generate SRAMs before simulation                   (default: False)
#                     e.g. True | False
#   --freq            Target clock frequency in MHz                      (default: 250)
#   --run             EDA run counter — selects which run outputs to use (default: 1)
#   --runtype         EDA run type for netlist selection                 (default: rtl)
#                     e.g. rtl | synthesis | pnr
#   --sram-compilers  Comma-separated SRAM compiler names: sp,2p        (default: rf_sp_hse_svt_mvt,rf_2p_hsc_svt_mvt)
#                     WARNING: SRAM compiler executables must be available in PATH before running this script.
#   --top-module      Top-level design name — locates PDK SRAM dir SRAMs_<top_module> (default: axi_cgra4ml)
#
# Examples:
#   for verilator
#   bash ./simulation.sh 
#   for xcelium - fpga simulation == verilator simulation
#   bash ./simulation.sh --sim xrun --sim-type fpga --freq 1000 --runtype rtl --top-module axi_cgra4ml
#   for xcelium - asic rtl simulation with srams generation (It will take approximately 3.5 hours to complete. if you need to reduce runtime reduce corners in gen_srams_spec.py)
#   bash ./simulation.sh --sim xrun --sim-type asic --sram-gen True  --freq 1000 --runtype rtl --sram-compilers rf_sp_hse_svt_mvt,rf_2p_hsc_svt_mvt --top-module axi_cgra4ml
#   for xcelium - asic rtl simulation with no srams generation (once srams are generated it will be there forever unless deleted manually)
#   bash ./simulation.sh --sim xrun --sim-type asic --runtype rtl --top-module axi_cgra4ml
#   for xcelium - asic synthesis gls simulation with no srams generation
#   bash ./simulation.sh --sim xrun --sim-type asic --run 1 --runtype synthesis --top-module axi_cgra4ml
#   for xcelium - asic pnr gls simulation with no srams generation
#   bash ./simulation.sh --sim xrun --sim-type asic --run 1 --runtype pnr --top-module axi_cgra4ml
#######################################################################################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

SIM="verilator"
SIM_TYPE="fpga"
SRAM_GEN="False"
FREQ=250
RUN=1
RUNTYPE="rtl"
SRAM_COMPILERS="rf_sp_hse_svt_mvt,rf_2p_hsc_svt_mvt"
TOP_MODULE="axi_cgra4ml"

while [[ $# -gt 0 ]]; do
    case $1 in
        --sim)             SIM="$2";             shift 2 ;;
        --sim-type)        SIM_TYPE="$2";        shift 2 ;;
        --sram-gen)        SRAM_GEN="$2";        shift 2 ;;
        --freq)            FREQ="$2";            shift 2 ;;
        --run)             RUN="$2";             shift 2 ;;
        --runtype)         RUNTYPE="$2";         shift 2 ;;
        --sram-compilers)  SRAM_COMPILERS="$2";  shift 2 ;;
        --top-module)      TOP_MODULE="$2";      shift 2 ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

cd "$SCRIPT_DIR/../../../../../"
pip install .
mkdir -p run/work
cd run/work
python ../example.py --sim "$SIM" --sim-type "$SIM_TYPE" --sram-gen "$SRAM_GEN" --freq "$FREQ" --run "$RUN" --runtype "$RUNTYPE" --sram-compilers "$SRAM_COMPILERS" --top-module "$TOP_MODULE"

cd "$SCRIPT_DIR"