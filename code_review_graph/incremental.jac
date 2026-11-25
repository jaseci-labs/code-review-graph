"""Incremental graph update logic.

Detects changed files via git diff, re-parses only changed + impacted files,
and updates the graph accordingly. Also supports CLI invocation for hooks.
"""

import importlib;

import operator;

import from jaclang.comptime { target as target_ }

import from __future__ { annotations }

import concurrent.futures;

import fnmatch;

import hashlib;

import json;

import logging;

import os;

import re;

import signal;

import subprocess;

import sys;

import threading;

import types;

import builtins;

import time;

import unicodedata;

import uuid;

import from collections { deque }

import from functools { partial }

import from pathlib { Path, PurePosixPath }

import from typing { TYPE_CHECKING, Any, Callable, Iterable, NamedTuple, Optional }

def _get_code_parser_cls -> any;

def __getattr__(name: str) -> any;

glob _MAX_PARSE_WORKERS: any;

glob _MCP_STDIO_ACTIVE: any;

glob _PARSE_WORKER_STATE: any;

glob logger: any;

glob VERIFIED_FILE_COUNT_KEY: any;

glob CPP_IDENTITY_VERSION: any;

glob _CPP_IDENTITY_METADATA_KEY: any;

glob CSHARP_IDENTITY_VERSION: any;

glob _CSHARP_IDENTITY_METADATA_KEY: any;

glob _CSHARP_PENDING_METADATA_KEY: any;

glob NESTED_SCOPE_IDENTITY_VERSION: any;

glob _NESTED_SCOPE_METADATA_KEY: any;

glob _NESTED_SCOPE_PENDING_KEY: any;

glob _NESTED_SCOPE_UNCHANGED_LANGUAGES: any;

glob _CPP_IDENTITY_PENDING_KEY: any;

glob _DEPENDENTS_PENDING_KEY: any;

glob DEFAULT_IGNORE_PATTERNS: any;

glob NESTED_OUTPUT_DIR_MARKERS: dict[str, frozenset[str]];

glob _MODULE_SCAN_DEPTH: any;

glob _MODULE_SCAN_MAX_DIRS: any;

glob _MAX_NESTED_OUTPUT_PATTERNS: any;

glob _NESTED_IGNORE_TTL_SECONDS: any;

glob _nested_ignore_cache: dict[tuple[str, tuple[str, ...], tuple[str, ...]], tuple[float, list[str]]];

glob _nested_ignore_lock: any;

glob _RECURSE_SUBMODULES: any;

glob _SAFE_GIT_REF: any;

glob _SAFE_SVN_REV: any;

glob DEFAULT_REVIEW_BASE: any;

glob ONE_COMMIT_NOTE: any;

glob NO_COMMIT_NOTE: any;

glob SHALLOW_CLONE_NOTE: any;

glob _FRESHNESS_FILE_LIMIT: any;

glob INSTALL_MANIFEST: any;

glob FOLLOW_SYMLINKS_ENV: any;

glob _FOLLOWED_FILES_KEY: any;

glob _FOLLOWED_DIRS_KEY: any;

glob _reported_links: any;

glob _ROOT_PROBE_LIMIT: any;

glob _MAX_DEPENDENT_HOPS: any;

glob _MAX_DEPENDENT_FILES: any;

glob _NO_GRAMMAR_LANGUAGES: any;

glob _DEBOUNCE_SECONDS: any;

glob _WATCH_PLAN_DEPTH: any;

glob _MAX_WATCH_SCHEDULES: any;

glob _WATCH_SPLIT_MIN_DIRS: any;

glob _WATCH_HEALTH_INTERVAL: any;

glob _WATCH_STOP_TIMEOUT: any;

glob _WATCH_TICK_SECONDS: any;

glob _WATCH_LOCK_POLL_SECONDS: any;

glob _PROMOTION_RETRY_SECONDS: any;

glob _MAX_UNWATCHED_TRACKED: any;

with entry {
    _MAX_PARSE_WORKERS = env_int("CRG_PARSE_WORKERS", min(os.cpu_count() or 4, 8));
    _MCP_STDIO_ACTIVE = False;
    _PARSE_WORKER_STATE = threading.local();
}

"""Return True when ``fileno`` is a real Windows console.

    On Windows, ``isatty()`` is True for any character device, including the
    ``NUL`` device that ``subprocess`` uses for ``stdin=DEVNULL`` and that
    Node uses for ``stdio: "ignore"``. Only a console handle accepts
    ``GetConsoleMode``, so that call tells the two apart.
    """
def _windows_console_handle(fileno: int) -> bool;

"""Return True only when stdin is an interactive terminal."""
def _stdin_is_interactive -> bool;

"""Return 'process' or 'thread' for parallel parsing.

    Defaults to ``process`` (the original behavior, fastest on Linux/macOS).
    Auto-switches to ``thread`` for an active MCP stdio server on every
    platform, where ``ProcessPoolExecutor`` workers can inherit the transport
    pipe/socket and prevent EOF shutdown. The older Windows non-TTY fallback
    remains for direct integrations that predate the explicit transport flag
    (issues #46, #136, PR #615). On Windows, stdin redirected from the
    ``NUL`` device counts as non-interactive even though ``isatty()`` is
    True for it, because a caller that kills such a run leaves its pool
    workers behind as orphans.

    Override explicitly with ``CRG_PARSE_EXECUTOR={process,thread}``.

    Tree-sitter parsing in the worker releases the GIL during native
    parsing, so the speedup loss for falling back to threads is small
    (typically <30% on the full-build path) and the trade is worth it
    to avoid the deadlock + zombie process accumulation.
    """
def _select_executor_kind -> str;

"""Construct the parallel-parse executor selected by [_select_executor_kind]."""
def _make_executor(max_workers: int) -> any;

with entry {
    logger = logging.getLogger(__name__);
    VERIFIED_FILE_COUNT_KEY = "verified_file_count";
    CPP_IDENTITY_VERSION = "1";
    _CPP_IDENTITY_METADATA_KEY = "cpp_identity_version";
    CSHARP_IDENTITY_VERSION = "5";
    _CSHARP_IDENTITY_METADATA_KEY = "csharp_identity_version";
    _CSHARP_PENDING_METADATA_KEY = "csharp_identity_pending_files";
    NESTED_SCOPE_IDENTITY_VERSION = "1";
    _NESTED_SCOPE_METADATA_KEY = "nested_scope_identity_version";
    _NESTED_SCOPE_PENDING_KEY = "nested_scope_identity_pending_files";
    _NESTED_SCOPE_UNCHANGED_LANGUAGES = ("python", "cpp", "julia", "ruby", "csharp");
    _CPP_IDENTITY_PENDING_KEY = "cpp_identity_pending";
    _DEPENDENTS_PENDING_KEY = "dependents_reparse_pending";
}

"""Repo-relative paths a metadata *key* holds for the next update to retry."""
def _load_pending_paths(store: GraphStore, key: str) -> set[str];

"""Files whose nested class members held leaf-scoped identities before #934."""
def _nested_scope_files(store: GraphStore, repo_root: Path) -> set[str];

"""Importers whose forced re-parse failed, for the next update to retry.

    Their seed's new hash is already stored, so nothing else would find them.
    """
def _load_dependents_pending(store: GraphStore) -> set[str];

"""Load failed paths from a complete attempt of this identity version.

    A missing/older checkpoint must still take the normal full migration path.
    Keep the global version stale until every recorded replacement succeeds.
    """
def _load_cpp_identity_pending(store: GraphStore) -> set[str] | None;

def _store_cpp_identity_pending(store: GraphStore, files: set[str]) -> None;

"""Run repository-wide Python import resolution without failing a build."""
def _run_python_resolver(store: GraphStore) -> Optional[dict];

"""Run the ReScript cross-module resolver, swallowing any failure so
    build never fails because of it. Returns stats or None on error.
    """
def _run_rescript_resolver(store: GraphStore) -> Optional[dict];

"""Run the Spring DI call resolver, swallowing any failure so
    build never fails because of it. Returns stats or None on error.
    """
def _run_spring_resolver(store: GraphStore) -> Optional[dict];

"""Run the Spring AOP advice-to-target call resolver, swallowing any
    failure so build never fails because of it. Returns stats or None on error.
    """
def _run_aop_resolver(store: GraphStore) -> Optional[dict];

