set PROJECT_NAME sys_accl
set RTL_DIR ../../rtl
set SCRIPTS_DIR ../scripts
source $SCRIPTS_DIR/vivado_config.tcl

#Board specific
# source $SCRIPTS_DIR/pynq_z2.tcl
# source $SCRIPTS_DIR/zcu102.tcl
source $SCRIPTS_DIR/zcu104.tcl


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
set_property -dict [list CONFIG.c_include_sg {0} CONFIG.c_sg_length_width {26} CONFIG.c_mm2s_burst_size {8} CONFIG.c_sg_include_stscntrl_strm {0} CONFIG.c_include_mm2s_dre {1} CONFIG.c_m_axi_mm2s_data_width $S_WEIGHTS_WIDTH_LF CONFIG.c_m_axis_mm2s_tdata_width $S_WEIGHTS_WIDTH_LF CONFIG.c_include_s2mm {0}] [get_bd_cells $IP_NAME]

set IP_NAME "dma_pixels"
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_dma:7.1 $IP_NAME
set_property -dict [list CONFIG.c_include_sg {0} CONFIG.c_sg_length_width {26} CONFIG.c_m_axi_mm2s_data_width $S_PIXELS_WIDTH_LF CONFIG.c_m_axis_mm2s_tdata_width $S_PIXELS_WIDTH_LF CONFIG.c_include_mm2s_dre {1} CONFIG.c_mm2s_burst_size {64} CONFIG.c_include_s2mm {0}] [get_bd_cells $IP_NAME]

set IP_NAME "axi_bram_ctrl"
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_bram_ctrl:4.1 $IP_NAME
set_property -dict [list CONFIG.SINGLE_PORT_BRAM {1}] [get_bd_cells $IP_NAME]

set IP_NAME "axi_gpio_out"
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_gpio:2.0 axi_gpio_out
set_property -dict [list CONFIG.C_GPIO_WIDTH {1} CONFIG.C_ALL_OUTPUTS {1}] [get_bd_cells axi_gpio_out]


# Interrupts
create_bd_cell -type ip -vlnv xilinx.com:ip:xlconcat:2.1 xlconcat_0
set_property -dict [list CONFIG.NUM_PORTS {3}] [get_bd_cells xlconcat_0]
connect_bd_net [get_bd_pins dma_pixels/mm2s_introut] [get_bd_pins xlconcat_0/In0]
connect_bd_net [get_bd_pins dma_weights/mm2s_introut] [get_bd_pins xlconcat_0/In1]
connect_bd_net [get_bd_pins xlconcat_0/dout] [get_bd_pins ${PS_IRQ}]

# AXI Lite
apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config "Clk_master {Auto} Clk_slave {Auto} Clk_xbar {Auto} Master $PS_M_AXI_LITE Slave {/dma_pixels/S_AXI_LITE} ddr_seg {Auto} intc_ip {New AXI Interconnect} master_apm {0}"       [get_bd_intf_pins dma_pixels/S_AXI_LITE]
apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config "Clk_master {Auto} Clk_slave {Auto} Clk_xbar {Auto} Master $PS_M_AXI_LITE Slave {/dma_weights/S_AXI_LITE} ddr_seg {Auto} intc_ip {New AXI Interconnect} master_apm {0}"  [get_bd_intf_pins dma_weights/S_AXI_LITE]
apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config " Clk_master {Auto} Clk_slave {Auto} Clk_xbar {Auto} Master $PS_M_AXI_BRAM Slave {/axi_bram_ctrl/S_AXI} ddr_seg {Auto} intc_ip {Auto} master_apm {0}"  [get_bd_intf_pins axi_bram_ctrl/S_AXI]
apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config " Clk_master {Auto} Clk_slave {Auto} Clk_xbar {Auto} Master $PS_M_AXI_BRAM Slave {/axi_gpio_out/S_AXI} ddr_seg {Auto} intc_ip {Auto} master_apm {0}"  [get_bd_intf_pins axi_gpio_out/S_AXI]

# AXI Full
apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config "Clk_master {Auto} Clk_slave {Auto} Clk_xbar {Auto} Master {/dma_pixels/M_AXI_MM2S} Slave $PS_S_AXI ddr_seg {Auto} intc_ip {New AXI SmartConnect} master_apm {0}"            [get_bd_intf_pins ${PS_S_AXI}]
apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config "Clk_master {Auto} Clk_slave $PS_CLK Clk_xbar $PS_CLK Master {/dma_weights/M_AXI_MM2S} Slave $PS_S_AXI ddr_seg {Auto} intc_ip {/axi_smc} master_apm {0}" [get_bd_intf_pins dma_weights/M_AXI_MM2S]


# Engine
add_files -norecurse -scan_for_includes [glob $RTL_DIR/*]
set_property top dnn_engine [current_fileset]
create_bd_cell -type module -reference dnn_engine dnn_engine_0

connect_bd_net [get_bd_pins $PS_CLK] [get_bd_pins dnn_engine_0/aclk]
connect_bd_intf_net [get_bd_intf_pins dma_pixels/M_AXIS_MM2S] [get_bd_intf_pins dnn_engine_0/s_axis_pixels]
connect_bd_intf_net [get_bd_intf_pins dma_weights/M_AXIS_MM2S] [get_bd_intf_pins dnn_engine_0/s_axis_weights]
connect_bd_net [get_bd_pins dnn_engine_0/aresetn] [get_bd_pins axi_smc/aresetn]
connect_bd_net [get_bd_pins dnn_engine_0/done_fill] [get_bd_pins xlconcat_0/In2]
connect_bd_net [get_bd_pins axi_bram_ctrl/bram_addr_a] [get_bd_pins dnn_engine_0/bram_addr_a]
connect_bd_net [get_bd_pins axi_bram_ctrl/bram_rddata_a] [get_bd_pins dnn_engine_0/bram_rddata_a]
connect_bd_net [get_bd_pins axi_bram_ctrl/bram_en_a] [get_bd_pins dnn_engine_0/bram_en_a]
connect_bd_net [get_bd_pins axi_gpio_out/gpio_io_o] [get_bd_pins dnn_engine_0/t_done_proc]

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
write_hw_platform -fixed -include_bit -force -file design_1_wrapper.xsa

# Reports
open_run impl_1
if {![file exists ../reports]} {exec mkdir ../reports}
report_timing_summary -delay_type min_max -report_unconstrained -check_timing_verbose -max_paths 100 -input_pins -routable_nets -name timing_1 -file ../reports/${PROJECT_NAME}_${BOARD}_${FREQ}_timing_report.txt
report_utilization -file ../reports/${PROJECT_NAME}_${BOARD}_${FREQ}_utilization_report.txt -name utilization_1
report_power -file ../reports/${PROJECT_NAME}_${BOARD}_${FREQ}_power_1.txt -name {power_1}
report_drc -name drc_1 -file ../reports/${PROJECT_NAME}_${BOARD}_${FREQ}_drc_1.txt -ruledecks {default opt_checks placer_checks router_checks bitstream_checks incr_eco_checks eco_checks abs_checks}

exec mkdir -p ../output
exec cp "$PROJECT_NAME/$PROJECT_NAME.gen/sources_1/bd/design_1/hw_handoff/design_1.hwh" ../output/
exec cp "$PROJECT_NAME/$PROJECT_NAME.runs/impl_1/design_1_wrapper.bit" ../output/design_1.bit
