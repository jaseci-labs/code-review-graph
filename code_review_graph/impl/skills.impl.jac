impl _zed_settings_path -> Path {
    if platform.system() == "Darwin" {
        return Path.home() / "Library" / "Application Support" / "Zed" / "settings.json";
    }
    return Path.home() / ".config" / "zed" / "settings.json";
}

impl _copilot_vscode_detected -> bool {
    home: any = Path.home();
    extension_dirs: any = [
        home / ".vscode" / "extensions",
        home / ".vscode-insiders" / "extensions",
    ];

    system: any = platform.system();
    if system == "Darwin" {
        for applications_dir in (Path("/Applications"), home / "Applications") {
            app_name: any;
            for app_name in ("Visual Studio Code.app", "Visual Studio Code - Insiders.app") {
                extension_dirs.append(
                    applications_dir / app_name / "Contents" / "Resources" / "app" / "extensions"
                );
            }
        }
    } elif system == "Windows" {
        for env_name in ("LOCALAPPDATA", "PROGRAMFILES", "PROGRAMFILES(X86)") {
            if install_root := os.environ.get(env_name) {
                for app_name in ("Microsoft VS Code", "Microsoft VS Code Insiders") {
                    extension_dirs.append(
                        Path(install_root) / app_name / "resources" / "app" / "extensions"
                    );
                }
            }
        }
    } elif system == "Linux" {
        extension_dirs.extend([
            Path("/usr/share/code/resources/app/extensions"),
            Path("/usr/share/code-insiders/resources/app/extensions"),
            Path("/usr/lib/code/resources/app/extensions"),
            Path("/opt/visual-studio-code/resources/app/extensions"),
            Path("/snap/code/current/usr/share/code/resources/app/extensions"),
        ]);
    }

    for command in ("code", "code-insiders") {
        if executable := shutil.which(command) {
            try {
                parents: any = Path(executable).resolve().parents[:6];
            } except OSError {
                continue;
            }
            for parent in parents {
                extension_dirs.extend([
                    parent / "extensions",
                    parent / "resources" / "app" / "extensions",
                    parent / "Resources" / "app" / "extensions",
                ]);
            }
        }
    }

