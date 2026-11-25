"""Safely reverse artifacts created by :mod:`code_review_graph.skills`.

The original implementation was contributed by Stephen Cheng in PR #491.
This current-main replacement keeps that command/report design while deriving
the live MCP inventory from ``skills.PLATFORMS`` and treating every shared file
as user-owned data that may only be edited surgically.
"""

import builtins;

import operator;

import from __future__ { annotations }

import copy;

import importlib;

import json;

import os;

import shutil;

import stat;

import subprocess;

import sys;

import tempfile;

import from dataclasses { dataclass, field }

import from pathlib { Path }

import from typing { Any, Callable, Sequence }

glob _tomllib: Any;

glob _ENTRY_NAME: any;

glob _GIT_HOOK_MARKER: any;

glob _GITIGNORE_BANNER: any;

glob _remove_jsonc_paths: any;

with entry {
    _tomllib = importlib.import_module("tomllib" if sys.version_info >= (3, 11) else "tomli");

    _ENTRY_NAME = "code-review-graph";
    _GIT_HOOK_MARKER = skills._GIT_HOOK_NOTE;
    _GITIGNORE_BANNER = "# Added by code-review-graph";
}

"""Structured record of completed or planned uninstall actions."""
@dataclass
class UninstallReport {
    has removed_paths: list[str] = field(default_factory=list[any]);

    has edited_paths: list[str] = field(default_factory=list[any]);

    has skipped_paths: list[str] = field(default_factory=list[any]);

    has errors: list[str] = field(default_factory=list[any]);

    has touched: list[Path] = field(default_factory=list[any], repr=False, compare=False);

    has install_only: frozenset[str] = field(
        default_factory=builtins.frozenset, repr=False, compare=False
    );

    has total_actions: int {
        getter {
            return len(self.removed_paths) + len(self.edited_paths);
        }
    }
}

with entry {
    _remove_jsonc_paths = jsonc.remove_paths;
}

def _absolute(path: Path) -> Path;

def _is_lexical_child(path: Path, boundary: Path) -> bool;

"""Require lexical and resolved containment, with no symlink traversal."""
def _safe_path(
    path: Path, boundary: Path, `report: UninstallReport, *, describe_skip: bool = True
) -> bool;

"""Word an action for the report: ``detail`` starts with a verb in its base form.

    A dry run says what it would do ("would remove owned file"); a real run
    says what it did ("removed owned file").
    """
def _done(detail: str, dry_run: bool) -> str;

def _record_edit(`report: UninstallReport, path: Path, detail: str, dry_run: bool) -> None;

def _record_remove(`report: UninstallReport, path: Path, detail: str, dry_run: bool) -> None;

def _read_text(path: Path, `report: UninstallReport) -> str | None;

def _write_text(
    path: Path, text: str, `report: UninstallReport, *, detail: str, dry_run: bool
) -> None;

def _parse_jsonc(path: Path, raw: str, `report: UninstallReport) -> dict[str, Any] | None;

def _remove_mcp_entry(
    path: Path,
    *,
    key: str,
    format_name: str,
    boundary: Path,
    `report: UninstallReport,
    dry_run: bool,
) -> None;

def _remove_toml_entry(
    path: Path, key: str, boundary: Path, `report: UninstallReport, *, dry_run: bool
) -> None;

"""Cut the code-review-graph ``insert`` operation out of a DSH patch layer.

    Only that operation's lines go; comments, ``!!js`` values and every other
    operation stay byte-for-byte. A row someone merged into an ``insert`` of
    their own is reported, not edited.
    """
def _remove_dsh_patch_entry(
    path: Path, boundary: Path, `report: UninstallReport, *, dry_run: bool
) -> None;

"""Delete ``<key>.code-review-graph`` from a YAML config, text-surgically.

    The rest of the document — comments, ordering, formatting — is preserved
    byte-for-byte; the parsed document is used only to locate the entry and to
    validate the result before writing.
    """
def _remove_yaml_entry(
    path: Path, key: str, boundary: Path, `report: UninstallReport, *, dry_run: bool
) -> None;

def _commands(value: Any) -> set[str];

"""Exact project hook commands earlier releases wrote and install no longer does."""
def _legacy_repo_hook_commands(repo_root: Path) -> set[str];

"""Exact Codex hook commands earlier releases wrote and install no longer does."""
def _legacy_codex_hook_commands -> set[str];

"""Map the steering hook's command to the one event and matcher it is written under.

    Install writes it there and only there, so a copy anywhere else is the user's.
    Both spellings are listed: the one for the copy running now and the one
    that runs the copy on PATH, as 2.4.0 wrote it.
    """