"""Run the Spring application-event resolver without failing a build."""
def _run_spring_event_resolver(store: GraphStore) -> Optional[dict];

"""Run the Temporal workflow/activity call resolver, swallowing any failure so
    build never fails because of it. Returns stats or None on error.
    """
def _run_temporal_resolver(store: GraphStore) -> Optional[dict];

"""Run Terraform module-scope resolution without failing a build."""
def _run_hcl_resolver(store: GraphStore) -> Optional[dict];

"""Resolve static/scoped ``Class::method`` calls without failing a build."""
def _run_scoped_resolver(store: GraphStore, repo_root: Path) -> Optional[dict];

"""Why the Jedi step does not run, or ``None`` when it was asked for.

    Opt-in: Jedi costs about a second per Python file, so having the
    ``enrichment`` extra installed (``[all]`` pulls it in) is not a request.
    *enrich* (CLI ``--enrich``) asks for it; ``None`` falls back to
    ``CRG_ENABLE_ENRICHMENT=1``. ``CRG_DISABLE_ENRICHMENT=1`` overrides both.
    """
def _enrichment_skip_reason(enrich: Optional[bool]) -> Optional[str];

"""Run post-build Jedi call-resolution enrichment (optional extra).

    Resolves ``receiver.method()`` calls on lowercase receivers with Jedi.
    Runs only when asked for (see :func:`_enrichment_skip_reason`); otherwise
    Jedi is not even imported and the graph is exactly what it would be
    without this step. Best-effort like the other resolvers: skipped when
    the ``[enrichment]`` extra (jedi) is not installed and never fails a
    build.

    *files* limits the scan to those files (see ``enrich_jedi_calls``);
    ``None`` scans every Python file.
    """
def _run_jedi_enrichment(
    store: GraphStore,
    repo_root: Path,
    files: Optional[list[str]] = None,
    enrich: Optional[bool] = None,
) -> Optional[dict];

"""Reclassify CALLS/REFERENCES targets after the cross-file resolvers.

    The resolvers above rewrite bare targets into qualified ones, so this has
    to run last. A failure here costs the query layer its stored certainty
    column, which every read falls back from safely, so it must never fail a
    build.
    """
def _refresh_target_resolution(store: GraphStore) -> None;

with entry {
    DEFAULT_IGNORE_PATTERNS = [
        "**/.code-review-graph/**",
        "**/node_modules/**",
        "**/.git/**",
        "**/.svn/**",
        "**/__pycache__/**",
        "*.pyc",
        "**/.venv/**",
        "**/venv/**",
        "/dist/**",
        "/build/**",
        "/.next/**",
        "/.nuxt/**",
        "/target/**",
        "/bin/**",
        "/obj/**",
        "**/vendor/**",
        "/storage/**",
        "/bootstrap/cache/**",
        "/public/build/**",
        "**/.bundle/**",
        "**/.gradle/**",
        "*.jar",
        "**/.dart_tool/**",
        "**/.pub-cache/**",
        "**/cdk.out/**",
        "/coverage/**",
        "**/.cache/**",
        "/.tmp/**",
        "/tmp/**",
        "*.min.js",
        "*.min.css",
        "*.map",
        "*.lock",
        "package-lock.json",
        "**/package-lock.json",
        "npm-shrinkwrap.json",
        "**/npm-shrinkwrap.json",
        "*.lock.json",
        "project.assets.json",
        "**/project.assets.json",
        "*.min.json",
        "pnpm-lock.yaml",
        "**/pnpm-lock.yaml",
        "yarn.lock",
        "*.db",
        "*.sqlite",
        "*.db-journal",
        "*.db-wal",
    ];
    NESTED_OUTPUT_DIR_MARKERS = {
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
        ".next": frozenset({
            "next.config.js",
            "next.config.mjs",
            "next.config.cjs",
            "next.config.ts",
        }),
        ".nuxt": frozenset({"nuxt.config.js", "nuxt.config.mjs", "nuxt.config.ts"}),
    };
    _MODULE_SCAN_DEPTH = env_int("CRG_MODULE_SCAN_DEPTH", 3);
    _MODULE_SCAN_MAX_DIRS = env_int("CRG_MODULE_SCAN_MAX_DIRS", 2000);
    _MAX_NESTED_OUTPUT_PATTERNS = 200;
    _NESTED_IGNORE_TTL_SECONDS = env_float("CRG_NESTED_IGNORE_TTL", 300.0);

    _nested_ignore_cache = {};
    _nested_ignore_lock = threading.Lock();
}

"""Walk up from start to find the SVN working copy root.

    For SVN 1.7+, there is a single ``.svn`` at the WC root.
    For older SVN, every directory has ``.svn`` — we return the topmost one
    found so that the WC root is correctly identified.
    """
def find_svn_root(start: Path | None = None) -> Optional[Path];

"""Walk up from ``start`` to find the nearest ``.git`` directory or SVN working copy root.

    Args:
        start: Starting directory.  Defaults to ``Path.cwd()``.
        stop_at: Optional boundary — if provided, the walk examines
            ``stop_at`` for a ``.git`` directory and then stops without
            crossing above it.  Useful for tests that create a synthetic
            repo under ``tmp_path`` (so the walk does not accidentally
            climb into a developer's home-directory dotfiles repo) and
            for any production caller that wants to bound the ancestor
            walk — e.g. multi-repo orchestrators, CI containers with
            bind-mounted volumes, embedded sandboxes.  See #241.

    Returns:
        The first ancestor containing ``.git`` or an SVN working copy,
        or ``None`` if no ancestor up to and including ``stop_at`` (when
        set) or the filesystem root (when ``stop_at is None``) contains one.
    """
def find_repo_root(start: Path | None = None, stop_at: Path | None = None) -> Optional[Path];

