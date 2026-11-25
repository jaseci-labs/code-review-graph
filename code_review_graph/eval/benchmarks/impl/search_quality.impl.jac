impl run(repo_path: Path, store, config: dict) -> list[dict] {
    results: any = [];
    for sq in config.get("search_queries", []) {
        query: any = sq["query"];
        expected: any = sq["expected"];

        try {
            hybrid_search = lazy("search", "hybrid_search");
            search_results: any = hybrid_search(
                store,
                query,
                limit=20,
                provider=config.get("_embedding_provider"),
                model=config.get("_embedding_model"),
            );
        } except (ImportError, sqlite3.OperationalError) as exc {
            logger.debug("hybrid_search unavailable, using fallback: %s", exc);
            search_results = [
                {"qualified_name": n.qualified_name}
                for n in store.search_nodes(query, limit=20)
            ];
        }

        rank: any = 0;
        for (i, r) in enumerate(search_results) {
            if isinstance(r, `dict) {
                qn: any = r.get("qualified_name", "");
            } elif hasattr(r, "qualified_name") {
                qn = r.qualified_name;
            } else {
                qn = "";
            }
            qn_lower: any = qn.lower();
            exp_lower: any = expected.lower();
            exp_name: any = expected.rsplit("::", 1)[-1] if "::" in expected else expected;
            qn_name: any = qn.rsplit("::", 1)[-1] if "::" in qn else qn;
            if exp_lower in qn_lower
                or qn_lower in exp_lower
                or exp_name.lower() == qn_name.lower()
            {
                rank = i + 1;
                break;
            }
        }

        results.append({
            "repo": config["name"],
            "query": query,
            "expected": expected,
            "rank": rank,
            "reciprocal_rank": round(1.0 / rank if rank > 0 else 0.0, 3),
        });
    }
    return results;
}
