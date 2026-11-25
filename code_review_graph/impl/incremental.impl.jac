impl _get_code_parser_cls -> any {
    cls: any = globals().get("CodeParser");
    if cls is None {
        import from .parser { CodeParser }

        globals()["CodeParser"] = CodeParser;
        return CodeParser;
    }
    return cls;
}

impl __getattr__(name: str) -> any {
    if name == "CodeParser" {
        import from .parser { CodeParser }
        globals()["CodeParser"] = CodeParser;
        return CodeParser;
    }
    raise AttributeError(f"module {__name__!r} has no attribute {name!r}");
}

impl _windows_console_handle(fileno: int) -> bool {
    comptime if target_().os != "windows" {
        return False;
    }
    try {
        import ctypes;
        import msvcrt;
    } except ImportError {
        return False;
    }
    try {
        handle: any = msvcrt.get_osfhandle(fileno);
        mode: any = ctypes.c_uint32();
        return `bool(ctypes.windll.kernel32.GetConsoleMode(handle, ctypes.byref(mode)));
    } except Exception as exc {
        expected: Any = (AttributeError, OSError, ValueError, ctypes.ArgumentError);
        if not isinstance(exc, expected) {
            raise;
        }
        return False;
    }
}

impl _stdin_is_interactive -> bool {
    try {
        if not sys.stdin.isatty() {
            return False;
        }
        comptime if target_().os == "windows" {
            return _windows_console_handle(sys.stdin.fileno());
        }
    } except (AttributeError, OSError, ValueError) {
        return False;
    }
    return True;
}

impl _select_executor_kind -> str {
    explicit: any = os.environ.get("CRG_PARSE_EXECUTOR", "").strip().lower();
    if explicit in ("process", "thread") {
        return explicit;
    }
    comptime if False {
        return "thread";
    }
    comptime if target_().os == "windows" {
        if not _stdin_is_interactive() {
            return "thread";
        }
    }
    return "process";
}

impl _make_executor(max_workers: int) -> any {
    if _select_executor_kind() == "thread" {
        return concurrent.futures.ThreadPoolExecutor(max_workers=max_workers);
    }
    return concurrent.futures.ProcessPoolExecutor(max_workers=max_workers);
}

impl _load_pending_paths(store: GraphStore, key: str) -> set[str] {
    try {
        files: any = json.loads(store.get_metadata(key) or "[]");
    } except (TypeError, ValueError) {
        return set[any]();
    }
    if not isinstance(files, `list) {
        return set[any]();
    }
    return {
        path
        for path in files
        if isinstance(path, `str)
            and path
            and not Path(path).is_absolute()
            and ".." not in Path(path).parts
    };
}

impl _nested_scope_files(store: GraphStore, repo_root: Path) -> set[str] {
    placeholders: any = ",".join("?" for _ in _NESTED_SCOPE_UNCHANGED_LANGUAGES);
    rows: any = store._conn.execute(
        f"SELECT DISTINCT file_path FROM nodes WHERE kind = 'Class' AND parent_name IS NOT NULL AND language NOT IN ({placeholders})",
        _NESTED_SCOPE_UNCHANGED_LANGUAGES,
    );
    return {
        Path(row[0]).relative_to(repo_root).as_posix()
        for row in rows
        if Path(row[0]).is_relative_to(repo_root)
    };
}

impl _load_dependents_pending(store: GraphStore) -> set[str] {
    try {
        files: any = json.loads(store.get_metadata(_DEPENDENTS_PENDING_KEY) or "[]");
    } except (TypeError, ValueError) {
        return set[any]();
    }
    if not isinstance(files, `list) {
        return set[any]();
    }
    return {
        path
        for path in files
        if isinstance(path, `str)
            and path
            and not Path(path).is_absolute()
            and ".." not in Path(path).parts
    };
}

impl _load_cpp_identity_pending(store: GraphStore) -> set[str] | None {
    try {
        state: any = json.loads(store.get_metadata(_CPP_IDENTITY_PENDING_KEY) or "null");
    } except (TypeError, ValueError) {
        return None;
    }
    if not isinstance(state, `dict) or state.get("version") != CPP_IDENTITY_VERSION {
        return None;
    }
    files: any = state.get("files");
    if not isinstance(files, `list)
        or `any(
            not isinstance(path, `str)
                or not path
                or Path(path).is_absolute()
                or ".." in Path(path).parts
            for path in files,
        )
    {
        return None;
    }
    return `set(files);
}

impl _store_cpp_identity_pending(store: GraphStore, files: set[str]) -> None {
    if not files {
        store.set_metadata(_CPP_IDENTITY_METADATA_KEY, CPP_IDENTITY_VERSION);
    }
    store.set_metadata(
        _CPP_IDENTITY_PENDING_KEY,
        json.dumps({"version": CPP_IDENTITY_VERSION, "files": sorted(files)}),
    );
}

impl _run_python_resolver(store: GraphStore) -> Optional[dict] {
    try {
        import from .python_resolver { resolve_python_imports }
        return resolve_python_imports(store);
    } except Exception as exc {
        logger.warning("Python import resolver failed: %s", exc);
        return None;
    }
}

impl _run_rescript_resolver(store: GraphStore) -> Optional[dict] {
    try {
        import from .rescript_resolver { resolve_rescript_cross_module }
        return resolve_rescript_cross_module(store);
    } except Exception as exc {
        logger.warning("ReScript cross-module resolver failed: %s", exc);
        return None;
    }
}

impl _run_spring_resolver(store: GraphStore) -> Optional[dict] {
    try {
        import from .spring_resolver { resolve_spring_di_calls }
        return resolve_spring_di_calls(store);
    } except Exception as exc {
        logger.warning("Spring DI resolver failed: %s", exc);
        return None;
    }
}

impl _run_aop_resolver(store: GraphStore) -> Optional[dict] {
    try {
        import from .aop_resolver { resolve_aop_advice }
        return resolve_aop_advice(store);
    } except Exception as exc {
        logger.warning("AOP resolver failed: %s", exc);
        return None;
    }
}

impl _run_spring_event_resolver(store: GraphStore) -> Optional[dict] {
    try {
        import from .event_resolver { resolve_spring_events }
        return resolve_spring_events(store);
    } except Exception as exc {
        logger.warning("Spring event resolver failed: %s", exc);
        return None;
    }
}

impl _run_temporal_resolver(store: GraphStore) -> Optional[dict] {
    try {
        import from .temporal_resolver { resolve_temporal_calls }
        return resolve_temporal_calls(store);
    } except Exception as exc {
        logger.warning("Temporal resolver failed: %s", exc);
        return None;
    }
}

impl _run_hcl_resolver(store: GraphStore) -> Optional[dict] {
    try {
        import from .hcl_resolver { resolve_hcl_module_references }
        return resolve_hcl_module_references(store);
    } except Exception as exc {
        logger.warning("Terraform/HCL resolver failed: %s", exc);
        return None;
    }
}

impl _run_scoped_resolver(store: GraphStore, repo_root: Path) -> Optional[dict] {
    try {
        import from .scoped_resolver { resolve_scoped_calls }
        return resolve_scoped_calls(store, repo_root);
    } except Exception as exc {
        logger.warning("Scoped call resolver failed: %s", exc);
        return None;
    }
}

impl _enrichment_skip_reason(enrich: Optional[bool]) -> Optional[str] {
    if os.environ.get("CRG_DISABLE_ENRICHMENT", "") == "1" {
        return "disabled via CRG_DISABLE_ENRICHMENT";
    }
    if enrich is None {
        enrich = operator.eq(os.environ.get("CRG_ENABLE_ENRICHMENT", ""), "1");
    }
    return None if enrich else "not requested";
}

impl _run_jedi_enrichment(
    store: GraphStore,
    repo_root: Path,
    files: Optional[list[str]] = None,
    enrich: Optional[bool] = None,
) -> Optional[dict] {
    reason: any = _enrichment_skip_reason(enrich);
    if reason is not None {
        return {"skipped": True, "reason": reason};
    }
    try {
        import from .jedi_resolver { enrich_jedi_calls }
        return enrich_jedi_calls(store, repo_root, files=files);
    } except Exception as exc {
        logger.warning("Jedi enrichment failed: %s", exc);
        return None;
    }
}

impl _refresh_target_resolution(store: GraphStore) -> None {
    try {
        store.refresh_target_resolution();
    } except Exception as exc {
        logger.warning("Target-resolution refresh failed: %s", exc);
    }
}

impl find_svn_root(start: Path | None = None) -> Optional[Path] {
    current: any = start or Path.cwd();
    candidate: Optional[Path] = None;
    while current != current.parent {
        if (current / ".svn").exists() {
            candidate = current;
        }
        current = current.parent;
    }
    if (current / ".svn").exists() {
        candidate = current;
    }
    return candidate;
}

impl find_repo_root(start: Path | None = None, stop_at: Path | None = None) -> Optional[Path] {
    current: any = start or Path.cwd();
    while current != current.parent {
        if (current / ".git").exists() {
            return current;
        }
        if stop_at is not None and current == stop_at {
            return None;
        }
        current = current.parent;
    }
    if (current / ".git").exists() {
        return current;
    }
    return find_svn_root(start);
}

impl detect_vcs(`root: Path) -> str {
    current: any = `root;
    while True {
        if (current / ".git").exists() {
            return "git";
        }
        if (current / ".svn").exists() {
            return "svn";
        }
        if current == current.parent {
            break;
        }
        current = current.parent;
    }
    return "none";
}

impl _git_worktree_prefix(repo_root: Path) -> str {
    requested_root: any = Path(repo_root).expanduser().resolve();
    current: any = requested_root;
    while True {
        if (current / ".git").exists() {
            if current == requested_root {
                return "";
            }
            return requested_root.relative_to(current).as_posix();
        }
        if current == current.parent {
            return "";
        }
        current = current.parent;
    }
}

impl find_project_root(start: Path | None = None, stop_at: Path | None = None) -> Path {
    env_override: any = os.environ.get("CRG_REPO_ROOT", "").strip();
    if env_override {
        p: any = Path(env_override).expanduser().resolve();
        if p.exists() {
            return p;
        }
    }
    `root: any = find_repo_root(start, stop_at=stop_at);
    if `root {
        return `root;
    }
    return start or Path.cwd();
}

impl _write_data_dir_gitignore(data_dir: Path) -> None {
    inner_gitignore: any = data_dir / ".gitignore";
    if not inner_gitignore.exists() {
        try {
            inner_gitignore.write_text(
                "# Auto-generated by code-review-graph — do not commit database files.\n# The graph.db contains absolute paths and code structure metadata.\n*\n",
                encoding="utf-8",
            );
        } except OSError {}
    }
}

impl _create_data_dir(data_dir: Path) -> None {
    try {
        data_dir.mkdir(parents=True, exist_ok=True);
    } except OSError as exc {
        raise GraphStoreError(
            f"cannot create the graph data directory at {data_dir} ({exc}). Check the permissions on {data_dir.parent}, or set CRG_DATA_DIR to a writable directory.",
        ) from exc;
    }
    _write_data_dir_gitignore(data_dir);
}

impl get_data_dir(repo_root: Path, *, create: bool = True) -> Path {
    try {
        import from .registry { Registry, default_registry_path }
        if create or default_registry_path().is_file() {
            registry_data_dir: any = Registry().get_data_dir_for_repo(`str(repo_root));
            if registry_data_dir {
                data_dir: any = Path(registry_data_dir).resolve();
                local_dir: any = repo_root / ".code-review-graph";
                if not data_dir.exists() and (local_dir / "graph.db").is_file() {
                    logger.warning(
                        "Registered graph directory %s is missing; falling back to normal resolution (local graph: %s).",
                        data_dir,
                        local_dir,
                    );
                } else {
                    if create {
                        _create_data_dir(data_dir);
                    }
                    return data_dir;
                }
            }
        }
    } except Exception as exc {
        logger.debug("Registry lookup failed for %s: %s", repo_root, exc);
    }
    env_override: any = os.environ.get("CRG_DATA_DIR", "").strip();
    if env_override {
        data_dir = Path(env_override).expanduser().resolve();
    } else {
        data_dir = repo_root / ".code-review-graph";
    }

    if create {
        _create_data_dir(data_dir);
    }

    return data_dir;
}

impl get_db_path(repo_root: Path, *, read_only: bool = False) -> Path {
    forced_read_only: any = read_only_requested();
    no_writes: any = read_only or forced_read_only;
    crg_dir: any = get_data_dir(repo_root, create=not no_writes);
    new_db: any = crg_dir / "graph.db";

    if no_writes {
        legacy_db: any = repo_root / ".code-review-graph.db";
        default_dir: any = repo_root / ".code-review-graph";
        if forced_read_only
            and not new_db.exists()
            and legacy_db.is_file()
            and crg_dir.resolve() == default_dir.resolve()
        {
            return legacy_db;
        }
        return new_db;
    }

    _prepare_db_path(repo_root, new_db);
    return new_db;
}

impl _prepare_db_path(repo_root: Path, new_db: Path) -> None {
    _create_data_dir(new_db.parent);
    legacy_db: any = repo_root / ".code-review-graph.db";
    if legacy_db.exists() and not new_db.exists() {
        legacy_db.rename(new_db);
    }
    for suffix in ("-wal", "-shm", "-journal") {
        side: any = repo_root / f".code-review-graph.db{suffix}";
        if side.exists() {
            side.unlink();
        }
    }
}

impl ensure_repo_gitignore_excludes_crg(repo_root: Path) -> str {
    gitignore_path: any = repo_root / ".gitignore";
    existing: any = install_plan.read_text(gitignore_path, encoding="utf-8")
        if install_plan.exists(gitignore_path)
        else "";

    for raw_line in existing.splitlines() {
        line: any = raw_line.strip();
        if not line or line.startswith("#") {
            continue;
        }
        if line == ".code-review-graph" or line.startswith(".code-review-graph/") {
            return "already-present";
        }
    }

    block: any = "# Added by code-review-graph\n.code-review-graph/\n";
    prefix: any = "\n" if existing and not existing.endswith("\n") else "";
    install_plan.write_text(gitignore_path, existing + prefix + block);

    if existing {
        return "updated";
    }
    return "created";
}

impl _load_ignore_patterns(repo_root: Path) -> list[str] {
    vendor_dependencies: any = `any(
        (repo_root / manifest).is_file() for manifest in NESTED_OUTPUT_DIR_MARKERS["vendor"]
    )
        or `any(path.is_file() for path in repo_root.glob("*.gemspec"));
    patterns: any = [
        pattern
        for pattern in DEFAULT_IGNORE_PATTERNS
        if pattern != "**/vendor/**" or vendor_dependencies
    ];
    keep: list[str] = [];
    ignore_file: any = repo_root / ".code-review-graphignore";
    if ignore_file.exists() {
        line: any;
        for line in ignore_file.read_text(encoding="utf-8", errors="replace").splitlines() {
            line = line.strip();
            if line and not line.startswith("#") {
                if line.startswith("!") {
                    keep.append(line[1:].strip().strip("/"));
                    continue;
                }
                if line.endswith("/") {
                    prefix: any = line[:-1];
                    if prefix.startswith("/") or "/" in prefix {
                        line = f"{prefix}/**";
                    } else {
                        line = f"**/{prefix}/**";
                    }
                } elif line.endswith("/**") and not line.startswith(("/", "**/")) {
                    prefix = line[:-3];
                    if "/" in prefix {
                        line = f"/{line}";
                    } else {
                        line = f"**/{line}";
                    }
                }
                if line {
                    patterns.append(line);
                }
            }
        }
    }
    patterns.extend(_nested_output_ignore_patterns(repo_root, patterns, `tuple(keep)));
    return patterns;
}

impl _should_ignore(path: str, patterns: list[str]) -> bool {
    normalized: any = path.replace("\\", "/").lstrip("/");
    parts: any = PurePosixPath(normalized).parts;
    for pattern in patterns {
        anchored: any = pattern.startswith("/");
        candidate: any = pattern[1:] if anchored else pattern;

        if candidate.startswith("**/") and candidate.endswith("/**") {
            segment: any = candidate[3:-3];
            if segment and segment in parts {
                return True;
            }
            continue;
        }

        if candidate.endswith("/**") {
            prefix: any = `tuple(part for part in candidate[:-3].split("/") if part);
            if not prefix {
                continue;
            }
            if anchored or len(prefix) > 1 {
                if parts[:len(prefix)] == prefix {
                    return True;
                }
            } elif prefix[0] in parts {
                return True;
            }
            continue;
        }

        if fnmatch.fnmatch(normalized, candidate) {
            return True;
        }
    }
    return False;
}

impl _child_directories(directory: Path) -> list[tuple[str, bool]] {
    try {
        entries: any;
        with os.scandir(directory) as entries {
            listing: list[tuple[str, bool]] = [];
            for `entry in entries {
                try {
                    listing.append((`entry.name, `entry.is_dir(follow_symlinks=False)));
                } except OSError {
                    continue;
                }
            }
        }
    } except OSError as exc {
        logger.debug("Cannot list %s: %s", directory, exc);
        return [];
    }
    listing.sort();
    return listing;
}

impl _scan_nested_output_dirs(
    repo_root: Path,
    base_patterns: list[str],
    max_depth: int = max_depth_default_,
    max_dirs: int = max_dirs_default_,
) -> list[str] {
    name: any;
    patterns: list[str] = [];
    queue: list[tuple[Path, int]] = [(repo_root, 0)];
    visited: any = 0;
    while queue {
        directory: any;
        depth: any;
        (directory, depth) = queue.pop() as any;
        visited += 1;
        if visited > max_dirs {
            logger.debug("Nested output scan hit the %d directory cap", max_dirs);
            break;
        }
        listing: any = _child_directories(directory);
        subdirectories: any = {name for (name, is_dir) in listing if is_dir};
        file_names: any = {name for (name, is_dir) in listing if not is_dir};
        flagged: set[str] = set[any]();
        if depth > 0 {
            for (output_dir, markers) in NESTED_OUTPUT_DIR_MARKERS.items() {
                has_marker: any = `bool(file_names & markers)
                    or operator.eq(output_dir, "vendor")
                        and `any(name.endswith(".gemspec") for name in file_names);
                if has_marker and output_dir not in file_names {
                    relative: any = (directory / output_dir).relative_to(repo_root).as_posix();
                    patterns.append(f"/{relative}/**");
                    flagged.add(output_dir);
                    if len(patterns) >= _MAX_NESTED_OUTPUT_PATTERNS {
                        logger.debug("Nested output scan hit the pattern cap");
                        return patterns;
                    }
                }
            }
        }
        if depth >= max_depth {
            continue;
        }
        for name in subdirectories {
            if name in flagged {
                continue;
            }
            child: any = directory / name;
            if _should_ignore(child.relative_to(repo_root).as_posix(), base_patterns) {
                continue;
            }
            queue.append((child, depth + 1));
        }
    }
    return patterns;
}

impl _nested_output_ignore_patterns(
    repo_root: Path, base_patterns: list[str], keep: tuple[str, ...] = ()
) -> list[str] {
    if os.environ.get("CRG_NESTED_OUTPUT_SCAN", "1").strip().lower() in ("0", "false", "no") {
        return [];
    }
    key: any = (`str(repo_root), keep, `tuple(base_patterns));
    now: any = time.monotonic();
    with _nested_ignore_lock {
        cached: any = _nested_ignore_cache.get(key);
        if cached is not None and now - cached[0] < _NESTED_IGNORE_TTL_SECONDS {
            return `list(cached[1]);
        }
    }
    patterns: any = _scan_nested_output_dirs(repo_root, base_patterns);
    if keep {
        spared: any = {`entry.replace("\\", "/").strip("/") for `entry in keep};
        patterns = [pattern for pattern in patterns if pattern[1:-3] not in spared];
    }
    if patterns {
        logger.info(
            "Excluding %d nested build-output director%s (a sibling manifest marks them as build output; keep one with '!<path>' in .code-review-graphignore): %s",
            len(patterns),
            "y" if len(patterns) == 1 else "ies",
            ", ".join(pattern[1:-3] for pattern in patterns[:10])
                + (" …" if len(patterns) > 10 else ""),
        );
    }
    with _nested_ignore_lock {
        _nested_ignore_cache[key] = (time.monotonic(), patterns);
    }
    return `list(patterns);
}

impl clear_nested_ignore_cache(repo_root: Path | None = None) -> None {
    with _nested_ignore_lock {
        if repo_root is None {
            _nested_ignore_cache.clear();
        } else {
            for key in `list(_nested_ignore_cache) {
                if key[0] == `str(repo_root) {
                    del _nested_ignore_cache[key];
                }
            }
        }
    }
}

impl _is_binary(path: Path) -> bool {
    try {
        handle: any;
        with path.open("rb") as handle {
            chunk: any = handle.read(8192);
        }
        return b"\x00" in chunk;
    } except (OSError, PermissionError) {
        return True;
    }
}

impl _git_branch_info(repo_root: Path) -> tuple[str, str] {
    branch: any = "";
    sha: any = "";
    try {
        result: any = subprocess.run(
            ["git", "rev-parse", "--abbrev-ref", "HEAD"],
            capture_output=True,
            text=True,
            encoding="utf-8",
            errors="replace",
            cwd=`str(repo_root),
            timeout=_GIT_TIMEOUT,
            stdin=subprocess.DEVNULL,
        );
        if result.returncode == 0 {
            branch = result.stdout.strip();
        }
    } except (subprocess.TimeoutExpired, FileNotFoundError, UnicodeDecodeError) {}
    try {
        result = subprocess.run(
            ["git", "rev-parse", "HEAD"],
            capture_output=True,
            text=True,
            encoding="utf-8",
            errors="replace",
            cwd=`str(repo_root),
            timeout=_GIT_TIMEOUT,
            stdin=subprocess.DEVNULL,
        );
        if result.returncode == 0 {
            sha = result.stdout.strip();
        }
    } except (subprocess.TimeoutExpired, FileNotFoundError, UnicodeDecodeError) {}
    return (branch, sha);
}

impl _svn_revision_info(repo_root: Path) -> tuple[str, str] {
    branch: any = "";
    rev: any = "";
    try {
        result: any = subprocess.run(
            ["svn", "info", "--non-interactive"],
            capture_output=True,
            text=True,
            encoding="utf-8",
            errors="replace",
            cwd=`str(repo_root),
            timeout=_GIT_TIMEOUT,
            stdin=subprocess.DEVNULL,
        );
        if result.returncode == 0 {
            for line in result.stdout.splitlines() {
                if line.startswith("URL: ") {
                    url: any = line[5:].strip();
                    for marker in ("/branches/", "/tags/", "/trunk") {
                        if marker in url {
                            idx: any = url.index(marker);
                            branch = url[idx:].lstrip("/");
                            break;
                        }
                    }
                    if not branch and url {
                        branch = url.rstrip("/").split("/")[-1];
                    }
                } elif line.startswith("Revision: ") {
                    rev = line[10:].strip();
                }
            }
        }
    } except (subprocess.TimeoutExpired, FileNotFoundError) {}
    return (branch, rev);
}

impl _decode_name_status_paths(output: bytes) -> list[str] {
    fields: any = [os.fsdecode(f) for f in output.split(b"\x00") if f];
    paths: list[str] = [];
    seen: set[str] = set[any]();
    i: any = 0;
    while i < len(fields) {
        status: any = fields[i];
        takes_two: any = status[:1] in ("R", "C");
        `entry: any = fields[i + 1:i + (3 if takes_two else 2)];
        i += 3 if takes_two else 2;
        for path in `entry {
            if path not in seen {
                seen.add(path);
                paths.append(path);
            }
        }
    }
    return paths;
}

impl _store_vcs_metadata(repo_root: Path, store: "GraphStore") -> bool {
    store.set_metadata("repo_root", `str(repo_root));
    vcs: any = detect_vcs(repo_root);
    if vcs == "git" {
        branch: any;
        sha: any;
        (branch, sha) = _git_branch_info(repo_root) as any;
        if branch {
            store.set_metadata("git_branch", branch);
        }
        if sha {
            store.set_metadata("git_head_sha", sha);
            return True;
        }
    } elif vcs == "svn" {
        rev: any;
        (branch, rev) = _svn_revision_info(repo_root) as any;
        if branch {
            store.set_metadata("svn_branch", branch);
        }
        if rev {
            store.set_metadata("svn_revision", rev);
            return True;
        }
    }
    return False;
}

impl _commit_object_exists(repo_root: Path, ref: str) -> bool {
    if not ref or ref.startswith("-") or not _SAFE_GIT_REF.fullmatch(ref) {
        return False;
    }
    try {
        result: any = subprocess.run(
            ["git", "rev-parse", "--verify", "--quiet", f"{ref}^{{commit}}"],
            capture_output=True,
            cwd=`str(repo_root),
            timeout=_GIT_TIMEOUT,
            stdin=subprocess.DEVNULL,
        );
        return operator.eq(result.returncode, 0);
    } except (OSError, subprocess.TimeoutExpired) {
        return False;
    }
}

impl resolve_incremental_base(repo_root: Path, store: "GraphStore") -> str | None {
    if detect_vcs(repo_root) != "git" {
        return "HEAD~1";
    }
    stored: any = store.get_metadata("git_head_sha");
    if stored and _commit_object_exists(repo_root, stored) {
        return stored;
    }
    return None;
}

impl resolve_review_base(
    repo_root: Path, base: str, *, timeout: float | None = None, require_vcs: bool = False
) -> str {
    if timeout is None {
        timeout = _GIT_TIMEOUT;
    }
    if detect_vcs(repo_root) != "git"
        or not base
        or base.startswith("-")
        or not _SAFE_GIT_REF.fullmatch(base)
    {
        return base;
    }

    try {
        symbolic: any = subprocess.run(
            ["git", "rev-parse", "--symbolic-full-name", "--verify", base],
            capture_output=True,
            text=True,
            encoding="utf-8",
            errors="replace",
            cwd=`str(repo_root),
            timeout=timeout,
            stdin=subprocess.DEVNULL,
        );
        symbolic_ref: any = symbolic.stdout.strip();
        if symbolic.returncode != 0
            or not symbolic_ref.startswith(("refs/heads/", "refs/remotes/"))
        {
            return base;
        }

        result: any = subprocess.run(
            ["git", "merge-base", base, "HEAD"],
            capture_output=True,
            text=True,
            encoding="utf-8",
            errors="replace",
            cwd=`str(repo_root),
            timeout=timeout,
            stdin=subprocess.DEVNULL,
        );
        resolved: any = result.stdout.strip();
        if result.returncode == 0 and re.fullmatch("[0-9a-fA-F]{40,64}", resolved) {
            return resolved;
        }
    } except (OSError, subprocess.TimeoutExpired) as exc {
        if require_vcs {
            raise _vcs_unavailable("git", exc, timeout=timeout) from exc;
        }
    }

    logger.debug("Could not resolve review merge base for %s; using it directly", base);
    return base;
}

impl _vcs_unavailable(
    tool: str, exc: BaseException, *, timeout: float | None = None
) -> ChangeDiscoveryError {
    if isinstance(exc, subprocess.TimeoutExpired) {
        budget: any = _GIT_TIMEOUT if timeout is None else timeout;
        knob: any = "CRG_GIT_TIMEOUT"
            if timeout is None or budget >= _GIT_TIMEOUT
            else "CRG_DISCOVERY_TIMEOUT";
        return ChangeDiscoveryError(
            f"could not determine the changes: {tool} timed out after {budget:g}s. Raise {knob}, or re-run when the repository is not busy.",
        );
    }
    return ChangeDiscoveryError(
        f"could not determine the changes: {tool} could not be run ({exc}). Install {tool} and make sure it is on PATH.",
    );
}

impl get_changed_files(
    repo_root: Path,
    base: str = "HEAD~1",
    *,
    strict: bool = False,
    timeout: float | None = None,
    require_vcs: bool = False,
) -> list[str] {
    if timeout is None {
        timeout = _GIT_TIMEOUT;
    }
    if detect_vcs(repo_root) == "svn" {
        return _get_svn_changed_files(
            repo_root,
            base if _SAFE_SVN_REV.match(base) else None,
            timeout=timeout,
            require_vcs=require_vcs or strict,
        );
    }
    if base.startswith("-") or not _SAFE_GIT_REF.fullmatch(base) {
        logger.warning("Invalid git ref rejected: %s", base);
        if strict {
            raise ChangeDiscoveryError(f"invalid git diff base: {base}");
        }
        return [];
    }
    try {
        result: any = subprocess.run(
            ["git", "diff", "--relative", "--name-status", "-z", base, "--", "."],
            capture_output=True,
            cwd=`str(repo_root),
            timeout=timeout,
            stdin=subprocess.DEVNULL,
        );
        if result.returncode != 0 {
            if strict {
                raise ChangeDiscoveryError(
                    f"git diff failed while discovering changed files (rc={result.returncode})"
                );
            }
            return get_staged_and_unstaged(repo_root, timeout=timeout, require_vcs=require_vcs);
        }
        if result.returncode != 0 {
            logger.warning("git diff failed while discovering changed files");
            return [];
        }
        changed: any = _decode_name_status_paths(result.stdout);
        if not changed {
            return get_staged_and_unstaged(
                repo_root, timeout=timeout, require_vcs=require_vcs or strict
            );
        }
        untracked: any = _get_untracked_files(
            repo_root, timeout=timeout, require_vcs=require_vcs or strict
        );
        return `list(dict.fromkeys([*changed, *untracked]));
    } except (OSError, subprocess.TimeoutExpired) as exc {
        if strict {
            raise ChangeDiscoveryError("git change discovery failed") from exc;
        }
        if require_vcs {
            raise _vcs_unavailable("git", exc, timeout=timeout) from exc;
        }
        return [];
    }
}

impl _find_content_mismatches(
    repo_root: Path, store: "GraphStore", only: set[str] | None = None
) -> tuple[list[str], dict[str, str], set[str]] {
    mismatched_files: list[str] = [];
    current_hashes: dict[str, str] = {};
    text_files: set[str] = set[any]();

    for (stored_path, stored_hash) in store.get_file_hashes().items() {
        if only is not None and stored_path not in only {
            continue;
        }
        path: any = Path(stored_path);
        if not path.is_absolute() {
            path = repo_root / path;
        }
        try {
            relative_path: any = path.relative_to(repo_root).as_posix();
            raw: any = path.read_bytes();
            current_hash: any = hashlib.sha256(raw).hexdigest();
            current_hashes[relative_path] = current_hash;
        } except (OSError, ValueError) {
            continue;
        }
        if b"\x00" not in raw[:8192] {
            text_files.add(stored_path);
        }
        if current_hash != stored_hash {
            mismatched_files.append(relative_path);
        }
    }

    return (mismatched_files, current_hashes, text_files);
}

impl _get_svn_changed_files(
    repo_root: Path,
    rev_range: str | None = None,
    *,
    timeout: float | None = None,
    require_vcs: bool = False,
) -> list[str] {
    if timeout is None {
        timeout = _GIT_TIMEOUT;
    }
    try {
        if rev_range {
            result: any = subprocess.run(
                ["svn", "diff", "--summarize", "--non-interactive", "-r", rev_range],
                capture_output=True,
                text=True,
                encoding="utf-8",
                errors="replace",
                cwd=`str(repo_root),
                timeout=timeout,
                stdin=subprocess.DEVNULL,
            );
            if result.returncode != 0 {
                logger.warning(
                    "svn diff --summarize failed (rc=%d): %s",
                    result.returncode,
                    result.stderr[:200],
                );
                return [];
            }
            files: any = [];
            line: any;
            for line in result.stdout.splitlines() {
                if len(line) >= 2 and line[0] in ("M", "A", "D") {
                    files.append(line[1:].strip());
                }
            }
            return files;
        }
        result = subprocess.run(
            ["svn", "status", "--non-interactive"],
            capture_output=True,
            text=True,
            encoding="utf-8",
            errors="replace",
            cwd=`str(repo_root),
            timeout=timeout,
            stdin=subprocess.DEVNULL,
        );
        files = [];
        for line in result.stdout.splitlines() {
            if len(line) < 2 {
                continue;
            }
            status_char: any = line[0];
            if status_char in ("M", "A", "D", "R", "C") {
                path: any = line[8:].strip() if len(line) > 8 else line[1:].strip();
                files.append(path);
            }
        }
        return files;
    } except (OSError, subprocess.TimeoutExpired) as exc {
        if require_vcs {
            raise _vcs_unavailable("svn", exc, timeout=timeout) from exc;
        }
        return [];
    } except UnicodeDecodeError {
        return [];
    }
}

impl _utf8_paths(paths: Iterable[str]) -> list[str] {
    kept: any = [];
    for path in paths {
        try {
            path.encode("utf-8");
        } except UnicodeEncodeError {
            logger.debug("Skipping path that is not UTF-8: %r", path[:120]);
            continue;
        }
        kept.append(path);
    }
    return kept;
}

impl get_staged_and_unstaged(
    repo_root: Path, *, timeout: float | None = None, require_vcs: bool = False
) -> list[str] {
    if timeout is None {
        timeout = _GIT_TIMEOUT;
    }
    if detect_vcs(repo_root) == "svn" {
        return _get_svn_changed_files(repo_root, timeout=timeout, require_vcs=require_vcs);
    }
    try {
        result: any = subprocess.run(
            ["git", "status", "--porcelain=v1", "-z", "--untracked-files=all", "--", "."],
            capture_output=True,
            cwd=`str(repo_root),
            timeout=timeout,
            stdin=subprocess.DEVNULL,
        );
        if result.returncode != 0 {
            logger.warning("git status failed while discovering working-tree files");
            return [];
        }
        files: list[str] = [];
        untracked: set[str] = set[any]();
        prefix: any = _git_worktree_prefix(repo_root);
        prefix_with_separator: any = f"{prefix}/" if prefix else "";
        records: any = result.stdout.split(b"\x00");
        index: any = 0;
        while index < len(records) {
            record: any = records[index];
            if len(record) > 3 {
                status: any = record[:2];
                path: any = os.fsdecode(record[3:]);
                if not prefix or path.startswith(prefix_with_separator) {
                    path = path[len(prefix_with_separator):] if prefix else path;
                    files.append(path);
                    if status == b"??" {
                        untracked.add(path);
                    }
                }
                if b"R" in status or b"C" in status {
                    index += 1;
                }
            }
            index += 1;
        }
        if untracked {
            kept: any = `set(_without_install_files(repo_root, sorted(untracked)));
            files = [path for path in files if path not in untracked or path in kept];
        }
        return _utf8_paths(files);
    } except (OSError, subprocess.TimeoutExpired) as exc {
        if require_vcs {
            raise _vcs_unavailable("git", exc, timeout=timeout) from exc;
        }
        return [];
    }
}

impl _git_is_shallow(repo_root: Path, timeout: float) -> bool {
    try {
        result: any = subprocess.run(
            ["git", "rev-parse", "--is-shallow-repository"],
            capture_output=True,
            cwd=`str(repo_root),
            timeout=timeout,
            stdin=subprocess.DEVNULL,
        );
    } except (OSError, subprocess.TimeoutExpired) as exc {
        raise _vcs_unavailable("git", exc, timeout=timeout) from exc;
    }
    return operator.eq(result.returncode, 0) and operator.eq(result.stdout.strip(), b"true");
}

impl _git_commit_known(repo_root: Path, ref: str, timeout: float) -> bool | None {
    try {
        result: any = subprocess.run(
            ["git", "rev-parse", "--verify", "--quiet", f"{ref}^{{commit}}"],
            capture_output=True,
            cwd=`str(repo_root),
            timeout=timeout,
            stdin=subprocess.DEVNULL,
        );
    } except (OSError, subprocess.TimeoutExpired) as exc {
        raise _vcs_unavailable("git", exc, timeout=timeout) from exc;
    }
    if result.returncode == 0 {
        return True;
    }
    if result.returncode == 1 {
        return False;
    }
    return None;
}

impl _empty_tree(repo_root: Path, timeout: float) -> str {
    try {
        result: any = subprocess.run(
            ["git", "hash-object", "-t", "tree", "--stdin"],
            capture_output=True,
            input=b"",
            cwd=`str(repo_root),
            timeout=timeout,
        );
    } except (OSError, subprocess.TimeoutExpired) as exc {
        raise _vcs_unavailable("git", exc, timeout=timeout) from exc;
    }
    tree: any = result.stdout.decode("ascii", "replace").strip();
    if result.returncode != 0 or not re.fullmatch("[0-9a-f]{40,64}", tree) {
        raise ChangeDiscoveryError(
            f"could not determine the changes: git could not name an empty tree (rc={result.returncode}).",
        );
    }
    return tree;
}

impl _usable_review_base(
    repo_root: Path, base: str, resolved_base: str, timeout: float, notes: list[str] | None
) -> str {
    side: any;
    if detect_vcs(repo_root) != "git" {
        return resolved_base;
    }
    unknown: any = ChangeDiscoveryError(
        f"base {base!r} is not a known revision. Check it with `git branch -a`, or run `git fetch origin <branch>` in a shallow clone.",
    );
    sides: any = [side for side in re.split("\\.{2,3}", resolved_base) if side];
    if not sides or `any(side.startswith("-") for side in sides) {
        raise unknown;
    }
    for side in sides {
        known: any = _git_commit_known(repo_root, side, timeout);
        if known is None {
            return resolved_base;
        }
        if known {
            continue;
        }
        if base != DEFAULT_REVIEW_BASE {
            raise unknown;
        }
        if _git_commit_known(repo_root, "HEAD", timeout) {
            if notes is not None {
                shallow: any = _git_is_shallow(repo_root, timeout);
                notes.append(SHALLOW_CLONE_NOTE if shallow else ONE_COMMIT_NOTE);
            }
            return "HEAD";
        }
        if notes is not None {
            notes.append(NO_COMMIT_NOTE);
        }
        return _empty_tree(repo_root, timeout);
    }
    return resolved_base;
}

impl discover_review_changes(
    repo_root: Path, base: str = base_default_, *, notes: list[str] | None = None
) -> tuple[list[str], str] {
    budget: any = discovery_timeout();
    resolved_base: any = resolve_review_base(repo_root, base, timeout=budget, require_vcs=True);
    resolved_base = _usable_review_base(repo_root, base, resolved_base, budget, notes);
    changed: any = get_changed_files(repo_root, resolved_base, timeout=budget, require_vcs=True);
    if not changed {
        changed = get_staged_and_unstaged(repo_root, timeout=budget, require_vcs=True);
    }
    return (changed, resolved_base);
}

impl graph_holds_commits(
    repo_root: Path, store: GraphStore, built_at: str, *, timeout: float | None = None
) -> bool {
    return files_hold_commits(repo_root, store.get_file_hashes, built_at, timeout=timeout);
}

impl files_hold_commits(
    repo_root: Path,
    file_hashes: Callable[[], dict[str, str]],
    built_at: str,
    *,
    timeout: float | None = None,
) -> bool {
    if timeout is None {
        timeout = discovery_timeout();
    }
    if not built_at or built_at.startswith("-") or not _SAFE_GIT_REF.fullmatch(built_at) {
        return False;
    }
    repo_root = _canonical_repo_root(repo_root);
    try {
        result: any = subprocess.run(
            ["git", "diff", "--relative", "--name-status", "-z", built_at, "HEAD", "--", "."],
            capture_output=True,
            cwd=`str(repo_root),
            timeout=timeout,
            stdin=subprocess.DEVNULL,
        );
    } except (OSError, subprocess.TimeoutExpired) {
        logger.debug("git diff failed while checking graph freshness", exc_info=True);
        return False;
    }
    if result.returncode != 0 {
        return False;
    }
    changed: any = _decode_name_status_paths(result.stdout);
    if len(changed) > _FRESHNESS_FILE_LIMIT {
        return False;
    }

    stored_hashes: any = file_hashes();
    parser: CodeParser | None = None;
    ignore_patterns: list[str] | None = None;
    for rel_path in changed {
        full_path: any = repo_root / rel_path;
        stored_hash: any = stored_hashes.get(normalize_file_path(full_path));
        if stored_hash is not None {
            try {
                current: any = hashlib.sha256(full_path.read_bytes()).hexdigest();
            } except OSError {
                return False;
            }
            if current != stored_hash {
                return False;
            }
            continue;
        }
        if not full_path.exists() {
            continue;
        }
        if parser is None {
            parser = _get_code_parser_cls()(repo_root);
            ignore_patterns = _load_ignore_patterns(repo_root);
        }
        if _keep_candidate(repo_root, rel_path, ignore_patterns or [], parser) {
            return False;
        }
    }
    return True;
}

impl get_all_tracked_files(repo_root: Path, recurse_submodules: bool | None = None) -> list[str] {
    if detect_vcs(repo_root) == "svn" {
        return _get_svn_all_tracked_files(repo_root);
    }

    if recurse_submodules is None {
        recurse_submodules = _RECURSE_SUBMODULES;
    }
    cmd: any = ["git", "ls-files", "-z"];
    if recurse_submodules {
        cmd.append("--recurse-submodules");
    }

    try {
        result: any = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            encoding="utf-8",
            errors="replace",
            cwd=`str(repo_root),
            timeout=_GIT_TIMEOUT,
            stdin=subprocess.DEVNULL,
        );
        return [f for f in result.stdout.split("\x00") if f];
    } except (FileNotFoundError, subprocess.TimeoutExpired, UnicodeDecodeError) {
        return [];
    }
}

impl install_manifest_paths(repo_root: Path) -> frozenset[str] {
    path: any = Path(repo_root) / INSTALL_MANIFEST;
    try {
        raw: any = path.read_bytes();
    } except FileNotFoundError {
        return frozenset();
    } except OSError as exc {
        logger.warning("Could not read %s: %s", path, exc);
        return frozenset();
    }
    try {
        data: any = json.loads(raw);
    } except ValueError as exc {
        logger.warning("Ignoring %s: not valid JSON (%s)", path, exc);
        return frozenset();
    }
    files: any = data.get("files") if isinstance(data, `dict) else None;
    if not isinstance(files, `list) or data.get("version") != 1 {
        logger.warning("Ignoring %s: not a version 1 install manifest", path);
        return frozenset();
    }
    return frozenset(
        `str(PurePosixPath(`entry)) for `entry in files if isinstance(`entry, `str) and `entry
    );
}

impl _without_install_files(repo_root: Path, untracked: list[str]) -> list[str] {
    if not untracked {
        return untracked;
    }
    installed: any = install_manifest_paths(repo_root);
    if not installed {
        return untracked;
    }
    return [path for path in untracked if PurePosixPath(path).as_posix() not in installed];
}

impl _get_untracked_files(
    repo_root: Path, *, timeout: float | None = None, require_vcs: bool = False
) -> list[str] {
    if timeout is None {
        timeout = _GIT_TIMEOUT;
    }
    try {
        result: any = subprocess.run(
            ["git", "ls-files", "--others", "--exclude-standard", "-z"],
            capture_output=True,
            cwd=`str(repo_root),
            timeout=timeout,
            stdin=subprocess.DEVNULL,
        );
        if result.returncode != 0 {
            logger.warning("git ls-files failed while discovering untracked files");
            if require_vcs {
                raise ChangeDiscoveryError(
                    f"git ls-files failed while discovering untracked files (rc={result.returncode})",
                );
            }
            return [];
        }
        return _without_install_files(
            repo_root,
            _utf8_paths(os.fsdecode(path) for path in result.stdout.split(b"\x00") if path),
        );
    } except (OSError, subprocess.TimeoutExpired) as exc {
        if require_vcs {
            raise _vcs_unavailable("git", exc, timeout=timeout) from exc;
        }
        return [];
    }
}

impl _get_svn_all_tracked_files(repo_root: Path) -> list[str] {
    try {
        result: any = subprocess.run(
            ["svn", "list", "--recursive", "--non-interactive"],
            capture_output=True,
            text=True,
            encoding="utf-8",
            errors="replace",
            cwd=`str(repo_root),
            timeout=60,
            stdin=subprocess.DEVNULL,
        );
        if result.returncode == 0 {
            files: any = [
                f.strip()
                for f in result.stdout.splitlines()
                if f.strip() and not f.strip().endswith("/")
            ];
            if files {
                return files;
            }
        }
    } except (FileNotFoundError, subprocess.TimeoutExpired) {}
    return [];
}

impl follow_symlinks_enabled(explicit: bool | None = None) -> bool {
    if explicit is not None {
        return `bool(explicit);
    }
    return os.environ.get(FOLLOW_SYMLINKS_ENV, "").strip().lower() in {"1", "true", "yes", "on"};
}

impl _inventory_candidates(repo_root: Path, recurse_submodules: bool | None = None) -> list[str] {
    vcs: any = detect_vcs(repo_root);
    tracked: any = get_all_tracked_files(repo_root, recurse_submodules);
    if vcs == "git" {
        candidates: any = `list(dict.fromkeys([*tracked, *_get_untracked_files(repo_root)]));
    } else {
        candidates = tracked;
    }
    if not candidates {
        installed: any = install_manifest_paths(repo_root);
        candidates = [
            `str(p.relative_to(repo_root))
            for p in repo_root.rglob("*")
            if (p.is_file() or p.is_symlink())
                and p.relative_to(repo_root).as_posix() not in installed
        ];
    }
    return candidates;
}

impl _keep_candidate(
    repo_root: Path, rel_path: str, ignore_patterns: list[str], parser: CodeParser
) -> bool {
    if _should_ignore(rel_path, ignore_patterns) {
        return False;
    }
    try {
        rel_path.encode("utf-8");
        full_path: any = repo_root / rel_path;
    } except (OSError, UnicodeEncodeError, ValueError) {
        logger.debug("Skipping path that cannot be represented safely");
        return False;
    }
    if len(`str(full_path)) > 1000
        or `any(operator.gt(len(p.encode()), 255) for p in full_path.parts)
    {
        logger.debug("Skipping overlong path: %s", rel_path[:120]);
        return False;
    }
    if not full_path.is_file() {
        return False;
    }
    if full_path.is_symlink() {
        return False;
    }
    if parser.detect_language(full_path) is None {
        return False;
    }
    if _is_binary(full_path) {
        return False;
    }
    return True;
}

impl _report_once(`root: Path, key: str, level: int, message: str, *args_: object) -> None {
    args: any = tuple(args_);
    marker: any = (`str(`root), key);
    if marker in _reported_links {
        level = logging.DEBUG;
    }
    _reported_links.add(marker);
    logger.log(level, message, *args);
}

impl _max_followed_files -> int {
    return max(1, env_int("CRG_MAX_FOLLOWED_FILES", 10000));
}

impl _is_junction(`entry: os.DirEntry) -> bool {
    comptime if target_().os != "windows" {
        return False;
    }
    is_junction: any = getattr(`entry, "is_junction", None);
    if is_junction is not None {
        return `bool(is_junction());
    }
    return operator.ne(
        os.path.normcase(os.path.realpath(`entry.path)),
        os.path.normcase(os.path.abspath(`entry.path)),
    );
}

impl _walk_symlinked_dirs(
    repo_root: Path, candidates: Iterable[str], ignore_patterns: list[str]
) -> _FollowedTree {
    listed_names: any;
    limit: any;
    files: list[str];
    listed: set[tuple[int, int]];
    taken: any;
    pending: any;
    `root: any = Path(repo_root).resolve();
    listed_names = {normalize_file_path(candidate) for candidate in candidates};
    limit = _max_followed_files();
    files = [];
    links: list[str] = [];
    outside: dict[str, str] = {};
    inside_dirs: list[str] = [];
    seen_links: set[str] = set[any]();
    listed = set[any]();
    taken = 0;
    pending = deque(
        (path, path)
        for path in sorted(
            normalize_file_path(candidate)
            for candidate in listed_names
            if os.path.islink(repo_root / candidate),
        ),
    );

    def _ignored(logical: str, via: str) -> bool {
        return _should_ignore(logical, ignore_patterns)
            or operator.ne(via, logical) and _should_ignore(via, ignore_patterns);
    }

    """List one followed folder; return False once the cap is reached."""
    def _list(directory: Path, logical: str, via: str) -> bool {
        stack: any = [(directory, logical, via)];
        while stack {
            current: any;
            current_logical: any;
            current_via: any;
            (current, current_logical, current_via) = stack.pop() as any;
            try {
                info: any = current.stat();
                if (info.st_dev, info.st_ino) in listed {
                    continue;
                }
                listed.add((info.st_dev, info.st_ino));
                scan: any;
                with os.scandir(current) as scan {
                    entries: any = sorted(scan, key=lambda (`entry) -> any { `entry.name });
                }
            } except OSError as exc {
                logger.debug("Cannot list %s: %s", current, exc);
                continue;
            }
            folders: list[tuple[Path, str, str]] = [];
            for `entry in entries {
                entry_logical: any = f"{current_logical}/{`entry.name}";
                entry_via: any = f"{current_via}/{`entry.name}";
                try {
                    if `entry.is_symlink() or _is_junction(`entry) {
                        pending.append((entry_logical, entry_via));
                    } elif `entry.is_dir(follow_symlinks=False) {
                        if not _ignored(entry_logical, entry_via) {
                            folders.append((Path(`entry.path), entry_logical, entry_via));
                        }
                    } elif `entry.is_file(follow_symlinks=False) {
                        if _ignored(entry_logical, entry_via) {
                            continue;
                        }
                        files.append(entry_logical);
                        if entry_logical not in listed_names {
                            taken += 1;
                            if taken >= limit {
                                return False;
                            }
                        }
                    }
                } except OSError {
                    continue;
                }
            }
            stack.extend(reversed(folders));
        }
        return True;
    }

    capped: any = False;
    while pending and not capped {
        link_rel: any;
        link_via: any;
        (link_rel, link_via) = pending.popleft() as any;
        if link_rel in seen_links {
            continue;
        }
        seen_links.add(link_rel);
        if _ignored(link_rel, link_via) {
            continue;
        }
        link: any = `root / link_rel;
        target: any = Path(os.path.realpath(link));
        try {
            if not target.is_dir() {
                continue;
            }
            info: any = target.stat();
        } except OSError {
            continue;
        }
        holder: any = Path(os.path.realpath(link.parent));
        if target == holder or target in holder.parents {
            _report_once(
                `root,
                link_rel,
                logging.INFO,
                "Not following %s: it points at a folder that holds it",
                link_rel,
            );
            continue;
        }
        if target == `root or target in `root.parents {
            _report_once(
                `root,
                link_rel,
                logging.INFO,
                "Not following %s: it points at a folder that holds the repository",
                link_rel,
            );
            continue;
        }
        try {
            logical: any = target.relative_to(`root).as_posix();
            inside: any = True;
        } except ValueError {
            logical = link_rel;
            inside = False;
        }
        if inside and _should_ignore(logical, ignore_patterns) {
            continue;
        }
        links.append(link_rel);
        if (info.st_dev, info.st_ino) in listed {
            continue;
        }
        if inside {
            inside_dirs.append(logical);
        } else {
            outside[normalize_file_path(target)] = link_rel;
        }
        if not _list(target, logical, link_via) {
            capped = True;
        }
    }
    if capped {
        _report_once(
            `root,
            "\x00cap",
            logging.WARNING,
            "Stopped following symlinked folders after %d files (CRG_MAX_FOLLOWED_FILES); files past that point are left out of the graph",
            limit,
        );
    }
    return _FollowedTree(files, links, outside, inside_dirs);
}

