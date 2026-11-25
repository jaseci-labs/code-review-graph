impl _binding_transaction(store: GraphStore) -> Generator[any, any, any] {
    conn: any = store._conn;
    store._begin_immediate();
    try {
        yield;
    } except BaseException {
        conn.rollback();
        raise;
    }
    conn.commit();
}

impl _extra(raw: str | None) -> dict {
    try {
        value: any = json.loads(raw or "{}");
    } except (ValueError, TypeError) {
        return {};
    }
    return value if isinstance(value, `dict) else {};
}

impl _parents(name: str) -> Generator[any, any, any] {
    while name {
        yield name;
        name = name.rpartition(".")[0];
    }
    yield "";
}

impl _join(parent: str, name: str) -> str {
    return f"{parent}.{name}" if parent else name;
}

impl _split(text: str, separator: str) -> list[str] | None {
    parts: list[str] = [];
    depth: list[str] = [];
    current: any = "";
    for character in text {
        if character in _CLOSING {
            depth.append(_CLOSING[character]);
        } elif depth and character == depth[-1] {
            depth.pop();
        } elif character == separator and not depth {
            parts.append(current);
            current = "";
            continue;
        }
        current += character;
    }
    if depth {
        return None;
    }
    parts.append(current);
    return parts;
}

impl _arity(arguments: str) -> int | None {
    if not arguments.endswith(">") {
        return None;
    }
    supplied: any = _split(arguments[:-1], ",");
    if supplied is None or not all(argument.strip() for argument in supplied) {
        return None;
    }
    return len(supplied);
}

impl _type_key(reference: str) -> str | None {
    segments: any = _split(reference, ".");
    if segments is None {
        return None;
    }
    keys: any = [];
    for (index, segment) in enumerate(segments) {
        name: any;
        separator: any;
        arguments: any;
        (name, separator, arguments) = segment.partition("<") as any;
        if not separator {
            if not segment.isidentifier() {
                return None;
            }
            keys.append(segment);
            continue;
        }
        if index != len(segments) - 1 or not name.isidentifier() {
            return None;
        }
        arity: any = _arity(arguments);
        if arity is None {
            return None;
        }
        keys.append(f"{name}`{arity}");
    }
    return ".".join(keys);
}

