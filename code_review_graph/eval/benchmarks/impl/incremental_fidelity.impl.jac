impl _clean_build(tree: Path, db_path: Path) -> dict[str, Any] {
    GraphStore = lazy("graph", "GraphStore");
    full_build = lazy("incremental", "full_build");
    _run_postprocess = lazy("tools.build", "_run_postprocess");

    store: any = GraphStore(db_path);
    try {
        result: any = `dict(full_build(tree, store));
        _run_postprocess(store, result, "full", full_rebuild=True);
        return result;
    } finally {
        store.close();
    }
}

impl _incremental_build(tree: Path, db_path: Path, base: str) -> dict[str, Any] {
    GraphStore = lazy("graph", "GraphStore");
    incremental_update = lazy("incremental", "incremental_update");
    _run_postprocess = lazy("tools.build", "_run_postprocess");

    store: any = GraphStore(db_path);
    try {
        result: any = `dict(incremental_update(tree, store, base=base));
        if result["files_updated"] == 0 and not result["errors"] {
            return result;
        }
        _run_postprocess(
            store,
            result,
            "full",
            full_rebuild=False,
            changed_files=[
                *(result.get("changed_files") or []),
                *(result.get("dependent_files") or []),
            ],
            repo_root=`str(tree),
            entry_point_qns=result.get("flow_entry_point_qns"),
            communities_were_affected=`bool(result.get("communities_were_affected")),
        );
        return result;
    } finally {
        store.close();
    }
}

impl _copy_db(source: Path, target: Path) {
    shutil.copy2(source, target);
    for suffix in ("-wal", "-shm") {
        sidecar: any = Path(`str(source) + suffix);
        if sidecar.exists() {
            shutil.copy2(sidecar, Path(`str(target) + suffix));
        }
    }
}

impl _blank(value: object) -> str {
    return "" if value is None else `str(value);
}

impl _join(row: sqlite3.Row, columns: tuple[str, ...]) -> str {
    return "|".join(_blank(row[c]) for c in columns);
}

impl _add(target: _Projection, key: str, value: str) {
    target.setdefault(key, Counter())[value] += 1;
}

impl _table_exists(conn: sqlite3.Connection, name: str) -> bool {
    row: any = conn.execute(
        "SELECT count(*) FROM sqlite_master WHERE type IN ('table','view') AND name = ?", (name,)
    ).fetchone();
    return `bool(row and row[0]);
}

impl _project_nodes(conn: sqlite3.Connection) -> _Projection {
    out: _Projection = {};
    for row in conn.execute("SELECT qualified_name, " + ", ".join(_NODE_COLUMNS) + " FROM nodes") {
        _add(out, row["qualified_name"], _join(row, _NODE_COLUMNS));
    }
    return out;
}

impl _project_node_community(conn: sqlite3.Connection) -> _Projection {
    out: _Projection = {};
    for row in conn.execute(
        "SELECT n.qualified_name AS qn, c.name AS cname FROM nodes n LEFT JOIN communities c ON c.id = n.community_id",
    ) {
        _add(out, row["qn"], _blank(row["cname"]));
    }
    return out;
}

impl _project_edges(conn: sqlite3.Connection) -> _Projection {
    out: _Projection = {};
    columns: any = ", ".join(_EDGE_KEY_COLUMNS + _EDGE_VALUE_COLUMNS);
    for row in conn.execute(f"SELECT {columns} FROM edges") {
        _add(out, _join(row, _EDGE_KEY_COLUMNS), _join(row, _EDGE_VALUE_COLUMNS));
    }
    return out;
}

impl _project_communities(conn: sqlite3.Connection) -> _Projection {
    out: _Projection = {};
    if not _table_exists(conn, "communities") {
        return out;
    }
    for row in conn.execute(
        "SELECT c.name AS name, c.level AS level, c.cohesion AS cohesion, c.size AS size, c.dominant_language AS dominant_language, c.description AS description, p.name AS parent_name FROM communities c LEFT JOIN communities p ON p.id = c.parent_id",
    ) {
        _add(out, row["name"], _join(row, _COMMUNITY_VALUE_COLUMNS));
    }
    return out;
}

impl _node_names(conn: sqlite3.Connection) -> dict[int, str] {
    return {
        `int(row[0]): `str(row[1])
        for row in conn.execute("SELECT id, qualified_name FROM nodes")
    };
}

