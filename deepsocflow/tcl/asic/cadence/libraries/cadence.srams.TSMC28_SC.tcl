# Set Paths for Timing Libs
set paths(SRAM_LIB_WEIGHTS_Paths)    "$paths(PDK_ROOT)/SRAM_Inst_old_cgra4ml/sram_weights"
set paths(SRAM_LIB_EDGES_Paths)      "$paths(PDK_ROOT)/SRAM_Inst_old_cgra4ml/sram_edges"

# SRAM Libs - SRAM Weights

set tech_files(SRAM_WEIGHTS_LVT_BC_LIB) "$paths(SRAM_LIB_WEIGHTS_Paths)/sram_weights_ffg_cbestt_0p88v_0p99v_m40c.lib"
    set tech_files(ALL_BC_LIBS) $tech_files(SRAM_WEIGHTS_LVT_BC_LIB)
set tech_files(SRAM_WEIGHTS_LVT_WC_LIB) "$paths(SRAM_LIB_WEIGHTS_Paths)/sram_weights_ssg_cworstt_0p72v_0p81v_125c.lib"
    set tech_files(ALL_WC_LIBS) $tech_files(SRAM_WEIGHTS_LVT_WC_LIB)
set tech_files(SRAM_WEIGHTS_LVT_TC_LIB) "$paths(SRAM_LIB_WEIGHTS_Paths)/sram_weights_tt_ctypical_0p80v_0p90v_85c.lib"
    set tech_files(ALL_TC_LIBS) $tech_files(SRAM_WEIGHTS_LVT_TC_LIB)

set tech_files(SRAM_WEIGHTS_RVT_BC_LIB) "$paths(SRAM_LIB_WEIGHTS_Paths)/sram_weights_ffg_cbestt_0p99v_0p99v_m40c.lib"
    lappend tech_files(ALL_BC_LIBS) $tech_files(SRAM_WEIGHTS_RVT_BC_LIB)
set tech_files(SRAM_WEIGHTS_RVT_WC_LIB) "$paths(SRAM_LIB_WEIGHTS_Paths)/sram_weights_ssg_cworstt_0p81v_0p81v_125c.lib"
    lappend tech_files(ALL_WC_LIBS) $tech_files(SRAM_WEIGHTS_RVT_WC_LIB)
set tech_files(SRAM_WEIGHTS_RVT_TC_LIB) "$paths(SRAM_LIB_WEIGHTS_Paths)/sram_weights_tt_ctypical_0p90v_0p90v_85c.lib"
    lappend tech_files(ALL_TC_LIBS) $tech_files(SRAM_WEIGHTS_RVT_TC_LIB)

set tech_files(SRAM_WEIGHTS_HVT_BC_LIB) "$paths(SRAM_LIB_WEIGHTS_Paths)/sram_weights_ffg_cbestt_1p05v_1p05v_m40c.lib"
    lappend tech_files(ALL_BC_LIBS) $tech_files(SRAM_WEIGHTS_HVT_BC_LIB)
set tech_files(SRAM_WEIGHTS_HVT_WC_LIB) "$paths(SRAM_LIB_WEIGHTS_Paths)/sram_weights_ssg_cworstt_0p90v_0p90v_125c.lib"
    lappend tech_files(ALL_WC_LIBS) $tech_files(SRAM_WEIGHTS_HVT_WC_LIB)
set tech_files(SRAM_WEIGHTS_HVT_TC_LIB) "$paths(SRAM_LIB_WEIGHTS_Paths)/sram_weights_tt_ctypical_1p00v_1p00v_85c.lib"
    lappend tech_files(ALL_TC_LIBS) $tech_files(SRAM_WEIGHTS_HVT_TC_LIB)

# SRAM Libs - SRAM Edges

set tech_files(SRAM_EDGES_LVT_BC_LIB) "$paths(SRAM_LIB_EDGES_Paths)/sram_edges_ffg_cbestt_0p88v_0p99v_m40c.lib"
    set tech_files(ALL_BC_LIBS) $tech_files(SRAM_EDGES_LVT_BC_LIB)
set tech_files(SRAM_EDGES_LVT_WC_LIB) "$paths(SRAM_LIB_EDGES_Paths)/sram_edges_ssg_cworstt_0p72v_0p81v_125c.lib"
    set tech_files(ALL_WC_LIBS) $tech_files(SRAM_EDGES_LVT_WC_LIB)