impl _path_key(rel_path: str) -> str {
    return unicodedata.normalize("NFC", rel_path).casefold();
}

impl _followed_extra_files(
    repo_root: Path, candidates: list[str], ignore_patterns: list[str], parser: CodeParser
) -> tuple[list[str], _FollowedTree] {
    candidate: any;
    full_path: any;
    listed: any = {normalize_file_path(candidate) for candidate in candidates};
    by_key: dict[str, list[str]] = {};
    for candidate in listed {
        by_key.setdefault(_path_key(candidate), []).append(candidate);
    }
    tree: any = _walk_symlinked_dirs(repo_root, candidates, ignore_patterns);
    extra: list[str] = [];
    taken: set[tuple[int, int]] = set[any]();
    for rel_path in sorted(`set(tree.files)) {
        if rel_path in listed {
            continue;
        }
        full_path = repo_root / rel_path;
        try {
            if `any(
                os.path.samefile(full_path, repo_root / other)
                for other in by_key.get(_path_key(rel_path), []),
            ) {
                continue;
            }
            info: any = full_path.stat();
        } except OSError {
            continue;
        }
        if (info.st_dev, info.st_ino) in taken {
            continue;
        }
        if not _keep_candidate(repo_root, rel_path, ignore_patterns, parser) {
            continue;
        }
        taken.add((info.st_dev, info.st_ino));
        extra.append(rel_path);
    }
    return (extra, tree);
}

