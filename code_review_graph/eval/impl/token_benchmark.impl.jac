impl estimate_tokens(`obj: Any) -> int {
    return len(json.dumps(`obj, default=str)) // 4;
}

impl benchmark_review_workflow(repo_root: str, base: str = "HEAD~1") -> dict {
    get_minimal_context = importlib.import_module("code_review_graph.tools.context").get_minimal_context;
    detect_changes_func = importlib.import_module("code_review_graph.tools.review").detect_changes_func;

    total_tokens: any = 0;
    calls: any = [];
    result: any = get_minimal_context(task="review changes", repo_root=repo_root, base=base);
    tokens: any = estimate_tokens(result);
    total_tokens += tokens;
    calls.append({"tool": "get_minimal_context", "tokens": tokens});
    result = detect_changes_func(base=base, repo_root=repo_root, detail_level="minimal");
    tokens = estimate_tokens(result);
    total_tokens += tokens;
    calls.append({"tool": "detect_changes_minimal", "tokens": tokens});

    return {
        "workflow": "review",
        "total_tokens": total_tokens,
        "tool_calls": len(calls),
        "calls": calls,
    };
}

impl benchmark_architecture_workflow(repo_root: str) -> dict {
    list_communities_func = importlib.import_module("code_review_graph.tools.community_tools").list_communities_func;
    get_minimal_context = importlib.import_module("code_review_graph.tools.context").get_minimal_context;
    list_flows = importlib.import_module("code_review_graph.tools.flows_tools").list_flows;

    total_tokens: any = 0;
    calls: any = [];

    result: any = get_minimal_context(task="map architecture", repo_root=repo_root);
    tokens: any = estimate_tokens(result);
    total_tokens += tokens;
    calls.append({"tool": "get_minimal_context", "tokens": tokens});

    result = list_communities_func(repo_root=repo_root, detail_level="minimal");
    tokens = estimate_tokens(result);
    total_tokens += tokens;
    calls.append({"tool": "list_communities_minimal", "tokens": tokens});

    result = list_flows(repo_root=repo_root, detail_level="minimal");
    tokens = estimate_tokens(result);
    total_tokens += tokens;
    calls.append({"tool": "list_flows_minimal", "tokens": tokens});

    return {
        "workflow": "architecture",
        "total_tokens": total_tokens,
        "tool_calls": len(calls),
        "calls": calls,
    };
}

impl benchmark_debug_workflow(repo_root: str) -> dict {
    get_minimal_context = importlib.import_module("code_review_graph.tools.context").get_minimal_context;
    semantic_search_nodes = importlib.import_module("code_review_graph.tools.query").semantic_search_nodes;

    total_tokens: any = 0;
    calls: any = [];

    result: any = get_minimal_context(task="debug login bug", repo_root=repo_root);
    tokens: any = estimate_tokens(result);
    total_tokens += tokens;
    calls.append({"tool": "get_minimal_context", "tokens": tokens});

    result = semantic_search_nodes(query="login", repo_root=repo_root, detail_level="minimal");
    tokens = estimate_tokens(result);
    total_tokens += tokens;
    calls.append({"tool": "semantic_search_minimal", "tokens": tokens});

    return {
        "workflow": "debug",
        "total_tokens": total_tokens,
        "tool_calls": len(calls),
        "calls": calls,
    };
}

impl benchmark_onboard_workflow(repo_root: str) -> dict {
    get_minimal_context = importlib.import_module("code_review_graph.tools.context").get_minimal_context;
    list_graph_stats = importlib.import_module("code_review_graph.tools.query").list_graph_stats;

    total_tokens: any = 0;
    calls: any = [];

    result: any = get_minimal_context(task="onboard developer", repo_root=repo_root);
    tokens: any = estimate_tokens(result);
    total_tokens += tokens;
    calls.append({"tool": "get_minimal_context", "tokens": tokens});

    result = list_graph_stats(repo_root=repo_root);
    tokens = estimate_tokens(result);
    total_tokens += tokens;
    calls.append({"tool": "list_graph_stats", "tokens": tokens});

    return {
        "workflow": "onboard",
        "total_tokens": total_tokens,
        "tool_calls": len(calls),
        "calls": calls,
    };
}

impl benchmark_pre_merge_workflow(repo_root: str, base: str = "HEAD~1") -> dict {
    get_minimal_context = importlib.import_module("code_review_graph.tools.context").get_minimal_context;
    detect_changes_func = importlib.import_module("code_review_graph.tools.review").detect_changes_func;

    total_tokens: any = 0;
    calls: any = [];

    result: any = get_minimal_context(task="pre-merge check", repo_root=repo_root, base=base);
    tokens: any = estimate_tokens(result);
    total_tokens += tokens;
    calls.append({"tool": "get_minimal_context", "tokens": tokens});

    result = detect_changes_func(base=base, repo_root=repo_root, detail_level="minimal");
    tokens = estimate_tokens(result);
    total_tokens += tokens;
    calls.append({"tool": "detect_changes_minimal", "tokens": tokens});

    return {
        "workflow": "pre_merge",
        "total_tokens": total_tokens,
        "tool_calls": len(calls),
        "calls": calls,
    };
}

impl run_all_benchmarks(repo_root: str, base: str = "HEAD~1") -> list[dict] {
    results: any = [];
    for (name, fn) in ALL_WORKFLOWS.items() {
        try {
            if "base" in fn.__code__.co_varnames {
                result: any = fn(repo_root=repo_root, base=base);
            } else {
                result = fn(repo_root=repo_root);
            }
            results.append(result);
        } except Exception as e {
            logger.warning("Benchmark %s failed: %s", name, e);
            results.append({"workflow": name, "error": `str(e)});
        }
    }
    return results;
}