    for extensions_dir in dict.fromkeys(extension_dirs) {
        try {
            extension_paths: any = `list(extensions_dir.iterdir());
        } except OSError {
            continue;
        }
        for extension_path in extension_paths {
            name: any = extension_path.name.lower();
            if name.startswith("github.copilot-") {
                return True;
            }
            if "copilot" not in name {
                continue;
            }
            try {
                manifest: any = json.loads(
                    (extension_path / "package.json").read_text(encoding="utf-8")
                );
            } except (OSError, json.JSONDecodeError) {
                continue;
            }
            if `str(manifest.get("publisher", "")).lower() == "github"
                and `str(manifest.get("name", "")).lower() in {"copilot", "copilot-chat"}
            {
                return True;
            }
        }
    }
    return False;
}

impl _xdg_config_home -> Path {
    xdg: any = os.environ.get("XDG_CONFIG_HOME", "").strip();
    return Path(xdg) if xdg else Path.home() / ".config";
}

impl _app_data_dirs(app: str) -> list[Path] {
    system: any = platform.system();
    if system == "Darwin" {
        return [Path.home() / "Library" / "Application Support" / app];
    }
    if system == "Windows" {
        appdata: any = os.environ.get("APPDATA", "").strip();
        return [Path(appdata) / app] if appdata else [];
    }
    return [_xdg_config_home() / app];
}

impl _xdg_data_home -> Path {
    xdg: any = os.environ.get("XDG_DATA_HOME", "").strip();
    return Path(xdg) if xdg else Path.home() / ".local" / "share";
}

impl _claude_code_detected -> bool {
    if os.environ.get("CLAUDECODE", "").strip() {
        return True;
    }
    config_dir: any = os.environ.get("CLAUDE_CONFIG_DIR", "").strip();
    if config_dir and Path(config_dir).expanduser().exists() {
        return True;
    }
    home: any = Path.home();
    return `bool(shutil.which("claude"))
        or (home / ".claude").exists()
        or (home / ".claude.json").exists();
}

impl _opencode_detected -> bool {
    if shutil.which("opencode") {
        return True;
    }
    return `any(
        folder.exists()
        for folder in (
            Path.home() / ".opencode",
            _xdg_config_home() / "opencode",
            _xdg_data_home() / "opencode",
        ),
    );
}

impl _qoder_detected -> bool {
    if shutil.which("qoder") or shutil.which("qodercli") {
        return True;
    }
    if (Path.home() / ".qoder").exists() {
        return True;
    }
    if platform.system() == "Darwin"
        and `any(
            (folder / "Qoder.app").exists()
            for folder in (Path("/Applications"), Path.home() / "Applications"),
        )
    {
        return True;
    }
    return `any(folder.exists() for folder in _app_data_dirs("Qoder"));
}

impl _codebuddy_detected -> bool {
    return `bool(shutil.which("codebuddy")) or (Path.home() / ".codebuddy").exists();
}

impl _hermes_home -> Path {
    `override: any = os.environ.get("HERMES_HOME", "").strip();
    if `override {
        return Path(`override).expanduser();
    }
    if platform.system() == "Windows" {
        local_appdata: any = os.environ.get("LOCALAPPDATA", "").strip();
        base: any = Path(local_appdata) if local_appdata else Path.home() / "AppData" / "Local";
        return base / "hermes";
    }
    return Path.home() / ".hermes";
}

impl _hermes_config_path -> Path {
    return _hermes_home() / "config.yaml";
}

impl _dsh_home -> Path {
    `override: any = os.environ.get("DSH_HOME", "");
    if `override.strip() {
        return Path(`override).expanduser();
    }
    return Path.home() / ".dsh";
}

impl _dsh_config_path -> Path {
    return _dsh_home() / "cordis.patch.yml";
}

impl _opencode_config_paths(repo_root: Path) -> tuple[Path, Path] {
    return (repo_root / "opencode.jsonc", repo_root / "opencode.json");
}

impl _opencode_config_path(repo_root: Path) -> Path {
    for path in _opencode_config_paths(repo_root) {
        if path.exists() {
            return path;
        }
    }
    return repo_root / "opencode.jsonc";
}

impl _mimo_config_home -> Path {
    mimo_home: any = os.environ.get("MIMOCODE_HOME", "").strip();
    if mimo_home and os.path.isabs(mimo_home) {
        return Path(mimo_home) / "config";
    }
    return _xdg_config_home() / "mimocode";
}

impl _mimo_config_paths(repo_root: Path) -> tuple[Path, Path] {
    config_dir: any = repo_root / ".mimocode";
    return (config_dir / "mimocode.json", config_dir / "mimocode.jsonc");
}

impl _mimo_config_path(repo_root: Path) -> Path {
    json_path: any;
    jsonc_path: any;
    (json_path, jsonc_path) = _mimo_config_paths(repo_root) as any;
    return jsonc_path if jsonc_path.exists() else json_path;
}

impl _codex_home -> Path {
    import from .codex_skill { codex_home }

    return codex_home();
}

impl _in_poetry_project -> bool {
    if os.environ.get("POETRY_ACTIVE") == "1" {
        return True;
    }
    virtual_env: any = os.environ.get("VIRTUAL_ENV", "");
    return `bool(virtual_env) and "pypoetry" in virtual_env.lower();
}

impl _in_uv_project -> bool {
    exe: any = Path(sys.executable).resolve();
    home: any = Path.home();
    for parent in exe.parents {
        if (parent / "uv.lock").exists() {
            return True;
        }
        if parent == home or parent == parent.parent {
            break;
        }
    }
    return False;
}

impl _running_from_uv_tool -> bool {
    prefix: any = Path(sys.prefix);
    if (prefix / "uv-receipt.toml").is_file() {
        return True;
    }
    return `bool(_UV_CACHE_ENV_RE.match(prefix.parent.name));
}

impl _detect_cli_launcher -> list[str] {
    if _in_poetry_project() and shutil.which("poetry") {
        return ["poetry", "run", "code-review-graph"];
    }
    if (os.environ.get("UV_PROJECT_ENVIRONMENT") or _in_uv_project()) and shutil.which("uv") {
        return ["uv", "run", "code-review-graph"];
    }
    if _running_from_uv_tool() and shutil.which("uvx") {
        return ["uvx", "code-review-graph"];
    }
    return [sys.executable, "-m", "code_review_graph"];
}

impl _detect_serve_command -> tuple[str, list[str]] {
    launcher: any = _detect_cli_launcher();
    return (launcher[0], [*launcher[1:], "serve"]);
}

impl _build_server_entry(
    plat: dict[str, Any], key: str = "", repo_root: "Path | None" = None
) -> dict[str, Any] {
    command: any;
    args: any;
    (command, args) = _detect_serve_command() as any;
    if key in ("opencode", "mimo") {
        local_command: any = [command, *args];
        if repo_root is not None {
            local_command.extend(("--repo", `str(repo_root)));
        }
        return {"type": "local", "command": local_command};
    }

    `entry: dict[str, Any] = {"command": command, "args": args};
    if key in ("hermes", "dsh") {
        return `entry;
    }
    if repo_root is not None {
        `entry["cwd"] = `str(repo_root);
    }
    if plat["needs_type"] {
        `entry["type"] = plat.get("server_type", "stdio");
    }
    `entry.update(plat.get("entry_fields", {}));
    return `entry;
}

impl _launcher_basename(token: str) -> str {
    name: any = token.replace("\\", "/").rsplit("/", 1)[-1];
    if name.lower().endswith(".exe") {
        name = name[:-len(".exe")];
    }
    return name;
}

impl _entry_command_tokens(`entry: dict[str, Any]) -> list[str] | None {
    command: any = `entry.get("command");
    if isinstance(command, `str) {
        tokens: any = [command];
    } elif isinstance(command, `list) and all(isinstance(item, `str) for item in command) {
        tokens = `list(command);
    } else {
        return None;
    }
    args: any = `entry.get("args", []);
    if not isinstance(args, `list) or not all(isinstance(item, `str) for item in args) {
        return None;
    }
    return tokens + args;
}

impl _is_generated_server_entry(`entry: Any) -> bool {
    if not isinstance(`entry, `dict) {
        return False;
    }
    if not `set(`entry) <= _GENERATED_ENTRY_FIELDS {
        return False;
    }
    if "type" in `entry and `entry["type"] not in _GENERATED_ENTRY_TYPES {
        return False;
    }
    if "tools" in `entry and `entry["tools"] != ["*"] {
        return False;
    }
    if "env" in `entry and `entry["env"] not in ([], {}) {
        return False;
    }
    tokens: any = _entry_command_tokens(`entry);
    if not tokens {
        return False;
    }
    launcher: any;
    rest: any;
    (launcher, rest) = (tokens[0], `tuple(tokens[1:]));
    if len(rest) >= 2 and rest[-2] == "--repo" {
        rest = rest[:-2];
    }
    launchers: any = _GENERATED_SERVE_ARGV.get(rest);
    if launchers is None {
        return False;
    }
    name: any = _launcher_basename(launcher);
    if "python" in launchers {
        return `bool(_PYTHON_LAUNCHER_RE.match(name));
    }
    return name in launchers;
}

impl _report_user_owned_entry(config_path: Path, label: str = "") -> None {
    prefix: any = f"  {label}: " if label else "  ";
    print(
        f"{prefix}{config_path} holds a hand-written 'code-review-graph' entry — leaving it as it is.",
    );
}

impl _warn_legacy_opencode_config(repo_root: Path) -> None {
    legacy: any = repo_root / ".opencode.json";
    if not legacy.exists() {
        return;
    }
    try {
        parsed: any = json.loads(
            _strip_jsonc(legacy.read_text(encoding="utf-8", errors="replace"))
        );
    } except (json.JSONDecodeError, OSError) {
        return;
    }
    if not isinstance(parsed, `dict) {
        return;
    }
    servers: any = parsed.get("mcpServers");
    if isinstance(servers, `dict) and "code-review-graph" in servers {
        print(
            f"  OpenCode: legacy config found at {legacy}; leaving it unchanged. OpenCode now reads opencode.json or opencode.jsonc with a top-level 'mcp' setting.",
        );
    }
}

impl _load_tomllib -> Any {
    import importlib;

    return importlib.import_module("tomllib" if sys.version_info >= (3, 11) else "tomli");
}

impl _format_toml_value(value: Any) -> str {
    if isinstance(value, `str) {
        escaped: any = value.replace("\\", "\\\\").replace("\"", "\\\"");
        return f"\"{escaped}\"";
    }
    if isinstance(value, `bool) {
        return "true" if value else "false";
    }
    if isinstance(value, `list) {
        return "[" + ", ".join(_format_toml_value(item) for item in value) + "]";
    }
    raise TypeError(f"Unsupported TOML value: {`type(value)!r}");
}

impl _toml_header_matches(line: str, table_path: tuple[str, ...]) -> bool {
    stripped: any = line.strip();
    if not stripped.startswith("[") or not stripped.endswith("]") {
        return False;
    }
    if stripped.startswith("[[") {
        return False;
    }
    parts: any = [part.strip().strip("\"").strip("'") for part in stripped[1:-1].split(".")];
    return operator.eq(`tuple(parts), table_path);
}

impl _toml_table_span(lines: list[str], table_path: tuple[str, ...]) -> tuple[int, int] | None {
    start: any = None;
    for (index, line) in enumerate(lines) {
        if _toml_header_matches(line, table_path) {
            start = index;
            break;
        }
    }
    if start is None {
        return None;
    }
    end: any = start + 1;
    last_content: any = end;
    while end < len(lines) {
        stripped: any = lines[end].strip();
        if stripped.startswith("[") {
            break;
        }
        if stripped and not stripped.startswith("#") {
            last_content = end + 1;
        }
        end += 1;
    }
    return (start, last_content);
}

impl _merge_toml_mcp_server(
    config_path: Path, server_name: str, server_entry: dict[str, Any], dry_run: bool = False
) -> bool | None {
    table_path: any = ("mcp_servers", server_name);
    section_lines: any = [f"[mcp_servers.{server_name}]"];
    for (key, value) in server_entry.items() {
        section_lines.append(f"{key} = {_format_toml_value(value)}");
    }
    section: any = "\n".join(section_lines) + "\n";

    existing: any = "";
    if install_plan.exists(config_path) {
        existing = install_plan.read_text(config_path, encoding="utf-8");
    }

    lines: any = existing.splitlines(keepends=True);
    span: any = _toml_table_span(lines, table_path);
    if existing {
        tomllib: any = _load_tomllib();
        current: Any = None;
        parsed_ok: any = False;
        try {
            parsed: any = tomllib.loads(existing);
        } except tomllib.TOMLDecodeError {
            parsed = None;
        }
        if isinstance(parsed, `dict) {
            parsed_ok = True;
            table: any = parsed.get("mcp_servers");
            if isinstance(table, `dict) {
                current = table.get(server_name);
            }
        }
        if not parsed_ok {
            if span is not None {
                return False;
            }
        } elif current is not None {
            if current == server_entry {
                return False;
            }
            if not _is_generated_server_entry(current) {
                _report_user_owned_entry(config_path);
                return None;
            }
            if span is None {
                print(
                    f"  {config_path}: the existing [mcp_servers.{server_name}] table could not be located for replacement — left unchanged.",
                );
                return None;
            }
            if dry_run {
                return True;
            }
            start: any;
            end: any;
            (start, end) = span as any;
            install_plan.write_text(
                config_path, "".join(lines[:start]) + section + "".join(lines[end:])
            );
            return True;
        }
    }

    if dry_run {
        return True;
    }

    prefix: any = "";
    if existing {
        prefix = existing if existing.endswith("\n") else existing + "\n";
        if not prefix.endswith("\n\n") {
            prefix += "\n";
        }
    }
    install_plan.write_text(config_path, prefix + section);
    return True;
}

impl _yaml_section_bounds(lines: list[str], key: str) -> tuple[int, int] | None {
    header: any = None;
    line: any;
    for (index, line) in enumerate(lines) {
        if line.startswith((" ", "\t", "#")) or not line.strip() {
            continue;
        }
        name: any;
        sep: any;
        value: any;
        (name, sep, value) = line.partition(":") as any;
        if sep and name.strip() == key {
            if value.strip() and not value.strip().startswith("#") {
                return None;
            }
            header = index;
            break;
        }
    }
    if header is None {
        return None;
    }
    end: any = header + 1;
    last_content: any = header + 1;
    while end < len(lines) {
        line = lines[end];
        if line.strip() and not line.startswith((" ", "\t")) {
            break;
        }
        if line.strip() and not line.lstrip().startswith("#") {
            last_content = end + 1;
        }
        end += 1;
    }
    return (header, last_content);
}

impl _yaml_block_indent(lines: list[str], start: int, end: int) -> int {
    for line in lines[start:end] {
        stripped: any = line.lstrip();
        if stripped and not stripped.startswith("#") {
            return len(line) - len(stripped);
        }
    }
    return 2;
}

impl _yaml_child_bounds(lines: list[str], start: int, end: int, name: str) -> tuple[int, int]
    | None {
    indent: any = _yaml_block_indent(lines, start, end);
    header: any = None;
    for index in range(start, min(end, len(lines))) {
        line: any = lines[index];
        stripped: any = line.strip();
        if not stripped or stripped.startswith("#") {
            continue;
        }
        if len(line) - len(line.lstrip()) != indent {
            continue;
        }
        key: any;
        sep: any;
        _value: any;
        (key, sep, _value) = stripped.partition(":") as any;
        if sep and key.strip().strip("\"").strip("'") == name {
            header = index;
            break;
        }
    }
    if header is None {
        return None;
    }
    cursor: any = header + 1;
    last_content: any = cursor;
    while cursor < min(end, len(lines)) {
        line = lines[cursor];
        if line.strip() and len(line) - len(line.lstrip()) <= indent {
            break;
        }
        if line.strip() and not line.lstrip().startswith("#") {
            last_content = cursor + 1;
        }
        cursor += 1;
    }
    return (header, last_content);
}

impl _merge_yaml_mcp_server(
    config_path: Path,
    server_key: str,
    server_name: str,
    server_entry: dict[str, Any],
    dry_run: bool = False,
) -> bool | None {
    import yaml;

    raw: any = "";
    replacing: any = False;
    if install_plan.exists(config_path) {
        raw = install_plan.read_text(config_path, encoding="utf-8", errors="replace");
        try {
            parsed: any = yaml.safe_load(raw);
        } except yaml.YAMLError as exc {
            print(
                f"  {config_path} contains unparseable YAML ({exc.__class__.__name__}) — skipping to avoid data loss. Please add the MCP config manually.",
            );
            return None;
        }
        if parsed is not None and not isinstance(parsed, `dict) {
            print(
                f"  {config_path} is valid YAML but not a top-level mapping ({`type(parsed).__name__}) — skipping to avoid data loss. Please add the MCP config manually.",
            );
            return None;
        }
        existing_servers: any = (parsed or {}).get(server_key);
        if existing_servers is not None and not isinstance(existing_servers, `dict) {
            print(
                f"  {config_path} setting {server_key!r} is {`type(existing_servers).__name__}; expected a mapping — skipping to avoid data loss.",
            );
            return None;
        }
        if isinstance(existing_servers, `dict) and server_name in existing_servers {
            current: any = existing_servers[server_name];
            if current == server_entry {
                return False;
            }
            if not _is_generated_server_entry(current) {
                _report_user_owned_entry(config_path);
                return None;
            }
            replacing = True;
        }
    }

    lines: any = raw.splitlines(keepends=True);
    if lines and not lines[-1].endswith("\n") {
        lines[-1] += "\n";
    }

    bounds: any = _yaml_section_bounds(lines, server_key);
    if bounds is None and raw and server_key in (yaml.safe_load(raw) or {}) {
        print(
            f"  {config_path} setting {server_key!r} is not a block mapping — skipping to avoid data loss. Please add the MCP config manually.",
        );
        return None;
    }

    body: any = yaml.safe_dump(
        {server_name: server_entry}, default_flow_style=False, sort_keys=False, allow_unicode=True
    );
    if bounds is None {
        indent: any = 2;
        prefix: any = "" if not lines or lines[-1].strip() == "" else "\n";
        block: any = prefix + f"{server_key}:\n" + _indent_block(body, indent);
        new_lines: any = lines + [block];
    } else {
        header: any;
        insert_at: any;
        (header, insert_at) = bounds as any;
        indent = _yaml_block_indent(lines, header + 1, insert_at);
        child: any = _yaml_child_bounds(lines, header + 1, insert_at, server_name)
            if replacing
            else None;
        if replacing and child is None {
            print(
                f"  {config_path}: the existing {server_name!r} entry could not be located for replacement — left unchanged.",
            );
            return None;
        }
        if child is None {
            new_lines = lines[:insert_at] + [_indent_block(body, indent)] + lines[insert_at:];
        } else {
            child_start: any;
            child_end: any;
            (child_start, child_end) = child as any;
            new_lines = lines[:child_start] + [_indent_block(body, indent)] + lines[child_end:];
        }
    }

    rewritten: any = "".join(new_lines);
    try {
        reparsed: any = yaml.safe_load(rewritten);
    } except yaml.YAMLError as exc {
        print(
            f"  {config_path}: safe YAML edit failed ({exc.__class__.__name__}) — left unchanged."
        );
        return None;
    }
    written: any = reparsed.get(server_key) or {} if isinstance(reparsed, `dict) else {};
    if not isinstance(written, `dict) or written.get(server_name) != server_entry {
        print(f"  {config_path}: safe YAML edit did not take effect — left unchanged.");
        return None;
    }

    if not dry_run {
        install_plan.write_text(config_path, rewritten);
    }
    return True;
}

impl _merge_dsh_patch_server(config_path: Path, server_entry: dict[str, Any]) -> bool | None {
    import importlib;

    dsh: any = importlib.import_module("code_review_graph.dsh");

    raw: any = "";
    row: any = dsh.server_row(server_entry);
    try {
        if install_plan.exists(config_path) {
            try {
                raw = install_plan.read_text(config_path, encoding="utf-8");
            } except UnicodeDecodeError as exc {
                raise dsh.PatchError("it is not UTF-8") from exc;
            }
        }
        document: any;
        found: any;
        (document, found) = dsh.find_owned(raw) as any;
        replace: int | None = None;
        if found {
            op_index: any;
            row_index: any;
            (op_index, row_index) = found[0] as any;
            current: any = document[op_index]["insert"][row_index];
            owned: any = operator.eq(len(found), 1)
                and operator.eq(dsh.removable(document, found), op_index)
                and dsh.is_generated_row(current, _is_generated_server_entry);
            if not owned {
                _report_user_owned_entry(config_path);
                return None;
            }
            if current == row {
                return False;
            }
            replace = op_index;
        }
        rewritten: any = dsh.with_row(raw, row, replace);
    } except dsh.PatchError as exc {
        print(
            f"  {config_path}: {exc} — skipping to avoid data loss. Please add the MCP config manually.",
        );
        return None;
    }
    install_plan.write_text(config_path, rewritten);
    return True;
}

impl _indent_block(text: str, indent: int) -> str {
    pad: any;
    pad = " " * indent;
    return "".join(
        f"{pad}{line}" if line.strip() else line for line in text.splitlines(keepends=True)
    );
}

impl _strip_jsonc(text: str) -> str {
    """If a comment starts at ``idx``, return the index just past it."""
    def _skip_comment(s: str, idx: int) -> int | None {
        if s[idx] != "/" or idx + 1 >= len(s) {
            return None;
        }
        nxt: any = s[idx + 1];
        if nxt == "/" {
            idx += 2;
            while idx < len(s) and s[idx] != "\n" {
                idx += 1;
            }
            return idx;
        }
        if nxt == "*" {
            idx += 2;
            while idx + 1 < len(s) and not (s[idx] == "*" and s[idx + 1] == "/") {
                idx += 1;
            }
            return idx + 2;
        }
        return None;
    }

    out: list[str] = [];
    i: any = 0;
    n: any = len(text);
    in_string: any = False;
    while i < n {
        ch: any = text[i];
        if in_string {
            out.append(ch);
            if ch == "\\" and i + 1 < n {
                out.append(text[i + 1]);
                i += 2;
                continue;
            }
            if ch == "\"" {
                in_string = False;
            }
            i += 1;
            continue;
        }
        if ch == "\"" {
            in_string = True;
            out.append(ch);
            i += 1;
            continue;
        }
        past: any = _skip_comment(text, i);
        if past is not None {
            i = past;
            continue;
        }
        if ch == "," {
            j: any = i + 1;
            while j < n {
                if text[j] in " \t\r\n" {
                    j += 1;
                    continue;
                }
                past = _skip_comment(text, j);
                if past is not None {
                    j = past;
                    continue;
                }
                break;
            }
            if j < n and text[j] in "}]" {
                i += 1;
                continue;
            }
        }
        out.append(ch);
        i += 1;
    }
    return "".join(out);
}

impl _splice_commented_config(
    raw: str,
    server_key: str,
    server_entry: dict[str, Any] | None,
    removals: list[tuple[str, ...]],
    *,
    array_format: bool,
    document: dict[str, Any],
) -> str | None {
    try {
        if not jsonc.tokenize(raw) {
            body: any = json.dumps(document, indent=2, ensure_ascii=False);
            return raw.rstrip("\n") + "\n" + body + "\n";
        }
        if array_format {
            return None;
        }
        text: any = jsonc.remove_paths(raw, removals) if removals else raw;
        if server_entry is None {
            return text;
        }
        try {
            return jsonc.set_member(text, (server_key, "code-review-graph"), server_entry);
        } except KeyError {
            return jsonc.set_member(text, (server_key,), {"code-review-graph": server_entry});
        }
    } except (ValueError, KeyError, IndexError, RecursionError) {
        return None;
    }
}

impl platforms_for_target(repo_root: Path, target: str) -> dict[str, dict[str, Any]] {
    if target == "all" {
        selected: any = {k: v for (k, v) in PLATFORMS.items() if v["detect"]()};
        if "kiro" not in selected and (repo_root / ".kiro").is_dir() {
            selected["kiro"] = PLATFORMS["kiro"];
        }
        return selected;
    }
    if target in PLATFORMS {
        return {target: PLATFORMS[target]};
    }
    return {};
}

impl selected_platforms(repo_root: Path, target: str) -> frozenset[str] {
    return frozenset(platforms_for_target(repo_root, target));
}

impl install_platform_configs(
    repo_root: Path,
    target: str = "all",
    dry_run: bool = False,
    platforms: Iterable[str] | None = None,
) -> list[str] {
    if dry_run and install_plan.active() is None {
        with install_plan.planning() {
            return _install_platform_configs(repo_root, target, True, platforms);
        }
    }
    return _install_platform_configs(repo_root, target, dry_run, platforms);
}

impl _install_platform_configs(
    repo_root: Path, target: str, dry_run: bool, platforms: Iterable[str] | None = None
) -> list[str] {
    shared_aliases: dict[str, tuple[str, ...]];
    claude: any;
    codebuddy: any;
    configured: list[str];
    shared_aliases = {};
    if target == "all" {
        if platforms is None {
            platforms_to_install: any = platforms_for_target(repo_root, target);
        } else {
            chosen: any = `set(platforms);
            platforms_to_install = {k: v for (k, v) in PLATFORMS.items() if k in chosen};
        }
        claude = platforms_to_install.get("claude");
        codebuddy = platforms_to_install.get("codebuddy");
        if claude is not None and codebuddy is not None {
            same_contract: any = operator.eq(
                claude["config_path"](repo_root), codebuddy["config_path"](repo_root)
            )
                and all(
                    operator.eq(claude[field], codebuddy[field])
                    for field in ("key", "format", "needs_type"),
                );
            if same_contract {
                shared_aliases["claude"] = ("codebuddy",);
                del platforms_to_install["codebuddy"];
            }
        }
    } else {
        if target not in PLATFORMS {
            logger.error("Unknown platform: %s", target);
            return [];
        }
        platforms_to_install = {target: PLATFORMS[target]};
    }

    configured = [];

    def _record_configured(key: str, plat: dict[str, Any]) -> None {
        configured.append(plat["name"]);
        configured.extend(PLATFORMS[alias]["name"] for alias in shared_aliases.get(key, ()));
    }

    for (key, plat) in platforms_to_install.items() {
        if key == "opencode" {
            _warn_legacy_opencode_config(repo_root);
        }
        config_path: Path = plat["config_path"](repo_root);
        shown: any = install_plan.display_path(config_path, repo_root);
        server_key: any = plat["key"];
        server_entry: any = _build_server_entry(plat, key=key, repo_root=repo_root);

        if plat["format"] in ("toml", "yaml", "dsh-patch") {
            if plat["format"] == "toml" {
                changed: any = _merge_toml_mcp_server(
                    config_path, "code-review-graph", server_entry
                );
            } elif plat["format"] == "dsh-patch" {
                changed = _merge_dsh_patch_server(config_path, server_entry);
            } else {
                changed = _merge_yaml_mcp_server(
                    config_path, server_key, "code-review-graph", server_entry
                );
            }
            if changed is None {
                continue;
            }
            if not changed {
                print(
                    "  " + format(plat["name"], "") + ": already configured in " + format(shown, "")
                );
                _record_configured(key, plat);
                continue;
            }
            if dry_run {
                print(
                    "  [dry-run] " + format(plat["name"], "") + ": would write " + format(shown, "")
                );
            } else {
                print("  " + format(plat["name"], "") + ": configured " + format(shown, ""));
            }
            _record_configured(key, plat);
            continue;
        }
        existing: dict[str, Any] = {};
        raw: any = "";
        if install_plan.exists(config_path) {
            raw = install_plan.read_text(config_path, encoding="utf-8", errors="replace");
            stripped: any = _strip_jsonc(raw);
            if not stripped.strip() {
                existing = {};
            } else {
                try {
                    parsed: any = json.loads(stripped);
                } except (json.JSONDecodeError, OSError) {
                    print(
                        "  "
                            + format(plat["name"], "")
                            + ": "
                            + format(config_path, "")
                            + " contains unparseable JSON — skipping to avoid data loss. Please add the MCP config manually.",
                    );
                    continue;
                }
                if not isinstance(parsed, `dict) {
                    print(
                        "  "
                            + format(plat["name"], "")
                            + ": "
                            + format(config_path, "")
                            + " is valid JSON but not a top-level object ("
                            + format(`type(parsed).__name__, "")
                            + ") — skipping to avoid data loss. Please add the MCP config manually.",
                    );
                    continue;
                }
                existing = parsed;
            }
        }

        expected_container: any = list[any] if plat["format"] == "array" else dict[any, any];
        if server_key in existing and not isinstance(existing[server_key], expected_container) {
            expected_name: any = "array" if expected_container is list[any] else "object";
            actual_name: any = `type(existing[server_key]).__name__;
            print(
                "  "
                    + format(plat["name"], "")
                    + ": "
                    + format(config_path, "")
                    + " setting "
                    + format(repr(server_key), "")
                    + " is "
                    + format(actual_name, "")
                    + "; expected a JSON "
                    + format(expected_name, "")
                    + " — skipping to avoid data loss. Please repair that setting or add the MCP config manually.",
            );
            continue;
        }
        removals: list[tuple[str, ...]] = [];
        wrote_entry: any = False;

        if plat["format"] == "array" {
            arr: any = existing.get(server_key, []);
            arr_entry: any = {"name": "code-review-graph", **server_entry};
            ours: any = [
                index
                for (index, item) in enumerate(arr)
                if isinstance(item, `dict) and item.get("name") == "code-review-graph"
            ];
            if ours {
                current: any = arr[ours[0]];
                if not _is_generated_server_entry(current) {
                    _report_user_owned_entry(config_path, plat["name"]);
                    continue;
                }
                if len(ours) == 1 and current == arr_entry {
                    print(
                        "  "
                            + format(plat["name"], "")
                            + ": already configured in "
                            + format(shown, ""),
                    );
                    _record_configured(key, plat);
                    continue;
                }
                duplicates: any = `set(ours[1:]);
                arr = [
                    arr_entry if index == ours[0] else item
                    for (index, item) in enumerate(arr)
                    if index not in duplicates
                ];
            } else {
                arr = [*arr, arr_entry];
            }
            existing[server_key] = arr;
            wrote_entry = True;
        } else {
            migrated: any = False;
            for legacy_key in plat.get("legacy_keys", ()) {
                legacy: any = existing.get(legacy_key);
                if isinstance(legacy, `dict) and "code-review-graph" in legacy {
                    del legacy["code-review-graph"];
                    removals.append((legacy_key, "code-review-graph"));
                    if not legacy {
                        del existing[legacy_key];
                        removals[-1] = (legacy_key,);
                    }
                    migrated = True;
                }
            }
            servers: any = existing.get(server_key, {});
            current = servers.get("code-review-graph");
            user_owned: any = current is not None and not _is_generated_server_entry(current);
            if user_owned {
                _report_user_owned_entry(config_path, plat["name"]);
                if not migrated {
                    continue;
                }
            } elif current == server_entry and not migrated {
                print(
                    "  " + format(plat["name"], "") + ": already configured in " + format(shown, "")
                );
                _record_configured(key, plat);
                continue;
            } else {
                servers["code-review-graph"] = server_entry;
                existing[server_key] = servers;
                wrote_entry = True;
            }
        }
        spliced: str | None = None;
        if jsonc.has_comments(raw) {
            spliced = _splice_commented_config(
                raw,
                server_key,
                server_entry if wrote_entry else None,
                removals,
                array_format=operator.eq(plat["format"], "array"),
                document=existing,
            );
            if spliced is None {
                print(
                    "  "
                        + format(plat["name"], "")
                        + ": "
                        + format(config_path, "")
                        + " keeps comments that this installer cannot preserve through an edit — left unchanged. Please add the MCP config manually.",
                );
                continue;
            }
        }

        install_plan.write_text(
            config_path,
            spliced
                if spliced is not None
                else json.dumps(existing, indent=2, ensure_ascii=False) + "\n",
        );
        if dry_run {
            print("  [dry-run] " + format(plat["name"], "") + ": would write " + format(shown, ""));
        } else {
            print("  " + format(plat["name"], "") + ": configured " + format(shown, ""));
        }

        if wrote_entry {
            _record_configured(key, plat);
        }
    }

