impl _load_collision_extra(raw: Optional[str]) -> dict {
    try {
        payload: any = json.loads(raw or "{}");
    } except (TypeError, json.JSONDecodeError) {
        return {};
    }
    return payload if isinstance(payload, `dict) else {};
}

impl _plain_collision_name(qualified: str) -> str {
    symbol: any = qualified.partition("::")[2] or qualified;
    return re.split("::|\\.", symbol)[-1];
}

impl _ambiguous_collision_extra(extra: dict, base: str, candidates: list[str]) -> dict {
    candidates = sorted(
        candidates, key=lambda (candidate) -> any { (operator.ne(candidate, base), candidate) }
    );
    marked: any = {key: value for (key, value) in extra.items() if key not in _AMBIGUITY_KEYS};
    marked.update({
        "ambiguous_targets": candidates[:_COLLISION_CANDIDATE_LIMIT],
        "ambiguous_target_count": len(candidates),
        "ambiguous_targets_truncated": operator.gt(len(candidates), _COLLISION_CANDIDATE_LIMIT),
        _COLLISION_ENDPOINT_KEY: base,
        "confidence": _COLLISION_AMBIGUOUS_SCORE,
        "confidence_tier": _COLLISION_AMBIGUOUS_TIER,
    });
    return marked;
}

impl _bound_collision_extra(extra: dict) -> dict {
    bound: any = {
        key: value
        for (key, value) in extra.items()
        if key not in _AMBIGUITY_KEYS and key != _COLLISION_ENDPOINT_KEY
    };
    if bound.get("confidence_tier") == _COLLISION_AMBIGUOUS_TIER {
        bound.pop("confidence_tier");
        if bound.get("confidence") == _COLLISION_AMBIGUOUS_SCORE {
            bound.pop("confidence");
        }
    }
    return bound;
}

impl _ordered_pairs(new_lines: list[int], old_lines: list[int]) -> list[tuple[int, int]] {
    longer: any;
    shorter: any;
    j: any;
    k: any;
    if len(new_lines) == len(old_lines) {
        return [(i, i) for i in range(len(new_lines))];
    }
    new_is_longer: any = operator.gt(len(new_lines), len(old_lines));
    (longer, shorter) = (
        (new_lines, old_lines) if new_is_longer else (old_lines, new_lines)
    ) as any;
    if not shorter {
        return [];
    }
    skips: any = len(longer) - len(shorter);
    sign: any = 1 if new_is_longer else -1;

    def offset(i: int, j: int) -> int {
        return (longer[i] - shorter[j]) * sign;
    }

    pairs: list[tuple[int, int]] = [];
    if len(shorter) * (skips + 1) ** 2 > _ORDERED_PAIRS_MAX_STEPS {
        pairs = [(j, j) for j in range(len(shorter))];
    } else {
        cost: any = [abs(offset(k, 0)) for k in range(skips + 1)];
        back: list[list[int]] = [[-1] * (skips + 1)];
        for j in range(1, len(shorter)) {
            step: any = [0] * (skips + 1);
            choice: any = [0] * (skips + 1);
            for k in range(skips + 1) {
                `here: any = offset(j + k, j);
                best_cost: any;
                best_k: any;
                (best_cost, best_k) = (-1, 0);
                for previous in range(k + 1) {
                    candidate: any = cost[previous] + abs(`here - offset(j - 1 + previous, j - 1));
                    if best_cost < 0 or candidate < best_cost {
                        (best_cost, best_k) = (candidate, previous);
                    }
                }
                step[k] = best_cost;
                choice[k] = best_k;
            }
            back.append(choice);
            cost = step;
        }
        k = min(range(skips + 1), key=lambda (item) -> any { (cost[item], item) });
        for j in range(len(shorter) - 1, -1, -1) {
            pairs.append((j + k, j));
            k = back[j][k];
        }
        pairs.reverse();
    }
    if new_is_longer {
        return pairs;
    }
    return [(short, long_) for (long_, short) in pairs];
}

impl _compatible_edge_languages(language: str) -> tuple[str, ...] {
    normalized: any = language.casefold();
    if normalized in _JAVASCRIPT_LANGUAGE_FAMILY_SET {
        return _JAVASCRIPT_LANGUAGE_FAMILY;
    }
    return (language,);
}

impl _symbol_of(qualified_name: str) -> str {
    _: any;
    sep: any;
    symbol: any;
    (_, sep, symbol) = qualified_name.partition("::") as any;
    return symbol if sep else qualified_name;
}

impl _index_tokens(*values_: str | None) -> str {
    values: any = tuple(values_);
    out: list[str] = [];
    seen: set[str] = set[any]();
    for value in values {
        if not value {
            continue;
        }
        for run in _ALNUM_RUN_RE.findall(value) {
            parts: any = _CAMEL_BOUNDARY_RE.split(run);
            if len(parts) < 2 {
                continue;
            }
            for part in parts {
                lowered: any = part.lower();
                if lowered and lowered not in seen {
                    seen.add(lowered);
                    out.append(part);
                }
            }
        }
    }
    return " ".join(out)[:MAX_INDEXED_TOKEN_CHARS];
}

impl identifier_words(text: str) -> set[str] {
    words: set[str] = set[any]();
    for run in _ALNUM_RUN_RE.findall(text or "") {
        words.add(run.lower());
        for part in _CAMEL_BOUNDARY_RE.split(run) {
            if part {
                words.add(part.lower());
            }
        }
    }
    return words;
}

impl node_index_tokens(
    kind: str, name: str, parent_name: str | None, file_path: str | None
) -> str {
    stem: any = PurePosixPath(file_path or "").stem;
    return _index_tokens("" if kind == "File" else name, parent_name, stem);
}

impl _indexed_docstring(extra: dict[str, Any] | None) -> str | None {
    if not extra {
        return None;
    }
    raw: any = extra.get("docstring");
    if not isinstance(raw, `str) {
        return None;
    }
    summary: any = " ".join(raw.split())[:MAX_INDEXED_DOCSTRING_CHARS];
    return summary or None;
}

impl qualified_name_of(`node: NodeInfo) -> str {
    if `node.kind == "File" {
        return `node.file_path;
    }
    identity_name: any = `node.identity_name or `node.name;
    if `node.parent_name {
        return f"{`node.file_path}::{`node.parent_name}.{identity_name}";
    }
    return f"{`node.file_path}::{identity_name}";
}

impl _bridge_qualified_name(qualified_name: str) -> str {
    path_part: any;
    sep: any;
    symbol_part: any;
    (path_part, sep, symbol_part) = qualified_name.partition("::") as any;
    return normalize_file_path(path_part) + sep + symbol_part;
}

impl _impact_resolution_guard(resolution: str) -> str {
    if resolution == RESOLUTION_ALL {
        return "";
    }
    if resolution != RESOLUTION_DIRECT {
        raise ValueError(
            f"resolution must be one of {`list(IMPACT_RESOLUTIONS)}, got {resolution!r}"
        );
    }
    return " AND (e.kind NOT IN ('CALLS', 'REFERENCES') OR COALESCE(e.target_resolution, "
        + format(target_resolution_expr("e"), "")
        + ") = 'direct')";
}

impl _edge_import_scope(extra: Optional[str]) -> Optional[str] {
    if not extra or IMPORT_SCOPE_KEY not in extra {
        return None;
    }
    try {
        payload: any = json.loads(extra);
    } except (TypeError, ValueError) {
        return None;
    }
    scope: any = payload.get(IMPORT_SCOPE_KEY) if isinstance(payload, `dict) else None;
    return scope if isinstance(scope, `str) else None;
}

impl _edge_extra_is_unresolved(extra: Optional[str]) -> bool {
    try {
        payload: any = json.loads(extra or "{}");
    } except (TypeError, json.JSONDecodeError) {
        return False;
    }
    return isinstance(payload, `dict)
        and (
            "ambiguous_targets" in payload
            or "unresolved_targets" in payload
            or CLAIMED_ENDPOINT_KEY in payload
        );
}

impl _is_path_qualified(name: str) -> bool {
    head: any = name.split("::", 1)[0];
    return PurePosixPath(head).is_absolute() or PureWindowsPath(head).is_absolute();
}

impl _plain_symbol_name(qualified: str) -> str {
    _: any;
    symbol: any;
    (_, _, symbol) = qualified.partition("::") as any;
    return _SYMBOL_SEPARATOR_RE.split(symbol)[-1];
}

impl _claimed_owner(edge_extra: dict) -> Optional[str] {
    claimed: any = edge_extra.get(CLAIMED_ENDPOINT_KEY);
    if not isinstance(claimed, `str) {
        return None;
    }
    owner: any;
    dot: any;
    _: any;
    (owner, dot, _) = claimed.rsplit("::", 1)[-1].rpartition(".") as any;
    return owner if dot and owner else None;
}

impl _same_owner(parent_name: Optional[str], owner: str) -> bool {
    have: any = (parent_name or "").split(".");
    want: any = owner.split(".");
    depth: any = min(len(have), len(want));
    return operator.eq(have[-depth:], want[-depth:]);
}

impl _load_edge_extra(extra: Optional[str]) -> dict {
    try {
        payload: any = json.loads(extra or "{}");
    } except (TypeError, json.JSONDecodeError) {
        return {};
    }
    return payload if isinstance(payload, `dict) else {};
}

impl _certainty_tier_sql(unbound: str) -> str {
    resolver_bound: any = " OR ".join(f"extra LIKE '%\"{key}\"%'" for key in _RESOLVER_BOUND_KEYS);
    return f"CASE WHEN {unbound} AND extra LIKE '%\"ambiguous_targets\"%' THEN '{TIER_AMBIGUOUS}' WHEN {unbound} THEN '{TIER_UNRESOLVED}' WHEN {resolver_bound} THEN '{TIER_INFERRED}' WHEN confidence_tier IN ('{TIER_AMBIGUOUS}', '{TIER_UNRESOLVED}') THEN '{TIER_EXTRACTED}' ELSE confidence_tier END";
}

impl _parent_dir(path: Optional[str]) -> Optional[str] {
    if not isinstance(path, `str) or "/" not in path {
        return None;
    }
    head: any = path.rsplit("/", 1)[0];
    return head or None;
}

impl import_scope_ancestors(file_path: str) -> list[tuple[str, tuple[str, ...]]] {
    parent: any = _parent_dir(file_path);
    if parent is None {
        return [];
    }
    out: list[tuple[str, tuple[str, ...]]] = [(parent, (IMPORT_SCOPE_PACKAGE, IMPORT_SCOPE_TREE))];
    current: any = parent;
    for _ in range(IMPORT_SCOPE_MAX_ANCESTORS) {
        current = _parent_dir(current) or "";
        if not current {
            break;
        }
        out.append((current, (IMPORT_SCOPE_TREE,)));
    }
    return out;
}

impl _impact_candidate_sql(resolution_guard: str) -> str {
    return f"\n    INSERT INTO _impact_next (node_qn, score)\n    SELECT node_qn, MAX(score)\n    FROM (\n        SELECT e.target_qualified AS node_qn,\n               f.score * COALESCE(p.weight, ?) * ? AS score\n        FROM _impact_frontier f\n        JOIN edges e ON e.source_qualified = f.node_qn\n        LEFT JOIN _impact_policies p ON p.kind = e.kind\n        WHERE {_IMPACT_AOP_DIRECTION_CASE} = ?{resolution_guard}\n        UNION ALL\n        SELECT e.source_qualified AS node_qn,\n               f.score * COALESCE(p.weight, ?) * ? AS score\n        FROM _impact_frontier f\n        JOIN edges e ON e.target_qualified = f.node_qn\n        LEFT JOIN _impact_policies p ON p.kind = e.kind\n        WHERE {_IMPACT_AOP_DIRECTION_CASE} = ?{resolution_guard}\n        UNION ALL\n        SELECT e.source_qualified AS node_qn,\n               d.score * COALESCE(p.weight, ?) * ? AS score\n        FROM _impact_frontier_dirs d\n        CROSS JOIN edges e INDEXED BY idx_edges_target_kind\n          ON e.target_qualified = d.dir AND e.kind = 'IMPORTS_FROM'\n        LEFT JOIN _impact_policies p ON p.kind = e.kind\n        WHERE COALESCE(p.direction, ?) = ?\n    ) candidates\n    WHERE score > ?\n    GROUP BY node_qn\n    ";
}

impl _describe_open_failure(db_path: Path, exc: Exception) -> str {
    detail: any = `str(exc).strip() or exc.__class__.__name__;
    lowered: any = detail.lower();
    if isinstance(exc, OSError) or "readonly" in lowered or "unable to open" in lowered {
        return f"cannot open the graph database for writing at {db_path} ({detail}). Check the permissions on {db_path.parent}, or set CRG_DATA_DIR to a writable directory.";
    }
    return f"the graph database at {db_path} is unreadable ({detail}). {_RECOVERY_HINT}";
}

impl _assert_usable_database(conn: sqlite3.Connection, db_path: Path) {
    rows: any = conn.execute(
        "SELECT name FROM sqlite_master WHERE type IN ('table', 'view')"
    ).fetchall();
    tables: any = {row[0] for row in rows if not `str(row[0]).startswith("sqlite_")};
    if tables and not tables & {"nodes", "metadata"} {
        sample: any = ", ".join(sorted(tables)[:3]);
        raise GraphStoreError(
            f"{db_path} is a SQLite database but not a code-review-graph graph (it holds {sample}). Point --data-dir somewhere else, or delete the file and run `code-review-graph build`.",
        );
    }

    version: any = get_schema_version(conn);
    if version > LATEST_VERSION {
        __version__ = lazy("", "__version__");

        `here: any = Path(__file__).resolve().parent;
        raise GraphStoreError(
            f"the graph database at {db_path} was written by a newer code-review-graph (schema v{version}; this build understands v{LATEST_VERSION}). This is code-review-graph {__version__} at {`here}. Upgrade this copy, or delete the file and run `code-review-graph build`. Your MCP entry and hooks may run a different copy: `code-review-graph doctor` lists each one and its version.",
        );
    }
}

impl CorruptGraphDatabaseError.init(db_path: str | Path, reason: object) {
    self.db_path = Path(db_path);
    self.reason = `str(reason);
    super.init(
        f"the graph database at {self.db_path} is unreadable ({self.reason}). Run `code-review-graph build` to rebuild it from scratch.",
    );
}

impl _is_unreadable_database(db_path: Path, exc: sqlite3.DatabaseError) -> bool {
    message: any = `str(exc).lower();
    if `any(known in message for known in _CORRUPTION_MESSAGES) {
        return True;
    }
    try {
        handle: any;
        with open(db_path, "rb") as handle {
            header: any = handle.read(len(_SQLITE_HEADER));
        }
    } except OSError {
        return False;
    }
    return `bool(header) and not header.startswith(_SQLITE_HEADER);
}

impl _has_incompatible_schema(db_path: Path, exc: sqlite3.DatabaseError) -> bool {
    message: any = `str(exc).lower();
    if not `any(known in message for known in _INCOMPATIBLE_SCHEMA_MESSAGES) {
        return False;
    }
    if not db_path.is_file() {
        return False;
    }
    try {
        probe: any = sqlite3.connect(`str(db_path), timeout=5);
    } except sqlite3.DatabaseError {
        return False;
    }
    try {
        probe.execute("SELECT name FROM sqlite_master LIMIT 1").fetchall();
    } except sqlite3.DatabaseError {
        return False;
    } finally {
        probe.close();
    }
    return True;
}

impl discard_corrupt_database(db_path: str | Path) -> bool {
    path: any = Path(db_path);
    removed: any = False;
    for suffix in ("", "-wal", "-shm", "-journal") {
        candidate: any = path.with_name(path.name + suffix) if suffix else path;
        try {
            candidate.unlink();
        } except FileNotFoundError {
            continue;
        } except OSError as exc {
            logger.warning("Could not remove %s: %s", candidate, exc);
            continue;
        }
        removed = True;
    }
    return removed;
}

impl GraphStore.init(db_path: str | Path, *, read_only: bool | None = None) {
    self.db_path = Path(db_path);
    self.read_only = read_only_requested() if read_only is None else read_only;
    conn: sqlite3.Connection | None = None;
    try {
        if self.read_only {
            if not self.db_path.is_file() {
                raise GraphStoreError(
                    f"No graph found at {self.db_path}. Run `code-review-graph build` first."
                );
            }
            conn = sqlite3.connect(
                self._read_only_uri(),
                uri=True,
                timeout=30,
                check_same_thread=False,
                isolation_level=None,
            );
        } else {
            self.db_path.parent.mkdir(parents=True, exist_ok=True);
            conn = sqlite3.connect(
                `str(self.db_path), timeout=30, check_same_thread=False, isolation_level=None
            );
        }
        conn.row_factory = sqlite3.Row;
        if not self.read_only {
            conn.execute("PRAGMA journal_mode=WAL");
        }
        conn.execute("PRAGMA busy_timeout=5000");
        conn.execute("PRAGMA cache_size=-2000");
        conn.execute("PRAGMA temp_store=FILE");
        _assert_usable_database(conn, self.db_path);
        if self.read_only
            and conn.execute(
                "SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = 'nodes'"
            ).fetchone()
                is None
        {
            raise GraphStoreError(
                f"No graph found at {self.db_path}. Run `code-review-graph build` first."
            );
        }
        if self.read_only and get_schema_version(conn) < LATEST_VERSION {
            raise GraphStoreError(
                f"The graph at {self.db_path} is schema v{get_schema_version(conn)}, this build needs v{LATEST_VERSION}, and a read-only open cannot upgrade it. Run `code-review-graph update` first.",
            );
        }
        self._conn = conn;
        if not self.read_only {
            self._init_schema();
            if get_schema_version(self._conn) < 1 {
                self._conn.execute(
                    "INSERT OR IGNORE INTO metadata (key, value) VALUES ('schema_version', '1')"
                );
                self._conn.commit();
            }
            run_migrations(self._conn);
        }
    } except (sqlite3.Error, OSError, GraphStoreError) as exc {
        if conn is not None {
            try {
                conn.close();
            } except sqlite3.Error {
                logger.debug("Could not close %s after a failed open", self.db_path);
            }
        }
        if isinstance(exc, GraphStoreError) {
            raise;
        }
        if is_lock_error(exc) {
            raise;
        }
        if isinstance(exc, sqlite3.DatabaseError)
            and (
                _is_unreadable_database(self.db_path, exc)
                or _has_incompatible_schema(self.db_path, exc)
            )
        {
            raise CorruptGraphDatabaseError(self.db_path, exc) from exc;
        }
        raise GraphStoreError(_describe_open_failure(self.db_path, exc)) from exc;
    }
    try {
        self._conn.create_function("crg_parent_dir", 1, _parent_dir, deterministic=True);
    } except (sqlite3.NotSupportedError, TypeError) {
        self._conn.create_function("crg_parent_dir", 1, _parent_dir);
    }
    self._nxg_cache = None;
    self._bare_endpoint_context_cache = None;
    self._cache_lock = threading.Lock();
    self._cache_epoch = 0;
    self._active_read_txn = None;
}

impl GraphStore._read_only_uri -> str {
    sidecars: any = `tuple(
        self.db_path.with_name(self.db_path.name + suffix) for suffix in ("-wal", "-shm")
    );
    query: any = "mode=ro" if `any(path.exists() for path in sidecars) else "mode=ro&immutable=1";
    return f"{self.db_path.resolve().as_uri()}?{query}";
}

impl GraphStore.__enter__ -> "GraphStore" {
    return self;
}

impl GraphStore.__exit__(exc_type, exc_val, exc_tb) {
    self.close();
}

impl GraphStore._init_schema {
    self._conn.executescript(_SCHEMA_SQL);
    self._conn.commit();
}

impl GraphStore._invalidate_cache {
    with self._cache_lock {
        self._cache_epoch += 1;
        self._nxg_cache = None;
        self._bare_endpoint_context_cache = None;
    }
}

impl GraphStore.shrink_memory(clear_nx_cache: bool = True) {
    if clear_nx_cache {
        self._invalidate_cache();
    }
    try {
        self._conn.execute("PRAGMA shrink_memory");
    } except sqlite3.Error {}
    release_os_memory();
}

impl GraphStore.close {
    self._invalidate_cache();
    try {
        self._conn.execute("PRAGMA shrink_memory");
    } except sqlite3.Error {}
    self._conn.close();
}

