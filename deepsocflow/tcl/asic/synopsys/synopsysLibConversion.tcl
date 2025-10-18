#--------- Generating SRAMS & Lib files
source ../../deepsocflow/tcl/asic/genSrams.tcl

#--------- Set PATH parameters
set SRAM_PATH ../asic/srams

#--------- SRAM EDGES
read_lib $SRAM_PATH/sram_edges/sram_edges_ffg_cbestt_1p05v_1p05v_125c.lib
write_lib SRAM_EDGES_ffg_cbestt_1p05v_1p05v_125c -output $SRAM_PATH/sram_edges/sram_edges_ffg_cbestt_1p05v_1p05v_125c.db

#--------- SRAM WEIGHTS
read_lib $SRAM_PATH/sram_weights/sram_weights_ffg_cbestt_1p05v_1p05v_125c.lib
write_lib SRAM_WEIGHTS_ffg_cbestt_1p05v_1p05v_125c -output $SRAM_PATH/sram_weights/sram_weights_ffg_cbestt_1p05v_1p05v_125c.db