"""Graph analysis: hub detection, bridge nodes, knowledge gaps, import cycles,
surprise scoring, suggested questions."""

import from __future__ { annotations }

import logging;

import from collections { Counter, defaultdict, deque }

import from pathlib { Path }

glob logger: any;

glob _MAX_CYCLE_FILES: any;

glob _MAX_CYCLE_HOPS: any;

with entry {
    logger = logging.getLogger(__name__);
    _MAX_CYCLE_FILES = 10;
    _MAX_CYCLE_HOPS = 10;
}

"""Find the most connected nodes (highest in+out degree), excluding File nodes.

    Returns list of dicts with: name, qualified_name, kind, file,
    in_degree, out_degree, total_degree, community_id
    """
def find_hub_nodes(store: GraphStore, top_n: int = 10) -> list[dict];

"""Find nodes with highest betweenness centrality.

    These are architectural chokepoints that sit on shortest paths
    between many node pairs. If they break, multiple communities
    lose connectivity.

    Returns list of dicts with: name, qualified_name, kind, file,
    betweenness, community_id
    """
def find_bridge_nodes(store: GraphStore, top_n: int = 10) -> list[dict];

"""Return the fewest files that lead from *start* back to itself."""
def _shortest_loop(adjacency: dict[str, set[str]], start: str) -> list[str];

"""Find groups of files that import each other, worst first.

    Only imports that run count: one under ``if TYPE_CHECKING`` or written
    ``import type`` never does. Only imports that name a file count too, so Go
    packages, which the compiler already keeps free of cycles, and C# namespaces
    are not followed.

    Returns list of dicts with: name (one loop, written out), size (files in the
    group), load_time (the loop can fail as the files load; False means every
    loop has an import that runs late), files, loop_length, and cycle (that
    loop's imports with their lines). Paths are relative to *repo_root* when it
    is given. Long lists are cut: size and loop_length keep the real counts.
    """
def find_import_cycles(
    store: GraphStore, edges: list[GraphEdge] | None = None, repo_root: Path | None = None
) -> list[dict];

"""Identify structural weaknesses in the codebase graph.

    Returns dict with categories:
    - isolated_nodes: degree <= 1, disconnected from graph
    - thin_communities: fewer than 3 members
    - untested_hotspots: high-degree nodes with no TESTED_BY edges
    - single_file_communities: entire community in one file
    - import_cycles: files that import each other (see find_import_cycles)
    """
def find_knowledge_gaps(store: GraphStore, repo_root: Path | None = None) -> dict[str, list[dict]];

"""Find edges with high surprise scores.

    Detects unexpected architectural coupling based on:
    - Cross-community: source and target in different communities
    - Cross-language: different file languages
    - Peripheral-to-hub: low-degree node to high-degree node
    - Cross-file-type: test calling production or vice versa
    - Non-standard edge kind for the node types
    """
def find_surprising_connections(store: GraphStore, top_n: int = 15) -> list[dict];

"""Auto-generate review questions from graph analysis.

    Categories:
    - bridge_node: Why does X connect communities A and B?
    - isolated_node: Is X dead code or dynamically invoked?
    - low_cohesion: Should community X be split?
    - hub_risk: Does hub node X have adequate test coverage?
    - surprising: Why does A call B across community boundary?
    """
def generate_suggested_questions(store: GraphStore) -> list[dict];
