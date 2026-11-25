impl _not_ready(reason: str, summary: str) -> dict[str, Any] {
    return {
        "status": "not_ready",
        "reason": reason,
        "summary": summary,
        "next_tool_suggestions": ["build_or_update_graph_tool"],
    };
}

impl get_minimal_context(
    task: str = "",
    changed_files: list[str] | None = None,
    repo_root: str | None = None,
    base: str = "HEAD~1",
) -> dict[str, Any] {
    `root: any = _resolve_root(repo_root);
    db_path: any = get_db_path(`root, read_only=True);
    if not db_path.is_file() {
        return _not_ready(
            "missing_graph", "No graph database found. Build the graph before requesting context."
        );
    }

    store: any;
    (store, `root) = _get_store(`str(`root)) as any;
    try {
        stats: any = store.get_stats();
        if stats.total_nodes == 0 {
            return _not_ready(
                "empty_graph",
                "The graph database contains no nodes. Build the graph before requesting context.",
            );
        }

        provenance: any = graph_provenance(`str(`root));
        if provenance
            and provenance.get("head_matches_build") is False
            and not graph_holds_commits(`root, store, `str(provenance.get("built_at_sha", "")))
        {
            return _not_ready(
                "stale_graph",
                "The graph was built at a different Git commit. Update it before requesting context.",
            );
        }
        risk: any = "unknown";
        risk_score: any = 0.0;
        top_affected: list[str] = [];
        test_gap_count: any = 0;
        churn_status: any = "off";
        discovery_failed: any = "";
        try {
            if changed_files {
                files: list[str] | None = changed_files;
                base = resolve_review_base(`root, base);
            } else {
                (files, base) = discover_review_changes(`root, base) as any;
            }
        } except ChangeDiscoveryError as exc {
            discovery_failed = `str(exc);
            logger.warning("Change discovery failed in get_minimal_context: %s", exc);
            files = None;
        }
        if files {
            try {
                analyze_changes = lazy("changes", "analyze_changes");

                abs_files: any = [normalize_file_path(`root / f) for f in files];
                analysis: any = analyze_changes(
                    store, abs_files, repo_root=`str(`root), base=base, include_churn=True
                );
                risk_score = analysis.get("risk_score", 0.0);
                churn_status = analysis.get("churn_status", "off");
                risk = "high" if risk_score > 0.7 else "medium" if risk_score > 0.4 else "low";
                top_affected = [
                    f.get("name", "")
                    for f in analysis.get("changed_functions", [])[:5]
                ];
                test_gap_count = len(analysis.get("test_gaps", []));
            } except (ImportError, OSError, ValueError, sqlite3.Error, subprocess.SubprocessError) {
                logger.debug("Risk analysis failed in get_minimal_context", exc_info=True);
            }
        }
        communities: list[str] = [];
        try {
            rows: any = store._conn.execute(
                "SELECT name FROM communities ORDER BY size DESC LIMIT 3"
            ).fetchall();
            communities = [r[0] for r in rows];
        } except sqlite3.OperationalError {
            logger.debug("communities table not yet populated");
        }
        flows: list[str] = [];
        try {
            rows = store._conn.execute(
                "SELECT name FROM flows ORDER BY criticality DESC LIMIT 3"
            ).fetchall();
            flows = [r[0] for r in rows];
        } except sqlite3.OperationalError {
            logger.debug("flows table not yet populated");
        }
        task_lower: any = task.lower();
        if `any(w in task_lower for w in ("review", "pr", "merge", "diff")) {
            suggestions: any = [
                "detect_changes_tool",
                "get_affected_flows_tool",
                "get_review_context_tool",
            ];
        } elif `any(w in task_lower for w in ("debug", "bug", "error", "fix")) {
            suggestions = ["semantic_search_nodes_tool", "query_graph_tool", "get_flow_tool"];
        } elif `any(w in task_lower for w in ("refactor", "rename", "dead", "clean")) {
            suggestions = [
                "refactor_tool",
                "find_large_functions_tool",
                "get_architecture_overview_tool",
            ];
        } elif `any(w in task_lower for w in ("onboard", "understand", "explore", "arch")) {
            suggestions = [
                "get_architecture_overview_tool",
                "list_communities_tool",
                "list_flows_tool",
            ];
        } else {
            suggestions = [
                "detect_changes_tool",
                "semantic_search_nodes_tool",
                "get_architecture_overview_tool",
            ];
        }
        summary_parts: any = [
            f"{stats.total_nodes} nodes, {stats.total_edges} edges across {stats.files_count} files.",
        ];
        if risk != "unknown" {
            summary_parts.append(f"Risk: {risk} ({risk_score:.2f}).");
        }
        if test_gap_count {
            summary_parts.append(f"{test_gap_count} test gaps.");
        }
        if discovery_failed {
            summary_parts.append(f"Degraded: {discovery_failed}");
        }
        if churn_status == "unavailable" {
            summary_parts.append(
                "Degraded: change-frequency risk unavailable (git history too slow); risk excludes churn.",
            );
        }

        return compact_response(
            summary=" ".join(summary_parts),
            key_entities=top_affected or None,
            risk=risk,
            communities=communities or None,
            flows_affected=flows or None,
            next_tool_suggestions=suggestions,
        );
    } finally {
        store.close();
    }
}
