import from __future__ { annotations }

def compute_token_efficiency(raw_tokens: int, graph_tokens: int) -> dict;
def compute_mrr(correct: str, results: list[str]) -> float;
def compute_precision_recall(predicted: set, actual: set) -> dict;