impl resolve_csharp_calls(store: GraphStore, repo_root: Path | None = None) -> dict {
    `root: any;
    projects: any;
    types: dict[str, list[str]];
    methods: dict[tuple[str, str], list[str]];
    static_methods: set[str];
    parents: dict[str, str];
    partial_types: dict[str, str];
    type_files: dict[str, str];
    imports: dict[tuple[str, int], list[tuple[str, dict]]];
    global_imports: dict[str, list[tuple[str, dict]]];
    row: any;
    conn: any = store._conn;
    nodes: any = conn.execute("SELECT * FROM nodes WHERE language = 'csharp'").fetchall();
    files: any = {n["file_path"] for n in nodes};
    if not files {
        return {"files_indexed": 0, "calls_resolved": 0};
    }
    `root = repo_root or Path(os.path.commonpath([`str(Path(f).parent) for f in files]));
    @lru_cache(maxsize=None)
    def project(directory: Path) -> str | None {
        try {
            projects: any = `list(directory.glob("*.csproj"));
        } except OSError {
            return None;
        }
        if projects {
            return `str(projects[0]) if len(projects) == 1 else None;
        }
        if directory == `root or directory.parent == directory {
            return `str(`root);
        }
        return project(directory.parent);
    }

    projects = {f: project(Path(f).parent) for f in files};
    types = {};
    methods = {};
    static_methods = set[any]();
    parents = {};
    partial_types = {};
    type_files = {};
    namespaces: any = {""};
    for `node in nodes {
        extra: any = _extra(`node["extra"]);
        namespace: any = extra.get("csharp_namespace");
        if `node["kind"] == "File" {
            name: any;
            for name in extra.get("csharp_namespaces", []) {
                namespaces.update(_parents(name));
            }
        }
        if not isinstance(namespace, `str) {
            continue;
        }
        namespaces.update(_parents(namespace));
        qualified: any = `node["qualified_name"];
        parent: any = `node["parent_name"] or "";
        parents[qualified] = parent;
        if `node["kind"] == "Class" {
            arity: any = extra.get("csharp_arity");
            name = `node["name"];
            if isinstance(arity, `int) and arity > 0 {
                name = f"{name}`{arity}";
            }
            type_key: any = _join(parent, name);
            types.setdefault(type_key, []).append(qualified);
            type_files[qualified] = `node["file_path"];
            if extra.get("csharp_partial") {
                partial_types[qualified] = type_key;
            }
        } elif `node["kind"] in ("Function", "Method", "Test") {
            method_key: any = (f"{`node["file_path"]}::{parent}", `node["name"]);
            methods.setdefault(method_key, []).append(qualified);
            if extra.get("csharp_static") {
                static_methods.add(qualified);
            }
        }
    }
    based: any = {
        row[0]
        for row in conn.execute(
            "SELECT DISTINCT e.source_qualified FROM edges e JOIN nodes n ON n.qualified_name = e.source_qualified WHERE e.kind IN ('INHERITS', 'IMPLEMENTS') AND n.language = 'csharp'",
        )
    };
    imports = {};
    global_imports = {};
    csharp_files_sql: any = "SELECT file_path FROM nodes WHERE kind = 'File' AND language = 'csharp'";
    for row in conn.execute(
        f"SELECT * FROM edges WHERE kind = 'IMPORTS_FROM' AND file_path IN ({csharp_files_sql})"
    ) {
        extra = _extra(row["extra"]);
        scopes: any = extra.get("csharp_scopes");
        if row["file_path"] not in files or not scopes {
            continue;
        }
        directive: any = (row["target_qualified"], extra);
        scope: any = scopes[0][1];
        if extra.get("csharp_global") and scope == -1 {
            key: any = projects[row["file_path"]] or row["file_path"];
            global_imports.setdefault(key, []).append(directive);
        } else {
            imports.setdefault((row["file_path"], scope), []).append(directive);
        }
    }

    def import_target(raw: str, extra: dict) -> str | None {
        absolute: any = raw.startswith("global::");
        raw = raw.removeprefix("global::");
        if not all(part.isidentifier() for part in raw.split(".")) {
            return None;
        }
        first: any = raw.split(".", 1)[0];
        namespace: any = extra["csharp_scopes"][0][0];
        for parent in [""] if absolute else _parents(namespace) {
            prefix: any = _join(parent, first);
            if prefix in namespaces or prefix in types {
                target: any = _join(parent, raw);
                return target if target in namespaces or target in types else None;
            }
        }
        return None;
    }

    def directives(file: str, scope: int) -> list[tuple[str, dict]] {
        local: any = imports.get((file, scope), []);
        if scope == -1 {
            return local + global_imports.get(projects[file] or file, []);
        }
        return local;
    }

    def type_targets(raw: str, owner: str, scopes: list, file: str) -> list[str] {
        extra: any;
        absolute: any = raw.startswith("global::");
        raw = raw.removeprefix("global::").removesuffix("?");
        alias: any;
        separator: any;
        reference: any;
        (alias, separator, reference) = raw.partition("::") as any;
        if separator {
            reference_key: any = _type_key(reference);
            if not alias.isidentifier() or reference_key is None {
                return [];
            }
            _: any;
            for (_, scope) in scopes {
                aliases: any = [
                    d
                    for d in directives(file, scope)
                    if d[1].get("csharp_alias") == alias
                ];
                if not aliases {
                    continue;
                }
                if len(aliases) != 1 {
                    return [];
                }
                target: any = import_target(*aliases[0]);
                return types.get(_join(target, reference_key), []) if target in namespaces else [];
            }
            return [];
        }
        key: any = _type_key(raw);
        if key is None {
            return [];
        }
        raw = key;
        first: any;
        tail: any;
        (first, _, tail) = raw.partition(".") as any;
        if absolute {
            return types.get(raw, []);
        }
        namespace: any = scopes[0][0];
        enclosing: any;
        for enclosing in _parents(owner) {
            if enclosing == namespace {
                break;
            }
            if _join(enclosing, first) in types {
                return types.get(_join(enclosing, raw), []);
            }
        }
        scope_by_namespace: any = {name: scope for (name, scope) in scopes};
        for enclosing in _parents(namespace) {
            visible: any = directives(file, scope_by_namespace[enclosing])
                if enclosing in scope_by_namespace
                else [];
            aliases = [
                (target, extra)
                for (target, extra) in visible
                if extra.get("csharp_alias") == first
            ];
            prefix: any = _join(enclosing, first);
            if prefix in namespaces or prefix in types {
                return [] if aliases else types.get(_join(enclosing, raw), []);
            }
            if aliases {
                if len(aliases) != 1 {
                    return [];
                }
                alias = import_target(*aliases[0]);
                return types.get(_join(alias, tail) if tail else alias, []) if alias else [];
            }
            imported: any = set[any]();
            for (target, extra) in visible {
                kind: any = extra.get("csharp_using_kind");
                if kind not in ("namespace", "static") {
                    continue;
                }
                imported_scope: any = import_target(target, extra);
                if imported_scope is None {
                    continue;
                }
                if kind == "namespace" and imported_scope not in namespaces {
                    continue;
                }
                if kind == "static" and imported_scope not in types {
                    continue;
                }
                candidate: any = _join(imported_scope, first);
                if candidate in types {
                    imported.add(candidate);
                }
            }
            if imported {
                if len(imported) != 1 {
                    return [];
                }
                prefix = next(iter(imported));
                return types.get(_join(prefix, tail) if tail else prefix, []);
            }
        }
        return [];
    }

    def targets(row, extra: dict) -> list[str] {
        scopes: any = extra.get("csharp_scopes");
        if not scopes or extra.get("receiver_resolution") == "shadowed_callable" {
            return [];
        }
        owner: any = extra.get("csharp_containing_type")
            or parents.get(row["source_qualified"], scopes[0][0]);
        kind: any = extra.get("csharp_call_kind");
        method: any = extra["csharp_raw_target"].rsplit("::", 1)[-1];
        receiver: any = extra.get("receiver_scope", "");
        for enclosing in _parents(owner) if kind == "unqualified" else (owner,) {
            if kind == "unqualified" and enclosing == scopes[0][0] {
                break;
            }
            if extra.get("receiver") == "this" or kind == "unqualified" {
                own_type: any = f"{row["file_path"]}::{enclosing}";
                candidates: any = [own_type] if own_type in parents else [];
                if own_type in partial_types {
                    candidates = [
                        c
                        for c in types.get(partial_types[own_type], [])
                        if c in partial_types
                            and projects[type_files[c]] == projects[row["file_path"]]
                    ];
                }
            } else {
                type_owner: any = owner;
                levels: any = extra.get("csharp_receiver_levels");
                if isinstance(levels, `int) and levels > 0 {
                    if owner.count(".") < levels {
                        return [];
                    }
                    type_owner = owner.rsplit(".", levels)[0];
                }
                candidates = type_targets(receiver, type_owner, scopes, row["file_path"]);
            }
            if len(candidates) > 1 {
                owners: any = {projects[type_files[c]] for c in candidates};
                if not all(c in partial_types for c in candidates)
                    or len(owners) != 1
                    or None in owners
                {
                    return [];
                }
            }
            if kind == "constructor" {
                return candidates;
            }
            found: any = [qn for c in candidates for qn in methods.get((c, method), [])];
            if found {
                if enclosing != owner and (len(found) != 1 or found[0] not in static_methods) {
                    return [];
                }
                return found;
            }
            if kind == "unqualified" and `any(c in based for c in candidates) {
                return [];
            }
        }
        return [];
    }

    resolved: any = 0;
    changed: any = False;
    with _binding_transaction(store) {
        for row in conn.execute(
            f"SELECT * FROM edges WHERE kind = 'CALLS' AND file_path IN ({csharp_files_sql})"
        ).fetchall() {
            extra = _extra(row["extra"]);
            raw: any = extra.get("csharp_raw_target");
            if row["file_path"] not in files or not isinstance(raw, `str) {
                continue;
            }
            candidates: any = targets(row, extra);
            target: any = candidates[0] if len(candidates) == 1 else raw;
            for key in ("unresolved_targets", "scoped_resolved", "scoped_via") {
                extra.pop(key, None);
            }
            if len(candidates) == 1 {
                extra.update(scoped_resolved=True, scoped_via="csharp_namespace");
            } else {
                extra["unresolved_targets"] = [];
            }
            if _set_call(store, row, target, extra) {
                resolved += operator.eq(len(candidates), 1);
                changed = True;
            }
        }
    }
    if changed {
        store._invalidate_cache();
    }
    return {"files_indexed": len(files), "calls_resolved": resolved};
}