set tech_files(SRAM_EDGES_LVT_TC_LIB) "$paths(SRAM_LIB_EDGES_Paths)/sram_edges_tt_ctypical_0p80v_0p90v_85c.lib"
    set tech_files(ALL_TC_LIBS) $tech_files(SRAM_EDGES_LVT_TC_LIB)

set tech_files(SRAM_EDGES_RVT_BC_LIB) "$paths(SRAM_LIB_EDGES_Paths)/sram_edges_ffg_cbestt_0p99v_0p99v_m40c.lib"
    lappend tech_files(ALL_BC_LIBS) $tech_files(SRAM_EDGES_RVT_BC_LIB)
set tech_files(SRAM_EDGES_RVT_WC_LIB) "$paths(SRAM_LIB_EDGES_Paths)/sram_edges_ssg_cworstt_0p81v_0p81v_125c.lib"
    lappend tech_files(ALL_WC_LIBS) $tech_files(SRAM_EDGES_RVT_WC_LIB)
set tech_files(SRAM_EDGES_RVT_TC_LIB) "$paths(SRAM_LIB_EDGES_Paths)/sram_edges_tt_ctypical_0p90v_0p90v_85c.lib"
    lappend tech_files(ALL_TC_LIBS) $tech_files(SRAM_EDGES_RVT_TC_LIB)

set tech_files(SRAM_EDGES_HVT_BC_LIB) "$paths(SRAM_LIB_EDGES_Paths)/sram_edges_ffg_cbestt_1p05v_1p05v_m40c.lib"
    lappend tech_files(ALL_BC_LIBS) $tech_files(SRAM_EDGES_HVT_BC_LIB)
set tech_files(SRAM_EDGES_HVT_WC_LIB) "$paths(SRAM_LIB_EDGES_Paths)/sram_edges_ssg_cworstt_0p90v_0p90v_125c.lib"
    lappend tech_files(ALL_WC_LIBS) $tech_files(SRAM_EDGES_HVT_WC_LIB)
set tech_files(SRAM_EDGES_HVT_TC_LIB) "$paths(SRAM_LIB_EDGES_Paths)/sram_edges_tt_ctypical_1p00v_1p00v_85c.lib"
    lappend tech_files(ALL_TC_LIBS) $tech_files(SRAM_EDGES_HVT_TC_LIB)

# CCS Libs

# set tech_files(CCS_STD_CELL_LVT_BC_LIB) "$paths(CCS_Paths)/sram_weights_ffg_cbestt_0p77v_0p88v_m40c.lib_ccs_tn"
#     set tech_files(ALL_BC_CCS_LIBS) $tech_files(CCS_STD_CELL_LVT_BC_LIB)
# set tech_files(CCS_STD_CELL_LVT_WC_LIB) "$paths(CCS_Paths)/sram_weights_ssg_cworstt_0p99v_0p72v_125c.lib_ccs_tn"
#     set tech_files(ALL_WC_CCS_LIBS) $tech_files(CCS_STD_CELL_LVT_WC_LIB)
# set tech_files(CCS_STD_CELL_LVT_TC_LIB) "$paths(CCS_Paths)/sram_weights_tt_ctypical_0p99v_0p70v_85c.lib_ccs_tn"
#     set tech_files(ALL_TC_CCS_LIBS) $tech_files(CCS_STD_CELL_LVT_TC_LIB)

# set tech_files(CCS_STD_CELL_RVT_BC_LIB) "$paths(CCS_Paths)/sram_weights_ffg_cbestt_0p77v_0p88v_m40c.lib_ccs_tn"
#     lappend tech_files(ALL_BC_CCS_LIBS) $tech_files(CCS_STD_CELL_RVT_BC_LIB)
# set tech_files(CCS_STD_CELL_RVT_WC_LIB) "$paths(CCS_Paths)/sram_weights_ssg_cworstt_0p77v_0p81v_125c.lib_ccs_tn"
#     lappend tech_files(ALL_WC_CCS_LIBS) $tech_files(CCS_STD_CELL_RVT_WC_LIB)
# set tech_files(CCS_STD_CELL_RVT_TC_LIB) "$paths(CCS_Paths)/sram_weights_tt_ctypical_0p99v_0p90v_85c.lib_ccs_tn"
#     lappend tech_files(ALL_TC_CCS_LIBS) $tech_files(CCS_STD_CELL_RVT_TC_LIB)

