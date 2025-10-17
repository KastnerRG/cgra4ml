# Routing
setNanoRouteMode -quiet -drouteAllowMergedWireAtPin false
# setNanoRouteMode -quiet -drouteFixAntenna true
setNanoRouteMode -quiet -routeWithTimingDriven true
setNanoRouteMode -quiet -routeWithSiDriven true
setNanoRouteMode -quiet -routeSiEffort high
setNanoRouteMode -quiet -routeWithSiPostRouteFix true
setNanoRouteMode -quiet -drouteAutoStop true
setNanoRouteMode -quiet -routeSelectedNetOnly false
setNanoRouteMode -quiet -drouteStartIteration default
routeDesign

# RC extraction for optimization
setExtractRCMode -engine postRoute
extractRC

# Post-route timing optimization
setAnalysisMode -analysisType onChipVariation -cppr both
optDesign -postRoute -setup -hold
# remove -drv -inc

# Fix DRC errors
optDesign -postRoute -drv
# -drv
optDesign -postRoute -inc
# -inc

saveDesign route.enc
