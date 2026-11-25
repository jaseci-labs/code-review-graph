impl _ensure_fts_state_table(conn: sqlite3.Connection) -> None {
    ensure_nodes_fts_state(conn);
}

impl _table_exists(conn: sqlite3.Connection, name: str) -> bool {
    row: any = conn.execute(
        "SELECT count(*) FROM sqlite_master WHERE type IN ('table', 'view') AND name = ?", (name,)
    ).fetchone();
    return `bool(row and row[0]);
}

impl rebuild_fts_index(store: GraphStore) -> int {
    conn: any = store._conn;
    if conn.in_transaction {
        logger.warning("Rolling back uncommitted transaction before BEGIN IMMEDIATE");
        conn.rollback();
    }
    conn.execute("BEGIN IMMEDIATE");
    try {
        conn.execute("DROP TABLE IF EXISTS nodes_fts");
        conn.execute(NODES_FTS_DDL);
        conn.execute("INSERT INTO nodes_fts(nodes_fts) VALUES('rebuild')");
        _ensure_fts_state_table(conn);
        conn.execute(f"DELETE FROM {_FTS_STATE_TABLE}");
        conn.execute(
            f"INSERT INTO {_FTS_STATE_TABLE} (node_id, {_FTS_COLUMN_SQL}) SELECT id, {_FTS_COLUMN_SQL} FROM nodes",
        );
        conn.execute(
            "INSERT OR REPLACE INTO metadata (key, value) VALUES (?, ?)",
            (_FTS_STATE_METADATA_KEY, _FTS_STATE_VERSION),
        );

        conn.commit();
    } except BaseException {
        conn.rollback();
        raise;
    }

    count: any = conn.execute("SELECT count(*) FROM nodes_fts").fetchone()[0];
    logger.info("FTS index rebuilt: %d rows indexed", count);
    return count;
}

impl _stored_path_hints(file_paths: Sequence[str] | None) -> list[str] {
    if not file_paths {
        return [];
    }
    seen: dict[str, None] = {};
    for raw in file_paths {
        if not raw {
            continue;
        }
        seen.setdefault(normalize_file_path(raw), None);
    }
    return `list(seen);
}

impl _batched(values: list[Any]) -> list[list[Any]] {
    return [values[i:i + _FTS_SQL_BATCH] for i in range(0, len(values), _FTS_SQL_BATCH)];
}

impl _collect_delta_rowids(conn: sqlite3.Connection, paths: list[str]) -> set[int] {
    ids: set[int] = set[any]();
    ids.update(
        row[0]
        for row in conn.execute(
            f"SELECT n.id FROM nodes n LEFT JOIN {_FTS_STATE_TABLE} s ON s.node_id = n.id WHERE s.node_id IS NULL",
        ),
    );
    ids.update(
        row[0]
        for row in conn.execute(
            f"SELECT s.node_id FROM {_FTS_STATE_TABLE} s LEFT JOIN nodes n ON n.id = s.node_id WHERE n.id IS NULL",
        ),
    );

    if paths {
        for batch in _batched(paths) {
            placeholders: any = ",".join("?" * len(batch));
            ids.update(
                row[0]
                for row in conn.execute(
                    f"SELECT id FROM nodes WHERE file_path IN ({placeholders})", batch
                ),
            );
            ids.update(
                row[0]
                for row in conn.execute(
                    f"SELECT node_id FROM {_FTS_STATE_TABLE} WHERE file_path IN ({placeholders})",
                    batch,
                ),
            );
        }
    } else {
        drift: any = " OR ".join(f"n.{column} IS NOT s.{column}" for column in NODES_FTS_COLUMNS);
        ids.update(
            row[0]
            for row in conn.execute(
                f"SELECT n.id FROM nodes n JOIN {_FTS_STATE_TABLE} s ON s.node_id = n.id WHERE {drift}",
            ),
        );
    }

    return ids;
}

