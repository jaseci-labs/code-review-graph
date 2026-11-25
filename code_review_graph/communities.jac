"""Community/cluster detection for the code knowledge graph.

Detects communities of related code nodes using the Leiden algorithm (via igraph,
optional) with a file-based grouping fallback when igraph is not installed.
"""

import operator;

import from __future__ { annotations }

import importlib.util;

import logging;

import random;

import re;

import from collections { Counter, defaultdict, namedtuple }

import from collections.abc { Sequence }

import from pathlib { Path }

import from typing { Any }

glob _CommunityEdge: any;

glob _LEIDEN_SEED: any;

glob logger: any;

glob _SQL_BATCH: any;

glob _SLUG_MAX_LEN: any;

glob IGRAPH_AVAILABLE: any;

glob ig: Any;

glob DETECTOR_METADATA_KEY: any;

glob DETECTOR_LEIDEN: any;

glob DETECTOR_FILE: any;

glob EDGE_WEIGHTS: dict[str, float];

glob _COMMON_WORDS: any;

glob _TEST_COMMUNITY_RE: any;

with entry {
    _CommunityEdge = namedtuple("_CommunityEdge", ("kind", "source_qualified", "target_qualified"));
    _LEIDEN_SEED = 42;

    logger = logging.getLogger(__name__);
    _SQL_BATCH = 450;
    _SLUG_MAX_LEN = 30;

    IGRAPH_AVAILABLE = importlib.util.find_spec("igraph") is not None;
    ig = None;
    DETECTOR_METADATA_KEY = "community_detector";
    DETECTOR_LEIDEN = "leiden";
    DETECTOR_FILE = "file";

    EDGE_WEIGHTS = {
        "CALLS": 1.0,
        "IMPORTS_FROM": 0.5,
        "INHERITS": 0.8,
        "IMPLEMENTS": 0.7,
        "CONTAINS": 0.3,
        "TESTED_BY": 0.4,
        "DEPENDS_ON": 0.6,
    };
    _COMMON_WORDS = frozenset({
        "get",
        "set",
        "self",
        "init",
        "new",
        "create",
        "update",
        "delete",
        "add",
        "remove",
        "make",
        "build",
        "from",
        "to",
        "for",
        "with",
        "the",
        "and",
        "test",
        "main",
        "run",
        "do",
        "is",
        "has",
        "on",
        "of",
        "in",
        "at",
        "by",
        "my",
        "this",
        "that",
        "all",
        "none",
        "should",
        "when",
        "then",
        "given",
        "return",
        "returns",
        "raise",
        "raises",
        "expect",
        "expected",
        "assert",
        "tests",
        "be",
        "it",
        "if",
        "not",
    });
}

