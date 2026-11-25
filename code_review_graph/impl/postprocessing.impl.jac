impl run_post_processing(
    store: GraphStore,
    *,
    changed_files: Sequence[str] | None = None,
    embedding_provider: str | None = None,
    embedding_model: str | None = None,
) -> dict[str, Any] {
    result: dict[str, Any] = {};
    warnings: list[str] = [];

    _resolve_bare_endpoints(store, result, warnings);
    _compute_signatures(store, result, warnings);
    _sync_fts_index(store, result, warnings, changed_files);
    _trace_flows(store, result, warnings);
    _detect_communities(store, result, warnings);
    _refresh_embeddings(
        store, result, warnings, provider=embedding_provider, model=embedding_model
    );

    if warnings {
        result["warnings"] = warnings;
    }
    return result;
}

impl _resolve_bare_endpoints(store: GraphStore, result: dict[str, Any], warnings: list[str]) {
    try {
        resolved: any = store.resolve_bare_call_targets();
        resolved += store.resolve_bare_tested_by_sources();
        result["bare_edges_resolved"] = resolved;
        result["cpp_scoped_edges_resolved"] = store.resolve_cpp_scoped_call_targets();
        store.refresh_target_resolution();
    } except sqlite3.OperationalError as e {
        logger.warning("Call-target resolution failed: %s", e);
        warnings.append(f"Call-target resolution failed: {`type(e).__name__}: {e}");
    }
}

impl _compute_signatures(store: GraphStore, result: dict[str, Any], warnings: list[str]) {
    try {
        rows: any = store.get_nodes_without_signature();
        signature_rows: list[tuple[str, int]] = [];
        for row in rows {
            node_id: any;
            name: any;
            kind: any;
            params: any;
            ret: any;
            (node_id, name, kind, params, ret) = (row[0], row[1], row[2], row[3], row[4]);
            if kind in ("Function", "Test") {
                sig: any = f"def {name}({params or ""})";
                if ret {
                    sig += f" -> {ret}";
                }
            } elif kind == "Class" {
                sig = f"class {name}";
            } else {
                sig = name;
            }
            signature_rows.append((sig[:512], node_id));
        }
        store.update_node_signatures(signature_rows);
        result["signatures_computed"] = len(signature_rows);
    } except (sqlite3.OperationalError, TypeError, KeyError) as e {
        logger.warning("Signature computation failed: %s", e);
        warnings.append(f"Signature computation failed: {`type(e).__name__}: {e}");
    }
}

impl _sync_fts_index(
    store: GraphStore,
    result: dict[str, Any],
    warnings: list[str],
    changed_files: Sequence[str] | None = None,
) {
    try {
        update_fts_index = lazy("search", "update_fts_index");

        mode: list[str] = [];
        result["fts_indexed"] = update_fts_index(store, changed_files, _out_mode=mode);
        if mode {
            result["fts_mode"] = mode[0];
        }
    } except (sqlite3.OperationalError, ImportError) as e {
        logger.warning("FTS index rebuild failed: %s", e);
        warnings.append(f"FTS index rebuild failed: {`type(e).__name__}: {e}");
    }
}

impl _trace_flows(store: GraphStore, result: dict[str, Any], warnings: list[str]) {
    try {
        store_flows = lazy("flows", "store_flows");
        trace_flows = lazy("flows", "trace_flows");

        flows: any = trace_flows(store);
        count: any = store_flows(store, flows);
        result["flows_detected"] = count;
    } except (sqlite3.OperationalError, ImportError) as e {
        logger.warning("Flow detection failed: %s", e);
        warnings.append(f"Flow detection failed: {`type(e).__name__}: {e}");
    }
}

impl _detect_communities(store: GraphStore, result: dict[str, Any], warnings: list[str]) {
    try {
        detect_communities = lazy("communities", "detect_communities");
        store_communities = lazy("communities", "store_communities");

        comms: any = detect_communities(store);
        count: any = store_communities(store, comms);
        result["communities_detected"] = count;
    } except (sqlite3.OperationalError, ImportError) as e {
        logger.warning("Community detection failed: %s", e);
        warnings.append(f"Community detection failed: {`type(e).__name__}: {e}");
    }
}

impl _refresh_embeddings(
    store: GraphStore,
    result: dict[str, Any],
    warnings: list[str],
    *,
    provider: str | None,
    model: str | None,
) {
    if provider is None and model is None {
        return;
    }
    if not provider or not model {
        warning: any = "Embedding refresh requires both an explicit provider and model.";
        logger.warning(warning);
        warnings.append(warning);
        return;
    }

    try {
        REFRESH_SKIPPED_WARNING = lazy("embeddings", "REFRESH_SKIPPED_WARNING");
        refresh_embeddings = lazy("embeddings", "refresh_embeddings");

        refreshed: any = refresh_embeddings(store, provider=provider, model=model);
        if refreshed is None {
            logger.warning(REFRESH_SKIPPED_WARNING);
            warnings.append(REFRESH_SKIPPED_WARNING);
            result["embeddings_refresh_skipped"] = True;
        } else {
            result["embeddings_refreshed"] = refreshed["embedded"];
            result["embeddings_purged"] = refreshed["purged"];
        }
    } except Exception as exc {
        logger.warning("Embedding refresh failed: %s", exc);
        warnings.append(f"Embedding refresh failed: {`type(exc).__name__}: {exc}");
    }
}
