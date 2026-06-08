#!/usr/bin/env bash
set -e

FOUNDARY="SAMSUNG"
TECHNOLOGY="LN05LPE"

# Genrating SRAM EDGES
cd "/work/PDK/${FOUNDARY}${TECHNOLOGY}/SRAMs_CGRA4ML/sram_edge"
rf_sp_hse_svt_mvt all     -spec sram_edge.spec
rf_sp_hse_svt_mvt liberty -spec sram_edge.spec     -libertyviewstyle ccs_tn
rf_sp_hse_svt_mvt liberty -spec sram_edge.spec     -libertyviewstyle ccs_tnv
cd "/work/cgra4ml/run/work/build"

# Genrating SRAM WEIGHTS
cd "/work/PDK/${FOUNDARY}${TECHNOLOGY}/SRAMs_CGRA4ML/sram_weight"
rf_sp_hse_svt_mvt all     -spec sram_weight.spec
rf_sp_hse_svt_mvt liberty -spec sram_weight.spec   -libertyviewstyle ccs_tn
rf_sp_hse_svt_mvt liberty -spec sram_weight.spec   -libertyviewstyle ccs_tnv
cd "/work/cgra4ml/run/work/build"

# Genrating SRAM DMA
cd "/work/PDK/${FOUNDARY}${TECHNOLOGY}/SRAMs_CGRA4ML/sram_dma"
rf_2p_hsc_svt_mvt all     -spec sram_dma.spec
rf_2p_hsc_svt_mvt liberty -spec sram_dma.spec      -libertyviewstyle ccs_tn
rf_2p_hsc_svt_mvt liberty -spec sram_dma.spec      -libertyviewstyle ccs_tnv
cd "/work/cgra4ml/run/work/build"