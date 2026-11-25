import from __future__ { annotations }

import importlib;

import operator;

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

def _is_test_node(`node: GraphNode) -> bool;
def _naming_members(members: list[GraphNode]) -> list[GraphNode];
def _generate_community_name(members: list[GraphNode]) -> str;
def _extract_file_prefix(file_paths: list[str]) -> str;
def _extract_keywords(members: list[GraphNode]) -> list[str];
def _split_name(name: str) -> list[str];
def _to_slug(s: str) -> str;
def _compute_cohesion_batch(
    community_member_qns: list[set[str]], all_edges: Sequence[GraphEdge | _CommunityEdge]
) -> list[float];
def _build_adjacency(edges: Sequence[GraphEdge | _CommunityEdge]) -> dict[str, list[str]];
def _compute_cohesion(
    member_qns: set[str],
    all_edges: Sequence[GraphEdge | _CommunityEdge],
    adj: dict[str, list[str]] | None = None,
) -> float;
def _reassign_test_nodes(
    clusters: list[list[int]],
    idx_to_node: dict[int, GraphNode],
    qn_to_idx: dict[str, int],
    edges: Sequence[GraphEdge | _CommunityEdge],
    resolution_nodes: list[GraphNode] | None = None,
) -> list[list[int]];
def _load_igraph -> bool;
def _detect_leiden(
    nodes: list[GraphNode],
    edges: Sequence[GraphEdge | _CommunityEdge],
    min_size: int,
    adj: dict[str, list[str]] | None = None,
) -> list[dict[str, Any]];
def _detect_file_based(
    nodes: list[GraphNode],
    edges: Sequence[GraphEdge | _CommunityEdge],
    min_size: int,
    adj: dict[str, list[str]] | None = None,
) -> list[dict[str, Any]];
def _split_oversized(
    communities: list[dict],
    nodes: list[GraphNode],
    edges: Sequence[GraphEdge | _CommunityEdge],
    threshold_pct: float = 0.25,
    min_split_size: int = 10,
) -> list[dict];
def _dedupe_community_names(communities: list[dict[str, Any]], nodes: list[GraphNode]);
def detect_communities(store: GraphStore, min_size: int = 2) -> list[dict[str, Any]];
def capture_community_assignments(store: GraphStore, file_paths: list[str]) -> dict[str, int];
def remap_community_assignments(store: GraphStore, community_by_qn: dict[str, int]) -> int;
def purge_empty_communities(store: GraphStore) -> int;
def incremental_detect_communities(
    store: GraphStore,
    changed_files: list[str],
    min_size: int = 2,
    repo_root: str | Path | None = None,
    force: bool = False,
) -> int;
def store_communities(store: GraphStore, communities: list[dict[str, Any]]) -> int;
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

def _is_test_community(name: str) -> bool;
def get_architecture_overview(store: GraphStore) -> dict[str, Any];
