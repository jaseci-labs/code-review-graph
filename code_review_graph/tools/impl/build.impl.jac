impl _should_rebuild_partial_graph(
    repo_root: Path, store: Any, recurse_submodules: bool | None = None
) -> bool {
    if store.get_metadata("intentionally_incomplete") == "1" {
        return False;
    }

    represented_paths: any = {normalize_file_path(path) for path in store.get_all_files()};
    try {
        verified: any = `int(store.get_metadata(VERIFIED_FILE_COUNT_KEY) or 0);
    } except ValueError {
        verified = 0;
    }
    if verified and len(represented_paths) > verified * _PARTIAL_GRAPH_MAX_COVERAGE {
        return False;
    }
    if detect_vcs(repo_root) == "svn" {
        return False;
    }

    tracked_files: any = get_all_tracked_files(repo_root, recurse_submodules);
    tracked_paths: set[str] = set[any]();
    if tracked_files {
        tracked_paths = {normalize_file_path(repo_root / relative) for relative in tracked_files};
        if len(represented_paths & tracked_paths)
            >= len(tracked_files) * _PARTIAL_GRAPH_SUSPECT_TRACKED_COVERAGE
        {
            return False;
        }
        if len(tracked_files) < _PARTIAL_GRAPH_MIN_FILES {
            return False;
        }
    }

    expected_files: any = collect_all_files(repo_root, recurse_submodules);
    if len(expected_files) < _PARTIAL_GRAPH_MIN_FILES {
        return False;
    }

    expected_paths: any = {
        normalize_file_path(repo_root / relative)
        for relative in expected_files
    };
    if tracked_paths {
        expected_paths &= tracked_paths;
    }
    represented_count: any = len(expected_paths & represented_paths);
    if represented_count <= len(expected_paths) * _PARTIAL_GRAPH_MAX_COVERAGE {
        return True;
    }
    store.set_metadata(VERIFIED_FILE_COUNT_KEY, `str(len(represented_paths)));
    return False;
}

impl build_was_interrupted(store: Any) -> bool {
    return read_build_state(store) in INCOMPLETE_BUILD_STATES;
}

impl _run_embedding_refresh(
    store: Any,
    result: dict[str, Any],
    warnings: list[str],
    *,
    provider: str | None,
    model: str | None,
) -> None {
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
        refresh_embeddings = importlib.import_module("code_review_graph.embeddings").refresh_embeddings;

        refreshed: any = refresh_embeddings(store, provider=provider, model=model);
        if refreshed is None {
            _report_refresh_skipped(result, warnings);
        } else {
            result["embeddings_refreshed"] = refreshed["embedded"];
            result["embeddings_purged"] = refreshed["purged"];
        }
    } except Exception as exc {
        logger.warning("Embedding refresh failed: %s", exc);
        warnings.append(f"Embedding refresh failed: {`type(exc).__name__}: {exc}");
    }
}

impl _report_refresh_skipped(result: dict[str, Any], warnings: list[str]) -> None {
    REFRESH_SKIPPED_WARNING = importlib.import_module("code_review_graph.embeddings").REFRESH_SKIPPED_WARNING;

    logger.warning(REFRESH_SKIPPED_WARNING);
    warnings.append(REFRESH_SKIPPED_WARNING);
    result["embeddings_refresh_skipped"] = True;
}

