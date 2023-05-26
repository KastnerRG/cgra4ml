set project_name sys
set rtl_dir ../../rtl
set params_dir ../../params
source vivado_config.tcl

create_project project_1 ${project_name}_vivado_accelerator -part xc7z020clg400-1 -force
# set_property board_part xilinx.com:zcu104:part0:1.1 [current_project]


#**** CREATE RAM IPs

set WIDTH [expr "$COLS * $WORD_WIDTH"]
set DEPTH [expr "$BRAM_WEIGHTS_DEPTH"]
create_ip -name blk_mem_gen -vendor xilinx.com -library ip -version 8.4 -module_name ram_weights
set_property -dict [list CONFIG.Write_Width_A $WIDTH CONFIG.Write_Depth_A $DEPTH CONFIG.Read_Width_A $WIDTH CONFIG.Operating_Mode_A {NO_CHANGE} CONFIG.Write_Width_B $WIDTH CONFIG.Read_Width_B $WIDTH CONFIG.Register_PortA_Output_of_Memory_Primitives {true}] [get_ips ram_weights]

set WIDTH [expr "$WORD_WIDTH * ($KH_MAX/2)"]
set DEPTH [expr "$RAM_EDGES_DEPTH"]
create_ip -name blk_mem_gen -vendor xilinx.com -library ip -version 8.4 -module_name ram_edges
set_property -dict [list CONFIG.Write_Width_A $WIDTH CONFIG.Write_Depth_A $DEPTH CONFIG.Read_Width_A $WIDTH CONFIG.Operating_Mode_A {NO_CHANGE} CONFIG.Write_Width_B $WIDTH CONFIG.Read_Width_B $WIDTH CONFIG.Register_PortA_Output_of_Memory_Primitives {false}] [get_ips ram_edges]

#**** BLOCK DIAGRAM

create_bd_design "design_1"

# ZYNQ
create_bd_cell -type ip -vlnv xilinx.com:ip:processing_system7:5.5 processing_system7_0
apply_bd_automation -rule xilinx.com:bd_rule:processing_system7 -config {make_external "FIXED_IO, DDR" Master "Disable" Slave "Disable" }  [get_bd_cells processing_system7_0]
set_property -dict [list CONFIG.PCW_USE_S_AXI_GP0 {0} CONFIG.PCW_USE_S_AXI_HP0 {1}  CONFIG.PCW_USE_FABRIC_INTERRUPT {1} CONFIG.PCW_IRQ_F2P_INTR {1} CONFIG.PCW_FPGA0_PERIPHERAL_FREQMHZ {100} CONFIG.PCW_UART0_PERIPHERAL_ENABLE {1}] [get_bd_cells processing_system7_0]


set IP_NAME "dma_weights_out"
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_dma:7.1 $IP_NAME
set_property -dict [list CONFIG.c_include_sg {0} CONFIG.c_sg_length_width {26} CONFIG.c_m_axi_mm2s_data_width {32} CONFIG.c_m_axis_mm2s_tdata_width {32} CONFIG.c_mm2s_burst_size {8} CONFIG.c_sg_include_stscntrl_strm {0} CONFIG.c_include_mm2s_dre {1} CONFIG.c_m_axi_mm2s_data_width $S_WEIGHTS_WIDTH_LF CONFIG.c_m_axis_mm2s_tdata_width $S_WEIGHTS_WIDTH_LF CONFIG.c_m_axi_s2mm_data_width $M_OUTPUT_WIDTH_LF CONFIG.c_s_axis_s2mm_tdata_width $M_OUTPUT_WIDTH_LF CONFIG.c_include_s2mm_dre {1} CONFIG.c_s2mm_burst_size {16}] [get_bd_cells $IP_NAME]

set IP_NAME "dma_pixels"
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_dma:7.1 $IP_NAME
set_property -dict [list CONFIG.c_include_sg {0} CONFIG.c_sg_length_width {26} CONFIG.c_m_axi_mm2s_data_width [expr $S_PIXELS_WIDTH_LF] CONFIG.c_m_axis_mm2s_tdata_width [expr $S_PIXELS_WIDTH_LF] CONFIG.c_include_mm2s_dre {1} CONFIG.c_mm2s_burst_size {64} CONFIG.c_include_s2mm {0}] [get_bd_cells $IP_NAME]