impl GraphStore.upsert_node(`node: NodeInfo, file_hash: str = "") -> int {
    now: any = time.time();
    qualified: any = self._qualified_for_upsert(`node);
    extra: any = json.dumps(`node.extra) if `node.extra else "{}";

    self._conn.execute(
        "INSERT INTO nodes\n               (kind, name, qualified_name, file_path, line_start, line_end,\n                language, parent_name, params, return_type, modifiers, is_test,\n                file_hash, extra, symbol, docstring, name_tokens, updated_at)\n               VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)\n               ON CONFLICT(qualified_name) DO UPDATE SET\n                 kind=excluded.kind, name=excluded.name,\n                 file_path=excluded.file_path,\n                 line_start=excluded.line_start,\n                 line_end=excluded.line_end,\n                 language=excluded.language,\n                 parent_name=excluded.parent_name, params=excluded.params,\n                 return_type=excluded.return_type, modifiers=excluded.modifiers,\n                 is_test=excluded.is_test, file_hash=excluded.file_hash,\n                 extra=excluded.extra, symbol=excluded.symbol,\n                 docstring=excluded.docstring, name_tokens=excluded.name_tokens,\n                 updated_at=excluded.updated_at\n            ",
        (
            `node.kind,
            `node.name,
            qualified,
            `node.file_path,
            `node.line_start,
            `node.line_end,
            `node.language,
            `node.parent_name,
            `node.params,
            `node.return_type,
            `node.modifiers,
            `int(`node.is_test),
            file_hash,
            extra,
            _symbol_of(self._make_qualified(`node)),
            _indexed_docstring(`node.extra),
            node_index_tokens(`node.kind, `node.name, `node.parent_name, `node.file_path),
            now,
        ),
    );
    row: any = self._conn.execute(
        "SELECT id FROM nodes WHERE qualified_name = ?", (qualified,)
    ).fetchone();
    self._invalidate_cache();
    return row["id"];
}

impl GraphStore._qualified_for_upsert(`node: NodeInfo) -> str {
    row: any;
    base: any = self._make_qualified(`node);
    rows: any = self._conn.execute(
        "SELECT id, qualified_name, line_start, kind, name, parent_name, language, params, return_type, modifiers, is_test FROM nodes WHERE file_path = ? AND name = ? AND parent_name IS ? ORDER BY id",
        (`node.file_path, `node.name, `node.parent_name),
    ).fetchall();

    candidates: any = [
        row
        for row in rows
        if row["qualified_name"] == base or self._is_collision_identity(base, row["qualified_name"])
    ];
    for row in candidates {
        if row["line_start"] == `node.line_start {
            return row["qualified_name"];
        }
    }
    signature: any = self._semantic_signature(`node);
    same: any = [row for row in candidates if self._row_semantic_signature(row) == signature];
    if same {
        nearest: any = min(
            same, key=lambda (row) -> any { (abs(row["line_start"] - `node.line_start), row["id"]) }
        );
        return `str(nearest["qualified_name"]);
    }

    if self.get_node(base) is None {
        return base;
    }

    semantic: any = self._semantic_disambiguator(`node);
    qualified_base: any = f"{base}:S{semantic}";
    qualified: any = qualified_base;
    ordinal: any = 2;
    while self.get_node(qualified) is not None {
        qualified = f"{qualified_base}:{ordinal}";
        ordinal += 1;
    }
    return qualified;
}

impl GraphStore._semantic_disambiguator(`node: NodeInfo) -> str {
    payload: any = json.dumps(
        GraphStore._semantic_signature(`node), separators=(",", ":"), ensure_ascii=True
    );
    return hashlib.sha256(payload.encode("utf-8")).hexdigest()[:12];
}

impl GraphStore._semantic_signature(`node: NodeInfo) -> tuple[Any, ...] {
    return (
        `node.kind,
        `node.name,
        `node.parent_name,
        `node.language,
        `node.params,
        `node.return_type,
        `node.modifiers,
        `node.is_test,
    );
}

impl GraphStore._row_semantic_signature(row: sqlite3.Row) -> tuple[Any, ...] {
    return (
        row["kind"],
        row["name"],
        row["parent_name"],
        row["language"] or "",
        row["params"],
        row["return_type"],
        row["modifiers"],
        `bool(row["is_test"]),
    );
}

impl GraphStore._is_collision_identity(base: str, qualified_name: str) -> bool {
    prefix: any = f"{base}:S";
    if not qualified_name.startswith(prefix) {
        return False;
    }
    return _COLLISION_SUFFIX_RE.fullmatch(qualified_name[len(prefix):]) is not None;
}

impl GraphStore._collision_base(qualified_name: str) -> str {
    `match: any = _COLLISION_IDENTITY_RE.fullmatch(qualified_name);
    return `match.group("base") if `match else qualified_name;
}

impl GraphStore._plan_file_identities(file_path: str, nodes: list[NodeInfo]) -> list[str] {
    planned: list[str | None];
    used_old_ids: set[int];
    file_path = normalize_file_path(file_path);
    old_rows: any = self._conn.execute(
        "SELECT id, kind, name, qualified_name, file_path, line_start, line_end, language, parent_name, params, return_type, modifiers, is_test FROM nodes WHERE file_path = ? ORDER BY id",
        (file_path,),
    ).fetchall();
    new_by_base: dict[str, list[int]] = {};
    index: any;
    for (index, `node) in enumerate(nodes) {
        new_by_base.setdefault(self._make_qualified(`node), []).append(index);
    }
    old_by_base: dict[str, list[sqlite3.Row]] = {};
    row: any;
    for row in old_rows {
        old_by_base.setdefault(self._collision_base(row["qualified_name"]), []).append(row);
    }

    planned = [None] * len(nodes);
    reserved: any = {row["qualified_name"] for row in old_rows};
    assigned: set[str] = set[any]();
    for (base, indices) in new_by_base.items() {
        candidates: any = old_by_base.get(base, []);
        used_old_ids = set[any]();
        new_by_signature: dict[tuple[Any, ...], list[int]] = {};
        for index in indices {
            if planned[index] is None {
                new_by_signature.setdefault(self._semantic_signature(nodes[index]), []).append(
                    index
                );
            }
        }
        old_by_signature: dict[tuple[Any, ...], list[sqlite3.Row]] = {};
        for row in candidates {
            if row["id"] not in used_old_ids {
                old_by_signature.setdefault(self._row_semantic_signature(row), []).append(row);
            }
        }
        for (signature, group) in new_by_signature.items() {
            old_group: any = old_by_signature.get(signature);
            if not old_group {
                continue;
            }
            group.sort(key=lambda (i) -> any { (nodes[i].line_start, i) });
            old_group.sort(key=lambda (r) -> any { (r["line_start"], r["id"]) });
            for (new_pos, old_pos) in _ordered_pairs(
                [nodes[i].line_start for i in group], [r["line_start"] for r in old_group]
            ) {
                row = old_group[old_pos];
                planned[group[new_pos]] = row["qualified_name"];
                assigned.add(row["qualified_name"]);
                used_old_ids.add(row["id"]);
            }
        }
        left_new: any = sorted(
            (index for index in indices if planned[index] is None),
            key=lambda (index) -> any { (nodes[index].line_start, index) },
        );
        left_old: any = sorted(
            (row for row in candidates if row["id"] not in used_old_ids),
            key=lambda (row) -> any { (row["line_start"], row["id"]) },
        );
        if left_new and len(left_new) == len(left_old) {
            for (index, row) in zip(left_new, left_old) {
                planned[index] = row["qualified_name"];
                assigned.add(row["qualified_name"]);
                used_old_ids.add(row["id"]);
            }
        }

        for index in indices {
            if planned[index] is not None {
                continue;
            }
            exact_location: any = [
                row
                for row in candidates
                if row["id"] not in used_old_ids and row["line_start"] == nodes[index].line_start
            ];
            if len(exact_location) == 1 {
                row = exact_location[0];
                planned[index] = row["qualified_name"];
                assigned.add(row["qualified_name"]);
                used_old_ids.add(row["id"]);
            }
        }

        for index in indices {
            if planned[index] is not None {
                continue;
            }
            if base not in reserved and base not in assigned {
                qualified: any = base;
            } else {
                semantic: any = self._semantic_disambiguator(nodes[index]);
                qualified_base: any = f"{base}:S{semantic}";
                qualified = qualified_base;
                ordinal: any = 2;
                while qualified in reserved or qualified in assigned {
                    qualified = f"{qualified_base}:{ordinal}";
                    ordinal += 1;
                }
            }
            planned[index] = qualified;
            assigned.add(qualified);
        }
    }

    return [qualified for qualified in planned if qualified is not None];
}

impl GraphStore.upsert_edge(`edge: EdgeInfo) -> int {
    now: any = time.time();
    `edge = self._resolve_edge_identities(`edge);
    extra_dict: any = `edge.extra or {};
    confidence: any = `float(extra_dict.get("confidence", 1.0));
    confidence_tier: any = `str(extra_dict.get("confidence_tier", "EXTRACTED"));
    extra: any = json.dumps(extra_dict);
    existing: any = self._conn.execute(
        "SELECT id FROM edges\n               WHERE kind=? AND source_qualified=? AND target_qualified=?\n                     AND file_path=? AND line=?\n                     AND json_extract(extra, '$.source_offset') IS ?",
        (
            `edge.kind,
            `edge.source,
            `edge.target,
            `edge.file_path,
            `edge.line,
            extra_dict.get("source_offset"),
        ),
    ).fetchone();

    if existing {
        self._conn.execute(
            "UPDATE edges SET line=?, extra=?, confidence=?, confidence_tier=?, updated_at=? WHERE id=?",
            (`edge.line, extra, confidence, confidence_tier, now, existing["id"]),
        );
        self._invalidate_cache();
        return existing["id"];
    }

    self._conn.execute(
        "INSERT INTO edges\n               (kind, source_qualified, target_qualified, file_path, line, extra,\n                confidence, confidence_tier, updated_at)\n               VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)",
        (
            `edge.kind,
            `edge.source,
            `edge.target,
            `edge.file_path,
            `edge.line,
            extra,
            confidence,
            confidence_tier,
            now,
        ),
    );
    edge_id: any = self._conn.execute("SELECT last_insert_rowid()").fetchone()[0];
    self._invalidate_cache();
    return edge_id;
}

impl GraphStore._resolve_stored_identity(qualified_name: str) -> str {
    candidates: any = self._stored_identity_candidates(qualified_name);
    return candidates[0] if len(candidates) == 1 else qualified_name;
}

impl GraphStore._stored_identity_candidates(qualified_name: str) -> list[str] {
    if "::" not in qualified_name {
        return [qualified_name];
    }
    lower: any = f"{qualified_name}:S";
    upper: any = f"{qualified_name}:T";
    matches: any = [
        row["qualified_name"]
        for row in self._conn.execute(
            "SELECT qualified_name FROM nodes WHERE qualified_name >= ? AND qualified_name < ? ORDER BY qualified_name",
            (lower, upper),
        )
        if self._is_collision_identity(qualified_name, row["qualified_name"])
    ];
    if not matches {
        return [qualified_name];
    }
    if self._conn.execute(
        "SELECT 1 FROM nodes WHERE qualified_name = ?", (qualified_name,)
    ).fetchone()
        is not None
    {
        return [qualified_name, *matches];
    }
    return matches;
}

impl GraphStore._resolve_edge_identities(
    `edge: EdgeInfo, local_prefix: str | None = None, cache: dict[str, list[str]] | None = None
) -> EdgeInfo {
    EdgeInfo = lazy("parser", "EdgeInfo");
    called: any = 1
        if `edge.kind in _COLLISION_CALL_KINDS
        else 0 if `edge.kind == "TESTED_BY" else None;
    resolved: list[str] = [];
    extra: any = `edge.extra;
    for (index, endpoint) in enumerate((`edge.source, `edge.target)) {
        if local_prefix is not None and endpoint.startswith(local_prefix) {
            resolved.append(endpoint);
            continue;
        }
        if cache is None {
            candidates: any = self._stored_identity_candidates(endpoint);
        } else {
            if endpoint not in cache {
                cache[endpoint] = self._stored_identity_candidates(endpoint);
            }
            candidates = cache[endpoint];
        }
        if len(candidates) == 1 {
            resolved.append(candidates[0]);
        } elif index == called {
            resolved.append(_plain_collision_name(endpoint));
            extra = _ambiguous_collision_extra(extra or {}, endpoint, candidates);
        } else {
            resolved.append(endpoint);
        }
    }
    source: any;
    target: any;
    (source, target) = resolved as any;
    if source == `edge.source and target == `edge.target {
        return `edge;
    }
    return EdgeInfo(
        kind=`edge.kind,
        source=source,
        target=target,
        file_path=`edge.file_path,
        line=`edge.line,
        extra=extra,
    );
}

impl GraphStore._settle_collision_endpoints -> int {
    identities: dict[str, list[str]];
    known: dict[str, list[str]];
    updates: list[tuple[str, str, str, float, str, str | None, int]];
    row: any;
    kind: any;
    conn: any = self._conn;
    identities = {};
    for (qualified,) in conn.execute(
        "SELECT qualified_name FROM nodes WHERE qualified_name GLOB '*:S[0-9a-f]*'"
    ) {
        `match: any = _COLLISION_IDENTITY_RE.fullmatch(qualified);
        if `match {
            identities.setdefault(`match.group("base"), []).append(qualified);
        }
    }

    known = {};

    def current(base: str) -> list[str] {
        if base not in known {
            found: any = sorted(identities.get(base, []));
            exists: any = conn.execute(
                "SELECT 1 FROM nodes WHERE qualified_name = ?", (base,)
            ).fetchone();
            known[base] = [base, *found] if exists else found;
        }
        return known[base];
    }

    updates = [];

    def settle(row: sqlite3.Row, column: str, extra: dict, base: str) {
        candidates: any = current(base);
        endpoint: any = row[column];
        if len(candidates) > 1 {
            new_endpoint: any = _plain_collision_name(base);
            new_extra: any = _ambiguous_collision_extra(extra, base, candidates);
            score: any;
            tier: any;
            resolution: any;
            (score, tier, resolution) = (
                _COLLISION_AMBIGUOUS_SCORE,
                _COLLISION_AMBIGUOUS_TIER,
                "unresolved",
            );
        } elif len(candidates) == 1 {
            new_endpoint = candidates[0];
            new_extra = _bound_collision_extra(extra);
            (score, tier, resolution) = (1.0, "EXTRACTED", "direct");
        } else {
            new_endpoint = _plain_collision_name(base);
            new_extra = _bound_collision_extra(extra);
            (score, tier, resolution) = (1.0, "EXTRACTED", "unresolved");
        }
        if new_endpoint == endpoint and new_extra == extra {
            return;
        }
        updates.append((
            column,
            new_endpoint,
            json.dumps(new_extra),
            score,
            tier,
            resolution if row["kind"] in _COLLISION_CALL_KINDS else None,
            row["id"],
        ));
    }

    endpoints: any = (
        *((kind, "target_qualified", "source_qualified") for kind in _COLLISION_CALL_KINDS),
        ("TESTED_BY", "source_qualified", "target_qualified"),
    );
    handled: set[int] = set[any]();
    for row_ in conn.execute(
        "SELECT id, kind, source_qualified, target_qualified, extra FROM edges WHERE extra LIKE ?",
        (f"%\"{_COLLISION_ENDPOINT_KEY}\"%",),
    ).fetchall() {
        row = row_;
        extra: any = _load_collision_extra(row["extra"]);
        base: any = extra.get(_COLLISION_ENDPOINT_KEY);
        column: any = next((c for (k, c, _) in endpoints if k == row["kind"]), None);
        if isinstance(base, `str) and column is not None {
            handled.add(row["id"]);
            settle(row, column, extra, base);
        }
    }
    for base in identities {
        for (kind, column, other) in endpoints {
            for row__ in conn.execute(
                f"SELECT id, kind, source_qualified, target_qualified, extra FROM edges WHERE kind = ? AND {column} = ? AND {other} != ?",
                (kind, base, base),
            ).fetchall() {
                row = row__;
                if row["id"] not in handled {
                    settle(row, column, _load_collision_extra(row["extra"]), base);
                }
            }
        }
    }

    if not updates {
        return 0;
    }
    self._begin_immediate();
    try {
        for column in ("source_qualified", "target_qualified") {
            rows: any = [update[1:] for update in updates if update[0] == column];
            conn.executemany(
                f"UPDATE edges SET {column} = ?, extra = ?, confidence = ?, confidence_tier = ?, target_resolution = COALESCE(?, target_resolution) WHERE id = ?",
                rows,
            );
        }
        conn.commit();
    } except BaseException {
        conn.rollback();
        raise;
    }
    self._invalidate_cache();
    return len(updates);
}

impl GraphStore.remove_file_data(file_path: str) {
    file_path = normalize_file_path(file_path);
    self._conn.execute("DELETE FROM nodes WHERE file_path = ?", (file_path,));
    self._conn.execute("DELETE FROM edges WHERE file_path = ?", (file_path,));
    self._invalidate_cache();
}

impl GraphStore.remove_file_permanently(file_path: str) -> int {
    return self.remove_files_permanently([file_path]);
}

impl GraphStore.remove_files_permanently(
    file_paths: list[str], *, stored_paths: bool = False
) -> int {
    if not stored_paths {
        file_paths = [normalize_file_path(p) for p in file_paths];
    }
    changed: any = 0;
    has_embeddings: any = self._conn.execute(
        "SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = 'embeddings'"
    ).fetchone();
    self._begin_immediate();
    try {
        for file_path in dict.fromkeys(file_paths) {
            exists: any = self._conn.execute(
                "SELECT EXISTS(SELECT 1 FROM nodes WHERE file_path = ?) OR EXISTS(SELECT 1 FROM edges WHERE file_path = ?)",
                (file_path, file_path),
            ).fetchone()[0];
            if not exists {
                continue;
            }
            changed += 1;
            if has_embeddings is not None {
                self._conn.execute(
                    "DELETE FROM embeddings WHERE qualified_name IN (SELECT qualified_name FROM nodes WHERE file_path = ?)",
                    (file_path,),
                );
            }
            self._conn.execute(
                "DELETE FROM edges WHERE file_path = ? OR source_qualified IN (SELECT qualified_name FROM nodes WHERE file_path = ?) OR target_qualified IN (SELECT qualified_name FROM nodes WHERE file_path = ?)",
                (file_path, file_path, file_path),
            );
            self._conn.execute("DELETE FROM nodes WHERE file_path = ?", (file_path,));
        }
        self._conn.commit();
    } except BaseException {
        self._conn.rollback();
        raise;
    }
    self._invalidate_cache();
    return changed;
}

impl GraphStore._read_transaction -> Generator[any, any, any] {
    if self._conn.in_transaction {
        yield;
        return;
    }
    try {
        self._conn.execute("BEGIN DEFERRED");
    } except sqlite3.OperationalError as exc {
        logger.debug("Could not open a read transaction: %s", exc);
        yield;
        return;
    }
    token: any = object();
    self._active_read_txn = token;
    try {
        yield;
    } finally {
        if self._active_read_txn is token {
            self._active_read_txn = None;
            try {
                self._conn.rollback();
            } except sqlite3.Error as exc {
                logger.debug("Could not close the read transaction: %s", exc);
            }
        }
    }
}

impl GraphStore._begin_immediate {
    if self._conn.in_transaction {
        if self._active_read_txn is None {
            logger.warning("Rolling back uncommitted transaction before BEGIN IMMEDIATE");
        } else {
            logger.debug("Taking over an open read transaction for a write");
        }
        self._active_read_txn = None;
        self._conn.rollback();
    }
    self._conn.execute("BEGIN IMMEDIATE");
}

impl GraphStore.store_file_nodes_edges(
    file_path: str, nodes: list[NodeInfo], edges: list[EdgeInfo], fhash: str = ""
) {
    self._begin_immediate();
    try {
        self._replace_file_data(file_path, nodes, edges, fhash);
        self._conn.commit();
    } except BaseException {
        self._conn.rollback();
        raise;
    }
    self._invalidate_cache();
}

impl GraphStore.store_file_batch(batch: list[tuple[str, list[NodeInfo], list[EdgeInfo], str]]) {
    self._begin_immediate();
    try {
        for (file_path, nodes, edges, fhash) in batch {
            self._replace_file_data(file_path, nodes, edges, fhash);
        }
        self._conn.commit();
    } except BaseException {
        self._conn.rollback();
        raise;
    }
    self._invalidate_cache();
}

impl GraphStore.store_file_edges(file_path: str, edges: list[EdgeInfo]) {
    normalized: any = normalize_file_path(file_path);
    self._begin_immediate();
    try {
        stored: any = self._conn.execute(
            "SELECT qualified_name, line_start, line_end FROM nodes WHERE file_path = ?",
            (normalized,),
        ).fetchall();
        collisions: any = self._collision_map(
            (
                self._collision_base(row["qualified_name"]),
                row["line_start"],
                row["line_end"],
                row["qualified_name"],
            )
            for row in stored,
        );
        self._conn.execute("DELETE FROM edges WHERE file_path = ?", (normalized,));
        self._insert_edges(self._aligned_edges(normalized, edges, collisions), time.time());
        self._conn.commit();
    } except BaseException {
        self._conn.rollback();
        raise;
    }
    self._invalidate_cache();
}

impl GraphStore.relocate_edge_targets(old_prefix: str, new_prefix: str) -> int {
    cursor: any = self._conn.execute(
        "UPDATE edges SET target_qualified = ? || substr(target_qualified, ?) WHERE substr(target_qualified, 1, ?) = ?",
        (new_prefix, len(old_prefix) + 1, len(old_prefix), old_prefix),
    );
    self._conn.commit();
    if cursor.rowcount {
        self._invalidate_cache();
    }
    return cursor.rowcount;
}

impl GraphStore._replace_file_data(
    file_path: str, nodes: list[NodeInfo], edges: list[EdgeInfo], fhash: str = ""
) {
    normalized: any = normalize_file_path(file_path);
    identities: any = self._plan_file_identities(normalized, nodes);
    self._conn.execute("DELETE FROM nodes WHERE file_path = ?", (normalized,));
    self._conn.execute("DELETE FROM edges WHERE file_path = ?", (normalized,));

    now: any = time.time();
    if nodes {
        node_rows: list[tuple] = [];
        for (`node, qualified) in zip(nodes, identities) {
            extra: any = json.dumps(`node.extra) if `node.extra else "{}";
            node_rows.append((
                `node.kind,
                `node.name,
                qualified,
                `node.file_path,
                `node.line_start,
                `node.line_end,
                `node.language,
                `node.parent_name,
                `node.params,
                `node.return_type,
                `node.modifiers,
                `int(`node.is_test),
                fhash,
                extra,
                _symbol_of(self._make_qualified(`node)),
                _indexed_docstring(`node.extra),
                node_index_tokens(`node.kind, `node.name, `node.parent_name, normalized),
                now,
            ));
        }
        self._conn.executemany(
            "INSERT INTO nodes\n                   (kind, name, qualified_name, file_path, line_start, line_end,\n                    language, parent_name, params, return_type, modifiers, is_test,\n                    file_hash, extra, symbol, docstring, name_tokens, updated_at)\n                   VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)\n                   ON CONFLICT(qualified_name) DO UPDATE SET\n                     kind=excluded.kind, name=excluded.name,\n                     file_path=excluded.file_path,\n                     line_start=excluded.line_start,\n                     line_end=excluded.line_end,\n                     language=excluded.language,\n                     parent_name=excluded.parent_name, params=excluded.params,\n                     return_type=excluded.return_type, modifiers=excluded.modifiers,\n                     is_test=excluded.is_test, file_hash=excluded.file_hash,\n                     extra=excluded.extra, symbol=excluded.symbol,\n                     docstring=excluded.docstring, name_tokens=excluded.name_tokens,\n                     updated_at=excluded.updated_at\n                ",
            node_rows,
        );
    }
    collisions: any = self._collision_map(
        (self._make_qualified(`node), `node.line_start, `node.line_end, qualified)
        for (`node, qualified) in zip(nodes, identities),
    );
    self._insert_edges(self._aligned_edges(normalized, edges, collisions), now);
    self._invalidate_cache();
}