impl is_lock_contention(exc: BaseException) -> bool {
    message: any;
    if not isinstance(exc, sqlite3.OperationalError) {
        return False;
    }
    errorcode: any = getattr(exc, "sqlite_errorcode", None);
    if isinstance(errorcode, `int) {
        return errorcode & 255 in _CONTENTION_ERRORCODES;
    }
    message = `str(exc).lower();
    return `any(text in message for text in _CONTENTION_MESSAGES);
}

impl _note_contention(build_result: dict[str, Any], exc: BaseException) -> None {
    if not isinstance(exc, sqlite3.OperationalError) {
        return;
    }
    if is_lock_contention(exc) {
        build_result["postprocess_contended"] = True;
    } else {
        build_result["postprocess_failed"] = True;
    }
}

impl _fts_file_hint(repo_root: str | None, changed_files: list[str] | None) -> list[str] | None {
    if not changed_files {
        return None;
    }
    if repo_root is None {
        return [normalize_file_path(path) for path in changed_files];
    }
    `root: any = Path(repo_root);
    return [normalize_file_path(`root / path) for path in changed_files];
}

impl _run_postprocess(
    store: Any,
    build_result: dict[str, Any],
    postprocess: str,
    full_rebuild: bool = False,
    changed_files: list[str] | None = None,
    repo_root: str | None = None,
    embedding_provider: str | None = None,
    embedding_model: str | None = None,
    entry_point_qns: list[str] | None = None,
    communities_were_affected: bool = False,
    skip_resolvers: bool = False,
) -> list[str] {
    warnings: list[str] = [];
    build_result["postprocess_level"] = postprocess;

    if postprocess == "none" {
        _run_embedding_refresh(
            store, build_result, warnings, provider=embedding_provider, model=embedding_model
        );
        try {
            store.refresh_target_resolution();
        } except sqlite3.OperationalError as e {
            logger.warning("Target-resolution refresh failed: %s", e);
            _note_contention(build_result, e);
            warnings.append(f"Target-resolution refresh failed: {`type(e).__name__}: {e}");
        }
        return warnings;
    }

    noop_incremental: any = not full_rebuild
        and changed_files is not None
        and operator.eq(build_result.get("files_updated"), 0)
        and not build_result.get("stale_files_removed")
        and operator.ne(store.get_metadata("csharp_flows_dirty"), "1");
    if not skip_resolvers {
        try {
            if noop_incremental and not store.get_nodes_without_signature() {
                build_result["bare_edges_resolved"] = 0;
                build_result["cpp_scoped_edges_resolved"] = 0;
            } else {
                noop_incremental = False;
                resolved: any = store.resolve_bare_call_targets();
                resolved += store.resolve_bare_tested_by_sources();
                build_result["bare_edges_resolved"] = resolved;
                build_result["cpp_scoped_edges_resolved"] = store.resolve_cpp_scoped_call_targets();
                store.refresh_target_resolution();
            }
        } except sqlite3.OperationalError as e {
            logger.warning("Call-target resolution failed: %s", e);
            _note_contention(build_result, e);
            warnings.append(f"Call-target resolution failed: {`type(e).__name__}: {e}");
        }
    }
    timing: dict[str, float] = {};
    stage_started: any = time.perf_counter();
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
                sig: any = "def " + format(name, "") + "(" + format(params or "", "") + ")";
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
        build_result["signatures_updated"] = True;
    } except (sqlite3.OperationalError, TypeError, KeyError) as e {
        logger.warning("Signature computation failed: %s", e);
        _note_contention(build_result, e);
        warnings.append(f"Signature computation failed: {`type(e).__name__}: {e}");
    }
    timing["signatures_s"] = max(0.0, round(time.perf_counter() - stage_started, 6));

    stage_started = time.perf_counter();
    try {
        rebuild_fts_index = importlib.import_module("code_review_graph.search").rebuild_fts_index;
        update_fts_index = importlib.import_module("code_review_graph.search").update_fts_index;

        if full_rebuild {
            build_result["fts_indexed"] = rebuild_fts_index(store);
            build_result["fts_rebuilt"] = True;
        } else {
            mode: list[str] = [];
            build_result["fts_indexed"] = update_fts_index(
                store, _fts_file_hint(repo_root, changed_files), _out_mode=mode
            );
            build_result["fts_rebuilt"] = operator.eq(mode, ["rebuild"]);
        }
    } except (sqlite3.OperationalError, ImportError) as e {
        logger.warning("FTS index rebuild failed: %s", e);
        _note_contention(build_result, e);
        warnings.append(f"FTS index rebuild failed: {`type(e).__name__}: {e}");
    }
    timing["fts_s"] = max(0.0, round(time.perf_counter() - stage_started, 6));

    if postprocess == "minimal" {
        _run_embedding_refresh(
            store, build_result, warnings, provider=embedding_provider, model=embedding_model
        );
        build_result["postprocess_timing"] = timing;
        return warnings;
    }
    use_incremental: any = not full_rebuild
        and not build_result.get("identity_rebuild")
        and (`bool(changed_files) or `bool(entry_point_qns) or communities_were_affected);

    stage_started = time.perf_counter();
    try {
        if noop_incremental {
            count: any = 0;
        } elif use_incremental {
            incremental_trace_flows = importlib.import_module("code_review_graph.flows").incremental_trace_flows;

            count = incremental_trace_flows(
                store, changed_files or [], repo_root=repo_root, entry_point_qns=entry_point_qns
            );
        } else {
            _store_flows = importlib.import_module("code_review_graph.flows").store_flows;
            _trace_flows = importlib.import_module("code_review_graph.flows").trace_flows;

            flows: any = _trace_flows(store);
            count = _store_flows(store, flows);
        }
        build_result["flows_detected"] = count;
    } except (sqlite3.OperationalError, ImportError) as e {
        logger.warning("Flow detection failed: %s", e);
        _note_contention(build_result, e);
        warnings.append(f"Flow detection failed: {`type(e).__name__}: {e}");
    }
    timing["flows_s"] = max(0.0, round(time.perf_counter() - stage_started, 6));

    stage_started = time.perf_counter();
    try {
        if noop_incremental {
            count = store._conn.execute("SELECT COUNT(*) FROM communities").fetchone()[0];
        } elif use_incremental {
            incremental_detect_communities = importlib.import_module("code_review_graph.communities").incremental_detect_communities;

            count = incremental_detect_communities(
                store, changed_files or [], repo_root=repo_root, force=communities_were_affected
            );
        } else {
            _detect_communities = importlib.import_module("code_review_graph.communities").detect_communities;
            _store_communities = importlib.import_module("code_review_graph.communities").store_communities;

            comms: any = _detect_communities(store);
            count = _store_communities(store, comms);
        }
        build_result["communities_detected"] = count;
    } except (sqlite3.OperationalError, ImportError) as e {
        logger.warning("Community detection failed: %s", e);
        _note_contention(build_result, e);
        warnings.append(f"Community detection failed: {`type(e).__name__}: {e}");
    }
    timing["communities_s"] = max(0.0, round(time.perf_counter() - stage_started, 6));

    _run_embedding_refresh(
        store, build_result, warnings, provider=embedding_provider, model=embedding_model
    );
    build_result["postprocess_timing"] = timing;

    store.set_metadata("last_postprocessed_at", time.strftime("%Y-%m-%dT%H:%M:%S"));
    store.set_metadata("postprocess_level", postprocess);
    if hasattr(store, "shrink_memory") {
        store.shrink_memory();
    }

    return warnings;
}

