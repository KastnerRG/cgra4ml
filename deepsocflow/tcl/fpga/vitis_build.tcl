# ---- paths ----
set ROOT [file normalize "../../"]
set XSA  [file normalize "./design_1_wrapper.xsa"]
set INC1 [file normalize "./"]
set INC2 [file normalize "$ROOT/deepsocflow/c"]
set APP  my_app
# unique workspace to dodge locks & name collisions
set WS   [file normalize "./ws_[clock format [clock seconds] -format %Y%m%d_%H%M%S]"]
setws $WS

# ---- cleanup if reusing names (ignore errors) ----
catch { app remove $APP }
catch { domain remove a53_standalone }
catch { platform remove plat }

# ---- create/generate ----
platform create -name plat -hw $XSA -proc psu_cortexa53_0 -os standalone
platform generate
domain create -name a53_standalone -os standalone -proc psu_cortexa53_0 -arch 64-bit
app create -name $APP -platform plat -domain a53_standalone -template {Hello World} -lang C

# ---- cfg ----
app config -name $APP -add include-path $INC1
app config -name $APP -add include-path $INC2
app config -name $APP -set compiler-optimization {Optimize most (-O3)}
app config -name $APP -add libraries m

# ---- replace source (local file ops; no tfile) ----
set DSTH "$WS/$APP/src/helloworld.c"
set SRC  [file normalize "$ROOT/deepsocflow/c/xilinx_example.c"]
if {[file exists $DSTH]} { file delete -force $DSTH }
file copy -force $SRC $DSTH

# ---- build ----
app build -name $APP
puts "ELF: $WS/$APP/Debug/$APP.elf"
