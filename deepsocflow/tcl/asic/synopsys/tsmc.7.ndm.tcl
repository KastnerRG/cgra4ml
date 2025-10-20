set metal_stack         1p13m_1x1xa1ya5y2yy2z
set ndm_design_library tsmc_7_srams.ndm
set ndmtfPath 	       "../asic/pdk/tsmc7/ndm/$metal_stack"
set sramLibPath        "../asic/srams"
set search_path        [concat $search_path $sramLibPath/sram_weights $sramLibPath/sram_edges] 

create_lib -ref_libs [list sram_weights.lef sram_edges.lef] -technology $ndmtfPath/sch240mc_tech.tf $sramLibPath/$ndm_design_library