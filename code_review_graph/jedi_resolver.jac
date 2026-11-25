import from __future__ { annotations }

import importlib, builtins, operator, json, logging, os;

import from pathlib { Path }

import from typing { Iterable, Optional }

glob logger: any = logging.getLogger(__name__);

glob _SELF_NAMES: any = frozenset({"self", "cls", "super"});

def enrich_jedi_calls(store, repo_root: Path, files: Optional[Iterable[str]] = None) -> dict;

obj _ResolvedCall {
    has target_qualified: any;

    def init(target: str);

    def __repr__ -> str;

    def __eq__(other: any) -> bool;

    def __hash__ -> int;
}

def _is_resolved_call(target: str, method_name: str) -> bool;
def _get_file_call_edges(store, file_path: str) -> any;

def _edge_extra(raw: Optional[str]) -> dict;
def _find_enclosing(func_nodes, line: int) -> Optional[str];
def _find_untracked_method_calls(`root, is_test_file: bool = False) -> any;
def _walk_calls(`node, results, is_test_file, enclosing_func) -> any;
def _check_dropped_call(attr_node, results, is_test_file, enclosing_func) -> any;
