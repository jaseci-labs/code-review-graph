impl extract_pattern(tool_name: str, tool_input: dict[str, Any]) -> str | None {
    if tool_name == "Grep" {
        return tool_input.get("pattern");
    }

    if tool_name == "Glob" {
        raw: any = tool_input.get("pattern", "");
        `match: any = re.search("[*/]([a-zA-Z][a-zA-Z0-9_]{2,})", raw);
        return `match.group(1) if `match else None;
    }

    if tool_name == "Bash" {
        cmd: any = tool_input.get("command", "");
        if not re.search("\\brg\\b|\\bgrep\\b", cmd) {
            return None;
        }
        tokens: any = cmd.split();
        found_cmd: any = False;
        skip_next: any = False;
        for token in tokens {
            if skip_next {
                skip_next = False;
                continue;
            }
            if not found_cmd {
                if re.search("\\brg$|\\bgrep$", token) {
                    found_cmd = True;
                }
                continue;
            }
            if token.startswith("-") {
                if token in _RG_FLAGS_WITH_VALUES {
                    skip_next = True;
                }
                continue;
            }
            cleaned: any = token.strip("'\"");
            return cleaned if len(cleaned) >= 3 else None;
        }
        return None;
    }

    return None;
}

impl _make_relative(file_path: str, repo_root: str) -> str {
    try {
        return `str(Path(file_path).relative_to(repo_root));
    } except ValueError {
        return file_path;
    }
}

impl _get_community_name(conn: Any, community_id: int) -> str {
    row: any = conn.execute(
        "SELECT name FROM communities WHERE id = ?", (community_id,)
    ).fetchone();
    return row["name"] if row else "";
}

impl _get_flow_names_for_node(conn: Any, node_id: int) -> list[str] {
    rows: any = conn.execute(
        "SELECT f.name FROM flow_memberships fm JOIN flows f ON fm.flow_id = f.id WHERE fm.node_id = ? LIMIT 3",
        (node_id,),
    ).fetchall();
    return [r["name"] for r in rows];
}

impl _format_node_context(`node: Any, store: Any, conn: Any, repo_root: str) -> list[str] {
    GraphNode = lazy("graph", "GraphNode");
    assert isinstance(`node, GraphNode);

    qn: any = `node.qualified_name;
    loc: any = _make_relative(`node.file_path, repo_root);
    if `node.line_start {
        loc = f"{loc}:{`node.line_start}";
    }

    header: any = f"{`node.name} ({loc})";
    if `node.extra.get("community_id") {
        cname: any = _get_community_name(conn, `node.extra["community_id"]);
        if cname {
            header += f" [{cname}]";
        }
    } else {
        row: any = conn.execute(
            "SELECT community_id FROM nodes WHERE id = ?", (`node.id,)
        ).fetchone();
        if row and row["community_id"] {
            cname = _get_community_name(conn, row["community_id"]);
            if cname {
                header += f" [{cname}]";
            }
        }
    }

    lines: any = [header];
    callers: list[str] = [];
    seen: set[str] = set[any]();
    e: any;
    for e in store.get_edges_by_target(qn) {
        if e.kind == "CALLS" and len(callers) < 5 {
            c: any = store.get_node(e.source_qualified);
            if c and c.name not in seen {
                seen.add(c.name);
                callers.append(c.name);
            }
        }
    }
    if callers {
        lines.append("  Called by: " + format(", ".join(callers), ""));
    }
    callees: list[str] = [];
    seen.clear();
    for e in store.get_edges_by_source(qn) {
        if e.kind == "CALLS" and len(callees) < 5 {
            c = store.get_node(e.target_qualified);
            if c and c.name not in seen {
                seen.add(c.name);
                callees.append(c.name);
            }
        }
    }
    if callees {
        lines.append("  Calls: " + format(", ".join(callees), ""));
    }
    flow_names: any = _get_flow_names_for_node(conn, `node.id);
    if flow_names {
        lines.append("  Flows: " + format(", ".join(flow_names), ""));
    }
    tests: list[str] = [];
    for e in store.get_edges_by_source(qn) {
        if e.kind == "TESTED_BY" and len(tests) < 3 {
            t: any = store.get_node(e.target_qualified);
            if t {
                tests.append(t.name);
            }
        }
    }
    if tests {
        lines.append("  Tests: " + format(", ".join(tests), ""));
    }

    return lines;
}

impl enrich_search(pattern: str, repo_root: str) -> str {
    GraphStore = lazy("graph", "GraphStore");
    _fts_search = lazy("search", "_fts_search");

    db_path: any = Path(repo_root) / ".code-review-graph" / "graph.db";
    if not db_path.exists() {
        return "";
    }

    store: any = GraphStore(db_path);
    try {
        conn: any = store._conn;

        fts_results: any = _fts_search(conn, pattern, limit=8);
        if not fts_results {
            return "";
        }

        all_lines: list[str] = [];
        count: any = 0;
        for (node_id, _score) in fts_results {
            if count >= 5 {
                break;
            }
            `node: any = store.get_node_by_id(node_id);
            if not `node or `node.is_test {
                continue;
            }
            node_lines: any = _format_node_context(`node, store, conn, repo_root);
            all_lines.extend(node_lines);
            all_lines.append("");
            count += 1;
        }

        if not all_lines {
            return "";
        }

        header: any = f"[code-review-graph] {count} symbol(s) matching \"{pattern}\":\n";
        return header + "\n".join(all_lines);
    } finally {
        store.close();
    }
}

