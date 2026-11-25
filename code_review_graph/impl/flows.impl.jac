impl _escape_like_literal(value: str) -> str {
    return value.replace("\\", "\\\\").replace("%", "\\%").replace("_", "\\_");
}

impl expand_changed_file_paths(
    store: GraphStore, changed_files: Iterable[str], repo_root: str | Path | None = None
) -> list[str] {
    variants: list[str];
    seen: set[str];
    `root: any = Path(repo_root).resolve() if repo_root is not None else None;
    variants = [];
    seen = set[any]();
    relative_inputs: list[str] = [];

    def _add(path: str) {
        normalized: any = normalize_file_path(path);
        if normalized and normalized not in seen {
            seen.add(normalized);
            variants.append(normalized);
        }
    }

    for raw in changed_files {
        text: any = normalize_file_path(raw);
        _add(text);
        path: any = Path(raw);
        if path.is_absolute() {
            _add(`str(path));
            try {
                resolved: any = path.resolve();
                _add(`str(resolved));
                if `root is not None {
                    _add(`str(resolved.relative_to(`root)));
                }
            } except (OSError, ValueError) {}
        } else {
            relative_inputs.append(text);
            if `root is not None {
                _add(`str(`root / path));
                try {
                    _add(`str((`root / path).resolve()));
                } except OSError {}
            }
        }
    }
    matched: list[str] = `list(variants);
    matched_seen: any = `set(variants);
    if variants {
        for i in range(0, len(variants), _SQL_BATCH) {
            path_batch: any = variants[i:i + _SQL_BATCH];
            placeholders: any = ",".join("?" * len(path_batch));
            rows: any = store._conn.execute(
                f"SELECT DISTINCT file_path FROM nodes WHERE file_path IN ({placeholders})",
                path_batch,
            ).fetchall();
            row: any;
            for row in rows {
                fp: any = row[0];
                if fp not in matched_seen {
                    matched.append(fp);
                    matched_seen.add(fp);
                }
            }
        }
    }
    if `root is None {
        for rel in relative_inputs {
            escaped: any = _escape_like_literal(rel);
            patterns: any = (escaped, f"%/{escaped}", f"%\\\\{escaped}");
            for pattern in patterns {
                rows = store._conn.execute(
                    "SELECT DISTINCT file_path FROM nodes WHERE file_path LIKE ? ESCAPE '\\'",
                    (pattern,),
                ).fetchall();
                for row in rows {
                    fp = row[0];
                    if fp not in matched_seen {
                        matched.append(fp);
                        matched_seen.add(fp);
                    }
                }
            }
        }
    }
    return matched;
}

impl _flows_touching_files(
    store: GraphStore, file_paths: list[str]
) -> tuple[list[int], list[int], set[str]] {
    if not file_paths {
        return ([], [], set[any]());
    }

    node_ids: any = `list(store.get_node_ids_by_files(file_paths));
    if not node_ids {
        return ([], [], set[any]());
    }

    flow_ids: any = store.get_flow_ids_by_node_ids(`set(node_ids));
    if not flow_ids {
        return (node_ids, [], set[any]());
    }

    return (node_ids, flow_ids, _flow_node_qns(store, flow_ids));
}

impl _flow_node_qns(store: GraphStore, flow_ids: list[int]) -> set[str] {
    qns: set[str] = set[any]();
    for i in range(0, len(flow_ids), _SQL_BATCH) {
        batch: any = flow_ids[i:i + _SQL_BATCH];
        placeholders: any = ",".join("?" * len(batch));
        rows: any = store._conn.execute(
            f"SELECT n.qualified_name FROM flows f JOIN nodes n ON n.id = f.entry_point_id WHERE f.id IN ({placeholders}) UNION SELECT n.qualified_name FROM flow_memberships fm JOIN nodes n ON n.id = fm.node_id WHERE fm.flow_id IN ({placeholders})",
            [*batch, *batch],
        ).fetchall();
        qns.update(r[0] for r in rows if r[0]);
    }
    return qns;
}

impl capture_affected_flow_entry_points(store: GraphStore, file_paths: list[str]) -> set[str] {
    _node_ids: any;
    _flow_ids: any;
    entry_qns: any;
    (_node_ids, _flow_ids, entry_qns) = _flows_touching_files(store, file_paths) as any;
    return entry_qns;
}

impl capture_flow_node_ids(store: GraphStore, file_paths: list[str]) -> dict[int, str] {
    captured: dict[int, str] = {};
    for i in range(0, len(file_paths), _SQL_BATCH) {
        batch: any = file_paths[i:i + _SQL_BATCH];
        placeholders: any = ",".join("?" * len(batch));
        rows: any = store._conn.execute(
            f"SELECT id, qualified_name FROM nodes WHERE file_path IN ({placeholders}) AND (id IN (SELECT node_id FROM flow_memberships) OR id IN (SELECT entry_point_id FROM flows))",
            batch,
        ).fetchall();
        captured.update({row[0]: row[1] for row in rows});
    }
    return captured;
}

impl remap_flow_node_ids(store: GraphStore, old_ids: dict[int, str]) -> int {
    new_ids: dict[int, int];
    conn: any = store._conn;
    new_ids = {};
    old_id: any;
    for (old_id, qualified_name) in old_ids.items() {
        row: any = conn.execute(
            "SELECT id FROM nodes WHERE qualified_name = ?", (qualified_name,)
        ).fetchone();
        if row is not None and row[0] != old_id {
            new_ids[old_id] = row[0];
        }
    }
    if not new_ids {
        return 0;
    }

    if conn.in_transaction {
        logger.warning("Rolling back uncommitted transaction before BEGIN IMMEDIATE");
        conn.rollback();
    }
    conn.execute("BEGIN IMMEDIATE");
    try {
        for (old_id, new_id) in new_ids.items() {
            conn.execute(
                "UPDATE flow_memberships SET node_id = ? WHERE node_id = ?", (new_id, old_id)
            );
            conn.execute(
                "UPDATE flows SET entry_point_id = ? WHERE entry_point_id = ?", (new_id, old_id)
            );
        }
        for (flow_id, path_json) in conn.execute("SELECT id, path_json FROM flows").fetchall() {
            path: any = json.loads(path_json);
            if `any(node_id in new_ids for node_id in path) {
                conn.execute(
                    "UPDATE flows SET path_json = ? WHERE id = ?",
                    (json.dumps([new_ids.get(n, n) for n in path]), flow_id),
                );
            }
        }
        conn.commit();
    } except BaseException {
        conn.rollback();
        raise;
    }
    return len(new_ids);
}

impl clear_flows_for_files(store: GraphStore, file_paths: list[str]) -> set[str] {
    if not file_paths {
        return set[any]();
    }

    node_ids: any;
    flow_ids: any;
    entry_qns: any;
    (node_ids, flow_ids, entry_qns) = _flows_touching_files(store, file_paths) as any;
    if not node_ids and not flow_ids {
        return entry_qns;
    }

    conn: any = store._conn;
    if conn.in_transaction {
        logger.warning("Rolling back uncommitted transaction before BEGIN IMMEDIATE");
        conn.rollback();
    }
    conn.execute("BEGIN IMMEDIATE");
    try {
        i: any;
        for i in range(0, len(flow_ids), _SQL_BATCH) {
            flow_batch: any = flow_ids[i:i + _SQL_BATCH];
            placeholders: any = ",".join("?" * len(flow_batch));
            conn.execute(
                f"DELETE FROM flow_memberships WHERE flow_id IN ({placeholders})", flow_batch
            );
            conn.execute(f"DELETE FROM flows WHERE id IN ({placeholders})", flow_batch);
        }
        for i in range(0, len(node_ids), _SQL_BATCH) {
            node_batch: any = node_ids[i:i + _SQL_BATCH];
            placeholders = ",".join("?" * len(node_batch));
            conn.execute(
                f"DELETE FROM flow_memberships WHERE node_id IN ({placeholders})", node_batch
            );
            conn.execute(f"DELETE FROM flows WHERE entry_point_id IN ({placeholders})", node_batch);
        }
        conn.commit();
    } except BaseException {
        conn.rollback();
        raise;
    }
    return entry_qns;
}

impl purge_orphan_flow_data(store: GraphStore) -> int {
    conn: any = store._conn;
    if conn.in_transaction {
        logger.warning("Rolling back uncommitted transaction before BEGIN IMMEDIATE");
        conn.rollback();
    }
    conn.execute("BEGIN IMMEDIATE");
    try {
        cur: any = conn.execute(
            "DELETE FROM flow_memberships WHERE node_id NOT IN (SELECT id FROM nodes)"
        );
        deleted: any = cur.rowcount if cur.rowcount is not None and cur.rowcount >= 0 else 0;
        conn.execute("DELETE FROM flows WHERE entry_point_id NOT IN (SELECT id FROM nodes)");
        conn.execute(
            "DELETE FROM flows WHERE id NOT IN (SELECT DISTINCT flow_id FROM flow_memberships)"
        );
        cur = conn.execute(
            "DELETE FROM flow_memberships WHERE flow_id NOT IN (SELECT id FROM flows)"
        );
        deleted += cur.rowcount if cur.rowcount is not None and cur.rowcount >= 0 else 0;
        conn.commit();
    } except BaseException {
        conn.rollback();
        raise;
    }
    return deleted;
}

impl _has_framework_decorator(`node: GraphNode) -> bool {
    decorators: any = `node.extra.get("decorators");
    if not decorators {
        return False;
    }
    if isinstance(decorators, `str) {
        decorators = [decorators];
    }
    for dec in decorators {
        for pat in _FRAMEWORK_DECORATOR_PATTERNS {
            if pat.search(dec) {
                return True;
            }
        }
    }
    return False;
}

impl _has_override_decorator(`node: GraphNode) -> bool {
    decorators: any = `node.extra.get("decorators");
    if not decorators {
        return False;
    }
    if isinstance(decorators, `str) {
        decorators = [decorators];
    }
    return `any(_OVERRIDE_DECORATOR.search(dec) for dec in decorators);
}

impl _matches_entry_name(`node: GraphNode) -> bool {
    pat: any;
    for pat in _ENTRY_NAME_PATTERNS {
        if pat.search(`node.name) {
            return True;
        }
    }
    for pat in _LANGUAGE_ENTRY_NAME_PATTERNS.get(`node.language, ()) {
        if pat.search(`node.name) {
            return True;
        }
    }
    return False;
}

impl detect_entry_points(store: GraphStore, include_tests: bool = False) -> list[GraphNode] {
    `node: any;
    called_qnames: any = store.get_all_call_targets(include_file_sources=False);
    candidate_nodes: any = store.get_nodes_by_kind(["Function", "Test"]);
    called_outside_tests: any = store.get_call_targets_outside_tests()
        if `any(`node.language in ("ruby", "java") for `node in candidate_nodes)
        else set[any]();

    entry_points: list[GraphNode] = [];
    seen_qn: set[str] = set[any]();
    repo_root: any = store.get_repo_root();

    for `node in candidate_nodes {
        if not include_tests and (`node.is_test or _is_test_file(`node.file_path, repo_root)) {
            continue;
        }
        if `node.extra.get("verilog_kind") {
            continue;
        }
        called: any = called_outside_tests if `node.language in ("ruby", "java") else called_qnames;
        is_entry: any = `node.qualified_name not in called
            or _has_framework_decorator(`node)
            or _matches_entry_name(`node);

        if is_entry and `node.qualified_name not in seen_qn {
            entry_points.append(`node);
            seen_qn.add(`node.qualified_name);
        }
    }

    return entry_points;
}

impl _trace_single_flow(adj: FlowAdjacency, ep: GraphNode, max_depth: int = 15) -> Optional[dict] {
    n: any;
    path_ids: list[int] = [ep.id];
    path_qnames: list[str] = [ep.qualified_name];
    visited: set[str] = {ep.qualified_name};
    queue: deque[tuple[str, int]] = deque([(ep.qualified_name, 0)]);

    actual_depth: any = 0;
    nodes_by_qn: any = adj.nodes_by_qn;
    calls_out: any = adj.calls_out;

    while queue {
        current_qn: any;
        depth: any;
        (current_qn, depth) = queue.popleft() as any;
        if depth > actual_depth {
            actual_depth = depth;
        }
        if depth >= max_depth {
            continue;
        }

        for target_qn in calls_out.get(current_qn, ()) {
            if target_qn in visited {
                continue;
            }
            target_node: any = nodes_by_qn.get(target_qn);
            if target_node is None {
                continue;
            }
            visited.add(target_qn);
            path_ids.append(target_node.id);
            path_qnames.append(target_qn);
            queue.append((target_qn, depth + 1));
        }
    }
    if len(path_ids) < 2 {
        return None;
    }

    files: any = `list({
        n.file_path
        for qn in path_qnames
        if (n := nodes_by_qn.get(qn)) is not None
    });

    `flow: dict = {
        "name": _sanitize_name(ep.name),
        "entry_point": ep.qualified_name,
        "entry_point_id": ep.id,
        "path": path_ids,
        "depth": actual_depth,
        "node_count": len(path_ids),
        "file_count": len(files),
        "files": files,
        "criticality": 0.0,
    };
    `flow["criticality"] = compute_criticality(`flow, adj);
    return `flow;
}

impl trace_flows(
    store: GraphStore, max_depth: int = 15, include_tests: bool = False
) -> list[dict] {
    entry_points: any = detect_entry_points(store, include_tests=include_tests);
    if not entry_points {
        return [];
    }

    adj: any = store.load_flow_adjacency();
    flows: list[dict] = [];

    for ep in entry_points {
        `flow: any = _trace_single_flow(adj, ep, max_depth);
        if `flow is not None {
            flows.append(`flow);
        }
    }
    flows.sort(key=lambda (f) -> any { f["criticality"] }, reverse=True);
    return flows;
}

impl compute_criticality(`flow: dict, adj: FlowAdjacency) -> float {
    n: any;
    node_ids: list[int] = `flow.get("path", []);
    if not node_ids {
        return 0.0;
    }

    nodes_by_id: any = adj.nodes_by_id;
    nodes_by_qn: any = adj.nodes_by_qn;
    calls_out: any = adj.calls_out;
    has_tested_by: any = adj.has_tested_by;

    nodes: list[GraphNode] = [n for nid in node_ids if (n := nodes_by_id.get(nid)) is not None];
    if not nodes {
        return 0.0;
    }
    file_count: any = len({n.file_path for n in nodes});
    file_spread: any = min((file_count - 1) / 4.0, 1.0) if file_count > 1 else 0.0;
    external_count: any = 0;
    for n in nodes {
        for target_qn in calls_out.get(n.qualified_name, ()) {
            if target_qn not in nodes_by_qn {
                external_count += 1;
            }
        }
    }
    external_score: any = min(external_count / 5.0, 1.0);
    security_hits: any = 0;
    for n in nodes {
        name_lower: any = n.name.lower();
        qn_lower: any = n.qualified_name.lower();
        for kw in _SECURITY_KEYWORDS {
            if kw in name_lower or kw in qn_lower {
                security_hits += 1;
                break;
            }
        }
    }
    security_score: any = min(security_hits / max(len(nodes), 1), 1.0);
    tested_count: any = sum(1 for n in nodes if n.qualified_name in has_tested_by);
    coverage: any = tested_count / max(len(nodes), 1);
    test_gap: any = 1.0 - coverage;
    depth: any = `flow.get("depth", 0);
    depth_score: any = min(depth / 10.0, 1.0);
    criticality: any = file_spread * 0.3
        + external_score * 0.2
        + security_score * 0.25
        + test_gap * 0.15
        + depth_score * 0.1;
    return round(min(max(criticality, 0.0), 1.0), 4);
}

impl store_flows(store: GraphStore, flows: list[dict]) -> int {
    conn: any = store._conn;

    if conn.in_transaction {
        logger.warning("Rolling back uncommitted transaction before BEGIN IMMEDIATE");
        conn.rollback();
    }
    conn.execute("BEGIN IMMEDIATE");
    try {
        conn.execute("DELETE FROM flow_memberships");
        conn.execute("DELETE FROM flows");

        count: any = 0;
        membership_rows: list[tuple[int, int, int]] = [];
        for `flow in flows {
            node_ids: any = `flow.get("path", []);
            path_json: any = json.dumps(node_ids);
            cursor: any = conn.execute(
                "INSERT INTO flows\n                   (name, entry_point_id, depth, node_count, file_count,\n                    criticality, path_json)\n                   VALUES (?, ?, ?, ?, ?, ?, ?)",
                (
                    `flow["name"],
                    `flow["entry_point_id"],
                    `flow["depth"],
                    `flow["node_count"],
                    `flow["file_count"],
                    `flow["criticality"],
                    path_json,
                ),
            );
            flow_id: any = cursor.lastrowid;
            membership_rows.extend(
                (flow_id, node_id, position) for (position, node_id) in enumerate(node_ids)
            );
            count += 1;
        }
        if membership_rows {
            conn.executemany(
                "INSERT OR IGNORE INTO flow_memberships (flow_id, node_id, position) VALUES (?, ?, ?)",
                membership_rows,
            );
        }

        conn.execute("DELETE FROM metadata WHERE key = 'csharp_flows_dirty'");
        conn.commit();
    } except BaseException {
        conn.rollback();
        raise;
    }
    return count;
}

impl incremental_trace_flows(
    store: GraphStore,
    changed_files: list[str],
    max_depth: int = 15,
    repo_root: str | Path | None = None,
    entry_point_qns: Iterable[str] | None = None,
) -> int {
    ep: any;
    flow_id: any;
    if store.get_metadata("csharp_flows_dirty") == "1" {
        return store_flows(store, trace_flows(store, max_depth=max_depth));
    }
    if not changed_files and not entry_point_qns {
        return 0;
    }
    changed_files = [normalize_file_path(p) for p in changed_files];
    conn: any = store._conn;
    expanded: any = expand_changed_file_paths(store, changed_files, repo_root=repo_root);
    changed_file_set: any = `set(expanded);
    preserved_entry_qns: any = {qn for qn in entry_point_qns or [] if qn};
    purge_orphan_flow_data(store);
    affected_ids: list[int] = [];
    if expanded {
        i: any;
        for i in range(0, len(expanded), _SQL_BATCH) {
            path_batch: any = expanded[i:i + _SQL_BATCH];
            placeholders: any = ",".join("?" * len(path_batch));
            affected_rows: any = conn.execute(
                f"SELECT DISTINCT fm.flow_id FROM flow_memberships fm JOIN nodes n ON n.id = fm.node_id WHERE n.file_path IN ({placeholders})",
                path_batch,
            ).fetchall();
            affected_ids.extend(r[0] for r in affected_rows);
        }
    }
    preserved_entry_qns |= _flow_node_qns(store, `list(dict.fromkeys(affected_ids)));
    preserved: any = sorted(preserved_entry_qns);
    for i in range(0, len(preserved), _SQL_BATCH) {
        qn_batch: any = preserved[i:i + _SQL_BATCH];
        placeholders = ",".join("?" * len(qn_batch));
        affected_rows = conn.execute(
            f"SELECT f.id FROM flows f JOIN nodes n ON n.id = f.entry_point_id WHERE n.qualified_name IN ({placeholders})",
            qn_batch,
        ).fetchall();
        affected_ids.extend(r[0] for r in affected_rows);
    }
    affected_ids = `list(dict.fromkeys(affected_ids));
    entry_point_ids: set[int] = set[any]();
    if affected_ids {
        for i in range(0, len(affected_ids), _SQL_BATCH) {
            id_batch: any = affected_ids[i:i + _SQL_BATCH];
            ep_placeholders: any = ",".join("?" * len(id_batch));
            ep_rows: any = conn.execute(
                f"SELECT f.entry_point_id, n.qualified_name FROM flows f LEFT JOIN nodes n ON n.id = f.entry_point_id WHERE f.id IN ({ep_placeholders})",
                id_batch,
            ).fetchall();
            for row in ep_rows {
                if row[0] is not None {
                    entry_point_ids.add(row[0]);
                }
                if row[1] {
                    preserved_entry_qns.add(row[1]);
                }
            }
        }
    }
    if affected_ids {
        if conn.in_transaction {
            logger.warning("Rolling back uncommitted transaction before BEGIN IMMEDIATE");
            conn.rollback();
        }
        conn.execute("BEGIN IMMEDIATE");
        try {
            for fid in affected_ids {
                conn.execute("DELETE FROM flow_memberships WHERE flow_id = ?", (fid,));
                conn.execute("DELETE FROM flows WHERE id = ?", (fid,));
            }
            conn.commit();
        } except BaseException {
            conn.rollback();
            raise;
        }
    }
    entry_points: any = detect_entry_points(store);
    relevant_eps: any = [
        ep
        for ep in entry_points
        if ep.file_path in changed_file_set
            or ep.id in entry_point_ids
            or ep.qualified_name in preserved_entry_qns
    ];
    new_flows: list[dict] = [];
    if relevant_eps {
        adj: any = store.load_flow_adjacency();
        for ep in relevant_eps {
            `flow: any = _trace_single_flow(adj, ep, max_depth);
            if `flow is not None {
                new_flows.append(`flow);
            }
        }
    }
    count: any = 0;
    if new_flows {
        store._begin_immediate();
        try {
            membership_rows: list[tuple[int, int, int]] = [];
            for `flow in new_flows {
                node_ids: any = `flow.get("path", []);
                path_json: any = json.dumps(node_ids);
                cursor: any = conn.execute(
                    "INSERT INTO flows\n                       (name, entry_point_id, depth, node_count, file_count,\n                        criticality, path_json)\n                       VALUES (?, ?, ?, ?, ?, ?, ?)",
                    (
                        `flow["name"],
                        `flow["entry_point_id"],
                        `flow["depth"],
                        `flow["node_count"],
                        `flow["file_count"],
                        `flow["criticality"],
                        path_json,
                    ),
                );
                flow_id = cursor.lastrowid;
                membership_rows.extend(
                    (flow_id, node_id, position) for (position, node_id) in enumerate(node_ids)
                );
                count += 1;
            }
            if membership_rows {
                conn.executemany(
                    "INSERT OR IGNORE INTO flow_memberships (flow_id, node_id, position) VALUES (?, ?, ?)",
                    membership_rows,
                );
            }
            conn.commit();
        } except BaseException {
            conn.rollback();
            raise;
        }
    }
    return count;
}

