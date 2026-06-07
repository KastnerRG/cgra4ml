# Set Paths for Timing Libs
set paths(SRAM_LIB_WEIGHTS_Paths)    "$paths(PDK_ROOT)/SRAM_Inst/sram_weights"
set paths(SRAM_LIB_EDGES_Paths)      "$paths(PDK_ROOT)/SRAM_Inst/sram_edges"
set paths(SRAM_LIB_DMA_Paths)        "$paths(PDK_ROOT)/SRAM_Inst/sram_dma"

# SRAM Libs - SRAM Weights

set tech_files(SRAM_WEIGHTS_LVT_BC_LIB) "$paths(SRAM_LIB_WEIGHTS_Paths)/sc9mcpp140z_cln28ht_base_ulvt_c35_ffg_cbestt_min_0p77v_m40c.lib"
    set tech_files(ALL_BC_LIBS) $tech_files(SRAM_WEIGHTS_LVT_BC_LIB)
set tech_files(SRAM_WEIGHTS_LVT_WC_LIB) "$paths(SRAM_LIB_WEIGHTS_Paths)/sc9mcpp140z_cln28ht_base_ulvt_c35_ssg_cworstt_max_0p72v_125c.lib"
    set tech_files(ALL_WC_LIBS) $tech_files(SRAM_WEIGHTS_LVT_WC_LIB)
set tech_files(SRAM_WEIGHTS_LVT_TC_LIB) "$paths(SRAM_LIB_WEIGHTS_Paths)/sc9mcpp140z_cln28ht_base_ulvt_c35_tt_ctypical_max_0p70v_85c.lib"
    set tech_files(ALL_TC_LIBS) $tech_files(SRAM_WEIGHTS_LVT_TC_LIB)

set tech_files(SRAM_WEIGHTS_RVT_BC_LIB) "$paths(SRAM_LIB_WEIGHTS_Paths)/sc9mcpp140z_cln28ht_base_ulvt_c35_ffg_cbestt_min_0p88v_m40c.lib"
    lappend tech_files(ALL_BC_LIBS) $tech_files(SRAM_WEIGHTS_RVT_BC_LIB)
set tech_files(SRAM_WEIGHTS_RVT_WC_LIB) "$paths(SRAM_LIB_WEIGHTS_Paths)/sc9mcpp140z_cln28ht_base_ulvt_c35_ssg_cworstt_max_0p81v_125c.lib"
    lappend tech_files(ALL_WC_LIBS) $tech_files(SRAM_WEIGHTS_RVT_WC_LIB)
set tech_files(SRAM_WEIGHTS_RVT_TC_LIB) "$paths(SRAM_LIB_WEIGHTS_Paths)/sc9mcpp140z_cln28ht_base_ulvt_c35_tt_ctypical_max_0p90v_85c.lib"
    lappend tech_files(ALL_TC_LIBS) $tech_files(SRAM_WEIGHTS_RVT_TC_LIB)

set tech_files(SRAM_WEIGHTS_HVT_BC_LIB) "$paths(SRAM_LIB_WEIGHTS_Paths)/sc9mcpp140z_cln28ht_base_ulvt_c35_ffg_cbestt_min_1p05v_m40c.lib"
    lappend tech_files(ALL_BC_LIBS) $tech_files(SRAM_WEIGHTS_HVT_BC_LIB)
set tech_files(SRAM_WEIGHTS_HVT_WC_LIB) "$paths(SRAM_LIB_WEIGHTS_Paths)/sc9mcpp140z_cln28ht_base_ulvt_c35_ssg_cworstt_max_0p90v_125c.lib"
    lappend tech_files(ALL_WC_LIBS) $tech_files(SRAM_WEIGHTS_HVT_WC_LIB)
set tech_files(SRAM_WEIGHTS_HVT_TC_LIB) "$paths(SRAM_LIB_WEIGHTS_Paths)/sc9mcpp140z_cln28ht_base_ulvt_c35_tt_ctypical_max_1p05v_85c.lib"
    lappend tech_files(ALL_TC_LIBS) $tech_files(SRAM_WEIGHTS_HVT_TC_LIB)

# SRAM Libs - SRAM Edges

set tech_files(STANDARD_CELLS_LVT_BC_LIB) "$paths(SRAM_LIB_EDGES_Paths)/sc9mcpp140z_cln28ht_base_ulvt_c35_ffg_cbestt_min_0p77v_m40c.lib"
    set tech_files(ALL_BC_LIBS) $tech_files(STANDARD_CELLS_LVT_BC_LIB)
