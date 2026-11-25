import from __future__ { annotations }

import importlib, operator;

import from jaclang.comptime { target as target_ }

import concurrent.futures, fnmatch, hashlib, json, logging, os, re, signal, subprocess, sys, threading, types, builtins, time, unicodedata, uuid;

import from collections { deque }

import from functools { partial }

import from pathlib { Path, PurePosixPath }

import from typing { TYPE_CHECKING, Any, Callable, Iterable, NamedTuple, Optional }

def _get_code_parser_cls -> any;

def __getattr__(name: str) -> any;

glob _MAX_PARSE_WORKERS: any = env_int("CRG_PARSE_WORKERS", min(os.cpu_count() or 4, 8));

glob _MCP_STDIO_ACTIVE: any = False;

glob _PARSE_WORKER_STATE: any = threading.local();

def _windows_console_handle(fileno: int) -> bool;
def _stdin_is_interactive -> bool;
def _select_executor_kind -> str;
def _make_executor(max_workers: int) -> any;

glob logger: any = logging.getLogger(__name__);

glob VERIFIED_FILE_COUNT_KEY: any = "verified_file_count";

glob CPP_IDENTITY_VERSION: any = "1";

glob _CPP_IDENTITY_METADATA_KEY: any = "cpp_identity_version";

glob CSHARP_IDENTITY_VERSION: any = "5";

glob _CSHARP_IDENTITY_METADATA_KEY: any = "csharp_identity_version";

glob _CSHARP_PENDING_METADATA_KEY: any = "csharp_identity_pending_files";

glob NESTED_SCOPE_IDENTITY_VERSION: any = "1";

glob _NESTED_SCOPE_METADATA_KEY: any = "nested_scope_identity_version";

glob _NESTED_SCOPE_PENDING_KEY: any = "nested_scope_identity_pending_files";

glob _NESTED_SCOPE_UNCHANGED_LANGUAGES: any = ("python", "cpp", "julia", "ruby", "csharp");

glob _CPP_IDENTITY_PENDING_KEY: any = "cpp_identity_pending";

glob _DEPENDENTS_PENDING_KEY: any = "dependents_reparse_pending";

def _load_pending_paths(store: GraphStore, key: str) -> set[str];
def _nested_scope_files(store: GraphStore, repo_root: Path) -> set[str];
def _load_dependents_pending(store: GraphStore) -> set[str];
def _load_cpp_identity_pending(store: GraphStore) -> set[str] | None;

def _store_cpp_identity_pending(store: GraphStore, files: set[str]);
def _run_python_resolver(store: GraphStore) -> Optional[dict];
def _run_rescript_resolver(store: GraphStore) -> Optional[dict];
def _run_spring_resolver(store: GraphStore) -> Optional[dict];
def _run_aop_resolver(store: GraphStore) -> Optional[dict];
def _run_spring_event_resolver(store: GraphStore) -> Optional[dict];
def _run_temporal_resolver(store: GraphStore) -> Optional[dict];
def _run_hcl_resolver(store: GraphStore) -> Optional[dict];
def _run_scoped_resolver(store: GraphStore, repo_root: Path) -> Optional[dict];
def _enrichment_skip_reason(enrich: Optional[bool]) -> Optional[str];
def _run_jedi_enrichment(
    store: GraphStore,
    repo_root: Path,
    files: Optional[list[str]] = None,
    enrich: Optional[bool] = None,
) -> Optional[dict];
def _refresh_target_resolution(store: GraphStore);

