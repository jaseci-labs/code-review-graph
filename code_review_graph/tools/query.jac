"""Tools 2, 3, 5, 6, 9: query / search / stats helpers."""

import builtins;

import operator;

import from __future__ { annotations }

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

"""Record where the call is written, not just who writes it.

    Every edge carries a file and a line. Without them on the row a reading
    agent has a caller's name and must open the file to find the call, which
    is the file read the graph exists to avoid.

    ``file`` is present only when the call is written somewhere other than the
    row's own ``file_path``: a repeated path is the single most expensive
    string in a row, and the reader already has it on the same object, so
    omitting the duplicate is lossless. Where the two differ -- a header, a
    generated file, a mixin applied elsewhere -- the path is spelled out, so a
    call is never silently mislocated. Read it as
    ``call_site.get("file", row["file_path"])``.
    """
def _attach_call_site(result: dict[str, Any], `edge: GraphEdge) -> dict[str, Any];

"""Order call sites so every distinct node is seen before any repeat.

    One row per call site is what makes repeated calls visible, but it would
    let a caller that calls the target forty times consume the whole
    ``max_results`` window and hide every other caller. Emitting the first
    call site of each node, then the second of each, keeps the truncated
    prefix as wide as the un-truncated answer while still reporting repeats.
    Within a round, calls bound to a real node come before guesses, or a few
    bare ``len`` calls would fill the window and hide the real callee. The rest
    of the order is first-seen, so the result stays deterministic.
    """
def _interleave_call_sites(
    sites: list[tuple[str, dict[str, Any], GraphEdge]]
) -> list[tuple[dict[str, Any], GraphEdge]];

"""Whether a naming-convention hit really is named after *name*.

    A test block's name holds free text, so ``it "tests json output"`` also hits
    a search for ``test_json``. Only its file can speak for a block.
    """
def _test_is_named_after(`test: GraphNode, name: str) -> bool;

"""Return whether *target* has a package/Class/method-like shape."""
def _looks_like_java_method_fqn(target: str) -> bool;

"""Resolve Java FQNs using language plus class/file evidence.

    ``None`` means that the target is not Java-FQN-shaped. An empty list means
    it is shaped like one but no safe match exists, so callers must not fall
    back to an unrelated globally unique method name.
    """
def _java_fqn_candidates(store: GraphStore, target: str) -> list[GraphNode] | None;

"""Resolve ``Class.method`` to a Ruby or C# method whose type sits in a namespace.

    Ruby and C# symbols carry the whole namespace (``Billing.Base.audit``,
    ``Lib.Service.Run``), so the exact qualified-tail lookup misses the short
    form people actually type.
    """
def _namespaced_member_candidates(store: GraphStore, target: str) -> list[GraphNode];

"""Return the nodes a bare *target* names exactly, and the tests set aside.

    The full-text index tokenises, so ``hybrid_search`` also hits every
    ``test_hybrid_search_*``. A name written in full means that name. A test or
    test helper with the same name gives way to the real symbol; when only test
    symbols have the name, they are the answer.
    """
def _exact_name_candidates(
    store: GraphStore, `root: Path, target: str
) -> tuple[list[GraphNode], int];

"""Return a qualified name that still selects *node* when sent back.

    A long checkout path can push a name past the cut ``_sanitize_name`` makes,
    and a cut name selects nothing. ``query_graph`` also reads a name relative
    to the repo root, which is much shorter.
    """
def _selectable_qualified_name(`node: GraphNode, `root: Path) -> str;

"""Return deterministic, sanitized candidates ordered by match quality."""
def _rank_disambiguation_candidates(
    candidates: list[GraphNode], target: str, `root: Path
) -> list[dict[str, Any]];

"""Project the radius onto files without serializing its graph records."""
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

