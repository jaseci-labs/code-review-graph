import from __future__ { annotations }

import builtins;

import operator;

import logging;

import os;

import re;

import subprocess;

import threading;

import from collections { Counter }

import from dataclasses { dataclass, field, replace }

import from pathlib { Path }

import from typing { Any }

glob logger: any;

glob _OVERALL_RISK_LINE: any;

glob _TEST_GAP_EXEMPT_NAMES: any;

glob _MIGRATION_METHOD_NAMES: any;

glob _MIGRATION_DIRS: any;

glob _SAFE_GIT_REF: any;

glob _SAFE_SVN_REV: any;

glob _LS_FILES_CHUNK: any;

glob _C_QUOTE_ESCAPES: any;

glob _POST_IMAGE_HEADER: any;

glob _PRE_IMAGE_HEADER: any;

glob _HUNK_HEADER: any;

glob _CHURN_SATURATION: any;

glob _CHURN_WEIGHT: any;

glob _NUMSTAT_COUNT: any;

glob _CHURN_TIMEOUT: any;

glob _CHURN_MAX_COMMITS: any;

glob _CHURN_CACHE_MAX_ENTRIES: any;

glob _CHURN_CACHE_LOCK: any;

glob _CHURN_CACHE: dict[tuple[str, str, int], dict[str, int]];

glob _CHURN_UNAVAILABLE: any;

glob CHURN_OK: any;

glob CHURN_UNAVAILABLE: any;

glob CHURN_OFF: any;

glob _CODE_KINDS: any;

glob _MAX_DELETION_FILES: any;

glob _MAX_REMOVED_SYMBOLS: any;

glob _MAX_REMOVED_USERS_SHOWN: any;

glob _SELF_RECEIVERS: any;

glob BRIEF_PRIORITIES: any;

with entry {
    logger = logging.getLogger(__name__);
    _OVERALL_RISK_LINE = "  - Overall risk score: {:.2f}";
    _TEST_GAP_EXEMPT_NAMES = frozenset({
        "setUp",
        "tearDown",
        "setUpBeforeClass",
        "tearDownAfterClass",
        "setup_method",
        "teardown_method",
        "setUpClass",
        "tearDownClass",
        "__construct",
        "__init__",
        "__destruct",
    });
    _MIGRATION_METHOD_NAMES = frozenset({"up", "down"});
    _MIGRATION_DIRS = frozenset({"migrations", "migrate"});
}

def _is_migration_file(file_path: str, repo_root: str | Path | None) -> bool;
def is_test_gap_exempt(`node: GraphNode, repo_root: str | Path | None = None) -> bool;
def _is_test_lifecycle(`node: GraphNode, store: GraphStore) -> bool;

with entry {
    _SAFE_GIT_REF = re.compile("^[A-Za-z0-9_.~^/@{}\\-]+$");
    _SAFE_SVN_REV = re.compile("^r?\\d+(:r?\\d+|:HEAD|:BASE|:COMMITTED)?$", re.IGNORECASE);
}

def _vcs_unavailable(tool: str, exc: BaseException) -> ChangeDiscoveryError;
def parse_git_diff_ranges(
    repo_root: str, base: str = "HEAD~1", *, require_vcs: bool = False
) -> dict[str, list[tuple[int, int]]];

with entry {
    _LS_FILES_CHUNK = 200;
}

def _untracked_among(repo_root: str, rel_paths: list[str]) -> set[str];
def _new_files_without_ranges(
    repo_root: str, changed_files: list[str], changed_ranges: dict[str, list[tuple[int, int]]]
) -> list[str];
def parse_svn_diff_ranges(
    repo_root: str, rev_range: str | None = None, *, require_vcs: bool = False
) -> dict[str, list[tuple[int, int]]];
def parse_diff_ranges(
    repo_root: str, base: str = "HEAD~1", *, require_vcs: bool = False
) -> dict[str, list[tuple[int, int]]];

with entry {
    _C_QUOTE_ESCAPES = {
        "a": "\x07",
        "b": "\x08",
        "f": "\x0c",
        "n": "\n",
        "r": "\r",
        "t": "\t",
        "v": "\x0b",
        "\\": "\\",
        "\"": "\"",
    };
}

def _unquote_c_path(quoted: str) -> str;
def _diff_header_path(rest: str, prefix: str = "b/") -> str | None;

with entry {
    _POST_IMAGE_HEADER = re.compile("^\\+\\+\\+ (/dev/null|\"b/(?:[^\"\\\\]|\\\\.)*\"|b/.*)$");
    _PRE_IMAGE_HEADER = re.compile("^--- (/dev/null|\"a/(?:[^\"\\\\]|\\\\.)*\"|a/.*)$");
    _HUNK_HEADER = re.compile("^@@ -(\\d+)(?:,(\\d+))? \\+(\\d+)(?:,(\\d+))? @@");
}

@dataclass(frozen=True)
class PureDeletion {
    has old_start: int;

    has old_end: int;

    has anchor: int;
}

@dataclass
class FileDeletions {
    has old_path: str;

    has hunks: list[PureDeletion] = field(default_factory=list[any]);
}

