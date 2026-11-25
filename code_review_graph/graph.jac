import from __future__ { annotations }

import importlib;

import builtins;

import operator;

import hashlib;

import json;

import logging;

import re;

import sqlite3;

import threading;

import time;

import from collections.abc { Iterable, Iterator }

import from contextlib { contextmanager }

import from dataclasses { dataclass }

import from pathlib { Path, PurePosixPath, PureWindowsPath }

import from typing { TYPE_CHECKING, Any, Optional }

glob logger: any;

glob _UPDATE_BATCH: any;

glob _JAVASCRIPT_LANGUAGE_FAMILY: any;

glob _JAVASCRIPT_LANGUAGE_FAMILY_SET: any;

glob _COLLISION_SUFFIX_RE: any;

glob _COLLISION_IDENTITY_RE: any;

glob _COLLISION_ENDPOINT_KEY: any;

glob _COLLISION_AMBIGUOUS_TIER: any;

glob _COLLISION_AMBIGUOUS_SCORE: any;

glob _COLLISION_CALL_KINDS: any;

glob _COLLISION_CANDIDATE_LIMIT: any;

glob _AMBIGUITY_KEYS: any;

glob _ORDERED_PAIRS_MAX_STEPS: any;

glob MAX_INDEXED_DOCSTRING_CHARS: any;

glob MAX_INDEXED_TOKEN_CHARS: any;

glob _ALNUM_RUN_RE: any;

glob _CAMEL_BOUNDARY_RE: any;

glob _SCHEMA_SQL: any;

glob RESOLUTION_ALL: any;

glob RESOLUTION_DIRECT: any;

glob RESOLUTION_UNRESOLVED: any;

glob QUERY_RESOLUTIONS: any;

glob IMPACT_RESOLUTIONS: any;

glob IMPORT_SCOPE_MAX_ANCESTORS: any;

glob TIER_EXTRACTED: any;

glob TIER_INFERRED: any;

glob TIER_AMBIGUOUS: any;

glob TIER_UNRESOLVED: any;

glob _SCORE_EXTRACTED: any;

glob _SCORE_INFERRED: any;

glob _SCORE_AMBIGUOUS: any;

glob _SCORE_UNRESOLVED: any;

glob _RESOLVER_BOUND_KEYS: any;

glob _SELF_RECEIVERS: any;

glob _SUPER_RECEIVERS: any;

glob _TYPED_RECEIVER_LANGUAGES: any;

glob _UNTYPED_RECEIVER_LANGUAGES: any;

glob _NODE_ENDPOINTS: any;

glob _SYMBOL_SEPARATOR_RE: any;

glob _CERTAINTY_SCORE_SQL: any;

glob IMPACT_FRONTIER_DIRS_SQL: any;

glob _IMPACT_AOP_EXTRA_LIKE: any;

glob _IMPACT_AOP_DIRECTION_CASE: any;

glob _RECOVERY_HINT: any;

glob _SQLITE_HEADER: any;

glob _CORRUPTION_MESSAGES: any;

glob _INCOMPATIBLE_SCHEMA_MESSAGES: any;

glob _NAME_CONTROL_CHARS: any;

with entry {
    logger = logging.getLogger(__name__);
    _UPDATE_BATCH = 50000;
    _JAVASCRIPT_LANGUAGE_FAMILY = ("javascript", "typescript", "tsx", "html");
    _JAVASCRIPT_LANGUAGE_FAMILY_SET = frozenset(_JAVASCRIPT_LANGUAGE_FAMILY);
    _COLLISION_SUFFIX_RE = re.compile("^[0-9a-f]{12}(?::(?:[2-9]|[1-9][0-9]+))?$");
    _COLLISION_IDENTITY_RE = re.compile("^(?P<base>.+):S[0-9a-f]{12}(?::(?:[2-9]|[1-9][0-9]+))?$");
    _COLLISION_ENDPOINT_KEY = "collision_endpoint";
    _COLLISION_AMBIGUOUS_TIER = "AMBIGUOUS";
    _COLLISION_AMBIGUOUS_SCORE = 0.4;
    _COLLISION_CALL_KINDS = ("CALLS", "REFERENCES");
    _COLLISION_CANDIDATE_LIMIT = 20;
    _AMBIGUITY_KEYS = (
        "ambiguous_targets",
        "ambiguous_target_count",
        "ambiguous_targets_truncated",
        "unresolved_targets",
        "unresolved_target_count",
        "unresolved_targets_truncated",
    );
}

