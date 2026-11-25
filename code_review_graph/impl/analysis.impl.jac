impl find_hub_nodes(store: GraphStore, top_n: int = 10) -> list[dict] {
    edges: any = store.get_all_edges();
    in_degree: dict[str, int] = Counter();
    out_degree: dict[str, int] = Counter();
    for e in edges {
        out_degree[e.source_qualified] += 1;
        in_degree[e.target_qualified] += 1;
    }
    nodes: any = store.get_all_nodes(exclude_files=True);
    community_map: any = store.get_all_community_ids();

    scored: any = [];
    for n in nodes {
        qn: any = n.qualified_name;
        ind: any = in_degree.get(qn, 0);
        outd: any = out_degree.get(qn, 0);
        total: any = ind + outd;
        if total == 0 {
            continue;
        }
        scored.append({
            "name": _sanitize_name(n.name),
            "qualified_name": n.qualified_name,
            "kind": n.kind,
            "file": n.file_path,
            "in_degree": ind,
            "out_degree": outd,
            "total_degree": total,
            "community_id": community_map.get(qn),
        });
    }

    scored.sort(key=lambda (x) -> any { x.get("total_degree", 0) }, reverse=True);
    return scored[:top_n];
}

impl find_bridge_nodes(store: GraphStore, top_n: int = 10) -> list[dict] {
    n: any;
    import networkx as nx;
    nxg: any = store._build_networkx_graph();
    n_nodes: any = nxg.number_of_nodes();
    if n_nodes > 5000 {
        k: any = min(500, n_nodes);
        bc: any = nx.betweenness_centrality(nxg, k=k, normalized=True);
    } elif n_nodes > 0 {
        bc = nx.betweenness_centrality(nxg, normalized=True);
    } else {
        return [];
    }

    community_map: any = store.get_all_community_ids();
    node_map: any = {n.qualified_name: n for n in store.get_all_nodes(exclude_files=True)};

    results: any = [];
    for (qn, score) in bc.items() {
        if score <= 0 or qn not in node_map {
            continue;
        }
        n = node_map[qn];
        if n.kind == "File" {
            continue;
        }
        results.append({
            "name": _sanitize_name(n.name),
            "qualified_name": n.qualified_name,
            "kind": n.kind,
            "file": n.file_path,
            "betweenness": round(score, 6),
            "community_id": community_map.get(qn),
        });
    }