"""The graph as hops, read only as far as the search walks.

    Nodes and outgoing edges come from indexed lookups when first reached.
    ``nodes.name`` has no index, so the bare-name table is read once, and only
    when a route has to guess at a name.
    """
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

    """The nodes a bare edge target could mean, by the rules callers_of uses."""
    def _name_matches(`edge: GraphEdge, source: GraphNode) -> list[GraphNode];

    def _guessed_hops(`edge: GraphEdge, source: GraphNode) -> list[_Hop];

    static def _ordered(hops: list[_Hop]) -> list[_Hop];

    """Every hop out of a node, in a fixed order, strongest first.

        Name guesses are worked out only once a search allows them.
        """
    def hops_from(qualified_name: str, weakest_allowed: int) -> list[_Hop];

    """Breadth-first search; also say whether it stopped at the visit limit."""
    def _search(source: str, target: str, weakest_allowed: int) -> tuple[_Route | None, bool];

    """The route whose weakest hop is strongest; the shortest of those.

        Trying each level in turn means a longer route through bound edges is
        preferred to a shorter one that guesses at a name. A level that stops at
        the visit limit has not ruled out a stronger route, so the search ends
        there and says it is incomplete rather than settle for a weaker one.
        """
    def route(source: str, target: str) -> tuple[_Route | None, bool];

    def __repr__ -> str;

    def __eq__(other: any) -> bool;

    def __hash__ -> int;
}

"""Return the nodes *name* could mean and how many there are in all."""
def _route_endpoint_candidates(
    store: GraphStore, `root: Path, `graph: _RouteGraph, name: str
) -> tuple[list[GraphNode], int];

"""Say which end of a route could not be pinned down, and why."""
def _unresolved_route_endpoint(
    store: GraphStore,
    `root: Path,
    name: str,
    which: str,
    candidates: list[GraphNode],
    count: int,
    minimal: bool,
) -> dict[str, Any];

"""Answer ``path_to``: how *target* reaches *to*, and how sure that is."""
def _query_route(
    store: GraphStore, `root: Path, target: str, to: str, minimal: bool
) -> dict[str, Any];

glob max_results_default_: any;

glob resolution_default_: any;

with entry {
    max_results_default_ = MAX_IMPACT_NODES;
    resolution_default_ = RESOLUTION_ALL;
}

"""Analyze the blast radius of changed files.

    Args:
        changed_files: Explicit list of changed file paths (relative to repo root).
                       If omitted, auto-detects from git diff.
        max_depth: How many hops to traverse in the graph (default: 2).
        max_results: Maximum impacted nodes to return (default:
            ``CRG_MAX_IMPACT_NODES``, or 500).
        repo_root: Repository root path. Auto-detected if omitted.
        base: Git ref for auto-detecting changes (default: HEAD~1).
        detail_level: "standard" (full output), "minimal" (summary only),
                      or "compact" (ranked file paths and counts, no node/edge records).
        max_files: Compact-mode file display limit (default: 25, hard ceiling: 200).
                   Independent of max_results, so it does not shrink the traversal.
        resolution: "all" (default) traverses every edge; "direct" refuses to
            traverse a CALLS/REFERENCES edge whose target was never bound to
            an indexed node.

    Returns:
        Changed nodes, impacted nodes, impacted files, connecting edges,
        plus ``truncated`` flag and ``total_impacted`` count. An impacted node
        that calls or references the changed code directly also carries the
        ``call_site`` it does so at, and ``unresolved_call_sites`` counts the
        call sites that name a changed symbol but were never bound to it.
    """
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

"""Run a predefined graph query.

    Args:
        pattern: Query pattern. One of: callers_of, references_to, callees_of,
                 imports_of, importers_of, children_of, tests_for, inheritors_of,
                 triggers_of, triggered_by, publishers_of, listeners_of,
                 handlers_of, endpoints_for, consumers_of, advises, advised_by,
                 file_summary, path_to.
        target: The node name, qualified name, or file path to query about.
        repo_root: Repository root path. Auto-detected if omitted.
        detail_level: "standard" (full output) or "minimal" (summary only).
        max_results: Maximum results to return. Minimal mode additionally caps
            visible results at five and reports the exact omitted count.
        resolution: For callers_of/callees_of/references_to, filter rows by how
            certain the edge's target attribution is. "all" (default) keeps
            both, "direct" keeps only calls bound to an indexed node, and
            "unresolved" keeps only the bare-name matches.
        to: For path_to, the node, qualified name or file to reach. A route is one
            answer, so max_results and the minimal cap do not cut it.

    Returns:
        Matching nodes and their aligned edges, with total and omitted counts.
        For callers_of, callees_of and references_to each row also carries the
        ``call_site`` it was found at, one row per call site rather than one
        per node, plus a ``resolution_split`` saying how much of the answer is
        certain.
    """
def query_graph(
    pattern: str,
    target: str,
    repo_root: str | None = None,
    detail_level: str = "standard",
    max_results: int = 100,
    resolution: str = resolution_default__,
    to: str | None = None,
) -> dict[str, Any];