# set tech_files(CCS_STD_CELL_HVT_BC_LIB) "$paths(CCS_Paths)/sram_weights_ffg_cbestt_0p77v_1p05v_m40c.lib_ccs_tn"
#     lappend tech_files(ALL_BC_CCS_LIBS) $tech_files(CCS_STD_CELL_HVT_BC_LIB)
# set tech_files(CCS_STD_CELL_HVT_WC_LIB) "$paths(CCS_Paths)/sram_weights_ssg_cworstt_0p77v_0p90v_125c.lib_ccs_tn"
#     lappend tech_files(ALL_WC_CCS_LIBS) $tech_files(CCS_STD_CELL_HVT_WC_LIB)
# set tech_files(CCS_STD_CELL_HVT_TC_LIB) "$paths(CCS_Paths)/sram_weights_tt_ctypical_0p99v_1p05v_85c.lib_ccs_tn"
#     lappend tech_files(ALL_TC_CCS_LIBS) $tech_files(CCS_STD_CELL_HVT_TC_LIB)

# AOCV Libs

# set tech_files(AOCV_STD_CELL_LVT_BC_LIB) "$paths(AOCV_Paths)/sram_weights_ffg_cbestt_0p77v_0p88v_m40c_10pct.aocv3"
#     set tech_files(ALL_BC_AOCV_LIBS) $tech_files(AOCV_STD_CELL_LVT_BC_LIB)
# set tech_files(AOCV_STD_CELL_LVT_WC_LIB) "$paths(AOCV_Paths)/sram_weights_ssg_cworstt_0p99v_0p72v_125c_5pct.aocv3"
#     set tech_files(ALL_WC_AOCV_LIBS) $tech_files(AOCV_STD_CELL_LVT_WC_LIB)
# set tech_files(AOCV_STD_CELL_LVT_TC_LIB) "$paths(AOCV_Paths)/sram_weights_tt_ctypical_0p99v_0p70v_85c_7pct.aocv3"
#     set tech_files(ALL_TC_AOCV_LIBS) $tech_files(AOCV_STD_CELL_LVT_TC_LIB)

# set tech_files(AOCV_STD_CELL_RVT_BC_LIB) "$paths(AOCV_Paths)/sram_weights_ffg_cbestt_0p77v_0p88v_m40c_10pct.aocv3"
#     lappend tech_files(ALL_BC_AOCV_LIBS) $tech_files(AOCV_STD_CELL_RVT_BC_LIB)
# set tech_files(AOCV_STD_CELL_RVT_WC_LIB) "$paths(AOCV_Paths)/sram_weights_ssg_cworstt_0p77v_0p81v_125c_5pct.aocv3"
#     lappend tech_files(ALL_WC_AOCV_LIBS) $tech_files(AOCV_STD_CELL_RVT_WC_LIB)
# set tech_files(AOCV_STD_CELL_RVT_TC_LIB) "$paths(AOCV_Paths)/sram_weights_tt_ctypical_0p99v_0p90v_85c_7pct.aocv3"
#     lappend tech_files(ALL_TC_AOCV_LIBS) $tech_files(AOCV_STD_CELL_RVT_TC_LIB)

# set tech_files(AOCV_STD_CELL_HVT_BC_LIB) "$paths(AOCV_Paths)/sram_weights_ffg_cbestt_0p77v_1p05v_m40c_10pct.aocv3"
#     lappend tech_files(ALL_BC_AOCV_LIBS) $tech_files(AOCV_STD_CELL_HVT_BC_LIB)
# set tech_files(AOCV_STD_CELL_HVT_WC_LIB) "$paths(AOCV_Paths)/sram_weights_ssg_cworstt_0p77v_0p90v_125c_5pct.aocv3"
#     lappend tech_files(ALL_WC_AOCV_LIBS) $tech_files(AOCV_STD_CELL_HVT_WC_LIB)
# set tech_files(AOCV_STD_CELL_HVT_TC_LIB) "$paths(AOCV_Paths)/sram_weights_tt_ctypical_0p99v_1p05v_85c_7pct.aocv3"
#     lappend tech_files(ALL_TC_AOCV_LIBS) $tech_files(AOCV_STD_CELL_HVT_TC_LIB)