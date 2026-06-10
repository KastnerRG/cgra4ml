# This file has procedures for working with Stylus Common UI tools
###################################################
#          krg_print_debug_data
#          -------------
#   This is a command for printing variable values
#       to a file for easier debugging
###################################################
proc krg_print_debug_data {write_or_append {debug_file "debug.txt"} this_file var_list dic_list} {
    #global design tech tech_files env

    set df [open $debug_file $write_or_append]
    puts $df "*************************************************************"
    puts $df "* Values loaded from $debug_file $this_file *"
    puts $df "*************************************************************"
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
#     global design tech runtype
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
proc krg_default_cost_groups {} {
    global runtype design
    if { $runtype == "synthesis" } {
        # reg2reg
        define_cost_group -name reg2reg -design $design(TOPLEVEL)
        path_group -from [all_registers] -to [all_registers] -group reg2reg -name reg2reg \
            -view $design(selected_setup_analysis_views)
        lappend design(cost_groups) "reg2reg"
        # in2reg
        define_cost_group -name in2reg -design $design(TOPLEVEL)
        path_group -from [all_inputs] -to [all_registers] -group in2reg -name in2reg \
            -view $design(selected_setup_analysis_views)
        lappend design(cost_groups) "in2reg"
        # reg2out
        define_cost_group -name reg2out -design $design(TOPLEVEL)
        path_group -from [all_registers] -to [all_outputs] -group reg2out -name reg2out \
            -view $design(selected_setup_analysis_views)
        lappend design(cost_groups) "reg2out"
        # in2out
        define_cost_group -name in2out -design $design(TOPLEVEL)
        path_group -from [all_inputs] -to [all_outputs] -group in2out -name in2out \
            -view $design(selected_setup_analysis_views)
        lappend design(cost_groups) "in2out"
    } elseif { $runtype == "pnr" } {
        # create_basic_path_groups -expanded
        # lappend design(cost_groups) "reg2reg"
        # lappend design(cost_groups) "in2reg"
        # lappend design(cost_groups) "reg2out"
        # lappend design(cost_groups) "in2out"
    }
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
        krg_message "You have to define a stage for using the krg_start_stage procedure"
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
    krg_message "Current time is: $formattedDate $formattedTime"
    set this_run($stage) $systemTime

    krg_message "------------------------------------"
}

###################################################
#          krg_report_timing
#          -------------
#   Reports timing and saves it in the 
#       appropriate directory
###################################################
proc krg_report_setup_timing {{reports_path "../asic/reports/cadence/"}} {
    global design runtype this_run
    mkdir -pv ${reports_path}/$this_run(stage)/
    set_db timing_report_fields \
        "timing_point flags arc edge cell fanout transition delay arrival"

    foreach cg $design(cost_groups) {
        if {$runtype == "synthesis"} {
            # Add report_timing -fields column_list
            report_timing -max_paths 100 -group [get_db cost_groups -match $cg] \
                > "${reports_path}/$this_run(stage)/${cg}.setup.timing.rpt"
        } elseif {$runtype == "pnr"} {
            report_timing -max_paths 100 -group $cg \
                > "${reports_path}/$this_run(stage)/${cg}.setup.timing.rpt"
        }
    }
}

###################################################
#          krg_report_hold_timing
#          -------------
#   Reports hold timing and saves it in the 
#       appropriate directory
###################################################
proc krg_report_hold_timing {{reports_path "../../tcl/asic/reports/cadence"}} {
    global design runtype this_run
    mkdir -pv ${reports_path}/$this_run(stage)/
    set_db timing_report_fields \
        "timing_point flags arc edge cell fanout transition delay arrival"

    foreach cg $design(cost_groups) {
        if {$runtype == "synthesis"} {
        report_timing -early -max_paths 100 -group [get_db cost_groups -match $cg] \
            > "${reports_path}/$this_run(stage)/${cg}.hold.timing.rpt"
        } elseif {$runtype == "pnr"} {
        report_timing -early -max_paths 100 -group $cg \
            > "${reports_path}/$this_run(stage)/${cg}.hold.timing.rpt"
        }
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
        -write_db           yes 
        -write_snapshot     yes
        -report_setup       no 
        -report_hold        no
        -check_drc          no 
        -check_connectivity no  
        -report_datapath    no
        -report_qor         no
        -report_gates       no
        -report_area        no
        -check_design_rules no
        -report_memory      no
        -help               0   }

    while {[llength $args]} {
        switch -glob -- [lindex $args 0] {
            -*write_db*     {set args [lassign $args - options(-write_db)]}
            -*snapshot*     {set args [lassign $args - options(-write_snapshot)]}
            -*setup*        {set args [lassign $args - options(-report_setup)]}
            -*hold*         {set args [lassign $args - options(-report_hold)]}
            -*drc*          {set args [lassign $args - options(-check_drc)]}
            -*conn*         {set args [lassign $args - options(-check_connectivity)]}
            -*datapath*     {set args [lassign $args - options(-report_datapath)]}
            -*qor*          {set args [lassign $args - options(-report_qor)]}
            -*gates*        {set args [lassign $args - options(-report_gates)]}
            -*area*         {set args [lassign $args - options(-report_area)]}
            -*design_rule*  {set args [lassign $args - options(-check_design_rules)]}
            -*memory*       {set args [lassign $args - options(-report_memory)]}
            -*help*         {set args [lassign $args - options(-help)]; set args [lrange $args 1 end]}
            default break
        }
    }

    set stage_prefix [format "%02d" $this_run(stage_count)]_$this_run(stage)

    krg_message "Starting to create reports for stage: $stage_prefix" medium

    if { $options(-write_db) eq "yes" } {
        krg_message "Starting to create genus databases for stage: $this_run(stage)" low
        mkdir -pv $design(dbs_dir)/$runtype
        set dbs_proc_dir $design(dbs_dir)/$runtype/$this_run(stage).stylus.enc
        write_db -common $dbs_proc_dir
        krg_message "Completed genus databases for stage: $this_run(stage)" low
    }

    if { $options(-write_snapshot) eq "yes" } {
        krg_message "Starting to create innovus snapshot for stage: $this_run(stage)" low
        mkdir -pv $design(dbs_dir)/$runtype
        set dbs_proc_dir $design(dbs_dir)/$runtype
        write_snapshot -innovus -outdir $dbs_proc_dir -tag $this_run(stage)
        krg_message "Completed innovus snapshot for stage: $this_run(stage)" low
    }

    if { $options(-report_setup) eq "yes" } {
        krg_message "Starting to create setup timing reports for stage: $this_run(stage)" low
        mkdir -pv $design(reports_dir)/$runtype
        set rpt_proc_dir $design(reports_dir)/$runtype
        krg_report_setup_timing $rpt_proc_dir
        krg_message "Completed setup timing reports for stage: $this_run(stage)" low
    }

    if { $options(-report_hold) eq "yes" } {
        krg_message "Starting to create hold timing reports for stage: $this_run(stage)" low
        mkdir -pv $design(reports_dir)/$runtype
        set rpt_proc_dir $design(reports_dir)/$runtype
        krg_report_hold_timing $rpt_proc_dir
        krg_message "Completed hold timing reports for stage: $this_run(stage)" low
    }

    if { $options(-check_drc) eq "yes" } {
        krg_message "Starting to create DRC reports for stage: $this_run(stage)" low
        mkdir -pv $design(reports_dir)/$runtype
        set rpt_proc_dir $design(reports_dir)/$runtype
        check_drc -out_file $rpt_proc_dir/${stage_prefix}_drc_report.rpt
        krg_message "Completed DRC reports for stage: $this_run(stage)" low
    }

    if { $options(-check_connectivity) eq "yes" } {
        krg_message "Starting to create connectivity reports for stage: $this_run(stage)" low
        mkdir -pv $design(reports_dir)/$runtype
        set rpt_proc_dir $design(reports_dir)/$runtype
        check_connectivity > $rpt_proc_dir/${stage_prefix}_connectivity.rpt
        krg_message "Completed connectivity reports for stage: $this_run(stage)" low
    }

    if { $options(-report_datapath) eq "yes" } {
        krg_message "Starting to create datapath reports for stage: $this_run(stage)" low
        mkdir -pv $design(reports_dir)/$runtype
        set rpt_proc_dir $design(reports_dir)/$runtype
        report_dp > $rpt_proc_dir/${stage_prefix}_datapath.rpt
        krg_message "Completed datapath reports for stage: $this_run(stage)" low
    }

    if { $options(-report_qor) eq "yes" } {
        krg_message "Starting to create QoR reports for stage: $this_run(stage)" low
        mkdir -pv $design(reports_dir)/$runtype
        set rpt_proc_dir $design(reports_dir)/$runtype
        report_qor > $rpt_proc_dir/${stage_prefix}_qor.rpt
        krg_message "Completed QoR reports for stage: $this_run(stage)" low
    }

    if { $options(-report_gates) eq "yes" } {
        krg_message "Starting to create gates reports for stage: $this_run(stage)" low
        mkdir -pv $design(reports_dir)/$runtype
        set rpt_proc_dir $design(reports_dir)/$runtype
        report_gates > $rpt_proc_dir/${stage_prefix}_gates.rpt
        krg_message "Completed gates reports for stage: $this_run(stage)" low
    }

    if { $options(-report_area) eq "yes" } {
        krg_message "Starting to create area reports for stage: $this_run(stage)" low
        mkdir -pv $design(reports_dir)/$runtype
        set rpt_proc_dir $design(reports_dir)/$runtype
        report_area > $rpt_proc_dir/${stage_prefix}_area.rpt
        krg_message "Completed area reports for stage: $this_run(stage)" low
    }

    if { $options(-check_design_rules) eq "yes" } {
        krg_message "Starting to create design rules reports for stage: $this_run(stage)" low
        mkdir -pv $design(reports_dir)/$runtype
        set rpt_proc_dir $design(reports_dir)/$runtype
        report_design_rules > $rpt_proc_dir/${stage_prefix}_design_rules.rpt
        krg_message "Completed design rules reports for stage: $this_run(stage)" low
    }

    if { $options(-report_memory) eq "yes" } {
        krg_message "Starting to create design rules reports for stage: $this_run(stage)" low
        mkdir -pv $design(reports_dir)/$runtype
        set rpt_proc_dir $design(reports_dir)/$runtype
        report_memory > $rpt_proc_dir/${stage_prefix}_memory_utilization.rpt
        krg_message "Completed design rules reports for stage: $this_run(stage)" low
    }
    write_report is needed before report_summary
    run_parallel_commands -queue...... not working for write_snapshot write_reports reprot_runtime
    if {$options(-help)} {
        help
    }
}

###################################################
#          krg_create_sdc_file
#          -------------
#   This is a command for create sdc file depends 
#       on synthesis or pnr
###################################################
proc krg_create_sdc_file {} {
    global design tech runtype

    set df [open $design(functional_sdc) "w"]

    puts $df "#################################"
    puts $df "#       Clock Constraints       #"
    puts $df "#################################"
    puts $df "# Create Clocks"
    if {$design(MULTI_CLOCK_DESIGN) == "yes"} {
        foreach cname $design(clock_list) cport $design(clock_port_list) cperiod $design(clock_period_list){
            puts $df "create_clock -period $cperiod -name $cname [get_ports $cport]"
            puts $df "set_clock_uncertainty \$design(CLOCK_UNCERTAINTY) $cname"
        }
    } else {
        puts $df {create_clock -period $design(clock_period_list) -name $design(clock_list) [get_ports $design(clock_port_list)]}
        puts $df {set_clock_uncertainty $design(CLOCK_UNCERTAINTY) $design(clock_list)}
    }
    puts $df {set_false_path    [get_ports $design(RST_PORT)]}
    puts $df "\n"

    if {$runtype == "synthesis"} {
        puts $df {set_ideal_network [get_ports $design(clock_port_list)]}
        puts $df "\n"
    }


    puts $df "#################################"
    puts $df "#       IO Constraints          #"
    puts $df "#################################"
    puts $df {set_input_delay -clock $design(CLK_NAME) $design(INPUT_DELAY) \ }
    puts $df {       [remove_from_collection [all_inputs] $design(CLK_PORT) $design(RST_PORT)]}
    puts $df {set_output_delay -clock $design(CLK_NAME) $design(OUTPUT_DELAY) [all_outputs]}

    puts $df "\n"

    if {$design(FULLCHIP_OR_MACRO) == "FULLCHIP"} {
        puts $df {set tech(SDC_LOAD_VALUE) $tech(EXTERNAL_SDC_LOAD)}
    } else {
        puts $df {set tech(SDC_LOAD_VALUE) [lindex [get_db [get_lib_pins $tech(SDC_LOAD_PIN)] .capacitance] 0]}
    }
    puts $df {set_load                $tech(SDC_LOAD_VALUE)                      [all_outputs]}
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
    puts $df "foreach srams \$design(SRAM_LIST_FULL) \{  "
    puts $df {    set_disable_timing $srams -from [get_db $srams .pins -if {.base_name == CLKA}] -to [get_db $srams .pins -if {.base_name == CLKB}] }
    puts $df "    set_disable_timing \$srams -from [get_db \$srams .pins -if {.base_name == CLKA}] -to [get_db \$srams .pins -if {.base_name == CLKB}] \} "
    close $df
}