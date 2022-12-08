set PROJ_NAME sys
set PROJ_FOLDER flow/fpga/$PROJ_NAME
set RTL_DIR rtl
set TB_DIR tb

set XILINX 1

source ./flow/config.tcl

# Delete existing
exec rm -rf ./$PROJ_FOLDER

# Create project
create_project $PROJ_NAME ./$PROJ_FOLDER -part xc7z045ffg900-2
set_property board_part xilinx.com:zc706:part0:1.4 [current_project]

# Make IPs
set IP_NAMES [list ]
source ./flow/gen_fpga_ip.tcl

# Generate IP output products
foreach IP_NAME $IP_NAMES {
  set_property generate_synth_checkpoint 0 [get_files $PROJ_FOLDER/$PROJ_NAME.srcs/sources_1/ip/$IP_NAME/$IP_NAME.xci]
}

# Add files
add_files -norecurse [glob $RTL_DIR/*]
# add_files -norecurse [glob $RTL_DIR/**/*]
add_files -fileset sim_1 -norecurse $TB_DIR/axis_accelerator_tb.sv
add_files -fileset sim_1 -norecurse $TB_DIR/wave/axis_accelerator_tb_behav.wcfg
set_property top axis_accelerator_tb [get_filesets sim_1]

# source ./tcl/zynq_bd.tcl

# # Strategies
# set_property strategy {Best - with retiming and all} [get_runs synth_1]
# set_property strategy {Best - with retiming} [get_runs impl_1]
