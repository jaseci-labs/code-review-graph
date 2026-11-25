impl _absolute(path: Path) -> Path {
    return Path(os.path.abspath(os.fspath(path.expanduser())));
}

impl _is_lexical_child(path: Path, boundary: Path) -> bool {
    candidate: any = _absolute(path);
    `root: any = _absolute(boundary);
    if candidate == `root {
        return False;
    }
    try {
        candidate.relative_to(`root);
    } except ValueError {
        return False;
    }
    return True;
}

impl _safe_path(
    path: Path, boundary: Path, `report: UninstallReport, *, describe_skip: bool = True
) -> bool {
    candidate: any = _absolute(path);
    `root: any = _absolute(boundary);
    if not _is_lexical_child(candidate, `root) {
        if describe_skip {
            `report.skipped_paths.append(f"{candidate} (outside allowed boundary {`root})");
        }
        return False;
    }

    try {
        resolved_root: any = `root.resolve(strict=False);
        resolved_candidate: any = candidate.resolve(strict=False);
        resolved_candidate.relative_to(resolved_root);
    } except (OSError, RuntimeError, ValueError) {
        if describe_skip {
            `report.skipped_paths.append(
                f"{candidate} (resolved outside allowed boundary {`root})"
            );
        }
        return False;
    }

    current: any = candidate;
    while current != `root {
        try {
            if current.is_symlink() {
                if describe_skip {
                    `report.skipped_paths.append(f"{candidate} (symlink path is not removed)");
                }
                return False;
            }
        } except OSError as exc {
            if describe_skip {
                `report.skipped_paths.append(f"{candidate} (cannot inspect path: {exc})");
            }
            return False;
        }
        current = current.parent;
    }
    return True;
}

impl _done(detail: str, dry_run: bool) -> str {
    if dry_run {
        return f"would {detail}";
    }
    verb: any;
    _: any;
    rest: any;
    (verb, _, rest) = detail.partition(" ") as any;
    past: any = f"{verb}d" if verb.endswith("e") else f"{verb}ed";
    return f"{past} {rest}" if rest else past;
}

impl _record_edit(`report: UninstallReport, path: Path, detail: str, dry_run: bool) {
    `report.edited_paths.append(f"{path} ({_done(detail, dry_run)})");
    `report.touched.append(path);
}

impl _record_remove(`report: UninstallReport, path: Path, detail: str, dry_run: bool) {
    `report.removed_paths.append(f"{path} ({_done(detail, dry_run)})");
    `report.touched.append(path);
}

impl _read_text(path: Path, `report: UninstallReport) -> str | None {
    try {
        return install_plan.read_text(path, encoding="utf-8");
    } except (OSError, UnicodeError) as exc {
        `report.errors.append(f"{path}: read failed ({exc})");
        return None;
    }
}

impl _write_text(path: Path, text: str, `report: UninstallReport, *, detail: str, dry_run: bool) {
    if dry_run {
        _record_edit(`report, path, detail, True);
        return;
    }
    if install_plan.active() is not None {
        install_plan.write_bytes(path, text.encode("utf-8"));
        _record_edit(`report, path, detail, False);
        return;
    }
    temporary: Path | None = None;
    try {
        mode: any = stat.S_IMODE(path.stat().st_mode);
        handle: any;
        with tempfile.NamedTemporaryFile(
            mode="w",
            encoding="utf-8",
            newline="",
            dir=path.parent,
            prefix=f".{path.name}.",
            suffix=".tmp",
            delete=False,
        ) as handle {
            temporary = Path(handle.name);
            handle.write(text);
            handle.flush();
            os.fsync(handle.fileno());
        }
        temporary.chmod(mode);
        os.replace(temporary, path);
        temporary = None;
    } except (OSError, UnicodeError) as exc {
        `report.errors.append(f"{path}: write failed ({exc})");
        return;
    } finally {
        if temporary is not None {
            try {
                temporary.unlink(missing_ok=True);
            } except OSError as exc {
                `report.errors.append(f"{temporary}: temporary cleanup failed ({exc})");
            }
        }
    }
    _record_edit(`report, path, detail, False);
}

impl _parse_jsonc(path: Path, raw: str, `report: UninstallReport) -> dict[str, Any] | None {
    try {
        parsed: any = json.loads(skills._strip_jsonc(raw));
    } except (json.JSONDecodeError, RecursionError, ValueError) as exc {
        `report.skipped_paths.append(f"{path} (parse failed; left unchanged: {exc})");
        return None;
    }
    if not isinstance(parsed, `dict) {
        `report.skipped_paths.append(
            f"{path} (top level is {`type(parsed).__name__}, not an object; left unchanged)"
        );
        return None;
    }
    return parsed;
}

