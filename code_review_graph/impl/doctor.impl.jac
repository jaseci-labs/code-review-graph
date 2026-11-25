impl Report.to_json -> dict[str, Any] {
    return {
        "healthy": self.healthy,
        "repo_root": self.repo_root,
        "this_copy": self.this_copy,
        "path_copies": [asdict(c) for c in self.path_copies],
        "mcp_entries": [asdict(e) for e in self.mcp_entries],
        "graph": self.graph,
        "hooks": self.hooks,
        "checks": [asdict(f) for f in self.findings],
    };
}

impl _run_quietly(argv: list[str], cwd: Path | None) -> str | None {
    env: any = `dict(os.environ);
    env["NO_COLOR"] = "1";
    try {
        result: any = subprocess.run(
            argv,
            capture_output=True,
            text=True,
            encoding="utf-8",
            errors="replace",
            cwd=`str(cwd) if cwd else tempfile.gettempdir(),
            env=env,
            stdin=subprocess.DEVNULL,
            timeout=_PROBE_TIMEOUT_SECONDS,
            check=False,
        );
    } except (OSError, subprocess.TimeoutExpired, ValueError) {
        return None;
    }
    if result.returncode != 0 {
        return None;
    }
    return (result.stdout or "") + (result.stderr or "");
}

impl _Prober.init(run: Callable[[list[str], Path | None], str | None]) {
    self._run = run;
    self._seen = {};
}

impl _Prober.version(argv: list[str], cwd: Path | None = None) -> str | None {
    key: any = (`tuple(argv), `str(cwd or ""));
    if key not in self._seen {
        output: any = self._run(argv, cwd) or "";
        `match: any = _NAMED_VERSION_RE.search(output) or _VERSION_RE.search(output);
        self._seen[key] = `match.group(1) if `match else None;
    }
    return self._seen[key];
}

impl _Prober.uv_tool_version -> str | None {
    uv: any = shutil.which("uv");
    if uv is None {
        return None;
    }
    output: any = self._run([uv, "tool", "list"], None);
    `match: any = _UV_TOOL_LINE_RE.search(output or "");
    return `match.group(1) if `match else None;
}

impl _Prober.__repr__ -> str {
    return (getattr(builtins.object, "__repr__") as any)(self);
}

impl _Prober.__eq__(other: any) -> bool {
    return self is other;
}

impl _Prober.__hash__ -> int {
    return id(self);
}

impl _program_names -> list[str] {
    if operator.ne(os.name, "nt") {
        return ["code-review-graph"];
    }
    exts: any = os.environ.get("PATHEXT", ".EXE;.CMD;.BAT").split(os.pathsep);
    return [f"code-review-graph{ext.lower()}" for ext in exts if ext];
}

impl copies_on_path(path_env: str | None = None) -> list[Path] {
    found: list[Path] = [];
    seen: set[str] = set[any]();
    raw: any = os.environ.get("PATH", "") if path_env is None else path_env;
    for folder in raw.split(os.pathsep) {
        if not folder {
            continue;
        }
        for name in _program_names() {
            candidate: any = Path(folder) / name;
            try {
                if not candidate.is_file() or not os.access(candidate, os.X_OK) {
                    continue;
                }
                real: any = os.path.realpath(candidate);
            } except OSError {
                continue;
            }
            if real in seen {
                continue;
            }
            seen.add(real);
            found.append(candidate);
        }
    }
    return found;
}

impl _version_key(version: str) -> tuple[int, ...] | None {
    `match: any = re.match("(\\d+)\\.(\\d+)\\.(\\d+)", version);
    return `tuple(`int(part) for part in `match.groups()) if `match else None;
}

impl _older_than_this(version: str) -> bool | None {
    mine: any;
    theirs: any;
    (mine, theirs) = (_version_key(__version__), _version_key(version));
    if mine is None or theirs is None {
        return None;
    }
    return operator.lt(theirs, mine);
}

impl _mismatch_fix(version: str, where: str, upgrade: str) -> str {
    if _older_than_this(version) is False {
        return f"This copy ({__version__}) is the older one. Upgrade it ({_UPGRADE_ANY}), then restart your AI tool.";
    }
    return f"Upgrade {where}: {upgrade}. Then restart your AI tool.";
}

impl _upgrade_for(path: str) -> str {
    try {
        path = os.path.realpath(path);
    } except (OSError, ValueError) {}
    lowered: any = path.replace("\\", "/").lower();
    if "/uv/tools/" in lowered {
        return "uv tool upgrade code-review-graph";
    }
    if "/pipx/" in lowered {
        return "pipx upgrade code-review-graph";
    }
    return _UPGRADE_ANY;
}

impl _read_json(path: Path) -> Any {
    _strip_jsonc = lazy("skills", "_strip_jsonc");

    try {
        text: any = path.read_text(encoding="utf-8");
    } except (OSError, UnicodeDecodeError) {
        return None;
    }
    try {
        return json.loads(_strip_jsonc(text));
    } except (json.JSONDecodeError, ValueError) {
        return None;
    }
}

impl _repo_mcp_configs(`root: Path) -> dict[Path, tuple[str, list[str]]] {
    PLATFORMS = lazy("skills", "PLATFORMS");

