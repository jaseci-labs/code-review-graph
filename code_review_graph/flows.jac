"""Execution flow detection, tracing, and criticality scoring.

Detects entry points in the codebase (functions with no incoming CALLS edges,
framework-decorated handlers, and conventional name patterns), traces execution
paths via forward BFS through CALLS edges, scores each flow for criticality,
and persists results to the ``flows`` / ``flow_memberships`` tables.
"""

import from __future__ { annotations }

import json;

import logging;

import re;

import from collections { deque }

import from pathlib { Path }

import from typing { Iterable, Optional }

glob logger: any;

glob _SQL_BATCH: any;

glob _FRAMEWORK_DECORATOR_PATTERNS: list[re.Pattern[str]];

glob _OVERRIDE_DECORATOR: any;

glob _ENTRY_NAME_PATTERNS: list[re.Pattern[str]];

glob _LANGUAGE_ENTRY_NAME_PATTERNS: dict[str, tuple[re.Pattern[str], ...]];

with entry {
    logger = logging.getLogger(__name__);

    _SQL_BATCH = 450;
}

"""Escape ``\\``, ``%``, and ``_`` for use in a SQL LIKE pattern."""
def _escape_like_literal(value: str) -> str;

"""Expand *changed_files* to every path form present in the graph.

    ``git diff --name-only`` yields repo-relative paths, while parsed nodes
    store absolute ``file_path`` values (and tests often use relative paths).
    Matching must accept both without treating ``%`` / ``_`` as wildcards
    (#569). When *repo_root* is provided, only exact absolute/relative
    variants are used — the ``LIKE`` basename fallback is skipped so a
    root-level ``util.py`` cannot match ``left/util.py``.
    """
def expand_changed_file_paths(
    store: GraphStore, changed_files: Iterable[str], repo_root: str | Path | None = None
) -> list[str];

"""Return ``(node_ids, flow_ids, entry_point_qns)`` for *file_paths*."""
def _flows_touching_files(
    store: GraphStore, file_paths: list[str]
) -> tuple[list[int], list[int], set[str]];

"""Return the qualified names of every node in *flow_ids*, entry points included.

    Any of them may head a flow once these flows go: when a caller is deleted or
    stops calling, the next function down has no caller left, so a full rebuild
    traces it even though its own file did not change.
    """
def _flow_node_qns(store: GraphStore, flow_ids: list[int]) -> set[str];

"""Return the names that may head a flow, for flows touching *file_paths*.

    That is every node of those flows, not only their entry points; see
    :func:`_flow_node_qns`. Must run **before** node replacement: after
    ``remove_file_data`` the old node IDs are gone and membership JOINs can no
    longer find those flows.
    """
def capture_affected_flow_entry_points(store: GraphStore, file_paths: list[str]) -> set[str];

"""Map the IDs of flow nodes in *file_paths* to their qualified names.

    Must run **before** node replacement, which gives every node a new ID.
    """
def capture_flow_node_ids(store: GraphStore, file_paths: list[str]) -> dict[int, str];

"""Point stored flows at the new rows of re-parsed nodes (#569).

    ``update --skip-flows``, the path the installed hooks run, never re-traces.
    Deleting the flows of a re-parsed file would lose them until the next full
    post-process, so they stay, keyed to the same symbols by qualified name.
    Nodes that no longer exist are left for :func:`purge_orphan_flow_data`.

    Returns the number of nodes remapped.
    """
def remap_flow_node_ids(store: GraphStore, old_ids: dict[int, str]) -> int;

"""Delete flows that touch *file_paths* before those nodes are replaced.

    Returns the qualified names to re-trace after replacement if they are entry
    points then (stable across node ID churn); see :func:`_flow_node_qns`.
    """
def clear_flows_for_files(store: GraphStore, file_paths: list[str]) -> set[str];

"""Remove flow rows/memberships that reference missing nodes.

    Returns the number of orphan memberships deleted.
    """
def purge_orphan_flow_data(store: GraphStore) -> int;

