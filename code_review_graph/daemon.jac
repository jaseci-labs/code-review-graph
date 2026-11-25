import from __future__ { annotations }

import importlib, builtins, operator;

import from jaclang.comptime { target as target_ }

import hashlib, json, logging, os, shutil, signal, subprocess, sys, threading, types, time;

import from collections.abc { Callable }

import from dataclasses { dataclass, field }

import from pathlib { Path }

import from typing { Any }

glob tomllib: any;

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
}

glob logger: any = logging.getLogger(__name__);

def default_config_path -> Path {
    return crg_home() / "watch.toml";
}

def default_pid_path -> Path {
    return crg_home() / "daemon.pid";
}

def default_state_path -> Path {
    return crg_home() / "daemon-state.json";
}

def default_log_dir -> Path {
    return crg_home() / "logs";
}

glob _LAZY_PATHS: any = {
    "CONFIG_PATH": default_config_path,
    "PID_PATH": default_pid_path,
    "STATE_PATH": default_state_path,
};

def __getattr__(name: str) -> Path {
    if name in _LAZY_PATHS {
        return _LAZY_PATHS[name]();
    }
    raise AttributeError(f"module {__name__!r} has no attribute {name!r}");
}

def __dir__ -> list[str] {
    return sorted(`list(globals()) + [name for name in _LAZY_PATHS if name not in globals()]);
}

glob _HEALTH_CHECK_INTERVAL: any = 30;

glob _RESTART_BACKOFF_BASE: any = env_float("CRG_RESTART_BACKOFF", 30.0);

glob _RESTART_BACKOFF_MAX: any = env_float("CRG_RESTART_BACKOFF_MAX", 900.0);

glob _RESTART_HEALTHY_SECONDS: any = env_float("CRG_RESTART_HEALTHY_AFTER", 600.0);

glob _JOB_OBJECT_EXTENDED_LIMIT_INFORMATION: any = 9;

glob _JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE: any = 8192;

obj _WindowsJob {
    has _ctypes: any,
        _kernel32: any,
        _handle: any;

    def init {
        import ctypes;
        import from ctypes { wintypes }

        ctypes_api: Any = ctypes;
        self._ctypes = ctypes_api;
        self._kernel32 = ctypes_api.WinDLL("kernel32", use_last_error=True);
        kernel32: any = self._kernel32;
        kernel32.CreateJobObjectW.argtypes = (wintypes.LPVOID, wintypes.LPCWSTR);
        kernel32.CreateJobObjectW.restype = wintypes.HANDLE;
        kernel32.SetInformationJobObject.argtypes = (
            wintypes.HANDLE,
            wintypes.DWORD,
            wintypes.LPVOID,
            wintypes.DWORD,
        );
        kernel32.SetInformationJobObject.restype = wintypes.BOOL;
        kernel32.AssignProcessToJobObject.argtypes = (wintypes.HANDLE, wintypes.HANDLE);
        kernel32.AssignProcessToJobObject.restype = wintypes.BOOL;
        kernel32.CloseHandle.argtypes = (wintypes.HANDLE,);
        kernel32.CloseHandle.restype = wintypes.BOOL;

        IoCounters: any = types.new_class("IoCounters", (ctypes.Structure,));
        IoCounters._fields_ = [(f"value_{index}", ctypes.c_ulonglong) for index in range(6)];

        BasicLimitInformation: any = types.new_class("BasicLimitInformation", (ctypes.Structure,));
        BasicLimitInformation._fields_ = [
            ("per_process_user_time_limit", ctypes.c_longlong),
            ("per_job_user_time_limit", ctypes.c_longlong),
            ("limit_flags", wintypes.DWORD),
            ("minimum_working_set_size", ctypes.c_size_t),
            ("maximum_working_set_size", ctypes.c_size_t),
            ("active_process_limit", wintypes.DWORD),
            ("affinity", ctypes.c_size_t),
            ("priority_class", wintypes.DWORD),
            ("scheduling_class", wintypes.DWORD),
        ];

        ExtendedLimitInformation: any = types.new_class(
            "ExtendedLimitInformation", (ctypes.Structure,)
        );
        ExtendedLimitInformation._fields_ = [
            ("basic_limit_information", BasicLimitInformation),
            ("io_info", IoCounters),
            ("process_memory_limit", ctypes.c_size_t),
            ("job_memory_limit", ctypes.c_size_t),
            ("peak_process_memory_used", ctypes.c_size_t),
            ("peak_job_memory_used", ctypes.c_size_t),
        ];

        self._handle = kernel32.CreateJobObjectW(None, None);
        if not self._handle {
            raise ctypes_api.WinError(ctypes_api.get_last_error());
        }

        limits: any = ExtendedLimitInformation();
        limits.basic_limit_information.limit_flags = _JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE;
        if not kernel32.SetInformationJobObject(
            self._handle,
            _JOB_OBJECT_EXTENDED_LIMIT_INFORMATION,
            ctypes.byref(limits),
            ctypes.sizeof(limits),
        ) {
            error: any = ctypes_api.get_last_error();
            kernel32.CloseHandle(self._handle);
            raise ctypes_api.WinError(error);
        }
    }

    def assign(proc: subprocess.Popen[bytes]) {
        process_handle: any = getattr(proc, "_handle", None);
        if process_handle is None {
            raise RuntimeError("Windows subprocess has no process handle");
        }
        if not self._kernel32.AssignProcessToJobObject(self._handle, process_handle) {
            raise self._ctypes.WinError(self._ctypes.get_last_error());
        }
    }

    def close {
        if self._handle {
            self._kernel32.CloseHandle(self._handle);
            self._handle = None;
        }
    }

    def __repr__ -> str {
        return (getattr(builtins.object, "__repr__") as any)(self);
    }

    def __eq__(other: any) -> bool {
        return self is other;
    }

    def __hash__ -> int {
        return id(self);
    }
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

def load_config(path: Path | None = None) -> DaemonConfig {
    if tomllib is None {
        raise RuntimeError(
            "TOML parsing requires the 'tomli' package on Python < 3.11. Install it with:  pip install tomli",
        );
    }

    config_path: any = path or default_config_path();

    if not config_path.exists() {
        logger.info("Config file not found at %s — using defaults", config_path);
        return DaemonConfig();
    }

    fh: any;
    with open(config_path, "rb") as fh {
        raw: dict[str, Any] = tomllib.load(fh);
    }
    daemon_section: dict[str, Any] = raw.get("daemon", {});
    session_name: str = daemon_section.get("session_name", "crg-watch");
    log_dir: any = Path(daemon_section.get("log_dir", `str(DaemonConfig().log_dir)));
    poll_interval: int = `int(daemon_section.get("poll_interval", 2));
    repos: list[WatchRepo] = [];
    seen_aliases: set[str] = set[any]();

    for `entry in raw.get("repos", []) {
        repo_path_str: str = `entry.get("path", "");
        if not repo_path_str {
            logger.warning("Skipping repo entry with empty path");
            continue;
        }

        repo_path: any = Path(repo_path_str).expanduser().resolve();

        if not repo_path.is_dir() {
            logger.warning("Skipping repo %s — directory does not exist", repo_path);
            continue;
        }

        has_repo_marker: any = (repo_path / ".git").exists()
            or (repo_path / ".svn").exists()
            or (repo_path / ".code-review-graph").exists();
        if not has_repo_marker {
            logger.warning(
                "Skipping repo %s — no .git, .svn, or .code-review-graph directory found", repo_path
            );
            continue;
        }

        alias: str = `entry.get("alias", "") or repo_path.name;

        if alias in seen_aliases {
            logger.warning("Skipping duplicate alias '%s' for repo %s", alias, repo_path);
            continue;
        }

        seen_aliases.add(alias);
        repos.append(WatchRepo(path=`str(repo_path), alias=alias));
    }

    return DaemonConfig(
        session_name=session_name, log_dir=log_dir, poll_interval=poll_interval, repos=repos
    );
}

glob _TOML_SHORT_ESCAPES: any = {
    "\\": "\\\\",
    "\"": "\\\"",
    "\x08": "\\b",
    "\t": "\\t",
    "\n": "\\n",
    "\x0c": "\\f",
    "\r": "\\r",
};

def _toml_str(value: object) -> str {
    chars: list[str] = [];
    for ch in `str(value) {
        esc: any = _TOML_SHORT_ESCAPES.get(ch);
        if esc is not None {
            chars.append(esc);
        } elif ord(ch) < 32 or ord(ch) == 127 {
            chars.append(f"\\u{ord(ch):04X}");
        } else {
            chars.append(ch);
        }
    }
    return "\"" + "".join(chars) + "\"";
}

def _serialize_toml(config: DaemonConfig) -> str {
    lines: list[str] = [
        "[daemon]",
        f"session_name = {_toml_str(config.session_name)}",
        f"log_dir = {_toml_str(config.log_dir)}",
        f"poll_interval = {config.poll_interval}",
    ];
    for repo in config.repos {
        lines.append("");
        lines.append("[[repos]]");
        lines.append(f"path = {_toml_str(repo.path)}");
        lines.append(f"alias = {_toml_str(repo.alias)}");
    }
    lines.append("");
    return "\n".join(lines);
}

def save_config(config: DaemonConfig, path: Path | None = None) {
    config_path: any = path or default_config_path();
    config_path.parent.mkdir(parents=True, exist_ok=True);
    config_path.write_text(_serialize_toml(config), encoding="utf-8");
    logger.info("Config saved to %s", config_path);
}

def add_repo_to_config(
    repo_path: str, alias: str | None = None, config_path: Path | None = None
) -> DaemonConfig {
    resolved: any = Path(repo_path).expanduser().resolve();

    if not resolved.is_dir() {
        raise ValueError(f"Not a directory: {resolved}");
    }

    has_repo_marker: any = (resolved / ".git").exists()
        or (resolved / ".svn").exists()
        or (resolved / ".code-review-graph").exists();
    if not has_repo_marker {
        raise ValueError(f"No .git, .svn, or .code-review-graph directory in {resolved}");
    }

    effective_alias: any = alias or resolved.name;

    config: any = load_config(config_path);
    for existing in config.repos {
        if existing.path == `str(resolved) {
            logger.warning("Repo %s is already configured — skipping", resolved);
            return config;
        }
        if existing.alias == effective_alias {
            raise ValueError(f"Alias '{effective_alias}' is already in use by {existing.path}");
        }
    }

    config.repos.append(WatchRepo(path=`str(resolved), alias=effective_alias));
    save_config(config, config_path);
    return config;
}

def remove_repo_from_config(path_or_alias: str, config_path: Path | None = None) -> DaemonConfig {
    config: any = load_config(config_path);
    resolved: any = `str(Path(path_or_alias).expanduser().resolve());

    original_count: any = len(config.repos);
    config.repos = [r for r in config.repos if r.path != resolved and r.alias != path_or_alias];

    if len(config.repos) == original_count {
        logger.warning("No repo matching '%s' found in config — nothing removed", path_or_alias);
    } else {
        save_config(config, config_path);
    }

    return config;
}

glob _lock_handles: dict[str, Any] = {};

obj DaemonAlreadyRunningError(RuntimeError) {
    has pid: any,
        lock_path: any;

    def init(pid: int | None, lock_path: Path) {
        self.pid = pid;
        self.lock_path = lock_path;
        holder: any = f"PID {pid}" if pid is not None else "an unrecorded PID";
        super.init(f"another code-review-graph daemon ({holder}) holds {lock_path}");
    }

    def __repr__ -> str {
        return (getattr(builtins.super(DaemonAlreadyRunningError, self), "__repr__") as any)();
    }

    def __eq__(other: any) -> bool {
        return self is other;
    }

    def __hash__ -> int {
        return id(self);
    }
}

def daemon_lock_path(path: Path | None = None) -> Path {
    return (path or default_pid_path()).with_suffix(".lock");
}

def _flock_supported -> bool {
    return operator.ne(sys.platform, "win32");
}

def _flock(handle: Any, blocking: bool = False) -> bool {
    import fcntl;

    flags: any = fcntl.LOCK_EX if blocking else fcntl.LOCK_EX | fcntl.LOCK_NB;
    try {
        fcntl.flock(handle.fileno(), flags);
    } except OSError {
        return False;
    }
    return True;
}

def acquire_daemon_lock(path: Path | None = None) -> bool {
    if not _flock_supported() {
        return True;
    }
    lock_path: any = daemon_lock_path(path);
    key: any = `str(lock_path);
    if key in _lock_handles {
        return True;
    }
    lock_path.parent.mkdir(parents=True, exist_ok=True);
    handle: any = open(lock_path, "a+");
    if not _flock(handle) {
        handle.close();
        return False;
    }
    _lock_handles[key] = handle;
    return True;
}

def claim_daemon_lock(path: Path | None = None) {
    if not acquire_daemon_lock(path) {
        raise DaemonAlreadyRunningError(read_pid(path), daemon_lock_path(path));
    }
}

def release_daemon_lock(path: Path | None = None) {
    handle: any = _lock_handles.pop(`str(daemon_lock_path(path)), None);
    if handle is not None {
        try {
            handle.close();
        } except OSError {}
    }
}

def daemon_lock_held(path: Path | None = None) -> bool {
    if not _flock_supported() {
        return True;
    }
    key: any = `str(daemon_lock_path(path));
    if key in _lock_handles {
        return True;
    }
    lock_path: any = daemon_lock_path(path);
    if not lock_path.exists() {
        return False;
    }
    try {
        probe: any = open(lock_path, "a+");
    } except OSError {
        return False;
    }
    try {
        if _flock(probe) {
            return False;
        }
        return True;
    } finally {
        probe.close();
    }
}

def _process_command(pid: int) -> str | None {
    if operator.eq(sys.platform, "win32") {
        return None;
    }
    try {
        result: any = subprocess.run(
            ["ps", "-ww", "-p", `str(pid), "-o", "command="],
            capture_output=True,
            text=True,
            timeout=5,
            check=False,
            stdin=subprocess.DEVNULL,
        );
    } except (OSError, subprocess.SubprocessError) {
        return None;
    }
    if result.returncode != 0 {
        return None;
    }
    return result.stdout.strip() or None;
}

def _looks_like_our_daemon(pid: int) -> bool {
    command: any = _process_command(pid);
    if command is None {
        return True;
    }
    return "crg-daemon" in command or "code_review_graph.daemon" in command;
}

def write_pid(pid: int | None = None, path: Path | None = None) {
    pid_path: any = path or default_pid_path();
    pid_path.parent.mkdir(parents=True, exist_ok=True);
    claim_daemon_lock(path);
    pid_path.write_text(`str(pid or os.getpid()), encoding="utf-8");
}

def read_pid(path: Path | None = None) -> int | None {
    pid_path: any = path or default_pid_path();
    if not pid_path.exists() {
        return None;
    }
    try {
        return `int(pid_path.read_text(encoding="utf-8").strip());
    } except (ValueError, OSError) {
        return None;
    }
}

def clear_pid(path: Path | None = None) {
    pid_path: any = path or default_pid_path();
    release_daemon_lock(path);
    try {
        pid_path.unlink(missing_ok=True);
    } except OSError {}
}

glob _PROCESS_QUERY_LIMITED_INFORMATION: any = 4096;

glob _SYNCHRONIZE: any = 1048576;

glob _ERROR_ACCESS_DENIED: any = 5;

glob _WAIT_OBJECT_0: any = 0;

glob _WAIT_FAILED: any = 4294967295;

def _pid_alive_windows(
    pid: int, kernel32: Any, get_last_error: Callable[[], int] | None = None
) -> bool {
    if get_last_error is None {
        get_last_error = kernel32.GetLastError;
    }
    handle: any = kernel32.OpenProcess(
        _PROCESS_QUERY_LIMITED_INFORMATION | _SYNCHRONIZE, False, pid
    );
    if not handle {
        return operator.eq(get_last_error(), _ERROR_ACCESS_DENIED);
    }
    try {
        result: any = kernel32.WaitForSingleObject(handle, 0);
        if result == _WAIT_FAILED {
            logger.debug(
                "WaitForSingleObject on PID %d failed (error %d); presuming alive",
                pid,
                get_last_error(),
            );
            return True;
        }
        return operator.ne(result, _WAIT_OBJECT_0);
    } finally {
        kernel32.CloseHandle(handle);
    }
}

def pid_alive(pid: int) -> bool {
    if operator.eq(sys.platform, "win32") {
        import ctypes;
        import from ctypes { wintypes }

        kernel32: any = ctypes.WinDLL("kernel32", use_last_error=True);
        kernel32.OpenProcess.argtypes = (wintypes.DWORD, wintypes.BOOL, wintypes.DWORD);
        kernel32.OpenProcess.restype = wintypes.HANDLE;
        kernel32.WaitForSingleObject.argtypes = (wintypes.HANDLE, wintypes.DWORD);
        kernel32.WaitForSingleObject.restype = wintypes.DWORD;
        kernel32.CloseHandle.argtypes = (wintypes.HANDLE,);
        kernel32.CloseHandle.restype = wintypes.BOOL;
        return _pid_alive_windows(pid, kernel32, ctypes.get_last_error);
    }
    try {
        os.kill(pid, 0);
        return True;
    } except ProcessLookupError {
        return False;
    } except PermissionError {
        return True;
    } except OSError as exc {
        logger.debug("PID %d liveness check failed: %s", pid, exc);
        return False;
    }
}

def is_daemon_running(path: Path | None = None) -> bool {
    pid: any = read_pid(path);
    if pid is None {
        return False;
    }
    if not pid_alive(pid) {
        clear_pid(path);
        return False;
    }
    identified: any = daemon_lock_held(path) if _flock_supported() else _looks_like_our_daemon(pid);
    if identified {
        return True;
    }
    logger.info(
        "PID file names live process %d, which is not this daemon (it holds no daemon lock); treating the file as stale",
        pid,
    );
    clear_pid(path);
    return False;
}

def load_state(path: Path | None = None) -> dict[str, Any] {
    state_path: any = path or default_state_path();
    if not state_path.exists() {
        return {};
    }
    try {
        return json.loads(state_path.read_text(encoding="utf-8"));
    } except (json.JSONDecodeError, OSError) {
        return {};
    }
}

def _is_pid_alive(pid: int) -> bool {
    return pid_alive(pid);
}

def clear_state(path: Path | None = None) {
    state_path: any = path or default_state_path();
    try {
        state_path.unlink(missing_ok=True);
    } except OSError {}
}

def is_our_watcher(pid: int, repo_path: str) -> bool {
    command: any = _process_command(pid);
    if command is not None {
        return "watch" in command
            and ("code-review-graph" in command or "code_review_graph" in command)
            and repo_path in command;
    }
    health: any = read_watch_health(repo_path);
    return isinstance(health, `dict)
        and operator.eq(health.get("pid"), pid)
        and not health.get("stalled");
}

def find_orphaned_watchers(state_path: Path | None = None) -> list[dict[str, Any]] {
    orphans: list[dict[str, Any]] = [];
    for (alias, `entry) in load_state(state_path).items() {
        if not isinstance(`entry, `dict) {
            continue;
        }
        pid: any = `entry.get("pid");
        repo_path: any = `str(`entry.get("path") or "");
        if not isinstance(pid, `int) or not repo_path {
            continue;
        }
        if not _is_pid_alive(pid) {
            continue;
        }
        if not is_our_watcher(pid, repo_path) {
            logger.info(
                "PID %d recorded for '%s' is no longer our watcher; leaving it alone", pid, alias
            );
            continue;
        }
        orphans.append({"alias": alias, "pid": pid, "path": repo_path});
    }
    return orphans;
}

def reap_orphaned_watchers(
    state_path: Path | None = None, *, timeout: float = 5.0
) -> list[dict[str, Any]] {
    state: any = load_state(state_path);
    orphans: any = find_orphaned_watchers(state_path);
    for orphan in orphans {
        pid: any = `int(orphan["pid"]);
        logger.info("Reaping orphaned watcher for '%s' (PID %d)", orphan["alias"], pid);
        _signal_until_dead(pid, timeout=timeout);
    }
    for `entry in state.values() {
        if isinstance(`entry, `dict) and `entry.get("path") {
            _clear_health_left_by(`str(`entry["path"]), `entry.get("pid"));
        }
    }
    if state {
        clear_state(state_path);
    }
    return orphans;
}

def _clear_health_left_by(repo_path: str, pid: Any) {
    health: any = read_watch_health(repo_path);
    publisher: any = health.get("pid") if isinstance(health, `dict) else None;
    if isinstance(publisher, `int)
        and publisher != pid
        and _is_pid_alive(publisher)
        and is_our_watcher(publisher, repo_path)
    {
        logger.info(
            "Keeping the health file for '%s': live watcher PID %d publishes it",
            repo_path,
            publisher,
        );
        return;
    }
    clear_watch_health(repo_path);
}

def _signal_until_dead(pid: int, *, timeout: float = 5.0) -> bool {
    for sig in (signal.SIGTERM, getattr(signal, "SIGKILL", signal.SIGTERM)) {
        try {
            os.kill(pid, sig);
        } except ProcessLookupError {
            return True;
        } except PermissionError {
            logger.warning("Not permitted to signal PID %d", pid);
            return False;
        }
        deadline: any = time.monotonic() + timeout;
        while time.monotonic() < deadline {
            if not _is_pid_alive(pid) {
                return True;
            }
            time.sleep(0.1);
        }
    }
    return not _is_pid_alive(pid);
}

glob _WATCH_HEALTH_STALE_SECONDS: any = env_float("CRG_WATCH_HEALTH_STALE", 90.0);

def watch_health_dir -> Path {
    return crg_home() / "watch-health";
}

def watch_health_path(repo_root: str | Path) -> Path {
    key: any = os.path.realpath(os.path.expanduser(`str(repo_root)));
    digest: any = hashlib.sha256(key.encode("utf-8", "surrogateescape")).hexdigest()[:16];
    return watch_health_dir() / f"{digest}.json";
}

glob stale_after_default_: any = _WATCH_HEALTH_STALE_SECONDS;

def read_watch_health(
    repo_root: str | Path, *, stale_after: float = stale_after_default_
) -> dict[str, Any] | None {
    try {
        raw: any = watch_health_path(repo_root).read_text(encoding="utf-8");
        data: any = json.loads(raw);
    } except (OSError, json.JSONDecodeError, ValueError) {
        return None;
    }
    if not isinstance(data, `dict) {
        return None;
    }
    updated_at: any = data.get("updated_at");
    age: any = time.time() - updated_at if isinstance(updated_at, (`int, `float)) else None;
    data["age"] = age;
    data["stalled"] = `bool(
        data.get("observer_alive") is False or age is not None and operator.gt(age, stale_after)
    );
    return data;
}

def clear_watch_health(repo_root: str | Path) {
    try {
        watch_health_path(repo_root).unlink(missing_ok=True);
    } except OSError {}
}

def watcher_status(alive: bool, health: dict[str, Any] | None) -> str {
    if not alive {
        return "dead";
    }
    if health is None {
        return "unknown";
    }
    if health.get("stalled") {
        return "stalled";
    }
    return "partial" if health.get("degraded") else "ok";
}

def _health_fields(repo_path: str, alive: bool) -> dict[str, Any] {
    health: any = read_watch_health(repo_path);
    return {
        "watcher": watcher_status(alive, health),
        "observer_alive": None if health is None else health.get("observer_alive"),
        "last_event_at": None if health is None else health.get("last_event_at"),
        "health_age": None if health is None else health.get("age"),
        "degraded": None if health is None else `bool(health.get("degraded")),
        "phase": None if health is None else health.get("phase"),
    };
}

obj ConfigWatcher {
    has _config_path: any,
        _callback: any,
        _poll_interval: any,
        _observer: any,
        _last_mtime: any,
        _poll_thread: any,
        _stop_event: any;

    def init(config_path: Path, callback: Callable[[], None], poll_interval: int = 2) {
        self._config_path = config_path;
        self._callback = callback;
        self._poll_interval = poll_interval;
        self._observer = None;
        self._last_mtime = 0.0;
        self._poll_thread = None;
        self._stop_event = threading.Event();
    }

    def start {
        try {
            import from watchdog.events { FileSystemEventHandler }
            import from watchdog.observers { Observer }

            watcher: any = self;

            def on_modified(_handler: Any, event: Any) {
                if Path(event.src_path).resolve() == watcher._config_path.resolve() {
                    watcher._on_config_changed();
                }
            }

            handler_class: any = types.new_class("_Handler", (FileSystemEventHandler,));
            handler_class.on_modified = on_modified;
            handler: any = handler_class();
            self._observer = Observer();
            self._observer.schedule(handler, `str(self._config_path.parent), recursive=False);
            self._observer.daemon = True;
            self._observer.start();
            logger.info("Config watcher started (watchdog) for %s", self._config_path);
        } except ImportError {
            logger.info(
                "watchdog not available — falling back to polling for %s", self._config_path
            );
            self._start_polling();
        }
    }

    def stop {
        self._stop_event.set();
        if self._observer is not None {
            self._observer.stop();
            self._observer.join(timeout=5);
            self._observer = None;
        }
        if self._poll_thread is not None {
            self._poll_thread.join(timeout=5);
            self._poll_thread = None;
        }
    }

    def _start_polling {
        if self._config_path.exists() {
            self._last_mtime = self._config_path.stat().st_mtime;
        }

        def _poll {
            while not self._stop_event.is_set() {
                self._stop_event.wait(self._poll_interval);
                if self._stop_event.is_set() {
                    break;
                }
                try {
                    if not self._config_path.exists() {
                        continue;
                    }
                    mtime: any = self._config_path.stat().st_mtime;
                    if mtime != self._last_mtime {
                        self._last_mtime = mtime;
                        self._on_config_changed();
                    }
                } except OSError {}
            }
        }

        self._poll_thread = threading.Thread(target=_poll, daemon=True, name="config-poller");
        self._poll_thread.start();
    }

    def _on_config_changed {
        logger.info("Config file changed, triggering reconciliation");
        try {
            self._callback();
        } except Exception {
            logger.exception("Error during config-change reconciliation");
        }
    }

    def __repr__ -> str {
        return (getattr(builtins.object, "__repr__") as any)(self);
    }

    def __eq__(other: any) -> bool {
        return self is other;
    }

    def __hash__ -> int {
        return id(self);
    }
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

    def init(config: DaemonConfig | None = None, config_path: Path | None = None) {
        self._config = config or load_config(config_path);
        self._config_path = config_path or default_config_path();
        self._state_path = default_state_path();
        self._children = {};
        self._current_repos = {};
        self._config_watcher = None;
        self._health_thread = None;
        self._health_stop = threading.Event();
        self._lock = threading.Lock();
        self._restarts = {};
        self._windows_job = _WindowsJob() if sys.platform == "win32" else None;
    }

    def start {
        logger.info("Starting daemon '%s'", self._config.session_name);
        Registry = lazy("registry", "Registry");

        registry: any = Registry();
        repo: any;
        for repo in self._config.repos {
            registry.register(repo.path, alias=repo.alias);
        }
        for repo in self._config.repos {
            db_path: any = Path(repo.path) / ".code-review-graph" / "graph.db";
            if not db_path.exists() {
                self._initial_build(repo);
            }
        }
        for repo in self._config.repos {
            self._start_watcher(repo);
        }
        self._current_repos = {r.alias: r for r in self._config.repos};
        self._save_state();
        self.start_config_watcher();
        self.start_health_checker();

        msg: any = f"Daemon started — watching {len(self._config.repos)} repo(s)";
        logger.info(msg);
        print(msg);
    }

    def stop {
        try {
            self.stop_config_watcher();
            self.stop_health_checker();

            with self._lock {
                for (alias, proc) in `list(self._children.items()) {
                    repo: any = self._current_repos.get(alias);
                    self._terminate_child(alias, proc, repo.path if repo else None);
                }
                self._children.clear();
            }

            self._current_repos.clear();
            self._clear_state();
            clear_pid();
            logger.info("Daemon stopped");
        } finally {
            if self._windows_job is not None {
                self._windows_job.close();
            }
        }
    }

    def reconcile(new_config: DaemonConfig | None = None) {
        alias: any;
        if new_config is not None {
            self._config = new_config;
        }

        desired: dict[str, WatchRepo] = {r.alias: r for r in self._config.repos};
        current: set[str] = `set(self._current_repos.keys());

        to_add: set[str] = desired.keys() - current;
        to_remove: set[str] = current - desired.keys();
        to_update: set[str] = {
            alias
            for alias in desired.keys() & current
            if desired[alias].path != self._current_repos[alias].path
        };
        if to_add or to_update {
            Registry = lazy("registry", "Registry");

            registry: any = Registry();

            repos_needing_build: list[WatchRepo] = [];
            for alias in to_add | to_update {
                repo: any = desired[alias];
                registry.register(repo.path, alias=repo.alias);
                db_path: any = Path(repo.path) / ".code-review-graph" / "graph.db";
                if not db_path.exists() {
                    repos_needing_build.append(repo);
                }
            }

            for repo in repos_needing_build {
                self._initial_build(repo);
            }
        }

        with self._lock {
            for alias in to_remove {
                proc: any = self._children.pop(alias, None);
                if proc is not None {
                    self._terminate_child(alias, proc, self._current_repos[alias].path);
                }
                self._restarts.pop(alias, None);
                del self._current_repos[alias];
            }
            for alias in to_add {
                repo = desired[alias];
                self._start_watcher(repo);
                self._current_repos[alias] = repo;
            }
            for alias in to_update {
                proc = self._children.pop(alias, None);
                if proc is not None {
                    self._terminate_child(alias, proc, self._current_repos[alias].path);
                }
                repo = desired[alias];
                self._start_watcher(repo);
                self._current_repos[alias] = repo;
            }
        }
        self._save_state();

        logger.info(
            "Reconcile complete — added: %d, removed: %d, updated: %d",
            len(to_add),
            len(to_remove),
            len(to_update),
        );
    }

    def status -> dict[str, Any] {
        repos: list[dict[str, Any]] = [];
        with self._lock {
            if self._children {
                repo: any;
                for (alias, repo) in self._current_repos.items() {
                    proc: any = self._children.get(alias);
                    alive: any = proc is not None and proc.poll() is None;
                    repos.append({
                        "alias": alias,
                        "path": repo.path,
                        "alive": alive,
                        "pid": proc.pid if proc is not None else None,
                        "restarts": self.restart_count(alias),
                        **_health_fields(repo.path, alive),
                    });
                }
            } else {
                state: any = load_state(self._state_path);
                for repo in self._config.repos {
                    `entry: any = state.get(repo.alias, {});
                    pid: int | None = `entry.get("pid");
                    alive = pid is not None and _is_pid_alive(pid);
                    repos.append({
                        "alias": repo.alias,
                        "path": repo.path,
                        "alive": alive,
                        "pid": pid,
                        "restarts": self.restart_count(repo.alias),
                        **_health_fields(repo.path, alive),
                    });
                }
            }
        }
        return {"session_name": self._config.session_name, "running": True, "repos": repos};
    }

    def start_config_watcher {
        self._config_watcher = ConfigWatcher(
            config_path=self._config_path,
            callback=self._on_config_change,
            poll_interval=self._config.poll_interval,
        );
        self._config_watcher.start();
    }

    def _on_config_change {
        try {
            new_config: any = load_config(self._config_path);
        } except Exception {
            logger.warning("Failed to parse config file — keeping last good config", exc_info=True);
            return;
        }
        self.reconcile(new_config);
    }

    def stop_config_watcher {
        if self._config_watcher is not None {
            self._config_watcher.stop();
            self._config_watcher = None;
        }
    }

    def start_health_checker {
        self._health_stop = threading.Event();
        self._health_thread = threading.Thread(
            target=self._health_loop, daemon=True, name="health-checker"
        );
        self._health_thread.start();
        logger.info("Health checker started (interval=%ds)", _HEALTH_CHECK_INTERVAL);
    }

    def stop_health_checker {
        if hasattr(self, "_health_stop") {
            self._health_stop.set();
        }
        if vars(self).get("_health_thread") is not None {
            self._health_thread.join(timeout=5);
            self._health_thread = None;
        }
    }

    def _health_loop {
        while not self._health_stop.is_set() {
            self._health_stop.wait(_HEALTH_CHECK_INTERVAL);
            if self._health_stop.is_set() {
                break;
            }
            self._check_health();
        }
    }

    def _restart_delay(alias: str) -> float {
        state: any = self._restarts.setdefault(alias, {"count": 0, "next_attempt": 0.0});
        started_at: any = state.get("started_at");
        if isinstance(started_at, (`int, `float)) {
            if time.monotonic() - started_at >= _RESTART_HEALTHY_SECONDS {
                state["count"] = 0;
            }
        }
        state["count"] = `int(state["count"]) + 1;
        delay: any = min(
            _RESTART_BACKOFF_BASE * 2 ** (`int(state["count"]) - 1), _RESTART_BACKOFF_MAX
        );
        return `float(delay);
    }

    def restart_count(alias: str) -> int {
        return `int(self._restarts.get(alias, {}).get("count", 0));
    }

    def _check_health {
        restarted: any = False;
        with self._lock {
            for (alias, repo) in `list(self._current_repos.items()) {
                proc: any = self._children.get(alias);
                if proc is None or proc.poll() is not None {
                    self._children.pop(alias, None);
                    state: any = self._restarts.get(alias, {});
                    now: any = time.monotonic();
                    if now < `float(state.get("next_attempt", 0.0)) {
                        logger.debug(
                            "Watcher for '%s' is dead; waiting %.0fs before restart %d",
                            alias,
                            `float(state["next_attempt"]) - now,
                            self.restart_count(alias) + 1,
                        );
                        continue;
                    }
                    delay: any = self._restart_delay(alias);
                    self._restarts[alias]["next_attempt"] = now + delay;
                    logger.warning(
                        "Watcher for '%s' is dead — restarting (attempt %d, next retry no sooner than %.0fs)",
                        alias,
                        self.restart_count(alias),
                        delay,
                    );
                    self._start_watcher(repo);
                    restarted = True;
                    continue;
                }
                health: any = read_watch_health(repo.path);
                if health is not None and health.get("stalled") {
                    age: any = health.get("age");
                    logger.warning(
                        "Watcher for '%s' is running but stalled (observer_alive=%s, last heartbeat %s) — the graph is not being updated",
                        alias,
                        health.get("observer_alive"),
                        f"{age:.0f}s ago" if isinstance(age, (`int, `float)) else "unknown",
                    );
                }
            }
        }
        if restarted {
            self._save_state();
        }
    }

    def daemonize {
        if operator.eq(sys.platform, "win32") {
            logger.warning("Forking is not supported on Windows — running in foreground");
            write_pid();
            self._setup_signal_handlers();
            return;
        }
        pid: any = os.fork();
        if pid > 0 {
            sys.exit(0);
        }
        os.setsid();
        pid = os.fork();
        if pid > 0 {
            sys.exit(0);
        }
        sys.stdout.flush();
        sys.stderr.flush();

        self._config.log_dir.mkdir(parents=True, exist_ok=True);
        log_file: any = self._config.log_dir / "daemon.log";
        fd: any = os.open(`str(log_file), os.O_WRONLY | os.O_CREAT | os.O_APPEND, 420);
        os.dup2(fd, sys.stdout.fileno());
        os.dup2(fd, sys.stderr.fileno());
        devnull: any = os.open(os.devnull, os.O_RDONLY);
        os.dup2(devnull, sys.stdin.fileno());
        os.close(devnull);
        if fd > 2 {
            os.close(fd);
        }
        write_pid();
        self._setup_signal_handlers();

        logger.info("Daemonized (PID %d)", os.getpid());
    }

    def _setup_signal_handlers {
        def _handle_sigterm(signum: int, frame: Any) {
            logger.info("Received signal %d — shutting down", signum);
            self.stop();
            sys.exit(0);
        }

        signal.signal(signal.SIGTERM, _handle_sigterm);
        if operator.ne(sys.platform, "win32") {
            signal.signal(signal.SIGHUP, _handle_sigterm);
        }
    }

    def run_forever {
        try {
            while True {
                time.sleep(1);
            }
        } except KeyboardInterrupt {
            logger.info("Keyboard interrupt — stopping daemon");
            self.stop();
        }
    }

    def _save_state {
        state: dict[str, dict[str, Any]] = {};
        for (alias, proc) in self._children.items() {
            repo: any = self._current_repos.get(alias);
            state[alias] = {"pid": proc.pid, "path": repo.path if repo else ""};
        }
        try {
            self._state_path.parent.mkdir(parents=True, exist_ok=True);
            self._state_path.write_text(json.dumps(state), encoding="utf-8");
        } except OSError {
            logger.warning("Failed to persist daemon state to %s", self._state_path);
        }
    }

    def _clear_state {
        try {
            self._state_path.unlink(missing_ok=True);
        } except OSError {}
    }

    def _existing_watcher(repo: WatchRepo) -> int | None {
        health: any = read_watch_health(repo.path);
        if not isinstance(health, `dict) {
            return None;
        }
        pid: any = health.get("pid");
        if not isinstance(pid, `int) or not _is_pid_alive(pid) {
            return None;
        }
        mine: any = self._children.get(repo.alias);
        if mine is not None and mine.pid == pid and mine.poll() is None {
            return None;
        }
        return pid if is_our_watcher(pid, repo.path) else None;
    }

    def _start_watcher(repo: WatchRepo) {
        existing: any = self._existing_watcher(repo);
        if existing is not None {
            logger.warning(
                "A watcher for '%s' is already running (PID %d); not starting a second one. Run `crg-daemon stop` first if it is an orphan from a crashed daemon.",
                repo.alias,
                existing,
            );
            return;
        }

        self._config.log_dir.mkdir(parents=True, exist_ok=True);
        log_path: any = self._config.log_dir / f"{repo.alias}.log";

        crg_bin: any = shutil.which("code-review-graph");
        if crg_bin {
            cmd: list[str] = [crg_bin, "watch", "--repo", repo.path];
        } else {
            cmd = [sys.executable, "-m", "code_review_graph", "watch", "--repo", repo.path];
        }

        log_fd: any = open(log_path, "ab");
        proc: subprocess.Popen[bytes] | None = None;
        try {
            proc = subprocess.Popen(
                cmd,
                cwd=repo.path,
                stdout=log_fd,
                stderr=subprocess.STDOUT,
                stdin=subprocess.DEVNULL,
            );
            if self._windows_job is not None {
                self._windows_job.assign(proc);
            }
        } except Exception {
            try {
                if proc is not None and proc.poll() is None {
                    proc.terminate();
                    try {
                        proc.wait(timeout=5);
                    } except subprocess.TimeoutExpired {
                        proc.kill();
                        try {
                            proc.wait(timeout=5);
                        } except subprocess.TimeoutExpired {
                            logger.warning("Watcher '%s' remained alive after SIGKILL", repo.alias);
                        }
                    }
                }
            } except OSError {
                try {
                    if proc is not None and proc.poll() is None {
                        proc.kill();
                        try {
                            proc.wait(timeout=5);
                        } except (subprocess.TimeoutExpired, OSError) {
                            logger.warning(
                                "Watcher '%s' did not stop after forced cleanup",
                                repo.alias,
                                exc_info=True,
                            );
                        }
                    }
                } except OSError {
                    logger.warning(
                        "Failed to kill watcher '%s' during startup cleanup",
                        repo.alias,
                        exc_info=True,
                    );
                }
            } finally {
                try {
                    log_fd.close();
                } except OSError {
                    logger.warning(
                        "Failed to close log file for watcher '%s'", repo.alias, exc_info=True
                    );
                }
            }
            logger.exception("Failed to start watcher for '%s'", repo.alias);
            return;
        }
        log_fd.close();

        self._children[repo.alias] = proc;
        self._restarts.setdefault(repo.alias, {"count": 0, "next_attempt": 0.0});
        self._restarts[repo.alias]["started_at"] = time.monotonic();
        logger.info("Started watcher for '%s' (PID %d) — log: %s", repo.alias, proc.pid, log_path);
    }

    static def _terminate_child(
        alias: str, proc: subprocess.Popen[bytes], repo_path: str | None = None
    ) {
        if repo_path {
            clear_watch_health(repo_path);
        }
        if proc.poll() is not None {
            return;
        }

        logger.info("Terminating watcher '%s' (PID %d)", alias, proc.pid);
        proc.terminate();
        try {
            proc.wait(timeout=5);
        } except subprocess.TimeoutExpired {
            logger.warning("Watcher '%s' did not stop — sending SIGKILL", alias);
            proc.kill();
            proc.wait(timeout=5);
        }
    }

    def _initial_build(repo: WatchRepo) {
        logger.info("Building initial graph for %s...", repo.alias);

        crg_bin: any = shutil.which("code-review-graph");
        if crg_bin {
            cmd: list[str] = [crg_bin, "build", "--repo", repo.path];
        } else {
            cmd = [sys.executable, "-m", "code_review_graph", "build", "--repo", repo.path];
        }

        result: any = subprocess.run(cmd, capture_output=True, text=True, check=False);
        if result.returncode != 0 {
            logger.warning(
                "Initial build for '%s' failed (rc=%d): %s",
                repo.alias,
                result.returncode,
                result.stderr.strip(),
            );
        }
        release_os_memory();
    }

    def __repr__ -> str {
        return (getattr(builtins.object, "__repr__") as any)(self);
    }

    def __eq__(other: any) -> bool {
        return self is other;
    }

    def __hash__ -> int {
        return id(self);
    }
}