    return configured;
}

impl generate_skills(repo_root: Path, skills_dir: Path | None = None) -> Path {
    if skills_dir is None {
        skills_dir = repo_root / ".claude" / "skills";
    }

    for (filename, skill) in _SKILLS.items() {
        skill_name: any = filename.removesuffix(".md");
        path: any = skills_dir / skill_name / "SKILL.md";
        content: any = "---\nname: "
            + format(skill["name"], "")
            + "\ndescription: "
            + format(skill["description"], "")
            + "\n---\n\n"
            + format(skill["body"], "")
            + "\n";
        install_plan.write_text(path, content);
        logger.info("Wrote skill: %s", path);
    }

    return skills_dir;
}

impl render_documentary_skill_markdown(slug: str) -> str {
    try {
        spec: any = DOCUMENTARY_SKILLS[slug];
    } except KeyError {
        known: any = ", ".join(sorted(DOCUMENTARY_SKILLS));
        raise KeyError(f"unknown documentary skill {slug!r} (known: {known})") from None;
    }
    frontmatter: any = ["---", f"name: {slug}", "description: " + format(spec["description"], "")];
    argument_hint: any = spec.get("argument_hint");
    if argument_hint {
        frontmatter.append(f"argument-hint: \"{argument_hint}\"");
    }
    frontmatter.append("---");
    frontmatter.append("");
    frontmatter.append("# " + format(spec["title"], ""));
    frontmatter.append("");
    frontmatter.append(spec["body"]);
    frontmatter.append("");
    return "\n".join(frontmatter);
}

