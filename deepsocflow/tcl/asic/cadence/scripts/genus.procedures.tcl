##############################################################################
# Project   : DeepSoCFlow CGRA4ML
# Script    : genus.procedures.tcl
# Purpose   : Utility procedures for Cadence Genus Stylus Common UI tool
##############################################################################
# Author    : Ravidu Munasinghe <raviduhm@gmail.com>
# Org       : Kastner Research Group | ENTC UoM
# Created   : 2026-05-14
# Modified  : 2026-06-14
##############################################################################
# Version   : 1.3
# Status    : In Progress
##############################################################################
#
# Description:
#   Reusable TCL procedure library sourced by Genus (synthesis). 
#   Provides logging, debug data dumps, stage tracking, cost group definitions,
#   and parallel report queuing under the `krg_` namespace prefix.
#
##############################################################################
# Procedures defined in this file:
#   krg_print_debug_data      - Dump variable/array values to a debug file
#   krg_message               - Formatted console messages (high/medium/low)
#   krg_reload_databases      - Reload defines and procedures  [DISABLED]
#   krg_reload_sdc            - Reload SDC constraint files    [DISABLED]
#   krg_define_cost_groups    - Define reg2reg/in2reg/reg2out/in2out cost groups
#   krg_start_stage           - Mark a new flow stage and log elapsed time
#   krg_report_setup_timing   - Return report_timing cmd string for setup (not executed)
#   krg_create_stage_reports  - Queue and execute all reports/DBs for a given stage
#                               Options: -write_design, -write_db, -write_snapshot,
#                               -report_setup, -check_drc,
#                               -check_connectivity, -report_datapath, -report_qor,
#                               -report_gates, -report_area, -check_design_rules,
#                               -report_multibit, -report_ple, -report_summary, -help
#                               -innovus_option (to be used with write_snapshot 
#                               after syn_opt stage)
#   krg_write_stage_outputs   - Write post-synthesis output files for the current stage
#                               Branches on phys_synth_type: floorplan writes LEC netlist,
#                               do_lec, netlist, SDC, SDF; else writes netlist, SDC, SDF
#   krg_report_debug_messages - Report all Genus messages and write unified metrics JSON
#   krg_create_sdc_file       - Generate SDC file (clocks, IO, DRV constraints)
#   krg_export_screenshot     - Highlight top-level hinsts with unique colors, build
#                               a color-keyed legend, and save floorplan + legend PNGs
#   krg_short_hinst_name      - Extract a short display name from a full hinst path string
##############################################################################
# TODO:
#   Minor Revisions
#   [X] Add a folder for each genus run and put new reports on it
#   [ ] Re-enable and test krg_reload_databases
#   [ ] Re-enable and test krg_reload_sdc
##############################################################################
# Usage:
#   This file is to use with cadence.cgra4ml.defines file
#   source cadence.procedures.tcl -quiet under cadence tools scripts
##############################################################################

###################################################
#          krg_print_debug_data
#          -------------
#   This is a command for printing variable values
#       to a file for easier debugging
###################################################
proc krg_print_debug_data {write_or_append {debug_file "debug.txt"} var_list dic_list} {

    set df [open $debug_file $write_or_append]
    puts $df "**********************************************************"
    puts $df "* All the available variables Cadence Tools going to use *"
    puts $df "**********************************************************"
    foreach var $var_list {
        global $var
        puts $df "$var = \t[set $var]"
    }

    foreach dic $dic_list {
        global $dic
        foreach key [array names $dic] {
        	puts $df "${dic}(${key}) = \t [set ${dic}([set key])]"  
        }
    }
    
    close $df
}

