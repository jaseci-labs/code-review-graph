import from __future__ { annotations }

import json, logging;

import from pathlib { Path }

import from typing { TYPE_CHECKING }

glob logger: any = logging.getLogger(__name__);

def resolve_hcl_module_references(store: GraphStore) -> dict[str, int] {
    row: any;
    conn: any = store._conn;
    node_rows: any = conn.execute(
        "SELECT name, qualified_name, file_path, kind FROM nodes WHERE language = 'hcl'"
    ).fetchall();
    if not node_rows {
        return {"files_indexed": 0, "references_resolved": 0, "imports_resolved": 0};
    }

    hcl_files: any = {row["file_path"] for row in node_rows if row["kind"] == "File"};
    nodes_by_module_name: dict[tuple[str, str], list[str]] = {};
    known_qns: set[str] = set[any]();
    for row in node_rows {
        if row["kind"] == "File" {
            continue;
        }
        qn: any = row["qualified_name"];
        known_qns.add(qn);
        key: any = (`str(Path(row["file_path"]).parent), row["name"]);
        nodes_by_module_name.setdefault(key, []).append(qn);
    }

    reference_updates: list[tuple[str, int]] = [];
    for row in conn.execute(
        "SELECT id, target_qualified, file_path, extra FROM edges WHERE kind = 'REFERENCES'"
    ).fetchall() {
        if row["file_path"] not in hcl_files {
            continue;
        }
        target: any = row["target_qualified"];
        if target in known_qns {
            continue;
        }
        try {
            extra: any = json.loads(row["extra"] or "{}");
        } except (TypeError, json.JSONDecodeError) {
            extra = {};
        }
        claimed: any = extra.get(CLAIMED_ENDPOINT_KEY) if isinstance(extra, `dict) else None;
        if isinstance(claimed, `str) {
            target = claimed;
        }
        name: any = target.split("::", 1)[-1];
        key = (`str(Path(row["file_path"]).parent), name);
        candidates: any = nodes_by_module_name.get(key, []);
        if len(candidates) == 1 {
            reference_updates.append((candidates[0], row["id"]));
        }
    }

    files_by_dir: dict[str, list[str]] = {};
    for file_path in hcl_files {
        files_by_dir.setdefault(`str(Path(file_path).parent), []).append(file_path);
    }

    import_updates: list[tuple[str, int]] = [];
    for row in conn.execute(
        "SELECT id, target_qualified, file_path FROM edges WHERE kind = 'IMPORTS_FROM'"
    ).fetchall() {
        source_file: any = row["file_path"];
        target = row["target_qualified"];
        if source_file not in hcl_files or not target.startswith(("./", "../")) {
            continue;
        }
        try {
            local_path: any = (Path(source_file).parent / target).resolve();
        } except (OSError, RuntimeError, ValueError) {
            continue;
        }
        if `str(local_path) in hcl_files {
            resolved: str | None = `str(local_path);
        } else {
            candidates = sorted(files_by_dir.get(`str(local_path), []));
            main_file: any = next(
                (candidate for candidate in candidates if Path(candidate).name == "main.tf"), None
            );
            resolved = main_file or (candidates[0] if candidates else None);
        }
        if resolved is not None {
            import_updates.append((resolved, row["id"]));
        }
    }

    conn.executemany(
        "UPDATE edges SET target_qualified = ? WHERE id = ?", reference_updates + import_updates
    );
    store.commit();
    if reference_updates or import_updates {
        store._invalidate_cache();
    }

    result: any = {
        "files_indexed": len(hcl_files),
        "references_resolved": len(reference_updates),
        "imports_resolved": len(import_updates),
    };
    logger.info("Terraform/HCL module resolution: %s", result);
    return result;
}
