import from __future__ { annotations }

import importlib, operator;

import from bisect { bisect_right }

import from collections { Counter }

import from collections.abc { Sequence }

import from typing { Any }

glob DETAIL_SECTIONS: tuple[str, ...] = (
    "risk",
    "communities",
    "hubs",
    "coupling",
    "impact",
    "gaps",
    "graph",
);

glob MAX_ROWS: any = 10;

glob MAX_CALLERS: any = 5;

glob _NOT_COUPLING: any = frozenset({"CONTAINS", "TESTED_BY"});

glob _LANGUAGE_FAMILY: any = {
    "typescript": "javascript",
    "tsx": "javascript",
    "vue": "javascript",
    "svelte": "javascript",
    "cpp": "c",
    "objc": "c",
    "luau": "lua",
    "notebook": "python",
};

def parse_detail_sections(value: str) -> tuple[str, ...];
def build_change_details(
    store: GraphStore,
    `report: dict[str, Any],
    sections: Sequence[str],
    *,
    changed_files: list[str],
    churn_counts: dict[str, int] | None = None,
) -> dict[str, Any];
def _changed_nodes(store: GraphStore, `report: dict[str, Any]) -> list[GraphNode];

def _where(`node: GraphNode) -> dict[str, Any];

def _risk(
    store: GraphStore,
    `report: dict[str, Any],
    by_id: dict[int, GraphNode],
    churn_counts: dict[str, int] | None,
) -> list[dict[str, Any]];

def _communities(
    store: GraphStore, changed: list[GraphNode], community_of: dict[str, int | None]
) -> dict[str, Any];

def _hubs(
    store: GraphStore, changed: list[GraphNode], community_of: dict[str, int | None]
) -> dict[str, Any];
def _communities_linked(
    store: GraphStore, `node: GraphNode, community_of: dict[str, int | None]
) -> int;

def _language_family(language: str) -> str;

def _is_test(`node: GraphNode) -> bool;

def _coupling(store: GraphStore, changed: list[GraphNode]) -> dict[str, Any];

def _callers_of(store: GraphStore, qualified_name: str) -> list[str];

def _impact(
    store: GraphStore,
    `report: dict[str, Any],
    by_id: dict[int, GraphNode],
    changed_files: list[str],
) -> dict[str, Any];

def _gaps(store: GraphStore, `report: dict[str, Any], changed: list[GraphNode]) -> dict[str, Any];

def _graph(store: GraphStore) -> dict[str, Any];
