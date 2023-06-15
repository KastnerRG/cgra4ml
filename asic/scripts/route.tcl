# Routing
setNanoRouteMode -quiet -drouteAllowMergedWireAtPin false
# setNanoRouteMode -quiet -drouteFixAntenna true
setNanoRouteMode -quiet -routeWithTimingDriven true
setNanoRouteMode -quiet -routeWithSiDriven true
setNanoRouteMode -quiet -routeSiEffort low
setNanoRouteMode -quiet -routeWithSiPostRouteFix false
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

# Fix DRC errors
optDesign -postRoute -drv
optDesign -postRoute -inc

saveDesign route.enc
