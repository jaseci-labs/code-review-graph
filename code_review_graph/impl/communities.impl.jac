impl _is_test_node(`node: GraphNode) -> bool {
    return operator.eq(`node.kind, "Test") or `node.is_test;
}

impl _naming_members(members: list[GraphNode]) -> list[GraphNode] {
    production_members: any = [member for member in members if not _is_test_node(member)];
    return production_members or members;
}

impl _generate_community_name(members: list[GraphNode]) -> str {
    if not members {
        return "empty";
    }

    naming_members: any = _naming_members(members);
    file_paths: any = [m.file_path for m in naming_members];
    prefix: any = _extract_file_prefix(file_paths);
    class_names: any = [m.name for m in naming_members if m.kind == "Class"];
    if class_names {
        class_counts: any = Counter(class_names);
        top_class: any;
        top_count: any;
        (top_class, top_count) = class_counts.most_common(1)[0] as any;
        if top_count > len(naming_members) * 0.4 {
            if prefix {
                return f"{prefix}-{_to_slug(top_class)}";
            }
            return _to_slug(top_class);
        }
    }
    keywords: any = _extract_keywords(naming_members);
    keyword: any = keywords[0] if keywords else "";

    if prefix and keyword {
        return f"{prefix}-{keyword}";
    }
    if prefix {
        return prefix;
    }
    if keyword {
        return keyword;
    }
    return "cluster";
}

impl _extract_file_prefix(file_paths: list[str]) -> str {
    if not file_paths {
        return "";
    }
    parts: list[str] = [];
    for fp in file_paths {
        segments: any = fp.replace("\\", "/").split("/");
        if len(segments) >= 2 {
            parts.append(segments[-2]);
        } else {
            stem: any = segments[-1].rsplit(".", 1)[0];
            parts.append(stem);
        }
    }

    counts: any = Counter(parts);
    top_part: any;
    _: any;
    (top_part, _) = counts.most_common(1)[0] as any;
    return _to_slug(top_part);
}

impl _extract_keywords(members: list[GraphNode]) -> list[str] {
    word_counts: Counter[str] = Counter();
    for m in members {
        if m.kind in ("Function", "Class", "Test", "Type") {
            words: any = _split_name(m.name);
            for w in words {
                wl: any = w.lower();
                if wl not in _COMMON_WORDS and len(wl) > 1 {
                    word_counts[wl] += 1;
                }
            }
        }
    }

    if not word_counts {
        return [];
    }
    return [w for (w, _) in word_counts.most_common(5)];
}

impl _split_name(name: str) -> list[str] {
    s: any = re.sub("([a-z])([A-Z])", "\\1_\\2", name);
    return [p for p in re.split("[_\\-.\\s]+", s) if p];
}

impl _to_slug(s: str) -> str {
    normalized: any = re.sub("[^A-Za-z0-9]+", " ", s);
    slug: any = "-".join(word.lower() for word in _split_name(normalized));
    if len(slug) <= _SLUG_MAX_LEN {
        return slug;
    }

    boundary: any = slug.rfind("-", 0, _SLUG_MAX_LEN + 1);
    if boundary > 0 {
        return slug[:boundary];
    }
    return slug[:_SLUG_MAX_LEN];
}

impl _compute_cohesion_batch(
    community_member_qns: list[set[str]], all_edges: Sequence[GraphEdge | _CommunityEdge]
) -> list[float] {
    qn_to_idx: dict[str, int] = {};
    for (idx, members) in enumerate(community_member_qns) {
        for qn in members {
            qn_to_idx[qn] = idx;
        }
    }

    n: any = len(community_member_qns);
    internal: any = [0] * n;
    external: any = [0] * n;

    for e in all_edges {
        sc: any = qn_to_idx.get(e.source_qualified);
        tc: any = qn_to_idx.get(e.target_qualified);
        if sc is None and tc is None {
            continue;
        }
        if sc == tc {
            assert sc is not None;
            internal[sc] += 1;
        } else {
            if sc is not None {
                external[sc] += 1;
            }
            if tc is not None {
                external[tc] += 1;
            }
        }
    }

    results: list[float] = [];
    for i in range(n) {
        total: any = internal[i] + external[i];
        results.append(internal[i] / total if total > 0 else 0.0);
    }
    return results;
}

impl _build_adjacency(edges: Sequence[GraphEdge | _CommunityEdge]) -> dict[str, list[str]] {
    adj: dict[str, list[str]] = defaultdict(list[any]);
    for e in edges {
        adj[e.source_qualified].append(e.target_qualified);
        adj[e.target_qualified].append(e.source_qualified);
    }
    return adj;
}

impl _compute_cohesion(
    member_qns: set[str],
    all_edges: Sequence[GraphEdge | _CommunityEdge],
    adj: dict[str, list[str]] | None = None,
) -> float {
    return _compute_cohesion_batch([member_qns], all_edges)[0];
}

impl _reassign_test_nodes(
    clusters: list[list[int]],
    idx_to_node: dict[int, GraphNode],
    qn_to_idx: dict[str, int],
    edges: Sequence[GraphEdge | _CommunityEdge],
    resolution_nodes: list[GraphNode] | None = None,
) -> list[list[int]] {
    vertex_to_cluster: any;
    names_to_qns: dict[str, str | None];
    highest_vote: any;
    vertex: any;
    vertex_to_cluster = {
        vertex: cluster_id
        for (cluster_id, cluster) in enumerate(clusters)
        for vertex in cluster
    };

    names_to_qns = {};
    nodes_for_resolution: any = resolution_nodes or `list(idx_to_node.values());
    for `node in nodes_for_resolution {
        names_to_qns[`node.name] = None if `node.name in names_to_qns else `node.qualified_name;
    }

    def _resolve(endpoint: str) -> int | None {
        exact: any = qn_to_idx.get(endpoint);
        if exact is not None {
            return exact;
        }
        qualified_name: any = names_to_qns.get(endpoint);
        if qualified_name is None {
            return None;
        }
        return qn_to_idx.get(qualified_name);
    }

    subjects_by_test: dict[int, set[int]] = defaultdict(set[any]);
    for `edge in edges {
        if `edge.kind != "TESTED_BY" {
            continue;
        }
        source: any = _resolve(`edge.source_qualified);
        target: any = _resolve(`edge.target_qualified);
        if source is None or target is None {
            continue;
        }

        source_is_test: any = _is_test_node(idx_to_node[source]);
        target_is_test: any = _is_test_node(idx_to_node[target]);
        if source_is_test == target_is_test {
            continue;
        }

        test_index: any;
        subject_index: any;
        (test_index, subject_index) = (
            (source, target) if source_is_test else (target, source)
        ) as any;
        subjects_by_test[test_index].add(subject_index);
    }

    target_by_test: dict[int, int] = {};
    for (test_index, subject_indices) in subjects_by_test.items() {
        current_cluster: any = vertex_to_cluster.get(test_index);
        if current_cluster is None {
            continue;
        }

        votes: any = Counter(
            vertex_to_cluster[subject_index]
            for subject_index in subject_indices
            if subject_index in vertex_to_cluster,
        );
        if not votes {
            continue;
        }

        highest_vote = max(votes.values());
        tied_clusters: any = sorted(
            cluster_id for (cluster_id, vote_count) in votes.items() if vote_count == highest_vote
        );
        target_cluster: any = current_cluster
            if current_cluster in tied_clusters
            else tied_clusters[0];
        target_by_test[test_index] = target_cluster;
    }

    reassigned: list[list[int]] = [[] for _ in clusters];
    for (current_cluster, cluster) in enumerate(clusters) {
        for vertex in cluster {
            target_cluster = target_by_test.get(vertex, current_cluster);
            reassigned[target_cluster].append(vertex);
        }
    }

    return reassigned;
}