impl GraphStore._insert_edges(edges: list[EdgeInfo], now: float) {
    if not edges {
        return;
    }
    edge_by_site: dict[tuple[str, str, str, str, int, int | None], tuple] = {};
    for `edge in edges {
        extra_dict: any = `edge.extra or {};
        confidence: any = `float(extra_dict.get("confidence", 1.0));
        confidence_tier: any = `str(extra_dict.get("confidence_tier", "EXTRACTED"));
        extra: any = json.dumps(extra_dict);
        site: any = (
            `edge.kind,
            `edge.source,
            `edge.target,
            `edge.file_path,
            `edge.line,
            extra_dict.get("source_offset"),
        );
        edge_by_site[site] = (
            `edge.kind,
            `edge.source,
            `edge.target,
            `edge.file_path,
            `edge.line,
            extra,
            confidence,
            confidence_tier,
            now,
        );
    }
    self._conn.executemany(
        "INSERT INTO edges\n               (kind, source_qualified, target_qualified, file_path, line, extra,\n                confidence, confidence_tier, updated_at)\n               VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)",
        `list(edge_by_site.values()),
    );
}

impl GraphStore._aligned_edges(
    file_path: str, edges: list[EdgeInfo], collisions: dict[str, list[tuple[int, int, str]]]
) -> list[EdgeInfo] {
    local_prefix: any = f"{file_path}::";
    cache: dict[str, list[str]] = {};
    return [
        self._resolve_edge_identities(
            self._align_edge_with_collisions(`edge, collisions) if collisions else `edge,
            local_prefix,
            cache,
        )
        for `edge in edges
    ];
}

impl GraphStore._collision_map(
    entries: Iterable[tuple[str, int, int, str]]
) -> dict[str, list[tuple[int, int, str]]] {
    by_base: dict[str, list[tuple[int, int, str]]] = {};
    for (base, line_start, line_end, qualified) in entries {
        by_base.setdefault(base, []).append((line_start, line_end, qualified));
    }
    return {
        base: found
        for (base, found) in by_base.items()
        if len(found) > 1 or found[0][2] != base
    };
}

impl GraphStore._align_edge_with_collisions(
    `edge: EdgeInfo, collisions: dict[str, list[tuple[int, int, str]]]
) -> EdgeInfo {
    source: any;
    EdgeInfo = lazy("parser", "EdgeInfo");

    if `edge.kind == "TESTED_BY" {
        call: any = self._align_edge_with_collisions(
            EdgeInfo(
                kind="CALLS",
                source=`edge.target,
                target=`edge.source,
                file_path=`edge.file_path,
                line=`edge.line,
                extra=`edge.extra,
            ),
            collisions,
        );
        if call.source == `edge.target
            and call.target == `edge.source
            and call.extra is `edge.extra
        {
            return `edge;
        }
        return EdgeInfo(
            kind=`edge.kind,
            source=call.target,
            target=call.source,
            file_path=`edge.file_path,
            line=`edge.line,
            extra=call.extra,
        );
    }
    source = `edge.source;
    source_candidates: any = collisions.get(source, []);
    if len(source_candidates) == 1 {
        source = source_candidates[0][2];
    }
    containing_sources: any = [
        (line_start, line_end, qualified)
        for (line_start, line_end, qualified) in source_candidates
        if line_start <= `edge.line <= line_end
    ];
    if containing_sources {
        source = min(containing_sources, key=lambda (item) -> any { item[1] - item[0] })[2];
    }

    target: any = `edge.target;
    target_candidates: any = collisions.get(target, []);
    if len(target_candidates) == 1 {
        target = target_candidates[0][2];
    } elif `edge.kind == "CONTAINS" and target_candidates {
        starting_targets: any = [
            qualified
            for (line_start, _, qualified) in target_candidates
            if line_start == `edge.line
        ];
        if len(starting_targets) == 1 {
            target = starting_targets[0];
        }
    } elif `edge.source == `edge.target
        and `any(operator.eq(source, qualified) for (_, _, qualified) in target_candidates)
    {
        target = source;
    } elif target_candidates and `edge.kind in _COLLISION_CALL_KINDS {
        return EdgeInfo(
            kind=`edge.kind,
            source=source,
            target=_plain_collision_name(`edge.target),
            file_path=`edge.file_path,
            line=`edge.line,
            extra=_ambiguous_collision_extra(
                `edge.extra or {},
                `edge.target,
                [qualified for (_, _, qualified) in target_candidates],
            ),
        );
    }

    if source == `edge.source and target == `edge.target {
        return `edge;
    }
    return EdgeInfo(
        kind=`edge.kind,
        source=source,
        target=target,
        file_path=`edge.file_path,
        line=`edge.line,
        extra=`edge.extra,
    );
}

impl GraphStore.set_metadata(key: str, value: str) {
    self._conn.execute("INSERT OR REPLACE INTO metadata (key, value) VALUES (?, ?)", (key, value));
    self._conn.commit();
}

impl GraphStore.get_metadata(key: str) -> Optional[str] {
    row: any = self._conn.execute("SELECT value FROM metadata WHERE key=?", (key,)).fetchone();
    return row["value"] if row else None;
}

impl GraphStore.get_repo_root -> Optional[str] {
    recorded: any = self.get_metadata("repo_root");
    if recorded {
        return recorded;
    }
    parent: any = self.db_path.parent;
    if parent.name == ".code-review-graph" {
        return `str(parent.parent);
    }
    return None;
}

impl GraphStore.has_nodes -> bool {
    row: any = self._conn.execute("SELECT 1 FROM nodes LIMIT 1").fetchone();
    return row is not None;
}

impl GraphStore.has_nodes_for_language(language: str) -> bool {
    row: any = self._conn.execute(
        "SELECT 1 FROM nodes WHERE language = ? LIMIT 1", (language,)
    ).fetchone();
    return row is not None;
}

impl GraphStore.commit {
    self._conn.commit();
    self._invalidate_cache();
}

impl GraphStore.rollback {
    self._conn.rollback();
    self._invalidate_cache();
}

impl GraphStore.get_node(qualified_name: str) -> Optional[GraphNode] {
    row: any = self._conn.execute(
        "SELECT * FROM nodes WHERE qualified_name = ?", (qualified_name,)
    ).fetchone();
    if row is None {
        bridged: any = _bridge_qualified_name(qualified_name);
        if bridged != qualified_name {
            row = self._conn.execute(
                "SELECT * FROM nodes WHERE qualified_name = ?", (bridged,)
            ).fetchone();
        }
    }
    return self._row_to_node(row) if row else None;
}

impl GraphStore.get_nodes_by_file(file_path: str) -> list[GraphNode] {
    return `list(self.iter_nodes_by_file(file_path));
}

impl GraphStore.iter_nodes_by_file(file_path: str) -> Generator[any, any, any] {
    rows: any = self._conn.execute(
        "SELECT * FROM nodes WHERE file_path = ?", (normalize_file_path(file_path),)
    );
    for row in rows {
        yield self._row_to_node(row);
    }
}

impl GraphStore.get_all_nodes(exclude_files: bool = True) -> list[GraphNode] {
    if exclude_files {
        rows: any = self._conn.execute("SELECT * FROM nodes WHERE kind != 'File'").fetchall();
    } else {
        rows = self._conn.execute("SELECT * FROM nodes").fetchall();
    }
    return [self._row_to_node(r) for r in rows];
}

impl GraphStore.get_edges_by_source(qualified_name: str) -> list[GraphEdge] {
    return `list(self.iter_edges_by_source(qualified_name));
}

impl GraphStore.iter_edges_by_source(qualified_name: str) -> Generator[any, any, any] {
    rows: any = self._conn.execute(
        "SELECT * FROM edges WHERE source_qualified = ? ORDER BY id", (qualified_name,)
    );
    for row in rows {
        yield self._row_to_edge(row);
    }
}

impl GraphStore.get_edges_by_target(qualified_name: str) -> list[GraphEdge] {
    return `list(self.iter_edges_by_target(qualified_name));
}

impl GraphStore.get_direct_dependent_files(file_path: str) -> set[str] {
    norm_fp: any = normalize_file_path(file_path);
    rows: any = self._conn.execute(
        "SELECT file_path FROM edges INDEXED BY idx_edges_target_kind WHERE target_qualified IN (?, ?) AND kind = 'IMPORTS_FROM' UNION SELECT e.file_path FROM nodes n JOIN edges e INDEXED BY idx_edges_target_kind ON e.target_qualified = n.qualified_name WHERE n.file_path = ? AND e.kind IN ('CALLS', 'IMPORTS_FROM', 'INHERITS', 'IMPLEMENTS')",
        (file_path, norm_fp, norm_fp),
    ).fetchall();
    dependents: any = {row[0] for row in rows};
    dependents.discard(file_path);
    dependents.discard(norm_fp);
    return dependents;
}

impl GraphStore.iter_edges_by_target(qualified_name: str) -> Generator[any, any, any] {
    rows: any = self._conn.execute(
        "SELECT * FROM edges WHERE target_qualified = ? ORDER BY id", (qualified_name,)
    );
    for row in rows {
        yield self._row_to_edge(row);
    }
}

impl GraphStore.get_config_consumers(key: str) -> list[GraphEdge] {
    parts: any = key.split(".");
    targets: any = [f"config:{key}", f"config:{key}.*"];
    targets.extend(f"config:{".".join(parts[:index])}.*" for index in range(1, len(parts)));
    rows: any = [];
    for target in dict.fromkeys(targets) {
        rows.extend(
            self._conn.execute(
                "SELECT * FROM edges WHERE kind = 'DEPENDS_ON_CONFIG' AND target_qualified = ? ORDER BY id",
                (target,),
            ).fetchall(),
        );
    }
    return [self._row_to_edge(row) for row in rows];
}

impl GraphStore.get_edges_claiming(qualified_name: str) -> list[GraphEdge] {
    rows: any = self._conn.execute(
        "SELECT * FROM edges WHERE extra LIKE ? AND json_valid(extra) AND json_extract(extra, ?) = ? ORDER BY id",
        (f"%\"{CLAIMED_ENDPOINT_KEY}\"%", f"$.{CLAIMED_ENDPOINT_KEY}", qualified_name),
    ).fetchall();
    return [self._row_to_edge(row) for row in rows];
}

impl GraphStore.search_edges_by_target_name(
    name: str, kind: str = "CALLS", language: str | None = None
) -> list[GraphEdge] {
    return `list(self.iter_edges_by_target_name(name, kind=kind, language=language));
}

impl GraphStore.iter_edges_by_target_name(
    name: str, kind: str = "CALLS", language: str | None = None
) -> Generator[any, any, any] {
    if language {
        languages: any = _compatible_edge_languages(language);
        placeholders: any = ", ".join("?" for _ in languages);
        rows: any = self._conn.execute(
            f"SELECT edges.* FROM edges JOIN nodes ON nodes.qualified_name = edges.source_qualified WHERE edges.target_qualified = ? AND edges.kind = ? AND nodes.language IN ({placeholders})",
            (name, kind, *languages),
        );
    } else {
        rows = self._conn.execute(
            "SELECT * FROM edges WHERE target_qualified = ? AND kind = ?", (name, kind)
        );
    }
    for row in rows {
        yield self._row_to_edge(row);
    }
}

impl GraphStore.get_transitive_tests(
    qualified_name: str,
    max_depth: int = 1,
    max_frontier: int | None = None,
    *,
    include_helper_routes: bool = True,
) -> list[dict] {
    candidate_cache: dict[str, list[tuple[str, str]]];
    import_cache: dict[str, set[str]];
    module_files: dict[str, str] | None;
    if max_frontier is None {
        max_frontier = env_int("CRG_MAX_TRANSITIVE_FRONTIER", 50);
    }
    conn: any = self._conn;
    seen: set[str] = set[any]();
    results: list[dict] = [];
    input_qns: any = [qualified_name];
    row: any = conn.execute(
        "SELECT kind, file_path, parent_name FROM nodes WHERE qualified_name = ?", (qualified_name,)
    ).fetchone();
    if row and row["kind"] == "Class" {
        for mrow in conn.execute(
            "SELECT target_qualified FROM edges WHERE source_qualified = ? AND kind = 'CONTAINS'",
            (qualified_name,),
        ).fetchall() {
            input_qns.append(mrow["target_qualified"]);
        }
    } elif row and row["kind"] == "File" {
        for symbol in conn.execute(
            "SELECT qualified_name FROM nodes WHERE file_path = ? AND qualified_name != ? AND kind IN ('Class', 'Function', 'Method')",
            (row["file_path"], qualified_name),
        ).fetchall() {
            input_qns.append(symbol["qualified_name"]);
        }
    }
    target_file: any = row["file_path"] if row else "";
    target_parent: any = row["parent_name"] if row else None;

    def _node_dict(qn: str, indirect: bool) -> dict | None {
        row: any = conn.execute("SELECT * FROM nodes WHERE qualified_name = ?", (qn,)).fetchone();
        if not row {
            return None;
        }
        return {
            "name": row["name"],
            "qualified_name": row["qualified_name"],
            "file_path": row["file_path"],
            "kind": row["kind"],
            "indirect": indirect,
        };
    }
    qn: any;
    for qn in input_qns {
        for row in conn.execute(
            "SELECT target_qualified, extra FROM edges WHERE source_qualified = ? AND kind = 'TESTED_BY'",
            (qn,),
        ).fetchall() {
            if _edge_extra_is_unresolved(row["extra"]) {
                continue;
            }
            tgt: any = row["target_qualified"];
            if tgt not in seen {
                seen.add(tgt);
                d: any = _node_dict(tgt, indirect=False);
                if d {
                    results.append(d);
                }
            }
        }
    }
    bare: any = qualified_name.rsplit("::", 1)[-1] if "::" in qualified_name else qualified_name;
    candidate_cache = {};
    import_cache = {};
    module_files = None;

    def _candidate_for_context(name: str, context_file: str) -> str | None {
        if name not in candidate_cache {
            candidate_cache[name] = [
                (candidate["qualified_name"], candidate["file_path"])
                for candidate in conn.execute(
                    "SELECT qualified_name, file_path FROM nodes WHERE name = ? AND kind IN ('Function', 'Test', 'Class')",
                    (name,),
                ).fetchall()
            ];
        }
        if context_file not in import_cache {
            if module_files is None {
                module_files = self._python_module_file_index(conn);
            }
            imported_files: set[str] = set[any]();
            for imported in conn.execute(
                "SELECT target_qualified FROM edges WHERE kind = 'IMPORTS_FROM' AND file_path = ?",
                (context_file,),
            ).fetchall() {
                target: any = imported["target_qualified"];
                target_file: any = target.split("::", 1)[0] if "::" in target else target;
                imported_files.add(target_file);
                resolved_module: any = module_files.get(target_file);
                if resolved_module {
                    imported_files.add(resolved_module);
                }
            }
            import_cache[context_file] = imported_files;
        }
        return self._select_evidence_backed_candidate(
            candidate_cache[name], context_file, import_cache[context_file]
        );
    }

    for row in conn.execute(
        "SELECT target_qualified, file_path, extra FROM edges WHERE source_qualified = ? AND kind = 'TESTED_BY'",
        (bare,),
    ).fetchall() {
        if _edge_extra_is_unresolved(row["extra"]) {
            continue;
        }
        if _candidate_for_context(bare, row["file_path"]) != qualified_name {
            continue;
        }
        try {
            tested_by_extra: any = json.loads(row["extra"] or "{}");
        } except (TypeError, json.JSONDecodeError) {
            tested_by_extra = {};
        }
        if isinstance(tested_by_extra, `dict)
            and not self._receiver_evidence_admits_candidate(
                tested_by_extra, qualified_name, target_file, target_parent
            )
        {
            continue;
        }
        tgt = row["target_qualified"];
        if tgt not in seen {
            seen.add(tgt);
            d = _node_dict(tgt, indirect=False);
            if d {
                results.append(d);
            }
        }
    }
    frontier: any = sorted(`set(input_qns));
    for _ in range(max_depth) {
        next_frontier: set[str] = set[any]();
        for qn in frontier {
            for row in conn.execute(
                "SELECT target_qualified, extra FROM edges WHERE source_qualified = ? AND kind = 'CALLS'",
                (qn,),
            ).fetchall() {
                if _edge_extra_is_unresolved(row["extra"]) {
                    continue;
                }
                next_frontier.add(row["target_qualified"]);
            }
        }
        bound_callees: any = self._existing_qualified_names(next_frontier);
        frontier = sorted(
            next_frontier, key=lambda (name) -> any { (name not in bound_callees, name) }
        )[:max_frontier];
        for callee in frontier {
            if callee not in bound_callees {
                continue;
            }
            for row in conn.execute(
                "SELECT target_qualified, extra FROM edges WHERE source_qualified = ? AND kind = 'TESTED_BY'",
                (callee,),
            ).fetchall() {
                if _edge_extra_is_unresolved(row["extra"]) {
                    continue;
                }
                tgt = row["target_qualified"];
                if tgt not in seen {
                    seen.add(tgt);
                    d = _node_dict(tgt, indirect=True);
                    if d {
                        results.append(d);
                    }
                }
            }
        }
    }

    if max_depth > 0 and include_helper_routes {
        for route in self._get_test_helper_routes(
            input_qns, max_depth + 1, max_frontier, self.get_repo_root()
        ).values() {
            for `test in route["tests"] {
                if `test not in seen {
                    seen.add(`test);
                    d = _node_dict(`test, indirect=True);
                    if d {
                        results.append(d);
                    }
                }
            }
        }
    }

    return results;
}

impl GraphStore.get_ambiguous_call_tests(qualified_name: str) -> list[str] {
    built_by_test: dict[str, set[tuple[str, int]]];
    conn: any = self._conn;
    built_by_test = {};

    def owner(method_qn: str) -> str {
        path: any;
        _: any;
        tail: any;
        (path, _, tail) = method_qn.rpartition("::") as any;
        return f"{path}::{tail.rpartition(".")[0]}";
    }

    def built(`test: str) -> set[tuple[str, int]] {
        if `test not in built_by_test {
            built_by_test[`test] = {
                (r["source_qualified"], r["line"])
                for r in conn.execute(
                    "SELECT e.source_qualified, e.line FROM edges e JOIN nodes n ON n.qualified_name = e.source_qualified WHERE e.kind = 'TESTED_BY' AND e.target_qualified = ? AND n.kind = 'Class'",
                    (`test,),
                ).fetchall()
            };
        }
        return built_by_test[`test];
    }

    row: any = conn.execute(
        "SELECT qualified_name, kind, name, file_path, language FROM nodes WHERE qualified_name = ?",
        (qualified_name,),
    ).fetchone();
    if not row or row["language"] != "php" {
        return [];
    }
    if row["kind"] == "Class" {
        symbol_rows: any = conn.execute(
            "SELECT n.qualified_name, n.name FROM edges e JOIN nodes n ON n.qualified_name = e.target_qualified WHERE e.source_qualified = ? AND e.kind = 'CONTAINS' AND n.kind = 'Function'",
            (qualified_name,),
        ).fetchall();
    } elif row["kind"] == "File" {
        symbol_rows = conn.execute(
            "SELECT qualified_name, name FROM nodes WHERE file_path = ? AND kind = 'Function'",
            (row["file_path"],),
        ).fetchall();
    } elif row["kind"] == "Function" {
        symbol_rows = [row];
    } else {
        return [];
    }

    tests: list[str] = [];
    for (symbol_qn, symbol_name) in ((r["qualified_name"], r["name"]) for r in symbol_rows) {
        edges: any = conn.execute(
            "SELECT target_qualified, line, extra FROM edges WHERE kind = 'TESTED_BY' AND source_qualified = ? AND instr(extra, ?) > 0",
            (symbol_name, json.dumps(symbol_qn)),
        ).fetchall();
        call_lines: dict[str, set[int]] = {};
        `edge: any;
        for `edge in edges {
            call_lines.setdefault(`edge["target_qualified"], set[any]()).add(`edge["line"]);
        }
        for `edge in edges {
            try {
                extra: any = json.loads(`edge["extra"] or "{}");
            } except (TypeError, json.JSONDecodeError) {
                continue;
            }
            candidates: any = extra.get("ambiguous_targets") if isinstance(extra, `dict) else None;
            `test: any = `edge["target_qualified"];
            if not isinstance(candidates, `list)
                or symbol_qn not in candidates
                or `test == symbol_qn
                or `test in tests
            {
                continue;
            }
            possible: any = {owner(c) for c in candidates if isinstance(c, `str)};
            made: any = built(`test);
            owners: any = {qn for (qn, at) in made if at == `edge["line"]} & possible;
            if not owners {
                owners = {qn for (qn, at) in made if at not in call_lines[`test]} & possible;
            }
            if owners and owner(symbol_qn) not in owners {
                continue;
            }
            tests.append(`test);
        }
    }
    return tests;
}

impl GraphStore._get_test_helper_routes(
    seeds: list[str], max_depth: int, max_callers: int, repo_root: str | None
) -> dict[str, dict[str, Any]] {
    origins: any;
    is_test_file = lazy("parser", "is_test_file");

    routes: dict[str, dict[str, Any]] = {};
    frontier: any = {qn: {qn} for qn in seeds if "::" in qn};
    expanded: any = {qn: `set(origins) for (qn, origins) in frontier.items()};
    for depth in range(1, max_depth + 1) {
        keys: any = sorted(frontier);
        if not keys {
            break;
        }
        hubs: set[str] = set[any]();
        start: any;
        for start in range(0, len(keys), 450) {
            batch: any = keys[start:start + 450];
            placeholders: any = ",".join("?" for _ in batch);
            row: any;
            for row in self._conn.execute(
                f"SELECT target_qualified, COUNT(*) AS n FROM edges WHERE kind = 'CALLS' AND target_qualified IN ({placeholders}) GROUP BY target_qualified",
                batch,
            ).fetchall() {
                if row["n"] > max_callers {
                    hubs.add(row["target_qualified"]);
                }
            }
        }
        keys = [key for key in keys if key not in hubs];
        next_frontier: dict[str, set[str]] = {};
        for start in range(0, len(keys), 450) {
            batch = keys[start:start + 450];
            placeholders = ",".join("?" for _ in batch);
            rows: any = self._conn.execute(
                f"SELECT e.source_qualified, e.target_qualified, e.extra, n.kind, n.file_path, n.is_test FROM edges e JOIN nodes n ON n.qualified_name = e.source_qualified WHERE e.kind = 'CALLS' AND e.target_qualified IN ({placeholders}) ORDER BY e.source_qualified, e.target_qualified",
                batch,
            ).fetchall();
            for row in rows {
                caller: any = row["source_qualified"];
                if "::" not in caller or _edge_extra_is_unresolved(row["extra"]) {
                    continue;
                }
                origins = frontier[row["target_qualified"]];
                fresh: any = origins - expanded.get(caller, set[any]()) - {caller};
                if row["kind"] == "Test" {
                    for origin in sorted(fresh) {
                        route: any = routes.setdefault(
                            origin, {"via": caller, "depth": depth, "tests": []}
                        );
                        if caller not in route["tests"] {
                            route["tests"].append(caller);
                        }
                    }
                } elif row["is_test"] or is_test_file(row["file_path"], repo_root) {
                    next_frontier.setdefault(caller, set[any]()).update(fresh);
                }
            }
        }
        for (caller, origins) in next_frontier.items() {
            expanded.setdefault(caller, set[any]()).update(origins);
        }
        frontier = next_frontier;
    }
    return routes;
}

impl GraphStore.get_directly_tested(qualified_names: Iterable[str]) -> set[str] {
    names: any = [qn for qn in dict.fromkeys(qualified_names) if qn];
    tested: set[str] = set[any]();
    for start in range(0, len(names), 450) {
        batch: any = names[start:start + 450];
        placeholders: any = ",".join("?" for _ in batch);
        rows: any = self._conn.execute(
            f"SELECT DISTINCT source_qualified FROM edges WHERE kind = 'TESTED_BY' AND source_qualified IN ({placeholders})",
            batch,
        ).fetchall();
        tested.update(row["source_qualified"] for row in rows);
    }
    return tested;
}

impl GraphStore.get_caller_test_routes(
    qualified_names: Iterable[str],
    max_depth: int = max_depth_default_,
    max_callers_per_node: int | None = None,
    repo_root: str | None = None,
) -> dict[str, dict[str, Any]] {
    origins: any;
    if max_callers_per_node is None {
        max_callers_per_node = CALLER_TEST_ROUTE_MAX_CALLERS;
    }
    if repo_root is None {
        repo_root = self.get_repo_root();
    }
    seeds: any = [qn for qn in dict.fromkeys(qualified_names) if qn];
    if not seeds or max_depth < 1 {
        return {};
    }
    routes: any = self._get_test_helper_routes(seeds, max_depth, max_callers_per_node, repo_root);
    for route in routes.values() {
        route["tests"] = route["tests"][:3];
    }
    frontier: dict[str, set[str]] = {qn: {qn} for qn in seeds if qn not in routes};
    expanded: dict[str, set[str]] = {qn: `set(origins) for (qn, origins) in frontier.items()};

    for depth in range(1, max_depth + 1) {
        callers: dict[str, set[str]] = {};
        keys: any = sorted(frontier);
        hubs: set[str] = set[any]();
        start: any;
        for start in range(0, len(keys), 450) {
            batch: any = keys[start:start + 450];
            placeholders: any = ",".join("?" for _ in batch);
            row: any;
            for row in self._conn.execute(
                f"SELECT target_qualified, COUNT(*) AS n FROM edges WHERE kind = 'CALLS' AND target_qualified IN ({placeholders}) GROUP BY target_qualified",
                batch,
            ).fetchall() {
                if row["n"] > max_callers_per_node {
                    hubs.add(row["target_qualified"]);
                }
            }
        }
        keys = [key for key in keys if key not in hubs];
        for start in range(0, len(keys), 450) {
            batch = keys[start:start + 450];
            placeholders = ",".join("?" for _ in batch);
            rows: any = self._conn.execute(
                f"SELECT source_qualified, target_qualified, extra FROM edges WHERE kind = 'CALLS' AND target_qualified IN ({placeholders})",
                batch,
            ).fetchall();
            for row in rows {
                if _edge_extra_is_unresolved(row["extra"]) {
                    continue;
                }
                caller: any = row["source_qualified"];
                if "::" not in caller {
                    continue;
                }
                origins = frontier.get(row["target_qualified"]);
                if not origins {
                    continue;
                }
                fresh: any = origins - expanded.get(caller, frozenset());
                fresh.discard(caller);
                if fresh {
                    callers.setdefault(caller, set[any]()).update(fresh);
                }
            }
        }
        if not callers {
            break;
        }
        is_test_file = lazy("parser", "is_test_file");

        caller_names: any = sorted(callers);
        for start in range(0, len(caller_names), 450) {
            batch = caller_names[start:start + 450];
            placeholders = ",".join("?" for _ in batch);
            for row in self._conn.execute(
                f"SELECT qualified_name, file_path, is_test FROM nodes WHERE qualified_name IN ({placeholders})",
                batch,
            ).fetchall() {
                if row["is_test"] or is_test_file(row["file_path"], repo_root) {
                    callers.pop(row["qualified_name"], None);
                }
            }
        }
        if not callers {
            break;
        }

        tests: dict[str, list[str]] = {};
        caller_names = sorted(callers);
        for start in range(0, len(caller_names), 450) {
            batch = caller_names[start:start + 450];
            placeholders = ",".join("?" for _ in batch);
            rows = self._conn.execute(
                f"SELECT source_qualified, target_qualified, extra FROM edges WHERE kind = 'TESTED_BY' AND source_qualified IN ({placeholders})",
                batch,
            ).fetchall();
            for row in rows {
                if _edge_extra_is_unresolved(row["extra"]) {
                    continue;
                }
                bucket: any = tests.setdefault(row["source_qualified"], []);
                if len(bucket) < 3 and row["target_qualified"] not in bucket {
                    bucket.append(row["target_qualified"]);
                }
            }
        }

        for caller in caller_names {
            covered: any = tests.get(caller);
            if not covered {
                continue;
            }
            for origin in callers[caller] {
                if origin not in routes {
                    routes[origin] = {"via": caller, "depth": depth, "tests": `list(covered)};
                }
            }
        }

        next_frontier: dict[str, set[str]] = {};
        for caller in caller_names {
            remaining: any = {o for o in callers[caller] if o not in routes};
            expanded.setdefault(caller, set[any]()).update(callers[caller]);
            if remaining {
                next_frontier[caller] = remaining;
            }
        }
        frontier = next_frontier;
        if not frontier {
            break;
        }
    }

    return routes;
}

