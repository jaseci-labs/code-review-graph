"""Multi-repo watch daemon for code-review-graph.

Reads ``~/.code-review-graph/watch.toml`` to configure which repositories
to watch, then spawns one ``code-review-graph watch`` child process per
repo.  Monitors the config file for live changes (adding/removing repos)
and health-checks child processes, restarting any that die.

No external dependencies beyond Python stdlib — no tmux required.
"""

import importlib;

import builtins;

import operator;

import from jaclang.comptime { target as target_ }

import from __future__ { annotations }

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

"""Path to ``watch.toml`` under the per-user state directory."""
def default_config_path -> Path;

"""Path to the daemon PID file."""
def default_pid_path -> Path;

"""Path to the persisted daemon state."""
def default_state_path -> Path;

"""Directory for per-repo daemon logs."""
def default_log_dir -> Path;

with entry {
    _LAZY_PATHS = {
        "CONFIG_PATH": default_config_path,
        "PID_PATH": default_pid_path,
        "STATE_PATH": default_state_path,
    };
}

def __getattr__(name: str) -> Path;

"""Include the lazy names so ``dir()`` and tab-completion still find them.

    ``__getattr__`` alone covers attribute access and ``from … import X``,
    but names absent from module globals are otherwise invisible to
    ``dir()``, ``from … import *`` and static analysers.
    """
def __dir__ -> list[str];

with entry {
    _HEALTH_CHECK_INTERVAL = 30;
    _RESTART_BACKOFF_BASE = env_float("CRG_RESTART_BACKOFF", 30.0);
    _RESTART_BACKOFF_MAX = env_float("CRG_RESTART_BACKOFF_MAX", 900.0);
    _RESTART_HEALTHY_SECONDS = env_float("CRG_RESTART_HEALTHY_AFTER", 600.0);

    _JOB_OBJECT_EXTENDED_LIMIT_INFORMATION = 9;
    _JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE = 8192;
}