###################################################
#          krg_message
#          -------------
#   This is a command for printing messages to the
#       screen and log file
#   Importance high will print a bold message
#   Importance standard (default) will print an underlined message
#   Importance low will print a one line message
###################################################
proc krg_message {msg {importance low}} {
    set krg_message "krgINFO: $msg"
    set message_length [string length $krg_message]

    if {$importance=="high"} {
        puts [string repeat "*" [expr 10+$message_length]]
        puts [string repeat "*" [expr 10+$message_length]]
        puts "* $krg_message *"
        puts [string repeat "*" [expr 10+$message_length]]
        puts [string repeat "*" [expr 10+$message_length]]
        puts ""
    } elseif {$importance=="medium"} {
        puts [string repeat "-" $message_length]
        puts "$krg_message"
        puts [string repeat "-" $message_length]
        puts ""
    } elseif {$importance=="low"} {
        puts ""
        puts "$krg_message"
        puts ""
    } else {
        puts "krgINFO: Error - Incorrect usage of proc krg_message"
        puts "krgINFO: Correct usage:krg_message <message> high|medium|low"
    }
}

###################################################
#          krg_reload_databases
#          -------------
#   Reloads the defines and procedures
###################################################
# proc krg_reload_databases {} {
#     global design env
#     # Load general procedures
#     source ../../tcl/asic/scripts/procedures.tcl -quiet
#     # Load the specific definitions for this project
#     source ../../tcl/asic/inputs/$design(TOPLEVEL).defines -quiet
# }

###################################################
#          krg_reload_sdc
#          -------------
#   Reloads the SDC Files after modifying them
#       default is for all constraint modes
###################################################
# proc krg_reload_sdc {{constraint_mode all}} {
#     global design tech
#     if {$constraint_mode == "all"} {
#         set constraint_mode_list [get_db constraint_modes]
#     } else {
#         set constraint_mode_list "constraint_mode:$constraint_mode"
#     }
#     foreach cm $constraint_mode_list {
#         update_constraint_mode -name [get_db $cm .name] -sdc_files [get_db $cm .sdc_files]
#     }
# }

###################################################
#          krg_default_cost_groups
#          -------------
#   Defines default cost groups:
#     reg2reg, in2reg, reg2out, in2out
###################################################
proc krg_define_cost_groups {} {
    global design

    # Remove Default Cost Groups
    delete_obj [get_db cost_groups *]
    set design(cost_groups) ""

    # reg2reg
    define_cost_group -name reg2reg -design $design(TOPLEVEL)
    # path_group not compatible with innovus | syn_opt -spatial warning use group_path | PHYS-1019
    # path_group -from [all_registers] -to [all_registers] -group reg2reg -name reg2reg \
    #     -view $design(selected_setup_analysis_views)
    group_path -from [all_registers] -to [all_registers] -name reg2reg
    lappend design(cost_groups) "reg2reg"

    # in2reg
    define_cost_group -name in2reg -design $design(TOPLEVEL)
    # path_group not compatible with innovus | syn_opt -spatial warning use group_path | PHYS-1019
    # path_group -from [all_inputs] -to [all_registers] -group in2reg -name in2reg \
    #     -view $design(selected_setup_analysis_views)
    group_path -from [all_inputs] -to [all_registers] -name in2reg 
    lappend design(cost_groups) "in2reg"

    # reg2out
    define_cost_group -name reg2out -design $design(TOPLEVEL)
    # path_group not compatible with innovus | syn_opt -spatial warning use group_path | PHYS-1019
    # path_group -from [all_registers] -to [all_outputs] -group reg2out -name reg2out \
    #     -view $design(selected_setup_analysis_views)
    group_path -from [all_registers] -to [all_outputs] -name reg2out 
    lappend design(cost_groups) "reg2out"

    # in2out
    define_cost_group -name in2out -design $design(TOPLEVEL)
    # path_group not compatible with innovus | syn_opt -spatial warning use group_path | PHYS-1019
    # path_group -from [all_inputs] -to [all_outputs] -group in2out -name in2out \
    #     -view $design(selected_setup_analysis_views)
    group_path -from [all_inputs] -to [all_outputs] -name in2out 
    lappend design(cost_groups) "in2out"

}

