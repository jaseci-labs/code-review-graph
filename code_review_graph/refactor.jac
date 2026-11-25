import from __future__ { annotations }

import importlib;

import builtins;

import operator;

import ast;

import functools;

import io;

import logging;

import re;

import sys;

import threading;

import time;

import tokenize;

import uuid;

import warnings;

import from collections { deque }

import from pathlib { Path, PurePosixPath }

import from typing { Any, Optional, Union }

glob logger: any;

glob _FRAMEWORK_BASE_CLASSES: any;

glob _CDK_CLASS_SUFFIXES: any;

glob _MOCK_NAME_RE: any;

glob _refactor_lock: any;

glob _pending_refactors: dict[str, dict[str, Any]];

glob _followed_edit_files: dict[str, Any];

glob REFACTOR_EXPIRY_SECONDS: any;

glob _DEF_SEARCH_LINES: any;

glob _PY_SUFFIXES: any;

glob _PY_MODULE_ENDINGS: any;

glob _JS_FAMILY: any;

glob _STAR_IMPORT_RE: any;

glob _DEF_KEYWORD_RE: any;

glob _JS_NAME_LEAVES: any;

glob _JS_DECLARATION_FIELDS: dict[str, tuple[str, ...]];

glob _JS_DECLARATION_PARENTS: any;

glob _JS_FUNCTION_SCOPES: any;

glob _JS_BLOCK_SCOPES: any;

glob _JS_NAMED_EXPRESSIONS: any;

glob _Occurrence: any;

glob _MIN_PKG_SEGMENT_LEN: any;

glob _TYPE_IDENT_RE: any;

glob _ASCII_FOLD: any;

with entry {
    logger = logging.getLogger(__name__);
    _FRAMEWORK_BASE_CLASSES = frozenset({
        "Base",
        "DeclarativeBase",
        "Model",
        "BaseModel",
        "BaseSettings",
        "db.Model",
        "TableBase",
        "Stack",
        "NestedStack",
        "Construct",
        "Resource",
    });
    _CDK_CLASS_SUFFIXES = ("Stack", "Construct", "Pipeline", "Resources", "Layer");
    _MOCK_NAME_RE = re.compile(
        "^(mock[A-Z_]|Mock[A-Z]|createMock[A-Z])|(Mock|Stub|Fake|Spy)$", re.IGNORECASE
    );

    _refactor_lock = threading.Lock();
    _pending_refactors = {};
    _followed_edit_files = {};
    REFACTOR_EXPIRY_SECONDS = 600;
}

def _cleanup_expired -> int;

with entry {
    _DEF_SEARCH_LINES = 20;

    _PY_SUFFIXES = (".py", ".pyi", ".pyw");
    _PY_MODULE_ENDINGS = (".py", ".pyi", ".pyw", "/__init__.py", "/__init__.pyi");
    _JS_FAMILY = frozenset({"javascript", "typescript", "tsx"});
    _STAR_IMPORT_RE = re.compile(b"\\bimport\\s+\\*");
    _DEF_KEYWORD_RE = re.compile("(?:async\\s+)?def\\s+|class\\s+");
    _JS_NAME_LEAVES = frozenset({
        "identifier",
        "type_identifier",
        "shorthand_property_identifier",
        "shorthand_property_identifier_pattern",
    });
    _JS_DECLARATION_FIELDS = {
        "variable_declarator": ("name",),
        "function_declaration": ("name",),
        "function_signature": ("name",),
        "generator_function_declaration": ("name",),
        "function_expression": ("name",),
        "function": ("name",),
        "generator_function": ("name",),
        "class_declaration": ("name",),
        "abstract_class_declaration": ("name",),
        "class": ("name",),
        "interface_declaration": ("name",),
        "type_alias_declaration": ("name",),
        "enum_declaration": ("name",),
        "type_parameter": ("name",),
        "required_parameter": ("pattern",),
        "optional_parameter": ("pattern",),
        "arrow_function": ("parameter",),
        "catch_clause": ("parameter",),
        "assignment_pattern": ("left",),
        "pair_pattern": ("value",),
        "for_in_statement": ("left",),
    };
    _JS_DECLARATION_PARENTS = frozenset({
        "formal_parameters",
        "array_pattern",
        "rest_pattern",
        "import_clause",
        "namespace_import",
    });
    _JS_FUNCTION_SCOPES = frozenset({
        "program",
        "function_declaration",
        "function_expression",
        "function",
        "arrow_function",
        "method_definition",
        "generator_function_declaration",
        "generator_function",
    });
    _JS_BLOCK_SCOPES = _JS_FUNCTION_SCOPES
        | frozenset({
            "statement_block",
            "for_statement",
            "for_in_statement",
            "catch_clause",
            "class_body",
            "switch_body",
        });
    _JS_NAMED_EXPRESSIONS = frozenset({
        "function_expression",
        "function",
        "generator_function",
        "class",
    });
}

def _ident_pattern(name: str) -> re.Pattern[str];
def _decode_source(data: bytes) -> Optional[tuple[str, bool]];

