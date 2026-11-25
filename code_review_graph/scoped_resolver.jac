import from __future__ { annotations }

import operator;

import json;

import logging;

import from pathlib { Path }

import from typing { TYPE_CHECKING, Optional }

glob logger: any;

glob _SCOPED_LANGUAGES: any;

glob _RECEIVER_SCOPE_LANGUAGES: any;

glob _METHOD_KINDS: any;

glob _PHP_SELF_SCOPES: any;

glob _IMPORT_SEGMENT_SEPARATORS: any;

with entry {
    logger = logging.getLogger(__name__);
    _SCOPED_LANGUAGES = ("php", "rust");
    _RECEIVER_SCOPE_LANGUAGES = ("php",);
    _METHOD_KINDS = ("Function", "Test", "Method");
    _PHP_SELF_SCOPES = {"self", "static"};
    _IMPORT_SEGMENT_SEPARATORS = ("::", "\\", "/");
}

def _import_segments(target: str) -> list[str];
def _fold(name: str, language: str) -> str;
def _path_tokens(file_path: str) -> list[str];
def _path_key(file_path: str) -> str;
def _path_ends_with(path_tokens: list[str], suffix: list[str], language: str) -> bool;
def _safe_import_suffixes(segments: list[str], language: str) -> list[list[str]];
def _is_unresolved_scoped_target(target: str) -> bool;
def _enclosing_class(source_qualified: str) -> Optional[str];
def _scope_and_method(target: str, language: str) -> Optional[tuple[Optional[str], str, bool]];
def resolve_scoped_calls(store: GraphStore, repo_root: Path | None = None) -> dict;