impl GraphStore._python_module_file_index(conn: sqlite3.Connection) -> dict[str, str] {
    modules: dict[str, str | None] = {};
    for row in conn.execute(
        "SELECT DISTINCT file_path FROM nodes WHERE file_path LIKE '%.py'"
    ).fetchall() {
        file_path: any = row["file_path"];
        path: any = PurePosixPath(file_path).with_suffix("");
        segments: any = path.parts[1:] if path.is_absolute() else path.parts;
        if segments and segments[-1] == "__init__" {
            segments = segments[:-1];
        }
        for start in range(len(segments)) {
            module: any = ".".join(segments[start:]);
            if not module {
                continue;
            }
            if modules.setdefault(module, file_path) != file_path {
                modules[module] = None;
            }
        }
    }
    return {module: path for (module, path) in modules.items() if path is not None};
}

impl GraphStore._select_evidence_backed_candidate(
    candidates: list[tuple[str, str]], context_file: str, imported_files: set[str]
) -> str | None {
    supported: any = [
        qualified
        for (qualified, candidate_file) in candidates
        if candidate_file == context_file or candidate_file in imported_files
    ];
    return supported[0] if len(supported) == 1 else None;
}

impl GraphStore._receiver_backed_candidates(
    candidates: list[tuple[str, str]], edge_extra: dict, parent_lookup: dict[str, str | None]
) -> list[tuple[str, str]] {
    binding: any = edge_extra.get("receiver_binding");
    if binding == "module" {
        module_file: any = edge_extra.get("receiver_module");
        if not isinstance(module_file, `str) or not module_file {
            return [];
        }
        return [
            candidate
            for candidate in candidates
            if candidate[1] == module_file and parent_lookup.get(candidate[0]) is None
        ];
    }
    if binding == "class" {
        class_name: any = edge_extra.get("receiver_class");
        if not isinstance(class_name, `str) or not class_name {
            return [];
        }
        class_file: any = edge_extra.get("receiver_class_file");
        if class_file is not None and not isinstance(class_file, `str) {
            return [];
        }
        scopes: any = edge_extra.get("receiver_scopes");
        lookup: any = [
            *(f"{scope}.{class_name}"
            for scope in (scopes if isinstance(scopes, `list) else [])
            if isinstance(scope, `str) and scope),
            class_name,
        ];
        for path in lookup {
            matched: any = [
                candidate
                for candidate in candidates
                if parent_lookup.get(candidate[0]) == path
                    and (not class_file or candidate[1] == class_file)
            ];
            if matched {
                return matched;
            }
        }
        return [];
    }
    return [];
}

impl GraphStore._class_backed_candidates(
    edge_extra: dict,
    bare_name: str,
    caller_class: str,
    caller_language: str,
    context_file: str,
    inheritance: InheritanceIndex,
) -> Optional[tuple[list[str], Optional[str]]] {
    receiver: any = edge_extra.get("receiver");
    if edge_extra.get("receiver_resolution") == "typed_receiver_unresolved" {
        receiver_type: any = edge_extra.get("receiver_type");
        owner: Optional[str] = inheritance.resolve_type(
            receiver_type, context_file, caller_language
        )
            if isinstance(receiver_type, `str) and receiver_type
            else None;
        if owner is None {
            return ([], None);
        }
    } elif (receiver in _SELF_RECEIVERS or receiver in _SUPER_RECEIVERS)
        and "receiver_binding" not in edge_extra
    {
        if not caller_class {
            return None;
        }
        owner = caller_class;
    } elif caller_language == "java"
        and isinstance(receiver, `str)
        and receiver[:1].isupper()
        and "receiver_type" not in edge_extra
    {
        owner = inheritance.resolve_type(receiver, context_file, "java");
        if owner is None {
            return None;
        }
    } else {
        return None;
    }

    if receiver not in _SUPER_RECEIVERS {
        `own: any = inheritance.method_of(owner, bare_name);
        if `own is not None {
            return ([`own], None);
        }
    }
    inherited: any = inheritance.inherited_method(owner, bare_name);
    if inherited is not None {
        return ([inherited], owner);
    }
    if receiver in _SELF_RECEIVERS or receiver in _SUPER_RECEIVERS {
        return None;
    }
    return ([], None);
}

impl GraphStore._receiver_is_untyped(edge_extra: dict, caller_language: str) -> bool {
    receiver: any = edge_extra.get("receiver");
    return caller_language in _UNTYPED_RECEIVER_LANGUAGES
        and isinstance(receiver, `str)
        and `bool(receiver)
        and receiver not in _SELF_RECEIVERS
        and receiver not in _SUPER_RECEIVERS
        and "receiver_binding" not in edge_extra
        and "receiver_type" not in edge_extra;
}

impl GraphStore._own_method_excluded(
    edge_extra: dict,
    bare_name: str,
    caller_class: str,
    caller_language: str,
    inheritance: InheritanceIndex,
) -> Optional[str] {
    receiver: any = edge_extra.get("receiver");
    if not caller_class
        or not isinstance(receiver, `str)
        or receiver in _SELF_RECEIVERS
        or receiver in _SUPER_RECEIVERS
        or caller_language not in _TYPED_RECEIVER_LANGUAGES
        or "receiver_binding" in edge_extra
        or "receiver_type" in edge_extra
    {
        return None;
    }
    return inheritance.method_of(caller_class, bare_name);
}

impl GraphStore._receiver_evidence_admits_candidate(
    edge_extra: dict, qualified_name: str, file_path: str, parent_name: str | None
) -> bool {
    if "receiver_binding" not in edge_extra {
        owner: any = _claimed_owner(edge_extra);
        if owner is None
            and edge_extra.get("receiver_resolution") == "typed_receiver_unresolved"
            and isinstance(edge_extra.get("receiver_type"), `str)
        {
            owner = edge_extra["receiver_type"];
        }
        if owner is None {
            return True;
        }
        return _same_owner(parent_name, owner);
    }
    return `bool(
        cls._receiver_backed_candidates(
            [(qualified_name, file_path)], edge_extra, {qualified_name: parent_name or None}
        ),
    );
}

impl GraphStore.receiver_evidence_admits(edge_extra: dict, `node: GraphNode) -> bool {
    return cls._receiver_evidence_admits_candidate(
        edge_extra, `node.qualified_name, `node.file_path, `node.parent_name
    );
}

impl GraphStore.resolve_bare_call_targets -> int {
    self._drop_bare_endpoint_context();
    return self._resolve_bare_endpoints("CALLS", "target_qualified");
}

impl GraphStore.refresh_target_resolution -> int {
    self._resolve_inherited_endpoints();
    self._settle_unbound_endpoints();
    placeholders: any = ", ".join("?" for _ in TARGET_RESOLUTION_KINDS);
    call_tier: any = _certainty_tier_sql(f"target_resolution = '{RESOLUTION_UNRESOLVED}'");
    tested_by_tier: any = _certainty_tier_sql(
        "NOT EXISTS (SELECT 1 FROM nodes crg_cert_n WHERE crg_cert_n.qualified_name = edges.source_qualified)",
    );
    self._begin_immediate();
    try {
        cursor: any = self._conn.execute(
            f"UPDATE edges SET target_resolution = {TARGET_RESOLUTION_EXPR} WHERE kind IN ({placeholders}) AND target_resolution IS NOT ({TARGET_RESOLUTION_EXPR})",
            TARGET_RESOLUTION_KINDS,
        );
        self._conn.execute(
            f"UPDATE edges SET confidence_tier = {call_tier} WHERE kind IN ({placeholders}) AND confidence_tier IS NOT {call_tier}",
            TARGET_RESOLUTION_KINDS,
        );
        self._conn.execute(
            f"UPDATE edges SET confidence_tier = {tested_by_tier} WHERE kind = 'TESTED_BY' AND confidence_tier IS NOT {tested_by_tier}",
        );
        self._conn.execute(
            f"UPDATE edges SET confidence = {_CERTAINTY_SCORE_SQL} WHERE kind IN ({placeholders}, 'TESTED_BY') AND confidence IS NOT {_CERTAINTY_SCORE_SQL}",
            TARGET_RESOLUTION_KINDS,
        );
        self._conn.commit();
    } except BaseException {
        self._conn.rollback();
        raise;
    }
    self._settle_collision_endpoints();
    return cursor.rowcount if cursor.rowcount and cursor.rowcount > 0 else 0;
}

impl GraphStore._resolve_inherited_endpoints -> int {
    conn: any = self._conn;
    work: list[tuple[str, sqlite3.Row, dict, str, str, str]] = [];
    column: any;
    for (kind, column) in (("CALLS", "target_qualified"), ("TESTED_BY", "source_qualified")) {
        row: any;
        for row in conn.execute(
            f"SELECT e.id, e.{column} AS endpoint, e.extra FROM edges e WHERE e.kind = ? AND (e.extra LIKE ? OR e.extra LIKE ? OR (e.{column} LIKE '%::%' AND NOT EXISTS (SELECT 1 FROM nodes n WHERE n.qualified_name = e.{column})))",
            (kind, f"%\"{CLAIMED_ENDPOINT_KEY}\"%", f"%\"{INHERITED_ENDPOINT_KEY}\"%"),
        ).fetchall() {
            extra: any = _load_edge_extra(row["extra"]);
            managed: any = extra.get(INHERITED_ENDPOINT_KEY);
            claimed: any = extra.get(CLAIMED_ENDPOINT_KEY);
            if isinstance(managed, `str) {
                written: any = managed;
            } elif `any(key in extra for key in _RESOLVER_BOUND_KEYS)
                or ("ambiguous_targets" in extra or "unresolved_targets" in extra)
            {
                continue;
            } elif isinstance(claimed, `str) {
                written = claimed;
            } else {
                written = row["endpoint"];
            }
            if not _is_path_qualified(written) {
                continue;
            }
            file_part: any;
            _: any;
            symbol: any;
            (file_part, _, symbol) = written.partition("::") as any;
            class_part: any;
            dot: any;
            method: any;
            (class_part, dot, method) = symbol.rpartition(".") as any;
            if not dot or not class_part or not method {
                continue;
            }
            work.append((column, row, extra, written, f"{file_part}::{class_part}", method));
        }
    }
    if not work {
        return 0;
    }
    with_parents: any = {
        row[0]
        for row in conn.execute(
            "SELECT DISTINCT source_qualified FROM edges WHERE kind = 'INHERITS'"
        )
    };
    work = [item for item in work if item[4] in with_parents or INHERITED_ENDPOINT_KEY in item[2]];
    if not work {
        return 0;
    }
    import_targets: any;
    raw_imports: any;
    (import_targets, _, raw_imports) = self._import_evidence() as any;
    inheritance: any = InheritanceIndex(conn, import_targets, raw_imports);

    moves: dict[str, list[tuple[str, str, int]]] = {};
    reverts: dict[str, list[tuple[str, str, str, float, int]]] = {};
    owner: any;
    for item_ in work {
        (column, row, extra, written, owner, method) = item_;
        target: Optional[str] = None;
        if inheritance.is_class(owner) and inheritance.method_of(owner, method) is None {
            target = inheritance.inherited_method(owner, method);
        }
        if target is not None {
            desired: any = `dict(extra);
            desired[INHERITED_ENDPOINT_KEY] = written;
            desired.pop(CLAIMED_ENDPOINT_KEY, None);
            if row["endpoint"] != target or desired != extra {
                moves.setdefault(column, []).append((target, json.dumps(desired), row["id"]));
            }
        } elif INHERITED_ENDPOINT_KEY in extra {
            restored: any = `dict(extra);
            del restored[INHERITED_ENDPOINT_KEY];
            reverts.setdefault(column, []).append((
                written,
                json.dumps(restored),
                `str(restored.get("confidence_tier", TIER_EXTRACTED)),
                `float(restored.get("confidence", _SCORE_EXTRACTED)),
                row["id"],
            ));
        }
    }

    changed: any = sum(len(v) for v in moves.values()) + sum(len(v) for v in reverts.values());
    if not changed {
        return 0;
    }
    self._begin_immediate();
    try {
        for (column, updates) in moves.items() {
            move_sql: any = f"UPDATE edges SET {column} = ?, extra = ? WHERE id = ?";
            start: any;
            for start in range(0, len(updates), _UPDATE_BATCH) {
                conn.executemany(move_sql, updates[start:start + _UPDATE_BATCH]);
            }
        }
        for (column, restores) in reverts.items() {
            revert_sql: any = f"UPDATE edges SET {column} = ?, extra = ?, confidence_tier = ?, confidence = ? WHERE id = ?";
            for start in range(0, len(restores), _UPDATE_BATCH) {
                conn.executemany(revert_sql, restores[start:start + _UPDATE_BATCH]);
            }
        }
        conn.commit();
    } except BaseException {
        conn.rollback();
        raise;
    }
    return changed;
}

