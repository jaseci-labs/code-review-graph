"""CLI entry point for code-review-graph.

Usage:
    code-review-graph install
    code-review-graph init
    code-review-graph uninstall [--platform NAME] [--dry-run] [--yes] [--repo PATH]
    code-review-graph build [--base BASE]
    code-review-graph update [--base BASE]
    code-review-graph forget PATH [PATH ...] [--dry-run]
    code-review-graph watch
    code-review-graph status
    code-review-graph serve [--auto-watch] [--http] [--host ADDR] [--port PORT] [--multi-repo]
    code-review-graph mcp [--auto-watch]
    code-review-graph visualize
    code-review-graph wiki
    code-review-graph detect-changes [--base BASE] [--brief]
    code-review-graph register <path> [--alias name]
    code-review-graph unregister <path_or_alias>
    code-review-graph repos
    code-review-graph daemon start [--foreground]
    code-review-graph daemon stop
    code-review-graph daemon restart [--foreground]
    code-review-graph daemon status
    code-review-graph daemon logs [--repo ALIAS] [--follow] [--lines N]
    code-review-graph daemon add <path> [--alias NAME]
    code-review-graph daemon remove <path_or_alias>
"""

import importlib;

import operator;

import from __future__ { annotations }

import builtins;

import sys;

glob logger: any;

glob _PLATFORM_CHOICES: any;

glob _GITIGNORE_HELP: any;

glob _BANNER_GROUPS: tuple[tuple[str, tuple[tuple[str, str], ...]], ...];

glob _HIDDEN_COMMANDS: any;

glob _STEERING_HELP: any;

glob _GRAPH_TOOL_COMMANDS: any;

glob _PATH_REPO_COMMANDS: any;

glob EXIT_TEMPFAIL: any;

glob _BUILD_NEXT_STEP: any;

glob _SUBCOMMANDS: dict[str, argparse.ArgumentParser];

with entry {
    if sys.version_info < (3, 10) {
        print("code-review-graph requires Python 3.10 or higher.");
        print(f"  You are running Python {sys.version}");
        print();
        print("Install Python 3.10+: https://www.python.org/downloads/");
        sys.exit(1);
    }

    logger = logging.getLogger(__name__);
    _PLATFORM_CHOICES = [
        "codex",
        "claude",
        "claude-code",
        "cursor",
        "windsurf",
        "zed",
        "continue",
        "opencode",
        "mimo",
        "antigravity",
        "gemini-cli",
        "qwen",
        "kiro",
        "qoder",
        "copilot",
        "copilot-cli",
        "codebuddy",
        "hermes",
        "dsh",
        "all",
    ];

    _GITIGNORE_HELP = "Also add the files and folders this run creates, and git does not track, to a marked block in .gitignore. Off by default; uninstall removes the block";
}

import argparse;

import contextlib;

import difflib;

import fnmatch;

import io;

import json;

import logging;

import os;

import sqlite3;

import from functools { partial }

import from importlib.metadata { PackageNotFoundError }

import from importlib.metadata { version as pkg_version }

import from pathlib { Path }

import from typing { TYPE_CHECKING, Callable, Iterable, TypedDict }

class _EmbeddingRefreshKwargs(TypedDict, total=False) {
    has embedding_provider: str;

    has embedding_model: str;
}

class _FollowSymlinksKwargs(TypedDict, total=False) {
    has follow_symlinks: bool;
}

"""Get the installed package version.

    Tries ``importlib.metadata`` first (canonical source from the installed
    dist-info), falling back to the package's ``__version__`` attribute if
    metadata is unavailable or corrupt. This matters for editable installs
    on filesystems where iCloud / OneDrive can leave orphan dist-info dirs
    behind that confuse importlib.metadata's lookup.
    """
def _get_version -> str;

"""Check if the terminal likely supports ANSI colors."""
def _supports_color -> bool;

"""Print the startup banner with graph art and available commands."""
def _print_banner -> None;