impl generate_documentary_skills(repo_root: Path, skills_dir: Path | None = None) -> Path {
    if skills_dir is None {
        skills_dir = repo_root / "skills";
    }
    skills_dir.mkdir(parents=True, exist_ok=True);

    for slug in DOCUMENTARY_SKILLS {
        skill_subdir: any = skills_dir / slug;
        skill_subdir.mkdir(parents=True, exist_ok=True);
        skill_path: any = skill_subdir / "SKILL.md";
        skill_path.write_text(
            render_documentary_skill_markdown(slug), encoding="utf-8", newline="\n"
        );
    }

    return skills_dir;
}

impl _sh_single_quote(value: str) -> str {
    return "'" + value.replace("'", "'\"'\"'") + "'";
}

impl _hook_launcher -> list[str] {
    if _detect_cli_launcher()[0] == "uvx" {
        return ["uvx", "code-review-graph"];
    }
    return [sys.executable, "-m", "code_review_graph"];
}

impl _hook_program -> _HookProgram {
    launcher: any = _hook_launcher();
    if launcher[0] == "uvx" {
        return _UVX_HOOK_PROGRAM;
    }
    exe: any = _sh_single_quote(Path(launcher[0]).as_posix());
    return _HookProgram(f"[ -x {exe} ]", f"{exe} -m code_review_graph");
}

impl _hook_chain(body: Callable[[str], str], program: _HookProgram, otherwise: str = "") -> str {
    tail: any = f" else {otherwise};" if otherwise else "";
    return f"if {program.guard}; then {body(program.command)}; elif {_PATH_GUARD}; then {body(_PATH_HOOK_PROGRAM.command)};{tail} fi";
}

impl _session_status_body(cli: str) -> str {
    return f"if git rev-parse --git-dir >/dev/null 2>&1; then {cli} status --repo \"$(git rev-parse --show-toplevel 2>/dev/null)\" || true; else echo 'Not a git repo, skipping'; fi";
}

impl _legacy_session_status_body(cli: str) -> str {
    return f"git rev-parse --git-dir >/dev/null 2>&1 && {cli} status --repo \"$(git rev-parse --show-toplevel 2>/dev/null)\" || echo 'Not a git repo, skipping'";
}

impl _claude_update_hook_command(program: _HookProgram) -> str {
    if program == _PATH_HOOK_PROGRAM {
        return f"{_PATH_GUARD} && code-review-graph hook-update; cat >/dev/null || true";
    }
    return _hook_chain(lambda (cli) -> any { f"{cli} hook-update" }, program)
        + "; cat >/dev/null || true";
}

impl _claude_session_hook_command(
    program: _HookProgram, body: Callable[[str], str] = body_default_
) -> str {
    if program == _PATH_HOOK_PROGRAM {
        return f"cat >/dev/null || true; {_PATH_GUARD} || exit 0; " + body("code-review-graph");
    }
    return "cat >/dev/null || true; " + _hook_chain(body, program);
}

impl _codex_hook_command(subcommand: str, program: _HookProgram | None = None) -> str {
    program = program or _hook_program();
    if program == _PATH_HOOK_PROGRAM {
        return f"cat | {{ if {_PATH_GUARD}; then code-review-graph {subcommand}; else cat >/dev/null; fi; }}";
    }
    chain: any = _hook_chain(
        lambda (cli) -> any { f"{cli} {subcommand}" }, program, "cat >/dev/null"
    );
    return f"cat | {{ {chain}; }}";
}

impl _shell_cli_function(name: str, program: _HookProgram, indent: str = "") -> str {
    return f"{indent}{name}() {{\n{indent}    if {program.guard}; then {program.command} \"$@\"\n{indent}    elif {_PATH_GUARD}; then code-review-graph \"$@\"\n{indent}    else return 127\n{indent}    fi\n{indent}}}\n";
}

impl generate_hooks_config(repo_root: Path, program: _HookProgram | None = None) -> dict[str, Any] {
    program = program or _hook_program();
    return {
        "hooks": {
            "PostToolUse": [
                {
                    "matcher": "Edit|Write",
                    "hooks": [
                        {
                            "type": "command",
                            "command": _claude_update_hook_command(program),
                            "timeout": 30,
                        },
                    ],
                },
            ],
            "SessionStart": [
                {
                    "matcher": "",
                    "hooks": [
                        {
                            "type": "command",
                            "command": _claude_session_hook_command(program),
                            "timeout": 10,
                        },
                    ],
                },
            ],
        },
    };
}

impl generate_plugin_hooks_config -> dict[str, Any] {
    hooks: any = generate_hooks_config(Path("."), program=_PATH_HOOK_PROGRAM)["hooks"];
    worktree: any = {
        "matcher": "EnterWorktree",
        "hooks": [{"type": "command", "command": _PLUGIN_WORKTREE_BUILD_COMMAND}],
    };
    return {
        "hooks": {
            "SessionStart": hooks["SessionStart"],
            "PostToolUse": [worktree, *hooks["PostToolUse"]],
        },
    };
}

impl generate_steering_hooks_config(program: _HookProgram | None = None) -> dict[str, Any] {
    return {
        "hooks": {
            "PreToolUse": [
                {
                    "matcher": "Grep|Glob|Bash|Read",
                    "hooks": [
                        {
                            "type": "command",
                            "command": format(_codex_hook_command("enrich", program), "")
                                + " || true",
                            "timeout": 5,
                        },
                    ],
                },
            ],
        },
    };
}

impl generate_codex_hooks_config(
    repo_root: Path, program: _HookProgram | None = None
) -> dict[str, Any] {
    program = program or _hook_program();
    return {
        "hooks": {
            "PostToolUse": [
                {
                    "matcher": "Write|Edit|Bash",
                    "hooks": [
                        {
                            "type": "command",
                            "command": _codex_hook_command(_CODEX_UPDATE_SUBCOMMAND, program),
                            "timeout": 30,
                            "statusMessage": "Updating code-review-graph",
                        },
                    ],
                },
            ],
            "SessionStart": [
                {
                    "matcher": "startup|resume",
                    "hooks": [
                        {
                            "type": "command",
                            "command": _codex_hook_command("hook-status", program),
                            "timeout": 10,
                            "statusMessage": "Checking code-review-graph status",
                        },
                    ],
                },
            ],
        },
    };
}

impl _any_copy_guard(program: _HookProgram) -> str {
    if program == _PATH_HOOK_PROGRAM {
        return _PATH_GUARD;
    }
    return f"{{ {program.guard} || {_PATH_GUARD}; }}";
}

impl _hook_cli_function(name: str, program: _HookProgram, indent: str) -> str {
    if program == _PATH_HOOK_PROGRAM {
        return f"{indent}{name}() {{ code-review-graph \"$@\"; }}\n";
    }
    return _shell_cli_function(name, program, indent);
}

impl _git_hook_body(program: _HookProgram | None = None) -> str {
    program = program or _hook_program();
    return f"if {_any_copy_guard(program)}; then\n"
        + _hook_cli_function("crg_hook_cli", program, "    ")
        + "    crg_hook_git_dir=$(git rev-parse --absolute-git-dir 2>/dev/null) || crg_hook_git_dir=\"\"\n    crg_hook_root=$(git rev-parse --show-toplevel 2>/dev/null) || crg_hook_root=\"\"\n    if [ -z \"$crg_hook_git_dir\" ] || [ -z \"$crg_hook_root\" ]; then\n        echo \"code-review-graph: skipping automatic checks; cannot determine the Git worktree.\" >&2\n    elif [ -f \"$crg_hook_git_dir/commondir\" ] && [ \"$CRG_HOOK_WORKTREES\" != \"1\" ]; then\n        # Only a linked worktree's git dir carries a commondir file (Git 2.5+),\n        # so this needs no rev-parse options newer than --absolute-git-dir.\n        echo \"code-review-graph: skipping automatic checks in a linked worktree;\" \\\n            \"set CRG_HOOK_WORKTREES=1 to keep a graph for this worktree too.\" >&2\n    else\n        crg_hook_cli update --quiet --repo \"$crg_hook_root\" || true\n        crg_hook_cli detect-changes --brief --repo \"$crg_hook_root\" || true\n    fi\nfi\n";
}

impl _git_hook_block(program: _HookProgram | None = None) -> str {
    return f"{_GIT_HOOK_BEGIN_MARKER}\n{_GIT_HOOK_NOTE}\n{_git_hook_body(program)}{_GIT_HOOK_END_MARKER}\n";
}

impl _known_git_hook_blocks -> tuple[str, ...] {
    return `tuple(sorted(`set(_LEGACY_GIT_HOOK_BLOCKS), key=builtins.len, reverse=True));
}

impl _git_hook_markers_balanced(
    text: str, begin_marker: str = begin_marker_default_, end_marker: str = end_marker_default_
) -> bool {
    begins: any = text.count(begin_marker);
    if begins != text.count(end_marker) {
        return False;
    }
    cursor: any = 0;
    for _ in range(begins) {
        begin: any = text.find(begin_marker, cursor);
        closing: any = text.find(end_marker, begin);
        if closing < 0 {
            return False;
        }
        nested: any = text.find(begin_marker, begin + len(begin_marker));
        if 0 <= nested < closing {
            return False;
        }
        cursor = closing + len(end_marker);
    }
    return True;
}

impl _git_hook_block_span(
    text: str,
    start: int = 0,
    begin_marker: str = begin_marker_default__,
    end_marker: str = end_marker_default__,
) -> tuple[int, int] | None {
    begin: any = text.find(begin_marker, start);
    if begin < 0 {
        return None;
    }
    closing: any = text.find(end_marker, begin);
    if closing < 0 {
        return None;
    }
    end: any = closing + len(end_marker);
    if end < len(text) and text[end] == "\n" {
        end += 1;
    }
    return (begin, end);
}

impl _upgrade_git_hook_block(existing: str, program: _HookProgram | None = None) -> str | None {
    if _GIT_HOOK_BEGIN_MARKER in existing and not _git_hook_markers_balanced(existing) {
        return None;
    }
    current: any = _git_hook_block(program);
    span: any = _git_hook_block_span(existing);
    if span is not None {
        begin: any;
        end: any;
        (begin, end) = span as any;
        return existing[:begin] + current + existing[end:];
    }
    for block in _known_git_hook_blocks() {
        if block in existing {
            return existing.replace(block, current, 1);
        }
    }
    return None;
}

impl _is_shell_filler(line: str) -> bool {
    stripped: any = line.strip();
    return not stripped or stripped.startswith("#");
}

impl _trailing_exit(text: str) -> tuple[int, bool] | None {
    lines: any = text.splitlines(keepends=True);
    offset: any = len(text);
    for index in range(len(lines) - 1, -1, -1) {
        offset -= len(lines[index]);
        if _is_shell_filler(lines[index]) {
            continue;
        }
        `match: any = _TOP_LEVEL_EXIT_RE.fullmatch(lines[index].rstrip("\r\n"));
        if `match is None {
            return None;
        }
        for before in reversed(lines[:index]) {
            if not _is_shell_filler(before) {
                if before.strip().endswith(_SHELL_LINE_CONTINUATIONS) {
                    return None;
                }
                break;
            }
        }
        arg: any = `match.group("arg");
        return (offset, `bool(arg) and "$?" not in arg);
    }
    return None;
}

impl _add_hook_block(existing: str, block: str) -> str | None {
    trailing: any = _trailing_exit(existing);
    if trailing is None {
        return existing.rstrip("\n") + "\n" + block;
    }
    offset: any;
    safe: any;
    (offset, safe) = trailing as any;
    if not safe {
        return None;
    }
    return existing[:offset] + block + existing[offset:];
}

impl _lift_block_above_exit(text: str, begin_marker: str, end_marker: str) -> str {
    span: any = _git_hook_block_span(text, 0, begin_marker, end_marker);
    if span is None or text[span[1]:].strip() {
        return text;
    }
    begin: any;
    end: any;
    (begin, end) = span as any;
    trailing: any = _trailing_exit(text[:begin]);
    if trailing is None or not trailing[1] {
        return text;
    }
    offset: any = trailing[0];
    return text[:offset] + text[begin:end] + text[offset:begin] + text[end:];
}

