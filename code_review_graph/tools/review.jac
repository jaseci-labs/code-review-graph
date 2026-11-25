"""Tools 4, 12, 16: review context, affected flows, detect changes."""

import operator;

import from __future__ { annotations }

import logging;

import sqlite3;

import from pathlib { Path, PurePath }

import from typing { Any }

glob logger: any;

glob _MAX_REVIEW_NODES: any;

glob _MAX_REVIEW_EDGES: any;

glob _MAX_REVIEW_FILES: any;

glob _MAX_REVIEW_SOURCE_LINES: any;

glob _MAX_LINES_PER_FILE: any;

glob _MAX_CHANGED_FUNCTIONS: any;

glob _MAX_DETECT_SOURCE_LINES: any;

glob _MAX_REMOVED_SYMBOLS: any;

glob _MAX_SOURCE_SHARE_PER_FILE: any;

glob _REGION_CONTEXT: any;

glob _MAX_WIDEN_SPAN: any;

glob _MAX_REGION_LINES: any;

glob _FALLBACK_HEAD_LINES: any;

glob _MAX_RISK_NODES_PER_FILE: any;

glob _MAX_RISK_SCORED_NODES: any;

glob _RISK_SCORED_KINDS: any;

glob _MAX_AFFECTED_FLOWS_STANDARD: any;

glob _MAX_AFFECTED_FLOWS_MINIMAL: any;

glob _MAX_AFFECTED_FLOW_STEPS: any;

glob _MAX_DETECT_FLOWS: any;

glob _DETECT_FLOW_FIELDS: any;

with entry {
    logger = logging.getLogger(__name__);
    _MAX_REVIEW_NODES = 100;
    _MAX_REVIEW_EDGES = 150;
    _MAX_REVIEW_FILES = 200;
    _MAX_REVIEW_SOURCE_LINES = 800;
    _MAX_LINES_PER_FILE = 500;
    _MAX_CHANGED_FUNCTIONS = 100;
    _MAX_DETECT_SOURCE_LINES = 600;
    _MAX_REMOVED_SYMBOLS = 25;
    _MAX_SOURCE_SHARE_PER_FILE = 0.4;
    _REGION_CONTEXT = 4;
    _MAX_WIDEN_SPAN = 40;
    _MAX_REGION_LINES = 120;
    _FALLBACK_HEAD_LINES = 50;
    _MAX_RISK_NODES_PER_FILE = 8;
    _MAX_RISK_SCORED_NODES = 400;
    _RISK_SCORED_KINDS = ("Function", "Test", "Class");
    _MAX_AFFECTED_FLOWS_STANDARD = 25;
    _MAX_AFFECTED_FLOWS_MINIMAL = 500;
    _MAX_AFFECTED_FLOW_STEPS = 400;
    _MAX_DETECT_FLOWS = 200;
    _DETECT_FLOW_FIELDS = ("id", "name", "criticality", "depth", "node_count", "file_count");
}

"""Keep only *fields* on each row, dropping keys the row does not have."""
def _project(rows: list[dict[str, Any]], fields: tuple[str, ...]) -> list[dict[str, Any]];

"""Spend a shared step budget across *flows*, most critical first.

    Returns ``(flows, truncated)``. Flows are already sorted by criticality,
    so the ones a reviewer cares about keep their full step list; the tail
    keeps metadata and is marked ``steps_omitted``. Every flow reports
    ``total_steps`` so the untruncated depth is never lost.
    """
def _bound_flow_steps(flows: list[dict[str, Any]]) -> tuple[list[dict[str, Any]], bool];

"""Group *changed_nodes* under the relative path the caller asked about.

    The graph stores absolute normalized paths while the tool's inputs and
    outputs are repo-relative, and the two spellings have to be bridged in
    exactly one place or the ranking and the snippets disagree about which
    nodes belong to a file.
    """