impl _followed_tree(repo_root: Path, ignore_patterns: list[str]) -> _FollowedTree {
    return _walk_symlinked_dirs(repo_root, _inventory_candidates(repo_root), ignore_patterns);
}

impl _outermost(paths: Iterable[str]) -> set[str] {
    path: any;
    kept: list[str] = [];
    for path_ in sorted(`set(paths), key=builtins.len) {
        path = path_;
        if not `any(
            operator.eq(path, other) or path.startswith(other.rstrip("/") + "/") for other in kept
        ) {
            kept.append(path);
        }
    }
    return `set(kept);
}

impl _collect_files(
    repo_root: Path, recurse_submodules: bool | None = None, follow_symlinks: bool | None = None
) -> tuple[list[str], list[str], dict[str, str]] {
    ignore_patterns: any = _load_ignore_patterns(repo_root);
    parser: any = _get_code_parser_cls()(repo_root);
    candidates: any = _inventory_candidates(repo_root, recurse_submodules);
    files: any = [
        rel_path
        for rel_path in candidates
        if _keep_candidate(repo_root, rel_path, ignore_patterns, parser)
    ];
    if not follow_symlinks_enabled(follow_symlinks) {
        return (files, [], {});
    }
    followed: any;
    tree: any;
    (followed, tree) = _followed_extra_files(repo_root, candidates, ignore_patterns, parser) as any;
    return (files + followed, followed, tree.outside);
}

impl collect_all_files(
    repo_root: Path, recurse_submodules: bool | None = None, follow_symlinks: bool | None = None
) -> list[str] {
    return _collect_files(repo_root, recurse_submodules, follow_symlinks)[0];
}

impl _load_followed_files(store: GraphStore) -> set[str] {
    raw: any = store.get_metadata(_FOLLOWED_FILES_KEY);
    if not raw or not isinstance(raw, `str) {
        return set[any]();
    }
    try {
        value: any = json.loads(raw);
    } except ValueError {
        logger.warning("Ignoring unreadable %s metadata", _FOLLOWED_FILES_KEY);
        return set[any]();
    }
    if not isinstance(value, `list) {
        return set[any]();
    }
    return {path for path in value if isinstance(path, `str)};
}