impl _exit_warning(hook_path: Path, command: str) -> None {
    logger.warning(
        "%s ends with an 'exit' that passes on the last command's status, so a block added after it would never run; leaving it alone. Call 'code-review-graph %s' from it before the 'exit'.",
        hook_path,
        command,
    );
}

impl _git_hooks_dir(repo_root: Path) -> Path | None {
    try {
        result: any = subprocess.run(
            ["git", "rev-parse", "--git-path", "hooks"],
            capture_output=True,
            text=True,
            encoding="utf-8",
            cwd=`str(repo_root),
            timeout=10,
            stdin=subprocess.DEVNULL,
        );
        if result.returncode == 0 and result.stdout.strip() {
            return repo_root / result.stdout.strip();
        }
    } except (subprocess.TimeoutExpired, OSError) as exc {
        logger.warning("git unavailable (%s); falling back to .git/hooks resolution.", exc);
    }

    git_dir: any = repo_root / ".git";
    if not git_dir.is_dir() {
        logger.warning(
            "No git hooks directory found at %s — skipping git hook install.", repo_root
        );
        return None;
    }
    return git_dir / "hooks";
}

impl install_git_hook(repo_root: Path) -> Path | None {
    hooks_dir: any = _git_hooks_dir(repo_root);
    if hooks_dir is None {
        return None;
    }

    hook_path: any = hooks_dir / "pre-commit";
    program: any = _hook_program();

    if install_plan.exists(hook_path) {
        try {
            existing: any = install_plan.read_text(hook_path, encoding="utf-8");
        } except UnicodeDecodeError {
            existing = None;
        }
        if existing is None or not _is_shell_hook(existing) {
            logger.warning(
                "%s is not a shell script; leaving it alone. Call 'code-review-graph detect-changes --brief' from it to get the risk summary.",
                hook_path,
            );
            return hook_path;
        }
        if _GIT_HOOK_BEGIN_MARKER in existing and not _git_hook_markers_balanced(existing) {
            logger.warning(
                "%s has a code-review-graph begin marker with no matching end marker; leaving it alone.",
                hook_path,
            );
            return hook_path;
        }
        if _GIT_HOOK_BEGIN_MARKER in existing or _GIT_HOOK_NOTE in existing {
            upgraded: any = _upgrade_git_hook_block(existing, program);
            if upgraded is None {
                logger.warning(
                    "%s has a hand-edited code-review-graph block; leaving it alone.", hook_path
                );
                return hook_path;
            }
            upgraded = _lift_block_above_exit(
                upgraded, _GIT_HOOK_BEGIN_MARKER, _GIT_HOOK_END_MARKER
            );
            if upgraded == existing {
                logger.info("%s already holds the current hook block.", hook_path);
                return hook_path;
            }
            install_plan.write_text(hook_path, upgraded);
        } else {
            added: any = _add_hook_block(existing, _git_hook_block(program));
            if added is None {
                _exit_warning(hook_path, "detect-changes --brief");
                return hook_path;
            }
            install_plan.write_text(hook_path, added);
        }
    } else {
        install_plan.write_text(hook_path, _GIT_HOOK_SHEBANG + _git_hook_block(program));
    }

    install_plan.chmod(hook_path, 493);
    logger.info("Wrote git pre-commit hook: %s", hook_path);
    return hook_path;
}

impl _git_sync_hook_block(hook_name: str, program: _HookProgram | None = None) -> str {
    program = program or _hook_program();
    condition: any = _GIT_SYNC_HOOK_CONDITIONS[hook_name];
    rebase_guard: any = "";
    if hook_name == "post-checkout" {
        rebase_guard = "    elif [ -d \"$crg_hook_git_dir/rebase-merge\" ] && grep -Eq \\\n            '^[[:space:]]*(p|pick|r|reword|e|edit|s|squash|f|fixup|m|merge)[[:space:]]' \\\n            \"$crg_hook_git_dir/rebase-merge/git-rebase-todo\" 2>/dev/null; then\n        :\n    elif [ -d \"$crg_hook_git_dir/rebase-apply\" ]; then\n        :\n";
    }
    head: any = f"if {condition}{_any_copy_guard(program)}; then\n"
        + _hook_cli_function("crg_hook_cli", program, "    ");
    body: any = f"{head}    crg_hook_git_dir=$(git rev-parse --absolute-git-dir 2>/dev/null) || crg_hook_git_dir=\"\"\n    crg_hook_root=$(git rev-parse --show-toplevel 2>/dev/null) || crg_hook_root=\"\"\n    if [ -z \"$crg_hook_git_dir\" ] || [ -z \"$crg_hook_root\" ]; then\n        echo \"code-review-graph: skipping graph sync; cannot determine the Git worktree.\" >&2\n    elif [ -f \"$crg_hook_git_dir/commondir\" ] && [ \"$CRG_HOOK_WORKTREES\" != \"1\" ]; then\n        echo \"code-review-graph: skipping graph sync in a linked worktree;\" \\\n            \"set CRG_HOOK_WORKTREES=1 to keep a graph for this worktree too.\" >&2\n{rebase_guard}    else\n        crg_hook_cli update --quiet --repo \"$crg_hook_root\" || true\n    fi\nfi\n";
    return f"{_GIT_SYNC_HOOK_BEGIN_MARKER}\n{_GIT_SYNC_HOOK_NOTE}\n{body}{_GIT_SYNC_HOOK_END_MARKER}\n";
}

impl _is_shell_hook(text: str) -> bool {
    if not text.startswith("#!") {
        return True;
    }
    parts: any = text[2:].split("\n", 1)[0].split();
    if not parts {
        return True;
    }
    if Path(parts[0]).name == "env" {
        parts = [part for part in parts[1:] if not part.startswith("-") and "=" not in part];
        if not parts {
            return False;
        }
    }
    return Path(parts[0]).name in _SHELL_INTERPRETERS;
}

impl install_git_sync_hooks(repo_root: Path) -> list[Path] {
    hooks_dir: any = _git_hooks_dir(repo_root);
    if hooks_dir is None {
        return [];
    }

    written: list[Path] = [];
    program: any = _hook_program();
    for name in _GIT_SYNC_HOOK_NAMES {
        hook_path: any = hooks_dir / name;
        block: any = _git_sync_hook_block(name, program);
        if install_plan.exists(hook_path) {
            try {
                existing: any = install_plan.read_text(hook_path, encoding="utf-8");
            } except UnicodeDecodeError {
                existing = None;
            }
            if existing is None or not _is_shell_hook(existing) {
                logger.warning(
                    "%s is not a shell script; leaving it alone. Call 'code-review-graph update --quiet' from it to keep the graph in sync.",
                    hook_path,
                );
                continue;
            }
            if _GIT_SYNC_HOOK_BEGIN_MARKER in existing or _GIT_SYNC_HOOK_END_MARKER in existing {
                span: any = _git_hook_block_span(
                    existing, 0, _GIT_SYNC_HOOK_BEGIN_MARKER, _GIT_SYNC_HOOK_END_MARKER
                );
                if span is None
                    or not _git_hook_markers_balanced(
                        existing, _GIT_SYNC_HOOK_BEGIN_MARKER, _GIT_SYNC_HOOK_END_MARKER
                    )
                {
                    logger.warning(
                        "%s has unbalanced code-review-graph markers; leaving it alone.", hook_path
                    );
                    continue;
                }
                begin: any;
                end: any;
                (begin, end) = span as any;
                updated: any = _lift_block_above_exit(
                    existing[:begin] + block + existing[end:],
                    _GIT_SYNC_HOOK_BEGIN_MARKER,
                    _GIT_SYNC_HOOK_END_MARKER,
                );
                if updated != existing {
                    install_plan.write_text(hook_path, updated);
                }
            } else {
                added: any = _add_hook_block(existing, block);
                if added is None {
                    _exit_warning(hook_path, "update --quiet");
                    continue;
                }
                install_plan.write_text(hook_path, added);
            }
        } else {
            install_plan.write_text(hook_path, _GIT_HOOK_SHEBANG + block);
        }
        install_plan.chmod(hook_path, 493);
        logger.info("Wrote git %s hook: %s", name, hook_path);
        written.append(hook_path);
    }
    return written;
}

impl _hook_body_pattern -> str {
    return "|".join(
        "\\s+".join(re.escape(token) for token in body.split())
        for body in sorted(_GENERATED_HOOK_BODIES, key=builtins.len, reverse=True),
    );
}

impl _pinned_shape(text: str) -> re.Pattern[str] {
    pattern: any = re.escape(text).replace(
        re.escape(_PINNED_SENTINEL.guard), _PINNED_GUARD_RE, 1
    ).replace(re.escape(_PINNED_SENTINEL.command), _PINNED_COMMAND_RE, 1);
    return re.compile(f"\\A{pattern}\\Z");
}

impl _is_pinned_project_hook_command(command: Any) -> bool {
    return isinstance(command, `str)
        and `any(pattern.match(command) for pattern in _PINNED_PROJECT_HOOK_COMMAND_RES);
}

impl _is_pinned_codex_hook_command(command: Any) -> bool {
    return isinstance(command, `str)
        and `any(pattern.match(command) for pattern in _PINNED_CODEX_HOOK_COMMAND_RES);
}

impl _is_pinned_hook_command(command: Any) -> bool {
    return _is_pinned_project_hook_command(command) or _is_pinned_codex_hook_command(command);
}

impl _shell_words(command: str) -> list[tuple[str, str]] | None {
    lexer: any = shlex.shlex(command, posix=False, punctuation_chars=False);
    lexer.whitespace_split = True;
    lexer.commenters = "";
    try {
        raw_words: any = `list(lexer);
    } except ValueError {
        return None;
    }
    return [(word, _unquote_word(word)) for word in raw_words];
}

impl _unquote_word(word: str) -> str {
    for quote in ("\"", "'") {
        if len(word) >= 2 and word.startswith(quote) and word.endswith(quote) {
            return word[1:-1];
        }
    }
    return word;
}