set tech_files(STANDARD_CELLS_LVT_WC_LIB) "$paths(SRAM_LIB_EDGES_Paths)/sc9mcpp140z_cln28ht_base_ulvt_c35_ssg_cworstt_max_0p72v_125c.lib"
    set tech_files(ALL_WC_LIBS) $tech_files(STANDARD_CELLS_LVT_WC_LIB)
set tech_files(STANDARD_CELLS_LVT_TC_LIB) "$paths(SRAM_LIB_EDGES_Paths)/sc9mcpp140z_cln28ht_base_ulvt_c35_tt_ctypical_max_0p70v_85c.lib"
    set tech_files(ALL_TC_LIBS) $tech_files(STANDARD_CELLS_LVT_TC_LIB)

set tech_files(STANDARD_CELLS_RVT_BC_LIB) "$paths(SRAM_LIB_EDGES_Paths)/sc9mcpp140z_cln28ht_base_ulvt_c35_ffg_cbestt_min_0p88v_m40c.lib"
    lappend tech_files(ALL_BC_LIBS) $tech_files(STANDARD_CELLS_RVT_BC_LIB)
set tech_files(STANDARD_CELLS_RVT_WC_LIB) "$paths(SRAM_LIB_EDGES_Paths)/sc9mcpp140z_cln28ht_base_ulvt_c35_ssg_cworstt_max_0p81v_125c.lib"
    lappend tech_files(ALL_WC_LIBS) $tech_files(STANDARD_CELLS_RVT_WC_LIB)
set tech_files(STANDARD_CELLS_RVT_TC_LIB) "$paths(SRAM_LIB_EDGES_Paths)/sc9mcpp140z_cln28ht_base_ulvt_c35_tt_ctypical_max_0p90v_85c.lib"
    lappend tech_files(ALL_TC_LIBS) $tech_files(STANDARD_CELLS_RVT_TC_LIB)

set tech_files(STANDARD_CELLS_HVT_BC_LIB) "$paths(SRAM_LIB_EDGES_Paths)/sc9mcpp140z_cln28ht_base_ulvt_c35_ffg_cbestt_min_1p05v_m40c.lib"
    lappend tech_files(ALL_BC_LIBS) $tech_files(STANDARD_CELLS_HVT_BC_LIB)
set tech_files(STANDARD_CELLS_HVT_WC_LIB) "$paths(SRAM_LIB_EDGES_Paths)/sc9mcpp140z_cln28ht_base_ulvt_c35_ssg_cworstt_max_0p90v_125c.lib"
    lappend tech_files(ALL_WC_LIBS) $tech_files(STANDARD_CELLS_HVT_WC_LIB)
set tech_files(STANDARD_CELLS_HVT_TC_LIB) "$paths(SRAM_LIB_EDGES_Paths)/sc9mcpp140z_cln28ht_base_ulvt_c35_tt_ctypical_max_1p05v_85c.lib"
    lappend tech_files(ALL_TC_LIBS) $tech_files(STANDARD_CELLS_HVT_TC_LIB)

# SRAM Libs - SRAM DMA

set tech_files(STANDARD_CELLS_LVT_BC_LIB) "$paths(SRAM_LIB_DMA_Paths)/sc9mcpp140z_cln28ht_base_ulvt_c35_ffg_cbestt_min_0p77v_m40c.lib"
    set tech_files(ALL_BC_LIBS) $tech_files(STANDARD_CELLS_LVT_BC_LIB)
set tech_files(STANDARD_CELLS_LVT_WC_LIB) "$paths(SRAM_LIB_DMA_Paths)/sc9mcpp140z_cln28ht_base_ulvt_c35_ssg_cworstt_max_0p72v_125c.lib"
    set tech_files(ALL_WC_LIBS) $tech_files(STANDARD_CELLS_LVT_WC_LIB)
set tech_files(STANDARD_CELLS_LVT_TC_LIB) "$paths(SRAM_LIB_DMA_Paths)/sc9mcpp140z_cln28ht_base_ulvt_c35_tt_ctypical_max_0p70v_85c.lib"
    set tech_files(ALL_TC_LIBS) $tech_files(STANDARD_CELLS_LVT_TC_LIB)

set tech_files(STANDARD_CELLS_RVT_BC_LIB) "$paths(SRAM_LIB_DMA_Paths)/sc9mcpp140z_cln28ht_base_ulvt_c35_ffg_cbestt_min_0p88v_m40c.lib"
    lappend tech_files(ALL_BC_LIBS) $tech_files(STANDARD_CELLS_RVT_BC_LIB)
