"""Route one stdio MCP session to one server process per Git worktree.

The normal MCP server already resolves an explicit ``repo_root`` per tool
call. This module adds process isolation for linked worktrees: each root gets
its own child server and therefore its own SQLite connection state and graph
database path. Only the primary checkout and worktrees reported by Git for
the same ``git common dir`` are accepted.
"""

import builtins;

import operator;

import from jaclang.comptime { target as target_ }

import from __future__ { annotations }

import atexit;

import json;

import logging;

import os;

import signal;

import subprocess;

import sys;

import threading;

import uuid;

import from pathlib { Path }

import from typing { Any }

glob logger: any;

glob _MAX_FRAME_BYTES: any;

glob _MAX_CHILD_FRAME_BYTES: any;

glob _MAX_CHILDREN: any;

glob _MAX_INFLIGHT_REQUESTS: any;

glob _CHILD_START_TIMEOUT: any;

glob _CHILD_STOP_TIMEOUT: any;

glob _GIT_TIMEOUT: any;

glob _PACKAGE_ROOT: any;

glob _CHILD_ENV_DROPPED: any;

with entry {
    logger = logging.getLogger(__name__);

    _MAX_FRAME_BYTES = 4 * 1024 * 1024;
    _MAX_CHILD_FRAME_BYTES = 64 * 1024 * 1024;
    _MAX_CHILDREN = 32;
    _MAX_INFLIGHT_REQUESTS = 256;
    _CHILD_START_TIMEOUT = 60.0;
    _CHILD_STOP_TIMEOUT = 10.0;
    _GIT_TIMEOUT = 10.0;
    _PACKAGE_ROOT = Path(__file__).resolve().parents[1];
    _CHILD_ENV_DROPPED = frozenset({"CRG_DATA_DIR", "CRG_REPO_ROOT"});
}

"""Raised when a worktree cannot be safely routed."""
obj MultiWorktreeError(RuntimeError) {
    def __repr__ -> str;

    def __eq__(other: any) -> bool;

    def __hash__ -> int;
}

def _request_key(value: object) -> str;

def _git_env -> dict[str, str];

def _run_git(`root: Path, *args_: str) -> str;

def _canonical_git_identity(path: str | Path) -> tuple[Path, Path];

def _listed_worktree_roots(primary_root: Path) -> set[Path];

"""Authorize the primary checkout and its currently linked worktrees."""
obj WorktreeAuthorizer {
    has primary_root: any,
        primary_common: any;

    def init(repo_root: str | None);

    def authorize(raw_root: object) -> Path;

    def __repr__ -> str;

    def __eq__(other: any) -> bool;

    def __hash__ -> int;
}

def _json_error(request_id: object, code: int, message: str) -> dict[str, object];

"""Yield newline-delimited frames without buffering an unbounded line."""
def _iter_bounded_lines(stream: Any, max_bytes: int) -> Generator[any, any, any];

obj _Child {
    has router: any,
        `root: any,
        process: any,
        stdin_lock: any,
        pending_lock: any,
        pending: any,
        reader_thread: any,
        stderr_thread: any,
        stopped: any,
        starting: any,
        ready: any;

    def init(router: "MultiWorktreeRouter", `root: Path);

    def start(initialize: bool = True) -> None;

    def _initialize(params: dict[str, Any]) -> None;

    def send(message: dict[str, Any]) -> None;

    def _read_stdout -> None;

    def _read_stderr -> None;

    def stop -> None;

    def __repr__ -> str;

    def __eq__(other: any) -> bool;

    def __hash__ -> int;
}

"""Multiplex JSON-RPC requests across repository-bound child servers."""
obj MultiWorktreeRouter {
    has authorizer: any,
        tools: any,
        auto_watch: any,
        children: any,
        db_paths: any,
        children_lock: any,
        routes: any,
        child_routes: any,
        routes_lock: any,
        output_lock: any,
        initialize_params: any,
        shutdown: any,
        waiting_for_start: any;

    def init(authorizer: WorktreeAuthorizer, tools: str | None, auto_watch: bool);

    has primary_root: Path {
        getter {
            return self.authorizer.primary_root;
        }
    }

    def write(message: dict[str, Any]) -> None;

    def child_message(child: _Child, message: dict[str, Any]) -> None;

    def child_failed(child: _Child, reason: str) -> None;

    def get_child(`root: Path, *, initialize: bool = True) -> _Child;

    def _forward(child: _Child, message: dict[str, Any]) -> None;

    def handle(message: object) -> None;

    def _child_is_running(`root: Path) -> bool;

    def _route(`root: Path, message: dict[str, Any]) -> None;

    def run -> None;

    def close -> None;

    def __repr__ -> str;

    def __eq__(other: any) -> bool;

    def __hash__ -> int;
}

"""Run the opt-in multi-worktree stdio MCP server."""
def run_multi_worktree_server(
    repo_root: str | None = None, tools: str | None = None, auto_watch: bool = False
) -> None;