    configs: dict[Path, tuple[str, list[str]]] = {};
    for plat in PLATFORMS.values() {
        if plat.get("format") != "object" {
            continue;
        }
        try {
            paths: any = plat["config_paths"](`root)
                if "config_paths" in plat
                else (plat["config_path"](`root),);
        } except (OSError, RuntimeError, KeyError) {
            continue;
        }
        for path in paths {
            try {
                path.resolve().relative_to(`root.resolve());
            } except (OSError, ValueError) {
                continue;
            }
            key: any;
            names: any;
            (key, names) = configs.setdefault(path, (plat["key"], [])) as any;
            names.append(plat["name"]);
        }
    }
    return configs;
}

impl _entry_tokens(`entry: dict[str, Any]) -> list[str] | None {
    command: any = `entry.get("command");
    if isinstance(command, `str) {
        tokens: any = [command];
    } elif isinstance(command, `list) and all(isinstance(t, `str) for t in command) {
        tokens = `list(command);
    } else {
        return None;
    }
    args: any = `entry.get("args", []);
    if not isinstance(args, `list) or not all(isinstance(t, `str) for t in args) {
        return None;
    }
    return tokens + args if tokens else None;
}

impl _launcher(token: str) -> str {
    name: any = token.replace("\\", "/").rsplit("/", 1)[-1];
    return name[:-4] if name.lower().endswith(".exe") else name;
}

impl _uvx_spec(rest: list[str]) -> str | None {
    word: any;
    for (index, word) in enumerate(rest) {
        if word == "--from" and index + 1 < len(rest) {
            return rest[index + 1];
        }
        if word.startswith("--from=") {
            return word.split("=", 1)[1];
        }
    }
    for word in rest {
        if not word.startswith("-") {
            return word;
        }
    }
    return None;
}

impl _program_doctor_may_run(exe: str, `root: Path) -> str | None {
    if os.path.isabs(exe) {
        found: str | None = exe;
    } elif os.sep in exe or "/" in exe or os.altsep and os.altsep in exe {
        return None;
    } else {
        found = shutil.which(exe);
    }
    if found is None or not os.path.isfile(found) {
        return None;
    }
    real: any;
    repo: any;
    (real, repo) = (Path(os.path.realpath(found)), Path(os.path.realpath(`root)));
    if real == repo or repo in real.parents {
        `own: any = {Path(os.path.realpath(sys.executable))};
        `own.add(Path(os.path.realpath(Path(sys.executable).parent / Path(found).name)));
        return found if real in `own else None;
    }
    return found;
}

impl resolve_mcp_entry(tokens: list[str], `root: Path, prober: _Prober) -> _Resolved {
    launcher: any;
    rest: any;
    (launcher, rest) = (_launcher(tokens[0]), tokens[1:]);

