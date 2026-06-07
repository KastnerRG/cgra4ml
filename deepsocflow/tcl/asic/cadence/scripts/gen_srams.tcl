# Foundary and Technolgy
set FOUNDARY "SAMSUNG"
set TECHNOLOGY "LN05LPE"

#Genrating SRAM EDGES
cd ../../../PDK/$FOUNDARY$TECHNOLOGY/SRAMs_CGRA4ML/sram_edge
exec rf_sp_hde_hvt_mvt verilog -spec sram_edge.spec
exec rf_sp_hde_hvt_mvt lef-fp  -spec sram_edge.spec
exec rf_sp_hde_hvt_mvt liberty -spec sram_edge.spec
exec rf_sp_hde_hvt_mvt aocv    -spec sram_edge.spec
cd ../../../work

#Genrating SRAM WEIGHTS
cd ../../../PDK/$FOUNDARY$TECHNOLOGY/SRAMs_CGRA4ML/sram_weight
exec rf_sp_hde_hvt_mvt verilog -spec sram_weight.spec
exec rf_sp_hde_hvt_mvt lef-fp  -spec sram_weight.spec
exec rf_sp_hde_hvt_mvt liberty -spec sram_weight.spec
exec rf_sp_hde_hvt_mvt aocv    -spec sram_weight.spec
cd ../../../work

#Genrating SRAM DMA
cd ../../../PDK/$FOUNDARY$TECHNOLOGY/SRAMs_CGRA4ML/sram_dma
exec rf_sp_hde_hvt_mvt verilog -spec sram_dma.spec
exec rf_sp_hde_hvt_mvt lef-fp  -spec sram_dma.spec
exec rf_sp_hde_hvt_mvt liberty -spec sram_dma.spec
exec rf_sp_hde_hvt_mvt aocv    -spec sram_dma.spec
cd ../../../work