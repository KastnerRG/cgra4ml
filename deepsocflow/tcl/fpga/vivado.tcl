# CREATE IPs
set IP_NAME "ram_weights"
set WIDTH [expr "$COLS * $K_BITS"]
set DEPTH [expr "$RAM_WEIGHTS_DEPTH "]
create_ip -name blk_mem_gen -vendor xilinx.com -library ip -version 8.4 -module_name $IP_NAME
set_property -dict [list CONFIG.Write_Width_A $WIDTH CONFIG.Write_Depth_A $DEPTH CONFIG.Read_Width_A $WIDTH CONFIG.Operating_Mode_A {NO_CHANGE} CONFIG.Write_Width_B $WIDTH CONFIG.Read_Width_B $WIDTH CONFIG.Register_PortA_Output_of_Memory_Primitives {true}] [get_ips $IP_NAME]
set_property generate_synth_checkpoint 0 [get_files $IP_NAME.xci]

set IP_NAME "ram_edges"
set WIDTH [expr "$X_BITS * ($KH_MAX/2)"]
set DEPTH [expr "$RAM_EDGES_DEPTH"]
create_ip -name blk_mem_gen -vendor xilinx.com -library ip -version 8.4 -module_name $IP_NAME
set_property -dict [list CONFIG.Write_Width_A $WIDTH CONFIG.Write_Depth_A $DEPTH CONFIG.Read_Width_A $WIDTH CONFIG.Operating_Mode_A {NO_CHANGE} CONFIG.Write_Width_B $WIDTH CONFIG.Read_Width_B $WIDTH CONFIG.Register_PortA_Output_of_Memory_Primitives {false}] [get_ips $IP_NAME]
set_property generate_synth_checkpoint 0 [get_files $IP_NAME.xci]

set IP_NAME "ram_output"
set WIDTH [expr "$Y_BITS"]
set DEPTH [expr "$COLS * $ROWS"]
create_ip -name blk_mem_gen -vendor xilinx.com -library ip -version 8.4 -module_name $IP_NAME
set_property -dict [list CONFIG.Write_Width_A $WIDTH CONFIG.Write_Depth_A $DEPTH CONFIG.Read_Width_A $WIDTH CONFIG.Operating_Mode_A {NO_CHANGE} CONFIG.Write_Width_B $WIDTH CONFIG.Read_Width_B $WIDTH CONFIG.Register_PortA_Output_of_Memory_Primitives {false}] [get_ips $IP_NAME]
set_property generate_synth_checkpoint 0 [get_files $IP_NAME.xci]

set IP_NAME "dma_weights"
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_dma:7.1 $IP_NAME
set_property -dict [list CONFIG.c_include_sg {0} CONFIG.c_sg_length_width {26} CONFIG.c_mm2s_burst_size {8} CONFIG.c_sg_include_stscntrl_strm {0} CONFIG.c_include_mm2s_dre {1} CONFIG.c_m_axi_mm2s_data_width $S_WEIGHTS_WIDTH_LF CONFIG.c_m_axis_mm2s_tdata_width $S_WEIGHTS_WIDTH_LF CONFIG.c_include_s2mm {0} CONFIG.c_m_axi_mm2s_data_width $S_WEIGHTS_WIDTH_LF CONFIG.c_mm2s_burst_size {256}] [get_bd_cells $IP_NAME]

set IP_NAME "dma_pixels"
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_dma:7.1 $IP_NAME
set_property -dict [list CONFIG.c_include_sg {0} CONFIG.c_sg_length_width {26} CONFIG.c_m_axi_mm2s_data_width $S_PIXELS_WIDTH_LF CONFIG.c_m_axis_mm2s_tdata_width $S_PIXELS_WIDTH_LF CONFIG.c_include_mm2s_dre {1} CONFIG.c_include_s2mm {0} CONFIG.c_m_axi_mm2s_data_width $S_PIXELS_WIDTH_LF CONFIG.c_mm2s_burst_size {256}] [get_bd_cells $IP_NAME]

