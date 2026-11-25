import from __future__ { annotations }

import importlib, builtins, operator, json, logging, os, platform, re, shlex, shutil, stat, subprocess, sys;

import from importlib { resources }

import from pathlib { Path }

import from typing { TYPE_CHECKING, Any, Callable, Iterable, NamedTuple, Sequence }

glob logger: any = logging.getLogger(__name__);

def _zed_settings_path -> Path;
def _copilot_vscode_detected -> bool;
def _xdg_config_home -> Path;
def _app_data_dirs(app: str) -> list[Path];
def _xdg_data_home -> Path;
def _claude_code_detected -> bool;
def _opencode_detected -> bool;
def _qoder_detected -> bool;
def _codebuddy_detected -> bool;
def _hermes_home -> Path;
def _hermes_config_path -> Path;
def _dsh_home -> Path;
def _dsh_config_path -> Path;
def _opencode_config_paths(repo_root: Path) -> tuple[Path, Path];
def _opencode_config_path(repo_root: Path) -> Path;
def _mimo_config_home -> Path;
def _mimo_config_paths(repo_root: Path) -> tuple[Path, Path];
def _mimo_config_path(repo_root: Path) -> Path;

glob PLATFORMS: dict[str, dict[str, Any]] = {
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

def _codex_home -> Path;
def _in_poetry_project -> bool;
def _in_uv_project -> bool;

glob _UV_CACHE_ENV_RE: any = re.compile("\\A(?:archive|builds)-v[0-9]+\\Z");

def _running_from_uv_tool -> bool;
def _detect_cli_launcher -> list[str];
def _detect_serve_command -> tuple[str, list[str]];
def _build_server_entry(
    plat: dict[str, Any], key: str = "", repo_root: "Path | None" = None
) -> dict[str, Any];

glob _GENERATED_ENTRY_FIELDS: any = frozenset({
    "name",
    "type",
    "command",
    "args",
    "cwd",
    "tools",
    "env",
});

glob _GENERATED_ENTRY_TYPES: any = frozenset({"stdio", "local"});

glob _GENERATED_SERVE_ARGV: dict[tuple[str, ...], frozenset[str]] = {
    ("code-review-graph", "serve"): frozenset({"uvx"}),
    ("serve",): frozenset({"code-review-graph"}),
    ("run", "code-review-graph", "serve"): frozenset({"poetry", "uv"}),
    ("-m", "code_review_graph", "serve"): frozenset({"python"}),
};

glob _PYTHON_LAUNCHER_RE: any = re.compile("\\Apythonw?[0-9]*(?:\\.[0-9]+)*\\Z");

def _launcher_basename(token: str) -> str;
def _entry_command_tokens(`entry: dict[str, Any]) -> list[str] | None;
def _is_generated_server_entry(`entry: Any) -> bool;
def _report_user_owned_entry(config_path: Path, label: str = "");
def _warn_legacy_opencode_config(repo_root: Path);
def _load_tomllib -> Any;
def _format_toml_value(value: Any) -> str;
def _toml_header_matches(line: str, table_path: tuple[str, ...]) -> bool;
def _toml_table_span(lines: list[str], table_path: tuple[str, ...]) -> tuple[int, int] | None;
def _merge_toml_mcp_server(
    config_path: Path, server_name: str, server_entry: dict[str, Any], dry_run: bool = False
) -> bool | None;
def _yaml_section_bounds(lines: list[str], key: str) -> tuple[int, int] | None;
def _yaml_block_indent(lines: list[str], start: int, end: int) -> int;
def _yaml_child_bounds(lines: list[str], start: int, end: int, name: str) -> tuple[int, int] | None;
def _merge_yaml_mcp_server(
    config_path: Path,
    server_key: str,
    server_name: str,
    server_entry: dict[str, Any],
    dry_run: bool = False,
) -> bool | None;
def _merge_dsh_patch_server(config_path: Path, server_entry: dict[str, Any]) -> bool | None;
def _indent_block(text: str, indent: int) -> str;
def _strip_jsonc(text: str) -> str;
def _splice_commented_config(
    raw: str,
    server_key: str,
    server_entry: dict[str, Any] | None,
    removals: list[tuple[str, ...]],
    *,
    array_format: bool,
    document: dict[str, Any],
) -> str | None;
def platforms_for_target(repo_root: Path, target: str) -> dict[str, dict[str, Any]];
def selected_platforms(repo_root: Path, target: str) -> frozenset[str];
def install_platform_configs(
    repo_root: Path,
    target: str = "all",
    dry_run: bool = False,
    platforms: Iterable[str] | None = None,
) -> list[str];
def _install_platform_configs(
    repo_root: Path, target: str, dry_run: bool, platforms: Iterable[str] | None = None
) -> list[str];

glob _SKILLS: dict[str, dict[str, str]] = {
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

def generate_skills(repo_root: Path, skills_dir: Path | None = None) -> Path;

glob DOCUMENTARY_SKILLS: dict[str, dict[str, str]] = {
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

def render_documentary_skill_markdown(slug: str) -> str;
def generate_documentary_skills(repo_root: Path, skills_dir: Path | None = None) -> Path;

class _HookProgram(NamedTuple) {
    has guard: str;

    has command: str;
}

glob _PATH_GUARD: any = "command -v code-review-graph >/dev/null 2>&1";

glob _PATH_HOOK_PROGRAM: any;

with entry {
    _PATH_HOOK_PROGRAM = _HookProgram(_PATH_GUARD, "code-review-graph");
}

glob _UVX_HOOK_PROGRAM: any;

with entry {
    _UVX_HOOK_PROGRAM = _HookProgram("command -v uvx >/dev/null 2>&1", "uvx code-review-graph");
}

def _sh_single_quote(value: str) -> str;
def _hook_launcher -> list[str];
def _hook_program -> _HookProgram;
def _hook_chain(body: Callable[[str], str], program: _HookProgram, otherwise: str = "") -> str;
def _session_status_body(cli: str) -> str;
def _legacy_session_status_body(cli: str) -> str;
def _claude_update_hook_command(program: _HookProgram) -> str;

glob body_default_: any = _session_status_body;

def _claude_session_hook_command(
    program: _HookProgram, body: Callable[[str], str] = body_default_
) -> str;

glob _PLUGIN_WORKTREE_BUILD_COMMAND: any = f"cat >/dev/null || true; {_PATH_GUARD} || exit 0; if git rev-parse --git-dir >/dev/null 2>&1; then code-review-graph build >/dev/null 2>&1 & fi";

def _codex_hook_command(subcommand: str, program: _HookProgram | None = None) -> str;
def _shell_cli_function(name: str, program: _HookProgram, indent: str = "") -> str;
def generate_hooks_config(repo_root: Path, program: _HookProgram | None = None) -> dict[str, Any];
def generate_plugin_hooks_config -> dict[str, Any];
def generate_steering_hooks_config(program: _HookProgram | None = None) -> dict[str, Any];

glob _CODEX_UPDATE_SUBCOMMAND: any = "hook-update --existing-only";

def generate_codex_hooks_config(
    repo_root: Path, program: _HookProgram | None = None
) -> dict[str, Any];

glob _GIT_HOOK_BEGIN_MARKER: any = "# >>> code-review-graph pre-commit hook >>>";

glob _GIT_HOOK_END_MARKER: any = "# <<< code-review-graph pre-commit hook <<<";

glob _GIT_HOOK_NOTE: any = "# Installed by code-review-graph. Remove this file to disable pre-commit graph checks.";

glob _GIT_HOOK_SHEBANG: any = "#!/bin/sh\n";

glob _GIT_HOOK_BODY: any = "if command -v code-review-graph >/dev/null 2>&1; then\n    crg_hook_git_dir=$(git rev-parse --absolute-git-dir 2>/dev/null) || crg_hook_git_dir=\"\"\n    crg_hook_root=$(git rev-parse --show-toplevel 2>/dev/null) || crg_hook_root=\"\"\n    if [ -z \"$crg_hook_git_dir\" ] || [ -z \"$crg_hook_root\" ]; then\n        echo \"code-review-graph: skipping automatic checks; cannot determine the Git worktree.\" >&2\n    elif [ -f \"$crg_hook_git_dir/commondir\" ] && [ \"$CRG_HOOK_WORKTREES\" != \"1\" ]; then\n        # Only a linked worktree's git dir carries a commondir file (Git 2.5+),\n        # so this needs no rev-parse options newer than --absolute-git-dir.\n        echo \"code-review-graph: skipping automatic checks in a linked worktree;\" \\\n            \"set CRG_HOOK_WORKTREES=1 to keep a graph for this worktree too.\" >&2\n    else\n        code-review-graph update --repo \"$crg_hook_root\" || true\n        code-review-graph detect-changes --brief --repo \"$crg_hook_root\" || true\n    fi\nfi\n";

def _any_copy_guard(program: _HookProgram) -> str;
def _hook_cli_function(name: str, program: _HookProgram, indent: str) -> str;
def _git_hook_body(program: _HookProgram | None = None) -> str;
def _git_hook_block(program: _HookProgram | None = None) -> str;

glob _LEGACY_GIT_HOOK_BLOCKS: tuple[str, ...] = (
    f"{_GIT_HOOK_NOTE}\nif command -v code-review-graph >/dev/null 2>&1; then\n    code-review-graph detect-changes --brief || true\nfi\n",
    f"{_GIT_HOOK_NOTE}\nif command -v code-review-graph >/dev/null 2>&1; then\n    code-review-graph update || true\n    code-review-graph detect-changes --brief || true\nfi\n",
    f"{_GIT_HOOK_NOTE}\n{_GIT_HOOK_BODY}",
);

def _known_git_hook_blocks -> tuple[str, ...];

glob begin_marker_default_: any = _GIT_HOOK_BEGIN_MARKER;

glob end_marker_default_: any = _GIT_HOOK_END_MARKER;

def _git_hook_markers_balanced(
    text: str, begin_marker: str = begin_marker_default_, end_marker: str = end_marker_default_
) -> bool;

glob begin_marker_default__: any = _GIT_HOOK_BEGIN_MARKER;

glob end_marker_default__: any = _GIT_HOOK_END_MARKER;

def _git_hook_block_span(
    text: str,
    start: int = 0,
    begin_marker: str = begin_marker_default__,
    end_marker: str = end_marker_default__,
) -> tuple[int, int] | None;
def _upgrade_git_hook_block(existing: str, program: _HookProgram | None = None) -> str | None;

glob _TOP_LEVEL_EXIT_RE: any = re.compile(
    "exit(?:[ \\t]+(?P<arg>[^\\s#;]+))?[ \\t]*;?[ \\t]*(?:#.*)?"
);

glob _SHELL_LINE_CONTINUATIONS: any = ("\\", "&&", "||", "|");

def _is_shell_filler(line: str) -> bool;
def _trailing_exit(text: str) -> tuple[int, bool] | None;
def _add_hook_block(existing: str, block: str) -> str | None;
def _lift_block_above_exit(text: str, begin_marker: str, end_marker: str) -> str;

def _exit_warning(hook_path: Path, command: str);
def _git_hooks_dir(repo_root: Path) -> Path | None;
def install_git_hook(repo_root: Path) -> Path | None;

glob _GIT_SYNC_HOOK_BEGIN_MARKER: any = "# >>> code-review-graph sync hook >>>";

glob _GIT_SYNC_HOOK_END_MARKER: any = "# <<< code-review-graph sync hook <<<";

glob _GIT_SYNC_HOOK_NOTE: any = "# Installed by code-review-graph. Keeps the graph in sync after checkout, merge and rebase.";

glob _GIT_SYNC_HOOK_NAMES: any = ("post-checkout", "post-merge", "post-rewrite");

glob _GIT_SYNC_HOOK_CONDITIONS: any = {
    "post-checkout": "[ \"$3\" = \"1\" ] && ",
    "post-merge": "",
    "post-rewrite": "",
};

def _git_sync_hook_block(hook_name: str, program: _HookProgram | None = None) -> str;

glob _SHELL_INTERPRETERS: any = frozenset({"sh", "bash", "dash", "zsh", "ksh", "ash"});

def _is_shell_hook(text: str) -> bool;
def install_git_sync_hooks(repo_root: Path) -> list[Path];

glob _GENERATED_HOOK_SCRIPTS: any = frozenset({
    "crg-update.sh",
    "crg-session-start.sh",
    "crg-pre-commit.sh",
});

glob _HOOK_SCRIPT_RUNNERS: any = frozenset({"bash", "sh"});

glob _GENERATED_HOOK_BODIES: any = (
    "update --quiet --skip-flows",
    "update --quiet",
    "update --skip-flows",
    "status --json",
    "status",
    "detect-changes --brief",
);

def _hook_body_pattern -> str;

glob _GENERATED_HOOK_COMMAND_RE: any = re.compile(
    "\\A(?:(?:cat\\s*>\\s*/dev/null\\s*\\|\\|\\s*true;\\s*)?(?:command\\s+-v\\s+code-review-graph\\s*>/dev/null\\s+2>&1\\s*\\|\\|\\s*exit\\s+0;\\s*)?(?:git\\s+rev-parse\\s+--git-dir\\s*>/dev/null\\s+2>&1\\s*&&\\s*)?code-review-graph\\s+(?:"
        + _hook_body_pattern()
        + ")(?:\\s+--repo\\s+(?:\\\"[^\\\"]*\\\"|'[^']*'|[^\\s\\\"'|&;<>]+))?(?:\\s*\\|\\|\\s*(?:true|echo\\s+'Not a git repo, skipping'))?|cat\\s*\\|\\s*\\{\\s*if\\s+command\\s+-v\\s+code-review-graph\\s*>/dev/null\\s+2>&1;\\s*then\\s+code-review-graph\\s+hook-(?:update(?:\\s+--existing-only)?|status);\\s*else\\s+cat\\s*>/dev/null;\\s*fi;\\s*\\}|command\\s+-v\\s+code-review-graph\\s*>/dev/null\\s+2>&1\\s*&&\\s*code-review-graph\\s+hook-update;\\s*cat\\s*>/dev/null(?:\\s*\\|\\|\\s*true)?)\\Z",
);

glob _STEERING_HOOK_COMMAND_RE: any = re.compile(
    "\\Acat\\s*\\|\\s*\\{\\s*if\\s+command\\s+-v\\s+code-review-graph\\s*>/dev/null\\s+2>&1;\\s*then\\s+code-review-graph\\s+enrich;\\s*else\\s+cat\\s*>/dev/null;\\s*fi;\\s*\\}\\s*\\|\\|\\s*true\\Z",
);

glob _PINNED_EXE_RE: any = "'(?:[^']|'\\\"'\\\"')*'";

glob _PINNED_GUARD_RE: any;

with entry {
    _PINNED_GUARD_RE = f"(?:\\[ -x (?P<exe>{_PINNED_EXE_RE}) \\]|{re.escape(_UVX_HOOK_PROGRAM.guard)})";
}

glob _PINNED_COMMAND_RE: any;

with entry {
    _PINNED_COMMAND_RE = f"(?(exe)(?P=exe) -m code_review_graph|{re.escape(_UVX_HOOK_PROGRAM.command)})";
}

glob _PINNED_SENTINEL: any;

with entry {
    _PINNED_SENTINEL = _HookProgram("\x00guard\x00", "\x00command\x00");
}

def _pinned_shape(text: str) -> re.Pattern[str];

glob _PINNED_PROJECT_HOOK_COMMAND_RES: any;

with entry {
    _PINNED_PROJECT_HOOK_COMMAND_RES = `tuple(
        _pinned_shape(text)
        for text in (
            _claude_update_hook_command(_PINNED_SENTINEL),
            _claude_session_hook_command(_PINNED_SENTINEL),
            _claude_session_hook_command(_PINNED_SENTINEL, _legacy_session_status_body),
        ),
    );
}

glob _PINNED_CODEX_HOOK_COMMAND_RES: any;

with entry {
    _PINNED_CODEX_HOOK_COMMAND_RES = `tuple(
        _pinned_shape(_codex_hook_command(subcommand, _PINNED_SENTINEL))
        for subcommand in (_CODEX_UPDATE_SUBCOMMAND, "hook-update", "hook-status"),
    );
}

glob _PINNED_STEERING_HOOK_COMMAND_RE: any;

with entry {
    _PINNED_STEERING_HOOK_COMMAND_RE = _pinned_shape(
        f"{_codex_hook_command("enrich", _PINNED_SENTINEL)} || true"
    );
}

def _is_pinned_project_hook_command(command: Any) -> bool;
def _is_pinned_codex_hook_command(command: Any) -> bool;
def _is_pinned_hook_command(command: Any) -> bool;

glob _HOOK_MENTION_MARKERS: any = ("code-review-graph", "code_review_graph", "crg-");

glob _GENERATED_HOOK_MATCHERS: dict[str, frozenset[str | None]] = {
    "PostToolUse": frozenset({"Edit|Write", "Edit|Write|Bash", "Write|Edit|Bash"}),
    "SessionStart": frozenset({"", None, "startup|resume"}),
    "AfterTool": frozenset({"write_file|replace"}),
    "PreToolUse": frozenset({"Grep|Glob|Bash|Read"}),
};

glob _SHELL_OPERATOR_RE: any = re.compile("[|&;<>`]|\\$\\(");

glob _NEW_ARGUMENT_RE: any = re.compile("\\A(?:[-/\\\\]|[A-Za-z]:[\\\\/])");

def _shell_words(command: str) -> list[tuple[str, str]] | None;
def _unquote_word(word: str) -> str;
def _is_generated_hook_script(command: str) -> bool;
def _is_generated_hook_command(command: Any) -> bool;
def _is_steering_hook_command(command: Any) -> bool;
def _report_kept_hook(command: Any);
def _allowed_hook_matchers(event_name: str, new_entries: Sequence[Any]) -> frozenset[Any];

glob owns_default_: any = _is_generated_hook_command;

def _merge_hook_entries(
    existing: Any,
    new_entries: list[Any],
    event_name: str = "",
    owns: Callable[[Any], bool] = owns_default_,
) -> list[Any];
def _merge_flat_hook_entries(existing: Any, new_entries: list[Any]) -> list[Any];

def _report_settings_left_alone(label: str, path: Path, problem: str);
def _read_settings_for_merge(
    path: Path, label: str, events: Iterable[str]
) -> tuple[str, dict[str, Any]] | None;
def _splice_merged_settings(raw: str, before: dict[str, Any], merged: dict[str, Any]) -> str | None;
def _write_merged_settings(path: Path, raw: str, merged: dict[str, Any], label: str) -> bool;

glob owns_default__: any = _is_generated_hook_command;

def _merge_hooks_into_settings(
    settings_dir: Path,
    hooks_config: dict[str, Any],
    label: str = "Claude Code",
    owns: Callable[[Any], bool] = owns_default__,
) -> Path | None;
def install_hooks(repo_root: Path, platform: str = "claude") -> Path | None;
def install_steering_hook(repo_root: Path) -> Path | None;
def install_codebuddy_hooks(repo_root: Path) -> Path | None;
def install_codex_hooks(repo_root: Path) -> Path | None;
def install_codex_skill -> Path | None;

glob _CLAUDE_MD_SECTION_MARKER: any = "<!-- code-review-graph MCP tools -->";

glob _CLAUDE_MD_SECTION_END_MARKER: any = "<!-- /code-review-graph MCP tools -->";

glob _INSTRUCTION_INTRO: any = "**This project has a knowledge graph. Start with the code-review-graph\nMCP tools to narrow scope, then read the source.** The graph is cheaper than scanning files and\ngives you structural context (callers, dependents, test coverage) that file search cannot.";

glob _INSTRUCTION_GUARDRAILS: any = "### Verify in the source\n\n- Answer from `include_source=True, expand_neighbors=True`; read a file only if truncated.\n- Do not change code from graph output alone: for any non-trivial change,\n  read the implementation and the relevant tests before concluding.\n- Verify the exact source when touching behavior, database logic, migrations, retries, fallbacks,\n  recovery, or compatibility code.\n- When the graph and the source disagree, the source wins. The graph may be stale.\n- An empty graph result can mean \"not indexed\" or \"not statically visible\", not \"does not exist\".";

glob _CLAUDE_MD_SECTION: any = f"{_CLAUDE_MD_SECTION_MARKER}\n## MCP Tools: code-review-graph\n\n{_INSTRUCTION_INTRO}\n\n### When to use graph tools FIRST\n\n- **Exploring code**: `semantic_search_nodes_tool(include_source=True, expand_neighbors=True)`\n- **Understanding impact**: `get_impact_radius_tool` instead of manually tracing imports\n- **Code review**: `detect_changes_tool` + `get_review_context_tool` instead of reading entire files\n- **Finding relationships**: `query_graph_tool` with callers_of/callees_of/imports_of/tests_for\n- **Architecture questions**: `get_architecture_overview_tool` + `list_communities_tool`\n\n{_INSTRUCTION_GUARDRAILS}\n\n### Key Tools\n\n| Tool | Use when |\n| ------ | ---------- |\n| `detect_changes_tool` | Reviewing code changes — gives risk-scored analysis |\n| `get_review_context_tool` | Need source snippets for review — token-efficient |\n| `get_impact_radius_tool` | Understanding blast radius of a change |\n| `get_affected_flows_tool` | Finding which execution paths are impacted |\n| `query_graph_tool` | Tracing callers, callees, imports, tests, dependencies |\n| `semantic_search_nodes_tool` | Finding functions/classes by name or keyword |\n| `get_architecture_overview_tool` | Understanding high-level codebase structure |\n| `refactor_tool` | Planning renames, finding dead code |\n\n### Workflow\n\n1. The graph auto-updates on file changes (via hooks).\n2. Use `detect_changes_tool` for code review.\n3. Use `get_affected_flows_tool` to understand impact.\n4. Use `query_graph_tool` pattern=\"tests_for\" to check coverage.\n{_CLAUDE_MD_SECTION_END_MARKER}\n";

glob _COPILOT_SECTION: any = f"---\napplyTo: '**'\ndescription: >-\n  Use code-review-graph MCP tools for token-efficient\n  codebase exploration and code review.\n---\n\n{_CLAUDE_MD_SECTION_MARKER}\n## MCP Tools: code-review-graph\n\n{_INSTRUCTION_INTRO}\n\n### When to use graph tools FIRST\n\n- **Exploring code**: `semantic_search_nodes_tool` or `query_graph_tool`\n- **Understanding impact**: `get_impact_radius_tool`\n- **Code review**: `detect_changes_tool` + `get_review_context_tool`\n- **Finding relationships**: `query_graph_tool` callers_of/callees_of\n- **Architecture questions**: `get_architecture_overview_tool`\n\n{_INSTRUCTION_GUARDRAILS}\n\n### Key Tools\n\n| Tool | Use when |\n| ------ | ---------- |\n| `detect_changes_tool` | Risk-scored change analysis |\n| `get_review_context_tool` | Token-efficient source snippets |\n| `get_impact_radius_tool` | Blast radius of a change |\n| `get_affected_flows_tool` | Impacted execution paths |\n| `query_graph_tool` | Trace callers, callees, imports, tests |\n| `semantic_search_nodes_tool` | Find functions/classes by keyword |\n| `get_architecture_overview_tool` | High-level structure |\n| `refactor_tool` | Rename planning, dead code |\n\n### Workflow\n\n1. The graph auto-updates on file changes (via hooks).\n2. Use `detect_changes_tool` for code review.\n3. Use `get_affected_flows_tool` to understand impact.\n4. Use `query_graph_tool` pattern=\"tests_for\" to check coverage.\n{_CLAUDE_MD_SECTION_END_MARKER}\n";

glob _PLATFORM_INSTRUCTION_CUSTOM_SECTIONS: dict[str, tuple[str, str]] = {
    ".github/instructions/code-review-graph.instructions.md": (
        _CLAUDE_MD_SECTION_MARKER,
        _COPILOT_SECTION,
    ),
    ".github/code-review-graph.instruction.md": (_CLAUDE_MD_SECTION_MARKER, _COPILOT_SECTION),
};

def _known_instruction_sections -> tuple[str, ...];
def _upgrade_managed_block(existing: str, section: str) -> str | None;
def _inject_instructions(file_path: Path, marker: str, section: str) -> str;
def inject_claude_md(repo_root: Path) -> str;

glob _PLATFORM_INSTRUCTION_FILES: dict[str, tuple[str, ...]] = {
    "AGENTS.md": ("cursor", "opencode", "mimo", "antigravity", "codex", "hermes", "dsh"),
    "GEMINI.md": ("antigravity", "gemini-cli"),
    ".cursorrules": ("cursor",),
    ".windsurfrules": ("windsurf",),
    "QODER.md": ("qoder",),
    ".kiro/steering/code-review-graph.md": ("kiro",),
    ".github/instructions/code-review-graph.instructions.md": ("copilot", "copilot-cli"),
    "CODEBUDDY.md": ("codebuddy",),
};

glob _LEGACY_PLATFORM_INSTRUCTION_FILES: dict[str, tuple[str, ...]] = {
    ".github/code-review-graph.instruction.md": ("copilot", "copilot-cli"),
};

def _remove_legacy_instruction_file(path: Path);

glob _GEMINI_CLI_HOOK_FILENAMES: any = ("crg-session-start.sh", "crg-update.sh");

def install_gemini_cli_hooks(repo_root: Path) -> Path | None;
def install_gemini_cli_skills(repo_root: Path) -> Path;
def install_codebuddy_skills(repo_root: Path) -> Path;
def inject_platform_instructions(repo_root: Path, target: str = "all") -> list[str];
def instruction_file_wanted(
    owners: Iterable[str], target: str, platforms: Iterable[str] | None = None
) -> bool;
def inject_instruction_files(
    repo_root: Path,
    target: str = "all",
    *,
    include_claude_md: bool = True,
    platforms: Iterable[str] | None = None,
) -> dict[str, str];
def generate_cursor_hooks_config -> dict[str, Any];
def _cursor_hook_scripts -> dict[str, str];
def install_cursor_hooks -> Path | None;
def bundled_skills_dir -> Traversable | None;
def bundled_skill_names -> tuple[str, ...];
def install_qoder_skills(repo_root: Path) -> Path | None;
def install_hermes_skills(repo_root: Path) -> Path;
def _detect_opencode_major_version -> int | None;
def _opencode_v1_plugin_content -> str;
def _opencode_v2_plugin_content -> str;

glob _OPENCODE_RUN_QUIET: any = "async function runQuiet(args: string[], cwd: string, timeoutMs: number): Promise<string> {\n  try {\n    const { stdout } = await execFileAsync(\"code-review-graph\", args, {\n      cwd,\n      timeout: timeoutMs,\n    })\n    return String(stdout ?? \"\").trim()\n  } catch (error) {\n    logFailure(args, error)\n    return \"\"\n  }\n}\n";

glob _OPENCODE_PINNED_RUN_QUIET: any = "// The copy of code-review-graph that ran install, then the one on PATH.\nconst CRG_COMMANDS: string[][] = __CRG_COMMANDS__\n\nasync function runQuiet(args: string[], cwd: string, timeoutMs: number): Promise<string> {\n  for (const [file, ...prefix] of CRG_COMMANDS) {\n    try {\n      const { stdout } = await execFileAsync(file, [...prefix, ...args], {\n        cwd,\n        timeout: timeoutMs,\n      })\n      return String(stdout ?? \"\").trim()\n    } catch (error) {\n      // Try the next copy only when this one is not there at all.\n      if ((error as { code?: unknown } | null)?.code !== \"ENOENT\") {\n        logFailure(args, error)\n        return \"\"\n      }\n    }\n  }\n  return \"\"\n}\n";

def _opencode_plugin_content(
    major_version: int = 2, launcher: Sequence[str] = ("code-review-graph",)
) -> str;
def _opencode_plugin_path -> Path;
def install_opencode_plugin(opencode_major: int | None = None) -> Path;