impl _remove_mcp_entry(
    path: Path,
    *,
    key: str,
    format_name: str,
    boundary: Path,
    `report: UninstallReport,
    dry_run: bool,
) {
    if not path.exists() {
        return;
    }
    if not _safe_path(path, boundary, `report) {
        return;
    }
    raw: any = _read_text(path, `report);
    if raw is None {
        return;
    }
    data: any = _parse_jsonc(path, raw, `report);
    if data is None or key not in data {
        return;
    }

    expected_type: any = list[any] if format_name == "array" else dict[any, any];
    container: any = data[key];
    if not isinstance(container, expected_type) {
        expected: any = "array" if expected_type is list[any] else "object";
        `report.skipped_paths.append(
            f"{path} ({key!r} is {`type(container).__name__}, not {expected}; left unchanged)"
        );
        return;
    }

    if format_name == "array" {
        indices: any = [
            index
            for (index, `entry) in enumerate(container)
            if isinstance(`entry, `dict) and `entry.get("name") == _ENTRY_NAME
        ];
        paths: list[tuple[str | int, ...]] = [(key, index) for index in indices];
        expected_data: any = copy.deepcopy(data);
        expected_data[key] = [
            `entry
            for `entry in container
            if not (isinstance(`entry, `dict) and `entry.get("name") == _ENTRY_NAME)
        ];
    } else {
        if _ENTRY_NAME not in container {
            return;
        }
        paths = [(key, _ENTRY_NAME)];
        expected_data = copy.deepcopy(data);
        del expected_data[key][_ENTRY_NAME];
    }
    if not paths {
        return;
    }

    try {
        rewritten: any = _remove_jsonc_paths(raw, paths);
        reparsed: any = json.loads(skills._strip_jsonc(rewritten));
    } except (IndexError, KeyError, RecursionError, ValueError, json.JSONDecodeError) as exc {
        `report.skipped_paths.append(f"{path} (safe JSONC edit failed; left unchanged: {exc})");
        return;
    }
    if reparsed != expected_data {
        `report.skipped_paths.append(f"{path} (safe JSONC edit did not validate; left unchanged)");
        return;
    }
    _write_or_drop(
        path,
        rewritten,
        boundary,
        `report,
        detail=f"remove {_ENTRY_NAME!r} from {key!r}",
        dry_run=dry_run,
    );
}

impl _remove_toml_entry(
    path: Path, key: str, boundary: Path, `report: UninstallReport, *, dry_run: bool
) {
    if not path.exists() or not _safe_path(path, boundary, `report) {
        return;
    }
    raw: any = _read_text(path, `report);
    if raw is None {
        return;
    }
    try {
        _tomllib.loads(raw);
    } except _tomllib.TOMLDecodeError as exc {
        `report.skipped_paths.append(f"{path} (TOML parse failed; left unchanged: {exc})");
        return;
    }
    lines: any = raw.splitlines(keepends=True);
    span: any = skills._toml_table_span(lines, (key, _ENTRY_NAME));
    if span is None {
        return;
    }
    start: any;
    end: any;
    (start, end) = span as any;
    while end < len(lines) and not lines[end].strip() {
        end += 1;
    }
    rewritten: any = "".join(lines[:start] + lines[end:]);
    try {
        _tomllib.loads(rewritten);
    } except _tomllib.TOMLDecodeError as exc {
        `report.skipped_paths.append(f"{path} (safe TOML edit failed; left unchanged: {exc})");
        return;
    }
    _write_text(path, rewritten, `report, detail=f"remove [{key}.{_ENTRY_NAME}]", dry_run=dry_run);
}

impl _remove_dsh_patch_entry(
    path: Path, boundary: Path, `report: UninstallReport, *, dry_run: bool
) {
    dsh: any = lazy("dsh");

    if not path.exists() or not _safe_path(path, boundary, `report) {
        return;
    }
    raw: any = _read_text(path, `report);
    if raw is None {
        return;
    }
    try {
        document: any;
        found: any;
        (document, found) = dsh.find_owned(raw) as any;
        if not found {
            return;
        }
        op_index: any = dsh.removable(document, found);
        if op_index is None {
            `report.skipped_paths.append(
                f"{path} (the {_ENTRY_NAME} row shares an insert with other rows; left unchanged, remove it by hand)",
            );
            return;
        }
        rewritten: any = dsh.without_row(raw, op_index);
    } except dsh.PatchError as exc {
        `report.skipped_paths.append(f"{path} ({exc}; left unchanged)");
        return;
    }
    _write_text(
        path, rewritten, `report, detail=f"remove the {dsh.ENTRY_ID} insert", dry_run=dry_run
    );
}

impl _remove_yaml_entry(
    path: Path, key: str, boundary: Path, `report: UninstallReport, *, dry_run: bool
) {
    import yaml;

    if not path.exists() or not _safe_path(path, boundary, `report) {
        return;
    }
    raw: any = _read_text(path, `report);
    if raw is None {
        return;
    }
    try {
        parsed: any = yaml.safe_load(raw);
    } except yaml.YAMLError as exc {
        `report.skipped_paths.append(f"{path} (YAML parse failed; left unchanged: {exc})");
        return;
    }
    if not isinstance(parsed, `dict) {
        return;
    }
    container: any = parsed.get(key);
    if not isinstance(container, `dict) or _ENTRY_NAME not in container {
        return;
    }

    lines: any = raw.splitlines(keepends=True);
    bounds: any = skills._yaml_section_bounds(lines, key);
    if bounds is None {
        `report.skipped_paths.append(f"{path} ({key} is not a block mapping; left unchanged)");
        return;
    }
    header: any;
    section_end: any;
    (header, section_end) = bounds as any;
    child_indent: any = skills._yaml_block_indent(lines, header + 1, section_end);
    entry_prefix: any = f"{" " * child_indent}{_ENTRY_NAME}:";
    start: any = next(
        (index
        for index in range(header + 1, section_end)
        if lines[index].rstrip("\n") == entry_prefix.rstrip()
            or lines[index].startswith(entry_prefix)),
        None,
    );
    if start is None {
        `report.skipped_paths.append(
            f"{path} (could not locate {_ENTRY_NAME} block; left unchanged)"
        );
        return;
    }
    end: any = start + 1;
    while end < len(lines) {
        line: any = lines[end];
        if line.strip() and len(line) - len(line.lstrip()) <= child_indent {
            break;
        }
        end += 1;
    }
    while end > start + 1 and not lines[end - 1].strip() {
        end -= 1;
    }

    rewritten: any = "".join(lines[:start] + lines[end:]);
    try {
        reparsed: any = yaml.safe_load(rewritten);
    } except yaml.YAMLError as exc {
        `report.skipped_paths.append(f"{path} (safe YAML edit failed; left unchanged: {exc})");
        return;
    }
    if not isinstance(reparsed, `dict) {
        `report.skipped_paths.append(f"{path} (safe YAML edit failed; left unchanged)");
        return;
    }
    remaining: any = reparsed.get(key);
    if _ENTRY_NAME in (remaining or {}) {
        `report.skipped_paths.append(f"{path} (safe YAML edit failed; left unchanged)");
        return;
    }
    expected: any = copy.deepcopy(parsed);
    del expected[key][_ENTRY_NAME];
    if not expected[key] {
        expected[key] = None;
    }
    if reparsed != expected {
        `report.skipped_paths.append(
            f"{path} (safe YAML edit changed unrelated settings; left unchanged)"
        );
        return;
    }
    _write_text(path, rewritten, `report, detail=f"remove {key}.{_ENTRY_NAME}", dry_run=dry_run);
}