###################################################
#          krg_start_stage
#          -------------
#   Starts a new stage in the flow
#       sets the this_run(stage) variable
#       also saves starting time of the stage
###################################################
proc krg_start_stage {stage {count yes}} {
    global design this_run

    if {$stage == ""} {
        krg_message "You have to define a stage for using the krg_start_stage procedure" medium
        return
    }

    # Print elapsed time of the previous stage
    if {[info exists this_run(stage)] && [info exists this_run($this_run(stage))]} {
        set prev_stage $this_run(stage)
        set elapsed [expr {[clock seconds] - $this_run($prev_stage)}]
        set h [expr {$elapsed / 3600}]
        set m [expr {($elapsed % 3600) / 60}]
        set s [expr {$elapsed % 60}]
        krg_message "Stage '$prev_stage' took: [format "%02d:%02d:%02d" $h $m $s] (hh:mm:ss)" medium
    }

    # Initialize counter on first call, then increment only when count is yes
    if {![info exists this_run(stage_count)]} {
        set this_run(stage_count) 0
    }
    if {$count eq "yes"} {
        incr this_run(stage_count)
    }

    set this_run(stage) $stage
    krg_message "Starting stage [format "%02d" $this_run(stage_count)]_$stage" high

    # Saving and printing the start time for the stage
    set systemTime [clock seconds]
    set formattedTime [clock format $systemTime -format %H:%M]
    set formattedDate [clock format $systemTime -format %d/%m/%Y]
    set stageTime "[clock format $systemTime -format %Y%m%d]_[clock format $systemTime -format %H%M%S]"
    krg_message "Current time is: $formattedDate $formattedTime" low
    set this_run($stage) $systemTime

    puts "------------------------------------------"
}

###################################################
#          krg_report_setup_timing
#          -------------
#   Reports timing and saves it in the 
#       appropriate directory
###################################################
proc krg_report_setup_timing {{reports_path "../asic/reports/cadence/"}} {
    global design this_run
    mkdir -pv ${reports_path}
    set_db timing_report_fields \
        "timing_point flags arc edge cell fanout transition delay arrival"

    foreach cg $design(cost_groups) {
        run_parallel_commands -queue "report_timing -max_paths 100 \
            -group [get_db cost_groups -match $cg] \
            > ${reports_path}/${cg}.setup.timing.rpt" -priority 4
    }
}