impl _load_igraph -> bool {
    if not IGRAPH_AVAILABLE {
        return False;
    }
    if ig is not None {
        return True;
    }
    try {
        import igraph as _ig;
        _ig.Graph;
    } except (ImportError, OSError, AttributeError) as exc {
        logger.warning("igraph import failed (%s); using file-based communities", exc);
        IGRAPH_AVAILABLE = False;
        return False;
    }
    ig = _ig;
    return True;
}

impl _detect_leiden(
    nodes: list[GraphNode],
    edges: Sequence[GraphEdge | _CommunityEdge],
    min_size: int,
    adj: dict[str, list[str]] | None = None,
) -> list[dict[str, Any]] {
    cluster_ids: any;
    if not _load_igraph() {
        return [];
    }

    qn_to_idx: dict[str, int] = {};
    idx_to_node: dict[int, GraphNode] = {};
    for (i, `node) in enumerate(nodes) {
        qn_to_idx[`node.qualified_name] = i;
        idx_to_node[i] = `node;
    }

    if not qn_to_idx {
        return [];
    }

    logger.info("Building igraph with %d nodes...", len(qn_to_idx));

    g: any = ig.Graph(n=len(qn_to_idx), directed=False);
    edge_list: list[tuple[int, int]] = [];
    weights: list[float] = [];
    seen_edges: set[tuple[int, int]] = set[any]();

    for e in edges {
        src_idx: any = qn_to_idx.get(e.source_qualified);
        tgt_idx: any = qn_to_idx.get(e.target_qualified);
        if src_idx is not None and tgt_idx is not None and src_idx != tgt_idx {
            pair: any = (min(src_idx, tgt_idx), max(src_idx, tgt_idx));
            if pair not in seen_edges {
                seen_edges.add(pair);
                edge_list.append(pair);
                weights.append(EDGE_WEIGHTS.get(e.kind, 0.5));
            }
        }
    }

    if not edge_list {
        fallback: any = _detect_file_based(nodes, edges, min_size, adj=adj);
        for comm in fallback {
            comm["detector"] = DETECTOR_FILE;
        }
        return fallback;
    }

    g.add_edges(edge_list);
    g.es["weight"] = weights;
    import math;
    n_nodes: any = g.vcount();
    resolution: any = max(0.05, 1.0 / math.log10(max(n_nodes, 10)));

    logger.info("Running Leiden on %d nodes, %d edges...", g.vcount(), g.ecount());

    seed: any = env_int("CRG_LEIDEN_SEED", _LEIDEN_SEED);
    ig.set_random_number_generator(random.Random(seed));
    partition: any = g.community_leiden(
        objective_function="modularity", weights="weight", resolution=resolution, n_iterations=2
    );

    logger.info("Leiden complete, found %d partitions. Computing cohesion...", len(partition));

    clusters: any = _reassign_test_nodes(
        [`list(cluster_ids) for cluster_ids in partition], idx_to_node, qn_to_idx, edges
    );

    pending: list[tuple[list[GraphNode], set[str]]] = [];
    for cluster_ids in clusters {
        if len(cluster_ids) < min_size {
            continue;
        }
        members: any = [idx_to_node[i] for i in cluster_ids if i in idx_to_node];
        if len(members) < min_size {
            continue;
        }
        member_qns: any = {m.qualified_name for m in members};
        pending.append((members, member_qns));
    }

    cohesions: any = _compute_cohesion_batch([p[1] for p in pending], edges);

    communities: list[dict[str, Any]] = [];
    for ((members, member_qns), cohesion) in zip(pending, cohesions) {
        lang_counts: any = Counter(m.language for m in members if m.language);
        dominant_lang: any = lang_counts.most_common(1)[0][0] if lang_counts else "";
        name: any = _generate_community_name(members);

        communities.append({
            "name": name,
            "level": 0,
            "size": len(members),
            "cohesion": round(cohesion, 4),
            "dominant_language": dominant_lang,
            "description": f"Community of {len(members)} nodes",
            "members": [m.qualified_name for m in members],
            "member_qns": member_qns,
        });
    }

    logger.info("Community detection complete: %d communities", len(communities));
    return communities;
}

