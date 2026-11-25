import from __future__ { annotations }

import importlib;

import builtins;

import operator;

import from jaclang.comptime { target as target_ }

import hashlib;

import json;

import logging;

import os;

import shutil;

import signal;

import subprocess;

import sys;

import threading;

import types;

import time;

import from collections.abc { Callable }

import from dataclasses { dataclass, field }

import from pathlib { Path }

import from typing { Any }

glob tomllib: any;

glob logger: any;

glob _LAZY_PATHS: any;

glob _HEALTH_CHECK_INTERVAL: any;

glob _RESTART_BACKOFF_BASE: any;

glob _RESTART_BACKOFF_MAX: any;

glob _RESTART_HEALTHY_SECONDS: any;

glob _JOB_OBJECT_EXTENDED_LIMIT_INFORMATION: any;

glob _JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE: any;

glob _TOML_SHORT_ESCAPES: any;

glob _lock_handles: dict[str, Any];

glob _PROCESS_QUERY_LIMITED_INFORMATION: any;

glob _SYNCHRONIZE: any;

glob _ERROR_ACCESS_DENIED: any;

glob _WAIT_OBJECT_0: any;

glob _WAIT_FAILED: any;

glob _WATCH_HEALTH_STALE_SECONDS: any;

with entry {
    if sys.version_info >= (3, 11) {
        import tomllib;
    } else {
        try {
            import tomli as tomllib;
        } except ImportError {
            tomllib = None;
        }
    }

    logger = logging.getLogger(__name__);
}

def default_config_path -> Path;
def default_pid_path -> Path;
def default_state_path -> Path;
def default_log_dir -> Path;

with entry {
    _LAZY_PATHS = {
        "CONFIG_PATH": default_config_path,
        "PID_PATH": default_pid_path,
        "STATE_PATH": default_state_path,
    };
}

def __getattr__(name: str) -> Path;
def __dir__ -> list[str];

with entry {
    _HEALTH_CHECK_INTERVAL = 30;
    _RESTART_BACKOFF_BASE = env_float("CRG_RESTART_BACKOFF", 30.0);
    _RESTART_BACKOFF_MAX = env_float("CRG_RESTART_BACKOFF_MAX", 900.0);
    _RESTART_HEALTHY_SECONDS = env_float("CRG_RESTART_HEALTHY_AFTER", 600.0);

    _JOB_OBJECT_EXTENDED_LIMIT_INFORMATION = 9;
    _JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE = 8192;
}

obj _WindowsJob {
    has _ctypes: any,
        _kernel32: any,
        _handle: any;

    def init;
    def assign(proc: subprocess.Popen[bytes]);
    def close;

    def __repr__ -> str;

    def __eq__(other: any) -> bool;

    def __hash__ -> int;
}

@dataclass
class WatchRepo {
    has path: str;

    has alias: str;
}

@dataclass
class DaemonConfig {
    has session_name: str = "crg-watch";

    has log_dir: Path = field(default_factory=default_log_dir);

    has poll_interval: int = 2;

    has repos: list[WatchRepo] = field(default_factory=list[any]);
}

def load_config(path: Path | None = None) -> DaemonConfig;

with entry {
    _TOML_SHORT_ESCAPES = {
        "\\": "\\\\",
        "\"": "\\\"",
        "\x08": "\\b",
        "\t": "\\t",
        "\n": "\\n",
        "\x0c": "\\f",
        "\r": "\\r",
    };
}

def _toml_str(value: object) -> str;
def _serialize_toml(config: DaemonConfig) -> str;
def save_config(config: DaemonConfig, path: Path | None = None);
def add_repo_to_config(
    repo_path: str, alias: str | None = None, config_path: Path | None = None
) -> DaemonConfig;
def remove_repo_from_config(path_or_alias: str, config_path: Path | None = None) -> DaemonConfig;

with entry {
    _lock_handles = {};
}

obj DaemonAlreadyRunningError(RuntimeError) {
    has pid: any,
        lock_path: any;

    def init(pid: int | None, lock_path: Path);

    def __repr__ -> str;

    def __eq__(other: any) -> bool;

    def __hash__ -> int;
}

def daemon_lock_path(path: Path | None = None) -> Path;

