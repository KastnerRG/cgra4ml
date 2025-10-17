# Placement
saveDesign floorplan.enc
setPlaceMode -timingDriven true -reorderScan false -congEffort high -modulePlan false
setOptMode -effort high -powerEffort high -leakageToDynamicRatio 0.5 -fixFanoutLoad true -restruct true -verbose false
place_opt_design

# addFiller -cell {DCAP DCAP4 DCAP8 DCAP16 DCAP32} -merge true

saveDesign placement.enc

