import from __future__ { annotations }

import builtins;

import operator;

import typing;

import logging;

import re;

import from collections { defaultdict, deque }

import from pathlib { Path }

import from typing { Any }

glob logger: any;

glob _MAX_IMPACT_NODES_SHOWN: any;

glob _MAX_IMPACT_EDGES: any;

glob _MAX_IMPACT_FILES: any;

glob _MAX_SEARCH_RESULTS_STANDARD: any;

glob _MAX_SEARCH_RESULTS_MINIMAL: any;

glob _MAX_LARGE_FUNCTIONS_STANDARD: any;

glob _MAX_LARGE_FUNCTIONS_MINIMAL: any;

glob _MAX_TRAVERSAL_TOKEN_BUDGET: any;

glob _SEARCH_WINDOW_FACTOR: any;

glob _MAX_SEARCH_SOURCE_LINES: any;

glob _MAX_SEARCH_SOURCE_LINES_PER_NODE: any;

glob _MAX_EXPANDED_SOURCE_LINES: any;

glob _MAX_EXPANDED_HITS: any;

glob _MAX_NEIGHBORS_PER_HIT: any;

glob _MAX_SEARCH_SOURCE_CHARS: any;

glob _MAX_SEARCH_SOURCE_CHARS_PER_NODE: any;

glob _SANITIZED_NAME_MAX: any;

glob _QUERY_PATTERNS: any;

glob _JAVA_FQN_PART: any;

glob _TEST_BLOCK_NAME: any;

glob _MAX_DOTTED_TARGET_CANDIDATES: any;

glob _MAX_BARE_TARGET_CANDIDATES: any;

glob _CALL_SITE_PATTERNS: any;

glob _HOP_CERTAINTY: any;

glob _HOP_DIRECT: any;

glob _HOP_UNIQUE_NAME: any;

glob _HOP_SHARED_NAME: any;

glob _ROUTE_EDGE_KINDS: any;

glob _NAME_MATCH_EDGE_KINDS: any;

glob _MAX_NAME_MATCH_CANDIDATES: any;

glob _MAX_ROUTE_VISITS: any;

glob _MAX_ROUTE_HOPS: any;

glob _Hop: any;

glob _Route: any;

glob _CANDIDATE_KEYS: any;

with entry {
    logger = logging.getLogger(__name__);
    _MAX_IMPACT_NODES_SHOWN = 100;
    _MAX_IMPACT_EDGES = 150;
    _MAX_IMPACT_FILES = 200;
    _MAX_SEARCH_RESULTS_STANDARD = 100;
    _MAX_SEARCH_RESULTS_MINIMAL = 5;
    _MAX_LARGE_FUNCTIONS_STANDARD = 100;
    _MAX_LARGE_FUNCTIONS_MINIMAL = 25;
    _MAX_TRAVERSAL_TOKEN_BUDGET = 10000;
    _SEARCH_WINDOW_FACTOR = 3;
    _MAX_SEARCH_SOURCE_LINES = 240;
    _MAX_SEARCH_SOURCE_LINES_PER_NODE = 60;
    _MAX_EXPANDED_SOURCE_LINES = 700;
    _MAX_EXPANDED_HITS = 3;
    _MAX_NEIGHBORS_PER_HIT = 4;
    _MAX_SEARCH_SOURCE_CHARS = 80000;
    _MAX_SEARCH_SOURCE_CHARS_PER_NODE = 12000;
    _SANITIZED_NAME_MAX = 256;
    _QUERY_PATTERNS = QUERY_PATTERNS;

    _JAVA_FQN_PART = re.compile("^[A-Za-z_$][A-Za-z0-9_$]*$");
    _TEST_BLOCK_NAME = re.compile("@L\\d+$");
    _MAX_DOTTED_TARGET_CANDIDATES = 100;
    _MAX_BARE_TARGET_CANDIDATES = 20;
    _CALL_SITE_PATTERNS = frozenset({"callers_of", "callees_of", "references_to"});
}

