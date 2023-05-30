setMultiCpuUsage -localCpu 20

source ../scripts/loadDesignTech.tcl
source ../scripts/initialFloorplan.tcl
source ../scripts/pinPlacement.tcl
source ../scripts/placement.tcl
source ../scripts/clock.tcl
source ../scripts/route.tcl
source ../scripts/reportDesign.tcl
# source ../scripts/outputGen.tcl

saveDesign route.enc
