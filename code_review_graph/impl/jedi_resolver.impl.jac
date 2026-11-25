impl enrich_jedi_calls(store, repo_root: Path, files: Optional[Iterable[str]] = None) -> dict {
    method_name: any;
    try {
        import jedi;
    } except ImportError {
        logger.info("Jedi not installed, skipping Python enrichment");
        return {"skipped": True, "reason": "jedi not installed"};
    }

    repo_root_given: any = Path(repo_root);
    repo_root = repo_root_given.resolve();
    all_files: any = store.get_all_files();
    py_files: any = [f for f in all_files if f.endswith(".py")];

    if not py_files {
        return {"resolved": 0, "files": 0};
    }
    if files is None {
        scan_files: any = py_files;
    } else {
        wanted: any = {normalize_file_path(f) for f in files};
        scan_files = [f for f in py_files if normalize_file_path(f) in wanted];
        if not scan_files {
            return {"resolved": 0, "files": 0};
        }
    }
    py_dirs: any = sorted({`str(Path(f).parent) for f in py_files});
    common_py_root: any = Path(os.path.commonpath(py_dirs)) if py_dirs else repo_root;
    if not `str(common_py_root).startswith(`str(repo_root)) {
        common_py_root = repo_root;
    }
    project: any = jedi.Project(
        path=`str(common_py_root), added_sys_path=[`str(repo_root)], smart_sys_path=False
    );
    parser: any = CodeParser();
    ts_parser: any = parser._get_parser("python");
    if not ts_parser {
        return {"resolved": 0, "files": 0};
    }
    project_func_names: any = {
        r["name"]
        for r in store._conn.execute(
            "SELECT DISTINCT name FROM nodes WHERE kind IN ('Function', 'Test')"
        ).fetchall()
    };

    files_with_pending: list[tuple[str, bytes, list]] = [];
    total_skipped: any = 0;
    file_path: any;
    for file_path in scan_files {
        try {
            source: any = Path(file_path).read_bytes();
        } except (OSError, PermissionError) {
            continue;
        }
        tree: any = ts_parser.parse(source);
        is_test: any = _parser_is_test_file(file_path, repo_root);
        pending: any = _find_untracked_method_calls(tree.root_node, is_test);
        if pending {
            filtered: any = [p for p in pending if p[2] in project_func_names];
            total_skipped += len(pending) - len(filtered);
            if filtered {
                files_with_pending.append((file_path, source, filtered));
            }
        }
    }

    if not files_with_pending {
        return {"resolved": 0, "files": 0};
    }

    logger.debug(
        "Jedi: %d/%d Python files have pending calls (%d calls skipped — no project target)",
        len(files_with_pending),
        len(scan_files),
        total_skipped,
    );

    resolved_count: any = 0;
    refined_count: any = 0;
    files_enriched: any = 0;
    errors: any = 0;

    for (file_path, source, pending) in files_with_pending {
        source_text: any = source.decode("utf-8", errors="replace");
        existing: dict[tuple[str, int], list] = {};
        for `edge in _get_file_call_edges(store, file_path) {
            existing.setdefault((`edge.source_qualified, `edge.line), []).append(`edge);
        }
        func_nodes: any = [
            n
            for n in store.get_nodes_by_file(file_path)
            if n.kind in ("Function", "Test")
        ];
        try {
            script: any = jedi.Script(source_text, path=file_path, project=project);
        } except Exception as e {
            logger.debug("Jedi failed to load %s: %s", file_path, e);
            errors += 1;
            continue;
        }

        file_resolved: any = 0;
        jedi_line: any;
        col: any;
        _enclosing_name: any;
        for item_ in pending {
            (jedi_line, col, method_name, _enclosing_name) = item_;
            enclosing: any = _find_enclosing(func_nodes, jedi_line);
            if not enclosing {
                enclosing = file_path;
            }

            same_line: any = existing.get((enclosing, jedi_line), []);
            if `any(_is_resolved_call(e.target_qualified, method_name) for e in same_line) {
                continue;
            }
            bare: any = next((e for e in same_line if e.target_qualified == method_name), None);
            try {
                names: any = script.goto(jedi_line, col);
            } except Exception {
                continue;
            }

            if not names {
                continue;
            }

            name: any = names[0];
            if not name.module_path {
                continue;
            }

            module_path: any = Path(name.module_path).resolve();
            try {
                rel_path: any = module_path.relative_to(repo_root);
            } except ValueError {
                continue;
            }
            target_file: any = normalize_file_path(repo_root_given / rel_path);
            parent: any = name.parent();
            if parent and parent.type == "class" {
                target: any = f"{target_file}::{parent.name}.{name.name}";
            } else {
                target = f"{target_file}::{name.name}";
            }
            if store.get_node(target) is None {
                continue;
            }

            if bare is not None {
                extra: any = `dict(bare.extra);
                extra["call_resolution"] = "jedi";
                store._conn.execute(
                    "UPDATE edges SET target_qualified = ?, extra = ?, target_resolution = NULL WHERE id = ?",
                    (target, json.dumps(extra, sort_keys=True), bare.id),
                );
                same_line.remove(bare);
                refined_count += 1;
            } else {
                store.upsert_edge(
                    EdgeInfo(
                        kind="CALLS",
                        source=enclosing,
                        target=target,
                        file_path=file_path,
                        line=jedi_line,
                        extra={"call_resolution": "jedi"},
                    ),
                );
            }
            existing.setdefault((enclosing, jedi_line), []).append(_ResolvedCall(target));
            file_resolved += 1;
        }

        if file_resolved {
            files_enriched += 1;
            resolved_count += file_resolved;
        }
    }

    if resolved_count {
        store.commit();
        store._invalidate_cache();
        logger.info(
            "Jedi enrichment: resolved %d calls in %d files", resolved_count, files_enriched
        );
    }

    return {
        "resolved": resolved_count,
        "refined": refined_count,
        "files": files_enriched,
        "errors": errors,
    };
}

impl _ResolvedCall.init(target: str) {
    self.target_qualified = target;
}

impl _ResolvedCall.__repr__ -> str {
    return (getattr(builtins.object, "__repr__") as any)(self);
}

impl _ResolvedCall.__eq__(other: any) -> bool {
    return self is other;
}

impl _ResolvedCall.__hash__ -> int {
    return id(self);
}

impl _is_resolved_call(target: str, method_name: str) -> bool {
    if "::" not in target {
        return False;
    }
    tail: any = target.rsplit("::", 1)[1];
    return operator.eq(tail, method_name) or tail.endswith("." + method_name);
}

impl _get_file_call_edges(store, file_path: str) -> any {
    conn: any = store._conn;
    rows: any = conn.execute(
        "SELECT * FROM edges WHERE file_path = ? AND kind = 'CALLS'", (file_path,)
    ).fetchall();
    GraphEdge = lazy("graph", "GraphEdge");
    return [
        GraphEdge(
            id=r["id"],
            kind=r["kind"],
            source_qualified=r["source_qualified"],
            target_qualified=r["target_qualified"],
            file_path=r["file_path"],
            line=r["line"],
            extra=_edge_extra(r["extra"]),
        )
        for r in rows
    ];
}

impl _edge_extra(raw: Optional[str]) -> dict {
    try {
        extra: any = json.loads(raw or "{}");
    } except (TypeError, ValueError) {
        return {};
    }
    return extra if isinstance(extra, `dict) else {};
}

impl _find_enclosing(func_nodes, line: int) -> Optional[str] {
    best: any = None;
    best_span: any = `float("inf");
    for `node in func_nodes {
        if `node.line_start <= line <= `node.line_end {
            span: any = `node.line_end - `node.line_start;
            if span < best_span {
                best = `node.qualified_name;
                best_span = span;
            }
        }
    }
    return best;
}

impl _find_untracked_method_calls(`root, is_test_file: bool = False) -> any {
    results: list[tuple[int, int, str, Optional[str]]] = [];
    _walk_calls(`root, results, is_test_file, enclosing_func=None);
    return results;
}

impl _walk_calls(`node, results, is_test_file, enclosing_func) -> any {
    if `node.type == "function_definition" {
        name: any = None;
        child: any;
        for child in `node.children {
            if child.type == "identifier" {
                name = child.text.decode("utf-8", errors="replace");
                break;
            }
        }
        for child in `node.children {
            _walk_calls(child, results, is_test_file, name or enclosing_func);
        }
        return;
    }

    if `node.type == "decorated_definition" {
        for child in `node.children {
            _walk_calls(child, results, is_test_file, enclosing_func);
        }
        return;
    }
    if `node.type == "call" {
        first: any = `node.children[0] if `node.children else None;
        if first and first.type == "attribute" {
            _check_dropped_call(first, results, is_test_file, enclosing_func);
        }
    }

    for child in `node.children {
        _walk_calls(child, results, is_test_file, enclosing_func);
    }
}

impl _check_dropped_call(attr_node, results, is_test_file, enclosing_func) -> any {
    children: any = attr_node.children;
    if len(children) < 2 {
        return;
    }

    receiver: any = children[0];
    if receiver.type != "identifier" {
        return;
    }

    receiver_text: any = receiver.text.decode("utf-8", errors="replace");
    if receiver_text in _SELF_NAMES {
        return;
    }
    if receiver_text[:1].isupper() {
        return;
    }
    if is_test_file {
        return;
    }
    method_node: any = children[-1];
    if method_node.type != "identifier" {
        return;
    }

    row: any;
    col: any;
    (row, col) = method_node.start_point as any;
    method_name: any = method_node.text.decode("utf-8", errors="replace");
    results.append((row + 1, col, method_name, enclosing_func));
}
