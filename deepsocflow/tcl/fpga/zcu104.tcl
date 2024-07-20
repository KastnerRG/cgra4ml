set BOARD zcu104
set CONFIG_BASEADDR 0x00B0000000

create_project ${PROJECT_NAME} ${PROJECT_NAME} -part xczu7ev-ffvc1156-2-e -force
set_property board_part xilinx.com:zcu104:part0:1.1 [current_project]

create_bd_design "design_1"
create_bd_cell -type ip -vlnv xilinx.com:ip:zynq_ultra_ps_e:3.4 zynq_ultra_ps_e_0
apply_bd_automation -rule xilinx.com:bd_rule:zynq_ultra_ps_e -config {apply_board_preset "1" }  [get_bd_cells zynq_ultra_ps_e_0]
set_property -dict [list CONFIG.PSU__USE__M_AXI_GP1 {1} CONFIG.PSU__USE__S_AXI_GP0 {1} CONFIG.PSU__USE__S_AXI_GP1 {1} CONFIG.PSU__USE__S_AXI_GP2 {1} CONFIG.PSU__CRL_APB__PL0_REF_CTRL__FREQMHZ $FREQ CONFIG.PSU__USE__M_AXI_GP0 {0} CONFIG.PSU__QSPI__PERIPHERAL__ENABLE {0} CONFIG.PSU__SAXIGP0__DATA_WIDTH $AXI_WIDTH CONFIG.PSU__SAXIGP1__DATA_WIDTH $AXI_WIDTH CONFIG.PSU__SAXIGP2__DATA_WIDTH $AXI_WIDTH] [get_bd_cells zynq_ultra_ps_e_0]

set PS_IRQ           "zynq_ultra_ps_e_0/pl_ps_irq0"
set PS_M_AXI_LITE    "/zynq_ultra_ps_e_0/M_AXI_HPM1_FPD"
set PS_S_AXI_OUTPUT  "/zynq_ultra_ps_e_0/S_AXI_HPC0_FPD"
set PS_S_AXI_PIXELS  "/zynq_ultra_ps_e_0/S_AXI_HPC1_FPD"
set PS_S_AXI_WEIGHTS "/zynq_ultra_ps_e_0/S_AXI_HP0_FPD"
set PS_CLK           "/zynq_ultra_ps_e_0/pl_clk0"
