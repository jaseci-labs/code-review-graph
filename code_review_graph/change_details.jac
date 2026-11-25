"""Bounded graph context for a change: the ``details`` of ``detect-changes``.

``detect-changes --details risk,hubs,...`` adds one ``details`` object to its
JSON report. The GitHub Action's renderer turns it into extra sections of the
review comment when the workflow opts in (issue #882). Every list here is cut
to :data:`MAX_ROWS`; the renderer cuts again and caps the bytes it writes.

Sections:

``risk``
    Each top symbol's risk score split into the terms that make it up
    (:func:`~code_review_graph.changes.risk_signals`), so a reader sees why a
    score moved, not only that it did.
``communities``
    The communities the changed symbols belong to.
``hubs``
    Changed production symbols ranked by connections, with their rank among
    all production symbols and how many other communities their direct
    callers and callees sit in.
``coupling``
    Links (one per source, target and edge kind) from or to a changed symbol
    that cross a community or a language boundary. Test code is left out.
``impact``
    The impact radius of the changed files, and the direct callers of the top
    symbols.
``gaps``
    The test gaps, ranked by how much depends on them.
``graph``
    Where the graph came from: size, languages, community count and the
    algorithm that found them, flow count, last build, versions.

All of it is read from the local graph; nothing leaves the machine.
"""

import operator;

import from __future__ { annotations }

import from bisect { bisect_right }

import from collections { Counter }

import from collections.abc { Sequence }

import from typing { Any }

glob DETAIL_SECTIONS: tuple[str, ...];

glob MAX_ROWS: any;

glob MAX_CALLERS: any;

glob _NOT_COUPLING: any;

glob _LANGUAGE_FAMILY: any;

with entry {
    DETAIL_SECTIONS = ("risk", "communities", "hubs", "coupling", "impact", "gaps", "graph");
    MAX_ROWS = 10;
    MAX_CALLERS = 5;
    _NOT_COUPLING = frozenset({"CONTAINS", "TESTED_BY"});
    _LANGUAGE_FAMILY = {
        "typescript": "javascript",
        "tsx": "javascript",
        "vue": "javascript",
        "svelte": "javascript",
        "cpp": "c",
        "objc": "c",
        "luau": "lua",
        "notebook": "python",
    };
}

"""Parse a comma-separated section list; ``all`` means every section.

    Order and repeats in *value* do not matter: the result follows
    :data:`DETAIL_SECTIONS`. An empty value is no sections. An unknown name
    raises :class:`ValueError` naming it, so a typo in a workflow fails
    loudly instead of quietly dropping a section.
    """
def parse_detail_sections(value: str) -> tuple[str, ...];

"""Build the ``details`` object for *report*, an ``analyze_changes`` result.

    *changed_files* are the changed paths as the graph stores them (absolute
    and normalized), for the impact radius. *churn_counts* must be what the
    report was scored with, so the ``risk`` signals add up to its scores.
    """
def build_change_details(
    store: GraphStore,
    `report: dict[str, Any],
    sections: Sequence[str],
    *,
    changed_files: list[str],
    churn_counts: dict[str, int] | None = None,
) -> dict[str, Any];

"""The changed functions and classes of *report*, as graph nodes."""
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

"""Other communities among the direct callers and callees of *node*."""
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
