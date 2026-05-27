
set PROJECT_NAME dsf_zcu104
set RTL_DIR      [file normalize [file join [file dirname [info script]] ".." "deepsocflow" "rtl"]]
set CONFIG_DIR   [file normalize [file join [file dirname [info script]] "work"]]

source [file normalize [file join [file dirname [info script]] ".." "config_hw.tcl"]]
source [file normalize [file join [file dirname [info script]] ".." "deepsocflow" "tcl" "fpga" "zcu104.tcl"]]
source [file normalize [file join [file dirname [info script]] ".." "deepsocflow" "tcl" "fpga" "vivado.tcl"]]