    results.sort(key=lambda (x) -> any { `float(x.get("betweenness", 0)) }, reverse=True);
    del nxg, bc;
    store.shrink_memory(clear_nx_cache=True);
    return results[:top_n];
}

impl _shortest_loop(adjacency: dict[str, set[str]], start: str) -> list[str] {
    came_from: dict[str, str] = {};
    queue: any = deque([start]);
    while queue {
        current: any = queue.popleft();
        for neighbour in sorted(adjacency.get(current, ())) {
            if neighbour == start {
                loop: any = [current];
                while loop[-1] != start {
                    loop.append(came_from[loop[-1]]);
                }
                return loop[::-1];
            }
            if neighbour not in came_from {
                came_from[neighbour] = current;
                queue.append(neighbour);
            }
        }
    }
    return [start];
}

impl find_import_cycles(
    store: GraphStore, edges: list[GraphEdge] | None = None, repo_root: Path | None = None
) -> list[dict] {
    prefix: any;
    group: any;
    import networkx as nx;

    files: any = `set(store.get_all_files());
    all_imports: dict[tuple[str, str], int] = {};
    load_imports: dict[tuple[str, str], int] = {};
    for `edge in store.get_all_edges() if edges is None else edges {
        source: any;
        target: any;
        (source, target) = (`edge.source_qualified, `edge.target_qualified);
        if `edge.kind != "IMPORTS_FROM"
            or source == target
            or source not in files
            or target not in files
        {
            continue;
        }
        context: any = `edge.extra.get(IMPORT_CONTEXT_KEY);
        if context in (IMPORT_CONTEXT_TYPE_ONLY, IMPORT_CONTEXT_PARENT_PACKAGE) {
            continue;
        }
        pair: any = (source, target);
        all_imports[pair] = min(all_imports.get(pair, `edge.line), `edge.line);
        if context != IMPORT_CONTEXT_DEFERRED {
            load_imports[pair] = min(load_imports.get(pair, `edge.line), `edge.line);
        }
    }

    groups: any = [
        group
        for group in nx.strongly_connected_components(nx.DiGraph(`list(all_imports)))
        if len(group) > 1
    ];
    if not groups {
        return [];
    }
    load_groups: any = sorted(
        (group
        for group in nx.strongly_connected_components(nx.DiGraph(`list(load_imports)))
        if len(group) > 1),
        key=lambda (group) -> any { (-len(group), min(group)) },
    );

    prefix = f"{normalize_file_path(repo_root)}/" if repo_root else "";

    """Drop the repository's own folder: it would repeat in every row."""
    def short(path: str) -> str {
        return _sanitize_name(path.removeprefix(prefix));
    }

    def adjacency(imports: dict[tuple[str, str], int]) -> dict[str, set[str]] {
        result: dict[str, set[str]] = defaultdict(set[any]);
        for (source, target) in imports {
            result[source].add(target);
        }
        return result;
    }

    all_adjacency: any = adjacency(all_imports);
    load_adjacency: any = adjacency(load_imports);

    cycles: list[dict] = [];
    for group_ in groups {
        group = group_;
        load_group: any = next((g for g in load_groups if g <= group), None);
        if load_group is not None {
            loop: any = _shortest_loop(load_adjacency, min(load_group));
        } else {
            loop = _shortest_loop(all_adjacency, min(group));
        }
        hops: any = `list(zip(loop, loop[1:] + loop[:1]));
        cycles.append({
            "name": _sanitize_name(" -> ".join(short(path) for path in [*loop, loop[0]])),
            "size": len(group),
            "load_time": load_group is not None,
            "files": [short(path) for path in sorted(group)[:_MAX_CYCLE_FILES]],
            "loop_length": len(loop),
            "cycle": [
                {
                    "file": short(source),
                    "line": load_imports.get((source, target), all_imports[source, target]),
                    "imports": short(target),
                }
                for (source, target) in hops[:_MAX_CYCLE_HOPS]
            ],
        });
    }
    cycles.sort(key=lambda (c) -> any { (not c["load_time"], -c["size"], c["name"]) });
    return cycles;
}

impl find_knowledge_gaps(
    store: GraphStore, repo_root: Path | None = None
) -> dict[str, list[dict]] {
    edges: any = store.get_all_edges();
    nodes: any = store.get_all_nodes(exclude_files=True);
    community_map: any = store.get_all_community_ids();
    degree: dict[str, int] = Counter();
    tested_nodes: set[str] = set[any]();
    for e in edges {
        degree[e.source_qualified] += 1;
        degree[e.target_qualified] += 1;
        if e.kind == "TESTED_BY" {
            tested_nodes.add(e.source_qualified);
        }
    }
    isolated: any = [];
    n: any;
    for n in nodes {
        d: any = degree.get(n.qualified_name, 0);
        if d <= 1 {
            isolated.append({
                "name": _sanitize_name(n.name),
                "qualified_name": n.qualified_name,
                "kind": n.kind,
                "file": n.file_path,
                "degree": d,
            });
        }
    }
    comm_sizes: Counter[int] = Counter();
    comm_files: dict[int, set[str]] = defaultdict(set[any]);
    for n in nodes {
        cid: any = community_map.get(n.qualified_name);
        if cid is not None {
            comm_sizes[cid] += 1;
            comm_files[cid].add(n.file_path);
        }
    }
    communities: any = store.get_communities_list();
    thin: any = [];
    c: any;
    for c in communities {
        cid = `int(c["id"]);
        size: any = comm_sizes.get(cid, 0);
        if size < 3 {
            thin.append({"community_id": cid, "name": `str(c["name"]), "size": size});
        }
    }
    untested_hotspots: any = [];
    for n in nodes {
        d = degree.get(n.qualified_name, 0);
        if d >= 5 and n.qualified_name not in tested_nodes and not n.is_test {
            untested_hotspots.append({
                "name": _sanitize_name(n.name),
                "qualified_name": n.qualified_name,
                "kind": n.kind,
                "file": n.file_path,
                "degree": d,
            });
        }
    }
    untested_hotspots.sort(key=lambda (x) -> any { x.get("degree", 0) }, reverse=True);
    single_file: any = [];
    for c in communities {
        cid = `int(c["id"]);
        files: any = comm_files.get(cid, set[any]());
        size = comm_sizes.get(cid, 0);
        if len(files) == 1 and size >= 3 {
            single_file.append({
                "community_id": cid,
                "name": `str(c["name"]),
                "size": size,
                "file": next(iter(files)),
            });
        }
    }

    return {
        "isolated_nodes": isolated[:50],
        "thin_communities": thin,
        "untested_hotspots": untested_hotspots[:20],
        "single_file_communities": single_file,
        "import_cycles": find_import_cycles(store, edges, repo_root),
    };
}

impl find_surprising_connections(store: GraphStore, top_n: int = 15) -> list[dict] {
    edges: any = store.get_all_edges();
    nodes: any = store.get_all_nodes(exclude_files=True);
    community_map: any = store.get_all_community_ids();