impl GraphStore._settle_unbound_endpoints -> int {
    conn: any = self._conn;
    changes: dict[str, list[tuple[str, str, int]]] = {};
    column: any;
    for (kind, column, managed_key) in _NODE_ENDPOINTS {
        updates: any = changes.setdefault(column, []);
        row: any;
        for row in conn.execute(
            f"SELECT e.id, e.{column} AS endpoint, e.extra FROM edges e WHERE e.kind = ? AND e.{column} LIKE '%::%' AND NOT EXISTS (SELECT 1 FROM nodes n WHERE n.qualified_name = e.{column})",
            (kind,),
        ).fetchall() {
            endpoint: any = row["endpoint"];
            if not _is_path_qualified(endpoint) {
                continue;
            }
            extra: any = _load_edge_extra(row["extra"]);
            managed: any = extra.get(managed_key);
            if isinstance(managed, `str) and managed {
                updates.append((managed, json.dumps(extra), row["id"]));
                continue;
            }
            plain: any = _plain_symbol_name(endpoint);
            if not plain {
                continue;
            }
            extra[CLAIMED_ENDPOINT_KEY] = endpoint;
            updates.append((plain, json.dumps(extra), row["id"]));
        }
        for row in conn.execute(
            f"SELECT e.id, e.{column} AS endpoint, e.extra FROM edges e WHERE e.kind = ? AND e.extra LIKE ?",
            (kind, f"%\"{CLAIMED_ENDPOINT_KEY}\"%"),
        ).fetchall() {
            extra = _load_edge_extra(row["extra"]);
            claimed: any = extra.get(CLAIMED_ENDPOINT_KEY);
            if not isinstance(claimed, `str) {
                continue;
            }
            if self._node_exists(claimed) {
                bound: any = claimed;
            } elif self._node_exists(row["endpoint"]) {
                bound = row["endpoint"];
            } else {
                continue;
            }
            del extra[CLAIMED_ENDPOINT_KEY];
            updates.append((bound, json.dumps(extra), row["id"]));
        }
    }

    changed: any = sum(len(updates) for updates in changes.values());
    if not changed {
        return 0;
    }
    self._begin_immediate();
    try {
        for (column, updates) in changes.items() {
            update_sql: any = f"UPDATE edges SET {column} = ?, extra = ? WHERE id = ?";
            for start in range(0, len(updates), _UPDATE_BATCH) {
                conn.executemany(update_sql, updates[start:start + _UPDATE_BATCH]);
            }
        }
        conn.commit();
    } except BaseException {
        conn.rollback();
        raise;
    }
    return changed;
}

impl GraphStore._existing_qualified_names(names: Iterable[str]) -> set[str] {
    wanted: any = sorted(`set(names));
    found: set[str] = set[any]();
    for start in range(0, len(wanted), 450) {
        batch: any = wanted[start:start + 450];
        placeholders: any = ",".join("?" for _ in batch);
        found.update(
            row[0]
            for row in self._conn.execute(
                f"SELECT qualified_name FROM nodes WHERE qualified_name IN ({placeholders})", batch
            ),
        );
    }
    return found;
}

impl GraphStore._node_exists(qualified_name: str) -> bool {
    return self._conn.execute(
        "SELECT 1 FROM nodes WHERE qualified_name = ? LIMIT 1", (qualified_name,)
    ).fetchone()
        is not None;
}

impl GraphStore.count_edges_by_resolution(kind: str = "CALLS") -> dict[str, int] {
    split: any = {"direct": 0, "unresolved": 0};
    unclassified: any = 0;
    resolution: any;
    count: any;
    for (resolution, count) in self._conn.execute(
        "SELECT target_resolution, COUNT(*) FROM edges WHERE kind = ? GROUP BY target_resolution",
        (kind,),
    ) {
        if resolution in split {
            split[resolution] = count;
        } elif resolution is None {
            unclassified = count;
        }
    }
    if unclassified {
        for (resolution, count) in self._conn.execute(
            f"SELECT {TARGET_RESOLUTION_EXPR} AS resolution, COUNT(*) FROM edges WHERE kind = ? AND target_resolution IS NULL GROUP BY resolution",
            (kind,),
        ) {
            if resolution in split {
                split[resolution] += count;
            }
        }
    }
    return split;
}

impl GraphStore.resolve_cpp_scoped_call_targets -> int {
    mirror_updates: list[tuple[str, str, int]];
    rows: any = self._conn.execute(
        "SELECT e.id, e.source_qualified, e.target_qualified, e.file_path, e.line, e.extra, s.parent_name, t.id target_id FROM edges e JOIN nodes s ON s.qualified_name = e.source_qualified LEFT JOIN nodes t ON t.qualified_name = e.target_qualified WHERE e.kind = 'CALLS' AND s.language = 'cpp' AND ((t.id IS NULL AND e.target_qualified LIKE '%::%') OR e.extra LIKE '%\"cpp_scoped_target\"%')",
    ).fetchall();
    if not rows {
        return 0;
    }

    candidates_by_name: dict[str, list[sqlite3.Row]] = {};
    for candidate in self._conn.execute(
        "SELECT name, qualified_name, parent_name FROM nodes WHERE language = 'cpp' AND kind IN ('Function', 'Test') ORDER BY qualified_name",
    ).fetchall() {
        candidates_by_name.setdefault(candidate["name"], []).append(candidate);
    }

    resolved: any = 0;
    call_updates: list[tuple[str, str, int]] = [];
    mirror_updates = [];
    def sync_tested_by(
        call_edge: sqlite3.Row,
        original_target: str,
        source_qualified: str,
        desired_extra: dict,
        serialized_extra: str,
    ) {
        mirrors: any = self._conn.execute(
            "SELECT id, source_qualified, extra FROM edges WHERE kind = 'TESTED_BY' AND target_qualified = ? AND file_path = ? AND line = ?",
            (call_edge["source_qualified"], call_edge["file_path"], call_edge["line"]),
        ).fetchall();
        for mirror in mirrors {
            try {
                mirror_extra: any = json.loads(mirror["extra"] or "{}");
            } except (TypeError, json.JSONDecodeError) {
                mirror_extra = {};
            }
            mirror_original: any = mirror_extra.get("cpp_scoped_target")
                if isinstance(mirror_extra, `dict)
                else None;
            if mirror["source_qualified"] not in (call_edge["target_qualified"], original_target)
                and mirror_original != original_target
            {
                continue;
            }
            if mirror["source_qualified"] == source_qualified and mirror_extra == desired_extra {
                continue;
            }
            mirror_updates.append((source_qualified, serialized_extra, mirror["id"]));
        }
    }

    for `edge in rows {
        try {
            extra: any = json.loads(`edge["extra"] or "{}");
        } except (TypeError, json.JSONDecodeError) {
            extra = {};
        }
        if not isinstance(extra, `dict) {
            extra = {};
        }
        previous_extra: any = `dict(extra);

        original_target: any = extra.get("cpp_scoped_target");
        target: any = original_target
            if isinstance(original_target, `str)
            else `edge["target_qualified"];
        global_scope: any = target.startswith("::");
        normalized: any = target.lstrip(":");
        if "::" not in normalized {
            continue;
        }
        explicit_scope: any;
        bare_name: any;
        (explicit_scope, bare_name) = normalized.rsplit("::", 1) as any;
        explicit_scope = explicit_scope.replace("::", ".");

        preferred_scopes: list[str] = [];
        source_scope: any = `edge["parent_name"];
        if not global_scope {
            while source_scope {
                preferred_scopes.append(f"{source_scope}.{explicit_scope}");
                source_scope = source_scope.rsplit(".", 1)[0] if "." in source_scope else None;
            }
        }
        preferred_scopes.append(explicit_scope);

        candidates: list[str] = [];
        for preferred_scope in preferred_scopes {
            candidates = [
                candidate["qualified_name"]
                for candidate in candidates_by_name.get(bare_name, [])
                if candidate["parent_name"] == preferred_scope
            ];
            if candidates {
                break;
            }
        }

        if len(candidates) == 1 {
            extra["cpp_scoped_target"] = target;
            key: any;
            for key in (
                "ambiguous_targets",
                "ambiguous_target_count",
                "ambiguous_targets_truncated",
                "unresolved_targets",
                "unresolved_target_count",
                "unresolved_targets_truncated",
            ) {
                extra.pop(key, None);
            }
            serialized_extra: any = json.dumps(extra, sort_keys=True);
            if `edge["target_qualified"] != candidates[0] or previous_extra != extra {
                call_updates.append((candidates[0], serialized_extra, `edge["id"]));
                resolved += 1;
            }
            sync_tested_by(`edge, target, candidates[0], extra, serialized_extra);
        } elif len(candidates) > 1 {
            for key in (
                "unresolved_targets",
                "unresolved_target_count",
                "unresolved_targets_truncated",
            ) {
                extra.pop(key, None);
            }
            candidates = sorted(candidates);
            extra.update({
                "cpp_scoped_target": target,
                "ambiguous_targets": candidates[:20],
                "ambiguous_target_count": len(candidates),
                "ambiguous_targets_truncated": operator.gt(len(candidates), 20),
            });
            serialized_extra = json.dumps(extra, sort_keys=True);
            if `edge["target_qualified"] != target or previous_extra != extra {
                call_updates.append((target, serialized_extra, `edge["id"]));
            }
            sync_tested_by(`edge, target, target, extra, serialized_extra);
        } else {
            extra["cpp_scoped_target"] = target;
            for key in (
                "ambiguous_targets",
                "ambiguous_target_count",
                "ambiguous_targets_truncated",
            ) {
                extra.pop(key, None);
            }
            extra.update({
                "unresolved_targets": [],
                "unresolved_target_count": 0,
                "unresolved_targets_truncated": False,
            });
            serialized_extra = json.dumps(extra, sort_keys=True);
            if `edge["target_qualified"] != target or previous_extra != extra {
                call_updates.append((target, serialized_extra, `edge["id"]));
            }
            sync_tested_by(`edge, target, target, extra, serialized_extra);
        }
    }

    if call_updates or mirror_updates {
        self._begin_immediate();
        try {
            call_sql: any = "UPDATE edges SET target_qualified = ?, extra = ? WHERE id = ?";
            start: any;
            for start in range(0, len(call_updates), _UPDATE_BATCH) {
                self._conn.executemany(call_sql, call_updates[start:start + _UPDATE_BATCH]);
            }
            mirror_sql: any = "UPDATE edges SET source_qualified = ?, extra = ? WHERE id = ?";
            for start in range(0, len(mirror_updates), _UPDATE_BATCH) {
                self._conn.executemany(mirror_sql, mirror_updates[start:start + _UPDATE_BATCH]);
            }
            self._conn.commit();
        } except BaseException {
            self._conn.rollback();
            raise;
        }
    }
    return resolved;
}

impl GraphStore.resolve_bare_tested_by_sources -> int {
    try {
        return self._resolve_bare_endpoints("TESTED_BY", "source_qualified");
    } finally {
        self._drop_bare_endpoint_context();
    }
}

impl GraphStore._drop_bare_endpoint_context {
    with self._cache_lock {
        self._cache_epoch += 1;
        self._bare_endpoint_context_cache = None;
    }
}

impl GraphStore._directory_member_files(
    conn: sqlite3.Connection, scoped_dirs: dict[str, str]
) -> dict[str, set[str]] {
    members: dict[str, set[str]] = {};
    for row in conn.execute("SELECT file_path FROM nodes WHERE kind = 'File'") {
        file_path: any = row["file_path"];
        for (directory, scopes) in import_scope_ancestors(file_path) {
            if scoped_dirs.get(directory) in scopes {
                members.setdefault(directory, set[any]()).add(file_path);
            }
        }
    }
    return members;
}

impl GraphStore._import_evidence -> tuple[dict[str, set[str]], dict[str, set[str]], dict[str, dict[str, str]]] {
    conn: any = self._conn;
    import_targets: dict[str, set[str]] = {};
    ambiguous_import_targets: dict[str, set[str]] = {};
    scoped_dirs: dict[str, str] = {};
    raw_imports: dict[str, dict[str, str]] = {};
    row: any;
    for row in conn.execute(
        "SELECT DISTINCT file_path, target_qualified, extra FROM edges WHERE kind = 'IMPORTS_FROM'"
    ).fetchall() {
        target: any = row["target_qualified"];
        target_file: any = target.split("::", 1)[0] if "::" in target else target;
        import_targets.setdefault(row["file_path"], set[any]()).add(target_file);
        if not (
            PurePosixPath(target_file).is_absolute() or PureWindowsPath(target_file).is_absolute()
        ) {
            short: any = target_file.rpartition("\\")[2].rpartition(".")[2];
            if short {
                raw_imports.setdefault(row["file_path"], {})[short] = target_file;
            }
        }
        raw_extra: any = row["extra"];
        if not raw_extra or raw_extra == "{}" {
            continue;
        }
        scope: any = _edge_import_scope(raw_extra);
        if scope is not None {
            scoped_dirs[target] = scope;
        }
        if "ambiguous" in raw_extra {
            try {
                import_extra: any = json.loads(raw_extra);
            } except (TypeError, json.JSONDecodeError) {
                import_extra = {};
            }
            if isinstance(import_extra, `dict)
                and import_extra.get("import_resolution") == "ambiguous"
                and isinstance(import_extra.get("import_candidates"), `list)
            {
                ambiguous_import_targets.setdefault(row["file_path"], set[any]()).update(
                    candidate
                    for candidate in import_extra["import_candidates"]
                    if isinstance(candidate, `str),
                );
            }
        }
    }
    namespace_files: dict[str, set[str]] = {};
    for row in conn.execute(
        "SELECT file_path, extra FROM nodes WHERE kind = 'File' AND extra LIKE '%\"csharp_namespaces\"%'",
    ).fetchall() {
        try {
            node_extra: any = json.loads(row["extra"] or "{}");
        } except (TypeError, json.JSONDecodeError) {
            continue;
        }
        if not isinstance(node_extra, `dict) {
            continue;
        }
        declared: any = node_extra.get("csharp_namespaces");
        if not isinstance(declared, `list) {
            continue;
        }
        for ns in declared {
            if isinstance(ns, `str) and ns {
                namespace_files.setdefault(ns, set[any]()).add(row["file_path"]);
            }
        }
    }
    if namespace_files {
        imported: any;
        for imported in import_targets.values() {
            expanded: set[str] = set[any]();
            for target in imported {
                expanded |= namespace_files.get(target, set[any]());
            }
            imported |= expanded;
        }
    }

    if scoped_dirs {
        members: any = self._directory_member_files(conn, scoped_dirs);
        for imported in import_targets.values() {
            grown: set[str] = set[any]();
            for target in imported {
                grown |= members.get(target, set[any]());
            }
            imported |= grown;
        }
    }
    module_files: any = self._python_module_file_index(conn);
    if module_files {
        for imported in import_targets.values() {
            expanded = set[any]();
            for target in imported {
                resolved_file: any = module_files.get(target);
                if resolved_file {
                    expanded.add(resolved_file);
                }
            }
            imported |= expanded;
        }
    }

    return (import_targets, ambiguous_import_targets, raw_imports);
}

impl GraphStore._get_bare_endpoint_context(
    conn: sqlite3.Connection
) -> tuple[dict[str, list[tuple[str, str]]], dict[str, str
    | None], dict[str, set[str]], dict[str, set[str]], set[str], dict[str, str], dict[str, dict[str, str]]] {
    cached: any = getattr(self, "_bare_endpoint_context_cache", None);
    if cached is not None {
        return cached;
    }
    epoch: any = self._cache_epoch;
    node_lookup: dict[str, list[tuple[str, str]]] = {};
    parent_lookup: dict[str, str | None] = {};
    ruby_nodes: set[str] = set[any]();
    language_lookup: dict[str, str] = {};
    for row in conn.execute(
        "SELECT name, qualified_name, file_path, parent_name, kind, language FROM nodes WHERE kind IN ('Function', 'Test', 'Class')",
    ).fetchall() {
        node_lookup.setdefault(row["name"], []).append((row["qualified_name"], row["file_path"]));
        parent_lookup[row["qualified_name"]] = row["parent_name"];
        if row["language"] == "ruby" {
            ruby_nodes.add(row["qualified_name"]);
        }
        if row["kind"] != "Class" {
            language_lookup[row["qualified_name"]] = row["language"] or "";
        }
    }

    import_targets: any;
    ambiguous_import_targets: any;
    raw_imports: any;
    (import_targets, ambiguous_import_targets, raw_imports) = self._import_evidence() as any;
    result: any = (
        node_lookup,
        parent_lookup,
        import_targets,
        ambiguous_import_targets,
        ruby_nodes,
        language_lookup,
        raw_imports,
    );
    with self._cache_lock {
        if self._cache_epoch == epoch {
            self._bare_endpoint_context_cache = result;
        }
    }
    return result;
}

impl GraphStore._resolve_bare_endpoints(kind: str, endpoint: str) -> int {
    if endpoint == "target_qualified" {
        raw_key: any = "bare_call_target";
        endpoint_column: any = "target_qualified";
        bare_condition: any = "target_qualified NOT LIKE '%::%' OR extra LIKE '%\"bare_call_target\"%'";
        select_sql: any = "SELECT id, source_qualified, target_qualified, file_path, extra FROM edges WHERE kind = ? AND ("
            + bare_condition
            + ")";
    } elif endpoint == "source_qualified" {
        raw_key = "bare_tested_by_source";
        endpoint_column = "source_qualified";
        bare_condition = "source_qualified NOT LIKE '%::%' OR extra LIKE '%\"bare_tested_by_source\"%'";
        select_sql = "SELECT id, source_qualified, target_qualified, file_path, extra FROM edges WHERE kind = ? AND ("
            + bare_condition
            + ")";
    } else {
        raise ValueError(f"Invalid edge endpoint column: {endpoint!r}");
    }

    conn: any = self._conn;
    has_bare: any = conn.execute(
        "SELECT EXISTS(SELECT 1 FROM edges WHERE kind = ? AND (" + bare_condition + "))", (kind,)
    ).fetchone()[0];
    if not has_bare {
        return 0;
    }

    node_lookup: any;
    parent_lookup: any;
    import_targets: any;
    ambiguous_import_targets: any;
    ruby_nodes: any;
    language_lookup: any;
    raw_imports: any;
    (
        node_lookup,
        parent_lookup,
        import_targets,
        ambiguous_import_targets,
        ruby_nodes,
        language_lookup,
        raw_imports,
    ) = self._get_bare_endpoint_context(conn) as any;
    bare_edges: any = conn.execute(select_sql, (kind,));
    inheritance: any = InheritanceIndex(conn, import_targets, raw_imports);
    caller_column: any = "source_qualified"
        if endpoint == "target_qualified"
        else "target_qualified";

    resolved: any = 0;
    updates: list[tuple[str, str, int]] = [];
    for `edge in bare_edges {
        raw_extra: any = `edge["extra"];
        if not raw_extra or raw_extra == "{}" {
            bare_name: any = `edge[endpoint];
            if not isinstance(bare_name, `str) {
                continue;
            }
            candidates: any = node_lookup.get(bare_name);
            if not candidates {
                continue;
            }
            edge_extra: any = {};
            receiver_constant: any = False;
        } else {
            try {
                edge_extra = json.loads(raw_extra);
            } except (TypeError, json.JSONDecodeError) {
                edge_extra = {};
            }
            if not isinstance(edge_extra, `dict) {
                edge_extra = {};
            }
            if raw_key not in edge_extra
                and (
                    "ambiguous_targets" in edge_extra
                    or "unresolved_targets" in edge_extra
                    or CLAIMED_ENDPOINT_KEY in edge_extra
                )
            {
                continue;
            }
            if INHERITED_ENDPOINT_KEY in edge_extra {
                continue;
            }
            bare_name = edge_extra.get(raw_key, `edge[endpoint]);
            if not isinstance(bare_name, `str) {
                continue;
            }
            receiver_constant = edge_extra.get("receiver_constant") is True;
            lookup_name: any = "initialize"
                if receiver_constant and bare_name == "new"
                else bare_name;
            candidates = node_lookup.get(lookup_name, []);
            if receiver_constant {
                candidates = [candidate for candidate in candidates if candidate[0] in ruby_nodes];
            }
            if "receiver_binding" in edge_extra {
                candidates = self._receiver_backed_candidates(
                    candidates, edge_extra, parent_lookup
                );
            }
        }

        context_file: any = `edge["file_path"];
        caller: any = `edge[caller_column];
        caller_language: any = language_lookup.get(caller, "");
        caller_class: any = caller.rpartition(".")[0] if parent_lookup.get(caller) else "";
        if not inheritance.is_class(caller_class) {
            caller_class = "";
        }
        class_backed: any = self._class_backed_candidates(
            edge_extra, bare_name, caller_class, caller_language, context_file, inheritance
        );
        if class_backed is not None {
            supported: any;
            inherited_through: any;
            (supported, inherited_through) = class_backed as any;
            candidates = [(qualified, "") for qualified in supported];
            ambiguity_supported: list[str] = [];
        } else {
            inherited_through = None;
            imported_files: any = import_targets.get(context_file, set[any]());
            receiver_file: any = edge_extra.get("receiver_module")
                if edge_extra.get("receiver_binding") == "module"
                else None;
            receiver_class_file: any = edge_extra.get("receiver_class_file");
            java_package: any = inheritance.java_package(context_file)
                if caller_language == "java"
                else None;
            supported = [
                qualified
                for (qualified, candidate_file) in candidates
                if candidate_file == context_file
                    or candidate_file in imported_files
                    or candidate_file == receiver_file
                    or candidate_file == receiver_class_file
                    or java_package is not None
                        and inheritance.is_class(qualified)
                        and inheritance.java_package(candidate_file) == java_package
                    or receiver_constant
            ];
            if self._receiver_is_untyped(edge_extra, caller_language) {
                supported = [
                    qualified
                    for qualified in supported
                    if not parent_lookup.get(qualified)
                ];
            }
            own_method: any = self._own_method_excluded(
                edge_extra, bare_name, caller_class, caller_language, inheritance
            );
            if own_method is not None and supported == [own_method] {
                supported = [];
            }
            ambiguous_files: any = ambiguous_import_targets.get(context_file, set[any]());
            ambiguity_supported = [
                qualified
                for (qualified, candidate_file) in candidates
                if candidate_file in ambiguous_files
            ];
        }
        managed: any = raw_key in edge_extra;
        if len(supported) != 1 and not managed and len(supported) < 2 and not ambiguity_supported {
            continue;
        }
        desired_extra: any = `dict(edge_extra);
        desired_extra[raw_key] = bare_name;
        if inherited_through and len(supported) == 1 {
            desired_extra[INHERITED_THROUGH_KEY] = inherited_through;
        } else {
            desired_extra.pop(INHERITED_THROUGH_KEY, None);
        }
        if len(supported) == 1 {
            desired_endpoint: any = supported[0];
            key: any;
            for key in (
                "ambiguous_targets",
                "ambiguous_target_count",
                "ambiguous_targets_truncated",
                "unresolved_targets",
                "unresolved_target_count",
                "unresolved_targets_truncated",
            ) {
                desired_extra.pop(key, None);
            }
        } else {
            desired_endpoint = bare_name;
            if len(supported) > 1 {
                resolution: any = "ambiguous";
                resolution_candidates: any = supported;
                other: any = "unresolved";
            } elif ambiguity_supported {
                resolution = "ambiguous" if len(ambiguity_supported) > 1 else "unresolved";
                resolution_candidates = ambiguity_supported;
                other = "unresolved" if resolution == "ambiguous" else "ambiguous";
            } else {
                resolution = "unresolved";
                resolution_candidates = [qualified for (qualified, _) in candidates];
                other = "ambiguous";
            }
            for key in (f"{other}_targets", f"{other}_target_count", f"{other}_targets_truncated") {
                desired_extra.pop(key, None);
            }
            resolution_candidates = sorted(resolution_candidates);
            desired_extra.update({
                f"{resolution}_targets": resolution_candidates[:20],
                f"{resolution}_target_count": len(resolution_candidates),
                f"{resolution}_targets_truncated": operator.gt(len(resolution_candidates), 20),
            });
        }

        if `edge[endpoint] == desired_endpoint and edge_extra == desired_extra {
            continue;
        }
        serialized_extra: any = json.dumps(desired_extra, sort_keys=True);
        updates.append((desired_endpoint, serialized_extra, `edge["id"]));
        if len(supported) == 1 and `edge[endpoint] != desired_endpoint {
            resolved += 1;
        }
    }

    bare_edges.close();

    if updates {
        self._begin_immediate();
        try {
            update_sql: any = f"UPDATE edges SET {endpoint_column} = ?, extra = ? WHERE id = ?";
            for start in range(0, len(updates), _UPDATE_BATCH) {
                conn.executemany(update_sql, updates[start:start + _UPDATE_BATCH]);
            }
            conn.commit();
        } except BaseException {
            conn.rollback();
            raise;
        }
    }
    if resolved {
        endpoint_label: any = "sources" if endpoint == "source_qualified" else "targets";
        logger.info("Resolved %d evidence-backed bare %s %s", resolved, kind, endpoint_label);
    }
    return resolved;
}

impl GraphStore.get_all_files -> list[str] {
    rows: any = self._conn.execute(
        "SELECT file_path FROM nodes WHERE extra IS NULL OR json_valid(extra) = 0 OR COALESCE(json_extract(extra, '$.virtual'), 0) != 1 UNION SELECT file_path FROM edges ORDER BY file_path",
    ).fetchall();
    return [r["file_path"] for r in rows];
}

impl GraphStore.get_file_hashes -> dict[str, str] {
    rows: any = self._conn.execute(
        "SELECT file_path, file_hash FROM nodes WHERE kind = 'File'"
    ).fetchall();
    return {normalize_file_path(row["file_path"]): row["file_hash"] or "" for row in rows};
}

impl GraphStore.get_file_marker_paths -> list[str] {
    rows: any = self._conn.execute(
        "SELECT file_path FROM nodes WHERE kind = 'File' ORDER BY file_path"
    ).fetchall();
    return [row["file_path"] for row in rows];
}

impl GraphStore.search_nodes_by_qualified_tail(tail: str, limit: int = 20) -> list[GraphNode] {
    rows: any = self._conn.execute(
        "SELECT * FROM nodes WHERE symbol = ? OR qualified_name = ? LIMIT ?", (tail, tail, limit)
    ).fetchall();
    return [self._row_to_node(row) for row in rows];
}

impl GraphStore.count_nodes_by_qualified_tail(tail: str) -> int {
    row: any = self._conn.execute(
        "SELECT COUNT(*) AS count FROM nodes WHERE symbol = ? OR qualified_name = ?", (tail, tail)
    ).fetchone();
    return `int(row["count"]);
}

impl GraphStore.search_nodes(query: str, limit: int = 20) -> list[GraphNode] {
    w: any;
    words: any = query.split();
    if not words {
        return [];
    }
    try {
        if len(words) == 1 {
            fts_query: any = "\"" + query.replace("\"", "\"\"") + "\"";
        } else {
            fts_query = " AND ".join("\"" + w.replace("\"", "\"\"") + "\"" for w in words);
        }
        rows: any = self._conn.execute(
            "SELECT n.* FROM nodes_fts f JOIN nodes n ON f.rowid = n.id WHERE nodes_fts MATCH ? AND n.kind != 'Output' LIMIT ?",
            (fts_query, limit),
        ).fetchall();
        if rows {
            return [self._row_to_node(r) for r in rows];
        }
    } except Exception {}
    conditions: list[str] = [];
    params: list[str | int] = [];
    for word in words {
        w = word.lower();
        conditions.append("(LOWER(name) LIKE ? OR LOWER(qualified_name) LIKE ?)");
        params.extend([f"%{w}%", f"%{w}%"]);
    }

    where: any = " AND ".join(conditions);
    sql: any = f"SELECT * FROM nodes WHERE {where} AND kind != 'Output' LIMIT ?";
    params.append(limit);
    rows = self._conn.execute(sql, params).fetchall();
    return [self._row_to_node(r) for r in rows];
}

impl GraphStore.count_search_nodes(query: str) -> int {
    word: any;
    words: any = query.split();
    if not words {
        return 0;
    }

    try {
        if len(words) == 1 {
            fts_query: any = "\"" + query.replace("\"", "\"\"") + "\"";
        } else {
            fts_query = " AND ".join("\"" + word.replace("\"", "\"\"") + "\"" for word in words);
        }
        count: any = self._conn.execute(
            "SELECT COUNT(*) FROM nodes_fts f JOIN nodes n ON f.rowid = n.id WHERE nodes_fts MATCH ? AND n.kind != 'Output'",
            (fts_query,),
        ).fetchone()[0];
        if count {
            return `int(count);
        }
    } except Exception {}

    conditions: list[str] = [];
    params: list[str] = [];
    for word in words {
        value: any = word.lower();
        conditions.append("(LOWER(name) LIKE ? OR LOWER(qualified_name) LIKE ?)");
        params.extend([f"%{value}%", f"%{value}%"]);
    }
    where: any = " AND ".join(conditions);
    sql: any = f"SELECT COUNT(*) FROM nodes WHERE {where} AND kind != 'Output'";
    return `int(self._conn.execute(sql, params).fetchone()[0]);
}

impl GraphStore.count_nodes_by_name(
    name: str, language: str | None = None, kinds: tuple[str, ...] = ()
) -> int {
    conditions: any = ["name = ?"];
    params: list[Any] = [name];
    if language is not None {
        conditions.append("language = ?");
        params.append(language);
    }
    if kinds {
        placeholders: any = ", ".join("?" for _ in kinds);
        conditions.append(f"kind IN ({placeholders})");
        params.extend(kinds);
    }
    where: any = " AND ".join(conditions);
    sql: any = f"SELECT COUNT(*) FROM nodes WHERE {where}";
    return `int(self._conn.execute(sql, params).fetchone()[0]);
}

impl GraphStore.get_nodes_by_name(name: str) -> list[GraphNode] {
    rows: any = self._conn.execute(
        "SELECT * FROM nodes WHERE name = ? ORDER BY qualified_name", (name,)
    ).fetchall();
    return [self._row_to_node(r) for r in rows];
}

impl GraphStore._impact_seed_qns(changed_files: list[str]) -> set[str] {
    seeds: set[str] = set[any]();
    files: list[str] = [];
    for f in changed_files {
        for n in self.get_nodes_by_file(f) {
            seeds.add(n.qualified_name);
            if n.kind == "File" {
                files.append(n.file_path);
                if n.language == "csharp" {
                    for ns in n.extra.get("csharp_namespaces") or [] {
                        if isinstance(ns, `str) and ns {
                            seeds.add(ns);
                        }
                    }
                }
            }
        }
    }
    seeds.update(self.tree_scope_bridges(files));
    return seeds;
}