impl _commands(value: Any) -> set[str] {
    found: set[str] = set[any]();
    if isinstance(value, `dict) {
        command: any = value.get("command");
        if isinstance(command, `str) {
            found.add(command);
        }
        child: any;
        for child in value.values() {
            found.update(_commands(child));
        }
    } elif isinstance(value, `list) {
        for child in value {
            found.update(_commands(child));
        }
    }
    return found;
}

impl _legacy_repo_hook_commands(repo_root: Path) -> set[str] {
    repo_arg: any = json.dumps(repo_root.resolve().as_posix());
    pinned: any = {
        f"git rev-parse --git-dir >/dev/null 2>&1 && code-review-graph update --skip-flows --repo {repo_arg} || true",
        f"git rev-parse --git-dir >/dev/null 2>&1 && code-review-graph status --repo {repo_arg} || echo 'Not a git repo, skipping'",
    };
    drained: any = {"cat >/dev/null || true; " + command for command in pinned};
    path_copy: any = _commands(
        skills.generate_hooks_config(repo_root, program=skills._PATH_HOOK_PROGRAM)
    );
    path_copy.add(
        skills._claude_session_hook_command(
            skills._PATH_HOOK_PROGRAM, skills._legacy_session_status_body
        ),
    );
    from_cwd: any = "cat >/dev/null || true; command -v code-review-graph >/dev/null 2>&1 || exit 0; git rev-parse --git-dir >/dev/null 2>&1 && code-review-graph update --skip-flows --repo \"$(git rev-parse --show-toplevel 2>/dev/null)\" || true";
    return pinned | drained | {from_cwd} | path_copy;
}

impl _legacy_codex_hook_commands -> set[str] {
    update: any = "git rev-parse --git-dir >/dev/null 2>&1 && code-review-graph update --skip-flows || true";
    status: any = "git rev-parse --git-dir >/dev/null 2>&1 && code-review-graph status || echo 'Not a git repo, skipping'";
    stdin_guard: any = "cat >/dev/null || true; ";
    path_copy: any = _commands(
        skills.generate_codex_hooks_config(Path("."), program=skills._PATH_HOOK_PROGRAM)
    );
    path_copy.add(skills._codex_hook_command("hook-update", skills._PATH_HOOK_PROGRAM));
    return {update, status, stdin_guard + update, stdin_guard + status} | path_copy;
}

impl _steering_hook_scopes -> dict[str, tuple[str, Any]] {
    scopes: dict[str, tuple[str, Any]] = {};
    for program in (None, skills._PATH_HOOK_PROGRAM) {
        config: any = skills.generate_steering_hooks_config(program);
        for (event, groups) in config["hooks"].items() {
            for group in groups {
                for hook in group["hooks"] {
                    scopes[hook["command"]] = (event, group.get("matcher"));
                }
            }
        }
    }
    return scopes;
}

impl _steering_hook_scope -> tuple[str, Any] {
    return next(iter(_steering_hook_scopes().values()));
}

impl _clean_hook_data(
    data: dict[str, Any],
    owned_commands: set[str],
    scoped_commands: dict[str, tuple[str, Any]] | None = None,
    *,
    owns: Callable[[str], bool] | None = None,
    scoped_owns: tuple[Callable[[str], bool], tuple[str, Any]] | None = None,
) -> tuple[dict[str, Any], list[tuple[str | int, ...]]] {
    scoped: any = scoped_commands or {};

    def owned(command: Any, event: str, matcher: Any) -> bool {
        if not isinstance(command, `str) {
            return False;
        }
        if command in owned_commands or owns is not None and owns(command) {
            return True;
        }
        scope: any = scoped.get(command);
        if scope is None and scoped_owns is not None and scoped_owns[0](command) {
            scope = scoped_owns[1];
        }
        return operator.eq(scope, (event, matcher));
    }

    expected: any = copy.deepcopy(data);
    hooks_obj: any = data.get("hooks");
    if not isinstance(hooks_obj, `dict) {
        return (expected, []);
    }

    paths: list[tuple[str | int, ...]] = [];
    expected_hooks: any = expected["hooks"];
    for (event, entries) in hooks_obj.items() {
        if not isinstance(entries, `list) {
            continue;
        }
        new_entries: list[Any] = [];
        entry_paths: list[tuple[str | int, ...]] = [];
        for (entry_index, `entry) in enumerate(entries) {
            if not isinstance(`entry, `dict) {
                new_entries.append(copy.deepcopy(`entry));
                continue;
            }
            if owned(`entry.get("command"), event, `entry.get("matcher")) {
                entry_paths.append(("hooks", event, entry_index));
                continue;
            }

            nested: any = `entry.get("hooks");
            if not isinstance(nested, `list) {
                new_entries.append(copy.deepcopy(`entry));
                continue;
            }
            kept_nested: list[Any] = [];
            nested_paths: list[tuple[str | int, ...]] = [];
            for (nested_index, hook) in enumerate(nested) {
                command: any = hook.get("command") if isinstance(hook, `dict) else None;
                if owned(command, event, `entry.get("matcher")) {
                    nested_paths.append(("hooks", event, entry_index, "hooks", nested_index));
                } else {
                    kept_nested.append(copy.deepcopy(hook));
                }
            }
            if not kept_nested and nested_paths {
                entry_paths.append(("hooks", event, entry_index));
                continue;
            }
            new_entry: any = copy.deepcopy(`entry);
            if nested_paths {
                new_entry["hooks"] = kept_nested;
                entry_paths.extend(nested_paths);
            }
            new_entries.append(new_entry);
        }

        if not new_entries and entry_paths {
            expected_hooks.pop(event, None);
            paths.append(("hooks", event));
        } elif entry_paths {
            expected_hooks[event] = new_entries;
            paths.extend(entry_paths);
        }
    }

    if paths and not expected_hooks {
        expected.pop("hooks", None);
        paths = [("hooks",)];
    }
    return (expected, paths);
}

impl remove_steering_hook(repo_root: Path, *, dry_run: bool = False) -> UninstallReport {
    `report: any = UninstallReport();
    _remove_hooks(
        repo_root / ".claude" / "settings.json",
        set[any](),
        repo_root,
        `report,
        dry_run=dry_run,
        scoped_commands=_steering_hook_scopes(),
        scoped_owns=(skills._is_steering_hook_command, _steering_hook_scope()),
        backup=False,
    );
    return `report;
}

impl _without_our_servers(data: dict[str, Any]) -> dict[str, Any] {
    spec: any;
    keys: any = {`str(spec["key"]) for spec in skills.PLATFORMS.values()};
    for spec in skills.PLATFORMS.values() {
        keys.update(`str(item) for item in spec.get("legacy_keys", ()));
    }
    cleaned: any = `dict(data);
    for key in keys & `set(cleaned) {
        container: any = cleaned[key];
        if isinstance(container, `dict) {
            cleaned[key] = {k: v for (k, v) in container.items() if k != _ENTRY_NAME};
        } elif isinstance(container, `list) {
            cleaned[key] = [
                `entry
                for `entry in container
                if not (isinstance(`entry, `dict) and `entry.get("name") == _ENTRY_NAME)
            ];
        }
    }
    return cleaned;
}

