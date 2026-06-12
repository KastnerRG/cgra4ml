"""
Regression tests for Steps 1-3 of chained-matmul implementation.

Step 1 — Fan-out fix in runtime.h
  model_setup(): (var==0) → (bundles[var].in_buffer_idx==-1)
  run() debug:   (ib==0)  → (pb->in_buffer_idx==-1)

Step 2 — w_bufs in Memory_st + N_W_BUF / W_BUF_BYTES_MAX defines in config_fw.h

Step 3 — w_buf_bitstring zeros placeholder in wb.bin / wbx.bin
"""

import os
import re
import sys
import pytest
import numpy as np

REPO_ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), ".."))
RUNTIME_H = os.path.join(REPO_ROOT, "deepsocflow/c/runtime.h")


# ── helpers ──────────────────────────────────────────────────────────────────

def _runtime_src():
    with open(RUNTIME_H) as f:
        return f.read()

def _config(work_dir):
    with open(os.path.join(work_dir, "config_fw.h")) as f:
        return f.read()

def _define(cfg, name):
    m = re.search(rf"#define {name}\s+(\S+)", cfg)
    assert m, f"#define {name} not found in config_fw.h"
    return m.group(1)

def _idefine(cfg, name):
    return int(_define(cfg, name))


# ── Step 1: source-level checks (no Python runtime needed) ───────────────────

class TestStep1FanoutFix:

    def test_model_setup_no_var_zero(self):
        """parameters[8*var] x_base line must NOT use (var==0)."""
        for line in _runtime_src().splitlines():
            if "parameters[8*var]" in line and "fb_addr_64to32" in line:
                assert "var == 0" not in line, \
                    f"Old fan-out condition still present:\n  {line}"

    def test_model_setup_uses_in_buffer_idx(self):
        """parameters[8*var] x_base line must use bundles[var].in_buffer_idx==-1."""
        found = False
        for line in _runtime_src().splitlines():
            if "parameters[8*var]" in line and "fb_addr_64to32" in line:
                assert "bundles[var].in_buffer_idx == -1" in line, \
                    f"New fan-out condition not present:\n  {line}"
                found = True
        assert found, "parameters[8*var] line not found in runtime.h"

    def test_run_debug_in_src_no_ib_zero(self):
        """in_src void* assignment must NOT use (ib==0)."""
        for line in _runtime_src().splitlines():
            if "in_src" in line and "void" in line and "mp->" in line:
                assert "ib == 0" not in line, \
                    f"Old debug condition (ib==0) still present:\n  {line}"

    def test_run_debug_in_src_uses_in_buffer_idx(self):
        """in_src void* assignment must use (pb->in_buffer_idx==-1)."""
        found = False
        for line in _runtime_src().splitlines():
            if "in_src" in line and "void" in line and "mp->" in line:
                assert "pb->in_buffer_idx == -1" in line, \
                    f"New condition not present:\n  {line}"
                found = True
        assert found, "in_src assignment line not found in runtime.h"

    def test_run_debug_label_no_ib_zero(self):
        """debug_printf label string for in_src must NOT use (ib==0)."""
        for line in _runtime_src().splitlines():
            if '"mp->x (raw input)"' in line:
                assert "ib == 0" not in line, \
                    f"Old condition on label line:\n  {line}"


# ── Step 2: Memory_st structure check (source-level) ─────────────────────────

class TestStep2MemoryStruct:

    def test_w_bufs_field_conditional(self):
        """Memory_st must have #if N_W_BUF > 0 guard around w_bufs."""
        src = _runtime_src()
        assert "#if N_W_BUF > 0" in src, \
            "#if N_W_BUF > 0 guard not found in runtime.h"

    def test_w_bufs_field_present(self):
        """Memory_st must declare w_bufs[N_W_BUF][W_BUF_BYTES_MAX]."""
        src = _runtime_src()
        assert "w_bufs" in src, "w_bufs field not found in runtime.h"
        assert "N_W_BUF" in src
        assert "W_BUF_BYTES_MAX" in src

    def test_w_bufs_after_w_before_b(self):
        """w_bufs must appear between w[] and b[] in Memory_st."""
        src = _runtime_src()
        pos_w    = src.find("i8     w              [W_BYTES")
        pos_wbuf = src.find("w_bufs")
        pos_b    = src.find("B_TYPE b              [B_WORDS")
        assert pos_w < pos_wbuf < pos_b, \
            "w_bufs is not positioned between w[] and b[] in Memory_st"


# ── Step 2 & 3: export-level checks ──────────────────────────────────────────

