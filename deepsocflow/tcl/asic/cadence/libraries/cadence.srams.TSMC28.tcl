# Tech Paths of SRAM
set paths(SRAM_TECH_FILES) "$paths(PDK_ROOT)/SRAM_Inst"

set tech_files(SRAM_WEIGHTS_LEF) "$paths(SRAM_TECH_FILES)/sram_weights/sram_weights.lef"
    lappend tech_files(ALL_LEFS) $tech_files(SRAM_WEIGHTS_LEF)
set tech_files(SRAM_EDGES_LEF) "$paths(SRAM_TECH_FILES)/sram_edges/sram_edges.lef"
    lappend tech_files(ALL_LEFS) $tech_files(SRAM_EDGES_LEF)