glob DEFAULT_IGNORE_PATTERNS: any = ("**/.code-review-graph/** **/node_modules/** **/.git/** **/.svn/** **/__pycache__/** *.pyc "
    "**/.venv/** **/venv/** /dist/** /build/** /.next/** /.nuxt/** /target/** /bin/** /obj/** "
    "**/vendor/** /storage/** /bootstrap/cache/** /public/build/** **/.bundle/** **/.gradle/** "
    "*.jar **/.dart_tool/** **/.pub-cache/** **/cdk.out/** /coverage/** **/.cache/** /.tmp/** "
    "/tmp/** *.min.js *.min.css *.map *.lock package-lock.json **/package-lock.json "
    "npm-shrinkwrap.json **/npm-shrinkwrap.json *.lock.json project.assets.json "
    "**/project.assets.json *.min.json pnpm-lock.yaml **/pnpm-lock.yaml yarn.lock *.db *.sqlite "
    "*.db-journal *.db-wal").split();

glob NESTED_OUTPUT_DIR_MARKERS: dict[str, frozenset[str]] = {
    "vendor": frozenset({
        "composer.json",
        "go.mod",
        "go.work",
        "Gemfile",
        "Rakefile",
        "Cargo.toml",
    }),
    "target": frozenset({"pom.xml", "Cargo.toml", "build.sbt"}),
    "build": frozenset({
        "build.gradle",
        "build.gradle.kts",
        "settings.gradle",
        "settings.gradle.kts",
    }),
    ".next": frozenset({"next.config.js", "next.config.mjs", "next.config.cjs", "next.config.ts"}),
    ".nuxt": frozenset({"nuxt.config.js", "nuxt.config.mjs", "nuxt.config.ts"}),
};

glob _MODULE_SCAN_DEPTH: any = env_int("CRG_MODULE_SCAN_DEPTH", 3);

glob _MODULE_SCAN_MAX_DIRS: any = env_int("CRG_MODULE_SCAN_MAX_DIRS", 2000);

glob _MAX_NESTED_OUTPUT_PATTERNS: any = 200;

glob _NESTED_IGNORE_TTL_SECONDS: any = env_float("CRG_NESTED_IGNORE_TTL", 300.0);

glob _nested_ignore_cache: dict[tuple[str, tuple[str, ...], tuple[str, ...]], tuple[float, list[str]]] = {};

glob _nested_ignore_lock: any = threading.Lock();

