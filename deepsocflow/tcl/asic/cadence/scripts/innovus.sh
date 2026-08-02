#!/usr/bin/env bash
# Usage:
#   bash <path_to>/innovus.sh [--no-abort] [--run <n>] [--genus-run <n>]
#                              [--phys-synth-type <type>] [--overwrite]
#                              [--metrics-compare]
#
# Options:
#   --no-abort         Drop into the Innovus interactive prompt on error instead of
#                      exiting — useful for debugging mid-flow. Script returns to
#                      the scripts folder automatically when you exit Innovus.
#   --run <n>          Set innovus_run_counter to <n>. Innovus runs inside:
#                      cgra4ml/run/work/innovus/innovus_run_<nn>
#                      Aborts if the folder already exists (use --overwrite to skip).
#                      (default: 00)
#   --genus-run <n>    Set genus_run_counter to <n>. Pulls synthesis netlist/DB
#                      paths from genus_run_<nn> (default: 0)
#   --phys-synth-type <type>
#                      Set PHYS_SYNTH_TYPE for innovus.tcl (default: lef).
#                      "lef"       - RTL floorplan flow with iSpatial
#                      "floorplan" - iSpatial flow with DEF input
#   --overwrite        Allow reuse of an existing innovus_run_<nn> folder instead of
#                      aborting. Use with caution — previous results will be mixed
#                      with new outputs.
#   --metrics-compare  Run innovus_metrics_compare.tcl in batch mode instead of the
#                      normal P&R flow.
#                      Compares runs 1..INNOVUS_RUN_COUNTER (set via --run).
#                      Runs inside a scratch folder
#                      (cgra4ml/run/work/innovus/innovus_metrics_compare_tmp)
#                      that is deleted automatically once Innovus exits.
#                      --overwrite is ignored in this mode.
#
#
# Usage: innovus [options]
#
# [-cpus <integer>]
#         Number of cpus to use for multi-threading on current host.
# [-db <dir>] ************** Usefule to read genus dbs from post ispatial synthesis **************
#         The directory of a DB to read. It is read before -execute or -files are invoked.
# [-execute <Tcl_commands>]
#         Tcl commands to execute at startup, before -files.
# [-files <in_file_list>]
#         One or more Tcl files to source at startup, after -execute. 
# [-ihdb <dir>]
#         Specifies an integrity/integrated Hierarchical Data Base to be read (e.g. xxx/my_design/placed) before -execute or -files are invoked.
#
# [-lic_multi_cpu <lic_list>]
#         Control which licenses to use for higher multi-cpu usage in priority
#         order from left to right. The allowed license names are:
#         "invs_cpu invs invsb fel fexl invs_dcpu"
# From our license servers valid license options are "invs_cpu invs invs_dcpu"
# invs_dcpu — distributed CPU license, used when work is spread across multiple hosts
#
# [-lic_startup <lic_list>]
#         Request one of these licenses at startup in priority order from left
#         to right. The supported licenses are:
#         "invs invsb fexl vdixl vdi fel synthesis"
# From our license servers valid license options are "invs vdi" 
#
# [-lic_options <lic_list>]
#         Ordered list for dynamic option license checkout in priority order
#         from left to right. These are checked out when needed by a specific
#         Tcl command. Legal names are:
#         "invs_hier invs_ms invs_3d_ic invs_5nm invs_3nm invs_3nmGAA invs_2nmGAA invs_7nm invs_20nm invs_10nm invs_i20nm invs_i10nm
#          invs_hfr invs_gigaplace invs_gigaplace_gxl qrcaa enclp encan enccco encng vdixl_capacity modus_dft modus_tp invs_phy_syn_opt
#          invs_pi invs_ml invs_ehfs invs_dfm invs_sc invs_automotive midas_user
#          tpsxl tpsl vtsxl vtsl vtsxm vtsesd vtsaa vtsgaabsp invs_vi jls20 jls30 jls40"         
# @innovus 1> set_license_check -exists_on_server
# Name               Prod #  Product Name                                     License string             Version 
# invs_hier          INVS40  Innovus Hierarchical Design Option               Innovus_Hier_Opt           23.1    
# invs_ms            INVS30  Innovus Mixed Signal Option                      Innovus_MS_Opt             23.1    
# invs_20nm          INVS20  Innovus 20nm Option                              Innovus_20nm_Opt           23.1    
# invs_7nm           INVS07  Innovus 7nm Option                               Innovus_7nm_Opt            23.1    
# invs_3nm           INVS03  Innovus 3nm Option                               Innovus_3nm_Opt            23.1    
# invs_hfr           INVS35  Innovus High Frequency Route Option              Innovus_hfr_Opt            23.1    
# invs_gigaplace     INVS45  Innovus GigaPlace XL Option                      Innovus_GigaPlace_XL_Opt   23.1    
# invs_gigaplace_gxl INVS48  Innovus GigaPlace GXL Option                     Innovus_GigaPlace_GXL_Opt  23.1    
# invs_pi            INVS55  Innovus Power Integrity Option                   Innovus_PI_Opt             23.1    
# jls20              JLS20   Joules Implementation Option                     Joules_Implementation_Opt  23.1    
# genb               GEN100  Genus Synthesis Solution                         Genus_Synthesis            23.1    
# genphy             GEN40   Genus Physical Option                            Genus_Physical_Opt         23.1    
# synthesis          INVS500 InnovusPLUS Logical Synthesis                    Innovus_Synthesis          23.1    
# invs_phy_syn_opt   INVS540 InnovusPLUS Physical Synthesis Option            Innovus_Physical_Syn_Opt   23.1 
# invs_dfm           INVS50  Innovus DFM Option                               Innovus_DFM                23.1    
# invs_automotive    INVS56  Innovus Automotive Option                        Innovus_Automotive_Opt     23.1    
# modus_dft          MOD30   Modus DFT Option                                 Modus_DFT_Opt              23.1    
# litmus_cmgr        CFML110 Conformal Litmus Constraint Management Option    CFM_Litmus_Const_Mgmt_Opt  23.1    
# midas_user         MDS007  Midas Safety Platform Option                     Midas_User                 22.0    
# tpsxl              TPS200  Tempus Timing Signoff Solution XL                Tempus_Timing_Signoff_XL   23.1    
# tpsl               TPS100  Tempus Timing Signoff Solution L                 Tempus_Timing_Signoff_L    23.1    
# qrcaa              QRCX310 Cadence Quantus QRC Advanced Analysis GXL Option QRC_Advanced_Analysis      16.1    
# tps_aa             TPS210  Tempus Advanced Analysis Option                  Tempus_Advanced_Analysis   23.1    
# vtsesd             VTS203  Voltus IC Power Integrity Solution - ESD         Voltus_Power_Integrity_ESD 23.1    
# vtsxl              VTS200  Voltus Power Integrity Solution XL               Voltus_Power_Integrity_XL  23.1    
# vtsaa              VTS201  Voltus Advanced Analysis GXL Option              Voltus_Power_Integrity_AA  23.1 
#
# Example:
#   for initial runs with debug
#   bash ./innovus.sh --run 1 --no-abort
#   for full P&R run
#   bash ./innovus.sh --run 1
#   for P&R using Genus run 6 netlist/DB
#   bash ./innovus.sh --run 1 --genus-run 6
#   for iSpatial floorplan (DEF) flow
#   bash ./innovus.sh --run 1 --phys-synth-type floorplan
#   to re-run into the same folder
#   bash ./innovus.sh --run 1 --overwrite
#   to compare runs 1-4
#   bash ./innovus.sh --run 4 --metrics-compare
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