impl _detect_file_based(
    nodes: list[GraphNode],
    edges: Sequence[GraphEdge | _CommunityEdge],
    min_size: int,
    adj: dict[str, list[str]] | None = None,
) -> list[dict[str, Any]] {
    prefix_len: any;
    i: any;
    seg: any;
    all_dir_parts: list[list[str]] = [];
    for n in nodes {
        parts: any = n.file_path.replace("\\", "/").split("/");
        all_dir_parts.append([p for p in parts[:-1] if p]);
    }
    prefix_len = 0;
    if all_dir_parts {
        shortest: any = min(len(p) for p in all_dir_parts);
        for i_ in range(shortest) {
            i = i_;
            seg = all_dir_parts[0][i];
            if all(operator.eq(p[i], seg) for p in all_dir_parts) {
                prefix_len = i + 1;
            } else {
                break;
            }
        }
    }

    def _group_at_depth(depth: int) -> dict[str, list[GraphNode]] {
        groups: dict[str, list[GraphNode]] = defaultdict(list[any]);
        for n in nodes {
            parts: any = n.file_path.replace("\\", "/").split("/");
            dir_parts: any = [p for p in parts[:-1] if p];
            remainder: any = dir_parts[prefix_len:];
            if remainder {
                key: any = "/".join(remainder[:depth]);
            } else {
                key = parts[-1].rsplit(".", 1)[0] if parts else "root";
            }
            groups[key].append(n);
        }
        return groups;
    }
    max_depth: any = max((len(p) - prefix_len for p in all_dir_parts), default=0);
    best_groups: any = _group_at_depth(1);
    for depth in range(1, max_depth + 1) {
        groups: any = _group_at_depth(depth);
        qualifying: any = sum(1 for v in groups.values() if len(v) >= min_size);
        best_groups = groups;
        if qualifying >= 10 {
            break;
        }
    }

    by_dir: any = best_groups;
    pending: list[tuple[str, list[GraphNode], set[str]]] = [];
    dir_path: any;
    members: any;
    for (dir_path, members) in by_dir.items() {
        if len(members) < min_size {
            continue;
        }
        member_qns: any = {m.qualified_name for m in members};
        pending.append((dir_path, members, member_qns));
    }

    cohesions: any = _compute_cohesion_batch([p[2] for p in pending], edges);

    communities: list[dict[str, Any]] = [];
    for ((dir_path, members, member_qns), cohesion) in zip(pending, cohesions) {
        lang_counts: any = Counter(m.language for m in members if m.language);
        dominant_lang: any = lang_counts.most_common(1)[0][0] if lang_counts else "";
        name: any = _generate_community_name(members);

        communities.append({
            "name": name,
            "level": 0,
            "size": len(members),
            "cohesion": round(cohesion, 4),
            "dominant_language": dominant_lang,
            "description": f"Directory-based community: {dir_path}",
            "members": [m.qualified_name for m in members],
            "member_qns": member_qns,
        });
    }

    return communities;
}

