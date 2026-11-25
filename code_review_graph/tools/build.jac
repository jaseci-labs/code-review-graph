"""Tool 1: build_or_update_graph + run_postprocess."""

import operator;

import from __future__ { annotations }

import logging;

import sqlite3;

import time;

import from pathlib { Path }

import from typing { Any }

glob logger: any;

glob _PARTIAL_GRAPH_MIN_FILES: any;

glob _PARTIAL_GRAPH_MAX_COVERAGE: any;

glob _PARTIAL_GRAPH_SUSPECT_TRACKED_COVERAGE: any;

glob _CONTENTION_ERRORCODES: any;

glob _CONTENTION_MESSAGES: any;

with entry {
    logger = logging.getLogger(__name__);

    _PARTIAL_GRAPH_MIN_FILES = 8;
    _PARTIAL_GRAPH_MAX_COVERAGE = 0.25;
    _PARTIAL_GRAPH_SUSPECT_TRACKED_COVERAGE = 0.5;
}

"""Detect a non-empty graph that represents only a small slice of a repo."""
def _should_rebuild_partial_graph(
    repo_root: Path, store: Any, recurse_submodules: bool | None = None
) -> bool;

"""True when the last build left source or derived data incomplete."""
def build_was_interrupted(store: Any) -> bool;

"""Run a provider-scoped embedding refresh only when explicitly requested."""
def _run_embedding_refresh(
    store: Any,
    result: dict[str, Any],
    warnings: list[str],
    *,
    provider: str | None,
    model: str | None,
) -> None;

"""Tell a caller who asked for a refresh that the graph has no index to refresh."""
def _report_refresh_skipped(result: dict[str, Any], warnings: list[str]) -> None;

with entry {
    _CONTENTION_ERRORCODES = frozenset({5, 6});
    _CONTENTION_MESSAGES = (
        "database is locked",
        "database table is locked",
        "database schema is locked",
    );
}

"""True only for SQLite refusing a write because another process holds it.

    Every other ``sqlite3.OperationalError`` — a malformed statement, a disk
    I/O error, a read-only database file — is a genuine failure that the next
    run will hit again in exactly the same way.  The distinction is not
    cosmetic: contention deliberately leaves the ``build_state`` marker set so
    the next run redoes the lost stage, so classifying a permanent error as
    contention marks the graph incomplete forever and promotes every later
    update to a full rebuild that cannot clear it.
    """
def is_lock_contention(exc: BaseException) -> bool;

"""Classify a post-processing stage that failed.

    Contention is transient: another process held the SQLite write lock, and
    the next run can redo the stage, so the build-state marker stays set.  A
    genuine SQLite error is recorded separately — it downgrades the build to
    ``partial`` instead of being retried forever.  Anything else (a missing
    optional dependency, say) is left to the warning list alone: one absent
    extra must not pin the repository into permanent full rebuilds.
    """
def _note_contention(build_result: dict[str, Any], exc: BaseException) -> None;

"""Spell *changed_files* the way ``nodes.file_path`` stores them.

    Change discovery reports repository-relative paths while the graph keys
    nodes by their normalised absolute path. A hint that matches nothing is
    harmless (the delta still repairs every added and removed row) but it
    buys nothing either, so resolve it whenever the root is known.
    """
def _fts_file_hint(repo_root: str | None, changed_files: list[str] | None) -> list[str] | None;

"""Run post-build steps based on *postprocess* level.

    When *full_rebuild* is False and *changed_files* are available,
    uses incremental flow/community detection for faster updates.

    *skip_resolvers* leaves call-target resolution out, for a no-op update on a
    graph whose edges are already resolved.

    Records structured stage durations in ``build_result["postprocess_timing"]``.
    Minimal processing reports ``signatures_s`` and ``fts_s``; full processing
    additionally reports ``flows_s`` and ``communities_s``.
    Each duration is a nonnegative float measured in seconds.

    Returns a list of warning strings (empty on success).
    """
def _run_postprocess(
    store: Any,
    build_result: dict[str, Any],
    postprocess: str,
    full_rebuild: bool = False,
    changed_files: list[str] | None = None,
    repo_root: str | None = None,
    embedding_provider: str | None = None,
    embedding_model: str | None = None,
    entry_point_qns: list[str] | None = None,
    communities_were_affected: bool = False,
    skip_resolvers: bool = False,
) -> list[str];

