import from __future__ { annotations }

import importlib, operator, logging, sqlite3, time;

import from pathlib { Path }

import from typing { Any }

glob logger: any = logging.getLogger(__name__);

glob _PARTIAL_GRAPH_MIN_FILES: any = 8;

glob _PARTIAL_GRAPH_MAX_COVERAGE: any = 0.25;

glob _PARTIAL_GRAPH_SUSPECT_TRACKED_COVERAGE: any = 0.5;

def _should_rebuild_partial_graph(
    repo_root: Path, store: Any, recurse_submodules: bool | None = None
) -> bool;
def build_was_interrupted(store: Any) -> bool;
def _run_embedding_refresh(
    store: Any,
    result: dict[str, Any],
    warnings: list[str],
    *,
    provider: str | None,
    model: str | None,
);
def _report_refresh_skipped(result: dict[str, Any], warnings: list[str]);

glob _CONTENTION_ERRORCODES: any = frozenset({5, 6});

glob _CONTENTION_MESSAGES: any = (
    "database is locked",
    "database table is locked",
    "database schema is locked",
);

def is_lock_contention(exc: BaseException) -> bool;
def _note_contention(build_result: dict[str, Any], exc: BaseException);
def _fts_file_hint(repo_root: str | None, changed_files: list[str] | None) -> list[str] | None;
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
def _lock_or_skip(
    db_path: Path, wait_for_lock: bool, outcome: str = "skipped instead of repeating the work"
) -> tuple[WriteLock | None, dict[str, Any] | None];
def _write_skipped_response(
    db_path: Path, holder_pid: int | None, outcome: str = "skipped instead of repeating the work"
) -> dict[str, Any];
def run_postprocess(
    flows: bool = True,
    communities: bool = True,
    fts: bool = True,
    repo_root: str | None = None,
    embedding_provider: str | None = None,
    embedding_model: str | None = None,
    wait_for_lock: bool = False,
) -> dict[str, Any];
