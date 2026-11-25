"""Shared utilities for tool sub-modules."""

import from code_review_graph._lazy { lazy }

import importlib;

import operator;

import from __future__ { annotations }

import logging;

import sqlite3;

import subprocess;

import from datetime { datetime }

import from pathlib { Path }

import from typing { Any }

glob _PROVENANCE_READ_TIMEOUT_SECONDS: any = 0.05;

glob _PROVENANCE_GIT_TIMEOUT_SECONDS: any = 1.0;

glob logger: any;

glob _BUILTIN_CALL_NAMES: set[str];

with entry {
    logger = logging.getLogger(__name__);
}

"""Build a standardised error response dict."""
def _error_response(message: str, status: str = "error", **extra: Any) -> dict[str, Any];

"""Return the checked-out commit without making provenance mandatory.

    ``head_matches_build`` deliberately compares commits only. It does not
    claim that staged, unstaged, or untracked files are represented by the
    graph, avoiding the misleading ``is_stale=False`` contract from #458.
    """
def _read_live_git_head(`root: Path) -> str | None;

"""Return best-effort build metadata for one repository's graph.

    The metadata read is deliberately read-only. Missing, incomplete, or
    unreadable graph databases must never make the enclosing tool call fail.
    """
def graph_provenance(repo_root: str | None = None) -> dict[str, Any] | None;

"""Attach a ``_graph`` envelope without changing existing fields."""
def with_provenance(result: Any, repo_root: str | None = None) -> Any;

with entry {
    _BUILTIN_CALL_NAMES = {
        "map",
        "filter",
        "reduce",
        "reduceRight",
        "forEach",
        "find",
        "findIndex",
        "some",
        "every",
        "includes",
        "indexOf",
        "lastIndexOf",
        "push",
        "pop",
        "shift",
        "unshift",
        "splice",
        "slice",
        "concat",
        "join",
        "flat",
        "flatMap",
        "sort",
        "reverse",
        "fill",
        "keys",
        "values",
        "entries",
        "from",
        "isArray",
        "of",
        "at",
        "trim",
        "trimStart",
        "trimEnd",
        "split",
        "replace",
        "replaceAll",
        "match",
        "matchAll",
        "search",
        "substring",
        "substr",
        "toLowerCase",
        "toUpperCase",
        "startsWith",
        "endsWith",
        "padStart",
        "padEnd",
        "repeat",
        "charAt",
        "charCodeAt",
        "assign",
        "freeze",
        "defineProperty",
        "getOwnPropertyNames",
        "hasOwnProperty",
        "create",
        "is",
        "fromEntries",
        "log",
        "warn",
        "error",
        "info",
        "debug",
        "trace",
        "dir",
        "table",
        "time",
        "timeEnd",
        "assert",
        "clear",
        "count",
        "then",
        "catch",
        "finally",
        "resolve",
        "reject",
        "all",
        "allSettled",
        "race",
        "any",
        "parse",
        "stringify",
        "floor",
        "ceil",
        "round",
        "random",
        "max",
        "min",
        "abs",
        "pow",
        "sqrt",
        "addEventListener",
        "removeEventListener",
        "querySelector",
        "querySelectorAll",
        "getElementById",
        "createElement",
        "appendChild",
        "removeChild",
        "setAttribute",
        "getAttribute",
        "preventDefault",
        "stopPropagation",
        "setTimeout",
        "clearTimeout",
        "setInterval",
        "clearInterval",
        "toString",
        "valueOf",
        "toJSON",
        "toISOString",
        "getTime",
        "getFullYear",
        "now",
        "isNaN",
        "parseInt",
        "parseFloat",
        "toFixed",
        "encodeURIComponent",
        "decodeURIComponent",
        "call",
        "apply",
        "bind",
        "next",
        "emit",
        "on",
        "off",
        "once",
        "pipe",
        "write",
        "read",
        "end",
        "close",
        "destroy",
        "send",
        "status",
        "json",
        "redirect",
        "set",
        "get",
        "delete",
        "has",
        "findUnique",
        "findFirst",
        "findMany",
        "createMany",
        "update",
        "updateMany",
        "deleteMany",
        "upsert",
        "aggregate",
        "groupBy",
        "transaction",
        "describe",
        "it",
        "test",
        "expect",
        "beforeEach",
        "afterEach",
        "beforeAll",
        "afterAll",
        "mock",
        "spyOn",
        "require",
        "fetch",
    };
}

"""Validate that a path is a plausible project root.

    Ensures the path is an existing directory that contains a ``.git``,
    ``.svn``, or ``.code-review-graph`` directory, preventing arbitrary
    file-system traversal via the ``repo_root`` parameter.
    """
def _validate_repo_root(path: "Path | str") -> Path;

"""Resolve and validate the repository root without opening a store."""
def _resolve_root(repo_root: str | None = None) -> Path;

"""Open the graph store, recovering from an unusable database file.

    A restored CI cache can hold a truncated or half-written ``graph.db``,
    and it can just as easily hold a valid SQLite file whose tables are the
    wrong shape. SQLite refuses either one and the command used to die with a
    traceback, which is why ``action.yml``'s ``update || build`` fallback
    could not recover: the full build failed for exactly the same reason.
    ``build`` rewrites the graph from scratch, so there the bad file is
    discarded and the build proceeds.

    Every other command re-raises, and ``main`` prints the one actionable
    line the error already carries. That is the whole difference between the
    two paths, and it is worth stating why the reporting is not duplicated
    here: a second message would compete with the first, and one of them
    would drift.

    ``build`` discards only what ``CorruptGraphDatabaseError`` names, and
    that class is deliberately narrow. A contended database, a read-only
    checkout, a foreign SQLite file and a graph from a newer release all
    reach ``main`` as themselves, because deleting any of those would destroy
    a graph, or data, that is not broken.
    """
def _open_graph_store(db_path: Path, command: str) -> any;

"""Resolve repo root and open the graph store.

    Callers own the returned store and must close it (try/finally or
    context manager) to avoid leaking SQLite file descriptors.

    A graph built for another repository is refused here rather than
    answered from: every tool wraps its body in ``except Exception`` and
    reports ``{"status": "error"}``, so the caller is told which repository
    the graph belongs to instead of being served its symbols.
    """
def _get_store(
    repo_root: str | None = None, *, db_path: Path | None = None, recover_corrupt: bool = False
) -> tuple[GraphStore, Path];

"""Compatibility wrapper returning only matched graph paths."""
def _resolve_graph_file_paths(store: GraphStore, `root: Path, file_paths: list[str]) -> list[str];