"""Return the nearest Git or SVN working copy containing *root*."""
def detect_vcs(`root: Path) -> str;

"""Return the path from the Git root to a requested subproject root."""
def _git_worktree_prefix(repo_root: Path) -> str;

"""Find the project root.

    Resolution order (highest precedence first):

    1. ``CRG_REPO_ROOT`` environment variable — explicit override for
       anyone scripting the CLI from outside the repo (CI jobs, daemons,
       multi-repo orchestrators). See: #155
    2. Git repository root via :func:`find_repo_root` from ``start``,
       honoring ``stop_at`` if provided.
    3. ``start`` itself (or cwd if no start given).

    ``stop_at`` is forwarded to :func:`find_repo_root` so callers that
    want to bound the ancestor walk (typically tests; see #241) can do so
    without having to call ``find_repo_root`` directly.
    """
def find_project_root(start: Path | None = None, stop_at: Path | None = None) -> Path;

"""Write .gitignore file in data directory if it doesn't exist.

    The gitignore contains a single '*' to prevent accidental commits.
    """
def _write_data_dir_gitignore(data_dir: Path) -> None;

"""Create the data directory, or say why it could not be created.

    ``GraphStore`` already reports a directory it cannot *write* to as one
    ``Error: ...`` line naming ``CRG_DATA_DIR``. A directory that cannot be
    *created* is the same failure one step earlier, and reached the user as a
    ``PermissionError`` traceback out of ``pathlib.mkdir`` because it happens
    while the path is still being resolved, before any store exists.
    """
def _create_data_dir(data_dir: Path) -> None;

"""Return the directory where this project's graph data lives.

    Resolution priority:
    1. Registry entry for this repo (set via --data-dir)
    2. CRG_DATA_DIR environment variable (global override)
    3. Default: <repo>/.code-review-graph/

    A missing registered directory is ignored when a local graph.db already
    exists, so an expired temporary relocation cannot strand that graph.

    By default, ``<repo_root>/.code-review-graph``. If the
    ``CRG_DATA_DIR`` environment variable is set, it is used verbatim
    instead — letting you keep graphs outside the working tree (useful
    for ephemeral workspaces, Docker volumes, or shared caches). See: #155

    By default the directory is created if it does not already exist; an
    inner ``.gitignore`` (with ``*``) is written so any accidentally-nested
    files never get committed. Both are idempotent. Pass ``create=False``
    when resolving the path for a read-only existence check.
    """
def get_data_dir(repo_root: Path, *, create: bool = True) -> Path;

"""Determine the database path for a repository.

    Respects ``CRG_DATA_DIR`` (see :func:`get_data_dir`). Migrates a
    legacy top-level ``.code-review-graph.db`` file into the new
    directory when it exists (WAL/SHM side-files are discarded). Pass
    ``read_only=True`` to resolve the current path without creating a data
    directory, migrating a legacy database, or deleting side-files.
    """
def get_db_path(repo_root: Path, *, read_only: bool = False) -> Path;

"""Prepare an already resolved database path, under the writer's lock."""
def _prepare_db_path(repo_root: Path, new_db: Path) -> None;

"""Ensure repo-level .gitignore excludes ``.code-review-graph/``.

    Returns one of:
    - ``created``: .gitignore was created with the entry
    - ``updated``: entry was appended to existing .gitignore
    - ``already-present``: no changes were needed
    """
def ensure_repo_gitignore_excludes_crg(repo_root: Path) -> str;

"""Load ignore patterns from .code-review-graphignore file.

    A line starting with ``!`` keeps a path out of the automatic nested
    build-output detection (see :data:`NESTED_OUTPUT_DIR_MARKERS`); it does not
    negate the explicit patterns, which keep their existing meaning.
    The default vendor exclusion applies to Composer, Go, Ruby and Cargo projects
    identified by root manifests. Nested manifests exclude their sibling
    vendor/ directory; other repositories can explicitly ignore vendor/.
    """
def _load_ignore_patterns(repo_root: Path) -> list[str];

"""Check if a path matches any ignore pattern.

    ``**/<dir>/**`` and unanchored single-directory patterns match at any
    depth. A leading slash anchors a pattern to the repository root.
    """
def _should_ignore(path: str, patterns: list[str]) -> bool;

"""List ``directory`` once, returning ``(name, is_dir)`` for its entries.

    Symlinked directories are reported as non-directories so no walk follows
    them out of the repository.  Returns an empty list for anything that
    cannot be listed — an unreadable directory is not worth a failed watch.
    """
def _child_directories(directory: Path) -> list[tuple[str, bool]];

glob max_depth_default_: any;

glob max_dirs_default_: any;

with entry {
    max_depth_default_ = _MODULE_SCAN_DEPTH;
    max_dirs_default_ = _MODULE_SCAN_MAX_DIRS;
}

"""Find nested build-output directories that a sibling manifest confirms.

    Returns root-anchored ignore patterns such as ``/moduleA/target/**``.  The
    walk lists directories only, skips trees the base patterns already ignore,
    and is bounded by *max_depth* and *max_dirs*.
    """
def _scan_nested_output_dirs(
    repo_root: Path,
    base_patterns: list[str],
    max_depth: int = max_depth_default_,
    max_dirs: int = max_dirs_default_,
) -> list[str];

"""Cached wrapper around :func:`_scan_nested_output_dirs`.

    The result is reused for ``_NESTED_IGNORE_TTL_SECONDS`` so a long-running
    watch pays for the scan once, not on every incremental update, while a
    module added later is still picked up without a restart.  Set
    ``CRG_NESTED_OUTPUT_SCAN=0`` to turn the whole thing off, or list
    ``!some/path`` in ``.code-review-graphignore`` to spare one directory.

    Excluding a directory removes its files from the graph, so the result is
    logged at info level: an unexpected exclusion has to be discoverable from
    a normal build, not only by diffing file counts.
    """
def _nested_output_ignore_patterns(
    repo_root: Path, base_patterns: list[str], keep: tuple[str, ...] = ()
) -> list[str];

"""Drop cached output patterns for one repository, or all repositories."""
def clear_nested_ignore_cache(repo_root: Path | None = None) -> None;

"""Quick heuristic: check if file appears to be binary."""
def _is_binary(path: Path) -> bool;

with entry {
    _RECURSE_SUBMODULES = os.environ.get("CRG_RECURSE_SUBMODULES", "").lower()
        in ("1", "true", "yes");
}

"""Return (branch_name, head_sha) for the current repo state."""
def _git_branch_info(repo_root: Path) -> tuple[str, str];

"""Return (branch_path, revision_str) for the current SVN working copy."""
def _svn_revision_info(repo_root: Path) -> tuple[str, str];

with entry {
    _SAFE_GIT_REF = re.compile("^[A-Za-z0-9_.~^/@{}\\-]+$");
    _SAFE_SVN_REV = re.compile("^r?\\d+(:r?\\d+|:HEAD|:BASE|:COMMITTED)?$", re.IGNORECASE);
}

"""Decode ``git diff --name-status -z`` output into a list of paths.

    Renames and copies (``R<score>``/``C<score>`` records) carry two paths —
    the old and the new one.  Both are emitted so the old path flows through
    the purge loop in :func:`incremental_update`; otherwise a rename leaves
    the old path's nodes and edges in the graph and the incremental result
    diverges from a full rebuild.
    """
def _decode_name_status_paths(output: bytes) -> list[str];

"""Persist VCS branch/revision info and report whether its anchor was stored."""
def _store_vcs_metadata(repo_root: Path, store: "GraphStore") -> bool;

"""Return True if *ref* resolves to a commit object present in the repo.

    This is an object-existence check, not an ancestry check: a commit that is
    only reachable from a branch we have since switched away from is still a
    valid ``git diff`` base, so we must accept it. Any git failure (missing
    binary, timeout, unknown ref) is treated as "not usable".
    """
def _commit_object_exists(repo_root: Path, ref: str) -> bool;

"""Resolve the automatic diff base for a default incremental update.

    The graph records the commit it was last built at (``git_head_sha``). Using
    that as the diff base lets a single ``update`` reconcile every change since
    the graph was last in sync, instead of only the most recent commit, which
    is what a fixed ``HEAD~1`` base does. That fixed base silently misses work
    that arrived through a multi-commit pull, rebase, or branch switch.

    Returns:
        - the stored commit SHA when it is still a usable diff base;
        - ``"HEAD~1"`` for SVN or non-git working copies, whose change
          discovery ignores or reinterprets the base anyway;
        - ``None`` for a git repo with no usable anchor (a fresh or legacy
          database, or a stored commit lost to a history rewrite or shallow
          clone), signalling the caller to do a full rebuild rather than
          diff against a wrong base.
    """
def resolve_incremental_base(repo_root: Path, store: "GraphStore") -> str | None;

"""Resolve a branch-like Git review base to its common ancestor with HEAD.

    ``git diff <branch>`` compares the two tips and therefore includes commits
    made only on the base branch after the reviewed branch diverged.  GitHub's
    "Files changed" view instead uses the merge base.  Preserve explicit
    commit/revision inputs, but translate local and remote-tracking branch
    refs to that common ancestor.

    If ref detection or merge-base resolution fails (for example in a shallow
    clone), return *base* unchanged so callers retain the existing diff
    behaviour rather than silently reporting no changes.

    Args:
        repo_root: Repository root directory.
        base: Git ref to resolve.
        timeout: Seconds allowed for each Git subprocess. ``None`` (default)
            uses the general ``CRG_GIT_TIMEOUT`` budget; the change-discovery
            chain passes the shorter :func:`discovery_timeout` instead.
        require_vcs: Raise
            :class:`~code_review_graph.errors.ChangeDiscoveryError` when git
            cannot be run or overruns *timeout*, instead of returning *base*
            unresolved.

            Falling back to the unresolved ref is right for a shallow clone,
            where there genuinely is no merge base, and wrong for a timeout:
            the caller then diffs two tips instead of the common ancestor and
            silently scopes the review to the base branch's commits too. The
            shorter the budget, the likelier that is, so the discovery chain
            asks to be told.
    """
def resolve_review_base(
    repo_root: Path, base: str, *, timeout: float | None = None, require_vcs: bool = False
) -> str;

"""Describe a VCS command that could not be run at all.

    Missing binary and timeout are the two failures that say nothing about
    the working tree, so a caller must never read them as "nothing changed".

    *timeout* is the budget that actually expired. It matters which one is
    named: change discovery runs on :func:`~.constants.discovery_timeout`,
    and telling that caller to raise ``CRG_GIT_TIMEOUT`` would send them to a
    knob that does not govern the call they just made.
    """
def _vcs_unavailable(
    tool: str, exc: BaseException, *, timeout: float | None = None
) -> ChangeDiscoveryError;

"""Get list of changed files via git diff or svn status.

    Git results also include untracked, non-ignored files so newly created
    source files reach incremental indexing before they are staged.

    For SVN working copies the *base* parameter is ignored; modified/added/
    deleted files are detected from ``svn status``.  Pass an SVN revision
    range (e.g. ``"r100:HEAD"``) as *base* to compare against a specific
    revision instead.  When *strict* is true, Git discovery failures raise
    instead of being reported as an empty change list.

    Args:
        repo_root: Repository root directory.
        base: Git ref (or SVN revision range) to diff against.
        strict: Raise instead of returning ``[]`` when Git discovery fails.
        timeout: Seconds allowed for each subprocess. ``None`` (default) uses
            the general ``CRG_GIT_TIMEOUT`` budget, which is what build,
            incremental update and watch want; the read-only change-discovery
            chain passes the shorter :func:`discovery_timeout` instead.
        require_vcs: The narrower half of *strict*, for callers whose whole
            answer is "these files changed": it raises
            :class:`~code_review_graph.errors.ChangeDiscoveryError` when the
            VCS binary is missing or times out, but keeps the documented
            fallback for a base ref that simply does not resolve (a repository
            with no commits still has to work). Returning ``[]`` for a VCS that
            could not be run is what let ``detect-changes`` report a clean tree
            it never looked at.

            It is also what makes the short *timeout* above safe to use: a
            budget that is exhausted has to be reported, not rounded down to
            "no changes".
    """
def get_changed_files(
    repo_root: Path,
    base: str = "HEAD~1",
    *,
    strict: bool = False,
    timeout: float | None = None,
    require_vcs: bool = False,
) -> list[str];

"""Find indexed files whose bytes differ from the graph's last parsed hash.

    Also returns the stored spellings of every file read that is not binary,
    so stale-file reconciliation can reuse this pass instead of reading the
    repository a second time.

    Git diffs compare the working tree with a base commit.  If a file is
    changed, incrementally indexed, and then reverted before the next update,
    that diff is empty even though the graph still represents the intermediate
    content.  Comparing indexed hashes with the files on disk catches that
    round trip and also catches a reverted file when another path keeps the
    git diff non-empty.
    """
def _find_content_mismatches(
    repo_root: Path, store: "GraphStore", only: set[str] | None = None
) -> tuple[list[str], dict[str, str], set[str]];

"""Return changed files in an SVN working copy.

    When *rev_range* is given (e.g. ``"r100:HEAD"``), ``svn diff --summarize``
    is used to list files changed between those revisions.  Otherwise
    ``svn status`` reports working-copy modifications.

    *timeout* is the per-subprocess budget; ``None`` uses ``CRG_GIT_TIMEOUT``.

    *require_vcs* has the same meaning as in :func:`get_changed_files`: an
    ``svn`` that cannot be run is raised rather than reported as "nothing
    changed".
    """
def _get_svn_changed_files(
    repo_root: Path,
    rev_range: str | None = None,
    *,
    timeout: float | None = None,
    require_vcs: bool = False,
) -> list[str];

"""Drop names that are not valid UTF-8: SQLite raises on any lookup of one.

    ``os.fsdecode`` keeps such a name as surrogate escapes, and these lists go
    straight into graph queries from ``update`` and the review tools.
    """
def _utf8_paths(paths: Iterable[str]) -> list[str];

"""Get all modified files (staged + unstaged + untracked).

    ``--untracked-files=all`` is deliberate and load-bearing, not a default
    nobody chose. It is what makes a brand-new, never-committed directory
    report the files inside it. Git's cheaper ``normal`` mode collapses such a
    directory to a single ``dir/`` record, which is not a path any caller can
    open, so scoping the walk down would delete the first commit of every new
    feature package from every review. See the note in
    :func:`discover_review_changes`.

    Args:
        repo_root: Repository root directory.
        timeout: Seconds allowed for the subprocess. ``None`` (default) uses
            the general ``CRG_GIT_TIMEOUT`` budget; the change-discovery chain
            passes the shorter :func:`discovery_timeout` instead.
        require_vcs: Raise
            :class:`~code_review_graph.errors.ChangeDiscoveryError` when git
            cannot be run or overruns *timeout*, instead of returning ``[]``.
            A caller whose answer is an all-clear must pass this.
    """
def get_staged_and_unstaged(
    repo_root: Path, *, timeout: float | None = None, require_vcs: bool = False
) -> list[str];

with entry {
    DEFAULT_REVIEW_BASE = "HEAD~1";

    ONE_COMMIT_NOTE = "this repository has one commit; reviewing uncommitted and new files instead.";
    NO_COMMIT_NOTE = "this repository has no commits yet; reviewing uncommitted and new files instead.";
    SHALLOW_CLONE_NOTE = "HEAD~1 is not in this shallow clone; reviewing uncommitted and new files instead. Run `git fetch --deepen=1` to review the last commit.";
}

"""Return whether this clone was cut short, as CI checkouts often are.

    Git before 2.15 does not know the option and echoes it back, which reads
    as "not shallow", the same answer as before this check existed.
    """
def _git_is_shallow(repo_root: Path, timeout: float) -> bool;

"""Return whether Git knows *ref* as a commit, or None when it cannot say.

    ``rev-parse --verify --quiet`` exits 1 for an unknown name and 128 when
    the folder is not a repository at all. Only the first is an answer.
    """
def _git_commit_known(repo_root: Path, ref: str, timeout: float) -> bool | None;

"""Return the id of the empty tree in this repository's hash format."""
def _empty_tree(repo_root: Path, timeout: float) -> str;

"""Check a Git review base before it is diffed against.

    A base Git does not know used to fall through to ``git status``, so a
    typo in ``--base`` reviewed the working tree and exited 0. A base the
    caller chose is now an error that says what to do. The default
    ``HEAD~1`` is different: in a repository with one commit, or none, or a
    shallow clone that holds only HEAD, it does not resolve, so the review
    covers uncommitted and new files and *notes* says so in plain words.
    """
def _usable_review_base(
    repo_root: Path, base: str, resolved_base: str, timeout: float, notes: list[str] | None
) -> str;

glob base_default_: any;

with entry {
    base_default_ = DEFAULT_REVIEW_BASE;
}

"""Discover the files under review, on the short discovery budget.

    This is the chain every review-shaped tool and command runs when the
    caller did not name ``changed_files`` itself: resolve the base, diff
    against it, and fall back to the working tree when that diff is empty.

    Two things make it different from calling the three functions directly,
    and both exist because this chain runs inside an MCP tool call that a
    client will abandon at its own request ceiling (#262):

    * every subprocess gets :func:`discovery_timeout` rather than the
      30-second ``CRG_GIT_TIMEOUT`` that build, update and watch need, so the
      worst case for the whole chain is seconds rather than two minutes;
    * every subprocess runs with ``require_vcs=True``, so exhausting that
      budget raises :class:`~code_review_graph.errors.ChangeDiscoveryError`.

    The second is what licenses the first. Shortening a budget whose timeout
    path returns ``[]`` would not have made this chain safer -- it would have
    made #913's false all-clear several times easier to hit, and extended it
    to the base resolution, where a timed-out merge base silently degrades a
    three-dot diff into a two-dot one and scopes the review to the wrong
    commits. Timing out is a failure, and it is now reported as one: callers
    turn the error into ``status: error`` naming
    ``CRG_DISCOVERY_TIMEOUT``, which a user can act on, instead of an
    all-clear they cannot tell from a clean tree.

    Note what this chain deliberately does *not* do: scope down the untracked
    walk. ``git status --untracked-files=normal`` is much cheaper on a large
    tree, and it was tried, but it collapses a wholly-untracked directory to
    one ``dir/`` record -- so the first commit of a new package disappears
    from every review tool with ``status: ok`` and no warning. Being slow is a
    bug; confidently reviewing nothing is a worse one. The budget above bounds
    the walk instead, and reports it when it does.

    Args:
        repo_root: Repository root directory.
        base: The ref to review against. The default, ``HEAD~1``, cannot
            resolve in a repository with one commit or none; the review then
            covers uncommitted and new files instead.
        notes: When given, plain sentences for the user are appended to it,
            such as the one saying the default base was replaced.

    Returns:
        ``(changed_files, resolved_base)``. The resolved base is returned
        because callers need the same ref afterwards, for diff hunks and risk
        scoring, and resolving it twice would spend the budget twice.

    Raises:
        ChangeDiscoveryError: git could not be run, overran the discovery
            budget, or does not know a base the caller chose. Never raised
            for a repository that simply has no changes.
    """
def discover_review_changes(
    repo_root: Path, base: str = base_default_, *, notes: list[str] | None = None
) -> tuple[list[str], str];

with entry {
    _FRESHNESS_FILE_LIMIT = 200;
}

"""Return True when the graph already holds every file changed since *built_at*.

    The pre-commit hook updates the graph before Git makes the commit, so the
    graph records the parent commit while already holding the committed
    files. Comparing commit ids alone then calls the graph stale after every
    hooked commit. This looks at the files instead: each file that differs
    between *built_at* and ``HEAD`` must have the same SHA-256 in the graph
    as on disk, a deleted file must be gone from the graph, and a file the
    graph does not hold must be one a build would leave out too.

    Any doubt -- git failing, too many files, a file that cannot be read --
    answers False, which keeps the old "update first" advice.
    """
def graph_holds_commits(
    repo_root: Path, store: GraphStore, built_at: str, *, timeout: float | None = None
) -> bool;

""":func:`graph_holds_commits` for a caller that reads the graph itself.

    ``file_hashes`` returns the graph's ``{file path: SHA-256}`` for File
    nodes, keyed as :meth:`GraphStore.get_file_hashes` keys them. It is
    called only once Git has listed the changed files. ``doctor`` uses this
    with its own read-only connection.
    """
def files_hold_commits(
    repo_root: Path,
    file_hashes: Callable[[], dict[str, str]],
    built_at: str,
    *,
    timeout: float | None = None,
) -> bool;

"""Get all files tracked by git or svn.

    Args:
        repo_root: Repository root directory.
        recurse_submodules: If True, pass ``--recurse-submodules`` to
            ``git ls-files`` so that files inside git submodules are
            included.  When *None* (default), falls back to the
            ``CRG_RECURSE_SUBMODULES`` environment variable.
            (Ignored for SVN working copies.)
    """
def get_all_tracked_files(repo_root: Path, recurse_submodules: bool | None = None) -> list[str];

with entry {
    INSTALL_MANIFEST = PurePosixPath(".code-review-graph", "install-manifest.json");
}

"""Return the repository paths ``install`` says it wrote.

    Build and change discovery leave these out while Git does not track
    them, so an install's own ``.mcp.json``, hook scripts and instruction
    files neither enter the graph nor fill the first review. Once the user
    commits one, Git tracks it and it is treated like any other file.

    No manifest, or one this release cannot read, means nothing is left out.
    """
def install_manifest_paths(repo_root: Path) -> frozenset[str];

"""Drop the files ``install`` wrote from a list Git calls untracked."""
def _without_install_files(repo_root: Path, untracked: list[str]) -> list[str];

"""Return Git's untracked, non-ignored files using NUL-delimited paths.

    Files the install manifest lists are left out: see
    :func:`install_manifest_paths`.
    """
def _get_untracked_files(
    repo_root: Path, *, timeout: float | None = None, require_vcs: bool = False
) -> list[str];

"""Return SVN-versioned files by walking the working copy.

    Uses ``svn list -R`` to get the server-side file list, falling back to
    a filesystem walk (which is also the fallback in :func:`collect_all_files`).
    """
def _get_svn_all_tracked_files(repo_root: Path) -> list[str];

with entry {
    FOLLOW_SYMLINKS_ENV = "CRG_FOLLOW_SYMLINKS";
    _FOLLOWED_FILES_KEY = "symlink_followed_files";
    _FOLLOWED_DIRS_KEY = "symlink_followed_dirs";
}

"""Return whether symlinked folders are followed.

    *explicit* (the CLI flag) wins when given; otherwise ``CRG_FOLLOW_SYMLINKS``
    decides. It is read on every call so tests and long-lived processes see
    the value in force when the work starts.
    """
def follow_symlinks_enabled(explicit: bool | None = None) -> bool;

"""Return the repository-relative paths a build considers, unfiltered.

    Git's tracked files plus its untracked, non-ignored files; SVN's versioned
    files; or, when neither answers, a walk of the directory. Symlinks are
    listed as entries of their own (Git never looks inside a symlinked
    folder), which is how followed folders are found.
    """
def _inventory_candidates(repo_root: Path, recurse_submodules: bool | None = None) -> list[str];

"""Return whether one inventory path is a file the graph should hold."""
def _keep_candidate(
    repo_root: Path, rel_path: str, ignore_patterns: list[str], parser: CodeParser
) -> bool;

with entry {
    _reported_links = set[any]();
}

"""Log *message* at *level* the first time in this process, then at debug.

    A watcher walks the followed folders again whenever a link changes, and
    the same line on every walk would bury everything else in the log.
    """
def _report_once(`root: Path, key: str, level: int, message: str, *args_: object) -> None;

