set top_module dnn_engine
set rtlPath "../../rtl/"

set_host_options -max_cores 8

# Target library
set target_library ../pdk/tsmc65gp/db/scadv10_cln65gp_lvt_tt_1p0v_25c.db
set link_library $target_library
set symbol_library {}
set wire_load_mode enclosed
set timing_use_enhanced_capacitance_modeling true

set search_path [concat $rtlPath $search_path]
set link_library [concat * $link_library ]

set synthetic_library {}
set link_path [concat  $link_library $synthetic_library]
set dont_use_cells 1
set dont_use_cell_list ""

remove_design -all
if {[file exists template]} {
	exec rm -rf template
}
exec mkdir template

sh date
sh echo hostname
sh echo uptime

#Compiler directives
set compile_effort   "low"
set compile_no_new_cells_at_top_level false
set hdlin_enable_vpp true
set hdlin_auto_save_templates false

define_design_lib WORK -path .template
set verilogout_single_bit false

# read RTL
analyze -format sverilog -lib WORK [glob ../../rtl/*.sv]
analyze -format verilog -lib WORK [glob ../../rtl/*.v]

elaborate $top_module -lib WORK -update
current_design $top_module

# Link Design
link

# Default SDC Constraints
read_sdc ../constraints/${top_module}.sdc
propagate_constraints

current_design $top_module
set_cost_priority {max_transition max_fanout max_delay max_capacitance}
set_fix_multiple_port_nets -all -buffer_constants
set_fix_hold [all_clocks]

set_driving_cell -lib_cell BUF_X9M_A9TR -pin Y [all_inputs]
#set_load [get_attribute "$target_library/BUF_X9M_A9TR/A" fanout_load] [all_outputs]
foreach_in_collection p [all_outputs] {
	set_load 0.050 $p
}

#More compiler directives
set compile_effort   "low"
set_app_var ungroup_keep_original_design true
set_register_merging [get_designs $top_module] false
set compile_seqmap_propagate_constants false
set compile_seqmap_propagate_high_effort false
# More constraints and setup before compile
foreach_in_collection design [ get_designs "*" ] {
	current_design $design
	#feedthrough / outputs / constants
	set_fix_multiple_port_nets -all
}
current_design $top_module


# Compile
# Source user compile options
compile_ultra -exact_map

# Write Out Design - Hierarchical
current_design $top_module

change_names -rules verilog -hierarchy

write -format verilog -hier -output [format "../outputs/%s%s" $top_module .out.v]

# Write Reports
redirect [format "%s%s%s" ../reports/ $top_module _area.rep] { report_area }
redirect -append [format "%s%s%s" ../reports/ $top_module _area.rep] { report_reference }
redirect [format "%s%s%s" ../reports/ $top_module _power.rep] { report_power }
redirect [format "%s%s%s" ../reports/ $top_module _timing.rep] \
  { report_timing -path full -max_paths 100 -nets -transition_time -capacitance -significant_digits 3 -nosplit}

set inFile  [open ../reports/$top_module\_area.rep]
while { [gets $inFile line]>=0 } {
    if { [regexp {Total cell area:} $line] } {
        set AREA [lindex $line 3]
    }
}
close $inFile
set inFile  [open ../reports/$top_module\_power.rep]
while { [gets $inFile line]>=0 } {
    if { [regexp {Total Dynamic Power} $line] } {
        set PWR [lindex $line 4]
    } elseif { [regexp {Cell Leakage Power} $line] } {  
        set LEAK [lindex $line 4] 
    }
}
close $inFile

set unmapped_designs [get_designs -filter "is_unmapped == true" $top_module]
if {  [sizeof_collection $unmapped_designs] != 0 } {
	echo "****************************************************"
	echo "* ERROR!!!! Compile finished with unmapped logic.  *"
	echo "****************************************************"
}
# Done
sh date
sh uptime

# Done
echo "run.scr completed successfully"
