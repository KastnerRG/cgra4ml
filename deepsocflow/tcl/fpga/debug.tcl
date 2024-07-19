connect
targets -set -filter {name =~ "Cortex-A* #0"}
fpga D:/dnn-engine/run/work/dsf_zcu104/dsf_zcu104.runs/impl_1/design_1_wrapper.bit
source "D:/dnn-engine/run/work/dsf_zcu104/dsf_zcu104.gen/sources_1/bd/design_1/ip/design_1_zynq_ultra_ps_e_0_0/psu_init.tcl"
rst -processor
psu_init
psu_post_config
dow C:/Users/abara/workspace/dsf/Debug/dsf.elf
bpadd -addr &main
readjtaguart -start
mwr -bin -file "D:/dnn-engine/run/work/vectors/wbx.bin" 0x20000000 5392
con