def _steering_hook_scopes -> dict[str, tuple[str, Any]];

"""Return the one ``(event, matcher)`` install files the steering hook under."""
def _steering_hook_scope -> tuple[str, Any];

"""Drop owned hooks: ``owned_commands`` anywhere, ``scoped_commands`` only
    under their own ``(event, matcher)``.

    ``owns`` and ``scoped_owns`` do the same for a hook that names the copy
    which ran ``install``, which may not be the copy running now.
    """
def _clean_hook_data(
    data: dict[str, Any],
    owned_commands: set[str],
    scoped_commands: dict[str, tuple[str, Any]] | None = None,
    *,
    owns: Callable[[str], bool] | None = None,
    scoped_owns: tuple[Callable[[str], bool], tuple[str, Any]] | None = None,
) -> tuple[dict[str, Any], list[tuple[str | int, ...]]];

"""Remove only the opt-in steering hook from the project's Claude Code settings."""
def remove_steering_hook(repo_root: Path, *, dry_run: bool = False) -> UninstallReport;

"""``data`` with every server entry named ``code-review-graph`` taken out."""
def _without_our_servers(data: dict[str, Any]) -> dict[str, Any];

"""Remove the ``.bak`` install made of ``path`` when it holds only our content.

    Install backs a settings file up before it merges hooks in. When the file
    held only what install wrote (hooks from an earlier install, or the server
    entry it had just added), the backup is a copy of ours and nothing of the
    user's. A backup with anything else in it is the user's, and stays.
    """
def _remove_backup_of_ours(
    path: Path,
    owned_commands: set[str],
    boundary: Path,
    `report: UninstallReport,
    *,
    dry_run: bool,
    scoped_commands: dict[str, tuple[str, Any]] | None,
    owns: Callable[[str], bool] | None,
    scoped_owns: tuple[Callable[[str], bool], tuple[str, Any]] | None,
) -> None;

"""Take our hooks out of ``path``, and drop its backup if only ours is in it.

    ``backup=False`` leaves the backup alone, for a change smaller than an
    uninstall.
    """
def _remove_hooks(
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
) -> None;

"""True for ``{}``, ``[]``, or objects and lists made only of those."""
def _holds_nothing(value: Any) -> bool;

"""Write ``text`` back, or remove the file when install made it and nothing is left.

    Removed only when the install record lists the file, Git does not track
    it, and ``text`` is plain JSON (no comments) that holds nothing, such as
    ``{"mcpServers": {}}``. Anything else is written back as before.
    """
def _write_or_drop(
    path: Path, text: str, boundary: Path, `report: UninstallReport, *, detail: str, dry_run: bool
) -> None;

"""The files the install record lists that Git does not track, repo-relative.

    Empty when there is no record, or Git cannot say: then nothing is removed
    that would not have been removed before the record existed.
    """
def _install_only_files(repo_root: Path) -> list[str];

"""Remove the folders install wrote into, deepest first, when they are empty."""
def _prune_install_folders(repo_root: Path, relative_files: Sequence[str]) -> None;

def _remove_file(
    path: Path,
    boundary: Path,
    `report: UninstallReport,
    *,
    dry_run: bool,
    detail: str = "remove owned file",
) -> None;

def _remove_tree(path: Path, boundary: Path, `report: UninstallReport, *, dry_run: bool) -> None;

def _prune_empty_directory(path: Path, boundary: Path) -> None;

def _remove_skill_file(
    path: Path, boundary: Path, `report: UninstallReport, *, dry_run: bool
) -> None;

"""Close the gap a removed instruction block leaves behind.

    The text on either side is kept. Only the whitespace at the seam is
    normalised, so removing a block from the middle of a file does not leave a
    pile of blank lines where it used to be.
    """
def _join_without_instruction(before: str, after: str) -> str;

"""Strip every generated instruction block from a file.

    Only text that exactly equals a block this project generated is removed, so
    a section someone edited by hand survives and is reported instead. Blocks
    written before the closing marker existed have no end boundary, which is why
    nothing here searches for one: their full recorded text is the boundary.
    Matching every known variant means a block from any past release comes out,
    not just one written by the running version (#314).
    """
def _remove_instruction(
    path: Path, boundary: Path, `report: UninstallReport, *, dry_run: bool
) -> None;

def _resolve_git_hook(repo_root: Path, name: str = "pre-commit") -> Path;