    if launcher == "uvx" or launcher == "uv" and rest[:2] == ["tool", "run"] {
        if launcher == "uv" {
            rest = rest[2:];
        }
        pinned: any = _PINNED_SPEC_RE.match(_uvx_spec(rest) or "");
        if pinned {
            return _Resolved(
                pinned.group(1),
                "pinned in the entry",
                "run code-review-graph install again to rewrite the entry",
            );
        }
        if "--isolated" not in rest {
            installed: any = prober.uv_tool_version();
            if installed {
                return _Resolved(
                    installed,
                    "the copy uv tool install put in place",
                    "uv tool upgrade code-review-graph",
                );
            }
        }
        return _Resolved(
            None,
            "uvx picks a copy when it starts, and finding out could mean a download. To see it, run: uvx code-review-graph --version",
        );
    }

    if launcher == "uv" and rest[:1] == ["run"] {
        return _Resolved(
            None,
            "uv run uses the project's own copy. To see it, run: uv run code-review-graph --version",
        );
    }

    if launcher == "poetry" {
        return _Resolved(
            None,
            "poetry run uses the project's own copy. To see it, run: poetry run code-review-graph --version",
        );
    }

    if _PYTHON_RE.match(launcher) and rest[:2] == ["-m", "code_review_graph"] {
        python: any = tokens[0];
        if _program_doctor_may_run(python, `root) is None {
            return _Resolved(None, _NOT_RUN);
        }
        version: any = prober.version([python, "-I", "-m", "code_review_graph", "--version"]);
        if version {
            return _Resolved(
                version,
                f"the copy installed for {python}",
                f"\"{python}\" -m pip install -U code-review-graph",
            );
        }
        return _Resolved(None, f"{python} did not answer --version");
    }

    if launcher == "code-review-graph" {
        exe: any = tokens[0];
        if not os.path.isabs(exe)
            and os.sep not in exe
            and "/" not in exe
            and shutil.which(exe) is None
        {
            return _Resolved(
                None,
                "there is no code-review-graph on PATH here, and the AI tool's PATH may differ",
            );
        }
        allowed: any = _program_doctor_may_run(exe, `root);
        if allowed is None {
            return _Resolved(None, _NOT_RUN);
        }
        exe = allowed;
        version = prober.version([exe, "--version"]);
        if version {
            return _Resolved(version, f"the copy at {exe}", _upgrade_for(exe));
        }
        return _Resolved(None, f"{exe} did not answer --version");
    }

    return _Resolved(None, "it is a hand-written command doctor cannot read");
}

impl check_mcp_entries(`root: Path, prober: _Prober) -> tuple[list[McpEntry], list[Finding]] {
    entries: list[McpEntry] = [];
    findings: list[Finding] = [];
    for (path, (key, names)) in _repo_mcp_configs(`root).items() {
        if not path.is_file() {
            continue;
        }
        data: any = _read_json(path);
        servers: any = data.get(key) if isinstance(data, `dict) else None;
        `entry: any = servers.get("code-review-graph") if isinstance(servers, `dict) else None;
        if not isinstance(`entry, `dict) {
            continue;
        }
        tokens: any = _entry_tokens(`entry);
        relative: any = Path(os.path.relpath(path, `root)).as_posix();
        label: any = "MCP entry in "
            + format(relative, "")
            + " ("
            + format(", ".join(names), "")
            + ")";
        if tokens is None {
            findings.append(Finding(WARN, f"{label}: no command doctor can read."));
            continue;
        }
        found: any = resolve_mcp_entry(tokens, `root, prober);
        command: any = " ".join(tokens);
        entries.append(McpEntry(relative, names, command, found.version, found.source));
        if found.version is None {
            findings.append(
                Finding(WARN, f"{label} runs: {command}. Version unknown: {found.source}.")
            );
        } elif found.version == __version__ {
            findings.append(Finding(OK, f"{label} runs {found.version} ({found.source})."));
        } else {
            findings.append(
                Finding(
                    FAIL,
                    f"{label} runs {found.version}, not {__version__} ({found.source}).",
                    _mismatch_fix(found.version, "the copy the MCP entry runs", found.upgrade),
                ),
            );
        }
    }
    return (entries, findings);
}

impl _read_only_uri(db_path: Path) -> str {
    sidecars: any = [db_path.with_name(db_path.name + s) for s in ("-wal", "-shm")];
    query: any = "mode=ro" if `any(p.exists() for p in sidecars) else "mode=ro&immutable=1";
    return f"{db_path.resolve().as_uri()}?{query}";
}

impl _live_head(`root: Path) -> str | None {
    if not (`root / ".git").exists() {
        return None;
    }
    output: any = _run_quietly(["git", "rev-parse", "--verify", "HEAD"], `root);
    return output.strip().splitlines()[0] if output and output.strip() else None;
}

impl _holds_commits_since(`root: Path, db_path: Path, built: str) -> bool {
    files_hold_commits = lazy("incremental", "files_hold_commits");
    normalize_file_path = lazy("parser", "normalize_file_path");

    def file_hashes -> dict[str, str] {
        conn: any = sqlite3.connect(_read_only_uri(db_path), uri=True, timeout=2);
        try {
            rows: any = conn.execute(
                "SELECT file_path, file_hash FROM nodes WHERE kind = ?", ("File",)
            ).fetchall();
        } finally {
            conn.close();
        }
        return {normalize_file_path(path): file_hash or "" for (path, file_hash) in rows};
    }

    try {
        return files_hold_commits(`root, file_hashes, built);
    } except (sqlite3.Error, OSError) {
        return False;
    }
}

