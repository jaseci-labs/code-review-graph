impl resolve_temporal_calls(store: GraphStore) -> dict {
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
    temporal_interfaces: dict[str, str] = {};
    for row in conn.execute(
        "SELECT name, qualified_name, extra FROM nodes WHERE language = 'java' AND extra IS NOT NULL AND extra LIKE '%temporal_role%'",
    ).fetchall() {
        try {
            ex: any = json.loads(row["extra"] or "{}");
        } except (json.JSONDecodeError, TypeError) {
            ex = {};
        }
        if ex.get("temporal_role") in ("workflow_interface", "activity_interface") {
            temporal_interfaces[row["name"]] = row["qualified_name"];
        }
    }

    if not temporal_interfaces {
        logger.info("Temporal resolver: no Workflow/ActivityInterface nodes, skipping");
        return {"files_indexed": len(java_files), "calls_resolved": 0};
    }
    field_map: dict[tuple[str, str], str] = {};
    for row in conn.execute(
        "SELECT source_qualified, target_qualified, extra FROM edges WHERE kind = 'TEMPORAL_STUB'"
    ).fetchall() {
        bare_target: any = row["target_qualified"];
        if bare_target not in temporal_interfaces {
            continue;
        }
        try {
            extra: any = json.loads(row["extra"] or "{}");
        } except (json.JSONDecodeError, TypeError) {
            extra = {};
        }
        fname: any = extra.get("field_name");
        if not fname {
            continue;
        }
        field_map[row["source_qualified"], fname] = bare_target;
    }

    if not field_map {
        logger.info("Temporal resolver: no TEMPORAL_STUB edges found, skipping");
        return {"files_indexed": len(java_files), "calls_resolved": 0};
    }
    method_to_qual: dict[tuple[str, str], str] = {};
    for row in conn.execute(
        "SELECT name, qualified_name, parent_name FROM nodes WHERE kind IN ('Function', 'Test') AND language = 'java' AND parent_name IS NOT NULL",
    ).fetchall() {
        method_to_qual[row["parent_name"], row["name"]] = row["qualified_name"];
    }
    implementors: dict[str, list[str]] = {};
    for row in conn.execute(
        "SELECT e.source_qualified, e.target_qualified FROM edges e JOIN nodes n ON n.qualified_name = e.source_qualified WHERE e.kind = 'INHERITS' AND n.language IN ('java', 'kotlin', 'scala')",
    ).fetchall() {
        iface: any = row["target_qualified"];
        `impl: any = row["source_qualified"];
        implementors.setdefault(iface, []).append(`impl);
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

        if extra.get("temporal_resolved") or extra.get("spring_resolved") {
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

        interface_bare: any = field_map.get((enclosing_class_qual, receiver));
        if not interface_bare {
            continue;
        }

        interface_qual: any = temporal_interfaces.get(interface_bare, interface_bare);
        impls: any = implementors.get(interface_bare, []);
        if len(impls) == 1 {
            concrete_class: any = impls[0].split("::")[-1];
            fallback: any = f"{impls[0]}.{method_name}";
            new_target: any = method_to_qual.get((concrete_class, method_name)) or fallback;
        } else {
            fallback = f"{interface_qual}.{method_name}";
            new_target = method_to_qual.get((interface_bare, method_name)) or fallback;
        }

        extra["temporal_resolved"] = True;
        extra["temporal_interface"] = interface_bare;
        new_extra: any = json.dumps(extra);

        conn.execute(
            "UPDATE edges SET target_qualified = ?, extra = ? WHERE id = ?",
            (new_target, new_extra, row["id"]),
        );
        resolved += 1;
        logger.debug(
            "Temporal resolved: %s → %s (receiver=%s, interface=%s)",
            source_qual,
            new_target,
            receiver,
            interface_bare,
        );
    }

    if resolved {
        store.commit();
    }

    logger.info(
        "Temporal resolver: resolved %d CALLS edges in %d Java files", resolved, len(java_files)
    );
    return {"files_indexed": len(java_files), "calls_resolved": resolved};
}