impl _apply_fts_delta(conn: sqlite3.Connection, rowids: list[int]) -> tuple[int, int] {
    removed: any = 0;
    added: any = 0;
    delete_sql: any = f"INSERT INTO nodes_fts(nodes_fts, rowid, {_FTS_COLUMN_SQL}) VALUES('delete', ?, {_FTS_COLUMN_PLACEHOLDERS})";
    insert_sql: any = f"INSERT INTO nodes_fts(rowid, {_FTS_COLUMN_SQL}) VALUES(?, {_FTS_COLUMN_PLACEHOLDERS})";
    state_sql: any = f"INSERT INTO {_FTS_STATE_TABLE} (node_id, {_FTS_COLUMN_SQL}) VALUES(?, {_FTS_COLUMN_PLACEHOLDERS})";

    for batch in _batched(rowids) {
        placeholders: any = ",".join("?" * len(batch));
        old_rows: any = [
            `tuple(row)
            for row in conn.execute(
                f"SELECT node_id, {_FTS_COLUMN_SQL} FROM {_FTS_STATE_TABLE} WHERE node_id IN ({placeholders})",
                batch,
            )
        ];
        if old_rows {
            conn.executemany(delete_sql, old_rows);
            conn.execute(
                f"DELETE FROM {_FTS_STATE_TABLE} WHERE node_id IN ({placeholders})", batch
            );
            removed += len(old_rows);
        }

        new_rows: any = [
            `tuple(row)
            for row in conn.execute(
                f"SELECT id, {_FTS_COLUMN_SQL} FROM nodes WHERE id IN ({placeholders})", batch
            )
        ];
        if new_rows {
            conn.executemany(insert_sql, new_rows);
            conn.executemany(state_sql, new_rows);
            added += len(new_rows);
        }
    }

    return (removed, added);
}

