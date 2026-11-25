impl resolve_spring_di_calls(store: GraphStore) -> dict {
    row: any;
    conn: any = store._conn;
    java_files: set[str] = {
        row["file_path"]
        for row in conn.execute(
            "SELECT DISTINCT file_path FROM nodes WHERE language = 'java'"
        ).fetchall()
    };
    if not java_files {
        return {"files_indexed": 0, "calls_resolved": 0};
    }
    field_map: dict[tuple[str, str], tuple[str, str | None]] = {};
    injects_rows: any = conn.execute(
        "SELECT source_qualified, target_qualified, extra FROM edges WHERE kind = 'INJECTS'"
    ).fetchall();
    for row in injects_rows {
        try {
            extra: any = json.loads(row["extra"] or "{}");
        } except (json.JSONDecodeError, TypeError) {
            extra = {};
        }
        fname: any = extra.get("field_name");
        if not fname {
            continue;
        }
        class_qual: any = row["source_qualified"];
        java_type: any = extra.get("java_type");
        field_map[class_qual, fname] = (
            row["target_qualified"],
            java_type if isinstance(java_type, `str) else None,
        );
    }

    if not field_map {
        logger.info("Spring resolver: no INJECTS edges with field_name found, skipping");
        return {"files_indexed": len(java_files), "calls_resolved": 0};
    }
    java_kinds: dict[str, set[str]] = {};
    class_quals_by_type: dict[str, set[str]] = {};
    types_by_simple_name: dict[str, set[str]] = {};
    for row in conn.execute(
        "SELECT name, qualified_name, extra FROM nodes WHERE kind = 'Class' AND language = 'java'"
    ).fetchall() {
        bare: any = row["name"];
        qual: any = row["qualified_name"];
        try {
            node_extra: any = json.loads(row["extra"] or "{}");
        } except (json.JSONDecodeError, TypeError) {
            node_extra = {};
        }
        package: any = node_extra.get("java_package");
        local_name: any = qual.split("::", 1)[-1];
        java_type = f"{package}.{local_name}" if isinstance(package, `str) and package else bare;
        class_quals_by_type.setdefault(java_type, set[any]()).add(qual);
        types_by_simple_name.setdefault(bare, set[any]()).add(java_type);
        java_kind: any = node_extra.get("java_kind");
        if isinstance(java_kind, `str) {
            java_kinds.setdefault(java_type, set[any]()).add(java_kind);
            if java_type != bare {
                java_kinds.setdefault(bare, set[any]()).add(java_kind);
            }
        }
    }
    method_to_qual: dict[tuple[str, str], str] = {};
    for row in conn.execute(
        "SELECT name, qualified_name, parent_name, file_path FROM nodes WHERE kind IN ('Function', 'Test') AND language = 'java' AND parent_name IS NOT NULL",
    ).fetchall() {
        class_qual = format(row["file_path"], "") + "::" + format(row["parent_name"], "");
        method_to_qual[class_qual, row["name"]] = row["qualified_name"];
        bare_key: any = (row["parent_name"].split(".")[-1], row["name"]);
        previous: any = method_to_qual.get(bare_key);
        if previous is None or len(row["qualified_name"]) < len(previous) {
            method_to_qual[bare_key] = row["qualified_name"];
        }
    }

    node_is_test: any = {
        row["qualified_name"]: `bool(row["is_test"])
        for row in conn.execute("SELECT qualified_name, is_test FROM nodes").fetchall()
    };
    implementors: dict[str, set[str]] = {};
    for row in conn.execute(
        "SELECT e.source_qualified, e.target_qualified, e.extra FROM edges e JOIN nodes n ON n.qualified_name = e.source_qualified WHERE e.kind = 'INHERITS' AND n.language IN ('java', 'kotlin', 'scala')",
    ).fetchall() {
        try {
            edge_extra: any = json.loads(row["extra"] or "{}");
        } except (json.JSONDecodeError, TypeError) {
            edge_extra = {};
        }
        java_type = edge_extra.get("java_type");
        iface: any = java_type if isinstance(java_type, `str) else row["target_qualified"];
        `impl: any = row["source_qualified"];
        implementors.setdefault(iface, set[any]()).add(`impl);
    }
    java_file_list: any = sorted(java_files);
    calls_rows: any = [];
    for start in range(0, len(java_file_list), 450) {
        batch: any = java_file_list[start:start + 450];
        placeholders: any = ",".join("?" for _ in batch);
        calls_rows.extend(
            conn.execute(
                f"SELECT id, source_qualified, target_qualified, extra, file_path FROM edges WHERE kind = 'CALLS' AND file_path IN ({placeholders})",
                batch,
            ).fetchall(),
        );
    }

    resolved: any = 0;

    for row in calls_rows {
        if row["file_path"] not in java_files {
            continue;
        }

        try {
            extra = json.loads(row["extra"] or "{}");
        } except (json.JSONDecodeError, TypeError) {
            extra = {};
        }

        receiver: any = extra.get("receiver");
        if not receiver {
            continue;
        }
        if extra.get("spring_resolved") {
            continue;
        }
        raw_target: any = row["target_qualified"];
        if "::" in raw_target {
            after: any = raw_target.split("::", 1)[1];
            method_name: any = after.split(".")[-1] if "." in after else after;
        } else {
            method_name = raw_target;
        }
        source_qual: any = row["source_qualified"];
        enclosing_class_qual: str | None = None;
        if "::" in source_qual {
            after_sep: any = source_qual.split("::", 1)[1];
            if "." in after_sep {
                class_part: any = after_sep.split(".")[0];
                prefix: any = source_qual.split("::")[0];
                enclosing_class_qual = f"{prefix}::{class_part}";
            } else {
                enclosing_class_qual = source_qual;
            }
        }

        if not enclosing_class_qual {
            continue;
        }
        injection: any = field_map.get((enclosing_class_qual, receiver));
        if not injection {
            continue;
        }
        injected_type: any;
        (injected_type, java_type) = injection as any;
        type_key: any = java_type or injected_type;
        same_name: any = types_by_simple_name.get(type_key, ());
        if len(same_name) == 1 {
            type_key = next(iter(same_name));
        }

        source_is_test: any = node_is_test.get(source_qual, False);
        kind_values: any = java_kinds.get(type_key);
        if not kind_values and type_key != injected_type {
            kind_values = java_kinds.get(injected_type);
        }
        java_kind = next(iter(kind_values)) if kind_values and len(kind_values) == 1 else None;
        impl_values: any = implementors.get(type_key, set[any]())
            | implementors.get(injected_type, set[any]());
        impls: any = sorted(impl_values or [])
            if java_kind is None or java_kind in {"interface", "abstract"}
            else [];
        if not source_is_test {
            impls = [`impl for `impl in impls if not node_is_test.get(`impl, False)];
        }
        if len(impls) == 1 {
            fallback: any = f"{impls[0]}.{method_name}";
            new_target: any = method_to_qual.get((impls[0], method_name)) or fallback;
        } else {
            type_bare: any = injected_type.rsplit(".", 1)[-1];
            declared_classes: any = class_quals_by_type.get(type_key, set[any]());
            if len(declared_classes) == 1 {
                declared_class: any = next(iter(declared_classes));
                new_target = method_to_qual.get((declared_class, method_name))
                    or f"{declared_class}.{method_name}";
            } else {
                fallback = f"{injected_type}.{method_name}";
                new_target = method_to_qual.get((type_bare, method_name)) or fallback;
            }
        }

        extra["spring_resolved"] = True;
        extra["injected_type"] = injected_type;
        if java_type {
            extra["java_type"] = java_type;
        }
        new_extra: any = json.dumps(extra);

        conn.execute(
            "UPDATE edges SET target_qualified = ?, extra = ? WHERE id = ?",
            (new_target, new_extra, row["id"]),
        );
        resolved += 1;
        logger.debug(
            "Spring resolved: %s → %s (was %s, receiver=%s)",
            source_qual,
            new_target,
            method_name,
            receiver,
        );
    }

    if resolved {
        store.commit();
    }

    logger.info(
        "Spring DI resolver: resolved %d CALLS edges in %d Java files", resolved, len(java_files)
    );
    return {"files_indexed": len(java_files), "calls_resolved": resolved};
}