###################################################
#          krg_create_stage_reports
#          -------------
#   Created all the appropritate reports for the 
#       current design stage
###################################################
proc krg_create_stage_reports {{args ""}} {
    global design this_run
    array set options {
        -write_design          no
        -write_db              no
        -innovus_option        no
        -write_snapshot        no
        -report_setup          no 
        -check_drc             no 
        -check_connectivity    no  
        -report_datapath       no
        -report_qor            no
        -report_gates          no
        -report_area           no
        -check_design_rules    no
        -report_summary        no
        -report_multibit       no
        -report_ple            no
        -help                  0   }

    while {[llength $args]} {
        switch -glob -- [lindex $args 0] {
            -*write_design*    {set args [lassign $args - options(-write_design)]}
            -*write_db*        {set args [lassign $args - options(-write_db)]}
            -*innovus_option*  {set args [lassign $args - options(-innovus_option)]}
            -*snapshot*        {set args [lassign $args - options(-write_snapshot)]}
            -*setup*           {set args [lassign $args - options(-report_setup)]}
            -*drc*             {set args [lassign $args - options(-check_drc)]}
            -*conn*            {set args [lassign $args - options(-check_connectivity)]}
            -*datapath*        {set args [lassign $args - options(-report_datapath)]}
            -*qor*             {set args [lassign $args - options(-report_qor)]}
            -*gates*           {set args [lassign $args - options(-report_gates)]}
            -*area*            {set args [lassign $args - options(-report_area)]}
            -*design_rule*     {set args [lassign $args - options(-check_design_rules)]}
            -*summary*         {set args [lassign $args - options(-report_summary)]}
            -*multibit*        {set args [lassign $args - options(-report_multibit)]}
            -*ple*             {set args [lassign $args - options(-report_ple)]}
            -*help*            {set args [lassign $args - options(-help)]; set args [lrange $args 1 end]}
            default break
        }
    }

    set stage_prefix [format "%02d" $this_run(stage_count)]_$this_run(stage)

    krg_message "Starting to create reports for stage: $stage_prefix" medium

    set active_dbs_dir $design(dbs_syn_dir)
    set active_rpt_dir $design(reports_syn_dir)

    mkdir -pv $active_dbs_dir
    mkdir -pv $active_rpt_dir

    if { $options(-write_design) eq "yes" } {
        krg_message "Starting to write genus design for stage: $this_run(stage)" low
        set dbs_proc_dir $active_dbs_dir/$this_run(stage)/design
        mkdir -pv $dbs_proc_dir
        run_parallel_commands -queue "write_design -basename $dbs_proc_dir/$this_run(stage)" -priority 5
        krg_message "Added to parallel commands queue, write design for stage: $this_run(stage)" low
    }

    if { $options(-write_db) eq "yes" } {
        krg_message "Starting to create genus databases for stage: $this_run(stage)" low
        set dbs_proc_dir $active_dbs_dir/$this_run(stage)/db
        mkdir -pv $dbs_proc_dir
        run_parallel_commands -queue "write_db -common -all_root_attributes $dbs_proc_dir/$this_run(stage).db" -priority 5
        krg_message "Added to parallel commands queue, genus databases for stage: $this_run(stage)" low
    }

    if {  $options(-write_snapshot) eq "yes" } {
        if { $options(-innovus_option) eq "yes" } {
            krg_message "Starting to create innovus snapshot for stage: $this_run(stage)" low
            set dbs_proc_dir $active_dbs_dir/$this_run(stage)/snapshot
            mkdir -pv $dbs_proc_dir
            write_snapshot -innovus -outdir $dbs_proc_dir -tag $this_run(stage)
            krg_message "Completed innovus snapshot for stage: $this_run(stage)" low
        } else {
            krg_message "Starting to create genus snapshot for stage: $this_run(stage)" low
            set dbs_proc_dir $active_dbs_dir/$this_run(stage)/snapshot
            mkdir -pv $dbs_proc_dir
            write_snapshot -outdir $dbs_proc_dir -tag $this_run(stage)
            krg_message "Completed genus snapshot for stage: $this_run(stage)" low
        }
    }

    if { $options(-report_setup) eq "yes" } {
        krg_message "Starting to create setup timing reports for stage: $this_run(stage)" low
        krg_report_setup_timing $active_rpt_dir/[format "%02d" $this_run(stage_count)]_$this_run(stage)_timing
        krg_message "Added to parallel commands queue, setup timing reports for stage: $this_run(stage)" low
    }

    if { $options(-check_drc) eq "yes" } {
        krg_message "Starting to create DRC reports for stage: $this_run(stage)" low
        set rpt_proc_dir $active_rpt_dir
        run_parallel_commands -queue "check_drc -out_file $rpt_proc_dir/${stage_prefix}_drc_report.rpt" -priority 3
        krg_message "Added to parallel commands queue, DRC reports for stage: $this_run(stage)" low
    }

    if { $options(-check_connectivity) eq "yes" } {
        krg_message "Starting to create connectivity reports for stage: $this_run(stage)" low
        set rpt_proc_dir $active_rpt_dir
        run_parallel_commands -queue "check_connectivity > $rpt_proc_dir/${stage_prefix}_connectivity.rpt" -priority 2
        krg_message "Added to parallel commands queue, connectivity reports for stage: $this_run(stage)" low
    }

    if { $options(-report_datapath) eq "yes" } {
        krg_message "Starting to create datapath reports for stage: $this_run(stage)" low
        set rpt_proc_dir $active_rpt_dir
        run_parallel_commands -queue "report_dp > $rpt_proc_dir/${stage_prefix}_datapath.rpt" -priority 1
        krg_message "Added to parallel commands queue, datapath reports for stage: $this_run(stage)" low
    }

    if { $options(-report_qor) eq "yes" } {
        krg_message "Starting to create QoR reports for stage: $this_run(stage)" low
        set rpt_proc_dir $active_rpt_dir
        run_parallel_commands -queue "report_qor > $rpt_proc_dir/${stage_prefix}_qor.rpt" -priority 1
        krg_message "Added to parallel commands queue, QoR reports for stage: $this_run(stage)" low
    }

    if { $options(-report_gates) eq "yes" } {
        krg_message "Starting to create gates reports for stage: $this_run(stage)" low
        set rpt_proc_dir $active_rpt_dir
        run_parallel_commands -queue "report_gates > $rpt_proc_dir/${stage_prefix}_gates.rpt" -priority 1
        run_parallel_commands -queue "report_gates -yield > $rpt_proc_dir/${stage_prefix}_gates_yield.rpt" -priority 1
        krg_message "Added to parallel commands queue, gates reports for stage: $this_run(stage)" low
    }

    if { $options(-report_area) eq "yes" } {
        krg_message "Starting to create area reports for stage: $this_run(stage)" low
        set rpt_proc_dir $active_rpt_dir
        run_parallel_commands -queue "report_area > $rpt_proc_dir/${stage_prefix}_area.rpt" -priority 1
        krg_message "Added to parallel commands queue, area reports for stage: $this_run(stage)" low
    }

    if { $options(-check_design_rules) eq "yes" } {
        krg_message "Starting to create design rules reports for stage: $this_run(stage)" low
        set rpt_proc_dir $active_rpt_dir
        run_parallel_commands -queue "report_design_rules > $rpt_proc_dir/${stage_prefix}_design_rules.rpt" -priority 1
        krg_message "Added to parallel commands queue, design rules reports for stage: $this_run(stage)" low
    }

    if { $options(-report_multibit) eq "yes" } {
        krg_message "Starting to create multibit inferencing reports for stage: $this_run(stage)" low
        set rpt_proc_dir $active_rpt_dir
        run_parallel_commands -queue "report_multibit_inferencing -reason_not_merged all > $rpt_proc_dir/${stage_prefix}_multibit.rpt" -priority 1
        krg_message "Added to parallel commands queue, multibit inferencing reports for stage: $this_run(stage)" low
    }

    if { $options(-report_ple) eq "yes" } {
        krg_message "Starting to create PLE reports for stage: $this_run(stage)" low
        set rpt_proc_dir $active_rpt_dir
        run_parallel_commands -queue "report_ple > $rpt_proc_dir/${stage_prefix}_ple.rpt" -priority 1
        krg_message "Added to parallel commands queue, PLE reports for stage: $this_run(stage)" low
    }

    if { $options(-report_summary) eq "yes" && $options(-write_snapshot) eq "yes" } {
        krg_message "Starting to create QoR summary reports for stage: $this_run(stage)" low
        set rpt_proc_dir $active_rpt_dir
        run_parallel_commands -queue "report_summary -directory $rpt_proc_dir/${stage_prefix}_summary.rpt" -priority 1
        krg_message "Added to parallel commands queue, QoR summary reports for stage: $this_run(stage)" low
    } elseif { $options(-report_summary) eq "yes" } {
        krg_message "Cannot generate summary report: both -report_summary and -write_snapshot must be set to yes" medium
    }
    
    if {$options(-help)} {
        puts ""
        puts "Usage: krg_create_stage_reports \[options\]"
        puts ""
        puts "Options (value: yes|no):"
        puts "  -write_design       yes|no   Write Genus design (netlist+constraints) (default: yes)"
        puts "  -write_db           yes|no   Write Stylus DB for current stage        (default: yes)"
        puts "  -write_snapshot     yes|no   Write Innovus snapshot for current stage  (default: yes)"
        puts "  -report_setup       yes|no   Generate per-cost-group setup timing rpt  (default: no)"
        puts "  -check_drc          yes|no   Run DRC check and save report             (default: no)"
        puts "  -check_connectivity yes|no   Run connectivity check and save report    (default: no)"
        puts "  -report_datapath    yes|no   Generate datapath report                  (default: no)"
        puts "  -report_qor         yes|no   Generate QoR report                       (default: no)"
        puts "  -report_gates       yes|no   Generate gates report                     (default: no)"
        puts "  -report_area        yes|no   Generate area report                      (default: no)"
        puts "  -check_design_rules yes|no   Run design rules check and save report    (default: no)"
        puts "  -report_multibit    yes|no   Generate multibit inferencing report      (default: no)"
        puts "  -report_ple         yes|no   Generate PLE report                       (default: no)"
        puts "  -report_summary     yes|no   Generate summary report                   (default: no)"
        puts "                               NOTE: requires -write_snapshot yes"
        puts "  -help               1        Print this help message"
        puts ""
        puts "Example:"
        puts "  krg_create_stage_reports -report_setup yes -report_qor yes"
        puts ""
        return
    }
    
    krg_message "Start Executing Commands Queue" medium
    run_parallel_commands -execute -prefix "${stage_prefix}_" -log_dir $design(workdir)
    krg_message "Completed Executing Commands Queue" medium
}