impl _flow_keys(conn: sqlite3.Connection) -> dict[int, str] {
    if not _table_exists(conn, "flows") {
        return {};
    }
    names: any = _node_names(conn);
    keys: dict[int, str] = {};
    for row in conn.execute("SELECT id, entry_point_id, path_json FROM flows") {
        try {
            path: any = json.loads(row["path_json"] or "[]");
        } except (TypeError, ValueError) {
            path = [];
        }
        `entry: any = names.get(`int(row["entry_point_id"]), "<unresolved>");
        walk: any = ">".join(names.get(`int(n), "<unresolved>") for n in path);
        keys[`int(row["id"])] = f"{`entry}::{walk}";
    }
    return keys;
}

impl _project_flows(conn: sqlite3.Connection) -> _Projection {
    out: _Projection = {};
    if not _table_exists(conn, "flows") {
        return out;
    }
    keys: any = _flow_keys(conn);
    for row in conn.execute(
        "SELECT id, name, depth, node_count, file_count, criticality FROM flows"
    ) {
        _add(out, keys[`int(row["id"])], _join(row, _FLOW_VALUE_COLUMNS));
    }
    return out;
}

impl _project_flow_memberships(conn: sqlite3.Connection) -> _Projection {
    out: _Projection = {};
    if not _table_exists(conn, "flow_memberships") {
        return out;
    }
    keys: any = _flow_keys(conn);
    for row in conn.execute(
        "SELECT fm.flow_id AS flow_id, fm.position AS position, n.qualified_name AS qn FROM flow_memberships fm LEFT JOIN nodes n ON n.id = fm.node_id",
    ) {
        flow_key: any = keys.get(`int(row["flow_id"]), "<orphan flow>");
        _add(out, f"{flow_key}|{_blank(row["qn"])}", _blank(row["position"]));
    }
    return out;
}

impl _project_nodes_fts(conn: sqlite3.Connection) -> Optional[_Projection] {
    if not _table_exists(conn, "nodes_fts") {
        return None;
    }
    vocab: any = "crg_fidelity_vocab";
    try {
        conn.execute(f"DROP TABLE IF EXISTS temp.{vocab}");
        conn.execute(f"CREATE VIRTUAL TABLE temp.{vocab} USING fts5vocab(main, nodes_fts, 'row')");
        out: _Projection = {};
        for row in conn.execute(f"SELECT term, doc, cnt FROM temp.{vocab}") {
            _add(out, _blank(row[0]), f"{_blank(row[1])}|{_blank(row[2])}");
        }
        return out;
    } except sqlite3.OperationalError as exc {
        logger.warning("fts5vocab unavailable, skipping nodes_fts: %s", exc);
        return None;
    } finally {
        try {
            conn.execute(f"DROP TABLE IF EXISTS temp.{vocab}");
        } except sqlite3.OperationalError {}
    }
}

impl _project_metadata(conn: sqlite3.Connection) -> _Projection {
    out: _Projection = {};
    for row in conn.execute("SELECT key, value FROM metadata") {
        if row["key"] in _VOLATILE_METADATA_KEYS {
            continue;
        }
        _add(out, row["key"], _blank(row["value"]));
    }
    return out;
}

impl _diff_projection(
    left: _Projection, right: _Projection, path_prefix: str = ""
) -> tuple[int, list[str]] {
    differing: any = 0;
    examples: list[str] = [];
    for key in sorted(`set(left) | `set(right)) {
        `here: any = left.get(key, Counter());
        there: any = right.get(key, Counter());
        if `here == there {
            continue;
        }
        delta: any = max(sum((`here - there).values()), sum((there - `here).values()));
        differing += delta;
        if len(examples) < _MAX_EXAMPLES {
            examples.append(
                f"{_clean(key, path_prefix)} :: incremental={_clean(_describe(`here), path_prefix)} rebuild={_clean(_describe(there), path_prefix)}",
            );
        }
    }
    return (differing, examples);
}

impl _clean(text: str, path_prefix: str) -> str {
    _sanitize_name = lazy("graph", "_sanitize_name");

