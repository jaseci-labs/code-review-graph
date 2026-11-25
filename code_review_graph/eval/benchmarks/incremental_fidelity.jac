"""Incremental-equals-rebuild benchmark.

A persistent graph rots invisibly. Nothing errors; caller lists quietly get
shorter, and a reviewer gets a confidently incomplete answer. A clean rebuild
of the same tree is a free and perfect oracle for that drift, so this
benchmark uses it.

For each of seven edit kinds the benchmark:

1. materialises the repository's tracked files into a throwaway git tree;
2. builds a clean graph and keeps it as the baseline;
3. applies the edit, commits it, and runs ``incremental_update`` plus the
   same post-processing the CLI and MCP tool run;
4. builds a second, clean graph from the edited tree;
5. compares the two databases table by table.

Nodes, edges and every derived table must match. Divergences are reported,
never raised: ``KNOWN_FAILURES`` names the edit kinds that are broken today
so a run stays green while the report stays honest.

Note on ``graph_diff``: the task brief placed ``take_snapshot`` and
``diff_snapshots`` in ``graph.py``; they actually live in
``code_review_graph/graph_diff.py`` and nothing called them before this
module. They are used here for the headline node/edge add/remove summary.
They are not sufficient on their own: a snapshot records only
``(kind, file, community_id)`` per node and ``source->target:kind`` per edge,
so it cannot see a node whose line range, signature, params or file hash
drifted, an edge whose confidence drifted, or any row in ``flows``,
``flow_memberships``, ``communities``, ``nodes_fts`` or ``metadata``.
``diff_snapshots`` also truncates its lists to 100 entries. The per-table comparator below covers
what the snapshot cannot.
"""

import from __future__ { annotations }

import typing;

import json;

import logging;

import os;

import re;

import shutil;

import sqlite3;

import subprocess;

import tempfile;

import time;

import from collections { Counter }

import from dataclasses { dataclass, field }

import from pathlib { Path }

import from typing { Any, Callable, Optional }

glob logger: any;

glob EDIT_KINDS: tuple[str, ...];

glob KNOWN_FAILURES: frozenset[str];

glob COMPARED_TABLES: tuple[str, ...];

glob _VOLATILE_METADATA_KEYS: any;

glob _COMMENT_TOKENS: dict[str, str];

glob _PROBE_SOURCES: dict[str, str];

glob _MAX_EXAMPLES: any;

glob _RENAME_SUFFIX: any;

glob _PROBE_STEM: any;

glob _Projection: any;

glob _NODE_COLUMNS: any;

glob _EDGE_KEY_COLUMNS: any;

glob _EDGE_VALUE_COLUMNS: any;

glob _COMMUNITY_VALUE_COLUMNS: any;

glob _FLOW_VALUE_COLUMNS: any;

glob _PROJECTORS: dict[str, Callable[[sqlite3.Connection], Optional[_Projection]]];

glob _GIT_IDENTITY: any;

glob _APPLIERS: dict[str, Callable[[Path, _Targets], _Edit]];

with entry {
    logger = logging.getLogger(__name__);
    EDIT_KINDS = (
        "trailing_comment",
        "rename_function",
        "delete_file",
        "add_file",
        "move_function",
        "change_import",
        "revert",
    );
    KNOWN_FAILURES = frozenset(EDIT_KINDS);
    COMPARED_TABLES = (
        "nodes",
        "node_community",
        "edges",
        "communities",
        "flows",
        "flow_memberships",
        "nodes_fts",
        "metadata",
    );
    _VOLATILE_METADATA_KEYS = frozenset({
        "last_updated",
        "last_build_type",
        "last_postprocessed_at",
    });
    _COMMENT_TOKENS = {
        ".py": "#",
        ".rb": "#",
        ".sh": "#",
        ".bash": "#",
        ".pl": "#",
        ".r": "#",
        ".jl": "#",
        ".ex": "#",
        ".exs": "#",
        ".yaml": "#",
        ".yml": "#",
        ".js": "//",
        ".jsx": "//",
        ".mjs": "//",
        ".cjs": "//",
        ".ts": "//",
        ".tsx": "//",
        ".go": "//",
        ".java": "//",
        ".c": "//",
        ".h": "//",
        ".cc": "//",
        ".cpp": "//",
        ".hpp": "//",
        ".cs": "//",
        ".rs": "//",
        ".php": "//",
        ".swift": "//",
        ".kt": "//",
        ".scala": "//",
        ".dart": "//",
        ".lua": "--",
        ".sql": "--",
        ".hs": "--",
        ".erl": "%",
    };
    _PROBE_SOURCES = {
        ".py": "\"\"\"Added by the incremental-fidelity benchmark.\"\"\"\n\n\ndef crg_fidelity_probe(value):\n    return value\n",
        ".js": "// Added by the incremental-fidelity benchmark.\nfunction crgFidelityProbe(value) {\n  return value;\n}\nmodule.exports = { crgFidelityProbe };\n",
        ".mjs": "// Added by the incremental-fidelity benchmark.\nexport function crgFidelityProbe(value) {\n  return value;\n}\n",
        ".ts": "// Added by the incremental-fidelity benchmark.\nexport function crgFidelityProbe(value: string): string {\n  return value;\n}\n",
        ".go": "package probe\n\n// CrgFidelityProbe is added by the incremental-fidelity benchmark.\nfunc CrgFidelityProbe(value string) string {\n\treturn value\n}\n",
        ".rb": "# Added by the incremental-fidelity benchmark.\ndef crg_fidelity_probe(value)\n  value\nend\n",
    };

    _MAX_EXAMPLES = 3;
    _RENAME_SUFFIX = "_crg_renamed";
    _PROBE_STEM = "crg_fidelity_probe";
}

