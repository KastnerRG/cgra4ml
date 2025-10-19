#--------- Generating SRAMS & Lib files
source ../../deepsocflow/tcl/asic/synopsys/genSrams.tcl

#--------- Set PATH parameters
set SRAM_PATH ../asic/srams
set CORNERS "ssgnp_cworstccworstt_0p90v_0p90v_125c,ffgnp_cbestccbestt_1p05v_1p05v_m40c,tt_typical_1p00v_1p00v_85c"

#--------- SRAM EDGES
read_lib $SRAM_PATH/sram_edges/sram_edges_ssgnp_cworstccworstt_0p90v_0p90v_125c.lib
write_lib SRAM_EDGES_ssgnp_cworstccworstt_0p90v_0p90v_125c -output $SRAM_PATH/sram_edges/sram_edges_ssgnp_cworstccworstt_0p90v_0p90v_125c.db

read_lib $SRAM_PATH/sram_edges/sram_edges_ffgnp_cbestccbestt_1p05v_1p05v_m40c.lib
write_lib SRAM_EDGES_ffgnp_cbestccbestt_1p05v_1p05v_m40c -output $SRAM_PATH/sram_edges/sram_edges_ffgnp_cbestccbestt_1p05v_1p05v_m40c.db

read_lib $SRAM_PATH/sram_edges/sram_edges_tt_typical_1p00v_1p00v_85c.lib
write_lib SRAM_EDGES_tt_typical_1p00v_1p00v_85c -output $SRAM_PATH/sram_edges/sram_edges_tt_typical_1p00v_1p00v_85c.db

#--------- SRAM WEIGHTS
read_lib $SRAM_PATH/sram_weights/sram_weights_ssgnp_cworstccworstt_0p90v_0p90v_125c.lib
write_lib SRAM_WEIGHTS_ssgnp_cworstccworstt_0p90v_0p90v_125c -output $SRAM_PATH/sram_weights/sram_weights_ssgnp_cworstccworstt_0p90v_0p90v_125c.db

read_lib $SRAM_PATH/sram_weights/sram_weights_ffgnp_cbestccbestt_1p05v_1p05v_m40c.lib
write_lib SRAM_WEIGHTS_ffgnp_cbestccbestt_1p05v_1p05v_m40c -output $SRAM_PATH/sram_weights/sram_weights_ffgnp_cbestccbestt_1p05v_1p05v_m40c.db

read_lib $SRAM_PATH/sram_weights/sram_weights_tt_typical_1p00v_1p00v_85c.lib
write_lib SRAM_WEIGHTS_tt_typical_1p00v_1p00v_85c -output $SRAM_PATH/sram_weights/sram_weights_tt_typical_1p00v_1p00v_85c.db