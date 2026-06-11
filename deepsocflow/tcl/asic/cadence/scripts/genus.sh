#!/usr/bin/env bash
# Usage:
#   cd <run_dir>/work/genus_runs
#   bash <path_to>/genus.sh [--no-abort] [--low-power]
#
# Options:
#   --no-abort    Drop into the Genus interactive prompt on error instead of
#                 exiting — useful for debugging mid-flow.
#   --low-power   Add Genus_Low_Power_Opt to the license startup options.
set -e

ABORT_FLAG="-abort_on_error"
LOW_POWER_OPT=""

for arg in "$@"; do
    case $arg in
        --no-abort)   ABORT_FLAG="" ;;
        --low-power)  LOW_POWER_OPT=" Genus_Low_Power_Opt" ;;
    esac
done

genus -lic_startup Genus_Synthesis $ABORT_FLAG \
      -lic_startup_options "Genus_Physical_Opt${LOW_POWER_OPT}" \
      -files /work/cgra4ml/deepsocflow/tcl/asic/cadence/scripts/genus.tcl