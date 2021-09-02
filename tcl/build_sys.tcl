set PROJ_NAME sys
source ./tcl/config.tcl

# Delete existing
exec rm -rf ./$PROJ_FOLDER

# Create project
create_project $PROJ_NAME ./$PROJ_FOLDER -part xc7z045ffg900-2
set_property board_part xilinx.com:zc706:part0:1.4 [current_project]

# Make IPs
set IP_NAMES [list ]
source ./tcl/generate_ip.tcl

# Generate IP output products
foreach IP_NAME $IP_NAMES {
  set_property generate_synth_checkpoint 0 [get_files $PROJ_FOLDER/$PROJ_NAME.srcs/sources_1/ip/$IP_NAME/$IP_NAME.xci]
}

# Add files
add_files -norecurse [glob $HDL_DIR/*.sv]
add_files -norecurse [glob $HDL_DIR/*.v]
add_files -fileset sim_1 -norecurse $TB_DIR/axis_accelerator_tb.sv
add_files -fileset sim_1 -norecurse $WAVE_DIR/axis_accelerator_tb_behav.wcfg

source ./tcl/generate_bd.tcl

# Strategies
set_property strategy {Best - with retiming and all} [get_runs synth_1]
set_property strategy {Best - with retiming} [get_runs impl_1]
