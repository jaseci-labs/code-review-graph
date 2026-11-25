"""SQLite-backed knowledge graph storage and query engine.

Stores code structure as nodes (File, Class, Function, Type, Test, YamlPath, DocSection,
JsonPath) and
edges (CALLS, IMPORTS_FROM, INHERITS, IMPLEMENTS, CONTAINS, TESTED_BY, DEPENDS_ON, REFERENCES).
Supports impact-radius queries and subgraph extraction.
"""

import from code_review_graph._lazy { lazy }

import importlib;

import builtins;

import operator;

import from __future__ { annotations }

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

"""The name the source wrote: ``a.py::Shapes.area`` -> ``area``."""
def _plain_collision_name(qualified: str) -> str;

"""*extra* for an edge that could mean any of *candidates*."""
def _ambiguous_collision_extra(extra: dict, base: str, candidates: list[str]) -> dict;

"""*extra* once its collision has gone and one definition is left."""
def _bound_collision_extra(extra: dict) -> dict;

with entry {
    _ORDERED_PAIRS_MAX_STEPS = 1000000;
}

"""Pair two sorted line lists in order, as an edit would have moved them.

    Returns ``(new_position, old_position)`` pairs covering the shorter list,
    never crossing two pairs. Equal lengths pair one-to-one in order. When
    definitions were added or removed, the pairing whose line offsets change
    least is chosen: an insertion shifts everything after it by one amount,
    so ``[10, 20]`` becoming ``[3, 16, 26]`` pairs 16 and 26, not 3 and 16.
    """
def _ordered_pairs(new_lines: list[int], old_lines: list[int]) -> list[tuple[int, int]];

"""Return languages that can safely share unresolved bare edge targets."""
def _compatible_edge_languages(language: str) -> tuple[str, ...];

"""Return the symbol portion of a qualified name (after the first "::").

    ``src/app.py::Handler.process`` → ``Handler.process``. A qualified name
    without a path component is already a bare symbol.
    """
def _symbol_of(qualified_name: str) -> str;

with entry {
    MAX_INDEXED_DOCSTRING_CHARS = 400;
    MAX_INDEXED_TOKEN_CHARS = 200;

    _ALNUM_RUN_RE = re.compile("[0-9A-Za-z]+");
    _CAMEL_BOUNDARY_RE = re.compile("(?<=[a-z0-9])(?=[A-Z])|(?<=[A-Z])(?=[A-Z][a-z])");
}

"""Return the camelCase/PascalCase word splits of *values*, space joined.

    Only sub-words that the FTS5 ``unicode61`` tokenizer cannot produce on
    its own are emitted. unicode61 already breaks on every non-alphanumeric
    character, so ``get_users`` and ``graph/impact.py`` contribute nothing,
    while ``hashPassword`` contributes ``hash Password``, the tokens that
    make ``password`` match it. Keeping the column minimal matters: repeating
    tokens that are already indexed would inflate their term frequency and
    skew BM25 ranking.
    """
def _index_tokens(*values_: str | None) -> str;

"""Return the lowercase words *text* is built from.

    Both the whole alphanumeric run and its camelCase parts are returned, so
    ``GraphStore`` yields ``{graphstore, graph, store}``. Callers compare
    these sets to decide whether a symbol is *named after* a query, which is
    the signal BM25 cannot express once long file paths dominate a row's
    token count.
    """
def identifier_words(text: str) -> set[str];

"""Return the value for a node's ``name_tokens`` column.

    A File node's ``name`` *is* its path, so splitting it would fold every
    directory segment of the checkout into the index (an absolute path under
    ``.../CloudDocs/`` would add "Cloud Docs" to every file in the graph).
    File nodes contribute their stem only.
    """
def node_index_tokens(kind: str, name: str, parent_name: str | None, file_path: str | None) -> str;

"""Return the whitespace-normalized docstring summary held in *extra*.

    Existing databases may carry any JSON value under ``docstring``, so
    non-strings are ignored rather than coerced.
    """
def _indexed_docstring(extra: dict[str, Any] | None) -> str | None;

"""The qualified name the store gives a parsed node.

    Exposed so code that parses a file without storing it (the old side of a
    diff, for one) names its symbols exactly as the graph does.
    """