@pytest.fixture(scope="module")
def exported_two_dense(tmp_path_factory):
    """
    Run export_inference() for a minimal two-dense model in a temp directory.
    Returns the path to that directory (where config_fw.h and vectors/ live).
    No simulation is run — Python export only.
    """
    work = tmp_path_factory.mktemp("two_dense_work")
    orig_dir = os.getcwd()
    os.chdir(str(work))

    try:
        sys.path.insert(0, REPO_ROOT)

        from tensorflow import keras
        from keras.layers import Input
        from keras.models import Model
        from deepsocflow import (
            Hardware, SYS_BITS, XModel, XBundle, XDense, XActivation,
            export_inference,
        )

        N = 16
        sys_bits = SYS_BITS(x=4, k=8, b=16)

        @keras.saving.register_keras_serializable()
        class _StepsTestModel(XModel):
            def __init__(self, sys_bits, x_int_bits, *args, **kwargs):
                super().__init__(sys_bits, x_int_bits, *args, **kwargs)
                self.b1 = XBundle(core=XDense(
                    k_int_bits=0, b_int_bits=0, units=N, use_bias=False,
                    act=XActivation(sys_bits=sys_bits, o_int_bits=0, type="relu"),
                ))
                self.b2 = XBundle(core=XDense(
                    k_int_bits=0, b_int_bits=0, units=N, use_bias=False,
                    act=XActivation(sys_bits=sys_bits, o_int_bits=0, type=None),
                ))

            def call(self, x):
                x = self.input_quant_layer(x)
                x = self.b1(x)
                x = self.b2(x)
                return x

        x_in = Input([N], name="input")
        user_model = _StepsTestModel(sys_bits=sys_bits, x_int_bits=0)
        x_out = user_model(x_in)
        model = Model(inputs=[x_in], outputs=[x_out])

        hw = Hardware(
            processing_elements=(N, N),
            frequency_mhz=150,
            bits_input=sys_bits.x,
            bits_weights=sys_bits.k,
            bits_sum=24,
            bits_bias=sys_bits.b,
            max_batch_size=N,
            max_channels_in=256,
            max_kernel_size=3,
            max_image_size=512,
            max_n_bundles=64,
            ram_weights_depth=256,
            ram_edges_depth=16,
            axi_width=64,
            config_baseaddr="40000000",
            target_cpu_int_bits=32,
            valid_prob=1,
            ready_prob=1,
            data_dir="vectors",
        )
        hw.export_json()
        hw = Hardware.from_json("hardware.json")
        hw.export()
        export_inference(model, hw, batch_size=N)

    finally:
        os.chdir(orig_dir)

    return str(work)


class TestStep2Defines:

    def test_n_w_buf_zero(self, exported_two_dense):
        """N_W_BUF must be 0 for a plain two-dense model (no dynamic weights)."""
        assert _idefine(_config(exported_two_dense), "N_W_BUF") == 0

    def test_w_buf_bytes_max_at_least_one(self, exported_two_dense):
        """W_BUF_BYTES_MAX must be >= 1 to avoid a zero-size C array declaration."""
        assert _idefine(_config(exported_two_dense), "W_BUF_BYTES_MAX") >= 1

    def test_wb_bytes_equals_w_plus_bias(self, exported_two_dense):
        """WB_BYTES must equal W_BYTES + B_WORDS*B_BITS//8 when N_W_BUF=0."""
        cfg = _config(exported_two_dense)
        wb     = _idefine(cfg, "WB_BYTES")
        w      = _idefine(cfg, "W_BYTES")
        b_words = _idefine(cfg, "B_WORDS")
        b_bits  = int(re.search(r"#define B_TYPE\s+int(\d+)_t", cfg).group(1))
        n_wbuf  = _idefine(cfg, "N_W_BUF")
        assert n_wbuf == 0, "precondition: N_W_BUF must be 0 for this model"
        assert wb == w + b_words * b_bits // 8, \
            f"WB_BYTES={wb} != W_BYTES({w}) + B_WORDS*B_BITS/8({b_words*b_bits//8})"

    def test_existing_defines_present(self, exported_two_dense):
        """Sanity: existing defines (N_OUT_BUF, W_BYTES, X_BYTES) must still exist."""
        cfg = _config(exported_two_dense)
        for name in ("N_OUT_BUF", "W_BYTES", "X_BYTES", "O_BYTES_MAX", "NHWC_WORDS"):
            assert re.search(rf"#define {name}\b", cfg), \
                f"#define {name} missing from config_fw.h"


class TestStep3BinLayout:

    def test_wb_bin_size_matches_wb_bytes(self, exported_two_dense):
        """wb.bin must be exactly WB_BYTES bytes."""
        cfg = _config(exported_two_dense)
        wb_bytes = _idefine(cfg, "WB_BYTES")
        actual   = os.path.getsize(os.path.join(exported_two_dense, "vectors/wb.bin"))
        assert actual == wb_bytes, \
            f"wb.bin size {actual} != WB_BYTES {wb_bytes}"

    def test_wbx_bin_size_matches_wb_plus_x(self, exported_two_dense):
        """wbx.bin must be exactly WB_BYTES + X_BYTES bytes."""
        cfg = _config(exported_two_dense)
        wb_bytes = _idefine(cfg, "WB_BYTES")
        x_bytes  = _idefine(cfg, "X_BYTES")
        actual   = os.path.getsize(os.path.join(exported_two_dense, "vectors/wbx.bin"))
        assert actual == wb_bytes + x_bytes, \
            f"wbx.bin size {actual} != WB_BYTES+X_BYTES {wb_bytes+x_bytes}"

    def test_no_spurious_padding_when_no_wbufs(self, exported_two_dense):
        """With N_W_BUF=0, w_buf_bitstring is empty; wb.bin must not have extra zeros."""
        cfg     = _config(exported_two_dense)
        n_wbuf  = _idefine(cfg, "N_W_BUF")
        w_bytes = _idefine(cfg, "W_BYTES")
        wb_size = os.path.getsize(os.path.join(exported_two_dense, "vectors/wb.bin"))
        assert n_wbuf == 0
        # WB_BYTES = W_BYTES + 0 * W_BUF_BYTES_MAX + B_WORDS*B_BITS//8
        # For this model B_WORDS=0, so wb.bin size must equal W_BYTES exactly
        b_words = _idefine(cfg, "B_WORDS")
        assert b_words == 0, "precondition: model has no biases"
        assert wb_size == w_bytes, \
            f"wb.bin size {wb_size} != W_BYTES {w_bytes} (spurious padding?)"