def _load_collision_extra(raw: Optional[str]) -> dict;
def _plain_collision_name(qualified: str) -> str;
def _ambiguous_collision_extra(extra: dict, base: str, candidates: list[str]) -> dict;
def _bound_collision_extra(extra: dict) -> dict;

with entry {
    _ORDERED_PAIRS_MAX_STEPS = 1000000;
}

def _ordered_pairs(new_lines: list[int], old_lines: list[int]) -> list[tuple[int, int]];
def _compatible_edge_languages(language: str) -> tuple[str, ...];
def _symbol_of(qualified_name: str) -> str;

with entry {
    MAX_INDEXED_DOCSTRING_CHARS = 400;
    MAX_INDEXED_TOKEN_CHARS = 200;

    _ALNUM_RUN_RE = re.compile("[0-9A-Za-z]+");
    _CAMEL_BOUNDARY_RE = re.compile("(?<=[a-z0-9])(?=[A-Z])|(?<=[A-Z])(?=[A-Z][a-z])");
}

def _index_tokens(*values_: str | None) -> str;
def identifier_words(text: str) -> set[str];
def node_index_tokens(kind: str, name: str, parent_name: str | None, file_path: str | None) -> str;
def _indexed_docstring(extra: dict[str, Any] | None) -> str | None;
def qualified_name_of(`node: NodeInfo) -> str;
def _bridge_qualified_name(qualified_name: str) -> str;

with entry {
    _SCHEMA_SQL = "\nCREATE TABLE IF NOT EXISTS nodes (\n    id INTEGER PRIMARY KEY AUTOINCREMENT,\n    kind TEXT NOT NULL,          -- File, Class, Function, Type, Test\n    name TEXT NOT NULL,\n    qualified_name TEXT NOT NULL UNIQUE,\n    file_path TEXT NOT NULL,\n    line_start INTEGER,\n    line_end INTEGER,\n    language TEXT,\n    parent_name TEXT,\n    params TEXT,\n    return_type TEXT,\n    modifiers TEXT,\n    is_test INTEGER DEFAULT 0,\n    file_hash TEXT,\n    extra TEXT DEFAULT '{}',\n    -- Symbol portion of qualified_name (everything after the first \"::\").\n    -- Stored so a dotted-tail lookup is an indexed equality test instead of a\n    -- substr() scan over every node; see search_nodes_by_qualified_tail.\n    -- idx_nodes_symbol is created by migration v10, not here: _init_schema runs\n    -- before run_migrations, so indexing a column this CREATE TABLE cannot add\n    -- to an existing table would break every pre-existing database on open.\n    symbol TEXT,\n    -- Documentation summary lifted out of extra['docstring'] so the FTS5\n    -- external-content index can reach it (FTS columns must be real columns\n    -- of the content table). See migration v11.\n    docstring TEXT,\n    -- camelCase/PascalCase word splits for name, parent_name and the file\n    -- stem. unicode61 splits on punctuation but keeps hashPassword as one\n    -- token, so \"password\" could never match it. Added by migration v11.\n    name_tokens TEXT,\n    updated_at REAL NOT NULL\n);\n\nCREATE TABLE IF NOT EXISTS edges (\n    id INTEGER PRIMARY KEY AUTOINCREMENT,\n    kind TEXT NOT NULL,           -- CALLS, IMPORTS_FROM, INHERITS, REFERENCES, etc.\n    source_qualified TEXT NOT NULL,\n    target_qualified TEXT NOT NULL,\n    file_path TEXT NOT NULL,\n    line INTEGER DEFAULT 0,\n    extra TEXT DEFAULT '{}',\n    confidence REAL DEFAULT 1.0,\n    confidence_tier TEXT DEFAULT 'EXTRACTED',\n    -- 'direct' when target_qualified names an indexed node, 'unresolved' when\n    -- it is a bare name the read path can only match by name. NULL for edge\n    -- kinds where the distinction is meaningless (an IMPORTS_FROM target is a\n    -- file path, not a call target) and for rows written since the last\n    -- refresh_target_resolution() pass. Same rule as nodes.symbol above:\n    -- idx_edges_kind_target_resolution is created by migration v11, not here.\n    target_resolution TEXT,\n    updated_at REAL NOT NULL\n);\n\nCREATE TABLE IF NOT EXISTS metadata (\n    key TEXT PRIMARY KEY,\n    value TEXT NOT NULL\n);\n\nCREATE INDEX IF NOT EXISTS idx_nodes_file ON nodes(file_path);\nCREATE INDEX IF NOT EXISTS idx_nodes_kind ON nodes(kind);\nCREATE INDEX IF NOT EXISTS idx_nodes_name ON nodes(name);\nCREATE INDEX IF NOT EXISTS idx_edges_kind ON edges(kind);\nCREATE INDEX IF NOT EXISTS idx_edges_target_kind ON edges(target_qualified, kind);\nCREATE INDEX IF NOT EXISTS idx_edges_source_kind ON edges(source_qualified, kind);\nCREATE INDEX IF NOT EXISTS idx_edges_file ON edges(file_path);\n";
    RESOLUTION_ALL = "all";
    RESOLUTION_DIRECT = "direct";
    RESOLUTION_UNRESOLVED = "unresolved";
    QUERY_RESOLUTIONS = (RESOLUTION_ALL, RESOLUTION_DIRECT, RESOLUTION_UNRESOLVED);
    IMPACT_RESOLUTIONS = (RESOLUTION_ALL, RESOLUTION_DIRECT);
}

def _impact_resolution_guard(resolution: str) -> str;

@dataclass
class GraphNode {
    has id: int;

    has kind: str;

    has name: str;

    has qualified_name: str;

    has file_path: str;

    has line_start: int;

    has line_end: int;

    has language: str;

    has parent_name: Optional[str];

    has params: Optional[str];

    has return_type: Optional[str];

    has is_test: bool;

    has file_hash: Optional[str];

    has extra: dict;
}

@dataclass
class GraphEdge {
    has id: int;

    has kind: str;

    has source_qualified: str;

    has target_qualified: str;

    has file_path: str;

    has line: int;

    has extra: dict;

    has confidence: float = 1.0;

    has confidence_tier: str = "EXTRACTED";

    has target_resolution: Optional[str] = None;
}

@dataclass
class FlowAdjacency {
    has calls_out: dict[str, list[str]];

    has has_tested_by: set[str];

    has nodes_by_qn: dict[str, "GraphNode"];

    has nodes_by_id: dict[int, "GraphNode"];
}

@dataclass
class GraphStats {
    has total_nodes: int;

    has total_edges: int;

    has nodes_by_kind: dict[str, int];

    has edges_by_kind: dict[str, int];

    has languages: list[str];

    has files_count: int;

    has last_updated: Optional[str];
}

with entry {
    IMPORT_SCOPE_MAX_ANCESTORS = 12;
}

def _edge_import_scope(extra: Optional[str]) -> Optional[str];
def _edge_extra_is_unresolved(extra: Optional[str]) -> bool;

with entry {
    TIER_EXTRACTED = "EXTRACTED";
    TIER_INFERRED = "INFERRED";
    TIER_AMBIGUOUS = "AMBIGUOUS";
    TIER_UNRESOLVED = "UNRESOLVED";
    _SCORE_EXTRACTED = 1.0;
    _SCORE_INFERRED = 0.8;
    _SCORE_AMBIGUOUS = 0.4;
    _SCORE_UNRESOLVED = 0.2;
    _RESOLVER_BOUND_KEYS = (
        "bare_call_target",
        "bare_tested_by_source",
        "cpp_scoped_target",
        INHERITED_ENDPOINT_KEY,
        "rescript_open_module",
        "scoped_resolved",
        "spring_resolved",
        "temporal_resolved",
    );
    _SELF_RECEIVERS = frozenset({"this", "$this", "self"});
    _SUPER_RECEIVERS = frozenset({"super", "base"});
    _TYPED_RECEIVER_LANGUAGES = frozenset({"csharp", "java", "kotlin", "tsx", "typescript"});
    _UNTYPED_RECEIVER_LANGUAGES = frozenset({"rust"});
    _NODE_ENDPOINTS = (
        ("CALLS", "target_qualified", "bare_call_target"),
        ("REFERENCES", "target_qualified", "bare_call_target"),
        ("TESTED_BY", "source_qualified", "bare_tested_by_source"),
    );

    _SYMBOL_SEPARATOR_RE = re.compile("::|\\.");
}

def _is_path_qualified(name: str) -> bool;
def _plain_symbol_name(qualified: str) -> str;
def _claimed_owner(edge_extra: dict) -> Optional[str];
def _same_owner(parent_name: Optional[str], owner: str) -> bool;
def _load_edge_extra(extra: Optional[str]) -> dict;
def _certainty_tier_sql(unbound: str) -> str;

with entry {
    _CERTAINTY_SCORE_SQL = f"CASE confidence_tier WHEN '{TIER_UNRESOLVED}' THEN {_SCORE_UNRESOLVED} WHEN '{TIER_AMBIGUOUS}' THEN {_SCORE_AMBIGUOUS} ELSE COALESCE(CASE WHEN extra LIKE '%\"confidence\"%' AND json_valid(extra) THEN json_extract(extra, '$.confidence') END, CASE confidence_tier WHEN '{TIER_INFERRED}' THEN {_SCORE_INFERRED} ELSE {_SCORE_EXTRACTED} END) END";
}

def _parent_dir(path: Optional[str]) -> Optional[str];
def import_scope_ancestors(file_path: str) -> list[tuple[str, tuple[str, ...]]];

with entry {
    IMPACT_FRONTIER_DIRS_SQL = "\nINSERT INTO _impact_frontier_dirs (dir, score)\nSELECT dir, MAX(score) FROM (\n    SELECT crg_parent_dir(n.file_path) AS dir, f.score AS score\n    FROM _impact_frontier f\n    CROSS JOIN nodes n\n      ON n.qualified_name = f.node_qn AND n.kind = 'File'\n)\nWHERE dir IS NOT NULL\nGROUP BY dir\n";
    _IMPACT_AOP_EXTRA_LIKE = "%\"aop_resolved\"%";
    _IMPACT_AOP_DIRECTION_CASE = "CASE WHEN e.extra LIKE ? THEN ? ELSE COALESCE(p.direction, ?) END";
}

def _impact_candidate_sql(resolution_guard: str) -> str;

with entry {
    _RECOVERY_HINT = "Delete it and run `code-review-graph build` to rebuild the graph.";
}

def _describe_open_failure(db_path: Path, exc: Exception) -> str;
def _assert_usable_database(conn: sqlite3.Connection, db_path: Path);

class CorruptGraphDatabaseError(GraphStoreError) {
    has db_path: Path;

    has reason: str;

    def init(db_path: str | Path, reason: object);
}

with entry {
    _SQLITE_HEADER = b"SQLite format 3\x00";

    _CORRUPTION_MESSAGES = (
        "file is not a database",
        "database disk image is malformed",
        "file is encrypted",
        "malformed database schema",
    );
    _INCOMPATIBLE_SCHEMA_MESSAGES = ("no such column", "no such table", "has no column named");
}

def _is_unreadable_database(db_path: Path, exc: sqlite3.DatabaseError) -> bool;
def _has_incompatible_schema(db_path: Path, exc: sqlite3.DatabaseError) -> bool;
def discard_corrupt_database(db_path: str | Path) -> bool;

glob max_depth_default_: any;

glob max_depth_default__: any;

glob max_nodes_default_: any;

glob max_depth_default___: any;

glob max_nodes_default__: any;

glob max_depth_default____: any;

glob max_nodes_default___: any;

with entry {
    max_depth_default_ = CALLER_TEST_ROUTE_DEPTH;
    max_depth_default__ = MAX_IMPACT_DEPTH;
    max_nodes_default_ = MAX_IMPACT_NODES;
    max_depth_default___ = MAX_IMPACT_DEPTH;
    max_nodes_default__ = MAX_IMPACT_NODES;
    max_depth_default____ = MAX_IMPACT_DEPTH;
    max_nodes_default___ = MAX_IMPACT_NODES;
}

class GraphStore(builtins.object) {
    def init(db_path: str | Path, *, read_only: bool | None = None);
    def _read_only_uri -> str;

    def __enter__ -> "GraphStore";

    def __exit__(exc_type, exc_val, exc_tb);

    def _init_schema;
    def _invalidate_cache;
    def shrink_memory(clear_nx_cache: bool = True);

    def close;
    def upsert_node(`node: NodeInfo, file_hash: str = "") -> int;
    def _qualified_for_upsert(`node: NodeInfo) -> str;
    static def _semantic_disambiguator(`node: NodeInfo) -> str;
    static def _semantic_signature(`node: NodeInfo) -> tuple[Any, ...];
    static def _row_semantic_signature(row: sqlite3.Row) -> tuple[Any, ...];
    static def _is_collision_identity(base: str, qualified_name: str) -> bool;
    static def _collision_base(qualified_name: str) -> str;
    def _plan_file_identities(file_path: str, nodes: list[NodeInfo]) -> list[str];
    def upsert_edge(`edge: EdgeInfo) -> int;
    def _resolve_stored_identity(qualified_name: str) -> str;
    def _stored_identity_candidates(qualified_name: str) -> list[str];
    def _resolve_edge_identities(
        `edge: EdgeInfo, local_prefix: str | None = None, cache: dict[str, list[str]] | None = None
    ) -> EdgeInfo;
    def _settle_collision_endpoints -> int;
    def remove_file_data(file_path: str);
    def remove_file_permanently(file_path: str) -> int;
    def remove_files_permanently(file_paths: list[str], *, stored_paths: bool = False) -> int;
    @contextmanager
    def _read_transaction -> Generator[any, any, any];
    def _begin_immediate;
    def store_file_nodes_edges(
        file_path: str, nodes: list[NodeInfo], edges: list[EdgeInfo], fhash: str = ""
    );
    def store_file_batch(batch: list[tuple[str, list[NodeInfo], list[EdgeInfo], str]]);
    def store_file_edges(file_path: str, edges: list[EdgeInfo]);
    def relocate_edge_targets(old_prefix: str, new_prefix: str) -> int;
    def _replace_file_data(
        file_path: str, nodes: list[NodeInfo], edges: list[EdgeInfo], fhash: str = ""
    );
    def _insert_edges(edges: list[EdgeInfo], now: float);
    def _aligned_edges(
        file_path: str, edges: list[EdgeInfo], collisions: dict[str, list[tuple[int, int, str]]]
    ) -> list[EdgeInfo];
    static def _collision_map(
        entries: Iterable[tuple[str, int, int, str]]
    ) -> dict[str, list[tuple[int, int, str]]];
    def _align_edge_with_collisions(
        `edge: EdgeInfo, collisions: dict[str, list[tuple[int, int, str]]]
    ) -> EdgeInfo;

    def set_metadata(key: str, value: str);

    def get_metadata(key: str) -> Optional[str];
    def get_repo_root -> Optional[str];

    def has_nodes -> bool;

    def has_nodes_for_language(language: str) -> bool;

    def commit;
    def rollback;

    def get_node(qualified_name: str) -> Optional[GraphNode];

    def get_nodes_by_file(file_path: str) -> list[GraphNode];
    def iter_nodes_by_file(file_path: str) -> Generator[any, any, any];
    def get_all_nodes(exclude_files: bool = True) -> list[GraphNode];

    def get_edges_by_source(qualified_name: str) -> list[GraphEdge];
    def iter_edges_by_source(qualified_name: str) -> Generator[any, any, any];

    def get_edges_by_target(qualified_name: str) -> list[GraphEdge];
    def get_direct_dependent_files(file_path: str) -> set[str];
    def iter_edges_by_target(qualified_name: str) -> Generator[any, any, any];
    def get_config_consumers(key: str) -> list[GraphEdge];
    def get_edges_claiming(qualified_name: str) -> list[GraphEdge];
    def search_edges_by_target_name(
        name: str, kind: str = "CALLS", language: str | None = None
    ) -> list[GraphEdge];
    def iter_edges_by_target_name(
        name: str, kind: str = "CALLS", language: str | None = None
    ) -> Generator[any, any, any];
    def get_transitive_tests(
        qualified_name: str,
        max_depth: int = 1,
        max_frontier: int | None = None,
        *,
        include_helper_routes: bool = True,
    ) -> list[dict];
    def get_ambiguous_call_tests(qualified_name: str) -> list[str];
    def _get_test_helper_routes(
        seeds: list[str], max_depth: int, max_callers: int, repo_root: str | None
    ) -> dict[str, dict[str, Any]];
    def get_directly_tested(qualified_names: Iterable[str]) -> set[str];
    def get_caller_test_routes(
        qualified_names: Iterable[str],
        max_depth: int = max_depth_default_,
        max_callers_per_node: int | None = None,
        repo_root: str | None = None,
    ) -> dict[str, dict[str, Any]];
    static def _python_module_file_index(conn: sqlite3.Connection) -> dict[str, str];
    static def _select_evidence_backed_candidate(
        candidates: list[tuple[str, str]], context_file: str, imported_files: set[str]
    ) -> str | None;
    static def _receiver_backed_candidates(
        candidates: list[tuple[str, str]], edge_extra: dict, parent_lookup: dict[str, str | None]
    ) -> list[tuple[str, str]];
    static def _class_backed_candidates(
        edge_extra: dict,
        bare_name: str,
        caller_class: str,
        caller_language: str,
        context_file: str,
        inheritance: InheritanceIndex,
    ) -> Optional[tuple[list[str], Optional[str]]];
    static def _receiver_is_untyped(edge_extra: dict, caller_language: str) -> bool;
    static def _own_method_excluded(
        edge_extra: dict,
        bare_name: str,
        caller_class: str,
        caller_language: str,
        inheritance: InheritanceIndex,
    ) -> Optional[str];
    class def _receiver_evidence_admits_candidate(
        edge_extra: dict, qualified_name: str, file_path: str, parent_name: str | None
    ) -> bool;
    class def receiver_evidence_admits(edge_extra: dict, `node: GraphNode) -> bool;
    def resolve_bare_call_targets -> int;
    def refresh_target_resolution -> int;
    def _resolve_inherited_endpoints -> int;
    def _settle_unbound_endpoints -> int;
    def _existing_qualified_names(names: Iterable[str]) -> set[str];

    def _node_exists(qualified_name: str) -> bool;
    def count_edges_by_resolution(kind: str = "CALLS") -> dict[str, int];
    def resolve_cpp_scoped_call_targets -> int;
    def resolve_bare_tested_by_sources -> int;

    def _drop_bare_endpoint_context;
    static def _directory_member_files(
        conn: sqlite3.Connection, scoped_dirs: dict[str, str]
    ) -> dict[str, set[str]];
    def _import_evidence -> tuple[dict[str, set[str]], dict[str, set[str]], dict[str, dict[str, str]]];
    def _get_bare_endpoint_context(
        conn: sqlite3.Connection
    ) -> tuple[dict[str, list[tuple[str, str]]], dict[str, str
        | None], dict[str, set[str]], dict[str, set[str]], set[str], dict[str, str], dict[str, dict[str, str]]];
    def _resolve_bare_endpoints(kind: str, endpoint: str) -> int;

    def get_all_files -> list[str];
    def get_file_hashes -> dict[str, str];
    def get_file_marker_paths -> list[str];
    def search_nodes_by_qualified_tail(tail: str, limit: int = 20) -> list[GraphNode];
    def count_nodes_by_qualified_tail(tail: str) -> int;
    def search_nodes(query: str, limit: int = 20) -> list[GraphNode];
    def count_search_nodes(query: str) -> int;
    def count_nodes_by_name(
        name: str, language: str | None = None, kinds: tuple[str, ...] = ()
    ) -> int;
    def get_nodes_by_name(name: str) -> list[GraphNode];
    def _impact_seed_qns(changed_files: list[str]) -> set[str];
    def tree_scope_bridges(file_paths: Iterable[str]) -> set[str];
    def import_scope_edges(file_paths: Iterable[str], source_qns: set[str]) -> list[GraphEdge];
    def _import_scope_importer_index -> dict[str, list[str]];
    def _file_node_directories -> dict[str, str];
    def count_unresolved_call_sites(names: set[str]) -> int;
    def get_impact_radius(
        changed_files: list[str],
        max_depth: int = max_depth_default__,
        max_nodes: int = max_nodes_default_,
        resolution: str = "all",
    ) -> dict[str, Any];
    def get_impact_radius_sql(
        changed_files: list[str],
        max_depth: int = max_depth_default___,
        max_nodes: int = max_nodes_default__,
        resolution: str = "all",
    ) -> dict[str, Any];
    def _get_impact_radius_networkx(
        changed_files: list[str],
        max_depth: int = max_depth_default____,
        max_nodes: int = max_nodes_default___,
        resolution: str = "all",
    ) -> dict[str, Any];
    def get_subgraph(qualified_names: list[str]) -> dict[str, Any];
    def get_stats -> GraphStats;

    def _get_stats_locked -> GraphStats;
    static def _nodes_by_size_filter(
        min_lines: int, max_lines: int | None, kind: str | None, file_path_pattern: str | None
    ) -> tuple[str, list];
    def count_nodes_by_size(
        min_lines: int = 50,
        max_lines: int | None = None,
        kind: str | None = None,
        file_path_pattern: str | None = None,
    ) -> int;
    def get_nodes_by_size(
        min_lines: int = 50,
        max_lines: int | None = None,
        kind: str | None = None,
        file_path_pattern: str | None = None,
        limit: int = 50,
    ) -> list[GraphNode];
    def get_node_by_id(node_id: int) -> Optional[GraphNode];
    def get_nodes_by_kind(kinds: list[str], file_pattern: str | None = None) -> list[GraphNode];
    def count_flow_memberships(node_id: int) -> int;
    def get_flow_criticalities_for_node(node_id: int) -> list[float];
    def get_flow_entry_point_ids(node_ids: set[int]) -> set[int];
    def get_node_community_id(node_id: int) -> int | None;
    def get_community_ids_by_qualified_names(qns: list[str]) -> dict[str, int | None];
    def get_files_matching(pattern: str) -> list[str];
    def get_nodes_without_signature -> list[sqlite3.Row];
    def update_node_signature(node_id: int, signature: str);
    def update_node_signatures(signature_rows: list[tuple[str, int]]);
    def get_all_community_ids -> dict[str, int | None];
    def get_node_ids_by_files(file_paths: list[str]) -> set[int];
    def get_flow_ids_by_node_ids(node_ids: set[int]) -> list[int];
    def get_flow_qualified_names(flow_id: int) -> set[str];
    def get_node_kind_by_id(node_id: int) -> str | None;
    def get_all_call_targets(include_file_sources: bool = True) -> set[str];
    def get_call_targets_outside_tests -> set[str];
    def get_communities_list -> list[sqlite3.Row];
    def get_community_member_qns(community_id: int) -> list[str];
    def get_nodes_by_community_id(community_id: int) -> list[GraphNode];
    def get_outgoing_targets(source_qns: list[str]) -> list[str];
    def get_incoming_sources(target_qns: list[str]) -> list[str];
    def get_all_edges -> list[GraphEdge];
    def get_edges_among(qualified_names: set[str]) -> list[GraphEdge];
    def get_edges_touching(names: set[str]) -> list[GraphEdge];
    def iter_edge_end_counts(column: str) -> Generator[any, any, any];
    def iter_edge_targets_from(sources: Iterable[str]) -> Generator[any, any, any];
    def get_files_with_edges(file_paths: Iterable[str]) -> set[str];
    def has_edge_with_backslash_path -> bool;
    def iter_node_identities -> Iterator[sqlite3.Row];
    def _batch_get_nodes(qualified_names: set[str]) -> list[GraphNode];
    def get_nodes_by_qualified_names(qualified_names: Iterable[str]) -> list[GraphNode];
    def get_node_degrees(*, include_tests: bool = True) -> dict[str, tuple[int, int]];
    def get_communities_by_ids(ids: Iterable[int]) -> dict[int, sqlite3.Row];
    def count_flows -> int;
    def load_flow_adjacency -> "FlowAdjacency";
    def _build_networkx_graph -> nx.DiGraph;

    def _make_qualified(`node: NodeInfo) -> str;

    def _row_to_node(row: sqlite3.Row) -> GraphNode;

    def _row_to_edge(row: sqlite3.Row) -> GraphEdge;
}

with entry {
    _NAME_CONTROL_CHARS = re.compile("[\\x00-\\x08\\x0b-\\x1f]");
}

def _sanitize_name(s: str, max_len: int = 256) -> str;

def node_to_dict(n: GraphNode) -> dict;

def edge_to_dict(e: GraphEdge) -> dict;

def __getattr__(name: str) -> Any;
