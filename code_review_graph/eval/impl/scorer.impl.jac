impl compute_token_efficiency(raw_tokens: int, graph_tokens: int) -> dict {
    if raw_tokens <= 0 {
        return {
            "raw_tokens": raw_tokens,
            "graph_tokens": graph_tokens,
            "ratio": 0.0,
            "reduction_percent": 0.0,
        };
    }
    ratio: any = graph_tokens / raw_tokens;
    reduction: any = (1.0 - ratio) * 100.0;
    return {
        "raw_tokens": raw_tokens,
        "graph_tokens": graph_tokens,
        "ratio": round(ratio, 4),
        "reduction_percent": round(reduction, 2),
    };
}

impl compute_mrr(correct: str, results: list[str]) -> float {
    for (i, r) in enumerate(results, 1) {
        if r == correct {
            return 1.0 / i;
        }
    }
    return 0.0;
}

impl compute_precision_recall(predicted: set, actual: set) -> dict {
    if not predicted and not actual {
        return {"precision": 1.0, "recall": 1.0, "f1": 1.0};
    }

    true_positive: any = len(predicted & actual);
    precision: any = true_positive / len(predicted) if predicted else 0.0;
    recall: any = true_positive / len(actual) if actual else 0.0;

    if precision + recall > 0 {
        f1: any = 2 * precision * recall / (precision + recall);
    } else {
        f1 = 0.0;
    }

    return {"precision": round(precision, 4), "recall": round(recall, 4), "f1": round(f1, 4)};
}