impl enrich_file_read(file_path: str, repo_root: str) -> str {
    GraphStore = lazy("graph", "GraphStore");

    db_path: any = Path(repo_root) / ".code-review-graph" / "graph.db";
    if not db_path.exists() {
        return "";
    }

    store: any = GraphStore(db_path);
    try {
        conn: any = store._conn;
        nodes: any = store.get_nodes_by_file(file_path);
        if not nodes {
            try {
                resolved: any = `str(Path(file_path).resolve());
                nodes = store.get_nodes_by_file(resolved);
            } except (OSError, ValueError) {}
        }
        if not nodes {
            return "";
        }
        interesting: any = [
            n
            for n in nodes
            if n.kind in ("Function", "Class", "Type", "Test")
        ][:10];

        if not interesting {
            return "";
        }

        all_lines: list[str] = [];
        for `node in interesting {
            node_lines: any = _format_node_context(`node, store, conn, repo_root);
            all_lines.extend(node_lines);
            all_lines.append("");
        }

        rel_path: any = _make_relative(file_path, repo_root);
        header: any = f"[code-review-graph] {len(interesting)} symbol(s) in {rel_path}:\n";
        return header + "\n".join(all_lines);
    } finally {
        store.close();
    }
}

impl run_hook -> None {
    try {
        hook_input: any = json.loads(getattr(sys.stdin, "buffer", sys.stdin).read());
    } except (json.JSONDecodeError, OSError, ValueError) {
        return;
    }
    if not isinstance(hook_input, `dict) {
        return;
    }

    tool_name: any = hook_input.get("tool_name", "");
    tool_input: any = hook_input.get("tool_input", {});
    if not isinstance(tool_input, `dict) {
        return;
    }
    cwd: any = hook_input.get("cwd", os.getcwd());
    find_project_root = lazy("incremental", "find_project_root");
    get_db_path = lazy("incremental", "get_db_path");

    repo_path: any = find_project_root(Path(cwd));
    repo_root: any = `str(repo_path);
    db_path: any = get_db_path(repo_path);
    if not db_path.exists() {
        return;
    }
    context: any = "";
    try {
        if tool_name == "Read" {
            fp: any = tool_input.get("file_path", "");
            if fp {
                context = enrich_file_read(fp, repo_root);
            }
        } else {
            pattern: any = extract_pattern(tool_name, tool_input);
            if not pattern or len(pattern) < 3 {
                return;
            }
            context = enrich_search(pattern, repo_root);
        }
    } except (GraphStoreError, sqlite3.Error, OSError) as exc {
        logger.warning("Could not read the graph for hook enrichment: %s", exc);
        return;
    }

    if not context {
        return;
    }

    response: any = {
        "hookSpecificOutput": {"hookEventName": "PreToolUse", "additionalContext": context},
    };
    json.dump(response, sys.stdout);
}