###################################################
#          krg_write_stage_outputs
#          -------------
#   Writes post-synthesis output files for the
#       current design stage: netlists, SDC, SDF,
#       and LEC do files
#   Branches on phys_synth_type:
#       floorplan - writes LEC netlist, do_lec,
#                   netlist, SDC, SDF (ispatial)
#       else      - writes netlist, SDC, SDF
###################################################
proc krg_write_stage_outputs {} {
    global design this_run phys_synth_type

    set stage_prefix [format "%02d" $this_run(stage_count)]_$this_run(stage)

    if { $phys_synth_type eq "floorplan" } {
        krg_message "Starting to write output files for stage: $this_run(stage)_ispatial" medium

        krg_message "Starting to write LEC netlist for stage: $this_run(stage)" low
        run_parallel_commands -queue "write_netlist -lec $design(TOPLEVEL) > $design(postsyn_lec_netlist_ispatial)" -priority 5
        krg_message "Added to parallel commands queue, LEC netlist for stage: $this_run(stage)" low

        krg_message "Starting to write LEC do file for stage: $this_run(stage)" low
        run_parallel_commands -queue "write_do_lec -golden_design fv_map -revised_design $design(postsyn_lec_netlist_ispatial) -logfile $design(conformal_dir)/fvmap2netlist.lec.log > $design(conformal_dir)/fvmap2netlist.lec.tcl" -priority 4
        krg_message "Added to parallel commands queue, LEC do file for stage: $this_run(stage)" low

        krg_message "Starting to write netlist for stage: $this_run(stage)" low
        run_parallel_commands -queue "write_netlist $design(TOPLEVEL) > $design(postsyn_netlist_rtl_flow)" -priority 5
        krg_message "Added to parallel commands queue, netlist for stage: $this_run(stage)" low

        krg_message "Starting to write SDC for stage: $this_run(stage)" low
        run_parallel_commands -queue "write_sdc -view wc_analysis_view $design(TOPLEVEL) > $design(postsyn_sdc_ispatial)" -priority 3
        krg_message "Added to parallel commands queue, SDC for stage: $this_run(stage)" low

        krg_message "Starting to write SDF for stage: $this_run(stage)" low
        run_parallel_commands -queue "write_sdf > $design(postsyn_sdf_ispatial)" -priority 3
        krg_message "Added to parallel commands queue, SDF for stage: $this_run(stage)" low
    } else {
        krg_message "Starting to write output files for stage: $this_run(stage)_rtl_floorplanning" medium
 
        krg_message "Starting to write netlist for stage: $this_run(stage)" low
        run_parallel_commands -queue "write_netlist $design(TOPLEVEL) > $design(postsyn_netlist_rtl_flow)" -priority 5
        krg_message "Added to parallel commands queue, netlist for stage: $this_run(stage)" low

        krg_message "Starting to write SDC for stage: $this_run(stage)" low
        run_parallel_commands -queue "write_sdc -view wc_analysis_view $design(TOPLEVEL) > $design(postsyn_sdc_rtl_flow)" -priority 3
        krg_message "Added to parallel commands queue, SDC for stage: $this_run(stage)" low

        krg_message "Starting to write SDF for stage: $this_run(stage)" low
        run_parallel_commands -queue "write_sdf > $design(postsyn_sdf_rtl_flow)" -priority 3
        krg_message "Added to parallel commands queue, SDF for stage: $this_run(stage)" low
    }

    krg_message "Start Executing Commands Queue" medium
    run_parallel_commands -execute -prefix "${stage_prefix}_" -log_dir $design(workdir)
    krg_message "Completed Executing Commands Queue" medium
}