"""Full parse plus full post-processing into *db_path*."""
def _clean_build(tree: Path, db_path: Path) -> dict[str, Any];

"""Incremental update plus post-processing, as ``build_or_update_graph`` does.

    The early return when nothing was updated is reproduced deliberately: it
    is the real code path, and skipping post-processing there is exactly the
    kind of thing that leaves derived tables behind.
    """
def _incremental_build(tree: Path, db_path: Path, base: str) -> dict[str, Any];

"""Copy a closed SQLite database, sidecars included."""
def _copy_db(source: Path, target: Path) -> None;

with entry {
    _Projection = typing.Dict[str, "Counter[str]"];
}

def _blank(value: object) -> str;

def _join(row: sqlite3.Row, columns: tuple[str, ...]) -> str;

def _add(target: _Projection, key: str, value: str) -> None;

def _table_exists(conn: sqlite3.Connection, name: str) -> bool;

with entry {
    _NODE_COLUMNS = (
        "kind",
        "name",
        "file_path",
        "line_start",
        "line_end",
        "language",
        "parent_name",
        "params",
        "return_type",
        "modifiers",
        "is_test",
        "file_hash",
        "extra",
        "symbol",
        "signature",
    );

    _EDGE_KEY_COLUMNS = ("kind", "source_qualified", "target_qualified", "file_path", "line");
    _EDGE_VALUE_COLUMNS = ("extra", "confidence", "confidence_tier");
}

def _project_nodes(conn: sqlite3.Connection) -> _Projection;

def _project_node_community(conn: sqlite3.Connection) -> _Projection;

def _project_edges(conn: sqlite3.Connection) -> _Projection;

with entry {
    _COMMUNITY_VALUE_COLUMNS = (
        "level",
        "parent_name",
        "cohesion",
        "size",
        "dominant_language",
        "description",
    );
}

def _project_communities(conn: sqlite3.Connection) -> _Projection;

def _node_names(conn: sqlite3.Connection) -> dict[int, str];

"""Map each flow id to an id-independent identity: entry point plus path."""
def _flow_keys(conn: sqlite3.Connection) -> dict[int, str];

with entry {
    _FLOW_VALUE_COLUMNS = ("name", "depth", "node_count", "file_count", "criticality");
}

def _project_flows(conn: sqlite3.Connection) -> _Projection;

def _project_flow_memberships(conn: sqlite3.Connection) -> _Projection;

"""Project the FTS5 index itself, not the content table behind it.

    ``nodes_fts`` is an external-content table, so ``SELECT ... FROM
    nodes_fts`` reads ``nodes`` and proves nothing. ``fts5vocab`` exposes the
    index's own terms and is rowid-independent, which is what makes it
    comparable across two builds.
    """
def _project_nodes_fts(conn: sqlite3.Connection) -> Optional[_Projection];

def _project_metadata(conn: sqlite3.Connection) -> _Projection;

with entry {
    _PROJECTORS = {
        "nodes": _project_nodes,
        "node_community": _project_node_community,
        "edges": _project_edges,
        "communities": _project_communities,
        "flows": _project_flows,
        "flow_memberships": _project_flow_memberships,
        "nodes_fts": _project_nodes_fts,
        "metadata": _project_metadata,
    };
}

"""Count differing rows and collect a few concrete examples.

    A key present on one side only contributes its row count. A key present on
    both whose values differ contributes the larger of the two one-sided
    multiset deltas, so a single changed column counts as one differing row
    rather than as one removal plus one insertion.
    """
def _diff_projection(
    left: _Projection, right: _Projection, path_prefix: str = ""
) -> tuple[int, list[str]];

"""Shorten an example to the part a reader can act on.

    The repository is materialised under a temporary directory, so every
    stored path carries a prefix that is noise in a report. Stripping it keeps
    the repo-relative identifier inside ``_sanitize_name``'s 256-character cap
    instead of truncating the interesting half away.
    """
def _clean(text: str, path_prefix: str) -> str;

def _describe(values: "Counter[str]") -> str;