with entry {
    _BANNER_GROUPS = (
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
    _HIDDEN_COMMANDS = frozenset({"enrich", "hook-update", "hook-status"});
}

"""Render ``_BANNER_GROUPS`` as the banner's command list."""
def _banner_commands(bold: str, green: str, reset: str) -> str;

"""Return ``(filename, how)`` for each instruction file that ``install``
    would write or modify, given the current state of the repo and the
    selected platform target. Shown before the question about them (#173).

    A file holding a section from an older release is listed as ``update``:
    install replaces that block in place rather than leaving it stale (#314).
    ``platforms`` narrows ``"all"`` to the platforms ``install`` selected.
    """
def _instruction_files_to_modify(
    repo_root: Path, target: str, platforms: Iterable[str] | None = None
) -> list[tuple[str, str]];

"""Prompt the user [Y/n] and return True for yes.

    Non-interactive environments (no TTY on stdin, e.g. an MCP wrapper
    piping the CLI) return ``default_yes`` without blocking — the
    stdio transport cannot safely read from stdin without corrupting
    the JSON-RPC stream. See: #173, #174. They say so, with
    ``no_terminal_hint`` on how to get the other answer, so an agent that
    runs the command knows a question was answered for it.

    Ctrl-C counts as "no" unless ``cancel_on_interrupt`` is set, in which case
    it is raised so the caller can stop altogether. The end of input takes the
    default like a pipe: on Windows, stdin from ``NUL`` says it is a terminal.
    """
def _confirm_yes_no(
    prompt: str,
    default_yes: bool = True,
    *,
    cancel_on_interrupt: bool = False,
    no_terminal_hint: str = "",
) -> bool;

"""Resolve user-supplied paths/globs to stored graph file paths.

    The graph keys every parsed file by its absolute path. A user may name a
    file with an absolute path, a path relative to the repository root, a
    directory whose contents should all be dropped, or a glob pattern. Each
    stored file is compared against every pattern in all of those forms and the
    sorted set of matching stored paths is returned.
    """
def _match_files_to_forget(
    stored_files: Iterable[str], patterns: Iterable[str], repo_root: Path
) -> list[str];

with entry {
    _STEERING_HELP = "Claude Code only: add (or, with --no-steering, remove) a hook that puts graph context beside each search and read. Off unless asked for; it uses a few hundred tokens at most on each call";
}

"""Drop a progress message: a dry run shows that change as a diff instead."""
def _say_nothing(*_args_: object, **_kwargs: object) -> None;

"""Add or remove the steering hook, as ``--steering`` or ``--no-steering`` asked.

    Called inside the install plan in both modes, so the change is planned
    with the rest and a dry run shows it as a diff.
    """
def _apply_steering_choice(
    repo_root: Path, target: str, steering: bool, *, skip_hooks: bool, dry_run: bool
) -> None;

"""Plan the --gitignore block and say what it does (#471).

    Called inside the install plan in both modes, so the block is worked out
    from the files the plan creates and the dry run lists exactly what a real
    install writes.
    """
def _report_gitignore_block(repo_root: Path, plan: _GitignorePlan, *, dry_run: bool) -> None;

"""Set up MCP config, hooks, skills and instructions for AI coding platforms.

    Every write is planned in memory first (see ``install_plan``). ``--dry-run``
    prints the plan as diffs and writes nothing. A real install lists the files
    it will change and asks about instruction files before it writes anything,
    then writes exactly that plan (#173).
    """
def _handle_init(args: argparse.Namespace) -> None;

"""Plan the MCP server entry for each platform and say what it does."""
def _plan_mcp_configs(
    repo_root: Path, target: str, dry_run: bool, platforms: Iterable[str] | None = None
) -> None;

"""Plan the .gitignore entry, skills and hooks. Return a Codex skill error, if any.

    Platform-native skills and hooks are installed by default where supported
    so the graph tools are used proactively; ``--no-skills`` and ``--no-hooks``
    opt out. The legacy ``--skills``/``--hooks``/``--all`` flags are still
    accepted and do nothing. ``say`` prints a message that only reports a
    write; a warning is printed in both modes. Skills and hooks are written
    only for ``platforms``, by default :func:`skills.selected_platforms`.
    """
def _plan_integrations(
    args: argparse.Namespace,
    repo_root: Path,
    target: str,
    platforms: Iterable[str] | None = None,
    *,
    say: Callable[[str], None],
) -> str | None;

"""Name each file whose graph block was edited by hand, so left alone (#314)."""
def _print_instruction_conflicts(outcomes: dict[str, str]) -> None;

"""List each file a real install is about to write, before it writes any.

    ``skip`` holds the instruction changes, listed apart because they wait on
    the question.
    """
def _print_planned_files(
    plan: install_plan.Plan, repo_root: Path, `skip: Iterable[install_plan.FileChange] = ()
) -> None;

"""Show what each file would become, then say that nothing was written."""
def _print_dry_run(plan: install_plan.Plan, repo_root: Path) -> None;

"""Handle --data-dir option by updating registry if specified."""
def _handle_data_dir_option(args, repo_root: Path) -> None;

"""Add explicit, provider-scoped refresh options to a CLI command."""
def _add_embedding_refresh_args(command) -> None;

"""Add the opt-in for following symlinked folders inside the repo (#269)."""
def _add_follow_symlinks_arg(command) -> None;

"""Pass the flag on only when it was given; otherwise the env var decides."""
def _follow_symlinks_kwargs(args) -> _FollowSymlinksKwargs;

"""Validate the all-or-nothing provider/model opt-in."""
def _embedding_refresh_kwargs(args, parser) -> _EmbeddingRefreshKwargs;

"""Parse a non-negative integer for bounded CLI output."""
def _non_negative_int(value: str) -> int;

"""Parse a positive integer for CLI limits."""
def _positive_int(value: str) -> int;

"""Parse ``detect-changes --details``; an unknown name is a usage error."""
def _detail_sections_arg(value: str) -> tuple[str, ...];

with entry {
    _GRAPH_TOOL_COMMANDS = {
        "query",
        "impact",
        "search",
        "flows",
        "flow",
        "communities",
        "community",
        "architecture",
        "large-functions",
        "refactor",
    };

    _PATH_REPO_COMMANDS = frozenset({
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
}

"""Canonicalize path-valued ``--repo`` arguments in place.

    Commands whose ``--repo`` value is a repository *name* rather than a path
    (eval configs and daemon log aliases) are deliberately excluded. Every
    path consumer receives the same absolute, symlink-resolved spelling before
    it opens a database or compares stored paths.
    """
def _canonicalize_repo_argument(args: argparse.Namespace) -> None;

"""Resolve an explicit --repo for graph-tool commands.

    Walks upward from ``start``, stopping at the nearest directory that
    contains a ``.code-review-graph``, ``.git``, or ``.svn`` marker. Unlike
    ``find_repo_root``, a registered subproject (``.code-review-graph``)
    counts as a boundary, so a monorepo subdirectory built with
    ``build --repo mono/module`` resolves to the module — not to the
    monorepo's top-level ``.git`` (#697).
    """
def _find_explicit_repo_root(start: Path) -> "Path | None";

"""Report on the setup, read-only; exit 1 when a check failed."""
def _handle_doctor(args) -> None;

"""Print the opt-in context history log as a trend (#813).

    Reads only. A repository with no log, or no data directory at all, gets
    a hint and exit 0, and nothing is created.
    """
def _handle_context_history(args) -> None;

"""Run one graph-tool CLI wrapper and emit exactly one JSON value."""
def _run_graph_tool_command(args, repo_root: Path) -> None;

with entry {
    EXIT_TEMPFAIL = getattr(os, "EX_TEMPFAIL", 75);
}

"""Stop when another writer already owns this repository's graph.

    The process holding the lock is writing the same graph, so this invocation
    has nothing left to do. ``EXIT_TEMPFAIL`` says so precisely: non-zero, so a
    caller cannot mistake a skip for success, but distinct from the exit code
    of an actual failure.
    """
def _exit_if_contended(result: dict) -> None;

"""Report files that failed to parse; their previous graph rows are kept."""
def _warn_failed_files(result: dict) -> None;

"""Open a store; CLI builds request recovery inside their write lock."""
def _open_graph_store(db_path: Path, command: str) -> any;

"""Stop with one line when ``--repo`` names no folder.

    The write commands used to make the folder, so a typed path left an
    empty one behind; stopping is the safer answer.
    """
def _require_repo_folder(repo_root: Path) -> None;

"""Let a plain directory pass tool validation, without opening graph.db.

    ``build``, ``update`` and ``postprocess`` all accept one, and each now
    reaches the tools before anything has created the data directory.
    """
def _ensure_project_marker(repo_root: Path) -> None;

"""``--enrich`` asks for Jedi; without it the env var decides (see full_build)."""
def _enrich_kwargs(args) -> dict;

with entry {
    _BUILD_NEXT_STEP = "Next: code-review-graph detect-changes --brief, or ask your assistant \"Review my changes\".";
}

"""Run writers before the generic CLI store initialization."""
def _handle_build_update(args, repo_root: Path, embedding_refresh_kwargs) -> None;

"""Print the Token Savings panel of a ``--brief`` review.

    With no changed function the response is almost empty, so the panel would
    claim nearly all of it saved for telling the reader nothing. One plain
    line says why there is no panel instead.
    """
def _print_savings_panel(
    args, repo_root: Path, changed: list[str], response: dict, original_tokens: int
) -> None;

"""Drop files from the graph. A real run holds the write lock throughout.

    Another writer does not cover this work, so standing down says nothing was
    forgotten. A dry run takes no lock, so it opens the graph read-only: a
    writable open would upgrade an older schema. *legacy* means the graph is
    still the old top-level ``.code-review-graph.db``; a real run moves it into
    *db_path* only once it holds the lock, and a dry run reads it where it is.
    """
def _handle_forget(args, repo_root: Path, db_path: Path, *, legacy: bool = False) -> None;

"""Main CLI entry point.

    Two families of failure are reported here rather than raised, because
    both of them are things the tool understands about itself.

    Everything the tool can explain is raised as a
    :class:`~code_review_graph.errors.CodeReviewGraphError` (a corrupt or
    foreign graph, a data directory it may not write to, a VCS it could not
    run) and printed in the house style the rest of the CLI already uses:
    one ``Error: ...`` line on stderr, exit 1, no traceback to decode.

    One of those is reported here only because nothing could be done about
    it earlier: an unreadable graph reaches ``build`` as a rebuild (see
    ``_open_graph_store``) and only every other command as a line.

    A contended graph is separate, and stays separate: it is reported, not
    raised, and never described as damage. The choice is deliberate:
    ``build`` and ``update`` are run from pre-commit hooks and editor hooks
    where blocking indefinitely would look like a hang, and retrying past
    SQLite's five-second wait would only lengthen a hang whose real cause is
    another process that has not finished. Failing immediately is also the
    recoverable outcome — the VCS anchor is written only by a build that ran
    to completion, so nothing marks the half-written graph as current and the
    next run rebuilds it.

    Anything else really is a bug and keeps its traceback.
    """
def main -> None;

with entry {
    _SUBCOMMANDS = {};
}

"""True when the visualize invocation asks for a neighbourhood view."""
def _is_seeded(args: argparse.Namespace) -> bool;

"""Reject visualize flag combinations that cannot mean anything.

    Every one of these used to be a silent no-op, which is the worst
    outcome: the command succeeds, the flag is ignored, and the user
    believes it took effect.
    """
def _check_visualize_flags(args: argparse.Namespace, fmt: str) -> None;

"""Say what ``--max-nodes`` cost, so a trimmed view is never silent."""
def _print_seed_budget(`report: dict) -> None;

"""One-line description of what the generated page shows."""
def _describe_visualization(args: argparse.Namespace, vis_mode: str, depth: int) -> str;

"""Build the CLI argument parser.

    Split out of :func:`_dispatch` so tests can assert on the flag surface
    without executing a command.
    """
def build_parser -> argparse.ArgumentParser;

"""Every top-level command name the parser accepts, hidden ones included."""
def _command_names(ap: argparse.ArgumentParser) -> list[str];

"""Stop on a mistyped command with a "did you mean", exit 2.

    argparse's own message lists every command, hidden ones too, in one long
    line and suggests nothing. The top level takes no option with a value, so
    the first word that is not an option is the command.
    """
def _reject_unknown_command(ap: argparse.ArgumentParser, argv: list[str]) -> None;

"""Parse arguments and run the requested subcommand."""
def _dispatch -> None;
