set metal_stack         1p13m_1x1xa1ya5y2yy2z
set ndm_sram_library    tsmc_7_srams.ndm
set lef 	            "../asic/pdk/tsmc7/lef"
set ndmtfPath 	        "../asic/pdk/tsmc7/ndm/$metal_stack"
set sramLibPath         "../asic/srams"
set search_path         [concat $search_path $sramLibPath/sram_weights $sramLibPath/sram_edges] 

create_lib -ref_libs [list $lef/sch240mc_cln07ff41001_base_svt_c11.lef sram_weights.lef sram_edges.lef] -technology $ndmtfPath/sch240mc_tech.tf $sramLibPath/$ndm_sram_library