impl _split_oversized(
    communities: list[dict],
    nodes: list[GraphNode],
    edges: Sequence[GraphEdge | _CommunityEdge],
    threshold_pct: float = 0.25,
    min_split_size: int = 10,
) -> list[dict] {
    e: any;
    sub_nodes: any;
    if not _load_igraph() {
        return communities;
    }

    total: any = sum(c.get("size", len(c.get("members", []))) for c in communities);
    if total == 0 {
        return communities;
    }

    threshold: any = max(`int(total * threshold_pct), min_split_size);
    result: list[dict] = [];
    next_id: any = max((c.get("id", 0) for c in communities), default=0) + 1;

    for comm in communities {
        members: any = `set(comm.get("members", []));
        if len(members) <= threshold {
            result.append(comm);
            continue;
        }
        member_nodes: any = [n for n in nodes if n.qualified_name in members];
        member_edges: any = [
            e
            for e in edges
            if e.source_qualified in members and e.target_qualified in members
        ];

        if len(member_nodes) < min_split_size {
            result.append(comm);
            continue;
        }
        qn_to_idx: any = {n.qualified_name: i for (i, n) in enumerate(member_nodes)};
        idx_to_node: any = {i: `node for (i, `node) in enumerate(member_nodes)};
        weights_by_pair: dict[tuple[int, int], float] = {};
        for e in member_edges {
            si: any = qn_to_idx.get(e.source_qualified);
            ti: any = qn_to_idx.get(e.target_qualified);
            if si is not None and ti is not None and si != ti {
                pair: any = (min(si, ti), max(si, ti));
                weights_by_pair[pair] = max(
                    weights_by_pair.get(pair, 0.0), EDGE_WEIGHTS.get(e.kind, 0.5)
                );
            }
        }

        ig_edges: any = sorted(weights_by_pair);
        ig_weights: any = [weights_by_pair[pair] for pair in ig_edges];

        if not ig_edges {
            result.append(comm);
            continue;
        }

        try {
            g: any = ig.Graph(n=len(member_nodes), edges=ig_edges, directed=False);
            g.es["weight"] = ig_weights;
            seed: any = env_int("CRG_LEIDEN_SEED", _LEIDEN_SEED);
            ig.set_random_number_generator(random.Random(seed));
            partition: any = g.community_leiden(
                objective_function="modularity", weights="weight", resolution=0.5
            );

            partition_clusters: dict[int, list[int]] = {};
            for (idx, cid) in enumerate(partition.membership) {
                partition_clusters.setdefault(cid, []).append(idx);
            }

            reassigned_clusters: any = _reassign_test_nodes(
                `list(partition_clusters.values()),
                idx_to_node,
                qn_to_idx,
                edges,
                resolution_nodes=nodes,
            );
            sub_communities: any = [
                [idx_to_node[idx] for idx in cluster]
                for cluster in reassigned_clusters
                if cluster
            ];

            if len(sub_communities) <= 1 {
                result.append(comm);
                continue;
            }

            parent_id: any = comm.get("id", 0);
            comm_name: any = comm.get("name", "");
            sub_member_qns: any = [
                {`node.qualified_name for `node in sub_nodes}
                for sub_nodes in sub_communities
            ];
            cohesions: any = _compute_cohesion_batch(sub_member_qns, edges);

            for (sub_nodes, member_qns, cohesion) in zip(
                sub_communities, sub_member_qns, cohesions
            ) {
                generated_name: any = _generate_community_name(sub_nodes);
                if generated_name in {"", "empty", "cluster"} {
                    generated_name = f"{comm_name}-{next_id}";
                }
                sub_comm: any = {
                    "id": next_id,
                    "name": generated_name,
                    "level": comm.get("level", 0) + 1,
                    "parent_id": parent_id,
                    "members": [`node.qualified_name for `node in sub_nodes],
                    "size": len(member_qns),
                    "cohesion": cohesion,
                    "dominant_language": comm.get("dominant_language"),
                    "description": f"Split from {comm_name}",
                };
                result.append(sub_comm);
                next_id += 1;
            }

            logger.info(
                "Split oversized community '%s' (%d members) into %d",
                comm_name,
                len(members),
                len(sub_communities),
            );
        } except Exception {
            logger.warning(
                "Failed to split community '%s', keeping as-is", comm.get("name", ""), exc_info=True
            );
            result.append(comm);
        }
    }

    return result;
}

impl _dedupe_community_names(communities: list[dict[str, Any]], nodes: list[GraphNode]) {
    communities_by_name: dict[str, list[tuple[int, dict[str, Any]]]] = defaultdict(list[any]);
    community: any;
    for (position, community) in enumerate(communities) {
        communities_by_name[community.get("name", "")].append((position, community));
    }

    nodes_by_qn: any = {`node.qualified_name: `node for `node in nodes};
    taken_names: any = {
        community.get("name", "")
        for community in communities
        if community.get("name", "")
    };

    for (base_name, duplicates) in communities_by_name.items() {
        if not base_name or len(duplicates) <= 1 {
            continue;
        }

        ordered: any = sorted(
            duplicates,
            key=lambda (item) -> any {
                (
                    -item[1].get("size", len(item[1].get("members", []))),
                    item[1].get("id", item[0]),
                    item[0],
                )
            },
        );
        base_words: any = `set(base_name.split("-"));

        for (_, community) in ordered[1:] {
            member_nodes: any = [
                nodes_by_qn[qualified_name]
                for qualified_name in community.get("members", [])
                if qualified_name in nodes_by_qn
            ];
            candidate_name: any = "";
            for keyword in _extract_keywords(_naming_members(member_nodes)) {
                suffix: any = _to_slug(keyword);
                if not suffix or suffix in base_words {
                    continue;
                }
                candidate: any = f"{base_name}-{suffix}";
                if candidate not in taken_names {
                    candidate_name = candidate;
                    break;
                }
            }

            if not candidate_name {
                suffix_number: any = 2;
                candidate_name = f"{base_name}-{suffix_number}";
                while candidate_name in taken_names {
                    suffix_number += 1;
                    candidate_name = f"{base_name}-{suffix_number}";
                }
            }

            community["name"] = candidate_name;
            taken_names.add(candidate_name);
        }
    }
}

impl detect_communities(store: GraphStore, min_size: int = 2) -> list[dict[str, Any]] {
    all_edges: Sequence[GraphEdge | _CommunityEdge] = [
        _CommunityEdge(row[0], row[1], row[2])
        for row in store._conn.execute(
            "SELECT kind, source_qualified, target_qualified FROM edges"
        ).fetchall()
    ];
    unique_nodes: any = store.get_all_nodes(exclude_files=True);

    logger.debug("Loaded %d unique nodes, %d edges", len(unique_nodes), len(all_edges));

    if _load_igraph() {
        logger.info("Detecting communities with Leiden algorithm (igraph)");
        results: any = _detect_leiden(unique_nodes, all_edges, min_size);
        detector: any = DETECTOR_LEIDEN;
    } else {
        logger.info(
            "Tip: pip install \"code-review-graph[communities]\" for finer communities (grouping by file for now).",
        );
        results = _detect_file_based(unique_nodes, all_edges, min_size);
        detector = DETECTOR_FILE;
    }
    results = _split_oversized(results, unique_nodes, all_edges);
    _dedupe_community_names(results, unique_nodes);
    comm: any;
    for comm in results {
        comm.setdefault("detector", detector);
    }
    for comm in results {
        if "member_qns" in comm {
            comm["member_qns"] = `list(comm["member_qns"]);
            del comm["member_qns"];
        }
    }

    return results;
}