"""Hands out source snippets until a shared line budget runs out.

    One budget is shared by the hits and by any neighbours expanded from
    them, so a response cannot grow without bound no matter how many edges a
    hot symbol has. Files are read once and reused.
    """
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

    """Attach ``source`` to *target*; return whether anything was added."""
    def attach(target: dict[str, Any], raw_path: Any, start: Any, end: Any) -> bool;

    def __repr__ -> str;

    def __eq__(other: any) -> bool;

    def __hash__ -> int;
}

def _neighbor_entry(`node: GraphNode) -> dict[str, Any];

"""Return the name edges are keyed on; a hit's own may be cut for display."""
def _stored_qualified_name(store: GraphStore, hit: dict[str, Any]) -> str | None;

"""Attach each top hit's direct callers and callees, with their source.

    A question about how a symbol works is usually answered by the symbol
    plus what calls it and what it calls, so returning those here is what
    stops the caller opening the same files by hand.
    """
def _attach_neighbors(
    results: list[dict[str, Any]], store: GraphStore, budget: _SourceBudget
) -> None;

glob max_source_lines_default_: any;

with entry {
    max_source_lines_default_ = _MAX_SEARCH_SOURCE_LINES_PER_NODE;
}

"""Search for nodes by name, keyword, or semantic similarity.

    Uses hybrid search (FTS5 BM25 + vector embeddings merged via Reciprocal
    Rank Fusion) as the primary search path, with graceful fallback to
    keyword matching.

    Args:
        query: Search string to match against node names and qualified names.
        kind: Optional filter by node kind (File, Class, Function, Type, Test).
        limit: Maximum results to return (default: 20, at most 100, or 5
            with detail_level "minimal").
        repo_root: Repository root path. Auto-detected if omitted.
        context_files: Optional list of file paths. Nodes in these files
            receive a relevance boost.
        detail_level: "standard" (full output) or "minimal" (summary only).
        include_source: Attach the source of each hit, so the caller can
            answer from the response instead of opening the files itself.
            Off by default: it costs tokens, and a caller that only wants
            locations should not pay for them.
        expand_neighbors: With include_source, also return the direct callers
            and callees of the top hits, each with their own source. This is
            what lets a caller answer "how does X work" from one response
            instead of opening those files itself.
        max_source_lines: Per-node snippet cap when include_source is set.
            The response is additionally capped in total.

    Returns:
        Ranked list of matching nodes. ``total`` and ``result_count`` count the
        matches that were ranked, ``results_omitted`` those not shown, and
        ``total_is_lower_bound`` says there may be more than were ranked.
    """
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

"""Get aggregate statistics about the knowledge graph.

    Args:
        repo_root: Repository root path. Auto-detected if omitted.

    Returns:
        Total nodes, edges, breakdown by kind, languages, and last update time.
    """
def list_graph_stats(repo_root: str | None = None) -> dict[str, Any];

"""Find functions, classes, or files exceeding a line-count threshold.

    Useful for identifying decomposition targets, code-quality audits,
    and enforcing size limits during code review.

    Args:
        min_lines: Minimum line count to flag (default: 50).
        kind: Filter by node kind: Function, Class, File, or Test.
        file_path_pattern: Filter by file path substring (e.g. "components/").
        limit: Maximum results (default: 50, at most 100, or 25 with
            detail_level "minimal").
        repo_root: Repository root path. Auto-detected if omitted.
        detail_level: "standard" (full rows) or "minimal" (fewer, smaller rows).

    Returns:
        Oversized nodes with line counts, ordered largest first. ``total``,
        ``total_found`` and ``result_count`` are the count before the cut.
    """
def find_large_functions(
    min_lines: int = 50,
    kind: str | None = None,
    file_path_pattern: str | None = None,
    limit: int = 50,
    repo_root: str | None = None,
    detail_level: str = "standard",
) -> dict[str, Any];

"""BFS/DFS traversal from best-matching node.

    Args:
        query: Search string to find the starting node.
        mode: "bfs" (breadth-first) or "dfs" (depth-first).
        depth: Max traversal depth (1-6). Default: 3.
        token_budget: Approximate token limit for results, at most 10,000. The
            walk stops when it runs out, so a small budget does little work and
            ``truncated`` means there was more.
        repo_root: Repository root path.
    """
def traverse_graph_func(
    query: str,
    mode: str = "bfs",
    depth: int = 3,
    token_budget: int = 2000,
    repo_root: str | None = None,
) -> dict[str, Any];
