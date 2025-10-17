# Import Parameters
source config_hw.tcl
set EDGE_BITS [expr $X_BITS * ($KH_MAX/2) ]
set WEIGHT_BITS [expr $COLS * $K_BITS ]

# Important to add mux
set SRAM_EDGE_MUX   4
set SRAM_WEIGHT_MUX 2


set SRAM_EDGES_EST_DEPTH   4096 
set SRAM_WEIGHTS_EST_DEPTH $RAM_WEIGHTS_DEPTH

# Generate Folders
exec mkdir -p ../../../PDK/TSMC28HPCPLUS/SRAM_Inst
exec mkdir -p ../../../PDK/TSMC28HPCPLUS/SRAM_Inst/sram_edges
exec mkdir -p ../../../PDK/TSMC28HPCPLUS/SRAM_Inst/sram_weights

#Genrating SRAM EDGES
cd ../../../PDK/TSMC28HPCPLUS/SRAM_Inst/sram_edges
exec rf_sp_hde_hvt_mvt all -activity_factor 20 -back_biasing off -bits $EDGE_BITS -bmux off -bus_notation on -check_instname on -corners ff_1p32v_1p32v_125c,ff_1p32v_1p32v_m40c,ss_1p08v_1p08v_125c,ss_1p08v_1p08v_m40c,tt_1p20v_1p20v_25c -cust_comment "" -diodes on -drive 6 -ema on -frequency $FREQ -instname sram_edges -left_bus_delim {[} -libertyviewstyle nldm -libname SRAM_EDGES -mux $SRAM_EDGE_MUX -mvt "" -name_case upper -power_type otc -prefix "" -pwr_gnd_rename vddpe:VDD,vddce:VDD,vsse:VSS -retention on -right_bus_delim {]} -ser none -site_def off -top_layer m5-m10 -words $RAM_EDGES_EST_DEPTH -writemask off -write_thru off -power_gating off -redundancy off
exec rf_sp_hde_hvt_mvt liberty -activity_factor 20 -back_biasing off -bits $EDGE_BITS -bmux off -bus_notation on -check_instname on -corners ff_1p32v_1p32v_125c,ff_1p32v_1p32v_m40c,ss_1p08v_1p08v_125c,ss_1p08v_1p08v_m40c,tt_1p20v_1p20v_25c -cust_comment "" -diodes on -drive 6 -ema on -frequency $FREQ -instname sram_edges -left_bus_delim {[} -libertyviewstyle nldm -libname SRAM_EDGES -mux $SRAM_EDGE_MUX -mvt "" -name_case upper -power_type otc -prefix "" -pwr_gnd_rename vddpe:VDD,vddce:VDD,vsse:VSS -retention on -right_bus_delim {]} -ser none -site_def off -top_layer m5-m10 -words $RAM_EDGES_EST_DEPTH -writemask off -write_thru off -power_gating off -redundancy off
cd ../../../../cgra4ml/run/work

#Genrating SRAM WEIGHTS
cd ../../../PDK/TSMC28HPCPLUS/SRAM_Inst/sram_weights
exec rf_sp_hde_hvt_mvt all -activity_factor 20 -back_biasing off -bits $WEIGHT_BITS -bmux off -bus_notation on -check_instname on -corners ff_1p32v_1p32v_125c,ff_1p32v_1p32v_m40c,ss_1p08v_1p08v_125c,ss_1p08v_1p08v_m40c,tt_1p20v_1p20v_25c -cust_comment "" -diodes on -drive 6 -ema on -frequency $FREQ -instname sram_weights -left_bus_delim {[} -libertyviewstyle nldm -libname SRAM_WEIGHTS -mux $SRAM_WEIGHT_MUX -mvt "" -name_case upper -power_type otc -prefix "" -pwr_gnd_rename vddpe:VDD,vddce:VDD,vsse:VSS -retention on -right_bus_delim {]} -ser none -site_def off -top_layer m5-m10 -words $RAM_WEIGHTS_EST_DEPTH -writemask off -write_thru off -power_gating off -redundancy off
exec rf_sp_hde_hvt_mvt liberty -activity_factor 20 -back_biasing off -bits $WEIGHT_BITS -bmux off -bus_notation on -check_instname on -corners ff_1p32v_1p32v_125c,ff_1p32v_1p32v_m40c,ss_1p08v_1p08v_125c,ss_1p08v_1p08v_m40c,tt_1p20v_1p20v_25c -cust_comment "" -diodes on -drive 6 -ema on -frequency $FREQ -instname sram_weights -left_bus_delim {[} -libertyviewstyle nldm -libname SRAM_WEIGHTS -mux $SRAM_WEIGHT_MUX -mvt "" -name_case upper -power_type otc -prefix "" -pwr_gnd_rename vddpe:VDD,vddce:VDD,vsse:VSS -retention on -right_bus_delim {]} -ser none -site_def off -top_layer m5-m10 -words $RAM_WEIGHTS_EST_DEPTH -writemask off -write_thru off -power_gating off -redundancy off
cd ../../../../cgra4ml/run/work