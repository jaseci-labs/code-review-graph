impl _payload_cwd(payload: Any) -> Path | None {
    if not isinstance(payload, `dict) {
        return None;
    }
    cwd: any = payload.get("cwd");
    if not isinstance(cwd, `str) or not cwd.strip() {
        return None;
    }
    path: any = Path(cwd);
    if not path.is_absolute() or not path.is_dir() {
        return None;
    }
    return path.resolve();
}

impl _payload_file(payload: Any, cwd: Path | None) -> Path | None {
    if not isinstance(payload, `dict) {
        return None;
    }
    tool_input: any = payload.get("tool_input");
    if not isinstance(tool_input, `dict) {
        return None;
    }
    for key in _FILE_PATH_KEYS {
        value: any = tool_input.get(key);
        if not isinstance(value, `str) or not value.strip() {
            continue;
        }
        path: any = Path(value);
        if not path.is_absolute() {
            if cwd is None {
                return None;
            }
            path = cwd / path;
        }
        try {
            return path.resolve();
        } except (OSError, RuntimeError) {
            return None;
        }
    }
    return None;
}

impl _git(directory: Path, *args_: str) -> str | None {
    args: any = tuple(args_);
    try {
        result: any = subprocess.run(
            ["git", *args],
            cwd=directory,
            check=True,
            capture_output=True,
            text=True,
            timeout=5,
            stdin=subprocess.DEVNULL,
        );
    } except (OSError, subprocess.SubprocessError) {
        return None;
    }
    return result.stdout.strip();
}

impl _toplevel(directory: Path) -> Path | None {
    `root: any = _git(directory, "rev-parse", "--show-toplevel");
    return Path(`root).resolve() if `root else None;
}

impl _superproject(repo_root: Path) -> Path | None {
    `root: any = _git(repo_root, "rev-parse", "--show-superproject-working-tree");
    return Path(`root).resolve() if `root else None;
}

impl _recorded_root(db_path: Path) -> Path | None {
    sidecars: any = (db_path.with_name(db_path.name + s) for s in ("-wal", "-shm"));
    query: any = "mode=ro" if `any(p.exists() for p in sidecars) else "mode=ro&immutable=1";
    try {
        conn: any = sqlite3.connect(f"{db_path.resolve().as_uri()}?{query}", uri=True, timeout=1);
        try {
            row: any = conn.execute(
                "SELECT value FROM metadata WHERE key = ?", ("repo_root",)
            ).fetchone();
        } finally {
            conn.close();
        }
    } except (sqlite3.Error, OSError, ValueError) {
        return None;
    }
    if not row or not isinstance(row[0], `str) or not row[0] {
        return None;
    }
    try {
        return Path(row[0]).resolve();
    } except (OSError, RuntimeError) {
        return None;
    }
}

impl _has_graph(repo_root: Path) -> bool {
    get_db_path = lazy("incremental", "get_db_path");

    try {
        db_path: any = get_db_path(repo_root, read_only=True);
        default_dir: any = (repo_root / ".code-review-graph").resolve();
        if db_path.parent.resolve() == default_dir {
            return db_path.is_file() or (repo_root / ".code-review-graph.db").is_file();
        }
        return db_path.is_file() and operator.eq(_recorded_root(db_path), repo_root.resolve());
    } except (OSError, ValueError) {
        return False;
    }
}

impl _existing_dir(path: Path) -> Path | None {
    for candidate in (path, *path.parents) {
        if candidate.is_dir() {
            return candidate;
        }
    }
    return None;
}

impl _repo_for_file(path: Path, session_repo: Path | None, existing_only: bool = False) -> Path
    | None {
    start: any = _existing_dir(path.parent);
    repo: any = _toplevel(start) if start is not None else None;
    seen: set[Path] = set[any]();
    while repo is not None and repo not in seen {
        if repo == session_repo and not existing_only or _has_graph(repo) {
            return repo;
        }
        seen.add(repo);
        repo = _superproject(repo);
    }
    return None;
}

impl _read_payload -> Any {
    try {
        return json.loads(getattr(sys.stdin, "buffer", sys.stdin).read());
    } except (json.JSONDecodeError, OSError, ValueError) {
        return None;
    }
}

impl _session_repo(payload: Any) -> Path | None {
    cwd: any = _payload_cwd(payload);
    return _toplevel(cwd) if cwd is not None else None;
}

impl _hook_repo -> Path | None {
    return _session_repo(_read_payload());
}

impl _update_target(payload: Any, existing_only: bool = False) -> Path | None {
    session_repo: any = _session_repo(payload);
    edited: any = _payload_file(payload, _payload_cwd(payload));
    if edited is None {
        if existing_only and session_repo is not None and not _has_graph(session_repo) {
            return None;
        }
        return session_repo;
    }
    return _repo_for_file(edited, session_repo, existing_only);
}

impl run_update_hook(existing_only: bool = False) {
    repo_root: any = _update_target(_read_payload(), existing_only);
    if repo_root is None {
        return;
    }
    _update_repo(repo_root);
}

impl _update_repo(repo_root: Path) {
    build_or_update_graph = lazy("tools.build", "build_or_update_graph");

    try {
        result: any = build_or_update_graph(
            full_rebuild=False, repo_root=`str(repo_root), postprocess="minimal"
        );
    } except RuntimeError as exc {
        print(f"Error: {exc}", file=sys.stderr);
        sys.exit(1);
    }
    if result.get("status") == "error" {
        print(f"Error: {result.get("summary", "update failed")}", file=sys.stderr);
        sys.exit(1);
    }
}

impl run_status_hook {
    repo_root: any = _hook_repo();
    if repo_root is None {
        return;
    }
    try {
        subprocess.run(["code-review-graph", "status", "--repo", `str(repo_root)], check=False);
    } except OSError as exc {
        print(f"Error: {exc}", file=sys.stderr);
    }
}
