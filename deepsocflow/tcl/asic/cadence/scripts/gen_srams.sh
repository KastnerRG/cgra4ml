#!/usr/bin/env bash
##############################################################################
# Script    : gen_srams.sh
# Purpose   : Generate SRAM macros (edge, weight, DMA) using PDK compilers
##############################################################################
#
# This script is invoked automatically by hardware.py when SRAM_GEN=True.
# It can also be run standalone from any directory:
#   bash gen_srams.sh [options]
#
# Options:
#   --design        Design name — appended to SRAMs_ to form the PDK SRAM dir (default: axi_cgra4ml)
#   --sp-compiler   Single-port SRAM compiler executable                      (default: rf_sp_hse_svt_mvt)
#   --2p-compiler   Two-port SRAM compiler executable                         (default: rf_2p_hsc_svt_mvt)
#                   WARNING: SRAM compiler executables must be available in PATH before running this script.
#
# Example:
#   bash ./gen_srams.sh --design axi_cgra4ml --sp-compiler rf_sp_hse_svt_mvt --2p-compiler rf_2p_hsc_svt_mvt
#
# WARNING: Do NOT remove the liberty nldm commands for any SRAM.
#          Each liberty view (nldm/ccs_tn/ccs_tnv) produces only a partial lib — the m40c corner
#          is missing from the ccs views in this process, making nldm the only complete corner available.
##############################################################################

set -e

DESIGN="axi_cgra4ml"
FOUNDARY="SAMSUNG"
TECHNOLOGY="LN05LPE"

SP_COMPILER="rf_sp_hse_svt_mvt"
P2_COMPILER="rf_2p_hsc_svt_mvt"

while [[ $# -gt 0 ]]; do
    case $1 in
        --design)       DESIGN="$2";       shift 2 ;;
        --sp-compiler)  SP_COMPILER="$2";  shift 2 ;;
        --2p-compiler)  P2_COMPILER="$2";  shift 2 ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

# Genrating SRAM EDGES
cd "/work/PDK/${FOUNDARY}${TECHNOLOGY}/SRAMs_${DESIGN}/sram_edge"
${SP_COMPILER} all     -spec sram_edge.spec
${SP_COMPILER} liberty -spec sram_edge.spec     -libertyviewstyle nldm
${SP_COMPILER} liberty -spec sram_edge.spec     -libertyviewstyle ccs_tn
${SP_COMPILER} liberty -spec sram_edge.spec     -libertyviewstyle ccs_tnv
cd "/work/cgra4ml/run/work/build"

# Genrating SRAM WEIGHTS
cd "/work/PDK/${FOUNDARY}${TECHNOLOGY}/SRAMs_${DESIGN}/sram_weight"
${SP_COMPILER} all     -spec sram_weight.spec
${SP_COMPILER} liberty -spec sram_weight.spec   -libertyviewstyle nldm
${SP_COMPILER} liberty -spec sram_weight.spec   -libertyviewstyle ccs_tn
${SP_COMPILER} liberty -spec sram_weight.spec   -libertyviewstyle ccs_tnv
cd "/work/cgra4ml/run/work/build"

# Genrating SRAM DMA
cd "/work/PDK/${FOUNDARY}${TECHNOLOGY}/SRAMs_${DESIGN}/sram_dma"
${P2_COMPILER} all     -spec sram_dma.spec
${P2_COMPILER} liberty -spec sram_dma.spec      -libertyviewstyle nldm
${P2_COMPILER} liberty -spec sram_dma.spec      -libertyviewstyle ccs_tn
${P2_COMPILER} liberty -spec sram_dma.spec      -libertyviewstyle ccs_tnv
cd "/work/cgra4ml/run/work/build"