"""Own watcher processes so Windows cannot orphan them on daemon exit."""
obj _WindowsJob {
    has _ctypes: any,
        _kernel32: any,
        _handle: any;

    def init;

    """Assign *proc* to this job before it can outlive the daemon."""
    def assign(proc: subprocess.Popen[bytes]) -> None;

    """Release the job; kill-on-close handles abnormal daemon exits."""
    def close -> None;

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

"""Load daemon configuration from a TOML file.

    Args:
        path: Explicit config path.  Falls back to :func:`default_config_path`.

    Returns:
        A fully-validated :class:`DaemonConfig`.

    Raises:
        RuntimeError: If ``tomllib`` / ``tomli`` is unavailable on Python < 3.11.
    """
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

"""Render *value* as a TOML basic string.

    Backslashes and double quotes are escape characters in TOML basic
    strings, so Windows paths like ``C:\\Users\\x`` must be escaped or
    the file fails to parse on the next load. Control characters
    (U+0000-U+001F, U+007F) are forbidden unescaped by the TOML spec,
    so they are escaped too — ``tomllib`` rejects the file otherwise.
    """
def _toml_str(value: object) -> str;

"""Serialize a :class:`DaemonConfig` to TOML text.

    ``tomllib`` is read-only, so we build the TOML manually.
    """
def _serialize_toml(config: DaemonConfig) -> str;

"""Write *config* back to a TOML file.

    Creates parent directories if they do not exist.

    Args:
        config: The daemon configuration to persist.
        path:   Explicit config path.  Falls back to :func:`default_config_path`.
    """
def save_config(config: DaemonConfig, path: Path | None = None) -> None;

"""Add a repository to the daemon config and persist the change.

    Args:
        repo_path:   Path to the repository (will be resolved to absolute).
        alias:       Optional short name.  Derived from dirname if *None*.
        config_path: Explicit config file path.  Falls back to :func:`default_config_path`.

    Returns:
        The updated :class:`DaemonConfig`.

    Raises:
        ValueError: If the path is not a valid repository directory.
    """
def add_repo_to_config(
    repo_path: str, alias: str | None = None, config_path: Path | None = None
) -> DaemonConfig;

"""Remove a repository from the daemon config by path or alias.

    Args:
        path_or_alias: Either the absolute/relative repo path or its alias.
        config_path:   Explicit config file path.  Falls back to :func:`default_config_path`.

    Returns:
        The updated :class:`DaemonConfig`.
    """
def remove_repo_from_config(path_or_alias: str, config_path: Path | None = None) -> DaemonConfig;

with entry {
    _lock_handles = {};
}

"""A live process already holds the daemon lock, so this one must not run.

    ``is_daemon_running`` is a look, not a claim, and two ``crg-daemon start``
    invocations a millisecond apart both used to pass it.  The lock is the only
    thing that can decide between them, so refusing to start is expressed as an
    exception out of the call that takes it rather than a boolean a caller can
    ignore.
    """
obj DaemonAlreadyRunningError(RuntimeError) {
    has pid: any,
        lock_path: any;

    def init(pid: int | None, lock_path: Path);

    def __repr__ -> str;

    def __eq__(other: any) -> bool;

    def __hash__ -> int;
}

"""Companion lock file for a PID file.

    Kept separate so ``daemon.pid`` stays exactly what every other tool
    expects it to be: one integer and nothing else.
    """
def daemon_lock_path(path: Path | None = None) -> Path;

def _flock_supported -> bool;

"""Take an exclusive lock on *handle*. Returns False when it is held."""
def _flock(handle: Any, blocking: bool = False) -> bool;

"""Claim the daemon lock for this process, and hold it until it exits.

    Returns True when this process owns the lock afterwards (including when it
    already did), False when another live process holds it.  On platforms
    without ``flock`` this is a no-op that reports success, and identity falls
    back to the process command line.
    """
def acquire_daemon_lock(path: Path | None = None) -> bool;

"""Take the daemon lock, or refuse and name the process that holds it.

    Call this before doing anything a second daemon must not do — forking,
    spawning watchers, writing the PID file.  Under ``flock`` the lock belongs
    to the open file description, so a daemon that forks after claiming keeps
    holding it once the parents exit.

    On Windows ``acquire_daemon_lock`` is a no-op that reports success, so this
    never refuses there and two simultaneous starts are still possible.
    """
def claim_daemon_lock(path: Path | None = None) -> None;

"""Drop the daemon lock this process holds, if any."""
def release_daemon_lock(path: Path | None = None) -> None;

"""True when some live process holds the daemon lock."""
def daemon_lock_held(path: Path | None = None) -> bool;

"""The command line of *pid*, or None when it cannot be determined.

    Windows returns None, and ``_looks_like_our_daemon`` reads that as "keep
    the old behaviour", so none of the PID-identity work below reaches a
    Windows user: there is no ``flock`` to fall back from either, so a PID
    file naming any live process is still adopted there. What that costs is
    written out in :func:`_looks_like_our_daemon`. Closing it needs a real
    command line, which Windows exposes only through WMI or
    ``NtQueryInformationProcess`` — neither is a change to make blind, with no
    Windows machine to test it on.
    """
def _process_command(pid: int) -> str | None;

"""Fallback identity check for platforms without ``flock``.

    On Windows this always returns True, because ``_process_command`` cannot
    answer there. A Windows user therefore keeps the pre-existing behaviour in
    full: ``crg-daemon status`` reports a daemon whenever ``daemon.pid`` names
    a live process, and ``crg-daemon stop`` signals it, even when the PID was
    recycled and now belongs to something unrelated. For the same reason
    ``claim_daemon_lock`` cannot exclude a second daemon on Windows — see
    :func:`acquire_daemon_lock`.
    """
def _looks_like_our_daemon(pid: int) -> bool;

"""Claim the daemon lock, then write the current (or given) PID.

    The lock is the exclusion; the PID file is only a label on it.  Discarding
    the result of :func:`acquire_daemon_lock` here meant the new lock could
    identify the daemon but never exclude a second one: two ``crg-daemon
    start`` invocations that both raced past ``is_daemon_running`` each wrote
    the PID file and each went on running, one of them invisible to every
    later ``status`` and ``stop``.

    Raises:
        DaemonAlreadyRunningError: another live process holds the lock. The PID
            file is left exactly as its owner wrote it.
    """
def write_pid(pid: int | None = None, path: Path | None = None) -> None;

"""Read the daemon PID from disk. Returns None if missing/invalid."""
def read_pid(path: Path | None = None) -> int | None;

"""Remove the PID file and release the daemon lock."""
def clear_pid(path: Path | None = None) -> None;

with entry {
    _PROCESS_QUERY_LIMITED_INFORMATION = 4096;
    _SYNCHRONIZE = 1048576;
    _ERROR_ACCESS_DENIED = 5;
    _WAIT_OBJECT_0 = 0;
    _WAIT_FAILED = 4294967295;
}

"""Win32 PID liveness check via OpenProcess/WaitForSingleObject.

    The access mask must include SYNCHRONIZE: a handle opened with only
    PROCESS_QUERY_LIMITED_INFORMATION cannot be waited on, so
    WaitForSingleObject returns WAIT_FAILED (ERROR_ACCESS_DENIED) and
    every exited process reads as alive.

    The kernel32 interface is injected so tests can drive handle/wait
    outcomes on non-Windows platforms. *get_last_error* defaults to
    ``kernel32.GetLastError``; the real caller passes
    ``ctypes.get_last_error`` (reliable with ``use_last_error=True``).
    """
def _pid_alive_windows(
    pid: int, kernel32: Any, get_last_error: Callable[[], int] | None = None
) -> bool;

"""Cross-platform check whether a process with *pid* is running.

    On Windows ``os.kill(pid, 0)`` routes to GenerateConsoleCtrlEvent and
    raises ``OSError`` (WinError 87) for alive PIDs outside the caller's
    console process group (#511), so the Win32 API is used instead.
    """
def pid_alive(pid: int) -> bool;

"""Check whether *our* daemon process is alive.

    A live PID is necessary but not sufficient: PIDs are recycled, and the
    file outlives the process that wrote it.  The daemon holds an exclusive
    lock for its whole lifetime, so a PID file naming a live process that does
    not hold that lock names a stranger, and is cleared rather than adopted.
    Without it, ``stop`` signalled that stranger.
    """
def is_daemon_running(path: Path | None = None) -> bool;

"""Load persisted child process state from disk.

    Returns a dict mapping alias to ``{"pid": int, "path": str}``.
    Returns an empty dict if the file is missing or corrupt.
    """
def load_state(path: Path | None = None) -> dict[str, Any];

"""Check whether a process with the given PID is running."""
def _is_pid_alive(pid: int) -> bool;

"""Remove the persisted child-state file."""
def clear_state(path: Path | None = None) -> None;

"""Is *pid* really a ``code-review-graph watch`` child for *repo_path*?

    Same reasoning as the daemon PID file: signalling a number recorded on
    disk is only safe once something ties that number to the process we mean.
    The command line is that tie, and it is checked first — a health file
    naming a PID proves only that some watcher once had it, and PIDs are
    recycled, so trusting it alone could both block a legitimate start and
    send SIGKILL to a stranger.  The health file is the fallback for platforms
    with no ``ps``, and there only while its heartbeat is still fresh.
    """
def is_our_watcher(pid: int, repo_path: str) -> bool;

"""Watcher children still running with no daemon left to manage them.

    The watchers are plain ``subprocess.Popen`` children in the daemon's
    session, so a SIGKILLed daemon leaves every one of them running.  Nothing
    used to look for them: ``status`` reported "not running" and listed
    nothing while a live watcher kept writing ``graph.db``, and the next
    ``start`` added a second watcher per repository — two writers on one
    database, one of them invisible.
    """
def find_orphaned_watchers(state_path: Path | None = None) -> list[dict[str, Any]];

"""Terminate every orphaned watcher and forget the state that named them.

    Only called with no daemon running, so every watcher the state names is
    finished by the end of this, including those already dead. Their health
    files go too. A watcher killed outright cannot clear its own, which is every
    watcher on Windows: ``stop`` ends the daemon with ``TerminateProcess`` and the
    Job Object takes the children with it, so no shutdown code runs. A file left
    behind reads as a stalled watcher forever.

    Returns the entries that were signalled, so the caller can report them.
    """
def reap_orphaned_watchers(
    state_path: Path | None = None, *, timeout: float = 5.0
) -> list[dict[str, Any]];

"""Drop the health file our watcher on *repo_path* left, not a replacement's.

    Health files are keyed by repository, so a watcher started by hand after
    ours died publishes to the same file. Deleting it would let the next
    ``start`` miss that watcher and launch a second writer on the same database.
    """
def _clear_health_left_by(repo_path: str, pid: Any) -> None;

"""SIGTERM, then SIGKILL, then confirm. Returns True when the PID is gone."""
def _signal_until_dead(pid: int, *, timeout: float = 5.0) -> bool;

with entry {
    _WATCH_HEALTH_STALE_SECONDS = env_float("CRG_WATCH_HEALTH_STALE", 90.0);
}

"""Directory holding one health file per watched repository."""
def watch_health_dir -> Path;

"""Health file for *repo_root*.

    Keyed by the real path so the watch child and the daemon agree even when
    one of them was handed a symlinked or relative path.  Deliberately free of
    heavy imports: ``crg-daemon status`` must stay instant.
    """
def watch_health_path(repo_root: str | Path) -> Path;

glob stale_after_default_: any;

with entry {
    stale_after_default_ = _WATCH_HEALTH_STALE_SECONDS;
}

"""Read a watcher's published health, or None when it never published any.

    The returned dict gains ``age`` (seconds since the last heartbeat) and
    ``stalled`` (observer reported dead, or heartbeat too old).
    """
def read_watch_health(
    repo_root: str | Path, *, stale_after: float = stale_after_default_
) -> dict[str, Any] | None;

"""Drop a watcher's health file (the daemon reaped or dropped the child)."""
def clear_watch_health(repo_root: str | Path) -> None;

"""Summarise one watcher: ``dead``, ``stalled``, ``partial``, ``unknown``, ``ok``.

    ``partial`` means the watcher has reduced coverage: either an OS watch
    registration failed, or the watch budget forced a coarser recursive watch.
    """
def watcher_status(alive: bool, health: dict[str, Any] | None) -> str;

"""Watcher-health columns for one repo entry in :meth:`WatchDaemon.status`."""
def _health_fields(repo_path: str, alive: bool) -> dict[str, Any];

"""Watches the daemon config file for changes and triggers reconciliation."""
obj ConfigWatcher {
    has _config_path: any,
        _callback: any,
        _poll_interval: any,
        _observer: any,
        _last_mtime: any,
        _poll_thread: any,
        _stop_event: any;

    def init(config_path: Path, callback: Callable[[], None], poll_interval: int = 2);

    """Begin watching the config file for modifications."""
    def start -> None;

    """Stop watching the config file."""
    def stop -> None;

    """Poll the config file mtime in a background thread."""
    def _start_polling -> None;

    """Handle a detected config file modification."""
    def _on_config_changed -> None;

    def __repr__ -> str;

    def __eq__(other: any) -> bool;

    def __hash__ -> int;
}

"""Manages child processes for multi-repo file watching.

    Each watched repository gets a ``code-review-graph watch`` child process
    managed via :mod:`subprocess`.  No external tools (tmux, screen, etc.)
    are required.
    """
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

    """Spawn a watcher child process for each configured repo."""
    def start -> None;

    """Tear down the daemon: stop watchers, terminate children."""
    def stop -> None;

    """Reconcile running watchers with the (possibly updated) config.

        Child processes are started, stopped, or restarted to match the
        desired state.  New repos are registered in the central registry
        and their graphs are built automatically (mirroring ``start()``).
        """
    def reconcile(new_config: DaemonConfig | None = None) -> None;

    """Return a summary of daemon state.

        When called from the daemon process itself, uses the in-memory
        ``_children`` dict.  When called from a separate process (e.g. the
        CLI ``status`` command), falls back to the persisted state file and
        checks liveness via ``os.kill(pid, 0)``.

        A live process is not the same as a working watcher, so every entry
        also carries the watcher health the child publishes: ``watcher``
        (ok/stalled/unknown/dead), ``observer_alive`` and ``last_event_at``.
        """
    def status -> dict[str, Any];

    """Begin watching the config file for live edits."""
    def start_config_watcher -> None;

    """Reload configuration and reconcile running watchers."""
    def _on_config_change -> None;

    """Stop the config file watcher if running."""
    def stop_config_watcher -> None;

    """Start the background health-check thread."""
    def start_health_checker -> None;

    """Stop the health-check thread."""
    def stop_health_checker -> None;

    """Periodically check child processes and restart dead ones."""
    def _health_loop -> None;

    """Seconds to wait before the next restart of *alias*.

        A watcher that keeps dying — a broken repo, an unreadable database —
        used to be restarted every 30s forever, each attempt paying for a full
        initial update.  The delay doubles per failure and resets once a
        watcher has stayed up long enough to count as healthy.
        """
    def _restart_delay(alias: str) -> float;

    """How many times *alias* has been restarted since it was last healthy."""
    def restart_count(alias: str) -> int;

    """Check each watcher child and restart if dead.

        A watcher that died takes the process with it and is restarted here,
        with exponential backoff so a repo that cannot start does not burn a
        full initial update every 30s.  One that is merely stalled — observer
        threads gone, heartbeat frozen — is reported, not restarted: the child
        exits on its own when it detects that, and restarting on a stale
        heartbeat alone risks a restart loop.
        """
    def _check_health -> None;

    """Fork to background using the double-fork pattern.

        Redirects stdout/stderr to the daemon log file.  Writes PID file.
        Sets up SIGTERM handler for graceful shutdown.

        On Windows, forking is not supported — the daemon runs in the
        foreground and a warning is logged.
        """
    def daemonize -> None;

    """Install SIGTERM/SIGHUP handlers for graceful shutdown."""
    def _setup_signal_handlers -> None;

    """Block forever, keeping the daemon alive.

        The config watcher and health checker run in background threads.
        This method sleeps in the main thread until interrupted.
        """
    def run_forever -> None;

    """Persist child PIDs and repo paths to disk for cross-process queries.

        Called after any mutation of ``_children`` so that ``status`` commands
        running in a separate process can determine which watchers are alive.
        """
    def _save_state -> None;

    """Remove the state file from disk."""
    def _clear_state -> None;

    """PID of a live watcher on *repo* that this daemon does not own.

        Two watchers on one repository means two processes writing one
        ``graph.db``.  The usual way to get there was a daemon crash: the
        children survived, ``status`` could not see them, and the next
        ``start`` spawned a full second set.  A watcher publishes its PID in
        its health file, so the check costs one small read.
        """
    def _existing_watcher(repo: WatchRepo) -> int | None;

    """Spawn a child process running ``code-review-graph watch`` for *repo*."""
    def _start_watcher(repo: WatchRepo) -> None;

    """Gracefully terminate a child process (SIGTERM, then SIGKILL).

        The child clears its own health file on SIGTERM, but a killed or
        already-dead one cannot, and a leftover file reads as a stalled
        watcher forever — so the reaper clears it too.
        """
    static def _terminate_child(
        alias: str, proc: subprocess.Popen[bytes], repo_path: str | None = None
    ) -> None;

    """Run a one-off graph build for a repo that has no database yet."""
    def _initial_build(repo: WatchRepo) -> None;

    def __repr__ -> str;

    def __eq__(other: any) -> bool;

    def __hash__ -> int;
}
