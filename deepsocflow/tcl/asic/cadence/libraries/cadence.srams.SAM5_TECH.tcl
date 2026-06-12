##############################################################################
# Script  : cadence.srams.SAM5_TECH.tcl
# Purpose : Append SRAM LEF files (weight, edge, DMA) to the global LEF list
#           for Samsung LN05LPE process
##############################################################################
#
# Sourced by Innovus (P&R) flow.
# Must be sourced after cadence.srams.SAM5_SC.tcl.
# Expects the following variables to be set before sourcing:
#   paths(SRAM_LIB_WEIGHTS_Paths)  — sram_weight lib directory
#   paths(SRAM_LIB_EDGES_Paths)    — sram_edge lib directory
#   paths(SRAM_LIB_DMA_Paths)      — sram_dma lib directory
#   tech_files(ALL_LEFS)           — existing LEF list to append to
#
# Defines:
#   tech_files(SRAM_WEIGHTS_LEF)   — weight SRAM LEF file
#   tech_files(SRAM_EDGES_LEF)     — edge SRAM LEF file
#   tech_files(SRAM_DMA_LEF)       — DMA SRAM LEF file
#   tech_files(ALL_LEFS)           — updated with all three SRAM LEFs appended
#
##############################################################################

# Loading Lef files of SRAMs

set tech_files(SRAM_WEIGHTS_LEF) "$paths(SRAM_LIB_WEIGHTS_Paths)/sram_weight.lef"
    lappend tech_files(ALL_LEFS) $tech_files(SRAM_WEIGHTS_LEF)
set tech_files(SRAM_EDGES_LEF) "$paths(SRAM_LIB_EDGES_Paths)/sram_edge.lef"
    lappend tech_files(ALL_LEFS) $tech_files(SRAM_EDGES_LEF)
set tech_files(SRAM_DMA_LEF) "$paths(SRAM_LIB_DMA_Paths)/sram_dma.lef"
    lappend tech_files(ALL_LEFS) $tech_files(SRAM_DMA_LEF)