"""How many files may be reached through symlinked folders in one walk."""
def _max_followed_files -> int;

"""Whether *entry* is a Windows junction, which can point anywhere.

    ``DirEntry.is_junction`` only exists from Python 3.12; before that a
    folder whose real path is not its own path is treated the same way.
    """
def _is_junction(`entry: os.DirEntry) -> bool;

"""What following the symlinked folders found (#269)."""
class _FollowedTree(NamedTuple) {
    has files: list[str];

    has links: list[str];

    has outside: dict[str, str];

    has inside: list[str];
}

"""Follow the symlinked folders among *candidates* (#269).

    A link to a folder inside the repository lists that folder under its
    real path, so a file reached by a link and directly has one path. A link
    to a folder outside the repository lists it under the link's own path:
    the outside real path is never stored.

    A link is not followed when its own path is ignored, when its target is
    an ignored folder of the repository, or when it points at a folder that
    holds it or holds the repository (a cycle). Below a link, an ignore rule
    applies to the path through the link as well as the stored path. Each real folder is listed
    at most once, by device and inode, so links that point at each other
    cannot loop. At most ``CRG_MAX_FOLLOWED_FILES`` new files are taken, and
    the log says when that cap cuts the walk short. Symlinked files are
    never followed.
    """
def _walk_symlinked_dirs(
    repo_root: Path, candidates: Iterable[str], ignore_patterns: list[str]
) -> _FollowedTree;

"""Spelling-blind key: case and Unicode form differ on some disks."""
def _path_key(rel_path: str) -> str;

"""Return the parseable files only symlinked folders reach, and the walk.

    A file the inventory already lists, or one already taken under another
    spelling or another link, is left out, so each file is stored once.
    """
def _followed_extra_files(
    repo_root: Path, candidates: list[str], ignore_patterns: list[str], parser: CodeParser
) -> tuple[list[str], _FollowedTree];

"""Walk the symlinked folders of the repository as a build would."""
def _followed_tree(repo_root: Path, ignore_patterns: list[str]) -> _FollowedTree;

"""Drop every path that sits inside another one of *paths*."""
def _outermost(paths: Iterable[str]) -> set[str];

"""Return ``(files, followed, outside)``: the inventory, the part of it
    that is there only because a symlinked folder was followed, and the
    followed folders outside the repository (real path to in-repo path)."""
def _collect_files(
    repo_root: Path, recurse_submodules: bool | None = None, follow_symlinks: bool | None = None
) -> tuple[list[str], list[str], dict[str, str]];

"""Collect all parseable files in the repo, respecting ignore patterns.

    Args:
        repo_root: Repository root directory.
        recurse_submodules: If True, include files from git submodules.
            When *None*, falls back to ``CRG_RECURSE_SUBMODULES`` env var.
        follow_symlinks: If True, also collect files in symlinked folders,
            under paths inside the repository. When *None*, falls back to
            ``CRG_FOLLOW_SYMLINKS``. Default: off.
    """
def collect_all_files(
    repo_root: Path, recurse_submodules: bool | None = None, follow_symlinks: bool | None = None
) -> list[str];

"""Stored paths a followed symlinked folder put in the graph."""
def _load_followed_files(store: GraphStore) -> set[str];

"""Stored paths the graph reached through a followed symlinked folder.

    Tools that read a file back pass this to :func:`path_within_repo`, so a
    file behind a link the user asked to follow is read through its in-repo
    path while every other path outside the repository is still refused.
    """
def followed_files(store: GraphStore) -> set[str];

"""Followed folders outside the repository: real path to in-repo path."""
def _load_followed_dirs(store: GraphStore) -> dict[str, str];

"""Record what followed symlinked folders put in the graph.

    Nothing is written for a graph that never used the option.
    """
def _store_followed(store: GraphStore, paths: set[str], dirs: dict[str, str]) -> None;

"""``(real prefix, in-repo prefix)`` pairs, longest real prefix first."""
def _relink_prefixes(repo_root: Path, dirs: dict[str, str]) -> list[tuple[str, str]];

def _relinked(value: str, prefixes: list[tuple[str, str]]) -> str;

"""Point edges at the in-repo path of files behind a followed link.

    Import resolution resolves symlinks, so an import between two files in a
    linked folder outside the repository would otherwise name the outside
    real path, which the graph never stores.
    """
def _relink_edges(edges: list, repo_root: Path, dirs: dict[str, str]) -> None;

"""The same, for edges the post-build resolvers wrote."""
def _relink_stored_edges(store: GraphStore, repo_root: Path, dirs: dict[str, str]) -> None;

"""Whether *path* may be read (or edited) as part of the repository.

    Its real path must lie inside the repository, or it must be one of the
    *followed* paths (see :func:`followed_files`): a file the graph reached
    through a symlinked folder the user asked to follow, read through its
    in-repo path. Any other path outside the repository is refused, whether
    it gets there with ``..`` or through a link nobody followed.
    """
def path_within_repo(repo_root: Path | str, path: Path | str, followed: Iterable[str] = ()) -> bool;

"""Whether *rel_path* leaves the repository or goes through a symlink."""
def _outside_or_below_symlink(repo_root: Path, rel_path: str) -> bool;

"""Compare what symlinked folders reach now with what the graph holds.

    Returns ``(new, gone, record, outside)``: repository-relative files a
    followed folder reaches that the graph does not hold yet; stored paths
    that were in the graph only through a followed folder and no longer are
    (the link went, or the option is off), or that sit in a followed folder
    inside the repository where a build would not take them (the watcher
    indexes a new file by its own path, before any link rule is applied);
    the new record, or ``None`` when there is nothing to compare; and the
    followed folders outside the repository. A graph that never used the
    option costs nothing.
    """
def _followed_files_delta(
    repo_root: Path, store: GraphStore, follow: bool, ignore_patterns: list[str], parser: CodeParser
) -> tuple[list[str], list[str], set[str] | None, dict[str, str]];

"""Remove graph files absent from the current parseable repository inventory.

    ``known_text`` holds stored spellings already read and found not binary in
    this update, so they are not read again just to repeat that check.

    When *remove* is False, only identify stale paths so callers can capture
    flow/community state before the permanent delete (#569).
    """
def _reconcile_stale_files(
    repo_root: Path,
    store: GraphStore,
    current_files: list[str] | None = None,
    *,
    known_text: set[str] | None = None,
    remove: bool = True,
) -> list[str];

"""Refuse an incremental reconciliation anchored to a different root.

    Authoritative File nodes identify the root a graph was built with. Every
    marker must be under the requested root: partial overlap can otherwise
    delete valid files in a parent or sibling repository (#909). Orphan-only
    databases have no File markers and retain the purge behavior from #861.
    """
def _assert_graph_matches_root(repo_root: Path, store: GraphStore) -> None;

with entry {
    _ROOT_PROBE_LIMIT = 25;
}

"""Refuse to *answer* from a graph built for a different repository.

    ``_assert_graph_matches_root`` guards the write side only: it runs during
    incremental reconciliation, where a wrong root would purge files. Every
    read-only consumer opened the same database without asking, so dropping
    one repository's ``graph.db`` into another repository (a copied file, a
    restored CI cache) served that repository's symbols and absolute paths
    under this repository's name, and exited 0 while doing it.

    Refusing to answer is not destructive the way purging is, so this check
    is deliberately narrower than the write-side one: it fires only on an
    unambiguously foreign graph. Four things are not that, and pass:

    * a graph with no authoritative File markers at all;
    * a graph of repo-relative paths, which carry no root identity;
    * a different spelling of the same root (macOS ``/var`` against
      ``/private/var``, a symlinked checkout) — resolved before comparing;
    * a graph whose files are not on this machine at all, which is stale or
      synthetic rather than another live checkout being served.
    """
def assert_graph_serves_root(repo_root: Path, store: GraphStore) -> None;

with entry {
    _MAX_DEPENDENT_HOPS = env_int("CRG_DEPENDENT_HOPS", 2);
    _MAX_DEPENDENT_FILES = 500;
}

"""Find files that directly depend on *file_path* (single hop).

    A file depends on *file_path* when it imports it, or when one of its
    edges calls, imports, inherits or implements a node defined in it.
    """
def _single_hop_dependents(store: GraphStore, file_path: str) -> set[str];

with entry {
    _NO_GRAMMAR_LANGUAGES = frozenset({"rescript", "vbnet", "yaml", "properties"});
}

"""Pre-warm grammar load probes concurrently before spawning worker pool."""
def _prewarm_parser_probes(parser: Any, rel_paths: list[str]) -> None;

"""A ``list[str]`` with a ``.truncated`` flag.

    When :func:`find_dependents` hits ``_MAX_DEPENDENT_FILES`` it truncates
    the result and sets ``truncated = True`` so callers can distinguish a
    complete expansion from a capped one.  See issue #261.

    This is a transparent ``list`` subclass — existing callers that iterate,
    ``len()``, or slice continue to work unchanged; only callers that
    specifically check ``.truncated`` benefit from the signal.
    """
class DependentList(builtins.list) {
    has truncated: bool;

    def init(items: list, *, truncated: bool = False);
}

glob max_hops_default_: any;

with entry {
    max_hops_default_ = _MAX_DEPENDENT_HOPS;
}

"""Find files that import from or depend on the given file.

    Performs up to *max_hops* iterations of expansion (default 2).
    Stops early if the total exceeds 500 files.

    Returns a :class:`DependentList` — a regular ``list[str]`` that also
    carries a ``.truncated`` flag.  When ``truncated is True`` the
    returned list is capped at ``_MAX_DEPENDENT_FILES`` and the full
    set of dependents was not explored.  See issue #261.
    """
def find_dependents(
    store: GraphStore, file_path: str, max_hops: int = max_hops_default_
) -> DependentList;

"""Parse one file in a process- or thread-pool worker.

    Returns ``(rel_path, nodes, edges, error_or_none, file_hash)``.
    Must be a module-level function so ``ProcessPoolExecutor`` can
    serialise it across processes.
    """
def _parse_single_file(args: tuple[str, str]) -> tuple[str, list, list, str | None, str];

"""Return one stable identity for a repository root.

    Graph paths are anchored to the root supplied by the caller. Resolving the
    root once prevents equivalent spellings (notably ``.`` and an absolute
    path) from looking like two different repositories during reconciliation.
    """
def _canonical_repo_root(repo_root: Path) -> Path;

"""Full rebuild of the entire graph.

    Args:
        repo_root: Repository root directory.
        store: Graph database store.
        recurse_submodules: If True, include files from git submodules.
            When *None*, falls back to ``CRG_RECURSE_SUBMODULES`` env var.
        enrich: If True, resolve Python method calls with Jedi (the
            ``enrichment`` extra). When *None*, falls back to
            ``CRG_ENABLE_ENRICHMENT``. Off by default.
        follow_symlinks: If True, also index files in symlinked folders,
            under paths inside the repository. When *None*, falls back to the
            ``CRG_FOLLOW_SYMLINKS`` env var. Default: off.
    """
def full_build(
    repo_root: Path,
    store: GraphStore,
    recurse_submodules: bool | None = None,
    enrich: bool | None = None,
    follow_symlinks: bool | None = None,
) -> dict;

"""Return *path* relative to *repo_root* when it is absolute and inside it.

    Update inputs are repo-relative, and the ignore rules are anchored to the
    repository root, so an absolute path handed in by a caller would be matched
    against patterns such as ``/tmp/**`` by its filesystem spelling instead of
    its place in the repository. Paths outside the root are returned unchanged
    and are left to stale-file reconciliation.
    """
def _relative_update_input(repo_root: Path, path: str) -> str;

"""Incremental update: re-parse changed + dependent files only.

    *enrich* is as for :func:`full_build`.

    *follow_symlinks* matches :func:`full_build`: when on (or when the graph
    holds files a followed folder brought in), a reconciling update also
    adds files that symlinked folders now reach and drops the ones they no
    longer reach, so it agrees with a full build. ``None`` falls back to
    ``CRG_FOLLOW_SYMLINKS``. *reconcile_followed* does only that part, and
    re-reads only the followed files: the watcher uses it when a link
    changes, a file changes in a followed folder outside the repository, or
    a file is added or removed in a followed folder inside it.

    A path that leaves the repository or goes through a symlink is parsed
    only when it is a file the followed folders reach; any other such path
    is treated as gone.
    """
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

with entry {
    _DEBOUNCE_SECONDS = 1;
}

"""Batch events until a quiet interval passes, then hand them on.

    The algorithm of watchdog 6.0.0's ``EventDebouncer``, with one change:
    the wait for a first event checks for queued events and for a stop
    under the condition lock before it sleeps.  watchdog's waits
    unconditionally, so an event or a stop that arrives between ``start()``
    and that first wait is notified to nobody and then slept on.  The
    observer starts before startup work, so that event can be the only one.
    """
class _WatchDebouncer(threading.Thread) {
    def init(interval: float, callback: Callable[[list[Any]], None]);

    def handle_event(event: Any) -> None;

    """Put a batch that could not be written back, ahead of newer events.

        The run loop then waits out one quiet interval and hands it on again,
        with the condition released, so a stop still gets through meanwhile.
        """
    def requeue(events: list[Any]) -> None;

    """Ask the thread to exit; events still queued are dropped, as in watchdog."""
    def stop -> None;

    def run -> None;
}

"""Fail the watch boundary when an incremental update reports errors."""
def _raise_watch_update_errors(result: dict, context: str) -> None;

"""Treat structured post-processing warnings as a failed watch update.

    One warning is exempt: an explicit embedding refresh that found no index
    to refresh. The graph update itself succeeded and the post-processing step
    has already logged the notice, so the watch keeps running. A refresh that
    fails against an existing index still fails the update.
    """
def _raise_watch_postprocess_warnings(result: object) -> None;

with entry {
    _WATCH_PLAN_DEPTH = env_int("CRG_WATCH_PLAN_DEPTH", 3);
    _MAX_WATCH_SCHEDULES = env_int("CRG_MAX_WATCH_SCHEDULES", 24);
    _WATCH_SPLIT_MIN_DIRS = env_int("CRG_WATCH_SPLIT_MIN_DIRS", 4);
    _WATCH_HEALTH_INTERVAL = env_float("CRG_WATCH_HEALTH_INTERVAL", 10.0);
    _WATCH_STOP_TIMEOUT = 10.0;
    _WATCH_TICK_SECONDS = 1.0;
    _WATCH_LOCK_POLL_SECONDS = 0.25;
    _PROMOTION_RETRY_SECONDS = 30.0;
    _MAX_UNWATCHED_TRACKED = env_int("CRG_MAX_UNWATCHED_TRACKED", 256);
}

"""Return the real (non-symlink) subdirectories of *directory*."""
def _watch_child_dirs(directory: Path, cache: dict[Path, list[Path]] | None = None) -> list[Path];

"""Count the directories inside an ignored tree, stopping at *cap*.

    Used to decide whether excluding the tree is worth a separate watch.  The
    count stops as soon as the cap is reached, so probing ``node_modules`` is
    barely more expensive than probing an empty ``__pycache__``.
    """
def _ignored_tree_weight(directory: Path, cap: int) -> int;

glob split_threshold_default_: any;

with entry {
    split_threshold_default_ = _WATCH_SPLIT_MIN_DIRS;
}

"""Plan the watches covering *directory*.

    Returns ``(clean, plan)``.  ``clean`` means nothing below *directory*
    within *max_depth* is worth excluding, in which case a single recursive
    watch covers it.  Otherwise the directory is watched non-recursively and
    each surviving child is planned in turn, so the ignored subtree is never
    handed to the OS at all.
    """
def _plan_watch_subtree(
    directory: Path,
    repo_root: Path,
    ignore_patterns: list[str],
    depth: int,
    max_depth: int,
    cache: dict[Path, list[Path]],
    split_threshold: int = split_threshold_default_,
) -> tuple[bool, list[tuple[Path, bool]]];

glob max_depth_default__: any;

glob max_schedules_default_: any;

glob split_threshold_default__: any;

with entry {
    max_depth_default__ = _WATCH_PLAN_DEPTH;
    max_schedules_default_ = _MAX_WATCH_SCHEDULES;
    split_threshold_default__ = _WATCH_SPLIT_MIN_DIRS;
}

"""Return the ``(path, recursive)`` watches that cover the repo.

    Deeper plans exclude more ignored trees but cost one watchdog emitter each,
    so an over-budget plan is retried at a shallower depth before falling back
    to the single recursive root watch.
    """
def _plan_watch_paths(
    repo_root: Path,
    ignore_patterns: list[str],
    max_depth: int = max_depth_default__,
    max_schedules: int = max_schedules_default_,
    split_threshold: int = split_threshold_default__,
) -> list[tuple[Path, bool]];

glob max_depth_default___: any;

glob max_schedules_default__: any;

glob split_threshold_default___: any;

with entry {
    max_depth_default___ = _WATCH_PLAN_DEPTH;
    max_schedules_default__ = _MAX_WATCH_SCHEDULES;
    split_threshold_default___ = _WATCH_SPLIT_MIN_DIRS;
}

"""Return the watch plan and whether the budget fallback was required."""
def _plan_watch_paths_with_status(
    repo_root: Path,
    ignore_patterns: list[str],
    max_depth: int = max_depth_default___,
    max_schedules: int = max_schedules_default__,
    split_threshold: int = split_threshold_default___,
) -> tuple[list[tuple[Path, bool]], bool];

"""Run *operation* on a throwaway thread so a wedged watcher cannot hang exit.

    Watchdog's teardown joins its emitter threads, and the whole point of this
    module's health check is that one of those threads may be stuck.  Every
    watchdog thread is a daemon thread, so abandoning the join is safe.
    """
def _run_time_boxed(operation: Callable[[], Any], description: str, timeout: float = 10.0) -> None;

"""Where this watcher publishes its health, or None if that is unavailable."""
def _watch_health_path(repo_root: Path) -> Path | None;

"""Identify a directory by inode, not by name.

    ``rm -rf src && mkdir src`` leaves the path spelled exactly as before while
    the watch on it is dead, so a name is not an identity.  ``st_birthtime``
    joins the tuple where the platform has it (macOS, Windows), which catches
    the recreated directory that happens to reuse an inode.
    """
def _watch_identity(path: str | Path) -> tuple[int, int, float] | None;

"""One scheduled watch: the watchdog handle and the directory it covers."""
class _WatchEntry(NamedTuple) {
    has handle: Any;

    has identity: tuple[int, int, float] | None;
}

glob max_schedules_default___: any;

with entry {
    max_schedules_default___ = _MAX_WATCH_SCHEDULES;
}

"""Owns the observer's watches and reports whether they still work.

    Three jobs, all deliberately cheap:

    * schedule only the directories that survive the ignore patterns, so the OS
      never registers a watch inside an ignored tree;
    * adopt directories created later underneath a non-recursive watch, and
      notice when a watched directory has been replaced by a new one wearing
      the same name;
    * notice a dead watchdog thread and publish watcher health, so a stalled
      watcher stops looking healthy to ``crg-daemon status``.
    """
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

    """True for coarser coverage, a failed promotion, or a refused watch."""
    has degraded: bool {
        getter {
            return self._degraded or self._promotion_failed or `bool(self._unwatched);
        }
    }

    """Directories the OS refused to watch, so they are not covered."""
    has unwatched_paths: list[str] {
        getter {
            return sorted(self._unwatched);
        }
    }

    """Bind the observer that the watches are scheduled on."""
    def attach(observer: Any) -> None;

    """Schedule the planned watches for *handler*."""
    def schedule_initial(handler: Any) -> None;

    def _schedule(path: Path, *, recursive: bool) -> None;

    """Keep one recursive watch on each followed folder outside the repo.

        Events inside such a folder arrive under its real path; the handler
        turns them into an update of the files stored under the link.
        """
    def sync_extra_roots(roots: set[str]) -> None;

    """Reconsider the plan after a directory change seen by watchdog."""
    def request_replan -> None;

    def _remember_ignored_boundaries -> None;

    def _replan_if_requested -> None;

    """Re-attempt the whole watch plan after a total loss of coverage.

        An exhausted OS watch budget is often transient — the build tool that
        consumed it finishes, or the user raises the limit — so a watcher that
        ended up watching nothing tries once more before giving up.  Returns
        True when at least one watch is live afterwards.
        """
    def rewatch_all -> bool;

    """Reconcile the watches under every non-recursive watch.

        Returns ``(adopted, vanished)`` as absolute paths, so the caller can
        index a directory that appeared and reconcile one that disappeared.

        Directory events cannot be used for this.  macOS drops every directory
        event for a child of a non-recursive watch (``FSEventsEmitter.
        _is_recursive_event``), so a brand-new top-level directory — or one
        recreated by ``rm -rf src && mkdir src`` — would never be noticed and
        would stay unindexed forever.  One ``scandir`` per non-recursive watch
        per tick (typically one or two) is nothing next to the thousands of
        kernel watches this planning saves, and it cannot go blind.
        """
    def sync_watches(*, ignore_patterns: list[str] | None = None) -> tuple[list[str], list[str]];

    """Directories newly refused a watch, whose files still need indexing.

        Each is returned once. The watch is retried every tick, and re-reading
        the tree on every retry would pass for live events in watcher health.
        """
    def take_refused_to_index -> list[str];

    """Record a directory the OS refused, newest last, and bound the record."""
    def _note_unwatched(key: str) -> None;

    """Forget refusals for directories that are no longer there.

        A refused directory never enters ``_watches``, so neither a successful
        reschedule nor ``_release_directory`` ever reaches it once it is
        deleted.  Without this the record only grows: ``degraded`` stays true
        for the daemon's whole lifetime over directories that do not exist,
        and ``crg-daemon status`` keeps reporting a gap nobody can close.
        """
    def _prune_unwatched -> None;

    """Watched paths directly underneath *parent*."""
    def _children_of(parent: str) -> list[str];

    """Watched paths anywhere underneath *parent*, at any depth."""
    def _descendants_of(parent: str) -> list[str];

    """Watch a directory that appeared under a non-recursive watch.

        Planned the same way startup plans the repository: a module arriving
        from a branch switch must not hand its ``node_modules`` and ``target``
        straight back to the OS, which is the exposure #811 is about.
        """
    def _adopt_directory(candidate: str, *, required: bool = False) -> bool;

    """The most selective plan for *directory* that fits the budget.

        Mirrors :func:`_plan_watch_paths`: try the deepest split first, then
        shallower ones, then a single recursive watch on the directory itself.
        Only when even one slot is unavailable does the caller fall back to
        promoting the parent.
        """
    def _affordable_plan(directory: Path) -> list[tuple[Path, bool]] | None;

    """Replace the filtered plan only after its recursive watch is live."""
    def _promote_to_recursive(parent: str) -> bool;

    def _release_directory(path: str) -> None;

    """Every thread the observer depends on, with the root it watches.

        The dispatcher, each emitter, and any reader thread an emitter owns
        (inotify keeps its buffer thread there) can die on their own; the
        process survives all three, which is what makes the failure silent.
        """
    def _watchdog_threads -> list[tuple[threading.Thread, str | None]];

    """Return ``(dead_thread_names, repaired_roots)``.

        A thread that stopped is only a death if the watch it belonged to is
        still the live watch for a directory that is still the same directory.
        Three things are deliberately not deaths:

        * a thread not yet started — an emitter caught between construction
          and start is not a corpse;
        * a thread whose watch we have already released, or whose root is gone.
          Both backends stop an emitter when its own root disappears, so a
          plain ``rm -rf lib/`` would otherwise exit the watcher, and the
          daemon would restart it every 30s forever;
        * a thread whose root has been replaced since we scheduled it.
          ``rm -rf src && mkdir src`` inside one tick leaves the name in place
          but kills the watch, and calling that a death both exits the process
          and loses the recreated directory's contents.

        The remaining case — the watch is current, the directory is the same
        one, and its thread died anyway — is repaired once per root by
        rescheduling it, so an inode the filesystem handed straight back does
        not cost a restart.  A second death of the same root is reported, and
        the caller exits: that is #811's crash, and it must stay loud.
        """
    def check_liveness -> tuple[list[str], list[str]];

    """Publish watcher health, rate-limited to one write per interval."""
    def report_health(
        *,
        observer_alive: bool,
        last_event_at: float | None = None,
        events_seen: int = 0,
        dead_threads: tuple[str, ...] = (),
        phase: str = "watching",
        force: bool = False,
    ) -> None;

    """Remove the health file on a clean shutdown."""
    def clear_health -> None;

    def __repr__ -> str;

    def __eq__(other: any) -> bool;

    def __hash__ -> int;
}