impl update_fts_index(
    store: GraphStore,
    file_paths: Sequence[str] | None = None,
    *,
    _out_mode: Optional[list[str]] = None,
) -> int {
    conn: any = store._conn;

    def _rebuild -> int {
        if _out_mode is not None {
            _out_mode.append("rebuild");
        }
        return rebuild_fts_index(store);
    }

    if not _table_exists(conn, "nodes_fts") or not _table_exists(conn, _FTS_STATE_TABLE) {
        return _rebuild();
    }

    if store.get_metadata(_FTS_STATE_METADATA_KEY) != _FTS_STATE_VERSION {
        return _rebuild();
    }

    total_nodes: any = conn.execute("SELECT count(*) FROM nodes").fetchone()[0];
    state_rows: any = conn.execute(f"SELECT count(*) FROM {_FTS_STATE_TABLE}").fetchone()[0];
    if total_nodes and not state_rows {
        return _rebuild();
    }

    delta_ids: any = _collect_delta_rowids(conn, _stored_path_hints(file_paths));
    rebuild_threshold: any = max(_FTS_DELTA_MIN_ROWS, `int(total_nodes * _FTS_DELTA_MAX_RATIO));
    if len(delta_ids) >= rebuild_threshold {
        return _rebuild();
    }

    if _out_mode is not None {
        _out_mode.append("delta");
    }

    if delta_ids {
        if conn.in_transaction {
            logger.warning("Rolling back uncommitted transaction before BEGIN IMMEDIATE");
            conn.rollback();
        }
        conn.execute("BEGIN IMMEDIATE");
        try {
            removed: any;
            added: any;
            (removed, added) = _apply_fts_delta(conn, sorted(delta_ids)) as any;
            conn.commit();
        } except sqlite3.DatabaseError as exc {
            conn.rollback();
            logger.warning("FTS delta failed, rebuilding index: %s", exc);
            return _rebuild();
        } except BaseException {
            conn.rollback();
            raise;
        }
        logger.info("FTS index delta: %d entries removed, %d indexed", removed, added);
    }
    return total_nodes;
}

impl extract_query_identifiers(query: str) -> list[str] {
    found: list[str] = [];
    seen: set[str] = set[any]();
    for pat in (_DOTTED_IDENT_RE, _SNAKE_IDENT_RE, _PASCAL_IDENT_RE) {
        for `match in pat.findall(query) {
            lo: any = `match.lower();
            if lo not in seen and len(lo) >= 3 {
                seen.add(lo);
                found.append(lo);
            }
        }
    }
    return found;
}

impl detect_query_kind_boost(query: str) -> dict[str, Any] {
    boosts: dict[str, Any] = {};

    if not query or not query.strip() {
        return boosts;
    }

    q: any = query.strip();
    if re.match("^[A-Z][a-z]", q) and not q.isupper() {
        boosts["Class"] = 1.5;
        boosts["Type"] = 1.5;
    }
    if "_" in q and re.search("[a-zA-Z]", q) {
        boosts["Function"] = 1.5;
    }
    if "." in q {
        boosts["_qualified"] = 2.0;
    }
    idents: any = extract_query_identifiers(q);
    if idents {
        boosts["_qualified_identifiers"] = idents;
    }
    if _EXACT_IDENT_QUERY_RE.match(q) {
        boosts["_exact_name"] = q.lower();
    }

    return boosts;
}

impl rrf_merge(*result_lists_: list[tuple[int, float]], k: int = 60) -> list[tuple[int, float]] {
    result_lists: any = tuple(result_lists_);
    scores: dict[int, float] = {};

    for result_list in result_lists {
        for (rank, (item_id, _score)) in enumerate(result_list) {
            scores[item_id] = scores.get(item_id, 0.0) + 1.0 / (k + rank + 1);
        }
    }

    merged: any = sorted(scores.items(), key=lambda (x) -> any { x[1] }, reverse=True);
    return merged;
}

impl _quote_term(text: str) -> str {
    return "\"" + text.replace("\"", "\"\"") + "\"";
}

impl _alnum_count(text: str) -> int {
    return sum(1 for ch in text if ch.isalnum());
}

impl _split_query_terms(query: str) -> list[_QueryTerm] {
    terms: list[_QueryTerm];
    seen: set[str];
    phrases: list[str] = [];
    loose: list[str] = [];
    cursor: any = 0;
    for `match in _EXPLICIT_PHRASE_RE.finditer(query) {
        loose.extend(query[cursor:`match.start()].split());
        phrases.append(`match.group(1));
        cursor = `match.end();
    }
    loose.extend(query[cursor:].split());

    terms = [];
    seen = set[any]();

    def _add(text: str, expression: str, is_phrase: bool) -> None {
        key: any = text.lower();
        if key in seen {
            return;
        }
        seen.add(key);
        terms.append(_QueryTerm(key, expression, is_phrase));
    }

    for phrase in phrases {
        if _HAS_ALNUM_RE.search(phrase) {
            _add(phrase, _quote_term(phrase), True);
        }
    }
    for token in loose {
        if not _HAS_ALNUM_RE.search(token) {
            continue;
        }
        prefix: any = "*" if _alnum_count(token) >= _MIN_PREFIX_ALNUM else "";
        _add(token, _quote_term(token) + prefix, False);
    }
    return terms;
}

impl _rarity_key(term: _QueryTerm, position: int) -> tuple[int, int, int] {
    if term.is_phrase {
        return (0, 0, position);
    }
    return (1, -len(term.key), position);
}

impl _cap_terms(terms: list[_QueryTerm]) -> list[_QueryTerm] {
    if len(terms) <= _MAX_FTS_TERMS {
        return terms;
    }
    ranked: any = sorted(range(len(terms)), key=lambda (i) -> any { _rarity_key(terms[i], i) });
    return [terms[i] for i in sorted(ranked[:_MAX_FTS_TERMS])];
}

impl build_fts_queries(query: str) -> list[str] {
    if not query or not query.strip() {
        return [];
    }

    terms: any = _cap_terms(_split_query_terms(query));
    if not terms {
        return [];
    }
    expressions: any = [term.expression for term in terms];
    if len(expressions) == 1 {
        return [expressions[0]];
    }

    conjunction: any = " AND ".join(expressions);
    if `any(term.is_phrase for term in terms) {
        return [conjunction];
    }
    return [conjunction, " OR ".join(expressions)];
}

impl _covered_word_count(query_words: set[str], symbol_words: set[str]) -> int {
    word: any;
    covered: any = 0;
    for word_ in query_words {
        word = word_;
        if word in symbol_words {
            covered += 1;
        } elif len(word) >= _MIN_PREFIX_ALNUM
            and `any(other.startswith(word) for other in symbol_words)
        {
            covered += 1;
        }
    }
    return covered;
}

impl _fts_column_weights(conn: sqlite3.Connection) -> str {
    columns: any = [row[1] for row in conn.execute("PRAGMA table_info(nodes_fts)")];
    weights: any = [
        _FTS_COLUMN_WEIGHTS.get(`str(column), _FTS_DEFAULT_WEIGHT)
        for column in columns
    ];
    return ", ".join(f"{weight:.1f}" for weight in weights);
}

impl _fts_search(
    conn: sqlite3.Connection,
    query: str,
    limit: int = 50,
    kind: str | None = None,
    skip_json: bool = False,
) -> list[tuple[int, float]] {
    expressions: any = build_fts_queries(query);
    if not expressions {
        return [];
    }

    try {
        weights: any = _fts_column_weights(conn);
    } except sqlite3.OperationalError as exc {
        logger.warning("FTS5 index unavailable: %s", exc);
        return [];
    }
    conditions: any = ["nodes_fts MATCH ?"];
    filters: tuple[Any, ...] = ();
    if kind {
        conditions.append("nodes.kind = ?");
        filters = (kind,);
    } elif conn.execute(
        "SELECT 1 FROM nodes WHERE kind = ? LIMIT 1", (_UNSEARCHED_KIND,)
    ).fetchone() {
        conditions.append("nodes.kind != ?");
        filters = (_UNSEARCHED_KIND,);
    }
    if skip_json {
        conditions.append("nodes.language IS NOT 'json'");
    }
    if len(conditions) > 1 {
        sql: any = "SELECT nodes_fts.rowid, bm25(nodes_fts, "
            + format(weights, "")
            + ") AS score FROM nodes_fts CROSS JOIN nodes ON nodes.id = nodes_fts.rowid WHERE "
            + format(" AND ".join(conditions), "")
            + " ORDER BY score LIMIT ?";
    } else {
        sql = f"SELECT rowid, bm25(nodes_fts, {weights}) AS score FROM nodes_fts WHERE nodes_fts MATCH ? ORDER BY score LIMIT ?";
    }
    for expression in expressions {
        params: any = (expression, *filters, limit);
        try {
            rows: any = conn.execute(sql, params).fetchall();
        } except sqlite3.OperationalError as e {
            logger.warning("FTS5 search failed for %r: %s", expression, e);
            return [];
        }
        if rows {
            return [(row[0], -row[1]) for row in rows];
        }
    }
    return [];
}

impl _embedding_search(
    store: GraphStore,
    query: str,
    limit: int = 50,
    model: str | None = None,
    provider: str | None = None,
    kind: str | None = None,
) -> list[tuple[int, float]] {
    if store.read_only {
        return [];
    }
    try {
        EmbeddingStore = lazy("embeddings", "EmbeddingStore");
    } except ImportError {
        return [];
    }

    try {
        emb_store: any = EmbeddingStore(store.db_path, provider=provider, model=model);
        try {
            if not emb_store.available or emb_store.count() == 0 {
                return [];
            }

            if kind {
                of_kind: any = {
                    row[0]
                    for row in store._conn.execute(
                        "SELECT qualified_name FROM nodes WHERE kind = ?", (kind,)
                    )
                };
                results: any = [
                    hit
                    for hit in emb_store.search(query, limit=emb_store.count())
                    if hit[0] in of_kind
                ][:limit];
            } else {
                results = emb_store.search(query, limit=limit);
            }
            id_scores: list[tuple[int, float]] = [];
            for (qn, score) in results {
                `node: any = store.get_node(qn);
                if `node {
                    id_scores.append((`node.id, score));
                }
            }
            return id_scores;
        } finally {
            emb_store.close();
        }
    } except Exception as e {
        logger.warning("Embedding search failed: %s", e);
        return [];
    }
}

impl _keyword_search(
    conn: sqlite3.Connection, query: str, limit: int = 50, kind: str | None = None
) -> list[tuple[int, float]] {
    words: any = query.lower().split();
    if not words {
        return [];
    }

    conditions: list[str] = [];
    params: list[str | int] = [];
    for word in words {
        conditions.append("(LOWER(name) LIKE ? OR LOWER(qualified_name) LIKE ?)");
        params.extend([f"%{word}%", f"%{word}%"]);
    }
    if kind {
        conditions.append("kind = ?");
        params.append(kind);
    } else {
        conditions.append("kind != ?");
        params.append(_UNSEARCHED_KIND);
    }

    where: any = " AND ".join(conditions);
    params.append(limit);
    sql: any = f"SELECT id, name, qualified_name FROM nodes WHERE {where} LIMIT ?";

    try {
        rows: any = conn.execute(sql, params).fetchall();
    } except sqlite3.OperationalError {
        return [];
    }
    q_lower: any = query.lower();
    results: list[tuple[int, float]] = [];
    for row in rows {
        name_lower: any = row["name"].lower();
        if name_lower == q_lower {
            score: any = 3.0;
        } elif name_lower.startswith(q_lower) {
            score = 2.0;
        } else {
            score = 1.0;
        }
        results.append((row["id"], score));
    }

    results.sort(key=lambda (x) -> any { x[1] }, reverse=True);
    return results;
}

impl _has_json_intent(query: str, kind: Optional[str]) -> bool {
    return operator.eq(kind, "JsonPath")
        or query.lstrip().startswith("$")
        or ".json" in query.lower();
}

impl _fts_search_past_json(
    conn: sqlite3.Connection,
    query: str,
    results: list[tuple[int, float]],
    limit: int,
    kind: Optional[str] = None,
) -> list[tuple[int, float]] {
    if len(results) < limit {
        return results;
    }
    ids: any = [node_id for (node_id, _) in results];
    json_rows: any = 0;
    for start in range(0, len(ids), 450) {
        batch: any = ids[start:start + 450];
        placeholders: any = ",".join("?" for _ in batch);
        json_rows += conn.execute(
            f"SELECT count(*) FROM nodes WHERE language = 'json' AND id IN ({placeholders})", batch
        ).fetchone()[0];
    }
    if not json_rows {
        return results;
    }
    seen: any = `set(ids);
    others: any = [
        row
        for row in _fts_search(conn, query, limit=limit, kind=kind, skip_json=True)
        if row[0] not in seen
    ];
    if not others {
        return results;
    }
    return sorted(results + others, key=lambda (row) -> any { row[1] }, reverse=True);
}

impl hybrid_search(
    store: GraphStore,
    query: str,
    kind: Optional[str] = None,
    limit: int = 20,
    context_files: Optional[list[str]] = None,
    model: Optional[str] = None,
    provider: Optional[str] = None,
    _out_mode: Optional[list[str]] = None,
    repo_root: Optional[str | Path] = None,
    _out_ids: Optional[list[int]] = None,
) -> list[dict[str, Any]] {
    node_id: any;
    qn_lo: any;
    if not query or not query.strip() {
        if _out_mode is not None {
            _out_mode.append("none");
        }
        return [];
    }
    conn: any = store._conn;
    fetch_limit: any = limit * 3;
    fts_results: list[tuple[int, float]] = [];
    emb_results: list[tuple[int, float]] = [];
    try {
        fts_results = _fts_search(conn, query, limit=fetch_limit, kind=kind);
    } except Exception as e {
        logger.warning("FTS5 unavailable, will use fallback: %s", e);
    }
    emb_results = _embedding_search(
        store, query, limit=fetch_limit, model=model, provider=provider, kind=kind
    );
    if fts_results and not _has_json_intent(query, kind) {
        fts_results = _fts_search_past_json(conn, query, fts_results, fetch_limit, kind);
    }
    if fts_results or emb_results {
        lists_to_merge: any = [];
        if fts_results {
            lists_to_merge.append(fts_results);
        }
        if emb_results {
            lists_to_merge.append(emb_results);
        }
        merged: any = rrf_merge(*lists_to_merge);
        if _out_mode is not None {
            if fts_results and emb_results {
                _out_mode.append("hybrid");
            } elif fts_results {
                _out_mode.append("fts");
            } else {
                _out_mode.append("semantic");
            }
        }
    } else {
        keyword_results: any = _keyword_search(conn, query, limit=fetch_limit, kind=kind);
        if not keyword_results {
            if _out_mode is not None {
                _out_mode.append("none");
            }
            return [];
        }
        if _out_mode is not None {
            _out_mode.append("keyword");
        }
        merged = keyword_results;
    }
    kind_boosts: any = detect_query_kind_boost(query);
    context_set: any = {normalize_file_path(p) for p in context_files}
        if context_files
        else set[any]();

    query_words: any = identifier_words(query);
    test_intent: any = operator.eq(kind, "Test")
        or `bool({w.lower() for w in query_words} & _TEST_INTENT_WORDS);
    json_intent: any = _has_json_intent(query, kind);
    candidate_ids: any = [node_id for (node_id, _) in merged];
    node_rows: dict[int, Any] = {};
    batch_size: any = 450;
    for i in range(0, len(candidate_ids), batch_size) {
        batch: any = candidate_ids[i:i + batch_size];
        placeholders: any = ",".join("?" for _ in batch);
        rows: any = conn.execute(
            f"SELECT * FROM nodes WHERE id IN ({placeholders})", batch
        ).fetchall();
        row: any;
        for row in rows {
            node_rows[row["id"]] = row;
        }
    }
    boosted: list[tuple[int, float]] = [];
    for (node_id, score) in merged {
        row = node_rows.get(node_id);
        if not row {
            continue;
        }

        node_kind: any = row["kind"];
        file_path: any = row["file_path"];
        qualified_name: any = row["qualified_name"];

        boost: any = 1.0;
        if node_kind in kind_boosts {
            boost *= kind_boosts[node_kind];
        }
        if "_qualified" in kind_boosts and "." in query {
            if query.lower() in qualified_name.lower() {
                boost *= kind_boosts["_qualified"];
            }
        }
        idents: any = kind_boosts.get("_qualified_identifiers");
        if idents {
            qn_lo = qualified_name.lower();
            if `any(ident in qn_lo for ident in idents) {
                boost *= 2.0;
            }
        }
        if query_words {
            symbol: any = row["symbol"] if "symbol" in row.keys() else None;
            symbol_words: any = identifier_words(symbol or row["name"]);
            covered: any = _covered_word_count(query_words, symbol_words);
            if covered {
                boost *= 1.0 + _NAME_COVERAGE_BOOST * covered / len(query_words);
                if symbol_words == query_words {
                    boost *= _NAME_EXACT_COVERAGE_BOOST;
                }
            }
        }

        exact: any = kind_boosts.get("_exact_name");
        if exact {
            if row["name"].lower() == exact {
                boost *= _EXACT_NAME_BOOST;
            } elif qualified_name.lower().endswith("::" + exact) {
                boost *= _EXACT_SYMBOL_BOOST;
            }
        }
        if context_set and file_path in context_set {
            boost *= 1.5;
        }
        if row["language"] == "json" and not json_intent {
            boost *= _JSON_RANK_PENALTY;
        }

        if not test_intent {
            row_keys: any = row.keys();
            is_test: any = `bool(row["is_test"]) if "is_test" in row_keys else False;
            if not is_test and file_path {
                is_test = is_test_file(file_path, repo_root);
            }
            if is_test {
                boost *= _TEST_RANK_PENALTY;
            }
        }

        boosted.append((node_id, score * boost));
    }

    boosted.sort(key=lambda (x) -> any { x[1] }, reverse=True);
    results: list[dict[str, Any]] = [];
    for (node_id, final_score) in boosted {
        if len(results) >= limit {
            break;
        }

        row = node_rows.get(node_id);
        if not row {
            continue;
        }

        node_kind = row["kind"];
        if kind and node_kind != kind {
            continue;
        }
        if not kind and node_kind == _UNSEARCHED_KIND {
            continue;
        }

        results.append({
            "name": _sanitize_name(row["name"]),
            "qualified_name": _sanitize_name(row["qualified_name"]),
            "kind": node_kind,
            "file_path": row["file_path"],
            "line_start": row["line_start"],
            "line_end": row["line_end"],
            "language": row["language"] or "",
            "params": row["params"],
            "return_type": row["return_type"],
            "signature": row["signature"] if "signature" in row.keys() else None,
            "score": round(final_score, 6),
        });
        if _out_ids is not None {
            _out_ids.append(node_id);
        }
    }

    return results;
}
