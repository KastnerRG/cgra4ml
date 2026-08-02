#!/usr/bin/env bash
# Usage:
#   bash <path_to>/genus.sh [--no-abort] [--low-power] [--run <n>] [--innovus-run <n>]
#                          [--phys-synth-type <type>] [--overwrite] [--metrics-compare]
#
# Options:
#   --no-abort         Drop into the Genus interactive prompt on error instead of
#                      exiting — useful for debugging mid-flow. Script returns to
#                      the scripts folder automatically when you exit Genus.
#   --low-power        Add Genus_Low_Power_Opt to the license startup options.
#   --run <n>          Set genus_run_counter to <n>. Genus runs inside:
#                      cgra4ml/run/work/genus/genus_run_<nn>
#                      Aborts if the folder already exists (use --overwrite to skip).
#                      (default: 00)
#   --innovus-run <n>  Set innovus_run_counter to <n>. Pulls floorplan DEF
#                      from innovus_run_<nn> for iSpatial synthesis (default: 0)
#   --phys-synth-type <type>
#                      Set PHYS_SYNTH_TYPE for genus.tcl (default: lef).
#                      "lef"       - RTL floorplan flow with iSpatial
#                      "floorplan" - iSpatial flow with DEF input
#   --overwrite        Allow reuse of an existing genus_run_<nn> folder instead of
#                      aborting. Use with caution — previous results will be mixed
#                      with new outputs.
#   --metrics-compare  Run genus_metrics_compare.tcl in batch mode instead of the
#                      normal synthesis flow. --low-power is ignored in this mode.
#                      Compares runs 1..GENUS_RUN_COUNTER (set via --run).
#                      Runs inside a scratch folder
#                      (cgra4ml/run/work/genus/genus_metrics_compare_tmp)
#                      that is deleted automatically once Genus exits.
#                      --overwrite is ignored in this mode.
#
# Example:
#   for initial runs with debug
#   bash ./genus.sh --run 1 --no-abort
#   for full physical run
#   bash ./genus.sh --run 1
#   for rtl floorplan (no intial DEF) flow
#   bash ./genus.sh --run 1 --phys-synth-type lef
#   for iSpatial floorplan (DEF) flow
#   bash ./genus.sh --run 1 --phys-synth-type floorplan
#   for iSpatial using Innovus run 6 floorplan DEF
#   bash ./genus.sh --run 1 --phys-synth-type floorplan --innovus-run 6
#   for full physical+low power run
#   bash ./genus.sh --run 1 --low-power Genus_Low_Power_Opt
#   to re-run into the same folder
#   bash ./genus.sh --run 1 --overwrite
#   to compare runs 1-4
#   bash ./genus.sh --run 4 --metrics-compare
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

ABORT_FLAG="-abort_on_error"
LOW_POWER_OPT=""
OVERWRITE=0
METRICS_COMPARE=0
export GENUS_RUN_COUNTER=0
export INNOVUS_RUN_COUNTER=0
export PHYS_SYNTH_TYPE="lef"

while [[ $# -gt 0 ]]; do
    case $1 in
        --no-abort)          ABORT_FLAG="";                        shift ;;
        --low-power)         LOW_POWER_OPT=" Genus_Low_Power_Opt"; shift ;;
        --run)               GENUS_RUN_COUNTER="$2";               shift 2 ;;
        --innovus-run)       INNOVUS_RUN_COUNTER="$2";             shift 2 ;;
        --phys-synth-type)   PHYS_SYNTH_TYPE="$2";                 shift 2 ;;
        --overwrite)         OVERWRITE=1;                          shift ;;
        --metrics-compare)   METRICS_COMPARE=1;                    shift ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

GENUS_WORK_DIR="$SCRIPT_DIR/../../../../../run/work/genus"

if [[ $METRICS_COMPARE -eq 1 ]]; then
    # Scratch folder only — wiped on entry and removed again on exit.
    RUN_DIR="$GENUS_WORK_DIR/genus_metrics_compare_tmp"
    rm -rf "$RUN_DIR"
    mkdir -p "$RUN_DIR"
else
    RUN_DIR="$GENUS_WORK_DIR/genus_run_$(printf '%02d' "${GENUS_RUN_COUNTER}")"

    if [[ -d "$RUN_DIR" ]]; then
        if [[ $OVERWRITE -eq 0 ]]; then
            echo "Error: run directory already exists: $RUN_DIR"
            echo "       Use --overwrite to reuse it."
            exit 1
        fi
        echo "Warning: reusing existing run directory: $RUN_DIR"
    fi

    mkdir -p "$RUN_DIR"
fi

cd "$RUN_DIR"

# trap ensures we return to the scripts folder, and remove the metrics-compare
# scratch folder, even when:
#   - Genus exits normally
#   - --no-abort drops into interactive prompt and user types exit
#   - an error causes early termination
trap "cd \"$SCRIPT_DIR\"; if [[ $METRICS_COMPARE -eq 1 ]]; then rm -rf \"$RUN_DIR\"; fi" EXIT

if [[ $METRICS_COMPARE -eq 1 ]]; then
    genus -batch -lic_startup Genus_Synthesis $ABORT_FLAG \
          -files /work/cgra4ml/deepsocflow/tcl/asic/cadence/scripts/genus_metrics_compare.tcl
else
    genus -lic_startup Genus_Synthesis $ABORT_FLAG \
          -lic_startup_options "Genus_Physical_Opt${LOW_POWER_OPT}" \
          -files /work/cgra4ml/deepsocflow/tcl/asic/cadence/scripts/genus.tcl
fi