def find_svn_root(start: Path | None = None) -> Optional[Path];
def find_repo_root(start: Path | None = None, stop_at: Path | None = None) -> Optional[Path];
def detect_vcs(`root: Path) -> str;
def _git_worktree_prefix(repo_root: Path) -> str;
def find_project_root(start: Path | None = None, stop_at: Path | None = None) -> Path;
def _write_data_dir_gitignore(data_dir: Path);
def _create_data_dir(data_dir: Path);
def get_data_dir(repo_root: Path, *, create: bool = True) -> Path;
def get_db_path(repo_root: Path, *, read_only: bool = False) -> Path;
def _prepare_db_path(repo_root: Path, new_db: Path);
def ensure_repo_gitignore_excludes_crg(repo_root: Path) -> str;
def _load_ignore_patterns(repo_root: Path) -> list[str];
def _should_ignore(path: str, patterns: list[str]) -> bool;
def _child_directories(directory: Path) -> list[tuple[str, bool]];

glob max_depth_default_: any = _MODULE_SCAN_DEPTH;

glob max_dirs_default_: any = _MODULE_SCAN_MAX_DIRS;

def _scan_nested_output_dirs(
    repo_root: Path,
    base_patterns: list[str],
    max_depth: int = max_depth_default_,
    max_dirs: int = max_dirs_default_,
) -> list[str];
def _nested_output_ignore_patterns(
    repo_root: Path, base_patterns: list[str], keep: tuple[str, ...] = ()
) -> list[str];
def clear_nested_ignore_cache(repo_root: Path | None = None);
def _is_binary(path: Path) -> bool;

glob _RECURSE_SUBMODULES: any = os.environ.get("CRG_RECURSE_SUBMODULES", "").lower()
    in ("1", "true", "yes");

def _git_branch_info(repo_root: Path) -> tuple[str, str];
def _svn_revision_info(repo_root: Path) -> tuple[str, str];

glob _SAFE_GIT_REF: any = re.compile("^[A-Za-z0-9_.~^/@{}\\-]+$");

glob _SAFE_SVN_REV: any = re.compile("^r?\\d+(:r?\\d+|:HEAD|:BASE|:COMMITTED)?$", re.IGNORECASE);

def _decode_name_status_paths(output: bytes) -> list[str];
def _store_vcs_metadata(repo_root: Path, store: "GraphStore") -> bool;
def _commit_object_exists(repo_root: Path, ref: str) -> bool;
def resolve_incremental_base(repo_root: Path, store: "GraphStore") -> str | None;
def resolve_review_base(
    repo_root: Path, base: str, *, timeout: float | None = None, require_vcs: bool = False
) -> str;
def _vcs_unavailable(
    tool: str, exc: BaseException, *, timeout: float | None = None
) -> ChangeDiscoveryError;
def get_changed_files(
    repo_root: Path,
    base: str = "HEAD~1",
    *,
    strict: bool = False,
    timeout: float | None = None,
    require_vcs: bool = False,
) -> list[str];
def _find_content_mismatches(
    repo_root: Path, store: "GraphStore", only: set[str] | None = None
) -> tuple[list[str], dict[str, str], set[str]];
def _get_svn_changed_files(
    repo_root: Path,
    rev_range: str | None = None,
    *,
    timeout: float | None = None,
    require_vcs: bool = False,
) -> list[str];
def _utf8_paths(paths: Iterable[str]) -> list[str];
def get_staged_and_unstaged(
    repo_root: Path, *, timeout: float | None = None, require_vcs: bool = False
) -> list[str];

glob DEFAULT_REVIEW_BASE: any = "HEAD~1";

glob ONE_COMMIT_NOTE: any = "this repository has one commit; reviewing uncommitted and new files instead.";

glob NO_COMMIT_NOTE: any = "this repository has no commits yet; reviewing uncommitted and new files instead.";

glob SHALLOW_CLONE_NOTE: any = "HEAD~1 is not in this shallow clone; reviewing uncommitted and new files instead. Run `git fetch --deepen=1` to review the last commit.";

def _git_is_shallow(repo_root: Path, timeout: float) -> bool;
def _git_commit_known(repo_root: Path, ref: str, timeout: float) -> bool | None;
def _empty_tree(repo_root: Path, timeout: float) -> str;
def _usable_review_base(
    repo_root: Path, base: str, resolved_base: str, timeout: float, notes: list[str] | None
) -> str;

glob base_default_: any = DEFAULT_REVIEW_BASE;

def discover_review_changes(
    repo_root: Path, base: str = base_default_, *, notes: list[str] | None = None
) -> tuple[list[str], str];

glob _FRESHNESS_FILE_LIMIT: any = 200;

def graph_holds_commits(
    repo_root: Path, store: GraphStore, built_at: str, *, timeout: float | None = None
) -> bool;
def files_hold_commits(
    repo_root: Path,
    file_hashes: Callable[[], dict[str, str]],
    built_at: str,
    *,
    timeout: float | None = None,
) -> bool;
def get_all_tracked_files(repo_root: Path, recurse_submodules: bool | None = None) -> list[str];

glob INSTALL_MANIFEST: any = PurePosixPath(".code-review-graph", "install-manifest.json");

def install_manifest_paths(repo_root: Path) -> frozenset[str];
def _without_install_files(repo_root: Path, untracked: list[str]) -> list[str];
def _get_untracked_files(
    repo_root: Path, *, timeout: float | None = None, require_vcs: bool = False
) -> list[str];
def _get_svn_all_tracked_files(repo_root: Path) -> list[str];

glob FOLLOW_SYMLINKS_ENV: any = "CRG_FOLLOW_SYMLINKS";

glob _FOLLOWED_FILES_KEY: any = "symlink_followed_files";

glob _FOLLOWED_DIRS_KEY: any = "symlink_followed_dirs";

def follow_symlinks_enabled(explicit: bool | None = None) -> bool;
def _inventory_candidates(repo_root: Path, recurse_submodules: bool | None = None) -> list[str];
def _keep_candidate(
    repo_root: Path, rel_path: str, ignore_patterns: list[str], parser: CodeParser
) -> bool;

glob _reported_links: any = set[any]();

def _report_once(`root: Path, key: str, level: int, message: str, *args_: object);
def _max_followed_files -> int;
def _is_junction(`entry: os.DirEntry) -> bool;

class _FollowedTree(NamedTuple) {
    has files: list[str];

    has links: list[str];

    has outside: dict[str, str];

    has inside: list[str];
}

def _walk_symlinked_dirs(
    repo_root: Path, candidates: Iterable[str], ignore_patterns: list[str]
) -> _FollowedTree;
def _path_key(rel_path: str) -> str;
def _followed_extra_files(
    repo_root: Path, candidates: list[str], ignore_patterns: list[str], parser: CodeParser
) -> tuple[list[str], _FollowedTree];
def _followed_tree(repo_root: Path, ignore_patterns: list[str]) -> _FollowedTree;
def _outermost(paths: Iterable[str]) -> set[str];
def _collect_files(
    repo_root: Path, recurse_submodules: bool | None = None, follow_symlinks: bool | None = None
) -> tuple[list[str], list[str], dict[str, str]];
def collect_all_files(
    repo_root: Path, recurse_submodules: bool | None = None, follow_symlinks: bool | None = None
) -> list[str];
def _load_followed_files(store: GraphStore) -> set[str];
def followed_files(store: GraphStore) -> set[str];
def _load_followed_dirs(store: GraphStore) -> dict[str, str];
def _store_followed(store: GraphStore, paths: set[str], dirs: dict[str, str]);
def _relink_prefixes(repo_root: Path, dirs: dict[str, str]) -> list[tuple[str, str]];

def _relinked(value: str, prefixes: list[tuple[str, str]]) -> str;
def _relink_edges(edges: list, repo_root: Path, dirs: dict[str, str]);
def _relink_stored_edges(store: GraphStore, repo_root: Path, dirs: dict[str, str]);
def path_within_repo(repo_root: Path | str, path: Path | str, followed: Iterable[str] = ()) -> bool;
def _outside_or_below_symlink(repo_root: Path, rel_path: str) -> bool;
def _followed_files_delta(
    repo_root: Path, store: GraphStore, follow: bool, ignore_patterns: list[str], parser: CodeParser
) -> tuple[list[str], list[str], set[str] | None, dict[str, str]];
def _reconcile_stale_files(
    repo_root: Path,
    store: GraphStore,
    current_files: list[str] | None = None,
    *,
    known_text: set[str] | None = None,
    remove: bool = True,
) -> list[str];
def _assert_graph_matches_root(repo_root: Path, store: GraphStore);

glob _ROOT_PROBE_LIMIT: any = 25;

def assert_graph_serves_root(repo_root: Path, store: GraphStore);

glob _MAX_DEPENDENT_HOPS: any = env_int("CRG_DEPENDENT_HOPS", 2);

glob _MAX_DEPENDENT_FILES: any = 500;

def _single_hop_dependents(store: GraphStore, file_path: str) -> set[str];

glob _NO_GRAMMAR_LANGUAGES: any = frozenset({"rescript", "vbnet", "yaml", "properties"});

def _prewarm_parser_probes(parser: Any, rel_paths: list[str]);

class DependentList(builtins.list) {
    has truncated: bool;

    def init(items: list, *, truncated: bool = False);
}

glob max_hops_default_: any = _MAX_DEPENDENT_HOPS;

def find_dependents(
    store: GraphStore, file_path: str, max_hops: int = max_hops_default_
) -> DependentList;
def _parse_single_file(args: tuple[str, str]) -> tuple[str, list, list, str | None, str];
def _canonical_repo_root(repo_root: Path) -> Path;
def full_build(
    repo_root: Path,
    store: GraphStore,
    recurse_submodules: bool | None = None,
    enrich: bool | None = None,
    follow_symlinks: bool | None = None,
) -> dict;
def _relative_update_input(repo_root: Path, path: str) -> str;
def incremental_update(
    repo_root: Path,
    store: GraphStore,
    base: str = "HEAD~1",
    changed_files: list[str] | None = None,
    reconcile_stale: bool = True,
    enrich: bool | None = None,
    follow_symlinks: bool | None = None,
    *,
    reconcile_followed: bool = False,
) -> dict;

glob _DEBOUNCE_SECONDS: any = 1;

class _WatchDebouncer(threading.Thread) {
    def init(interval: float, callback: Callable[[list[Any]], None]);

    def handle_event(event: Any);
    def requeue(events: list[Any]);
    def stop;

    def run;
}

def _raise_watch_update_errors(result: dict, context: str);
def _raise_watch_postprocess_warnings(result: object);

glob _WATCH_PLAN_DEPTH: any = env_int("CRG_WATCH_PLAN_DEPTH", 3);

glob _MAX_WATCH_SCHEDULES: any = env_int("CRG_MAX_WATCH_SCHEDULES", 24);

glob _WATCH_SPLIT_MIN_DIRS: any = env_int("CRG_WATCH_SPLIT_MIN_DIRS", 4);

glob _WATCH_HEALTH_INTERVAL: any = env_float("CRG_WATCH_HEALTH_INTERVAL", 10.0);

glob _WATCH_STOP_TIMEOUT: any = 10.0;

glob _WATCH_TICK_SECONDS: any = 1.0;

glob _WATCH_LOCK_POLL_SECONDS: any = 0.25;

glob _PROMOTION_RETRY_SECONDS: any = 30.0;

glob _MAX_UNWATCHED_TRACKED: any = env_int("CRG_MAX_UNWATCHED_TRACKED", 256);

def _watch_child_dirs(directory: Path, cache: dict[Path, list[Path]] | None = None) -> list[Path];
def _ignored_tree_weight(directory: Path, cap: int) -> int;

glob split_threshold_default_: any = _WATCH_SPLIT_MIN_DIRS;

def _plan_watch_subtree(
    directory: Path,
    repo_root: Path,
    ignore_patterns: list[str],
    depth: int,
    max_depth: int,
    cache: dict[Path, list[Path]],
    split_threshold: int = split_threshold_default_,
) -> tuple[bool, list[tuple[Path, bool]]];

glob max_depth_default__: any = _WATCH_PLAN_DEPTH;

glob max_schedules_default_: any = _MAX_WATCH_SCHEDULES;

glob split_threshold_default__: any = _WATCH_SPLIT_MIN_DIRS;

def _plan_watch_paths(
    repo_root: Path,
    ignore_patterns: list[str],
    max_depth: int = max_depth_default__,
    max_schedules: int = max_schedules_default_,
    split_threshold: int = split_threshold_default__,
) -> list[tuple[Path, bool]];

glob max_depth_default___: any = _WATCH_PLAN_DEPTH;

glob max_schedules_default__: any = _MAX_WATCH_SCHEDULES;

glob split_threshold_default___: any = _WATCH_SPLIT_MIN_DIRS;

def _plan_watch_paths_with_status(
    repo_root: Path,
    ignore_patterns: list[str],
    max_depth: int = max_depth_default___,
    max_schedules: int = max_schedules_default__,
    split_threshold: int = split_threshold_default___,
) -> tuple[list[tuple[Path, bool]], bool];
def _run_time_boxed(operation: Callable[[], Any], description: str, timeout: float = 10.0);
def _watch_health_path(repo_root: Path) -> Path | None;
def _watch_identity(path: str | Path) -> tuple[int, int, float] | None;

class _WatchEntry(NamedTuple) {
    has handle: Any;

    has identity: tuple[int, int, float] | None;
}

glob max_schedules_default___: any = _MAX_WATCH_SCHEDULES;

obj _WatchSupervisor {
    has _observer: any,
        _repo_root: any,
        _ignore_patterns: any,
        _health_path: any,
        _max_schedules: any,
        _handler: any,
        _watches: any,
        _extra: any,
        _shallow: any,
        _live_threads: any,
        _repaired_roots: any,
        _replan_requested: any,
        _replan_retry_at: any,
        _ignored_boundaries: any,
        _degraded: any,
        _promotion_failed: any,
        _unwatched: any,
        _refused_to_index: any,
        _promotion_retry_at: any,
        _last_health_write: any,
        _last_health_state: any,
        _started_at: any,
        _token: any;

    def init(
        observer: Any,
        repo_root: Path,
        ignore_patterns: list[str],
        health_path: Path | None = None,
        max_schedules: int = max_schedules_default___,
    );

    has watched_paths: list[str] {
        getter {
            return sorted(self._watches);
        }
    }

    has degraded: bool {
        getter {
            return self._degraded or self._promotion_failed or `bool(self._unwatched);
        }
    }

    has unwatched_paths: list[str] {
        getter {
            return sorted(self._unwatched);
        }
    }

    def attach(observer: Any);
    def schedule_initial(handler: Any);

    def _schedule(path: Path, *, recursive: bool);
    def sync_extra_roots(roots: set[str]);
    def request_replan;

    def _remember_ignored_boundaries;

    def _replan_if_requested;
    def rewatch_all -> bool;
    def sync_watches(*, ignore_patterns: list[str] | None = None) -> tuple[list[str], list[str]];
    def take_refused_to_index -> list[str];
    def _note_unwatched(key: str);
    def _prune_unwatched;
    def _children_of(parent: str) -> list[str];
    def _descendants_of(parent: str) -> list[str];
    def _adopt_directory(candidate: str, *, required: bool = False) -> bool;
    def _affordable_plan(directory: Path) -> list[tuple[Path, bool]] | None;
    def _promote_to_recursive(parent: str) -> bool;

    def _release_directory(path: str);
    def _watchdog_threads -> list[tuple[threading.Thread, str | None]];
    def check_liveness -> tuple[list[str], list[str]];
    def report_health(
        *,
        observer_alive: bool,
        last_event_at: float | None = None,
        events_seen: int = 0,
        dead_threads: tuple[str, ...] = (),
        phase: str = "watching",
        force: bool = False,
    );
    def clear_health;

    def __repr__ -> str;

    def __eq__(other: any) -> bool;

    def __hash__ -> int;
}

def _is_csharp_project(relative_path: str) -> bool;
def _event_only_touches(event: Any, target: Path) -> bool;
def _holds_symlink(directory: Path, relative: str, ignore_patterns: list[str]) -> bool;
def _create_watch_handler(
    repo_root: Path,
    store: GraphStore,
    on_files_updated: Optional[Callable],
    on_directory_changed: Optional[Callable[[], None]] = None,
    follow_symlinks: bool | None = None,
) -> any;
def _sync_watch_tree(supervisor: _WatchSupervisor, handler: Any);
def _wait_for_watch_write_lock(
    lock: WriteLock, supervisor: _WatchSupervisor, stop_event: threading.Event | None
) -> bool;
def _install_sigterm_interrupt -> Callable[[], None];
def watch(
    repo_root: Path,
    store: GraphStore,
    on_files_updated: Optional[Callable] = None,
    stop_event: threading.Event | None = None,
    follow_symlinks: bool | None = None,
);
def start_watch_thread(
    repo_root: Path,
    store: GraphStore,
    daemon: bool = True,
    *,
    on_files_updated: Optional[Callable] = None,
    stop_event: threading.Event | None = None,
) -> threading.Thread | None;