"""Cut out every pre-commit block this project has ever written.

    Marked blocks are removed between their begin and end markers; blocks from
    releases that predate the markers are matched by their full recorded text,
    longest first. Nothing infers a block's extent from the shell inside it:
    the body nests an ``if``/``elif``/``else`` in an outer ``if``, so a rule
    such as "stop at the first ``fi``" leaves the outer ``fi`` behind and the
    hook becomes a syntax error that breaks every later ``git commit``.

    An unbalanced marker pair removes nothing at all: matching the body by its
    legacy text there would strip it and leave the orphan marker line sitting
    in the user's hook, which is neither a removal nor a refusal.
    """
def _strip_git_hook_blocks(raw: str) -> tuple[str, bool];

def _remove_git_hook(repo_root: Path, `report: UninstallReport, *, dry_run: bool) -> None;

"""Write back what is left of a hook, or delete it when only a shebang remains."""
def _rewrite_or_remove_hook(
    path: Path,
    new_text: str,
    repo_root: Path,
    `report: UninstallReport,
    *,
    detail: str,
    dry_run: bool,
) -> None;

"""Cut the marked sync block out of post-checkout, post-merge and post-rewrite."""
def _remove_git_sync_hooks(repo_root: Path, `report: UninstallReport, *, dry_run: bool) -> None;

def _remove_gitignore(repo_root: Path, `report: UninstallReport, *, dry_run: bool) -> None;

def _scope_for_config(
    path: Path, repo_root: Path, home: Path, extra_user_boundaries: Sequence[Path] = ()
) -> tuple[str, Path] | None;

def _process_platform_configs(
    repo_root: Path,
    home: Path,
    `report: UninstallReport,
    *,
    scope: str,
    dry_run: bool,
    platforms: frozenset[str] | None = None,
) -> None;

def _generated_skill_slugs -> list[str];

"""Return every ``.qoder/skills`` name this project has ever installed.

    Two shapes, because two releases wrote two different things:

    * Current (#909): ``install`` copies the workflows bundled in the
      distribution, so their names come from :func:`skills.bundled_skill_names`
      — the same answer the installer acts on. A normal user repository has no
      top-level ``skills/`` directory, so deriving the list from one removed
      nothing at all.
    * Before #909: ``install`` copied the *target project's* own top-level
      ``skills/`` directory. Repositories set up by those releases still carry
      those copies, and only that directory names them, so it is still read.

    Union, not replacement: dropping the legacy source would strand the files
    an older release installed.
    """
def _qoder_skill_names(repo_root: Path, `report: UninstallReport) -> list[str];

"""Clean only historical paths from #491 that are absent from live specs."""
def _remove_legacy_mcp_configs(
    repo_root: Path, home: Path, `report: UninstallReport, *, scope: str, dry_run: bool
) -> None;

def _process_repo(
    repo_root: Path,
    home: Path,
    `report: UninstallReport,
    *,
    keep_data: bool,
    dry_run: bool,
    platforms: frozenset[str] | None = None,
) -> None;

def _process_repo_files(
    repo_root: Path,
    home: Path,
    `report: UninstallReport,
    *,
    keep_data: bool,
    dry_run: bool,
    platforms: frozenset[str] | None = None,
) -> None;

def _process_user(
    reference_repo: Path,
    home: Path,
    `report: UninstallReport,
    *,
    keep_data: bool,
    dry_run: bool,
    platforms: frozenset[str] | None = None,
) -> None;

def _registry_repo_paths(home: Path, `report: UninstallReport) -> list[Path];

def _normalise_repo(path: Path, home: Path, `report: UninstallReport) -> Path | None;

"""Return the platform keys to scope an unbind to, or ``None`` for all.

    ``None``, an empty selection, or an explicit ``"all"`` disables scoping and
    restores the full uninstall. ``"claude-code"`` is accepted as an alias for
    ``"claude"`` so the flag matches the install command's spelling.
    """
def _normalise_platform_filter(platforms: Sequence[str] | None) -> frozenset[str] | None;

"""Uninstall CRG artifacts and return a precise action report.

    When ``platforms`` names one or more specific platforms, the run is scoped
    to *unbinding* those platforms: only their MCP server registration is
    removed and all graph data is preserved, regardless of ``keep_data``.
    """
def run(
    *,
    repo: Path | None = None,
    all_repos: bool = False,
    keep_data: bool = False,
    keep_user_configs: bool = False,
    dry_run: bool = False,
    platforms: Sequence[str] | None = None,
) -> UninstallReport;
