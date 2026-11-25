"""Tools 10, 11: list_flows, get_flow."""

import from __future__ { annotations }

import from pathlib { Path }

import from typing { Any }

glob _FETCH_ALL: any;

glob _MAX_FLOWS: any;

glob _MAX_FLOW_STEPS: any;

glob _MAX_FLOW_SOURCE_LINES: any;

with entry {
    _FETCH_ALL = 10 ** 9;
    _MAX_FLOWS = 200;
    _MAX_FLOW_STEPS = 200;
    _MAX_FLOW_SOURCE_LINES = 2000;
}

"""List execution flows in the codebase, sorted by criticality.

    [EXPLORE] Retrieves stored execution flows from the knowledge graph.
    Each flow represents a call chain starting from an entry point
    (e.g. HTTP handler, CLI command, test function).

    Args:
        repo_root: Repository root path. Auto-detected if omitted.
        sort_by: Sort column: criticality, depth, node_count, file_count,
                 or name.
        limit: Maximum flows to return (default: 50, capped at 200).
        kind: Optional filter by entry point kind (e.g. "Test", "Function").
        detail_level: "standard" (default) returns full flow data;
                      "minimal" returns only name, criticality, and
                      node_count per flow.

    Returns:
        Flows with criticality scores, plus ``total`` and ``truncated``.
    """
def list_flows(
    repo_root: str | None = None,
    sort_by: str = "criticality",
    limit: int = 50,
    kind: str | None = None,
    detail_level: str = "standard",
) -> dict[str, Any];

"""Get details of a single execution flow.

    [EXPLORE] Retrieves full path details for a flow, including each step's
    function name, file, and line numbers.  Optionally includes source
    snippets for every step in the path.

    Args:
        flow_id: Database ID of the flow (from list_flows).
        flow_name: Name to search for (partial match). Ignored if flow_id
                   given.
        include_source: If True, include source code snippets for each step.
        repo_root: Repository root path. Auto-detected if omitted.
        max_steps: Maximum steps to return (default 50, capped at 200).
            ``flow["total_steps"]`` reports the untruncated count.
        max_source_lines: Total source lines emitted across all steps when
            ``include_source`` is set (default 400, capped at 2000). Without
            this, one deep flow inlines every function body it touches.

    Returns:
        Flow details with steps, or not_found status. ``flow["truncated"]``
        marks that ``max_steps`` or the source budget cut the response.
    """
def get_flow(
    flow_id: int | None = None,
    flow_name: str | None = None,
    include_source: bool = False,
    repo_root: str | None = None,
    max_steps: int = 50,
    max_source_lines: int = 400,
) -> dict[str, Any];
