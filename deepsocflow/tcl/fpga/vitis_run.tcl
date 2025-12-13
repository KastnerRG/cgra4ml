setws [glob -nocomplain -types d ./ws_*]   ;# picks the latest; or paste exact path
connect
targets -set -filter {name =~ "Cortex-A53*#0"}
rst -processor
set APP my_app
dow "[getws]/$APP/Debug/$APP.elf"
dow -data "./wbx.bin" 0x20000000
con
