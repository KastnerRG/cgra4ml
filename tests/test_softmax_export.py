"""
Python-only (no Verilator) tests for the non-terminal and terminal softmax export paths.

Checks:
  - config_fw.h contains is_softmax=1, softmax_frac, softmax_max_i for the softmax bundle
  - Non-terminal softmax: O_TYPE is int32_t (output is requantized integer)
  - Terminal softmax:     O_TYPE is float
  - allow_mismatch propagates to downstream bundles
  - Requantized output has correct bit width and stays in [-2^(X_BITS-1), 2^(X_BITS-1)-1]
"""

import os
import re
import sys
import pytest
import numpy as np

REPO_ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), ".."))


# ── helpers ──────────────────────────────────────────────────────────────────

def _config(work_dir):
    with open(os.path.join(work_dir, "config_fw.h")) as f:
        return f.read()

def _define(cfg, name):
    m = re.search(rf"#define {name}\s+(\S+)", cfg)
    assert m, f"#define {name} not found in config_fw.h"
    return m.group(1)

def _idefine(cfg, name):
    return int(_define(cfg, name))

def _bundle_field(cfg, ib, field):
    """Extract a numeric field value from bundle ib's initialiser in bundles[]."""
    pattern = rf"\.{field}=(-?\d+)"
    matches = re.findall(pattern, cfg)
    assert len(matches) > ib, f"Field .{field} not found for bundle {ib}"
    return int(matches[ib])


# ── shared model builder ──────────────────────────────────────────────────────

def _build_and_export(work_dir, terminal_softmax: bool):
    """
    Export a minimal model with a softmax bundle.

    terminal_softmax=True  → single bundle with softmax (last bundle → float out)
    terminal_softmax=False → softmax bundle feeds a downstream dense bundle (int out)

    Returns (work_dir, softmax_bundle_ib).
    """
    orig_dir = os.getcwd()
    os.chdir(str(work_dir))

    try:
        sys.path.insert(0, REPO_ROOT)

        from tensorflow import keras
        from keras.layers import Input
        from keras.models import Model
        from deepsocflow import (
            Hardware, SYS_BITS, XModel, XBundle, XDense, XActivation,
            export_inference,
        )
        from deepsocflow.py.utils import BUNDLES

        N = 16
        sys_bits = SYS_BITS(x=4, k=8, b=16)

        relu = lambda: XActivation(sys_bits=sys_bits, o_int_bits=0, type="relu")
        lin  = lambda: XActivation(sys_bits=sys_bits, o_int_bits=0, type=None)

        if terminal_softmax:
            @keras.saving.register_keras_serializable()
            class _TermSoftmaxModel(XModel):
                def __init__(self, sys_bits, x_int_bits, *args, **kwargs):
                    super().__init__(sys_bits, x_int_bits, *args, **kwargs)
                    self.b1 = XBundle(core=XDense(
                        k_int_bits=0, b_int_bits=0, units=N, use_bias=False, act=relu()))
                    self.b2 = XBundle(core=XDense(
                        k_int_bits=0, b_int_bits=0, units=N, use_bias=False, act=lin()),
                        softmax=True)

                def call(self, x):
                    x = self.input_quant_layer(x)
                    x = self.b1(x)
                    return self.b2(x)

            x_in = Input([N], name="input")
            um = _TermSoftmaxModel(sys_bits=sys_bits, x_int_bits=0)
            m = Model(inputs=[x_in], outputs=[um(x_in)])
            softmax_ib = 1   # bundle index 1 is the softmax bundle

        else:
            @keras.saving.register_keras_serializable()
            class _NonTermSoftmaxModel(XModel):
                def __init__(self, sys_bits, x_int_bits, *args, **kwargs):
                    super().__init__(sys_bits, x_int_bits, *args, **kwargs)
                    self.b1 = XBundle(core=XDense(
                        k_int_bits=0, b_int_bits=0, units=N, use_bias=False, act=relu()))
                    # non-terminal: has a consumer bundle after it
                    self.b2 = XBundle(core=XDense(
                        k_int_bits=0, b_int_bits=0, units=N, use_bias=False, act=lin()),
                        softmax=True)
                    self.b3 = XBundle(core=XDense(
                        k_int_bits=0, b_int_bits=0, units=N, use_bias=False, act=lin()))

                def call(self, x):
                    x = self.input_quant_layer(x)
                    x = self.b1(x)
                    x = self.b2(x)   # non-terminal softmax
                    return self.b3(x)

            x_in = Input([N], name="input")
            um = _NonTermSoftmaxModel(sys_bits=sys_bits, x_int_bits=0)
            m = Model(inputs=[x_in], outputs=[um(x_in)])
            softmax_ib = 1   # bundle index 1

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
        export_inference(m, hw, batch_size=N)

        # Return bundles so callers can inspect Python-side state
        bundles_snapshot = list(BUNDLES)

    finally:
        os.chdir(orig_dir)

    return str(work_dir), softmax_ib, bundles_snapshot, hw


# ── fixtures ─────────────────────────────────────────────────────────────────

@pytest.fixture(scope="module")
def terminal_export(tmp_path_factory):
    work = tmp_path_factory.mktemp("terminal_softmax")
    return _build_and_export(work, terminal_softmax=True)


@pytest.fixture(scope="module")
def non_terminal_export(tmp_path_factory):
    work = tmp_path_factory.mktemp("non_terminal_softmax")
    return _build_and_export(work, terminal_softmax=False)


# ── Terminal softmax tests ────────────────────────────────────────────────────

