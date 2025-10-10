# Import Parameters
source config_hw.tcl
set EDGE_BITS [expr $X_BITS * ($KH_MAX/2) ]
set WEIGHT_BITS [expr $COLS * $K_BITS ]
# Important to add mux

# Generate Folders
exec mkdir -p ../asic/srams
exec mkdir -p ../asic/srams/sram_weights
exec mkdir -p ../asic/srams/sram_edges

#Genrating SRAM EDGES
cd ../asic/srams/sram_edges
exec rf_sp_hdf_hvt_rvt all -activity_factor 20 -back_biasing off -bits $EDGE_BITS -bmux off -bus_notation on -check_instname on -corners ff_1p32v_1p32v_125c,ff_1p32v_1p32v_m40c,ss_1p08v_1p08v_125c,ss_1p08v_1p08v_m40c,tt_1p20v_1p20v_25c -cust_comment "" -diodes on -drive 6 -ema on -frequency $FREQ -instname sram_edges -left_bus_delim {[} -libertyviewstyle nldm -libname SRAM_EDGES -mux 8 -mvt "" -name_case upper -power_type otc -prefix "" -pwr_gnd_rename vddpe:VDD,vddce:VDD,vsse:VSS -retention on -right_bus_delim {]} -ser none -site_def off -top_layer m5-m10 -words $RAM_EDGES_DEPTH -wp_size 1 -write_mask off -write_thru off
exec rf_sp_hdf_hvt_rvt liberty -activity_factor 20 -back_biasing off -bits $EDGE_BITS -bmux off -bus_notation on -check_instname on -corners ff_1p32v_1p32v_125c,ff_1p32v_1p32v_m40c,ss_1p08v_1p08v_125c,ss_1p08v_1p08v_m40c,tt_1p20v_1p20v_25c -cust_comment "" -diodes on -drive 6 -ema on -frequency $FREQ -instname sram_edges -left_bus_delim {[} -libertyviewstyle nldm -libname SRAM_EDGES -mux 8 -mvt "" -name_case upper -power_type otc -prefix "" -pwr_gnd_rename vddpe:VDD,vddce:VDD,vsse:VSS -retention on -right_bus_delim {]} -ser none -site_def off -top_layer m5-m10 -words $RAM_EDGES_DEPTH -wp_size 1 -write_mask off -write_thru off
cd ../../../work

#Genrating SRAM WEIGHTS
cd ../asic/srams/sram_weights
exec rf_sp_hdf_hvt_rvt all -activity_factor 20 -back_biasing off -bits $WEIGHT_BITS -bmux off -bus_notation on -check_instname on -corners ff_1p32v_1p32v_125c,ff_1p32v_1p32v_m40c,ss_1p08v_1p08v_125c,ss_1p08v_1p08v_m40c,tt_1p20v_1p20v_25c -cust_comment "" -diodes on -drive 6 -ema on -frequency $FREQ -instname sram_weights -left_bus_delim {[} -libertyviewstyle nldm -libname SRAM_WEIGHTS -mux 2 -mvt "" -name_case upper -power_type otc -prefix "" -pwr_gnd_rename vddpe:VDD,vddce:VDD,vsse:VSS -retention on -right_bus_delim {]} -ser none -site_def off -top_layer m5-m10 -words $RAM_WEIGHTS_DEPTH -wp_size 1 -write_mask off -write_thru off
exec rf_sp_hdf_hvt_rvt liberty -activity_factor 20 -back_biasing off -bits $WEIGHT_BITS -bmux off -bus_notation on -check_instname on -corners ff_1p32v_1p32v_125c,ff_1p32v_1p32v_m40c,ss_1p08v_1p08v_125c,ss_1p08v_1p08v_m40c,tt_1p20v_1p20v_25c -cust_comment "" -diodes on -drive 6 -ema on -frequency $FREQ -instname sram_weights -left_bus_delim {[} -libertyviewstyle nldm -libname SRAM_WEIGHTS -mux 2 -mvt "" -name_case upper -power_type otc -prefix "" -pwr_gnd_rename vddpe:VDD,vddce:VDD,vsse:VSS -retention on -right_bus_delim {]} -ser none -site_def off -top_layer m5-m10 -words $RAM_WEIGHTS_DEPTH -wp_size 1 -write_mask off -write_thru off
cd ../../../work