obj _Source {
    has path: any,
        text: any,
        lines: any,
        data: any,
        _py_tree: any,
        _py_parsed: any,
        _py_tokens: any,
        _py_tokens_for: any,
        _py_calls: any,
        _py_calls_for: any;

    def init(path: str, text: str);

    def line(lineno: int) -> str;
    def char_col(lineno: int, byte_col: int) -> int;

    def python_tree -> Optional[ast.Module];
    def python_name_tokens(name: str) -> Optional[list[tuple[int, int, bool]]];
    def _python_name_at(`node: ast.AST, name: str) -> Optional[tuple[int, int, bool]];

    def _python_fstring_names(name: str) -> list[tuple[int, int, bool]];
    def python_call_names(name: str) -> dict[int, list[tuple[int, int, bool]]];

    def __repr__ -> str;

    def __eq__(other: any) -> bool;

    def __hash__ -> int;
}

obj _Sources {
    has _root: any,
        _files: any,
        _trees: any,
        _parser: any;

    def init(repo_root: Optional[str]);

    has parser: CodeParser {
        getter {
            if self._parser is None {
                self._parser = CodeParser(Path(self._root) if self._root else None);
            }
            return self._parser;
        }
    }

    def get(path: str) -> Optional[_Source];

    def language(path: str) -> Optional[str];
    def tree(path: str) -> Any;

    def resolve_js_module(spec: str, from_file: str) -> Optional[str];

    def __repr__ -> str;

    def __eq__(other: any) -> bool;

    def __hash__ -> int;
}

with entry {
    _Occurrence = builtins.tuple[int, int, str, Optional[str]];
}

def _import_targets_by_line(store: GraphStore, file_path: str) -> dict[int, set[str]];
def _importer_files(store: GraphStore, module_file: str) -> list[str];

obj _PyScope {
    has kind: any,
        parent: any,
        binds: any,
        bound_yet: any,
        declared: any,
        target: any,
        star: any;

    static has __slots__: any = (
        "kind",
        "parent",
        "binds",
        "bound_yet",
        "declared",
        "target",
        "star",
    );

    def init(kind: str, parent: Optional[_PyScope]);

    def bind(target: bool = False);
    def outside_class -> _PyScope;

    def __repr__ -> str;

    def __eq__(other: any) -> bool;

    def __hash__ -> int;
}

def _any_submodule(submodule_of: any, target: str, imported_names: list[str]) -> bool;
def _py_module_matches(target: str, module_path: str, exact: bool) -> bool;
def _py_module_base(dotted: str, targets: set[str]) -> Optional[str];
def _dotted(expr: ast.expr) -> Optional[str];

obj _PyRenameScan {
    has src: any,
        name: any,
        name_bytes: any,
        word: any,
        target_def: any,
        import_targets: any,
        exporters: any,
        `root: any,
        uses: any,
        fixed: any,
        attributes: any,
        module_prefixes: any,
        module_paths: any,
        all_entries: any,
        called: any;

    def init(
        source: _Source,
        name: str,
        *,
        target_def: Optional[ast.AST],
        import_targets: dict[int, set[str]],
        exporters: set[str],
    );
    def run(tree: ast.Module) -> tuple[list[_Occurrence], bool];
    def _names_exporter(dotted: Optional[str]) -> bool;
    def _owner(scope: _PyScope) -> _PyScope;

    def _use(scope: _PyScope, line: int, byte_col: int, site: str = "reference");
    def _use_after(scope: _PyScope, line: int, byte_col: int, prefix: str = "");

    def _def_name_col(
        `node: Union[ast.FunctionDef, ast.AsyncFunctionDef, ast.ClassDef]
    ) -> Optional[int];
    def _string_entry_col(const: ast.Constant) -> Optional[int];
    def _collect_all(stmt: ast.stmt);

    def _visit(`node: ast.AST, scope: _PyScope);
    def _bind_import_module(`node: ast.Assign);

    def _visit_function(`node: Union[ast.FunctionDef, ast.AsyncFunctionDef], scope: _PyScope);

    def _visit_class(`node: ast.ClassDef, scope: _PyScope);

    def _bind_definition(
        `node: Union[ast.FunctionDef, ast.AsyncFunctionDef, ast.ClassDef], scope: _PyScope
    );

    def _visit_arguments(args: ast.arguments, scope: _PyScope);

    def _bind_arguments(args: ast.arguments, inner: _PyScope);

    def _visit_comprehension(
        `node: Union[ast.ListComp, ast.SetComp, ast.GeneratorExp, ast.DictComp], scope: _PyScope
    );

    def _alias_name_col(alias: ast.alias) -> int;

    def _alias_asname_col(alias: ast.alias) -> tuple[int, int];

    def _visit_import(`node: ast.Import, scope: _PyScope);

    def _visit_import_from(`node: ast.ImportFrom, scope: _PyScope);

    def __repr__ -> str;

    def __eq__(other: any) -> bool;

    def __hash__ -> int;
}

def _py_find_definition(tree: ast.Module, name: str, line: int) -> tuple[Optional[ast.AST], str];
def _python_rename_sites(
    store: GraphStore, `node: GraphNode, sources: _Sources, call_files: set[str]
) -> Optional[dict[str, list[_Occurrence]]];

def _ts_text(`node: Any) -> str;

def _ts_same(a: Any, b: Any) -> bool;

def _ts_string_value(`node: Any) -> str;
def _js_module_call_spec(`node: Any) -> Any;

def _js_is_declaration(leaf: Any) -> bool;
def _ts_ancestor(`node: Any, kinds: frozenset[str]) -> Any;
def _js_declaration_scope(leaf: Any) -> Any;

obj _JsScan {
    has src: any,
        name: any,
        new_name: any,
        def_lines: any,
        import_targets: any,
        exporters: any,
        resolve: any,
        renames: any,
        plain: any,
        kept: any,
        scopes: any,
        members: any,
        prefixes: any,
        barrels: any,
        reexports: any,
        local_export: any,
        found_definition: any,
        exported_definition: any,
        commonjs: any,
        `root: any;

    def init(
        source: _Source,
        name: str,
        new_name: str,
        *,
        def_lines: Optional[range],
        import_targets: dict[int, set[str]],
        exporters: set[str],
        resolve: Any,
    );

    def occurrence(leaf: Any, site: str, new: Optional[str] = None) -> _Occurrence;

    def declare(`node: Any, target: bool);

    def statement_targets(statement: Any) -> set[str];

    def run(`root: Any);
    def resolves_to_symbol(start: int, end: int) -> Optional[bool];

    has bound: bool {
        getter {
            return `any(target for (_s, _e, target) in self.scopes);
        }
    }

    has authoritative: bool {
        getter {
            return self.bound;
        }
    }

    has exports_by_name: bool {
        getter {
            return self.reexports or self.local_export or self.exported_definition;
        }
    }

    has exports: bool {
        getter {
            return self.exports_by_name or self.def_lines is not None and not self.commonjs;
        }
    }

    def visit_name(leaf: Any);
    def namespace(ident: Any, targets: set[str], scope: Any);
    def module_targets(spec: Any) -> set[str];
    def visit_module_value(declarator: Any);
    def visit_import_then(call: Any);

    def visit_import(statement: Any);

    def visit_import_specifier(spec: Any, targets: set[str], from_exporter: bool);

    def visit_reexport(statement: Any);

    def __repr__ -> str;

    def __eq__(other: any) -> bool;

    def __hash__ -> int;
}