def _attach_call_site(result: dict[str, Any], `edge: GraphEdge) -> dict[str, Any];
def _interleave_call_sites(
    sites: list[tuple[str, dict[str, Any], GraphEdge]]
) -> list[tuple[dict[str, Any], GraphEdge]];
def _test_is_named_after(`test: GraphNode, name: str) -> bool;
def _looks_like_java_method_fqn(target: str) -> bool;
def _java_fqn_candidates(store: GraphStore, target: str) -> list[GraphNode] | None;
def _namespaced_member_candidates(store: GraphStore, target: str) -> list[GraphNode];
def _exact_name_candidates(
    store: GraphStore, `root: Path, target: str
) -> tuple[list[GraphNode], int];
def _selectable_qualified_name(`node: GraphNode, `root: Path) -> str;
def _rank_disambiguation_candidates(
    candidates: list[GraphNode], target: str, `root: Path
) -> list[dict[str, Any]];
def _compact_impact_response(
    result: dict[str, Any],
    `root: Path,
    changed_files: list[str],
    unmatched_files: list[str],
    max_files: int,
    resolution: str,
    unresolved_call_sites: int,
) -> dict[str, Any];

with entry {
    _HOP_CERTAINTY = ("direct", "unique_name", "shared_name");
    (_HOP_DIRECT, _HOP_UNIQUE_NAME, _HOP_SHARED_NAME) = range(len(_HOP_CERTAINTY)) as any;
    _ROUTE_EDGE_KINDS = frozenset({
        "CALLS",
        "REFERENCES",
        "INHERITS",
        "IMPLEMENTS",
        "IMPORTS_FROM",
        "CONTAINS",
    });
    _NAME_MATCH_EDGE_KINDS = frozenset({"CALLS", "REFERENCES", "INHERITS", "IMPLEMENTS"});
    _MAX_NAME_MATCH_CANDIDATES = 10;
    _MAX_ROUTE_VISITS = 200000;
    _MAX_ROUTE_HOPS = 30;

    _Hop = builtins.tuple[str, int, GraphEdge];
    _Route = typing.List[typing.Tuple[str, str, int, GraphEdge]];
    _CANDIDATE_KEYS = (
        ("ambiguous_targets", "ambiguous_target_count"),
        ("unresolved_targets", "unresolved_target_count"),
    );
}

obj _RouteGraph {
    has _store: any,
        _root: any,
        _nodes: any,
        _by_name: any,
        _direct: any,
        _all: any,
        _edges: any;

    def init(store: GraphStore, `root: Path);

    def `node(qualified_name: str) -> GraphNode | None;

    def _is_test(`node: GraphNode) -> bool;

    def _edges_from(qualified_name: str) -> list[GraphEdge];

    def _named(name: str) -> list[GraphNode];
    def _name_matches(`edge: GraphEdge, source: GraphNode) -> list[GraphNode];

    def _guessed_hops(`edge: GraphEdge, source: GraphNode) -> list[_Hop];

    static def _ordered(hops: list[_Hop]) -> list[_Hop];
    def hops_from(qualified_name: str, weakest_allowed: int) -> list[_Hop];
    def _search(source: str, target: str, weakest_allowed: int) -> tuple[_Route | None, bool];
    def route(source: str, target: str) -> tuple[_Route | None, bool];

    def __repr__ -> str;

    def __eq__(other: any) -> bool;

    def __hash__ -> int;
}

def _route_endpoint_candidates(
    store: GraphStore, `root: Path, `graph: _RouteGraph, name: str
) -> tuple[list[GraphNode], int];
def _unresolved_route_endpoint(
    store: GraphStore,
    `root: Path,
    name: str,
    which: str,
    candidates: list[GraphNode],
    count: int,
    minimal: bool,
) -> dict[str, Any];
def _query_route(
    store: GraphStore, `root: Path, target: str, to: str, minimal: bool
) -> dict[str, Any];

glob max_results_default_: any;

glob resolution_default_: any;

with entry {
    max_results_default_ = MAX_IMPACT_NODES;
    resolution_default_ = RESOLUTION_ALL;
}

def get_impact_radius(
    changed_files: list[str] | None = None,
    max_depth: int = 2,
    max_results: int = max_results_default_,
    repo_root: str | None = None,
    base: str = "HEAD~1",
    detail_level: str = "standard",
    resolution: str = resolution_default_,
    max_files: int = 25,
) -> dict[str, Any];

glob resolution_default__: any;

with entry {
    resolution_default__ = RESOLUTION_ALL;
}

def query_graph(
    pattern: str,
    target: str,
    repo_root: str | None = None,
    detail_level: str = "standard",
    max_results: int = 100,
    resolution: str = resolution_default__,
    to: str | None = None,
) -> dict[str, Any];

obj _SourceBudget {
    has _root: any,
        _followed: any,
        _left: any,
        _chars_left: any,
        _per_node: any,
        _files: any,
        omitted: any;

    def init(`root: Path, total: int, per_node: int, followed: set[str] | None = None);

    has exhausted: bool {
        getter {
            return operator.le(self._left, 0) or operator.le(self._chars_left, 0);
        }
    }

    def _lines(raw_path: str) -> list[str];
    def attach(target: dict[str, Any], raw_path: Any, start: Any, end: Any) -> bool;

    def __repr__ -> str;

    def __eq__(other: any) -> bool;

    def __hash__ -> int;
}

def _neighbor_entry(`node: GraphNode) -> dict[str, Any];
def _stored_qualified_name(store: GraphStore, hit: dict[str, Any]) -> str | None;
def _attach_neighbors(results: list[dict[str, Any]], store: GraphStore, budget: _SourceBudget);

glob max_source_lines_default_: any;

with entry {
    max_source_lines_default_ = _MAX_SEARCH_SOURCE_LINES_PER_NODE;
}

def semantic_search_nodes(
    query: str,
    kind: str | None = None,
    limit: int = 20,
    repo_root: str | None = None,
    context_files: list[str] | None = None,
    model: str | None = None,
    provider: str | None = None,
    detail_level: str = "standard",
    include_source: bool = False,
    expand_neighbors: bool = False,
    max_source_lines: int = max_source_lines_default_,
) -> dict[str, Any];
def list_graph_stats(repo_root: str | None = None) -> dict[str, Any];
def find_large_functions(
    min_lines: int = 50,
    kind: str | None = None,
    file_path_pattern: str | None = None,
    limit: int = 50,
    repo_root: str | None = None,
    detail_level: str = "standard",
) -> dict[str, Any];
def traverse_graph_func(
    query: str,
    mode: str = "bfs",
    depth: int = 3,
    token_budget: int = 2000,
    repo_root: str | None = None,
) -> dict[str, Any];