def _flock_supported -> bool;
def _flock(handle: Any, blocking: bool = False) -> bool;
def acquire_daemon_lock(path: Path | None = None) -> bool;
def claim_daemon_lock(path: Path | None = None);
def release_daemon_lock(path: Path | None = None);
def daemon_lock_held(path: Path | None = None) -> bool;
def _process_command(pid: int) -> str | None;
def _looks_like_our_daemon(pid: int) -> bool;
def write_pid(pid: int | None = None, path: Path | None = None);
def read_pid(path: Path | None = None) -> int | None;
def clear_pid(path: Path | None = None);

with entry {
    _PROCESS_QUERY_LIMITED_INFORMATION = 4096;
    _SYNCHRONIZE = 1048576;
    _ERROR_ACCESS_DENIED = 5;
    _WAIT_OBJECT_0 = 0;
    _WAIT_FAILED = 4294967295;
}

def _pid_alive_windows(
    pid: int, kernel32: Any, get_last_error: Callable[[], int] | None = None
) -> bool;
def pid_alive(pid: int) -> bool;
def is_daemon_running(path: Path | None = None) -> bool;
def load_state(path: Path | None = None) -> dict[str, Any];
def _is_pid_alive(pid: int) -> bool;
def clear_state(path: Path | None = None);
def is_our_watcher(pid: int, repo_path: str) -> bool;
def find_orphaned_watchers(state_path: Path | None = None) -> list[dict[str, Any]];
def reap_orphaned_watchers(
    state_path: Path | None = None, *, timeout: float = 5.0
) -> list[dict[str, Any]];
def _clear_health_left_by(repo_path: str, pid: Any);
def _signal_until_dead(pid: int, *, timeout: float = 5.0) -> bool;

with entry {
    _WATCH_HEALTH_STALE_SECONDS = env_float("CRG_WATCH_HEALTH_STALE", 90.0);
}

def watch_health_dir -> Path;
def watch_health_path(repo_root: str | Path) -> Path;

glob stale_after_default_: any;

with entry {
    stale_after_default_ = _WATCH_HEALTH_STALE_SECONDS;
}

def read_watch_health(
    repo_root: str | Path, *, stale_after: float = stale_after_default_
) -> dict[str, Any] | None;
def clear_watch_health(repo_root: str | Path);
def watcher_status(alive: bool, health: dict[str, Any] | None) -> str;
def _health_fields(repo_path: str, alive: bool) -> dict[str, Any];

obj ConfigWatcher {
    has _config_path: any,
        _callback: any,
        _poll_interval: any,
        _observer: any,
        _last_mtime: any,
        _poll_thread: any,
        _stop_event: any;

    def init(config_path: Path, callback: Callable[[], None], poll_interval: int = 2);
    def start;
    def stop;
    def _start_polling;
    def _on_config_changed;

    def __repr__ -> str;

    def __eq__(other: any) -> bool;

    def __hash__ -> int;
}

obj WatchDaemon {
    has _config: any,
        _config_path: any,
        _state_path: any,
        _children: any,
        _current_repos: any,
        _config_watcher: any,
        _health_thread: any,
        _health_stop: any,
        _lock: any,
        _restarts: any,
        _windows_job: any;

    def init(config: DaemonConfig | None = None, config_path: Path | None = None);
    def start;
    def stop;
    def reconcile(new_config: DaemonConfig | None = None);
    def status -> dict[str, Any];
    def start_config_watcher;
    def _on_config_change;
    def stop_config_watcher;
    def start_health_checker;
    def stop_health_checker;
    def _health_loop;
    def _restart_delay(alias: str) -> float;
    def restart_count(alias: str) -> int;
    def _check_health;
    def daemonize;
    def _setup_signal_handlers;
    def run_forever;
    def _save_state;
    def _clear_state;
    def _existing_watcher(repo: WatchRepo) -> int | None;
    def _start_watcher(repo: WatchRepo);
    static def _terminate_child(
        alias: str, proc: subprocess.Popen[bytes], repo_path: str | None = None
    );
    def _initial_build(repo: WatchRepo);

    def __repr__ -> str;

    def __eq__(other: any) -> bool;

    def __hash__ -> int;
}