impl _remove_backup_of_ours(
    path: Path,
    owned_commands: set[str],
    boundary: Path,
    `report: UninstallReport,
    *,
    dry_run: bool,
    scoped_commands: dict[str, tuple[str, Any]] | None,
    owns: Callable[[str], bool] | None,
    scoped_owns: tuple[Callable[[str], bool], tuple[str, Any]] | None,
) {
    backup: any = path.with_name(f"{path.name}.bak");
    if not install_plan.exists(backup)
        or not _safe_path(backup, boundary, `report, describe_skip=False)
    {
        return;
    }
    raw: any = _read_text(backup, `report);
    if raw is None {
        return;
    }
    try {
        data: any = json.loads(skills._strip_jsonc(raw));
    } except (json.JSONDecodeError, RecursionError, ValueError) {
        return;
    }
    if not isinstance(data, `dict) or _holds_nothing(data) {
        return;
    }
    cleaned: any;
    _paths: any;
    (cleaned, _paths) = _clean_hook_data(
        data, owned_commands, scoped_commands, owns=owns, scoped_owns=scoped_owns
    ) as any;
    if _holds_nothing(_without_our_servers(cleaned)) {
        _remove_file(
            backup,
            boundary,
            `report,
            dry_run=dry_run,
            detail="remove backup holding only code-review-graph settings",
        );
    }
}

impl _remove_hooks(
    path: Path,
    owned_commands: set[str],
    boundary: Path,
    `report: UninstallReport,
    *,
    dry_run: bool,
    scoped_commands: dict[str, tuple[str, Any]] | None = None,
    owns: Callable[[str], bool] | None = None,
    scoped_owns: tuple[Callable[[str], bool], tuple[str, Any]] | None = None,
    backup: bool = True,
) {
    if backup {
        _remove_backup_of_ours(
            path,
            owned_commands,
            boundary,
            `report,
            dry_run=dry_run,
            scoped_commands=scoped_commands,
            owns=owns,
            scoped_owns=scoped_owns,
        );
    }
    if not install_plan.exists(path) or not _safe_path(path, boundary, `report) {
        return;
    }
    raw: any = _read_text(path, `report);
    if raw is None {
        return;
    }
    data: any = _parse_jsonc(path, raw, `report);
    if data is None {
        return;
    }
    expected: any;
    paths: any;
    (expected, paths) = _clean_hook_data(
        data, owned_commands, scoped_commands, owns=owns, scoped_owns=scoped_owns
    ) as any;
    if not paths {
        return;
    }
    try {
        rewritten: any = _remove_jsonc_paths(raw, paths);
        reparsed: any = json.loads(skills._strip_jsonc(rewritten));
    } except (IndexError, KeyError, RecursionError, ValueError, json.JSONDecodeError) as exc {
        `report.skipped_paths.append(f"{path} (safe hook edit failed; left unchanged: {exc})");
        return;
    }
    if reparsed != expected {
        `report.skipped_paths.append(f"{path} (safe hook edit did not validate; left unchanged)");
        return;
    }
    _write_or_drop(
        path,
        rewritten,
        boundary,
        `report,
        detail="remove code-review-graph hook entries",
        dry_run=dry_run,
    );
}

impl _holds_nothing(value: Any) -> bool {
    if isinstance(value, `dict) {
        return all(_holds_nothing(item) for item in value.values());
    }
    if isinstance(value, `list) {
        return all(_holds_nothing(item) for item in value);
    }
    return False;
}

impl _write_or_drop(
    path: Path, text: str, boundary: Path, `report: UninstallReport, *, detail: str, dry_run: bool
) {
    if os.path.abspath(path) in `report.install_only {
        try {
            empty: any = _holds_nothing(json.loads(text));
        } except (ValueError, RecursionError) {
            empty = False;
        }
        if empty {
            _remove_file(
                path,
                boundary,
                `report,
                dry_run=dry_run,
                detail="remove file install wrote, as nothing else was in it",
            );
            return;
        }
    }
    _write_text(path, text, `report, detail=detail, dry_run=dry_run);
}

impl _install_only_files(repo_root: Path) -> list[str] {
    listed: any = install_manifest.read(repo_root);
    if not listed {
        return [];
    }
    try {
        result: any = subprocess.run(
            ["git", "--literal-pathspecs", "ls-files", "-z", "--", *listed],
            capture_output=True,
            cwd=`str(repo_root),
            timeout=30,
            stdin=subprocess.DEVNULL,
        );
    } except (OSError, subprocess.SubprocessError) {
        return [];
    }
    if result.returncode != 0 {
        return [];
    }
    tracked: any = {os.fsdecode(path) for path in result.stdout.split(b"\x00") if path};
    return [path for path in listed if path not in tracked];
}

impl _prune_install_folders(repo_root: Path, relative_files: Sequence[str]) {
    folders: set[Path] = set[any]();
    for relative in relative_files {
        parent: any = (repo_root / relative).parent;
        while parent != repo_root and _is_lexical_child(parent, repo_root) {
            folders.add(parent);
            parent = parent.parent;
        }
    }
    for folder in sorted(folders, key=lambda (item) -> any { len(item.parts) }, reverse=True) {
        _prune_empty_directory(folder, repo_root);
    }
}