impl GraphStore.tree_scope_bridges(file_paths: Iterable[str]) -> set[str] {
    wanted: dict[str, str] = {};
    for file_path in file_paths {
        for (directory, scopes) in import_scope_ancestors(file_path)[1:] {
            if IMPORT_SCOPE_TREE in scopes {
                wanted[directory] = IMPORT_SCOPE_TREE;
            }
        }
    }
    if not wanted {
        return set[any]();
    }
    found: set[str] = set[any]();
    directories: any = `list(wanted);
    for start in range(0, len(directories), 450) {
        batch: any = directories[start:start + 450];
        placeholders: any = ",".join("?" for _ in batch);
        rows: any = self._conn.execute(
            f"SELECT DISTINCT target_qualified, extra FROM edges WHERE kind = 'IMPORTS_FROM' AND target_qualified IN ({placeholders})",
            batch,
        ).fetchall();
        for row in rows {
            if _edge_import_scope(row["extra"]) == IMPORT_SCOPE_TREE {
                found.add(row["target_qualified"]);
            }
        }
    }
    return found;
}

impl GraphStore.import_scope_edges(
    file_paths: Iterable[str], source_qns: set[str]
) -> list[GraphEdge] {
    wanted: dict[str, tuple[str, ...]] = {};
    for file_path in file_paths {
        for (directory, scopes) in import_scope_ancestors(file_path) {
            wanted[directory] = `tuple(sorted(`set(wanted.get(directory, ())) | `set(scopes)));
        }
    }
    if not wanted or not source_qns {
        return [];
    }
    out: list[GraphEdge] = [];
    directories: any = `list(wanted);
    for start in range(0, len(directories), 450) {
        batch: any = directories[start:start + 450];
        placeholders: any = ",".join("?" for _ in batch);
        rows: any = self._conn.execute(
            f"SELECT * FROM edges WHERE kind = 'IMPORTS_FROM' AND target_qualified IN ({placeholders})",
            batch,
        ).fetchall();
        for row in rows {
            `edge: any = self._row_to_edge(row);
            if `edge.source_qualified not in source_qns {
                continue;
            }
            scope: any = `edge.extra.get(IMPORT_SCOPE_KEY);
            if scope in wanted.get(`edge.target_qualified, ()) {
                out.append(`edge);
            }
        }
    }
    return out;
}

impl GraphStore._import_scope_importer_index -> dict[str, list[str]] {
    index: dict[str, list[str]] = {};
    rows: any = self._conn.execute(
        "SELECT source_qualified, target_qualified, extra FROM edges WHERE kind = 'IMPORTS_FROM' AND extra LIKE ?",
        (f"%{IMPORT_SCOPE_KEY}%",),
    ).fetchall();
    for row in rows {
        if _edge_import_scope(row["extra"]) is None {
            continue;
        }
        index.setdefault(row["target_qualified"], []).append(row["source_qualified"]);
    }
    return index;
}

impl GraphStore._file_node_directories -> dict[str, str] {
    out: dict[str, str] = {};
    for row in self._conn.execute(
        "SELECT qualified_name, file_path FROM nodes WHERE kind = 'File'"
    ) {
        directory: any = _parent_dir(row["file_path"]);
        if directory {
            out[row["qualified_name"]] = directory;
        }
    }
    return out;
}

impl GraphStore.count_unresolved_call_sites(names: set[str]) -> int {
    if not names {
        return 0;
    }
    self._conn.execute(
        "CREATE TEMP TABLE IF NOT EXISTS _impact_seed_names (name TEXT PRIMARY KEY)"
    );
    self._conn.execute("DELETE FROM _impact_seed_names");
    name_list: any = `list(names);
    for start in range(0, len(name_list), 450) {
        batch: any = name_list[start:start + 450];
        placeholders: any = ",".join("(?)" for _ in batch);
        self._conn.execute(
            f"INSERT OR IGNORE INTO _impact_seed_names (name) VALUES {placeholders}", batch
        );
    }
    try {
        row: any = self._conn.execute(
            f"SELECT COUNT(*) FROM edges JOIN _impact_seed_names s ON s.name = edges.target_qualified WHERE edges.kind IN ('CALLS', 'REFERENCES') AND COALESCE(edges.target_resolution, {TARGET_RESOLUTION_EXPR}) = 'unresolved'",
        ).fetchone();
        return `int(row[0]) if row else 0;
    } finally {
        try {
            self._conn.execute("DELETE FROM _impact_seed_names");
        } except sqlite3.Error {}
    }
}

impl GraphStore.get_impact_radius(
    changed_files: list[str],
    max_depth: int = max_depth_default__,
    max_nodes: int = max_nodes_default_,
    resolution: str = "all",
) -> dict[str, Any] {
    if BFS_ENGINE == "networkx" {
        return self._get_impact_radius_networkx(
            changed_files, max_depth=max_depth, max_nodes=max_nodes, resolution=resolution
        );
    }
    return self.get_impact_radius_sql(
        changed_files, max_depth=max_depth, max_nodes=max_nodes, resolution=resolution
    );
}

