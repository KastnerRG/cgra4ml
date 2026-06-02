"""
class_attention_demo.py

A small, self-contained attention demo for the CGRA4ML Transformer project.

This file is meant for class demonstration, not full hardware compilation yet.
It shows the core attention pipeline:

1. Input tokens X
2. Compute Q, K, V
3. Compute attention scores Q @ K.T
4. Optionally apply softmax
5. Compute output = attention_weights @ V
6. Optional tiny 2-head attention demo

Run from repo root:
    python .\run\class_attention_demo.py

Or from run/work:
    python ..\class_attention_demo.py
"""

import numpy as np


def print_matrix(name, matrix):
    """Pretty-print a matrix with its shape."""
    print(f"\n{name} shape = {matrix.shape}")
    print(matrix)


def softmax(x):
    """
    Row-wise softmax.

    We subtract the row max for numerical stability.
    This turns raw attention scores into probability-like weights.
    """
    x_shifted = x - np.max(x, axis=1, keepdims=True)
    exp_x = np.exp(x_shifted)
    return exp_x / np.sum(exp_x, axis=1, keepdims=True)


def single_head_attention_no_softmax(x, w_q, w_k, w_v):
    """
    Single-head self-attention without softmax.

    This is the simplest version:
        Q = X @ W_Q
        K = X @ W_K
        V = X @ W_V
        scores = Q @ K.T
        output = scores @ V

    This is useful because it shows the chained matrix multiplication pattern.
    """
    q = x @ w_q
    k = x @ w_k
    v = x @ w_v

    scores = q @ k.T
    output = scores @ v

    return q, k, v, scores, output


def single_head_attention_with_softmax(x, w_q, w_k, w_v):
    """
    Single-head self-attention with softmax.

    Standard attention is:
        Attention(Q, K, V) = softmax(Q @ K.T) @ V
    """
    q = x @ w_q
    k = x @ w_k
    v = x @ w_v

    scores = q @ k.T
    attention_weights = softmax(scores)
    output = attention_weights @ v

    return q, k, v, scores, attention_weights, output


def two_head_attention_demo(x):
    """
    Tiny 2-head attention demo.

    Each head has its own W_Q, W_K, and W_V.
    Then we concatenate both head outputs.

    This is only for classroom explanation.
    The main CGRA4ML MVP should stay focused on single-head attention first.
    """
    np.random.seed(7)

    d_model = x.shape[1]
    d_head = 4

    # Head 1 weights
    w_q1 = np.random.randint(-2, 3, size=(d_model, d_head))
    w_k1 = np.random.randint(-2, 3, size=(d_model, d_head))
    w_v1 = np.random.randint(-2, 3, size=(d_model, d_head))

    # Head 2 weights
    w_q2 = np.random.randint(-2, 3, size=(d_model, d_head))
    w_k2 = np.random.randint(-2, 3, size=(d_model, d_head))
    w_v2 = np.random.randint(-2, 3, size=(d_model, d_head))

    _, _, _, _, attn1, out1 = single_head_attention_with_softmax(x, w_q1, w_k1, w_v1)
    _, _, _, _, attn2, out2 = single_head_attention_with_softmax(x, w_q2, w_k2, w_v2)

    combined_output = np.concatenate([out1, out2], axis=1)

    return attn1, out1, attn2, out2, combined_output


def main():
    np.set_printoptions(precision=3, suppress=True)

    print("=" * 70)
    print("CGRA4ML Class Demo: Simple Attention-Based Models")
    print("=" * 70)

    # Tiny dimensions for class demo
    seq_len = 4      # number of tokens
    d_model = 8      # features per token
    d_head = 4       # projected attention dimension

    # Fixed seed so the output is repeatable for presentation/demo
    np.random.seed(145)

    # Input token matrix X
    # Each row is one token.
    x = np.random.randint(-3, 4, size=(seq_len, d_model))

    # Projection weights
    w_q = np.random.randint(-2, 3, size=(d_model, d_head))
    w_k = np.random.randint(-2, 3, size=(d_model, d_head))
    w_v = np.random.randint(-2, 3, size=(d_model, d_head))

    print("\nDemo setup:")
    print(f"SEQ_LEN = {seq_len}")
    print(f"D_MODEL = {d_model}")
    print(f"D_HEAD = {d_head}")

    print_matrix("Input X", x)
    print_matrix("W_Q", w_q)
    print_matrix("W_K", w_k)
    print_matrix("W_V", w_v)

    # ------------------------------------------------------------
    # Demo 1: Single-head attention without softmax
    # ------------------------------------------------------------
    print("\n" + "=" * 70)
    print("DEMO 1: Single-Head Attention WITHOUT Softmax")
    print("=" * 70)

    q, k, v, scores, output_no_softmax = single_head_attention_no_softmax(
        x, w_q, w_k, w_v
    )

    print_matrix("Q = X @ W_Q", q)
    print_matrix("K = X @ W_K", k)
    print_matrix("V = X @ W_V", v)
    print_matrix("Scores = Q @ K.T", scores)
    print_matrix("Output = Scores @ V", output_no_softmax)

    print(
        "\nExplanation: Without softmax, the raw scores directly decide how much "
        "each token mixes information from V."
    )

    # ------------------------------------------------------------
    # Demo 2: Single-head attention with softmax
    # ------------------------------------------------------------
    print("\n" + "=" * 70)
    print("DEMO 2: Single-Head Attention WITH Softmax")
    print("=" * 70)

    q, k, v, scores, attention_weights, output_softmax = (
        single_head_attention_with_softmax(x, w_q, w_k, w_v)
    )

    print_matrix("Scores = Q @ K.T", scores)
    print_matrix("Attention Weights = softmax(Scores)", attention_weights)
    print_matrix("Output = Attention Weights @ V", output_softmax)

    print(
        "\nExplanation: With softmax, each row becomes a set of normalized "
        "attention weights. This is closer to standard Transformer attention."
    )

    # Check that each softmax row sums to 1
    row_sums = np.sum(attention_weights, axis=1)
    print_matrix("Softmax row sums", row_sums)

    # ------------------------------------------------------------
    # Demo 3: Optional tiny 2-head attention
    # ------------------------------------------------------------
    print("\n" + "=" * 70)
    print("DEMO 3: Optional Tiny 2-Head Attention")
    print("=" * 70)

    attn1, out1, attn2, out2, combined_output = two_head_attention_demo(x)

    print_matrix("Head 1 attention weights", attn1)
    print_matrix("Head 1 output", out1)
    print_matrix("Head 2 attention weights", attn2)
    print_matrix("Head 2 output", out2)
    print_matrix("Combined 2-head output", combined_output)

    print(
        "\nExplanation: Multi-head attention runs multiple attention heads. "
        "Each head can focus on different relationships between tokens."
    )

    # ------------------------------------------------------------
    # Final summary
    # ------------------------------------------------------------
    print("\n" + "=" * 70)
    print("Class Demo Summary")
    print("=" * 70)
    print("1. X is the input token matrix.")
    print("2. Q, K, and V are produced using matrix multiplication.")
    print("3. Q @ K.T creates token-to-token attention scores.")
    print("4. Softmax normalizes those scores.")
    print("5. The final output is produced by multiplying attention weights with V.")
    print("6. This is the core operation behind Transformer attention.")


if __name__ == "__main__":
    main()