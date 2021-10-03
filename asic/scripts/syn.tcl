# set params
set HDL_DIR ../../src_hdl
set LIB_DIR ../../../tsmc/40nm
source ../../tcl/config.tcl

set_db init_lib_search_path [list $LIB_DIR/lef $LIB_DIR/lib $LIB_DIR/cap]
set_db library [glob $LIB_DIR/lib/tcbn45gsbwpbc0d88*.lib]
set_db lef_library [glob $LIB_DIR/lef/*.lef]

set_db hdl_search_path $HDL_DIR

# read_hdl [glob $HDL_DIR/*.v]
# read_hdl -sv [glob $HDL_DIR/*.sv]

read_hdl [list params.v register.v alex_axis_register.v]
read_hdl -sv [list asic_alternatives.sv n_delay.sv pad_filter.sv conv_engine.sv axis_conv_engine.sv ]

set TOP axis_conv_engine
elaborate $TOP

check_design > ../report/check_design.log
uniquify $TOP

# constraints
create_clock -name aclk -period 5 [get_ports aclk]
set_dont_touch_network [all_clocks]
set_dont_touch_network [get_ports {aresetn}]

# synth
# set_db module:${TOP} .retime true
# synthesize -to_mapped -effort m
set_db syn_global_effort high
syn_generic
syn_map
syn_opt

# 7. Write netlist
write -mapped > ../output/${TOP}.v
write_sdc > ../output/${TOP}.sdc

# 8. Reports
report_area > ../report/area.log
report_gates > ../report/gates.log
report_timing  -nworst 10 > ../report/timing.log
report_power > ../report/power.log