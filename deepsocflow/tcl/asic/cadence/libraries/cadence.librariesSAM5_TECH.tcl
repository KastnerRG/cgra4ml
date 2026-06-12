##############################################################################
# Script  : cadence.librariesSAM5_TECH.tcl
# Purpose : Define technology node settings, LEF paths, corner temperatures /
#           voltages, and QRC extraction files for Samsung LN05LPE process
##############################################################################
#
# Sourced by Genus (synthesis), Innovus (P&R), and Tempus (STA) flows.
# Expects the following variables to be set before sourcing:
#   paths(PDK_ROOT)  — root directory containing all PDK technology nodes
#
# Defines:
#   TECHNOLOGY_NODE              — PDK technology node identifier
#   METAL_STACK                  — metal stack configuration string
#   paths(PDK_AIM)               — resolved PDK directory for this technology
#   paths(TECHNOLOGY_FILES)      — TECH lib directory
#   paths(STANDARD_CELLS_TECH_FILES) — standard cell LEF directory
#   tech_files(TECHNOLOGY_LEF)   — technology LEF file
#   tech_files(STANDARD_CELLS_LEF) — standard cell LEF file
#   tech_files(ALL_LEFS)         — aggregated LEF file list
#   tech(TEMPERATURE_BC/TC/WC)   — corner temperatures (°C)
#   tech(VOLTAGE_BC/TC/WC)       — corner voltages (V)
#   tech_files(QRC_NOMINAL)      — QRC parasitic extraction tech file
#
# TODO:
#   Major Revisions
#   [ ] Add Genus Suppress Messages
#   [ ] Add Innovus Suppress Messages
#   [ ] Add Tempus Suppress Messages
##############################################################################

# Route Technology settings for the Samsung 5nm Technology
set TECHNOLOGY_NODE SAMSUNGLN05LPE
set METAL_STACK     14M_4Mx_8Dx_2Iz_LB
set METAL_LAYERS    14
set PROCESS_NODE    5
set TECH_NODE       S5

# Technology
set paths(PDK_AIM)                   "$paths(PDK_ROOT)/$TECHNOLOGY_NODE"
set paths(TECHNOLOGY_FILES)          "$paths(PDK_AIM)/TECH_Libs"
set paths(STANDARD_CELLS_TECH_FILES) "$paths(PDK_AIM)/STD_Libs/lef"

# Supress lef unwanted messages
# lappend tech(LEF_SUPPRESS_MESSAGES_GENUS)   {*} "PHYS-279"
# lappend tech(LEF_SUPPRESS_MESSAGES_INNOVUS) {*} "IMPLF_20"

set tech_files(TECHNOLOGY_LEF) "$paths(TECHNOLOGY_FILES)/lef/$METAL_STACK/sc7p5mcpp60_tech.lef"
    set tech_files(ALL_LEFS) [list $tech_files(TECHNOLOGY_LEF)]
set tech_files(STANDARD_CELLS_LEF) "$paths(STANDARD_CELLS_TECH_FILES)/sc7p5mcpp60_ln05lpe_base_lvt_c10.lef"
    lappend tech_files(ALL_LEFS) $tech_files(STANDARD_CELLS_LEF)

# Temperatures for Corners
set tech(TEMPERATURE_BC) -40
set tech(TEMPERATURE_TC) 85
set tech(TEMPERATURE_WC) 125

# Temperatures for Corners
set tech(VOLTAGE_BC) 0.605
set tech(VOLTAGE_TC) 0.750
set tech(VOLTAGE_WC) 0.855

# Parasitic Extraction
set tech_files(QRC_NOMINAL) "$paths(TECHNOLOGY_FILES)/qrc/$METAL_STACK/nominal.qrcTechFile"
