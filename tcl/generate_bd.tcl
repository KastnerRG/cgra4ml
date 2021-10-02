create_bd_design "sys"

# ZYNQ IP
create_bd_cell -type ip -vlnv xilinx.com:ip:processing_system7:5.5 processing_system7_0
apply_bd_automation -rule xilinx.com:bd_rule:processing_system7 -config {make_external "FIXED_IO, DDR" apply_board_preset "1" Master "Disable" Slave "Disable" }  [get_bd_cells processing_system7_0]
set_property -dict [list CONFIG.PCW_FPGA0_PERIPHERAL_FREQMHZ $FREQ_LITE CONFIG.PCW_FPGA1_PERIPHERAL_FREQMHZ $FREQ_LOW CONFIG.PCW_FPGA2_PERIPHERAL_FREQMHZ $FREQ_HIGH CONFIG.PCW_EN_CLK2_PORT $FREQ_LITE CONFIG.PCW_USE_S_AXI_ACP {1} CONFIG.PCW_USE_DEFAULT_ACP_USER_VAL {1} CONFIG.PCW_USE_FABRIC_INTERRUPT {1} CONFIG.PCW_EN_CLK1_PORT {1} CONFIG.PCW_EN_CLK2_PORT {1} CONFIG.PCW_IRQ_F2P_INTR {1} CONFIG.PCW_QSPI_PERIPHERAL_ENABLE {0} CONFIG.PCW_SD0_PERIPHERAL_ENABLE {0} CONFIG.PCW_I2C0_PERIPHERAL_ENABLE {0} CONFIG.PCW_GPIO_MIO_GPIO_ENABLE {0}] [get_bd_cells processing_system7_0]

# Accelerator
create_bd_cell -type module -reference axis_accelerator axis_accelerator_0

# Weights & out DMA
set IP_NAME "dma_weights_im_out"
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_dma:7.1 $IP_NAME
set_property -dict [list CONFIG.c_include_sg {0} CONFIG.c_sg_length_width {26} CONFIG.c_m_axi_mm2s_data_width {32} CONFIG.c_m_axis_mm2s_tdata_width {32} CONFIG.c_mm2s_burst_size {8} CONFIG.c_sg_include_stscntrl_strm {0} CONFIG.c_include_mm2s_dre {1} CONFIG.c_m_axi_mm2s_data_width $S_WEIGHTS_WIDTH_LF CONFIG.c_m_axis_mm2s_tdata_width $S_WEIGHTS_WIDTH_LF CONFIG.c_m_axi_s2mm_data_width $M_DATA_WIDTH_LF CONFIG.c_s_axis_s2mm_tdata_width $M_DATA_WIDTH_LF CONFIG.c_include_s2mm_dre {1} CONFIG.c_s2mm_burst_size {16}] [get_bd_cells $IP_NAME]

# Im_in_1
set IP_NAME "dma_im_in"
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_dma:7.1 $IP_NAME
set_property -dict [list CONFIG.c_include_sg {0} CONFIG.c_sg_length_width {26} CONFIG.c_m_axi_mm2s_data_width [expr $S_PIXELS_WIDTH_LF] CONFIG.c_m_axis_mm2s_tdata_width [expr $S_PIXELS_WIDTH_LF] CONFIG.c_include_mm2s_dre {1} CONFIG.c_mm2s_burst_size {64} CONFIG.c_include_s2mm {0}] [get_bd_cells $IP_NAME]

# # Interrupts
create_bd_cell -type ip -vlnv xilinx.com:ip:xlconcat:2.1 xlconcat_0
set_property -dict [list CONFIG.NUM_PORTS {4}] [get_bd_cells xlconcat_0]
connect_bd_net [get_bd_pins dma_im_in/mm2s_introut] [get_bd_pins xlconcat_0/In0]
connect_bd_net [get_bd_pins dma_weights_im_out/mm2s_introut] [get_bd_pins xlconcat_0/In2]
connect_bd_net [get_bd_pins dma_weights_im_out/s2mm_introut] [get_bd_pins xlconcat_0/In3]
connect_bd_net [get_bd_pins xlconcat_0/dout] [get_bd_pins processing_system7_0/IRQ_F2P]

# Engine connections
connect_bd_net [get_bd_pins processing_system7_0/FCLK_CLK1] [get_bd_pins axis_accelerator_0/aclk]
connect_bd_net [get_bd_pins processing_system7_0/FCLK_CLK2] [get_bd_pins axis_accelerator_0/hf_aclk]
connect_bd_intf_net [get_bd_intf_pins dma_im_in/M_AXIS_MM2S] [get_bd_intf_pins axis_accelerator_0/s_axis_pixels]
connect_bd_intf_net [get_bd_intf_pins dma_weights_im_out/M_AXIS_MM2S] [get_bd_intf_pins axis_accelerator_0/s_axis_weights]
switch $OUTPUT_MODE {
  "CONV"    {connect_bd_intf_net [get_bd_intf_pins dma_weights_im_out/S_AXIS_S2MM] [get_bd_intf_pins axis_accelerator_0/conv_dw2_lf_m_axis]}
  "LRELU"   {connect_bd_intf_net [get_bd_intf_pins dma_weights_im_out/S_AXIS_S2MM] [get_bd_intf_pins axis_accelerator_0/lrelu_dw_lf_m_axis]}
  "MAXPOOL" {connect_bd_intf_net [get_bd_intf_pins dma_weights_im_out/S_AXIS_S2MM] [get_bd_intf_pins axis_accelerator_0/max_dw2_lf_m_axis ]}
}