impl get_flows(store: GraphStore, sort_by: str = "criticality", limit: int = 50) -> list[dict] {
    allowed_sort: any = {"criticality", "depth", "node_count", "file_count", "name"};
    if sort_by not in allowed_sort {
        sort_by = "criticality";
    }

    order: any = "DESC"
        if sort_by in ("criticality", "depth", "node_count", "file_count")
        else "ASC";
    rows: any = store._conn.execute(
        f"SELECT * FROM flows ORDER BY {sort_by} {order} LIMIT ?", (limit,)
    ).fetchall();

    results: list[dict] = [];
    for row in rows {
        results.append({
            "id": row["id"],
            "name": _sanitize_name(row["name"]),
            "entry_point_id": row["entry_point_id"],
            "depth": row["depth"],
            "node_count": row["node_count"],
            "file_count": row["file_count"],
            "criticality": row["criticality"],
            "path": json.loads(row["path_json"]),
            "created_at": row["created_at"],
            "updated_at": row["updated_at"],
        });
    }
    return results;
}

impl get_flow_by_id(store: GraphStore, flow_id: int) -> Optional[dict] {
    row: any = store._conn.execute("SELECT * FROM flows WHERE id = ?", (flow_id,)).fetchone();
    if row is None {
        return None;
    }

    path_ids: list[int] = json.loads(row["path_json"]);
    steps: list[dict] = [];
    for nid in path_ids {
        `node: any = store.get_node_by_id(nid);
        if `node {
            steps.append({
                "node_id": `node.id,
                "name": _sanitize_name(`node.name),
                "kind": `node.kind,
                "file": `node.file_path,
                "line_start": `node.line_start,
                "line_end": `node.line_end,
                "qualified_name": _sanitize_name(`node.qualified_name),
            });
        }
    }

    return {
        "id": row["id"],
        "name": _sanitize_name(row["name"]),
        "entry_point_id": row["entry_point_id"],
        "depth": row["depth"],
        "node_count": row["node_count"],
        "file_count": row["file_count"],
        "criticality": row["criticality"],
        "path": path_ids,
        "steps": steps,
        "created_at": row["created_at"],
        "updated_at": row["updated_at"],
    };
}

impl get_affected_flows(store: GraphStore, changed_files: list[str]) -> dict {
    if not changed_files {
        return {"affected_flows": [], "total": 0};
    }
    node_ids: any = store.get_node_ids_by_files(changed_files);

    if not node_ids {
        return {"affected_flows": [], "total": 0};
    }
    flow_ids: any = store.get_flow_ids_by_node_ids(node_ids);

    if not flow_ids {
        return {"affected_flows": [], "total": 0};
    }

    affected: list[dict] = [];
    for fid in flow_ids {
        `flow: any = get_flow_by_id(store, fid);
        if `flow {
            affected.append(`flow);
        }
    }
    affected.sort(key=lambda (f) -> any { f.get("criticality", 0) }, reverse=True);

    return {"affected_flows": affected, "total": len(affected)};
}
