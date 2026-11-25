impl _name_set(rows: list[dict[str, Any]]) -> set[str] {
    out: set[str] = set[any]();
    for r in rows {
        name: any = (r.get("name") or "").lower();
        if name {
            out.add(name);
        }
    }
    return out;
}

impl run(repo_path: Path, store, config: dict) -> list[dict] {
    hybrid_search = lazy("search", "hybrid_search");
    query_graph = lazy("tools.query", "query_graph");

    repo_root: any = `str(repo_path);
    results: list[dict] = [];

    for task in config.get("multi_hop_tasks", []) {
        task_id: any = task["id"];
        nl_query: any = task["nl_query"];
        suffix: any = task["anchor_qualified_suffix"].lower();
        traversal: any = task.get("traversal_pattern", "callers_of");
        expected: any = [e.lower() for e in task.get("expected_neighbor_names", [])];
        k: any = `int(task.get("k", 10));
        try {
            hits: any = hybrid_search(
                store,
                nl_query,
                limit=k,
                provider=config.get("_embedding_provider"),
                model=config.get("_embedding_model"),
            );
        } except Exception as exc {
            logger.warning("hybrid_search failed on %s: %s", task_id, exc);
            hits = [];
        }

        anchor: any = None;
        anchor_rank: any = -1;
        for (i, h) in enumerate(hits) {
            qn: any = (h.get("qualified_name") or "").lower();
            if qn.endswith(suffix) {
                anchor = h;
                anchor_rank = i;
                break;
            }
        }

        if anchor is None {
            results.append({
                "repo": config["name"],
                "task_id": task_id,
                "nl_query": nl_query,
                "anchor_found": False,
                "anchor_rank": -1,
                "neighbor_count": 0,
                "expected_count": len(expected),
                "matched_count": 0,
                "neighbor_recall": 0.0,
                "score": 0.0,
            });
            continue;
        }
        try {
            trav: any = query_graph(
                pattern=traversal,
                target=anchor["qualified_name"],
                repo_root=repo_root,
                detail_level="standard",
            );
        } except Exception as exc {
            logger.warning("query_graph(%s) failed on %s: %s", traversal, task_id, exc);
            trav = {};
        }

        rows: any = trav.get("data") or trav.get("results") or [];
        names: any = _name_set(rows);
        matched: any = sum(1 for e in expected if e in names);
        recall: any = matched / len(expected) if expected else 0.0;

        results.append({
            "repo": config["name"],
            "task_id": task_id,
            "nl_query": nl_query,
            "anchor_found": True,
            "anchor_rank": anchor_rank,
            "neighbor_count": len(rows),
            "expected_count": len(expected),
            "matched_count": matched,
            "neighbor_recall": round(recall, 3),
            "score": round(recall, 3),
        });
    }

    return results;
}
