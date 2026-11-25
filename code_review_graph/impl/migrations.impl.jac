impl _progress(msg: str, *args_: object) {
    args: any = tuple(args_);
    logger.log(_progress_level.get(), msg, *args);
}

impl _matches(exc: sqlite3.Error, needles: tuple[str, ...]) -> bool {
    message: any = `str(exc).lower();
    return `any(needle in message for needle in needles);
}

impl _apply(conn: sqlite3.Connection, sql: str, *, what: str) -> bool {
    try {
        conn.execute(sql);
    } except sqlite3.OperationalError as exc {
        if _matches(exc, _ALREADY_APPLIED) {
            logger.debug("%s already applied by another process", what);
            return False;
        }
        raise;
    }
    return True;
}

impl _write_lock_held(conn: sqlite3.Connection) -> Generator[any, any, any] {
    if conn.in_transaction {
        yield;
        return;
    }
    conn.execute("BEGIN IMMEDIATE");
    try {
        yield;
    } except BaseException {
        conn.rollback();
        raise;
    }
    conn.commit();
}

impl get_schema_version(conn: sqlite3.Connection) -> int {
    try {
        row: any = conn.execute(
            "SELECT value FROM metadata WHERE key = 'schema_version'"
        ).fetchone();
        if row is None {
            return 1;
        }
        return `int(row[0] if isinstance(row, (`tuple, `list)) else row["value"]);
    } except sqlite3.OperationalError {
        return 0;
    }
}

impl _set_schema_version(conn: sqlite3.Connection, version: int) {
    conn.execute(
        "INSERT OR REPLACE INTO metadata (key, value) VALUES ('schema_version', ?)",
        (`str(version),),
    );
}