def _js_reexport_files(store: GraphStore, sources: _Sources, name: str, home: str) -> list[str];
def _js_rename_sites(
    store: GraphStore, `node: GraphNode, new_name: str, sources: _Sources, graph_files: set[str]
) -> Optional[dict[str, _JsScan]];

def _ts_is_name_leaf(kind: str) -> bool;
def _ts_call_row(leaf: Any) -> Optional[int];
def _ts_in_comment_or_string(tree: Any, row: int, start: int, end: int) -> bool;
def _lexical_sites(
    sources: _Sources,
    source: _Source,
    lines: dict[int, str],
    name: str,
    new_name: str,
    mode: str = "any",
) -> list[_Occurrence];
def _locate_definition(
    sources: _Sources, source: _Source, `node: GraphNode, new_name: str
) -> Optional[_Occurrence];
def _rename_target(store: GraphStore, old_name: str) -> Optional[GraphNode];
def rename_preview(store: GraphStore, old_name: str, new_name: str) -> Optional[dict[str, Any]];
def _rename_edits(
    store: GraphStore, `node: GraphNode, new_name: str
) -> Optional[list[dict[str, Any]]];
def _is_entry_point(`node: Any) -> bool;

with entry {
    _MIN_PKG_SEGMENT_LEN = 4;
}

@functools.lru_cache(maxsize=4096)
def _path_segments(file_path: str) -> tuple[str, ...];

with entry {
    _TYPE_IDENT_RE = re.compile("[A-Z][A-Za-z0-9_]*");
}

def _collect_type_referenced_names(store: GraphStore) -> set[str];

with entry {
    _ASCII_FOLD = str.maketrans("ABCDEFGHIJKLMNOPQRSTUVWXYZ", "abcdefghijklmnopqrstuvwxyz");
}

def _ascii_fold(text: str) -> str;
def _csharp_member_scopes(conn: Any) -> dict[str, set[str]];
def find_dead_code(
    store: GraphStore,
    kind: Optional[str] = None,
    file_pattern: Optional[str] = None,
    `root: Optional[Union[str, Path]] = None,
) -> list[dict[str, Any]];
def suggest_refactorings(store: GraphStore) -> list[dict[str, Any]];
def _apply_file_edits(text: str, file_edits: list[dict[str, Any]]) -> tuple[str, int, int];
def apply_refactor(refactor_id: str, repo_root: Path, dry_run: bool = False) -> dict[str, Any];
