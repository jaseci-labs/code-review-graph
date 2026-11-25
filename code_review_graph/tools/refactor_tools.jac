"""Tools 17, 18: refactor_func, apply_refactor_func."""

import from __future__ { annotations }

import from pathlib { Path }

import from typing { Any }

glob _MAX_REFACTOR_RESULTS: any = 150;

glob _MINIMAL_DEAD_FIELDS: any = ("name", "kind", "relative_path", "line");

glob _MINIMAL_SUGGESTION_FIELDS: any = ("type", "description", "symbols");

glob _MINIMAL_EDIT_FIELDS: any = ("file", "line", "confidence");

"""Keep only *fields* on each row, dropping keys the row does not have."""
def _project(rows: list[dict[str, Any]], fields: tuple[str, ...]) -> list[dict[str, Any]];

"""Unified refactoring entry point.

    [REFACTOR] Supports three modes:
    - ``rename``: Preview renaming a symbol (requires *old_name* and
      *new_name*).
    - ``dead_code``: Find unreferenced functions/classes.
    - ``suggest``: Get community-driven refactoring suggestions.

    Args:
        mode: One of ``"rename"``, ``"dead_code"``, or ``"suggest"``.
        old_name: (rename mode) Current symbol name.
        new_name: (rename mode) Desired new name.
        kind: (dead_code mode) Optional node kind filter.
        file_pattern: (dead_code mode) Optional file path substring filter.
        repo_root: Repository root path. Auto-detected if omitted.
        max_results: Maximum edits/symbols/suggestions to include in the
            response (default 50, capped at 150). ``total`` always reports
            the untruncated count. The stored rename preview keeps every
            edit, so ``apply_refactor_tool`` still applies the full set.
        detail_level: "standard" (default) returns full records; "minimal"
            keeps only the identifying fields per record.

    Returns:
        Mode-specific results dict with ``total`` and ``truncated``.
    """
def refactor_func(
    mode: str = "rename",
    old_name: str | None = None,
    new_name: str | None = None,
    kind: str | None = None,
    file_pattern: str | None = None,
    repo_root: str | None = None,
    max_results: int = 50,
    detail_level: str = "standard",
) -> dict[str, Any];

"""Apply a previously previewed refactoring to source files.

    [REFACTOR] Validates the refactor_id, checks expiry, ensures all edit
    paths are within the repo root, then performs exact string replacements.

    Args:
        refactor_id: ID returned by a prior ``refactor_tool(mode="rename")``
            call.
        repo_root: Repository root path. Auto-detected if omitted.
        dry_run: If True, return a unified diff of what would change
            without touching disk. The refactor_id remains valid so the
            user can review the diff, then call again with ``dry_run=False``
            to actually write the changes. See: #176
        max_diff_files: Maximum per-file diffs to include in a dry run
            (default 25, capped at 150). Renaming a widely-used symbol
            produces one diff per touched file; ``would_modify`` still
            lists every file that would change, and the write path is
            never affected.

    Returns:
        Status with count of applied edits and modified files. When
        ``dry_run=True`` the response additionally contains ``would_modify``
        (list of file paths), ``diffs`` (map of file -> unified-diff
        string), and ``diffs_truncated``.
    """
def apply_refactor_func(
    refactor_id: str, repo_root: str | None = None, dry_run: bool = False, max_diff_files: int = 25
) -> dict[str, Any];