###################################################
#          krg_report_debug_messages
#          -------------
#   Reports all Genus messages to separate files
#       and writes the unified metrics JSON for
#       cross-run comparison
###################################################
proc krg_report_debug_messages {} {
    global design this_run genus_run_counter

    set stage_prefix [format "%02d" $this_run(stage_count)]_$this_run(stage)
    krg_message "Starting to report debug messages for stage: $stage_prefix" medium

    mkdir -pv $design(compare_dir)
    mkdir -pv $design(messages_dir)

    run_parallel_commands -queue "report_messages -all                > $design(messages_dir)/$design(TOPLEVEL)_genus_run_[format "%02d" $genus_run_counter]_messages_all.rpt"                -priority 1
    run_parallel_commands -queue "report_messages -include_suppressed > $design(messages_dir)/$design(TOPLEVEL)_genus_run_[format "%02d" $genus_run_counter]_messages_include_suppressed.rpt" -priority 1
    run_parallel_commands -queue "report_messages -errors             > $design(messages_dir)/$design(TOPLEVEL)_genus_run_[format "%02d" $genus_run_counter]_messages_errors.rpt"             -priority 1
    run_parallel_commands -queue "report_messages -warnings           > $design(messages_dir)/$design(TOPLEVEL)_genus_run_[format "%02d" $genus_run_counter]_messages_warnings.rpt"           -priority 1
    run_parallel_commands -queue "report_messages -info               > $design(messages_dir)/$design(TOPLEVEL)_genus_run_[format "%02d" $genus_run_counter]_messages_info.rpt"               -priority 1
    run_parallel_commands -queue "write_metric    -format json        -out_file $design(compare_dir)/$design(TOPLEVEL)_metrics_genus_run_[format "%02d" $genus_run_counter].json" -priority 1
    run_parallel_commands -execute -prefix "${stage_prefix}_" -log_dir $design(workdir)

    krg_message "Completed reporting debug messages for stage: $stage_prefix" medium
}