set tech_files(STANDARD_CELLS_RVT_WC_LIB) "$paths(SRAM_LIB_DMA_Paths)/sc9mcpp140z_cln28ht_base_ulvt_c35_ssg_cworstt_max_0p81v_125c.lib"
    lappend tech_files(ALL_WC_LIBS) $tech_files(STANDARD_CELLS_RVT_WC_LIB)
set tech_files(STANDARD_CELLS_RVT_TC_LIB) "$paths(SRAM_LIB_DMA_Paths)/sc9mcpp140z_cln28ht_base_ulvt_c35_tt_ctypical_max_0p90v_85c.lib"
    lappend tech_files(ALL_TC_LIBS) $tech_files(STANDARD_CELLS_RVT_TC_LIB)

set tech_files(STANDARD_CELLS_HVT_BC_LIB) "$paths(SRAM_LIB_DMA_Paths)/sc9mcpp140z_cln28ht_base_ulvt_c35_ffg_cbestt_min_1p05v_m40c.lib"
    lappend tech_files(ALL_BC_LIBS) $tech_files(STANDARD_CELLS_HVT_BC_LIB)
set tech_files(STANDARD_CELLS_HVT_WC_LIB) "$paths(SRAM_LIB_DMA_Paths)/sc9mcpp140z_cln28ht_base_ulvt_c35_ssg_cworstt_max_0p90v_125c.lib"
    lappend tech_files(ALL_WC_LIBS) $tech_files(STANDARD_CELLS_HVT_WC_LIB)
set tech_files(STANDARD_CELLS_HVT_TC_LIB) "$paths(SRAM_LIB_DMA_Paths)/sc9mcpp140z_cln28ht_base_ulvt_c35_tt_ctypical_max_1p05v_85c.lib"
    lappend tech_files(ALL_TC_LIBS) $tech_files(STANDARD_CELLS_HVT_TC_LIB)


# CCS Libs

# set tech_files(CCS_STD_CELL_LVT_BC_LIB) "$paths(CCS_Paths)/sc9mcpp140z_cln28ht_base_ulvt_c35_ffg_cbestt_min_0p77v_m40c.lib_ccs_tn"
#     set tech_files(ALL_BC_CCS_LIBS) $tech_files(CCS_STD_CELL_LVT_BC_LIB)
# set tech_files(CCS_STD_CELL_LVT_WC_LIB) "$paths(CCS_Paths)/sc9mcpp140z_cln28ht_base_ulvt_c35_ssg_cworstt_max_0p72v_125c.lib_ccs_tn"
#     set tech_files(ALL_WC_CCS_LIBS) $tech_files(CCS_STD_CELL_LVT_WC_LIB)
# set tech_files(CCS_STD_CELL_LVT_TC_LIB) "$paths(CCS_Paths)/sc9mcpp140z_cln28ht_base_ulvt_c35_tt_ctypical_max_0p70v_85c.lib_ccs_tn"
#     set tech_files(ALL_TC_CCS_LIBS) $tech_files(CCS_STD_CELL_LVT_TC_LIB)

# set tech_files(CCS_STD_CELL_RVT_BC_LIB) "$paths(CCS_Paths)/sc9mcpp140z_cln28ht_base_ulvt_c35_ffg_cbestt_min_0p88v_m40c.lib_ccs_tn"
#     lappend tech_files(ALL_BC_CCS_LIBS) $tech_files(CCS_STD_CELL_RVT_BC_LIB)
# set tech_files(CCS_STD_CELL_RVT_WC_LIB) "$paths(CCS_Paths)/sc9mcpp140z_cln28ht_base_ulvt_c35_ssg_cworstt_max_0p81v_125c.lib_ccs_tn"
#     lappend tech_files(ALL_WC_CCS_LIBS) $tech_files(CCS_STD_CELL_RVT_WC_LIB)
# set tech_files(CCS_STD_CELL_RVT_TC_LIB) "$paths(CCS_Paths)/sc9mcpp140z_cln28ht_base_ulvt_c35_tt_ctypical_max_0p90v_85c.lib_ccs_tn"
#     lappend tech_files(ALL_TC_CCS_LIBS) $tech_files(CCS_STD_CELL_RVT_TC_LIB)

