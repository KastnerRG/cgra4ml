# Set Paths for Timing Libs
set paths(LIB_Paths)    "$paths(PDK_ROOT)/STD_Libs/lib"
set paths(CCS_Paths)    "$paths(PDK_ROOT)/STD_Libs/lib-ccs-tn"
set paths(AOCV_Paths)   "$paths(PDK_ROOT)/STD_Libs/aocv"

# General
set tech(STANDARD_CELL_VDD)   VDD
set tech(STANDARD_CELL_GND)   VSS
set tech(STANDARD_CELL_SITE)  sc9mcpp140z_cln28ht

# LEFS
lappend tech(LIB_SUPPRESS_MESSAGES_GENUS) {*}"LBR-9 LBR-76 LBR-40 LBR-436 LBR-170 LBR-415 LBR-162 LBR-155"
lappend tech(LIB_SUPPRESS_MESSAGES_INNOVUS) {*}"LBR-9 LBR-76 LBR-40 LBR-436 LBR-170 LBR-415 LBR-162 LBR-155"

# Libs

set tech_files(STANDARD_CELLS_LVT_BC_LIB) "$paths(LIB_Paths)/sc9mcpp140z_cln28ht_base_ulvt_c35_ffg_cbestt_min_0p77v_m40c.lib"
    set tech_files(ALL_BC_LIBS) $tech_files(STANDARD_CELLS_LVT_BC_LIB)
set tech_files(STANDARD_CELLS_LVT_WC_LIB) "$paths(LIB_Paths)/sc9mcpp140z_cln28ht_base_ulvt_c35_ssg_cworstt_max_0p72v_125c.lib"
    set tech_files(ALL_WC_LIBS) $tech_files(STANDARD_CELLS_LVT_WC_LIB)
set tech_files(STANDARD_CELLS_LVT_TC_LIB) "$paths(LIB_Paths)/sc9mcpp140z_cln28ht_base_ulvt_c35_tt_ctypical_max_0p70v_85c.lib"
    set tech_files(ALL_TC_LIBS) $tech_files(STANDARD_CELLS_LVT_TC_LIB)

set tech_files(STANDARD_CELLS_RVT_BC_LIB) "$paths(LIB_Paths)/sc9mcpp140z_cln28ht_base_ulvt_c35_ffg_cbestt_min_0p88v_m40c.lib"
    lappend tech_files(ALL_BC_LIBS) $tech_files(STANDARD_CELLS_RVT_BC_LIB)
set tech_files(STANDARD_CELLS_RVT_WC_LIB) "$paths(LIB_Paths)/sc9mcpp140z_cln28ht_base_ulvt_c35_ssg_cworstt_max_0p81v_125c.lib"
    lappend tech_files(ALL_WC_LIBS) $tech_files(STANDARD_CELLS_RVT_WC_LIB)
set tech_files(STANDARD_CELLS_RVT_TC_LIB) "$paths(LIB_Paths)/sc9mcpp140z_cln28ht_base_ulvt_c35_tt_ctypical_max_0p90v_85c.lib"
    lappend tech_files(ALL_TC_LIBS) $tech_files(STANDARD_CELLS_RVT_TC_LIB)

set tech_files(STANDARD_CELLS_HVT_BC_LIB) "$paths(LIB_Paths)/sc9mcpp140z_cln28ht_base_ulvt_c35_ffg_cbestt_min_1p05v_m40c.lib"
    lappend tech_files(ALL_BC_LIBS) $tech_files(STANDARD_CELLS_HVT_BC_LIB)
set tech_files(STANDARD_CELLS_HVT_WC_LIB) "$paths(LIB_Paths)/sc9mcpp140z_cln28ht_base_ulvt_c35_ssg_cworstt_max_0p90v_125c.lib"
    lappend tech_files(ALL_WC_LIBS) $tech_files(STANDARD_CELLS_HVT_WC_LIB)
set tech_files(STANDARD_CELLS_HVT_TC_LIB) "$paths(LIB_Paths)/sc9mcpp140z_cln28ht_base_ulvt_c35_tt_ctypical_max_1p05v_85c.lib"
    lappend tech_files(ALL_TC_LIBS) $tech_files(STANDARD_CELLS_HVT_TC_LIB)
 
# Set Input and Output Capacitance Values from Std Cells
set tech(SDC_LOAD_PIN)      BUF_X0P5B_A9PP140ZTUL_C35/A
set tech(SDC_DRIVING_CELL)  BUF_X0P5B_A9PP140ZTUL_C35

# Set Tie High and Tie Low cells
set tech(TIE_PREFIX)        TIEOFF_
set tech(TIE_HIGH_CELL)     TIEHI_X1M_A9PP140ZTUL_C35
set tech(TIE_LOW_CELL)      TIELO_X1M_A9PP140ZTUL_C35

# Set End Cap Cells, Fill Tie Cells
set tech(END_CAP_PREFIX)    ENDCAP_
set tech(END_CAP_CELL)      ENDCAPTIE3_A9PP140ZTUL_C35 
set tech(FILL_TIE_PREFIX)   FILLTIE 
set tech(FILL_TIE_CELL)     FILLTIE5_A9PP140ZTUL_C35

# Set Fill Cells
set tech(FILL_CELL_PREFIX) FILLER_CELL_
set tech(FILL_CELLS)       "FILLSGCAP2_A9PP140ZTUL_C35 FILLSGCAP3_A9PP140ZTUL_C35 FILLSGCAP4_A9PP140ZTUL_C35 FILLSGCAP8_A9PP140ZTUL_C35 FILLSGCAP16_A9PP140ZTUL_C35 FILLSGCAP32_A9PP140ZTUL_C35 FILLSGCAP64_A9PP140ZTUL_C35 FILLSGCAP128_A9PP140ZTUL_C35"

# Set Antenna Cell
set tech(ANTENNA_CELL)      ANTENNA2_A9PP140ZTUL_C35

# Set Clock Tree Specs 
set tech(CCOPT_DRIVING_PIN) {BUF_X0P5B_A9PP140ZTUL_C35/A BUF_X0P5B_A9PP140ZTUL_C35/Y}
# set tech(CLOCK_BUFFERS)     BUF_X0P5B_A9PP140ZTUL_C35
# set tech(CLOKC_GATES)       
# set tech(CLOCK_INVERTERS)   
# set tech(CLOCK_LOGIC)       MXGL2
# set tech(CLOCK_DELAYS)      DLYCLK8

# Set Slew Rates from Documentation
set tech(CLOCK_SLEW)        0.00108
set tech(DATA_SLEW)         0.00108
set tech(INPUT_SLEW)        0.00108

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