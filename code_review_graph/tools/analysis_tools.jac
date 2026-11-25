"""MCP tool wrappers for graph analysis features."""

import from __future__ { annotations }

import from typing { Any }

glob _FETCH_ALL: any;

glob _MAX_HUB_NODES: any;

glob _MAX_BRIDGE_NODES: any;

glob _MAX_SURPRISING: any;

glob _MAX_GAPS_PER_CATEGORY: any;

glob _MINIMAL_HUB_FIELDS: any;

glob _MINIMAL_BRIDGE_FIELDS: any;

glob _MINIMAL_SURPRISE_FIELDS: any;

glob _MINIMAL_GAP_FIELDS: any;

with entry {
    _FETCH_ALL = 10 ** 9;
    _MAX_HUB_NODES = 100;
    _MAX_BRIDGE_NODES = 100;
    _MAX_SURPRISING = 100;
    _MAX_GAPS_PER_CATEGORY = 50;

    _MINIMAL_HUB_FIELDS = ("name", "kind", "total_degree");
    _MINIMAL_BRIDGE_FIELDS = ("name", "kind", "betweenness");
    _MINIMAL_SURPRISE_FIELDS = ("source", "target", "edge_kind", "surprise_score");
    _MINIMAL_GAP_FIELDS = ("name", "qualified_name", "community_id", "size", "degree", "load_time");
}

"""Keep only *fields* on each row, dropping keys the row does not have."""
def _project(rows: list[dict[str, Any]], fields: tuple[str, ...]) -> list[dict[str, Any]];

"""Find the most connected nodes in the codebase graph.

    Hub nodes have the highest total degree (in + out edges).
    These are architectural hotspots -- changes to them have
    disproportionate blast radius.

    Args:
        repo_root: Repository root (auto-detected if omitted).
        top_n: Number of top hubs to return (default 10, capped at 100).
        detail_level: "standard" (default) returns full node data;
            "minimal" returns only name, kind, and total_degree.

    Returns:
        Ranked hubs. ``total`` reports the untruncated candidate count and
        ``truncated`` marks that ``top_n`` or the ceiling cut the list.
    """
def get_hub_nodes_func(
    repo_root: str | None = None, top_n: int = 10, detail_level: str = "standard"
) -> dict[str, Any];

"""Find architectural chokepoints via betweenness centrality.

    Bridge nodes sit on the shortest paths between many node
    pairs. If they break, multiple code regions lose
    connectivity.

    Args:
        repo_root: Repository root (auto-detected if omitted).
        top_n: Number of top bridges to return (default 10, capped at 100).
        detail_level: "standard" (default) returns full node data;
            "minimal" returns only name, kind, and betweenness.

    Returns:
        Ranked bridges. ``total`` reports the untruncated candidate count and
        ``truncated`` marks that ``top_n`` or the ceiling cut the list.
    """
def get_bridge_nodes_func(
    repo_root: str | None = None, top_n: int = 10, detail_level: str = "standard"
) -> dict[str, Any];

"""Identify structural weaknesses in the codebase.

    Finds: isolated nodes (disconnected), thin communities
    (< 3 members), untested hotspots (high-degree, no tests),
    single-file communities, and import cycles (files that
    import each other).

    Args:
        repo_root: Repository root (auto-detected if omitted).
        max_per_category: Maximum entries per gap category (default 15,
            capped at 50). ``summary`` and ``total_gaps`` always report the
            untruncated counts.
        detail_level: "standard" (default) returns full gap records;
            "minimal" drops file paths and keeps identifying fields only.

    Returns:
        Gaps by category. ``summary`` maps each category to its untruncated
        count and ``truncated`` marks that at least one list was cut.
    """
def get_knowledge_gaps_func(
    repo_root: str | None = None, max_per_category: int = 15, detail_level: str = "standard"
) -> dict[str, Any];

"""Find unexpected architectural coupling in the codebase.

    Scores edges by surprise factors: cross-community,
    cross-language, peripheral-to-hub, cross-test-boundary.

    Args:
        repo_root: Repository root (auto-detected if omitted).
        top_n: Number of top surprises to return (default 15, capped at 100).
        detail_level: "standard" (default) returns full edge records;
            "minimal" returns only source, target, edge_kind, and score.

    Returns:
        Ranked surprising edges. ``total`` reports the untruncated count and
        ``truncated`` marks that ``top_n`` or the ceiling cut the list.
    """
def get_surprising_connections_func(
    repo_root: str | None = None, top_n: int = 15, detail_level: str = "standard"
) -> dict[str, Any];

"""Auto-generate review questions from graph analysis.

    Produces questions about: bridge nodes, untested hubs,
    surprising connections, thin communities, and untested
    hotspots.

    The output is bounded by construction: ``generate_suggested_questions``
    draws at most 3 bridges, 3 hubs, 3 surprises, 2 thin communities and
    2 untested hotspots, so no result cap is needed here.

    Args:
        repo_root: Repository root (auto-detected if omitted).
    """
def get_suggested_questions_func(repo_root: str | None = None) -> dict[str, Any];
