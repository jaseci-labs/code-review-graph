import from __future__ { annotations }

import builtins;

import operator;

import json;

import sqlite3;

import from typing { Optional }

glob _SINGLE_SUPERCLASS: any;

glob _MAX_DEPTH: any;

with entry {
    _SINGLE_SUPERCLASS = frozenset({"java", "csharp", "typescript", "tsx", "javascript", "php"});
    _MAX_DEPTH = 32;
}

def _load_extra(raw: Optional[str]) -> dict;
def _is_interface(language: str, extra: dict) -> bool;
def _strip_type(raw: str) -> str;

obj InheritanceIndex {
    has _imports: any,
        _raw_imports: any,
        _classes: any,
        _by_name: any,
        _java_fqcn: any,
        _java_package: any,
        _php_namespaces: any,
        _php_fqn: any,
        _methods: any,
        _raw_parents: any,
        _parents: any,
        _inherited: any;

    def init(
        conn: sqlite3.Connection,
        import_targets: dict[str, set[str]],
        raw_imports: dict[str, dict[str, str]],
    );

    def is_class(qualified_name: str) -> bool;

    def has_parents(qualified_name: str) -> bool;
    def java_package(file_path: str) -> Optional[str];
    def method_of(class_name: str, method: str) -> Optional[str];
    def resolve_type(raw: str, context_file: str, language: str) -> Optional[str];
    def inherited_method(class_name: str, method: str) -> Optional[str];

    static def _only(candidates: list[str]) -> Optional[str];

    def _resolve_parent(child: str, raw: str, extra: dict) -> Optional[str];
    def _parents_of(class_name: str) -> tuple[list[str], bool];

    def _walk(class_name: str, method: str) -> Optional[str];
    def _only_declaration(class_name: str, method: str) -> Optional[str];

    def __repr__ -> str;

    def __eq__(other: any) -> bool;

    def __hash__ -> int;
}