"""Build or incrementally update the code knowledge graph.

    Only one build runs per repository at a time. A second call that arrives
    while the first is still parsing reports ``status: contended`` and returns
    without touching the graph rather than repeating the same work: ``build``
    and ``update`` are fired from commit hooks, save hooks and the watcher,
    which can overlap by seconds, and each duplicate used to pay for a full
    parse plus its own process pool before failing on the SQLite write lock.
    Pass ``wait_for_lock=True`` (CLI: ``--wait``) to block instead of skipping.

    Args:
        full_rebuild: If True, re-parse every file. If False (default),
                      only re-parse files changed since ``base``.
        repo_root: Path to the repository root. Auto-detected if omitted.
        base: Git ref for the incremental diff. When None (default), the base
              is resolved automatically to the commit the graph was last built
              at, so a single update reconciles everything since the last sync
              rather than only the most recent commit. Pass an explicit ref to
              override. Ignored when full_rebuild is True.
        postprocess: Post-processing level after build:
            ``"full"`` (default) — signatures, FTS, flows, communities.
            ``"minimal"`` — signatures + FTS only (fast, keeps search working).
            ``"none"`` — skip all post-processing (raw parse only).
        recurse_submodules: If True, include files from git submodules
            via ``git ls-files --recurse-submodules``. When None
            (default), falls back to the CRG_RECURSE_SUBMODULES
            environment variable. Default: disabled.
        embedding_provider: Exact provider to use for an explicitly requested
            post-build refresh. Must be supplied together with
            ``embedding_model``; omitted by default so builds never transmit
            source-derived text or load an embedding model unexpectedly.
        embedding_model: Exact model for an explicitly requested post-build
            embedding refresh. Must be supplied with ``embedding_provider``.
        wait_for_lock: Block until an in-flight build for this repository
            finishes, instead of skipping. Default: False, because the
            skipping caller is usually a hook whose work the in-flight build
            already covers; a human running ``build``/``update`` by hand
            usually wants the wait.

        recover_corrupt: Discard an unusable graph before an explicit full rebuild.
            Used by the CLI build command; ignored for incremental updates.
        enrich: Also resolve Python method calls with Jedi (the
            ``enrichment`` extra; CLI: ``--enrich``). When None (default),
            falls back to ``CRG_ENABLE_ENRICHMENT``. Off by default because
            it costs about a second per Python file.
        follow_symlinks: If True, also index files in symlinked folders that
            point inside the repository (never outside it). When None
            (default), falls back to the CRG_FOLLOW_SYMLINKS environment
            variable. Default: disabled.

    Returns:
        Summary with files_parsed/updated, node/edge counts, and errors. A run
        that stood down because another build held the lock returns
        ``status: contended``, ``skipped: True`` and ``holder_pid``.
    """
def build_or_update_graph(
    full_rebuild: bool = False,
    repo_root: str | None = None,
    base: str | None = None,
    postprocess: str = "full",
    recurse_submodules: bool | None = None,
    embedding_provider: str | None = None,
    embedding_model: str | None = None,
    wait_for_lock: bool = False,
    recover_corrupt: bool = False,
    enrich: bool | None = None,
    follow_symlinks: bool | None = None,
) -> dict[str, Any];

"""Take the graph's write lock, or build the response for standing down.

    Returns the held lock and ``None``, or ``None`` and the response to return.
    Every graph-writing entry point shares this so none can drift from the
    others. *outcome* says what standing down means for the caller.
    """
def _lock_or_skip(
    db_path: Path, wait_for_lock: bool, outcome: str = "skipped instead of repeating the work"
) -> tuple[WriteLock | None, dict[str, Any] | None];

"""Describe a run that stood down because another writer owns the graph.

    ``contended`` rather than ``error``: nothing failed, and a caller switching
    on the existing statuses would otherwise have no way to tell a lost race
    from a broken database. The counts are present and zero so callers that
    unpack them keep working.

    A second build really does repeat the first, but ``forget`` and ``embed``
    are not covered by whatever else is running, so they pass their own
    *outcome* rather than tell the reader the work is in hand.
    """
def _write_skipped_response(
    db_path: Path, holder_pid: int | None, outcome: str = "skipped instead of repeating the work"
) -> dict[str, Any];

"""Run post-processing steps on an existing graph.

    Useful for running expensive steps (flows, communities) separately
    from the build, or for re-running after the graph has been updated
    with ``postprocess="none"``.

    Takes the same per-repository write lock as ``build`` and ``update``: this
    rewrites derived data (flows, communities, FTS) for a graph another process
    may be half way through writing, which is the failure #1073 reports.

    Args:
        flows: Run flow detection. Default: True.
        communities: Run community detection. Default: True.
        fts: Rebuild FTS index. Default: True.
        repo_root: Repository root path. Auto-detected if omitted.
        embedding_provider: Exact provider for an explicit refresh. Must be
            supplied with ``embedding_model``. Default: disabled.
        embedding_model: Exact model for an explicit refresh. Must be supplied
            with ``embedding_provider``. Default: disabled.
        wait_for_lock: Block until an in-flight write for this repository
            finishes, instead of skipping. Default: False.

    Returns:
        Summary of what was computed, or ``status: contended`` when another
        writer held the lock.
    """
def run_postprocess(
    flows: bool = True,
    communities: bool = True,
    fts: bool = True,
    repo_root: str | None = None,
    embedding_provider: str | None = None,
    embedding_model: str | None = None,
    wait_for_lock: bool = False,
) -> dict[str, Any];
