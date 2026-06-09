#!/usr/bin/env bash
set -e

genus -lic_startup Genus_Synthesis -lic_startup_options Genus_Physical_Opt -abort_on_error \
      -files /work/cgra4ml/deepsocflow/tcl/asic/cadence/scripts/genus.tcl 