impl capture_community_assignments(store: GraphStore, file_paths: list[str]) -> dict[str, int] {
    if not file_paths {
        return {};
    }

    conn: any = store._conn;
    mapping: dict[str, int] = {};
    for i in range(0, len(file_paths), _SQL_BATCH) {
        batch: any = file_paths[i:i + _SQL_BATCH];
        placeholders: any = ",".join("?" * len(batch));
        rows: any = conn.execute(
            f"SELECT qualified_name, community_id FROM nodes WHERE community_id IS NOT NULL AND file_path IN ({placeholders})",
            batch,
        ).fetchall();
        for (qn, cid) in rows {
            if qn and cid is not None {
                mapping[qn] = `int(cid);
            }
        }
    }
    return mapping;
}

impl remap_community_assignments(store: GraphStore, community_by_qn: dict[str, int]) -> int {
    if not community_by_qn {
        return 0;
    }

    conn: any = store._conn;
    updated: any = 0;
    items: any = `list(community_by_qn.items());
    if conn.in_transaction {
        logger.warning("Rolling back uncommitted transaction before BEGIN IMMEDIATE");
        conn.rollback();
    }
    conn.execute("BEGIN IMMEDIATE");
    try {
        for (qn, cid) in items {
            cur: any = conn.execute(
                "UPDATE nodes SET community_id = ? WHERE qualified_name = ?", (cid, qn)
            );
            if cur.rowcount {
                updated += cur.rowcount;
            }
        }
        conn.commit();
    } except BaseException {
        conn.rollback();
        raise;
    }
    return updated;
}

impl purge_empty_communities(store: GraphStore) -> int {
    conn: any = store._conn;
    if conn.in_transaction {
        logger.warning("Rolling back uncommitted transaction before BEGIN IMMEDIATE");
        conn.rollback();
    }
    conn.execute("BEGIN IMMEDIATE");
    try {
        conn.execute(
            "UPDATE communities SET size = (SELECT COUNT(*) FROM nodes WHERE nodes.community_id = communities.id)",
        );
        cur: any = conn.execute(
            "DELETE FROM communities WHERE id NOT IN (SELECT DISTINCT community_id FROM nodes WHERE community_id IS NOT NULL)",
        );
        deleted: any = cur.rowcount if cur.rowcount is not None and cur.rowcount >= 0 else 0;
        conn.commit();
    } except BaseException {
        conn.rollback();
        raise;
    }
    return deleted;
}

impl incremental_detect_communities(
    store: GraphStore,
    changed_files: list[str],
    min_size: int = 2,
    repo_root: str | Path | None = None,
    force: bool = False,
) -> int {
    if not changed_files and not force {
        return 0;
    }

    expand_changed_file_paths = lazy("flows", "expand_changed_file_paths");

    expanded: any = expand_changed_file_paths(store, changed_files, repo_root=repo_root);
    conn: any = store._conn;
    affected_count: any = 0;
    unassigned_count: any = 0;
    for i in range(0, len(expanded), _SQL_BATCH) {
        batch: any = expanded[i:i + _SQL_BATCH];
        placeholders: any = ",".join("?" * len(batch));
        row: any = conn.execute(
            f"SELECT COUNT(DISTINCT community_id), SUM(CASE WHEN community_id IS NULL AND kind != 'File' THEN 1 ELSE 0 END) FROM nodes WHERE file_path IN ({placeholders})",
            batch,
        ).fetchone();
        if row {
            affected_count += row[0] or 0;
            unassigned_count += row[1] or 0;
        }
    }

    if not force and affected_count == 0 and unassigned_count == 0 {
        return 0;
    }
    communities: any = detect_communities(store, min_size=min_size);
    return store_communities(store, communities);
}

impl store_communities(store: GraphStore, communities: list[dict[str, Any]]) -> int {
    conn: any = store._conn;

    if conn.in_transaction {
        logger.warning("Rolling back uncommitted transaction before BEGIN IMMEDIATE");
        conn.rollback();
    }
    conn.execute("BEGIN IMMEDIATE");
    try {
        conn.execute("DELETE FROM communities");
        conn.execute("UPDATE nodes SET community_id = NULL");

        count: any = 0;
        for comm in communities {
            cursor: any = conn.execute(
                "INSERT INTO communities\n                   (name, level, cohesion, size, dominant_language, description)\n                   VALUES (?, ?, ?, ?, ?, ?)",
                (
                    comm["name"],
                    comm.get("level", 0),
                    comm.get("cohesion", 0.0),
                    comm["size"],
                    comm.get("dominant_language", ""),
                    comm.get("description", ""),
                ),
            );
            community_id: any = cursor.lastrowid;
            member_qns: any = comm.get("members", []);
            for j in range(0, len(member_qns), _SQL_BATCH) {
                batch: any = member_qns[j:j + _SQL_BATCH];
                placeholders: any = ",".join("?" * len(batch));
                conn.execute(
                    f"UPDATE nodes SET community_id = ? WHERE qualified_name IN ({placeholders})",
                    [community_id] + batch,
                );
            }
            count += 1;
        }
        tags: any = [comm.get("detector") for comm in communities];
        if tags and all(tags) {
            conn.execute(
                "INSERT OR REPLACE INTO metadata (key, value) VALUES (?, ?)",
                (DETECTOR_METADATA_KEY, "+".join(sorted({`str(t) for t in tags}))),
            );
        } else {
            conn.execute("DELETE FROM metadata WHERE key = ?", (DETECTOR_METADATA_KEY,));
        }

        conn.commit();
    } except BaseException {
        conn.rollback();
        raise;
    }
    return count;
}

impl get_communities(
    store: GraphStore,
    sort_by: str = "size",
    min_size: int = 0,
    members_by_community: dict[int, list[str]] | None = None,
) -> list[dict[str, Any]] {
    valid_sorts: any = {"size", "cohesion", "name"};
    if sort_by not in valid_sorts {
        sort_by = "size";
    }

    order: any = "DESC" if sort_by in ("size", "cohesion") else "ASC";
    rows: any = store._conn.execute(
        f"SELECT * FROM communities WHERE size >= ? ORDER BY {sort_by} {order}", (min_size,)
    ).fetchall();

    communities: list[dict[str, Any]] = [];
    for row in rows {
        member_qns: any = [_sanitize_name(qn) for qn in store.get_community_member_qns(row["id"])]
            if members_by_community is None
            else members_by_community.get(row["id"], []);

        communities.append({
            "id": row["id"],
            "name": _sanitize_name(row["name"]),
            "level": row["level"],
            "cohesion": row["cohesion"],
            "size": row["size"],
            "dominant_language": row["dominant_language"] or "",
            "description": _sanitize_name(row["description"] or ""),
            "members": member_qns,
        });
    }

    return communities;
}

impl _is_test_community(name: str) -> bool {
    return `bool(_TEST_COMMUNITY_RE.search(name));
}

impl get_architecture_overview(store: GraphStore) -> dict[str, Any] {
    communities: any = get_communities(store);
    node_to_community: dict[str, int] = {};
    for comm in communities {
        comm_id: any = comm.get("id", 0);
        for qn in comm.get("members", []) {
            node_to_community[qn] = comm_id;
        }
    }
    all_edges: any = store.get_all_edges();
    cross_edges: list[dict[str, Any]] = [];
    cross_counts: Counter[tuple[int, int]] = Counter();

    for e in all_edges {
        if e.kind == "TESTED_BY" {
            continue;
        }
        src_comm: any = node_to_community.get(e.source_qualified);
        tgt_comm: any = node_to_community.get(e.target_qualified);
        if src_comm is not None and tgt_comm is not None and src_comm != tgt_comm {
            pair: any = (min(src_comm, tgt_comm), max(src_comm, tgt_comm));
            cross_counts[pair] += 1;
            cross_edges.append({
                "source_community": src_comm,
                "target_community": tgt_comm,
                "edge_kind": e.kind,
                "source": _sanitize_name(e.source_qualified),
                "target": _sanitize_name(e.target_qualified),
            });
        }
    }
    warnings: list[str] = [];
    comm_name_map: any = {c.get("id", 0): c["name"] for c in communities};
    for ((c1, c2), count) in cross_counts.most_common() {
        if count > 10 {
            name1: any = comm_name_map.get(c1, f"community-{c1}");
            name2: any = comm_name_map.get(c2, f"community-{c2}");
            if _is_test_community(name1) or _is_test_community(name2) {
                continue;
            }
            warnings.append(f"High coupling ({count} edges) between '{name1}' and '{name2}'");
        }
    }

    return {"communities": communities, "cross_community_edges": cross_edges, "warnings": warnings};
}