impl _has_column(conn: sqlite3.Connection, table: str, column: str) -> bool {
    if table not in _KNOWN_TABLES {
        raise ValueError(f"Unknown table: {table}");
    }
    cursor: any = conn.execute(f"PRAGMA table_info({table})");
    columns: any = [row[1] if isinstance(row, `tuple) else row["name"] for row in cursor];
    return column in columns;
}

impl _table_exists(conn: sqlite3.Connection, table: str) -> bool {
    if table not in _KNOWN_TABLES {
        raise ValueError(f"Unknown table: {table}");
    }
    row: any = conn.execute(
        "SELECT count(*) FROM sqlite_master WHERE type IN ('table', 'view') AND name = ?", (table,)
    ).fetchone();
    return operator.gt(row[0], 0);
}

impl ensure_nodes_fts_state(conn: sqlite3.Connection) {
    name: any;
    columns: any = ", ".join(f"{name} TEXT" for name in NODES_FTS_COLUMNS);
    conn.execute(
        f"CREATE TABLE IF NOT EXISTS {NODES_FTS_STATE_TABLE} (  node_id INTEGER PRIMARY KEY, {columns})",
    );
    for name in NODES_FTS_COLUMNS {
        if not _has_column(conn, NODES_FTS_STATE_TABLE, name) {
            _apply(
                conn,
                f"ALTER TABLE {NODES_FTS_STATE_TABLE} ADD COLUMN {name} TEXT",
                what=f"{NODES_FTS_STATE_TABLE}.{name}",
            );
        }
    }
    conn.execute(
        f"CREATE INDEX IF NOT EXISTS idx_nodes_fts_state_file ON {NODES_FTS_STATE_TABLE}(file_path)"
    );
}

impl _migrate_v2(conn: sqlite3.Connection) {
    if not _has_column(conn, "nodes", "signature") {
        if _apply(conn, "ALTER TABLE nodes ADD COLUMN signature TEXT", what="nodes.signature") {
            _progress("Migration v2: added 'signature' column to nodes");
        }
    }
}

impl _migrate_v3(conn: sqlite3.Connection) {
    conn.execute(
        "\n        CREATE TABLE IF NOT EXISTS flows (\n            id INTEGER PRIMARY KEY AUTOINCREMENT,\n            name TEXT NOT NULL,\n            entry_point_id INTEGER NOT NULL,\n            depth INTEGER NOT NULL,\n            node_count INTEGER NOT NULL,\n            file_count INTEGER NOT NULL,\n            criticality REAL NOT NULL DEFAULT 0.0,\n            path_json TEXT NOT NULL,\n            created_at TEXT NOT NULL DEFAULT (datetime('now')),\n            updated_at TEXT NOT NULL DEFAULT (datetime('now'))\n        )\n    ",
    );
    conn.execute(
        "\n        CREATE TABLE IF NOT EXISTS flow_memberships (\n            flow_id INTEGER NOT NULL,\n            node_id INTEGER NOT NULL,\n            position INTEGER NOT NULL,\n            PRIMARY KEY (flow_id, node_id)\n        )\n    ",
    );
    conn.execute("CREATE INDEX IF NOT EXISTS idx_flows_criticality ON flows(criticality DESC)");
    conn.execute("CREATE INDEX IF NOT EXISTS idx_flows_entry ON flows(entry_point_id)");
    conn.execute(
        "CREATE INDEX IF NOT EXISTS idx_flow_memberships_node ON flow_memberships(node_id)"
    );
    _progress("Migration v3: created flows and flow_memberships tables");
}

impl _migrate_v4(conn: sqlite3.Connection) {
    conn.execute(
        "\n        CREATE TABLE IF NOT EXISTS communities (\n            id INTEGER PRIMARY KEY AUTOINCREMENT,\n            name TEXT NOT NULL,\n            level INTEGER NOT NULL DEFAULT 0,\n            parent_id INTEGER,\n            cohesion REAL NOT NULL DEFAULT 0.0,\n            size INTEGER NOT NULL DEFAULT 0,\n            dominant_language TEXT,\n            description TEXT,\n            created_at TEXT NOT NULL DEFAULT (datetime('now'))\n        )\n    ",
    );
    if not _has_column(conn, "nodes", "community_id") {
        if _apply(
            conn, "ALTER TABLE nodes ADD COLUMN community_id INTEGER", what="nodes.community_id"
        ) {
            _progress("Migration v4: added 'community_id' column to nodes");
        }
    }
    conn.execute("CREATE INDEX IF NOT EXISTS idx_nodes_community ON nodes(community_id)");
    conn.execute("CREATE INDEX IF NOT EXISTS idx_communities_parent ON communities(parent_id)");
    conn.execute(
        "CREATE INDEX IF NOT EXISTS idx_communities_cohesion ON communities(cohesion DESC)"
    );
    _progress("Migration v4: created communities table");
}

impl _migrate_v5(conn: sqlite3.Connection) {
    if not _table_exists(conn, "nodes_fts") {
        if _apply(
            conn,
            "\n            CREATE VIRTUAL TABLE nodes_fts USING fts5(\n                name, qualified_name, file_path, signature,\n                content='nodes', content_rowid='rowid',\n                tokenize='porter unicode61'\n            )\n            ",
            what="nodes_fts",
        ) {
            _progress("Migration v5: created nodes_fts FTS5 virtual table");
        }
    }
}

impl _migrate_v6(conn: sqlite3.Connection) {
    conn.execute(
        "\n        CREATE TABLE IF NOT EXISTS community_summaries (\n            community_id INTEGER PRIMARY KEY,\n            name TEXT NOT NULL,\n            purpose TEXT DEFAULT '',\n            key_symbols TEXT DEFAULT '[]',\n            risk TEXT DEFAULT 'unknown',\n            size INTEGER DEFAULT 0,\n            dominant_language TEXT DEFAULT '',\n            FOREIGN KEY (community_id) REFERENCES communities(id)\n        )\n    ",
    );
    conn.execute(
        "\n        CREATE TABLE IF NOT EXISTS flow_snapshots (\n            flow_id INTEGER PRIMARY KEY,\n            name TEXT NOT NULL,\n            entry_point TEXT NOT NULL,\n            critical_path TEXT DEFAULT '[]',\n            criticality REAL DEFAULT 0.0,\n            node_count INTEGER DEFAULT 0,\n            file_count INTEGER DEFAULT 0,\n            FOREIGN KEY (flow_id) REFERENCES flows(id)\n        )\n    ",
    );
    conn.execute(
        "\n        CREATE TABLE IF NOT EXISTS risk_index (\n            node_id INTEGER PRIMARY KEY,\n            qualified_name TEXT NOT NULL,\n            risk_score REAL DEFAULT 0.0,\n            caller_count INTEGER DEFAULT 0,\n            test_coverage TEXT DEFAULT 'unknown',\n            security_relevant INTEGER DEFAULT 0,\n            last_computed TEXT DEFAULT '',\n            FOREIGN KEY (node_id) REFERENCES nodes(id)\n        )\n    ",
    );
    conn.execute("CREATE INDEX IF NOT EXISTS idx_risk_index_score ON risk_index(risk_score DESC)");
    _progress(
        "Migration v6: created summary tables (community_summaries, flow_snapshots, risk_index)"
    );
}

impl _migrate_v7(conn: sqlite3.Connection) {
    conn.execute(
        "CREATE INDEX IF NOT EXISTS idx_edges_target_kind ON edges(target_qualified, kind)"
    );
    conn.execute(
        "CREATE INDEX IF NOT EXISTS idx_edges_source_kind ON edges(source_qualified, kind)"
    );
    _progress("Migration v7: added compound edge indexes");
}

impl _migrate_v8(conn: sqlite3.Connection) {
    if not _has_column(conn, "edges", "line") {
        _progress("Migration v8: skipped, edges.line is not present");
        return;
    }
    conn.execute(
        "\n        CREATE INDEX IF NOT EXISTS idx_edges_composite\n        ON edges(kind, source_qualified, target_qualified, file_path, line)\n    ",
    );
    _progress("Migration v8: created composite edge index");
}

impl _migrate_v9(conn: sqlite3.Connection) {
    if not _has_column(conn, "edges", "confidence") {
        _apply(
            conn,
            "ALTER TABLE edges ADD COLUMN confidence REAL DEFAULT 1.0",
            what="edges.confidence",
        );
    }
    if not _has_column(conn, "edges", "confidence_tier") {
        _apply(
            conn,
            "ALTER TABLE edges ADD COLUMN confidence_tier TEXT DEFAULT 'EXTRACTED'",
            what="edges.confidence_tier",
        );
    }
    _progress("Migration v9: added edge confidence columns");
}

impl _migrate_v10(conn: sqlite3.Connection) {
    if not _has_column(conn, "nodes", "symbol") {
        _apply(conn, "ALTER TABLE nodes ADD COLUMN symbol TEXT", what="nodes.symbol");
    }
    conn.execute(
        "UPDATE nodes SET symbol = CASE WHEN instr(qualified_name, '::') > 0 THEN substr(qualified_name, instr(qualified_name, '::') + 2) ELSE qualified_name END",
    );
    conn.execute("CREATE INDEX IF NOT EXISTS idx_nodes_symbol ON nodes(symbol)");
    _progress("Migration v10: added indexed nodes.symbol column");
}

impl target_resolution_expr(alias: str = "edges") -> str {
    if alias not in _ALLOWED_EDGE_ALIASES {
        raise ValueError(f"Unsupported edges alias: {alias!r}");
    }
    return _TARGET_RESOLUTION_TEMPLATE.format(alias=alias);
}

impl _migrate_v11(conn: sqlite3.Connection) {
    if not _has_column(conn, "edges", "target_resolution") {
        _apply(
            conn,
            "ALTER TABLE edges ADD COLUMN target_resolution TEXT",
            what="edges.target_resolution",
        );
    }
    placeholders: any = ", ".join("?" for _ in TARGET_RESOLUTION_KINDS);
    conn.execute(
        f"UPDATE edges SET target_resolution = {TARGET_RESOLUTION_EXPR} WHERE kind IN ({placeholders})",
        TARGET_RESOLUTION_KINDS,
    );
    conn.execute(
        "CREATE INDEX IF NOT EXISTS idx_edges_kind_target_resolution ON edges(kind, target_resolution)",
    );
    _progress("Migration v11: added indexed edges.target_resolution column");
}

impl _migrate_v12(conn: sqlite3.Connection) {
    conn.execute(
        "CREATE TABLE IF NOT EXISTS nodes_fts_state (  node_id INTEGER PRIMARY KEY,  name TEXT,  qualified_name TEXT,  file_path TEXT,  signature TEXT)",
    );
    conn.execute(
        "CREATE INDEX IF NOT EXISTS idx_nodes_fts_state_file ON nodes_fts_state(file_path)"
    );
    _progress("Migration v12: added nodes_fts_state index mirror");
}

impl _migrate_v13(conn: sqlite3.Connection) {
    node_index_tokens = lazy("graph", "node_index_tokens");

    if not _has_column(conn, "nodes", "docstring") {
        _apply(conn, "ALTER TABLE nodes ADD COLUMN docstring TEXT", what="nodes.docstring");
    }
    if not _has_column(conn, "nodes", "name_tokens") {
        _apply(conn, "ALTER TABLE nodes ADD COLUMN name_tokens TEXT", what="nodes.name_tokens");
    }
    conn.execute(
        "UPDATE nodes SET docstring = substr(trim(json_extract(extra, '$.docstring')), 1, 400) WHERE docstring IS NULL AND extra IS NOT NULL AND json_valid(extra) AND json_type(extra, '$.docstring') = 'text'",
    );
    pending: list[tuple[str, int]] = [];
    cursor: any = conn.execute("SELECT id, kind, name, parent_name, file_path FROM nodes");
    for row in cursor.fetchall() {
        node_id: any;
        kind: any;
        name: any;
        parent: any;
        path: any;
        (node_id, kind, name, parent, path) = (row[0], row[1], row[2], row[3], row[4]);
        pending.append((node_index_tokens(kind, name, parent, path), node_id));
        if len(pending) >= _BACKFILL_BATCH {
            conn.executemany("UPDATE nodes SET name_tokens = ? WHERE id = ?", pending);
            pending.clear();
        }
    }
    if pending {
        conn.executemany("UPDATE nodes SET name_tokens = ? WHERE id = ?", pending);
    }
    with _write_lock_held(conn) {
        conn.execute("DROP TABLE IF EXISTS nodes_fts");
        conn.execute(NODES_FTS_DDL);
        conn.execute("INSERT INTO nodes_fts(nodes_fts) VALUES('rebuild')");
        ensure_nodes_fts_state(conn);
        columns: any = ", ".join(NODES_FTS_COLUMNS);
        conn.execute(f"DELETE FROM {NODES_FTS_STATE_TABLE}");
        conn.execute(
            f"INSERT INTO {NODES_FTS_STATE_TABLE} (node_id, {columns}) SELECT id, {columns} FROM nodes",
        );
        conn.execute(
            "INSERT OR REPLACE INTO metadata (key, value) VALUES (?, ?)",
            (FTS_STATE_METADATA_KEY, FTS_STATE_VERSION),
        );
    }
    _progress("Migration v13: indexed nodes.docstring and nodes.name_tokens");
}

impl _migrate_v14(conn: sqlite3.Connection) {
    updated: any = conn.execute(
        "UPDATE nodes SET file_hash = '' WHERE kind = 'File' AND language = 'ruby' AND file_hash IS NOT NULL AND file_hash != ''",
    ).rowcount;
    _progress("Migration v14: invalidated %d Ruby file(s) for re-keying on next update", updated);
}

impl _migrate_v15(conn: sqlite3.Connection) {
    for statement in (
        "DROP TABLE IF EXISTS community_summaries",
        "DROP TABLE IF EXISTS flow_snapshots",
        "DROP TABLE IF EXISTS risk_index",
        "DROP INDEX IF EXISTS idx_nodes_qualified",
        "DROP INDEX IF EXISTS idx_edges_source",
        "DROP INDEX IF EXISTS idx_edges_target",
    ) {
        conn.execute(statement);
    }
    _progress("Migration v15: dropped unread tables and covered indexes");
}

impl _run_one(conn: sqlite3.Connection, version: int) {
    last: sqlite3.Error | None = None;
    for attempt in range(_MAX_ATTEMPTS) {
        try {
            MIGRATIONS[version](conn);
            _set_schema_version(conn, version);
            conn.commit();
            return;
        } except sqlite3.OperationalError as exc {
            conn.rollback();
            if not _matches(exc, _CONTENDED) {
                logger.error("Migration v%d failed", version, exc_info=True);
                raise;
            }
            last = exc;
            jitter: any = 0.5 + os.getpid() % 101 / 100.0;
            time.sleep(_RETRY_BASE_SECONDS * 2 ** attempt * jitter);
        } except sqlite3.Error {
            conn.rollback();
            logger.error("Migration v%d failed, rolling back", version, exc_info=True);
            raise;
        }
    }
    logger.error("Migration v%d could not get the write lock", version);
    raise last if last is not None else sqlite3.OperationalError("database is locked");
}

impl _is_new_database(conn: sqlite3.Connection, current: int) -> bool {
    if current > 1 or not _table_exists(conn, "nodes") {
        return False;
    }
    return conn.execute("SELECT 1 FROM nodes LIMIT 1").fetchone() is None;
}

impl run_migrations(conn: sqlite3.Connection) {
    current: any = get_schema_version(conn);
    if current >= LATEST_VERSION {
        return;
    }

    new_database: any = _is_new_database(conn, current);
    token: any = _progress_level.set(logging.DEBUG if new_database else logging.INFO);
    try {
        _progress("Schema version %d -> %d: running migrations", current, LATEST_VERSION);

        for version in sorted(MIGRATIONS.keys()) {
            if version <= current {
                continue;
            }
            _progress("Running migration v%d", version);
            _run_one(conn, version);
        }

        _progress("Migrations complete, now at schema version %d", LATEST_VERSION);
    } finally {
        _progress_level.reset(token);
    }
    if new_database {
        logger.info("Created graph database (schema v%d).", LATEST_VERSION);
    } elif `any(
        operator.lt(current, version) and operator.le(version, LATEST_VERSION)
        for version in _REBUILD_AFTER,
    ) {
        logger.info(_REBUILD_HINT, LATEST_VERSION);
    }
}