class TestTerminalSoftmax:

    def test_is_softmax_flag(self, terminal_export):
        work, ib, bundles, hw = terminal_export
        cfg = _config(work)
        assert _bundle_field(cfg, ib, "is_softmax") == 1, \
            f"Bundle {ib} should have is_softmax=1"

    def test_o_type_is_float(self, terminal_export):
        work, ib, bundles, hw = terminal_export
        assert _define(_config(work), "O_TYPE") == "float", \
            "Terminal softmax model must have O_TYPE=float"

    def test_softmax_frac_written(self, terminal_export):
        work, ib, bundles, hw = terminal_export
        cfg = _config(work)
        frac_val = _bundle_field(cfg, ib, "softmax_frac")
        # softmax_frac must equal the pre-softmax integer tensor's frac bits
        assert frac_val > 0, "softmax_frac should be positive"

    def test_softmax_max_i_written(self, terminal_export):
        work, ib, bundles, hw = terminal_export
        cfg = _config(work)
        # softmax_max_i can be 0 when all inputs are zero, but the field must exist
        m = re.search(r"\.softmax_max_i=(-?\d+)", cfg)
        assert m, "softmax_max_i field missing from bundle initialiser"

    def test_non_softmax_bundle_has_zero_flags(self, terminal_export):
        work, ib, bundles, hw = terminal_export
        cfg = _config(work)
        # Bundle 0 (before softmax) should have is_softmax=0
        assert _bundle_field(cfg, 0, "is_softmax") == 0


# ── Non-terminal softmax tests ────────────────────────────────────────────────

class TestNonTerminalSoftmax:

    def test_is_softmax_flag(self, non_terminal_export):
        work, ib, bundles, hw = non_terminal_export
        cfg = _config(work)
        assert _bundle_field(cfg, ib, "is_softmax") == 1

    def test_o_type_is_int(self, non_terminal_export):
        work, ib, bundles, hw = non_terminal_export
        # Non-terminal softmax: last bundle has no softmax → O_TYPE is integer
        o_type = _define(_config(work), "O_TYPE")
        assert "int" in o_type, \
            f"Non-terminal model's last bundle is not softmax; O_TYPE should be int, got {o_type}"

    def test_requantized_output_in_range(self, non_terminal_export):
        work, ib, bundles, hw = non_terminal_export
        sm_bundle = bundles[ib]
        out = sm_bundle.out
        # Non-terminal softmax produces an integer XTensor
        assert out.from_int, "Non-terminal softmax bundle.out must be from_int=True"
        ints = out.itensor.numpy()
        limit = 1 << (hw.X_BITS - 1)
        assert np.all(ints >= -limit) and np.all(ints < limit), \
            f"Requantized softmax output out of [{-limit}, {limit-1}] range"

    def test_requantized_frac_matches_x_bits(self, non_terminal_export):
        work, ib, bundles, hw = non_terminal_export
        sm_bundle = bundles[ib]
        assert sm_bundle.out.frac == hw.X_BITS - 1, \
            f"Non-terminal softmax frac should be X_BITS-1={hw.X_BITS-1}, got {sm_bundle.out.frac}"

    def test_allow_mismatch_propagates(self, non_terminal_export):
        work, ib, bundles, hw = non_terminal_export
        sm_bundle = bundles[ib]
        downstream = bundles[ib + 1]  # b3 in the 3-bundle model
        assert sm_bundle.allow_mismatch, \
            "Non-terminal softmax bundle itself should have allow_mismatch=True"
        assert downstream.allow_mismatch, \
            "Bundle after non-terminal softmax should inherit allow_mismatch=True"

    def test_softmax_values_sum_to_one(self, non_terminal_export):
        work, ib, bundles, hw = non_terminal_export
        sm_bundle = bundles[ib]
        # Use the pre-requantization float softmax output — the requantized q/2^frac
        # does NOT sum to 1.0 in general due to fixed-point rounding.
        float_out = sm_bundle.softmax_float_out  # shape (N, CO), float32, sums to 1 per row
        row_sums = float_out.sum(axis=-1)
        assert np.allclose(row_sums, 1.0, atol=1e-5), \
            f"Softmax rows don't sum to 1: {row_sums}"

    def test_argmax_preserved(self, non_terminal_export):
        work, ib, bundles, hw = non_terminal_export
        sm_bundle = bundles[ib]
        # Argmax of float softmax (pre-requantization) must match argmax of quantized output.
        # Using sm_bundle.out.ftensor (= q/scale) would be a trivial identity comparison.
        float_out = sm_bundle.softmax_float_out   # float32 softmax probabilities
        q_out     = sm_bundle.out.itensor.numpy() # requantized integer output
        assert np.all(np.argmax(float_out, axis=-1) == np.argmax(q_out, axis=-1)), \
            "Argmax not preserved after softmax requantization"

    def test_softmax_frac_written_to_config(self, non_terminal_export):
        work, ib, bundles, hw = non_terminal_export
        cfg = _config(work)
        frac_val = _bundle_field(cfg, ib, "softmax_frac")
        expected = bundles[ib].softmax_frac
        assert frac_val == expected, \
            f"config_fw.h softmax_frac={frac_val} != Python bundle.softmax_frac={expected}"

    def test_softmax_max_i_written_to_config(self, non_terminal_export):
        work, ib, bundles, hw = non_terminal_export
        cfg = _config(work)
        # softmax_max_i fields appear in bundle initialiser order
        matches = re.findall(r"\.softmax_max_i=(-?\d+)", cfg)
        assert len(matches) > ib, "softmax_max_i field missing for softmax bundle"
        cfg_val = int(matches[ib])
        expected = bundles[ib].softmax_max_i
        assert cfg_val == expected, \
            f"config_fw.h softmax_max_i={cfg_val} != Python bundle.softmax_max_i={expected}"