    if path_prefix {
        text = text.replace(path_prefix, "");
    }
    return _sanitize_name(text);
}

impl _describe(values: "Counter[str]") -> str {
    if not values {
        return "<absent>";
    }
    return "; ".join(
        f"{value}" if count == 1 else f"{value} (x{count})"
        for (value, count) in sorted(values.items()),
    )[:300];
}

impl _open(db_path: Path) -> sqlite3.Connection {
    conn: any = sqlite3.connect(`str(db_path));
    conn.row_factory = sqlite3.Row;
    return conn;
}

impl compare_graphs(
    incremental_db: Path, rebuild_db: Path, path_prefix: str = ""
) -> dict[str, Any] {
    tables: dict[str, dict[str, Any]];
    tables = {};
    left_conn: any = _open(incremental_db);
    right_conn: any = _open(rebuild_db);
    try {
        for name in COMPARED_TABLES {
            projector: any = _PROJECTORS[name];
            left: any = projector(left_conn);
            right: any = projector(right_conn);
            if left is None or right is None {
                tables[name] = {"differing_rows": 0, "examples": [], "checked": False};
                continue;
            }
            differing: any;
            examples: any;
            (differing, examples) = _diff_projection(left, right, path_prefix) as any;
            tables[name] = {"differing_rows": differing, "examples": examples, "checked": True};
        }
    } finally {
        left_conn.close();
        right_conn.close();
    }

    total: any = sum(t["differing_rows"] for t in tables.values());
    worst: any = max(COMPARED_TABLES, key=lambda (name) -> any { tables[name]["differing_rows"] });
    return {
        "tables": tables,
        "total_differing_rows": total,
        "worst_table": worst if tables[worst]["differing_rows"] else "",
        "unchecked": [n for n in COMPARED_TABLES if not tables[n]["checked"]],
        "snapshot_summary": _snapshot_summary(incremental_db, rebuild_db),
    };
}

impl _snapshot_summary(incremental_db: Path, rebuild_db: Path) -> dict[str, Any] {
    GraphStore = lazy("graph", "GraphStore");
    diff_snapshots = lazy("graph_diff", "diff_snapshots");
    take_snapshot = lazy("graph_diff", "take_snapshot");

    left: any = GraphStore(incremental_db);
    try {
        before: any = take_snapshot(left);
    } finally {
        left.close();
    }
    right: any = GraphStore(rebuild_db);
    try {
        after: any = take_snapshot(right);
    } finally {
        right.close();
    }
    return `dict(diff_snapshots(before, after)["summary"]);
}

impl _git(tree: Path, *args_: str, check: bool = True) -> str {
    args: any = tuple(args_);
    proc: any = subprocess.run(
        ["git", *_GIT_IDENTITY, *args],
        cwd=`str(tree),
        capture_output=True,
        text=True,
        timeout=120,
        stdin=subprocess.DEVNULL,
    );
    if check and proc.returncode != 0 {
        raise RuntimeError(f"git {" ".join(args)} failed in {tree}: {proc.stderr.strip()}");
    }
    return proc.stdout;
}

impl _tracked_files(repo_path: Path) -> list[str] {
    proc: any = subprocess.run(
        ["git", "ls-files", "-z"],
        cwd=`str(repo_path),
        capture_output=True,
        timeout=120,
        stdin=subprocess.DEVNULL,
    );
    if proc.returncode != 0 {
        return [];
    }
    raw: any = proc.stdout.decode("utf-8", errors="replace");
    return [p for p in raw.split("\x00") if p];
}

impl _materialise_tree(repo_path: Path, destination: Path) -> Path {
    destination = destination.expanduser().resolve();
    destination.mkdir(parents=True, exist_ok=True);
    tracked: any = _tracked_files(repo_path);
    if not tracked {
        raise RuntimeError(f"{repo_path} has no git-tracked files to copy");
    }
    for rel in tracked {
        source: any = repo_path / rel;
        if not source.is_file() or source.is_symlink() {
            continue;
        }
        target: any = destination / rel;
        target.parent.mkdir(parents=True, exist_ok=True);
        shutil.copy2(source, target);
    }
    _git(destination, "init", "-q");
    _git(destination, "add", "-A");
    _git(destination, "commit", "-q", "--no-verify", "-m", "baseline");
    return destination;
}

impl _head(tree: Path) -> str {
    return _git(tree, "rev-parse", "HEAD").strip();
}

impl _commit_all(tree: Path, message: str) -> str {
    _git(tree, "add", "-A");
    _git(tree, "commit", "-q", "--no-verify", "--allow-empty", "-m", message);
    return _head(tree);
}

impl _reset(tree: Path, sha: str) {
    _git(tree, "reset", "-q", "--hard", sha);
    _git(tree, "clean", "-qfd");
}

impl _relative(tree: Path, stored: str) -> str {
    try {
        return os.path.relpath(stored, `str(tree)).replace(os.sep, "/");
    } except ValueError {
        return stored;
    }
}

impl _pick_targets(db_path: Path, tree: Path) -> _Targets {
    per_file: Counter[str];
    conn: any = _open(db_path);
    try {
        symbols: list[_Symbol] = [];
        for row in conn.execute(
            "SELECT qualified_name, name, file_path, line_start, line_end FROM nodes WHERE kind = 'Function' AND is_test = 0 AND line_start IS NOT NULL AND line_end IS NOT NULL ORDER BY file_path, line_start",
        ) {
            symbols.append(
                _Symbol(
                    qualified_name=row["qualified_name"],
                    name=row["name"],
                    rel_path=_relative(tree, row["file_path"]),
                    line_start=`int(row["line_start"]),
                    line_end=`int(row["line_end"]),
                ),
            );
        }
        per_file = Counter(s.rel_path for s in symbols);
        ranked: any = sorted(
            (p for p in per_file if Path(p).suffix in _COMMENT_TOKENS),
            key=lambda (p) -> any { (-per_file[p], p) },
        );
        primary: any = ranked[0] if ranked else "";
        suffix: any = Path(primary).suffix if primary else "";
        sibling: any = next((p for p in ranked[1:] if Path(p).suffix == suffix), "");
        import_sites: any = [
            (_relative(tree, row["file_path"]), `int(row["line"]))
            for row in conn.execute(
                "SELECT file_path, line FROM edges WHERE kind = 'IMPORTS_FROM' AND line > 0 ORDER BY file_path, line",
            )
        ];
        depended_on: any = [
            _relative(tree, row["file_path"])
            for row in conn.execute(
                "SELECT n.file_path AS file_path, COUNT(*) AS hits FROM edges e JOIN nodes n ON n.qualified_name = e.target_qualified WHERE e.file_path != n.file_path GROUP BY n.file_path ORDER BY hits DESC, n.file_path",
            )
        ];
        deletable: any = next((p for p in depended_on if Path(p).suffix in _COMMENT_TOKENS), "");
        return _Targets(
            primary=primary,
            sibling=sibling,
            functions=[s for s in symbols if s.rel_path == primary],
            import_sites=import_sites,
            deletable=deletable,
        );
    } finally {
        conn.close();
    }
}

impl _read_lines(path: Path) -> list[str] {
    return path.read_text(encoding="utf-8", errors="replace").splitlines(True);
}

impl _write_lines(path: Path, lines: list[str]) {
    path.write_text("".join(lines), encoding="utf-8");
}

impl _edit_trailing_comment(tree: Path, targets: _Targets) -> _Edit {
    if not targets.primary {
        return _Edit(skipped="no source file with a known comment syntax");
    }
    token: any = _COMMENT_TOKENS[Path(targets.primary).suffix];
    path: any = tree / targets.primary;
    text: any = path.read_text(encoding="utf-8", errors="replace");
    if not text.endswith("\n") {
        text += "\n";
    }
    path.write_text(
        f"{text}{token} incremental-fidelity benchmark: neutral edit\n", encoding="utf-8"
    );
    return _Edit(target=targets.primary, note="appended one comment line");
}

impl _rename_candidate(tree: Path, targets: _Targets) -> tuple[_Symbol, int] | None {
    if not targets.primary {
        return None;
    }
    lines: any = _read_lines(tree / targets.primary);
    for symbol in targets.functions {
        if not symbol.name or not symbol.name.isidentifier() {
            continue;
        }
        for offset in range(0, 3) {
            index: any = symbol.line_start - 1 + offset;
            if 0 <= index < len(lines)
                and re.search(f"\\b{re.escape(symbol.name)}\\b", lines[index])
            {
                return (symbol, index);
            }
        }
    }
    return None;
}

impl _edit_rename_function(tree: Path, targets: _Targets) -> _Edit {
    candidate: any = _rename_candidate(tree, targets);
    if candidate is None {
        return _Edit(skipped="no function definition line found to rename");
    }
    symbol: any;
    index: any;
    (symbol, index) = candidate as any;
    path: any = tree / targets.primary;
    lines: any = _read_lines(path);
    lines[index] = re.sub(
        f"\\b{re.escape(symbol.name)}\\b", symbol.name + _RENAME_SUFFIX, lines[index], count=1
    );
    _write_lines(path, lines);
    return _Edit(
        target=targets.primary, note=f"renamed {symbol.name} to {symbol.name}{_RENAME_SUFFIX}"
    );
}

impl _edit_delete_file(tree: Path, targets: _Targets) -> _Edit {
    if not targets.deletable {
        return _Edit(skipped="no depended-on file to delete");
    }
    path: any = tree / targets.deletable;
    if not path.is_file() {
        return _Edit(skipped=f"{targets.deletable} is not a file");
    }
    path.unlink();
    return _Edit(target=targets.deletable, note="deleted a depended-on file");
}

impl _edit_add_file(tree: Path, targets: _Targets) -> _Edit {
    suffix: any = Path(targets.primary).suffix if targets.primary else "";
    source: any = _PROBE_SOURCES.get(suffix);
    if source is None {
        return _Edit(skipped=f"no probe source for {suffix or "unknown suffix"}");
    }
    rel: any = `str(Path(targets.primary).with_name(_PROBE_STEM + suffix));
    (tree / rel).write_text(source, encoding="utf-8");
    return _Edit(target=rel, note="added a new source file");
}

impl _edit_move_function(tree: Path, targets: _Targets) -> _Edit {
    if not targets.primary or not targets.sibling {
        return _Edit(skipped="need two same-language files to move between");
    }
    source_path: any = tree / targets.primary;
    lines: any = _read_lines(source_path);
    movable: any = [
        s
        for s in targets.functions
        if 1 <= s.line_start <= s.line_end <= len(lines)
            and s.line_end > s.line_start
            and not lines[s.line_start - 1][:1].isspace()
    ];
    if not movable {
        return _Edit(skipped="no top-level multi-line function to move");
    }
    symbol: any = movable[-1];
    block: any = lines[symbol.line_start - 1:symbol.line_end];
    remaining: any = lines[:symbol.line_start - 1] + lines[symbol.line_end:];
    _write_lines(source_path, remaining);
    target_path: any = tree / targets.sibling;
    tail: any = target_path.read_text(encoding="utf-8", errors="replace");
    if tail and not tail.endswith("\n") {
        tail += "\n";
    }
    target_path.write_text(tail + "\n\n" + "".join(block), encoding="utf-8");
    return _Edit(target=f"{targets.primary} -> {targets.sibling}", note=f"moved {symbol.name}");
}

impl _ranked_import_sites(targets: _Targets) -> list[tuple[str, int]] {
    suffix: any = Path(targets.primary).suffix if targets.primary else "";

    def rank(site: tuple[str, int]) -> tuple[int, str, int] {
        rel: any = site[0];
        if rel == targets.primary {
            return (0, rel, site[1]);
        }
        if suffix and Path(rel).suffix == suffix {
            return (1, rel, site[1]);
        }
        return (2, rel, site[1]);
    }

    return sorted(targets.import_sites, key=rank);
}

impl _edit_change_import(tree: Path, targets: _Targets) -> _Edit {
    for (rel, line_no) in _ranked_import_sites(targets) {
        path: any = tree / rel;
        if not path.is_file() {
            continue;
        }
        lines: any = _read_lines(path);
        if not 1 <= line_no <= len(lines) {
            continue;
        }
        text: any = lines[line_no - 1];
        stripped: any = text.strip();
        if not stripped or stripped.endswith(("(", "\\", "{", ",")) {
            continue;
        }
        del lines[line_no - 1];
        _write_lines(path, lines);
        return _Edit(target=rel, note=f"removed import at line {line_no}");
    }
    return _Edit(skipped="no single-line import statement found");
}

impl _blank_row(repo: str, kind: str) -> dict[str, Any] {
    row: dict[str, Any] = {
        "repo": repo,
        "edit_kind": kind,
        "status": "skipped",
        "known_failure": 1 if kind in KNOWN_FAILURES else 0,
        "target": "",
        "total_differing_rows": 0,
        "worst_table": "",
        "snapshot_nodes_only_in_rebuild": 0,
        "snapshot_nodes_only_in_incremental": 0,
        "snapshot_edges_only_in_rebuild": 0,
        "snapshot_edges_only_in_incremental": 0,
        "unchecked_tables": "",
        "example": "",
        "note": "",
        "seconds": 0.0,
        "benchmark_seconds": 0.0,
    };
    for table in COMPARED_TABLES {
        row[f"{table}_diff"] = 0;
    }
    return row;
}

impl _record(row: dict[str, Any], diff: dict[str, Any]) {
    for table in COMPARED_TABLES {
        row[f"{table}_diff"] = diff["tables"][table]["differing_rows"];
    }
    row["total_differing_rows"] = diff["total_differing_rows"];
    row["worst_table"] = diff["worst_table"];
    summary: any = diff["snapshot_summary"];
    row["snapshot_nodes_only_in_rebuild"] = summary["nodes_added"];
    row["snapshot_nodes_only_in_incremental"] = summary["nodes_removed"];
    row["snapshot_edges_only_in_rebuild"] = summary["edges_added"];
    row["snapshot_edges_only_in_incremental"] = summary["edges_removed"];
    row["unchecked_tables"] = ",".join(diff["unchecked"]);
    worst: any = diff["worst_table"];
    if worst {
        examples: any = diff["tables"][worst]["examples"];
        row["example"] = f"{worst}: {examples[0]}" if examples else worst;
    }
}

impl _run_scenario(
    kind: str,
    repo: str,
    tree: Path,
    workdir: Path,
    baseline_db: Path,
    base_sha: str,
    targets: _Targets,
) -> dict[str, Any] {
    row: any = _blank_row(repo, kind);
    started: any = time.perf_counter();
    try {
        applier: any = _APPLIERS[kind] if kind != "revert" else _edit_trailing_comment;
        edit: any = applier(tree, targets);
        if edit.skipped {
            row["note"] = edit.skipped;
            return row;
        }
        row["target"] = edit.target;
        row["note"] = edit.note;

        incremental_db: any = workdir / f"{kind}_incremental.db";
        _copy_db(baseline_db, incremental_db);

        edited_sha: any = _commit_all(tree, f"benchmark: {kind}");
        _incremental_build(tree, incremental_db, base=base_sha);

        if kind == "revert" {
            _reset(tree, base_sha);
            _commit_all(tree, "benchmark: revert");
            _incremental_build(tree, incremental_db, base=edited_sha);
            row["note"] = "appended then removed one comment line";
        }

        rebuild_db: any = workdir / f"{kind}_rebuild.db";
        _clean_build(tree, rebuild_db);

        diff: any = compare_graphs(incremental_db, rebuild_db, path_prefix=`str(tree) + "/");
        _record(row, diff);
        if diff["total_differing_rows"] == 0 {
            row["status"] = "ok";
        } elif kind in KNOWN_FAILURES {
            row["status"] = "known_failure";
        } else {
            row["status"] = "diverged";
        }
        return row;
    } except Exception as exc {
        logger.warning("incremental_fidelity %s failed: %s", kind, exc);
        row["status"] = "error";
        row["note"] = f"{`type(exc).__name__}: {exc}"[:300];
        return row;
    } finally {
        row["seconds"] = round(time.perf_counter() - started, 3);
        try {
            _reset(tree, base_sha);
        } except RuntimeError as exc {
            logger.warning("could not reset the benchmark tree: %s", exc);
        }
    }
}

