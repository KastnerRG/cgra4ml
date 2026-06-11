# Tech Paths of SRAM
set paths(SRAM_TECH_FILES) "$paths(SRAM_FILES)/SRAM_Inst/sram_weights"

set tech_files(SRAM_WEIGHTS_LEF) "$paths(SRAM_LIB_WEIGHTS_Paths)/sram_weight.lef"
    lappend tech_files(ALL_LEFS) $tech_files(SRAM_WEIGHTS_LEF)
set tech_files(SRAM_EDGES_LEF) "$paths(SRAM_LIB_EDGES_Paths)/sram_edge.lef"
    lappend tech_files(ALL_LEFS) $tech_files(SRAM_EDGES_LEF)
set tech_files(SRAM_DMA_LEF) "$paths(SRAM_LIB_DMA_Paths)/sram_dma.lef"
    lappend tech_files(ALL_LEFS) $tech_files(SRAM_DMA_LEF)