impl check_graph(`root: Path) -> tuple[dict[str, Any], list[Finding]] {
    BUILD_STATE_KEY = lazy("build_state", "BUILD_STATE_KEY");
    INCOMPLETE_BUILD_STATES = lazy("build_state", "INCOMPLETE_BUILD_STATES");
    get_db_path = lazy("incremental", "get_db_path");
    LATEST_VERSION = lazy("migrations", "LATEST_VERSION");
    get_schema_version = lazy("migrations", "get_schema_version");

    db_path: any = get_db_path(`root, read_only=True);
    info: dict[str, Any] = {
        "path": `str(db_path),
        "exists": db_path.is_file(),
        "supported_schema_version": LATEST_VERSION,
    };
    if not db_path.is_file() {
        return (info, [Finding(FAIL, f"No graph at {db_path}.", "Run: code-review-graph build")]);
    }
    try {
        conn: any = sqlite3.connect(_read_only_uri(db_path), uri=True, timeout=2);
        try {
            schema: any = get_schema_version(conn);
            metadata: any = `dict(
                conn.execute(
                    "SELECT key, value FROM metadata WHERE key IN (?, ?, ?)",
                    (BUILD_STATE_KEY, "git_head_sha", "last_updated"),
                ).fetchall(),
            );
            nodes: any = conn.execute("SELECT COUNT(*) FROM nodes").fetchone()[0];
            files: any = conn.execute(
                "SELECT COUNT(*) FROM nodes WHERE kind = 'File'"
            ).fetchone()[0];
        } finally {
            conn.close();
        }
    } except sqlite3.Error as exc {
        return (
            info,
            [
                Finding(
                    FAIL,
                    f"Could not read the graph at {db_path} ({exc}).",
                    "Run: code-review-graph build",
                ),
            ],
        );
    }
    info.update(schema_version=schema, nodes=nodes, files=files);
    findings: list[Finding] = [];

    if schema > LATEST_VERSION {
        findings.append(
            Finding(
                FAIL,
                f"The graph is schema v{schema}, written by a newer copy; this copy ({__version__}) understands v{LATEST_VERSION}.",
                f"Upgrade this copy ({_UPGRADE_ANY}).",
            ),
        );
        return (info, findings);
    }
    if schema < LATEST_VERSION {
        findings.append(
            Finding(
                WARN,
                f"The graph is schema v{schema}; the next build or update moves it to v{LATEST_VERSION}, and older copies cannot read it after that.",
            ),
        );
    }

    state: any = `str(metadata.get(BUILD_STATE_KEY) or "");
    info["build_state"] = state or None;
    if state in INCOMPLETE_BUILD_STATES {
        findings.append(
            Finding(
                FAIL,
                "The last build did not finish, so files may be missing.",
                "Run: code-review-graph build",
            ),
        );
    }
    built: any = metadata.get("git_head_sha") or None;
    head: any = _live_head(`root) if built else None;
    info.update(built_at_sha=built, head_sha=head, updated_at=metadata.get("last_updated"));
    summary: any = f"Graph: schema v{schema}, {files} files, {nodes} nodes";
    matches: any = operator.eq(built, head) if built and head else None;
    if matches is False and _holds_commits_since(`root, db_path, `str(built)) {
        info["stale"] = False;
        findings.append(
            Finding(
                OK,
                f"{summary}, built at {`str(built)[:7]}. HEAD is {`str(head)[:7]}, but the graph already holds every file changed since, so it is current.",
            ),
        );
    } elif matches is False {
        info["stale"] = True;
        findings.append(
            Finding(
                FAIL,
                f"{summary}, built at {`str(built)[:7]} but HEAD is {`str(head)[:7]}.",
                "Run: code-review-graph update",
            ),
        );
    } elif matches is True {
        info["stale"] = False;
        findings.append(Finding(OK, f"{summary}, built at HEAD ({`str(head)[:7]})."));
    } else {
        info["stale"] = None;
        findings.append(Finding(INFO, f"{summary}. Cannot tell which commit it was built at."));
    }
    return (info, findings);
}

