#!/usr/bin/env bash
# Usage:
#   bash <path_to>/genus.sh [--no-abort] [--low-power] [--run <n>]
#
# Options:
#   --no-abort    Drop into the Genus interactive prompt on error instead of
#                 exiting — useful for debugging mid-flow. Script returns to
#                 the scripts folder automatically when you exit Genus.
#   --low-power   Add Genus_Low_Power_Opt to the license startup options.
#   --run <n>     Set genus_run_counter to <n>. Genus runs inside:
#                 cgra4ml/run/work/genus/genus_run_<n>
#                 Folder is created automatically if it does not exist.
#                 (default: 0)
#
# Example:
#   for initial runs with debug
#   bash ./genus.sh --run 1 --no-abort
#   for full physical run
#   bash ./genus.sh --run 1
#   for full physical+low power run
#   bash ./genus.sh --run 1 --low-power Genus_Low_Power_Opt
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

ABORT_FLAG="-abort_on_error"
LOW_POWER_OPT=""
export GENUS_RUN_COUNTER=0

while [[ $# -gt 0 ]]; do
    case $1 in
        --no-abort)   ABORT_FLAG="";                        shift ;;
        --low-power)  LOW_POWER_OPT=" Genus_Low_Power_Opt"; shift ;;
        --run)        GENUS_RUN_COUNTER="$2";               shift 2 ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

RUN_DIR="$SCRIPT_DIR/../../../../../run/work/genus/genus_run_$(printf '%02d' "${GENUS_RUN_COUNTER}")"
mkdir -p "$RUN_DIR"
cd "$RUN_DIR"

# trap ensures we return to the scripts folder even when:
#   - Genus exits normally
#   - --no-abort drops into interactive prompt and user types exit
#   - an error causes early termination
trap "cd \"$SCRIPT_DIR\"" EXIT

genus -lic_startup Genus_Synthesis $ABORT_FLAG \
      -lic_startup_options "Genus_Physical_Opt${LOW_POWER_OPT}" \
      -files /work/cgra4ml/deepsocflow/tcl/asic/cadence/scripts/genus.tcl