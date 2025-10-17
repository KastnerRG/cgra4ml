# setMultiCpuUsage -localCpu 8
# 
# source ../../deepsocflow/tcl/asic/loadDesignTech.tcl
# source ../../deepsocflow/tcl/asic/macro_placement.tcl
# source ../../deepsocflow/tcl/asic/initialFloorplan.tcl
source ../../deepsocflow/tcl/asic/pinPlacement.tcl
source ../../deepsocflow/tcl/asic/placement.tcl
source ../../deepsocflow/tcl/asic/clock.tcl
source ../../deepsocflow/tcl/asic/route.tcl
source ../../deepsocflow/tcl/asic/reportDesign.tcl
source ../../deepsocflow/tcl/asic/outputGen.tcl

gui_fit
saveDesign route.enc
dumpToGIF ../../docs/pnr_drc_violations.gif
verify_drc -report ../asic/reports/dnn_engine_drc_report.rpt
dumpToGIF ../../docs/pnr_no_drc.gif