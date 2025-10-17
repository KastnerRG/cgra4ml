#--------- Set PATH parameters
set top_module dnn_engine
set reportPath "../asic/reports"
set outputPath "../asic/outputs"
set libraryPath "../asic/pdk/tsmc65lp/db"
set rclibPath "../asic/pdk/tsmc65lp/tluplus"
set sramLibPath "../asic/srams"
set search_path [concat $search_path $libraryPath $sramLibPath/sram_edges $sramLibPath/sram_weights] 
set search_path [concat $search_path $outputPath]

#--------- Set Libraries
set library_name ${top_module}_tsmc65lp
set target_library "sc12_cln65lp_base_rvt_ss_typical_max_1p08v_125c.db sram_edges_ss_1p08v_1p08v_125c.db sram_weights_ss_1p08v_1p08v_125c.db"
set link_library [concat "* $target_library"]

create_lib -technology "../asic/pdk/tsmc65lp/tf/sc12_tech.tf" -ref_libs [list "../asic/pdk/tsmc65lp/lef/sc12_cln65lp_base_rvt.lef" "../asic/srams/sram_edges/sram_edges.lef" "../asic/srams/sram_weights/sram_weights.lef"] $library_name
#open_lib ${top_module}_tsmc65lp
read_parasitic_tech -name typical -tlup "../asic/pdk/tsmc65lp/tluplus/typical.tluplus" -layermap "../asic/pdk/tsmc65lp/tluplus/tluplus.map"
read_parasitic_tech -name rcbest -tlup "../asic/pdk/tsmc65lp/tluplus/rcbest.tluplus" -layermap "../asic/pdk/tsmc65lp/tluplus/tluplus.map"
read_parasitic_tech -name rcworst -tlup "../asic/pdk/tsmc65lp/tluplus/rcworst.tluplus" -layermap "../asic/pdk/tsmc65lp/tluplus/tluplus.map"

#--------- Set Libraries
read_verilog -library $library_name -top $top_module "$outputPath/${top_module}.out.v"
read_sdc "$outputPath/${top_module}.out.sdc"
link_block

save_block $library_name:$top_module
save_lib -all