ABORT_FLAG="-abort_on_error"
OVERWRITE=0
METRICS_COMPARE=0
export INNOVUS_RUN_COUNTER=0
export GENUS_RUN_COUNTER=0
export PHYS_SYNTH_TYPE=lef

while [[ $# -gt 0 ]]; do
    case $1 in
        --no-abort)          ABORT_FLAG="";                        shift ;;
        --run)               INNOVUS_RUN_COUNTER="$2";             shift 2 ;;
        --genus-run)         GENUS_RUN_COUNTER="$2";               shift 2 ;;
        --phys-synth-type)   PHYS_SYNTH_TYPE="$2";                 shift 2 ;;
        --overwrite)         OVERWRITE=1;                          shift ;;
        --metrics-compare)   METRICS_COMPARE=1;                    shift ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

INNOVUS_WORK_DIR="$SCRIPT_DIR/../../../../../run/work/innovus"

if [[ $METRICS_COMPARE -eq 1 ]]; then
    # Scratch folder only — wiped on entry and removed again on exit.
    RUN_DIR="$INNOVUS_WORK_DIR/innovus_metrics_compare_tmp"
    rm -rf "$RUN_DIR"
    mkdir -p "$RUN_DIR"
else
    RUN_DIR="$INNOVUS_WORK_DIR/innovus_run_$(printf '%02d' "${INNOVUS_RUN_COUNTER}")"

    if [[ -d "$RUN_DIR" ]]; then
        if [[ $OVERWRITE -eq 0 ]]; then
            echo "Error: run directory already exists: $RUN_DIR"
            echo "       Use --overwrite to reuse it."
            exit 1
        fi
        echo "Warning: reusing existing run directory: $RUN_DIR"
    fi

    mkdir -p "$RUN_DIR"
fi

cd "$RUN_DIR"

# trap ensures we return to the scripts folder, and remove the metrics-compare
# scratch folder, even when:
#   - Innovus exits normally
#   - --no-abort drops into interactive prompt and user types exit
#   - an error causes early termination
trap "cd \"$SCRIPT_DIR\"; if [[ $METRICS_COMPARE -eq 1 ]]; then rm -rf \"$RUN_DIR\"; fi" EXIT

if [[ $METRICS_COMPARE -eq 1 ]]; then
    innovus -stylus -batch -no_gui $ABORT_FLAG \
            -files /work/cgra4ml/deepsocflow/tcl/asic/cadence/scripts/innovus_metrics_compare.tcl
else
    innovus -stylus $ABORT_FLAG \
            -files /work/cgra4ml/deepsocflow/tcl/asic/cadence/scripts/innovus.tcl
fi