    node_map: any = {n.qualified_name: n for n in nodes};
    degree: dict[str, int] = Counter();
    e: any;
    for e in edges {
        degree[e.source_qualified] += 1;
        degree[e.target_qualified] += 1;
    }
    degrees: any = [d for d in degree.values() if d > 0];
    if not degrees {
        return [];
    }
    median_deg: any = sorted(degrees)[len(degrees) // 2];
    high_deg_threshold: any = max(median_deg * 3, 10);

    scored_edges: any = [];
    for e in edges {
        src: any = node_map.get(e.source_qualified);
        tgt: any = node_map.get(e.target_qualified);
        if not src or not tgt {
            continue;
        }
        if src.kind == "File" or tgt.kind == "File" {
            continue;
        }

        score: any = 0.0;
        reasons: any = [];
        src_cid: any = community_map.get(e.source_qualified);
        tgt_cid: any = community_map.get(e.target_qualified);
        if src_cid is not None and tgt_cid is not None and src_cid != tgt_cid {
            score += 0.3;
            reasons.append("cross-community");
        }
        src_lang: any = src.file_path.rsplit(".", 1)[-1] if "." in src.file_path else "";
        tgt_lang: any = tgt.file_path.rsplit(".", 1)[-1] if "." in tgt.file_path else "";
        if src_lang and tgt_lang and src_lang != tgt_lang {
            score += 0.2;
            reasons.append("cross-language");
        }
        src_deg: any = degree.get(e.source_qualified, 0);
        tgt_deg: any = degree.get(e.target_qualified, 0);
        if src_deg <= 2 and tgt_deg >= high_deg_threshold
            or tgt_deg <= 2 and src_deg >= high_deg_threshold
        {
            score += 0.2;
            reasons.append("peripheral-to-hub");
        }
        if src.is_test != tgt.is_test and e.kind == "CALLS" {
            score += 0.15;
            reasons.append("cross-test-boundary");
        }
        if e.kind == "CALLS" and src.kind == "Type" {
            score += 0.15;
            reasons.append("unusual-edge-kind");
        }

        if score > 0 {
            scored_edges.append({
                "source": _sanitize_name(src.name),
                "source_qualified": e.source_qualified,
                "target": _sanitize_name(tgt.name),
                "target_qualified": e.target_qualified,
                "edge_kind": e.kind,
                "surprise_score": round(score, 2),
                "reasons": reasons,
                "source_community": src_cid,
                "target_community": tgt_cid,
            });
        }
    }

    scored_edges.sort(key=lambda (x) -> any { `float(x.get("surprise_score", 0)) }, reverse=True);
    return scored_edges[:top_n];
}

impl generate_suggested_questions(store: GraphStore) -> list[dict] {
    questions: any = [];
    bridges: any = find_bridge_nodes(store, top_n=3);
    for b in bridges {
        questions.append({
            "category": "bridge_node",
            "question": "'"
                + format(b["name"], "")
                + "' is a critical connector between multiple code regions. Is it adequately tested and documented?",
            "target": b["qualified_name"],
            "priority": "high",
        });
    }
    hubs: any = find_hub_nodes(store, top_n=3);
    edges: any = store.get_all_edges();
    tested: any = {e.source_qualified for e in edges if e.kind == "TESTED_BY"};
    h: any;
    for h in hubs {
        if h["qualified_name"] not in tested {
            questions.append({
                "category": "hub_risk",
                "question": "Hub node '"
                    + format(h["name"], "")
                    + "' has "
                    + format(h["total_degree"], "")
                    + " connections but no direct test coverage. Should it be tested?",
                "target": h["qualified_name"],
                "priority": "high",
            });
        }
    }
    surprises: any = find_surprising_connections(store, top_n=3);
    for s in surprises {
        if "cross-community" in s["reasons"] {
            questions.append({
                "category": "surprising_connection",
                "question": "'"
                    + format(s["source"], "")
                    + "' (community "
                    + format(s["source_community"], "")
                    + ") calls '"
                    + format(s["target"], "")
                    + "' (community "
                    + format(s["target_community"], "")
                    + "). Is this coupling intentional?",
                "target": s["source_qualified"],
                "priority": "medium",
            });
        }
    }
    gaps: any = find_knowledge_gaps(store);

    for c in gaps["thin_communities"][:2] {
        questions.append({
            "category": "thin_community",
            "question": "Community '"
                + format(c["name"], "")
                + "' has only "
                + format(c["size"], "")
                + " member(s). Should it be merged with a neighbor?",
            "target": "community:" + format(c["community_id"], ""),
            "priority": "low",
        });
    }

    for h in gaps["untested_hotspots"][:2] {
        questions.append({
            "category": "untested_hotspot",
            "question": "'"
                + format(h["name"], "")
                + "' has "
                + format(h["degree"], "")
                + " connections but no test coverage. Is this a risk?",
            "target": h["qualified_name"],
            "priority": "medium",
        });
    }

    return questions;
}