impl followed_files(store: GraphStore) -> set[str] {
    return _load_followed_files(store);
}

impl _load_followed_dirs(store: GraphStore) -> dict[str, str] {
    raw: any = store.get_metadata(_FOLLOWED_DIRS_KEY);
    if not raw or not isinstance(raw, `str) {
        return {};
    }
    try {
        value: any = json.loads(raw);
    } except ValueError {
        logger.warning("Ignoring unreadable %s metadata", _FOLLOWED_DIRS_KEY);
        return {};
    }
    if not isinstance(value, `dict) {
        return {};
    }
    return {
        real: logical
        for (real, logical) in value.items()
        if isinstance(real, `str) and isinstance(logical, `str)
    };
}

impl _store_followed(store: GraphStore, paths: set[str], dirs: dict[str, str]) -> None {
    if store.get_metadata(_FOLLOWED_FILES_KEY) is not None or paths {
        if _load_followed_files(store) != paths or store.get_metadata(_FOLLOWED_FILES_KEY) is None {
            store.set_metadata(_FOLLOWED_FILES_KEY, json.dumps(sorted(paths)));
        }
    }
    if store.get_metadata(_FOLLOWED_DIRS_KEY) is not None or dirs {
        if _load_followed_dirs(store) != dirs or store.get_metadata(_FOLLOWED_DIRS_KEY) is None {
            store.set_metadata(_FOLLOWED_DIRS_KEY, json.dumps(dirs, sort_keys=True));
        }
    }
}

impl _relink_prefixes(repo_root: Path, dirs: dict[str, str]) -> list[tuple[str, str]] {
    return sorted(
        ((real.rstrip("/") + "/", normalize_file_path(Path(repo_root) / logical) + "/")
        for (real, logical) in dirs.items()),
        key=lambda (pair) -> any { len(pair[0]) },
        reverse=True,
    );
}

impl _relinked(value: str, prefixes: list[tuple[str, str]]) -> str {
    for (real, logical) in prefixes {
        if value.startswith(real) {
            return logical + value[len(real):];
        }
        if value == real[:-1] {
            return logical[:-1];
        }
    }
    return value;
}

impl _relink_edges(edges: list, repo_root: Path, dirs: dict[str, str]) -> None {
    if not dirs {
        return;
    }
    prefixes: any = _relink_prefixes(repo_root, dirs);
    for `edge in edges {
        `edge.source = _relinked(`edge.source, prefixes);
        `edge.target = _relinked(`edge.target, prefixes);
    }
}

impl _relink_stored_edges(store: GraphStore, repo_root: Path, dirs: dict[str, str]) -> None {
    for (real, logical) in _relink_prefixes(repo_root, dirs) {
        store.relocate_edge_targets(real, logical);
    }
}

impl path_within_repo(
    repo_root: Path | str, path: Path | str, followed: Iterable[str] = ()
) -> bool {
    `root: any = Path(repo_root).resolve();
    candidate: any = Path(path);
    if not candidate.is_absolute() {
        candidate = `root / candidate;
    }
    try {
        candidate.resolve().relative_to(`root);
        return True;
    } except (OSError, RuntimeError, ValueError) {}
    lexical: any = Path(os.path.normpath(candidate));
    try {
        lexical.relative_to(`root);
    } except ValueError {
        return False;
    }
    return normalize_file_path(lexical) in `set(followed);
}

impl _outside_or_below_symlink(repo_root: Path, rel_path: str) -> bool {
    candidate: any = Path(os.path.normpath(repo_root / rel_path));
    try {
        relative: any = candidate.relative_to(repo_root);
    } except ValueError {
        return True;
    }
    current: any = repo_root;
    for part in relative.parts[:-1] {
        current = current / part;
        if os.path.islink(current) {
            return True;
        }
    }
    return False;
}

impl _followed_files_delta(
    repo_root: Path, store: GraphStore, follow: bool, ignore_patterns: list[str], parser: CodeParser
) -> tuple[list[str], list[str], set[str] | None, dict[str, str]] {
    recorded: any;
    listed: any;
    inside: list[str];
    record: any;
    recorded = _load_followed_files(store);
    if not follow and not recorded {
        return ([], [], None, {});
    }
    candidates: any = _inventory_candidates(repo_root);
    if not candidates {
        return ([], [], None, _load_followed_dirs(store));
    }
    listed = {normalize_file_path(repo_root / candidate) for candidate in candidates};
    followed: list[str] = [];
    outside: dict[str, str] = {};
    inside = [];
    if follow {
        tree: any;
        (followed, tree) = _followed_extra_files(
            repo_root, candidates, ignore_patterns, parser
        ) as any;
        outside = tree.outside;
        inside = [normalize_file_path(repo_root / folder) + "/" for folder in tree.inside];
    }
    record = {normalize_file_path(repo_root / rel_path) for rel_path in followed};
    stored: any = `set(store.get_all_files());
    new: any = [
        rel_path
        for rel_path in followed
        if normalize_file_path(repo_root / rel_path) not in stored
    ];
    gone: any = sorted(
        path
        for path in stored
        if path not in record
            and path not in listed
            and (path in recorded or `any(path.startswith(folder) for folder in inside)),
    );
    return (new, gone, record, outside);
}

impl _reconcile_stale_files(
    repo_root: Path,
    store: GraphStore,
    current_files: list[str] | None = None,
    *,
    known_text: set[str] | None = None,
    remove: bool = True,
) -> list[str] {
    stored_files: any = `set(store.get_all_files());
    if current_files is not None {
        current_paths: set[str] = {
            normalize_file_path(repo_root / file_path)
            for file_path in current_files
        };
    } else {
        ignore_patterns: any = _load_ignore_patterns(repo_root);
        parser: any = _get_code_parser_cls()(repo_root);
        current_paths = set[any]();
        followed: any = _load_followed_files(store);
        linked_parents: dict[str, bool] = {};
        for stored_file in stored_files {
            path: any = Path(stored_file);
            try {
                relative: any = `str(path.relative_to(repo_root));
            } except ValueError {
                continue;
            }
            parent: any = os.path.dirname(relative);
            if parent not in linked_parents {
                linked_parents[parent] = _outside_or_below_symlink(repo_root, relative);
            }
            if linked_parents[parent] and stored_file not in followed {
                continue;
            }
            if path.is_file()
                and not path.is_symlink()
                and not _should_ignore(relative, ignore_patterns)
                and parser.detect_language(path) is not None
                and (known_text is not None and stored_file in known_text or not _is_binary(path))
            {
                current_paths.add(stored_file);
            }
        }
    }
    stale_files: any = sorted(stored_files - current_paths);
    if stale_files and remove {
        restore_csharp_references(store, stale_files);
        store.remove_files_permanently(stale_files, stored_paths=True);
    }
    return stale_files;
}

impl _assert_graph_matches_root(repo_root: Path, store: GraphStore) -> None {
    file_paths: any = store.get_file_marker_paths();
    if not file_paths {
        return;
    }
    prefix: any = normalize_file_path(repo_root);
    prefix = prefix if prefix.endswith("/") else prefix + "/";
    foreign_paths: any = [
        normalize_file_path(path)
        for path in file_paths
        if not normalize_file_path(path).startswith(prefix)
    ];
    if not foreign_paths {
        return;
    }
    sample: any = sorted(foreign_paths)[0];
    raise RuntimeError(
        f"the graph holds {len(foreign_paths)} file(s) such as {sample!r} outside {`str(repo_root)!r}; it was built with a different repository root. Rebuild it, or retry with the root it was built with, instead of reconciling every file away.",
    );
}

impl assert_graph_serves_root(repo_root: Path, store: GraphStore) -> None {
    prefix: any;
    markers: any = [`str(path) for path in store.get_file_marker_paths()];
    absolute: any = [path for path in markers if Path(path).is_absolute()];
    if not absolute {
        return;
    }

    prefix = normalize_file_path(_canonical_repo_root(repo_root));
    prefix = prefix if prefix.endswith("/") else prefix + "/";
    if `any(normalize_file_path(path).startswith(prefix) for path in absolute) {
        return;
    }

    probe: any = absolute[:_ROOT_PROBE_LIMIT];
    if `any(normalize_file_path(os.path.realpath(path)).startswith(prefix) for path in probe) {
        return;
    }

    elsewhere: any = next((path for path in probe if Path(path).exists()), None);
    if elsewhere is None {
        logger.debug(
            "Graph at %s holds no file under %s and none on this machine; treating it as stale rather than as another repository's graph.",
            store.db_path,
            repo_root,
        );
        return;
    }

    raise GraphRootMismatchError(
        f"the graph at {store.db_path} was built for a different repository root: none of its {len(absolute)} file(s), such as {normalize_file_path(elsewhere)}, are under {repo_root}. Run `code-review-graph build` here, or point --repo at the root it was built for.",
    );
}

impl _single_hop_dependents(store: GraphStore, file_path: str) -> set[str] {
    return store.get_direct_dependent_files(file_path);
}

impl _prewarm_parser_probes(parser: Any, rel_paths: list[str]) -> None {
    try {
        import importlib;

        parser_mod: any = importlib.import_module("code_review_graph.parser");
    } except Exception {
        return;
    }
    probe_fn: any = getattr(parser_mod, "_parser_load_probe_succeeds", None);
    if getattr(probe_fn, "__qualname__", "") != "_parser_load_probe_succeeds" {
        return;
    }
    ext_map: any = getattr(parser, "_extension_map", None);
    if not isinstance(ext_map, `dict) {
        return;
    }
    grammars: set[str] = set[any]();
    for rel_path in rel_paths {
        suffix: any = Path(rel_path).suffix.lower();
        lang: any = ext_map.get(suffix);
        if not lang {
            continue;
        }
        if lang == "notebook" {
            grammars.add("python");
        } elif lang in ("vue", "svelte") {
            grammars.update(("javascript", "typescript", "html"));
        } elif lang == "blade" {
            grammars.update(("php", "html"));
        } elif lang == "c" and suffix == ".h" {
            grammars.update(("c", "cpp"));
        } elif lang in _NO_GRAMMAR_LANGUAGES {
            continue;
        } else {
            grammars.add(lang);
        }
    }
    custom: any = getattr(parser, "_custom_languages", None) or {};
    grammars = {getattr(custom.get(g), "grammar", None) or g for g in grammars};
    unprobed: any = [g for g in grammars if g not in parser_mod._PARSER_PROBE_RESULTS];
    if not unprobed {
        return;
    }
    if len(unprobed) == 1 {
        probe_fn(unprobed[0]);
        return;
    }
    pool: any;
    with concurrent.futures.ThreadPoolExecutor(
        max_workers=min(len(unprobed), _MAX_PARSE_WORKERS)
    ) as pool {
        `list(pool.map(probe_fn, unprobed));
    }
}

impl DependentList.init(items: list, *, truncated: bool = False) {
    super.__init__(items);
    self.truncated = truncated;
}

impl find_dependents(
    store: GraphStore, file_path: str, max_hops: int = max_hops_default_
) -> DependentList {
    all_dependents: set[str] = set[any]();
    visited: set[str] = {file_path};
    frontier: set[str] = {file_path};
    for _hop in range(max_hops) {
        next_frontier: set[str] = set[any]();
        for fp in frontier {
            deps: any = _single_hop_dependents(store, fp);
            new_deps: any = deps - visited;
            all_dependents.update(new_deps);
            next_frontier.update(new_deps);
        }
        visited.update(next_frontier);
        frontier = next_frontier;
        if not frontier {
            break;
        }
        if len(all_dependents) > _MAX_DEPENDENT_FILES {
            logger.warning(
                "Dependent expansion capped at %d files for %s", len(all_dependents), file_path
            );
            return DependentList(`list(all_dependents)[:_MAX_DEPENDENT_FILES], truncated=True);
        }
    }
    return DependentList(`list(all_dependents));
}

impl _parse_single_file(args: tuple[str, str]) -> tuple[str, list, list, str | None, str] {
    rel_path: any;
    repo_root_str: any;
    (rel_path, repo_root_str) = args as any;
    abs_path: any = Path(repo_root_str) / rel_path;
    try {
        raw: any = abs_path.read_bytes();
        fhash: any = hashlib.sha256(raw).hexdigest();
        parser: any = getattr(_PARSE_WORKER_STATE, "parser", None);
        parser_repo_root: any = getattr(_PARSE_WORKER_STATE, "repo_root", None);
        if parser is None or parser_repo_root != repo_root_str {
            parser = _get_code_parser_cls()(Path(repo_root_str));
            _PARSE_WORKER_STATE.parser = parser;
            _PARSE_WORKER_STATE.repo_root = repo_root_str;
        }
        nodes: any;
        edges: any;
        (nodes, edges) = parser.parse_bytes(abs_path, raw) as any;
        return (rel_path, nodes, edges, None, fhash);
    } except Exception as e {
        return (rel_path, [], [], `str(e), "");
    }
}

impl _canonical_repo_root(repo_root: Path) -> Path {
    return Path(repo_root).expanduser().resolve();
}