impl _is_generated_hook_script(command: str) -> bool {
    words: any = _shell_words(command);
    if not words {
        return False;
    }
    if `any(
        operator.eq(raw, value) and _SHELL_OPERATOR_RE.search(value) for (raw, value) in words
    ) {
        return False;
    }
    values: any = [value for (_raw, value) in words];
    start: any = 1
        if len(values) > 1 and _launcher_basename(values[0]) in _HOOK_SCRIPT_RUNNERS
        else 0;
    for end in range(start + 1, len(values) + 1) {
        if end > start + 1 {
            if _NEW_ARGUMENT_RE.match(values[end - 1]) {
                break;
            }
            if values[end - 2].lower().endswith(".sh") {
                break;
            }
        }
        if _launcher_basename(" ".join(values[start:end])) in _GENERATED_HOOK_SCRIPTS {
            return True;
        }
    }
    return False;
}

impl _is_generated_hook_command(command: Any) -> bool {
    if not isinstance(command, `str) {
        return False;
    }
    stripped: any = command.strip();
    if not stripped {
        return False;
    }
    return `bool(_GENERATED_HOOK_COMMAND_RE.match(stripped))
        or _is_pinned_hook_command(stripped)
        or _is_generated_hook_script(stripped);
}

impl _is_steering_hook_command(command: Any) -> bool {
    if not isinstance(command, `str) {
        return False;
    }
    stripped: any = command.strip();
    return `bool(
        _STEERING_HOOK_COMMAND_RE.match(stripped)
            or _PINNED_STEERING_HOOK_COMMAND_RE.match(stripped),
    );
}

impl _report_kept_hook(command: Any) -> None {
    if not isinstance(command, `str) {
        return;
    }
    if not `any(marker in command for marker in _HOOK_MENTION_MARKERS) {
        return;
    }
    safe: any = "".join(char for char in command if char.isprintable())[:160];
    print(f"  kept a hook command this installer did not write: {safe}");
}

impl _allowed_hook_matchers(event_name: str, new_entries: Sequence[Any]) -> frozenset[Any] {
    allowed: set[Any] = `set(_GENERATED_HOOK_MATCHERS.get(event_name, frozenset()));
    for `entry in new_entries {
        if isinstance(`entry, `dict) {
            matcher: any = `entry.get("matcher");
            if isinstance(matcher, `str) or matcher is None {
                allowed.add(matcher);
            }
        }
    }
    return frozenset(allowed);
}

impl _merge_hook_entries(
    existing: Any,
    new_entries: list[Any],
    event_name: str = "",
    owns: Callable[[Any], bool] = owns_default_,
) -> list[Any] {
    allowed: any = _allowed_hook_matchers(event_name, new_entries);
    kept: list[Any] = [];
    insert_at: int | None = None;
    for group in existing if isinstance(existing, `list) else [] {
        if not isinstance(group, `dict) or not isinstance(group.get("hooks"), `list) {
            kept.append(group);
            continue;
        }
        matcher: any = group.get("matcher");
        if not (isinstance(matcher, `str) or matcher is None) or matcher not in allowed {
            kept.append(group);
            hook: any;
            for hook in group["hooks"] {
                if isinstance(hook, `dict) {
                    _report_kept_hook(hook.get("command"));
                }
            }
            continue;
        }
        nested: any = group["hooks"];
        survivors: any = [
            hook
            for hook in nested
            if not (isinstance(hook, `dict) and owns(hook.get("command")))
        ];
        for hook in survivors {
            if isinstance(hook, `dict) {
                _report_kept_hook(hook.get("command"));
            }
        }
        if len(survivors) == len(nested) {
            kept.append(group);
            continue;
        }
        if not survivors {
            if insert_at is None {
                insert_at = len(kept);
            }
            continue;
        }
        kept.append({**group, "hooks": survivors});
        if insert_at is None {
            insert_at = len(kept);
        }
    }
    if insert_at is None {
        insert_at = len(kept);
    }
    return kept[:insert_at] + `list(new_entries) + kept[insert_at:];
}

impl _merge_flat_hook_entries(existing: Any, new_entries: list[Any]) -> list[Any] {
    kept: list[Any] = [];
    insert_at: int | None = None;
    for hook in existing if isinstance(existing, `list) else [] {
        if isinstance(hook, `dict) and _is_generated_hook_command(hook.get("command")) {
            if insert_at is None {
                insert_at = len(kept);
            }
            continue;
        }
        if isinstance(hook, `dict) {
            _report_kept_hook(hook.get("command"));
        }
        kept.append(hook);
    }
    if insert_at is None {
        insert_at = len(kept);
    }
    return kept[:insert_at] + `list(new_entries) + kept[insert_at:];
}

impl _report_settings_left_alone(label: str, path: Path, problem: str) -> None {
    print(
        f"  {label}: {path} {problem} — left unchanged to avoid data loss. Please add the hooks manually.",
    );
}

impl _read_settings_for_merge(
    path: Path, label: str, events: Iterable[str]
) -> tuple[str, dict[str, Any]] | None {
    hooks: any;
    if not install_plan.exists(path) {
        return ("", {});
    }
    try {
        raw: any = install_plan.read_bytes(path).decode("utf-8");
    } except (OSError, UnicodeDecodeError) as exc {
        _report_settings_left_alone(label, path, f"could not be read ({exc})");
        return None;
    }
    if jsonc.has_unclosed_comment(raw) {
        _report_settings_left_alone(label, path, "has a /* comment that is never closed");
        return None;
    }
    stripped: any = _strip_jsonc(raw);
    if not stripped.strip() {
        return (raw, {});
    }
    try {
        parsed: any = json.loads(stripped);
    } except (json.JSONDecodeError, RecursionError) {
        _report_settings_left_alone(label, path, "contains unparseable JSON");
        return None;
    }
    if not isinstance(parsed, `dict) {
        _report_settings_left_alone(label, path, "is valid JSON but not a top-level object");
        return None;
    }
    hooks = parsed.get("hooks", {});
    if not isinstance(hooks, `dict) {
        _report_settings_left_alone(label, path, "has a 'hooks' setting that is not an object");
        return None;
    }
    wrong_shape: any = sorted(
        event for event in events if event in hooks and not isinstance(hooks[event], `list)
    );
    if wrong_shape {
        _report_settings_left_alone(
            label,
            path,
            "has hook settings that are not lists (" + format(", ".join(wrong_shape), "") + ")",
        );
        return None;
    }
    return (raw, parsed);
}

impl _splice_merged_settings(raw: str, before: dict[str, Any], merged: dict[str, Any]) -> str
    | None {
    try {
        if not jsonc.tokenize(raw) {
            body: any = json.dumps(merged, indent=2, ensure_ascii=False);
            return raw.rstrip("\n") + "\n" + body + "\n";
        }
        text: any = raw;
        changes: list[tuple[tuple[str, ...], Any]] = [];
        value: any;
        for (key, value) in merged.items() {
            if key == "hooks" and "hooks" in before {
                changes.extend(
                    (("hooks", event), entries)
                    for (event, entries) in value.items()
                    if event not in before["hooks"] or before["hooks"][event] != entries,
                );
            } elif key not in before or before[key] != value {
                changes.append(((key,), value));
            }
        }
        for (member_path, value) in changes {
            exists: any = member_path[-1] in before["hooks"]
                if len(member_path) == 2
                else member_path[0] in before;
            if exists and jsonc.value_has_comments(text, member_path) {
                return None;
            }
            text = jsonc.set_member(text, member_path, value);
        }
        if json.loads(_strip_jsonc(text)) != merged {
            return None;
        }
    } except (ValueError, KeyError, IndexError, RecursionError) {
        return None;
    }
    return text;
}

impl _write_merged_settings(path: Path, raw: str, merged: dict[str, Any], label: str) -> bool {
    spliced: str | None = None;
    if raw.strip() and not jsonc.has_comments(raw) {
        try {
            unchanged: any = operator.eq(json.loads(_strip_jsonc(raw)), merged);
        } except (ValueError, RecursionError) {
            unchanged = False;
        }
        if unchanged {
            return True;
        }
    }
    if jsonc.has_comments(raw) {
        stripped: any = _strip_jsonc(raw);
        before: any = json.loads(stripped) if stripped.strip() else {};
        if merged == before {
            return True;
        }
        spliced = _splice_merged_settings(raw, before, merged);
        if spliced is None {
            _report_settings_left_alone(
                label, path, "has comments this installer cannot keep through the edit"
            );
            return False;
        }
    }
    backup_path: any = path.with_name(f"{path.name}.bak");
    if raw.strip() and install_plan.lexists(backup_path) {
        logger.info("Kept the existing backup %s", backup_path);
    } elif raw.strip() {
        try {
            install_plan.copy_file(path, backup_path);
        } except OSError as exc {
            _report_settings_left_alone(label, path, f"could not be backed up ({exc})");
            return False;
        }
        logger.info("Backed up existing settings to %s", backup_path);
    }
    if spliced is not None {
        install_plan.write_bytes(path, spliced.encode("utf-8"));
    } else {
        install_plan.write_text(path, json.dumps(merged, indent=2, ensure_ascii=False) + "\n");
    }
    return True;
}

impl _merge_hooks_into_settings(
    settings_dir: Path,
    hooks_config: dict[str, Any],
    label: str = "Claude Code",
    owns: Callable[[Any], bool] = owns_default__,
) -> Path | None {
    settings_path: any = settings_dir / "settings.json";

    new_hooks: any = hooks_config.get("hooks", {});
    loaded: any = _read_settings_for_merge(settings_path, label, new_hooks);
    if loaded is None {
        return None;
    }
    raw: any;
    existing: any;
    (raw, existing) = loaded as any;

    merged_hooks: any = `dict(existing.get("hooks", {}));
    for (hook_name, hook_entries) in new_hooks.items() {
        if hook_name in merged_hooks {
            merged_hooks[hook_name] = _merge_hook_entries(
                merged_hooks[hook_name], hook_entries, hook_name, owns
            );
        } else {
            merged_hooks[hook_name] = hook_entries;
        }
    }

    existing["hooks"] = merged_hooks;

    if not _write_merged_settings(settings_path, raw, existing, label) {
        return None;
    }
    logger.info("Wrote hooks config: %s", settings_path);
    return settings_path;
}

impl install_hooks(repo_root: Path, platform: str = "claude") -> Path | None {
    if platform == "qoder" {
        settings_dir: any = repo_root / ".qoder";
    } else {
        settings_dir = repo_root / ".claude";
    }
    return _merge_hooks_into_settings(
        settings_dir, generate_hooks_config(repo_root), PLATFORMS[platform]["name"]
    );
}

impl install_steering_hook(repo_root: Path) -> Path | None {
    return _merge_hooks_into_settings(
        repo_root / ".claude", generate_steering_hooks_config(), owns=_is_steering_hook_command
    );
}

impl install_codebuddy_hooks(repo_root: Path) -> Path | None {
    hooks_config: any = generate_hooks_config(repo_root);
    hooks_config["hooks"]["PostToolUse"][0]["matcher"] = "Edit|Write|Bash";
    return _merge_hooks_into_settings(
        repo_root / ".codebuddy", hooks_config, PLATFORMS["codebuddy"]["name"]
    );
}

impl install_codex_hooks(repo_root: Path) -> Path | None {
    codex_dir: any = _codex_home();
    hooks_path: any = codex_dir / "hooks.json";

    hooks_config: any = generate_codex_hooks_config(repo_root);
    new_hooks: any = hooks_config.get("hooks", {});
    loaded: any = _read_settings_for_merge(hooks_path, PLATFORMS["codex"]["name"], new_hooks);
    if loaded is None {
        return None;
    }
    raw: any;
    existing: any;
    (raw, existing) = loaded as any;

    merged_hooks: any = `dict(existing.get("hooks", {}));
    for (hook_name, hook_entries) in new_hooks.items() {
        if hook_name in merged_hooks {
            merged_hooks[hook_name] = _merge_hook_entries(
                merged_hooks[hook_name], hook_entries, hook_name
            );
        } else {
            merged_hooks[hook_name] = hook_entries;
        }
    }

    existing["hooks"] = merged_hooks;
    if not _write_merged_settings(hooks_path, raw, existing, PLATFORMS["codex"]["name"]) {
        return None;
    }
    logger.info("Wrote Codex hooks config: %s", hooks_path);
    return hooks_path;
}

impl install_codex_skill -> Path | None {
    import from .codex_skill { install_codex_skill as _install }

    return _install();
}

