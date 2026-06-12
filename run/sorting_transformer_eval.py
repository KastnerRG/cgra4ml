"""
Evaluate the trained sorting transformer encoder block.

Run from the run/ directory:
    python sorting_transformer_eval.py

Three sections:
  1. Sorting accuracy  — perfect sort rate, Kendall's tau, MSE over 500 unseen sequences
  2. Sample outputs    — perfectly sorted examples vs imperfect examples side by side
  3. Inference latency — CPU single-sequence latency averaged over 500 timed runs

Hardware (FPGA) performance is reported by `make smoke_sorting`, which calls
predict_model_performance(hw) after export_inference.
"""

import sys
import os
import time
sys.path.insert(0, "../../")
import numpy as np
from scipy.stats import kendalltau
from sorting_transformer import model, N, D

SEED      = 99      # different from training seed — unseen sequences
N_TEST    = 500
N_SAMPLES = 3       # number of examples to display per category (perfect / imperfect)
N_WARMUP  = 100     # warm-up runs before timing
N_TIMED   = 500     # timed runs for latency measurement

# ── Load trained weights ───────────────────────────────────────────────────
weights_path = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                            'sorting_transformer_weights.weights.h5')
model.load_weights(weights_path)
print(f"Loaded weights: {weights_path}\n")

# ── Generate test data ─────────────────────────────────────────────────────
rng    = np.random.default_rng(SEED)
X_test = rng.uniform(-1, 1, (N_TEST, N, D)).astype(np.float32)
Y_test = np.array([x[np.argsort(x[:, 0])] for x in X_test], dtype=np.float32)

# ══════════════════════════════════════════════════════════════════════════════
# Section 1 — Sorting Accuracy
# ══════════════════════════════════════════════════════════════════════════════
print("=" * 52)
print(f"Section 1 — Sorting Accuracy  ({N_TEST} unseen sequences)")
print("=" * 52)

perfect      = 0
taus         = []
mses         = []
preds        = []           # cache predictions for Section 2
perfect_idxs = []
bad_idxs     = []

for i in range(N_TEST):
    y_pred     = model(X_test[i], training=False).numpy()
    first_feat = y_pred[:, 0]
    preds.append(y_pred)

    is_sorted = np.all(first_feat[:-1] <= first_feat[1:])
    if is_sorted:
        perfect += 1
        perfect_idxs.append(i)
    else:
        bad_idxs.append(i)

    tau, _ = kendalltau(np.argsort(first_feat), np.arange(N))
    taus.append(tau)
    mses.append(np.mean((y_pred - Y_test[i]) ** 2))

print(f"Perfect sort rate : {perfect}/{N_TEST} ({100*perfect/N_TEST:.1f}%)")
print(f"Mean Kendall's τ  : {np.mean(taus):.4f}  (1.0 = perfect, 0.0 = random)")
print(f"Mean MSE          : {np.mean(mses):.6f}\n")

# ══════════════════════════════════════════════════════════════════════════════
# Section 2 — Sample Inputs and Outputs
# ══════════════════════════════════════════════════════════════════════════════
print("=" * 52)
print(f"Section 2 — Sample Inputs and Outputs")
print("=" * 52)

def print_sequence(label, idx, sample_num):
    x_in   = X_test[idx]
    y_true = Y_test[idx]
    y_pred = preds[idx]
    tau, _ = kendalltau(np.argsort(y_pred[:, 0]), np.arange(N))
    print(f"\n--- {label} {sample_num}  (seq {idx}, τ={tau:.3f}) ---")
    print(f"{'Pos':>4}  {'Input[0]':>10}  {'Output[0]':>10}  {'Target[0]':>10}")
    print(f"{'---':>4}  {'--------':>10}  {'---------':>10}  {'---------':>10}")
    for pos in range(N):
        mark = " *" if pos > 0 and y_pred[pos, 0] < y_pred[pos-1, 0] else "  "
        print(f"{pos:>4}  {x_in[pos, 0]:>10.4f}  {y_pred[pos, 0]:>10.4f}  {y_true[pos, 0]:>10.4f}{mark}")

n_perfect_show  = min(N_SAMPLES, len(perfect_idxs))
n_bad_show      = min(N_SAMPLES, len(bad_idxs))

# Sort imperfect examples by Kendall's tau descending so we show a range of quality
bad_taus        = [(i, taus[i]) for i in bad_idxs]
bad_taus_sorted = sorted(bad_taus, key=lambda x: x[1])   # worst first
bad_show        = [idx for idx, _ in bad_taus_sorted[:n_bad_show]]

if n_perfect_show > 0:
    print(f"\n{'─'*52}")
    print(f"  Correctly sorted  ({n_perfect_show} example{'s' if n_perfect_show > 1 else ''})")
    print(f"{'─'*52}")
    for k, idx in enumerate(perfect_idxs[:n_perfect_show], 1):
        print_sequence("Perfect", idx, k)
else:
    print("\n  (no perfectly sorted sequences found in this test set)")

print(f"\n{'─'*52}")
print(f"  Incorrectly sorted  ({n_bad_show} example{'s' if n_bad_show > 1 else ''}, worst τ first)")
print(f"  (* marks positions where output[0] decreases — a sorting error)")
print(f"{'─'*52}")
for k, idx in enumerate(bad_show, 1):
    print_sequence("Imperfect", idx, k)

print()

# ══════════════════════════════════════════════════════════════════════════════
# Section 3 — Inference Latency (CPU)
# ══════════════════════════════════════════════════════════════════════════════
print("=" * 52)
print("Section 3 — Inference Latency (CPU / Python-Keras)")
print("=" * 52)

x_bench = X_test[0]

# Warm up
for _ in range(N_WARMUP):
    _ = model(x_bench, training=False)

# Timed runs
t0 = time.perf_counter()
for _ in range(N_TIMED):
    _ = model(x_bench, training=False)
t1 = time.perf_counter()

latency_ms  = (t1 - t0) / N_TIMED * 1000
throughput  = 1000 / latency_ms

print(f"Single-sequence latency : {latency_ms:.3f} ms  (avg over {N_TIMED} runs)")
print(f"Throughput              : {throughput:.1f} sequences/sec")
print()
print("Note: FPGA hardware performance is reported by `make smoke_sorting`,")
print("      which calls predict_model_performance(hw) after export_inference.")
