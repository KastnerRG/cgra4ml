##############################################################################
# Script  : cadence.libraries.SAM5_SC.tcl
# Purpose : Define standard cell library paths and tech settings for
#           Samsung 5nm LPE (LN05LPE) process — LVT / RVT / HVT corners
##############################################################################
#
# Sourced by Genus (synthesis), Innovus (P&R), and Tempus (STA) flows.
# Expects the following variables to be set before sourcing:
#   paths(PDK_AIM)  — root directory of the PDK
#
# Defines:
#   paths(LIB_Paths)   — NLDM liberty lib directory
#   paths(CCS_Paths)   — CCS liberty lib directory
#   paths(AOCV_Paths)  — AOCV lib directory
#   tech(*)            — standard cell technology settings
#   tech_files(*)      — per-corner liberty / CCS / AOCV file lists
#
# Corner vs Voltage Table:
# IMPORTANT!!! The first library for wc corner is important.
# +--------+----------------------+------------------+--------+--------+--------+
# | Corner | Condition            | Temp             |  LVT   |  RVT   |  HVT   |
# +--------+----------------------+------------------+--------+--------+--------+
# | BC     | ffpg_nominal_min     | m40c             | 0.605V | 0.715V | 1.000V |
# | WC     | sspg_nominal_max     | 125c             | 0.495V | 0.675V | 0.855V |
# | TC     | tt_nominal_max       |  85c             | 0.550V | 0.750V | 0.950V |
# +--------+----------------------+------------------+--------+--------+--------+
# if you need to add additional temperatures or voltages you add them 
# in the vt_defs and corner defs variables.
#
# TODO:
#   Major Revisions
#   [X] Add Genus Suppress Messages
#   [ ] Add Innovus Suppress Messages
#   [X] Add CCS/AOCV support
#   [ ] Add Tempus Suppress Messages

##############################################################################

# Set Paths for Timing Libs
set paths(LIB_Paths)    "$paths(PDK_AIM)/STD_Libs/lib"
set paths(CCS_Paths)    "$paths(PDK_AIM)/STD_Libs/lib-ccs-tn"
set paths(AOCV_Paths)   "$paths(PDK_AIM)/STD_Libs/aocv"

# General
set tech(STANDARD_CELL_VDD)   VDD
set tech(STANDARD_CELL_GND)   VSS
set tech(STANDARD_CELL_SITE)  sc9mcpp140z_cln28ht

# Set Input and Output Capacitance Values from Std Cells. Extract from Lib Databook
set tech(SDC_LOAD_PIN)      DFFQ_X3N_A7P5PP60TL_C10/Q
set tech(SDC_DRIVING_CELL)  DFFQ_X3N_A7P5PP60TL_C10

# Supress Libs unwanted messages
lappend tech(LIB_SUPPRESS_MESSAGES_GENUS)   {*}"LBR-9 LBR-22 LBR-38 LBR-40 LBR-41 LBR-76 \
                                                LBR-110 LBR-155 LBR-161 LBR-162 LBR-168 \
                                                LBR-170 LBR-412 LBR-436 LBR-518 LBR-785"
# lappend tech(LIB_SUPPRESS_MESSAGES_INNOVUS) {*}"LBR-9 LBR-76 LBR-40 LBR-436 LBR-170 LBR-415 LBR-162 LBR-155"

# NLDM Liberty Files Setup
set LIB_PREFIX "sc7p5mcpp60_ln05lpe_base_lvt_c10"

# {Vt   {BC voltages...}          {WC voltages...}   {TC voltages...}}
set vt_defs {
    {HVT  {1p00v}   {0p855v}  {0p95v}}
    {RVT  {0p715v}  {0p675v}  {0p75v}}
    {LVT  {0p605v}  {0p495v}  {0p55v}}
}

# {corner  condition_prefix  {temps...}}
set corner_defs {
    {BC  ffpg_nominal_min  {m40c}}
    {WC  sspg_nominal_max  {125c}}
    {TC  tt_nominal_max    {85c}}
}

set first_vt 1
foreach vt_entry $vt_defs {
    set vt       [lindex $vt_entry 0]
    set vt_volts [lindex $vt_entry 1]   ;# BC voltages
    set vt_wvolts [lindex $vt_entry 2]  ;# WC voltages
    set vt_tvolts [lindex $vt_entry 3]  ;# TC voltages
    array set corner_volts [list BC $vt_volts WC $vt_wvolts TC $vt_tvolts]

    foreach corner_entry $corner_defs {
        lassign $corner_entry corner cond temps
        set first_file 1
        foreach volt $corner_volts($corner) {
            foreach temp $temps {
                set key  "STANDARD_CELLS_${vt}_${corner}_${volt}_${temp}_LIB"
                set tech_files($key) \
                    "$paths(LIB_Paths)/${LIB_PREFIX}_${cond}_${volt}_${temp}.lib.gz"
                if {$first_vt && $first_file} {
                    set  tech_files(ALL_${corner}_LIBS) $tech_files($key)
                } else {
                    lappend tech_files(ALL_${corner}_LIBS) $tech_files($key)
                }
                set first_file 0
            }
        }
    }
    set first_vt 0
}

# CCS/LVF Liberty Files Setup
set first_vt 1
foreach vt_entry $vt_defs {
    set vt [lindex $vt_entry 0]
    array set corner_volts [list BC [lindex $vt_entry 1] WC [lindex $vt_entry 2] TC [lindex $vt_entry 3]]
    foreach corner_entry $corner_defs {
        lassign $corner_entry corner cond temps
        set first_file 1
        foreach volt $corner_volts($corner) {
            foreach temp $temps {
                set key "CCS_STD_CELL_${vt}_${corner}_${volt}_${temp}_LIB"
                set tech_files($key) \
                    "$paths(CCS_Paths)/${LIB_PREFIX}_${cond}_${volt}_${temp}.lib_ccs_tn.gz"
                if {$first_vt && $first_file} {
                    set  tech_files(ALL_${corner}_CCS_LIBS) $tech_files($key)
                } else {
                    lappend tech_files(ALL_${corner}_CCS_LIBS) $tech_files($key)
                }
                set first_file 0
            }
        }
    }
    set first_vt 0
}

# AOCV Liberty Files Setup
set first_vt 1
foreach vt_entry $vt_defs {
    set vt [lindex $vt_entry 0]
    array set corner_volts [list BC [lindex $vt_entry 1] WC [lindex $vt_entry 2] TC [lindex $vt_entry 3]]
    foreach corner_entry $corner_defs {
        lassign $corner_entry corner cond temps
        set first_file 1
        foreach volt $corner_volts($corner) {
            foreach temp $temps {
                set key "AOCV_STD_CELL_${vt}_${corner}_${volt}_${temp}_LIB"
                set tech_files($key) \
                    "$paths(AOCV_Paths)/${LIB_PREFIX}_${cond}_${volt}_${temp}_0pct.aocv3"
                if {$first_vt && $first_file} {
                    set  tech_files(ALL_${corner}_AOCV_LIBS) $tech_files($key)
                } else {
                    lappend tech_files(ALL_${corner}_AOCV_LIBS) $tech_files($key)
                }
                set first_file 0
            }
        }
    }
    set first_vt 0
}