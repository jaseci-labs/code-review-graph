"""Tools 13, 14, 15: community listing, detail, architecture overview."""

import from __future__ { annotations }

import from collections { Counter }

import from typing { Any }

glob _MAX_COMMUNITIES: any = 200;

glob _MAX_MEMBERS: any = 25;

glob _MAX_CROSS_EDGES: any = 200;

"""Return a copy of *community* whose member lists are bounded.

    ``size`` already carries the true member count, so the caller never
    loses the total; ``members_truncated`` marks that the list was cut.
    """
def _cap_members(community: dict[str, Any], max_members: int) -> dict[str, Any];

"""List detected code communities in the codebase.

    [EXPLORE] Retrieves stored communities from the knowledge graph.
    Each community represents a cluster of related code entities
    (functions, classes) detected via the Leiden algorithm or
    file-based grouping.

    Args:
        repo_root: Repository root path. Auto-detected if omitted.
        sort_by: Sort column: size, cohesion, or name.
        min_size: Minimum community size to include (default: 0).
        detail_level: "standard" (default) returns full community data;
                      "minimal" returns only name, size, and cohesion
                      per community.
        max_results: Maximum communities to return (default 50, capped at
                     200). ``total`` reports the untruncated count.
        max_members: Maximum member names listed per community in standard
                     mode (default 10, capped at 100). Each community's
                     ``size`` still reports its true member count.

    Returns:
        Communities with size and cohesion scores, plus ``total`` and
        ``truncated``.
    """
def list_communities_func(
    repo_root: str | None = None,
    sort_by: str = "size",
    min_size: int = 0,
    detail_level: str = "standard",
    max_results: int = 50,
    max_members: int = 10,
) -> dict[str, Any];

"""Get details of a single code community.

    [EXPLORE] Retrieves a community by its database ID or by name match.
    Optionally includes the full list of member nodes.

    Args:
        community_name: Name to search for (partial match). Ignored if
                        community_id given.
        community_id: Database ID of the community.
        include_members: If True, include full member node details.
        repo_root: Repository root path. Auto-detected if omitted.
        max_members: Maximum member entries to include (default 25, capped
                     at 100). The community's ``size`` still reports its
                     true member count and ``members_truncated`` marks the
                     cut. Without this bound a single 3000-member community
                     serialized to >130k tokens.

    Returns:
        Community details, or not_found status.
    """
def get_community_func(
    community_name: str | None = None,
    community_id: int | None = None,
    include_members: bool = False,
    repo_root: str | None = None,
    max_members: int = 25,
) -> dict[str, Any];

glob _MINIMAL_COMMUNITY_FIELDS: any = ("id", "name", "size", "cohesion", "dominant_language");

"""Compress overview for ``detail_level="minimal"``.

    The full overview can exceed 600KB on medium repos because it embeds
    every community's member list and every individual cross-community
    edge. Minimal mode drops member lists and aggregates the edge list
    to one row per community pair with a count and the top edge kinds —
    enough to spot coupling smells without exploding token budgets.
    """
def _minimal_overview(overview: dict[str, Any]) -> dict[str, Any];

"""Generate an architecture overview based on community structure.

    [EXPLORE] Builds a high-level view of the codebase architecture by
    analyzing community boundaries and cross-community coupling.
    Includes warnings for high coupling between communities.

    Args:
        repo_root: Repository root path. Auto-detected if omitted.
        detail_level: "minimal" (default) drops community member lists
                      and aggregates edges to one row per community pair
                      (typical reduction: 600KB -> <5KB);
                      "standard" returns the full overview including
                      per-edge cross-community detail.
        max_results: Maximum cross-community rows and warnings to return
                     (default 100, capped at 200).
                     ``cross_community_edges_total`` reports the
                     untruncated count.
        max_members: (standard only) Maximum member names per community
                     (default 10, capped at 25). Standard mode returned
                     >600k tokens on this repo without these bounds.

    Returns:
        Architecture overview with communities, cross-community edges,
        warnings, and a ``truncated`` flag.
    """
def get_architecture_overview_func(
    repo_root: str | None = None,
    detail_level: str = "minimal",
    max_results: int = 100,
    max_members: int = 10,
) -> dict[str, Any];
