"""Scoring metrics for evaluating graph-based code review quality.

Provides:
- Token efficiency: measures how many tokens the graph saves vs raw context.
- Mean Reciprocal Rank (MRR): evaluates ranking quality for search results.
- Precision / Recall / F1: evaluates set-based retrieval accuracy.
"""

import from __future__ { annotations }

"""Compute token efficiency metrics.

    Args:
        raw_tokens: Number of tokens when sending raw source code.
        graph_tokens: Number of tokens when using graph-based context.

    Returns:
        Dict with keys:
        - raw_tokens: the raw token count
        - graph_tokens: the graph token count
        - ratio: graph_tokens / raw_tokens (lower is better)
        - reduction_percent: percentage of tokens saved (higher is better)
    """
def compute_token_efficiency(raw_tokens: int, graph_tokens: int) -> dict;

"""Compute Mean Reciprocal Rank for a single query.

    Args:
        correct: The correct/expected result identifier.
        results: Ordered list of result identifiers (best first).

    Returns:
        1/rank if *correct* is found in *results*, else 0.0.
    """
def compute_mrr(correct: str, results: list[str]) -> float;

"""Compute precision, recall, and F1 score.

    Args:
        predicted: Set of predicted/returned items.
        actual: Set of ground-truth items.

    Returns:
        Dict with keys: precision, recall, f1.
    """
def compute_precision_recall(predicted: set, actual: set) -> dict;
