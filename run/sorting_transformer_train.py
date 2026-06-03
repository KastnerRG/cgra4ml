"""
Train the sorting transformer encoder block and save weights.

Run once from the run/ directory before running the Verilator test:
    python sorting_transformer_train.py

Task: sort N D-dimensional tokens by their first feature.
Loss: pairwise ranking on the first output feature.
  For every pair (i < j), requires pred[j,0] > pred[i,0].
  Loss = mean softplus(-(pred[j,0] - pred[i,0])) over all N*(N-1)/2 pairs.

Trained weights are saved to sorting_transformer_weights.weights.h5.
"""

import sys
import os
sys.path.insert(0, "../../")
import numpy as np
import tensorflow as tf
from tensorflow import keras

# Import the pre-built model — avoids duplicating UserModel.
# export_inference clears and re-populates BUNDLES on each call, so
# BUNDLES state from this import does not affect the inference test.
from sorting_transformer import model, N, D

SEED       = 42
N_SEQ      = 2000
EPOCHS     = 200   # upper bound; early stopping will terminate before this
LR         = 1e-3
PATIENCE   = 20    # stop if val_loss doesn't improve for this many epochs

def pairwise_ranking_loss(y_true, y_pred):
    """
    Pairwise ranking loss on the first output feature.

    y_true is sorted ascending by first feature, so for all i < j the
    correct ordering is y_pred[j, 0] > y_pred[i, 0].

    Loss = softplus(-(pred[j] - pred[i])) for each pair i < j.
    """
    scores = y_pred[:, 0]                                                   # (N,)
    # gap[i,j] = pred[j] - pred[i]; we want this > 0 for all i < j
    gap    = tf.expand_dims(scores, 0) - tf.expand_dims(scores, 1)         # (N, N)
    # Upper-triangle mask (i < j)
    mask   = tf.linalg.band_part(tf.ones_like(gap), 0, -1) \
           - tf.linalg.band_part(tf.ones_like(gap), 0, 0)
    loss   = tf.math.softplus(-gap) * mask
    return tf.reduce_sum(loss) / tf.reduce_sum(mask)

rng     = np.random.default_rng(SEED)
X_train = rng.uniform(-1, 1, (N_SEQ, N, D)).astype(np.float32)
# Sort each sequence by its first feature (column 0)
Y_train = np.array([x[np.argsort(x[:, 0])] for x in X_train], dtype=np.float32)

early_stop = keras.callbacks.EarlyStopping(
    monitor='val_loss',
    patience=PATIENCE,
    restore_best_weights=True,  # revert to the epoch with lowest val_loss
    verbose=1,
)

# batch_size=N keeps each batch as one complete sequence (preserves attention context)
model.compile(loss=pairwise_ranking_loss, optimizer=keras.optimizers.Adam(LR))
model.fit(
    X_train.reshape(-1, D),
    Y_train.reshape(-1, D),
    batch_size=N,
    shuffle=False,
    epochs=EPOCHS,
    validation_split=0.1,   # 10% of sequences held out for early stopping
    callbacks=[early_stop],
    verbose=1,
)

out_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'sorting_transformer_weights.weights.h5')
model.save_weights(out_path)
print(f"Weights saved to {out_path}")