def qualified_name_of(`node: NodeInfo) -> str;

"""Return *qualified_name* with its file-path component POSIX-normalized.

    Qualified names embed the file path before the first ``::`` (File nodes
    are just the path). Stored identities always use forward slashes (#774),
    so a Windows-native spelling must be bridged to find the POSIX-keyed row.
    Only the path component is rewritten — the symbol part may legitimately
    contain backslashes (PHP fully-qualified names).
    """
def _bridge_qualified_name(qualified_name: str) -> str;

with entry {
    _SCHEMA_SQL = "\nCREATE TABLE IF NOT EXISTS nodes (\n    id INTEGER PRIMARY KEY AUTOINCREMENT,\n    kind TEXT NOT NULL,          -- File, Class, Function, Type, Test\n    name TEXT NOT NULL,\n    qualified_name TEXT NOT NULL UNIQUE,\n    file_path TEXT NOT NULL,\n    line_start INTEGER,\n    line_end INTEGER,\n    language TEXT,\n    parent_name TEXT,\n    params TEXT,\n    return_type TEXT,\n    modifiers TEXT,\n    is_test INTEGER DEFAULT 0,\n    file_hash TEXT,\n    extra TEXT DEFAULT '{}',\n    -- Symbol portion of qualified_name (everything after the first \"::\").\n    -- Stored so a dotted-tail lookup is an indexed equality test instead of a\n    -- substr() scan over every node; see search_nodes_by_qualified_tail.\n    -- idx_nodes_symbol is created by migration v10, not here: _init_schema runs\n    -- before run_migrations, so indexing a column this CREATE TABLE cannot add\n    -- to an existing table would break every pre-existing database on open.\n    symbol TEXT,\n    -- Documentation summary lifted out of extra['docstring'] so the FTS5\n    -- external-content index can reach it (FTS columns must be real columns\n    -- of the content table). See migration v11.\n    docstring TEXT,\n    -- camelCase/PascalCase word splits for name, parent_name and the file\n    -- stem. unicode61 splits on punctuation but keeps hashPassword as one\n    -- token, so \"password\" could never match it. Added by migration v11.\n    name_tokens TEXT,\n    updated_at REAL NOT NULL\n);\n\nCREATE TABLE IF NOT EXISTS edges (\n    id INTEGER PRIMARY KEY AUTOINCREMENT,\n    kind TEXT NOT NULL,           -- CALLS, IMPORTS_FROM, INHERITS, REFERENCES, etc.\n    source_qualified TEXT NOT NULL,\n    target_qualified TEXT NOT NULL,\n    file_path TEXT NOT NULL,\n    line INTEGER DEFAULT 0,\n    extra TEXT DEFAULT '{}',\n    confidence REAL DEFAULT 1.0,\n    confidence_tier TEXT DEFAULT 'EXTRACTED',\n    -- 'direct' when target_qualified names an indexed node, 'unresolved' when\n    -- it is a bare name the read path can only match by name. NULL for edge\n    -- kinds where the distinction is meaningless (an IMPORTS_FROM target is a\n    -- file path, not a call target) and for rows written since the last\n    -- refresh_target_resolution() pass. Same rule as nodes.symbol above:\n    -- idx_edges_kind_target_resolution is created by migration v11, not here.\n    target_resolution TEXT,\n    updated_at REAL NOT NULL\n);\n\nCREATE TABLE IF NOT EXISTS metadata (\n    key TEXT PRIMARY KEY,\n    value TEXT NOT NULL\n);\n\nCREATE INDEX IF NOT EXISTS idx_nodes_file ON nodes(file_path);\nCREATE INDEX IF NOT EXISTS idx_nodes_kind ON nodes(kind);\nCREATE INDEX IF NOT EXISTS idx_nodes_name ON nodes(name);\nCREATE INDEX IF NOT EXISTS idx_edges_kind ON edges(kind);\nCREATE INDEX IF NOT EXISTS idx_edges_target_kind ON edges(target_qualified, kind);\nCREATE INDEX IF NOT EXISTS idx_edges_source_kind ON edges(source_qualified, kind);\nCREATE INDEX IF NOT EXISTS idx_edges_file ON edges(file_path);\n";
    RESOLUTION_ALL = "all";
    RESOLUTION_DIRECT = "direct";
    RESOLUTION_UNRESOLVED = "unresolved";
    QUERY_RESOLUTIONS = (RESOLUTION_ALL, RESOLUTION_DIRECT, RESOLUTION_UNRESOLVED);
    IMPACT_RESOLUTIONS = (RESOLUTION_ALL, RESOLUTION_DIRECT);
}

"""Return the SQL predicate for one validated impact resolution mode."""
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

"""In-memory adjacency structure for flow tracing.

    Loaded once via :meth:`GraphStore.load_flow_adjacency` and passed to
    ``trace_flows`` / ``compute_criticality`` to avoid per-edge SQLite
    point queries on large graphs.
    """
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

"""The ``import_scope`` recorded on one raw ``edges.extra`` value."""
def _edge_import_scope(extra: Optional[str]) -> Optional[str];

"""True when an edge's ``extra`` marks its endpoint as unresolved.

    An edge carrying ``ambiguous_targets`` or ``unresolved_targets`` names a
    set of candidates rather than one node, and one carrying a claimed endpoint
    was written for a symbol the graph does not have, so no traversal may treat
    it as a fact about a specific symbol.
    """
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

"""Is *name* ``<absolute file path>::<symbol>``, the form a node's name takes?

    ``Redis::get``, ``crate::a::b`` and ``App\\Mail::send`` also hold ``::``, but
    they are what the source wrote, and they are what the scoped resolvers read.
    """
def _is_path_qualified(name: str) -> bool;

"""The last name in a path-qualified symbol: ``a.py::Helper.ping`` -> ``ping``."""
def _plain_symbol_name(qualified: str) -> str;

"""The class a settled edge's claimed endpoint put the method on, if any.

    ``a.py::Helper.ping`` gives ``Helper``; ``a.py::ping`` gives None.
    """
def _claimed_owner(edge_extra: dict) -> Optional[str];

"""Can a method whose class is *parent_name* be the one *owner* named?

    Scopes are compared from the innermost name out, as far as both go.
    ``Alpha.Inner`` is not ``Beta.Inner``, but a side that knew only ``Inner``
    is no evidence against ``Outer.Inner``.
    """
def _same_owner(parent_name: Optional[str], owner: str) -> bool;

"""Parse one ``edges.extra`` value, treating anything unusable as empty."""
def _load_edge_extra(extra: Optional[str]) -> dict;

"""SQL for the tier an edge has earned, given the test that it is unbound."""
def _certainty_tier_sql(unbound: str) -> str;

with entry {
    _CERTAINTY_SCORE_SQL = f"CASE confidence_tier WHEN '{TIER_UNRESOLVED}' THEN {_SCORE_UNRESOLVED} WHEN '{TIER_AMBIGUOUS}' THEN {_SCORE_AMBIGUOUS} ELSE COALESCE(CASE WHEN extra LIKE '%\"confidence\"%' AND json_valid(extra) THEN json_extract(extra, '$.confidence') END, CASE confidence_tier WHEN '{TIER_INFERRED}' THEN {_SCORE_INFERRED} ELSE {_SCORE_EXTRACTED} END) END";
}

"""The directory holding *path*, as a directory-scoped edge spells it.

    Registered as the SQLite function ``crg_parent_dir``. Returns ``None``
    for anything that is not an absolute POSIX-ish path, so a qualified name
    that is not a file path can never join a directory target by accident.
    """
def _parent_dir(path: Optional[str]) -> Optional[str];

"""Directory targets that could name *file_path*, nearest first.

    Each entry pairs a directory with the import scopes for which that
    directory legitimately stands for the file. The file's own directory
    qualifies under both scopes; anything higher only under
    :data:`IMPORT_SCOPE_TREE`, because a Go package is exactly one directory
    deep and a subdirectory of it is a different package.
    """
def import_scope_ancestors(file_path: str) -> list[tuple[str, tuple[str, ...]]];

with entry {
    IMPACT_FRONTIER_DIRS_SQL = "\nINSERT INTO _impact_frontier_dirs (dir, score)\nSELECT dir, MAX(score) FROM (\n    SELECT crg_parent_dir(n.file_path) AS dir, f.score AS score\n    FROM _impact_frontier f\n    CROSS JOIN nodes n\n      ON n.qualified_name = f.node_qn AND n.kind = 'File'\n)\nWHERE dir IS NOT NULL\nGROUP BY dir\n";
    _IMPACT_AOP_EXTRA_LIKE = "%\"aop_resolved\"%";
    _IMPACT_AOP_DIRECTION_CASE = "CASE WHEN e.extra LIKE ? THEN ? ELSE COALESCE(p.direction, ?) END";
}

"""One hop of the impact relaxation.

    *resolution_guard* is either the empty string or a fixed predicate chosen
    by a validated enum; no caller value reaches the SQL text.

    The first two branches carry the AOP direction override, so each binds
    the ``extra`` LIKE pattern and the forced direction ahead of the policy
    default. See ``_IMPACT_AOP_DIRECTION_CASE``.

    The third branch is the directory-scoped one. A Go import names a
    package, so its edge targets the file's DIRECTORY rather than the file,
    and expanding it here -- at every hop, without spending one -- is what
    one edge per import buys: the alternative is one edge per file in the
    package, which on kubernetes is 73,507 edges for a single directory.

    ``CROSS JOIN`` and ``INDEXED BY`` pin that branch to one index seek per
    frontier package. Left to itself SQLite drove it from the covering index
    on ``kind`` alone and rescanned every IMPORTS_FROM row once per
    directory: 18 seconds of a 19-second kubernetes traversal, against 1.5
    with the plan pinned. ``tests/test_import_scope.py`` asserts the plan.
    """
def _impact_candidate_sql(resolution_guard: str) -> str;

with entry {
    _RECOVERY_HINT = "Delete it and run `code-review-graph build` to rebuild the graph.";
}

"""Turn a raw SQLite/OS error into one actionable line.

    ``sqlite3`` reports "file is not a database" for a corrupt or foreign
    file and "attempt to write a readonly database" / "unable to open
    database file" for a directory the process may not write to. Those two
    need opposite fixes, so they get opposite messages instead of one
    generic apology.
    """
def _describe_open_failure(db_path: Path, exc: Exception) -> str;

"""Refuse a SQLite file this build cannot honestly answer from.

    Two cases that both used to be accepted in silence:

    * a perfectly valid SQLite file belonging to something else. ``CREATE
      TABLE IF NOT EXISTS`` would graft our schema onto it and every query
      would then answer "nothing found" about a graph that was never there.
    * a file written by a newer release. ``run_migrations`` is a no-op once
      the stored version is at or above ``LATEST_VERSION``, so the mismatch
      only surfaced much later, as a missing column in an unrelated query.
    """
def _assert_usable_database(conn: sqlite3.Connection, db_path: Path) -> None;

"""The graph database file exists but cannot be opened as this graph.

    A named subclass of :class:`GraphStoreError`, rather than a bare one, so
    a caller that is about to rebuild the graph from scratch anyway
    (``build``) can discard the unusable file and carry on, and every other
    caller reports the single actionable line every ``GraphStoreError``
    carries instead of a traceback. A restored CI cache is the
    common source: an unusable ``graph.db`` turns every later run red until
    someone clears the cache by hand.

    Deliberately not a ``sqlite3.Error``. Nothing this package can explain
    about itself may reach a caller as a raw SQLite exception; what the
    subclass records is the one shape of unusable that a rebuild fixes by
    itself. A foreign SQLite file and a database written by a newer release
    are excluded for the same reason they are refused up front in
    :func:`_assert_usable_database`: deleting somebody else's data, or a
    graph this build is merely too old to read, is not a recovery.

    Two shapes of unusable reach here, and both are unrecoverable in place:
    a file SQLite cannot read at all (truncated, half-written, not a
    database), and a perfectly valid SQLite file whose tables are the wrong
    shape, which ``CREATE TABLE IF NOT EXISTS`` will not repair.
    """
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

"""Distinguish a corrupt database file from an environment problem.

    A missing directory or a permission error also raises
    ``sqlite3.DatabaseError``; deleting the file would be wrong there, so
    only SQLite's own corruption messages, or a file that does not carry the
    SQLite header, count as corruption.
    """
def _is_unreadable_database(db_path: Path, exc: sqlite3.DatabaseError) -> bool;

"""True when *db_path* is readable SQLite holding the wrong tables.

    Both halves are required. The message has to name a schema object, which
    rules out locks, read-only filesystems and I/O errors; and the file has
    to still answer a read of ``sqlite_master``, which rules out reporting a
    genuinely broken file as merely mis-shaped.
    """
def _has_incompatible_schema(db_path: Path, exc: sqlite3.DatabaseError) -> bool;

"""Delete an unusable graph database and its WAL sidecars.

    Returns True when at least one file was removed. Only ever call this
    where the graph is about to be rebuilt from scratch: the data is gone.
    """
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

"""SQLite-backed code knowledge graph."""
class GraphStore(builtins.object) {
    def init(db_path: str | Path, *, read_only: bool | None = None);

    """Open SQLite without creating or updating any database sidecar."""
    def _read_only_uri -> str;

    def __enter__ -> "GraphStore";

    def __exit__(exc_type, exc_val, exc_tb) -> None;

    def _init_schema -> None;

    """Invalidate the cached NetworkX graph after write operations."""
    def _invalidate_cache -> None;

    """Release cached in-memory structures and shrink SQLite page cache."""
    def shrink_memory(clear_nx_cache: bool = True) -> None;

    def close -> None;

    """Insert or update a node. Returns the node ID."""
    def upsert_node(`node: NodeInfo, file_hash: str = "") -> int;

    """Return a stable identity, suffixing genuine same-file collisions.

        A row at the same line, or else the semantically identical row nearest
        to it, is this definition and is updated in place, so a moved line
        never adds a second row. Only a definition that differs from every
        stored one sharing its base becomes a suffixed collision.
        """
    def _qualified_for_upsert(`node: NodeInfo) -> str;

    """Hash definition semantics that survive harmless source line shifts."""
    static def _semantic_disambiguator(`node: NodeInfo) -> str;

    """Return definition fields that identify a node across line shifts."""
    static def _semantic_signature(`node: NodeInfo) -> tuple[Any, ...];

    """Return the semantic signature stored for an existing node row."""
    static def _row_semantic_signature(row: sqlite3.Row) -> tuple[Any, ...];

    """Return whether *qualified_name* has this store's exact suffix shape.

        Checking the full generated suffix avoids treating colon-bearing symbol
        names, such as Objective-C selectors, as collision identities.
        """
    static def _is_collision_identity(base: str, qualified_name: str) -> bool;

    """Return the base identity of a collision row, or the name itself."""
    static def _collision_base(qualified_name: str) -> str;

    """Reconcile a replacement file's nodes with their previous identities.

        Semantic matches keep their qualified name across collision-set reorder.
        When definitions are semantically identical, the closest source location
        preserves identity across harmless shifts, growth, and shrink transitions.
        """
    def _plan_file_identities(file_path: str, nodes: list[NodeInfo]) -> list[str];

    """Insert or update an edge."""
    def upsert_edge(`edge: EdgeInfo) -> int;

    """Resolve a bare edge endpoint to one lone historical suffix."""
    def _resolve_stored_identity(qualified_name: str) -> str;

    """Every stored definition a base edge endpoint can mean.

        Only a qualified (``path::symbol``) name can be a collision base. The
        index range seek is tried first because it is almost always empty;
        the exact lookup runs only when a suffixed row exists. A name with no
        collision rows is returned alone, whether or not it has a node.
        """
    def _stored_identity_candidates(qualified_name: str) -> list[str];

    """Settle both edge endpoints against the stored collision identities.

        Endpoints under *local_prefix* (``"<file>::"``) belong to the file
        being stored, whose identities the caller has already aligned.
        """
    def _resolve_edge_identities(
        `edge: EdgeInfo, local_prefix: str | None = None, cache: dict[str, list[str]] | None = None
    ) -> EdgeInfo;

    """Keep every edge into a duplicated name honest after a store pass.

        A file is stored on its own, so a call from another file can be written
        before, or after, the duplicates it names: bound to the first
        definition, or left on a collision that has since gone. Settled here:
        an unevidenced ``CALLS``/``REFERENCES`` target, or ``TESTED_BY`` source,
        on a name several definitions share lists them all instead (#585); one
        whose duplicates are gone binds to the definition left. A recursive
        call is evidence and keeps its binding.

        Returns the number of edges changed.
        """
    def _settle_collision_endpoints -> int;

    """Remove all nodes and edges associated with a file."""
    def remove_file_data(file_path: str) -> None;

    """Remove one deleted file and every graph reference to its nodes."""
    def remove_file_permanently(file_path: str) -> int;

    """Atomically remove deleted files and graph references to their nodes.

        Reconciliation passes exact inventory spellings with ``stored_paths``.
        Normalising legacy rows would miss them and could delete a different,
        current row that already uses the canonical spelling (#911).
        """
    def remove_files_permanently(file_paths: list[str], *, stored_paths: bool = False) -> int;

    """Hold one snapshot for the duration of a multi-statement read.

        The connection runs with ``isolation_level=None``, so without this
        every statement gets its own snapshot and a writer committing between
        two of them yields numbers that contradict each other — ``get_stats``
        could report a ``total_nodes`` taken before a watcher's commit and a
        per-kind breakdown taken after it.

        ``BEGIN DEFERRED`` takes no lock and, under WAL, never blocks the
        writer: it only pins the snapshot this connection reads from. Nested
        use is a no-op so an enclosing write transaction keeps its own scope,
        and a failure to begin degrades to today's per-statement reads rather
        than failing the query.
        """
    @contextmanager
    def _read_transaction -> Generator[any, any, any];

    """Start an IMMEDIATE transaction, rolling back any prior uncommitted
        transaction first (regression guard for #135 / #489).
        """
    def _begin_immediate -> None;

    """Atomically replace all data for a file."""
    def store_file_nodes_edges(
        file_path: str, nodes: list[NodeInfo], edges: list[EdgeInfo], fhash: str = ""
    ) -> None;

    """Atomically replace data for a batch of files in one transaction."""
    def store_file_batch(batch: list[tuple[str, list[NodeInfo], list[EdgeInfo], str]]) -> None;

    """Atomically replace a file's edges and keep its node rows.

        For a file whose bytes did not change. Its symbols are the same, and
        flows and communities point at their node ids, so those ids must stay.
        """
    def store_file_edges(file_path: str, edges: list[EdgeInfo]) -> None;

    """Rewrite edge targets that start with *old_prefix* to *new_prefix*.

        Used for files behind a followed symlinked folder outside the
        repository: a resolver that resolves symlinks names the outside real
        path, and the graph stores those files under the in-repo path (#269).
        """
    def relocate_edge_targets(old_prefix: str, new_prefix: str) -> int;

    """Delete and re-insert one file's nodes/edges with batched statements.

        The previous implementation ran :meth:`upsert_node` /
        :meth:`upsert_edge` once per symbol, i.e. a SELECT + INSERT (or
        SELECT + UPDATE) round trip for every row. On large graphs (10^5+
        nodes, 10^6+ edges) that per-row Python/SQLite round trip dominates
        the whole build and can take tens of minutes (issue #721). This bulk
        path deduplicates rows in Python and inserts everything with
        ``executemany``, so each statement is prepared once and the file
        lands in a single transaction.

        Must be called inside an open transaction (BEGIN IMMEDIATE).
        """
    def _replace_file_data(
        file_path: str, nodes: list[NodeInfo], edges: list[EdgeInfo], fhash: str = ""
    ) -> None;

    """Insert one file's edges; its previous edge rows are already deleted."""
    def _insert_edges(edges: list[EdgeInfo], now: float) -> None;

    """Align one file's parsed edges with its own and stored identities.

        The file's own endpoints are settled by *collisions*; only endpoints
        in other files can need the index lookup, once per distinct name.
        """
    def _aligned_edges(
        file_path: str, edges: list[EdgeInfo], collisions: dict[str, list[tuple[int, int, str]]]
    ) -> list[EdgeInfo];

    """Group ``(base, line_start, line_end, identity)`` by colliding base.

        A base is kept when it has several definitions, or one whose identity
        is suffixed (the survivor of a collision that shrank).
        """
    static def _collision_map(
        entries: Iterable[tuple[str, int, int, str]]
    ) -> dict[str, list[tuple[int, int, str]]];

    """Point an edge at the colliding definition evidenced by its line."""
    def _align_edge_with_collisions(
        `edge: EdgeInfo, collisions: dict[str, list[tuple[int, int, str]]]
    ) -> EdgeInfo;

    def set_metadata(key: str, value: str) -> None;

    def get_metadata(key: str) -> Optional[str];

    """Absolute root of the repository this graph describes, if known.

        ``file_path`` values are absolute, so any consumer that reads a path
        convention out of them (``tests/``, ``src/test/``) has to know where
        the repository starts, or it reads the directories above the checkout
        instead. Builds record the root; for a graph built before they did,
        the default database location ``<root>/.code-review-graph/graph.db``
        gives the same answer. ``None`` means neither applies, and callers
        must degrade explicitly rather than assume the whole path is inside
        the repository.
        """
    def get_repo_root -> Optional[str];

    def has_nodes -> bool;

    def has_nodes_for_language(language: str) -> bool;

    def commit -> None;

    """Rollback the current transaction."""
    def rollback -> None;

    def get_node(qualified_name: str) -> Optional[GraphNode];

    def get_nodes_by_file(file_path: str) -> list[GraphNode];

    """Yield file nodes without first materializing the complete row set."""
    def iter_nodes_by_file(file_path: str) -> Generator[any, any, any];

    """Return all nodes, optionally excluding File nodes."""
    def get_all_nodes(exclude_files: bool = True) -> list[GraphNode];

    def get_edges_by_source(qualified_name: str) -> list[GraphEdge];

    """Yield outgoing edges without first materializing the complete set."""
    def iter_edges_by_source(qualified_name: str) -> Generator[any, any, any];

    def get_edges_by_target(qualified_name: str) -> list[GraphEdge];

    """Files that import *file_path* or point an edge at a node in it.

        One indexed query instead of one lookup per node in the file. The
        node edges counted are CALLS, IMPORTS_FROM, INHERITS and IMPLEMENTS;
        *file_path* itself is never its own dependent.
        """
    def get_direct_dependent_files(file_path: str) -> set[str];

    """Yield incoming edges without first materializing the complete set."""
    def iter_edges_by_target(qualified_name: str) -> Generator[any, any, any];

    """Find direct and ConfigurationProperties-prefix consumers of a key."""
    def get_config_consumers(key: str) -> list[GraphEdge];

    """Edges whose settled endpoint once named *qualified_name*.

        ``_settle_unbound_endpoints`` turns an endpoint that names no node back
        into the plain name and keeps the qualified one under
        ``CLAIMED_ENDPOINT_KEY``, so a symbol a diff deleted is still found by
        the calls written against it.
        """
    def get_edges_claiming(qualified_name: str) -> list[GraphEdge];

    """Search for edges where target_qualified matches an unqualified name.

        CALLS edges often store unqualified target names (e.g. ``generateTestCode``)
        rather than fully qualified ones (``file.ts::generateTestCode``).  This
        method finds those edges by exact match on the plain function name so that
        reverse call tracing (callers_of) works even when qualified-name lookup
        returns nothing.

        When ``language`` is given, only edges whose source node has a compatible
        language are returned. JavaScript, TypeScript, TSX and HTML pages form
        one family because calls and inheritance routinely cross those source
        types (JSX is stored as JavaScript; Astro as TypeScript). Other languages require an
        exact match. Bare names are ambiguous across the whole graph, so without
        this filter a common method name like ``clone`` can match a same-named
        method in an unrelated language (#708).
        """
    def search_edges_by_target_name(
        name: str, kind: str = "CALLS", language: str | None = None
    ) -> list[GraphEdge];

    """Yield exact bare-target edges without materializing all matches."""
    def iter_edges_by_target_name(
        name: str, kind: str = "CALLS", language: str | None = None
    ) -> Generator[any, any, any];

    """Find tests covering a node, including indirect (transitive) coverage.

        TESTED_BY edges are stored as source=production, target=test by
        the parser, so look them up by source_qualified. See: #515

        1. Direct: TESTED_BY edges originating at this node (+ bare-name fallback).
        2. Indirect: follow outgoing CALLS edges up to *max_depth* hops,
           then collect TESTED_BY edges on each callee.
        3. Follow incoming CALLS through test helpers to actual Test nodes,
           allowing *max_depth* helpers between the symbol and a test. Pass
           ``include_helper_routes=False`` to leave this step out: a call path
           is a pointer to a test, not a record of coverage, so risk scoring
           must not count it.

        Returns a list of dicts with node fields plus ``indirect: bool``.

        ``max_frontier`` caps the CALLS fan-out per BFS hop to prevent O(N*M)
        query explosion on hub functions in large graphs. Defaults to
        ``CRG_MAX_TRANSITIVE_FRONTIER`` env var (50 if unset). The callees
        kept are the first by name, so one graph gives one answer.
        """
    def get_transitive_tests(
        qualified_name: str,
        max_depth: int = 1,
        max_frontier: int | None = None,
        *,
        include_helper_routes: bool = True,
    ) -> list[dict];

    """Tests with a call that may mean this PHP symbol, but was never pinned.

        A Laravel test reaches a class through the container, as in
        ``app(Service::class)->run()``, so nothing in the file says which class
        ``run`` belongs to. When more than one class the test file imports (or
        the test file itself) defines ``run``, the call stays unresolved and the
        resolver keeps those classes' methods on the edge as
        ``ambiguous_targets``. This returns each test whose list holds
        *qualified_name*. That is a guess, never coverage: risk scoring and the
        test-gap report do not read it.

        A call made on a class the test builds, as in
        ``(new UpdateBooks)->handle()``, is taken to mean that class's method,
        so it is not a guess for the others. A class built on the call's own
        line settles only that call. A class built on a line with no such
        call, as in ``$job = new UpdateBooks()`` and a later
        ``$job->withBatchId($id)->handle()``, settles the test's other calls.

        Only PHP is answered (#850). A class or file target is expanded to its
        methods, as :meth:`get_transitive_tests` does. A list cut at 20
        entries can leave a guess out, never put a wrong one in.
        """
    def get_ambiguous_call_tests(qualified_name: str) -> list[str];

    """Resolve CALLS paths through test helpers, never helper TESTED_BY edges.

        Helpers are marked as test code after parsing, so they need not have
        TESTED_BY edges. Only reaching a real Test declaration supplies evidence;
        a fixture's is_test flag alone cannot vouch for production code.
        """
    def _get_test_helper_routes(
        seeds: list[str], max_depth: int, max_callers: int, repo_root: str | None
    ) -> dict[str, dict[str, Any]];

    """Which of *qualified_names* carry a TESTED_BY edge of their own.

        One batched query per 450 names instead of one edge fetch per symbol;
        a test-gap report asks this about every changed symbol at once.
        """
    def get_directly_tested(qualified_names: Iterable[str]) -> set[str];

    """Find, for each input symbol, a tested *caller* that reaches it.

        This walks *upwards* over incoming CALLS edges, unlike the outgoing
        callee traversal in :meth:`get_transitive_tests`: a
        private helper that no test names directly is still run by the tests of
        the public function that calls it, and reporting it as flatly
        "untested" is a false alarm the author cannot act on (#1047).

        **What a route proves, and what it does not.** A route is a static
        CALLS path from a tested caller down to the symbol. It does not show
        that any test executes the symbol: a helper can sit under two
        well-tested callers on a branch none of their tests take. Measured
        against line coverage over this repository's own suite, about 6% of
        the symbols this walk reaches are never executed by any test, and no
        shape of the call graph separates them -- the discriminating fact is
        which branch a test takes, which the graph does not record. Tightening
        the hop limit, the caller fan-out or the file boundary was tried and
        each halves the number of symbols reached while leaving that ~6%
        roughly where it was. So the result is reported as reachability and
        never scored as coverage: ``analyze_changes`` keeps an indirectly
        reached symbol in the gap report at full untested risk, and only adds
        the route as a pointer to where a test already runs nearby.

        Args:
            qualified_names: Symbols with no direct TESTED_BY edge of their own.
            max_depth: Maximum CALLS hops to walk upwards. The default of
                ``CALLER_TEST_ROUTE_DEPTH`` (2) is measured, not guessed: on
                this repository depths 3-5 reach no additional symbol while
                each concedes another ~8% of the codebase to "reached".
            max_callers_per_node: Skip expanding any one node with more
                incoming CALLS than this (default
                ``CALLER_TEST_ROUTE_MAX_CALLERS``). Deliberately a per-node
                limit rather than a budget shared across the inputs: a shared
                budget makes one hub in a change set delete the routes of
                every other symbol in it, which is the false alarm this walk
                exists to remove. It is applied before the callers are read,
                so it bounds the work rather than the leftovers.
            repo_root: Repository root, used to recognise callers that live in
                test files. Such a caller's TESTED_BY edges point at other
                symbols in its own test file, so crediting a production symbol
                through one would let a test fixture vouch for the code it
                sets up. Resolved CALLS paths through helpers to actual Test
                nodes are accepted. Defaults to the graph's recorded root.

        Returns:
            ``{qualified_name: {"via", "depth", "tests"}}`` holding only the
            inputs that were reached. ``via`` is the tested caller, ``depth``
            the hop count (1 = a direct caller), ``tests`` up to three of that
            caller's test symbols. Inputs absent from the mapping have no
            tested caller within *max_depth*.
        """
    def get_caller_test_routes(
        qualified_names: Iterable[str],
        max_depth: int = max_depth_default_,
        max_callers_per_node: int | None = None,
        repo_root: str | None = None,
    ) -> dict[str, dict[str, Any]];

    """Map each dotted Python module to the one indexed file defining it.

        Built from indexed ``.py`` paths rather than the filesystem, so it works
        on a graph queried away from the source tree. A module maps to a file
        only when exactly one file answers to it; ambiguous modules are dropped
        so they cannot manufacture evidence. Matching is on whole path segments,
        which keeps ``mypkg.core`` away from ``.../notmypkg/core.py``.
        """
    static def _python_module_file_index(conn: sqlite3.Connection) -> dict[str, str];

    """Return the sole same-file/import-backed candidate, if one exists."""
    static def _select_evidence_backed_candidate(
        candidates: list[tuple[str, str]], context_file: str, imported_files: set[str]
    ) -> str | None;

    """Narrow bare-name candidates to what the receiver can actually hold.

        ``x.get(...)`` calls the ``get`` belonging to whatever ``x`` is. The
        call-site file's import list says nothing about that, so a name match
        plus an import is not evidence — it is how a plain ``some_dict.get()``
        ended up recorded as a call into ``ConnectionPool.get``. The parser
        records what the file itself says the receiver is; honour it:

        ``module``
            the name is bound to a module file, so the method has to be a
            top-level name in that file — ``agent_baseline.run(...)`` means
            ``agent_baseline.py::run`` and nothing else.
        ``class``
            the name is annotated, constructed, or is itself an imported
            symbol, so the method has to belong to a class of that name.
        anything else
            a container literal, or a local with no evidence at all. There is
            nothing to attribute the call to, so nothing is attributed and the
            target stays bare for the unresolved path to explain.
        """
    static def _receiver_backed_candidates(
        candidates: list[tuple[str, str]], edge_extra: dict, parent_lookup: dict[str, str | None]
    ) -> list[tuple[str, str]];

    """(candidates, class inherited through) when the call names its class.

        ``pet.getName()`` on a ``Pet pet`` can only mean ``Pet.getName`` or the
        ``getName`` that ``Pet`` inherits; a same-named method elsewhere is no
        answer, not even in the same file. ``$this->run()`` and Java's
        ``this.run()`` name the caller's own class the same way, and
        ``super.run()`` its parent. See: #984

        None when the receiver says nothing about a class, so the usual file
        and import evidence applies.
        """
    static def _class_backed_candidates(
        edge_extra: dict,
        bare_name: str,
        caller_class: str,
        caller_language: str,
        context_file: str,
        inheritance: InheritanceIndex,
    ) -> Optional[tuple[list[str], Optional[str]]];

    """Is this a call on another object whose type nothing records?

        Only for languages whose parser records the receiver's name and never
        its type (Rust). In the typed languages a missing type means the
        receiver is truly unknown, and ``_own_method_excluded`` covers that.
        """
    static def _receiver_is_untyped(edge_extra: dict, caller_language: str) -> bool;

    """The caller's own method that a call on another object cannot mean.

        ``h.equals(x)`` inside ``Widget.equals`` calls ``equals`` on whatever
        ``h`` is. With nothing known about ``h``, sharing a file is no evidence
        that it is a ``Widget``, and choosing ``Widget.equals`` makes the method
        call itself.
        """
    static def _own_method_excluded(
        edge_extra: dict,
        bare_name: str,
        caller_class: str,
        caller_language: str,
        inheritance: InheritanceIndex,
    ) -> Optional[str];

    """Row-level form of :meth:`receiver_evidence_admits`."""
    class def _receiver_evidence_admits_candidate(
        edge_extra: dict, qualified_name: str, file_path: str, parent_name: str | None
    ) -> bool;

    """Can this edge's receiver evidence mean *node*?

        The read path keeps a bare-name fallback: a CALLS edge whose target is
        the plain method name still answers ``callers_of`` for a node of that
        name. That fallback applies exactly the rule
        ``_resolve_bare_endpoints`` refuses to apply — ``some_dict.get(...)``
        writes the target ``get`` and says nothing whatever about
        ``ConnectionPool.get`` — so leaving the two paths disagreeing means
        every attribution the resolver honestly declined is handed back by the
        tool. Reuse the resolver's own test here, over the single candidate the
        caller is asking about.

        An edge carrying no ``receiver_binding`` at all is a plain
        ``foo(...)`` call with no receiver to consult. That is the case the
        fallback exists for, and it is admitted unchanged.
        """
    class def receiver_evidence_admits(edge_extra: dict, `node: GraphNode) -> bool;

    """Resolve bare CALLS targets backed by same-file or import evidence.

        After parsing, some CALLS edges have bare targets (no ``::`` separator)
        because the parser couldn't resolve cross-file. A globally unique name
        is not sufficient evidence: unrelated repositories often contain one
        matching helper by coincidence. The candidate must be in the call-site
        file or in exactly one file imported by that file.

        Returns the number of resolved edges.
        """
    def resolve_bare_call_targets -> int;

    """Settle every edge endpoint, then recompute what each edge claims.

        Run after every resolver pass: those passes rewrite bare targets into
        qualified ones, so a classification taken at insert time would be
        stale for exactly the edges the distinction is about. Set-based
        UPDATEs over the edge table, not a per-row query.

        Returns the number of rows whose classification changed; rows that
        are already right are not rewritten.
        """
    def refresh_target_resolution -> int;

    """Move a call on a class that only inherits the method to the ancestor.

        ``this.handle()`` in ``Leaf`` is written ``<leaf>::Leaf.handle``, and
        ``pet.getName()`` on an imported ``Pet`` is ``<pet>::Pet.getName``. When
        the class does not declare the method, that names no node. If one
        ancestor surely declares it (see ``InheritanceIndex``), the endpoint
        moves there, and ``extra`` keeps the name the parser wrote. Every pass
        checks the move again from that name, so after an update that adds the
        method nearer, removes it, or leaves the answer unsure, the edge is
        where a fresh parse and this pass would put it. TESTED_BY mirrors take
        the same path, so ``tests_for`` on the ancestor finds the test.

        Runs before ``_settle_unbound_endpoints`` and also takes up edges that
        pass settled earlier. Returns the number of edges changed. See: #984
        """
    def _resolve_inherited_endpoints -> int;

    """Stop an edge naming a qualified symbol the graph does not have.

        The parser sees one file. It qualifies a call whenever it can tell the
        file, so ``h.hashCode()`` on a ``Helper`` declared in the same file is
        written ``One.java::Helper.hashCode`` whether or not ``Helper`` has that
        method, and ``self.shared()`` names the enclosing class when ``shared``
        is inherited. A path in front of a name passes every check a real name
        does, and the bare-name path skips it, so it reads as fact while pointing
        at nothing. See: #984

        Such an endpoint goes back to the plain name the source wrote. The
        qualified form stays in ``extra``, because the file that adds the method
        may be the only one parsed next: the edge returns to it when the node
        appears, and is written exactly as a fresh parse writes it, so an
        incremental update and a rebuild agree. A receiver was on the call, so
        the plain name is not evidence for a same-named symbol nearby, and
        ``_resolve_bare_endpoints`` leaves these edges alone.

        Returns the number of edges changed.
        """
    def _settle_unbound_endpoints -> int;

    """The members of *names* that are a node's qualified name."""
    def _existing_qualified_names(names: Iterable[str]) -> set[str];

    def _node_exists(qualified_name: str) -> bool;

    """Split one edge kind into certain and guessed target attributions.

        The first query is an index-only group-by over
        ``idx_edges_kind_target_resolution``; that is what the stored column
        is for. Only rows the column has not classified yet -- a store written
        directly by a test, or a build that skipped post-processing -- pay for
        re-deriving the answer, so the count is never silently short and a
        refreshed graph never pays for a scan.
        """
    def count_edges_by_resolution(kind: str = "CALLS") -> dict[str, int];

    """Resolve cross-file C++ ``Scope::call`` targets by stable scope identity.

        An explicit C++ scope is stronger evidence than a globally unique bare
        name. Resolve it when exactly one signature-bearing node matches; keep
        overload sets explicit and bounded when more than one node matches.
        """
    def resolve_cpp_scoped_call_targets -> int;

    """Resolve bare TESTED_BY sources backed by graph evidence.

        TESTED_BY edges copy the target of a test's CALLS edge, so unresolved
        cross-file calls also leave a bare production source. The test call-site
        file must import the candidate file (or contain the candidate itself)
        before this method qualifies that source.

        Returns the number of resolved edges.
        """
    def resolve_bare_tested_by_sources -> int;

    def _drop_bare_endpoint_context -> None;

    """Member files of each directory-scoped import target.

        One pass over the File nodes, walking each file's ancestors against
        the directories that are actually import targets. A ``package``
        directory owns only the files directly in it; a ``tree`` directory
        owns every file below it.
        """
    static def _directory_member_files(
        conn: sqlite3.Connection, scoped_dirs: dict[str, str]
    ) -> dict[str, set[str]];

    """What each file imports: (files, ambiguous candidates, raw names).

        One pass over the IMPORTS_FROM edges, with the expansions every
        resolver needs: C# namespaces, Go packages and Python dotted modules
        mapped back to the files that declare them.
        """
    def _import_evidence -> tuple[dict[str, set[str]], dict[str, set[str]], dict[str, dict[str, str]]];

    """The node lookups and import evidence bare resolution reads, cached.

        (names, owning classes, imported files, ambiguous imports, Ruby nodes,
        function languages, raw import names). A write drops the cache.
        """
    def _get_bare_endpoint_context(
        conn: sqlite3.Connection
    ) -> tuple[dict[str, list[tuple[str, str]]], dict[str, str
        | None], dict[str, set[str]], dict[str, set[str]], set[str], dict[str, str], dict[str, dict[str, str]]];

    """Resolve a bare edge endpoint only when one candidate has evidence."""
    def _resolve_bare_endpoints(kind: str, endpoint: str) -> int;

    def get_all_files -> list[str];

    """Return indexed file paths mapped to the hash last stored for each file."""
    def get_file_hashes -> dict[str, str];

    """Return paths that have authoritative File nodes.

        Reconciliation uses this to distinguish a graph anchored to another
        repository from orphan Function/Edge rows left by a failed update.
        """
    def get_file_marker_paths -> list[str];

    """Return nodes whose qualified symbol portion exactly matches *tail*.

        Both predicates are indexed equality tests (``idx_nodes_symbol`` and the
        ``qualified_name`` unique index), so this stays a bounded lookup rather
        than a scan of every node on large graphs.
        """
    def search_nodes_by_qualified_tail(tail: str, limit: int = 20) -> list[GraphNode];

    """Count nodes whose qualified symbol portion exactly matches *tail*."""
    def count_nodes_by_qualified_tail(tail: str) -> int;

    """Keyword search across node names.

        Tries FTS5 first (fast, tokenized matching), then falls back to
        LIKE-based substring search when FTS5 returns no results. Liquid
        ``Output`` nodes are left out: their names are the text a template
        prints, and on a theme they would crowd out every real match.
        """
    def search_nodes(query: str, limit: int = 20) -> list[GraphNode];

    """Count nodes using the same FTS-first semantics as ``search_nodes``."""
    def count_search_nodes(query: str) -> int;

    """Count exact-name nodes with optional language and kind filters."""
    def count_nodes_by_name(
        name: str, language: str | None = None, kinds: tuple[str, ...] = ()
    ) -> int;

    """Return every node with exactly this name, by qualified name."""
    def get_nodes_by_name(name: str) -> list[GraphNode];

    """Seed qualified names for the impact traversal.

        Includes every node in the changed files plus, for changed C#
        files, the namespaces they declare. C# ``using X.Y;`` directives
        store IMPORTS_FROM targets as raw namespace strings rather than
        file paths, so without these bridge seeds the traversal can never
        reach importers of a changed .cs file. The namespace strings have
        no node rows, so they act purely as bridges and never surface in
        results. See: #310

        Tree-scoped import targets are bridged the same way. A Ruby
        ``require_all "jekyll/converters"`` names a DIRECTORY, and a file
        two levels below it is still one of the files it loads, so the
        directory is seeded for the changed file. The one-level case -- a Go
        package, which is exactly one directory -- is not seeded here: the
        traversal expands it at every hop, so it also works for a file
        reached indirectly rather than only for a changed one.
        """
    def _impact_seed_qns(changed_files: list[str]) -> set[str];

    """Ancestor directories that a tree-scoped import target names.

        Only ancestors ABOVE each file's own directory: the own-directory
        case is handled by the traversal itself, which is what keeps it
        working at every hop instead of only for a seed.
        """
    def tree_scope_bridges(file_paths: Iterable[str]) -> set[str];

    """Directory-scoped IMPORTS_FROM edges that connect the given files.

        ``get_edges_among`` matches source and target against the same set of
        qualified names, and a directory target is in no such set, so these
        edges would otherwise be missing from the answer that rests on them.
        """
    def import_scope_edges(file_paths: Iterable[str], source_qns: set[str]) -> list[GraphEdge];

    """Directory target -> the qualified names that import it.

        Only the NetworkX engine needs this materialised. The SQL engine
        seeks the same rows one directory at a time through
        ``idx_edges_target_kind``.
        """
    def _import_scope_importer_index -> dict[str, list[str]];

    """File node qualified name -> the directory that holds it."""
    def _file_node_directories -> dict[str, str];

    """Count call sites that name *names* but were never bound to a node.

        These are the blast radius's blind spot: a CALLS/REFERENCES edge whose
        target is a bare name cannot join a qualified seed, so the traversal
        never follows it. The count is deliberately not receiver-filtered --
        that check needs a specific candidate node -- so it is an upper bound
        on missed impact, not a claim that every one of these is a real call.
        """
    def count_unresolved_call_sites(names: set[str]) -> int;

    """Calculate the impact radius (dependents and tests) of changed files within depth N.

        Delegates to ``get_impact_radius_sql()`` by default (faster for
        large graphs).  Set ``CRG_BFS_ENGINE=networkx`` to use the legacy
        Python-side BFS via NetworkX.

        Dependency-shaped edges propagate from target to source, while
        TESTED_BY propagates from production source to test target. CONTAINS
        does not expand the traversal because every node in a changed file is
        already seeded.

        Returns dict with:
          - changed_nodes: nodes in changed files
          - impacted_nodes: reachable nodes ordered by best-path impact score
          - impacted_files: unique set of affected files
          - edges: connecting edges
          - impact_scores: qualified name to best-path score

        ``resolution="direct"`` refuses to traverse a CALLS/REFERENCES edge
        whose target was never bound to an indexed node, so the answer rests
        only on attributions the graph can prove. It is a guard, not a
        reachability change: a bare target cannot equal a qualified seed, so
        an unresolved hop is already unreachable under both engines. The
        guard keeps that true if a future resolver leaves a dangling
        qualified target behind. ``IMPORTS_FROM`` is never filtered -- its
        targets are file paths and C# namespace bridges, for which
        "unresolved" would be a false claim.
        """
    def get_impact_radius(
        changed_files: list[str],
        max_depth: int = max_depth_default__,
        max_nodes: int = max_nodes_default_,
        resolution: str = "all",
    ) -> dict[str, Any];

    """Impact radius via bounded best-score relaxation in SQLite.

        Faster than NetworkX for large graphs because it avoids
        materialising the full graph in Python.
        """
    def get_impact_radius_sql(
        changed_files: list[str],
        max_depth: int = max_depth_default___,
        max_nodes: int = max_nodes_default__,
        resolution: str = "all",
    ) -> dict[str, Any];

    """BFS via NetworkX (legacy). Used when CRG_BFS_ENGINE=networkx."""
    def _get_impact_radius_networkx(
        changed_files: list[str],
        max_depth: int = max_depth_default____,
        max_nodes: int = max_nodes_default___,
        resolution: str = "all",
    ) -> dict[str, Any];

    """Extract a subgraph containing the specified nodes and their connecting edges."""
    def get_subgraph(qualified_names: list[str]) -> dict[str, Any];

    """Return aggregate statistics about the graph.

        Every statement below reads from one snapshot, so the per-kind
        breakdowns still sum to the totals when a watcher commits partway
        through (issue: `status` printing numbers that do not add up).
        """
    def get_stats -> GraphStats;

    def _get_stats_locked -> GraphStats;

    """Build the WHERE clause and parameters for a line-count range."""
    static def _nodes_by_size_filter(
        min_lines: int, max_lines: int | None, kind: str | None, file_path_pattern: str | None
    ) -> tuple[str, list];

    """Count what :meth:`get_nodes_by_size` would return without a limit."""
    def count_nodes_by_size(
        min_lines: int = 50,
        max_lines: int | None = None,
        kind: str | None = None,
        file_path_pattern: str | None = None,
    ) -> int;

    """Find nodes within a line-count range, ordered largest first.

        Args:
            min_lines: Minimum line count threshold (inclusive).
            max_lines: Maximum line count threshold (inclusive). None = no upper bound.
            kind: Filter by node kind (Function, Class, File, etc.).
            file_path_pattern: SQL LIKE pattern to filter by file path.
            limit: Maximum results to return.

        Returns:
            List of GraphNode objects, ordered by line count descending.
        """
    def get_nodes_by_size(
        min_lines: int = 50,
        max_lines: int | None = None,
        kind: str | None = None,
        file_path_pattern: str | None = None,
        limit: int = 50,
    ) -> list[GraphNode];

    """Fetch a single node by its integer primary key."""
    def get_node_by_id(node_id: int) -> Optional[GraphNode];

    """Return nodes matching any of *kinds*, optionally filtered by file.

        Args:
            kinds: List of node kind strings (e.g. ``["Function", "Test"]``).
            file_pattern: If provided, only nodes whose ``file_path``
                contains *file_pattern* (SQL LIKE ``%pattern%``) are
                returned.
        """
    def get_nodes_by_kind(kinds: list[str], file_pattern: str | None = None) -> list[GraphNode];

    """Return the number of flows a node participates in."""
    def count_flow_memberships(node_id: int) -> int;

    """Return criticality values for all flows a node participates in."""
    def get_flow_criticalities_for_node(node_id: int) -> list[float];

    """Entry-point node ids of the flows that contain any of *node_ids*."""
    def get_flow_entry_point_ids(node_ids: set[int]) -> set[int];

    """Return the ``community_id`` for a node, or ``None``."""
    def get_node_community_id(node_id: int) -> int | None;

    """Batch-fetch ``community_id`` for a list of qualified names.

        Returns a mapping from qualified name to community_id (may be
        ``None`` if the node has no assigned community).
        """
    def get_community_ids_by_qualified_names(qns: list[str]) -> dict[str, int | None];

    """Return distinct ``file_path`` values ending with *pattern*.

        Paths are normalized to POSIX separators first. ``%`` and ``_`` in
        *pattern* are treated as literal characters, not SQL ``LIKE``
        wildcards.
        """
    def get_files_matching(pattern: str) -> list[str];

    """Return raw rows for nodes that have no signature yet."""
    def get_nodes_without_signature -> list[sqlite3.Row];

    """Set the ``signature`` column for a single node."""
    def update_node_signature(node_id: int, signature: str) -> None;

    """Bulk-set ``signature`` for many nodes in one transaction.

        Hot paths (postprocessing, review builds) should use this instead of
        looping :meth:`update_node_signature`: the per-row loop autocommits
        one UPDATE per node (``isolation_level=None``), i.e. one WAL commit +
        fsync per row, which dominates runtime on graphs with 10^5+ nodes
        (issue #721).

        Args:
            signature_rows: ``(signature, node_id)`` pairs.
        """
    def update_node_signatures(signature_rows: list[tuple[str, int]]) -> None;

    """Return a mapping of *all* qualified names to their community_id.

        Used primarily by the visualization exporter.
        """
    def get_all_community_ids -> dict[str, int | None];

    """Return node IDs belonging to the given file paths."""
    def get_node_ids_by_files(file_paths: list[str]) -> set[int];

    """Return distinct flow IDs that contain any of *node_ids*."""
    def get_flow_ids_by_node_ids(node_ids: set[int]) -> list[int];

    """Return the set of qualified names for nodes in a flow."""
    def get_flow_qualified_names(flow_id: int) -> set[str];

    """Return just the ``kind`` column for a node, or ``None``."""
    def get_node_kind_by_id(node_id: int) -> str | None;

    """Return the set of all CALLS-edge target qualified names.

        When ``include_file_sources`` is False, CALLS edges whose source is a
        File node (module-scope calls from top-level script glue, CLI
        entrypoints, or notebook cells) are excluded. Callers that treat "has
        an incoming call" as "is not a root" (e.g. entry-point detection)
        should pass ``include_file_sources=False`` — otherwise a script-only
        callee looks called and is hidden from flow analysis.

        The File-node filter joins against ``nodes.kind`` rather than pattern-
        matching ``source_qualified`` so that file paths containing ``::`` or
        any future change to the File-node naming convention cannot silently
        miscategorize edges.
        """
    def get_all_call_targets(include_file_sources: bool = True) -> set[str];

    """Return CALLS targets with a caller that is neither test code nor a File."""
    def get_call_targets_outside_tests -> set[str];

    """Return raw rows from the ``communities`` table."""
    def get_communities_list -> list[sqlite3.Row];

    """Return qualified names of nodes in a community."""
    def get_community_member_qns(community_id: int) -> list[str];

    """Return all nodes belonging to a community."""
    def get_nodes_by_community_id(community_id: int) -> list[GraphNode];

    """Return ``target_qualified`` for edges sourced from *source_qns*."""
    def get_outgoing_targets(source_qns: list[str]) -> list[str];

    """Return ``source_qualified`` for edges targeting *target_qns*."""
    def get_incoming_sources(target_qns: list[str]) -> list[str];

    """Return all edges in the graph."""
    def get_all_edges -> list[GraphEdge];

    """Return edges where both source and target are in the given set.

        Batches the source-side IN clause to stay under SQLite's default
        SQLITE_MAX_VARIABLE_NUMBER limit, then filters targets in Python.
        """
    def get_edges_among(qualified_names: set[str]) -> list[GraphEdge];

    """Return edges whose stored source or target is in *names*, oldest first.

        Each edge appears once, in the order a read of the whole table gives.
        """
    def get_edges_touching(names: set[str]) -> list[GraphEdge];

    """Yield each distinct value of an edge end and how many edges have it.

        Reads an index rather than the edge rows, however large the table is.
        """
    def iter_edge_end_counts(column: str) -> Generator[any, any, any];

    """Yield the target of every edge leaving one of *sources*."""
    def iter_edge_targets_from(sources: Iterable[str]) -> Generator[any, any, any];

    """Return which of *file_paths* appear as the file of at least one edge."""
    def get_files_with_edges(file_paths: Iterable[str]) -> set[str];

    """Return whether any edge's file path still holds a backslash (before #774)."""
    def has_edge_with_backslash_path -> bool;

    """Yield the few columns that identify each node, in export order.

        ``listed`` follows the rule :meth:`get_all_files` uses to keep virtual
        nodes out of the file inventory.
        """
    def iter_node_identities -> Iterator[sqlite3.Row];

    """Batch-fetch nodes by qualified name, staying under SQLite variable limits."""
    def _batch_get_nodes(qualified_names: set[str]) -> list[GraphNode];

    """Fetch the nodes with these qualified names; unknown names are skipped."""
    def get_nodes_by_qualified_names(qualified_names: Iterable[str]) -> list[GraphNode];

    """``qualified_name -> (in_degree, out_degree)`` for every non-File node.

        Counts edges of every kind, which is the measure
        :func:`~code_review_graph.analysis.find_hub_nodes` ranks hubs by,
        without loading every edge into Python. ``include_tests=False``
        leaves out nodes marked as test code.
        """
    def get_node_degrees(*, include_tests: bool = True) -> dict[str, tuple[int, int]];

    """``id -> row`` with ``id``, ``name`` and ``size`` for these communities."""
    def get_communities_by_ids(ids: Iterable[int]) -> dict[int, sqlite3.Row];

    """Number of stored execution flows."""
    def count_flows -> int;

    """Load all nodes and CALLS/TESTED_BY edges into memory for fast traversal.

        Reads the entire ``nodes`` and ``edges`` tables in two streaming
        queries and returns an in-memory adjacency structure suitable for
        flow tracing and criticality scoring.  At ~500k nodes / 3M edges
        this fits in a few hundred MB and eliminates tens of millions of
        single-row SQLite point queries that otherwise dominate
        ``trace_flows`` / ``compute_criticality`` runtime.
        """
    def load_flow_adjacency -> "FlowAdjacency";

    """Build a directed graph with impact weights for both policies."""
    def _build_networkx_graph -> nx.DiGraph;

    def _make_qualified(`node: NodeInfo) -> str;

    def _row_to_node(row: sqlite3.Row) -> GraphNode;

    def _row_to_edge(row: sqlite3.Row) -> GraphEdge;
}

with entry {
    _NAME_CONTROL_CHARS = re.compile("[\\x00-\\x08\\x0b-\\x1f]");
}

"""Strip ASCII control characters and truncate to prevent prompt injection.

    Node names extracted from source code could contain adversarial strings
    (e.g. ``IGNORE_ALL_PREVIOUS_INSTRUCTIONS``).  This function removes control
    characters (0x00-0x1F except tab and newline) and enforces a length limit so
    that names flowing through MCP tool responses cannot easily influence AI
    agent behaviour.
    """
def _sanitize_name(s: str, max_len: int = 256) -> str;

def node_to_dict(n: GraphNode) -> dict;

def edge_to_dict(e: GraphEdge) -> dict;

def __getattr__(name: str) -> Any;
