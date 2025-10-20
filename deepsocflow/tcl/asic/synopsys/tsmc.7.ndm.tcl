set metal_stack         1p13m_1x1xa1ya5y2yy2z

set ndmtfPath 	        "../asic/pdk/tsmc7/ndm/$metal_stack"
set sramLibPath         "../asic/srams"
set search_path         [concat $search_path $sramLibPath/sram_weights $sramLibPath/sram_edges] 

set_app_var link_library "sram_edges_ssgnp_cworstccworstt_0p90v_0p90v_125c.db sram_weights_ssgnp_cworstccworstt_0p90v_0p90v_125c.db"
create_lib -ref_libs [list sram_weights.lef sram_edges.lef] -technology $ndmtfPath/sch240mc_tech.tf