def _nodes_by_rel_path(
    `root: Path, rel_files: list[str], changed_nodes: list[GraphNode]
) -> dict[str, list[GraphNode]];

"""Score each changed file by the riskiest changed node it contains.

    Uses ``changes.compute_risk_score`` -- the same score ``detect_changes``
    reports -- so the review context and the risk report agree on what
    matters. Scoring is bounded (see ``_MAX_RISK_SCORED_NODES``); unscored
    files keep a score of 0.0 and therefore their original order.
    """
def _risk_by_file(
    store: Any, rel_files: list[str], nodes_by_rel: dict[str, list[GraphNode]]
) -> dict[str, float];

"""The most source lines any single file may hold of the shared budget."""
def _source_share_cap(total_budget: int, per_file_limit: int) -> int;

"""Changed line ranges per repo-relative path, or ``{}`` if Git cannot say.

    ``get_review_context`` seeds its subgraph from whole files, so its
    ``changed_nodes`` list is every node in a changed file and cannot say
    where inside the file the change is. One ``git diff --unified=0`` buys
    that, and it is the difference between spending the source budget on the
    changed code and spending it on whatever happens to sit at the top of the
    file. Failure is not an error: the regions fall back to node spans.
    """
def _diff_hunks(`root: Path, base: str) -> dict[str, list[tuple[int, int]]];

"""The regions of one file worth showing, as 0-based ``[start, end)``.

    Preference order, because each source is better than the next but not
    always available:

    1. *hunks* -- the lines the diff actually changed. A hunk inside a
       definition no longer than ``_MAX_WIDEN_SPAN`` is widened to that whole
       definition; otherwise it gets ``_REGION_CONTEXT`` lines either side.
    2. the changed nodes' own spans, for a file the caller named but the diff
       does not cover (an explicit ``changed_files`` list, a non-Git tree).
    3. the head of the file, for a file the graph does not know either.

    Overlapping regions merge, but only while the merged span stays within
    *region_cap*: merging past that is what turned a multi-hunk file into one
    window whose top ``max_lines_per_file`` lines were all a reviewer saw.
    """
def _file_regions(
    line_count: int, hunks: list[tuple[int, int]], nodes: list[GraphNode], region_cap: int
) -> list[tuple[int, int]];

"""Grant whole regions from *total_budget*, round-robin in rank order.

    Round-robin rather than depth-first: every file is offered its first
    region before any file is offered its second, so a one-hunk file costs one
    small grant and a six-hunk file gets six turns. Within a round the
    riskiest file goes first, which is what decides who loses out when the
    budget runs dry.

    A region is granted whole or not at all -- half a hunk is what the old
    per-file line cap delivered and it is not reviewable. The single
    exception is a region larger than the cap on its own, which is truncated
    to the cap because nothing else can be done with it.

    Returns ``({file: granted regions in source order}, {file: regions
    omitted})``.
    """
def _allocate_regions(
    ranked_files: list[str],
    regions_by_file: dict[str, list[tuple[int, int]]],
    total_budget: int,
    per_file_limit: int,
) -> tuple[dict[str, list[tuple[int, int]]], dict[str, int]];

"""Number and join *regions*, marking the gaps and what was left out."""
def _render_regions(lines: list[str], regions: list[tuple[int, int]], omitted: int) -> str;

"""Generate a focused review context from changed files.

    Builds a token-optimized subgraph + source snippets for code review.

    Args:
        changed_files: Files to review (auto-detected from git diff if omitted).
        max_depth: Impact radius depth (default: 2).
        include_source: Whether to include source code snippets (default: True).
        max_lines_per_file: Max source lines per file in output (default: 200).
        repo_root: Repository root path. Auto-detected if omitted.
        base: Git ref for change detection (default: HEAD~1).
        detail_level: Output detail level.  "standard" returns full context;
            "minimal" returns summary, risk level, changed/impacted file counts,
            top 5 key entity names, test gap count, and next tool suggestions.
            Default: "standard".
        max_results: Maximum graph nodes per list and edges to return
            (default 50; nodes capped at 200, edges at 300). Each list
            carries its untruncated ``*_total`` count.
        max_files: Maximum files to list and to emit source snippets for
            (default 25, capped at 200). A whole-repo diff otherwise inlined
            every tracked file's source. Snippets additionally share an
            800-line budget and ``max_lines_per_file`` is capped at 500.

    Returns:
        Structured review context with subgraph, source snippets, and
        review guidance, plus a ``truncated`` flag. ``changed_files`` is
        ordered by the risk score ``detect_changes`` reports (highest
        first, reported per file in ``file_risk``), and both the file cap
        and the shared source-line budget are spent in that order. The
        budget buys whole changed regions rather than a per-file line
        quota, and ``source_regions`` reports how many regions each file
        has and how many were shown.
    """
