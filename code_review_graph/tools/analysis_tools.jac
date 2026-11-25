import from __future__ { annotations }

import from typing { Any }

glob _FETCH_ALL: any = 10 ** 9;

glob _MAX_HUB_NODES: any = 100;

glob _MAX_BRIDGE_NODES: any = 100;

glob _MAX_SURPRISING: any = 100;

glob _MAX_GAPS_PER_CATEGORY: any = 50;

glob _MINIMAL_HUB_FIELDS: any = ("name", "kind", "total_degree");

glob _MINIMAL_BRIDGE_FIELDS: any = ("name", "kind", "betweenness");

glob _MINIMAL_SURPRISE_FIELDS: any = ("source", "target", "edge_kind", "surprise_score");

glob _MINIMAL_GAP_FIELDS: any = (
    "name",
    "qualified_name",
    "community_id",
    "size",
    "degree",
    "load_time",
);

def _project(rows: list[dict[str, Any]], fields: tuple[str, ...]) -> list[dict[str, Any]];
def get_hub_nodes_func(
    repo_root: str | None = None, top_n: int = 10, detail_level: str = "standard"
) -> dict[str, Any];
def get_bridge_nodes_func(
    repo_root: str | None = None, top_n: int = 10, detail_level: str = "standard"
) -> dict[str, Any];
def get_knowledge_gaps_func(
    repo_root: str | None = None, max_per_category: int = 15, detail_level: str = "standard"
) -> dict[str, Any];
def get_surprising_connections_func(
    repo_root: str | None = None, top_n: int = 15, detail_level: str = "standard"
) -> dict[str, Any];
def get_suggested_questions_func(repo_root: str | None = None) -> dict[str, Any];
