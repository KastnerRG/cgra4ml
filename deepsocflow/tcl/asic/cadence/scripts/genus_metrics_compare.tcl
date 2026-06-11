##############################################################################
# Project   : DeepSoCFlow CGRA4ML
# Script    : genus_metrics_compare.tcl
# Purpose   : Compare N Genus metric runs and generate a visual HTML report
##############################################################################
# Author    : Ravidu Munasinghe <raviduhm@gmail.com>
# Org       : Kastner Research Group | ENTC UoM
# Created   : 2026-06-11
# Modified  : 2026-06-11
##############################################################################
# Version   : 1.2
# Status    : Completed
##############################################################################
#
# Description:
#   Loads N Genus metric JSON files (one per run) and generates a side-by-side
#   HTML comparison report using report_metric -format vivid.
#   Useful for comparing PPA across multiple synthesis runs (e.g. sweeping
#   effort settings, frequency targets, or flow updates).
#
##############################################################################
# TODO:
#   [X] Parameterize input JSON file paths via environment variables
#   [X] Add timestamp to output HTML filename to avoid overwriting
##############################################################################
# Usage:
#   genus -files genus_metrics_compare.tcl
#   Then open $design(compare_dir)/compare_all.html in a browser
##############################################################################

################################################
#            Parameters
################################################
set design(TOPLEVEL)    "cgra4ml"
set design(compare_dir) "/work/cgra4ml/run/asic/cadence/compare"

set tool        "genus" ;   # genus | innovus | genus_innovus
set num_runs    7
set json_dir    $design(compare_dir)
set json_name   "$design(TOPLEVEL)_${tool}_run_"
set json_ext    ".json"
set report_file "$json_dir/compare_${tool}_runs_upto_${num_runs}.html"

################################################
#            Load metrics for each run
################################################
set run_ids {}

for { set i 1 } { $i <= $num_runs } { incr i } {
    set run_id    "${tool}_run_[format "%02d" $i]"
    set json_file "$json_dir/${json_name}[format "%02d" $i]${json_ext}"
    read_metric -id $run_id $json_file
    lappend run_ids $run_id
}

################################################
#            Generate comparison report
################################################
report_metric -id $run_ids -format vivid -file $report_file
