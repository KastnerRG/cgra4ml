set TOP dnn_engine
set FREQ_MHZ 1000
set clock_cycle [expr 1000/$FREQ_MHZ]
set io_delay [expr $clock_cycle/5]

#--------- CONFIG
set REPORT_DIR ../reports/
set_db hdl_max_loop_limit 10000000
set_db max_cpus_per_server 20

#--------- LIBRARIES
set_db library "../pdk/tsmc65gp/lib/scadv10_cln65gp_lvt_ff_1p1v_m40c.lib"
set_db lef_library { ../pdk/tsmc65gp/lef/tsmc_cln65_a10_4X2Z_tech.lef ../pdk/tsmc65gp/lef/tsmc65_lvt_sc_adv10_macro.lef}
set_db qrc_tech_file ../pdk/tsmc65gp/qrc/icecaps.tch

#--------- READ
read_hdl -language sv ../../rtl/include/params_input.svh
read_hdl -language sv ../../rtl/include/params.svh
read_hdl -language v2001 [glob ../../rtl/ext/*.v]
read_hdl -language sv [glob ../../rtl/ext/*.sv]
read_hdl -language sv [glob ../../rtl/*.sv]
read_hdl -language v2001 [glob ../../rtl/*.v]

#--------- ELABORATE & CHECK
set_db lp_insert_clock_gating false
elaborate $TOP
check_design > ${REPORT_DIR}/check_design.rpt
uniquify $TOP

#--------- CONSTRAINTS
read_sdc ../constraints/$TOP.sdc

#--------- RETIME OPTIONS
set_db retime_async_reset true
set_db design:${TOP} .retime true

#--------- SYNTHESIZE
set_db syn_global_effort high
syn_generic
syn_map
syn_opt

#--------- NETLIST
write -mapped > ../outputs/${TOP}.out.v
write_sdc > ../outputs/${TOP}.out.sdc

#--------- REPORTS
report_area > ${REPORT_DIR}/area.rpt
report_gates > ${REPORT_DIR}/gates.rpt
report_timing  -nworst 10 > ${REPORT_DIR}/timing.rpt
report_congestion > ${REPORT_DIR}/congestion.rpt
report_messages > ${REPORT_DIR}/messages.rpt
report_hierarchy > ${REPORT_DIR}/hierarchy.rpt
report_clock_gating > ${REPORT_DIR}/clock_gating.rpt

build_rtl_power_models -clean_up_netlist
report_power > ${REPORT_DIR}/power.rpt
