"""Claude Code skills and hooks auto-install.

Generates Claude Code agent skill files, hooks configuration, and
CLAUDE.md integration for seamless code-review-graph usage.
Also supports multi-platform MCP server installation and
Cursor hooks / OpenCode plugin generation.
"""

import builtins;

import operator;

import from __future__ { annotations }

import json;

import logging;

import os;

import platform;

import re;

import shlex;

import shutil;

import stat;

import subprocess;

import sys;

import from importlib { resources }

import from pathlib { Path }

import from typing { TYPE_CHECKING, Any, Callable, Iterable, NamedTuple, Sequence }

glob logger: any;

glob PLATFORMS: dict[str, dict[str, Any]];

glob _UV_CACHE_ENV_RE: any;

glob _GENERATED_ENTRY_FIELDS: any;

glob _GENERATED_ENTRY_TYPES: any;

glob _GENERATED_SERVE_ARGV: dict[tuple[str, ...], frozenset[str]];

glob _PYTHON_LAUNCHER_RE: any;

glob _SKILLS: dict[str, dict[str, str]];

glob DOCUMENTARY_SKILLS: dict[str, dict[str, str]];

glob _PATH_GUARD: any;

glob _PATH_HOOK_PROGRAM: any;

glob _UVX_HOOK_PROGRAM: any;

glob _PLUGIN_WORKTREE_BUILD_COMMAND: any;

glob _CODEX_UPDATE_SUBCOMMAND: any;

glob _GIT_HOOK_BEGIN_MARKER: any;

glob _GIT_HOOK_END_MARKER: any;

glob _GIT_HOOK_NOTE: any;

glob _GIT_HOOK_SHEBANG: any;

glob _GIT_HOOK_BODY: any;

glob _LEGACY_GIT_HOOK_BLOCKS: tuple[str, ...];

glob _TOP_LEVEL_EXIT_RE: any;

glob _SHELL_LINE_CONTINUATIONS: any;

glob _GIT_SYNC_HOOK_BEGIN_MARKER: any;

glob _GIT_SYNC_HOOK_END_MARKER: any;

glob _GIT_SYNC_HOOK_NOTE: any;

glob _GIT_SYNC_HOOK_NAMES: any;

glob _GIT_SYNC_HOOK_CONDITIONS: any;

glob _SHELL_INTERPRETERS: any;

glob _GENERATED_HOOK_SCRIPTS: any;

glob _HOOK_SCRIPT_RUNNERS: any;

glob _GENERATED_HOOK_BODIES: any;

glob _GENERATED_HOOK_COMMAND_RE: any;

glob _STEERING_HOOK_COMMAND_RE: any;

glob _PINNED_EXE_RE: any;

glob _PINNED_GUARD_RE: any;

glob _PINNED_COMMAND_RE: any;

glob _PINNED_SENTINEL: any;

glob _PINNED_PROJECT_HOOK_COMMAND_RES: any;

glob _PINNED_CODEX_HOOK_COMMAND_RES: any;

glob _PINNED_STEERING_HOOK_COMMAND_RE: any;

glob _HOOK_MENTION_MARKERS: any;

glob _GENERATED_HOOK_MATCHERS: dict[str, frozenset[str | None]];

glob _SHELL_OPERATOR_RE: any;

glob _NEW_ARGUMENT_RE: any;

glob _CLAUDE_MD_SECTION_MARKER: any;

glob _CLAUDE_MD_SECTION_END_MARKER: any;

glob _INSTRUCTION_INTRO: any;

glob _INSTRUCTION_GUARDRAILS: any;

glob _CLAUDE_MD_SECTION: any;

glob _COPILOT_SECTION: any;

glob _PLATFORM_INSTRUCTION_CUSTOM_SECTIONS: dict[str, tuple[str, str]];

glob _PLATFORM_INSTRUCTION_FILES: dict[str, tuple[str, ...]];

glob _LEGACY_PLATFORM_INSTRUCTION_FILES: dict[str, tuple[str, ...]];

glob _GEMINI_CLI_HOOK_FILENAMES: any;

glob _OPENCODE_RUN_QUIET: any;

glob _OPENCODE_PINNED_RUN_QUIET: any;

with entry {
    logger = logging.getLogger(__name__);
}

"""Return the Zed settings.json path for the current OS."""
def _zed_settings_path -> Path;

"""Return whether a GitHub Copilot extension is installed for VS Code."""
def _copilot_vscode_detected -> bool;

"""Return ``$XDG_CONFIG_HOME``, or ``~/.config`` when it is not set."""
def _xdg_config_home -> Path;

"""Return where a desktop app keeps its user data on this OS."""
def _app_data_dirs(app: str) -> list[Path];

"""Return ``$XDG_DATA_HOME``, or ``~/.local/share`` when it is not set."""
def _xdg_data_home -> Path;

"""Return whether Claude Code is on this machine, or this runs inside it."""
def _claude_code_detected -> bool;

"""Return whether OpenCode is on PATH or has left a folder in the home folder.

    Its install script puts the program in ``~/.opencode/bin``, which a shell
    started before the install has not added to PATH yet, and OpenCode keeps
    its config and its data in the XDG folders on every OS.
    """
def _opencode_detected -> bool;

"""Return whether the Qoder editor or its CLI is on this machine."""
def _qoder_detected -> bool;

"""Return whether CodeBuddy Code is on PATH or has a user config folder."""
def _codebuddy_detected -> bool;

"""Return the Hermes Agent home directory.

    Mirrors Hermes' own resolution order: the ``HERMES_HOME`` environment
    variable wins, otherwise the platform-native default (``%LOCALAPPDATA%\\hermes``
    on Windows, ``~/.hermes`` elsewhere).
    """
def _hermes_home -> Path;

"""Return the Hermes Agent config file (``config.yaml``)."""
def _hermes_config_path -> Path;

"""Return the DeepSeek Harness home, as DSH resolves it.

    ``DSH_HOME`` wins when it is not blank; otherwise ``~/.dsh`` on every
    platform (DSH's ``@deepseek-ai/dsh-home-paths``).
    """
def _dsh_home -> Path;

"""Return DSH's home-level patch layer, which every DSH profile applies."""
def _dsh_config_path -> Path;

"""Return both OpenCode project configs. OpenCode loads each one."""
def _opencode_config_paths(repo_root: Path) -> tuple[Path, Path];

"""Return OpenCode's existing project config, preferring JSONC."""
def _opencode_config_path(repo_root: Path) -> Path;

"""Return MiMo Code's global config folder.

    Mirrors MiMo's own lookup: ``$MIMOCODE_HOME/config`` when that is an
    absolute path, otherwise ``mimocode`` under ``$XDG_CONFIG_HOME``
    (default ``~/.config``).
    """
def _mimo_config_home -> Path;

"""Return both MiMo project configs, in the order MiMo Code loads them.

    MiMo reads ``.mimocode/mimocode.json`` and then ``.mimocode/mimocode.jsonc``,
    so an entry in either file is live.
    """
def _mimo_config_paths(repo_root: Path) -> tuple[Path, Path];

"""Return the MiMo project config install writes to.

    An existing ``mimocode.jsonc`` wins, because MiMo loads it last.
    """
def _mimo_config_path(repo_root: Path) -> Path;

