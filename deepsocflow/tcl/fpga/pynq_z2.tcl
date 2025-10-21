set BOARD pynq_z2

set_param board.repoPaths {C:/Users/abara/AppData/Roaming/Xilinx/Vivado/2024.2.2/xhub/board_store/xilinx_board_store}
create_project ${PROJECT_NAME} ${PROJECT_NAME} -part xc7z020clg400-1 -force
set_property board_part tul.com.tw:pynq-z2:part0:1.0 [current_project]

create_bd_design "design_1"
create_bd_cell -type ip -vlnv xilinx.com:ip:processing_system7:5.5 processing_system7_0
apply_bd_automation -rule xilinx.com:bd_rule:processing_system7 -config {make_external "FIXED_IO, DDR" Master "Disable" Slave "Disable" }  [get_bd_cells processing_system7_0]
set_property -dict [list CONFIG.PCW_USE_S_AXI_GP0 {0} CONFIG.PCW_USE_S_AXI_HP0 {1} CONFIG.PCW_USE_S_AXI_HP1 {1} CONFIG.PCW_USE_S_AXI_HP2 {1}  CONFIG.PCW_USE_FABRIC_INTERRUPT {1} CONFIG.PCW_IRQ_F2P_INTR {1} CONFIG.PCW_FPGA0_PERIPHERAL_FREQMHZ $FREQ CONFIG.PCW_UART0_PERIPHERAL_ENABLE {1}] [get_bd_cells processing_system7_0]

set PS_IRQ        "processing_system7_0/IRQ_F2P"
set PS_M_AXI_LITE "/processing_system7_0/M_AXI_GP0"
set PS_S_AXI_OUTPUT  "/processing_system7_0/S_AXI_HP0"
set PS_S_AXI_PIXELS  "/processing_system7_0/S_AXI_HP1"
set PS_S_AXI_WEIGHTS "/processing_system7_0/S_AXI_HP2"
set PS_CLK        "/processing_system7_0/FCLK_CLK0"