"""A ``.csproj`` decides C# project ownership, so it rebinds calls (#964)."""
def _is_csharp_project(relative_path: str) -> bool;

"""True when every path *event* names is *target*, however it is spelled."""
def _event_only_touches(event: Any, target: Path) -> bool;

"""Return whether a symlink that is not ignored sits below *directory*."""
def _holds_symlink(directory: Path, relative: str, ignore_patterns: list[str]) -> bool;

"""Create the debounced watchdog handler for one repository."""
def _create_watch_handler(
    repo_root: Path,
    store: GraphStore,
    on_files_updated: Optional[Callable],
    on_directory_changed: Optional[Callable[[], None]] = None,
    follow_symlinks: bool | None = None,
) -> any;

"""Reconcile watches, then bring the graph in line with what changed.

    A directory adopted this tick may already hold files, and one that
    vanished may still have nodes in the graph — on macOS neither produces a
    single event, so the sync has to do the bookkeeping itself.  The work goes
    through the debouncer, exactly as a real event would, so indexing a large
    new directory never blocks the loop that publishes the heartbeat.
    """
def _sync_watch_tree(supervisor: _WatchSupervisor, handler: Any) -> None;

"""Take the write lock for startup, waiting out whoever holds it.

    A watcher started during a build has work to do once the build ends, so it
    waits rather than stands down, and the daemon does not see it die. It polls:
    a blocking lock could not notice *stop_event* and would hold up an MCP
    server's shutdown, and the heartbeat has to keep going or a healthy watcher
    reads as stalled. Returns False if told to stop first.
    """
