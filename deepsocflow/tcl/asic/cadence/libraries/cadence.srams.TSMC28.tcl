# SRAM Power Straps Widths, Spacing
set tech(SRAM_PINS_TO_STRAP)    7
set tech(SRAM_MIN_WIDTH)        0.210
set tech(SRAM_MAX_SPACING)      10
set tech(SRAM_MIN_INTERVAL)     10

# Tech Paths of SRAM
set paths(SRAM_TECH_FILES)       "$paths(PDK_ROOT)/SRAM_Inst_old_cgra4ml"

set tech_files(SRAM_WEIGHTS_LEF) "$paths(SRAM_TECH_FILES)/sram_weights/sram_weights.lef"
    lappend tech_files(ALL_LEFS) $tech_files(SRAM_WEIGHTS_LEF)
set tech_files(SRAM_EDGES_LEF)   "$paths(SRAM_TECH_FILES)/sram_edges/sram_edges.lef"
    lappend tech_files(ALL_LEFS) $tech_files(SRAM_EDGES_LEF)