"""Return whether a graph node represents test code."""
def _is_test_node(`node: GraphNode) -> bool;

"""Prefer production nodes as the source of community name vocabulary."""
def _naming_members(members: list[GraphNode]) -> list[GraphNode];

"""Generate a meaningful name for a community of nodes.

    Algorithm:
    1. Find most common module/file prefix among members
    2. If a dominant class exists (>40% of nodes), use its name
    3. Fallback: most frequent keyword in function/class names
    4. Format: "{prefix}-{keyword}"
    """
def _generate_community_name(members: list[GraphNode]) -> str;

"""Find the most common short directory or module name from file paths."""
def _extract_file_prefix(file_paths: list[str]) -> str;

"""Extract the most frequent meaningful keywords from member names."""
def _extract_keywords(members: list[GraphNode]) -> list[str];

"""Split a camelCase or snake_case name into words."""
def _split_name(name: str) -> list[str];

"""Convert a string to a short lowercase slug at a word boundary."""
def _to_slug(s: str) -> str;

"""Compute cohesion for multiple communities in a single O(edges) pass.

    Builds a ``qualified_name -> community_index`` reverse map (each node
    appears in at most one community since all callers produce partitions),
    then walks every edge exactly once, bucketing it into internal/external
    counters per community.

    Total work: O(edges + sum(|members|)) instead of
    O(edges * communities) for naive per-community cohesion.

    Returns a list of cohesion scores aligned with ``community_member_qns``.
    """
def _compute_cohesion_batch(
    community_member_qns: list[set[str]], all_edges: Sequence[GraphEdge | _CommunityEdge]
) -> list[float];

"""Build adjacency list from edges (one pass over all edges)."""
def _build_adjacency(edges: Sequence[GraphEdge | _CommunityEdge]) -> dict[str, list[str]];

"""Compute cohesion: internal_edges / (internal_edges + external_edges).

    For multiple communities, prefer :func:`_compute_cohesion_batch`, which
    runs in O(edges) total instead of O(edges) per community.
    """
def _compute_cohesion(
    member_qns: set[str],
    all_edges: Sequence[GraphEdge | _CommunityEdge],
    adj: dict[str, list[str]] | None = None,
) -> float;

"""Move tests to the community containing most unique tested subjects.

    Edge direction is ignored, ambiguous bare names are skipped, ties retain
    the current cluster, and rebuilding from the original partition keeps the
    result deterministic without repeated linear-time list removals.
    """
def _reassign_test_nodes(
    clusters: list[list[int]],
    idx_to_node: dict[int, GraphNode],
    qn_to_idx: dict[str, int],
    edges: Sequence[GraphEdge | _CommunityEdge],
    resolution_nodes: list[GraphNode] | None = None,
) -> list[list[int]];

"""Import igraph lazily; a failed import disables the package for good.

    ``find_spec("igraph")`` only proves the package directory exists. The
    import itself can still fail when a native dependency is missing, so the
    flag is cleared here and every caller falls back to file-based grouping
    instead of returning an empty community set.
    """
def _load_igraph -> bool;

"""Detect communities using Leiden algorithm via igraph.

    Caps Leiden at ``n_iterations=2`` (sufficient for code dependency graphs)
    and skips the recursive sub-community splitting pass that caused
    exponential blow-up on large repos (>100k nodes).
    """
def _detect_leiden(
    nodes: list[GraphNode],
    edges: Sequence[GraphEdge | _CommunityEdge],
    min_size: int,
    adj: dict[str, list[str]] | None = None,
) -> list[dict[str, Any]];

"""Group nodes by directory when Leiden is unavailable or over-fragments.

    Strips the longest common directory prefix from all file paths, then
    adaptively picks a grouping depth that yields 10-200 communities.
    """
def _detect_file_based(
    nodes: list[GraphNode],
    edges: Sequence[GraphEdge | _CommunityEdge],
    min_size: int,
    adj: dict[str, list[str]] | None = None,
) -> list[dict[str, Any]];

"""Recursively split communities that exceed threshold_pct of total.

    Uses Leiden on the subgraph of oversized communities. If igraph is
    not available, returns communities unchanged.
    """
def _split_oversized(
    communities: list[dict],
    nodes: list[GraphNode],
    edges: Sequence[GraphEdge | _CommunityEdge],
    threshold_pct: float = 0.25,
    min_split_size: int = 10,
) -> list[dict];

"""Disambiguate exact duplicate names while keeping the largest unchanged."""
def _dedupe_community_names(communities: list[dict[str, Any]], nodes: list[GraphNode]) -> None;

"""Detect communities in the code graph.

    Uses the Leiden algorithm via igraph if available, otherwise falls back to
    file-based grouping.

    Args:
        store: The GraphStore instance.
        min_size: Minimum number of nodes for a community to be included.

    Returns:
        List of community dicts with keys: name, level, size, cohesion,
        dominant_language, description, members, member_qns.
    """
def detect_communities(store: GraphStore, min_size: int = 2) -> list[dict[str, Any]];

"""Capture ``qualified_name -> community_id`` for nodes in *file_paths*.

    Must run **before** node replacement so assignments can be remapped onto
    the new node rows after IDs churn (#569).
    """
def capture_community_assignments(store: GraphStore, file_paths: list[str]) -> dict[str, int];

"""Re-apply captured community IDs onto current nodes by qualified name.

    Returns the number of nodes updated.
    """
def remap_community_assignments(store: GraphStore, community_by_qn: dict[str, int]) -> int;

"""Delete community rows that no longer have any assigned nodes.

    Also refreshes ``size`` for communities that still have members so
    incremental deletion stays consistent with a fresh full rebuild.
    Returns the number of empty community rows removed.
    """
def purge_empty_communities(store: GraphStore) -> int;

"""Re-detect communities only if changed files affect existing communities.

    If no existing communities contain nodes from changed files, skips
    re-detection unless changed files contain unassigned code nodes. That
    happens for a file new to the graph, which was in no community to be
    affected, and for a re-parsed file whose nodes were inserted without
    their old assignment. In that case, re-run full community detection to
    assign the new nodes, as a clean build would.

    Args:
        store: The GraphStore instance.
        changed_files: List of file paths that have changed.
        min_size: Minimum number of nodes for a community to be included.
        repo_root: Optional repo root used to expand relative/absolute paths.
        force: When True, always re-run detection (used after pre-replacement
            capture showed communities were affected even if path matching
            would otherwise miss them).

    Returns:
        Number of communities detected, or 0 if skipped.
    """
def incremental_detect_communities(
    store: GraphStore,
    changed_files: list[str],
    min_size: int = 2,
    repo_root: str | Path | None = None,
    force: bool = False,
) -> int;

"""Store detected communities in the database.

    Clears existing communities and community_id assignments, then inserts
    the new communities and updates node community_id references.

    Args:
        store: The GraphStore instance.
        communities: List of community dicts from detect_communities().

    Returns:
        Number of communities stored.
    """
def store_communities(store: GraphStore, communities: list[dict[str, Any]]) -> int;

"""Retrieve stored communities from the database.

    Args:
        store: The GraphStore instance.
        sort_by: Column to sort by ("size", "cohesion", "name").
        min_size: Minimum community size to include.
        members_by_community: Members to report for each community id, for a
            caller that only wants some of them. Saves one query per community.

    Returns:
        List of community dicts.
    """
def get_communities(
    store: GraphStore,
    sort_by: str = "size",
    min_size: int = 0,
    members_by_community: dict[int, list[str]] | None = None,
) -> list[dict[str, Any]];

with entry {
    _TEST_COMMUNITY_RE = re.compile(
        "(^test[-/]|[-/]test([:/]|$)|it:should|describe:|spec[-/]|[-/]spec$)", re.IGNORECASE
    );
}

"""Return True if a community name indicates it is test-dominated."""
def _is_test_community(name: str) -> bool;

"""Generate an architecture overview based on community structure.

    Builds a node-to-community mapping, counts cross-community edges,
    and generates warnings for high coupling.

    Args:
        store: The GraphStore instance.

    Returns:
        Dict with keys: communities, cross_community_edges, warnings.
    """
def get_architecture_overview(store: GraphStore) -> dict[str, Any];