def _wait_for_watch_write_lock(
    lock: WriteLock, supervisor: _WatchSupervisor, stop_event: threading.Event | None
) -> bool;

"""Make SIGTERM unwind like Ctrl+C, and return an undo callable.

    ``crg-daemon stop`` terminates its children, so without this the watcher
    dies at 143 and leaves its health file behind, which then reads as a
    stalled watcher forever.  Only the main thread may install handlers.
    """
def _install_sigterm_interrupt -> Callable[[], None];

"""Watch for file changes and auto-update the graph.

    Uses a one-second debounce to batch rapid-fire saves into a single update.

    Ignored trees are never handed to the OS watcher, and every tick checks
    that watchdog's own threads are still running: a dead one raises, so the
    process exits non-zero and the daemon restarts it instead of the graph
    going quietly stale.  See: #811.

    Args:
        repo_root: Repository root to watch.
        store: Graph database to update.
        on_files_updated: Optional callback invoked after each debounced
            batch of file updates completes.  Receives the store as its
            only argument.  Used by the CLI and MCP auto-watch to run post-processing
            (FTS, flows, communities) after watch updates.
        stop_event: Optional event that ends the loop cleanly, for callers
            that run ``watch`` on a thread they need to shut down.
        follow_symlinks: Follow symlinked folders inside the repository, as
            :func:`full_build` does. When *None*, falls back to the
            ``CRG_FOLLOW_SYMLINKS`` env var. Default: off.

    Raises:
        RuntimeError: if a watch update fails, or if the filesystem observer
            stops running.
    """
def watch(
    repo_root: Path,
    store: GraphStore,
    on_files_updated: Optional[Callable] = None,
    stop_event: threading.Event | None = None,
    follow_symlinks: bool | None = None,
) -> None;

"""Start watch mode in a background thread.

    ``on_files_updated`` is forwarded to ``watch`` for post-processing
    after changed batches, including startup reconciliation.

    Returns the started thread, or None if watchdog is unavailable. Set
    *stop_event* and join the returned thread before closing its store.
    """
def start_watch_thread(
    repo_root: Path,
    store: GraphStore,
    daemon: bool = True,
    *,
    on_files_updated: Optional[Callable] = None,
    stop_event: threading.Event | None = None,
) -> threading.Thread | None;
