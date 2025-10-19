# Import Parameters
source config_hw.tcl

set EDGE_BITS [expr $X_BITS * ($KH_MAX/2) ]
set SRAM_EDGES_EST_DEPTH   4096 
set SRAM_EDGE_MUX   8
set SRAM_EDGES_BANKS  2 
set SRAM_EDGES_SLICES 2

set WEIGHT_BITS [expr $COLS * $K_BITS ]
set SRAM_WEIGHTS_EST_DEPTH $RAM_WEIGHTS_DEPTH
set SRAM_WEIGHT_MUX 2
set SRAM_WEIGHTS_BANKS  2
set SRAM_WEIGHTS_SLICES 2

set CORNERS "ssgnp_cworstccworstt_0p90v_0p90v_125c,ffgnp_cbestccbestt_1p05v_1p05v_m40c,tt_typical_1p00v_1p00v_85c"

# Generate Folders
exec mkdir -p ../asic/srams
exec mkdir -p ../asic/srams/sram_weights
exec mkdir -p ../asic/srams/sram_edges

#Genrating SRAM EDGES
cd ../asic/srams/sram_edges
exec rf_sp_hde_svt_mvt all -atf off -activity_factor 50 -back_biasing off -bits $EDGE_BITS -flexible_banking $SRAM_EDGES_BANKS -flexible_slices $SRAM_EDGES_SLICES -bmux off -bus_notation on -check_instname on -corners $CORNERS -cust_comment "" -diodes on -drive 6 -ema on -frequency $FREQ -instname sram_edges -left_bus_delim {[} -libertyviewstyle nldm -libname SRAM_EDGES -mux $SRAM_EDGE_MUX -name_case upper -power_type otc -prefix "" -pwr_gnd_rename vddpe:VDD,vddce:VDD,vsse:VSS -retention on -right_bus_delim {]} -ser none -site_def off -top_layer m5-m10 -words $SRAM_EDGES_EST_DEPTH -write_mask off -write_thru off -power_gating off -redundancy off -lren_bankmask off -pipeliene off -scan off -vmin_assist off
exec rf_sp_hde_svt_mvt liberty -atf off -activity_factor 50 -back_biasing off -bits $EDGE_BITS -flexible_banking $SRAM_EDGES_BANKS -flexible_slices $SRAM_EDGES_SLICES -bmux off -bus_notation on -check_instname on -corners $CORNERS -cust_comment "" -diodes on -drive 6 -ema on -frequency $FREQ -instname sram_edges -left_bus_delim {[} -libertyviewstyle nldm -libname SRAM_EDGES -mux $SRAM_EDGE_MUX -name_case upper -power_type otc -prefix "" -pwr_gnd_rename vddpe:VDD,vddce:VDD,vsse:VSS -retention on -right_bus_delim {]} -ser none -site_def off -top_layer m5-m10 -words $SRAM_EDGES_EST_DEPTH -write_mask off -write_thru off -power_gating off -redundancy off -lren_bankmask off -pipeliene off -scan off -vmin_assist off
cd ../../../work

#Genrating SRAM WEIGHTS
cd ../asic/srams/sram_weights
exec rf_sp_hde_svt_mvt all -atf off -activity_factor 50 -back_biasing off -bits $WEIGHT_BITS -flexible_banking $SRAM_WEIGHTS_BANKS -flexible_slices $SRAM_WEIGHTS_SLICES -bmux off -bus_notation on -check_instname on -corners $CORNERS -cust_comment "" -diodes on -drive 6 -ema on -frequency $FREQ -instname sram_weights -left_bus_delim {[} -libertyviewstyle nldm -libname SRAM_WEIGHTS -mux $SRAM_WEIGHT_MUX -name_case upper -power_type otc -prefix "" -pwr_gnd_rename vddpe:VDD,vddce:VDD,vsse:VSS -retention on -right_bus_delim {]} -ser none -site_def off -top_layer m5-m10 -words $SRAM_WEIGHTS_EST_DEPTH -write_mask off -write_thru off -power_gating off -redundancy off -lren_bankmask off -pipeliene off -scan off -vmin_assist off
exec rf_sp_hde_svt_mvt liberty -atf off -activity_factor 50 -back_biasing off -bits $WEIGHT_BITS -flexible_banking $SRAM_WEIGHTS_BANKS -flexible_slices $SRAM_WEIGHTS_SLICES -bmux off -bus_notation on -check_instname on -corners $CORNERS -cust_comment "" -diodes on -drive 6 -ema on -frequency $FREQ -instname sram_weights -left_bus_delim {[} -libertyviewstyle nldm -libname SRAM_WEIGHTS -mux $SRAM_WEIGHT_MUX -name_case upper -power_type otc -prefix "" -pwr_gnd_rename vddpe:VDD,vddce:VDD,vsse:VSS -retention on -right_bus_delim {]} -ser none -site_def off -top_layer m5-m10 -words $SRAM_WEIGHTS_EST_DEPTH -write_mask off -write_thru off -power_gating off -redundancy off -lren_bankmask off -pipeliene off -scan off -vmin_assist off
cd ../../../work

#--------- Set PATH parameters
set SRAM_PATH ../asic/srams

#--------- SRAM EDGES
read_lib $SRAM_PATH/sram_edges/sram_edges_ssgnp_cworstccworstt_0p90v_0p90v_125c.lib
write_lib SRAM_EDGES_ssgnp_cworstccworstt_0p90v_0p90v_125c -output $SRAM_PATH/sram_edges/sram_edges_ssgnp_cworstccworstt_0p90v_0p90v_125c.db

read_lib $SRAM_PATH/sram_edges/sram_edges_ffgnp_cbestccbestt_1p05v_1p05v_m40c.lib
write_lib SRAM_EDGES_ffgnp_cbestccbestt_1p05v_1p05v_m40c -output $SRAM_PATH/sram_edges/sram_edges_ffgnp_cbestccbestt_1p05v_1p05v_m40c.db

read_lib $SRAM_PATH/sram_edges/sram_edges_tt_typical_1p00v_1p00v_85c.lib
write_lib SRAM_EDGES_tt_typical_1p00v_1p00v_85c -output $SRAM_PATH/sram_edges/sram_edges_tt_typical_1p00v_1p00v_85c.db

#--------- SRAM WEIGHTS
read_lib $SRAM_PATH/sram_weights/sram_weights_ssgnp_cworstccworstt_0p90v_0p90v_125c.lib
write_lib SRAM_WEIGHTS_ssgnp_cworstccworstt_0p90v_0p90v_125c -output $SRAM_PATH/sram_weights/sram_weights_ssgnp_cworstccworstt_0p90v_0p90v_125c.db

read_lib $SRAM_PATH/sram_weights/sram_weights_ffgnp_cbestccbestt_1p05v_1p05v_m40c.lib
write_lib SRAM_WEIGHTS_ffgnp_cbestccbestt_1p05v_1p05v_m40c -output $SRAM_PATH/sram_weights/sram_weights_ffgnp_cbestccbestt_1p05v_1p05v_m40c.db

read_lib $SRAM_PATH/sram_weights/sram_weights_tt_typical_1p00v_1p00v_85c.lib
write_lib SRAM_WEIGHTS_tt_typical_1p00v_1p00v_85c -output $SRAM_PATH/sram_weights/sram_weights_tt_typical_1p00v_1p00v_85c.db