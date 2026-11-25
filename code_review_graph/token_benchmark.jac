import from __future__ { annotations }

import logging, sqlite3;

import from pathlib { Path }

import from typing { Any }

glob logger: any = logging.getLogger(__name__);

glob _SAMPLE_QUESTIONS: any = [
    "how does authentication work",
    "what is the main entry point",
    "how are database connections managed",
    "what error handling patterns are used",
    "how do tests verify core functionality",
];

def estimate_tokens(text: str) -> int {
    return max(1, len(text) // 4);
}

def compute_naive_tokens(repo_root: Path) -> int {
    total: any = 0;
    exts: any = tuple(".py .js .ts .go .rs .java .c .cpp .rb .php .swift .kt".split());
    for ext in exts {
        for f in repo_root.rglob(f"*{ext}") {
            try {
                total += estimate_tokens(f.read_text(errors="replace"));
            } except OSError {
                continue;
            }
        }
    }
    return total;
}

def run_token_benchmark(
    store: GraphStore, repo_root: Path, questions: list[str] | None = None
) -> dict[str, Any] {
    if questions is None {
        questions = _SAMPLE_QUESTIONS;
    }

    using_default_questions: any = questions is _SAMPLE_QUESTIONS;
    try {
        cur: any = store._conn.execute("SELECT count(*) FROM embeddings");
        embedding_count: any = cur.fetchone()[0];
    } except sqlite3.OperationalError {
        embedding_count = 0;
    }
    if embedding_count == 0 and using_default_questions {
        logger.warning(
            "No embeddings found in this graph. The default sample questions are natural language and will not match via FTS5/LIKE alone — every reduction ratio is likely to be 0. Run `code-review-graph embed` first, or pass keyword-matching `questions=`.",
        );
    }

    naive_total: any = compute_naive_tokens(repo_root);

    results: any = [];
    for q in questions {
        search_results: any = hybrid_search(store, q, limit=5);
        graph_tokens: any = 0;
        for r in search_results {
            graph_tokens += estimate_tokens(`str(r));
            qn: any = r.get("qualified_name", "");
            edges: any = store.get_edges_by_source(qn)[:5];
            for e in edges {
                graph_tokens += estimate_tokens(`str(e));
            }
        }

        if graph_tokens > 0 {
            ratio: any = naive_total / graph_tokens;
        } else {
            ratio = 0;
        }
        results.append({
            "question": q,
            "naive_tokens": naive_total,
            "graph_tokens": graph_tokens,
            "reduction_ratio": round(ratio, 1),
        });
    }

    if results {
        total: any = sum(r["reduction_ratio"] for r in results);
        avg_ratio: any = `float(total) / len(results);
    } else {
        avg_ratio = 0.0;
    }

    return {
        "naive_corpus_tokens": naive_total,
        "per_question": results,
        "average_reduction_ratio": round(avg_ratio, 1),
        "summary": f"Graph queries use ~{avg_ratio:.0f}x fewer tokens than reading all source files",
    };
}