"""Resolve user-facing file paths to the paths stored in the graph.

    Graphs may contain absolute paths, repo-relative paths, or cwd-relative
    paths depending on how they were built. Tool inputs are usually relative to
    repo root, so exact matching alone can miss existing graph nodes.
    """
def _resolve_graph_file_paths_with_unmatched(
    store: GraphStore, `root: Path, file_paths: list[str]
) -> tuple[list[str], list[str]];

"""Explain incomplete path coverage without growing an unbounded summary."""
def _unmatched_file_warning(unmatched: list[str]) -> str;

"""Validate a caller-supplied result bound.

    Mirrors the check ``query.py`` applies to ``max_results``: ``bool`` is
    rejected explicitly because ``True`` would otherwise silently mean 1.
    """
def _validate_positive_int(value: int, name: str) -> int;

"""Cap *items* at ``min(max_results, hard_cap)``.

    Returns ``(visible, total, truncated)`` where ``total`` is the
    untruncated length, so callers can always report the real count.
    """
def _bounded(items: "list[Any]", max_results: int, hard_cap: int) -> tuple[list[Any], int, bool];

"""Return the ``", showing N of M"`` fragment used by capped summaries."""
def _shown_of(shown: int, total: int) -> str;

"""Standard compact response format for token efficiency."""
def compact_response(
    summary: str,
    key_entities: list[str] | None = None,
    risk: str = "unknown",
    communities: list[str] | None = None,
    flows_affected: list[str] | None = None,
    next_tool_suggestions: list[str] | None = None,
    data: dict[str, Any] | None = None,
    detail_level: str = "minimal",
) -> dict[str, Any];
