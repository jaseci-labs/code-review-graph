impl run(repo_path: Path, store, config: dict) -> list[dict] {
    stats: any = store.get_stats();
    try {
        import from code_review_graph.flows { store_flows, trace_flows }
        t0: any = time.perf_counter();
        flows: any = trace_flows(store);
        store_flows(store, flows);
        flow_time: any = time.perf_counter() - t0;
    } except Exception as exc {
        logger.warning("Flow detection failed: %s", exc);
        flow_time = 0.0;
    }
    try {
        import from code_review_graph.communities { detect_communities, store_communities }
        t0 = time.perf_counter();
        comms: any = detect_communities(store);
        store_communities(store, comms);
        community_time: any = time.perf_counter() - t0;
    } except Exception as exc {
        logger.warning("Community detection failed: %s", exc);
        community_time = 0.0;
    }
    search_times: list[float] = [];
    for sq in config.get("search_queries", [])[:10] {
        t0 = time.perf_counter();
        store.search_nodes(sq["query"], limit=20);
        search_times.append(time.perf_counter() - t0);
    }

    avg_search_ms: any = round(sum(search_times) / max(len(search_times), 1) * 1000, 1);

    return [
        {
            "repo": config["name"],
            "file_count": stats.files_count,
            "node_count": stats.total_nodes,
            "edge_count": stats.total_edges,
            "flow_detection_seconds": round(flow_time, 3),
            "community_detection_seconds": round(community_time, 3),
            "search_avg_ms": avg_search_ms,
            "nodes_per_second": round(stats.total_nodes / max(flow_time, 0.001)),
        },
    ];
}