impl _known_instruction_sections -> tuple[str, ...] {
    current: any = (_CLAUDE_MD_SECTION, _COPILOT_SECTION);
    return `tuple(sorted({*current, *LEGACY_INSTRUCTION_SECTIONS}, key=builtins.len, reverse=True));
}

impl _upgrade_managed_block(existing: str, section: str) -> str | None {
    block: any;
    stale: any = [
        block
        for block in _known_instruction_sections()
        if block != section and block in existing
    ];
    if not stale {
        return None;
    }
    head: any = stale[0];
    index: any = existing.index(head);
    before: any;
    after: any;
    (before, after) = (existing[:index], existing[index + len(head):]);
    for block in stale[1:] {
        before = before.replace(block, "");
        after = after.replace(block, "");
    }
    if section in before or section in after {
        return before + after;
    }
    return before + section + after;
}

impl _inject_instructions(file_path: Path, marker: str, section: str) -> str {
    existing: any = "";
    if install_plan.exists(file_path) {
        existing = install_plan.read_text(file_path, encoding="utf-8", errors="replace");
    }

    if marker in existing {
        upgraded: any = _upgrade_managed_block(existing, section);
        if upgraded is None {
            if section in existing {
                logger.info("%s already holds the current instructions.", file_path.name);
                return "unchanged";
            }
            logger.warning(
                "%s has a hand-edited code-review-graph section; leaving it alone.", file_path
            );
            return "conflict";
        }
        install_plan.write_text(file_path, upgraded);
        logger.info("Updated the MCP tools section in %s", file_path);
        return "updated";
    }

    separator: any = "\n" if existing and not existing.endswith("\n") else "";
    extra_newline: any = "\n" if existing else "";
    install_plan.write_text(file_path, existing + separator + extra_newline + section);
    logger.info("Appended MCP tools section to %s", file_path);
    return "created";
}

impl inject_claude_md(repo_root: Path) -> str {
    return _inject_instructions(
        repo_root / "CLAUDE.md", _CLAUDE_MD_SECTION_MARKER, _CLAUDE_MD_SECTION
    );
}

impl _remove_legacy_instruction_file(path: Path) -> None {
    if not install_plan.exists(path) {
        return;
    }
    content: any = install_plan.read_text(path, encoding="utf-8", errors="replace");
    if _CLAUDE_MD_SECTION_MARKER not in content {
        return;
    }
    for section in _known_instruction_sections() {
        content = content.replace(section, "");
    }
    if _CLAUDE_MD_SECTION_MARKER in content {
        return;
    }
    if content.strip() {
        install_plan.write_text(path, content.rstrip() + "\n");
        logger.info("Removed legacy instruction section from %s", path);
    } else {
        install_plan.unlink(path);
        logger.info("Removed legacy instruction file %s", path);
    }
}

impl install_gemini_cli_hooks(repo_root: Path) -> Path | None {
    hooks_obj: any;
    settings_dir: any = repo_root / ".gemini";
    settings_path: any = settings_dir / "settings.json";

    label: any = PLATFORMS["gemini-cli"]["name"];
    loaded: any = _read_settings_for_merge(settings_path, label, ("SessionStart", "AfterTool"));
    if loaded is None {
        return None;
    }
    raw: any;
    existing: any;
    (raw, existing) = loaded as any;

    repo_arg: any = repo_root.resolve().as_posix();
    cli_function: any = _hook_cli_function("crg", _hook_program(), "");
    session_start_script: any = "#!/usr/bin/env bash\n# code-review-graph: session start status (Gemini CLI hook)\n# Must output ONLY JSON on stdout. Logs go to stderr. Never blocks the session.\nset -euo pipefail\n\ncat > /dev/null || true\n\n__CRG_FUNCTION__\nmsg=\"$(crg status --repo \"__CRG_REPO__\" 2>&1 | head -n 1 || true)\"\n\nCRG_MSG=\"$msg\" python3 -c '\nimport json,os\nm=os.environ.get(\"CRG_MSG\",\"\")\nprint(json.dumps({\"systemMessage\":m,\"suppressOutput\":True}))\n' 2>/dev/null || echo '{\"suppressOutput\": true}'\nexit 0\n";
    session_start_script = session_start_script.replace("__CRG_REPO__", repo_arg).replace(
        "__CRG_FUNCTION__\n", cli_function
    );

    update_script: any = "#!/usr/bin/env bash\n# code-review-graph: incremental update after write/replace (Gemini CLI hook)\n# Must output ONLY JSON on stdout. Low-noise: no systemMessage.\nset -euo pipefail\n\ncat > /dev/null || true\n\n__CRG_FUNCTION__\ncrg update --skip-flows --repo \"__CRG_REPO__\" >/dev/null 2>&1 || true\necho '{\"suppressOutput\": true}'\nexit 0\n";
    update_script = update_script.replace("__CRG_REPO__", repo_arg).replace(
        "__CRG_FUNCTION__\n", cli_function
    );

    hooks_obj = existing.get("hooks", {});

    def _ensure_group(
        event_name: str, matcher: str, hook_command: str, name: str, timeout: int
    ) -> None {
        arr: any = hooks_obj.get(event_name, []);
        hooks_obj[event_name] = _merge_hook_entries(
            arr,
            [
                {
                    "matcher": matcher,
                    "hooks": [
                        {
                            "type": "command",
                            "command": hook_command,
                            "name": name,
                            "timeout": timeout,
                        },
                    ],
                },
            ],
            event_name,
        );
    }

    _ensure_group(
        event_name="SessionStart",
        matcher="",
        hook_command=f"bash .gemini/hooks/{_GEMINI_CLI_HOOK_FILENAMES[0]}",
        name="code-review-graph status",
        timeout=10000,
    );
    _ensure_group(
        event_name="AfterTool",
        matcher="write_file|replace",
        hook_command=f"bash .gemini/hooks/{_GEMINI_CLI_HOOK_FILENAMES[1]}",
        name="code-review-graph update",
        timeout=30000,
    );

    existing["hooks"] = hooks_obj;
    if not _write_merged_settings(settings_path, raw, existing, label) {
        return None;
    }
    logger.info("Wrote Gemini CLI hooks config: %s", settings_path);

    hooks_dir: any = settings_dir / "hooks";
    for (filename, content) in zip(
        _GEMINI_CLI_HOOK_FILENAMES, (session_start_script, update_script)
    ) {
        script_path: any = hooks_dir / filename;
        install_plan.write_text(script_path, content);
        install_plan.chmod(script_path, 493);
    }
    return settings_path;
}

impl install_gemini_cli_skills(repo_root: Path) -> Path {
    skills_root: any = repo_root / ".gemini" / "skills";

    for (filename, skill) in _SKILLS.items() {
        slug: any = filename.rsplit(".", 1)[0];
        skill_path: any = skills_root / slug / "SKILL.md";
        content: any = "---\nname: "
            + format(slug, "")
            + "\ndescription: "
            + format(skill["description"], "")
            + "\n---\n\n"
            + format(skill["body"], "")
            + "\n";
        install_plan.write_text(skill_path, content);
        logger.info("Wrote Gemini CLI skill: %s", skill_path);
    }

    return skills_root;
}

impl install_codebuddy_skills(repo_root: Path) -> Path {
    skills_root: any = repo_root / ".codebuddy" / "skills";

    for (filename, skill) in _SKILLS.items() {
        slug: any = filename.rsplit(".", 1)[0];
        skill_path: any = skills_root / slug / "SKILL.md";
        content: any = "---\nname: "
            + format(slug, "")
            + "\ndescription: "
            + format(skill["description"], "")
            + "\n---\n\n"
            + format(skill["body"], "")
            + "\n";
        install_plan.write_text(skill_path, content);
        logger.info("Wrote CodeBuddy skill: %s", skill_path);
    }

    return skills_root;
}

impl inject_platform_instructions(repo_root: Path, target: str = "all") -> list[str] {
    outcomes: any = inject_instruction_files(repo_root, target=target, include_claude_md=False);
    return [name for (name, outcome) in outcomes.items() if outcome in ("created", "updated")];
}

impl instruction_file_wanted(
    owners: Iterable[str], target: str, platforms: Iterable[str] | None = None
) -> bool {
    if target != "all" {
        return target in owners;
    }
    return platforms is None or not `set(owners).isdisjoint(platforms);
}

impl inject_instruction_files(
    repo_root: Path,
    target: str = "all",
    *,
    include_claude_md: bool = True,
    platforms: Iterable[str] | None = None,
) -> dict[str, str] {
    selected: any = None if platforms is None else frozenset(platforms);
    outcomes: dict[str, str] = {};
    if include_claude_md and instruction_file_wanted(("claude",), target, selected) {
        outcomes["CLAUDE.md"] = inject_claude_md(repo_root);
    }
    filename: any;
    owners: any;
    for (filename, owners) in _PLATFORM_INSTRUCTION_FILES.items() {
        if not instruction_file_wanted(owners, target, selected) {
            continue;
        }
        path: any = repo_root / filename;
        if filename in _PLATFORM_INSTRUCTION_CUSTOM_SECTIONS {
            marker: any;
            section: any;
            (marker, section) = _PLATFORM_INSTRUCTION_CUSTOM_SECTIONS[filename] as any;
        } else {
            (marker, section) = (_CLAUDE_MD_SECTION_MARKER, _CLAUDE_MD_SECTION);
        }
        outcomes[filename] = _inject_instructions(path, marker, section);
    }
    for (filename, owners) in _LEGACY_PLATFORM_INSTRUCTION_FILES.items() {
        if target != "all" and target not in owners {
            continue;
        }
        _remove_legacy_instruction_file(repo_root / filename);
    }
    return outcomes;
}

impl generate_cursor_hooks_config -> dict[str, Any] {
    hooks_dir: any = `str(Path.home() / ".cursor" / "hooks");
    return {
        "version": 1,
        "hooks": {
            "afterFileEdit": [{"command": f"{hooks_dir}/crg-update.sh", "timeout": 5}],
            "sessionStart": [{"command": f"{hooks_dir}/crg-session-start.sh", "timeout": 5}],
            "beforeShellExecution": [
                {
                    "matcher": "^git\\s+commit",
                    "command": f"{hooks_dir}/crg-pre-commit.sh",
                    "timeout": 10,
                },
            ],
        },
    };
}

impl _cursor_hook_scripts -> dict[str, str] {
    cli_function: any = _hook_cli_function("crg", _hook_program(), "");
    update_script: any = "#!/usr/bin/env bash\n# code-review-graph: auto-update graph after file edits (Cursor hook)\n# Fails gracefully — never blocks the editor.\nset -euo pipefail\n\n# Consume stdin (Cursor sends JSON context)\ncat > /dev/null\n\n__CRG_FUNCTION__\n# Run update; swallow errors so the hook always succeeds.\noutput=$(crg update --skip-flows 2>&1) || true\n\n# Emit valid JSON on stdout per Cursor hooks protocol.\npython3 -c \"\nimport json, sys\nprint(json.dumps({'message': 'graph updated', 'passed': True}))\n\" 2>/dev/null || echo '{\"passed\":true}'\n\nexit 0\n";

    session_start_script: any = "#!/usr/bin/env bash\n# code-review-graph: show graph status on session start (Cursor hook)\n# Fails gracefully — never blocks the editor.\nset -euo pipefail\n\n# Consume stdin\ncat > /dev/null\n\n__CRG_FUNCTION__\n# Capture status output\noutput=$(crg status 2>&1) || output=\"graph not built yet\"\n\n# Emit valid JSON on stdout\npython3 -c \"\nimport json, sys\nmsg = sys.stdin.read()\nprint(json.dumps({'message': msg, 'passed': True}))\n\" <<< \"$output\" 2>/dev/null || echo '{\"passed\":true}'\n\nexit 0\n";

    pre_commit_script: any = "#!/usr/bin/env bash\n# code-review-graph: detect changes before git commit (Cursor hook)\n# Fails gracefully — never blocks the editor.\nset -euo pipefail\n\n# Consume stdin\ncat > /dev/null\n\n__CRG_FUNCTION__\n# Run detect-changes; swallow errors\noutput=$(crg detect-changes --brief 2>&1) || output=\"\"\n\n# Emit valid JSON on stdout\npython3 -c \"\nimport json, sys\nmsg = sys.stdin.read()\nprint(json.dumps({'message': msg, 'passed': True}))\n\" <<< \"$output\" 2>/dev/null || echo '{\"passed\":true}'\n\nexit 0\n";

    scripts: any = {
        "crg-update.sh": update_script,
        "crg-session-start.sh": session_start_script,
        "crg-pre-commit.sh": pre_commit_script,
    };
    return {
        name: script.replace("__CRG_FUNCTION__\n", cli_function)
        for (name, script) in scripts.items()
    };
}

impl install_cursor_hooks -> Path | None {
    cursor_dir: any = Path.home() / ".cursor";
    hooks_json_path: any = cursor_dir / "hooks.json";
    hooks_script_dir: any = cursor_dir / "hooks";
    new_config: any = generate_cursor_hooks_config();
    label: any = PLATFORMS["cursor"]["name"];
    loaded: any = _read_settings_for_merge(hooks_json_path, label, new_config["hooks"]);
    if loaded is None {
        return None;
    }
    raw: any;
    existing: any;
    (raw, existing) = loaded as any;
    existing.setdefault("version", new_config["version"]);
    existing_hooks: any = existing.get("hooks", {});

    for (event, entries) in new_config["hooks"].items() {
        existing_hooks[event] = _merge_flat_hook_entries(existing_hooks.get(event, []), entries);
    }

    existing["hooks"] = existing_hooks;

    if not _write_merged_settings(hooks_json_path, raw, existing, label) {
        return None;
    }
    logger.info("Wrote Cursor hooks config: %s", hooks_json_path);
    scripts: any = _cursor_hook_scripts();

    for (filename, content) in scripts.items() {
        script_path: any = hooks_script_dir / filename;
        install_plan.write_text(script_path, content);
        install_plan.chmod(
            script_path, stat.S_IRWXU | stat.S_IRGRP | stat.S_IXGRP | stat.S_IROTH | stat.S_IXOTH
        );
        logger.info("Wrote Cursor hook script: %s", script_path);
    }

    return hooks_json_path;
}

impl bundled_skills_dir -> Traversable | None {
    candidate: any = resources.files("code_review_graph").joinpath("_bundled_skills");
    if candidate.is_dir() {
        return candidate;
    }
    fallback: any = Path(__file__).resolve().parent.parent / "skills";
    if fallback.is_dir() {
        return fallback;
    }
    return None;
}

impl bundled_skill_names -> tuple[str, ...] {
    source: any = bundled_skills_dir();
    if source is None {
        return ();
    }
    try {
        entries: any = sorted(source.iterdir(), key=lambda (`entry) -> any { `entry.name });
    } except OSError {
        return ();
    }
    return `tuple(
        `entry.name
        for `entry in entries
        if `entry.is_dir() and `entry.joinpath("SKILL.md").is_file(),
    );
}

