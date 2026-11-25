import from __future__ { annotations }

import importlib;

import operator;

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

def _error_response(message: str, status: str = "error", **extra: Any) -> dict[str, Any];
def _read_live_git_head(`root: Path) -> str | None;
def graph_provenance(repo_root: str | None = None) -> dict[str, Any] | None;
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

def _validate_repo_root(path: "Path | str") -> Path;
def _resolve_root(repo_root: str | None = None) -> Path;
def _open_graph_store(db_path: Path, command: str) -> any;
def _get_store(
    repo_root: str | None = None, *, db_path: Path | None = None, recover_corrupt: bool = False
) -> tuple[GraphStore, Path];
def _resolve_graph_file_paths(store: GraphStore, `root: Path, file_paths: list[str]) -> list[str];
def _resolve_graph_file_paths_with_unmatched(
    store: GraphStore, `root: Path, file_paths: list[str]
) -> tuple[list[str], list[str]];
def _unmatched_file_warning(unmatched: list[str]) -> str;
def _validate_positive_int(value: int, name: str) -> int;
def _bounded(items: "list[Any]", max_results: int, hard_cap: int) -> tuple[list[Any], int, bool];
def _shown_of(shown: int, total: int) -> str;
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