with entry {
    _FRAMEWORK_DECORATOR_PATTERNS = [
        re.compile("app\\.(get|post|put|delete|patch|route|websocket|on_event)", re.IGNORECASE),
        re.compile("router\\.(get|post|put|delete|patch|route)", re.IGNORECASE),
        re.compile("blueprint\\.(route|before_request|after_request)", re.IGNORECASE),
        re.compile("(before|after)_(request|response)", re.IGNORECASE),
        re.compile("click\\.(command|group)", re.IGNORECASE),
        re.compile("\\w+\\.(command|group)\\b", re.IGNORECASE),
        re.compile("(field|model)_(serializer|validator)", re.IGNORECASE),
        re.compile("(celery\\.)?(task|shared_task|periodic_task)", re.IGNORECASE),
        re.compile("receiver", re.IGNORECASE),
        re.compile("api_view", re.IGNORECASE),
        re.compile("\\baction\\b", re.IGNORECASE),
        re.compile("pytest\\.(fixture|mark)"),
        re.compile(
            "^(?:[\\w.]+\\.)?(?:Test|TestFactory|TestTemplate|ParameterizedTest|RepeatedTest|BeforeEach|AfterEach|BeforeAll|AfterAll|Before|After|BeforeClass|AfterClass|BeforeMethod|AfterMethod|BeforeSuite|AfterSuite|BeforeTest|AfterTest|BeforeGroups|AfterGroups|DataProvider)(?:\\s*\\(.*)?$",
            re.DOTALL,
        ),
        re.compile("(override_settings|modify_settings)", re.IGNORECASE),
        re.compile("(event\\.)?listens_for", re.IGNORECASE),
        re.compile("(Get|Post|Put|Delete|Patch|RequestMapping)Mapping", re.IGNORECASE),
        re.compile("(Scheduled|EventListener|Bean|Configuration)", re.IGNORECASE),
        re.compile("KafkaListener", re.IGNORECASE),
        re.compile("(WorkflowMethod|ActivityMethod)", re.IGNORECASE),
        re.compile("(Component|Injectable|Controller|Module|Guard|Pipe)", re.IGNORECASE),
        re.compile("(Subscribe|Mutation|Query|Resolver)", re.IGNORECASE),
        re.compile("(app|router)\\.(get|post|put|delete|patch|use|all)\\b"),
        re.compile("(HiltViewModel|AndroidEntryPoint|Inject)", re.IGNORECASE),
        re.compile("\\w+\\.(tool|tool_plain|system_prompt|result_validator)\\b", re.IGNORECASE),
        re.compile("^tool\\b"),
        re.compile("\\w+\\.(middleware|exception_handler|on_exception)\\b", re.IGNORECASE),
        re.compile("\\w+\\.route\\b", re.IGNORECASE),
    ];
    _OVERRIDE_DECORATOR = re.compile("^(?:java\\.lang\\.)?Override$");
    _ENTRY_NAME_PATTERNS = [
        re.compile("^main$"),
        re.compile("^__main__$"),
        re.compile("^test_"),
        re.compile("^Test[A-Z]"),
        re.compile("^on_"),
        re.compile("^handle_"),
        re.compile("^handler$"),
        re.compile("^handle$"),
        re.compile("^lambda_handler$"),
        re.compile("^upgrade$"),
        re.compile("^downgrade$"),
        re.compile("^lifespan$"),
        re.compile("^get_db$"),
        re.compile("^on(Create|Start|Resume|Pause|Stop|Destroy|Bind|Receive)"),
        re.compile("^do(Get|Post|Put|Delete)$"),
        re.compile("^do_(GET|POST|PUT|DELETE|PATCH|HEAD|OPTIONS)$"),
        re.compile("^log_message$"),
        re.compile("^(middleware|errorHandler)$"),
        re.compile(
            "^ng(OnInit|OnChanges|OnDestroy|DoCheck|AfterContentInit|AfterContentChecked|AfterViewInit|AfterViewChecked)$",
        ),
        re.compile("^(transform|writeValue|registerOnChange|registerOnTouched|setDisabledState)$"),
        re.compile("^(canActivate|canDeactivate|canActivateChild|canLoad|canMatch|resolve)$"),
        re.compile(
            "^(componentDidMount|componentDidUpdate|componentWillUnmount|shouldComponentUpdate|render)$",
        ),
    ];
    _LANGUAGE_ENTRY_NAME_PATTERNS = {
        "php": (re.compile("^(boot|register)$"), re.compile("^__invoke$")),
    };
}