def _open(db_path: Path) -> sqlite3.Connection;

"""Compare an incrementally updated graph against a clean rebuild.

    Args:
        incremental_db: Database that was built once and then updated.
        rebuild_db: Database built clean from the same tree. The oracle.
        path_prefix: Stripped from example strings so they stay readable.

    Returns:
        ``tables`` maps every entry of :data:`COMPARED_TABLES` to
        ``{"differing_rows": int, "examples": [str, ...], "checked": bool}``;
        ``total_differing_rows`` is their sum; ``worst_table`` names the
        biggest contributor; ``snapshot_summary`` is
        ``graph_diff.diff_snapshots``' node/edge summary.
    """
def compare_graphs(incremental_db: Path, rebuild_db: Path, path_prefix: str = "") -> dict[str, Any];

"""Headline node/edge deltas via the previously unused graph_diff helpers."""
def _snapshot_summary(incremental_db: Path, rebuild_db: Path) -> dict[str, Any];

with entry {
    _GIT_IDENTITY = (
        "-c",
        "user.email=benchmark@code-review-graph.invalid",
        "-c",
        "user.name=crg-benchmark",
        "-c",
        "commit.gpgsign=false",
    );
}

def _git(tree: Path, *args_: str, check: bool = True) -> str;

def _tracked_files(repo_path: Path) -> list[str];

"""Copy the repository's tracked files into a standalone git repository.

    A fresh ``git init`` rather than a clone: the benchmark commits an edit per
    scenario and resets between them, and it must never write to the
    repository under evaluation.

    The destination is resolved before use. ``full_build`` anchors every
    stored ``file_path`` to ``_canonical_repo_root``, so an unresolved root
    (on macOS ``/var/...`` for ``/private/var/...``) would make every
    ``relpath`` computed against it meaningless.
    """
def _materialise_tree(repo_path: Path, destination: Path) -> Path;

def _head(tree: Path) -> str;

def _commit_all(tree: Path, message: str) -> str;

def _reset(tree: Path, sha: str) -> None;

@dataclass
class _Symbol {
    has qualified_name: str;

    has name: str;

    has rel_path: str;

    has line_start: int;

    has line_end: int;
}

@dataclass
class _Targets {
    has primary: str = "";

    has sibling: str = "";

    has functions: list[_Symbol] = field(default_factory=list[any]);

    has import_sites: list[tuple[str, int]] = field(default_factory=list[any]);

    has deletable: str = "";
}

def _relative(tree: Path, stored: str) -> str;

"""Choose edit targets from the baseline graph, deterministically."""
def _pick_targets(db_path: Path, tree: Path) -> _Targets;

"""What a scenario did, or why it could not run."""
@dataclass
class _Edit {
    has target: str = "";

    has note: str = "";

    has skipped: str = "";
}

def _read_lines(path: Path) -> list[str];

def _write_lines(path: Path, lines: list[str]) -> None;

def _edit_trailing_comment(tree: Path, targets: _Targets) -> _Edit;

"""Find a function whose definition line carries its own name."""
def _rename_candidate(tree: Path, targets: _Targets) -> tuple[_Symbol, int] | None;

def _edit_rename_function(tree: Path, targets: _Targets) -> _Edit;

def _edit_delete_file(tree: Path, targets: _Targets) -> _Edit;

def _edit_add_file(tree: Path, targets: _Targets) -> _Edit;

def _edit_move_function(tree: Path, targets: _Targets) -> _Edit;

"""Prefer an import inside the busiest file, then its language.

    Taking the first import site in path order picks whichever file sorts
    first, which on a polyglot repository is usually a build script with no
    callers, no flows and no community. Removing an import there proves
    almost nothing.
    """
def _ranked_import_sites(targets: _Targets) -> list[tuple[str, int]];

def _edit_change_import(tree: Path, targets: _Targets) -> _Edit;

with entry {
    _APPLIERS = {
        "trailing_comment": _edit_trailing_comment,
        "rename_function": _edit_rename_function,
        "delete_file": _edit_delete_file,
        "add_file": _edit_add_file,
        "move_function": _edit_move_function,
        "change_import": _edit_change_import,
    };
}

def _blank_row(repo: str, kind: str) -> dict[str, Any];

def _record(row: dict[str, Any], diff: dict[str, Any]) -> None;

def _run_scenario(
    kind: str,
    repo: str,
    tree: Path,
    workdir: Path,
    baseline_db: Path,
    base_sha: str,
    targets: _Targets,
) -> dict[str, Any];

"""Prove, or disprove, that an incremental update equals a clean rebuild.

    ``store`` is the runner's already-built graph for *repo_path*. It is not
    used: the benchmark needs two graphs of the same tree at the same instant,
    so it builds both itself in a throwaway copy and never writes to the
    repository under evaluation.
    """
def run(repo_path: Path, store: Any, config: dict) -> list[dict];