set IP_NAME "dma_output"
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_dma:7.1 $IP_NAME
set_property -dict [list CONFIG.c_include_sg {0} CONFIG.c_sg_length_width {26} CONFIG.c_s2mm_burst_size {8} CONFIG.c_sg_include_stscntrl_strm {0} CONFIG.c_include_s2mm_dre {1} CONFIG.c_m_axi_s2mm_data_width $M_OUTPUT_WIDTH_LF CONFIG.c_s_axis_s2mm_tdata_width $M_OUTPUT_WIDTH_LF CONFIG.c_include_s2mm {1} CONFIG.c_include_mm2s {0} CONFIG.c_m_axi_s2mm_data_width $M_OUTPUT_WIDTH_LF CONFIG.c_s2mm_burst_size {256} ] [get_bd_cells $IP_NAME]

# Interrupts
create_bd_cell -type ip -vlnv xilinx.com:ip:xlconcat:2.1 xlconcat_0
set_property -dict [list CONFIG.NUM_PORTS {3}] [get_bd_cells xlconcat_0]
connect_bd_net [get_bd_pins dma_pixels/mm2s_introut] [get_bd_pins xlconcat_0/In0]
connect_bd_net [get_bd_pins dma_weights/mm2s_introut] [get_bd_pins xlconcat_0/In1]
connect_bd_net [get_bd_pins dma_output/s2mm_introut] [get_bd_pins xlconcat_0/In2]
connect_bd_net [get_bd_pins xlconcat_0/dout] [get_bd_pins ${PS_IRQ}]

# AXI Lite
apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config "Clk_master $PS_CLK Clk_slave $PS_CLK Clk_xbar $PS_CLK Master $PS_M_AXI_LITE Slave {/dma_pixels/S_AXI_LITE}  ddr_seg {Auto} intc_ip {New AXI Interconnect} master_apm {0}"  [get_bd_intf_pins dma_pixels/S_AXI_LITE ]
apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config "Clk_master $PS_CLK Clk_slave $PS_CLK Clk_xbar $PS_CLK Master $PS_M_AXI_LITE Slave {/dma_weights/S_AXI_LITE} ddr_seg {Auto} intc_ip {New AXI Interconnect} master_apm {0}"  [get_bd_intf_pins dma_weights/S_AXI_LITE]
apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config "Clk_master $PS_CLK Clk_slave $PS_CLK Clk_xbar $PS_CLK Master $PS_M_AXI_LITE Slave {/dma_output/S_AXI_LITE}  ddr_seg {Auto} intc_ip {New AXI Interconnect} master_apm {0}"  [get_bd_intf_pins dma_output/S_AXI_LITE ]

# AXI Full
connect_bd_intf_net [get_bd_intf_pins dma_output/M_AXI_S2MM ] [get_bd_intf_pins $PS_S_AXI_OUTPUT   ]
connect_bd_intf_net [get_bd_intf_pins dma_pixels/M_AXI_MM2S ] [get_bd_intf_pins $PS_S_AXI_PIXELS   ]
connect_bd_intf_net [get_bd_intf_pins dma_weights/M_AXI_MM2S] [get_bd_intf_pins $PS_S_AXI_WEIGHTS  ]

