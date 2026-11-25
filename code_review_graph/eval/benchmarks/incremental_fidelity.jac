import from __future__ { annotations }

import importlib;

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

def _clean_build(tree: Path, db_path: Path) -> dict[str, Any];
def _incremental_build(tree: Path, db_path: Path, base: str) -> dict[str, Any];
def _copy_db(source: Path, target: Path);

with entry {
    _Projection = typing.Dict[str, "Counter[str]"];
}

def _blank(value: object) -> str;

def _join(row: sqlite3.Row, columns: tuple[str, ...]) -> str;

def _add(target: _Projection, key: str, value: str);

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
def _flow_keys(conn: sqlite3.Connection) -> dict[int, str];

with entry {
    _FLOW_VALUE_COLUMNS = ("name", "depth", "node_count", "file_count", "criticality");
}

def _project_flows(conn: sqlite3.Connection) -> _Projection;

def _project_flow_memberships(conn: sqlite3.Connection) -> _Projection;
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

def _diff_projection(
    left: _Projection, right: _Projection, path_prefix: str = ""
) -> tuple[int, list[str]];
def _clean(text: str, path_prefix: str) -> str;

def _describe(values: "Counter[str]") -> str;

def _open(db_path: Path) -> sqlite3.Connection;
def compare_graphs(incremental_db: Path, rebuild_db: Path, path_prefix: str = "") -> dict[str, Any];
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
def _materialise_tree(repo_path: Path, destination: Path) -> Path;

def _head(tree: Path) -> str;

def _commit_all(tree: Path, message: str) -> str;

def _reset(tree: Path, sha: str);

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
def _pick_targets(db_path: Path, tree: Path) -> _Targets;

@dataclass
class _Edit {
    has target: str = "";

    has note: str = "";

    has skipped: str = "";
}

def _read_lines(path: Path) -> list[str];

def _write_lines(path: Path, lines: list[str]);

def _edit_trailing_comment(tree: Path, targets: _Targets) -> _Edit;
def _rename_candidate(tree: Path, targets: _Targets) -> tuple[_Symbol, int] | None;

def _edit_rename_function(tree: Path, targets: _Targets) -> _Edit;

def _edit_delete_file(tree: Path, targets: _Targets) -> _Edit;

def _edit_add_file(tree: Path, targets: _Targets) -> _Edit;

def _edit_move_function(tree: Path, targets: _Targets) -> _Edit;
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

def _record(row: dict[str, Any], diff: dict[str, Any]);

def _run_scenario(
    kind: str,
    repo: str,
    tree: Path,
    workdir: Path,
    baseline_db: Path,
    base_sha: str,
    targets: _Targets,
) -> dict[str, Any];
def run(repo_path: Path, store: Any, config: dict) -> list[dict];
