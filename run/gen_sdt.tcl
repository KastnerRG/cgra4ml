set xsa_path  [lindex $argv 0]
set sdt_dir   [lindex $argv 1]
set board_dts [lindex $argv 2]

set_dt_param -debug enable
set_dt_param -zocl disable
set_dt_param -dir $sdt_dir
set_dt_param -xsa $xsa_path
set_dt_param -board_dts $board_dts
generate_sdt