# Engine
add_files  [glob $CONFIG_DIR/*.svh] [glob $RTL_DIR/*] [glob $RTL_DIR/ext/*]
set_property top dnn_engine [current_fileset]
create_bd_cell -type module -reference dnn_engine dnn_engine_0


connect_bd_net      [get_bd_pins $PS_CLK]                      [get_bd_pins dnn_engine_0/aclk]
connect_bd_intf_net [get_bd_intf_pins dma_pixels/M_AXIS_MM2S]  [get_bd_intf_pins dnn_engine_0/s_axis_pixels]
connect_bd_intf_net [get_bd_intf_pins dma_weights/M_AXIS_MM2S] [get_bd_intf_pins dnn_engine_0/s_axis_weights]
connect_bd_intf_net [get_bd_intf_pins dma_output/S_AXIS_S2MM]  [get_bd_intf_pins dnn_engine_0/m_axis]
connect_bd_net      [get_bd_pins dnn_engine_0/aresetn]         [get_bd_pins rst_ps8_0_${FREQ}M/peripheral_aresetn]

# Clock Automations
apply_bd_automation -rule xilinx.com:bd_rule:clkrst -config " Clk $PS_CLK Freq {100} Ref_Clk0 {} Ref_Clk1 {} Ref_Clk2 {}"  [get_bd_pins dma_output/m_axi_s2mm_aclk ]
apply_bd_automation -rule xilinx.com:bd_rule:clkrst -config " Clk $PS_CLK Freq {100} Ref_Clk0 {} Ref_Clk1 {} Ref_Clk2 {}"  [get_bd_pins dma_pixels/m_axi_mm2s_aclk ]
apply_bd_automation -rule xilinx.com:bd_rule:clkrst -config " Clk $PS_CLK Freq {100} Ref_Clk0 {} Ref_Clk1 {} Ref_Clk2 {}"  [get_bd_pins dma_weights/m_axi_mm2s_aclk]

set_property STEPS.SYNTH_DESIGN.ARGS.FLATTEN_HIERARCHY full [get_runs synth_1]
set_property STEPS.SYNTH_DESIGN.ARGS.RETIMING true [get_runs synth_1]


validate_bd_design

generate_target all [get_files ./${PROJECT_NAME}/${PROJECT_NAME}.srcs/sources_1/bd/design_1/design_1.bd]
make_wrapper -files [get_files ./${PROJECT_NAME}/${PROJECT_NAME}.srcs/sources_1/bd/design_1/design_1.bd] -top
add_files -norecurse ./${PROJECT_NAME}/${PROJECT_NAME}.srcs/sources_1/bd/design_1/hdl/design_1_wrapper.v
set_property top design_1_wrapper [current_fileset]
save_bd_design

# Implementation
reset_run impl_1
reset_run synth_1
launch_runs impl_1 -to_step write_bitstream -jobs 10
wait_on_run -timeout 360 impl_1
write_hw_platform -fixed -include_bit -force -file $PROJECT_NAME/design_1_wrapper.xsa

# Reports
open_run impl_1
if {![file exists $PROJECT_NAME/reports]} {exec mkdir $PROJECT_NAME/reports}
report_timing_summary -delay_type min_max -report_unconstrained -check_timing_verbose -max_paths 100 -input_pins -routable_nets -name timing_1 -file $PROJECT_NAME/reports/${PROJECT_NAME}_${BOARD}_${FREQ}_timing_report.txt
report_utilization -file $PROJECT_NAME/reports/${PROJECT_NAME}_${BOARD}_${FREQ}_utilization_report.txt -name utilization_1
report_power -file $PROJECT_NAME/reports/${PROJECT_NAME}_${BOARD}_${FREQ}_power_1.txt -name {power_1}
report_drc -name drc_1 -file $PROJECT_NAME/reports/${PROJECT_NAME}_${BOARD}_${FREQ}_drc_1.txt -ruledecks {default opt_checks placer_checks router_checks bitstream_checks incr_eco_checks eco_checks abs_checks}

exec mkdir -p $PROJECT_NAME/output
exec cp "$PROJECT_NAME/$PROJECT_NAME.gen/sources_1/bd/design_1/hw_handoff/design_1.hwh" $PROJECT_NAME/output/
exec cp "$PROJECT_NAME/$PROJECT_NAME.runs/impl_1/design_1_wrapper.bit" $PROJECT_NAME/output/design_1.bit
