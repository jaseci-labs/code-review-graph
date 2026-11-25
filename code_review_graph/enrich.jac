"""PreToolUse search enrichment for Claude Code hooks.

Intercepts Grep/Glob/Bash/Read tool calls and enriches them with
structural context from the code knowledge graph: callers, callees,
execution flows, community membership, and test coverage.
"""

import from __future__ { annotations }

import json;

import logging;

import os;

import re;

import sqlite3;

import sys;

import from pathlib { Path }

import from typing { Any }

glob logger: any;

glob _RG_FLAGS_WITH_VALUES: any;

with entry {
    logger = logging.getLogger(__name__);
    _RG_FLAGS_WITH_VALUES = frozenset({
        "-e",
        "-f",
        "-m",
        "-A",
        "-B",
        "-C",
        "-g",
        "--glob",
        "-t",
        "--type",
        "--include",
        "--exclude",
        "--max-count",
        "--max-depth",
        "--max-filesize",
        "--color",
        "--colors",
        "--context-separator",
        "--field-match-separator",
        "--path-separator",
        "--replace",
        "--sort",
        "--sortr",
    });
}

"""Extract a search pattern from a tool call's input.

    Returns None if no meaningful pattern can be extracted.
    """
def extract_pattern(tool_name: str, tool_input: dict[str, Any]) -> str | None;

"""Make a file path relative to repo_root for display."""
def _make_relative(file_path: str, repo_root: str) -> str;

"""Fetch a community name by ID."""
def _get_community_name(conn: Any, community_id: int) -> str;

"""Fetch execution flow names that a node participates in (max 3)."""
def _get_flow_names_for_node(conn: Any, node_id: int) -> list[str];

"""Format a single node's structural context as plain text lines."""
def _format_node_context(`node: Any, store: Any, conn: Any, repo_root: str) -> list[str];

"""Search the graph for pattern and return enriched context."""
def enrich_search(pattern: str, repo_root: str) -> str;

"""Enrich a file read with structural context for functions in that file."""
def enrich_file_read(file_path: str, repo_root: str) -> str;

"""Entry point for the enrich CLI subcommand.

    Reads Claude Code hook JSON from stdin, extracts the search pattern,
    queries the graph, and outputs hookSpecificOutput JSON to stdout.
    """
def run_hook -> None;
