# Route Technology settings for the TSMC 28 HPCPLUS Technology
set TECHNOLOGY_NODE TSMC28HPCPLUS
set METAL_STACK  1p8m_5x2z_utalrdl
set METAL_LAYERS 9
set TECH_NODE    28

# Technology
set HOME "../../.."
set paths(PDK_ROOT)                  "$HOME/PDK/$TECHNOLOGY_NODE"
set paths(TECHNOLOGY_FILES)          "$paths(PDK_ROOT)/TECH_Libs"
set paths(STANDARD_CELLS_TECH_FILES) "$paths(PDK_ROOT)/STD_Libs/lef"
set paths(SRAM_TECH_FILES)           "$paths(PDK_ROOT)/SRAM_INST"

# LEFS
lappend tech(LEF_SUPPRESS_MESSAGES_GENUS) {*}"PHYS-279"
lappend tech(LEF_SUPPRESS_MESSAGES_INNOVUS) {*}"IMPLF_20"

set tech_files(TECHNOLOGY_LEF) "$paths(TECHNOLOGY_FILES)/tech_lef/$METAL_STACK/sc9mcpp140z_tech.lef"
    set tech_files(ALL_LEFS) [list $tech_files(TECHNOLOGY_LEF)]
set tech_files(STANDARD_CELLS_LEF) "$paths(STANDARD_CELLS_TECH_FILES)/sc9mcpp140z_cln28ht_base_ulvt_c35.lef"
    lappend tech_files(ALL_LEFS) $tech_files(STANDARD_CELLS_LEF)

# Temperatures for Corners
set tech(TEMPERATURE_BC) -40
set tech(TEMPERATURE_TC) 85
set tech(TEMPERATURE_WC) 125

# Parasitic Extraction
set tech_files(CAPTABLE_BC) "$paths(TECHNOLOGY_FILES)/captbl/$METAL_STACK/rcbest.captbl"
set tech_files(CAPTABLE_TC) "$paths(TECHNOLOGY_FILES)/captbl/$METAL_STACK/typical.captbl"
set tech_files(CAPTABLE_WC) "$paths(TECHNOLOGY_FILES)/captbl/$METAL_STACK/rcworst.captbl"