"""Return True if *node* has a decorator matching a framework pattern."""
def _has_framework_decorator(`node: GraphNode) -> bool;

"""Return True if *node* carries Java's ``@Override``."""
def _has_override_decorator(`node: GraphNode) -> bool;

"""Return True if *node*'s name matches a conventional entry-point pattern."""
def _matches_entry_name(`node: GraphNode) -> bool;

"""Find functions that are entry points in the graph.

    An entry point is a Function/Test node that either:
    1. Has no incoming CALLS edges (true root), or
    2. Has a framework decorator (e.g. ``@app.get``), or
    3. Matches a conventional name pattern (``main``, ``test_*``, etc.).

    When *include_tests* is False (the default), Test nodes are excluded so
    that flow analysis focuses on production entry points.
    """
def detect_entry_points(store: GraphStore, include_tests: bool = False) -> list[GraphNode];

"""Trace a single execution flow from *ep* via forward BFS.

    Returns a flow dict (see :func:`trace_flows` for the schema) or ``None``
    if the flow is trivial (single-node, no outgoing CALLS that resolve).
    """
def _trace_single_flow(adj: FlowAdjacency, ep: GraphNode, max_depth: int = 15) -> Optional[dict];

"""Trace execution flows from every entry point via forward BFS.

    Returns a list of flow dicts, each containing:
      - name: human-readable flow name (entry point name)
      - entry_point: qualified name of the entry point
      - entry_point_id: node database id of the entry point
      - path: ordered list of node IDs in the flow
      - depth: maximum BFS depth reached
      - node_count: number of distinct nodes in the path
      - file_count: number of distinct files touched
      - files: list of distinct file paths
      - criticality: computed criticality score (0.0-1.0)
    """
def trace_flows(store: GraphStore, max_depth: int = 15, include_tests: bool = False) -> list[dict];

"""Score a flow from 0.0 to 1.0 based on multiple weighted factors.

    Weights:
      - File spread:         0.30
      - External calls:      0.20
      - Security sensitivity: 0.25
      - Test coverage gap:   0.15
      - Depth:               0.10
    """
def compute_criticality(`flow: dict, adj: FlowAdjacency) -> float;

"""Clear existing flows and persist new ones.

    Returns the number of flows stored.
    """
def store_flows(store: GraphStore, flows: list[dict]) -> int;

"""Re-trace only flows that touch *changed_files*.  Much faster than full trace.

    1. Expand *changed_files* to absolute/relative forms present in the graph (#569).
    2. Purge orphan memberships left behind by node ID replacement.
    3. Find flow IDs whose memberships reference nodes in the expanded paths.
    4. Collect entry-point node IDs / qualified names before deleting those flows.
    5. Delete only the affected flows and their memberships.
    6. Re-detect entry points in expanded paths **or** matching the qualified
       names of nodes in those flows (stable across node replacement).
    7. BFS-trace each relevant entry point via :func:`_trace_single_flow`.
    8. INSERT the new flows (without clearing unrelated flows).

    Returns the number of re-traced flows that were stored.
    """
def incremental_trace_flows(
    store: GraphStore,
    changed_files: list[str],
    max_depth: int = 15,
    repo_root: str | Path | None = None,
    entry_point_qns: Iterable[str] | None = None,
) -> int;

"""Retrieve stored flows from the database.

    Args:
        store: The graph store.
        sort_by: Column to sort by (``criticality``, ``depth``, ``node_count``).
        limit: Maximum number of flows to return.
    """
def get_flows(store: GraphStore, sort_by: str = "criticality", limit: int = 50) -> list[dict];

"""Retrieve a single flow with full path details.

    Returns a dict with the flow metadata plus a ``steps`` list containing
    each node's name, kind, file, and line info.
    """
def get_flow_by_id(store: GraphStore, flow_id: int) -> Optional[dict];

"""Find flows that include nodes from the given changed files.

    Returns::

        {
            "affected_flows": [<flow dicts>],
            "total": <int>,
        }
    """
def get_affected_flows(store: GraphStore, changed_files: list[str]) -> dict;
