"""The opt-in ``.gitignore`` block for files ``install`` created (#471).

``install --gitignore`` adds one marked block to the repository's
``.gitignore``. The block lists the files and folders that run created and
that git does not track. A path that existed before the run is never listed,
so nothing a user wrote is ignored, and a tracked path is never listed. A
folder the run created is listed whole. Running install again merges into the
same block instead of adding a second one. ``uninstall`` removes the block and
nothing else.

The ``.code-review-graph/`` entry has its own handling in
:func:`incremental.ensure_repo_gitignore_excludes_crg` and is not touched here.
"""

import builtins;

import operator;

import from __future__ { annotations }

import logging;

import os;

import re;

import subprocess;

import from collections.abc { Iterable }

import from dataclasses { dataclass, field }

import from pathlib { Path, PurePath, PurePosixPath }

glob logger: any;

glob BLOCK_START: any;

glob BLOCK_NOTE: any;

glob BLOCK_END: any;

glob _ENTRY: any;

with entry {
    logger = logging.getLogger(__name__);

    BLOCK_START = "# >>> code-review-graph install files >>>";
    BLOCK_NOTE = "# Added by `code-review-graph install --gitignore`. `uninstall` removes this block.";
    BLOCK_END = "# <<< code-review-graph install files <<<";
    _ENTRY = re.compile("/[A-Za-z0-9._-]+(?:/[A-Za-z0-9._-]+)*/?");
}

"""What was on disk before install wrote anything."""
@dataclass(frozen=True)
class Plan {
    has files: tuple[str, ...];

    has existed: frozenset[str];
}

"""What happened to the block.

    ``status`` is one of ``"written"``, ``"unchanged"``, ``"edited"`` (the
    block was changed by hand and is left alone), ``"not-git"`` or
    ``"error"``.
    """
@dataclass
class Result {
    has status: str;

    has added: list[str] = field(default_factory=list[any]);

    has entries: list[str] = field(default_factory=list[any]);

    has detail: str = "";
}

"""Return ``path`` relative to the repository, or None when outside it."""
def _relative(repo_root: Path, path: Path) -> str | None;

"""Return the files ``install`` may write inside the repository.

    Follows the steps in ``cli._handle_init`` for the same options. Files
    outside the repository, such as user-level configs and ``.git/hooks``, are
    left out because no ``.gitignore`` in the repository applies to them.
    ``platforms`` is :func:`skills.selected_platforms`, worked out by the caller.
    """
def repo_files(
    repo_root: Path,
    target: str,
    *,
    with_skills: bool,
    with_hooks: bool,
    with_instructions: bool,
    platforms: Iterable[str] | None = None,
) -> list[str];

"""Map every file and every folder above it to whether it is a folder."""
def _with_folders(files: Iterable[str]) -> dict[str, bool];

"""Record which of install's paths exist. Call it before install writes."""
def plan(
    repo_root: Path,
    target: str,
    *,
    with_skills: bool,
    with_hooks: bool,
    with_instructions: bool,
    platforms: Iterable[str] | None = None,
) -> Plan;

def _git(repo_root: Path, args: list[str], stdin: str | None = None) -> str | None;

def _in_git_work_tree(repo_root: Path) -> bool;

"""git could not say which files it tracks."""
obj _GitError(Exception) {
    def __repr__ -> str;

    def __eq__(other: any) -> bool;

    def __hash__ -> int;
}

"""Return the tracked files at or under any of ``paths``.

    Raises :class:`_GitError` rather than guess: an empty answer would let a
    tracked file into the block.
    """
def _tracked(repo_root: Path, paths: Iterable[str]) -> set[str];

def _holds_tracked(path: str, tracked: set[str]) -> bool;

"""Return the entries some ignore rule already covers.

    A folder entry keeps its trailing slash, which tells git it is a folder
    even before it exists.
    """
def _ignored(repo_root: Path, entries: list[str]) -> set[str];

"""Return the top-most paths this run created, folders ending with ``/``."""
def _created_entries(repo_root: Path, install_plan: Plan, dry_run: bool) -> list[str];

"""Return the block's first and last line index, ``"edited"`` or None."""
def _find_block(lines: list[str]) -> tuple[int, int] | str | None;

def _block_entries(lines: list[str], start: int, end: int) -> list[str];

def _render(entries: list[str], newline: str) -> str;

"""Return the text with the block at ``start``..``end`` holding ``entries``.

    No entries removes the block. A block added to a file with no final
    newline brought the newline that ends the line before it, and leaves its
    own last line unended to say so. Removing such a block takes that newline
    back, so the file ends as it did before.
    """
def _replace_block(lines: list[str], start: int, end: int, entries: list[str], newline: str) -> str;

"""Remove the block from ``text``, used by ``uninstall``.

    Returns the new text and ``"removed"``, ``"absent"`` or ``"edited"``. The
    block's own lines, and the newline it added before itself, are the only
    bytes removed, so the text around it comes back exactly as it was. A
    block that was edited by hand is left alone.
    """
def remove_block(text: str) -> tuple[str, str];

"""Merge what this run created into the block.

    With ``dry_run`` nothing is written: every planned path that does not
    exist yet is taken as created, and the result says what would change.
    ``install`` itself calls this inside its plan (#173), where the files the
    plan creates count as created and the write is held with the rest.
    """
def apply(repo_root: Path, install_plan: Plan, *, dry_run: bool) -> Result;
