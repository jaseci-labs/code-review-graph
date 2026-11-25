import from __future__ { annotations }

import from collections { Counter }

import from typing { Any }

glob _MAX_COMMUNITIES: any = 200;

glob _MAX_MEMBERS: any = 25;

glob _MAX_CROSS_EDGES: any = 200;
def _cap_members(community: dict[str, Any], max_members: int) -> dict[str, Any];
def list_communities_func(
    repo_root: str | None = None,
    sort_by: str = "size",
    min_size: int = 0,
    detail_level: str = "standard",
    max_results: int = 50,
    max_members: int = 10,
) -> dict[str, Any];
def get_community_func(
    community_name: str | None = None,
    community_id: int | None = None,
    include_members: bool = False,
    repo_root: str | None = None,
    max_members: int = 25,
) -> dict[str, Any];

glob _MINIMAL_COMMUNITY_FIELDS: any = ("id", "name", "size", "cohesion", "dominant_language");
def _minimal_overview(overview: dict[str, Any]) -> dict[str, Any];
def get_architecture_overview_func(
    repo_root: str | None = None,
    detail_level: str = "minimal",
    max_results: int = 100,
    max_members: int = 10,
) -> dict[str, Any];
