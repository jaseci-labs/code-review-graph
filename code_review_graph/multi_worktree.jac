import from __future__ { annotations }

import builtins, operator;

import from jaclang.comptime { target as target_ }

import atexit, json, logging, os, signal, subprocess, sys, threading, uuid;

import from pathlib { Path }

import from typing { Any }

glob logger: any = logging.getLogger(__name__);

glob _MAX_FRAME_BYTES: any = 4 * 1024 * 1024;

glob _MAX_CHILD_FRAME_BYTES: any = 64 * 1024 * 1024;

glob _MAX_CHILDREN: any = 32;

glob _MAX_INFLIGHT_REQUESTS: any = 256;

glob _CHILD_START_TIMEOUT: any = 60.0;

glob _CHILD_STOP_TIMEOUT: any = 10.0;

glob _GIT_TIMEOUT: any = 10.0;

glob _PACKAGE_ROOT: any = Path(__file__).resolve().parents[1];

glob _CHILD_ENV_DROPPED: any = frozenset({"CRG_DATA_DIR", "CRG_REPO_ROOT"});

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

    def start(initialize: bool = True);

    def _initialize(params: dict[str, Any]);

    def send(message: dict[str, Any]);

    def _read_stdout;

    def _read_stderr;

    def stop;

    def __repr__ -> str;

    def __eq__(other: any) -> bool;

    def __hash__ -> int;
}

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

    def write(message: dict[str, Any]);

    def child_message(child: _Child, message: dict[str, Any]);

    def child_failed(child: _Child, reason: str);

    def get_child(`root: Path, *, initialize: bool = True) -> _Child;

    def _forward(child: _Child, message: dict[str, Any]);

    def handle(message: object);

    def _child_is_running(`root: Path) -> bool;

    def _route(`root: Path, message: dict[str, Any]);

    def run;

    def close;

    def __repr__ -> str;

    def __eq__(other: any) -> bool;

    def __hash__ -> int;
}

def run_multi_worktree_server(
    repo_root: str | None = None, tools: str | None = None, auto_watch: bool = False
);