impl _git_hooks_dir(`root: Path) -> Path | None {
    output: any = _run_quietly(["git", "rev-parse", "--git-path", "hooks"], `root);
    if output and output.strip() {
        return `root / output.strip().splitlines()[0];
    }
    fallback: any = `root / ".git" / "hooks";
    return fallback if fallback.is_dir() else None;
}

impl _ours(text: str) -> bool {
    return `any(marker in text for marker in _HOOK_MARKERS);
}

impl _runners(text: str) -> set[str] {
    named: any = `set(_ABSOLUTE_PROGRAM_RE.findall(text))
        | `set(_ABSOLUTE_PYTHON_RE.findall(text))
        | `set(_QUOTED_PYTHON_RE.findall(text));
    if _UVX_HOOK_RE.search(text) {
        named.add("uvx");
    }
    return named or {"PATH"};
}

impl _settings_hook_events(path: Path) -> list[str] {
    data: any = _read_json(path);
    hooks: any = data.get("hooks") if isinstance(data, `dict) else None;
    if not isinstance(hooks, `dict) {
        return [];
    }
    events: list[str] = [];
    for (event, entries) in hooks.items() {
        if not isinstance(entries, `list) {
            continue;
        }
        commands: list[str] = [];
        for `entry in entries {
            if not isinstance(`entry, `dict) {
                continue;
            }
            commands.append(`str(`entry.get("command", "")));
            for inner in `entry.get("hooks", []) if isinstance(`entry.get("hooks"), `list) else [] {
                if isinstance(inner, `dict) {
                    commands.append(`str(inner.get("command", "")));
                }
            }
        }
        if `any(_ours(command) for command in commands) {
            events.append(`str(event));
        }
    }
    return events;
}

impl _hook_settings_files(`root: Path) -> list[tuple[str, Path]] {
    _codex_home = lazy("skills", "_codex_home");

    return [
        ("Claude Code", `root / ".claude" / "settings.json"),
        ("Qoder", `root / ".qoder" / "settings.json"),
        ("CodeBuddy Code", `root / ".codebuddy" / "settings.json"),
        ("Gemini CLI", `root / ".gemini" / "settings.json"),
        ("Codex", _codex_home() / "hooks.json"),
        ("Cursor", Path.home() / ".cursor" / "hooks.json"),
    ];
}

impl _check_uvx_hooks(prober: _Prober, path_copies: list[Copy]) -> list[Finding] {
    if shutil.which("uvx") is None {
        if path_copies {
            return [];
        }
        return [
            Finding(
                WARN,
                "The hooks call uvx, or code-review-graph from PATH, but neither is on PATH here, so they do nothing.",
                "Install it where your shell finds it, for example: uv tool install code-review-graph",
            ),
        ];
    }
    version: any = prober.uv_tool_version();
    if version is None {
        return [
            Finding(
                WARN,
                "The hooks run uvx code-review-graph. Version unknown: uvx picks a copy when it starts, and finding out could mean a download. To see it, run: uvx code-review-graph --version",
            ),
        ];
    }
    if version != __version__ {
        return [
            Finding(
                FAIL,
                f"The hooks run uvx code-review-graph, which is {version}, not {__version__}.",
                _mismatch_fix(version, "the copy uvx runs", "uv tool upgrade code-review-graph"),
            ),
        ];
    }
    return [];
}

impl check_hooks(
    `root: Path, prober: _Prober, path_copies: list[Copy]
) -> tuple[list[dict[str, Any]], list[Finding]] {
    hooks: list[dict[str, Any]] = [];
    runners: set[str] = set[any]();

    hooks_dir: any = _git_hooks_dir(`root);
    if hooks_dir is not None {
        names: list[str] = [];
        for name in _GIT_HOOK_NAMES {
            path: any = hooks_dir / name;
            try {
                text: any = path.read_text(encoding="utf-8", errors="replace");
            } except OSError {
                continue;
            }
            if _ours(text) {
                names.append(name);
                runners.update(_runners(text));
            }
        }
        if names {
            hooks.append({"where": "git", "file": `str(hooks_dir), "events": names});
        }
    }

    for (label, path) in _hook_settings_files(`root) {
        if not path.is_file() {
            continue;
        }
        events: any = _settings_hook_events(path);
        if events {
            hooks.append({"where": label, "file": `str(path), "events": events});
            text = path.read_text(encoding="utf-8", errors="replace");
            runners.update(_runners(text));
        }
    }

    findings: list[Finding] = [];
    if not hooks {
        findings.append(
            Finding(
                INFO,
                "Hooks: none found, so the graph changes only when you run update or build. code-review-graph install adds them.",
            ),
        );
        return (hooks, findings);
    }

    listed: any = "; ".join(
        format(h["where"], "") + " " + format(", ".join(h["events"]), "") for h in hooks
    );
    findings.append(Finding(OK, f"Hooks: {listed}."));
    if "PATH" in runners and not path_copies {
        findings.append(
            Finding(
                WARN,
                "The hooks call code-review-graph from PATH, but there is none on PATH here, so they do nothing.",
                "Install it where your shell finds it, for example: uv tool install code-review-graph",
            ),
        );
    }
    if "uvx" in runners {
        findings.extend(_check_uvx_hooks(prober, path_copies));
    }
    for runner in sorted(r for r in runners if r not in ("PATH", "uvx")) {
        if _program_doctor_may_run(runner, `root) is None {
            findings.append(
                Finding(
                    WARN,
                    f"The hooks run {runner}. Version unknown: {_NOT_RUN}.",
                    "Run code-review-graph install again to rewrite the hooks.",
                ),
            );
            continue;
        }
        argv: any = [runner, "-I", "-m", "code_review_graph", "--version"]
            if _PYTHON_RE.match(_launcher(runner))
            else [runner, "--version"];
        version: any = prober.version(argv);
        if version is None {
            findings.append(
                Finding(
                    FAIL,
                    f"The hooks run {runner}, which did not answer --version.",
                    "Run code-review-graph install again to rewrite the hooks.",
                ),
            );
        } elif version != __version__ {
            findings.append(
                Finding(
                    FAIL,
                    f"The hooks run {runner}, which is {version}, not {__version__}.",
                    _mismatch_fix(version, f"the copy at {runner}", _upgrade_for(runner)),
                ),
            );
        }
    }
    return (hooks, findings);
}

impl check_path_copies(prober: _Prober) -> tuple[list[Copy], list[Finding]] {
    copies: any = [Copy(`str(p), prober.version([`str(p), "--version"])) for p in copies_on_path()];
    findings: list[Finding] = [];
    if not copies {
        findings.append(
            Finding(
                INFO,
                "On PATH: no code-review-graph. Your shell cannot find it, and nor can a hook that names no copy.",
            ),
        );
    }
    for (index, copy) in enumerate(copies) {
        role: any = "Your shell runs this one, and so does a hook that names no copy"
            if index == 0
            else "Hidden behind the one above";
        shown: any = copy.version or "no answer to --version";
        message: any = f"On PATH: {copy.path} {shown}. {role}.";
        if copy.version == __version__ {
            findings.append(Finding(OK, message));
        } elif index == 0 {
            findings.append(
                Finding(
                    FAIL,
                    message,
                    _mismatch_fix(
                        copy.version or "", f"the copy at {copy.path}", _upgrade_for(copy.path)
                    )
                        if copy.version
                        else f"Reinstall the copy at {copy.path}.",
                ),
            );
        } else {
            findings.append(
                Finding(WARN, message, f"Remove it, or upgrade it too: {_upgrade_for(copy.path)}.")
            );
        }
    }
    return (copies, findings);
}

impl diagnose(
    repo_root: Path, run: Callable[[list[str], Path | None], str | None] = run_default_
) -> Report {
    prober: any = _Prober(run);
    `here: any = Path(__file__).resolve().parent;
    `report: any = Report(
        repo_root=`str(repo_root),
        this_copy={"version": __version__, "package": `str(`here), "python": sys.executable},
    );
    `report.findings.append(Finding(OK, f"This copy: {__version__} at {`here}."));

    items_: any = list(check_path_copies(prober) as any);
    if len(items_) != 2 {
        raise ValueError(
            f"too many values to unpack (expected 2, got {len(items_)})"
                if len(items_) > 2
                else f"not enough values to unpack (expected 2, got {len(items_)})",
        );
    }
    `report.path_copies = items_[0];
    found: any = items_[1];
    `report.findings.extend(found);
    items__: any = list(check_mcp_entries(repo_root, prober) as any);
    if len(items__) != 2 {
        raise ValueError(
            f"too many values to unpack (expected 2, got {len(items__)})"
                if len(items__) > 2
                else f"not enough values to unpack (expected 2, got {len(items__)})",
        );
    }
    `report.mcp_entries = items__[0];
    found = items__[1];
    `report.findings.extend(found);
    items___: any = list(check_graph(repo_root) as any);
    if len(items___) != 2 {
        raise ValueError(
            f"too many values to unpack (expected 2, got {len(items___)})"
                if len(items___) > 2
                else f"not enough values to unpack (expected 2, got {len(items___)})",
        );
    }
    `report.graph = items___[0];
    found = items___[1];
    `report.findings.extend(found);
    items____: any = list(check_hooks(repo_root, prober, `report.path_copies) as any);
    if len(items____) != 2 {
        raise ValueError(
            f"too many values to unpack (expected 2, got {len(items____)})"
                if len(items____) > 2
                else f"not enough values to unpack (expected 2, got {len(items____)})",
        );
    }
    `report.hooks = items____[0];
    found = items____[1];
    `report.findings.extend(found);
    return `report;
}

impl render(`report: Report) -> str {
    lines: any = [f"code-review-graph doctor: {`report.repo_root}", ""];
    for finding in `report.findings {
        lines.append(f"  {finding.status:<5} {finding.message}");
        if finding.fix {
            lines.append(f"        Fix: {finding.fix}");
        }
    }
    problems: any = sum(1 for f in `report.findings if f.status == FAIL);
    lines.append("");
    lines.append(
        "All good."
            if not problems
            else format(problems, "")
                + " problem"
                + format("s" if problems != 1 else "", "")
                + " found.",
    );
    return "\n".join(lines);
}

impl run_doctor(repo_root: Path, *, as_json: bool = False) -> int {
    `report: any = diagnose(repo_root);
    if as_json {
        print(json.dumps(`report.to_json(), indent=2));
    } else {
        print(render(`report));
    }
    return 0 if `report.healthy else 1;
}
