import from __future__ { annotations }

import importlib, hashlib, logging;

import from pathlib { Path }

import from typing { Any }

glob logger: any = logging.getLogger(__name__);

glob _SQL_PARAM_CHUNK: any = 400;

def _referrer_files(
    store: GraphStore, deleted_qualified_names: set[str], forgotten: set[str]
) -> list[str] {
    if not deleted_qualified_names {
        return [];
    }
    conn: any = store._conn;
    referrers: set[str] = set[any]();
    names: any = `list(deleted_qualified_names);
    for start in range(0, len(names), _SQL_PARAM_CHUNK) {
        window: any = names[start:start + _SQL_PARAM_CHUNK];
        placeholders: any = ",".join("?" for _ in window);
        rows: any = conn.execute(
            f"SELECT DISTINCT file_path FROM edges WHERE target_qualified IN ({placeholders}) OR source_qualified IN ({placeholders})",
            window + window,
        ).fetchall();
        referrers.update(row["file_path"] for row in rows);
    }
    return sorted(referrers - forgotten);
}

def _purge_orphan_embeddings(store: GraphStore) -> int {
    conn: any = store._conn;
    has_table: any = conn.execute(
        "SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = 'embeddings'"
    ).fetchone();
    if has_table is None {
        return 0;
    }
    cursor: any = conn.execute(
        "DELETE FROM embeddings WHERE NOT EXISTS (SELECT 1 FROM nodes WHERE nodes.qualified_name = embeddings.qualified_name)",
    );
    return max(cursor.rowcount, 0);
}

def forget_files(store: GraphStore, repo_root: Path, targets: list[str]) -> dict[str, Any] {
    import from code_review_graph.parser { CodeParser }
    import from code_review_graph.postprocessing { run_post_processing }
    import from code_review_graph.python_resolver { resolve_python_imports }
    import from code_review_graph.scoped_resolver { resolve_scoped_calls }

    forgotten: any = `set(targets);
    deleted_qualified_names: set[str] = set[any]();
    file_path: any;
    for file_path in targets {
        for `node in store.get_nodes_by_file(file_path) {
            deleted_qualified_names.add(`node.qualified_name);
        }
    }

    referrers: any = _referrer_files(store, deleted_qualified_names, forgotten);
    for file_path in targets {
        store.remove_file_data(file_path);
    }
    store.set_metadata("intentionally_incomplete", "1");
    store.commit();
    import from code_review_graph.incremental { _load_followed_dirs }
    import from code_review_graph.incremental { _relink_edges }

    parser: any = CodeParser(repo_root);
    parser.exclude_files(forgotten);
    followed_dirs: any = _load_followed_dirs(store);
    reparsed: list[str] = [];
    for file_path in referrers {
        abs_path: any = Path(file_path);
        if not abs_path.is_file() {
            continue;
        }
        if parser.detect_language(abs_path) is None {
            continue;
        }
        try {
            source: any = abs_path.read_bytes();
            fhash: any = hashlib.sha256(source).hexdigest();
            nodes: any;
            edges: any;
            (nodes, edges) = parser.parse_bytes(abs_path, source) as any;
            _relink_edges(edges, Path(repo_root).resolve(), followed_dirs);
            store.store_file_nodes_edges(`str(abs_path), nodes, edges, fhash);
            reparsed.append(file_path);
        } except (OSError, PermissionError) as exc {
            logger.warning("Could not re-parse referrer %s: %s", file_path, exc);
        } except Exception as exc {
            logger.warning("Error re-parsing referrer %s: %s", file_path, exc);
        }
    }
    try {
        resolve_python_imports(store);
    } except Exception as exc {
        logger.warning("Python import resolver failed after forget: %s", exc);
    }
    try {
        resolve_scoped_calls(store, repo_root);
    } except Exception as exc {
        logger.warning("Scoped call resolver failed after forget: %s", exc);
    }
    run_post_processing(store);
    purged: any = _purge_orphan_embeddings(store);

    return {"forgotten": sorted(forgotten), "reparsed": reparsed, "embeddings_purged": purged};
}
