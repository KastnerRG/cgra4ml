set FREQ  99

create_project project_1 ${project_name}_vivado_accelerator -part xc7z020clg400-1 -force
# set_property board_part xilinx.com:zcu104:part0:1.1 [current_project]

create_bd_cell -type ip -vlnv xilinx.com:ip:processing_system7:5.5 processing_system7_0
apply_bd_automation -rule xilinx.com:bd_rule:processing_system7 -config {make_external "FIXED_IO, DDR" Master "Disable" Slave "Disable" }  [get_bd_cells processing_system7_0]
set_property -dict [list CONFIG.PCW_USE_S_AXI_GP0 {0} CONFIG.PCW_USE_S_AXI_HP0 {1}  CONFIG.PCW_USE_FABRIC_INTERRUPT {1} CONFIG.PCW_IRQ_F2P_INTR {1} CONFIG.PCW_FPGA0_PERIPHERAL_FREQMHZ $FREQ CONFIG.PCW_UART0_PERIPHERAL_ENABLE {1}] [get_bd_cells processing_system7_0]

create_bd_design "design_1"
create_bd_cell -type ip -vlnv xilinx.com:ip:zynq_ultra_ps_e:3.3 zynq_ultra_ps_e_0
apply_bd_automation -rule xilinx.com:bd_rule:zynq_ultra_ps_e -config {apply_board_preset "1" }  [get_bd_cells zynq_ultra_ps_e_0]
set_property -dict [list CONFIG.PSU__USE__M_AXI_HPM0_LPD {0} CONFIG.PSU__USE__M_AXI_GP1 {0} CONFIG.PSU__USE__S_AXI_GP0 {1} CONFIG.PSU__USE__M_AXI_GP2 {1} CONFIG.PSU__CRL_APB__PL0_REF_CTRL__FREQMHZ $FREQ CONFIG.PSU__USE__M_AXI_GP0 {0}] [get_bd_cells zynq_ultra_ps_e_0]

set PS_IRQ        "processing_system7_0/IRQ_F2P"
set PS_M_AXI_LITE "/processing_system7_0/M_AXI_GP0"
set PS_S_AXI      "processing_system7_0/S_AXI_HP0"
set PS_CLK        "/processing_system7_0/FCLK_CLK0 ($FREQ MHz)"