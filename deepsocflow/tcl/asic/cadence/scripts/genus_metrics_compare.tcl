##############################################################################
# Project   : DeepSoCFlow CGRA4ML
# Script    : genus_metrics_compare.tcl
# Purpose   : Compare two Genus metric runs and generate a visual HTML report
##############################################################################
# Author    : Ravidu Munasinghe <raviduhm@gmail.com>
# Org       : Kastner Research Group | ENTC UoM
# Created   : 2026-06-11
# Modified  : 2026-06-11
##############################################################################
# Version   : 1.0
# Status    : In Progress
##############################################################################
#
# Description:
#   Loads two Genus metric JSON files (gold and comparison run) and
#   generates a side-by-side HTML diff report using report_metric -format vivid.
#   Useful for comparing PPA between two synthesis runs (e.g. before/after
#   a settings change or flow update).
#
##############################################################################
# TODO:
#   [ ] Parameterize input JSON file paths via environment variables
#   [ ] Add timestamp to output HTML filename to avoid overwriting
##############################################################################
# Usage:
#   genus -files genus_metrics_compare.tcl
#   Then open compare.html in a browser to view the comparison report
##############################################################################

read_metric -id gold run1.jason
read_metric -id comp run2.jason
report_metric -id "gold comp" -format vivid -file compare.html