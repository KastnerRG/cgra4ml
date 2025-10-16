# Tech Paths of SRAM
set paths(SRAM_TECH_FILES) "$paths(PDK_ROOT)/SRAM_Inst/sram_weights"

set tech_files(SRAM_WEIGHTS_LEF) "$paths(SRAM_TECH_FILES)/sp_sram_weights.lef"
    lappend tech_files(ALL_LEFS) $tech_files(SRAM_WEIGHTS_LEF)
set tech_files(SRAM_EDGES_LEF) "$paths(SRAM_TECH_FILES)/sp_sram_edges.lef"
    lappend tech_files(ALL_LEFS) $tech_files(SRAM_EDGES_LEF)
set tech_files(SRAM_DMA_LEF) "$paths(SRAM_TECH_FILES)/dp_sram_dma.lef"
    lappend tech_files(ALL_LEFS) $tech_files(SRAM_DMA_LEF)

