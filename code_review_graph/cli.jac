import from __future__ { annotations }

import importlib, operator, builtins, sys;
import argparse, contextlib, difflib, fnmatch, io, json, logging, os, sqlite3;
import from functools { partial }
import from importlib.metadata { PackageNotFoundError }
import from importlib.metadata { version as pkg_version }
import from pathlib { Path }
import from typing { TYPE_CHECKING, Callable, Iterable, TypedDict }

with entry {
    if sys.version_info < (3, 10) {
        print("code-review-graph requires Python 3.10 or higher.");
        print(f"  You are running Python {sys.version}");
        print();
        print("Install Python 3.10+: https://www.python.org/downloads/");
        sys.exit(1);
    }
}

glob logger: any = logging.getLogger(__name__);

glob _PLATFORM_CHOICES: any = ("codex claude claude-code cursor windsurf zed continue opencode mimo antigravity gemini-cli "
    "qwen kiro qoder copilot copilot-cli codebuddy hermes dsh all").split();

glob _GITIGNORE_HELP: any = "Also add the files and folders this run creates, and git does not track, to a marked block in .gitignore. Off by default; uninstall removes the block";

class _EmbeddingRefreshKwargs(TypedDict, total=False) {
    has embedding_provider: str;

    has embedding_model: str;
}

class _FollowSymlinksKwargs(TypedDict, total=False) {
    has follow_symlinks: bool;
}

def _get_version -> str;
def _supports_color -> bool;
def _print_banner;

glob _BANNER_GROUPS: tuple[tuple[str, tuple[tuple[str, str], ...]], ...] = (
    (
        "Set up",
        (
            ("install", "Set up the MCP server, hooks and skills for your AI tools"),
            ("init", "Same as install"),
            ("uninstall", "Remove what install added"),
            ("doctor", "Check which copies run, the graph and the hooks"),
        ),
    ),
    (
        "Build the graph",
        (
            ("build", "Parse every file into a new graph"),
            ("update", "Parse only the files that changed"),
            ("watch", "Update the graph as files change"),
            ("status", "Show graph counts"),
            ("postprocess", "Redo flows, communities and the search index"),
            ("embed", "Add vectors for search by meaning"),
            ("forget", "Drop files from the graph"),
        ),
    ),
    (
        "Review",
        (
            ("detect-changes", "Score the risk of your changes (read-only)"),
            ("impact", "Show what a change can reach"),
            ("dead-code", "Find code that nothing calls or tests"),
            ("refactor", "Preview a rename, dead code or suggestions"),
        ),
    ),
    (
        "Explore",
        (
            ("query", "Callers, callees, imports, tests and more"),
            ("search", "Find code by name or keyword"),
            ("architecture", "Show the main parts of the code"),
            ("flows", "List execution flows"),
            ("flow", "Show one execution flow"),
            ("communities", "List groups of related code"),
            ("community", "Show one group"),
            ("large-functions", "Find very long functions and classes"),
            ("visualize", "Draw the graph as an interactive page"),
            ("wiki", "Write a Markdown wiki from the graph"),
            ("context-history", "Show the saved-context log"),
        ),
    ),
    (
        "Serve and more",
        (
            ("serve", "Start the MCP server (stdio, or --http on localhost)"),
            ("mcp", "Same as serve"),
            ("daemon", "Watch many repositories in the background"),
            ("register", "Add a repository to the multi-repo list"),
            ("unregister", "Remove a repository from that list"),
            ("repos", "Show the listed repositories"),
            ("eval", "Run the benchmarks"),
        ),
    ),
);

glob _HIDDEN_COMMANDS: any = frozenset({"enrich", "hook-update", "hook-status"});

def _banner_commands(bold: str, green: str, reset: str) -> str;
def _instruction_files_to_modify(
    repo_root: Path, target: str, platforms: Iterable[str] | None = None
) -> list[tuple[str, str]];
def _confirm_yes_no(
    prompt: str,
    default_yes: bool = True,
    *,
    cancel_on_interrupt: bool = False,
    no_terminal_hint: str = "",
) -> bool;
def _match_files_to_forget(
    stored_files: Iterable[str], patterns: Iterable[str], repo_root: Path
) -> list[str];

