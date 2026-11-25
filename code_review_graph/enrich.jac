import from __future__ { annotations }

import importlib, json, logging, os, re, sqlite3, sys;

import from pathlib { Path }

import from typing { Any }

glob logger: any = logging.getLogger(__name__);

glob _RG_FLAGS_WITH_VALUES: any = frozenset(
    ("-e -f -m -A -B -C -g --glob -t --type --include --exclude --max-count --max-depth "
        "--max-filesize --color --colors --context-separator --field-match-separator --path-separator "
        "--replace --sort --sortr").split(),
);

def extract_pattern(tool_name: str, tool_input: dict[str, Any]) -> str | None;
def _make_relative(file_path: str, repo_root: str) -> str;
def _get_community_name(conn: Any, community_id: int) -> str;
def _get_flow_names_for_node(conn: Any, node_id: int) -> list[str];
def _format_node_context(`node: Any, store: Any, conn: Any, repo_root: str) -> list[str];
def enrich_search(pattern: str, repo_root: str) -> str;
def enrich_file_read(file_path: str, repo_root: str) -> str;
def run_hook;