impl _set_call(store: GraphStore, row, target: str, extra: dict) -> bool {
    if target == row["target_qualified"] and extra == _extra(row["extra"]) {
        return False;
    }
    serialized: any = json.dumps(extra, sort_keys=True);
    tier: any = "INFERRED" if extra.get("scoped_resolved") else "EXTRACTED";
    store._conn.execute(
        "UPDATE edges SET target_qualified = ?, extra = ?, confidence_tier = ? WHERE id = ?",
        (target, serialized, tier, row["id"]),
    );
    store._conn.execute(
        "UPDATE edges SET source_qualified = ?, extra = ?, confidence_tier = ? WHERE kind = 'TESTED_BY' AND source_qualified = ? AND target_qualified = ? AND file_path = ? AND line = ? AND extra = ?",
        (
            target,
            serialized,
            tier,
            row["target_qualified"],
            row["source_qualified"],
            row["file_path"],
            row["line"],
            row["extra"],
        ),
    );
    if target != row["target_qualified"] {
        store._conn.execute(
            "INSERT OR IGNORE INTO metadata (key, value) VALUES ('csharp_flows_dirty', '1')"
        );
    }
    return True;
}

impl restore_csharp_references(store: GraphStore, deleted_files: list[str]) {
    if not deleted_files {
        return;
    }
    deleted: any = `set(deleted_files);
    rows: any = store._conn.execute(
        "SELECT e.*, n.file_path AS target_file FROM edges e JOIN nodes n ON e.target_qualified = n.qualified_name WHERE e.kind = 'CALLS' AND n.language = 'csharp'",
    ).fetchall();
    changed: any = False;
    with _binding_transaction(store) {
        for row in rows {
            extra: any = _extra(row["extra"]);
            raw: any = extra.get("csharp_raw_target");
            if row["target_file"] not in deleted or not isinstance(raw, `str) {
                continue;
            }
            extra.pop("scoped_resolved", None);
            extra.pop("scoped_via", None);
            extra["unresolved_targets"] = [];
            changed = _set_call(store, row, raw, extra) or changed;
        }
    }
    if changed {
        store._invalidate_cache();
    }
}
