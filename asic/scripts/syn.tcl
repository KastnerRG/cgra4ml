set TOP axis_accelerator_asic
# set TOP axis_conv_engine

#--------- CONFIG
set RTL_DIR ../../rtl
set XILINX 0
source ../../tcl/config.tcl
set LIB_DIR ../../../tsmc/40nm

set NUM_MACS [expr $MEMBERS*$UNITS*$GROUPS*$COPIES]
set REPORT_DIR ../report/${TOP}/${NUM_MACS}
exec mkdir -p $REPORT_DIR

#--------- LIBRARIES
set_db init_lib_search_path [list $LIB_DIR/lef $LIB_DIR/lib $LIB_DIR/cap]
set_db library [glob $LIB_DIR/lib/tcbn45gsbwpbc0d88*.lib]
set_db lef_library [glob $LIB_DIR/lef/*.lef]

#--------- READ
read_hdl -mixvlog [glob $RTL_DIR/include/*]
read_hdl -mixvlog [glob $RTL_DIR/external/*]
read_hdl -mixvlog [glob $RTL_DIR/src/*]

#--------- ELABORATE & CHECK
elaborate $TOP
check_design > ${REPORT_DIR}/check_design.log
uniquify $TOP

#--------- CONSTRAINTS
create_clock -name aclk -period 5 [get_ports aclk]
set_dont_touch_network [all_clocks]
set_dont_touch_network [get_ports {aresetn}]

#--------- SYNTHESIZE
# set_db module:${TOP} .retime true
set_db syn_global_effort medium
syn_generic
# syn_map
# syn_opt

#--------- NETLIST
write -mapped > ../output/${TOP}.v
write_sdc > ../output/${TOP}.sdc

#--------- REPORTS
report_area > ${REPORT_DIR}/area.log
report_gates > ${REPORT_DIR}/gates.log
report_timing  -nworst 10 > ${REPORT_DIR}/timing.log
report_power > ${REPORT_DIR}/power.log