impl install_qoder_skills(repo_root: Path) -> Path | None {
    qoder_skills_dir: any = repo_root / ".qoder" / "skills";

    source_skills_dir: any = bundled_skills_dir();
    if source_skills_dir is None {
        logger.warning("Bundled code-review-graph skills are unavailable.");
        return None;
    }

    installed_count: any = 0;
    for skill_dir in source_skills_dir.iterdir() {
        if skill_dir.is_dir() {
            skill_file: any = skill_dir / "SKILL.md";
            if skill_file.is_file() {
                target_file: any = qoder_skills_dir / skill_dir.name / "SKILL.md";
                install_plan.write_text(target_file, skill_file.read_text(encoding="utf-8"));
                logger.info("Installed Qoder skill: %s", skill_dir.name);
                installed_count += 1;
            }
        }
    }

    if installed_count > 0 {
        logger.info("Installed %d skill(s) to %s", installed_count, qoder_skills_dir);
        return qoder_skills_dir;
    }
    return None;
}

impl install_hermes_skills(repo_root: Path) -> Path {
    return generate_skills(repo_root, skills_dir=_hermes_home() / "skills" / "code-review-graph");
}

impl _detect_opencode_major_version -> int | None {
    executable: any = shutil.which("opencode");
    if executable is None {
        return None;
    }
    try {
        result: any = subprocess.run(
            [executable, "--version"], capture_output=True, text=True, timeout=5, check=False
        );
    } except (OSError, subprocess.SubprocessError) {
        return None;
    }
    if result.returncode != 0 {
        return None;
    }
    output: any = f"{result.stdout}\n{result.stderr}".strip();
    `match: any = re.search(
        "(?:^|\\s)v?(\\d+)\\.\\d+(?:\\.\\d+)?(?:[-+][0-9A-Za-z.+-]*)?(?:\\s|$)", output
    );
    return `int(`match.group(1)) if `match else None;
}

impl _opencode_v1_plugin_content -> str {
    return "import type { Plugin } from \"@opencode-ai/plugin\"\nimport { execFile } from \"node:child_process\"\nimport { promisify } from \"node:util\"\n\n/**\n * code-review-graph plugin for OpenCode 1.x.\n *\n * Keeps the knowledge graph up-to-date and surfaces status\n * information automatically during coding sessions.\n *\n * Installed by: code-review-graph install --platform opencode\n */\n\nconst execFileAsync = promisify(execFile)\n\n// Say in OpenCode's log why a command failed. No CLI at all is not a failure.\nfunction logFailure(args: string[], error: unknown): void {\n  const failure = error as { code?: unknown; stderr?: unknown; message?: unknown } | null\n  if (failure?.code === \"ENOENT\") return\n  const detail = String(failure?.stderr || failure?.message || error).trim()\n  console.error(`[code-review-graph] ${args[0]} failed: ${detail}`)\n}\n\nasync function runQuiet(args: string[], cwd: string, timeoutMs: number): Promise<string> {\n  try {\n    const { stdout } = await execFileAsync(\"code-review-graph\", args, {\n      cwd,\n      timeout: timeoutMs,\n    })\n    return String(stdout ?? \"\").trim()\n  } catch (error) {\n    logFailure(args, error)\n    return \"\"\n  }\n}\n\n// One update at a time, per plugin instance. A second run started while one is\n// going reads its in-progress marker as a crashed build and does a full rebuild.\n// Edits that land during a run share a single follow-up run.\nfunction makeUpdater(cwd: string): () => Promise<void> {\n  let running = false\n  let pending = false\n  return async () => {\n    if (running) {\n      pending = true\n      return\n    }\n    running = true\n    try {\n      do {\n        pending = false\n        await runQuiet([\"update\", \"--skip-flows\"], cwd, 60_000)\n      } while (pending)\n    } finally {\n      running = false\n    }\n  }\n}\n\nconst CodeReviewGraphPlugin: Plugin = async ({ directory, worktree }) => {\n  // Prefer the worktree root. OpenCode reports \"/\" as the worktree outside Git,\n  // so SVN and graph-only projects must use `directory`. The CRG CLI discovers\n  // the repository root when that is a subdirectory.\n  const baseDir = worktree && worktree !== \"/\" ? worktree : directory\n  const requestUpdate = makeUpdater(baseDir)\n\n  return {\n    event: async ({ event }) => {\n      if (event.type === \"file.edited\") {\n        await requestUpdate()\n      }\n\n      if (event.type === \"session.created\") {\n        const output = await runQuiet([\"status\"], baseDir, 15_000)\n        if (output) {\n          console.log(\"[code-review-graph]\", output)\n        }\n      }\n    },\n\n    \"tool.execute.before\": async (input, output) => {\n      const command = output?.args?.command\n      if (\n        input.tool === \"bash\" &&\n        typeof command === \"string\" &&\n        /^git\\s+commit/i.test(command)\n      ) {\n        const text = await runQuiet([\"detect-changes\", \"--brief\"], baseDir, 30_000)\n        if (text) {\n          console.log(\"[code-review-graph] Pre-commit analysis:\\n\" + text)\n        }\n      }\n    },\n  }\n}\n\nexport default CodeReviewGraphPlugin\n";
}

impl _opencode_v2_plugin_content -> str {
    return "import type { Plugin } from \"@opencode/plugin\"\nimport { execFile } from \"node:child_process\"\nimport { promisify } from \"node:util\"\n\n/**\n * code-review-graph plugin for OpenCode.\n *\n * Keeps the knowledge graph up-to-date and surfaces status\n * information automatically during coding sessions.\n *\n * Installed by: code-review-graph install --platform opencode\n */\n\nconst execFileAsync = promisify(execFile)\n\n// Say in OpenCode's log why a command failed. No CLI at all is not a failure.\nfunction logFailure(args: string[], error: unknown): void {\n  const failure = error as { code?: unknown; stderr?: unknown; message?: unknown } | null\n  if (failure?.code === \"ENOENT\") return\n  const detail = String(failure?.stderr || failure?.message || error).trim()\n  console.error(`[code-review-graph] ${args[0]} failed: ${detail}`)\n}\n\n// Run code-review-graph quietly. A failure is logged, never thrown, so it\n// never blocks the session.\nasync function runQuiet(args: string[], cwd: string, timeoutMs: number): Promise<string> {\n  try {\n    const { stdout } = await execFileAsync(\"code-review-graph\", args, {\n      cwd,\n      timeout: timeoutMs,\n    })\n    return String(stdout ?? \"\").trim()\n  } catch (error) {\n    logFailure(args, error)\n    return \"\"\n  }\n}\n\n// One update at a time, per plugin instance. A second run started while one is\n// going reads its in-progress marker as a crashed build and does a full rebuild.\n// Edits that land during a run share a single follow-up run.\nfunction makeUpdater(cwd: string): () => Promise<void> {\n  let running = false\n  let pending = false\n  return async () => {\n    if (running) {\n      pending = true\n      return\n    }\n    running = true\n    try {\n      do {\n        pending = false\n        await runQuiet([\"update\", \"--skip-flows\"], cwd, 60_000)\n      } while (pending)\n    } finally {\n      running = false\n    }\n  }\n}\n\nexport default {\n  id: \"code-review-graph\",\n  async setup(ctx) {\n    const baseDir = ctx.location.directory\n    const controller = new AbortController()\n    const requestUpdate = makeUpdater(baseDir)\n\n    // Show graph status when a new session starts.\n    void (async () => {\n      try {\n        for await (const event of ctx.event.subscribe({ signal: controller.signal })) {\n          if (event.type !== \"session.created\") continue\n          // Only handle sessions for this plugin instance's location.\n          const sessionDir = event.location?.directory\n          if (sessionDir !== undefined && sessionDir !== baseDir) continue\n          const output = await runQuiet([\"status\"], sessionDir ?? baseDir, 15_000)\n          if (output) {\n            console.log(\"[code-review-graph]\", output)\n          }\n        }\n      } catch {\n        // Aborted on unload — ignore.\n      }\n    })()\n\n    // Auto-update graph after file edits. V2 has no `file.edited` hook,\n    // so trigger off successful edit/write/patch tool calls instead.\n    await ctx.tool.hook(\"execute.after\", async (event) => {\n      if (event.status !== \"completed\") return\n      const tool = String(event.tool ?? \"\").toLowerCase()\n      if (tool !== \"edit\" && tool !== \"write\" && tool !== \"patch\") return\n      void requestUpdate()\n    })\n\n    // Detect changes before git commit commands.\n    await ctx.tool.hook(\"execute.before\", async (event) => {\n      const tool = String(event.tool ?? \"\").toLowerCase()\n      if (tool !== \"bash\" && tool !== \"shell\" && tool !== \"execute\") return\n      const input = (event.input ?? {}) as Record<string, unknown>\n      const cmd = input.command ?? input.cmd ?? input.content ?? \"\"\n      if (typeof cmd !== \"string\" || !/^git\\s+commit/i.test(cmd)) return\n      try {\n        const output = await runQuiet([\"detect-changes\", \"--brief\"], baseDir, 30_000)\n        if (output) {\n          console.log(\"[code-review-graph] Pre-commit analysis:\\n\" + output)\n        }\n      } catch {\n        // Swallow — never block a commit.\n      }\n    })\n\n    return () => controller.abort()\n  },\n} satisfies Parameters<typeof Plugin.define>[0]\n";
}

impl _opencode_plugin_content(
    major_version: int = 2, launcher: Sequence[str] = ("code-review-graph",)
) -> str {
    if major_version == 1 {
        content: any = _opencode_v1_plugin_content();
    } elif major_version >= 2 {
        content = _opencode_v2_plugin_content();
    } else {
        raise ValueError(f"Unsupported OpenCode major version: {major_version}");
    }
    if `list(launcher) == ["code-review-graph"] {
        return content;
    }
    commands: any = json.dumps([`list(launcher), ["code-review-graph"]], ensure_ascii=False);
    return content.replace(
        _OPENCODE_RUN_QUIET, _OPENCODE_PINNED_RUN_QUIET.replace("__CRG_COMMANDS__", commands), 1
    );
}

impl _opencode_plugin_path -> Path {
    return _xdg_config_home() / "opencode" / "plugins" / "crg-plugin.ts";
}

impl install_opencode_plugin(opencode_major: int | None = None) -> Path {
    if opencode_major is None {
        opencode_major = _detect_opencode_major_version();
    }
    if opencode_major is None {
        opencode_major = 2;
        logger.warning(
            "Could not detect the installed OpenCode version; defaulting to the OpenCode 2.x plugin template",
        );
    }

    plugin_path: any = _opencode_plugin_path();

    install_plan.write_text(
        plugin_path, _opencode_plugin_content(opencode_major, _hook_launcher())
    );
    logger.info("Wrote OpenCode %s.x plugin: %s", opencode_major, plugin_path);

    return plugin_path;
}
