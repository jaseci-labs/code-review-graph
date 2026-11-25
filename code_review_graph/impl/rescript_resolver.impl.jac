impl resolve_rescript_cross_module(store: GraphStore) -> dict {
    conn: any = store._conn;

    has_rescript: any = conn.execute(
        "SELECT 1 FROM (SELECT 1 FROM nodes WHERE file_path LIKE '%.res' OR file_path LIKE '%.resi' OR file_path LIKE '%.RES' OR file_path LIKE '%.RESI' LIMIT 1) UNION ALL SELECT 1 FROM (SELECT 1 FROM edges WHERE file_path LIKE '%.res' OR file_path LIKE '%.resi' OR file_path LIKE '%.RES' OR file_path LIKE '%.RESI' LIMIT 1) LIMIT 1",
    ).fetchone();
    if has_rescript is None {
        return {"files_indexed": 0, "calls_resolved": 0, "imports_resolved": 0};
    }
    basename_to_path: dict[str, str] = {};
    rescript_files: set[str] = set[any]();
    for file_path in store.get_all_files() {
        p: any = Path(file_path);
        suffix: any = p.suffix.lower();
        if suffix not in (".res", ".resi") {
            continue;
        }
        rescript_files.add(file_path);
        stem: any = p.stem;
        existing: any = basename_to_path.get(stem);
        if existing is None or existing.lower().endswith(".resi") {
            basename_to_path[stem] = file_path;
        }
    }

    if not basename_to_path {
        return {"files_indexed": 0, "calls_resolved": 0, "imports_resolved": 0};
    }
    opens_by_file: dict[str, list[str]] = {};
    imports_rows: any = conn.execute(
        "SELECT source_qualified, target_qualified, file_path, extra FROM edges WHERE kind = 'IMPORTS_FROM'",
    ).fetchall();
    row: any;
    for row in imports_rows {
        fp: any = row["file_path"];
        if fp not in rescript_files {
            continue;
        }
        try {
            extra: any = json.loads(row["extra"] or "{}");
        } except (json.JSONDecodeError, TypeError) {
            extra = {};
        }
        kind: any = extra.get("rescript_import_kind");
        if kind in ("open", "include") {
            `root: any = row["target_qualified"].split(".", 1)[0];
            opens_by_file.setdefault(fp, []).append(`root);
        }
    }
    call_rows: any = conn.execute(
        "SELECT id, source_qualified, target_qualified, file_path, extra FROM edges WHERE kind = 'CALLS'",
    ).fetchall();

    call_updates: list[tuple[str, int]] = [];
    open_call_updates: list[tuple[str, str, int]] = [];
    for row in call_rows {
        target: any = row["target_qualified"];
        if "::" in target {
            continue;
        }

        resolved: any;
        opened: any;
        (resolved, opened) = _resolve_call_target(
            target, row["file_path"], basename_to_path, opens_by_file, store
        ) as any;
        if not resolved or resolved == target {
            continue;
        }
        if opened is None {
            call_updates.append((resolved, row["id"]));
            continue;
        }
        try {
            call_extra: any = json.loads(row["extra"] or "{}");
        } except (json.JSONDecodeError, TypeError) {
            call_extra = {};
        }
        if not isinstance(call_extra, `dict) {
            call_extra = {};
        }
        call_extra["rescript_open_module"] = opened;
        open_call_updates.append((resolved, json.dumps(call_extra), row["id"]));
    }
    import_updates: list[tuple[str, int]] = [];
    import_rows_full: any = conn.execute(
        "SELECT id, target_qualified, file_path FROM edges WHERE kind = 'IMPORTS_FROM'"
    ).fetchall();
    for row in import_rows_full {
        target = row["target_qualified"];
        if target in rescript_files {
            continue;
        }
        if "/" in target or "\\" in target {
            continue;
        }
        `root = target.split(".", 1)[0];
        file_target: any = basename_to_path.get(`root);
        if file_target and file_target != target {
            import_updates.append((file_target, row["id"]));
        }
    }

    all_updates: any = call_updates + import_updates;
    if all_updates or open_call_updates {
        store._begin_immediate();
        conn.executemany("UPDATE edges SET target_qualified = ? WHERE id = ?", all_updates);
        conn.executemany(
            "UPDATE edges SET target_qualified = ?, extra = ? WHERE id = ?", open_call_updates
        );
        store.commit();
        store._invalidate_cache();
    }

    result: any = {
        "files_indexed": len(basename_to_path),
        "calls_resolved": len(call_updates) + len(open_call_updates),
        "imports_resolved": len(import_updates),
    };
    logger.info("ReScript cross-module resolution: %s", result);
    return result;
}

impl _resolve_call_target(
    target: str,
    file_path: str,
    basename_to_path: dict[str, str],
    opens_by_file: dict[str, list[str]],
    store: GraphStore,
) -> tuple[str | None, str | None] {
    if "." in target {
        head: any;
        _: any;
        rest: any;
        (head, _, rest) = target.partition(".") as any;
        target_file: any = basename_to_path.get(head);
        if target_file is None {
            return (None, None);
        }
        candidate: any = _pick_existing_qualified(target_file, rest, store);
        return (candidate, None);
    }
    for opened in opens_by_file.get(file_path, []) {
        target_file = basename_to_path.get(opened);
        if target_file is None {
            continue;
        }
        candidate = f"{target_file}::{target}";
        if store.get_node(candidate) is not None {
            return (candidate, opened);
        }
    }
    return (None, None);
}

impl _pick_existing_qualified(target_file: str, rest: str, store: GraphStore) -> str | None {
    direct: any = f"{target_file}::{rest}";
    if store.get_node(direct) is not None {
        return direct;
    }
    parts: any = rest.split(".");
    while len(parts) > 1 {
        parts.pop();
        candidate: any = f"{target_file}::{".".join(parts)}";
        if store.get_node(candidate) is not None {
            return candidate;
        }
    }
    first: any = rest.split(".", 1)[0];
    candidate = f"{target_file}::{first}";
    if store.get_node(candidate) is not None {
        return candidate;
    }
    return None;
}