glob _STEERING_HELP: any = "Claude Code only: add (or, with --no-steering, remove) a hook that puts graph context beside each search and read. Off unless asked for; it uses a few hundred tokens at most on each call";

def _say_nothing(*_args_: object, **_kwargs: object);
def _apply_steering_choice(
    repo_root: Path, target: str, steering: bool, *, skip_hooks: bool, dry_run: bool
);
def _report_gitignore_block(repo_root: Path, plan: _GitignorePlan, *, dry_run: bool);
def _handle_init(args: argparse.Namespace);
def _plan_mcp_configs(
    repo_root: Path, target: str, dry_run: bool, platforms: Iterable[str] | None = None
);
def _plan_integrations(
    args: argparse.Namespace,
    repo_root: Path,
    target: str,
    platforms: Iterable[str] | None = None,
    *,
    say: Callable[[str], None],
) -> str | None;
def _print_instruction_conflicts(outcomes: dict[str, str]);
def _print_planned_files(
    plan: install_plan.Plan, repo_root: Path, `skip: Iterable[install_plan.FileChange] = ()
);
def _print_dry_run(plan: install_plan.Plan, repo_root: Path);
def _handle_data_dir_option(args, repo_root: Path);
def _add_embedding_refresh_args(command);
def _add_follow_symlinks_arg(command);
def _follow_symlinks_kwargs(args) -> _FollowSymlinksKwargs;
def _embedding_refresh_kwargs(args, parser) -> _EmbeddingRefreshKwargs;
def _non_negative_int(value: str) -> int;
def _positive_int(value: str) -> int;
def _detail_sections_arg(value: str) -> tuple[str, ...];

glob _GRAPH_TOOL_COMMANDS: any = set(
    ("query impact search flows flow communities community architecture large-functions refactor").split(),
);

glob _PATH_REPO_COMMANDS: any = frozenset({
    "context-history",
    "doctor",
    "install",
    "init",
    "uninstall",
    "build",
    "update",
    "postprocess",
    "embed",
    "watch",
    "status",
    "forget",
    "visualize",
    "wiki",
    "detect-changes",
    "dead-code",
    "serve",
    "mcp",
    *_GRAPH_TOOL_COMMANDS,
});

def _canonicalize_repo_argument(args: argparse.Namespace);
def _find_explicit_repo_root(start: Path) -> "Path | None";
def _handle_doctor(args);
def _handle_context_history(args);
def _run_graph_tool_command(args, repo_root: Path);

glob EXIT_TEMPFAIL: any = getattr(os, "EX_TEMPFAIL", 75);

def _exit_if_contended(result: dict);
def _warn_failed_files(result: dict);
def _open_graph_store(db_path: Path, command: str) -> any;
def _require_repo_folder(repo_root: Path);
def _ensure_project_marker(repo_root: Path);
def _enrich_kwargs(args) -> dict;

glob _BUILD_NEXT_STEP: any = "Next: code-review-graph detect-changes --brief, or ask your assistant \"Review my changes\".";

def _handle_build_update(args, repo_root: Path, embedding_refresh_kwargs);
def _print_savings_panel(
    args, repo_root: Path, changed: list[str], response: dict, original_tokens: int
);
def _handle_forget(args, repo_root: Path, db_path: Path, *, legacy: bool = False);
def main;

glob _SUBCOMMANDS: dict[str, argparse.ArgumentParser] = {};

def _is_seeded(args: argparse.Namespace) -> bool;
def _check_visualize_flags(args: argparse.Namespace, fmt: str);
def _print_seed_budget(`report: dict);
def _describe_visualization(args: argparse.Namespace, vis_mode: str, depth: int) -> str;
def build_parser -> argparse.ArgumentParser;
def _command_names(ap: argparse.ArgumentParser) -> list[str];
def _reject_unknown_command(ap: argparse.ArgumentParser, argv: list[str]);
def _dispatch;