def get_review_context(
    changed_files: list[str] | None = None,
    max_depth: int = 2,
    include_source: bool = True,
    max_lines_per_file: int = 200,
    repo_root: str | None = None,
    base: str = "HEAD~1",
    detail_level: str = "standard",
    max_results: int = 50,
    max_files: int = 25,
) -> dict[str, Any];

"""Generate review guidance based on the impact analysis.

    *repo_root* is what makes the test-file check read a project path rather
    than an absolute one. Without it, directory conventions are skipped for
    absolute paths, which can leave a test helper in the untested list but
    never hides a production gap. See #1023.

    *store* lets this split the untested list the same way ``detect_changes``
    does. CLAUDE.md sends reviewers through both tools in one session, so when
    one says a symbol "lacks test coverage" and the other says a tested caller
    reaches it, the reviewer gets two answers and no way to pick. Without a
    store the wording still stays inside what an edge check can support.
    """
def _generate_review_guidance(
    impact: dict,
    changed_files: list[str],
    repo_root: "str | Path | None" = None,
    store: "GraphStore | None" = None,
) -> str;

"""Find execution flows affected by changed files.

    [REVIEW] Identifies which execution flows pass through nodes in the
    changed files.  Useful during code review to understand which user-facing
    or critical paths are affected by a change.

    Args:
        changed_files: List of changed file paths (relative to repo root).
                       Auto-detected from git diff if omitted.
        base: Git ref for auto-detecting changes (default: HEAD~1).
        repo_root: Repository root path. Auto-detected if omitted.
        detail_level: "standard" for full step details, "minimal" for
            per-flow metadata only (name, criticality, depth, counts).
            Every flow carries a full ``steps`` list in standard mode, so
            large change sets can exceed 200k tokens without a bound (#849).
        max_flows: Maximum flows to return (default: 50). ``total`` always
            reports the untruncated count; 0 means "no caller limit".
            Standard mode additionally caps the visible flows at 25 and
            minimal mode at 500, because one standard flow costs ~980
            tokens against ~18 for a minimal one. This mirrors the way
            query.py caps minimal-mode results at five. Standard mode also
            spends a shared 400-step budget across the returned flows, so
            a codebase with very deep call chains cannot blow the budget
            with a legal flow count.

    Returns:
        Affected flows sorted by criticality; ``truncated`` is set when
        ``max_flows``, the per-detail-level ceiling, or the step budget cut
        the response.
    """
def get_affected_flows_func(
    changed_files: list[str] | None = None,
    base: str = "HEAD~1",
    repo_root: str | None = None,
    detail_level: str = "standard",
    max_flows: int = 50,
) -> dict[str, Any];

"""Detect changes and produce risk-scored review guidance.

    [REVIEW] Primary tool for code review.  Maps git diffs to affected
    functions, YAML paths, flows, communities, and test coverage gaps.
    Returns priority-ordered review guidance with risk scores.

    Args:
        base: Git ref to diff against (default: HEAD~1).
        changed_files: Explicit list of changed file paths (relative to repo
            root).  Auto-detected from git diff if omitted.
        include_source: If True, include source code snippets for changed
            functions.  Default: False.
        max_depth: Impact radius depth for BFS traversal.  Default: 2.
        repo_root: Repository root path.  Auto-detected if omitted.
        detail_level: Output detail level.  "standard" returns full analysis;
            "minimal" returns only summary, risk_score, changed_file_count,
            changed_yaml_path_count, test_gap_count, and the top three code
            review priorities (text only).
            Default: "standard".
        max_results: Maximum changed functions, YAML paths and test gaps to return
            (default 25, capped at 200). ``changed_functions_total`` and
            ``test_gaps_total`` report the untruncated counts.
        max_flows: Maximum affected flows to embed (default 20, capped at
            200). The embedded flows carry per-flow metadata only; use
            get_affected_flows_tool for step detail. See #849.

    Returns:
        Risk-scored analysis with changed functions, YAML paths, affected
        flows, test gaps, and review priorities, plus ``truncated``.
    """
def detect_changes_func(
    base: str = "HEAD~1",
    changed_files: list[str] | None = None,
    include_source: bool = False,
    max_depth: int = 2,
    repo_root: str | None = None,
    detail_level: str = "standard",
    max_results: int = 25,
    max_flows: int = 20,
) -> dict[str, Any];
