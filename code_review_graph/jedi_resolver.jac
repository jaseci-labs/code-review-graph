"""Post-build Jedi enrichment for Python call resolution.

After tree-sitter parsing, many method calls on lowercase-receiver variables
are dropped (e.g. ``svc.authenticate()`` where ``svc = factory()``).  Jedi
can resolve these by tracing return types across files.

This module runs as a post-build step: it re-walks Python ASTs to find
dropped calls, uses ``jedi.Script.goto()`` to resolve them, and adds the
resulting CALLS edges to the graph database.
"""

import builtins;

import operator;

import from __future__ { annotations }

import json;

import logging;

import os;

import from pathlib { Path }

import from typing { Iterable, Optional }

glob logger: any;

glob _SELF_NAMES: any;

with entry {
    logger = logging.getLogger(__name__);

    _SELF_NAMES = frozenset({"self", "cls", "super"});
}

"""Resolve untracked Python method calls via Jedi.

    Walks Python files, finds ``receiver.method()`` calls on lowercase
    receivers (not self/cls), and resolves them with Jedi. The parser keeps
    most of them as a CALLS edge to the bare method name; that edge gets the
    resolved target. A call the parser dropped gets a new CALLS edge.

    *files* limits which files are read and scanned for calls. ``None``
    (a full build) scans every Python file in the graph. An incremental
    update passes only the files it re-parsed: re-parsing replaces a file's
    edges, so those are the only files that lost their Jedi edges, and
    reading every other Python file again on each update is wasted work.
    Jedi still resolves call targets across the whole project.

    Returns stats dict with ``resolved`` count.
    """
def enrich_jedi_calls(store, repo_root: Path, files: Optional[Iterable[str]] = None) -> dict;

"""A call resolved in this pass, standing in for its edge row."""
obj _ResolvedCall {
    has target_qualified: any;

    def init(target: str);

    def __repr__ -> str;

    def __eq__(other: any) -> bool;

    def __hash__ -> int;
}

"""Whether a CALLS target already names *method_name* in a file."""
def _is_resolved_call(target: str, method_name: str) -> bool;

"""Get all CALLS edges originating from a file."""
def _get_file_call_edges(store, file_path: str) -> any;

def _edge_extra(raw: Optional[str]) -> dict;

"""Find the qualified name of the function enclosing a given line."""
def _find_enclosing(func_nodes, line: int) -> Optional[str];

"""Walk Python AST to find method calls the parser would have dropped.

    Returns list of (jedi_line, col, method_name, enclosing_func_name) tuples.
    Jedi_line is 1-indexed, col is 0-indexed.
    """
def _find_untracked_method_calls(`root, is_test_file: bool = False) -> any;

"""Recursively walk AST collecting dropped method calls."""
def _walk_calls(`node, results, is_test_file, enclosing_func) -> any;

"""Check if an attribute-based call was dropped by the parser."""
def _check_dropped_call(attr_node, results, is_test_file, enclosing_func) -> any;
