# Import Parameters
source config_hw.tcl
set EDGE_BITS [expr $X_BITS * ($KH_MAX/2) ]
set WEIGHT_BITS [expr $COLS * $K_BITS ]

set SRAM_EDGE_MUX   4
set SRAM_WEIGHT_MUX 2

set SRAM_EDGES_EST_DEPTH   4096 
set SRAM_WEIGHTS_EST_DEPTH $RAM_WEIGHTS_DEPTH

set CORNERS ffg_cbestt_1p05v_1p05v_m40c,ffg_cbestt_0p88v_0p99v_125c,ffg_cbestt_0p88v_0p99v_m40c,ssg_cworstt_0p81v_0p81v_125c,ffg_cbestt_0p99v_0p99v_125c,tt_ctypical_0p80v_0p90v_85c,ssg_cworstt_0p90v_0p90v_m40c,ssg_cworstt_0p72v_0p81v_125c,tt_ctypical_0p90v_0p90v_85c,ssg_cworstt_0p81v_0p81v_m40c,ssg_cworstt_0p90v_0p90v_125c,ffg_cbestt_1p05v_1p05v_125c,ssg_cworstt_0p72v_0p81v_m40c,tt_ctypical_1p00v_1p00v_85c,ffg_cbestt_0p99v_0p99v_m40c

# Generate Folders
exec mkdir -p ../../../PDK/TSMC28HPCPLUS/SRAM_Inst
exec mkdir -p ../../../PDK/TSMC28HPCPLUS/SRAM_Inst/sram_edges
exec mkdir -p ../../../PDK/TSMC28HPCPLUS/SRAM_Inst/sram_weights

#Genrating SRAM EDGES
cd ../../../PDK/TSMC28HPCPLUS/SRAM_Inst/sram_edges
exec rf_sp_hde_hvt_mvt all -activity_factor 50 -back_biasing off -bits $EDGE_BITS -bmux off -bus_notation on -check_instname on -corners $CORNERS -cust_comment "" -diodes on -drive 6 -ema on -frequency $FREQ -instname sram_edges -left_bus_delim {[} -libertyviewstyle nldm -libname SRAM_EDGES -mux $SRAM_EDGE_MUX -name_case upper -power_type otc -prefix "" -pwr_gnd_rename vddpe:VDD,vddce:VDD,vsse:VSS -retention on -right_bus_delim {]} -ser none -site_def off -top_layer m5-m10 -words $SRAM_EDGES_EST_DEPTH -writemask off -write_thru off -power_gating off -redundancy off
exec rf_sp_hde_hvt_mvt liberty -activity_factor 50 -back_biasing off -bits $EDGE_BITS -bmux off -bus_notation on -check_instname on -corners $CORNERS -cust_comment "" -diodes on -drive 6 -ema on -frequency $FREQ -instname sram_edges -left_bus_delim {[} -libertyviewstyle nldm -libname SRAM_EDGES -mux $SRAM_EDGE_MUX -name_case upper -power_type otc -prefix "" -pwr_gnd_rename vddpe:VDD,vddce:VDD,vsse:VSS -retention on -right_bus_delim {]} -ser none -site_def off -top_layer m5-m10 -words $SRAM_EDGES_EST_DEPTH -writemask off -write_thru off -power_gating off -redundancy off
cd ../../../../cgra4ml/run/work

#Genrating SRAM WEIGHTS
cd ../../../PDK/TSMC28HPCPLUS/SRAM_Inst/sram_weights
exec rf_sp_hde_hvt_mvt all -activity_factor 50 -back_biasing off -bits $WEIGHT_BITS -bmux off -bus_notation on -check_instname on -corners $CORNERS -cust_comment "" -diodes on -drive 6 -ema on -frequency $FREQ -instname sram_weights -left_bus_delim {[} -libertyviewstyle nldm -libname SRAM_WEIGHTS -mux $SRAM_WEIGHT_MUX -name_case upper -power_type otc -prefix "" -pwr_gnd_rename vddpe:VDD,vddce:VDD,vsse:VSS -retention on -right_bus_delim {]} -ser none -site_def off -top_layer m5-m10 -words $SRAM_WEIGHTS_EST_DEPTH -writemask off -write_thru off -power_gating off -redundancy off
exec rf_sp_hde_hvt_mvt liberty -activity_factor 50 -back_biasing off -bits $WEIGHT_BITS -bmux off -bus_notation on -check_instname on -corners $CORNERS -cust_comment "" -diodes on -drive 6 -ema on -frequency $FREQ -instname sram_weights -left_bus_delim {[} -libertyviewstyle nldm -libname SRAM_WEIGHTS -mux $SRAM_WEIGHT_MUX -name_case upper -power_type otc -prefix "" -pwr_gnd_rename vddpe:VDD,vddce:VDD,vsse:VSS -retention on -right_bus_delim {]} -ser none -site_def off -top_layer m5-m10 -words $SRAM_WEIGHTS_EST_DEPTH -writemask off -write_thru off -power_gating off -redundancy off
cd ../../../../cgra4ml/run/work