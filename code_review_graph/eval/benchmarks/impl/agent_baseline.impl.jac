impl derive_search_terms(question: str) -> list[str] {
    extract_query_identifiers = lazy("search", "extract_query_identifiers");

    terms: list[str] = [];
    seen: set[str] = set[any]();
    for ident in extract_query_identifiers(question) {
        if ident not in seen {
            seen.add(ident);
            terms.append(ident);
        }
    }
    for word in question.split() {
        w: any = word.strip(".,;:!?\"'()[]{}`").lower();
        if len(w) >= 3 and w not in _STOPWORDS and w not in seen {
            seen.add(w);
            terms.append(w);
        }
    }
    return terms;
}

impl iter_source_files(repo_path: Path) -> Generator[any, any, any] {
    for path in sorted(repo_path.rglob("*")) {
        if path.suffix not in _SOURCE_EXTS or not path.is_file() {
            continue;
        }
        if `any(part in _SKIP_DIRS for part in path.parts) {
            continue;
        }
        yield path;
    }
}

impl grep_rank(repo_path: Path, terms: list[str], k: int = k_default_) -> list[tuple[str, int]] {
    lowered: any = [t.lower() for t in terms if t];
    if not lowered {
        return [];
    }
    test_intent: any = `bool(`set(lowered) & _TEST_INTENT_TERMS);
    scores: list[tuple[str, float]] = [];
    for path in iter_source_files(repo_path) {
        try {
            text: any = path.read_text(encoding="utf-8", errors="replace").lower();
        } except OSError {
            continue;
        }
        count: any = sum(text.count(term) for term in lowered);
        if count <= 0 {
            continue;
        }
        rel: any = `str(path.relative_to(repo_path));
        score: any = `float(count);
        if not test_intent and is_test_file(rel) {
            score *= _TEST_FILE_PENALTY;
        }
        scores.append((rel, score));
    }
    scores.sort(key=lambda (item) -> any { (-item[1], item[0]) });
    return [(rel, `int(round(score))) for (rel, score) in scores[:k]];
}

impl run(repo_path: Path, store, config: dict) -> list[dict] {
    questions: any = `list(config.get("agent_questions") or []);
    if not questions {
        questions = [sq["query"] for sq in config.get("search_queries", [])];
    }

    k: any = `int(config.get("agent_baseline_top_k", DEFAULT_TOP_K));
    results: list[dict] = [];

    for question in questions {
        terms: any = derive_search_terms(question);
        top: any = grep_rank(repo_path, terms, k=k);
        baseline_tokens: any = 0;
        for (rel, _count) in top {
            try {
                baseline_tokens += estimate_tokens(
                    (repo_path / rel).read_text(encoding="utf-8", errors="replace")
                );
            } except OSError {
                continue;
            }
        }

        row: dict = {
            "repo": config["name"],
            "question": question,
            "terms": " ".join(terms),
            "files_matched": len(top),
            "top_files": ";".join(rel for (rel, _) in top),
            "baseline_tokens": baseline_tokens,
            "graph_tokens": "",
            "baseline_to_graph_ratio": "",
            "status": "ok",
            "error": "",
        };

        try {
            hybrid_search = lazy("search", "hybrid_search");
            hits: any = hybrid_search(
                store,
                question,
                limit=5,
                provider=config.get("_embedding_provider"),
                model=config.get("_embedding_model"),
                repo_root=repo_path,
            );
        } except Exception as exc {
            logger.warning("hybrid_search failed on %r: %s", question, exc);
            row["status"] = "error";
            row["error"] = `str(exc)[:200];
            results.append(row);
            continue;
        }
        graph_tokens: any = 0;
        for hit in hits {
            graph_tokens += estimate_tokens(`str(hit));
            qn: any = hit.get("qualified_name", "");
            for `edge in store.get_edges_by_source(qn)[:5] {
                graph_tokens += estimate_tokens(`str(`edge));
            }
        }

        row["graph_tokens"] = graph_tokens;
        if baseline_tokens > 0 and graph_tokens > 0 {
            row["baseline_to_graph_ratio"] = round(baseline_tokens / graph_tokens, 1);
        } elif graph_tokens == 0 {
            row["status"] = "no_graph_results";
        } else {
            row["status"] = "no_baseline_match";
        }
        results.append(row);
    }

    return results;
}

impl aggregate(results: list[dict]) -> dict {
    ok: any = [r for r in results if r.get("status") == "ok"];
    ratios: any = [`float(r["baseline_to_graph_ratio"]) for r in ok];
    no_graph: any = sum(1 for r in results if r.get("status") == "no_graph_results");
    return {
        "total_rows": len(results),
        "ok_rows": len(ok),
        "error_rows": sum(1 for r in results if r.get("status") == "error"),
        "no_graph_results_rows": no_graph,
        "no_baseline_match_rows": sum(1 for r in results if r.get("status") == "no_baseline_match"),
        "median_baseline_to_graph_ratio": round(statistics.median(ratios), 1) if ratios else None,
        "mean_baseline_to_graph_ratio": round(statistics.mean(ratios), 1) if ratios else None,
    };
}
