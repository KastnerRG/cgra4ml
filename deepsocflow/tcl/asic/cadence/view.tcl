# Version:1.0 MMMC View Definition File
# Do Not Remove Above Line
set TOP dnn_engine
set TECH 65nm
set LIB_DIR ../../../tsmc/${TECH}/GP
create_rc_corner -name rc_slow -T {125} -preRoute_res {1.0} -preRoute_cap {1.0} -preRoute_clkres {0.0} -preRoute_clkcap {0.0} -postRoute_res {1.0} -postRoute_cap {1.0} -postRoute_xcap {1.0} -postRoute_clkres {0.0} -postRoute_clkcap {0.0} -qx_tech_file $LIB_DIR/other/icecaps.tch
create_rc_corner -name rc_fast -T {-40} -preRoute_res {1.0} -preRoute_cap {1.0} -preRoute_clkres {0.0} -preRoute_clkcap {0.0} -postRoute_res {1.0} -postRoute_cap {1.0} -postRoute_xcap {1.0} -postRoute_clkres {0.0} -postRoute_clkcap {0.0} -qx_tech_file $LIB_DIR/other/icecaps.tch

create_library_set -name lib_fast -timing {$LIB_DIR/cc_lib/noise_scadv10_cln65gp_hvt_ff_1p1v_m40c.lib $LIB_DIR/scadv10_cln65gp_hvt_ff_1p1v_m40c.lib}
create_library_set -name lib_slow -timing {$LIB_DIR/cc_lib/noise_scadv10_cln65gp_hvt_ss_0p9v_m40c.lib $LIB_DIR/scadv10_cln65gp_hvt_ss_0p9v_m40c.lib}
create_constraint_mode -name SDC -sdc_files ../output/${TOP}.sdc
create_delay_corner -name dc_slow -rc_corner {rc_slow} -early_library_set {lib_fast} -late_library_set {lib_slow}
create_delay_corner -name dc_fast -rc_corner {rc_fast} -early_library_set {lib_fast} -late_library_set {lib_slow}
create_analysis_view -name view_slow -constraint_mode {SDC} -delay_corner {dc_slow}
create_analysis_view -name view_fast -constraint_mode {SDC} -delay_corner {dc_fast}
set_analysis_view -setup {view_slow} -hold {view_fast}