impl GraphStore.get_impact_radius_sql(
    changed_files: list[str],
    max_depth: int = max_depth_default___,
    max_nodes: int = max_nodes_default__,
    resolution: str = "all",
) -> dict[str, Any] {
    resolution_guard: any = _impact_resolution_guard(resolution);
    max_depth = max(0, `int(max_depth));
    max_nodes = max(0, `int(max_nodes));
    if not changed_files {
        return {
            "changed_nodes": [],
            "impacted_nodes": [],
            "impacted_files": [],
            "edges": [],
            "truncated": False,
            "total_impacted": 0,
            "impact_scores": {},
        };
    }
    seeds: any = self._impact_seed_qns(changed_files);

    if not seeds {
        return {
            "changed_nodes": [],
            "impacted_nodes": [],
            "impacted_files": [],
            "edges": [],
            "truncated": False,
            "total_impacted": 0,
            "impact_scores": {},
        };
    }
    self._conn.execute("CREATE TEMP TABLE IF NOT EXISTS _impact_seeds (qn TEXT PRIMARY KEY)");
    self._conn.execute("DELETE FROM _impact_seeds");
    batch_size: any = 450;
    seed_list: any = `list(seeds);
    for i in range(0, len(seed_list), batch_size) {
        batch: any = seed_list[i:i + batch_size];
        placeholders: any = ",".join("(?)" for _ in batch);
        self._conn.execute(
            f"INSERT OR IGNORE INTO _impact_seeds (qn) VALUES {placeholders}", batch
        );
    }
    self._conn.execute(
        "CREATE TEMP TABLE IF NOT EXISTS _impact_policies (kind TEXT PRIMARY KEY, weight REAL NOT NULL, direction TEXT NOT NULL)",
    );
    self._conn.execute("DELETE FROM _impact_policies");
    self._conn.executemany(
        "INSERT INTO _impact_policies (kind, weight, direction) VALUES (?, ?, ?)",
        [
            (kind, weight, IMPACT_EDGE_DIRECTIONS.get(kind, IMPACT_DEFAULT_EDGE_DIRECTION))
            for (kind, weight) in IMPACT_EDGE_WEIGHTS.items()
        ],
    );
    for table in ("_impact_best", "_impact_frontier", "_impact_next") {
        self._conn.execute(
            f"CREATE TEMP TABLE IF NOT EXISTS {table} (node_qn TEXT PRIMARY KEY, score REAL NOT NULL)",
        );
        self._conn.execute(f"DELETE FROM {table}");
    }
    self._conn.execute(
        "CREATE TEMP TABLE IF NOT EXISTS _impact_frontier_dirs (dir TEXT PRIMARY KEY, score REAL NOT NULL)",
    );
    self._conn.execute("DELETE FROM _impact_frontier_dirs");

    self._conn.execute(
        "INSERT INTO _impact_best (node_qn, score) SELECT qn, 1.0 FROM _impact_seeds"
    );
    self._conn.execute(
        "INSERT INTO _impact_frontier (node_qn, score) SELECT qn, 1.0 FROM _impact_seeds"
    );

    candidate_sql: any = _impact_candidate_sql(resolution_guard);
    candidate_params: any = (
        IMPACT_DEFAULT_EDGE_WEIGHT,
        IMPACT_DEPTH_DECAY,
        _IMPACT_AOP_EXTRA_LIKE,
        IMPACT_DIRECTION_OUTGOING,
        IMPACT_DEFAULT_EDGE_DIRECTION,
        IMPACT_DIRECTION_OUTGOING,
        IMPACT_DEFAULT_EDGE_WEIGHT,
        IMPACT_DEPTH_DECAY,
        _IMPACT_AOP_EXTRA_LIKE,
        IMPACT_DIRECTION_OUTGOING,
        IMPACT_DEFAULT_EDGE_DIRECTION,
        IMPACT_DIRECTION_INCOMING,
        IMPACT_DEFAULT_EDGE_WEIGHT,
        IMPACT_DEPTH_DECAY,
        IMPACT_DEFAULT_EDGE_DIRECTION,
        IMPACT_DIRECTION_INCOMING,
        IMPACT_SCORE_FLOOR,
    );
    for _ in range(max_depth) {
        self._conn.execute("DELETE FROM _impact_next");
        self._conn.execute("DELETE FROM _impact_frontier_dirs");
        self._conn.execute(IMPACT_FRONTIER_DIRS_SQL);
        self._conn.execute(candidate_sql, candidate_params);
        self._conn.execute(
            "DELETE FROM _impact_next WHERE score <= COALESCE((SELECT score FROM _impact_best b WHERE b.node_qn = _impact_next.node_qn), 0.0)",
        );
        if self._conn.execute("SELECT 1 FROM _impact_next LIMIT 1").fetchone() is None {
            break;
        }
        self._conn.execute(
            "INSERT OR REPLACE INTO _impact_best (node_qn, score) SELECT node_qn, score FROM _impact_next",
        );
        self._conn.execute("DELETE FROM _impact_frontier");
        self._conn.execute(
            "INSERT INTO _impact_frontier (node_qn, score) SELECT node_qn, score FROM _impact_next"
        );
    }
    try {
        rows: any = self._conn.execute(
            "SELECT b.node_qn, b.score FROM _impact_best b JOIN nodes n ON n.qualified_name = b.node_qn LEFT JOIN _impact_seeds s ON s.qn = b.node_qn WHERE s.qn IS NULL AND n.extra NOT LIKE '%\"verilog_kind\"%' ORDER BY b.score DESC, b.node_qn LIMIT ?",
            (max_nodes + 1,),
        ).fetchall();
        truncated: any = operator.gt(len(rows), max_nodes);
        if truncated {
            total_impacted: any = self._conn.execute(
                "SELECT COUNT(*) FROM _impact_best b JOIN nodes n ON n.qualified_name = b.node_qn LEFT JOIN _impact_seeds s ON s.qn = b.node_qn WHERE s.qn IS NULL AND n.extra NOT LIKE '%\"verilog_kind\"%'",
            ).fetchone()[0];
        } else {
            total_impacted = len(rows);
        }
    } finally {
        for _tbl in (
            "_impact_seeds",
            "_impact_policies",
            "_impact_best",
            "_impact_frontier",
            "_impact_next",
            "_impact_frontier_dirs",
        ) {
            try {
                self._conn.execute(f"DELETE FROM {_tbl}");
            } except sqlite3.Error {}
        }
    }
    kept_rows: any = rows[:max_nodes];
    score_by_qn: any = {row[0]: `float(row[1]) for row in kept_rows};

    changed_nodes: any = self._batch_get_nodes(seeds);
    impacted_nodes: any = self._batch_get_nodes(`set(score_by_qn));
    impacted_nodes.sort(
        key=lambda (`node) -> any {
            (-score_by_qn.get(`node.qualified_name, 0.0), `node.qualified_name)
        },
    );

    impacted_files: any = `list({n.file_path for n in impacted_nodes});

    relevant_edges: list[GraphEdge] = [];
    all_qns: any = seeds | {n.qualified_name for n in impacted_nodes};
    if all_qns {
        relevant_edges = self.get_edges_among(all_qns);
        relevant_edges.extend(
            self.import_scope_edges({n.file_path for n in changed_nodes + impacted_nodes}, all_qns)
        );
        if resolution == RESOLUTION_DIRECT {
            relevant_edges = [
                `edge
                for `edge in relevant_edges
                if `edge.target_resolution != RESOLUTION_UNRESOLVED
            ];
        }
    }

    return {
        "changed_nodes": changed_nodes,
        "impacted_nodes": impacted_nodes,
        "impacted_files": impacted_files,
        "edges": relevant_edges,
        "truncated": truncated,
        "total_impacted": total_impacted,
        "impact_scores": {
            `node.qualified_name: round(score_by_qn.get(`node.qualified_name, 0.0), 4)
            for `node in impacted_nodes
        },
    };
}

impl GraphStore._get_impact_radius_networkx(
    changed_files: list[str],
    max_depth: int = max_depth_default____,
    max_nodes: int = max_nodes_default___,
    resolution: str = "all",
) -> dict[str, Any] {
    best: dict[str, float];
    if resolution not in IMPACT_RESOLUTIONS {
        raise ValueError(
            f"resolution must be one of {`list(IMPACT_RESOLUTIONS)}, got {resolution!r}"
        );
    }
    direct_only: any = operator.eq(resolution, RESOLUTION_DIRECT);
    max_depth = max(0, `int(max_depth));
    max_nodes = max(0, `int(max_nodes));
    nxg: any = self._build_networkx_graph();

    seeds: any = self._impact_seed_qns(changed_files);
    scope_importers: any = self._import_scope_importer_index();
    file_directories: any = self._file_node_directories() if scope_importers else {};
    scope_weight: any = IMPACT_EDGE_WEIGHTS.get("IMPORTS_FROM", IMPACT_DEFAULT_EDGE_WEIGHT);

    best = dict.fromkeys(seeds, 1.0);
    frontier: any = `dict(best);

    for _ in range(max_depth) {
        if not frontier {
            break;
        }
        next_frontier: dict[str, float] = {};
        for (qn, score) in frontier.items() {
            directory: any = file_directories.get(qn);
            scoped: any = [
                (importer, scope_weight)
                for importer in scope_importers.get(directory or "", ())
            ];
            if qn not in nxg {
                if not scoped {
                    continue;
                }
                neighbors: any = scoped;
            } else {
                neighbors = [
                    (target, data["impact_outgoing_weight"])
                    for (_, target, data) in nxg.out_edges(qn, data=True)
                    if "impact_outgoing_weight" in data
                        and not (direct_only and data.get("unresolved_target"))
                ]
                    + [
                        (source, data["impact_incoming_weight"])
                        for (source, _, data) in nxg.in_edges(qn, data=True)
                        if "impact_incoming_weight" in data
                            and not (direct_only and data.get("unresolved_target"))
                    ]
                    + scoped;
            }
            for (other_qn, weight) in neighbors {
                new_score: any = score * weight * IMPACT_DEPTH_DECAY;
                if new_score <= IMPACT_SCORE_FLOOR {
                    continue;
                }
                if new_score > best.get(other_qn, 0.0) {
                    best[other_qn] = new_score;
                    next_frontier[other_qn] = new_score;
                }
            }
        }
        frontier = next_frontier;
    }

    changed_nodes: any = self._batch_get_nodes(seeds);
    impacted_qns: any = `set(best) - seeds;
    impacted_nodes: any = self._batch_get_nodes(impacted_qns);
    impacted_nodes = [`node for `node in impacted_nodes if not `node.extra.get("verilog_kind")];
    impacted_nodes.sort(
        key=lambda (`node) -> any { (-best.get(`node.qualified_name, 0.0), `node.qualified_name) }
    );

    total_impacted: any = len(impacted_nodes);
    truncated: any = operator.gt(total_impacted, max_nodes);
    if truncated {
        impacted_nodes = impacted_nodes[:max_nodes];
    }

    impacted_files: any = `list({n.file_path for n in impacted_nodes});

    relevant_edges: list[GraphEdge] = [];
    all_qns: any = seeds | {n.qualified_name for n in impacted_nodes};
    if all_qns {
        relevant_edges = self.get_edges_among(all_qns);
        relevant_edges.extend(
            self.import_scope_edges({n.file_path for n in changed_nodes + impacted_nodes}, all_qns)
        );
        if resolution == RESOLUTION_DIRECT {
            relevant_edges = [
                `edge
                for `edge in relevant_edges
                if `edge.target_resolution != RESOLUTION_UNRESOLVED
            ];
        }
    }

    return {
        "changed_nodes": changed_nodes,
        "impacted_nodes": impacted_nodes,
        "impacted_files": impacted_files,
        "edges": relevant_edges,
        "truncated": truncated,
        "total_impacted": total_impacted,
        "impact_scores": {
            `node.qualified_name: round(best.get(`node.qualified_name, 0.0), 4)
            for `node in impacted_nodes
        },
    };
}

impl GraphStore.get_subgraph(qualified_names: list[str]) -> dict[str, Any] {
    nodes: any = [];
    qn: any;
    for qn in qualified_names {
        `node: any = self.get_node(qn);
        if `node {
            nodes.append(`node);
        }
    }

    edges: any = [];
    qn_set: any = `set(qualified_names);
    for qn in qualified_names {
        for e in self.get_edges_by_source(qn) {
            if e.target_qualified in qn_set {
                edges.append(e);
            }
        }
    }

    return {"nodes": nodes, "edges": edges};
}

impl GraphStore.get_stats -> GraphStats {
    with self._read_transaction() {
        return self._get_stats_locked();
    }
}

impl GraphStore._get_stats_locked -> GraphStats {
    total_nodes: any = self._conn.execute("SELECT COUNT(*) FROM nodes").fetchone()[0];
    total_edges: any = self._conn.execute("SELECT COUNT(*) FROM edges").fetchone()[0];

    nodes_by_kind: dict[str, int] = {};
    row: any;
    for row in self._conn.execute(
        "SELECT CASE WHEN extra LIKE '%\"verilog_kind\"%' THEN 'Signal' ELSE kind END AS display_kind, COUNT(*) AS cnt FROM nodes GROUP BY CASE WHEN extra LIKE '%\"verilog_kind\"%' THEN 'Signal' ELSE kind END",
    ) {
        nodes_by_kind[row["display_kind"]] = row["cnt"];
    }

    edges_by_kind: dict[str, int] = {};
    for row in self._conn.execute("SELECT kind, COUNT(*) as cnt FROM edges GROUP BY kind") {
        edges_by_kind[row["kind"]] = row["cnt"];
    }
    languages: any = [
        r["language"]
        for r in self._conn.execute(
            "SELECT DISTINCT language FROM nodes WHERE kind = 'File' AND language IS NOT NULL AND language != '' ORDER BY language",
        )
    ];

    files_count: any = self._conn.execute(
        "SELECT COUNT(*) FROM nodes WHERE kind = 'File'"
    ).fetchone()[0];

    last_updated: any = self.get_metadata("last_updated");

    return GraphStats(
        total_nodes=total_nodes,
        total_edges=total_edges,
        nodes_by_kind=nodes_by_kind,
        edges_by_kind=edges_by_kind,
        languages=languages,
        files_count=files_count,
        last_updated=last_updated,
    );
}

impl GraphStore._nodes_by_size_filter(
    min_lines: int, max_lines: int | None, kind: str | None, file_path_pattern: str | None
) -> tuple[str, list] {
    conditions: any = [
        "line_start IS NOT NULL",
        "line_end IS NOT NULL",
        "(line_end - line_start + 1) >= ?",
        "extra NOT LIKE '%\"verilog_kind\"%'",
    ];
    params: list = [min_lines];

    if max_lines is not None {
        conditions.append("(line_end - line_start + 1) <= ?");
        params.append(max_lines);
    }
    if kind {
        conditions.append("kind = ?");
        params.append(kind);
    }
    if file_path_pattern {
        conditions.append("file_path LIKE ?");
        params.append(f"%{file_path_pattern}%");
    }
    return (" AND ".join(conditions), params);
}

impl GraphStore.count_nodes_by_size(
    min_lines: int = 50,
    max_lines: int | None = None,
    kind: str | None = None,
    file_path_pattern: str | None = None,
) -> int {
    where: any;
    params: any;
    (where, params) = self._nodes_by_size_filter(
        min_lines, max_lines, kind, file_path_pattern
    ) as any;
    row: any = self._conn.execute(f"SELECT COUNT(*) FROM nodes WHERE {where}", params).fetchone();
    return `int(row[0]);
}

impl GraphStore.get_nodes_by_size(
    min_lines: int = 50,
    max_lines: int | None = None,
    kind: str | None = None,
    file_path_pattern: str | None = None,
    limit: int = 50,
) -> list[GraphNode] {
    where: any;
    params: any;
    (where, params) = self._nodes_by_size_filter(
        min_lines, max_lines, kind, file_path_pattern
    ) as any;
    params.append(limit);
    rows: any = self._conn.execute(
        f"SELECT * FROM nodes WHERE {where} ORDER BY (line_end - line_start + 1) DESC LIMIT ?",
        params,
    ).fetchall();
    return [self._row_to_node(r) for r in rows];
}

impl GraphStore.get_node_by_id(node_id: int) -> Optional[GraphNode] {
    row: any = self._conn.execute("SELECT * FROM nodes WHERE id = ?", (node_id,)).fetchone();
    return self._row_to_node(row) if row else None;
}

