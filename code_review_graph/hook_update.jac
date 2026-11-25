"""Payload-scoped graph updates for agent hooks.

An edit hook acts on the repository that holds the edited file, not on the
directory the agent was started in. One session can sit in a folder of sibling
repositories, in an outer repository with nested ones, or in the main checkout
while it edits a linked worktree; in each case the right graph is the one next
to the file (#311).
"""

import operator;

import from __future__ { annotations }

import json;

import sqlite3;

import subprocess;

import sys;

import from pathlib { Path }

import from typing { Any }

glob _FILE_PATH_KEYS: any = ("file_path", "notebook_path");

def _payload_cwd(payload: Any) -> Path | None;

"""Return the file the tool call changed, when the payload names one.

    A relative path is read against the payload ``cwd``, and ignored without
    one, so a guess about where the file lives can never pick a repository.
    """
def _payload_file(payload: Any, cwd: Path | None) -> Path | None;

def _git(directory: Path, *args_: str) -> str | None;

"""Return the work tree that holds ``directory``: the innermost one."""
def _toplevel(directory: Path) -> Path | None;

"""Return the repository this one is a submodule of, if it is one.

    A nested repository that is not a submodule, and a linked worktree, are
    checkouts of their own: the outer repository's graph never holds their
    files, so they have no superproject here.
    """
def _superproject(repo_root: Path) -> Path | None;

"""The repository root a graph says it was built for, read without writing."""
def _recorded_root(db_path: Path) -> Path | None;

"""True when ``repo_root`` has a graph of its own.

    A graph in the default data directory, or at the legacy
    ``.code-review-graph.db`` that the update migrates, is the repository's.
    One anywhere else (``CRG_DATA_DIR`` or a registered ``--data-dir``) can be
    the database every repository resolves to, so it counts only when it
    records this repository as the one it was built for.
    """
def _has_graph(repo_root: Path) -> bool;

"""The nearest existing directory at or above ``path``."""
def _existing_dir(path: Path) -> Path | None;

"""Pick the graph to update for an edit to ``path``.

    The repository that holds the file is the answer when it already has a
    graph, or when it is the session's own repository, which is updated (and
    built on first use) exactly as before, unless ``existing_only`` says to
    build nothing. Any other repository is left alone, so an edit somewhere
    else on disk cannot start a build there. A submodule with no graph of its
    own hands the edit to its superproject, whose graph can hold the
    submodule's files.
    """
def _repo_for_file(path: Path, session_repo: Path | None, existing_only: bool = False) -> Path
    | None;

"""Read the event JSON as bytes, so json finds the UTF-8 hosts write.

    On Windows a text-mode stdin decodes a pipe with the ANSI code page.
    """
def _read_payload -> Any;

def _session_repo(payload: Any) -> Path | None;

"""The repository named by the payload ``cwd``, for the status hook."""
def _hook_repo -> Path | None;

"""The repository an edit hook should update, or None to do nothing."""
def _update_target(payload: Any, existing_only: bool = False) -> Path | None;

"""Update the graph of the repository that holds the edited file.

    Without a file path in the payload (a shell command, for example) the
    repository named by a valid payload ``cwd`` is updated, as before. With
    ``existing_only`` a repository with no graph is left alone rather than
    built: the Codex hook asks for that, as Codex builds a graph only when the
    user asks for one.
    """
def run_update_hook(existing_only: bool = False) -> None;

def _update_repo(repo_root: Path) -> None;

"""Delegate to the normal status command for a valid hook payload cwd.

    Status only informs. A repository with no graph is normal, so its
    diagnostic is enough and the session start must not report a failed hook.
    """
def run_status_hook -> None;
