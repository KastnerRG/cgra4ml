#!/usr/bin/env bash
# Usage:
#   bash <path_to>/genus.sh [--no-abort] [--low-power] [--run <n>] [--overwrite]
#                           [--metrics-compare]
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
#   --overwrite        Allow reuse of an existing genus_run_<nn> folder instead of
#                      aborting. Use with caution — previous results will be mixed
#                      with new outputs.
#   --metrics-compare  Run genus_metrics_compare.tcl in batch mode instead of the
#                      normal synthesis flow. --low-power is ignored in this mode.
#
# Example:
#   for initial runs with debug
#   bash ./genus.sh --run 1 --no-abort
#   for full physical run
#   bash ./genus.sh --run 1
#   for full physical+low power run
#   bash ./genus.sh --run 1 --low-power Genus_Low_Power_Opt
#   to re-run into the same folder
#   bash ./genus.sh --run 1 --overwrite
#   to run metrics comparison
#   bash ./genus.sh --run 1 --overwrite --metrics-compare
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

ABORT_FLAG="-abort_on_error"
LOW_POWER_OPT=""
OVERWRITE=0
METRICS_COMPARE=0
export GENUS_RUN_COUNTER=0

while [[ $# -gt 0 ]]; do
    case $1 in
        --no-abort)          ABORT_FLAG="";                        shift ;;
        --low-power)         LOW_POWER_OPT=" Genus_Low_Power_Opt"; shift ;;
        --run)               GENUS_RUN_COUNTER="$2";               shift 2 ;;
        --overwrite)         OVERWRITE=1;                          shift ;;
        --metrics-compare)   METRICS_COMPARE=1;                    shift ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

RUN_DIR="$SCRIPT_DIR/../../../../../run/work/genus/genus_run_$(printf '%02d' "${GENUS_RUN_COUNTER}")"

if [[ -d "$RUN_DIR" ]]; then
    if [[ $OVERWRITE -eq 0 ]]; then
        echo "Error: run directory already exists: $RUN_DIR"
        echo "       Use --overwrite to reuse it."
        exit 1
    fi
    echo "Warning: reusing existing run directory: $RUN_DIR"
fi

mkdir -p "$RUN_DIR"
cd "$RUN_DIR"

# trap ensures we return to the scripts folder even when:
#   - Genus exits normally
#   - --no-abort drops into interactive prompt and user types exit
#   - an error causes early termination
trap "cd \"$SCRIPT_DIR\"" EXIT

if [[ $METRICS_COMPARE -eq 1 ]]; then
    genus -batch -lic_startup Genus_Synthesis $ABORT_FLAG \
          -files /work/cgra4ml/deepsocflow/tcl/asic/cadence/scripts/genus_metrics_compare.tcl
else
    genus -lic_startup Genus_Synthesis $ABORT_FLAG \
          -lic_startup_options "Genus_Physical_Opt${LOW_POWER_OPT}" \
          -files /work/cgra4ml/deepsocflow/tcl/asic/cadence/scripts/genus.tcl
fi