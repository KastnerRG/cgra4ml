set BOARD zcu104
set FREQ  249

create_project ${PROJECT_NAME} ${PROJECT_NAME} -part xczu7ev-ffvc1156-2-e -force
set_property board_part xilinx.com:zcu104:part0:1.1 [current_project]

create_bd_design "design_1"
create_bd_cell -type ip -vlnv xilinx.com:ip:zynq_ultra_ps_e:3.3 zynq_ultra_ps_e_0
apply_bd_automation -rule xilinx.com:bd_rule:zynq_ultra_ps_e -config {apply_board_preset "1" }  [get_bd_cells zynq_ultra_ps_e_0]
set_property -dict [list CONFIG.PSU__USE__M_AXI_HPM0_LPD {0} CONFIG.PSU__USE__M_AXI_GP1 {0} CONFIG.PSU__USE__S_AXI_GP0 {1} CONFIG.PSU__USE__M_AXI_GP2 {1} CONFIG.PSU__CRL_APB__PL0_REF_CTRL__FREQMHZ $FREQ CONFIG.PSU__USE__M_AXI_GP0 {0}] [get_bd_cells zynq_ultra_ps_e_0]

set PS_IRQ        "zynq_ultra_ps_e_0/pl_ps_irq0"
set PS_M_AXI_LITE "/zynq_ultra_ps_e_0/M_AXI_HPM0_LPD"
set PS_S_AXI      "/zynq_ultra_ps_e_0/S_AXI_HPC0_FPD"
set PS_CLK        "/zynq_ultra_ps_e_0/pl_clk0"
