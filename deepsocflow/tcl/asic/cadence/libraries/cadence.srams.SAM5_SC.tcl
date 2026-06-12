##############################################################################
# Script  : cadence.srams.SAM5_SC.tcl
# Purpose : Define SRAM liberty lib paths and per-corner file lists for
#           weight, edge, and DMA SRAMs — Samsung LN05LPE process
##############################################################################
#
# Sourced by Genus (synthesis), Innovus (P&R), and Tempus (STA) flows.
# Must be sourced after cadence.librariesSAM5_TECH.tcl.
# Expects the following variables to be set before sourcing:
#   paths(PDK_AIM)       — resolved PDK directory (set by TECH script)
#   design(TOPLEVEL)     — top-level design name, used to locate SRAMs_<TOPLEVEL>
#
# Defines:
#   paths(SRAM_FILES)              — root SRAM directory for this design
#   paths(SRAM_LIB_WEIGHTS_Paths)  — sram_weight lib directory
#   paths(SRAM_LIB_EDGES_Paths)    — sram_edge lib directory
#   paths(SRAM_LIB_DMA_Paths)      — sram_dma lib directory
#   tech_files(SRAM_*)             — per-corner NLDM / CCS / AOCV lib files
#   tech_files(ALL_BC/WC/TC_LIBS)      — aggregated NLDM corner lib lists
#   tech_files(ALL_BC/WC/TC_CCS_LIBS)  — aggregated CCS  corner lib lists
#   tech_files(ALL_BC/WC/TC_AOCV_LIBS) — aggregated AOCV corner lib lists
#
# Corner vs Voltage Table:
# +--------+----------------+------------------+---------------------+----------------------+
# | Corner | Condition      | Temp             | periphery_voltage   | bitcell_array_voltage|
# +--------+----------------+------------------+---------------------+----------------------+
# | BC     | ffpg_sigcmin   | m40c             | 0.900V              | 0.900V               |
# | WC     | sspg_sigrcmax  | m40c             | 0.675V              | 0.675V               |
# | TC     | tt_nominal     |  85c             | 0.750V              | 0.750V               |
# +--------+----------------+------------------+---------------------+----------------------+
#
# SRAM Definitions (sram_defs):
#   Each entry is {sram_type  key_prefix  path_var}
#     sram_type  — prefix used in the lib filename  (e.g. sram_weight → sram_weight_ffpg_...lib)
#     key_prefix — prefix used in tech_files keys   (e.g. SRAM_WEIGHTS → tech_files(SRAM_WEIGHTS_BC_...))
#     path_var   — paths() variable holding the lib directory for this SRAM
#   To add a new SRAM instance, add a row to sram_defs and a matching paths() entry:
#     set paths(SRAM_LIB_NEWNAME_Paths)  "$paths(SRAM_FILES)/sram_newname"
#     {sram_newname  SRAM_NEWNAME  SRAM_LIB_NEWNAME_Paths}
#
# TODO:
#   Major Revisions
#   [X] Add CCS/AOCV support
##############################################################################

# Set Paths for Timing Libs
set paths(SRAM_FILES)                "$paths(PDK_AIM)/SRAMs_${design(TOPLEVEL)}"
set paths(SRAM_LIB_WEIGHTS_Paths)    "$paths(SRAM_FILES)/sram_weight"
set paths(SRAM_LIB_EDGES_Paths)      "$paths(SRAM_FILES)/sram_edge"
set paths(SRAM_LIB_DMA_Paths)        "$paths(SRAM_FILES)/sram_dma"

# {sram_type  key_prefix  path_var}
set sram_defs {
    {sram_weight  SRAM_WEIGHTS  SRAM_LIB_WEIGHTS_Paths}
    {sram_edge    SRAM_EDGES    SRAM_LIB_EDGES_Paths}
    {sram_dma     SRAM_DMA      SRAM_LIB_DMA_Paths}
}

# {corner  condition  {periphery_voltages...}  {bitcell_array_voltages...}  {temps...}}
# volt1 and volt2 are iterated as pairs — add matching entries to extend both voltage lists.
set sram_corner_defs {
    {BC  ffpg_sigcmin   {0p90v}   {0p90v}   {m40c}}
    {WC  sspg_sigrcmax  {0p675v}  {0p675v}  {m40c}}
    {TC  tt_nominal     {0p75v}   {0p75v}   {85c}}
}

# NLDM Liberty Files
foreach sram_entry $sram_defs {
    lassign $sram_entry sram_name key_prefix path_var
    foreach corner_entry $sram_corner_defs {
        lassign $corner_entry corner cond volt1s volt2s temps
        foreach volt1 $volt1s volt2 $volt2s {
            foreach temp $temps {
                set key "${key_prefix}_${corner}_${volt1}_${volt2}_${temp}_LIB"
                set tech_files($key) \
                    "$paths($path_var)/${sram_name}_${cond}_${volt1}_${volt2}_${temp}.lib"
                lappend tech_files(ALL_${corner}_LIBS) $tech_files($key)
            }
        }
    }
}

# CCS Liberty Files
foreach sram_entry $sram_defs {
    lassign $sram_entry sram_name key_prefix path_var
    foreach corner_entry $sram_corner_defs {
        lassign $corner_entry corner cond volt1s volt2s temps
        foreach volt1 $volt1s volt2 $volt2s {
            foreach temp $temps {
                set key "${key_prefix}_${corner}_${volt1}_${volt2}_${temp}_CCS_LIB"
                set tech_files($key) \
                    "$paths($path_var)/${sram_name}_${cond}_${volt1}_${volt2}_${temp}.lib_ccs_tn"
                lappend tech_files(ALL_${corner}_CCS_LIBS) $tech_files($key)
            }
        }
    }
}

# AOCV Liberty Files
foreach sram_entry $sram_defs {
    lassign $sram_entry sram_name key_prefix path_var
    foreach corner_entry $sram_corner_defs {
        lassign $corner_entry corner cond volt1s volt2s temps
        foreach volt1 $volt1s volt2 $volt2s {
            foreach temp $temps {
                set key "${key_prefix}_${corner}_${volt1}_${volt2}_${temp}_AOCV_LIB"
                set tech_files($key) \
                    "$paths($path_var)/${sram_name}_${cond}_${volt1}_${volt2}_${temp}.aocv3"
                lappend tech_files(ALL_${corner}_AOCV_LIBS) $tech_files($key)
            }
        }
    }
}