# set tech_files(CCS_STD_CELL_HVT_BC_LIB) "$paths(CCS_Paths)/sc9mcpp140z_cln28ht_base_ulvt_c35_ffg_cbestt_min_1p05v_m40c.lib_ccs_tn"
#     lappend tech_files(ALL_BC_CCS_LIBS) $tech_files(CCS_STD_CELL_HVT_BC_LIB)
# set tech_files(CCS_STD_CELL_HVT_WC_LIB) "$paths(CCS_Paths)/sc9mcpp140z_cln28ht_base_ulvt_c35_ssg_cworstt_max_0p90v_125c.lib_ccs_tn"
#     lappend tech_files(ALL_WC_CCS_LIBS) $tech_files(CCS_STD_CELL_HVT_WC_LIB)
# set tech_files(CCS_STD_CELL_HVT_TC_LIB) "$paths(CCS_Paths)/sc9mcpp140z_cln28ht_base_ulvt_c35_tt_ctypical_max_1p05v_85c.lib_ccs_tn"
#     lappend tech_files(ALL_TC_CCS_LIBS) $tech_files(CCS_STD_CELL_HVT_TC_LIB)

# AOCV Libs

# set tech_files(AOCV_STD_CELL_LVT_BC_LIB) "$paths(AOCV_Paths)/sc9mcpp140z_cln28ht_base_ulvt_c35_ffg_cbestt_min_0p77v_m40c_10pct.aocv3"
#     set tech_files(ALL_BC_AOCV_LIBS) $tech_files(AOCV_STD_CELL_LVT_BC_LIB)
# set tech_files(AOCV_STD_CELL_LVT_WC_LIB) "$paths(AOCV_Paths)/sc9mcpp140z_cln28ht_base_ulvt_c35_ssg_cworstt_max_0p72v_125c_5pct.aocv3"
#     set tech_files(ALL_WC_AOCV_LIBS) $tech_files(AOCV_STD_CELL_LVT_WC_LIB)
# set tech_files(AOCV_STD_CELL_LVT_TC_LIB) "$paths(AOCV_Paths)/sc9mcpp140z_cln28ht_base_ulvt_c35_tt_ctypical_max_0p70v_85c_7pct.aocv3"
#     set tech_files(ALL_TC_AOCV_LIBS) $tech_files(AOCV_STD_CELL_LVT_TC_LIB)

# set tech_files(AOCV_STD_CELL_RVT_BC_LIB) "$paths(AOCV_Paths)/sc9mcpp140z_cln28ht_base_ulvt_c35_ffg_cbestt_min_0p88v_m40c_10pct.aocv3"
#     lappend tech_files(ALL_BC_AOCV_LIBS) $tech_files(AOCV_STD_CELL_RVT_BC_LIB)
# set tech_files(AOCV_STD_CELL_RVT_WC_LIB) "$paths(AOCV_Paths)/sc9mcpp140z_cln28ht_base_ulvt_c35_ssg_cworstt_max_0p81v_125c_5pct.aocv3"
#     lappend tech_files(ALL_WC_AOCV_LIBS) $tech_files(AOCV_STD_CELL_RVT_WC_LIB)
# set tech_files(AOCV_STD_CELL_RVT_TC_LIB) "$paths(AOCV_Paths)/sc9mcpp140z_cln28ht_base_ulvt_c35_tt_ctypical_max_0p90v_85c_7pct.aocv3"
#     lappend tech_files(ALL_TC_AOCV_LIBS) $tech_files(AOCV_STD_CELL_RVT_TC_LIB)

# set tech_files(AOCV_STD_CELL_HVT_BC_LIB) "$paths(AOCV_Paths)/sc9mcpp140z_cln28ht_base_ulvt_c35_ffg_cbestt_min_1p05v_m40c_10pct.aocv3"
#     lappend tech_files(ALL_BC_AOCV_LIBS) $tech_files(AOCV_STD_CELL_HVT_BC_LIB)
# set tech_files(AOCV_STD_CELL_HVT_WC_LIB) "$paths(AOCV_Paths)/sc9mcpp140z_cln28ht_base_ulvt_c35_ssg_cworstt_max_0p90v_125c_5pct.aocv3"
#     lappend tech_files(ALL_WC_AOCV_LIBS) $tech_files(AOCV_STD_CELL_HVT_WC_LIB)
# set tech_files(AOCV_STD_CELL_HVT_TC_LIB) "$paths(AOCV_Paths)/sc9mcpp140z_cln28ht_base_ulvt_c35_tt_ctypical_max_1p05v_85c_7pct.aocv3"
#     lappend tech_files(ALL_TC_AOCV_LIBS) $tech_files(AOCV_STD_CELL_HVT_TC_LIB)