impl GraphStore.get_nodes_by_kind(
    kinds: list[str], file_pattern: str | None = None
) -> list[GraphNode] {
    if not kinds {
        return [];
    }
    placeholders: any = ",".join("?" for _ in kinds);
    conditions: any = [f"kind IN ({placeholders})"];
    params: list[str] = `list(kinds);
    if file_pattern {
        conditions.append("file_path LIKE ?");
        params.append(f"%{file_pattern}%");
    }
    where: any = " AND ".join(conditions);
    rows: any = self._conn.execute(f"SELECT * FROM nodes WHERE {where}", params).fetchall();
    return [self._row_to_node(r) for r in rows];
}

impl GraphStore.count_flow_memberships(node_id: int) -> int {
    row: any = self._conn.execute(
        "SELECT COUNT(*) as cnt FROM flow_memberships WHERE node_id = ?", (node_id,)
    ).fetchone();
    return row["cnt"] if row else 0;
}

impl GraphStore.get_flow_criticalities_for_node(node_id: int) -> list[float] {
    rows: any = self._conn.execute(
        "SELECT f.criticality FROM flows f JOIN flow_memberships fm ON fm.flow_id = f.id WHERE fm.node_id = ?",
        (node_id,),
    ).fetchall();
    return [r["criticality"] for r in rows];
}

impl GraphStore.get_flow_entry_point_ids(node_ids: set[int]) -> set[int] {
    flow_ids: any = self.get_flow_ids_by_node_ids(node_ids);
    result: set[int] = set[any]();
    for i in range(0, len(flow_ids), 450) {
        batch: any = flow_ids[i:i + 450];
        placeholders: any = ",".join("?" for _ in batch);
        rows: any = self._conn.execute(
            f"SELECT entry_point_id FROM flows WHERE id IN ({placeholders})", batch
        ).fetchall();
        result.update(r["entry_point_id"] for r in rows);
    }
    return result;
}

impl GraphStore.get_node_community_id(node_id: int) -> int | None {
    row: any = self._conn.execute(
        "SELECT community_id FROM nodes WHERE id = ?", (node_id,)
    ).fetchone();
    if row and row["community_id"] is not None {
        return row["community_id"];
    }
    return None;
}

impl GraphStore.get_community_ids_by_qualified_names(qns: list[str]) -> dict[str, int | None] {
    result: dict[str, int | None] = {};
    batch_size: any = 450;
    for i in range(0, len(qns), batch_size) {
        batch: any = qns[i:i + batch_size];
        placeholders: any = ",".join("?" for _ in batch);
        rows: any = self._conn.execute(
            f"SELECT qualified_name, community_id FROM nodes WHERE qualified_name IN ({placeholders})",
            batch,
        ).fetchall();
        for r in rows {
            result[r["qualified_name"]] = r["community_id"];
        }
    }
    return result;
}

impl GraphStore.get_files_matching(pattern: str) -> list[str] {
    normalized: any = normalize_file_path(pattern);
    escaped: any = normalized.replace("\\", "\\\\").replace("%", "\\%").replace("_", "\\_");
    rows: any = self._conn.execute(
        "SELECT DISTINCT file_path FROM nodes WHERE file_path LIKE ? ESCAPE '\\'", (f"%{escaped}",)
    ).fetchall();
    return [r["file_path"] for r in rows];
}

impl GraphStore.get_nodes_without_signature -> list[sqlite3.Row] {
    return self._conn.execute(
        "SELECT id, name, kind, params, return_type FROM nodes WHERE signature IS NULL"
    ).fetchall();
}

impl GraphStore.update_node_signature(node_id: int, signature: str) {
    self._conn.execute("UPDATE nodes SET signature = ? WHERE id = ?", (signature, node_id));
}

impl GraphStore.update_node_signatures(signature_rows: list[tuple[str, int]]) {
    if not signature_rows {
        return;
    }
    self._begin_immediate();
    try {
        for start in range(0, len(signature_rows), _UPDATE_BATCH) {
            self._conn.executemany(
                "UPDATE nodes SET signature = ? WHERE id = ?",
                signature_rows[start:start + _UPDATE_BATCH],
            );
        }
        self._conn.commit();
    } except BaseException {
        self._conn.rollback();
        raise;
    }
}

impl GraphStore.get_all_community_ids -> dict[str, int | None] {
    try {
        rows: any = self._conn.execute("SELECT qualified_name, community_id FROM nodes").fetchall();
        return {r["qualified_name"]: r["community_id"] for r in rows};
    } except sqlite3.OperationalError as exc {
        logger.debug("Community IDs unavailable (schema not yet migrated): %s", exc);
        return {};
    }
}

impl GraphStore.get_node_ids_by_files(file_paths: list[str]) -> set[int] {
    if not file_paths {
        return set[any]();
    }
    file_paths = [normalize_file_path(p) for p in file_paths];
    result: set[int] = set[any]();
    batch_size: any = 450;
    for i in range(0, len(file_paths), batch_size) {
        batch: any = file_paths[i:i + batch_size];
        placeholders: any = ",".join("?" for _ in batch);
        rows: any = self._conn.execute(
            f"SELECT id FROM nodes WHERE file_path IN ({placeholders})", batch
        ).fetchall();
        result.update(r["id"] for r in rows);
    }
    return result;
}

impl GraphStore.get_flow_ids_by_node_ids(node_ids: set[int]) -> list[int] {
    if not node_ids {
        return [];
    }
    nids: any = `list(node_ids);
    result: list[int] = [];
    batch_size: any = 450;
    for i in range(0, len(nids), batch_size) {
        batch: any = nids[i:i + batch_size];
        placeholders: any = ",".join("?" for _ in batch);
        rows: any = self._conn.execute(
            f"SELECT DISTINCT flow_id FROM flow_memberships WHERE node_id IN ({placeholders})",
            batch,
        ).fetchall();
        result.extend(r["flow_id"] for r in rows);
    }
    return `list(dict.fromkeys(result));
}

impl GraphStore.get_flow_qualified_names(flow_id: int) -> set[str] {
    rows: any = self._conn.execute(
        "SELECT n.qualified_name FROM flow_memberships fm JOIN nodes n ON fm.node_id = n.id WHERE fm.flow_id = ?",
        (flow_id,),
    ).fetchall();
    return {r["qualified_name"] for r in rows};
}

impl GraphStore.get_node_kind_by_id(node_id: int) -> str | None {
    row: any = self._conn.execute("SELECT kind FROM nodes WHERE id = ?", (node_id,)).fetchone();
    return row["kind"] if row else None;
}

impl GraphStore.get_all_call_targets(include_file_sources: bool = True) -> set[str] {
    if include_file_sources {
        rows: any = self._conn.execute(
            "SELECT DISTINCT target_qualified FROM edges WHERE kind = 'CALLS'"
        ).fetchall();
    } else {
        rows = self._conn.execute(
            "SELECT DISTINCT e.target_qualified FROM edges e LEFT JOIN nodes n ON n.qualified_name = e.source_qualified WHERE e.kind = 'CALLS' AND (n.kind IS NULL OR n.kind != 'File')",
        ).fetchall();
    }
    return {r["target_qualified"] for r in rows};
}

impl GraphStore.get_call_targets_outside_tests -> set[str] {
    rows: any = self._conn.execute(
        "SELECT DISTINCT e.target_qualified FROM edges e LEFT JOIN nodes n ON n.qualified_name = e.source_qualified WHERE e.kind = 'CALLS' AND (n.kind IS NULL OR (n.kind != 'File' AND n.is_test = 0))",
    ).fetchall();
    return {r["target_qualified"] for r in rows};
}

impl GraphStore.get_communities_list -> list[sqlite3.Row] {
    try {
        return self._conn.execute("SELECT id, name FROM communities").fetchall();
    } except sqlite3.OperationalError as exc {
        logger.debug("Communities list unavailable (table missing): %s", exc);
        return [];
    }
}

impl GraphStore.get_community_member_qns(community_id: int) -> list[str] {
    rows: any = self._conn.execute(
        "SELECT qualified_name FROM nodes WHERE community_id = ?", (community_id,)
    ).fetchall();
    return [r["qualified_name"] for r in rows];
}

impl GraphStore.get_nodes_by_community_id(community_id: int) -> list[GraphNode] {
    rows: any = self._conn.execute(
        "SELECT * FROM nodes WHERE community_id = ?", (community_id,)
    ).fetchall();
    return [self._row_to_node(r) for r in rows];
}

impl GraphStore.get_outgoing_targets(source_qns: list[str]) -> list[str] {
    results: list[str] = [];
    batch_size: any = 450;
    for i in range(0, len(source_qns), batch_size) {
        batch: any = source_qns[i:i + batch_size];
        placeholders: any = ",".join("?" for _ in batch);
        rows: any = self._conn.execute(
            f"SELECT target_qualified FROM edges WHERE source_qualified IN ({placeholders}) ORDER BY source_qualified, id",
            batch,
        ).fetchall();
        results.extend(r["target_qualified"] for r in rows);
    }
    return results;
}

impl GraphStore.get_incoming_sources(target_qns: list[str]) -> list[str] {
    results: list[str] = [];
    batch_size: any = 450;
    for i in range(0, len(target_qns), batch_size) {
        batch: any = target_qns[i:i + batch_size];
        placeholders: any = ",".join("?" for _ in batch);
        rows: any = self._conn.execute(
            f"SELECT source_qualified FROM edges WHERE target_qualified IN ({placeholders}) ORDER BY target_qualified, id",
            batch,
        ).fetchall();
        results.extend(r["source_qualified"] for r in rows);
    }
    return results;
}

impl GraphStore.get_all_edges -> list[GraphEdge] {
    rows: any = self._conn.execute("SELECT * FROM edges").fetchall();
    return [self._row_to_edge(r) for r in rows];
}

impl GraphStore.get_edges_among(qualified_names: set[str]) -> list[GraphEdge] {
    if not qualified_names {
        return [];
    }
    qns: any = `list(qualified_names);
    results: list[GraphEdge] = [];
    batch_size: any = 450;
    for i in range(0, len(qns), batch_size) {
        batch: any = qns[i:i + batch_size];
        placeholders: any = ",".join("?" for _ in batch);
        rows: any = self._conn.execute(
            f"SELECT * FROM edges WHERE source_qualified IN ({placeholders}) ORDER BY source_qualified, id",
            batch,
        ).fetchall();
        for r in rows {
            `edge: any = self._row_to_edge(r);
            if `edge.target_qualified in qualified_names {
                results.append(`edge);
            }
        }
    }
    return results;
}

impl GraphStore.get_edges_touching(names: set[str]) -> list[GraphEdge] {
    if not names {
        return [];
    }
    wanted: any = `list(names);
    found: dict[int, GraphEdge] = {};
    batch_size: any = 450;
    for column in ("source_qualified", "target_qualified") {
        for i in range(0, len(wanted), batch_size) {
            batch: any = wanted[i:i + batch_size];
            placeholders: any = ",".join("?" for _ in batch);
            rows: any = self._conn.execute(
                f"SELECT * FROM edges WHERE {column} IN ({placeholders})", batch
            ).fetchall();
            for row in rows {
                if row["id"] not in found {
                    found[row["id"]] = self._row_to_edge(row);
                }
            }
        }
    }
    return [found[edge_id] for edge_id in sorted(found)];
}

impl GraphStore.iter_edge_end_counts(column: str) -> Generator[any, any, any] {
    if column not in ("source_qualified", "target_qualified") {
        raise ValueError(f"not an edge end: {column!r}");
    }
    rows: any = self._conn.execute(
        f"SELECT {column} AS name, COUNT(*) AS edges FROM edges GROUP BY {column}"
    );
    for row in rows {
        yield (row["name"], row["edges"]);
    }
}

impl GraphStore.iter_edge_targets_from(sources: Iterable[str]) -> Generator[any, any, any] {
    wanted: any = `list(sources);
    batch_size: any = 450;
    for i in range(0, len(wanted), batch_size) {
        batch: any = wanted[i:i + batch_size];
        placeholders: any = ",".join("?" for _ in batch);
        rows: any = self._conn.execute(
            f"SELECT target_qualified FROM edges WHERE source_qualified IN ({placeholders})", batch
        );
        for row in rows {
            yield row["target_qualified"];
        }
    }
}

impl GraphStore.get_files_with_edges(file_paths: Iterable[str]) -> set[str] {
    wanted: any = `list(file_paths);
    found: set[str] = set[any]();
    batch_size: any = 450;
    for i in range(0, len(wanted), batch_size) {
        batch: any = wanted[i:i + batch_size];
        placeholders: any = ",".join("?" for _ in batch);
        rows: any = self._conn.execute(
            f"SELECT DISTINCT file_path FROM edges WHERE file_path IN ({placeholders})", batch
        ).fetchall();
        found.update(row["file_path"] for row in rows);
    }
    return found;
}

impl GraphStore.has_edge_with_backslash_path -> bool {
    row: any = self._conn.execute(
        "SELECT 1 FROM edges WHERE instr(file_path, char(92)) > 0 LIMIT 1"
    ).fetchone();
    return row is not None;
}

impl GraphStore.iter_node_identities -> Iterator[sqlite3.Row] {
    return iter(
        self._conn.execute(
            "SELECT id, qualified_name, name, kind, file_path, community_id, (extra IS NULL OR json_valid(extra) = 0 OR COALESCE(json_extract(extra, '$.virtual'), 0) != 1) AS listed FROM nodes ORDER BY file_path, id",
        ),
    );
}

impl GraphStore._batch_get_nodes(qualified_names: set[str]) -> list[GraphNode] {
    if not qualified_names {
        return [];
    }
    qns: any = `list(qualified_names);
    results: list[GraphNode] = [];
    batch_size: any = 450;
    for i in range(0, len(qns), batch_size) {
        batch: any = qns[i:i + batch_size];
        placeholders: any = ",".join("?" for _ in batch);
        rows: any = self._conn.execute(
            f"SELECT * FROM nodes WHERE qualified_name IN ({placeholders})", batch
        ).fetchall();
        results.extend(self._row_to_node(r) for r in rows);
    }
    return results;
}

impl GraphStore.get_nodes_by_qualified_names(qualified_names: Iterable[str]) -> list[GraphNode] {
    return self._batch_get_nodes(`set(qualified_names));
}

impl GraphStore.get_node_degrees(*, include_tests: bool = True) -> dict[str, tuple[int, int]] {
    sql: any = "SELECT n.qualified_name, (SELECT COUNT(*) FROM edges e WHERE e.target_qualified = n.qualified_name), (SELECT COUNT(*) FROM edges e WHERE e.source_qualified = n.qualified_name) FROM nodes n WHERE n.kind != 'File'";
    if not include_tests {
        sql += " AND n.is_test = 0 AND n.kind != 'Test'";
    }
    rows: any = self._conn.execute(sql).fetchall();
    return {row[0]: (`int(row[1]), `int(row[2])) for row in rows};
}

impl GraphStore.get_communities_by_ids(ids: Iterable[int]) -> dict[int, sqlite3.Row] {
    i: any;
    wanted: any = sorted({`int(i) for i in ids});
    found: dict[int, sqlite3.Row] = {};
    batch_size: any = 450;
    for i in range(0, len(wanted), batch_size) {
        batch: any = wanted[i:i + batch_size];
        placeholders: any = ",".join("?" for _ in batch);
        rows: any = self._conn.execute(
            f"SELECT id, name, size FROM communities WHERE id IN ({placeholders})", batch
        ).fetchall();
        for row in rows {
            found[`int(row["id"])] = row;
        }
    }
    return found;
}

impl GraphStore.count_flows -> int {
    return `int(self._conn.execute("SELECT COUNT(*) FROM flows").fetchone()[0]);
}

impl GraphStore.load_flow_adjacency -> "FlowAdjacency" {
    nodes_by_qn: dict[str, GraphNode] = {};
    nodes_by_id: dict[int, GraphNode] = {};
    row: any;
    for row in self._conn.execute("SELECT * FROM nodes") {
        `node: any = self._row_to_node(row);
        nodes_by_qn[`node.qualified_name] = `node;
        nodes_by_id[`node.id] = `node;
    }

    calls_out: dict[str, list[str]] = {};
    has_tested_by: set[str] = set[any]();
    for row in self._conn.execute(
        "SELECT kind, source_qualified, target_qualified FROM edges WHERE kind IN ('CALLS', 'TESTED_BY')",
    ) {
        kind: any;
        src: any;
        tgt: any;
        (kind, src, tgt) = (row["kind"], row["source_qualified"], row["target_qualified"]);
        if kind == "CALLS" {
            calls_out.setdefault(src, []).append(tgt);
        } else {
            has_tested_by.add(src);
        }
    }

    return FlowAdjacency(
        calls_out=calls_out,
        has_tested_by=has_tested_by,
        nodes_by_qn=nodes_by_qn,
        nodes_by_id=nodes_by_id,
    );
}

impl GraphStore._build_networkx_graph -> nx.DiGraph {
    import networkx as nx;

    with self._cache_lock {
        if self._nxg_cache is not None {
            return self._nxg_cache;
        }
        g: nx.DiGraph = nx.DiGraph();
        rows: any = self._conn.execute("SELECT * FROM edges").fetchall();
        known_qns: any = {row[0] for row in self._conn.execute("SELECT qualified_name FROM nodes")};
        for r in rows {
            source: any = r["source_qualified"];
            target: any = r["target_qualified"];
            kind: any = r["kind"];
            candidate_weight: any = IMPACT_EDGE_WEIGHTS.get(kind, IMPACT_DEFAULT_EDGE_WEIGHT);
            if not g.has_edge(source, target) {
                g.add_edge(source, target, kind=kind);
            }
            data: any = g[source][target];
            unresolved: any = False;
            if kind in TARGET_RESOLUTION_KINDS {
                stored: any = r["target_resolution"] if "target_resolution" in r.keys() else None;
                unresolved = operator.eq(stored, "unresolved")
                    if stored is not None
                    else target not in known_qns;
            }
            if unresolved {
                data.setdefault("unresolved_target", True);
            } else {
                data["unresolved_target"] = False;
            }
            existing_weight: any = IMPACT_EDGE_WEIGHTS.get(
                data.get("kind", ""), IMPACT_DEFAULT_EDGE_WEIGHT
            );
            if candidate_weight > existing_weight {
                data["kind"] = kind;
            }
            if "\"aop_resolved\"" in (r["extra"] or "") {
                direction: any = IMPACT_DIRECTION_OUTGOING;
            } else {
                direction = IMPACT_EDGE_DIRECTIONS.get(kind, IMPACT_DEFAULT_EDGE_DIRECTION);
            }
            if direction != IMPACT_DIRECTION_NONE {
                weight_key: any = f"impact_{direction}_weight";
                data[weight_key] = max(data.get(weight_key, 0.0), candidate_weight);
            }
        }
        self._nxg_cache = g;
        return g;
    }
}

impl GraphStore._make_qualified(`node: NodeInfo) -> str {
    return qualified_name_of(`node);
}

impl GraphStore._row_to_node(row: sqlite3.Row) -> GraphNode {
    raw_extra: any = row["extra"];
    return GraphNode(
        id=row["id"],
        kind=row["kind"],
        name=row["name"],
        qualified_name=row["qualified_name"],
        file_path=row["file_path"],
        line_start=row["line_start"],
        line_end=row["line_end"],
        language=row["language"] or "",
        parent_name=row["parent_name"],
        params=row["params"],
        return_type=row["return_type"],
        is_test=`bool(row["is_test"]),
        file_hash=row["file_hash"],
        extra=json.loads(raw_extra) if raw_extra and raw_extra != "{}" else {},
    );
}

impl GraphStore._row_to_edge(row: sqlite3.Row) -> GraphEdge {
    raw_extra: any = row["extra"];
    extra: any = json.loads(raw_extra) if raw_extra and raw_extra != "{}" else {};
    keys: any = row.keys();
    confidence: any = row["confidence"] if "confidence" in keys else 1.0;
    confidence_tier: any = row["confidence_tier"] if "confidence_tier" in keys else "EXTRACTED";
    target_resolution: any = row["target_resolution"] if "target_resolution" in keys else None;
    return GraphEdge(
        id=row["id"],
        kind=row["kind"],
        source_qualified=row["source_qualified"],
        target_qualified=row["target_qualified"],
        file_path=row["file_path"],
        line=row["line"],
        extra=extra,
        confidence=confidence,
        confidence_tier=confidence_tier,
        target_resolution=target_resolution,
    );
}

impl _sanitize_name(s: str, max_len: int = 256) -> str {
    if len(s) <= max_len and not _NAME_CONTROL_CHARS.search(s) {
        return s;
    }
    cleaned: any = "".join(ch for ch in s if ch in ("\t", "\n") or ord(ch) >= 32);
    return cleaned[:max_len];
}

impl node_to_dict(n: GraphNode) -> dict {
    result: any = {
        "id": n.id,
        "kind": n.kind,
        "name": _sanitize_name(n.name),
        "qualified_name": _sanitize_name(n.qualified_name),
        "file_path": n.file_path,
        "line_start": n.line_start,
        "line_end": n.line_end,
        "language": n.language,
        "parent_name": _sanitize_name(n.parent_name) if n.parent_name else n.parent_name,
        "is_test": n.is_test,
    };
    if n.kind in ("YamlPath", "JsonPath") {
        yaml_metadata: dict[str, Any] = {};
        key: any;
        for key in ("schema_path", "example_path", "value_type") {
            value: any = n.extra.get(key);
            if isinstance(value, `str) {
                yaml_metadata[key] = _sanitize_name(value);
            }
        }
        for key in (
            "document_index",
            "occurrence_count",
            "duplicate_key_occurrence_count",
            "duplicate_group_count",
        ) {
            value = n.extra.get(key);
            if isinstance(value, `int) and not isinstance(value, `bool) {
                yaml_metadata[key] = value;
            }
        }
        for key in (
            "duplicate_key",
            "duplicate_groups_truncated",
            "is_alias",
            "anchor_definition",
            "yaml_merge",
            "lines_truncated",
        ) {
            value = n.extra.get(key);
            if isinstance(value, `bool) {
                yaml_metadata[key] = value;
            }
        }
        value_types: any = n.extra.get("value_types");
        if isinstance(value_types, `list) {
            yaml_metadata["value_types"] = [
                _sanitize_name(value)
                for value in value_types[:20]
                if isinstance(value, `str)
            ];
        }
        line_samples: any = n.extra.get("line_samples");
        if isinstance(line_samples, `list) {
            yaml_metadata["line_samples"] = [
                line
                for line in line_samples[:20]
                if isinstance(line, `int) and not isinstance(line, `bool)
            ];
            occurrence_count: any = n.extra.get("occurrence_count", len(line_samples));
            if isinstance(occurrence_count, `int) and not isinstance(occurrence_count, `bool) {
                yaml_metadata["line_samples_omitted"] = max(
                    0, occurrence_count - len(yaml_metadata["line_samples"])
                );
            }
        }
        result["json" if n.kind == "JsonPath" else "yaml"] = yaml_metadata;
    } elif n.kind == "File" and n.language == "json" {
        json_metadata: dict[str, Any] = {
            "truncated": `bool(n.extra.get("json_truncated")),
            "values_indexed": False,
        };
        if n.extra.get("json_locale_file") {
            json_metadata["locale_file"] = True;
        }
        if n.extra.get("json_data_file") {
            json_metadata["data_file"] = True;
        }
        result["json"] = json_metadata;
    } elif n.kind == "File" and "values_indexed" in n.extra {
        file_yaml_metadata: dict[str, Any] = {
            "document_count": n.extra.get("yaml_document_count", 0),
            "duplicate_key_count": n.extra.get("yaml_duplicate_key_count", 0),
            "unsupported_key_count": n.extra.get("yaml_unsupported_key_count", 0),
            "truncated": `bool(n.extra.get("yaml_truncated")),
            "values_indexed": False,
        };
        if n.extra.get("yaml_locale_file") {
            file_yaml_metadata["locale_file"] = True;
        }
        duplicate_keys: any = n.extra.get("yaml_duplicate_keys");
        if isinstance(duplicate_keys, `list) {
            safe_duplicate_keys: list[dict[str, Any]] = [];
            for item in duplicate_keys[:100] {
                if not isinstance(item, `dict) {
                    continue;
                }
                item_lines: any = item.get("line_samples");
                if not isinstance(item_lines, `list) {
                    item_lines = [];
                }
                safe_duplicate_keys.append({
                    "document_index": item.get("document_index"),
                    "path": _sanitize_name(`str(item.get("path", ""))),
                    "occurrence_count": item.get("occurrence_count"),
                    "line_samples": [
                        line
                        for line in item_lines[:20]
                        if isinstance(line, `int) and not isinstance(line, `bool)
                    ],
                    "lines_truncated": `bool(item.get("lines_truncated")),
                });
            }
            file_yaml_metadata["duplicate_keys"] = safe_duplicate_keys;
        }
        result["yaml"] = file_yaml_metadata;
    }
    return result;
}

impl edge_to_dict(e: GraphEdge) -> dict {
    result: dict = {
        "id": e.id,
        "kind": e.kind,
        "source": _sanitize_name(e.source_qualified),
        "target": _sanitize_name(e.target_qualified),
        "file_path": e.file_path,
        "line": e.line,
        "confidence": e.confidence,
        "confidence_tier": e.confidence_tier,
    };
    if e.target_resolution == RESOLUTION_UNRESOLVED {
        result["target_resolution"] = RESOLUTION_UNRESOLVED;
    }
    for key in ("ambiguous_targets", "unresolved_targets") {
        targets: any = e.extra.get(key);
        if isinstance(targets, `list) {
            result[key] = [
                _sanitize_name(target)
                for target in targets[:20]
                if isinstance(target, `str)
            ];
            resolution: any = key.removesuffix("_targets");
            count: any = e.extra.get(f"{resolution}_target_count");
            if not isinstance(count, `int) {
                count = len(targets);
            }
            result[f"{resolution}_target_count"] = count;
            result[f"{resolution}_targets_truncated"] = `bool(
                e.extra.get(f"{resolution}_targets_truncated")
                    or operator.gt(count, len(result[key])),
            );
        }
    }
    return result;
}

impl __getattr__(name: str) -> Any {
    if name in ("EdgeInfo", "NodeInfo", "is_test_file") {
        val: any = getattr(lazy("parser"), name);
        globals()[name] = val;
        return val;
    }
    if name == "nx" {
        import networkx as _nx;

        globals()["nx"] = _nx;
        return _nx;
    }
    raise AttributeError(f"module {__name__!r} has no attribute {name!r}");
}