impl full_build(
    repo_root: Path,
    store: GraphStore,
    recurse_submodules: bool | None = None,
    enrich: bool | None = None,
    follow_symlinks: bool | None = None,
) -> dict {
    rel_path: any;
    repo_root = _canonical_repo_root(repo_root);
    parser: any = _get_code_parser_cls()(repo_root);
    files: any;
    followed: any;
    followed_dirs: any;
    (files, followed, followed_dirs) = _collect_files(
        repo_root, recurse_submodules, follow_symlinks
    ) as any;
    stale_files: any = _reconcile_stale_files(repo_root, store, files);
    _store_followed(
        store, {normalize_file_path(repo_root / rel_path) for rel_path in followed}, followed_dirs
    );

    total_nodes: any = 0;
    total_edges: any = 0;
    errors: any = [];
    cpp_errors: set[str] = set[any]();
    file_count: any = len(files);

    use_serial: any = operator.eq(os.environ.get("CRG_SERIAL_PARSE", ""), "1");

    if use_serial or file_count < 8 {
        i: any;
        for (i, rel_path) in enumerate(files, 1) {
            full_path: any = repo_root / rel_path;
            parsed: tuple[list, list, str] | None = None;
            try {
                source: any = full_path.read_bytes();
                fhash: any = hashlib.sha256(source).hexdigest();
                nodes: any;
                edges: any;
                (nodes, edges) = parser.parse_bytes(full_path, source) as any;
                _relink_edges(edges, repo_root, followed_dirs);
                parsed = (nodes, edges, fhash);
            } except (OSError, PermissionError) as e {
                errors.append({"file": rel_path, "error": `str(e)});
                if parser.detect_language(full_path) == "cpp" {
                    cpp_errors.add(`str(rel_path));
                }
            } except Exception as e {
                logger.warning("Error parsing %s: %s", rel_path, e);
                errors.append({"file": rel_path, "error": `str(e)});
                if parser.detect_language(full_path) == "cpp" {
                    cpp_errors.add(`str(rel_path));
                }
            }
            if parsed is not None {
                store.store_file_nodes_edges(`str(full_path), *parsed);
                total_nodes += len(parsed[0]);
                total_edges += len(parsed[1]);
            }
            if i % 50 == 0 or i == file_count {
                logger.info("Progress: %d/%d files parsed", i, file_count);
            }
        }
    } else {
        _prewarm_parser_probes(parser, files);
        args_list: any = [(rel_path, `str(repo_root)) for rel_path in files];
        executor: any;
        with _make_executor(_MAX_PARSE_WORKERS) as executor {
            for (i, (rel_path, nodes, edges, error, fhash)) in enumerate(
                executor.map(_parse_single_file, args_list, chunksize=20), 1
            ) {
                if error {
                    logger.warning("Error parsing %s: %s", rel_path, error);
                    errors.append({"file": rel_path, "error": error});
                    if parser.detect_language(repo_root / rel_path) == "cpp" {
                        cpp_errors.add(`str(rel_path));
                    }
                    continue;
                }
                full_path = repo_root / rel_path;
                _relink_edges(edges, repo_root, followed_dirs);
                store.store_file_nodes_edges(`str(full_path), nodes, edges, fhash);
                total_nodes += len(nodes);
                total_edges += len(edges);
                if i % 200 == 0 or i == file_count {
                    logger.info("Progress: %d/%d files parsed", i, file_count);
                }
            }
        }
    }

    store.set_metadata("last_updated", time.strftime("%Y-%m-%dT%H:%M:%S"));
    store.set_metadata("last_build_type", "full");
    store.set_metadata("intentionally_incomplete", "0");
    store.set_metadata(
        VERIFIED_FILE_COUNT_KEY, "0" if errors else `str(len(store.get_all_files()))
    );
    _store_cpp_identity_pending(store, cpp_errors);
    store.set_metadata(_NESTED_SCOPE_METADATA_KEY, NESTED_SCOPE_IDENTITY_VERSION);
    store.set_metadata(_NESTED_SCOPE_PENDING_KEY, "[]");
    store.set_metadata(_CSHARP_IDENTITY_METADATA_KEY, CSHARP_IDENTITY_VERSION);
    store.set_metadata(
        _CSHARP_PENDING_METADATA_KEY,
        json.dumps(sorted(error["file"] for error in errors if error["file"].endswith(".cs"))),
    );
    python_stats: any = _run_python_resolver(store);
    rescript_stats: any = _run_rescript_resolver(store);
    spring_stats: any = _run_spring_resolver(store);
    aop_stats: any = _run_aop_resolver(store);
    spring_event_stats: any = _run_spring_event_resolver(store);
    temporal_stats: any = _run_temporal_resolver(store);
    hcl_stats: any = _run_hcl_resolver(store);
    scoped_stats: any = _run_scoped_resolver(store, repo_root);
    jedi_stats: any = _run_jedi_enrichment(store, repo_root, enrich=enrich);
    _relink_stored_edges(store, repo_root, followed_dirs);
    _refresh_target_resolution(store);
    store.set_metadata(_DEPENDENTS_PENDING_KEY, "[]");
    advance_to_postprocess_pending(store);
    _store_vcs_metadata(repo_root, store);
    store.commit();

    return {
        "files_parsed": len(files),
        "stale_files_removed": len(stale_files),
        "total_nodes": total_nodes,
        "total_edges": total_edges,
        "errors": errors,
        "python_resolution": python_stats,
        "rescript_resolution": rescript_stats,
        "spring_resolution": spring_stats,
        "aop_resolution": aop_stats,
        "event_resolution": spring_event_stats,
        "temporal_resolution": temporal_stats,
        "hcl_resolution": hcl_stats,
        "scoped_resolution": scoped_stats,
        "jedi_enrichment": jedi_stats,
    };
}

impl _relative_update_input(repo_root: Path, path: str) -> str {
    candidate: any = Path(path);
    if not candidate.is_absolute() {
        return path;
    }
    try {
        return candidate.relative_to(repo_root).as_posix();
    } except ValueError {
        return path;
    }
}

impl incremental_update(
    repo_root: Path,
    store: GraphStore,
    base: str = "HEAD~1",
    changed_files: list[str] | None = None,
    reconcile_stale: bool = True,
    enrich: bool | None = None,
    follow_symlinks: bool | None = None,
    *,
    reconcile_followed: bool = False,
) -> dict {
    followed_dirs: dict[str, str] | None;
    edges_only: dict[str, str];
    cleared_entry_qns: set[str];
    flow_node_ids: dict[int, str];
    reparsed_paths: list[str];
    has_graph_changes: any;
    repo_root = _canonical_repo_root(repo_root);
    follow: any = follow_symlinks_enabled(follow_symlinks);
    if reconcile_stale {
        _assert_graph_matches_root(repo_root, store);
    }
    parser: any = _get_code_parser_cls()(repo_root);
    ignore_patterns: any = _load_ignore_patterns(repo_root);
    vcs: any = detect_vcs(repo_root);
    stored_git_sha: any = store.get_metadata("git_head_sha") if vcs == "git" else None;
    authoritative_git_sync: any = changed_files is None
        and `bool(stored_git_sha)
        and operator.eq(base, stored_git_sha);

    identity_pending: any = _load_cpp_identity_pending(store);
    if identity_pending is None
        and store.get_metadata(_CPP_IDENTITY_METADATA_KEY) != CPP_IDENTITY_VERSION
        and store.has_nodes_for_language("cpp")
    {
        logger.info("C++ identity format changed; rebuilding the graph before incremental update");
        rebuilt: any = full_build(repo_root, store, enrich=enrich, follow_symlinks=follow);
        return {
            "files_updated": rebuilt["files_parsed"],
            "total_nodes": rebuilt["total_nodes"],
            "total_edges": rebuilt["total_edges"],
            "changed_files": `list(changed_files or []),
            "dependent_files": [],
            "errors": rebuilt["errors"],
            "identity_rebuild": True,
            "python_resolution": rebuilt["python_resolution"],
            "rescript_resolution": rebuilt["rescript_resolution"],
            "spring_resolution": rebuilt["spring_resolution"],
            "event_resolution": rebuilt["event_resolution"],
            "temporal_resolution": rebuilt["temporal_resolution"],
            "hcl_resolution": rebuilt["hcl_resolution"],
        };
    }
    if changed_files is None {
        changed_files = get_changed_files(repo_root, base, strict=authoritative_git_sync);
    }
    csharp_upgrade: any = operator.ne(
        store.get_metadata(_CSHARP_IDENTITY_METADATA_KEY), CSHARP_IDENTITY_VERSION
    )
        and store.has_nodes_for_language("csharp");
    pending_csharp: any = `set(
        json.loads(store.get_metadata(_CSHARP_PENDING_METADATA_KEY) or "[]")
    );
    if csharp_upgrade {
        pending_csharp.update(
            `str(Path(row[0]).relative_to(repo_root))
            for row in store._conn.execute(
                "SELECT DISTINCT file_path FROM nodes WHERE language = 'csharp'"
            )
            if Path(row[0]).is_relative_to(repo_root),
        );
    }
    nested_upgrade: any = operator.ne(
        store.get_metadata(_NESTED_SCOPE_METADATA_KEY), NESTED_SCOPE_IDENTITY_VERSION
    );
    pending_nested: any = _load_pending_paths(store, _NESTED_SCOPE_PENDING_KEY);
    if nested_upgrade {
        pending_nested |= _nested_scope_files(store, repo_root);
        if not pending_nested {
            store.set_metadata(_NESTED_SCOPE_METADATA_KEY, NESTED_SCOPE_IDENTITY_VERSION);
            nested_upgrade = False;
        }
    }
    content_mismatches: list[str] = [];
    current_hashes: dict[str, str] = {};
    known_text: set[str] | None = None;
    followed_new: list[str] = [];
    followed_gone: list[str] = [];
    followed_record: set[str] | None = None;
    followed_dirs = None;
    if reconcile_stale or reconcile_followed {
        (followed_new, followed_gone, followed_record, followed_dirs) = _followed_files_delta(
            repo_root, store, follow, ignore_patterns, parser
        ) as any;
        if followed_record is not None {
            _store_followed(store, followed_record, followed_dirs);
        }
    }
    if reconcile_followed and not reconcile_stale {
        _text: any;
        (content_mismatches, current_hashes, _text) = _find_content_mismatches(
            repo_root, store, only=(followed_record or set[any]()) | _load_followed_files(store)
        ) as any;
    }
    if reconcile_stale {
        (content_mismatches, current_hashes, known_text) = _find_content_mismatches(
            repo_root, store
        ) as any;
    }
    if followed_dirs is None {
        followed_dirs = _load_followed_dirs(store) if follow else {};
    }
    if not follow {
        followed_dirs = {};
    }
    followed_allowed: any = followed_record
        if followed_record is not None
        else _load_followed_files(store) if follow else set[any]();
    changed_files = `list(
        dict.fromkeys([
            _relative_update_input(repo_root, p)
            for p in [
                *changed_files,
                *content_mismatches,
                *sorted(pending_csharp),
                *sorted(pending_nested),
                *followed_new,
            ]
        ]),
    );
    if followed_gone {
        gone: any = `set(followed_gone);
        changed_files = [
            p
            for p in changed_files
            if normalize_file_path(repo_root / p) not in gone
        ];
    }
    stale_files: any = _reconcile_stale_files(repo_root, store, known_text=known_text, remove=False)
        if reconcile_stale
        else [];
    if followed_gone {
        stale_files = sorted(`set(stale_files) | `set(followed_gone));
    }
    if not changed_files
        and not stale_files
        and not identity_pending
        and not authoritative_git_sync
    {
        return {
            "files_updated": 0,
            "total_nodes": 0,
            "total_edges": 0,
            "changed_files": [],
            "dependent_files": [],
            "stale_files_removed": 0,
            "flow_entry_point_qns": [],
            "communities_were_affected": False,
            "errors": [],
            "freshness_advanced": False,
        };
    }
    dependents_pending: any = _load_dependents_pending(store);
    dependent_files: set[str] = `set(dependents_pending);
    rel_path: any;
    for rel_path in changed_files {
        full_path: any = normalize_file_path(repo_root / rel_path);
        existing: any = store.get_nodes_by_file(full_path);
        if existing and rel_path not in pending_nested {
            try {
                current_hash: any = current_hashes.get(normalize_file_path(rel_path));
                if current_hash is None {
                    current_hash = hashlib.sha256((repo_root / rel_path).read_bytes()).hexdigest();
                    current_hashes[normalize_file_path(rel_path)] = current_hash;
                }
                if existing[0].file_hash == current_hash {
                    continue;
                }
            } except (OSError, PermissionError) {}
        }
        deps: any = find_dependents(store, full_path);
        for d in deps {
            try {
                dependent_files.add(`str(Path(d).relative_to(repo_root)));
            } except ValueError {
                dependent_files.add(d);
            }
        }
    }
    all_files: any = `set(changed_files) | dependent_files | (identity_pending or set[any]());
    remaining_identity: any = `set(identity_pending or []);

    total_nodes: any = 0;
    total_edges: any = 0;
    errors: any = [];
    missing_paths: set[str] = set[any]();
    to_parse: list[str] = [];
    edges_only = {};
    for rel_path in all_files {
        if _should_ignore(rel_path, ignore_patterns) {
            if rel_path in remaining_identity {
                ignored_path: any = repo_root / rel_path;
                if normalize_file_path(ignored_path) in stale_files
                    or not store.get_nodes_by_file(`str(ignored_path))
                {
                    remaining_identity.discard(rel_path);
                } else {
                    errors.append({
                        "file": rel_path,
                        "error": "Identity migration pending for ignored file",
                    });
                }
            }
            continue;
        }
        abs_path: any = repo_root / rel_path;
        if abs_path.is_symlink()
            or not abs_path.is_file()
            or _outside_or_below_symlink(repo_root, rel_path)
                and normalize_file_path(abs_path) not in followed_allowed
        {
            remaining_identity.discard(rel_path);
            if normalize_file_path(abs_path) not in stale_files {
                missing_paths.add(normalize_file_path(abs_path));
            }
            continue;
        }
        if parser.detect_language(abs_path) is None {
            continue;
        }
        normalized_path: any = normalize_file_path(rel_path);
        fhash: any = current_hashes.get(normalized_path);
        if fhash is None {
            try {
                raw: any = abs_path.read_bytes();
                fhash = hashlib.sha256(raw).hexdigest();
            } except (OSError, PermissionError) {
                fhash = None;
            }
        }
        try {
            existing_nodes: any = store.get_nodes_by_file(`str(abs_path));
            if rel_path not in pending_csharp
                and rel_path not in pending_nested
                and rel_path not in remaining_identity
                and fhash is not None
                and existing_nodes
                and existing_nodes[0].file_hash == fhash
            {
                if rel_path not in dependent_files {
                    continue;
                }
                edges_only[rel_path] = fhash;
            }
        } except (OSError, PermissionError) {}
        to_parse.append(rel_path);
    }
    import from .communities {
        capture_community_assignments,
        purge_empty_communities,
        remap_community_assignments,
    }
    import from .flows {
        capture_affected_flow_entry_points,
        capture_flow_node_ids,
        clear_flows_for_files,
        expand_changed_file_paths,
        purge_orphan_flow_data,
        remap_flow_node_ids,
    }
    lifecycle_inputs: any = [
        *[rel_path.replace("\\", "/") for rel_path in to_parse],
        *missing_paths,
        *stale_files,
    ];
    lifecycle_paths: any = expand_changed_file_paths(store, lifecycle_inputs, repo_root=repo_root);
    community_by_qn: any = capture_community_assignments(store, lifecycle_paths);
    cleared_entry_qns = set[any]();
    flow_node_ids = {};
    reparsed_paths = [];

    def store_parsed(rel_path: str, nodes: list, edges: list, fhash: str) -> None {
        reparsed_paths.append(`str(repo_root / rel_path));
        _relink_edges(edges, repo_root, followed_dirs);
        if edges_only.get(rel_path) == fhash {
            store.store_file_edges(`str(repo_root / rel_path), edges);
            return;
        }
        file_paths: any = expand_changed_file_paths(store, [rel_path], repo_root=repo_root);
        cleared_entry_qns.update(capture_affected_flow_entry_points(store, file_paths));
        flow_node_ids.update(capture_flow_node_ids(store, file_paths));
        store.store_file_nodes_edges(`str(repo_root / rel_path), nodes, edges, fhash);
    }

    use_serial: any = operator.eq(os.environ.get("CRG_SERIAL_PARSE", ""), "1");
    parsed_files: any = 0;

    if use_serial or len(to_parse) < 8 {
        for rel_path in to_parse {
            abs_path = repo_root / rel_path;
            try {
                source: any = abs_path.read_bytes();
                fhash = hashlib.sha256(source).hexdigest();
                nodes: any;
                edges: any;
                (nodes, edges) = parser.parse_bytes(abs_path, source) as any;
            } except (OSError, PermissionError) as e {
                errors.append({"file": rel_path, "error": `str(e)});
                continue;
            } except Exception as e {
                logger.warning("Error parsing %s: %s", rel_path, e);
                errors.append({"file": rel_path, "error": `str(e)});
                continue;
            }
            store_parsed(rel_path, nodes, edges, fhash);
            remaining_identity.discard(rel_path);
            parsed_files += 1;
            total_nodes += len(nodes);
            total_edges += len(edges);
        }
    } else {
        _prewarm_parser_probes(parser, to_parse);
        args_list: any = [(rel_path, `str(repo_root)) for rel_path in to_parse];
        executor: any;
        with _make_executor(_MAX_PARSE_WORKERS) as executor {
            for (rel_path, nodes, edges, error, fhash) in executor.map(
                _parse_single_file, args_list, chunksize=20
            ) {
                if error {
                    logger.warning("Error parsing %s: %s", rel_path, error);
                    errors.append({"file": rel_path, "error": error});
                    continue;
                }
                store_parsed(rel_path, nodes, edges, fhash);
                remaining_identity.discard(rel_path);
                parsed_files += 1;
                total_nodes += len(nodes);
                total_edges += len(edges);
            }
        }
    }

    failed_dependents: any = dependent_files & {error["file"] for error in errors};
    if failed_dependents != dependents_pending {
        store.set_metadata(_DEPENDENTS_PENDING_KEY, json.dumps(sorted(failed_dependents)));
    }

    removed_files: any = 0;
    to_remove: any = sorted(`set(missing_paths) | `set(stale_files));
    if to_remove {
        remove_paths: any = expand_changed_file_paths(store, to_remove, repo_root=repo_root);
        cleared_entry_qns |= clear_flows_for_files(store, remove_paths);
        restore_csharp_references(store, to_remove);
        removed_files = store.remove_files_permanently(to_remove, stored_paths=True);
    }
    remap_community_assignments(store, community_by_qn);
    remap_flow_node_ids(store, flow_node_ids);
    purge_orphan_flow_data(store);
    purge_empty_communities(store);

    flow_entry_point_qns: any = sorted(cleared_entry_qns);
    communities_were_affected: any = `bool(community_by_qn)
        and (operator.gt(parsed_files, 0) or `bool(to_remove))
        or `bool(missing_paths)
        or `bool(stale_files);

    files_updated: any = parsed_files + removed_files;
    if nested_upgrade or pending_nested {
        failed: any = {error["file"] for error in errors};
        store.set_metadata(_NESTED_SCOPE_METADATA_KEY, NESTED_SCOPE_IDENTITY_VERSION);
        store.set_metadata(_NESTED_SCOPE_PENDING_KEY, json.dumps(sorted(pending_nested & failed)));
    }
    if csharp_upgrade or pending_csharp or `any(p.endswith(".cs") for p in all_files) {
        store.set_metadata(_CSHARP_IDENTITY_METADATA_KEY, CSHARP_IDENTITY_VERSION);
        store.set_metadata(
            _CSHARP_PENDING_METADATA_KEY,
            json.dumps(sorted(error["file"] for error in errors if error["file"].endswith(".cs"))),
        );
    }
    if identity_pending is not None and remaining_identity != identity_pending {
        _store_cpp_identity_pending(store, remaining_identity);
        store.commit();
    }

    has_graph_changes = `bool(files_updated or stale_files);
    candidate_paths: any = `set(all_files) | `set(stale_files) | missing_paths;
    python_changed: any = has_graph_changes
        and `any(path.endswith(".py") for path in candidate_paths);
    python_stats: any = _run_python_resolver(store) if python_changed else None;

    rescript_changed: any = has_graph_changes
        and `any(rp.endswith((".res", ".resi")) for rp in all_files);
    rescript_stats: any = _run_rescript_resolver(store) if rescript_changed else None;
    spring_changed: any = has_graph_changes
        and `any(path.endswith(".java") for path in candidate_paths);
    spring_stats: any = _run_spring_resolver(store) if spring_changed else None;
    aop_stats: any = _run_aop_resolver(store) if spring_changed else None;
    spring_event_stats: any = _run_spring_event_resolver(store) if spring_changed else None;
    temporal_stats: any = _run_temporal_resolver(store) if spring_changed else None;
    hcl_changed: any = has_graph_changes and `any(rp.endswith((".tf", ".hcl")) for rp in all_files);
    hcl_stats: any = _run_hcl_resolver(store) if hcl_changed else None;
    scoped_changed: any = `any(
        has_graph_changes and rp.endswith((".php", ".rs", ".cs")) or _is_csharp_project(rp)
        for rp in candidate_paths,
    );
    scoped_stats: any = _run_scoped_resolver(store, repo_root) if scoped_changed else None;
    reparsed_py: any = [p for p in reparsed_paths if p.endswith(".py")];
    jedi_stats: any = _run_jedi_enrichment(store, repo_root, files=reparsed_py, enrich=enrich)
        if reparsed_py
        else None;
    if files_updated and followed_dirs {
        _relink_stored_edges(store, repo_root, followed_dirs);
    }
    if has_graph_changes or scoped_changed {
        _refresh_target_resolution(store);
    }
    freshness_advanced: any = False;
    if files_updated or authoritative_git_sync {
        store.set_metadata("last_updated", time.strftime("%Y-%m-%dT%H:%M:%S"));
        store.set_metadata("last_build_type", "incremental");
        if not remaining_identity {
            store.set_metadata(_CPP_IDENTITY_METADATA_KEY, CPP_IDENTITY_VERSION);
        }
        advance_to_postprocess_pending(store);
        freshness_advanced = _store_vcs_metadata(repo_root, store);
        store.commit();
    }

    if parsed_files >= 20 and hasattr(parser, "clear_caches") {
        parser.clear_caches(include_parsers=True, release_memory=operator.ge(parsed_files, 50));
    }
    _PARSE_WORKER_STATE.__dict__.clear();
    if hasattr(store, "_invalidate_cache") {
        store._invalidate_cache();
    }

    return {
        "files_updated": files_updated,
        "total_nodes": total_nodes,
        "total_edges": total_edges,
        "changed_files": `list(changed_files),
        "dependent_files": `list(dependent_files),
        "stale_files_removed": len(stale_files),
        "flow_entry_point_qns": flow_entry_point_qns,
        "communities_were_affected": communities_were_affected,
        "errors": errors,
        "freshness_advanced": freshness_advanced,
        "python_resolution": python_stats,
        "rescript_resolution": rescript_stats,
        "spring_resolution": spring_stats,
        "aop_resolution": aop_stats,
        "event_resolution": spring_event_stats,
        "temporal_resolution": temporal_stats,
        "hcl_resolution": hcl_stats,
        "scoped_resolution": scoped_stats,
        "jedi_enrichment": jedi_stats,
        **{"identity_rebuild": True} if csharp_upgrade else {},
    };
}

impl _WatchDebouncer.init(interval: float, callback: Callable[[list[Any]], None]) {
    super.__init__(name="crg-watch-debouncer", daemon=True);
    self._interval = interval;
    self._callback = callback;
    self._events = [];
    self._stopping = False;
    self._cond = threading.Condition();
}

impl _WatchDebouncer.handle_event(event: Any) -> None {
    with self._cond {
        self._events.append(event);
        self._cond.notify();
    }
}

impl _WatchDebouncer.requeue(events: list[Any]) -> None {
    with self._cond {
        self._events[:0] = events;
        self._cond.notify();
    }
}

impl _WatchDebouncer.stop -> None {
    with self._cond {
        self._stopping = True;
        self._cond.notify();
    }
}

impl _WatchDebouncer.run -> None {
    with self._cond {
        while True {
            while not self._events and not self._stopping {
                self._cond.wait();
            }
            if self._interval {
                while not self._stopping {
                    if not self._cond.wait(timeout=self._interval) {
                        break;
                    }
                }
            }
            if self._stopping {
                break;
            }
            items_: any = list((self._events, []));
            if len(items_) != 2 {
                raise ValueError(
                    f"too many values to unpack (expected 2, got {len(items_)})"
                        if len(items_) > 2
                        else f"not enough values to unpack (expected 2, got {len(items_)})",
                );
            }
            events: any = items_[0];
            self._events = items_[1];
            self._callback(events);
        }
    }
}

impl _raise_watch_update_errors(result: dict, context: str) -> None {
    errors: any = result.get("errors") or [];
    if not errors {
        return;
    }
    details: any = "; ".join(
        format(error.get("file", "unknown"), "")
            + ": "
            + format(error.get("error", "unknown error"), "")
        for error in errors,
    );
    raise RuntimeError(f"{context} reported errors: {details}");
}

impl _raise_watch_postprocess_warnings(result: object) -> None {
    if not isinstance(result, `dict) {
        return;
    }
    import from .embeddings { REFRESH_SKIPPED_WARNING }

    warnings: any = [
        warning
        for warning in result.get("warnings") or []
        if warning != REFRESH_SKIPPED_WARNING
    ];
    if warnings {
        details: any = "; ".join(`str(warning) for warning in warnings);
        raise RuntimeError(f"post-processing reported warnings: {details}");
    }
}

impl _watch_child_dirs(directory: Path, cache: dict[Path, list[Path]] | None = None) -> list[Path] {
    if cache is not None and directory in cache {
        return cache[directory];
    }
    children: any = [
        directory / name
        for (name, is_dir) in _child_directories(directory)
        if is_dir
    ];
    if cache is not None {
        cache[directory] = children;
    }
    return children;
}

impl _ignored_tree_weight(directory: Path, cap: int) -> int {
    if cap <= 0 {
        return 0;
    }
    total: any = 1;
    queue: any = [directory];
    while queue and total < cap {
        current: any = queue.pop();
        for (name, is_dir) in _child_directories(current) {
            if not is_dir {
                continue;
            }
            total += 1;
            if total >= cap {
                return total;
            }
            queue.append(current / name);
        }
    }
    return total;
}

impl _plan_watch_subtree(
    directory: Path,
    repo_root: Path,
    ignore_patterns: list[str],
    depth: int,
    max_depth: int,
    cache: dict[Path, list[Path]],
    split_threshold: int = split_threshold_default_,
) -> tuple[bool, list[tuple[Path, bool]]] {
    ignored_weight: any = 0;
    kept: list[Path] = [];
    child: any;
    for child in _watch_child_dirs(directory, cache) {
        if _should_ignore(child.relative_to(repo_root).as_posix(), ignore_patterns) {
            if ignored_weight < split_threshold {
                ignored_weight += _ignored_tree_weight(child, split_threshold - ignored_weight);
            }
        } else {
            kept.append(child);
        }
    }
    clean: any = operator.lt(ignored_weight, split_threshold);
    if depth >= max_depth {
        if clean {
            return (True, [(directory, True)]);
        }
        return (False, [(directory, False)] + [(child, True) for child in kept]);
    }
    child_plans: list[tuple[Path, bool]] = [];
    for child in kept {
        child_clean: any;
        child_plan: any;
        (child_clean, child_plan) = _plan_watch_subtree(
            child, repo_root, ignore_patterns, depth + 1, max_depth, cache, split_threshold
        ) as any;
        clean = clean and child_clean;
        child_plans.extend(child_plan);
    }
    if clean {
        return (True, [(directory, True)]);
    }
    return (False, [(directory, False)] + child_plans);
}

impl _plan_watch_paths(
    repo_root: Path,
    ignore_patterns: list[str],
    max_depth: int = max_depth_default__,
    max_schedules: int = max_schedules_default_,
    split_threshold: int = split_threshold_default__,
) -> list[tuple[Path, bool]] {
    plan: any;
    _: any;
    (plan, _) = _plan_watch_paths_with_status(
        repo_root, ignore_patterns, max_depth, max_schedules, split_threshold
    ) as any;
    return plan;
}

impl _plan_watch_paths_with_status(
    repo_root: Path,
    ignore_patterns: list[str],
    max_depth: int = max_depth_default___,
    max_schedules: int = max_schedules_default__,
    split_threshold: int = split_threshold_default___,
) -> tuple[list[tuple[Path, bool]], bool] {
    cache: dict[Path, list[Path]] = {};
    for depth in range(max(1, max_depth), 0, -1) {
        _: any;
        plan: any;
        (_, plan) = _plan_watch_subtree(
            repo_root, repo_root, ignore_patterns, 0, depth, cache, split_threshold
        ) as any;
        if len(plan) <= max(1, max_schedules) {
            return (plan, False);
        }
    }
    logger.warning(
        "%s needs more than %d watches to skip its ignored trees; falling back to one recursive watch (raise CRG_MAX_WATCH_SCHEDULES to split it)",
        repo_root,
        max_schedules,
    );
    return ([(repo_root, True)], True);
}

impl _run_time_boxed(
    operation: Callable[[], Any], description: str, timeout: float = 10.0
) -> None {
    def _call -> None {
        try {
            operation();
        } except Exception as exc {
            logger.debug("%s failed: %s", description, exc);
        }
    }

    thread: any = threading.Thread(target=_call, name="crg-watch-teardown", daemon=True);
    thread.start();
    thread.join(timeout);
    if thread.is_alive() {
        logger.warning(
            "%s did not finish in %.0fs; leaving it to process exit", description, timeout
        );
    }
}

impl _watch_health_path(repo_root: Path) -> Path | None {
    try {
        import from .daemon { watch_health_path }

        return watch_health_path(repo_root);
    } except Exception as exc {
        logger.debug("Watcher health reporting disabled: %s", exc);
        return None;
    }
}

impl _watch_identity(path: str | Path) -> tuple[int, int, float] | None {
    try {
        status: any = os.stat(path);
    } except OSError {
        return None;
    }
    return (status.st_dev, status.st_ino, `float(getattr(status, "st_birthtime", 0.0)));
}

impl _WatchSupervisor.init(
    observer: Any,
    repo_root: Path,
    ignore_patterns: list[str],
    health_path: Path | None = None,
    max_schedules: int = max_schedules_default___,
) {
    self._observer = observer;
    self._repo_root = Path(os.path.abspath(repo_root));
    self._ignore_patterns = ignore_patterns;
    self._health_path = health_path;
    self._max_schedules = max(1, max_schedules);
    self._handler = None;
    self._watches = {};
    self._extra = {};
    self._shallow = set[any]();
    self._live_threads = {};
    self._repaired_roots = set[any]();
    self._replan_requested = False;
    self._replan_retry_at = 0.0;
    self._ignored_boundaries = {};
    self._degraded = False;
    self._promotion_failed = False;
    self._unwatched = {};
    self._refused_to_index = [];
    self._promotion_retry_at = {};
    self._last_health_write = 0.0;
    self._last_health_state = None;
    self._started_at = time.time();
    self._token = f"{os.getpid()}.{uuid.uuid4().hex[:8]}";
}

impl _WatchSupervisor.attach(observer: Any) -> None {
    self._observer = observer;
}

impl _WatchSupervisor.schedule_initial(handler: Any) -> None {
    self._handler = handler;
    plan: any;
    fallback: any;
    (plan, fallback) = _plan_watch_paths_with_status(
        self._repo_root, self._ignore_patterns, max_schedules=self._max_schedules
    ) as any;
    self._degraded = fallback;
    for (path, recursive) in plan {
        self._schedule(path, recursive=recursive);
    }
    self._remember_ignored_boundaries();
    logger.info(
        "Watching %d path(s) under %s; ignored trees are never registered",
        len(self._watches),
        self._repo_root,
    );
}

impl _WatchSupervisor._schedule(path: Path, *, recursive: bool) -> None {
    key: any = `str(path);
    if key in self._watches {
        return;
    }
    try {
        handle: any = self._observer.schedule(self._handler, key, recursive=recursive);
    } except OSError as exc {
        self._note_unwatched(key);
        logger.warning("Could not watch %s: %s — coverage of that directory is lost", key, exc);
        return;
    }
    self._unwatched.pop(key, None);
    self._watches[key] = _WatchEntry(handle, _watch_identity(key));
    if recursive {
        self._shallow.discard(key);
    } else {
        self._shallow.add(key);
    }
}

impl _WatchSupervisor.sync_extra_roots(roots: set[str]) -> None {
    if self._handler is None {
        return;
    }
    key: any;
    for key in sorted(self._extra) {
        `entry: any = self._extra[key];
        if key in roots and `entry.identity == _watch_identity(key) {
            continue;
        }
        del self._extra[key];
        _run_time_boxed(
            partial(self._observer.unschedule, `entry.handle),
            f"unschedule {key}",
            timeout=_WATCH_STOP_TIMEOUT,
        );
    }
    for key in sorted(roots - `set(self._extra)) {
        try {
            handle: any = self._observer.schedule(self._handler, key, recursive=True);
        } except OSError as exc {
            logger.warning(
                "Could not watch followed folder %s: %s — changes in it are picked up by the next update",
                key,
                exc,
            );
            continue;
        }
        self._extra[key] = _WatchEntry(handle, _watch_identity(key));
    }
}

impl _WatchSupervisor.request_replan -> None {
    self._replan_requested = True;
}

impl _WatchSupervisor._remember_ignored_boundaries -> None {
    boundaries: dict[str, bool] = {};
    for parent in self._shallow {
        for child in _watch_child_dirs(Path(parent)) {
            relative: any = Path(child).relative_to(self._repo_root).as_posix();
            if _should_ignore(relative, self._ignore_patterns) {
                boundaries[`str(child)] = operator.ge(
                    _ignored_tree_weight(child, _WATCH_SPLIT_MIN_DIRS), _WATCH_SPLIT_MIN_DIRS
                );
            }
        }
    }
    self._ignored_boundaries = boundaries;
}

impl _WatchSupervisor._replan_if_requested -> None {
    recursive: any;
    if not self._replan_requested {
        return;
    }
    if time.monotonic() < self._replan_retry_at {
        self._promotion_failed = True;
        return;
    }
    self._replan_requested = False;
    plan: any;
    fallback: any;
    (plan, fallback) = _plan_watch_paths_with_status(
        self._repo_root, self._ignore_patterns, max_schedules=self._max_schedules
    ) as any;
    if fallback and self._watches {
        self._remember_ignored_boundaries();
        return;
    }
    desired: any = {`str(path): recursive for (path, recursive) in plan};
    current: any = {path: path not in self._shallow for path in self._watches};
    provisional: list[tuple[str, Any, bool]] = [];
    try {
        planned_path: any;
        for (planned_path, recursive) in plan {
            key: any = `str(planned_path);
            if key in current and desired[key] == current[key] {
                continue;
            }
            if key in current and desired[key] != current[key] {
                continue;
            }
            handle: any = self._observer.schedule(self._handler, key, recursive=recursive);
            provisional.append((key, handle, recursive));
        }
        for (planned_path, recursive) in plan {
            key = `str(planned_path);
            if key not in current or desired[key] == current[key] {
                continue;
            }
            handle = self._observer.schedule(self._handler, key, recursive=recursive);
            provisional.append((key, handle, recursive));
        }
    } except OSError as exc {
        logger.warning(
            "Could not apply watch replan; keeping existing watches and retrying in %.0fs: %s",
            _PROMOTION_RETRY_SECONDS,
            exc,
        );
        for (key, handle, _) in provisional {
            _run_time_boxed(
                partial(self._observer.unschedule, handle),
                f"rollback watch registration {key}",
                timeout=_WATCH_STOP_TIMEOUT,
            );
        }
        self._replan_requested = True;
        self._replan_retry_at = time.monotonic() + _PROMOTION_RETRY_SECONDS;
        self._promotion_failed = True;
        return;
    }

    for current_path in current {
        if current_path not in desired or desired[current_path] != current[current_path] {
            self._release_directory(current_path);
        }
    }
    for (key, handle, recursive) in provisional {
        self._watches[key] = _WatchEntry(handle, _watch_identity(key));
        if recursive {
            self._shallow.discard(key);
        } else {
            self._shallow.add(key);
        }
    }
    self._replan_retry_at = 0.0;
    self._degraded = fallback;
    self._unwatched.clear();
    self._promotion_retry_at.clear();
    self._remember_ignored_boundaries();
}

impl _WatchSupervisor.rewatch_all -> bool {
    if self._handler is None {
        return False;
    }
    self._promotion_retry_at.clear();
    plan: any = _plan_watch_paths(
        self._repo_root, self._ignore_patterns, max_schedules=self._max_schedules
    );
    for (path, recursive) in plan {
        self._schedule(path, recursive=recursive);
    }
    self._prune_unwatched();
    if self._watches {
        logger.warning(
            "Re-established %d watch(es) on %s after a total loss of coverage",
            len(self._watches),
            self._repo_root,
        );
    }
    return `bool(self._watches);
}

impl _WatchSupervisor.sync_watches(
    *, ignore_patterns: list[str] | None = None
) -> tuple[list[str], list[str]] {
    name: any;
    previous_patterns: any = self._ignore_patterns;
    if ignore_patterns is not None {
        self._ignore_patterns = ignore_patterns;
    }
    adopted: list[str] = [];
    vanished: list[str] = [];
    self._promotion_failed = False;
    for parent in sorted(self._shallow) {
        present: any = {name for (name, is_dir) in _child_directories(Path(parent)) if is_dir};
        for name in sorted(present) {
            candidate_path: any = Path(parent) / name;
            relative: any = candidate_path.relative_to(self._repo_root).as_posix();
            if _should_ignore(relative, self._ignore_patterns) {
                above_threshold: any = operator.ge(
                    _ignored_tree_weight(candidate_path, _WATCH_SPLIT_MIN_DIRS),
                    _WATCH_SPLIT_MIN_DIRS,
                );
                key: any = `str(candidate_path);
                if self._ignored_boundaries.get(key, False) != above_threshold {
                    self.request_replan();
                }
                self._ignored_boundaries[key] = above_threshold;
            }
        }
        for child in sorted(self._children_of(parent)) {
            if os.path.basename(child) not in present {
                self._release_directory(child);
                vanished.append(child);
            } elif self._watches[child].identity != _watch_identity(child) {
                logger.info("Directory %s was replaced; re-watching it", child);
                self._release_directory(child);
                vanished.append(child);
            }
        }
        for name in sorted(present) {
            if parent not in self._shallow {
                break;
            }
            candidate: any = os.path.join(parent, name);
            if candidate in self._watches {
                continue;
            }
            newly_included: any = previous_patterns is not self._ignore_patterns
                and _should_ignore(
                    Path(candidate).relative_to(self._repo_root).as_posix(), previous_patterns
                );
            refused_before: any = candidate in self._unwatched;
            if self._adopt_directory(candidate, required=newly_included) {
                adopted.append(candidate);
            } elif candidate in self._unwatched and not refused_before {
                self._refused_to_index.append(candidate);
            }
        }
    }
    self._prune_unwatched();
    self._replan_if_requested();
    return (adopted, vanished);
}

impl _WatchSupervisor.take_refused_to_index -> list[str] {
    items__: any = list((self._refused_to_index, []));
    if len(items__) != 2 {
        raise ValueError(
            f"too many values to unpack (expected 2, got {len(items__)})"
                if len(items__) > 2
                else f"not enough values to unpack (expected 2, got {len(items__)})",
        );
    }
    paths: any = items__[0];
    self._refused_to_index = items__[1];
    return paths;
}

impl _WatchSupervisor._note_unwatched(key: str) -> None {
    self._unwatched.pop(key, None);
    self._unwatched[key] = time.time();
    while len(self._unwatched) > _MAX_UNWATCHED_TRACKED {
        self._unwatched.pop(next(iter(self._unwatched)));
    }
}

impl _WatchSupervisor._prune_unwatched -> None {
    for path in [p for p in self._unwatched if not os.path.isdir(p)] {
        self._unwatched.pop(path, None);
    }
}

impl _WatchSupervisor._children_of(parent: str) -> list[str] {
    return [path for path in self._watches if os.path.dirname(path) == parent];
}

impl _WatchSupervisor._descendants_of(parent: str) -> list[str] {
    prefix: any = parent.rstrip(os.sep) + os.sep;
    return [path for path in self._watches if path.startswith(prefix)];
}

impl _WatchSupervisor._adopt_directory(candidate: str, *, required: bool = False) -> bool {
    try {
        relative: any = Path(candidate).relative_to(self._repo_root).as_posix();
    } except ValueError {
        return False;
    }
    if _should_ignore(relative, self._ignore_patterns) {
        logger.debug("Not watching ignored directory %s", relative);
        return False;
    }
    plan: any = self._affordable_plan(Path(candidate));
    if plan is None {
        promoted: any = self._promote_to_recursive(os.path.dirname(candidate));
        if required and not promoted {
            raise RuntimeError(f"Cannot watch newly included directory: {candidate}");
        }
        return promoted;
    }
    for (path, recursive) in plan {
        self._schedule(path, recursive=recursive);
        if required and `str(path) not in self._watches {
            raise RuntimeError(f"Cannot watch newly included directory: {path}");
        }
    }
    if candidate not in self._watches {
        return False;
    }
    logger.info("Watching new directory %s (%d watch(es))", relative, len(plan));
    return True;
}

impl _WatchSupervisor._affordable_plan(directory: Path) -> list[tuple[Path, bool]] | None {
    cache: dict[Path, list[Path]] = {};
    available: any = self._max_schedules - len(self._watches);
    if available <= 0 {
        return None;
    }
    for depth in range(max(1, _WATCH_PLAN_DEPTH), 0, -1) {
        _: any;
        plan: any;
        (_, plan) = _plan_watch_subtree(
            directory, self._repo_root, self._ignore_patterns, 0, depth, cache
        ) as any;
        if len(plan) <= available {
            return plan;
        }
    }
    return [(directory, True)];
}

impl _WatchSupervisor._promote_to_recursive(parent: str) -> bool {
    retry_at: any = self._promotion_retry_at.get(parent);
    if retry_at is not None and time.monotonic() < retry_at {
        self._promotion_failed = True;
        return False;
    }
    try {
        handle: any = self._observer.schedule(self._handler, parent, recursive=True);
    } except OSError as exc {
        self._promotion_failed = True;
        self._promotion_retry_at[parent] = time.monotonic() + _PROMOTION_RETRY_SECONDS;
        logger.warning(
            "Could not promote watch on %s; keeping existing watches and retrying in %.0fs: %s",
            parent,
            _PROMOTION_RETRY_SECONDS,
            exc,
        );
        return False;
    }
    self._promotion_retry_at.pop(parent, None);
    for path in [parent, *self._descendants_of(parent)] {
        self._release_directory(path);
    }
    self._watches[parent] = _WatchEntry(handle, _watch_identity(parent));
    self._degraded = True;
    logger.warning(
        "Watch budget of %d reached; watching %s recursively instead — ignored trees under it are watched again. Raise CRG_MAX_WATCH_SCHEDULES to keep filtering.",
        self._max_schedules,
        parent,
    );
    return True;
}

impl _WatchSupervisor._release_directory(path: str) -> None {
    `entry: any;
    `entry = self._watches.pop(path, None);
    self._shallow.discard(path);
    self._repaired_roots.discard(path);
    self._unwatched.pop(path, None);
    if `entry is None {
        return;
    }
    _run_time_boxed(
        lambda -> any { self._observer.unschedule(`entry.handle) },
        f"unschedule {path}",
        timeout=_WATCH_STOP_TIMEOUT,
    );
}

impl _WatchSupervisor._watchdog_threads -> list[tuple[threading.Thread, str | None]] {
    emitter: any;
    `root: any;
    threads: list[tuple[threading.Thread, str | None]] = [];
    observer: any = self._observer;
    if isinstance(observer, threading.Thread) {
        threads.append((observer, None));
    }
    try {
        emitters: any = `list(getattr(observer, "emitters", ()) or ());
    } except TypeError {
        return threads;
    }
    for emitter_ in emitters {
        emitter = emitter_;
        `root = getattr(getattr(emitter, "watch", None), "path", None);
        `root = `root if isinstance(`root, `str) else None;
        if isinstance(emitter, threading.Thread) {
            threads.append((emitter, `root));
        }
        try {
            members: any = `list(vars(emitter).values());
        } except TypeError {
            continue;
        }
        threads.extend(
            (member, `root)
            for member in members
            if isinstance(member, threading.Thread) and member is not emitter,
        );
    }
    return threads;
}

impl _WatchSupervisor.check_liveness -> tuple[list[str], list[str]] {
    dead: list[str] = [];
    repaired: list[str] = [];
    still_present: dict[int, threading.Thread] = {};
    for (thread, `root) in self._watchdog_threads() {
        key: any = id(thread);
        if thread.is_alive() {
            still_present[key] = thread;
            continue;
        }
        if key not in self._live_threads and thread.ident is None {
            continue;
        }
        if `root is None {
            dead.append(thread.name);
            continue;
        }
        `entry: any = self._watches.get(`root);
        if `entry is None {
            logger.debug("Watch on %s was already released; not a death", `root);
            continue;
        }
        if `entry.identity != _watch_identity(`root) {
            logger.info(
                "Watch root %s is gone or replaced; not a death — sync_watches releases the stale watch and adopts the replacement",
                `root,
            );
            continue;
        }
        if `root in self._repaired_roots {
            dead.append(thread.name);
            continue;
        }
        logger.warning(
            "Watch on %s stopped while the directory is still there; rescheduling it once before giving up",
            `root,
        );
        recursive: any = `root not in self._shallow;
        self._release_directory(`root);
        self._schedule(Path(`root), recursive=recursive);
        if `root not in self._watches {
            logger.error("Could not reschedule the watch on %s", `root);
            dead.append(thread.name);
            continue;
        }
        self._repaired_roots.add(`root);
        repaired.append(`root);
    }
    self._live_threads = still_present;
    return (dead, repaired);
}

impl _WatchSupervisor.report_health(
    *,
    observer_alive: bool,
    last_event_at: float | None = None,
    events_seen: int = 0,
    dead_threads: tuple[str, ...] = (),
    phase: str = "watching",
    force: bool = False,
) -> None {
    if self._health_path is None {
        return;
    }
    now: any = time.time();
    state: any = (observer_alive, self.degraded, `tuple(dead_threads));
    if not force
        and state == self._last_health_state
        and now - self._last_health_write < _WATCH_HEALTH_INTERVAL
    {
        return;
    }
    payload: any = {
        "repo": `str(self._repo_root),
        "pid": os.getpid(),
        "started_at": self._started_at,
        "updated_at": now,
        "observer_alive": observer_alive,
        "last_event_at": last_event_at,
        "events_seen": events_seen,
        "watched_paths": len(self._watches),
        "dead_threads": `list(dead_threads),
        "degraded": self.degraded,
        "failed_paths": self.unwatched_paths,
        "phase": phase,
    };
    try {
        self._health_path.parent.mkdir(parents=True, exist_ok=True);
        temporary: any = self._health_path.with_name(f"{self._health_path.name}.{self._token}.tmp");
        temporary.write_text(json.dumps(payload), encoding="utf-8");
        os.replace(temporary, self._health_path);
    } except OSError as exc {
        logger.debug("Could not write watcher health to %s: %s", self._health_path, exc);
        return;
    }
    self._last_health_write = now;
    self._last_health_state = state;
}

impl _WatchSupervisor.clear_health -> None {
    if self._health_path is None {
        return;
    }
    try {
        self._health_path.unlink(missing_ok=True);
    } except OSError {}
}

impl _WatchSupervisor.__repr__ -> str {
    return (getattr(builtins.object, "__repr__") as any)(self);
}

impl _WatchSupervisor.__eq__(other: any) -> bool {
    return self is other;
}

impl _WatchSupervisor.__hash__ -> int {
    return id(self);
}

impl _is_csharp_project(relative_path: str) -> bool {
    return relative_path.lower().endswith(".csproj");
}

impl _event_only_touches(event: Any, target: Path) -> bool {
    wanted: any;
    paths: any = [
        os.fsdecode(path)
        for path in (event.src_path, getattr(event, "dest_path", ""))
        if path
    ];
    if not paths or `any(operator.ne(os.path.basename(path), target.name) for path in paths) {
        return False;
    }
    wanted = os.path.normcase(os.path.realpath(target));
    return all(operator.eq(os.path.normcase(os.path.realpath(path)), wanted) for path in paths);
}

impl _holds_symlink(directory: Path, relative: str, ignore_patterns: list[str]) -> bool {
    for (current, dirnames, filenames) in os.walk(directory) {
        current_rel: any = Path(relative, os.path.relpath(current, directory)).as_posix();
        kept: any = [];
        for name in [*dirnames, *filenames] {
            entry_rel: any = f"{current_rel}/{name}";
            if _should_ignore(entry_rel, ignore_patterns) {
                continue;
            }
            if os.path.islink(os.path.join(current, name)) {
                return True;
            }
            if name in dirnames {
                kept.append(name);
            }
        }
        dirnames[:] = kept;
    }
    return False;
}

impl _create_watch_handler(
    repo_root: Path,
    store: GraphStore,
    on_files_updated: Optional[Callable],
    on_directory_changed: Optional[Callable[[], None]] = None,
    follow_symlinks: bool | None = None,
) -> any {
    ignore_patterns: any;
    parser: any;
    lexical_root: any;
    resolved_root: any;
    manifest_names: any;
    follow: any;
    processor: any;
    debouncer: any;
    write_lock_file: any;
    import from watchdog.events { FileSystemEvent, FileSystemEventHandler }

    ignore_patterns = _load_ignore_patterns(repo_root);
    parser = _get_code_parser_cls()(repo_root);
    lexical_root = Path(os.path.abspath(repo_root));
    resolved_root = lexical_root.resolve();
    manifest_names = {name for names in NESTED_OUTPUT_DIR_MARKERS.values() for name in names};
    follow = follow_symlinks_enabled(follow_symlinks);

    class WatchBatchProcessor(builtins.object) {
        def init {
            self.followed_links = set[any]();
            self.outside_roots = set[any]();
            self.inside_roots = set[any]();
            if follow {
                self._remember_followed();
            }
            self.failure = None;
            self.last_event_at = None;
            self.events_seen = 0;
            self.lock = threading.Lock();
            self.write_lock = WriteLock(store.db_path);
        }

        def _relative_path(path: str, *, apply_ignores: bool = True) -> str | None {
            candidate: any = Path(os.path.abspath(path));
            try {
                relative: any = candidate.relative_to(lexical_root);
            } except ValueError {
                return None;
            }
            try {
                existing: any = candidate;
                while not existing.exists() and existing != lexical_root {
                    existing = existing.parent;
                }
                existing.resolve().relative_to(resolved_root);
                if `any(
                    component.is_symlink()
                    for component in [
                        lexical_root / Path(*relative.parts[:index])
                        for index in range(1, len(relative.parts) + 1)
                    ],
                ) {
                    return None;
                }
            } except ValueError {
                return None;
            } except OSError as exc {
                logger.debug("Skipping unstattable watch path %s: %s", path[:120], exc);
                return None;
            }
            if apply_ignores and _should_ignore(`str(relative), ignore_patterns) {
                return None;
            }
            return `str(relative);
        }

        def _refresh_ignore_patterns(events: list[FileSystemEvent]) -> tuple[int, set[str]] {
            invalidate: any = False;
            for event in events {
                for path in (event.src_path, getattr(event, "dest_path", "")) {
                    if not path {
                        continue;
                    }
                    relative: any = self._relative_path(os.fsdecode(path), apply_ignores=False);
                    if relative is None {
                        continue;
                    }
                    output_became_file: any = not event.is_directory
                        and event.event_type in {"created", "moved"}
                        and Path(relative).name in NESTED_OUTPUT_DIR_MARKERS
                        and f"/{Path(relative).as_posix()}/**" in ignore_patterns
                        and (repo_root / relative).is_file();
                    if output_became_file
                        or relative == ".code-review-graphignore"
                        or not _should_ignore(relative, ignore_patterns)
                            and (
                                event.is_directory
                                    and event.event_type in {"created", "deleted", "moved"}
                                or Path(relative).name in manifest_names
                                or Path(relative).name.endswith(".gemspec")
                            )
                    {
                        invalidate = True;
                    }
                }
            }
            if invalidate {
                clear_nested_ignore_cache(repo_root);
            }
            refreshed: any = _load_ignore_patterns(repo_root);
            if `set(refreshed) == `set(ignore_patterns) {
                return (0, set[any]());
            }
            previous: any = ignore_patterns;
            ignore_patterns = refreshed;
            _assert_graph_matches_root(repo_root, store);
            newly_included: any = set[any]();
            if `set(previous) - `set(refreshed) {
                newly_included = {
                    path
                    for path in collect_all_files(repo_root, follow_symlinks=follow)
                    if _should_ignore(path, previous)
                        and self._relative_path(`str(repo_root / path)) is not None
                };
            }
            ignored_files: any = [];
            for stored_path in store.get_all_files() {
                try {
                    stored_relative: any = PurePosixPath(
                        normalize_file_path(stored_path)
                    ).relative_to(PurePosixPath(normalize_file_path(repo_root)));
                } except ValueError {
                    continue;
                }
                if _should_ignore(stored_relative.as_posix(), ignore_patterns) {
                    ignored_files.append(stored_path);
                }
            }
            removed: any = store.remove_files_permanently(ignored_files, stored_paths=True)
                if ignored_files
                else 0;
            return (removed, newly_included);
        }

        def _stored_descendants(relative_directory: str) -> set[str] {
            directory: any = normalize_file_path(repo_root / relative_directory) + "/";
            return {
                `str(Path(file_path).relative_to(repo_root))
                for file_path in store.get_all_files()
                if file_path.startswith(directory)
            };
        }

        def _parseable_file(relative_path: str) -> bool {
            absolute_path: any = repo_root / relative_path;
            resolved_path: any = absolute_path.resolve();
            try {
                resolved_path.relative_to(resolved_root);
            } except ValueError {
                return False;
            }
            return absolute_path.is_file()
                and not absolute_path.is_symlink()
                and parser.detect_language(absolute_path) is not None
                and not _is_binary(absolute_path);
        }

        def _parseable_descendants(relative_directory: str) -> set[str] {
            directory: any = repo_root / relative_directory;
            if not directory.is_dir() or directory.is_symlink() {
                return set[any]();
            }
            return {
                `str(path.relative_to(repo_root))
                for path in directory.rglob("*")
                if self._parseable_file(`str(path.relative_to(repo_root)))
                    and not _should_ignore(`str(path.relative_to(repo_root)), ignore_patterns)
            };
        }

        def _event_paths(event: FileSystemEvent) -> set[str] {
            paths: set[str] = set[any]();
            source: any = self._relative_path(os.fsdecode(event.src_path));
            destination_path: any = getattr(event, "dest_path", "");
            destination: any = self._relative_path(os.fsdecode(destination_path))
                if destination_path
                else None;
            if event.is_directory {
                if source is not None and event.event_type in {"deleted", "moved"} {
                    paths.update(self._stored_descendants(source));
                }
                if destination is not None {
                    paths.update(self._parseable_descendants(destination));
                } elif source is not None and event.event_type == "created" {
                    paths.update(self._parseable_descendants(source));
                }
            } else {
                if source is not None and event.event_type in {"deleted", "moved"} {
                    paths.add(source);
                } elif source is not None
                    and (self._parseable_file(source) or _is_csharp_project(source))
                {
                    paths.add(source);
                }
                if destination is not None
                    and (self._parseable_file(destination) or _is_csharp_project(destination))
                {
                    paths.add(destination);
                }
            }
            return paths;
        }

        def _remember_followed -> None {
            tree: any = _followed_tree(repo_root, ignore_patterns);
            self.followed_links = `set(tree.links);
            self.outside_roots = _outermost(tree.outside);
            self.inside_roots = _outermost(tree.inside);
        }

        """Whether a batch changes a symlinked folder, and whether it
            changes a file in a followed folder outside the repository or
            adds or removes one in a followed folder inside it."""
        def _touches_followed(events: list[FileSystemEvent]) -> tuple[bool, bool] {
            relative: any;
            spelled: any;
            prefix: any;
            links_changed: any = False;
            contents_changed: any = False;
            for event in events {
                for raw in (event.src_path, getattr(event, "dest_path", "")) {
                    if not raw {
                        continue;
                    }
                    candidate: any = Path(os.path.abspath(os.fsdecode(raw)));
                    try {
                        relative = candidate.relative_to(lexical_root).as_posix();
                    } except ValueError {
                        spelled = normalize_file_path(candidate);
                        if `any(
                            operator.eq(spelled, `root)
                                or spelled.startswith(`root.rstrip("/") + "/")
                            for `root in self.outside_roots,
                        ) {
                            contents_changed = True;
                            if os.path.islink(candidate) {
                                links_changed = True;
                            }
                        }
                        continue;
                    }
                    if relative == "." or _should_ignore(relative, ignore_patterns) {
                        continue;
                    }
                    if os.path.islink(candidate) {
                        links_changed = True;
                        continue;
                    }
                    if event.event_type in {"created", "deleted", "moved"}
                        and `any(
                            operator.eq(relative, `root) or relative.startswith(`root + "/")
                            for `root in self.inside_roots,
                        )
                    {
                        contents_changed = True;
                    }
                    prefix = relative + "/";
                    if `any(
                        operator.eq(link, relative) or link.startswith(prefix)
                        for link in self.followed_links,
                    )
                        or event.is_directory
                            and _holds_symlink(candidate, relative, ignore_patterns)
                    {
                        links_changed = True;
                    }
                }
            }
            return (links_changed, contents_changed);
        }

        def _reconcile_followed -> int {
            result: any = incremental_update(
                repo_root,
                store,
                changed_files=[],
                reconcile_stale=False,
                follow_symlinks=True,
                reconcile_followed=True,
            );
            _raise_watch_update_errors(result, "symlinked folder reconciliation");
            self._remember_followed();
            return `int(result["files_updated"]);
        }

        def process(events: list[FileSystemEvent]) -> None {
            with self.lock {
                if not self.write_lock.acquire() {
                    logger.debug(
                        "Watch batch for %s waits on the write lock (PID %s)",
                        repo_root,
                        self.write_lock.holder_pid(),
                    );
                    debouncer.requeue(events);
                    return;
                }
                self.last_event_at = time.time();
                self.events_seen += len(events);
                try {
                    patterns_before: any = ignore_patterns;
                    files_updated: any;
                    newly_included: any;
                    (files_updated, newly_included) = self._refresh_ignore_patterns(events) as any;
                    changed_files: any = sorted(
                        newly_included | {
                            path
                            for event in events
                            for path in self._event_paths(event)
                        },
                    );
                    if changed_files {
                        result: any = incremental_update(
                            repo_root,
                            store,
                            changed_files=changed_files,
                            reconcile_stale=False,
                            follow_symlinks=follow,
                        );
                        _raise_watch_update_errors(result, "incremental update");
                        files_updated += result["files_updated"];
                    }
                    if follow {
                        links_changed: any;
                        contents_changed: any;
                        (links_changed, contents_changed) = self._touches_followed(events) as any;
                        links_changed = links_changed or ignore_patterns is not patterns_before;
                        if links_changed or contents_changed {
                            files_updated += self._reconcile_followed();
                        }
                    }
                    if on_files_updated is not None
                        and (
                            files_updated > 0
                            or changed_files and store.get_metadata("csharp_flows_dirty") == "1"
                        )
                    {
                        postprocess_result: any = on_files_updated(store);
                        _raise_watch_postprocess_warnings(postprocess_result);
                    }
                } except BaseException as exc {
                    self.failure = exc;
                } finally {
                    self.write_lock.release();
                }
            }
        }

        def raise_if_failed -> None {
            if self.failure is not None {
                raise RuntimeError("watch update failed") from self.failure;
            }
        }
    }

    processor = WatchBatchProcessor();
    debouncer = _WatchDebouncer(_DEBOUNCE_SECONDS, processor.process);
    write_lock_file = write_lock_path(store.db_path);

    def _handler_dispatch(_self, event: FileSystemEvent) -> None {
        if event.event_type not in {"created", "modified", "deleted", "moved"} {
            return;
        }
        if event.is_directory and event.event_type == "modified" {
            return;
        }
        if _event_only_touches(event, write_lock_file) {
            return;
        }
        if event.is_directory
            and on_directory_changed is not None
            and _inside_lexical_root(event.src_path)
        {
            on_directory_changed();
        }
        debouncer.handle_event(event);
    }

    def _handler_start(_self) -> None {
        debouncer.start();
    }

    def _handler_stop(_self) -> None {
        debouncer.stop();
        debouncer.join();
    }

    def _handler_process(_self, events: list[FileSystemEvent]) -> None {
        processor.process(events);
    }

    """The lock event batches hold while they write to the graph."""
    def _handler_serialized(_self) -> threading.Lock {
        return processor.lock;
    }

    def _handler_raise_if_failed(_self) -> None {
        processor.raise_if_failed();
    }

    def _handler_ignore_patterns(_self) -> list[str] {
        return ignore_patterns;
    }

    def _handler_last_event_at(_self) -> float | None {
        return processor.last_event_at;
    }

    def _handler_events_seen(_self) -> int {
        return processor.events_seen;
    }

    """Followed folders outside the repository, to watch as well."""
    def _handler_outside_roots(_self) -> set[str] {
        return processor.outside_roots;
    }

    handler_class: any = types.new_class("GraphUpdateHandler", (FileSystemEventHandler,));
    handler_class.dispatch = _handler_dispatch;
    handler_class.start = _handler_start;
    handler_class.stop = _handler_stop;
    handler_class.process = _handler_process;
    handler_class.serialized = _handler_serialized;
    handler_class.raise_if_failed = _handler_raise_if_failed;
    handler_class.ignore_patterns = builtins.property(_handler_ignore_patterns);
    handler_class.last_event_at = builtins.property(_handler_last_event_at);
    handler_class.events_seen = builtins.property(_handler_events_seen);
    handler_class.outside_roots = builtins.property(_handler_outside_roots);

    def _inside_lexical_root(raw: Any) -> bool {
        try {
            Path(os.path.abspath(os.fsdecode(raw))).relative_to(lexical_root);
        } except (TypeError, ValueError) {
            return False;
        }
        return True;
    }

    return handler_class();
}

impl _sync_watch_tree(supervisor: _WatchSupervisor, handler: Any) -> None {
    import from watchdog.events { DirCreatedEvent, DirDeletedEvent }

    adopted: any;
    vanished: any;
    (adopted, vanished) = supervisor.sync_watches(ignore_patterns=handler.ignore_patterns) as any;
    outside_roots: any = getattr(handler, "outside_roots", None);
    if isinstance(outside_roots, (`set, frozenset)) {
        supervisor.sync_extra_roots(`set(outside_roots));
    }
    path: any;
    for path in [*adopted, *supervisor.take_refused_to_index()] {
        handler.dispatch(DirCreatedEvent(path));
    }
    for path in vanished {
        handler.dispatch(DirDeletedEvent(path));
    }
}

impl _wait_for_watch_write_lock(
    lock: WriteLock, supervisor: _WatchSupervisor, stop_event: threading.Event | None
) -> bool {
    while not lock.acquire() {
        supervisor.report_health(observer_alive=True, phase="initial-build");
        if stop_event is None {
            time.sleep(_WATCH_LOCK_POLL_SECONDS);
        } elif stop_event.wait(_WATCH_LOCK_POLL_SECONDS) {
            return False;
        }
    }
    return True;
}

impl _install_sigterm_interrupt -> Callable[[], None] {
    previous: any;
    def _raise_interrupt(_signum: int, _frame: Any) -> None {
        raise KeyboardInterrupt();
    }

    try {
        previous = signal.signal(signal.SIGTERM, _raise_interrupt);
    } except (ValueError, OSError, AttributeError) {
        return lambda -> any { None };
    }

    def _restore -> None {
        try {
            signal.signal(signal.SIGTERM, previous);
        } except (ValueError, OSError) {}
    }

    return _restore;
}

impl watch(
    repo_root: Path,
    store: GraphStore,
    on_files_updated: Optional[Callable] = None,
    stop_event: threading.Event | None = None,
    follow_symlinks: bool | None = None,
) -> None {
    import from watchdog.events { DirCreatedEvent, DirDeletedEvent }
    import from watchdog.observers { Observer }
    repo_root = _canonical_repo_root(repo_root);
    _assert_graph_matches_root(repo_root, store);
    supervisor: any = _WatchSupervisor(
        None, repo_root, _load_ignore_patterns(repo_root), health_path=_watch_health_path(repo_root)
    );
    supervisor.report_health(observer_alive=True, phase="initial-build", force=True);

    observer: any = Observer();
    supervisor.attach(observer);
    handler: any = _create_watch_handler(
        repo_root,
        store,
        on_files_updated,
        supervisor.request_replan,
        follow_symlinks=follow_symlinks,
    );
    supervisor.schedule_initial(handler);
    outside_roots: any = getattr(handler, "outside_roots", None);
    if isinstance(outside_roots, (`set, frozenset)) and outside_roots {
        supervisor.sync_extra_roots(`set(outside_roots));
    }
    handler.start();
    observer_started: any = False;
    try {
        with handler.serialized() {
            observer.start();
            observer_started = True;
            write_lock: any = WriteLock(store.db_path);
            if _wait_for_watch_write_lock(write_lock, supervisor, stop_event) {
                try {
                    initial: any = incremental_update(
                        repo_root, store, changed_files=[], follow_symlinks=follow_symlinks
                    );
                    _raise_watch_update_errors(initial, "initial watch reconciliation");
                    if initial["files_updated"] > 0 and on_files_updated is not None {
                        postprocess_result: any = on_files_updated(store);
                        _raise_watch_postprocess_warnings(postprocess_result);
                    }
                } finally {
                    write_lock.release();
                }
            }
        }
    } except BaseException {
        _run_time_boxed(observer.stop, "observer stop");
        if observer_started {
            observer.join(timeout=_WATCH_STOP_TIMEOUT);
        }
        handler.stop();
        raise;
    }
    supervisor.report_health(observer_alive=True, force=True);

    logger.info("Watching %s for changes... (Ctrl+C to stop)", repo_root);
    restore_sigterm: any = _install_sigterm_interrupt();
    try {
        import time as _time;

        while True {
            if stop_event is not None {
                if stop_event.wait(_WATCH_TICK_SECONDS) {
                    break;
                }
            } else {
                _time.sleep(_WATCH_TICK_SECONDS);
            }
            handler.raise_if_failed();
            _sync_watch_tree(supervisor, handler);
            if not supervisor.watched_paths {
                if not supervisor.rewatch_all() {
                    supervisor.report_health(
                        observer_alive=False,
                        last_event_at=handler.last_event_at,
                        events_seen=handler.events_seen,
                        dead_threads=("no filesystem watches",),
                        force=True,
                    );
                    logger.error(
                        "No filesystem watches could be established on %s (the OS watch limit is the usual cause); this watcher is exiting rather than reporting health while watching nothing. Raise the limit (Linux: fs.inotify.max_user_watches) or CRG_MAX_WATCH_SCHEDULES, then restart it.",
                        repo_root,
                    );
                    raise RuntimeError(
                        f"watch observer has no watches on {repo_root}: the OS refused every watch (watch limit exhausted)",
                    );
                }
            }
            dead: any;
            repaired: any;
            (dead, repaired) = supervisor.check_liveness() as any;
            for path in repaired {
                handler.dispatch(DirDeletedEvent(path));
                handler.dispatch(DirCreatedEvent(path));
            }
            if dead {
                names: any = ", ".join(dead);
                supervisor.report_health(
                    observer_alive=False,
                    last_event_at=handler.last_event_at,
                    events_seen=handler.events_seen,
                    dead_threads=`tuple(dead),
                    force=True,
                );
                logger.error(
                    "Filesystem watcher thread(s) died (%s); %s would stop updating silently, so this watcher is exiting for the daemon to restart it",
                    names,
                    repo_root,
                );
                raise RuntimeError(f"watch observer stopped: dead thread(s) {names}");
            }
            supervisor.report_health(
                observer_alive=True,
                last_event_at=handler.last_event_at,
                events_seen=handler.events_seen,
            );
        }
        supervisor.clear_health();
    } except KeyboardInterrupt {
        supervisor.clear_health();
        _run_time_boxed(observer.stop, "observer stop");
    } finally {
        restore_sigterm();
        _run_time_boxed(observer.stop, "observer stop");
        observer.join(timeout=_WATCH_STOP_TIMEOUT);
        handler.stop();
    }
    logger.info("Watch stopped.");
}

impl start_watch_thread(
    repo_root: Path,
    store: GraphStore,
    daemon: bool = True,
    *,
    on_files_updated: Optional[Callable] = None,
    stop_event: threading.Event | None = None,
) -> threading.Thread | None {
    try {
        import watchdog;
    } except ImportError {
        logger.warning("watchdog not installed; auto-watch disabled");
        return None;
    }

    def _run -> None {
        try {
            if stop_event is None {
                watch(repo_root, store, on_files_updated=on_files_updated);
            } else {
                watch(repo_root, store, on_files_updated=on_files_updated, stop_event=stop_event);
            }
        } except RuntimeError as exc {
            logger.error("Auto-watch for %s stopped: %s", repo_root, exc);
        }
    }

    thread: any = threading.Thread(target=_run, daemon=daemon, name="crg-watch");
    thread.start();
    logger.info("Auto-watch started for %s", repo_root);
    return thread;
}