with entry {
    PLATFORMS = {
        "codex": {
            "name": "Codex",
            "config_path": lambda (`root) -> any { _codex_home() / "config.toml" },
            "key": "mcp_servers",
            "detect": lambda -> any {
                `bool(os.environ.get("CODEX_HOME", "").strip())
                    or _codex_home().exists()
                    or `bool(shutil.which("codex"))
            },
            "format": "toml",
            "needs_type": True,
        },
        "claude": {
            "name": "Claude Code",
            "config_path": lambda (`root) -> any { `root / ".mcp.json" },
            "key": "mcpServers",
            "detect": _claude_code_detected,
            "format": "object",
            "needs_type": True,
        },
        "cursor": {
            "name": "Cursor",
            "config_path": lambda (`root) -> any { `root / ".cursor" / "mcp.json" },
            "key": "mcpServers",
            "detect": lambda -> any { (Path.home() / ".cursor").exists() },
            "format": "object",
            "needs_type": True,
        },
        "windsurf": {
            "name": "Windsurf",
            "config_path": lambda (`root) -> any {
                Path.home() / ".codeium" / "windsurf" / "mcp_config.json"
            },
            "key": "mcpServers",
            "detect": lambda -> any { (Path.home() / ".codeium" / "windsurf").exists() },
            "format": "object",
            "needs_type": False,
        },
        "zed": {
            "name": "Zed",
            "config_path": lambda (`root) -> any { _zed_settings_path() },
            "key": "context_servers",
            "detect": lambda -> any { _zed_settings_path().parent.exists() },
            "format": "object",
            "needs_type": False,
        },
        "continue": {
            "name": "Continue",
            "config_path": lambda (`root) -> any { Path.home() / ".continue" / "config.json" },
            "key": "mcpServers",
            "detect": lambda -> any { (Path.home() / ".continue").exists() },
            "format": "array",
            "needs_type": True,
        },
        "opencode": {
            "name": "OpenCode",
            "config_path": _opencode_config_path,
            "config_paths": _opencode_config_paths,
            "key": "mcp",
            "detect": _opencode_detected,
            "format": "object",
            "needs_type": False,
        },
        "mimo": {
            "name": "MiMo Code",
            "config_path": _mimo_config_path,
            "config_paths": _mimo_config_paths,
            "key": "mcp",
            "detect": lambda -> any { `bool(shutil.which("mimo")) or _mimo_config_home().exists() },
            "format": "object",
            "needs_type": False,
        },
        "antigravity": {
            "name": "Antigravity",
            "config_path": lambda (`root) -> any {
                Path.home() / ".gemini" / "antigravity" / "mcp_config.json"
            },
            "key": "mcpServers",
            "detect": lambda -> any { (Path.home() / ".gemini" / "antigravity").exists() },
            "format": "object",
            "needs_type": False,
        },
        "gemini-cli": {
            "name": "Gemini CLI",
            "config_path": lambda (`root) -> any { `root / ".gemini" / "settings.json" },
            "key": "mcpServers",
            "detect": lambda -> any {
                `bool(shutil.which("gemini")) or (Path.home() / ".gemini").exists()
            },
            "format": "object",
            "needs_type": False,
        },
        "qwen": {
            "name": "Qwen Code",
            "config_path": lambda (`root) -> any { Path.home() / ".qwen" / "settings.json" },
            "key": "mcpServers",
            "detect": lambda -> any { (Path.home() / ".qwen").exists() },
            "format": "object",
            "needs_type": True,
        },
        "kiro": {
            "name": "Kiro",
            "config_path": lambda (`root) -> any { `root / ".kiro" / "settings" / "mcp.json" },
            "key": "mcpServers",
            "detect": lambda -> any { (Path.home() / ".kiro").exists() },
            "format": "object",
            "needs_type": True,
        },
        "qoder": {
            "name": "Qoder",
            "config_path": lambda (`root) -> any { `root / ".qoder" / "mcp.json" },
            "key": "mcpServers",
            "detect": _qoder_detected,
            "format": "object",
            "needs_type": True,
        },
        "copilot": {
            "name": "GitHub Copilot",
            "config_path": lambda (`root) -> any { `root / ".vscode" / "mcp.json" },
            "key": "servers",
            "detect": _copilot_vscode_detected,
            "format": "object",
            "needs_type": True,
        },
        "copilot-cli": {
            "name": "GitHub Copilot CLI",
            "config_path": lambda (`root) -> any { Path.home() / ".copilot" / "mcp-config.json" },
            "key": "mcpServers",
            "legacy_keys": ("servers",),
            "detect": lambda -> any { (Path.home() / ".copilot").exists() },
            "format": "object",
            "needs_type": True,
            "server_type": "local",
            "entry_fields": {"tools": ["*"]},
        },
        "hermes": {
            "name": "Hermes Agent",
            "config_path": lambda (`root) -> any { _hermes_config_path() },
            "key": "mcp_servers",
            "detect": lambda -> any { _hermes_home().exists() },
            "format": "yaml",
            "needs_type": False,
        },
        "dsh": {
            "name": "DeepSeek Harness",
            "config_path": lambda (`root) -> any { _dsh_config_path() },
            "key": "insert",
            "detect": lambda -> any { _dsh_home().exists() },
            "format": "dsh-patch",
            "needs_type": False,
        },
        "codebuddy": {
            "name": "CodeBuddy Code",
            "config_path": lambda (`root) -> any { `root / ".mcp.json" },
            "key": "mcpServers",
            "detect": _codebuddy_detected,
            "format": "object",
            "needs_type": True,
        },
    };
}

"""Return Codex's active state directory, honoring ``CODEX_HOME``."""
def _codex_home -> Path;

"""Return True when the running interpreter is a Poetry-managed virtualenv.

    Two signals are checked so that **both** ``poetry shell`` and ``poetry run``
    are detected:

    * ``POETRY_ACTIVE=1`` — set by ``poetry shell`` when the user activates the
      virtual environment interactively.
    * ``VIRTUAL_ENV`` containing ``"pypoetry"`` — set by **both** ``poetry shell``
      and ``poetry run`` because Poetry stores its virtualenvs under a path that
      includes the string ``pypoetry`` (e.g.
      ``~/.cache/pypoetry/virtualenvs/<name>`` on Linux/macOS or
      ``%LOCALAPPDATA%\\pypoetry\\Cache\\virtualenvs\\<name>`` on Windows).

    Checking only ``POETRY_ACTIVE`` would miss the ``poetry run`` case, which is
    the primary scenario described in issue #256.
    """
def _in_poetry_project -> bool;

"""Return True if ``sys.executable`` lives inside a uv-managed project.

    A project is considered uv-managed when a ``uv.lock`` file exists in any
    ancestor directory of the running Python interpreter (stopping at the home
    directory to avoid false positives on system-wide installations).
    """
def _in_uv_project -> bool;

with entry {
    _UV_CACHE_ENV_RE = re.compile("\\A(?:archive|builds)-v[0-9]+\\Z");
}

"""Return True when this copy was started by ``uvx`` or installed by ``uv tool``.

    ``uv tool install`` leaves a ``uv-receipt.toml`` in the tool's environment.
    ``uvx`` without an installed tool runs from a folder in uv's cache. Either
    way, ``uvx code-review-graph`` starts this same copy again.
    """
def _running_from_uv_tool -> bool;

"""Return the command line that runs the copy of ``code-review-graph`` running now.

    The MCP entry and every hook ``install`` writes start with it, so they
    all run the copy that ran ``install``, not whichever one is first on PATH.

    1. **Poetry** – ``POETRY_ACTIVE=1`` or ``VIRTUAL_ENV`` contains ``"pypoetry"``
       (``poetry shell`` and ``poetry run``), and ``poetry`` is on PATH
       → ``poetry run code-review-graph``
    2. **uv project** – ``UV_PROJECT_ENVIRONMENT`` is set, or a ``uv.lock``
       is found above ``sys.executable``, and ``uv`` is on PATH
       → ``uv run code-review-graph``
    3. **uvx or a uv tool** – this copy runs from ``uvx`` or ``uv tool install``,
       and ``uvx`` is on PATH → ``uvx code-review-graph``
    4. **Anything else** – the interpreter running now
       → ``sys.executable -m code_review_graph``

    Step 4 is always safe: ``sys.executable`` is the exact interpreter running
    this copy, in any virtual environment, conda env or system Python. Up to
    2.4.0 step 3 picked ``uvx`` whenever it was on PATH, which could start an
    older ``uv tool`` copy than the one ``pip`` had just installed.
    """
def _detect_cli_launcher -> list[str];

"""Return ``(command, args)`` that launches ``code-review-graph serve``.

    It is :func:`_detect_cli_launcher` followed by ``serve``.
    """
def _detect_serve_command -> tuple[str, list[str]];

"""Build the MCP server entry for a platform."""
def _build_server_entry(
    plat: dict[str, Any], key: str = "", repo_root: "Path | None" = None
) -> dict[str, Any];

with entry {
    _GENERATED_ENTRY_FIELDS = frozenset({"name", "type", "command", "args", "cwd", "tools", "env"});
    _GENERATED_ENTRY_TYPES = frozenset({"stdio", "local"});
    _GENERATED_SERVE_ARGV = {
        ("code-review-graph", "serve"): frozenset({"uvx"}),
        ("serve",): frozenset({"code-review-graph"}),
        ("run", "code-review-graph", "serve"): frozenset({"poetry", "uv"}),
        ("-m", "code_review_graph", "serve"): frozenset({"python"}),
    };
    _PYTHON_LAUNCHER_RE = re.compile("\\Apythonw?[0-9]*(?:\\.[0-9]+)*\\Z");
}

"""Return the bare program name of a command token, without ``.exe``."""
def _launcher_basename(token: str) -> str;

"""Flatten an MCP entry's command and args into one token list."""
def _entry_command_tokens(`entry: dict[str, Any]) -> list[str] | None;

"""Return True when ``entry`` is an MCP registration this project wrote.

    Recognition is by the exact shapes this project emits, not by equality with
    the entry the running version would write: an older release pinned an
    absolute interpreter path and a checkout that no longer exists, and exactly
    that entry has to be replaced rather than kept. Everything else under our
    name -- a field this project never writes, a transport it never uses, a
    command line someone tuned by hand -- counts as the user's own and is left
    alone. Mentioning ``code-review-graph`` somewhere on the command line is
    not enough; the whole argument vector has to be one this project wrote.
    """
def _is_generated_server_entry(`entry: Any) -> bool;

"""Say that a hand-written entry under our name was deliberately kept."""
def _report_user_owned_entry(config_path: Path, label: str = "") -> None;

"""Warn without modifying the obsolete Cursor-shaped OpenCode config."""
def _warn_legacy_opencode_config(repo_root: Path) -> None;

"""Return the TOML reader for this interpreter (``tomli`` before 3.11)."""
def _load_tomllib -> Any;

"""Format a primitive Python value as TOML."""
def _format_toml_value(value: Any) -> str;

"""Return whether ``line`` opens the TOML table named by ``table_path``."""
def _toml_header_matches(line: str, table_path: tuple[str, ...]) -> bool;

"""Return the ``(start, end)`` line span of a TOML table, or None.

    ``end`` stops just past the table's last key line. The trailing run of
    comment and blank lines before the next table header is deliberately left
    outside the span: in TOML a comment sitting above ``[next.table]`` belongs
    to that table, and swallowing it into the replaced region silently deletes
    something the user wrote (``# DO NOT REMOVE`` above an unrelated server,
    or a free-standing note at the end of the file). This project never writes
    a comment inside its own table, so nothing of ours is stranded by stopping
    early.
    """
def _toml_table_span(lines: list[str], table_path: tuple[str, ...]) -> tuple[int, int] | None;

"""Write a Codex MCP server table without clobbering the rest of the file.

    An entry a previous release wrote is replaced in place rather than treated
    as up to date, so a stale absolute interpreter path or a dead ``cwd`` does
    not survive a reinstall. A hand-written entry is never rewritten.

    Returns True when the file was (or would be) modified, False when no edit
    is needed, and None when the edit was refused -- because it would lose
    data, or because the table belongs to the user and only they can change it.
    """
def _merge_toml_mcp_server(
    config_path: Path, server_name: str, server_entry: dict[str, Any], dry_run: bool = False
) -> bool | None;

"""Return ``(header_index, end_index)`` for a top-level block mapping ``key``.

    ``end_index`` is the index just past the last line belonging to the block
    (blank lines and comments trailing the block are excluded so an insertion
    lands inside it). Returns ``None`` when the key is absent or is not a
    block mapping (e.g. ``key: {}`` written in flow style).
    """
def _yaml_section_bounds(lines: list[str], key: str) -> tuple[int, int] | None;

"""Return the child indentation used inside a block, defaulting to 2."""
def _yaml_block_indent(lines: list[str], start: int, end: int) -> int;

"""Return the line span of the child mapping ``name`` inside a block.

    Only a child written at the block's own indentation is matched, and the
    span runs to the last line indented deeper than it, so replacing the span
    cannot swallow a sibling entry.
    """
def _yaml_child_bounds(lines: list[str], start: int, end: int, name: str) -> tuple[int, int] | None;

"""Add an MCP server to a YAML config without reformatting the rest.

    The file is edited as text rather than round-tripped through a YAML
    dumper: Hermes' ``config.yaml`` is hand-edited and full of comments,
    anchors, and deliberate ordering that a dump would destroy. The parsed
    document is only used to decide *whether* an edit is needed, and the
    result is re-parsed before writing so a malformed edit is never saved.

    Returns True when the file was (or would be) modified, False when the
    entry is already present, and None when the edit was refused -- to avoid
    data loss, or because the entry belongs to the user (the reason is
    printed).
    """
def _merge_yaml_mcp_server(
    config_path: Path,
    server_key: str,
    server_name: str,
    server_entry: dict[str, Any],
    dry_run: bool = False,
) -> bool | None;

"""Add the MCP client row to DSH's home patch layer, keeping the rest as it is.

    Same contract as :func:`_merge_yaml_mcp_server`: True when the file was
    (or, in a plan, would be) changed, False when the row is already there,
    None when the edit was refused (the reason is printed).
    """
def _merge_dsh_patch_server(config_path: Path, server_entry: dict[str, Any]) -> bool | None;

"""Indent every non-empty line of ``text`` by ``indent`` spaces."""
def _indent_block(text: str, indent: int) -> str;

"""Strip JSONC comments and trailing commas without corrupting string values.

    Editors like Zed accept non-standard JSON (``//`` and ``/* */`` comments,
    trailing commas). To merge such a config we must reduce it to strict JSON
    first. A naive regex pass cannot tell structure from data: it would delete a
    comma inside ``"foo, bar"`` or truncate a ``"https://..."`` URL at the
    ``//``. This walks the text character by character, tracking whether we are
    inside a double-quoted string (respecting ``\\`` escapes), and only removes
    comments and trailing commas that appear in structural position. Content
    inside string values is preserved verbatim. (GH #553)
    """
def _strip_jsonc(text: str) -> str;

"""Apply this install's edits to a JSONC file without losing its comments.

    Parsing a commented config, mutating the dict and dumping it back deletes
    every comment and every hand-made formatting choice in the file, which is a
    silent loss of something the user wrote. Only the members this install
    actually touches are spliced into the original text; everything else is
    copied through byte for byte.

    Returns None when the edit cannot be expressed as a splice, so the caller
    can leave the file alone instead of flattening it. Array-shaped configs
    (Continue) are refused for the same reason: this project has no positional
    splice for them.
    """
def _splice_commented_config(
    raw: str,
    server_key: str,
    server_entry: dict[str, Any] | None,
    removals: list[tuple[str, ...]],
    *,
    array_format: bool,
    document: dict[str, Any],
) -> str | None;

"""Return the platforms whose MCP config ``install`` writes for ``target``.

    ``"all"`` means every detected platform, plus Kiro when the repository has
    a ``.kiro`` folder. An unknown name gives an empty mapping.
    """
def platforms_for_target(repo_root: Path, target: str) -> dict[str, dict[str, Any]];

"""Return the platform keys ``install`` writes anything for.

    A named platform is written whether or not it is found here. ``"all"``
    means the platforms found on this machine (see :func:`platforms_for_target`).
    Skills, hooks and instruction files follow the same selection as the MCP
    entries, so nothing is written for a tool that is not there.
    """
def selected_platforms(repo_root: Path, target: str) -> frozenset[str];

"""Install MCP config for one or all detected platforms.

    Args:
        repo_root: Project root directory.
        target: Platform key or "all".
        dry_run: If True, print what would be done without writing. Inside an
            active :func:`install_plan.planning` block the would-be writes go
            into that plan, so the caller can show them.
        platforms: With ``target="all"``, the keys already worked out by
            :func:`selected_platforms`, so detection runs once per install.

    Returns:
        List of platform names that were configured.
    """
def install_platform_configs(
    repo_root: Path,
    target: str = "all",
    dry_run: bool = False,
    platforms: Iterable[str] | None = None,
) -> list[str];

"""Do the work of :func:`install_platform_configs`.

    Writes go through :mod:`install_plan`, so under a dry run (always inside a
    plan here) they are held in memory and shown, never written.
    """
def _install_platform_configs(
    repo_root: Path, target: str, dry_run: bool, platforms: Iterable[str] | None = None
) -> list[str];

with entry {
    _SKILLS = {
        "explore-codebase.md": {
            "name": "explore-codebase",
            "description": "Navigate and understand codebase structure using the knowledge graph",
            "body": "## Explore Codebase\n\nUse the code-review-graph MCP tools to find your way around the codebase.\n\n### Steps\n\n1. Call `get_architecture_overview_tool` for the community structure. Call `list_communities_tool`, then `get_community_tool`, only for the modules you need.\n2. Call `semantic_search_nodes_tool` to find a function or class by name or keyword. Pass `include_source=True, expand_neighbors=True` to get the code of the hits and their direct callers and callees, so you need not open the files. Leave `detail_level` at its default for this call: `minimal` drops the source.\n3. Call `query_graph_tool` with `callers_of`, `callees_of` or `imports_of` to trace relationships. `children_of` on a file lists its functions and classes, and `path_to` with `to` shows how one symbol reaches another.\n4. Call `list_flows_tool`, then `get_flow_tool` for one flow, to follow an execution path.\n5. Call `find_large_functions_tool` to find oversized functions.\n6. Call `list_graph_stats_tool` only when you need node, edge and language counts.\n\n## Token Efficiency Rules\n- Call `get_minimal_context_tool(task=\"<your task>\")` before any other graph tool.\n- Pass `detail_level=\"minimal\"` unless it is not enough. Minimal drops source, so leave `semantic_search_nodes_tool(include_source=True)` and `get_review_context_tool` at standard.\n- Prefer a targeted `query_graph_tool` call over a broad listing call.\n- Budget: about five tool calls per task. Source snippets stand in for file reads.\n- Read the implementation and its tests before changing code. The graph narrows scope; it does not replace the source.",
        },
        "review-changes.md": {
            "name": "review-changes",
            "description": "Perform a structured code review using change detection and impact",
            "body": "## Review Changes\n\nReview a change set with risk scores and blast radius from the knowledge graph.\n\n### Steps\n\n1. Call `detect_changes_tool` for risk-scored changed functions, test gaps and affected flows.\n2. Call `get_affected_flows_tool(detail_level=\"standard\")` only when you need the steps of an affected flow; `minimal` returns no steps.\n3. For each high-risk function, call `query_graph_tool` with `pattern=\"tests_for\"` to check test coverage.\n4. Call `get_impact_radius_tool` when the blast radius is not clear from step 1.\n5. Suggest specific test cases for untested changes.\n\n### Output Format\n\nGroup findings by risk level (high, medium, low). For each finding give what changed and why it matters, its test coverage, and the suggested fix. End with a merge recommendation.\n\n## Token Efficiency Rules\n- Call `get_minimal_context_tool(task=\"<your task>\")` before any other graph tool.\n- Pass `detail_level=\"minimal\"` unless it is not enough. Minimal drops source, so leave `semantic_search_nodes_tool(include_source=True)` and `get_review_context_tool` at standard.\n- Prefer a targeted `query_graph_tool` call over a broad listing call.\n- Budget: about five tool calls per task. Source snippets stand in for file reads.\n- Read the implementation and its tests before changing code. The graph narrows scope; it does not replace the source.",
        },
        "debug-issue.md": {
            "name": "debug-issue",
            "description": "Systematically debug issues using graph-powered code navigation",
            "body": "## Debug Issue\n\nTrace a bug through the knowledge graph before reading source.\n\n### Steps\n\n1. Call `semantic_search_nodes_tool` to find code related to the issue.\n2. Call `query_graph_tool` with `callers_of` and `callees_of` to trace the call chain in both directions.\n3. Call `get_flow_tool` for the execution path that reaches the suspect code. Its entry point is where the bug is triggered.\n4. Call `detect_changes_tool` to check whether a recent change caused the issue.\n5. Call `get_impact_radius_tool` on the suspect files to see what a fix would affect.\n\n## Token Efficiency Rules\n- Call `get_minimal_context_tool(task=\"<your task>\")` before any other graph tool.\n- Pass `detail_level=\"minimal\"` unless it is not enough. Minimal drops source, so leave `semantic_search_nodes_tool(include_source=True)` and `get_review_context_tool` at standard.\n- Prefer a targeted `query_graph_tool` call over a broad listing call.\n- Budget: about five tool calls per task. Source snippets stand in for file reads.\n- Read the implementation and its tests before changing code. The graph narrows scope; it does not replace the source.",
        },
        "refactor-safely.md": {
            "name": "refactor-safely",
            "description": "Plan and execute safe refactoring using dependency analysis",
            "body": "## Refactor Safely\n\nPlan a refactor from the dependency graph and apply renames from a preview.\n\n### Steps\n\n1. Call `refactor_tool` with `mode=\"suggest\"` for refactoring candidates, or `mode=\"dead_code\"` for unreferenced code.\n2. For a rename, call `refactor_tool` with `mode=\"rename\"`, `old_name` and `new_name`. Check the returned edit list before applying.\n3. Call `apply_refactor_tool` with the returned `refactor_id` to apply the rename.\n4. Before a large refactor, call `get_impact_radius_tool` and `get_affected_flows_tool` to see the dependents and critical paths involved.\n5. Call `find_large_functions_tool` to find functions worth splitting.\n6. After the change, call `detect_changes_tool` to confirm the impact matches the plan.\n\n## Token Efficiency Rules\n- Call `get_minimal_context_tool(task=\"<your task>\")` before any other graph tool.\n- Pass `detail_level=\"minimal\"` unless it is not enough. Minimal drops source, so leave `semantic_search_nodes_tool(include_source=True)` and `get_review_context_tool` at standard.\n- Prefer a targeted `query_graph_tool` call over a broad listing call.\n- Budget: about five tool calls per task. Source snippets stand in for file reads.\n- Read the implementation and its tests before changing code. The graph narrows scope; it does not replace the source.",
        },
    };
}

"""Generate Claude Code skill files.

    Creates `.claude/skills/` directory with 4 skill markdown files,
    each containing frontmatter and instructions.

    Args:
        repo_root: Repository root directory.
        skills_dir: Custom skills directory. Defaults to repo_root/.claude/skills.

    Returns:
        Path to the skills directory.
    """
def generate_skills(repo_root: Path, skills_dir: Path | None = None) -> Path;

with entry {
    DOCUMENTARY_SKILLS = {
        "build-graph": {
            "description": "Build or update the code review knowledge graph. Run this first to initialise, or let hooks keep it updated automatically.",
            "argument_hint": "[full]",
            "title": "Build Graph",
            "body": "Build or incrementally update the knowledge graph for this repository.\n\n## Steps\n\n1. Call `list_graph_stats_tool`. If `last_updated` is null, the graph has never been built.\n2. For a first build, or when the argument is `full`, call `build_or_update_graph_tool(full_rebuild=True)`. Otherwise call `build_or_update_graph_tool()` for an incremental update.\n3. Report the response: `status` (`ok`, `partial` or `error`) and `summary`. `contended` means another build of this repository is running; retry once it finishes.\n\n## When to Use\n\n- First set-up of a repository, or after a branch switch or large refactor.\n- When the graph looks stale. Hooks installed by `code-review-graph install` run an update after each edit, before each commit and after a branch switch, merge or rebase, so manual builds are rarely needed.\n\n## Notes\n\n- The database is `.code-review-graph/graph.db` in the repository root.\n- Binary files, dependency and build directories, and patterns in `.code-review-graphignore` are skipped.\n- For the list of supported languages call `get_docs_section_tool(section_name=\"languages\")`.",
        },
        "review-delta": {
            "description": "Review only changes since last commit using impact analysis. Token-efficient delta review with automatic blast-radius detection.",
            "argument_hint": "[file or function name]",
            "title": "Review Delta",
            "body": "Review only the changed code and its blast radius.\n\n## Steps\n\n1. Call `get_minimal_context_tool(task=\"review changes\")`. If it returns `status: not_ready`, call `build_or_update_graph_tool()` and continue.\n2. Call `detect_changes_tool(detail_level=\"minimal\")` for risk-scored changed functions, test gaps and affected flows. Changes come from `git diff` against `HEAD~1`; if the argument names a file, pass it in `changed_files`.\n3. Call `get_review_context_tool()` (standard detail: `minimal` returns no source and no `review_guidance`) when you need source snippets for the changed areas and `review_guidance` (untested functions, wide blast radius, inheritance changes).\n4. For each untested high-risk function, confirm with `query_graph_tool(pattern=\"tests_for\", target=\"<function>\")`.\n5. Use `detail_level=\"standard\"` only for a high-risk item the minimal output leaves unclear. Do not load whole files unless a snippet is not enough.\n\n## Report\n\n- Summary: one line\n- Risk: low, medium or high, from the blast radius\n- Issues: bugs, missing tests, style\n- Blast radius: impacted files and functions\n- Recommendations",
        },
        "review-pr": {
            "description": "Review a PR or branch diff using the knowledge graph for full structural context. Outputs a structured review with blast-radius analysis.",
            "argument_hint": "[PR number or branch name]",
            "title": "Review PR",
            "body": "Review all commits of a pull request or branch against its base branch.\n\n## Steps\n\n1. The graph tools read the files on disk, so check out what you review first: `git switch <branch>`, or for a PR `git fetch origin pull/<n>/head:pr-<n>` then `git switch pr-<n>`, then call `build_or_update_graph_tool()`. Diff it against `main` (or `master`) with `git diff --name-only main...HEAD`, and use that ref as `base` below.\n2. Call `get_minimal_context_tool(task=\"review PR\", base=\"main\")`. If it returns `status: not_ready`, call `build_or_update_graph_tool()` and continue.\n3. Call `detect_changes_tool(base=\"main\", detail_level=\"minimal\")` for risk-scored changed functions, test gaps and affected flows across the whole branch.\n4. For high-risk functions call `query_graph_tool(pattern=\"callers_of\", target=\"<function>\")` and `query_graph_tool(pattern=\"tests_for\", target=\"<function>\")`. Flag public API changes whose callers were not updated.\n5. Call `get_review_context_tool(base=\"main\")` for source snippets, or `get_impact_radius_tool(base=\"main\")` for the full dependent list, only when step 3 leaves a high-risk item unclear.\n6. Read the changed source of the highest-impact files first. Do not load whole files unless the change needs it.\n\n## Output\n\n```\n## PR Review: <title>\n\n### Summary\n<1-3 sentences>\n\n### Risk\n- Overall: Low / Medium / High\n- Blast radius: <n> files, <m> functions\n- Test coverage: <covered> of <changed> changed functions\n\n### Files\n#### <path>\n- Changes: <what>\n- Impact: <who depends on it>\n- Issues: <bugs, style, concerns>\n\n### Missing Tests\n- <function> in <file>\n\n### Recommendations\n1. <action>\n```\n\n## Tips\n\n- Use `semantic_search_nodes_tool` to find related code the PR may have missed.",
        },
    };
}

"""Render the checked-in markdown for a documentation-driven skill.

    Raises:
        KeyError: *slug* is not one of ``DOCUMENTARY_SKILLS``.
    """
def render_documentary_skill_markdown(slug: str) -> str;

"""Generate the documentation-driven skills under ``skills/``.

    ``DOCUMENTARY_SKILLS`` is the source of these files: edit the text there,
    then run ``scripts/generate_documentary_skills.py``.

    Args:
        repo_root: Repository root directory.
        skills_dir: Custom skills directory. Defaults to repo_root/skills.

    Returns:
        Path to the skills directory.
    """
def generate_documentary_skills(repo_root: Path, skills_dir: Path | None = None) -> Path;

"""How a hook starts code-review-graph: a shell test, then the words that run it."""
class _HookProgram(NamedTuple) {
    has guard: str;

    has command: str;
}

with entry {
    _PATH_GUARD = "command -v code-review-graph >/dev/null 2>&1";
    _PATH_HOOK_PROGRAM = _HookProgram(_PATH_GUARD, "code-review-graph");

    _UVX_HOOK_PROGRAM = _HookProgram("command -v uvx >/dev/null 2>&1", "uvx code-review-graph");
}

"""Quote ``value`` as one POSIX shell word, always in single quotes."""
def _sh_single_quote(value: str) -> str;

"""Return the command line hooks use to start the copy running now.

    ``uvx`` when :func:`_detect_cli_launcher` picks it. Otherwise the running
    interpreter by its absolute path, also inside a Poetry or uv project: a
    hook can run in any folder, where ``poetry run`` or ``uv run`` would find
    another project, or none.
    """
def _hook_launcher -> list[str];

"""Return :func:`_hook_launcher` as the shell test and words a hook uses."""
def _hook_program -> _HookProgram;

"""Run ``body`` with ``program``, else with the copy on PATH, else ``otherwise``.

    ``body`` takes the words that start code-review-graph.
    """
def _hook_chain(body: Callable[[str], str], program: _HookProgram, otherwise: str = "") -> str;

"""Print the graph status in a Git checkout, and say so outside one."""
def _session_status_body(cli: str) -> str;

"""The body up to 2.4.0, kept so hooks that carry it are still ours.

    A failing ``status``, as in a Git repo with no graph, also printed
    "Not a git repo".
    """
def _legacy_session_status_body(cli: str) -> str;

"""The edit hook: hand the event JSON to ``hook-update``, then drain the rest.

    Draining means a large payload never meets a closed pipe (#493). It never
    fails the edit: not when the CLI is missing, not when an older CLI has no
    ``hook-update``, not when the update itself fails.
    """
def _claude_update_hook_command(program: _HookProgram) -> str;

glob body_default_: any;

with entry {
    body_default_ = _session_status_body;
}

"""The session hook: print the graph status of the repository it starts in."""
def _claude_session_hook_command(
    program: _HookProgram, body: Callable[[str], str] = body_default_
) -> str;

with entry {
    _PLUGIN_WORKTREE_BUILD_COMMAND = f"cat >/dev/null || true; {_PATH_GUARD} || exit 0; if git rev-parse --git-dir >/dev/null 2>&1; then code-review-graph build >/dev/null 2>&1 & fi";
}

"""Forward the event JSON to a payload-scoped subcommand when the CLI exists."""
def _codex_hook_command(subcommand: str, program: _HookProgram | None = None) -> str;

"""Define shell function ``name``: ``program`` if it is there, else the copy on PATH.

    Hook scripts call it in place of ``code-review-graph``. When neither copy
    is there it fails with 127, as a missing command would.
    """
def _shell_cli_function(name: str, program: _HookProgram, indent: str = "") -> str;

"""Generate Claude Code hooks configuration.

    Hooks use the v1.x+ schema: each entry needs a ``matcher`` and a nested
    ``hooks`` array. Timeouts are in seconds. ``PreCommit`` is not a valid
    Claude Code event — pre-commit checks are handled by ``install_git_hook``.

    The ``repo_root`` parameter is retained for backward compatibility but is
    not embedded in hook commands. The edit hook passes the event JSON to
    ``hook-update``, which updates the repository that holds the edited file
    rather than the one the session started in (#311). The session hook
    resolves its repository with ``git rev-parse --show-toplevel``.

    ``program`` is the copy the hooks run, by default the one running now (see
    :func:`_hook_program`). When it is gone, as on a collaborator's machine
    that shares ``settings.json``, they run the copy on PATH, and exit
    silently when there is none (#549).
    """
def generate_hooks_config(repo_root: Path, program: _HookProgram | None = None) -> dict[str, Any];

"""Return what ``hooks/hooks.json``, the Claude Code plugin's hooks, holds.

    The plugin cannot know which copy a user has, so its hooks run the one on
    PATH. Beside the hooks ``install`` writes, it builds a graph in a
    worktree Claude Code enters.
    """
def generate_plugin_hooks_config -> dict[str, Any];

"""Generate the opt-in Claude Code hook that runs ``code-review-graph enrich``.

    It adds graph context beside each search and read, which changes what the
    model sees on every one of them, so ``install`` writes it only when asked.
    ``|| true`` matters: exit code 2 from a PreToolUse hook stops the tool call,
    and a failed lookup must never do that. Claude Code is the only client whose
    hook output ``enrich`` writes. ``program`` is as for :func:`generate_hooks_config`.
    """
def generate_steering_hooks_config(program: _HookProgram | None = None) -> dict[str, Any];

with entry {
    _CODEX_UPDATE_SUBCOMMAND = "hook-update --existing-only";
}

"""Generate native Codex hooks configuration for the active Codex home.

    ``program`` is as for :func:`generate_hooks_config`.
    """
def generate_codex_hooks_config(
    repo_root: Path, program: _HookProgram | None = None
) -> dict[str, Any];

with entry {
    _GIT_HOOK_BEGIN_MARKER = "# >>> code-review-graph pre-commit hook >>>";
    _GIT_HOOK_END_MARKER = "# <<< code-review-graph pre-commit hook <<<";
    _GIT_HOOK_NOTE = "# Installed by code-review-graph. Remove this file to disable pre-commit graph checks.";

    _GIT_HOOK_SHEBANG = "#!/bin/sh\n";
    _GIT_HOOK_BODY = "if command -v code-review-graph >/dev/null 2>&1; then\n    crg_hook_git_dir=$(git rev-parse --absolute-git-dir 2>/dev/null) || crg_hook_git_dir=\"\"\n    crg_hook_root=$(git rev-parse --show-toplevel 2>/dev/null) || crg_hook_root=\"\"\n    if [ -z \"$crg_hook_git_dir\" ] || [ -z \"$crg_hook_root\" ]; then\n        echo \"code-review-graph: skipping automatic checks; cannot determine the Git worktree.\" >&2\n    elif [ -f \"$crg_hook_git_dir/commondir\" ] && [ \"$CRG_HOOK_WORKTREES\" != \"1\" ]; then\n        # Only a linked worktree's git dir carries a commondir file (Git 2.5+),\n        # so this needs no rev-parse options newer than --absolute-git-dir.\n        echo \"code-review-graph: skipping automatic checks in a linked worktree;\" \\\n            \"set CRG_HOOK_WORKTREES=1 to keep a graph for this worktree too.\" >&2\n    else\n        code-review-graph update --repo \"$crg_hook_root\" || true\n        code-review-graph detect-changes --brief --repo \"$crg_hook_root\" || true\n    fi\nfi\n";
}

"""A shell test that is true when ``program`` or the copy on PATH is there."""
def _any_copy_guard(program: _HookProgram) -> str;

"""Define ``name`` to run ``program``, or the copy on PATH when it is gone."""
def _hook_cli_function(name: str, program: _HookProgram, indent: str) -> str;

"""Return the pre-commit body: update the graph quietly, then show the risk summary.

    It runs ``program``, by default the copy running now (see ``_hook_program``),
    or the copy on PATH when that one is gone.
    """
def _git_hook_body(program: _HookProgram | None = None) -> str;

"""Return the whole marked pre-commit block, as ``install`` writes it."""
def _git_hook_block(program: _HookProgram | None = None) -> str;

with entry {
    _LEGACY_GIT_HOOK_BLOCKS = (
        f"{_GIT_HOOK_NOTE}\nif command -v code-review-graph >/dev/null 2>&1; then\n    code-review-graph detect-changes --brief || true\nfi\n",
        f"{_GIT_HOOK_NOTE}\nif command -v code-review-graph >/dev/null 2>&1; then\n    code-review-graph update || true\n    code-review-graph detect-changes --brief || true\nfi\n",
        f"{_GIT_HOOK_NOTE}\n{_GIT_HOOK_BODY}",
    );
}

"""Every unmarked hook block this project has generated, longest first.

    Longest first matters: a shorter variant contained in a longer one must
    never win the match and strand the tail.
    """
def _known_git_hook_blocks -> tuple[str, ...];

glob begin_marker_default_: any;

glob end_marker_default_: any;

with entry {
    begin_marker_default_ = _GIT_HOOK_BEGIN_MARKER;
    end_marker_default_ = _GIT_HOOK_END_MARKER;
}

"""Return whether every begin marker in ``text`` has its own end marker.

    A begin marker with no end marker after it, or a second begin marker
    opening before the first one closes, means the block was hand-edited. There
    is then no trustworthy boundary, so callers must refuse rather than guess
    where the block stops.
    """
def _git_hook_markers_balanced(
    text: str, begin_marker: str = begin_marker_default_, end_marker: str = end_marker_default_
) -> bool;

glob begin_marker_default__: any;

glob end_marker_default__: any;

with entry {
    begin_marker_default__ = _GIT_HOOK_BEGIN_MARKER;
    end_marker_default__ = _GIT_HOOK_END_MARKER;
}

"""Return ``(begin, end)`` offsets of one marked block, or None.

    ``end`` is just past the block's trailing newline, so slicing the span out
    leaves no blank line behind.
    """
def _git_hook_block_span(
    text: str,
    start: int = 0,
    begin_marker: str = begin_marker_default__,
    end_marker: str = end_marker_default__,
) -> tuple[int, int] | None;

"""Return ``existing`` with a block we wrote replaced by the current one.

    Returns None when the hook carries our marker but no block this project
    recognises, meaning it was hand-edited and must be left alone. An
    unbalanced marker pair is one such case: falling through to the unmarked
    matcher there would strip the body and leave the orphan marker line
    sitting in the user's hook.
    """
def _upgrade_git_hook_block(existing: str, program: _HookProgram | None = None) -> str | None;

with entry {
    _TOP_LEVEL_EXIT_RE = re.compile("exit(?:[ \\t]+(?P<arg>[^\\s#;]+))?[ \\t]*;?[ \\t]*(?:#.*)?");
    _SHELL_LINE_CONTINUATIONS = ("\\", "&&", "||", "|");
}

"""Return whether ``line`` is blank or only a comment."""
def _is_shell_filler(line: str) -> bool;

"""Find the top-level ``exit`` a shell hook ends with, if any.

    Returns ``(offset, safe)``: where the ``exit`` line starts, and whether
    code put just before it leaves the hook's exit status alone. A bare
    ``exit`` or ``exit $?`` passes on the last command's status, so it is not
    safe. None when the hook does not end with such a line, or when the
    ``exit`` belongs to the command on the line before (``check ||`` then
    ``exit 1``).
    """
def _trailing_exit(text: str) -> tuple[int, bool] | None;

"""Return a user's shell hook with ``block`` added where it will run.

    That is the end, or just before a top-level ``exit`` the hook ends with,
    since the shell stops there. None when the block would change what the
    hook exits with (see ``_trailing_exit``): the caller leaves it alone.
    """
def _add_hook_block(existing: str, block: str) -> str | None;

"""Move a marked block that sits after a hook's final ``exit`` to just before it.

    Earlier releases appended the block after it, where it never ran. Text
    the user wrote after the block, or an ``exit`` that is not safe to move
    past, keeps the block where it is.
    """
def _lift_block_above_exit(text: str, begin_marker: str, end_marker: str) -> str;

def _exit_warning(hook_path: Path, command: str) -> None;

"""Return the directory git runs hooks from, or None when there is none.

    Resolved via ``git rev-parse --git-path hooks`` so linked worktrees,
    submodules and ``core.hooksPath`` are honoured, with the legacy
    ``.git/hooks`` lookup as the fallback when git itself is unavailable.
    """
def _git_hooks_dir(repo_root: Path) -> Path | None;

"""Install a git pre-commit hook that prints a risk summary before each commit.

    Called automatically by ``code-review-graph install``.
    The hooks directory is resolved via ``git rev-parse --git-path hooks`` so
    the hook lands where git actually runs it — including linked worktrees
    and submodules (where ``.git`` is a file, not a directory) and repos with
    ``core.hooksPath`` set (issue #313). ``core.hooksPath`` users with their
    own hook manager (husky, pre-commit) may prefer integrating the
    ``code-review-graph`` commands into that manager manually instead.

    Creates ``pre-commit`` if it doesn't exist, or appends to an existing
    one — the hook is appended, not overwritten, preserving any hooks
    already there. A hook that ends with a top-level ``exit`` gets the block
    just before that line, where it still runs. Falls back to the legacy
    ``.git/hooks`` resolution when git itself is unavailable. Returns None
    when no hooks directory can be determined. A block written by any past
    release is upgraded in place, and a hand-edited one is left alone. The
    installed hook skips automatic checks in linked worktrees, where an
    implicit update could build a duplicate graph for a different branch;
    ``CRG_HOOK_WORKTREES=1`` opts a worktree back in.
    Detection relies only on ``git rev-parse --absolute-git-dir`` (Git 2.13),
    not on newer options.
    """
def install_git_hook(repo_root: Path) -> Path | None;

with entry {
    _GIT_SYNC_HOOK_BEGIN_MARKER = "# >>> code-review-graph sync hook >>>";
    _GIT_SYNC_HOOK_END_MARKER = "# <<< code-review-graph sync hook <<<";
    _GIT_SYNC_HOOK_NOTE = "# Installed by code-review-graph. Keeps the graph in sync after checkout, merge and rebase.";
    _GIT_SYNC_HOOK_NAMES = ("post-checkout", "post-merge", "post-rewrite");
    _GIT_SYNC_HOOK_CONDITIONS = {
        "post-checkout": "[ \"$3\" = \"1\" ] && ",
        "post-merge": "",
        "post-rewrite": "",
    };
}

"""Return the marked block that ``hook_name`` runs to update the graph.

    It runs ``program``, by default the copy running now (see ``_hook_program``),
    or the copy on PATH when that one is gone.
    """
def _git_sync_hook_block(hook_name: str, program: _HookProgram | None = None) -> str;

with entry {
    _SHELL_INTERPRETERS = frozenset({"sh", "bash", "dash", "zsh", "ksh", "ash"});
}

"""Return whether a shell block can be appended to this hook script.

    Git runs a hook with no shebang through ``/bin/sh``, so that counts as
    shell. Otherwise the interpreter named by the shebang decides, looking
    through ``/usr/bin/env`` and its options.
    """
def _is_shell_hook(text: str) -> bool;

"""Install post-checkout, post-merge and post-rewrite hooks that run ``update``.

    Called automatically by ``code-review-graph install`` next to
    :func:`install_git_hook`, and resolves the hooks directory the same way.
    Each block is appended to an existing hook, never overwriting it (just
    before a final top-level ``exit``, so it runs), and a block written by an
    earlier release is replaced in place. A hook whose
    markers are unbalanced was edited by hand and is left alone, and so is a
    hook written in a language other than shell. A failed
    update never fails the git command that triggered it.
    """
def install_git_sync_hooks(repo_root: Path) -> list[Path];

with entry {
    _GENERATED_HOOK_SCRIPTS = frozenset({
        "crg-update.sh",
        "crg-session-start.sh",
        "crg-pre-commit.sh",
    });

    _HOOK_SCRIPT_RUNNERS = frozenset({"bash", "sh"});
    _GENERATED_HOOK_BODIES = (
        "update --quiet --skip-flows",
        "update --quiet",
        "update --skip-flows",
        "status --json",
        "status",
        "detect-changes --brief",
    );
}

"""Alternate the released bodies, longest first, spaces relaxed."""
def _hook_body_pattern -> str;

with entry {
    _GENERATED_HOOK_COMMAND_RE = re.compile(
        "\\A(?:(?:cat\\s*>\\s*/dev/null\\s*\\|\\|\\s*true;\\s*)?(?:command\\s+-v\\s+code-review-graph\\s*>/dev/null\\s+2>&1\\s*\\|\\|\\s*exit\\s+0;\\s*)?(?:git\\s+rev-parse\\s+--git-dir\\s*>/dev/null\\s+2>&1\\s*&&\\s*)?code-review-graph\\s+(?:"
            + _hook_body_pattern()
            + ")(?:\\s+--repo\\s+(?:\\\"[^\\\"]*\\\"|'[^']*'|[^\\s\\\"'|&;<>]+))?(?:\\s*\\|\\|\\s*(?:true|echo\\s+'Not a git repo, skipping'))?|cat\\s*\\|\\s*\\{\\s*if\\s+command\\s+-v\\s+code-review-graph\\s*>/dev/null\\s+2>&1;\\s*then\\s+code-review-graph\\s+hook-(?:update(?:\\s+--existing-only)?|status);\\s*else\\s+cat\\s*>/dev/null;\\s*fi;\\s*\\}|command\\s+-v\\s+code-review-graph\\s*>/dev/null\\s+2>&1\\s*&&\\s*code-review-graph\\s+hook-update;\\s*cat\\s*>/dev/null(?:\\s*\\|\\|\\s*true)?)\\Z",
    );
    _STEERING_HOOK_COMMAND_RE = re.compile(
        "\\Acat\\s*\\|\\s*\\{\\s*if\\s+command\\s+-v\\s+code-review-graph\\s*>/dev/null\\s+2>&1;\\s*then\\s+code-review-graph\\s+enrich;\\s*else\\s+cat\\s*>/dev/null;\\s*fi;\\s*\\}\\s*\\|\\|\\s*true\\Z",
    );
    _PINNED_EXE_RE = "'(?:[^']|'\\\"'\\\"')*'";
    _PINNED_GUARD_RE = f"(?:\\[ -x (?P<exe>{_PINNED_EXE_RE}) \\]|{re.escape(_UVX_HOOK_PROGRAM.guard)})";
    _PINNED_COMMAND_RE = f"(?(exe)(?P=exe) -m code_review_graph|{re.escape(_UVX_HOOK_PROGRAM.command)})";
    _PINNED_SENTINEL = _HookProgram("\x00guard\x00", "\x00command\x00");
}

"""Compile ``text``, made with ``_PINNED_SENTINEL``, into a pattern for any copy."""
def _pinned_shape(text: str) -> re.Pattern[str];

with entry {
    _PINNED_PROJECT_HOOK_COMMAND_RES = `tuple(
        _pinned_shape(text)
        for text in (
            _claude_update_hook_command(_PINNED_SENTINEL),
            _claude_session_hook_command(_PINNED_SENTINEL),
            _claude_session_hook_command(_PINNED_SENTINEL, _legacy_session_status_body),
        ),
    );
    _PINNED_CODEX_HOOK_COMMAND_RES = `tuple(
        _pinned_shape(_codex_hook_command(subcommand, _PINNED_SENTINEL))
        for subcommand in (_CODEX_UPDATE_SUBCOMMAND, "hook-update", "hook-status"),
    );
    _PINNED_STEERING_HOOK_COMMAND_RE = _pinned_shape(
        format(_codex_hook_command("enrich", _PINNED_SENTINEL), "") + " || true"
    );
}

"""Return whether ``command`` is a project edit or session hook that names its copy."""
def _is_pinned_project_hook_command(command: Any) -> bool;

"""Return whether ``command`` is a Codex hook that names its copy."""
def _is_pinned_codex_hook_command(command: Any) -> bool;

"""Return whether ``command`` is any hook ``install`` writes that names its copy."""
def _is_pinned_hook_command(command: Any) -> bool;

with entry {
    _HOOK_MENTION_MARKERS = ("code-review-graph", "code_review_graph", "crg-");
    _GENERATED_HOOK_MATCHERS = {
        "PostToolUse": frozenset({"Edit|Write", "Edit|Write|Bash", "Write|Edit|Bash"}),
        "SessionStart": frozenset({"", None, "startup|resume"}),
        "AfterTool": frozenset({"write_file|replace"}),
        "PreToolUse": frozenset({"Grep|Glob|Bash|Read"}),
    };
    _SHELL_OPERATOR_RE = re.compile("[|&;<>`]|\\$\\(");
    _NEW_ARGUMENT_RE = re.compile("\\A(?:[-/\\\\]|[A-Za-z]:[\\\\/])");
}

"""Split ``command`` into shell words as ``(raw, unquoted)`` pairs.

    ``str.split`` is the wrong tool: it cannot see through ``"..."`` and it
    breaks ``/Users/jo smith/hooks/crg-update.sh`` -- one path on a home
    directory with a space in it -- into two words. ``shlex`` understands
    quoting, and non-POSIX mode leaves backslashes alone so a Windows path
    survives the trip. Returns None for a line no shell could parse, such as
    one with an unterminated quote; nothing about such a line is certain
    enough to act on.
    """
def _shell_words(command: str) -> list[tuple[str, str]] | None;

"""Strip one layer of matching surrounding quotes from a shell word."""
def _unquote_word(word: str) -> str;

"""Return whether ``command`` just runs a hook script this project writes.

    Ownership is the script's own file name, so the answer must not depend on
    how the path leading to it is spelled: quoted or bare, absolute or
    relative, ``/`` or ``\\``, with a space in the home directory, with a
    trailing argument. What still disqualifies a command is a second program:
    a chained or redirected command, or one of our scripts passed as an
    argument to somebody else's.
    """
def _is_generated_hook_script(command: str) -> bool;

"""Return whether ``command`` is a hook command this project writes.

    Only the exact command shapes released versions emit count. Anything else
    that merely mentions this project -- a different subcommand, extra flags, a
    second command chained on with ``&&``, an unrelated path that happens to
    contain ``crg-`` -- belongs to the user and is left in place.
    """
def _is_generated_hook_command(command: Any) -> bool;

"""Return whether ``command`` is the steering hook this project writes."""
def _is_steering_hook_command(command: Any) -> bool;

"""Say that a hook mentioning this project was deliberately left alone.

    Certainty is the condition for touching someone's configuration. When a
    command mentions this project but is not a shape it writes, the hook stays
    and the user is told, rather than being deleted on a guess.
    """
def _report_kept_hook(command: Any) -> None;

"""Return the matchers under which a group may be claimed for this event."""
def _allowed_hook_matchers(event_name: str, new_entries: Sequence[Any]) -> frozenset[Any];

glob owns_default_: any;

with entry {
    owns_default_ = _is_generated_hook_command;
}

"""Return ``existing`` with our own hook groups replaced by ``new_entries``.

    Comparing whole entries (or exact command strings) only ever recognises the
    hook the running version would write, so any change to the command left the
    previous release's hook in place and appended a second one beside it, and
    the repository then ran two code-review-graph hooks on one event.

    Ownership is therefore decided by the command, bounded twice over: the
    command has to be one of the shapes this project emits, and the group has
    to sit under a matcher this project has written for this event. A group
    that also holds a hook someone else wrote keeps that hook, and the
    replacement lands where the old group sat rather than at the end, so a hook
    that ran first goes on running first. ``owns`` narrows the commands claimed.
    """
def _merge_hook_entries(
    existing: Any,
    new_entries: list[Any],
    event_name: str = "",
    owns: Callable[[Any], bool] = owns_default_,
) -> list[Any];

"""The same replacement rule for a flat, one-level hook list (Cursor)."""
def _merge_flat_hook_entries(existing: Any, new_entries: list[Any]) -> list[Any];

def _report_settings_left_alone(label: str, path: Path, problem: str) -> None;

"""Return a hook settings file's text and parsed object, or None to leave it.

    Merging onto an empty dict whenever a file fails strict JSON replaces all of
    it with our hooks, so one comment or trailing comma used to cost the user
    every setting they had, with no backup. JSONC is read as JSONC, and a file
    that cannot be merged is named and left alone, as
    :func:`install_platform_configs` does for MCP entries.
    """
def _read_settings_for_merge(
    path: Path, label: str, events: Iterable[str]
) -> tuple[str, dict[str, Any]] | None;

"""Apply only what changed to a commented settings file, or return None.

    Replacing a value deletes any comment inside it, so a change that would do
    that is refused rather than made.
    """
def _splice_merged_settings(raw: str, before: dict[str, Any], merged: dict[str, Any]) -> str | None;

"""Write merged hook settings, keeping a backup and every comment.

    Returns False when the file was left alone instead. A file that already
    holds these settings is not touched, so reinstalling neither rewrites it nor
    leaves a backup that is the same as the file. An existing backup is kept:
    it is the copy from before the first install, and a later install that
    changes the file must not replace it with our own earlier edit.
    """
def _write_merged_settings(path: Path, raw: str, merged: dict[str, Any], label: str) -> bool;

glob owns_default__: any;

with entry {
    owns_default__ = _is_generated_hook_command;
}

"""Merge hook entries into a project settings file without clobbering users.

    ``owns`` says which commands are ours to replace. Returns the settings
    path, or None when the file had to be left alone.
    """
def _merge_hooks_into_settings(
    settings_dir: Path,
    hooks_config: dict[str, Any],
    label: str = "Claude Code",
    owns: Callable[[Any], bool] = owns_default__,
) -> Path | None;

"""Write hooks config to platform-specific settings.json.

    Merges new hook entries into existing settings, preserving both
    non-hook configuration and user-defined hooks.  A backup of the
    original file is created before any modifications.

    Args:
        repo_root: Repository root directory.
        platform: Target platform ("claude" or "qoder").

    Returns:
        The settings path, or None when the file had to be left alone.
    """
def install_hooks(repo_root: Path, platform: str = "claude") -> Path | None;

"""Add the opt-in steering hook to the project's Claude Code settings.

    Returns the settings path, or None when the file had to be left alone.
    """
def install_steering_hook(repo_root: Path) -> Path | None;

"""Install runtime-resolved POSIX hooks in .codebuddy/settings.json.

    CodeBuddy uses the same nested hook schema and POSIX-shell execution
    model as the existing project hooks. The shared generator deliberately
    resolves the checkout at hook runtime instead of embedding the installer's
    absolute path, so committed settings work for every collaborator.
    """
def install_codebuddy_hooks(repo_root: Path) -> Path | None;

"""Write native Codex hooks config to the active Codex home.

    Merges code-review-graph hook entries into any existing hooks.json,
    preserving user-defined hook entries and other top-level settings.
    A backup of the original file is created before modifications.

    Returns the hooks path, or None when the file had to be left alone.
    """
def install_codex_hooks(repo_root: Path) -> Path | None;

"""Install the bundled global Codex skill in the active Codex home."""
def install_codex_skill -> Path | None;

with entry {
    _CLAUDE_MD_SECTION_MARKER = "<!-- code-review-graph MCP tools -->";
    _CLAUDE_MD_SECTION_END_MARKER = "<!-- /code-review-graph MCP tools -->";
    _INSTRUCTION_INTRO = "**This project has a knowledge graph. Start with the code-review-graph\nMCP tools to narrow scope, then read the source.** The graph is cheaper than scanning files and\ngives you structural context (callers, dependents, test coverage) that file search cannot.";

    _INSTRUCTION_GUARDRAILS = "### Verify in the source\n\n- Answer from `include_source=True, expand_neighbors=True`; read a file only if truncated.\n- Do not change code from graph output alone: for any non-trivial change,\n  read the implementation and the relevant tests before concluding.\n- Verify the exact source when touching behavior, database logic, migrations, retries, fallbacks,\n  recovery, or compatibility code.\n- When the graph and the source disagree, the source wins. The graph may be stale.\n- An empty graph result can mean \"not indexed\" or \"not statically visible\", not \"does not exist\".";

    _CLAUDE_MD_SECTION = f"{_CLAUDE_MD_SECTION_MARKER}\n## MCP Tools: code-review-graph\n\n{_INSTRUCTION_INTRO}\n\n### When to use graph tools FIRST\n\n- **Exploring code**: `semantic_search_nodes_tool(include_source=True, expand_neighbors=True)`\n- **Understanding impact**: `get_impact_radius_tool` instead of manually tracing imports\n- **Code review**: `detect_changes_tool` + `get_review_context_tool` instead of reading entire files\n- **Finding relationships**: `query_graph_tool` with callers_of/callees_of/imports_of/tests_for\n- **Architecture questions**: `get_architecture_overview_tool` + `list_communities_tool`\n\n{_INSTRUCTION_GUARDRAILS}\n\n### Key Tools\n\n| Tool | Use when |\n| ------ | ---------- |\n| `detect_changes_tool` | Reviewing code changes — gives risk-scored analysis |\n| `get_review_context_tool` | Need source snippets for review — token-efficient |\n| `get_impact_radius_tool` | Understanding blast radius of a change |\n| `get_affected_flows_tool` | Finding which execution paths are impacted |\n| `query_graph_tool` | Tracing callers, callees, imports, tests, dependencies |\n| `semantic_search_nodes_tool` | Finding functions/classes by name or keyword |\n| `get_architecture_overview_tool` | Understanding high-level codebase structure |\n| `refactor_tool` | Planning renames, finding dead code |\n\n### Workflow\n\n1. The graph auto-updates on file changes (via hooks).\n2. Use `detect_changes_tool` for code review.\n3. Use `get_affected_flows_tool` to understand impact.\n4. Use `query_graph_tool` pattern=\"tests_for\" to check coverage.\n{_CLAUDE_MD_SECTION_END_MARKER}\n";
    _COPILOT_SECTION = f"---\napplyTo: '**'\ndescription: >-\n  Use code-review-graph MCP tools for token-efficient\n  codebase exploration and code review.\n---\n\n{_CLAUDE_MD_SECTION_MARKER}\n## MCP Tools: code-review-graph\n\n{_INSTRUCTION_INTRO}\n\n### When to use graph tools FIRST\n\n- **Exploring code**: `semantic_search_nodes_tool` or `query_graph_tool`\n- **Understanding impact**: `get_impact_radius_tool`\n- **Code review**: `detect_changes_tool` + `get_review_context_tool`\n- **Finding relationships**: `query_graph_tool` callers_of/callees_of\n- **Architecture questions**: `get_architecture_overview_tool`\n\n{_INSTRUCTION_GUARDRAILS}\n\n### Key Tools\n\n| Tool | Use when |\n| ------ | ---------- |\n| `detect_changes_tool` | Risk-scored change analysis |\n| `get_review_context_tool` | Token-efficient source snippets |\n| `get_impact_radius_tool` | Blast radius of a change |\n| `get_affected_flows_tool` | Impacted execution paths |\n| `query_graph_tool` | Trace callers, callees, imports, tests |\n| `semantic_search_nodes_tool` | Find functions/classes by keyword |\n| `get_architecture_overview_tool` | High-level structure |\n| `refactor_tool` | Rename planning, dead code |\n\n### Workflow\n\n1. The graph auto-updates on file changes (via hooks).\n2. Use `detect_changes_tool` for code review.\n3. Use `get_affected_flows_tool` to understand impact.\n4. Use `query_graph_tool` pattern=\"tests_for\" to check coverage.\n{_CLAUDE_MD_SECTION_END_MARKER}\n";
    _PLATFORM_INSTRUCTION_CUSTOM_SECTIONS = {
        ".github/instructions/code-review-graph.instructions.md": (
            _CLAUDE_MD_SECTION_MARKER,
            _COPILOT_SECTION,
        ),
        ".github/code-review-graph.instruction.md": (_CLAUDE_MD_SECTION_MARKER, _COPILOT_SECTION),
    };
}

"""Every block text this project has ever generated, longest first.

    Longest first matters: a shorter variant that happens to be contained in a
    longer one must never win the match and leave the tail behind.
    """
def _known_instruction_sections -> tuple[str, ...];

"""Replace a previously generated block with ``section``.

    Only text that exactly equals a known generated block is ever rewritten, so
    anything the user wrote around it survives byte for byte. Blocks predating
    the end marker have no closing boundary, which is why nothing here searches
    for one; guessing where such a block stops would eat user content.

    Returns the new file content, or None when the marker is present but no
    known block is, meaning someone edited the block by hand.
    """
def _upgrade_managed_block(existing: str, section: str) -> str | None;

"""Create, or upgrade in place, the managed instruction block in a file.

    Returns one of:

    - ``"created"``: the block was written for the first time, creating the
      file or appending to one that had no block.
    - ``"updated"``: an older generated block was replaced with the current one.
    - ``"unchanged"``: the file already holds the current block, byte for byte.
      Nothing is written, so repeated installs do not touch the file.
    - ``"conflict"``: the marker is present but the block matches nothing this
      project generated, so it was hand-edited. The file is left alone and the
      caller is expected to tell the user about it.
    """
def _inject_instructions(file_path: Path, marker: str, section: str) -> str;

"""Create or upgrade the MCP tools section in CLAUDE.md.

    Returns the outcome string documented on ``_inject_instructions``.
    """
def inject_claude_md(repo_root: Path) -> str;

with entry {
    _PLATFORM_INSTRUCTION_FILES = {
        "AGENTS.md": ("cursor", "opencode", "mimo", "antigravity", "codex", "hermes", "dsh"),
        "GEMINI.md": ("antigravity", "gemini-cli"),
        ".cursorrules": ("cursor",),
        ".windsurfrules": ("windsurf",),
        "QODER.md": ("qoder",),
        ".kiro/steering/code-review-graph.md": ("kiro",),
        ".github/instructions/code-review-graph.instructions.md": ("copilot", "copilot-cli"),
        "CODEBUDDY.md": ("codebuddy",),
    };
    _LEGACY_PLATFORM_INSTRUCTION_FILES = {
        ".github/code-review-graph.instruction.md": ("copilot", "copilot-cli"),
    };
}

"""Strip an exact generated section from a superseded instruction file."""
def _remove_legacy_instruction_file(path: Path) -> None;

with entry {
    _GEMINI_CLI_HOOK_FILENAMES = ("crg-session-start.sh", "crg-update.sh");
}

"""Install Gemini CLI hooks in .gemini/settings.json and write hook scripts.

    Hooks schema reference:
    - https://geminicli.com/docs/hooks/reference/

    This is workspace-scoped (project) configuration: .gemini/settings.json

    Returns the settings path, or None when the file had to be left alone.
    """
def install_gemini_cli_hooks(repo_root: Path) -> Path | None;

"""Install Gemini CLI Agent Skills in .gemini/skills/<skill>/SKILL.md."""
def install_gemini_cli_skills(repo_root: Path) -> Path;

"""Install project skills in .codebuddy/skills/<name>/SKILL.md."""
def install_codebuddy_skills(repo_root: Path) -> Path;

"""Inject 'use graph first' instructions into platform rule files.

    Writes AGENTS.md, GEMINI.md, .cursorrules, and/or .windsurfrules
    depending on ``target``:

    - ``"all"`` (default): writes every file — matches pre-filter behavior.
    - ``"claude"``: writes nothing (CLAUDE.md is handled by ``inject_claude_md``).
    - any other platform key (``cursor``, ``windsurf``, ``antigravity``,
      ``opencode``, ``codex``): writes only the files associated with that platform.

    Returns list of filenames that were created or updated. Use
    ``inject_instruction_files`` when the caller also needs to know which files
    were left alone because someone edited the block by hand.
    """
def inject_platform_instructions(repo_root: Path, target: str = "all") -> list[str];

"""Return whether an instruction file read by ``owners`` is written for ``target``.

    ``platforms`` narrows ``"all"`` to the platforms ``install`` selected.
    """
def instruction_file_wanted(
    owners: Iterable[str], target: str, platforms: Iterable[str] | None = None
) -> bool;

"""Write every instruction file for ``target`` and report what happened.

    Maps each filename to ``"created"``, ``"updated"``, ``"unchanged"`` or
    ``"conflict"``, as documented on ``_inject_instructions``. This is the entry
    point the install command uses so it can tell the user which files it
    upgraded and which ones need manual attention. ``platforms`` narrows
    ``"all"`` to the platforms ``install`` selected.
    """
def inject_instruction_files(
    repo_root: Path,
    target: str = "all",
    *,
    include_claude_md: bool = True,
    platforms: Iterable[str] | None = None,
) -> dict[str, str];

"""Generate Cursor hooks.json configuration.

    Returns a dict conforming to the Cursor hooks schema (version 1) with
    hooks for afterFileEdit, sessionStart, and beforeShellExecution.
    Each hook points to a shell script in ~/.cursor/hooks/.

    Returns:
        Dict suitable for writing as ~/.cursor/hooks.json.
    """
def generate_cursor_hooks_config -> dict[str, Any];

"""Return a mapping of filename -> shell script content for Cursor hooks.

    Three scripts are generated:
    - crg-update.sh: runs ``code-review-graph update --skip-flows`` after file edits
    - crg-session-start.sh: runs ``code-review-graph status`` on session start
    - crg-pre-commit.sh: runs ``code-review-graph detect-changes --brief`` before
      git commit commands

    All scripts:
    - Read stdin (Cursor passes JSON context) and discard it
    - Run the copy of code-review-graph that ran ``install``, or the one on
      PATH when it is gone
    - Fail gracefully (exit 0) so they never block the editor
    - Emit valid JSON on stdout per the Cursor hooks protocol
    """
def _cursor_hook_scripts -> dict[str, str];

"""Install Cursor hooks configuration and scripts at user level.

    Writes ``~/.cursor/hooks.json`` (merging code-review-graph hooks
    into any existing configuration) and creates executable shell scripts
    in ``~/.cursor/hooks/``.

    Returns:
        Path to the hooks.json file that was written, or None when the file
        had to be left alone, in which case no scripts are written either.
    """
def install_cursor_hooks -> Path | None;

"""Return the directory holding this release's bundled Qoder workflows.

    Wheels carry them at ``code_review_graph/_bundled_skills`` (force-included
    from the repository's top-level ``skills/``). Editable installs and source
    checkouts have no such resource, so the same files are read from beside the
    package. Returns ``None`` when neither exists.

    A :class:`~importlib.abc.Traversable`, not a :class:`~pathlib.Path`, so a
    package imported from a zip keeps working; both callers only iterate it and
    read text from it.

    Install and uninstall must agree on this answer: the installer writes one
    ``.qoder/skills/<name>/SKILL.md`` per entry here, and uninstall has no other
    way to know which of a user's ``.qoder`` skills are ours.
    """
def bundled_skills_dir -> Traversable | None;

"""Return the names of the bundled workflows, sorted, or ``()`` if absent.

    This is the list ``uninstall`` deletes from ``.qoder/skills``. It must stay
    the same answer :func:`install_qoder_skills` acts on; deriving it from the
    target project's own ``skills/`` directory instead removed nothing, because
    a normal repository has no such directory (#909).
    """
def bundled_skill_names -> tuple[str, ...];

"""Install skills to Qoder's project-level skills directory.

    Qoder expects skills in .qoder/skills/{skillName}/SKILL.md format within the project.
    Loads the shipped skills from package resources. Source checkouts use their
    own top-level skills/ directory when wheel resources are not present.

    Args:
        repo_root: Target repository root directory.

    Returns:
        Path to the Qoder skills directory, or None if installation failed.
    """
def install_qoder_skills(repo_root: Path) -> Path | None;

"""Install skills into Hermes Agent's user-level skills directory.

    Hermes discovers skills at ``<HERMES_HOME>/skills/<category>/<name>/SKILL.md``
    and uses the same ``name``/``description`` frontmatter as Claude Code, so
    :func:`generate_skills` writes them directly under a ``code-review-graph``
    category.
    """
def install_hermes_skills(repo_root: Path) -> Path;

"""Return the installed OpenCode major version, when it can be detected."""
def _detect_opencode_major_version -> int | None;

"""Return TypeScript source for the OpenCode 1.x user-level plugin."""
def _opencode_v1_plugin_content -> str;

"""Return TypeScript source for the OpenCode user-level plugin.

    The plugin exports an OpenCode 2.x (V2) definition object with an ``id``
    and a ``setup`` function because the V2 loader rejects any other
    default-export shape with ``SchemaError(Expected object at ["default"])``.
    The plugin package is imported only for types so older 2.x hosts do not
    need to resolve it at runtime. ``setup`` mirrors the Claude Code hook behaviors:

    1. successful ``edit``/``write``/``patch`` tool calls (there is no V2
       ``file.edited`` hook) — runs ``code-review-graph update --skip-flows``
    2. ``session.created`` events via ``ctx.event.subscribe`` — runs
       ``code-review-graph status``
    3. ``ctx.tool.hook("execute.before")`` — when the tool is a shell
       command starting with ``git commit``, runs ``code-review-graph
       detect-changes --brief``

    All handlers use try/catch (or a swallowing helper) so errors never
    break the editor session. Subprocesses run via ``node:child_process``
    ``execFile`` with argv arrays — never by interpolating a command string
    into Bun's ``$`` template, which would escape it into one executable
    name.
    """
def _opencode_v2_plugin_content -> str;

with entry {
    _OPENCODE_RUN_QUIET = "async function runQuiet(args: string[], cwd: string, timeoutMs: number): Promise<string> {\n  try {\n    const { stdout } = await execFileAsync(\"code-review-graph\", args, {\n      cwd,\n      timeout: timeoutMs,\n    })\n    return String(stdout ?? \"\").trim()\n  } catch (error) {\n    logFailure(args, error)\n    return \"\"\n  }\n}\n";
    _OPENCODE_PINNED_RUN_QUIET = "// The copy of code-review-graph that ran install, then the one on PATH.\nconst CRG_COMMANDS: string[][] = __CRG_COMMANDS__\n\nasync function runQuiet(args: string[], cwd: string, timeoutMs: number): Promise<string> {\n  for (const [file, ...prefix] of CRG_COMMANDS) {\n    try {\n      const { stdout } = await execFileAsync(file, [...prefix, ...args], {\n        cwd,\n        timeout: timeoutMs,\n      })\n      return String(stdout ?? \"\").trim()\n    } catch (error) {\n      // Try the next copy only when this one is not there at all.\n      if ((error as { code?: unknown } | null)?.code !== \"ENOENT\") {\n        logFailure(args, error)\n        return \"\"\n      }\n    }\n  }\n  return \"\"\n}\n";
}

"""Return the plugin template for an OpenCode major version.

    ``launcher`` is the command line that starts the CLI. Any other than the
    copy on PATH is tried first, and the copy on PATH only when it is gone.
    """
def _opencode_plugin_content(
    major_version: int = 2, launcher: Sequence[str] = ("code-review-graph",)
) -> str;

"""Return where OpenCode loads our global plugin from.

    OpenCode keeps its global config in ``$XDG_CONFIG_HOME/opencode``
    (default ``~/.config/opencode``).
    """
def _opencode_plugin_path -> Path;

"""Install the OpenCode user-level plugin for code-review-graph.

    Writes ``crg-plugin.ts`` to OpenCode's global plugins folder (see
    ``_opencode_plugin_path``).  Creates the directories if they don't
    exist.  If the file already exists it is overwritten (the plugin is
    self-contained and idempotent).

    Returns:
        Path to the plugin file that was written.
    """
def install_opencode_plugin(opencode_major: int | None = None) -> Path;