impl build_or_update_graph(
    full_rebuild: bool = False,
    repo_root: str | None = None,
    base: str | None = None,
    postprocess: str = "full",
    recurse_submodules: bool | None = None,
    embedding_provider: str | None = None,
    embedding_model: str | None = None,
    wait_for_lock: bool = False,
    recover_corrupt: bool = False,
    enrich: bool | None = None,
    follow_symlinks: bool | None = None,
) -> dict[str, Any] {
    `root: any = _resolve_root(repo_root);
    db_path: any = get_db_path(`root, read_only=True);
    lock: any;
    contended: any;
    (lock, contended) = _lock_or_skip(db_path, wait_for_lock) as any;
    if contended is not None {
        return contended;
    }
    store: any = None;
    try {
        recovery_reason: str | None = None;
        _prepare_db_path(`root, db_path);
        (store, `root) = _get_store(
            `str(`root), db_path=db_path, recover_corrupt=full_rebuild and recover_corrupt
        ) as any;
        if not full_rebuild and not store.has_nodes() {
            full_rebuild = True;
        }
        interrupted: any = build_was_interrupted(store);
        if not graph_contents_are_complete(read_build_state(store)) and not full_rebuild {
            logger.warning(
                "Previous build stopped before all source files were stored; rebuilding"
            );
            full_rebuild = True;
        }
        base_resolved: str | None = base;
        if not full_rebuild and base is None {
            base_resolved = resolve_incremental_base(`root, store);
            if base_resolved is None {
                full_rebuild = True;
            }
        }

        if not full_rebuild and _should_rebuild_partial_graph(`root, store, recurse_submodules) {
            full_rebuild = True;
            recovery_reason = "partial_graph";
        }

        previous_state: any = store.get_metadata(BUILD_STATE_KEY);
        store.set_metadata(BUILD_STATE_KEY, BUILD_IN_PROGRESS);

        if full_rebuild {
            result: any = full_build(
                `root, store, recurse_submodules, enrich=enrich, follow_symlinks=follow_symlinks
            );
            failed: any = [`str(item.get("file", "?")) for item in result["errors"]];
            summary: any = "Full build complete: parsed "
                + format(result["files_parsed"], "")
                + " files, created "
                + format(result["total_nodes"], "")
                + " nodes and "
                + format(result["total_edges"], "")
                + " edges.";
            if failed {
                summary += f" {len(failed)} file(s) failed to parse: {failed}.";
            }
            build_result: any = {
                **result,
                "status": "partial" if failed else "ok",
                "build_type": "full",
                "base_resolved": None,
                "summary": summary,
            };
            if recovery_reason is not None {
                build_result["recovery_reason"] = recovery_reason;
            }
        } else {
            try {
                result = incremental_update(
                    `root, store, base=base_resolved, enrich=enrich, follow_symlinks=follow_symlinks
                );
            } except RuntimeError as exc {
                if previous_state is not None {
                    store.set_metadata(BUILD_STATE_KEY, previous_state);
                }
                return {
                    "status": "error",
                    "build_type": "incremental",
                    "base_resolved": base_resolved,
                    "files_updated": 0,
                    "errors": [],
                    "error": `str(exc),
                    "summary": f"Incremental update failed: {exc}",
                    "postprocess_level": postprocess,
                };
            }
            failed = [`str(item.get("file", "?")) for item in result["errors"]];
            if result["files_updated"] == 0
                and not failed
                and not (postprocess == "full" and store.get_metadata("csharp_flows_dirty") == "1")
            {
                summary = "No changes detected. Graph is up to date."
                    if result.get("freshness_advanced")
                    else "No graph changes detected. Freshness metadata was not advanced.";
                if postprocess == "none" {
                    store.set_metadata(BUILD_STATE_KEY, previous_state or "");
                    noop_result: any = {
                        **result,
                        "status": "ok",
                        "build_type": "incremental",
                        "base_resolved": base_resolved,
                        "summary": summary,
                        "postprocess_level": postprocess,
                    };
                    if embedding_provider and embedding_model {
                        has_embeddings = importlib.import_module("code_review_graph.embeddings").has_embeddings;

                        if not has_embeddings(store) {
                            noop_warnings: list[str] = [];
                            _report_refresh_skipped(noop_result, noop_warnings);
                            noop_result["warnings"] = noop_warnings;
                        }
                    }
                    return noop_result;
                }
                pending: any = operator.eq(previous_state, POSTPROCESS_PENDING);
                postprocess_level: any = postprocess if pending else "minimal";
                build_result = {
                    **result,
                    "status": "ok",
                    "build_type": "incremental",
                    "base_resolved": base_resolved,
                    "summary": summary,
                };
                advance_to_postprocess_pending(store);
                warnings: any = _run_postprocess(
                    store,
                    build_result,
                    postprocess_level,
                    full_rebuild=False,
                    changed_files=None,
                    repo_root=`str(`root),
                    embedding_provider=embedding_provider if pending else None,
                    embedding_model=embedding_model if pending else None,
                    skip_resolvers=not pending,
                );
                if warnings {
                    build_result["warnings"] = warnings;
                }
                if build_result.get("postprocess_failed") {
                    build_result["status"] = "partial";
                }
                if not build_result.get("postprocess_contended") {
                    store.set_metadata(BUILD_STATE_KEY, BUILD_COMPLETE);
                }
                build_result["repaired_interrupted_build"] = interrupted;
                if not pending and embedding_provider and embedding_model {
                    has_embeddings = importlib.import_module("code_review_graph.embeddings").has_embeddings;

                    if not has_embeddings(store) {
                        embedding_warnings: list[str] = [];
                        _report_refresh_skipped(build_result, embedding_warnings);
                        build_result.setdefault("warnings", []).extend(embedding_warnings);
                    }
                }
                build_result["postprocess_level"] = postprocess_level;
                return build_result;
            }
            summary = "Incremental update: "
                + format(result["files_updated"], "")
                + " files re-parsed, "
                + format(result["total_nodes"], "")
                + " nodes and "
                + format(result["total_edges"], "")
                + " edges updated. Changed: "
                + format(result["changed_files"], "")
                + ". Dependents also updated: "
                + format(result["dependent_files"], "")
                + ".";
            if failed {
                summary += f" {len(failed)} file(s) failed to parse and keep their previous graph rows: {failed}.";
            }
            build_result = {
                **result,
                "status": "partial" if failed else "ok",
                "build_type": "incremental",
                "base_resolved": base_resolved,
                "summary": summary,
            };
        }
        advance_to_postprocess_pending(store);
        changed: any = None;
        entry_qns: any = None;
        communities_affected: any = False;
        flow_entry_qns: any = build_result.pop("flow_entry_point_qns", None);
        if not full_rebuild and previous_state != POSTPROCESS_PENDING {
            changed = `list(result.get("changed_files") or []);
            changed.extend(result.get("dependent_files") or []);
            entry_qns = `list(flow_entry_qns or []);
            communities_affected = `bool(result.get("communities_were_affected"));
        }
        warnings = _run_postprocess(
            store,
            build_result,
            postprocess,
            full_rebuild=full_rebuild,
            changed_files=changed,
            repo_root=`str(`root),
            embedding_provider=embedding_provider,
            embedding_model=embedding_model,
            entry_point_qns=entry_qns,
            communities_were_affected=communities_affected,
        );
        if warnings {
            build_result["warnings"] = warnings;
        }
        if build_result.get("postprocess_failed") {
            build_result["status"] = "partial";
        }
        if not build_result.get("postprocess_contended") and postprocess != "none" {
            store.set_metadata(BUILD_STATE_KEY, BUILD_COMPLETE);
        } elif postprocess == "none" and failed {
            rows_changed: any = result.get("files_updated", 0) or result.get("files_parsed", 0);
            store.set_metadata(
                BUILD_STATE_KEY, POSTPROCESS_PENDING if rows_changed else previous_state or ""
            );
        }
        build_result["repaired_interrupted_build"] = interrupted;
        return build_result;
    } finally {
        try {
            if store is not None {
                store.close();
            }
        } finally {
            lock.release();
        }
    }
}