# Interrupts
create_bd_cell -type ip -vlnv xilinx.com:ip:xlconcat:2.1 xlconcat_0
set_property -dict [list CONFIG.NUM_PORTS {3}] [get_bd_cells xlconcat_0]
connect_bd_net [get_bd_pins dma_pixels/mm2s_introut] [get_bd_pins xlconcat_0/In0]
connect_bd_net [get_bd_pins dma_weights_out/mm2s_introut] [get_bd_pins xlconcat_0/In1]
connect_bd_net [get_bd_pins dma_weights_out/s2mm_introut] [get_bd_pins xlconcat_0/In2]
connect_bd_net [get_bd_pins xlconcat_0/dout] [get_bd_pins processing_system7_0/IRQ_F2P]


# AXI Lite
apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config { Clk_master {Auto} Clk_slave {Auto} Clk_xbar {Auto} Master {/processing_system7_0/M_AXI_GP0} Slave {/dma_pixels/S_AXI_LITE} ddr_seg {Auto} intc_ip {New AXI Interconnect} master_apm {0}}  [get_bd_intf_pins dma_pixels/S_AXI_LITE]
apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config { Clk_master {Auto} Clk_slave {Auto} Clk_xbar {Auto} Master {/processing_system7_0/M_AXI_GP0} Slave {/dma_weights_out/S_AXI_LITE} ddr_seg {Auto} intc_ip {New AXI Interconnect} master_apm {0}}  [get_bd_intf_pins dma_weights_out/S_AXI_LITE]

# AXI Full
apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config { Clk_master {Auto} Clk_slave {Auto} Clk_xbar {Auto} Master {/dma_pixels/M_AXI_MM2S} Slave {/processing_system7_0/S_AXI_HP0} ddr_seg {Auto} intc_ip {New AXI SmartConnect} master_apm {0}}  [get_bd_intf_pins processing_system7_0/S_AXI_HP0]
apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config { Clk_master {Auto} Clk_slave {/processing_system7_0/FCLK_CLK0 (99 MHz)} Clk_xbar {/processing_system7_0/FCLK_CLK0 (99 MHz)} Master {/dma_weights_out/M_AXI_MM2S} Slave {/processing_system7_0/S_AXI_HP0} ddr_seg {Auto} intc_ip {/axi_smc} master_apm {0}}  [get_bd_intf_pins dma_weights_out/M_AXI_MM2S]
apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config { Clk_master {Auto} Clk_slave {/processing_system7_0/FCLK_CLK0 (99 MHz)} Clk_xbar {/processing_system7_0/FCLK_CLK0 (99 MHz)} Master {/dma_weights_out/M_AXI_S2MM} Slave {/processing_system7_0/S_AXI_HP0} ddr_seg {Auto} intc_ip {/axi_smc} master_apm {0}}  [get_bd_intf_pins dma_weights_out/M_AXI_S2MM]


# Engine
add_files -norecurse [glob $rtl_dir/*]
add_files -norecurse -scan_for_includes [glob $params_dir/*]
set_property top dnn_engine [current_fileset]

create_bd_cell -type module -reference dnn_engine dnn_engine_0
connect_bd_net [get_bd_pins processing_system7_0/FCLK_CLK0] [get_bd_pins dnn_engine_0/aclk]
connect_bd_intf_net [get_bd_intf_pins dma_pixels/M_AXIS_MM2S] [get_bd_intf_pins dnn_engine_0/s_axis_pixels]
connect_bd_intf_net [get_bd_intf_pins dma_weights_out/M_AXIS_MM2S] [get_bd_intf_pins dnn_engine_0/s_axis_weights]
connect_bd_intf_net [get_bd_intf_pins dma_weights_out/S_AXIS_S2MM] [get_bd_intf_pins dnn_engine_0/m_axis]
connect_bd_net [get_bd_pins dnn_engine_0/aresetn] [get_bd_pins axi_smc/aresetn]

validate_bd_design

generate_target all [get_files ./${project_name}_vivado_accelerator/project_1.srcs/sources_1/bd/design_1/design_1.bd]
make_wrapper -files [get_files ./${project_name}_vivado_accelerator/project_1.srcs/sources_1/bd/design_1/design_1.bd] -top
add_files -norecurse ./${project_name}_vivado_accelerator/project_1.srcs/sources_1/bd/design_1/hdl/design_1_wrapper.v
set_property top design_1_wrapper [current_fileset]
save_bd_design


reset_run impl_1
reset_run synth_1
launch_runs impl_1 -to_step write_bitstream -jobs 10
wait_on_run -timeout 360 impl_1
write_hw_platform -fixed -include_bit -force -file design_1_wrapper.xsa