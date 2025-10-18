# Import Parameters
source config_hw.tcl
set EDGE_BITS 12
set WEIGHT_BITS 8
# Important to add mux

# Generate Folders
exec mkdir -p ../asic/srams
exec mkdir -p ../asic/srams/sram_weights
exec mkdir -p ../asic/srams/sram_edges

#Genrating SRAM EDGES
cd ../asic/srams/sram_edges
exec rf_sp_hde_hvt_mvt all -activity_factor 20 -atf off -back_biasing off -bits $EDGE_BITS -bmux off -bus_notation on -check_instname on -corners ffg_cbestt_1p05v_1p05v_125c,ffg_cbestt_1p05v_1p05v_m40c -cust_comment "" -diodes on -drive 6 -ema on -frequency $FREQ -instname sram_edges -left_bus_delim {[} -libertyviewstyle nldm -libname SRAM_EDGES -mux 16 -mvt "LL" -name_case upper -pipeline "off" -power_gating "off" -power_type otc -prefix "" -pwr_gnd_rename vddpe:VDD,vddce:VDD,vsse:VSS -rcols 2 -redundancy "off" -retention on -right_bus_delim {]} -rows_p_bl 256 -rrows 0 -ser none -site_def off -top_layer m5-m10 -wa on -words $RAM_EDGES_DEPTH -wp_size 1 -write_mask off -write_thru off
exec rf_sp_hde_hvt_mvt liberty -activity_factor 20 -atf off -back_biasing off -bits $EDGE_BITS -bmux off -bus_notation on -check_instname on -corners ffg_cbestt_1p05v_1p05v_125c,ffg_cbestt_1p05v_1p05v_m40c -cust_comment "" -diodes on -drive 6 -ema on -frequency $FREQ -instname sram_edges -left_bus_delim {[} -libertyviewstyle nldm -libname SRAM_EDGES -mux 16 -mvt "LL" -name_case upper -pipeline "off" -power_gating "off" -power_type otc -prefix "" -pwr_gnd_rename vddpe:VDD,vddce:VDD,vsse:VSS -rcols 2 -redundancy "off" -retention on -right_bus_delim {]} -rows_p_bl 256 -rrows 0 -ser none -site_def off -top_layer m5-m10 -wa on -words $RAM_EDGES_DEPTH -wp_size 1 -write_mask off -write_thru off
cd ../../../work

#Genrating SRAM WEIGHTS
cd ../asic/srams/sram_weights
exec rf_sp_hde_hvt_mvt all -activity_factor 20 -atf off -back_biasing off -bits $WEIGHT_BITS -bmux off -bus_notation on -check_instname on -corners ffg_cbestt_1p05v_1p05v_125c,ffg_cbestt_1p05v_1p05v_m40c -cust_comment "" -diodes on -drive 6 -ema on -frequency $FREQ -instname sram_weights -left_bus_delim {[} -libertyviewstyle nldm -libname SRAM_WEIGHTS -mux 4 -mvt "LL" -name_case upper -pipeline "off" -power_gating "off" -power_type otc -prefix "" -pwr_gnd_rename vddpe:VDD,vddce:VDD,vsse:VSS -rcols 2 -redundancy "off" -retention on -right_bus_delim {]} -rows_p_bl 256 -rrows 0 -ser none -site_def off -top_layer m5-m10 -wa on -words $RAM_WEIGHTS_DEPTH -wp_size 1 -write_mask off -write_thru off
exec rf_sp_hde_hvt_mvt liberty -activity_factor 20 -atf off -back_biasing off -bits $WEIGHT_BITS -bmux off -bus_notation on -check_instname on -corners ffg_cbestt_1p05v_1p05v_125c,ffg_cbestt_1p05v_1p05v_m40c -cust_comment "" -diodes on -drive 6 -ema on -frequency $FREQ -instname sram_weights -left_bus_delim {[} -libertyviewstyle nldm -libname SRAM_WEIGHTS -mux 4 -mvt "LL" -name_case upper -pipeline "off" -power_gating "off" -power_type otc -prefix "" -pwr_gnd_rename vddpe:VDD,vddce:VDD,vsse:VSS -rcols 2 -redundancy "off" -retention on -right_bus_delim {]} -rows_p_bl 256 -rrows 0 -ser none -site_def off -top_layer m5-m10 -wa on -words $RAM_WEIGHTS_DEPTH -wp_size 1 -write_mask off -write_thru off
cd ../../../work