###################################################
#          krg_create_sdc_file
#          -------------
#   This is a command for create sdc file 
###################################################
proc krg_create_sdc_file {} {
    global design tech

    set df [open $design(functional_sdc) "w"]

    puts $df "#################################"
    puts $df "#       Clock Constraints       #"
    puts $df "#################################"
    puts $df "# Create Clocks"
    if {$design(MULTI_CLOCK_DESIGN) == "yes"} {
        foreach cname $design(clock_list) cport $design(clock_port_list) cperiod $design(clock_period_list) {
            puts $df "create_clock -period $cperiod -name $cname [get_ports $cport]"
            puts $df "set_clock_uncertainty \$design(CLOCK_UNCERTAINTY) $cname"
        }
    } else {
        puts $df {create_clock -period $design(clock_period_list) -name $design(clock_list) [get_ports $design(clock_port_list)]}
        puts $df {set_clock_uncertainty $design(CLOCK_UNCERTAINTY) $design(clock_list)}
    }

    puts $df {set_ideal_network [get_ports $design(clock_port_list)]}
    puts $df "\n"

    puts $df "#################################"
    puts $df "#       IO Constraints          #"
    puts $df "#################################"
    puts $df "set_input_delay -clock \$design(CLK_NAME) \$design(INPUT_DELAY) \\"
    puts $df {       [remove_from_collection [all_inputs] [list $design(CLK_PORT)]]}
    puts $df {set_output_delay -clock $design(CLK_NAME) $design(OUTPUT_DELAY) [all_outputs]}

    puts $df "\n"

    if {$design(FULLCHIP_OR_MACRO) == "FULLCHIP"} {
        puts $df {set tech(SDC_LOAD_VALUE) $tech(EXTERNAL_SDC_LOAD)}
    } else {
        puts $df {set tech(SDC_LOAD_VALUE) [lindex [get_db [get_lib_pins $tech(SDC_LOAD_PIN)] .capacitance] 0]}
    }
    puts $df "set_load                \[expr \$tech(SDC_LOAD_VALUE)*20\]        \[all_outputs\]"
    puts $df {set_input_transition    $design(INPUT_TRANSITION)                  [all_inputs]}
    puts $df {set_driving_cell        -lib_cell $tech(SDC_DRIVING_CELL)          [all_inputs]}

    puts $df "\n"

    puts $df "#################################"
    puts $df "#       DRV Constraints         #"
    puts $df "#################################"
    # puts $df {set_max_fanout         $design(MAX_FANOUT)                   [current_design]}
    puts $df {set_max_transition     $design(MAX_TRANSITION)               [current_design]}
    # puts $df {set_max_capacitance    $design(MAX_CAPACITANCE)              [current_design]}

    puts $df "\n"

    puts $df "#################################"
    puts $df "#      Design Constraints       #"
    puts $df "#################################"
    puts $df "foreach srams \$design(DMA_SRAM_LIST) \{  "
    puts $df "    set_disable_timing \$srams -from \[get_db \$srams .pins -if \{.base_name == CLKA\}\] -to \[get_db \$srams .pins -if \{.base_name == CLKB\}\]"
    puts $df "    set_disable_timing \$srams -from \[get_db \$srams .pins -if \{.base_name == CLKA\}\] -to \[get_db \$srams .pins -if \{.base_name == CLKB\}\]"
    puts $df "\}"
    close $df
}