impl run(repo_path: Path, store: Any, config: dict) -> list[dict] {
    kind: any;
    repo: any = config.get("name", `str(repo_path));
    kinds: any = [k for k in EDIT_KINDS if k in `set(config.get("fidelity_edits", EDIT_KINDS))];
    started: any = time.perf_counter();
    workdir: any = Path(tempfile.mkdtemp(prefix="crg-fidelity-")).resolve();
    try {
        tree: any = _materialise_tree(Path(repo_path), workdir / "tree");
        base_sha: any = _head(tree);
        baseline_db: any = workdir / "baseline.db";
        _clean_build(tree, baseline_db);
        targets: any = _pick_targets(baseline_db, tree);
        rows: any = [
            _run_scenario(kind, repo, tree, workdir, baseline_db, base_sha, targets)
            for kind in kinds
        ];
    } except Exception as exc {
        logger.error("incremental_fidelity setup failed: %s", exc);
        rows = [];
        for kind in kinds {
            row: any = _blank_row(repo, kind);
            row["status"] = "error";
            row["note"] = f"{`type(exc).__name__}: {exc}"[:300];
            rows.append(row);
        }
    } finally {
        shutil.rmtree(workdir, ignore_errors=True);
    }

    elapsed: any = round(time.perf_counter() - started, 3);
    for row in rows {
        row["benchmark_seconds"] = elapsed;
    }
    return rows;
}