impl _remove_file(
    path: Path,
    boundary: Path,
    `report: UninstallReport,
    *,
    dry_run: bool,
    detail: str = "remove owned file",
) {
    if not path.exists() and not path.is_symlink() {
        return;
    }
    if not _safe_path(path, boundary, `report) {
        return;
    }
    if dry_run {
        _record_remove(`report, path, detail, True);
        return;
    }
    try {
        path.unlink();
    } except OSError as exc {
        `report.errors.append(f"{path}: remove failed ({exc})");
        return;
    }
    _record_remove(`report, path, detail, False);
}

impl _remove_tree(path: Path, boundary: Path, `report: UninstallReport, *, dry_run: bool) {
    if not path.exists() and not path.is_symlink() {
        return;
    }
    if not _safe_path(path, boundary, `report) {
        return;
    }
    if not path.is_dir() {
        `report.skipped_paths.append(f"{path} (expected an owned directory; left unchanged)");
        return;
    }
    if dry_run {
        _record_remove(`report, path, "remove owned directory", True);
        return;
    }
    try {
        shutil.rmtree(path);
    } except OSError as exc {
        `report.errors.append(f"{path}: remove failed ({exc})");
        return;
    }
    _record_remove(`report, path, "remove owned directory", False);
}

impl _prune_empty_directory(path: Path, boundary: Path) {
    if not path.is_dir() or path.is_symlink() or not _is_lexical_child(path, boundary) {
        return;
    }
    try {
        path.rmdir();
    } except OSError {
        return;
    }
}

impl _remove_skill_file(path: Path, boundary: Path, `report: UninstallReport, *, dry_run: bool) {
    existed: any = path.exists();
    _remove_file(path, boundary, `report, dry_run=dry_run, detail="remove generated skill");
    if existed and not dry_run and not path.exists() {
        _prune_empty_directory(path.parent, boundary);
    }
}

impl _join_without_instruction(before: str, after: str) -> str {
    if not after.strip() {
        return before.rstrip() + ("\n" if before.strip() else "");
    }
    if not before.strip() {
        return after.lstrip("\n");
    }
    return before.rstrip("\n") + "\n\n" + after.lstrip("\n");
}

impl _remove_instruction(path: Path, boundary: Path, `report: UninstallReport, *, dry_run: bool) {
    if not path.exists() or not _safe_path(path, boundary, `report) {
        return;
    }
    raw: any = _read_text(path, `report);
    if raw is None {
        return;
    }

    rewritten: any = raw;
    for known in skills._known_instruction_sections() {
        while (index := rewritten.find(known)) >= 0 {
            rewritten = _join_without_instruction(
                rewritten[:index], rewritten[index + len(known):]
            );
        }
    }

    if rewritten == raw {
        if skills._CLAUDE_MD_SECTION_MARKER in raw {
            `report.skipped_paths.append(
                f"{path} (marked instruction section differs from a known installed section; left unchanged)",
            );
        }
        return;
    }

    if skills._CLAUDE_MD_SECTION_MARKER in rewritten {
        `report.skipped_paths.append(
            f"{path} (a further marked instruction section differs from a known installed section; left unchanged)",
        );
    }

    if rewritten {
        _write_text(
            path,
            rewritten,
            `report,
            detail="remove code-review-graph instruction section",
            dry_run=dry_run,
        );
    } else {
        _remove_file(
            path, boundary, `report, dry_run=dry_run, detail="remove generated instruction file"
        );
    }
}

impl _resolve_git_hook(repo_root: Path, name: str = "pre-commit") -> Path {
    try {
        result: any = subprocess.run(
            ["git", "rev-parse", "--git-path", "hooks"],
            cwd=`str(repo_root),
            capture_output=True,
            text=True,
            encoding="utf-8",
            timeout=10,
            stdin=subprocess.DEVNULL,
        );
    } except (OSError, subprocess.TimeoutExpired) {
        result = None;
    }
    if result is not None and result.returncode == 0 and result.stdout.strip() {
        return repo_root / result.stdout.strip() / name;
    }
    return repo_root / ".git" / "hooks" / name;
}

impl _strip_git_hook_blocks(raw: str) -> tuple[str, bool] {
    if skills._GIT_HOOK_BEGIN_MARKER in raw and not skills._git_hook_markers_balanced(raw) {
        return (raw, False);
    }
    text: any = raw;
    removed: any = False;
    while (span := skills._git_hook_block_span(text)) is not None {
        begin: any;
        end: any;
        (begin, end) = span as any;
        text = text[:begin] + text[end:];
        removed = True;
    }
    for block in skills._known_git_hook_blocks() {
        while block in text {
            text = text.replace(block, "", 1);
            removed = True;
        }
    }
    return (text, removed);
}

impl _remove_git_hook(repo_root: Path, `report: UninstallReport, *, dry_run: bool) {
    path: any = _resolve_git_hook(repo_root);
    if not path.exists() or not _safe_path(path, repo_root, `report) {
        return;
    }
    raw: any = _read_text(path, `report);
    if raw is None {
        return;
    }
    if _GIT_HOOK_MARKER not in raw and skills._GIT_HOOK_BEGIN_MARKER not in raw {
        return;
    }
    if skills._GIT_HOOK_BEGIN_MARKER in raw and not skills._git_hook_markers_balanced(raw) {
        `report.skipped_paths.append(
            f"{path} (a code-review-graph begin marker has no matching end marker; left unchanged)"
        );
        return;
    }

    new_text: any;
    removed: any;
    (new_text, removed) = _strip_git_hook_blocks(raw) as any;
    if not removed {
        `report.skipped_paths.append(
            f"{path} (marked pre-commit block differs from a known installed block; left unchanged)"
        );
        return;
    }
    detail: any = "remove code-review-graph hook block";
    if _GIT_HOOK_MARKER in new_text or skills._GIT_HOOK_BEGIN_MARKER in new_text {
        detail = "remove code-review-graph hook block (a further block, edited by hand, stays)";
    }

    _rewrite_or_remove_hook(path, new_text, repo_root, `report, detail=detail, dry_run=dry_run);
}

impl _rewrite_or_remove_hook(
    path: Path,
    new_text: str,
    repo_root: Path,
    `report: UninstallReport,
    *,
    detail: str,
    dry_run: bool,
) {
    meaningful: any = [
        line
        for line in new_text.splitlines()
        if line.strip() and not line.strip().startswith("#!")
    ];
    if meaningful {
        _write_text(path, new_text.rstrip("\n") + "\n", `report, detail=detail, dry_run=dry_run);
    } else {
        _remove_file(
            path,
            repo_root,
            `report,
            dry_run=dry_run,
            detail="remove hook containing only code-review-graph",
        );
    }
}

impl _remove_git_sync_hooks(repo_root: Path, `report: UninstallReport, *, dry_run: bool) {
    begin_marker: any = skills._GIT_SYNC_HOOK_BEGIN_MARKER;
    end_marker: any = skills._GIT_SYNC_HOOK_END_MARKER;
    for name in skills._GIT_SYNC_HOOK_NAMES {
        path: any = _resolve_git_hook(repo_root, name);
        if not path.exists() or not _safe_path(path, repo_root, `report) {
            continue;
        }
        raw: any = _read_text(path, `report);
        if raw is None or begin_marker not in raw {
            continue;
        }
        if not skills._git_hook_markers_balanced(raw, begin_marker, end_marker) {
            `report.skipped_paths.append(
                f"{path} (a code-review-graph begin marker has no matching end marker; left unchanged)",
            );
            continue;
        }
        text: any = raw;
        while span := skills._git_hook_block_span(text, 0, begin_marker, end_marker) {
            begin: any;
            end: any;
            (begin, end) = span as any;
            text = text[:begin] + text[end:];
        }
        _rewrite_or_remove_hook(
            path,
            text,
            repo_root,
            `report,
            detail="remove code-review-graph hook block",
            dry_run=dry_run,
        );
    }
}

impl _remove_gitignore(repo_root: Path, `report: UninstallReport, *, dry_run: bool) {
    path: any = repo_root / ".gitignore";
    if not path.exists() or not _safe_path(path, repo_root, `report) {
        return;
    }
    try {
        raw: any = path.read_bytes().decode("utf-8");
    } except (OSError, UnicodeError) as exc {
        `report.errors.append(f"{path}: read failed ({exc})");
        return;
    }
    without_block: any;
    block_state: any;
    (without_block, block_state) = install_gitignore.remove_block(raw) as any;
    if block_state == "edited" {
        `report.skipped_paths.append(
            f"{path} (code-review-graph install files block was edited by hand; left unchanged)"
        );
    }
    lines: any = without_block.splitlines(keepends=True);
    rewritten: list[str] = [];
    changed: any = operator.eq(block_state, "removed");
    index: any = 0;
    while index < len(lines) {
        if lines[index].strip() == _GITIGNORE_BANNER
            and index + 1 < len(lines)
            and lines[index + 1].strip() in {".code-review-graph", ".code-review-graph/"}
        {
            changed = True;
            index += 2;
            continue;
        }
        rewritten.append(lines[index]);
        index += 1;
    }
    if not changed {
        return;
    }
    new_text: any = "".join(rewritten);
    if new_text.strip() {
        _write_text(
            path, new_text, `report, detail="remove installer-owned ignore block", dry_run=dry_run
        );
    } else {
        _remove_file(
            path, repo_root, `report, dry_run=dry_run, detail="remove generated .gitignore"
        );
    }
}

impl _scope_for_config(
    path: Path, repo_root: Path, home: Path, extra_user_boundaries: Sequence[Path] = ()
) -> tuple[str, Path] | None {
    if _is_lexical_child(path, repo_root) {
        return ("repo", repo_root);
    }
    if _is_lexical_child(path, home) {
        return ("user", home);
    }
    hermes_home: any = _absolute(skills._hermes_home());
    if _is_lexical_child(path, hermes_home) {
        return ("user", hermes_home);
    }
    dsh_home: any = _absolute(skills._dsh_home());
    if _is_lexical_child(path, dsh_home) {
        return ("user", dsh_home);
    }
    for boundary in extra_user_boundaries {
        if _is_lexical_child(path, boundary) {
            return ("user", boundary);
        }
    }
    return None;
}

impl _process_platform_configs(
    repo_root: Path,
    home: Path,
    `report: UninstallReport,
    *,
    scope: str,
    dry_run: bool,
    platforms: frozenset[str] | None = None,
) {
    seen: set[tuple[Path, str, str]] = set[any]();
    active_codex_home: Path | None = None;
    if platforms is None or "codex" in platforms {
        codex_home = lazy("codex_skill", "codex_home");

        active_codex_home = codex_home();
    } else {
        active_codex_home = None;
    }
    for (platform_name, spec) in skills.PLATFORMS.items() {
        if platforms is not None and platform_name not in platforms {
            continue;
        }
        try {
            all_paths: any = spec.get("config_paths");
            candidates: any = all_paths(repo_root)
                if all_paths
                else (spec["config_path"](repo_root),);
            paths: any = `list(dict.fromkeys(_absolute(candidate) for candidate in candidates));
            key: any = `str(spec["key"]);
            format_name: any = `str(spec["format"]);
        } except (KeyError, OSError, TypeError, ValueError) as exc {
            `report.skipped_paths.append(
                f"{platform_name} config (invalid platform specification: {exc})"
            );
            continue;
        }
        for path in paths {
            destination: any = _scope_for_config(
                path,
                repo_root,
                home,
                (active_codex_home,) if platform_name == "codex" and active_codex_home else (),
            );
            if destination is None {
                if path.exists() {
                    `report.skipped_paths.append(
                        f"{path} ({platform_name} config is outside home/repo boundary)"
                    );
                }
                continue;
            }
            config_scope: any;
            boundary: any;
            (config_scope, boundary) = destination as any;
            if config_scope != scope {
                continue;
            }
            legacy_keys: any = `tuple(`str(item) for item in spec.get("legacy_keys", ()));
            for entry_key in (key, *legacy_keys) {
                identity: any = (path, entry_key, format_name);
                if identity in seen {
                    continue;
                }
                seen.add(identity);
                if format_name == "toml" {
                    _remove_toml_entry(path, entry_key, boundary, `report, dry_run=dry_run);
                } elif format_name == "yaml" {
                    _remove_yaml_entry(path, entry_key, boundary, `report, dry_run=dry_run);
                } elif format_name == "dsh-patch" {
                    _remove_dsh_patch_entry(path, boundary, `report, dry_run=dry_run);
                } elif format_name in {"object", "array"} {
                    _remove_mcp_entry(
                        path,
                        key=entry_key,
                        format_name=format_name,
                        boundary=boundary,
                        report=`report,
                        dry_run=dry_run,
                    );
                } else {
                    `report.skipped_paths.append(
                        f"{path} ({platform_name} has unsupported config format {format_name!r})"
                    );
                }
            }
        }
    }
}

impl _generated_skill_slugs -> list[str] {
    return [filename.rsplit(".", 1)[0] for filename in skills._SKILLS];
}

impl _qoder_skill_names(repo_root: Path, `report: UninstallReport) -> list[str] {
    names: list[str] = `list(skills.bundled_skill_names());
    source_skills: any = repo_root / "skills";
    if source_skills.is_dir() and not source_skills.is_symlink() {
        try {
            candidates: any = `list(source_skills.iterdir());
        } except OSError as exc {
            `report.errors.append(f"{source_skills}: list failed ({exc})");
        } else {
            for candidate in candidates {
                if candidate.is_dir() and (candidate / "SKILL.md").is_file() {
                    names.append(candidate.name);
                }
            }
        }
    }
    return `list(dict.fromkeys(names));
}

impl _remove_legacy_mcp_configs(
    repo_root: Path, home: Path, `report: UninstallReport, *, scope: str, dry_run: bool
) {
    artifacts: any = {
        "repo": (repo_root / ".opencode.json", repo_root),
        "user": (home / ".cursor" / "mcp.json", home),
    };
    path: any;
    boundary: any;
    (path, boundary) = artifacts[scope] as any;
    _remove_mcp_entry(
        path,
        key="mcpServers",
        format_name="object",
        boundary=boundary,
        report=`report,
        dry_run=dry_run,
    );
}

impl _process_repo(
    repo_root: Path,
    home: Path,
    `report: UninstallReport,
    *,
    keep_data: bool,
    dry_run: bool,
    platforms: frozenset[str] | None = None,
) {
    install_only: any = _install_only_files(repo_root);
    `report.install_only = frozenset(
        os.path.abspath(repo_root / relative) for relative in install_only
    );
    try {
        _process_repo_files(
            repo_root, home, `report, keep_data=keep_data, dry_run=dry_run, platforms=platforms
        );
    } finally {
        `report.install_only = frozenset();
        if not dry_run {
            install_manifest.forget(repo_root, `report.touched);
            _prune_install_folders(repo_root, install_only);
        }
    }
}

impl _process_repo_files(
    repo_root: Path,
    home: Path,
    `report: UninstallReport,
    *,
    keep_data: bool,
    dry_run: bool,
    platforms: frozenset[str] | None = None,
) {
    name: any;
    _process_platform_configs(
        repo_root, home, `report, scope="repo", dry_run=dry_run, platforms=platforms
    );
    if platforms is not None {
        return;
    }
    _remove_legacy_mcp_configs(repo_root, home, `report, scope="repo", dry_run=dry_run);

    data_paths: any = [
        (repo_root / ".code-review-graph", "tree"),
        (repo_root / ".code-review-graph.db", "file"),
        (repo_root / ".code-review-graph.db-wal", "file"),
        (repo_root / ".code-review-graph.db-shm", "file"),
    ];
    for (path, kind) in data_paths {
        if keep_data {
            if path.exists() or path.is_symlink() {
                `report.skipped_paths.append(f"{path} (kept by --keep-data)");
            }
            continue;
        }
        if kind == "tree" {
            _remove_tree(path, repo_root, `report, dry_run=dry_run);
        } else {
            _remove_file(path, repo_root, `report, dry_run=dry_run);
        }
    }

    hook_commands: any = _commands(skills.generate_hooks_config(repo_root));
    hook_commands.update(_legacy_repo_hook_commands(repo_root));
    pinned: any = skills._is_pinned_project_hook_command;
    _remove_hooks(
        repo_root / ".claude" / "settings.json",
        hook_commands,
        repo_root,
        `report,
        dry_run=dry_run,
        scoped_commands=_steering_hook_scopes(),
        owns=pinned,
        scoped_owns=(skills._is_steering_hook_command, _steering_hook_scope()),
    );
    _remove_hooks(
        repo_root / ".qoder" / "settings.json",
        hook_commands,
        repo_root,
        `report,
        dry_run=dry_run,
        owns=pinned,
    );
    _remove_hooks(
        repo_root / ".codebuddy" / "settings.json",
        hook_commands,
        repo_root,
        `report,
        dry_run=dry_run,
        owns=pinned,
    );

    gemini_script_names: any = skills._GEMINI_CLI_HOOK_FILENAMES;
    gemini_commands: any = {f"bash .gemini/hooks/{name}" for name in gemini_script_names};
    _remove_hooks(
        repo_root / ".gemini" / "settings.json",
        gemini_commands,
        repo_root,
        `report,
        dry_run=dry_run,
    );
    for name in gemini_script_names {
        _remove_file(repo_root / ".gemini" / "hooks" / name, repo_root, `report, dry_run=dry_run);
    }

    for root_name in (".claude", ".gemini", ".codebuddy") {
        for slug in _generated_skill_slugs() {
            _remove_skill_file(
                repo_root / root_name / "skills" / slug / "SKILL.md",
                repo_root,
                `report,
                dry_run=dry_run,
            );
        }
    }
    for name in _qoder_skill_names(repo_root, `report) {
        _remove_skill_file(
            repo_root / ".qoder" / "skills" / name / "SKILL.md", repo_root, `report, dry_run=dry_run
        );
    }
    instruction_files: any = dict.fromkeys((
        "CLAUDE.md",
        *skills._PLATFORM_INSTRUCTION_FILES,
        *skills._LEGACY_PLATFORM_INSTRUCTION_FILES,
    ));
    for relative in instruction_files {
        _remove_instruction(repo_root / relative, repo_root, `report, dry_run=dry_run);
    }

    _remove_git_hook(repo_root, `report, dry_run=dry_run);
    _remove_git_sync_hooks(repo_root, `report, dry_run=dry_run);
    _remove_gitignore(repo_root, `report, dry_run=dry_run);
}

impl _process_user(
    reference_repo: Path,
    home: Path,
    `report: UninstallReport,
    *,
    keep_data: bool,
    dry_run: bool,
    platforms: frozenset[str] | None = None,
) {
    _process_platform_configs(
        reference_repo, home, `report, scope="user", dry_run=dry_run, platforms=platforms
    );
    if platforms is not None {
        return;
    }
    _remove_legacy_mcp_configs(reference_repo, home, `report, scope="user", dry_run=dry_run);

    user_data: any = home / ".code-review-graph";
    if keep_data {
        if user_data.exists() or user_data.is_symlink() {
            `report.skipped_paths.append(f"{user_data} (kept by --keep-data)");
        }
    } else {
        _remove_tree(user_data, home, `report, dry_run=dry_run);
    }

    codex_home = lazy("codex_skill", "codex_home");
    codex_skill_dir = lazy("codex_skill", "codex_skill_dir");
    owned_skill_files = lazy("codex_skill", "owned_skill_files");

    active_codex_home: any = codex_home();
    _remove_hooks(
        active_codex_home / "hooks.json",
        _commands(skills.generate_codex_hooks_config(reference_repo))
            | _legacy_codex_hook_commands(),
        active_codex_home,
        `report,
        dry_run=dry_run,
        owns=skills._is_pinned_codex_hook_command,
    );
    skill_dir: any = codex_skill_dir();
    for owned_path in owned_skill_files(skill_dir) {
        _remove_skill_file(owned_path, active_codex_home, `report, dry_run=dry_run);
    }
    if not dry_run {
        try {
            skill_dir.parent.rmdir();
        } except OSError {}
    }
    _remove_hooks(
        home / ".cursor" / "hooks.json",
        _commands(skills.generate_cursor_hooks_config()),
        home,
        `report,
        dry_run=dry_run,
    );
    for filename in skills._cursor_hook_scripts() {
        _remove_file(home / ".cursor" / "hooks" / filename, home, `report, dry_run=dry_run);
    }
    config_home: any = skills._xdg_config_home();
    for (plugin, boundary) in {
        skills._opencode_plugin_path(): config_home,
        home / ".config" / "opencode" / "plugins" / "crg-plugin.ts": home,
    }.items() {
        _remove_file(plugin, boundary, `report, dry_run=dry_run);
    }

    hermes_skills: any = skills._hermes_home() / "skills" / "code-review-graph";
    for slug in _generated_skill_slugs() {
        _remove_skill_file(
            hermes_skills / slug / "SKILL.md", hermes_skills, `report, dry_run=dry_run
        );
    }
}

impl _registry_repo_paths(home: Path, `report: UninstallReport) -> list[Path] {
    path: any = home / ".code-review-graph" / "registry.json";
    if not path.exists() or not _safe_path(path, home, `report) {
        return [];
    }
    raw: any = _read_text(path, `report);
    if raw is None {
        return [];
    }
    try {
        data: any = json.loads(raw);
    } except (json.JSONDecodeError, RecursionError) as exc {
        `report.skipped_paths.append(f"{path} (registry parse failed: {exc})");
        return [];
    }
    repos: any = data.get("repos") if isinstance(data, `dict) else None;
    if not isinstance(repos, `list) {
        `report.skipped_paths.append(f"{path} (registry has no valid repos array)");
        return [];
    }
    paths: list[Path] = [];
    for `entry in repos {
        value: any = `entry.get("path") if isinstance(`entry, `dict) else None;
        if isinstance(value, `str) and value {
            paths.append(Path(value).expanduser());
        }
        data_dir: any = `entry.get("data_dir") if isinstance(`entry, `dict) else None;
        if isinstance(data_dir, `str) and data_dir {
            `report.skipped_paths.append(
                f"{Path(data_dir).expanduser()} (external data directory retained for safety)"
            );
        }
    }
    return paths;
}

impl _normalise_repo(path: Path, home: Path, `report: UninstallReport) -> Path | None {
    lexical: any = _absolute(path);
    try {
        resolved: any = lexical.resolve(strict=False);
    } except (OSError, RuntimeError) as exc {
        `report.skipped_paths.append(f"{lexical} (cannot resolve repository: {exc})");
        return None;
    }
    filesystem_root: any = Path(resolved.anchor);
    if resolved in {filesystem_root, home.resolve(strict=False)} {
        `report.skipped_paths.append(f"{resolved} (refusing unsafe repository boundary)");
        return None;
    }
    if not resolved.is_dir() {
        `report.skipped_paths.append(f"{resolved} (repository directory is missing)");
        return None;
    }

    find_repo_root = lazy("incremental", "find_repo_root");

    repository_root: any = find_repo_root(resolved);
    if repository_root is None {
        `report.skipped_paths.append(f"{resolved} (not inside a Git or SVN repository)");
        return None;
    }
    try {
        repository_root = repository_root.resolve(strict=True);
    } except (OSError, RuntimeError) as exc {
        `report.skipped_paths.append(f"{resolved} (cannot resolve repository root: {exc})");
        return None;
    }
    if repository_root in {Path(repository_root.anchor), home.resolve(strict=False)} {
        `report.skipped_paths.append(f"{repository_root} (refusing unsafe repository boundary)");
        return None;
    }
    return repository_root;
}

impl _normalise_platform_filter(platforms: Sequence[str] | None) -> frozenset[str] | None {
    if not platforms {
        return None;
    }
    selected: set[str] = set[any]();
    for name in platforms {
        key: any = "claude" if name == "claude-code" else name;
        if key == "all" {
            return None;
        }
        selected.add(key);
    }
    return frozenset(selected) or None;
}

impl run(
    *,
    repo: Path | None = None,
    all_repos: bool = False,
    keep_data: bool = False,
    keep_user_configs: bool = False,
    dry_run: bool = False,
    platforms: Sequence[str] | None = None,
) -> UninstallReport {
    `report: any = UninstallReport();
    home: any = _absolute(Path.home());
    platform_filter: any = _normalise_platform_filter(platforms);
    requested: any = [repo if repo is not None else Path.cwd()];
    if all_repos {
        requested.extend(_registry_repo_paths(home, `report));
    }

    roots: list[Path] = [];
    for candidate in requested {
        normalised: any = _normalise_repo(Path(candidate), home, `report);
        if normalised is not None and normalised not in roots {
            roots.append(normalised);
        }
    }

    for `root in roots {
        _process_repo(
            `root, home, `report, keep_data=keep_data, dry_run=dry_run, platforms=platform_filter
        );
    }

    if not keep_user_configs {
        reference: any = roots[0] if roots else home / ".crg-uninstall-repo-sentinel";
        _process_user(
            reference,
            home,
            `report,
            keep_data=keep_data,
            dry_run=dry_run,
            platforms=platform_filter,
        );
    }
    return `report;
}