# AXI Lite
startgroup
apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config { Clk_master {/processing_system7_0/FCLK_CLK0 ($FREQ_LITE MHz)} Clk_slave {/processing_system7_0/FCLK_CLK0 ($FREQ_LITE MHz)} Clk_xbar {/processing_system7_0/FCLK_CLK0 ($FREQ_LITE MHz)} Master {/processing_system7_0/M_AXI_GP0} Slave {/dma_im_in/S_AXI_LITE} ddr_seg {Auto} intc_ip {New AXI Interconnect} master_apm {0}}  [get_bd_intf_pins dma_im_in/S_AXI_LITE]
apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config { Clk_master {/processing_system7_0/FCLK_CLK0 ($FREQ_LITE MHz)} Clk_slave {/processing_system7_0/FCLK_CLK0 ($FREQ_LITE MHz)} Clk_xbar {/processing_system7_0/FCLK_CLK0 ($FREQ_LITE MHz)} Master {/processing_system7_0/M_AXI_GP0} Slave {/dma_weights_im_out/S_AXI_LITE} ddr_seg {Auto} intc_ip {New AXI Interconnect} master_apm {0}}  [get_bd_intf_pins dma_weights_im_out/S_AXI_LITE]
endgroup

# AXI4
startgroup
apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config { Clk_master {/processing_system7_0/FCLK_CLK1 ($FREQ_LOW MHz)} Clk_slave {/processing_system7_0/FCLK_CLK1 ($FREQ_LOW MHz)} Clk_xbar {/processing_system7_0/FCLK_CLK1 ($FREQ_LOW MHz)} Master {/dma_weights_im_out/M_AXI_MM2S} Slave {/processing_system7_0/S_AXI_ACP} ddr_seg {Auto} intc_ip {New AXI Interconnect} master_apm {0}}  [get_bd_intf_pins processing_system7_0/S_AXI_ACP]
apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config { Clk_master {/processing_system7_0/FCLK_CLK1 ($FREQ_LOW MHz)} Clk_slave {/processing_system7_0/FCLK_CLK1 ($FREQ_LOW MHz)} Clk_xbar {/processing_system7_0/FCLK_CLK1 ($FREQ_LOW MHz)} Master {/dma_im_in/M_AXI_MM2S} Slave {/processing_system7_0/S_AXI_ACP} ddr_seg {Auto} intc_ip {/axi_mem_intercon} master_apm {0}}  [get_bd_intf_pins dma_im_in/M_AXI_MM2S]
apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config { Clk_master {/processing_system7_0/FCLK_CLK1 ($FREQ_LOW MHz)} Clk_slave {/processing_system7_0/FCLK_CLK1 ($FREQ_LOW MHz)} Clk_xbar {/processing_system7_0/FCLK_CLK1 ($FREQ_LOW MHz)} Master {/dma_weights_im_out/M_AXI_S2MM} Slave {/processing_system7_0/S_AXI_ACP} ddr_seg {Auto} intc_ip {/axi_mem_intercon} master_apm {0}}  [get_bd_intf_pins dma_weights_im_out/M_AXI_S2MM]
endgroup

# HF Reset
set IP_NAME "reset_hf"
create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 $IP_NAME
connect_bd_net [get_bd_pins processing_system7_0/FCLK_CLK2] [get_bd_pins $IP_NAME/slowest_sync_clk]
connect_bd_net [get_bd_pins processing_system7_0/FCLK_RESET0_N] [get_bd_pins $IP_NAME/ext_reset_in]
connect_bd_net [get_bd_pins $IP_NAME/peripheral_aresetn] [get_bd_pins axis_accelerator_0/hf_aresetn]

# LF Reset
# NOTE: axi_mem_intercon gets created after axi lite
connect_bd_net [get_bd_pins axis_accelerator_0/aresetn] [get_bd_pins axi_mem_intercon/ARESETN]

save_bd_design
validate_bd_design

generate_target all [get_files  $PROJ_FOLDER/$PROJ_NAME.srcs/sources_1/bd/sys/sys.bd]
make_wrapper -files [get_files $PROJ_FOLDER/$PROJ_NAME.srcs/sources_1/bd/sys/sys.bd] -top
add_files -norecurse $PROJ_FOLDER/$PROJ_NAME.gen/sources_1/bd/sys/hdl/sys_wrapper.v
set_property top sys_wrapper [current_fileset]