###################################################
#          krg_export_screenshot
#          -------------
#   Highlights all top-level hierarchical instances
#       in the Genus GUI with unique colors,
#       builds a color-keyed legend, and saves two
#       snapshots: floorplan view and legend view.
###################################################
proc krg_export_screenshot {} {
    global design genus_run_counter

    krg_message "Opening GUI and Capture a screenshot of floorplan with ispatial placement" medium
    gui_show
    gui_zoom_fit_pv

    set list_hier_inst [lsearch -all -inline -not -glob [get_db designs .hinsts] "*/DW_genblk2*"]

    set color_palette {red blue green yellow magenta cyan lightpink purple teal olive plum navy pink lime orange brown lightblue gold chocolate lightgreen maroon}
    set n_colors [llength $color_palette]

    set color_list {}
    for {set i 0} {$i < [llength $list_hier_inst]} {incr i} {
        lappend color_list [lindex $color_palette [expr {$i % $n_colors}]]
    }

    set legend_list {}
    set i 0
    foreach hier_inst $list_hier_inst {
        gui_highlight_pv -append -color [lindex $color_list $i] $hier_inst
        lappend legend_list [list [lindex $color_list $i] [krg_short_hinst_name $hier_inst]]
        incr i
    }

    gui_legend -physical -title Legend $legend_list

    gui_snapshot_pv -width 1920 -height 1080 \
        -png $design(compare_dir)/$design(TOPLEVEL)_floorplan_genus_run_[format "%02d" $genus_run_counter].png

    gui_snapshot_pv -legend -width 1920 -height 1080 \
        -png $design(compare_dir)/$design(TOPLEVEL)_legend_genus_run_[format "%02d" $genus_run_counter].png
    
    krg_message "Captured a screenshot of floorplan with ispatial placement" medium
}

###################################################
#          krg_short_hinst_name
#          -------------
#   Extracts a short display name from a full
#       hierarchical instance path string.
#   Returns "" for sub-instances (skipped).
###################################################
proc krg_short_hinst_name {hinst} {
    set inst [regsub {^hinst:[^/]+/} $hinst ""]
    if {[string match "*/*" $inst]} { return "" }
    # string first is more reliable than regsub for _DW_ stripping in Genus Tcl
    set dw_idx [string first "_DW_" $inst]
    if {$dw_idx >= 0} {
        set inst [string range $inst 0 [expr {$dw_idx - 1}]]
    } else {
        regsub {\.[^.]+$} $inst inst
    }
    set tok [split $inst "_"]
    set n   [llength $tok]
    return  [join [lrange $tok [expr {max(0, $n-2)}] end] "_"]
}