impl _lock_or_skip(
    db_path: Path, wait_for_lock: bool, outcome: str = "skipped instead of repeating the work"
) -> tuple[WriteLock | None, dict[str, Any] | None] {
    lock: any = WriteLock(db_path);
    if lock.acquire(blocking=wait_for_lock) {
        return (lock, None);
    }
    return (None, _write_skipped_response(db_path, lock.holder_pid(), outcome));
}

impl _write_skipped_response(
    db_path: Path, holder_pid: int | None, outcome: str = "skipped instead of repeating the work"
) -> dict[str, Any] {
    holder: any = f"PID {holder_pid}" if holder_pid is not None else "another process";
    return {
        "status": "contended",
        "skipped": True,
        "build_type": "none",
        "holder_pid": holder_pid,
        "lock_path": `str(write_lock_path(db_path)),
        "files_parsed": 0,
        "files_updated": 0,
        "total_nodes": 0,
        "total_edges": 0,
        "errors": [],
        "summary": f"Another code-review-graph write is already running for this repository ({holder}); {outcome}. Pass wait_for_lock=True (CLI: --wait) to block until it finishes.",
    };
}

impl run_postprocess(
    flows: bool = True,
    communities: bool = True,
    fts: bool = True,
    repo_root: str | None = None,
    embedding_provider: str | None = None,
    embedding_model: str | None = None,
    wait_for_lock: bool = False,
) -> dict[str, Any] {
    `root: any = _resolve_root(repo_root);
    db_path: any = get_db_path(`root, read_only=True);
    lock: any;
    contended: any;
    (lock, contended) = _lock_or_skip(db_path, wait_for_lock) as any;
    if contended is not None {
        return contended;
    }
    store: any = None;
    result: dict[str, Any] = {"status": "ok"};
    warnings: list[str] = [];

    try {
        _prepare_db_path(`root, db_path);
        _root: any;
        (store, _root) = _get_store(`str(`root), db_path=db_path) as any;
        state_before: any = read_build_state(store);
        graph_complete: any = graph_contents_are_complete(state_before);

        try {
            resolved: any = store.resolve_bare_call_targets();
            resolved += store.resolve_bare_tested_by_sources();
            result["bare_edges_resolved"] = resolved;
            result["cpp_scoped_edges_resolved"] = store.resolve_cpp_scoped_call_targets();
            store.refresh_target_resolution();
        } except sqlite3.OperationalError as e {
            logger.warning("Call-target resolution failed: %s", e);
            _note_contention(result, e);
            warnings.append(f"Call-target resolution failed: {`type(e).__name__}: {e}");
        }

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
                    sig: any = "def " + format(name, "") + "(" + format(params or "", "") + ")";
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
            result["signatures_updated"] = True;
        } except (sqlite3.OperationalError, TypeError, KeyError) as e {
            logger.warning("Signature computation failed: %s", e);
            _note_contention(result, e);
            warnings.append(f"Signature computation failed: {`type(e).__name__}: {e}");
        }

        if fts {
            try {
                rebuild_fts_index = importlib.import_module("code_review_graph.search").rebuild_fts_index;

                fts_count: any = rebuild_fts_index(store);
                result["fts_indexed"] = fts_count;
            } except (sqlite3.OperationalError, ImportError) as e {
                store.rollback();
                logger.warning("FTS index rebuild failed: %s", e);
                _note_contention(result, e);
                warnings.append(f"FTS index rebuild failed: {`type(e).__name__}: {e}");
            }
        }

        if flows {
            try {
                _store_flows = importlib.import_module("code_review_graph.flows").store_flows;
                _trace_flows = importlib.import_module("code_review_graph.flows").trace_flows;

                traced: any = _trace_flows(store);
                count: any = _store_flows(store, traced);
                result["flows_detected"] = count;
            } except (sqlite3.OperationalError, ImportError) as e {
                store.rollback();
                logger.warning("Flow detection failed: %s", e);
                _note_contention(result, e);
                warnings.append(f"Flow detection failed: {`type(e).__name__}: {e}");
            }
        }

        if communities {
            try {
                _detect_communities = importlib.import_module("code_review_graph.communities").detect_communities;
                _store_communities = importlib.import_module("code_review_graph.communities").store_communities;

                comms: any = _detect_communities(store);
                count = _store_communities(store, comms);
                result["communities_detected"] = count;
            } except (sqlite3.OperationalError, ImportError) as e {
                store.rollback();
                logger.warning("Community detection failed: %s", e);
                _note_contention(result, e);
                warnings.append(f"Community detection failed: {`type(e).__name__}: {e}");
            }
        }

        _run_embedding_refresh(
            store, result, warnings, provider=embedding_provider, model=embedding_model
        );

        store.set_metadata("last_postprocessed_at", time.strftime("%Y-%m-%dT%H:%M:%S"));
        if not graph_complete {
            warning: any = "The last build stopped before every file was stored, so the graph is still incomplete. Post-processing rebuilt what it could from the stored nodes; run 'code-review-graph build' to finish the graph itself.";
            logger.warning(warning);
            warnings.append(warning);
            result["build_incomplete"] = True;
            result["status"] = "partial";
            result["summary"] = "Post-processing ran, but the graph is missing files from an unfinished build. Run a full build to repair it.";
        } else {
            if not result.get("postprocess_contended") {
                store.set_metadata(BUILD_STATE_KEY, BUILD_COMPLETE);
            }
            result["summary"] = "Post-processing complete.";
        }
        if warnings {
            result["warnings"] = warnings;
        }
        return result;
    } finally {
        try {
            if store is not None {
                store.close();
            }
        } finally {
            lock.release();
        }
    }
}