class DiffRanges(builtins.dict) {
    def init(
        ranges: dict[str, list[tuple[int, int]]] | None = None,
        deletions: dict[str, FileDeletions] | None = None,
    );
    def edit_ranges -> dict[str, list[tuple[int, int]]];
    def remapped(`root: str | Path) -> DiffRanges;
}

def _parse_unified_diff(diff_text: str) -> DiffRanges;

with entry {
    _CHURN_SATURATION = 10.0;
    _CHURN_WEIGHT = 0.15;
    _NUMSTAT_COUNT = re.compile("^(?:\\d+|-)$");
    _CHURN_TIMEOUT = env_float("CRG_CHURN_TIMEOUT", 5.0);
    _CHURN_MAX_COMMITS = env_int("CRG_CHURN_MAX_COMMITS", 2000);
    _CHURN_CACHE_MAX_ENTRIES = 32;
    _CHURN_CACHE_LOCK = threading.Lock();
    _CHURN_CACHE = {};
    _CHURN_UNAVAILABLE = set[any]();
    CHURN_OK = "ok";
    CHURN_UNAVAILABLE = "unavailable";
    CHURN_OFF = "off";
}

def clear_churn_cache;

def _churn_is_unavailable(fail_key: tuple[str, int]) -> bool;

def _mark_churn_unavailable(fail_key: tuple[str, int]);
def _churn_cache_key(repo_root: str, window_days: int) -> tuple[str, str, int] | None;
def _parse_numstat(log_text: str) -> dict[str, int];
def compute_file_churn(repo_root: str, window_days: int | None = None) -> dict[str, int];
def compute_file_churn_with_status(
    repo_root: str, window_days: int | None = None
) -> tuple[dict[str, int], str];
def map_changes_to_nodes(
    store: GraphStore, changed_ranges: dict[str, list[tuple[int, int]]]
) -> list[GraphNode];

with entry {
    _CODE_KINDS = ("Function", "Test", "Class");
    _MAX_DELETION_FILES = env_int("CRG_MAX_DELETION_FILES", 100);
    _MAX_REMOVED_SYMBOLS = 200;
    _MAX_REMOVED_USERS_SHOWN = 3;
    _SELF_RECEIVERS = frozenset({"self", "this", "cls"});
}

@dataclass
class _DeletionReview {
    has changed: list[GraphNode] = field(default_factory=list[any]);

    has removed: list[dict[str, Any]] = field(default_factory=list[any]);

    has removed_total: int = 0;

    has files_not_read: int = 0;
}

def _nodes_in_file(store: GraphStore, file_path: str) -> list[GraphNode];

@dataclass
class _OldSide {
    has nodes: list[tuple[str, NodeInfo]];

    has calls: dict[str, list[str]];
}

def _old_side_nodes(
    parser: CodeParser, repo_root: str, base: str, old_path: str, parse_path: str
) -> _OldSide | None;
def _bare_call_reaches(`edge: GraphEdge, removed: GraphNode) -> bool;

@dataclass
class _RemovedUsers {
    has users: list[dict[str, Any]];

    has call_sources: list[str];

    has caller_ids: set[int];
}

def _as_graph_node(qualified_name: str, info: NodeInfo) -> GraphNode;
def _removed_symbol_users(store: GraphStore, removed: GraphNode) -> _RemovedUsers;

@dataclass
class _RemovedSymbol {
    has `node: GraphNode;

    has old_calls: list[str];

    has file_community: int | None;

    has found: _RemovedUsers = field(
        default_factory=lambda -> any {
            _RemovedUsers(users=[], call_sources=[], caller_ids=set[any]())
        },
    );
}

def _removed_flow_criticalities(
    store: GraphStore, removed: list[_RemovedSymbol]
) -> dict[str, list[float]];
def _score_removed(
    store: GraphStore, removed: list[_RemovedSymbol], churn_counts: dict[str, int] | None
) -> dict[str, float];
def _file_community(store: GraphStore, nodes: list[GraphNode]) -> int | None;
def _review_pure_deletions(
    store: GraphStore,
    deletions: dict[str, FileDeletions],
    repo_root: str | None,
    base: str,
    churn_counts: dict[str, int] | None = None,
) -> _DeletionReview;
def _removed_summary_lines(review: _DeletionReview) -> list[str];
def _symbol_part(qualified_name: str) -> str;
def compute_risk_score(
    store: GraphStore, `node: GraphNode, churn_counts: dict[str, int] | None = None
) -> float;
def risk_signals(
    store: GraphStore, `node: GraphNode, churn_counts: dict[str, int] | None = None
) -> dict[str, dict[str, float]];
def _cross_community(
    store: GraphStore, caller_qns: list[str], node_cid: int | None, *, own_group: bool = False
) -> int;
def _sum_signals(signals: dict[str, dict[str, float]]) -> float;
def _score_risk(
    store: GraphStore,
    `node: GraphNode,
    churn_counts: dict[str, int] | None,
    *,
    flow_criticalities: list[float],
    flow_count: int,
    caller_qns: list[str],
    cross_community: int,
) -> float;
def _risk_signals_from(
    store: GraphStore,
    `node: GraphNode,
    churn_counts: dict[str, int] | None,
    *,
    flow_criticalities: list[float],
    flow_count: int,
    caller_qns: list[str],
    cross_community: int,
) -> dict[str, dict[str, float]];
def review_churn_counts(repo_root: str | None, include_churn: bool) -> tuple[dict[str, int]
    | None, str];
def analyze_changes(
    store: GraphStore,
    changed_files: list[str],
    changed_ranges: dict[str, list[tuple[int, int]]] | None = None,
    repo_root: str | None = None,
    base: str = "HEAD~1",
    include_churn: bool = False,
    require_vcs: bool = False,
) -> dict[str, Any];

with entry {
    BRIEF_PRIORITIES = 3;
}

def risk_label(score: float) -> str;
def _short_name(qualified_name: str) -> str;
def _name_list(names: list[str], limit: int = 2) -> str;
def _brief_priority_line(store: GraphStore, priority: dict[str, Any], repo_root: str | None) -> str;

glob limit_default_: any;

with entry {
    limit_default_ = BRIEF_PRIORITIES;
}

def format_brief(
    store: GraphStore,
    analysis: dict[str, Any],
    repo_root: str | Path | None = None,
    limit: int = limit_default_,
) -> str;
