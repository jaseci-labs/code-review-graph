"""Tree-sitter based multi-language code parser.

Extracts structural nodes (classes, functions, imports, types) and edges
(calls, inheritance, contains) from source files.
"""

import builtins;

import operator;

import from __future__ { annotations }

import ast;

import hashlib;

import html;

import importlib;

import importlib.util;

import json;

import logging;

import math;

import os;

import re;

import subprocess;

import sys;

import threading;

import from bisect { bisect_left, bisect_right }

import from collections { deque }

import from collections.abc { Iterator }

import from dataclasses { dataclass, field }

import from functools { lru_cache }

import from pathlib { Path, PurePath }

import from typing { Any, NamedTuple, Optional }

import tomllib;

import yaml as _yaml;

import from yaml { MappingNode as _YamlMapping }

import from yaml { ScalarNode as _YamlScalar }

import from yaml { SequenceNode as _YamlSequence }

import from yaml.events { AliasEvent as _YamlAliasEvent }

"""Represents a single cell in a notebook with its language."""
class CellInfo(NamedTuple) {
    has cell_index: int;

    has language: str;

    has source: str;
}

glob _SQL_TABLE_RE: any;

glob _DBT_REF_RE: any;

glob _PYTHON_STAR_CACHE_MAX: any;

glob _PYTHON_STAR_EXPORT_CACHE: dict[tuple[str, int, int], dict[str, str]];

glob _PYTHON_STAR_EXPORT_CACHE_LOCK: any;

glob _PYTHON_MODULE_ALIAS_CACHE: dict[tuple[str, int, int], Optional[str]];

glob _PYTHON_MODULE_ALIAS_CACHE_LOCK: any;

glob _PYTHON_RETURN_ANNOTATION_CACHE: dict[tuple[str, int, int], dict[str, str]];

glob _PYTHON_RETURN_ANNOTATION_CACHE_LOCK: any;

glob _PYTHON_PROPERTY_RETURN_ANNOTATION_CACHE: dict[tuple[str, int, int], dict[tuple[str, str], str]];

glob _PYTHON_MODULE_CLASS_IDENTITY_CACHE: dict[tuple[str, int, int], dict[str, tuple[str, str]]];

glob _PYTHON_MODULE_CLASS_IDENTITY_CACHE_LOCK: any;

glob _PY_EXPR_RECEIVER_KEY: any;

glob _PY_CLASS_IDENTITY_PREFIX: any;

glob _PY_TUPLE_ANNOTATION_NAMES: any;

glob _PY_TARGET_PATTERN_TYPES: any;

glob _PY_SPLAT_PATTERN_TYPES: any;

glob _TRY_STMT_TYPES: tuple[Any, ...];

glob _MATCH_STMT_TYPES: tuple[Any, ...];

glob _SQL_KEYWORDS: frozenset[str];

glob logger: any;

glob _DEFAULT_PARSER_LOAD_TIMEOUT_SECONDS: any;

glob _PARSER_PROBE_RESULTS: dict[str, bool];

glob _PARSER_PROBE_FAILURE_DETAILS: dict[str, str];

glob _PARSER_PROBE_LOCK: any;

glob _PARSER_PROBE_GRAMMAR_LOCKS: dict[str, threading.Lock];

glob _EXPECTED_PARSER_LOAD_ERRORS: any;

glob _PhpPsr4Mappings: any;

glob _GO_MODULE_LINE_RE: any;

glob _GO_REPLACE_LINE_RE: any;

glob _RUBY_REQUIRE_PATHS_RE: any;

glob _RUBY_LOAD_PATH_RE: any;

glob _RUBY_IMPORT_METHODS: any;

glob _RUBY_IMPORT_PATH_ARGUMENT: any;

glob _GO_MOD_MAX_LINES: any;

glob EXTENSION_TO_LANGUAGE: dict[str, str];

glob _CPP_HEADER_EVIDENCE_TYPES: any;

glob _CPP_HEADER_EVIDENCE_QUALIFIERS: any;

glob _CPP_HEADER_NON_CODE_RE: any;

glob _CPP_HEADER_TEXT_EVIDENCE_RE: any;

glob _CPP_QT_STRUCTURAL_MACRO_REPLACEMENTS: any;

glob SHEBANG_INTERPRETER_TO_LANGUAGE: dict[str, str];

glob _SHEBANG_PROBE_BYTES: any;

glob _ANSIBLE_PATH_COMPONENTS: frozenset[str];

glob _ANSIBLE_PLAYBOOK_NAMES: frozenset[str];

glob _ANSIBLE_PLAY_KEYS: frozenset[str];

glob _ANSIBLE_MODULE_KEYS: frozenset[str];

glob _TASK_META_KEYS: frozenset[str];

glob _CLASS_TYPES: dict[str, list[str]];

glob _TS_HERITAGE_CLAUSES: any;

glob _TS_TYPE_DECLARATIONS: any;

glob _FUNCTION_TYPES: dict[str, list[str]];

glob _IMPORT_TYPES: dict[str, list[str]];

glob _CALL_TYPES: dict[str, list[str]];

glob _TEST_PATTERNS: any;

glob _SEP: any;

glob _ABSOLUTE_PATH_RE: any;

glob _TEST_DIR_PATTERNS: any;

glob _SINGULAR_TEST_DIR_RE: any;

glob _TEST_HELPER_DIR_PATTERNS: any;

glob _STORYBOOK_FILE_RE: any;

glob _TEST_NAME_PATTERNS: any;

glob _TEST_RUNNER_NAMES: any;

glob _RUBY_TEST_BLOCK_NAMES: any;

glob _RUBY_MEMO_BLOCK_NAMES: any;

glob _RUBY_DESCRIBING_BLOCK_NAMES: any;

glob _RUBY_CONSTANT_PATH_RE: any;

glob _RubyClassRef: any;

glob _JAVA_PACKAGE_QUALIFIED_TYPE: any;

glob _TEST_ANNOTATIONS: any;

glob _SPRING_STEREOTYPE_ANNOTATIONS: any;

glob _SPRING_INJECT_ANNOTATIONS: any;

glob _SPRING_PLACEHOLDER_RE: any;

glob _TEMPORAL_INTERFACE_ANNOTATIONS: any;

glob _TEMPORAL_METHOD_ANNOTATIONS: any;

glob _KAFKA_LISTENER_ANNOTATIONS: any;

glob _KAFKA_CONSUMER_TYPES: any;

glob _KAFKA_PRODUCER_TYPES: any;

glob _SPRING_SCHEDULED_ANNOTATIONS: any;

glob _SPRING_EVENT_LISTENER_ANNOTATIONS: any;

glob _SPRING_EVENT_PUBLISH_METHODS: any;

glob _JAVA_PACKAGE_KEY: any;

glob _JAVA_WILDCARD_KEY: any;

glob _SPRING_REQUEST_PREFIX_KEY: any;

glob _JS_IMPORT_ORIGINAL_PREFIX_KEY: any;

glob _PY_MODULE_BINDING_KEY: any;

glob _RUST_INLINE_MODULE_KEY: any;

glob _PY_LITERAL_VALUE_TYPES: any;

glob _SPRING_REQUEST_MAPPINGS: any;

glob _SPRING_WEBFLUX_HTTP_VERBS: any;

glob _HTTP_REQUEST_METHODS: any;

glob _VBNET_IDENT: any;

glob _VBNET_DOTTED_IDENT: any;

glob _VBNET_MODIFIER_WORDS: any;

glob _VBNET_MODIFIER_RE: any;

glob _VBNET_IMPORT_RE: any;

glob _VBNET_NAMESPACE_RE: any;

glob _VBNET_END_NAMESPACE_RE: any;

glob _VBNET_TYPE_RE: any;

glob _VBNET_END_TYPE_RE: any;

glob _VBNET_MEMBER_RE: any;

glob _VBNET_OPERATOR_RE: any;

glob _VBNET_END_MEMBER_RE: any;

glob _VBNET_INHERITS_RE: any;

glob _VBNET_IMPLEMENTS_RE: any;

glob _VBNET_NEW_RE: any;

glob _VBNET_CALL_RE: any;

glob _VBNET_CALL_KEYWORDS: any;

glob _RESCRIPT_IDENT: any;

glob _RESCRIPT_MODULE_RE: any;

glob _RESCRIPT_DECORATOR_PREFIX: any;

glob _RESCRIPT_LET_RE: any;

glob _RESCRIPT_EXTERNAL_RE: any;

glob _RESCRIPT_TYPE_RE: any;

glob _RESCRIPT_OPEN_RE: any;

glob _RESCRIPT_MODULE_ALIAS_RE: any;

glob _RESCRIPT_JSX_RE: any;

glob _RESCRIPT_MODULE_ATTR_RE: any;

glob _RESCRIPT_CALL_RE: any;

glob _RESCRIPT_KEYWORDS: any;

glob _is_test_file: any;

glob _MAX_DOCSTRING_CHARS: any;

glob _DOC_COMMENT_NODE_TYPES: any;

glob _DOC_COMMENT_SKIP_TYPES: any;

glob _DOC_COMMENT_WRAPPER_TYPES: any;

glob _CSHARP_SUMMARY_RE: any;

glob _XML_TAG_RE: any;

glob _DOC_PARAGRAPH_TAG_RE: any;

glob _DOC_INLINE_TAG_RE: any;

glob _DOC_BRIEF_RE: any;

glob _PHPUNIT_TEST_ATTRIBUTE: any;

glob _PHP_TEST_DOC_TAG_RE: any;

glob _SEPARATE_SCOPE_RULE_LANGUAGES: any;

glob _HCL_REF_PREFIXES: frozenset[str];

glob _HCL_RECURSE_TYPES: frozenset[str];

glob _HCL_BLOCK_CFG: dict[str, tuple[str, str, int, bool]];

glob _JSON_VALUE_TYPES: any;

glob _JSON_DATA_DIR_NAMES: any;

glob _HTML_SECTION_TAGS: any;

glob _HTML_HEADING_TAGS: any;

glob _HTML_TEMPLATE_MARKERS: any;

glob _HTML_JAVASCRIPT_TYPES: any;

glob _HTML_TYPESCRIPT_TYPES: any;

glob _XSLT_NAMESPACE: any;

glob _XSLT_NAMED_STEP_RE: any;

glob _YAML_SIMPLE_PATH_SEGMENT: any;

glob _LOCALE_DIR_NAMES: any;

glob _LANGUAGE_TAG_RE: any;

glob _LANGUAGE_CODES: any;

glob _POWERSHELL_NUMBER_PATTERN: any;

glob _POWERSHELL_RANGE_RE: any;

glob _POWERSHELL_SCOPE_RE: any;

glob _PLSQL_IDENT_RE: any;

glob _PLSQL_ROUTINE_RE: any;

with entry {
    _SQL_TABLE_RE = re.compile(
        "(?:FROM|JOIN|INTO|CREATE\\s+(?:OR\\s+REPLACE\\s+)?(?:TABLE|VIEW)(?:\\s+IF\\s+NOT\\s+EXISTS)?|INSERT\\s+OVERWRITE)\\s+((?:`[^`]+`|\\w+)(?:\\.(?:`[^`]+`|\\w+))*)",
        re.IGNORECASE,
    );
    _DBT_REF_RE = re.compile(
        "\\{\\{-?\\s*(ref|source)\\s*\\(\\s*['\\\"]([^'\\\"]+)['\\\"](?:\\s*,\\s*['\\\"]([^'\\\"]+)['\\\"])?\\s*\\)",
    );

    _PYTHON_STAR_CACHE_MAX = 15000;
    _PYTHON_STAR_EXPORT_CACHE = {};
    _PYTHON_STAR_EXPORT_CACHE_LOCK = threading.RLock();
    _PYTHON_MODULE_ALIAS_CACHE = {};
    _PYTHON_MODULE_ALIAS_CACHE_LOCK = threading.Lock();
    _PYTHON_RETURN_ANNOTATION_CACHE = {};
    _PYTHON_RETURN_ANNOTATION_CACHE_LOCK = threading.RLock();
    _PYTHON_PROPERTY_RETURN_ANNOTATION_CACHE = {};
    _PYTHON_MODULE_CLASS_IDENTITY_CACHE = {};
    _PYTHON_MODULE_CLASS_IDENTITY_CACHE_LOCK = threading.RLock();
    _PY_EXPR_RECEIVER_KEY = "\x00expr:";
    _PY_CLASS_IDENTITY_PREFIX = "\x00python-class\x00";

    _PY_TUPLE_ANNOTATION_NAMES = frozenset({"Tuple", "tuple"});
    _PY_TARGET_PATTERN_TYPES = frozenset({
        "list",
        "list_pattern",
        "pattern_list",
        "tuple",
        "tuple_pattern",
    });
    _PY_SPLAT_PATTERN_TYPES = frozenset({"list_splat", "list_splat_pattern"});
}

"""Keep a class's defining module attached to its receiver evidence."""
def _python_qualified_class_identity(file_path: str, class_name: str) -> str;

def _python_split_class_identity(identity: str) -> Optional[tuple[str, str]];

"""Everything one Python file says about the names it binds.

    Read-only for the duration of a parse: the declaration scan fills it in
    once, then the scope walk consults it. ``symbol_origins`` is the only
    field that can lead outside the file, and it leads only to a module the
    file's own ``from`` statement names — never to a guess.
    """
class _PyReceiverContext(NamedTuple) {
    has file_path: str;

    has class_names: frozenset[str];

    has imported_names: frozenset[str];

    has module_bindings: dict[str, set[str]];

    has symbol_origins: dict[str, str];

    has symbol_names: dict[str, str];

    has local_returns: dict[str, str];

    has property_returns: dict[tuple[str, str], str];
}

"""A stand-in parent for some of a tree-sitter node's children.

    ``CodeParser._extract_from_tree`` only reads its root's ``children``, so a
    group lets it visit a chosen subset exactly as a walk over the real parent
    would have visited them.
    """
class _NodeGroup(NamedTuple) {
    has children: list;
}

"""Read one Cargo manifest, keyed by immutable file identity metadata."""
@lru_cache(maxsize=512)
def _read_cargo_manifest(manifest_path: str, _mtime_ns: int, _size: int) -> dict[str, Any];

def _load_cargo_manifest(path: Path) -> dict[str, Any];

"""Collect names bound in one Python lexical scope."""
class _PythonScopeBindingVisitor(ast.NodeVisitor) {
    def init;

    def visit_Name(`node: ast.Name) -> None;

    def visit_FunctionDef(`node: ast.FunctionDef) -> None;

    def visit_AsyncFunctionDef(`node: ast.AsyncFunctionDef) -> None;

    def visit_ClassDef(`node: ast.ClassDef) -> None;

    def visit_Lambda(`node: ast.Lambda) -> None;

    def visit_Import(`node: ast.Import) -> None;

    def visit_ImportFrom(`node: ast.ImportFrom) -> None;

    def visit_Global(`node: ast.Global) -> None;
}

"""Return parameter and local names for each Python function position."""
def _python_function_scope_bindings(
    source: bytes
) -> dict[tuple[int, int], tuple[frozenset[str], frozenset[str]]];

"""Return unshadowed aliases for ``typing.TYPE_CHECKING``."""
def _python_type_checking_aliases(tree: ast.Module) -> tuple[frozenset[str], frozenset[str]];

glob type_checking_names_default_: any;

glob typing_modules_default_: any;

with entry {
    type_checking_names_default_ = frozenset();
    typing_modules_default_ = frozenset();
}

"""Return a truth value for the small constant subset we can prove."""
def _python_static_truth(
    `node: ast.expr,
    type_checking_names: frozenset[str] = type_checking_names_default_,
    typing_modules: frozenset[str] = typing_modules_default_,
) -> Optional[bool];

with entry {
    _TRY_STMT_TYPES = (ast.Try, ast.TryStar) if hasattr(ast, "TryStar") else (ast.Try,);
    _MATCH_STMT_TYPES = (ast.Match,) if hasattr(ast, "Match") else ();
}

"""Collect calls and attribute loads in statically unreachable branches."""
class _PythonUnreachableCallVisitor(ast.NodeVisitor) {
    def init(type_checking_names: frozenset[str], typing_modules: frozenset[str]);

    def visit_Module(`node: ast.Module) -> None;

    def visit_Call(`node: ast.Call) -> None;

    def visit_Attribute(`node: ast.Attribute) -> None;

    def visit_If(`node: ast.If) -> None;

    def visit_FunctionDef(`node: ast.FunctionDef) -> None;

    def visit_AsyncFunctionDef(`node: ast.AsyncFunctionDef) -> None;

    def visit_ClassDef(`node: ast.ClassDef) -> None;

    def _visit_function(`node: ast.FunctionDef | ast.AsyncFunctionDef) -> None;

    def _visit_statements(statements: list[ast.stmt], *, dead: bool) -> None;
}

"""Return positions of calls and attribute loads in proven-dead branches."""
@lru_cache(maxsize=128)
def _python_unreachable_call_positions(source: bytes) -> frozenset[tuple[int, int]];

"""Collect import statements in proven-dead branches, not calls."""
class _PythonUnreachableImportVisitor(_PythonUnreachableCallVisitor) {
    def visit_Call(`node: ast.Call) -> None;

    def visit_Attribute(`node: ast.Attribute) -> None;

    def visit_Import(`node: ast.Import) -> None;

    def visit_ImportFrom(`node: ast.ImportFrom) -> None;
}

"""Return positions of imports that never run, such as under ``if TYPE_CHECKING``.

    A bare ``TYPE_CHECKING`` counts whatever it is bound to: type checkers read
    any name spelled so as true, which is what ``TYPE_CHECKING = False`` relies on.
    """
@lru_cache(maxsize=128)
def _python_unreachable_import_positions(source: bytes) -> frozenset[tuple[int, int]];

"""Return True if *node* is *child_node* or one of its descendants.

    Compares byte ranges because the tree-sitter Python bindings create a
    fresh ``Node`` object on every ``child_by_field_name`` call, so ``is``
    identity fails even when both sides refer to the same tree node.
    """
def _node_is_in_child(`node, child_node) -> bool;

"""Return True if *cond* is a statically-false literal (non-Python).

    * ``parenthesized_expression`` (TS/JS wrap ``if (expr)``) is unwrapped.
    * ``false`` -- Go and TS/JS boolean literal.
    * ``number`` equal to ``0`` -- TS/JS ``if (0)``.
    """
def _is_statically_false_condition(cond) -> bool;

"""Return whether *child* enters a statically-dead branch of *parent*."""
def _is_static_dead_guard_child(parent, child) -> bool;

"""Return True if *node* sits in a statically-dead branch (non-Python).

    Walk the ancestor chain once, checking each parent-child edge:

    * Go / TS / JS ``if false`` / ``if (0)``.
    * C/C++ ``#if 0`` / ``#elif 0``.

    Neither walk stops at a function or class boundary. A declaration
    nested inside a dead branch is never evaluated, so calls in its body
    are dead too -- matching what the Python ``ast`` path above already
    does for a ``def`` or ``class`` under ``if False:``. Unlike Python,
    JS/TS class declarations are not hoisted, so there is no reachable
    symbol to preserve either.
    """
def _is_in_static_dead_guard(`node) -> bool;

"""Return True if *node* sits in the consequence of a Rust ``if false``.

    Rust's if is an ``if_expression`` and its false is a ``boolean_literal``.
    Both are shared with Kotlin and Scala, where ``if (false)`` is kept, so
    this walk is only called for Rust. The else branch and ``if true`` stay
    live, and only a literal ``false`` counts: ``false && false`` does not.

    The walk ends at an ``impl_item``. Rust impl blocks are non-local: one
    written inside a branch still applies to the type, so its methods and
    associated consts are reached from outside that branch, and their callees
    are live. Inheriting the guard from the declaration dropped those edges and
    reported real targets as dead code, which is worse than keeping a call that
    never runs. Everything else the branch encloses stays dead: a local ``fn``,
    ``mod`` or ``trait`` is scoped to the block, so a call in its body is
    unreachable. Guards written inside a body are still found, because the
    walk reaches them before the item boundary.
    """
def _is_in_rust_dead_guard(`node) -> bool;

with entry {
    _SQL_KEYWORDS = frozenset({
        "SELECT",
        "WHERE",
        "GROUP",
        "ORDER",
        "HAVING",
        "LIMIT",
        "OFFSET",
        "UNION",
        "INTERSECT",
        "EXCEPT",
        "AS",
        "ON",
        "USING",
        "SET",
        "VALUES",
        "DEFAULT",
        "NULL",
        "TRUE",
        "FALSE",
        "INNER",
        "OUTER",
        "LEFT",
        "RIGHT",
        "FULL",
        "CROSS",
        "NATURAL",
        "LATERAL",
        "RECURSIVE",
        "ONLY",
        "WITH",
        "IF",
        "NOT",
        "EXISTS",
    });

    logger = logging.getLogger(__name__);

    _DEFAULT_PARSER_LOAD_TIMEOUT_SECONDS = 5.0;
    _PARSER_PROBE_RESULTS = {};
    _PARSER_PROBE_FAILURE_DETAILS = {};
    _PARSER_PROBE_LOCK = threading.Lock();
    _PARSER_PROBE_GRAMMAR_LOCKS = {};
    _EXPECTED_PARSER_LOAD_ERRORS = (ImportError, LookupError, OSError, ValueError);
}

"""Return a safe positive timeout for native grammar probes."""
def _parser_load_timeout_seconds -> float;

"""Build the environment for a disposable grammar-load probe.

    The probe runs in a child interpreter so a hanging or crashing native
    grammar cannot take down the parent. The child must still be able to
    import the same ``tree_sitter_language_pack`` the parent can see
    (venv site-packages, ``pip install --user``, or a non-standard
    ``sys.path`` entry). Isolated mode (``python -I``) is intentionally
    avoided for this reason (#760, #807).
    """
def _parser_probe_env -> dict[str, str];

"""Return installable guidance for common probe failure modes."""
def _install_hint_for_probe_failure(detail: str) -> str | None;

"""Probe one native grammar in a disposable interpreter process."""
def _run_parser_load_probe(grammar: str, timeout_seconds: float) -> bool;

"""Return a process-cached result for one bounded grammar probe.

    A per-grammar lock covers the subprocess call so parallel parser users
    never start duplicate probes for the same grammar while distinct grammars
    can probe concurrently.
    """
def _parser_load_probe_succeeds(grammar: str, timeout_seconds: float | None = None) -> bool;

"""Prevent repeated parent-process loads after an expected failure."""
def _mark_parser_unavailable(grammar: str) -> None;

"""Clear process-level probe state (used by focused tests)."""
def _clear_parser_probe_cache -> None;

"""Load a probed grammar, suppressing only known availability errors."""
def _load_tree_sitter_parser(grammar: str) -> any;

with entry {
    _PhpPsr4Mappings = builtins.tuple[builtins.tuple[str, builtins.tuple[str, ...]], ...];
}

"""One import statement: its module string, its own line, and its form.

    ``line`` is the line of the individual specifier, not of the statement
    that encloses it: every spec in a Go ``import ( ... )`` block used to be
    stamped with the line of the ``import (`` token.

    ``form`` carries the language keyword when identical module strings
    resolve by different algorithms depending on it. Ruby needs it --
    ``require "x"`` searches the load paths while ``require_relative "x"``
    searches the requiring file's own directory -- and it is part of the
    resolution cache key. ``None`` for the languages with a single form.

    ``context`` says when the import does not run as the file loads. See
    ``IMPORT_CONTEXT_KEY``. ``None`` means it does.
    """
class _ImportSpec(NamedTuple) {
    has module: str;

    has line: int;

    has form: Optional[str] = None;

    has context: Optional[str] = None;
}

"""One ``go.mod``: its directory, the module path it declares, and the
    ``replace`` directives that redirect a module prefix to a local path."""
class _GoModule(NamedTuple) {
    has `root: Path;

    has path: str;

    has replacements: tuple[tuple[str, str], ...];
}

with entry {
    _GO_MODULE_LINE_RE = re.compile("^\\s*module\\s+\"?([^\\s\"]+)\"?\\s*(?://.*)?$");
    _GO_REPLACE_LINE_RE = re.compile(
        "^\\s*(?:replace\\s+)?([^\\s=>]+)(?:\\s+v\\S+)?\\s*=>\\s*(\\S+)(?:\\s+v\\S+)?\\s*(?://.*)?$"
    );
    _RUBY_REQUIRE_PATHS_RE = re.compile(
        "require_paths?\\s*=\\s*(?:\\[([^\\]]*)\\]|%w[\\[({]([^\\])}]*)[\\])}]|(['\"])([^'\"]+)\\3)"
    );
    _RUBY_LOAD_PATH_RE = re.compile(
        "(?:\\$LOAD_PATH|\\$:)\\s*(?:\\.unshift|\\.push|<<)\\s*\\(?\\s*(?:File\\.expand_path\\(\\s*)?(['\"])([^'\"]+)\\1\\s*(?:,\\s*(__dir__|__FILE__))?",
    );
    _RUBY_IMPORT_METHODS = frozenset({
        "require",
        "require_relative",
        "load",
        "autoload",
        "require_all",
    });
    _RUBY_IMPORT_PATH_ARGUMENT = {"autoload": 1};
    _GO_MOD_MAX_LINES = 2000;
}

"""Read the module path and local ``replace`` targets from one go.mod.

    The declared module path is the only thing that tells this repository's
    own packages (``github.com/cli/cli/v2/pkg/cmdutil``) from a dependency
    (``github.com/spf13/cobra``), so without it there is no anchor to
    resolve from. Cached on (path, mtime, size) like the composer.json
    reader, so a whole-repository build reads each go.mod once.

    Returns ``("", ())`` when the file is unreadable or declares no module.
    """
@lru_cache(maxsize=256)
def _read_go_mod(
    go_mod_path: str, _mtime_ns: int, _size: int
) -> tuple[str, tuple[tuple[str, str], ...]];

"""Read ``require_paths`` from one .gemspec.

    A gemspec that declares none still has load roots: RubyGems defaults
    ``require_paths`` to ``["lib"]``, which is what jekyll, rubocop and most
    gems rely on.
    """
@lru_cache(maxsize=64)
def _read_gemspec_require_paths(gemspec_path: str, _mtime_ns: int, _size: int) -> tuple[str, ...];

"""Return whether *path* is inside *root* after both are resolved."""
def _path_is_within(path: Path, `root: Path) -> bool;

"""Read immutable, shape-safe PSR-4 mappings from one composer.json."""
@lru_cache(maxsize=128)
def _read_php_composer_psr4(
    composer_path: str, repo_root: str, _mtime_ns: int, _size: int
) -> _PhpPsr4Mappings;

@dataclass
class NodeInfo {
    has kind: str;

    has name: str;

    has file_path: str;

    has line_start: int;

    has line_end: int;

    has language: str = "";

    has parent_name: Optional[str] = None;

    has params: Optional[str] = None;

    has return_type: Optional[str] = None;

    has modifiers: Optional[str] = None;

    has is_test: bool = False;

    has extra: dict = field(default_factory=dict[any, any]);

    has identity_name: Optional[str] = None;

    def postinit -> None;
}

@dataclass
class EdgeInfo {
    has kind: str;

    has source: str;

    has target: str;

    has file_path: str;

    has line: int = 0;

    has extra: dict = field(default_factory=dict[any, any]);

    def postinit -> None;
}

with entry {
    EXTENSION_TO_LANGUAGE = {
        ".py": "python",
        ".js": "javascript",
        ".jsx": "javascript",
        ".ts": "typescript",
        ".mts": "typescript",
        ".cts": "typescript",
        ".tsx": "tsx",
        ".go": "go",
        ".rs": "rust",
        ".java": "java",
        ".cs": "csharp",
        ".rb": "ruby",
        ".cpp": "cpp",
        ".cc": "cpp",
        ".cxx": "cpp",
        ".c": "c",
        ".h": "c",
        ".hpp": "cpp",
        ".hh": "cpp",
        ".kt": "kotlin",
        ".kts": "kotlin",
        ".swift": "swift",
        ".php": "php",
        ".scala": "scala",
        ".sol": "solidity",
        ".vue": "vue",
        ".html": "html",
        ".htm": "html",
        ".dart": "dart",
        ".r": "r",
        ".mjs": "javascript",
        ".cjs": "javascript",
        ".astro": "typescript",
        ".pl": "perl",
        ".pm": "perl",
        ".t": "perl",
        ".xs": "c",
        ".lua": "lua",
        ".luau": "luau",
        ".m": "objc",
        ".sh": "bash",
        ".bash": "bash",
        ".zsh": "bash",
        ".ksh": "bash",
        ".ex": "elixir",
        ".exs": "elixir",
        ".ipynb": "notebook",
        ".zig": "zig",
        ".ps1": "powershell",
        ".psm1": "powershell",
        ".psd1": "powershell",
        ".svelte": "svelte",
        ".jl": "julia",
        ".res": "rescript",
        ".resi": "rescript",
        ".gd": "gdscript",
        ".nix": "nix",
        ".sv": "verilog",
        ".svh": "verilog",
        ".v": "verilog",
        ".vh": "verilog",
        ".vb": "vbnet",
        ".sql": "sql",
        ".pls": "sql",
        ".plb": "sql",
        ".pks": "sql",
        ".pkb": "sql",
        ".pck": "sql",
        ".prc": "sql",
        ".fnc": "sql",
        ".trg": "sql",
        ".tf": "hcl",
        ".hcl": "hcl",
        ".properties": "properties",
        ".xsl": "xslt",
        ".xslt": "xslt",
        ".yml": "yaml",
        ".yaml": "yaml",
        ".json": "json",
        ".robot": "robot",
        ".resource": "robot",
        ".liquid": "liquid",
    };
    _CPP_HEADER_EVIDENCE_TYPES = frozenset({
        "access_specifier",
        "alias_declaration",
        "base_class_clause",
        "class_specifier",
        "concept_definition",
        "lambda_expression",
        "namespace_definition",
        "noexcept",
        "template_declaration",
        "trailing_return_type",
        "using_declaration",
    });

    _CPP_HEADER_EVIDENCE_QUALIFIERS = frozenset({b"consteval", b"constinit"});
    _CPP_HEADER_NON_CODE_RE = re.compile(
        b"/\\*.*?(?:\\*/|\\Z)|//[^\\n]*|\"(?:[^\"\\\\\\n]|\\\\.)*\"|'(?:[^'\\\\\\n]|\\\\.)*'",
        re.DOTALL,
    );
    _CPP_HEADER_TEXT_EVIDENCE_RE = re.compile(
        b"\\b(?:class|namespace|template|concept|using|public|private|protected|constexpr|noexcept|consteval|constinit|Q_SIGNALS)\\b|::|->|\\benum\\b[^;{}]{0,1024}\\bstruct\\b|\\b(?:struct|union)\\b[^;{}]{0,1024}:|\\]\\s*(?:\\[\\[|[^\\s;,)=\\[\\].+\\-*/%&|^!?:>])",
    );

    _CPP_QT_STRUCTURAL_MACRO_REPLACEMENTS = {
        b"QT_BEGIN_NAMESPACE": b" " * len(b"QT_BEGIN_NAMESPACE"),
        b"QT_END_NAMESPACE": b" " * len(b"QT_END_NAMESPACE"),
        b"Q_OBJECT": b" " * len(b"Q_OBJECT"),
        b"Q_SIGNALS": b"public" + b" " * (len(b"Q_SIGNALS") - len(b"public")),
        b"Q_SLOTS": b" " * len(b"Q_SLOTS"),
        b"Q_EMIT": b" " * len(b"Q_EMIT"),
    };
    SHEBANG_INTERPRETER_TO_LANGUAGE = {
        "bash": "bash",
        "sh": "bash",
        "zsh": "bash",
        "ksh": "bash",
        "dash": "bash",
        "ash": "bash",
        "python": "python",
        "python2": "python",
        "python3": "python",
        "pypy": "python",
        "pypy3": "python",
        "node": "javascript",
        "nodejs": "javascript",
        "ruby": "ruby",
        "perl": "perl",
        "lua": "lua",
        "Rscript": "r",
        "php": "php",
    };
    _SHEBANG_PROBE_BYTES = 256;
    _ANSIBLE_PATH_COMPONENTS = frozenset({
        "playbooks",
        "roles",
        "tasks",
        "handlers",
        "group_vars",
        "host_vars",
    });
    _ANSIBLE_PLAYBOOK_NAMES = frozenset({
        "site.yml",
        "site.yaml",
        "main.yml",
        "main.yaml",
        "install.yml",
        "install.yaml",
        "deploy.yml",
        "deploy.yaml",
    });
    _ANSIBLE_PLAY_KEYS = frozenset({
        "tasks",
        "handlers",
        "pre_tasks",
        "post_tasks",
        "roles",
        "gather_facts",
        "become",
        "become_user",
        "become_method",
        "serial",
        "strategy",
        "vars_files",
        "vars_prompt",
        "any_errors_fatal",
        "max_fail_percentage",
        "ignore_errors",
    });
    _ANSIBLE_MODULE_KEYS = frozenset({
        "apt",
        "yum",
        "dnf",
        "package",
        "pip",
        "copy",
        "template",
        "file",
        "service",
        "systemd",
        "command",
        "shell",
        "raw",
        "git",
        "user",
        "stat",
        "include_tasks",
        "import_tasks",
        "include_role",
        "import_role",
        "set_fact",
        "debug",
        "fail",
        "assert",
        "wait_for",
        "pause",
        "lineinfile",
        "blockinfile",
        "get_url",
        "uri",
        "unarchive",
        "add_host",
        "group_by",
        "include_vars",
    });
    _TASK_META_KEYS = frozenset({
        "name",
        "when",
        "loop",
        "loop_control",
        "with_items",
        "with_first_found",
        "with_fileglob",
        "with_dict",
        "with_subelements",
        "with_nested",
        "with_sequence",
        "with_indexed_items",
        "register",
        "notify",
        "tags",
        "become",
        "become_user",
        "become_method",
        "ignore_errors",
        "vars",
        "no_log",
        "check_mode",
        "environment",
        "any_errors_fatal",
        "run_once",
        "delegate_to",
        "delegate_facts",
        "block",
        "rescue",
        "always",
        "changed_when",
        "failed_when",
        "retries",
        "delay",
        "until",
        "listen",
        "connection",
        "timeout",
    });
    _CLASS_TYPES = {
        "python": ["class_definition"],
        "javascript": ["class_declaration", "class"],
        "typescript": [
            "class_declaration",
            "abstract_class_declaration",
            "class",
            "interface_declaration",
            "type_alias_declaration",
            "enum_declaration",
        ],
        "tsx": [
            "class_declaration",
            "abstract_class_declaration",
            "class",
            "interface_declaration",
            "type_alias_declaration",
            "enum_declaration",
        ],
        "go": ["type_declaration"],
        "rust": ["struct_item", "enum_item", "trait_item"],
        "java": ["class_declaration", "interface_declaration", "enum_declaration"],
        "c": ["struct_specifier", "type_definition"],
        "cpp": ["class_specifier", "struct_specifier"],
        "csharp": [
            "class_declaration",
            "interface_declaration",
            "enum_declaration",
            "struct_declaration",
            "record_declaration",
        ],
        "ruby": ["class", "module"],
        "r": [],
        "perl": ["package_statement", "class_statement", "role_statement"],
        "kotlin": ["class_declaration", "object_declaration"],
        "swift": ["class_declaration", "protocol_declaration"],
        "php": [
            "class_declaration",
            "interface_declaration",
            "trait_declaration",
            "enum_declaration",
        ],
        "scala": ["class_definition", "trait_definition", "object_definition", "enum_definition"],
        "solidity": [
            "contract_declaration",
            "interface_declaration",
            "library_declaration",
            "struct_declaration",
            "enum_declaration",
            "error_declaration",
            "user_defined_type_definition",
        ],
        "dart": ["class_definition", "mixin_declaration", "enum_declaration"],
        "lua": [],
        "luau": ["type_definition"],
        "objc": ["class_interface", "class_implementation", "protocol_declaration"],
        "bash": [],
        "elixir": [],
        "nix": [],
        "zig": [],
        "powershell": ["class_statement"],
        "julia": ["struct_definition", "abstract_definition", "module_definition"],
        "verilog": [
            "module_declaration",
            "interface_declaration",
            "class_declaration",
            "package_declaration",
        ],
        "gdscript": ["class_definition", "class_name_statement"],
        "sql": [],
        "hcl": [],
    };
    _TS_HERITAGE_CLAUSES = frozenset({
        "extends_clause",
        "implements_clause",
        "extends_type_clause",
    });
    _TS_TYPE_DECLARATIONS = frozenset({
        "class_declaration",
        "abstract_class_declaration",
        "interface_declaration",
        "type_alias_declaration",
        "enum_declaration",
    });

    _FUNCTION_TYPES = {
        "python": ["function_definition"],
        "javascript": [
            "function_declaration",
            "generator_function_declaration",
            "method_definition",
            "arrow_function",
        ],
        "typescript": [
            "function_declaration",
            "generator_function_declaration",
            "method_definition",
            "abstract_method_signature",
            "arrow_function",
        ],
        "tsx": [
            "function_declaration",
            "generator_function_declaration",
            "method_definition",
            "abstract_method_signature",
            "arrow_function",
        ],
        "go": ["function_declaration", "method_declaration"],
        "rust": ["function_item", "function_signature_item"],
        "java": ["method_declaration", "constructor_declaration"],
        "c": ["function_definition"],
        "cpp": ["function_definition", "declaration", "field_declaration"],
        "csharp": ["method_declaration", "constructor_declaration"],
        "ruby": ["method", "singleton_method"],
        "r": ["function_definition"],
        "perl": ["subroutine_declaration_statement", "method_declaration_statement"],
        "kotlin": ["function_declaration"],
        "swift": [
            "function_declaration",
            "init_declaration",
            "deinit_declaration",
            "subscript_declaration",
        ],
        "php": ["function_definition", "method_declaration"],
        "scala": ["function_definition", "function_declaration"],
        "solidity": [
            "function_definition",
            "constructor_definition",
            "modifier_definition",
            "event_definition",
            "fallback_receive_definition",
        ],
        "dart": ["function_signature"],
        "lua": ["function_declaration"],
        "luau": ["function_declaration"],
        "objc": ["method_definition", "function_definition"],
        "bash": ["function_definition"],
        "elixir": [],
        "nix": [],
        "zig": [],
        "powershell": ["function_statement", "class_method_definition"],
        "julia": ["function_definition", "macro_definition"],
        "verilog": ["task_declaration", "function_declaration", "always_construct"],
        "gdscript": ["function_definition"],
        "sql": [],
        "hcl": [],
    };

    _IMPORT_TYPES = {
        "python": ["import_statement", "import_from_statement"],
        "javascript": ["import_statement"],
        "typescript": ["import_statement"],
        "tsx": ["import_statement"],
        "go": ["import_declaration"],
        "rust": ["use_declaration"],
        "java": ["import_declaration"],
        "c": ["preproc_include"],
        "cpp": ["preproc_include"],
        "csharp": ["using_directive"],
        "ruby": ["call"],
        "r": ["call"],
        "perl": ["use_statement", "require_expression"],
        "kotlin": ["import_header"],
        "swift": ["import_declaration"],
        "php": [
            "namespace_use_declaration",
            "include_expression",
            "include_once_expression",
            "require_expression",
            "require_once_expression",
        ],
        "scala": ["import_declaration"],
        "solidity": ["import_directive"],
        "dart": ["import_or_export"],
        "lua": [],
        "luau": [],
        "objc": ["preproc_include"],
        "bash": [],
        "elixir": [],
        "nix": [],
        "zig": [],
        "powershell": [],
        "julia": ["import_statement", "using_statement"],
        "verilog": ["package_import_declaration"],
        "gdscript": ["extends_statement"],
        "sql": [],
        "hcl": [],
    };

    _CALL_TYPES = {
        "python": ["call"],
        "javascript": ["call_expression", "new_expression"],
        "typescript": ["call_expression", "new_expression"],
        "tsx": ["call_expression", "new_expression"],
        "go": ["call_expression"],
        "rust": ["call_expression", "macro_invocation"],
        "java": ["method_invocation", "object_creation_expression", "method_reference"],
        "c": ["call_expression"],
        "cpp": ["call_expression"],
        "csharp": ["invocation_expression", "object_creation_expression"],
        "ruby": ["call"],
        "r": ["call"],
        "perl": [
            "function_call_expression",
            "method_call_expression",
            "ambiguous_function_call_expression",
        ],
        "kotlin": ["call_expression"],
        "swift": ["call_expression"],
        "php": [
            "function_call_expression",
            "member_call_expression",
            "scoped_call_expression",
            "nullsafe_member_call_expression",
            "object_creation_expression",
        ],
        "scala": ["call_expression", "instance_expression", "generic_function"],
        "solidity": ["call_expression"],
        "lua": ["function_call"],
        "luau": ["function_call"],
        "objc": ["message_expression", "call_expression"],
        "bash": ["command"],
        "elixir": [],
        "nix": [],
        "zig": [],
        "powershell": ["command"],
        "julia": ["call_expression", "broadcast_call_expression", "macrocall_expression"],
        "verilog": [
            "module_instantiation",
            "interface_instantiation",
            "function_subroutine_call",
            "subroutine_call",
            "system_tf_call",
        ],
        "gdscript": ["call", "attribute_call"],
        "sql": [],
        "hcl": [],
    };
}

"""All built-in language identifiers.

    Used to stop config-driven custom languages (languages.toml) from
    shadowing a built-in language name — built-ins always win.
    """
def _builtin_language_names -> frozenset[str];

with entry {
    _TEST_PATTERNS = [
        re.compile("^test_"),
        re.compile("^Test"),
        re.compile("_test$"),
        re.compile("\\.test\\."),
        re.compile("\\.spec\\."),
        re.compile("_spec$"),
    ];
    _SEP = "(?:^|[\\\\/])";
    _ABSOLUTE_PATH_RE = re.compile("^(?:/|[A-Za-z]:/|//)");
    _TEST_DIR_PATTERNS = [
        re.compile(_SEP + "tests[\\\\/]"),
        re.compile(_SEP + "__tests__[\\\\/]"),
        re.compile(_SEP + "e2e[_-]?tests?[\\\\/]"),
        re.compile(_SEP + "testthat[\\\\/]"),
        re.compile(_SEP + "specs?[\\\\/].*\\.(?:rb|rake)$"),
    ];
    _SINGULAR_TEST_DIR_RE = re.compile(_SEP + "test[\\\\/]");
    _TEST_HELPER_DIR_PATTERNS = [re.compile(_SEP + "test[_-]utils?[\\\\/]")];
    _STORYBOOK_FILE_RE = re.compile("\\.stories\\.[jt]sx?$");
    _TEST_NAME_PATTERNS = [
        re.compile("^test_.*\\.py$"),
        re.compile("_test\\.py$"),
        re.compile("^conftest\\.py$"),
        re.compile("\\.(?:test|spec)\\.[cm]?[jt]sx?$"),
        _STORYBOOK_FILE_RE,
        re.compile("_test\\.go$"),
        re.compile("_(?:test|spec)\\.rb$"),
        re.compile("[a-z0-9]Tests?\\.(?:java|kt|kts|scala|groovy)$"),
        re.compile("[a-z0-9]Tests?\\.cs$"),
        re.compile("[a-z0-9]Test\\.php$"),
        re.compile("_test\\.dart$"),
        re.compile("^test[_-].*\\.[rR]$"),
        re.compile("\\.tests\\.ps1$", re.IGNORECASE),
        re.compile("[_.]test\\.resi?$"),
        re.compile("^runtests\\.jl$"),
    ];

    _TEST_RUNNER_NAMES = frozenset({
        "describe",
        "it",
        "test",
        "beforeEach",
        "afterEach",
        "beforeAll",
        "afterAll",
        "suite",
    });
    _RUBY_TEST_BLOCK_NAMES = frozenset({
        "describe",
        "context",
        "it",
        "specify",
        "example",
        "test",
        "feature",
        "scenario",
        "shared_examples",
        "shared_context",
        "before",
        "after",
        "around",
        "setup",
        "teardown",
        "let",
        "let!",
        "subject",
        "subject!",
    });
    _RUBY_MEMO_BLOCK_NAMES = frozenset({"let", "let!", "subject", "subject!"});
    _RUBY_DESCRIBING_BLOCK_NAMES = frozenset({"describe", "context"});
    _RUBY_CONSTANT_PATH_RE = re.compile("^[A-Z]\\w*(?:\\.[A-Z]\\w*)*$");
    _RubyClassRef = builtins.tuple[str, builtins.tuple[str, ...]];
    _JAVA_PACKAGE_QUALIFIED_TYPE = re.compile("(?:[a-z_$][\\w$]*\\.)+[A-Z][\\w$]*");
    _TEST_ANNOTATIONS = frozenset({
        "Test",
        "ParameterizedTest",
        "RepeatedTest",
        "TestFactory",
        "org.junit.Test",
        "org.junit.jupiter.api.Test",
        "test",
        "tokio::test",
        "async_std::test",
        "rstest",
        "rstest::rstest",
        "proptest",
    });
    _SPRING_STEREOTYPE_ANNOTATIONS = frozenset({
        "Component",
        "Service",
        "Repository",
        "Controller",
        "RestController",
        "Configuration",
        "Indexed",
        "ControllerAdvice",
        "RestControllerAdvice",
        "EventListener",
    });
    _SPRING_INJECT_ANNOTATIONS = frozenset({"Autowired", "Inject", "Resource"});
    _SPRING_PLACEHOLDER_RE = re.compile("\\$\\{([^{}]+)\\}");
    _TEMPORAL_INTERFACE_ANNOTATIONS = frozenset({"WorkflowInterface", "ActivityInterface"});
    _TEMPORAL_METHOD_ANNOTATIONS = frozenset({
        "WorkflowMethod",
        "ActivityMethod",
        "SignalMethod",
        "QueryMethod",
    });
    _KAFKA_LISTENER_ANNOTATIONS = frozenset({"KafkaListener", "KafkaHandler"});
    _KAFKA_CONSUMER_TYPES = frozenset({
        "KafkaReceiver",
        "ReactiveKafkaConsumerTemplate",
        "MessageListenerContainer",
        "ConcurrentMessageListenerContainer",
    });
    _KAFKA_PRODUCER_TYPES = frozenset({
        "KafkaTemplate",
        "KafkaOperations",
        "ReactiveKafkaProducerTemplate",
        "KafkaSender",
    });
    _SPRING_SCHEDULED_ANNOTATIONS = frozenset({"Scheduled", "Schedules"});

    _SPRING_EVENT_LISTENER_ANNOTATIONS = frozenset({"EventListener"});
    _SPRING_EVENT_PUBLISH_METHODS = frozenset({"publishEvent"});
    _JAVA_PACKAGE_KEY = "__crg_java_package__";
    _JAVA_WILDCARD_KEY = "__crg_java_wildcard__";
    _SPRING_REQUEST_PREFIX_KEY = "__crg_spring_request_prefix__:";
    _JS_IMPORT_ORIGINAL_PREFIX_KEY = "__crg_js_import_original__:";
    _PY_MODULE_BINDING_KEY = "__crg_py_module_binding__:";
    _RUST_INLINE_MODULE_KEY = "__crg_rust_inline_module__:";
    _PY_LITERAL_VALUE_TYPES = frozenset({
        "concatenated_string",
        "dictionary",
        "dictionary_comprehension",
        "false",
        "float",
        "generator_expression",
        "integer",
        "list",
        "list_comprehension",
        "set",
        "set_comprehension",
        "string",
        "true",
        "tuple",
    });
    _SPRING_REQUEST_MAPPINGS = {
        "DeleteMapping": ("DELETE",),
        "GetMapping": ("GET",),
        "PatchMapping": ("PATCH",),
        "PostMapping": ("POST",),
        "PutMapping": ("PUT",),
        "RequestMapping": (),
    };
    _SPRING_WEBFLUX_HTTP_VERBS = frozenset({"DELETE", "GET", "PATCH", "POST", "PUT"});
    _HTTP_REQUEST_METHODS = frozenset({
        "CONNECT",
        "DELETE",
        "GET",
        "HEAD",
        "OPTIONS",
        "PATCH",
        "POST",
        "PUT",
        "TRACE",
    });

    _VBNET_IDENT = "(?:[A-Za-z_][A-Za-z0-9_]*|\\[[^\\]\\r\\n]+\\])";
    _VBNET_DOTTED_IDENT = f"{_VBNET_IDENT}(?:\\.{_VBNET_IDENT})*";
    _VBNET_MODIFIER_WORDS = (
        "Public",
        "Private",
        "Protected",
        "Friend",
        "Partial",
        "Shared",
        "Static",
        "MustInherit",
        "NotInheritable",
        "Overridable",
        "Overrides",
        "MustOverride",
        "Overloads",
        "Default",
        "ReadOnly",
        "WriteOnly",
        "Shadows",
        "Async",
        "Iterator",
        "Declare",
        "Narrowing",
        "Widening",
    );
    _VBNET_MODIFIER_RE = "(?:(?:" + format("|".join(_VBNET_MODIFIER_WORDS), "") + ")\\s+)*";

    _VBNET_IMPORT_RE = re.compile("^\\s*Imports\\s+(.+?)\\s*$", re.IGNORECASE);
    _VBNET_NAMESPACE_RE = re.compile(
        f"^\\s*Namespace\\s+(?P<name>{_VBNET_DOTTED_IDENT})\\s*$", re.IGNORECASE
    );
    _VBNET_END_NAMESPACE_RE = re.compile("^\\s*End\\s+Namespace\\b", re.IGNORECASE);
    _VBNET_TYPE_RE = re.compile(
        f"^\\s*{_VBNET_MODIFIER_RE}(?P<kind>Class|Interface|Structure|Module|Enum)\\s+(?P<name>{_VBNET_IDENT})\\b(?P<rest>.*)$",
        re.IGNORECASE,
    );
    _VBNET_END_TYPE_RE = re.compile(
        "^\\s*End\\s+(?P<kind>Class|Interface|Structure|Module|Enum)\\b", re.IGNORECASE
    );
    _VBNET_MEMBER_RE = re.compile(
        f"^\\s*(?P<mods>{_VBNET_MODIFIER_RE})(?P<kind>Function|Sub|Property)\\s+(?P<name>{_VBNET_IDENT})\\b(?P<rest>.*)$",
        re.IGNORECASE,
    );
    _VBNET_OPERATOR_RE = re.compile(
        f"^\\s*(?P<mods>{_VBNET_MODIFIER_RE})(?P<kind>Operator)\\s+(?P<name>\\S+)\\s*(?P<rest>.*)$",
        re.IGNORECASE,
    );
    _VBNET_END_MEMBER_RE = re.compile(
        "^\\s*End\\s+(Function|Sub|Property|Operator)\\b", re.IGNORECASE
    );
    _VBNET_INHERITS_RE = re.compile("\\bInherits\\s+(.+?)\\s*$", re.IGNORECASE);
    _VBNET_IMPLEMENTS_RE = re.compile("\\bImplements\\s+(.+?)\\s*$", re.IGNORECASE);
    _VBNET_NEW_RE = re.compile(
        f"\\bNew\\s+(?P<target>{_VBNET_DOTTED_IDENT})\\s*(?:\\(Of\\b[^)]*\\))?\\s*\\(",
        re.IGNORECASE,
    );
    _VBNET_CALL_RE = re.compile(
        f"(?<![A-Za-z0-9_.])(?P<target>{_VBNET_DOTTED_IDENT})\\s*\\(", re.IGNORECASE
    );

    _VBNET_CALL_KEYWORDS = frozenset({
        "addhandler",
        "and",
        "andalso",
        "as",
        "call",
        "case",
        "catch",
        "class",
        "cobj",
        "continue",
        "ctype",
        "directcast",
        "do",
        "each",
        "else",
        "elseif",
        "end",
        "enum",
        "erase",
        "error",
        "event",
        "exit",
        "finally",
        "for",
        "function",
        "get",
        "gettype",
        "getxmlnamespace",
        "global",
        "gosub",
        "goto",
        "if",
        "implements",
        "imports",
        "inherits",
        "interface",
        "loop",
        "module",
        "mustinherit",
        "new",
        "next",
        "not",
        "nothing",
        "operator",
        "option",
        "or",
        "orelse",
        "property",
        "raiseevent",
        "redim",
        "rem",
        "removehandler",
        "resume",
        "return",
        "select",
        "set",
        "step",
        "stop",
        "structure",
        "sub",
        "synclock",
        "then",
        "throw",
        "to",
        "try",
        "typeof",
        "until",
        "using",
        "when",
        "while",
        "with",
        "withevents",
        "xor",
    });
}

"""Remove VB escaping while preserving dotted identity."""
def _vbnet_normalize_name(value: str) -> str;

"""Blank VB comments and string contents while preserving line numbers."""
def _strip_vbnet_noise(text: str) -> str;

"""Join explicit and parenthesized VB continuations with source ranges."""
def _vbnet_logical_lines(cleaned: str) -> list[tuple[int, int, str]];

"""Return one balanced parenthesized group and its exclusive end."""
def _vbnet_parenthesized(text: str, start: int) -> tuple[str, int] | None;

"""Split a comma list without splitting generic/array groups."""
def _vbnet_split_top_level(value: str) -> list[str];

def _vbnet_type_parameters(rest: str) -> tuple[list[str], str];

"""Extract parameters, return type, and method type parameters."""
def _vbnet_signature_parts(rest: str) -> tuple[Optional[str], Optional[str], list[str]];

def _vbnet_relationship_targets(value: str) -> list[str];

with entry {
    _RESCRIPT_IDENT = "[A-Za-z_][A-Za-z0-9_']*";
    _RESCRIPT_MODULE_RE = re.compile(
        "^\\s*module\\s+(?:type\\s+)?([A-Z][A-Za-z0-9_']*)\\s*[:=]", re.MULTILINE
    );
    _RESCRIPT_DECORATOR_PREFIX = "(?:@[A-Za-z_][A-Za-z0-9_']*(?:\\([^)]*\\))?\\s+)*";
    _RESCRIPT_LET_RE = re.compile(
        f"^\\s*{_RESCRIPT_DECORATOR_PREFIX}(?:let\\s+(?:rec\\s+)?|and\\s+)({_RESCRIPT_IDENT})\\b",
        re.MULTILINE,
    );
    _RESCRIPT_EXTERNAL_RE = re.compile(
        f"^\\s*{_RESCRIPT_DECORATOR_PREFIX}external\\s+({_RESCRIPT_IDENT})\\s*:", re.MULTILINE
    );
    _RESCRIPT_TYPE_RE = re.compile(
        f"^\\s*{_RESCRIPT_DECORATOR_PREFIX}type\\s+(?:rec\\s+)?({_RESCRIPT_IDENT})\\b", re.MULTILINE
    );
    _RESCRIPT_OPEN_RE = re.compile("^\\s*(open|include)\\s+([A-Z][A-Za-z0-9_'.]*)", re.MULTILINE);
    _RESCRIPT_MODULE_ALIAS_RE = re.compile(
        "^\\s*module\\s+([A-Z][A-Za-z0-9_']*)\\s*=\\s*([A-Z][A-Za-z0-9_']*(?:\\.[A-Za-z_][A-Za-z0-9_']*)*)\\s*$",
        re.MULTILINE,
    );
    _RESCRIPT_JSX_RE = re.compile(
        "(?:^|(?<=[\\s{(,>}]))<([A-Z][A-Za-z0-9_']*(?:\\.[A-Z][A-Za-z0-9_']*)*)\\b", re.MULTILINE
    );
    _RESCRIPT_MODULE_ATTR_RE = re.compile("@module\\(\\s*\"([^\"]+)\"\\s*\\)");
    _RESCRIPT_CALL_RE = re.compile(
        f"(?<![A-Za-z0-9_']){_RESCRIPT_IDENT}(?:\\.{_RESCRIPT_IDENT})*\\s*\\("
    );
    _RESCRIPT_CALL_RE = re.compile(
        "(?<![A-Za-z0-9_'])([A-Za-z_][A-Za-z0-9_']*(?:\\.[A-Za-z_][A-Za-z0-9_']*)*)\\s*\\("
    );
    _RESCRIPT_KEYWORDS = frozenset({
        "let",
        "rec",
        "and",
        "type",
        "module",
        "open",
        "include",
        "external",
        "if",
        "else",
        "switch",
        "when",
        "match",
        "fun",
        "true",
        "false",
        "for",
        "while",
        "mutable",
        "try",
        "catch",
        "throw",
        "assert",
        "lazy",
        "do",
        "in",
        "of",
        "as",
        "exception",
        "private",
        "constraint",
        "with",
        "downto",
        "to",
        "unpack",
        "async",
        "await",
    });
}

"""Replace ReScript comments and string/backtick content with spaces.

    Newlines are preserved so absolute offsets still map back to accurate
    line numbers. ReScript block comments may nest, so we track depth.
    """
def _strip_rescript_noise(text: str) -> str;

"""Compute brace depth at every offset in `cleaned` (comment/string-stripped).

    Returned array has length len(cleaned); `depth[i]` is the depth
    immediately before the character at position i.
    """
def _rescript_brace_depth_array(cleaned: str) -> list[int];

"""Find `module Name = { ... }` blocks and their offset/line ranges.

    Returns dicts with name, start/end offsets, start/end lines, and parent
    module name (or None for top-level).
    """
def _scan_rescript_modules(cleaned: str, offset_to_line) -> list[dict];

"""Return the POSIX spellings a path under *repo_root* may start with.

    Both the spelling the caller gave and its symlink-resolved form are
    returned: ``/tmp`` and ``/private/tmp`` name the same directory on macOS,
    and a graph built through one spelling is often queried through the other.
    """
@lru_cache(maxsize=64)
def _repo_root_prefixes(repo_root: str) -> tuple[str, ...];

"""Symlink-resolved POSIX spelling of *directory*, or "" if unresolvable."""
@lru_cache(maxsize=2048)
def _resolved_dir(directory: str) -> str;

def _strip_prefix(normalized: str, `root: str) -> Optional[str];

"""Return *normalized* relative to *repo_root*, or ``None`` if unknowable.

    ``None`` means "this path cannot be placed inside a repository", which
    happens in exactly two ways: the path is absolute and no root was given,
    or it is absolute and lies outside the root (a dependency, a generated
    file, a stale row from another checkout).  Callers must not fall back to
    the absolute path in that case — see :func:`is_test_file`.
    """
def _repo_relative_path(normalized: str, repo_root: "str | PurePath | None") -> Optional[str];

"""Whether *directory* is an importable Python package (has __init__.py)."""
@lru_cache(maxsize=256)
def _is_python_package_dir(directory: str) -> bool;

"""Whether the singular ``test/`` directory in *relative* is shipped code.

    ``django/test/client.py`` is production code: ``django/test/`` carries an
    ``__init__.py`` and sits inside the ``django`` package, so users import it
    as ``django.test``.  A top-level ``test/`` directory in an application is
    not shipped — its parent is the repository root, which is not a package —
    and neither is a ``test/`` directory holding a test-named module, which
    the filename rules have already claimed before this is reached.

    Returns False whenever the directories cannot be inspected (a relative
    path with no root, a graph queried away from its checkout, a deleted
    file), which keeps the conservative answer: the file stays test code.
    """
def _is_shipped_test_package(
    normalized: str, relative: str, repo_root: "str | PurePath | None"
) -> bool;

"""Return *path* as a POSIX path inside *repo_root*, or ``None``.

    ``None`` says the path cannot be placed inside the repository — it is
    absolute and either no root was given or it lies outside that root.  Any
    rule that reads meaning from a directory name (``tests/``, a package
    directory matched against an import specifier) needs this: the
    directories above a checkout belong to whoever cloned it, not to the
    project, and reading them as project structure is how a CI workspace
    named "test" silences an entire report.  See #1023.
    """
def repo_relative_path(
    path: "str | PurePath", repo_root: "str | PurePath | None" = None
) -> Optional[str];

"""Return whether *path* holds test code.

    Everything in a test file is test code: the test functions, the classes
    that group them, the fixtures and the private helpers they call.  Callers
    outside the parser use this to keep test-file symbols out of reports about
    production code.

    *repo_root* is required to answer directory conventions such as ``tests/``
    for an absolute path, because those directories must be inside the project.
    The graph stores absolute paths, so without a root a repository checked
    out under a directory named ``test`` (a CI workspace, a job directory)
    would have every production symbol classified as test code and the
    untested-code report would go silent.  When the root is unknown, or the
    path lies outside it, only the filename conventions apply; that under-
    reports test files but never hides a production gap.

    *include_helper_dirs* additionally claims ``test-utils/`` and
    ``test_utils/``.  Those directories are genuinely ambiguous — shared
    libraries are published from them — so only dead-code detection opts in,
    where over-suppressing costs less than a false "dead" report.
    """
def is_test_file(
    path: "str | PurePath",
    repo_root: "str | PurePath | None" = None,
    *,
    include_helper_dirs: bool = False,
) -> bool;

with entry {
    _is_test_file = is_test_file;
}

"""A function is a test if its name matches test patterns, it lives
    in a test file and has a test-runner name, or it has a @Test annotation.
    """
def _is_test_function(
    name: str,
    file_path: str,
    decorators: tuple[str, ...] = (),
    repo_root: "str | PurePath | None" = None,
) -> bool;

with entry {
    _MAX_DOCSTRING_CHARS = 400;
    _DOC_COMMENT_NODE_TYPES = frozenset({
        "comment",
        "block_comment",
        "line_comment",
        "doc_comment",
    });
    _DOC_COMMENT_SKIP_TYPES = frozenset({"attribute_item", "decorator"});
    _DOC_COMMENT_WRAPPER_TYPES = frozenset({"export_statement", "template_declaration"});
    _CSHARP_SUMMARY_RE = re.compile(
        "<summary(?:\\s[^>]*)?>(.*?)</summary\\s*>", re.IGNORECASE | re.DOTALL
    );
    _XML_TAG_RE = re.compile("<[^>]+>");
    _DOC_PARAGRAPH_TAG_RE = re.compile("</?(?:p|para)(?:\\s[^>]*)?>", re.IGNORECASE);
    _DOC_INLINE_TAG_RE = re.compile("\\{@(?:code|literal|link)\\s+([^}]+)\\}", re.IGNORECASE);
    _DOC_BRIEF_RE = re.compile("^\\s*[@\\\\]brief\\s+", re.IGNORECASE);
}

"""Return a whitespace-stable, first-paragraph documentation summary."""
def _clean_docstring_summary(raw: str, language: str) -> str;

"""Remove a Doxygen/Javadoc-style wrapper and per-line ``*`` prefix."""
def _strip_block_doc_comment(text: str) -> str;

"""Return annotation names from a ``modifiers`` child of *node*.

    Covers Java/Kotlin/C# where annotations live inside a ``modifiers``
    node as ``annotation`` / ``marker_annotation`` children. The leading
    ``@`` is stripped. See: #295
    """
def _modifier_annotation_names(`node) -> list[str];

"""Return decorators wrapping a Python definition in source order."""
def _python_decorator_names(`node) -> list[str];

"""Return C# attribute names from ``attribute_list`` children of *node*.

    C# attributes (``[HttpGet]``, ``[Authorize]``, ``[ApiController]``) are
    ``attribute_list`` nodes, each wrapping one or more ``attribute`` nodes
    whose first ``identifier`` is the attribute name. The bracket wrapper
    and any argument list are dropped. See: #295
    """
def _csharp_attribute_names(`node) -> list[str];

with entry {
    _PHPUNIT_TEST_ATTRIBUTE = "phpunit\\framework\\attributes\\test";
}

"""Return aliases that resolve specifically to PHPUnit's Test attribute."""
def _php_attribute_aliases(`node) -> dict[str, str];

"""Return PHP attribute names from ``attribute_list`` children of *node*.

    PHP 8 attributes (``#[Test]``, ``#[DataProvider('x')]``) are
    ``attribute_list`` nodes wrapping one or more ``attribute_group`` nodes,
    each wrapping one or more ``attribute`` nodes whose ``name`` child is the
    attribute name -- one level deeper than C#'s ``attribute_list >
    attribute``. See: #693
    """
def _php_attribute_names(`node) -> list[str];

with entry {
    _PHP_TEST_DOC_TAG_RE = re.compile("(?<![\\w-])@test(?![\\w-])");
}

"""Return True if a PHPUnit ``/** @test */`` docblock precedes *node*.

    PHPUnit's legacy convention marks a test method with an ``@test`` tag in
    the doc comment immediately above it, instead of a ``test_`` name prefix
    or a ``#[Test]`` attribute. Tree-sitter represents that comment as a
    preceding sibling of the ``method_declaration``, not a child, so it needs
    its own check rather than reuse of the attribute-based extraction above.
    See: #693
    """
def _php_docblock_marks_test(`node) -> bool;

with entry {
    _SEPARATE_SCOPE_RULE_LANGUAGES = frozenset({"python", "cpp", "julia", "csharp"});
}

"""Return the in-file scope chain a JVM import of a nested class names.

    ``import app.Outer.Inner`` resolves to ``app/Outer.java``; the class it
    names is ``Outer.Inner`` there, and its members carry that whole chain
    (#934). Any other import keeps *symbol* unchanged.
    """
def _nested_import_chain(module: str, resolved: str, symbol: str) -> str;

"""A C# binding declared *levels* containing types out from its use.

    A field of ``Outer`` used inside ``Outer.Inner`` names its type from
    ``Outer``, where an ``Inner.Service`` cannot shadow it. The value is still
    the type text, so every other consumer reads it as a plain string.
    """
class _OuterBinding(builtins.str) {
    has levels: int;

    static def __new__(cls, value: str, levels: int) -> "_OuterBinding";
}

"""Read a C# name without folding trivia into its identity."""
def _csharp_name(`node) -> str;

"""Innermost namespace body first; byte offsets distinguish reopened bodies.

    Some grammar versions put file-scoped namespace members beside the
    declaration rather than underneath it. Its scope still extends to EOF.
    The compilation unit has scope -1, distinct from a namespace at byte 0.
    """
def _csharp_namespace_context(`node) -> list[tuple[str, int]];

"""Namespaces a PHP file declares at its top level, in source order."""
def _php_namespaces(root_node) -> list[str];

"""Return all namespaces declared in a C# compilation unit.

    Handles both the block form (``namespace_declaration``) and the C# 10+
    file-scoped form (``file_scoped_namespace_declaration``). A single file
    may declare multiple namespaces; all are returned in source order.
    See: #310
    """
def _csharp_namespaces(root_node) -> list[str];

"""SHA-256 hash of file contents."""
def file_hash(path: Path) -> str;

"""Decode tree-sitter node bytes to a string."""
def _hcl_text(`node) -> str;

"""Return the first direct child whose type is in *types*, or None."""
def _hcl_child(`node, *types_: str) -> any;

"""Build *prefix.label0[.label1]* from the first *n_labels* labels, or None."""
def _hcl_block_name(prefix: str, labels: list[str], n_labels: int) -> Optional[str];

with entry {
    _HCL_REF_PREFIXES = frozenset({
        "var",
        "module",
        "local",
        "data",
        "each",
        "count",
        "self",
        "path",
        "terraform",
    });
}

"""Map a ``variable_expr.get_attr*`` chain to its canonical graph name."""
def _hcl_ref_target(`root: str, attrs: list[str], *, provider: bool = False) -> Optional[str];

"""Yield (root, attrs, line) for each ``variable_expr get_attr*`` chain
    that is a direct child sequence inside *expr_node*."""
def _hcl_variable_refs(expr_node) -> Generator[any, any, any];

with entry {
    _HCL_RECURSE_TYPES = frozenset({
        "expression",
        "body",
        "block",
        "attribute",
        "tuple",
        "object",
        "object_elem",
        "collection_value",
        "template_expr",
        "for_expr",
        "for_tuple_expr",
        "for_object_expr",
        "for_intro",
        "for_cond",
        "conditional",
        "function_call",
        "function_arguments",
        "quoted_template",
        "template_interpolation",
    });
}

"""Return loop-local symbols declared by a Terraform for-expression."""
def _hcl_for_iterator_names(for_expr_node) -> frozenset[str];

"""Return the iterator symbol for a ``dynamic`` block, or ``None``.

    Defaults to the dynamic block's string label (e.g. ``"setting"`` becomes
    the symbol ``setting``).  Can be overridden by an
    ``iterator = <ident>`` attribute inside the block body.  Returns ``None``
    when *block_node* is not a ``dynamic`` block.

    This is used by ``_walk_hcl_expressions`` to build a *local_names* scope
    so that iterator references such as ``setting.value[...]`` or
    ``origin_group.key`` do not produce spurious ``resource.*`` REFERENCES
    edges.
    """
def _hcl_dynamic_iterator_name(block_node) -> Optional[str];

with entry {
    _HCL_BLOCK_CFG = {
        "resource": ("Class", "resource", 2, True),
        "data": ("Class", "data", 2, True),
        "module": ("Class", "module", 1, True),
        "variable": ("Function", "var", 1, False),
        "output": ("Function", "output", 1, True),
        "provider": ("Function", "provider", 1, True),
    };
}

"""Return True if the path suggests an Ansible YAML file by directory convention."""
def _is_ansible_path(path: Path) -> bool;

"""Lightweight byte-scan: does this YAML look like an Ansible file?

    Checks that the file is a top-level list and contains at least one
    Ansible-specific structural marker (hosts, tasks, handlers, import_playbook,
    or a known module key / FQCN pattern).
    """
def _is_ansible_content(source: bytes) -> bool;

"""Classify an Ansible file by path convention.

    Returns one of: 'playbook', 'tasks', 'handlers', 'meta', 'vars', 'unknown'.
    """
def _ansible_file_type(path: Path) -> str;

"""Strip FQCN prefix: 'ansible.builtin.include_tasks' → 'include_tasks'."""
def _ansible_fqcn_short(key: str) -> str;

def _yaml_line(`node: object) -> int;

"""Return the last source line of *node*, 1-based and inclusive.

    A block collection or block scalar ends at the next token, so its end mark
    sits on the line of whatever follows, which may be a sibling key. When only
    indentation comes before the mark on that line, the node ended earlier: on
    the last line before it that is not blank.
    """
def _yaml_end_line(`node: object) -> int;

def _yaml_get_key(mapping_node: object, key: str) -> Optional[object];

with entry {
    _JSON_VALUE_TYPES = {
        "array": "array",
        "false": "boolean",
        "null": "null",
        "number": "number",
        "object": "object",
        "string": "string",
        "true": "boolean",
    };
    _JSON_DATA_DIR_NAMES = frozenset({
        "__fixtures__",
        "__mocks__",
        "__snapshots__",
        "data",
        "datasets",
        "demo",
        "demos",
        "doc",
        "docs",
        "example",
        "examples",
        "fixtures",
        "mocks",
        "sample",
        "samples",
        "snapshots",
        "test-data",
        "test_data",
        "testdata",
    });
}

"""Whether SQLite can store *key*: an escaped lone surrogate is not UTF-8."""
def _is_storable_key(key: str) -> bool;

"""Return a key's text with its escapes read, or None if it cannot be a path."""
def _json_key(key_node: Any) -> Optional[str];

def _yaml_scalar(`node: object) -> Optional[str];

with entry {
    _HTML_SECTION_TAGS = frozenset({"article", "div", "section"});
    _HTML_HEADING_TAGS = frozenset({"h1", "h2", "h3", "h4", "h5", "h6"});
    _HTML_TEMPLATE_MARKERS = ("{{", "{%", "<%", "${");
    _HTML_JAVASCRIPT_TYPES = frozenset({
        "",
        "application/ecmascript",
        "application/javascript",
        "application/x-javascript",
        "module",
        "text/babel",
        "text/ecmascript",
        "text/javascript",
        "text/jsx",
    });
    _HTML_TYPESCRIPT_TYPES = frozenset({"application/typescript", "text/typescript"});
}

"""Return the opening tag of an element, if the page has one."""
def _html_start_tag(element: Any) -> Any;

def _html_tag_name(start_tag: Any) -> str;

"""Read a tag's attributes. HTML names ignore case; the first one wins."""
def _html_attributes(start_tag: Any) -> dict[str, str];

"""Return the grammar for a script's text, or None when it holds data."""
def _html_script_language(attributes: dict[str, str]) -> Optional[str];

"""Whether a script's ``src`` names a file, not a URL or a template."""
def _html_is_local_src(src: str) -> bool;

"""Return a section's first heading, in its own words and capped.

    A nested section keeps its heading to itself. The prose is left out on
    purpose: this is a label for finding the section, not its content.
    """
def _html_first_heading(element: Any, max_chars: int) -> Optional[str];

with entry {
    _XSLT_NAMESPACE = "http://www.w3.org/1999/XSL/Transform";
    _XSLT_NAMED_STEP_RE = re.compile("@?[^\\W\\d][\\w.-]*(?::[^\\W\\d][\\w.-]*)?");
}

"""Return an element's tag name as written, prefix included."""
def _xml_name(element: Any) -> str;

"""Read an element's attributes with entities such as ``&gt;`` decoded."""
def _xml_attributes(element: Any) -> dict[str, str];

"""The namespaces in scope on *element*: its parent's, plus what it declares.

    The default namespace is keyed by the empty prefix.
    """
def _xml_scope(element: Any, parent: dict[str, str]) -> dict[str, str];

"""The local name of an XSLT element, or "" when it is in another namespace."""
def _xslt_local_name(element: Any, scope: dict[str, str]) -> str;

"""Return the elements directly inside *element*, in document order."""
def _xml_child_elements(element: Any) -> list[Any];

"""Split an XPath expression where *separator* is not inside ``[]`` or ``()``."""
def _xslt_split(expression: str, separator: str) -> list[str];

"""Return the names an expression ends on, one for each ``|`` alternative.

    A predicate narrows a match without changing what it names, so ``a/b[1]``
    ends on ``b``. An alternative with no name to read makes the whole answer
    empty: linking only the readable half would pass off a guess as the answer.
    """
def _xslt_named_steps(expression: str) -> set[str];

"""One top-level template or function, as read before its body is walked."""
@dataclass
class _XsltTemplate {
    has element: Any;

    has scope: dict[str, str];

    has `node: NodeInfo;

    has qualified: str;

    has modes: set[str];

    has steps: set[str];

    """Can the processor pick it by its ``match``, whether or not it has a name?"""
    has matches: bool {
        getter {
            return operator.ne(self.node.extra["xslt_kind"], "function")
                and "match" in self.node.extra;
        }
    }
}

with entry {
    _YAML_SIMPLE_PATH_SEGMENT = re.compile("^[A-Za-z_][A-Za-z0-9_-]*$");
    _LOCALE_DIR_NAMES = frozenset({"i18n", "l10n", "locale", "locales", "translations"});

    _LANGUAGE_TAG_RE = re.compile("([a-z]{2,3})(?:[-_@][a-z0-9]{2,8})*");
    _LANGUAGE_CODES = frozenset(
        "aa ab ae af ak am an ar as av ay az ba be bg bh bi bm bn bo br bs ca ce ch co cr cs cu cv cy da de dv dz ee el en eo es et eu fa ff fi fj fo fr fy ga gd gl gn gu gv ha he hi ho hr ht hu hy hz ia id ie ig ii ik io is it iu ja jv ka kg ki kj kk kl km kn ko kr ks ku kv kw ky la lb lg li ln lo lt lu lv mg mh mi mk ml mn mr ms mt my na nb nd ne ng nl nn no nr nv ny oc oj om or os pa pi pl ps pt qu rm rn ro ru rw sa sc sd se sg si sk sl sm sn so sq sr ss st su sv sw ta te tg th ti tk tl tn to tr ts tt tw ty ug uk ur uz ve vi vo wa wo xh yi yo za zh zu ast ceb ckb fil gsw haw hsb kab kmr nds sco szl tok tzl yue zgh".split(),
    );
}

"""Append a mapping key to a path without making dotted keys ambiguous."""
def _yaml_path_child(prefix: str, segment: str) -> str;

"""Return a bounded structural/scalar type label without exposing its value."""
def _yaml_value_type(`node: object) -> str;

"""Whether *text* is a language tag such as ``en``, ``pt-BR`` or ``zh_Hans``."""
def _is_language_tag(text: str) -> bool;

"""Whether *path* is a translation file, judged inside the repository.

    A translation catalogue repeats the same keys once per language, so it adds
    thousands of paths that say nothing about the code. It takes two pieces of
    evidence to call a file one. A translation folder alone is not enough
    (``locales/deploy.yml``), and neither is the name alone: ``config/en.yml``
    could be anything, and ``it.yml`` or ``no.yml`` are ordinary words. A file
    this misses keeps its paths, which costs some noise; a false match would
    lose real config, so doubtful files stay indexed.

    The folders above a checkout belong to whoever cloned it, so an absolute
    path with no root to read it against is never called a translation file.
    A relative path is already read as relative to the root, as everywhere else.
    """
def _is_locale_yaml(path: "str | PurePath", repo_root: "str | PurePath | None") -> bool;

"""True if this top-level sequence item is a definitive Ansible play or playbook import.

    Requires EITHER:
    - ``import_playbook:`` key (unambiguous), OR
    - ``hosts:`` key AND at least one key from ``_ANSIBLE_PLAY_KEYS``.

    A bare ``hosts: all`` without any other play key is too generic and is rejected.
    """
def _ansible_is_play_item(item: object) -> bool;

with entry {
    _POWERSHELL_NUMBER_PATTERN = "[+-]?(?:(?:0x[0-9a-f]+|0b[01]+)(?:u[ysl]?|[ysln])?|\\d+(?:u[ysl]?|[yslnd])?|(?:\\d+(?:\\.\\d*)?|\\.\\d+)(?:e[+-]?\\d+)?d?)(?:[kmgtp]b)?";
    _POWERSHELL_RANGE_RE = re.compile(
        f"{_POWERSHELL_NUMBER_PATTERN}\\.\\.(?:{_POWERSHELL_NUMBER_PATTERN}|\\$.*)?", re.IGNORECASE
    );
    _POWERSHELL_SCOPE_RE = re.compile("^(?:global|local|private|script):", re.IGNORECASE);

    _PLSQL_IDENT_RE = "[^\\W\\d][\\w$#]*";

    _PLSQL_ROUTINE_RE = f"{_PLSQL_IDENT_RE}(?:\\.{_PLSQL_IDENT_RE})*(?![\\w$#])\\s*(?:\\((?:[^();]|\\([^()]*\\))*\\)\\s*)?";
    local_names_default_ = frozenset();
    provider_attributes_default_ = frozenset();
    resolving_default_ = frozenset();
    resolving_default__ = frozenset();
}

glob local_names_default_: any;

glob provider_attributes_default_: any;

glob resolving_default_: any;

glob resolving_default__: any;

"""Parses source files using Tree-sitter and extracts structural information."""
class CodeParser(builtins.object) {
    static has _MODULE_CACHE_MAX: any = 15000;

    static has _MAX_HTML_BYTES: any = 2097152;

    static has _MAX_HTML_SECTIONS: any = 500;

    static has _MAX_HTML_HEADING_CHARS: any = 200;

    static has _MAX_XSLT_BYTES: any = 4194304;

    static has _MAX_XSLT_NAME_CHARS: any = 200;

    static has _MAX_XSLT_PATTERN_CHARS: any = 512;

    static has _MAX_XSLT_MODE_FANOUT: any = 20;

    static has _MAX_GENERIC_YAML_BYTES: any = 1048576;

    static has _MAX_YAML_DEPTH: any = 100;

    static has _MAX_YAML_NODES: any = 10000;

    static has _MAX_YAML_PATH_LENGTH: any = 512;

    static has _MAX_YAML_OCCURRENCE_SAMPLES: any = 10000;

    static has _MAX_YAML_DUPLICATE_GROUP_SAMPLES: any = 100;

    static has _MAX_YAML_DUPLICATE_LINE_SAMPLES: any = 20;

    static has _MAX_JSON_BYTES: any = 262144;

    static has _MAX_JSON_DEPTH: any = 32;

    static has _MAX_JSON_NODES: any = 1000;

    static has _MAX_JSON_OCCURRENCE_SAMPLES: any = 50;

    static has _MAX_JSON_OBJECT_KEYS: any = 200;

    static has _RUBY_MANIFEST_SCAN_MAX: any = 10;

    static has _RUBY_MANIFEST_MAX_BYTES: any = 256 * 1024;

    static has _BLADE_COMMENT_RE: any = re.compile("\\{\\{--.*?(?:--\\}\\}|$)", re.DOTALL);

    static has _BLADE_DIRECTIVE_RE: any = re.compile(
        "(?<!@)@(extends|include|component|livewire)\\s*\\(\\s*(['\"])([^'\"]+)\\2\\s*\\)"
    );

    static has _LIQUID_LITERAL_RE: any = re.compile(
        "\\{%-?\\s*(comment|raw|doc|schema|javascript|stylesheet)\\s*-?%\\}.*?\\{%-?\\s*end\\1\\s*-?%\\}|\\{%-?\\s*#.*?-?%\\}",
        re.DOTALL,
    );

    static has _LIQUID_TAG_RE: any = re.compile(
        "\\{%-?\\s*([A-Za-z_][A-Za-z0-9_-]*)(.*?)-?%\\}", re.DOTALL
    );

    static has _LIQUID_OUTPUT_RE: any = re.compile("\\{\\{-?\\s*(.*?)\\s*-?\\}\\}", re.DOTALL);

    static has _LIQUID_ASSIGN_RE: any = re.compile("\\s*([A-Za-z_][A-Za-z0-9_-]*)\\s*=");

    static has _LIQUID_TARGET_RE: any = re.compile("\\s*(['\\\"])([^'\\\"]+)\\1");

    static has _LIQUID_MAX_OUTPUT_NAME: any = 120;

    static has _LARAVEL_ROUTE_FACADE: any = "Illuminate\\Support\\Facades\\Route";

    static has _LARAVEL_ELOQUENT_MODEL: any = "Illuminate\\Database\\Eloquent\\Model";

    static has _LARAVEL_ROUTE_VERBS: any = frozenset({
        "get",
        "post",
        "put",
        "patch",
        "delete",
        "options",
        "any",
        "match",
        "resource",
        "apiResource",
    });

    static has _LARAVEL_RELATIONSHIPS: any = frozenset({
        "hasMany",
        "hasOne",
        "belongsTo",
        "belongsToMany",
        "morphTo",
        "morphMany",
        "morphOne",
        "morphToMany",
        "morphedByMany",
        "hasManyThrough",
        "hasOneThrough",
    });

    def init(repo_root: Optional[Path] = None);

    def _get_parser(language: str) -> any;

    """Clear per-instance and module-level caches and optionally release free heap pages."""
    def clear_caches(include_parsers: bool = False, release_memory: bool = True) -> None;

    """Map a file path to its language name.

        Extension-based lookup is tried first.  For extension-less files
        (typical for Unix scripts like ``bin/myapp`` or ``.git/hooks/pre-commit``)
        we fall back to reading the first line for a shebang.  Files that
        already have a known extension are never re-read — shebang probing
        only runs when the extension lookup returns ``None`` **and** the path
        has no suffix at all.  See issue #237.

        When *source* is provided, the shebang is sniffed from those bytes
        instead of re-reading the file.  Callers that hash-and-parse one byte
        snapshot MUST pass it: a separate disk read can race a concurrent
        save, mis-detect the language, and store a wrong parse under the
        snapshot's hash (issue #746).
        """
    def detect_language(path: Path, source: Optional[bytes] = None) -> Optional[str];

    """Inspect the first line of ``path`` for a shebang interpreter.

        When *head* is given it is used as the first bytes of the file and
        the file is not read from disk (TOCTOU-safe for callers that already
        hold the byte snapshot being parsed, see issue #746).

        Returns the mapped language name or ``None`` if the file has no
        shebang, is unreadable, or names an interpreter we don't map.

        Accepted shapes::

            #!/bin/bash
            #!/usr/bin/env python3
            #!/usr/bin/env -S node --experimental-vm-modules
            #!/usr/bin/bash -e

        Only the basename of the interpreter is consulted.  Trailing flags
        after the interpreter are ignored.  Windows-style ``
`` line
        endings are handled.  Binary files read as garbage bytes simply
        fail the ``#!`` prefix check and return ``None``.
        """
    static def _detect_language_from_shebang(
        path: Path, head: Optional[bytes] = None
    ) -> Optional[str];

    """Whether *path* holds test code, judged inside this repository.

        Every test-ness question the parser asks goes through here so the
        repository root is never left out: :func:`is_test_file` reads
        directory conventions from the path relative to the root, and an
        absolute path with no root silently loses them.
        """
    def _is_test_path(path: "str | PurePath") -> bool;

    """Parse a single file and return extracted nodes and edges."""
    def parse_file(path: Path) -> tuple[list[NodeInfo], list[EdgeInfo]];

    """Parse pre-read bytes and return extracted nodes and edges.

        This avoids re-reading the file from disk, eliminating TOCTOU gaps
        when the caller has already read the bytes (e.g. for hashing): every
        parse decision, including shebang language detection, derives from
        *source* so the stored file hash always describes the bytes that were
        actually parsed (issue #746).
        """
    def parse_bytes(path: Path, source: bytes) -> tuple[list[NodeInfo], list[EdgeInfo]];

    """Language dispatch for :meth:`parse_bytes`."""
    def _extract_bytes(path: Path, source: bytes) -> tuple[list[NodeInfo], list[EdgeInfo]];

    """Return whether a parsed ``.h`` tree contains C++-only syntax."""
    static def _has_cpp_header_evidence(`root) -> bool;

    """Cheaply decide whether a C header merits a speculative C++ parse."""
    static def _has_cpp_header_text_evidence(source: bytes) -> bool;

    """Shield structural Qt macros without changing byte or line offsets."""
    static def _mask_cpp_qt_macros(source: bytes) -> bytes;

    """Mask Blade comments while preserving offsets and line numbers."""
    class def _mask_blade_comments(text: str) -> str;

    """Parse static Blade template references without a Tree-sitter grammar."""
    def _parse_blade(path: Path, source: bytes) -> tuple[list[NodeInfo], list[EdgeInfo]];

    """Blank a span of a template, keeping its offsets and line numbers."""
    static def _blank_liquid_span(`match: re.Match[str]) -> str;

    """Yield ``(directive, arguments, offset)`` for each Liquid statement.

        Only a statement's first word is its directive, so a quoted value can
        never read as one. A ``{% liquid %}`` tag holds one statement per line,
        with ``#`` and ``comment`` lines of its own.
        """
    def _liquid_statements(masked: str) -> Generator[any, any, any];

    """Return the ``snippets/<name>.liquid`` a render or include names.

        A theme keeps its snippets in one folder at its root and can sit anywhere
        in the repository, so walk up from the template, stopping at the root.
        """
    def _resolve_liquid_snippet(path: Path, name: str) -> Optional[str];

    """Name an output by what it prints, so the name survives line changes."""
    def _liquid_output_name(expression: str) -> str;

    """Index Liquid files without requiring a dedicated Tree-sitter grammar.

        A repeated assignment or output is one node with every line in
        ``extra["lines"]``: names carry no line number, so an edit above them
        does not rename them, and a second use cannot overwrite the first.
        """
    def _parse_liquid(path: Path, source: bytes) -> tuple[list[NodeInfo], list[EdgeInfo]];

    """Parse a Vue SFC by extracting <script> blocks and delegating to JS/TS."""
    def _parse_vue(path: Path, source: bytes) -> tuple[list[NodeInfo], list[EdgeInfo]];

    """Parse a Svelte SFC by extracting <script> blocks.

        Uses the same approach as Vue: parse the outer HTML structure,
        locate ``<script>`` blocks, detect ``lang="ts"`` for TypeScript,
        and delegate each block to the appropriate JS/TS parser.
        """
    def _parse_svelte(path: Path, source: bytes) -> tuple[list[NodeInfo], list[EdgeInfo]];

    """Parse a page: its scripts as code and its anchored blocks as sections.

        Scripts go to the JS/TS parsers as Vue and Svelte blocks do. A
        ``div``, ``section`` or ``article`` with an id becomes a ``DocSection``
        carrying its anchor and first heading, which is what a query can find:
        the prose itself is not indexed.
        """
    def _parse_html(path: Path, source: bytes) -> tuple[list[NodeInfo], list[EdgeInfo]];

    """Record one anchored block. A repeated id keeps the first, as browsers do."""
    def _add_html_section(
        element: Any,
        tag: str,
        attributes: dict[str, str],
        file_path: str,
        test_file: bool,
        sections: dict[str, NodeInfo],
        file_node: NodeInfo,
    ) -> None;

    """Extract a page's scripts, in page order, into the node and edge lists.

        Returns the nodes of the classic scripts: the page's globals.
        """
    def _extract_html_scripts(
        scripts: list[Any], file_path: str, all_nodes: list[NodeInfo], all_edges: list[EdgeInfo]
    ) -> list[NodeInfo];

    """Names an inline handler calls, read with the JavaScript grammar.

        Only a call of a plain name counts: not ``obj.run()``, and nothing in a
        string or a comment.
        """
    def _html_handler_calls(handler: str) -> list[str];

    """Link a page to the script file it loads. URLs and templates say nothing."""
    def _add_html_script_import(src: str, file_path: str, line: int, edges: list[EdgeInfo]) -> None;

    """Parse a stylesheet into templates and the links between them.

        ``call-template`` and ``xsl:import`` name their target, so those edges
        are certain. ``apply-templates`` is chosen by the processor from the
        input document, so it is linked only where a mode or a named step says
        which templates it can reach. Where nothing does, the graph adds no edge
        and counts it on the template instead of guessing.
        """
    def _parse_xslt(path: Path, source: bytes) -> tuple[list[NodeInfo], list[EdgeInfo]];

    """Link a stylesheet to the local file it imports or includes."""
    def _add_xslt_import(element: Any, how: str, file_path: str, edges: list[EdgeInfo]) -> None;

    """Read one template or function. Without a name or match it cannot run."""
    def _xslt_template(
        element: Any, local_name: str, scope: dict[str, str], file_path: str, seen: set[str]
    ) -> Optional[_XsltTemplate];

    """Add the calls written inside a template, however deep they sit."""
    def _walk_xslt_body(
        element: Any,
        scope: dict[str, str],
        owner: Optional[_XsltTemplate],
        templates: list[_XsltTemplate],
        named: dict[str, str],
        file_path: str,
        edges: list[EdgeInfo],
    ) -> None;

    """Link one ``apply-templates`` to the templates it can be shown to reach."""
    def _add_xslt_apply(
        element: Any,
        owner: Optional[_XsltTemplate],
        source: str,
        templates: list[_XsltTemplate],
        file_path: str,
        line: int,
        edges: list[EdgeInfo],
    ) -> None;

    """Parse a Jupyter notebook by extracting code cells."""
    def _parse_notebook(path: Path, source: bytes) -> tuple[list[NodeInfo], list[EdgeInfo]];

    """Parse notebook cells grouped by language.

        Args:
            path: Notebook file path.
            cells: List of CellInfo with index, language, and source.
            default_language: Default language for the File node.
        """
    def _parse_notebook_cells(
        path: Path, cells: list[CellInfo], default_language: str
    ) -> tuple[list[NodeInfo], list[EdgeInfo]];

    """Parse a Databricks .py notebook export."""
    def _parse_databricks_py_notebook(
        path: Path, source: bytes
    ) -> tuple[list[NodeInfo], list[EdgeInfo]];

    """Parse stable VB structure without pretending to be a full compiler.

        VB is case-insensitive. Symbols are therefore resolved only when an
        exact case-folded, scope-aware match exists in this file; ambiguous or
        external targets remain unresolved instead of gaining a false edge.
        """
    def _parse_vbnet(path: Path, source: bytes) -> tuple[list[NodeInfo], list[EdgeInfo]];

    """Extract graph structure from Robot Framework tables."""
    def _parse_robot(path: Path, source: bytes) -> tuple[list[NodeInfo], list[EdgeInfo]];

    """Resolve only unique case-insensitive same-file VB targets."""
    def _resolve_vbnet_edges(
        nodes: list[NodeInfo], edges: list[EdgeInfo], file_path: str
    ) -> list[EdgeInfo];

    """Parse a ReScript `.res` or `.resi` file.

        Extracts modules, let bindings, types, external bindings, open/include
        imports, and function calls. Interface files (`.resi`) are flagged via
        ``File`` node ``extra["rescript_interface"]=True`` and skip call
        extraction since signatures have no call sites.
        """
    def _parse_rescript(path: Path, source: bytes) -> tuple[list[NodeInfo], list[EdgeInfo]];

    static has _PLSQL_IDENT: any = _PLSQL_IDENT_RE;

    static has _SQL_PROC_RE: any = re.compile(
        "\\bCREATE\\s+(?:OR\\s+REPLACE\\s+)?PROCEDURE\\s+(\\w[\\w$#]*(?:\\.\\w[\\w$#]*)*)",
        re.IGNORECASE,
    );

    static has _SQL_DDL_NODE_TYPES: any = frozenset({
        "create_table",
        "create_view",
        "create_function",
    });

    static has _SQL_PLSQL_FUNC_RE: any = re.compile(
        f"\\bCREATE\\s+(?:OR\\s+REPLACE\\s+)?FUNCTION\\s+({_PLSQL_IDENT_RE}(?:\\.{_PLSQL_IDENT_RE})*)",
        re.IGNORECASE,
    );

    static has _SQL_TRIGGER_RE: any = re.compile(
        f"\\bCREATE\\s+(?:OR\\s+REPLACE\\s+)?TRIGGER\\s+({_PLSQL_IDENT_RE}(?:\\.{_PLSQL_IDENT_RE})*)",
        re.IGNORECASE,
    );

    static has _SQL_PACKAGE_RE: any = re.compile(
        f"\\bCREATE\\s+(?:OR\\s+REPLACE\\s+)?PACKAGE\\s+(?!BODY\\b)({_PLSQL_IDENT_RE}(?:\\.{_PLSQL_IDENT_RE})*)",
        re.IGNORECASE,
    );

    static has _SQL_PACKAGE_BODY_RE: any = re.compile(
        f"\\bCREATE\\s+(?:OR\\s+REPLACE\\s+)?PACKAGE\\s+BODY\\s+({_PLSQL_IDENT_RE}(?:\\.{_PLSQL_IDENT_RE})*)",
        re.IGNORECASE,
    );

    static has _SQL_PACKAGE_MEMBER_RE: any = re.compile(
        f"\\b(PROCEDURE|FUNCTION)\\s+({_PLSQL_IDENT_RE})", re.IGNORECASE
    );

    static has _PLSQL_CALL_RE: any = re.compile(
        f"(?<![\\w$#])({_PLSQL_IDENT_RE}(?:\\.{_PLSQL_IDENT_RE}){{0,2}})\\s*\\("
    );

    has _PLSQL_CALL_KEYWORDS: frozenset[str] = frozenset({
        "if",
        "elsif",
        "else",
        "then",
        "end",
        "loop",
        "while",
        "for",
        "case",
        "when",
        "begin",
        "declare",
        "exception",
        "return",
        "raise",
        "is",
        "as",
        "procedure",
        "function",
        "trigger",
        "package",
        "cursor",
        "type",
        "record",
        "table",
        "pragma",
        "and",
        "or",
        "not",
        "in",
        "exists",
        "between",
        "into",
        "over",
        "varchar",
        "varchar2",
        "nvarchar2",
        "number",
        "char",
        "nchar",
        "date",
        "timestamp",
        "raw",
        "boolean",
        "clob",
        "blob",
        "long",
        "float",
        "integer",
        "int",
        "smallint",
        "decimal",
        "numeric",
        "double",
        "real",
        "pls_integer",
        "binary_integer",
        "urowid",
        "rowid",
        "bfile",
        "xmltype",
        "sys_refcursor",
        "interval",
    });

    has _PLSQL_BUILTIN_FUNCS: frozenset[str] = frozenset({
        "count",
        "sum",
        "avg",
        "max",
        "min",
        "greatest",
        "least",
        "to_char",
        "to_date",
        "to_number",
        "to_timestamp",
        "cast",
        "nvl",
        "nvl2",
        "coalesce",
        "nullif",
        "decode",
        "substr",
        "substrb",
        "instr",
        "trim",
        "ltrim",
        "rtrim",
        "upper",
        "lower",
        "initcap",
        "length",
        "lengthb",
        "replace",
        "lpad",
        "rpad",
        "concat",
        "round",
        "trunc",
        "mod",
        "abs",
        "ceil",
        "floor",
        "power",
        "sqrt",
        "extract",
        "sysdate",
        "systimestamp",
        "raise_application_error",
    });

    static has _PLSQL_BUILTIN_PACKAGE_PREFIXES: any = ("dbms_", "utl_");

    static has _PLSQL_BUILTIN_RECEIVERS: any = frozenset({"", "sys", "standard"});

    static has _PLSQL_COLLECTION_METHODS: any = frozenset({"count", "trim"});

    static has _INTO_LOOKBACK: any = 60;

    static has _ORACLE_EXTENSIONS: any = frozenset({
        ".pls",
        ".plb",
        ".pks",
        ".pkb",
        ".pck",
        ".prc",
        ".fnc",
        ".trg",
    });

    static has _PLSQL_ROUTINE: any = _PLSQL_ROUTINE_RE;

    static has _ORACLE_SIGNAL_RE: any = re.compile(
        f"%TYPE\\b|%ROWTYPE\\b|\\bVARCHAR2\\b|\\bPLS_INTEGER\\b|\\bBINARY_INTEGER\\b|\\bSYS_REFCURSOR\\b|\\bDBMS_OUTPUT\\b|:(?:NEW|OLD)\\.|\\bCREATE\\s+(?:OR\\s+REPLACE\\s+)?PACKAGE\\b|\\bCREATE\\s+(?:OR\\s+REPLACE\\s+)?FUNCTION\\s+{_PLSQL_ROUTINE_RE}RETURN\\b|\\bCREATE\\s+(?:OR\\s+REPLACE\\s+)?PROCEDURE\\s+{_PLSQL_ROUTINE_RE}IS\\b|\\bCREATE\\s+OR\\s+REPLACE\\s+PROCEDURE\\s+{_PLSQL_ROUTINE_RE}AS\\s+[^\\s$']",
        re.IGNORECASE,
    );

    """True if this `.sql`-family file is Oracle PL/SQL, as opposed to
        plain ANSI SQL, T-SQL, or MySQL.

        Gates every PL/SQL-specific pass (body-span computation and CALLS
        extraction for packages/triggers/PL/SQL-style functions) so a
        non-Oracle `CREATE PROCEDURE` with no `END;` terminator (T-SQL uses
        `GO`, MySQL uses a custom `DELIMITER`) doesn't have its span
        computed at all — see PR #785 review, where unconditionally
        computing a body span caused it to fall back to end-of-file and
        pick up false CALLS edges spanning unrelated code.
        """
    class def _is_plsql_dialect(path: Path, text: str) -> bool;

    static has _PLSQL_Q_DELIM_CLOSE: any = {"[": "]", "{": "}", "(": ")", "<": ">"};

    """Blank `--`/`/* */` comments and string-literal contents with
        spaces, preserving line numbers and overall text length.

        Every PL/SQL-specific regex pass below (block-end search, forward-
        declaration detection, call extraction, and the CREATE-statement
        matchers themselves) runs against this cleaned text instead of the
        raw source. Without it, a `;` or `END name;`-shaped substring inside
        a trailing comment or a dynamic-SQL string literal (both common in
        real PL/SQL) is indistinguishable from the real terminator — e.g. a
        member with a same-line comment containing a semicolon before its
        `IS` keyword was misdetected as a bodyless forward declaration and
        dropped entirely; a body with a comment mentioning `END name;` had
        its span truncated at the comment instead of the real end.

        This runs as one pass over the whole text rather than per line or
        as a separate global comment-stripping regex applied first (PR #785
        review): both of those earlier approaches broke on real PL/SQL —
        a plain `'...'` string's open/close state was reset at the start
        of every line, so a string spanning multiple lines (or an Oracle
        `q'[...]'`/`Q'<...>'` quoted string, which allows unescaped `'`
        inside it) let a `;` or `END name;` inside the string terminate the
        block early; and a bare `/\\*.*?\\*/` substitution over raw text
        doesn't know it's inside a string either, so a string containing an
        unterminated `/*` (e.g. a comment-like fragment in a literal) could
        pair up with an unrelated later `*/` and blank out everything in
        between, including real statements — silently dropping a
        `CREATE PROCEDURE ...` that happened to fall inside that span.
        """
    static def _strip_plsql_noise(text: str) -> str;

    static has _SQL_NEXT_STMT_RE: any = re.compile(
        "\\bCREATE\\s+(?:OR\\s+REPLACE\\s+)?(?:PROCEDURE|FUNCTION|TRIGGER|PACKAGE|TABLE|VIEW)\\b",
        re.IGNORECASE,
    );

    static has _PLSQL_NAMED_END_RE: any = re.compile(
        f"\\bEND\\b\\s*({_PLSQL_IDENT_RE})\\s*;", re.IGNORECASE
    );

    static has _PLSQL_BLOCK_WORD_RE: any = re.compile(
        "(?<![\\w$#])(?:(?P<open>BEGIN|CASE)|(?P<skip>END\\s+(?:IF|LOOP))|END(?:\\s+CASE)?)(?![\\w$#])",
        re.IGNORECASE,
    );

    static has _PLSQL_IS_AS_RE: any = re.compile("(?:IS|AS)\\b", re.IGNORECASE);

    """True if a PROCEDURE/FUNCTION member at `start` (just after the
        name) is a forward declaration — `PROCEDURE x(...);` — rather than
        a real definition — `PROCEDURE x(...) IS ... END;` (or
        `... RETURN t IS ...` for functions).

        Forward declarations in a PACKAGE BODY (used for mutual recursion)
        have no body of their own; treating one as a real member makes its
        block-end search land on the *next* member's END, producing a
        phantom node with a bogus line span and false CALLS edges — see
        PR #785 review.

        Callers already pass comment/string-stripped text (`clean_text`),
        but this function skips `--`/`/* */` comments on its own too, so
        it's independently correct rather than only correct because of an
        external pre-processing step — a `;` inside a trailing comment on
        the declaration line must not be mistaken for the forward-decl
        terminator. The `IS`/`AS` check also requires a word boundary on
        *both* sides (`re.match` alone only anchors the end): without it,
        a return type like `t_alias` matches `AS` mid-word (`t_ali|AS`)
        and a genuine forward declaration gets misclassified as a real
        definition, producing the same phantom-node failure mode.
        """
    static def _plsql_is_forward_decl(text: str, start: int) -> bool;

    """Extract the raw, whitespace-normalized parameter-list text right
        after a PACKAGE BODY member's name (e.g. ``p_x NUMBER, p_y NUMBER``).

        Oracle allows overloaded PROCEDURE/FUNCTION members within a
        package (never for standalone subprograms), so two members sharing
        a name are a normal, common pattern — not a duplicate. Without a
        signature to distinguish them, both would collide on the same
        qualified name, same root cause as the spec/body collision fixed
        above. Mirrors ``_cpp_function_identity``'s always-on signature
        identity, for the same stable-identity property. Returns "" for a
        parameterless member.

        Skips `--`/`/* */` comments and `'...'` string-literal contents on
        its own (like ``_plsql_is_forward_decl``), so an unbalanced paren
        inside a default-value string (e.g. ``p_x VARCHAR2 := '('``) can't
        throw off the paren-depth count when called directly on raw text.
        """
    static def _plsql_member_signature(text: str, start: int) -> str;

    """Parse a `.sql` file, including Oracle PL/SQL (`.sql`, `.pls`,
        `.plb`, `.pks`, `.pkb`, `.pck`, `.prc`, `.fnc`, `.trg`).

        Extracts:
        - Tables (CREATE TABLE) → Class nodes with extra["sql_kind"]="table"
        - Views  (CREATE VIEW)  → Class nodes with extra["sql_kind"]="view"
        - Functions (CREATE FUNCTION) → Function nodes with extra["sql_kind"]="function"
        - Procedures (CREATE PROCEDURE, regex fallback) → Function nodes with
          extra["sql_kind"]="procedure"

        The following are Oracle-only and only extracted when
        ``_is_plsql_dialect`` confirms the file is PL/SQL (via an Oracle
        extension or a content signal like `VARCHAR2`/`%TYPE`/`:NEW.`) —
        never for plain ANSI/T-SQL/MySQL `.sql` files:
        - Packages (CREATE PACKAGE) → Class nodes with extra["sql_kind"]="package"
        - Package bodies (CREATE PACKAGE BODY) → Class nodes with
          extra["sql_kind"]="package_body", qualified as ``pkg_name$body``
          (distinct from the spec's ``pkg_name``, since they're separate
          Oracle objects), containing nested PROCEDURE/FUNCTION members as
          Function nodes qualified as ``pkg_name$body.member_name(params)``
          — the parameter signature is always included (even with zero
          overloads) since Oracle allows overloaded package members
          — mirrors ``_cpp_function_identity``'s always-on signature identity
        - Triggers (CREATE TRIGGER) → Function nodes with extra["sql_kind"]="trigger"

        For confirmed-PL/SQL files, procedure/function/trigger/package-member
        bodies are also scanned for `identifier(` call sites to produce
        CALLS edges (regex-based: no PL/SQL grammar is available, so this is
        a best-effort heuristic that skips known PL/SQL keywords, scalar
        type names, common builtins, and INSERT INTO table targets).

        Data dependencies (FROM/JOIN table references) are recorded as
        IMPORTS_FROM edges so the impact-radius query can follow them.

        dbt models use a dedicated extraction instead: one Class node per
        model, named after the file stem, with IMPORTS_FROM edges from the
        Jinja dependency calls. Within a dbt project, model membership comes
        from ``model-paths`` in ``dbt_project.yml``; without project context,
        a ``ref()`` / ``source()`` call remains a best-effort content signal.
        """
    def _parse_sql(path: Path, source: bytes) -> tuple[list[NodeInfo], list[EdgeInfo]];

    """Return whether *path* belongs to a configured dbt model directory.

        ``None`` means there is no enclosing dbt project in this parser's
        repository context, so callers may use content sniffing as a fallback.
        """
    def _is_dbt_model_path(path: Path) -> Optional[bool];

    """Read and cache the model directories for one dbt project."""
    def _dbt_model_paths(project_file: Path) -> tuple[Path, ...];

    """Extract a dbt model file: one Class node plus its Jinja deps.

        dbt materializes each model file as a table or view named after the
        file stem, so the stem is the node name.

        - `{{ ref('m') }}` → IMPORTS_FROM target `m`
        - `{{ ref('pkg', 'm') }}` → IMPORTS_FROM target `pkg.m`
        - `{{ source('src', 'tbl') }}` → IMPORTS_FROM target `src.tbl`
          (kept qualified: sources are external tables, not project models,
          so the target must not collide with a model node of the same name)
        """
    def _extract_dbt_model(
        path: Path,
        text: str,
        dbt_refs: list[re.Match],
        file_path_str: str,
        test_file: bool,
        nodes: list[NodeInfo],
        edges: list[EdgeInfo],
    ) -> None;

    """Return the index just past the terminating ``;`` of a named
        PL/SQL block beginning at ``start``.

        Prefers a name-qualified ``END <name>;`` — the Oracle style-guide
        convention — since that reliably identifies the *outer* block even
        when nested ``BEGIN ... EXCEPTION ... END;`` blocks inside it use a
        bare, unnamed ``END;``. Falls back to counting blocks if no named
        terminator exists; see :meth:`_plsql_bare_end`.

        ``limit`` bounds how far either search can look (defaults to the
        next top-level ``CREATE`` statement after ``start``, or end of
        file, if no ``END`` at all is found). Without this bound, the named
        search ran unbounded to end-of-file: two package bodies with a
        same-named member (two overloads sharing a name is explicitly a
        supported case, but so is one package body's member called `foo`
        and another, unrelated package body's member also called `foo`)
        could bleed into each other when the first used a bare `END;` and
        the regex, un-bounded, found some *later* package body's own named
        `END foo;` instead — see PR #785 review. An unbounded scan from
        every member's start to end-of-file is also quadratic over a file
        with many members (~4s for 4,000 members, per that review); passing
        the enclosing block's own end as `limit` keeps each member's search
        proportional to that block's size instead of to the whole file.

        ``named_ends`` maps a lower-cased name to the sorted end offsets of its
        ``END name;`` terminators. A caller walking many members of one body
        passes it so that a member with a bare ``END;`` does not rescan the rest
        of the body for a name that never appears.
        """
    static def _plsql_block_end(
        text: str,
        start: int,
        name: str,
        limit: int | None = None,
        named_ends: dict[str, list[int]] | None = None,
        package: bool = False,
    ) -> int;

    """Find the end of a block with no ``END <name>;``, counting nested blocks.

        A package body holds whole subprograms, so its end is the ``END`` with no
        block open. A subprogram ends at the bare ``END;`` closing its outermost
        block; a named ``END`` that closes everything belongs to a local
        subprogram. A local subprogram with a bare ``END;`` still under-shoots:
        telling it apart needs a real PL/SQL grammar, and none is available.

        A package's initialisation section opens a block whose ``END`` is also
        the package's, so the last ``END`` seen stands in when none is left over.
        """
    static def _plsql_bare_end(text: str, start: int, limit: int, package: bool) -> int;

    """Emit CALLS edges for procedure/function invocations found between
        ``body_start`` and ``body_end``.

        Regex-based (no PL/SQL grammar is available): matches
        ``identifier(`` / ``pkg.proc(``, skipping PL/SQL/SQL keywords,
        scalar type names that also precede ``(`` (e.g. ``VARCHAR2(50)``
        in a variable declaration), the target of ``INSERT INTO t (cols)``,
        and common builtin functions/packages (``COUNT``, ``NVL``,
        ``TO_CHAR``, ``DBMS_OUTPUT.PUT_LINE``, ...) which are calls but not
        to user code.
        """
    def _extract_plsql_calls(
        text: str,
        body_start: int,
        body_end: int,
        caller_qualified: str,
        file_path_str: str,
        edges: list[EdgeInfo],
    ) -> None;

    """Recursively walk a tree-sitter SQL AST and extract DDL entities."""
    def _walk_sql_tree(
        `node, source: bytes, file_path_str: str, nodes: list[NodeInfo], edges: list[EdgeInfo]
    ) -> None;

    """Extract a single CREATE TABLE / VIEW / FUNCTION DDL node."""
    def _extract_sql_ddl(
        `node, source: bytes, file_path_str: str, nodes: list[NodeInfo], edges: list[EdgeInfo]
    ) -> None;

    """Resolve bare call targets to qualified names using same-file definitions.

        After parsing, CALLS edges store bare function names (e.g. ``FirebaseAuth``)
        as targets. This method builds a symbol table from the parsed nodes and
        qualifies any bare target that matches a local definition, so that
        ``callers_of`` / ``callees_of`` queries produce correct results.

        External calls (names not defined in this file) remain bare.
        """
    def _resolve_call_targets(
        nodes: list[NodeInfo], edges: list[EdgeInfo], file_path: str
    ) -> list[EdgeInfo];

    """Resolve Julia calls from the nearest lexical scope outward."""
    def _resolve_julia_call_targets(
        nodes: list[NodeInfo], edges: list[EdgeInfo], file_path: str
    ) -> list[EdgeInfo];

    static has _TYPED_CALL_LANGUAGES: any = frozenset({
        "python",
        "kotlin",
        "java",
        "javascript",
        "typescript",
        "tsx",
        "php",
        "csharp",
    });

    static has _UNRESOLVED_TYPE_LANGUAGES: any = frozenset({
        "java",
        "kotlin",
        "javascript",
        "typescript",
        "tsx",
    });

    static has _TRANSPARENT_TYPE_WRAPPERS: any = frozenset({"Annotated", "Optional", "Type"});

    static has _NON_RECEIVER_TYPE_NAMES: any = frozenset({
        "Array",
        "Collection",
        "Dict",
        "Iterable",
        "List",
        "Map",
        "Mapping",
        "MutableList",
        "MutableMap",
        "MutableMapping",
        "ReadonlyArray",
        "Sequence",
        "Set",
        "Tuple",
        "Union",
        "dict",
        "frozenset",
        "list",
        "set",
        "tuple",
    });

    """Collect evidence-backed targets for calls on typed receivers.

        The result is keyed by source position, receiver, and method so the normal
        call extractor remains the single producer of CALLS edges. C# uses byte
        offsets to distinguish lexical bindings on the same line. Statically
        typed receivers resolve directly when their class is repository-local.
        PHP variables assigned from ``new Type`` retain a bare parse-time target
        plus the constructed class scope for conservative graph-wide resolution.
        Unknown or ambiguous types keep their existing bare targets.
        """
    def _collect_typed_call_targets(
        `root, language: str, file_path: str, import_map: dict[str, str], defined_names: set[str]
    ) -> dict[tuple[int, str, str], tuple[Optional[str], str, str]];

    """Return declared instance-field types for one class."""
    def _collect_class_typed_fields(
        class_node, language: str, function_types: set[str], class_types: set[str]
    ) -> dict[str, str];

    """Return typed parameters declared directly by one function."""
    def _collect_function_typed_parameters(function_node, language: str) -> dict[str, str];

    """Return TypeScript constructor parameters that declare fields."""
    def _collect_ts_parameter_properties(constructor_node) -> dict[str, str];

    """Extract typed variable declarations from one AST node."""
    def _typed_bindings_from_node(`node, language: str) -> dict[str, str];

    """Return simple PHP variables invalidated by one assignment."""
    static def _php_assigned_variables(`node) -> set[str];

    class def _store_typed_binding(
        result: dict[str, str], name_node, type_node, *, csharp: bool = False
    ) -> None;

    """Store a Java binding, keeping a package-qualified type whole.

        ``com.acme.other.Cart`` is not the ``Cart`` in this file's package, so
        cutting it to ``Cart`` would let the package fallback pick the wrong one.
        """
    class def _store_java_typed_binding(result: dict[str, str], name_node, type_node) -> None;

    """Return the receiver class from a generic/nullable annotation."""
    class def _base_type_name(annotation: str) -> Optional[str];

    def _resolve_typed_method_target(
        type_name: str,
        method: str,
        file_path: str,
        language: str,
        import_map: dict[str, str],
        defined_names: set[str],
    ) -> Optional[str];

    static def _apply_typed_call_targets(
        edges: list[EdgeInfo],
        targets: dict[tuple[int, str, str], tuple[Optional[str], str, str]],
        language: str,
    ) -> list[EdgeInfo];

    """Collect typed receiver evidence and edges for property reads.

        Scoped the way Python is scoped, because a file-wide answer is wrong
        often enough to matter: ``store`` is a ``GraphStore`` in fifteen test
        methods and a ``MagicMock`` in three, and only the enclosing function
        says which. Module bindings and imported symbols seed the module
        scope; a class contributes its annotated attributes and every
        ``self.x = ...`` written anywhere inside it; a function contributes
        its typed parameters and its own assignments, in source order.

        The whole tree is scanned for imports, not only its top level: the
        import that decides a receiver is routinely written inside the
        function that uses it, which is exactly where ``_collect_file_scope``
        stops looking.
        """
    def _collect_python_receiver_evidence(
        `root, file_path: str, source: bytes
    ) -> tuple[dict[tuple[int, str], tuple[str, str]], list[EdgeInfo]];

    """Instance attributes a class declares, however it declares them.

        Annotated class-body attributes, plus every ``self.x = ...`` written
        in any of its methods — which is where the binding that matters
        usually lives, and where the shared typed-field collector stops.
        """
    def _collect_python_class_fields(
        class_node, context: _PyReceiverContext
    ) -> dict[str, tuple[str, str]];

    """Return the defining file, class, and return annotation of a property.

        Cross-file metadata is read only from the file bound by a ``from``
        import in the current module. An unresolved or ambiguous import never
        supplies a property definition.
        """
    def _python_property_definition(
        owner_type: str, property_name: str, context: _PyReceiverContext
    ) -> Optional[tuple[str, str, str]];

    """Read explicitly decorated property getters from one Python module."""
    def _python_module_property_return_annotations(module_file: str) -> dict[tuple[str, str], str];

    """Resolve class names in one module without borrowing caller names."""
    def _python_module_class_identities(module_file: str) -> dict[str, tuple[str, str]];

    """Parse class property declarations without evaluating their bodies."""
    def _read_python_property_return_annotations(module_path: Path) -> dict[tuple[str, str], str];

    """Infer a class only from a local binding, field, or property annotation."""
    def _python_expression_class_evidence(
        expression,
        env: dict[str, tuple[str, str]],
        class_fields: dict[str, tuple[str, str]],
        current_class: Optional[str],
        context: _PyReceiverContext,
        instance_receiver_name: Optional[str] = None,
        class_receiver_name: Optional[str] = None,
    ) -> Optional[tuple[str, str]];

    """Reconcile several bindings of one name in the same scope.

        ``unknown`` is the ABSENCE of evidence, not evidence against: a field
        a helper returns in one branch and constructs in another is still that
        class. Two different classes, a class and a module, or a class and a
        container literal, do contradict, and contradiction means no
        attribution.
        """
    static def _merge_python_evidence(found: list[tuple[str, str]]) -> tuple[str, str];

    """Names one binding form binds, each with its position in the value.

        ``store = ...`` binds ``store`` to the whole value, spelled as the
        empty path. ``store, root = ...`` binds ``store`` to position 0 and
        ``root`` to position 1, and ``a, (b, c) = ...`` nests the same way.

        A starred element costs its own position and every position after it —
        the length of the value is not visible here, so nothing after a star
        can be numbered — but the names BEFORE it keep their positions rather
        than the whole statement being thrown away.
        """
    class def _python_binding_targets(left) -> list[tuple[str, tuple[int, ...]]];

    """Is *name* bound through ``self.x``/``cls.x`` rather than bare?"""
    static def _python_target_is_attribute(left, name: str) -> bool;

    """What one binding says its target holds, or None for "nothing"."""
    def _python_binding_evidence(
        value,
        type_node,
        path: tuple[int, ...],
        context: _PyReceiverContext,
        env: Optional[dict[str, tuple[str, str]]] = None,
        class_fields: Optional[dict[str, tuple[str, str]]] = None,
        current_class: Optional[str] = None,
        instance_receiver_name: Optional[str] = None,
        class_receiver_name: Optional[str] = None,
    ) -> Optional[tuple[str, str]];

    """What a call expression says the value it returns is.

        An annotated return type wins over the constructor rule, because it
        is what the source actually claims; the constructor rule is the
        fallback for a class that, being a class, has no return annotation.
        """
    def _python_call_evidence(
        call, path: tuple[int, ...], context: _PyReceiverContext
    ) -> tuple[str, str];

    """Class a constructor call names, bare or dotted, or None.

        ``GraphStore(...)`` counts when the file defines or imports the name —
        otherwise a local factory function would manufacture class evidence.
        ``graph.GraphStore(...)`` and ``code_review_graph.graph.GraphStore(...)``
        count on the same terms, resolved through the file's import map: the
        root of the dotted chain has to be a name an import bound, and the
        last segment has to be spelled like a class. Without the spelling
        rule ``os.path.join(...)`` would claim a class named ``join`` and
        contradict the real evidence for that name elsewhere in the scope.
        """
    def _python_constructor_class(callee, context: _PyReceiverContext) -> Optional[str];

    """Strip the wrappers the grammar puts around a callee name.

        ``*CodeParser().parse_file(p)`` parses with the splat INSIDE the
        constructor call — ``call(list_splat(identifier))`` — so the callee of
        the inner call is a ``list_splat``, not the class name it plainly is.
        """
    static def _python_unwrap_callee(`node) -> any;

    """Leftmost identifier of a pure ``a.b.c`` chain, or None."""
    static def _python_dotted_root(`node) -> Optional[str];

    """Return annotation the source writes for this call's callee.

        Three places, in the order a reader would look: a ``def`` in this very
        file, the module a ``from X import f`` statement names, and the module
        an ``import m`` binding names for ``m.f(...)``. Only the annotation
        text is ever read — no return statement is inspected, in this file or
        any other, so nothing here is inferred.
        """
    def _python_callee_return_annotation(callee, context: _PyReceiverContext) -> Optional[str];

    """What a nameless Python call receiver is, or None for "nothing".

        Two shapes carry their own answer. ``CodeParser().parse_file(...)``
        calls a method on a constructor expression, so the class is written
        right there. ``pkg.graph.GraphStore(...)`` is not a member call at all
        — it is a dotted module path, and the name it calls is a top-level
        name of the module that path resolves to.
        """
    def _python_expression_receiver_evidence(
        call, context: _PyReceiverContext
    ) -> Optional[tuple[str, str]];

    """File the dotted module path *prefix* names, through this file's imports.

        The root of the chain has to be a name one of this file's own
        ``import`` statements bound to a module; otherwise the chain is an
        attribute walk over some object and names no module at all.
        """
    def _python_dotted_module_file(prefix, context: _PyReceiverContext) -> Optional[str];

    """Element of *annotation* at a tuple position, or None if unnamed."""
    class def _python_annotation_at_path(annotation: str, path: tuple[int, ...]) -> Optional[str];

    """Split ``tuple[A, B]`` into its element annotations, or None."""
    static def _python_tuple_annotation_elements(annotation: str) -> Optional[list[str]];

    """Return annotations of every top-level ``def`` in *module_file*.

        Cached on the module's identity and mtime the way star exports are,
        so a repository-wide build reads each imported module at most once.
        """
    def _python_module_return_annotations(module_file: str) -> dict[str, str];

    """Parse one module for the return annotations of its top-level defs."""
    def _read_python_return_annotations(module_path: Path) -> dict[str, str];

    """Record names bound by ``import x`` / ``import x.y as z``."""
    def _python_plain_import_bindings(
        `node, file_path: str, module_bindings: dict[str, set[str]], imported_names: set[str]
    ) -> None;

    """Record names bound by ``from X import a, b as c``.

        *symbol_origins*, when given, also records the module file each
        non-module name came from, so a caller can read that module's own
        annotation for the symbol.
        """
    def _python_from_import_bindings(
        `node,
        file_path: str,
        module_bindings: dict[str, set[str]],
        imported_names: set[str],
        symbol_origins: Optional[dict[str, str]] = None,
        symbol_names: Optional[dict[str, str]] = None,
    ) -> None;

    """Name an assignment binds, as the receiver reader would spell it.

        ``self.pool = ...`` binds ``pool``, because ``self.pool.get()`` is
        recorded with ``pool`` as its receiver.
        """
    static def _python_binding_target_name(left) -> Optional[str];

    """Stamp each bare Python member call with what its receiver is."""
    def _apply_python_receiver_evidence(
        edges: list[EdgeInfo], evidence: dict[tuple[int, str], tuple[str, str]]
    ) -> list[EdgeInfo];

    static has _MAX_AST_DEPTH: any = 180;

    static has _MAX_TEST_DESCRIPTION_LEN: any = 200;

    """Extract the first string argument from a test runner call node."""
    def _get_test_description(call_node, source: bytes) -> Optional[str];

    """Whether a Ruby call is a test block, such as ``it "adds" do ... end``.

        The block is what makes it one: ``[1].map { it + 1 }`` and a helper named
        ``test`` are not tests, and neither is ``robot.it`` on some other object.
        """
    def _is_ruby_test_block(`node, call_name: str, file_path: str) -> bool;

    """Return the subject of a Ruby test block: a string, class or symbol."""
    def _get_ruby_test_description(call_node) -> Optional[str];

    """Return ``Shop.Cart``, the way nodes spell it, for ``Shop::Cart``."""
    static def _ruby_constant_path(`node) -> Optional[str];

    """Return a constant with the modules around it, innermost first.

        Ruby looks a relative constant up in those modules before the top
        level, so the scopes travel with it. ``::Cart`` is absolute and has none.
        """
    class def _ruby_class_ref(`node, nesting: tuple[str, ...]) -> Optional[_RubyClassRef];

    """Return the lexical nesting inside a ``module`` or ``class`` body."""
    class def _ruby_nesting(`node, nesting: tuple[str, ...]) -> tuple[str, ...];

    """Say which class each call in a Ruby test file is made on.

        Ruby calls carry no receiver, so ``client.push`` matches every ``push``
        in the repository. Only what the file itself states counts: a constant
        (``Shop::Cart.build``), a constructor (``Shop::Cart.new.tax``), a name
        last assigned from a constructor, and ``described_class``. ``@ivars`` and
        ``let`` names are read file-wide, since ``before`` sets them for the
        tests beside it, unless the file gives one name two meanings.

        Returns, for each ``(line, method)``, one entry per call in source
        order: whether it has a receiver, and the class the file says that
        receiver is, or ``None`` where it does not say. A receiverless call on
        the same line as one with a receiver keeps its own entry.
        """
    def _collect_ruby_test_receivers(
        `root
    ) -> dict[tuple[int, str], list[tuple[bool, Optional[_RubyClassRef]]]];

    """Stamp each Ruby test call with the class the file says it is made on.

        A receiver the file says nothing about is stamped too. A test is the one
        place a wrong call costs a false claim of coverage, and a method that
        merely shares a name with something the test requires is not evidence.
        A call with no receiver is left as it is.
        """
    static def _apply_ruby_test_receivers(
        edges: list[EdgeInfo],
        receivers: dict[tuple[int, str], list[tuple[bool, Optional[_RubyClassRef]]]],
    ) -> list[EdgeInfo];

    """Index generic YAML structure while deliberately discarding values.

        Repeated sequence shapes are aggregated under ``[*]`` paths to keep
        large configuration repositories bounded. Nodes retain occurrence and
        source-line samples, while duplicate keys and aliases receive explicit
        diagnostics. Scalar values never enter node or edge metadata.
        """
    def _parse_yaml(path: Path, source: bytes) -> tuple[list[NodeInfo], list[EdgeInfo]];

    """Index a JSON file's paths while deliberately discarding its values.

        The shape follows generic YAML: repeated array items share one ``[*]``
        path, and scalar values never enter node or edge metadata. JSON is far
        more often data than YAML, so more of it stays out. Translation files
        follow the YAML rule (``_is_locale_yaml``); test data, docs, examples,
        data folders and oversized files keep only their file node; and an
        object used as a table collapses to ``.*``. Paths are read breadth
        first, so a file over the cap loses its deepest paths, not its last
        top-level keys.
        """
    def _parse_json(path: Path, source: bytes) -> tuple[list[NodeInfo], list[EdgeInfo]];

    static def _spring_config_file_node(path: Path, source: bytes, language: str) -> NodeInfo;

    """Index Spring property names while deliberately discarding values."""
    def _parse_spring_config(path: Path, source: bytes) -> tuple[list[NodeInfo], list[EdgeInfo]];

    """Flatten Spring YAML keys using PyYAML's syntax tree, never values."""
    def _parse_spring_yaml(path: Path, source: bytes) -> tuple[list[NodeInfo], list[EdgeInfo]];

    """Reject clear CI, deployment, and API manifests despite their filename."""
    static def _is_non_spring_yaml(documents: list[object]) -> bool;

    """Join Java-properties continuation lines while retaining start lines."""
    static def _spring_property_logical_lines(text: str) -> list[tuple[int, str]];

    """Extract the unescaped key portion of one Java-properties entry."""
    static def _spring_property_key(line: str) -> Optional[str];

    """Index Spring .properties keys without retaining their values."""
    def _parse_spring_properties(
        path: Path, source: bytes
    ) -> tuple[list[NodeInfo], list[EdgeInfo]];

    """Parse an Ansible YAML file using PyYAML's compose() node tree.

        Dispatches to sub-parsers based on the file's classified role:
        playbook, tasks, handlers, meta, or vars (vars emits File node only).
        """
    def _parse_ansible(path: Path, source: bytes) -> tuple[list[NodeInfo], list[EdgeInfo]];

    """Return a stable node name without collapsing repeated task labels."""
    static def _ansible_unique_name(
        nodes: list[NodeInfo], file_path: str, parent_name: Optional[str], requested: str, line: int
    ) -> str;

    """Qualify notify targets when one same-scope handler matches."""
    def _resolve_ansible_notify_targets(
        nodes: list[NodeInfo], edges: list[EdgeInfo]
    ) -> list[EdgeInfo];

    """Extract plays and import_playbook references from a top-level SequenceNode."""
    def _parse_ansible_playbook(
        `root: object, file_path: str, nodes: list[NodeInfo], edges: list[EdgeInfo]
    ) -> None;

    """Extract task/handler Function nodes from a SequenceNode of task mappings."""
    def _parse_ansible_tasks(
        tasks_node: object,
        file_path: str,
        nodes: list[NodeInfo],
        edges: list[EdgeInfo],
        is_handler: bool,
        parent_play: Optional[str],
    ) -> None;

    """Extract role dependencies from a role meta/main.yml."""
    def _parse_ansible_meta(
        `root: object, file_path: str, nodes: list[NodeInfo], edges: list[EdgeInfo]
    ) -> None;

    """Extract a role name from a roles-list item.

        Handles: plain string, ``{role: name}`` dict, ``{name: ns.role}`` dict.
        """
    def _ansible_extract_role_name(item: object) -> Optional[str];

    """Extract handler names from a notify: value (scalar or sequence)."""
    def _ansible_extract_notify_targets(notify_node: object) -> list[str];

    """Extract a simple string argument from a module args node.

        Handles: bare scalar (``include_tasks: db.yml``) or mapping with ``file:`` key.
        Jinja2 expressions are returned as-is.
        """
    def _ansible_module_arg_str(args_node: Optional[object]) -> Optional[str];

    """Extract role name from include_role/import_role module args."""
    def _ansible_role_from_module_args(args_node: Optional[object]) -> Optional[str];

    """Recursively walk the AST and extract nodes/edges."""
    def _extract_from_tree(
        `root,
        source: bytes,
        language: str,
        file_path: str,
        nodes: list[NodeInfo],
        edges: list[EdgeInfo],
        enclosing_class: Optional[str] = None,
        enclosing_func: Optional[str] = None,
        import_map: Optional[dict[str, str]] = None,
        defined_names: Optional[set[str]] = None,
        _depth: int = 0,
        _go_receiver_bindings: Optional[tuple[str, tuple[int, ...], tuple[int, ...]]] = None,
    ) -> None;

    """Return the leading identifier of an Elixir ``call`` node.

        For ``def add(a, b)`` returns ``"def"``; for ``defmodule Calc``
        returns ``"defmodule"``; for ``IO.puts(msg)`` returns the dotted
        path's final identifier (``"puts"``); for ``alias Calculator``
        returns ``"alias"``.
        """
    def _elixir_call_identifier(`node) -> Optional[str];

    """Extract a module name from a ``defmodule`` / ``alias`` / etc.
        arguments node. Supports ``Calc`` (single alias) and ``Foo.Bar``
        (dotted alias inside a `dot` node).
        """
    def _elixir_module_name(arguments) -> Optional[str];

    """Extract the function name and parameter list from a ``def``/
        ``defp``/``defmacro`` arguments node.

        The ``arguments`` of a ``def`` call wraps another ``call`` whose
        first child is the function's identifier and whose children
        (past the parens) are the parameters.
        """
    def _elixir_function_name_and_params(
        arguments, source: bytes
    ) -> tuple[Optional[str], Optional[str]];

    """Handle every Elixir ``call`` node by dispatching on the leading
        identifier. See: #112

        Returns True if the node was fully handled (and the main loop
        should skip generic recursion); False to let the default dispatch
        continue (never used here — Elixir has no other node types).
        """
    def _extract_elixir_constructs(
        `node,
        source: bytes,
        language: str,
        file_path: str,
        nodes: list[NodeInfo],
        edges: list[EdgeInfo],
        enclosing_class: Optional[str],
        enclosing_func: Optional[str],
        import_map: Optional[dict[str, str]],
        defined_names: Optional[set[str]],
        _depth: int,
    ) -> bool;

    """Give each multi-clause Elixir function one node spanning its clauses.

        Each clause is its own ``def``, but they share one qualified name and
        the graph keeps one node per name, so the last clause overwrote the
        others: the earlier lines belonged to no function and a change there
        was missed. Calls in every clause already name the shared function as
        their source, so only the node and its CONTAINS edge need merging. The
        first clause keeps its parameters: a head with defaults comes first.
        See: #979
        """
    def _merge_elixir_clauses(
        nodes: list[NodeInfo], edges: list[EdgeInfo]
    ) -> tuple[list[NodeInfo], list[EdgeInfo]];

    """Return True for files whose basename is ``flake.nix``."""
    static def _is_nix_flake_file(file_path: str) -> bool;

    """Flatten a Nix ``attrpath`` node into a list of identifier parts.

        ``packages.default`` → ``["packages", "default"]``;
        ``inputs.nixpkgs.url`` → ``["inputs", "nixpkgs", "url"]``. Dotted
        attrpaths have ``identifier`` children separated by ``.`` tokens.
        """
    def _nix_attrpath_parts(attrpath_node) -> list[str];

    """Walk a Nix ``attrset_expression`` looking for ``*.url = "..."``
        bindings whose RHS is a literal string. Returns ``(url, line)``
        tuples. Used when the enclosing attrpath is ``inputs`` so that both
        the nested form

            inputs = { nixpkgs.url = "..."; flake-utils.url = "..."; };

        and the mixed form (an inner input with its own nested attrset)
        surface the URL strings as IMPORTS_FROM targets.
        """
    def _extract_nix_flake_input_urls(attrset_node) -> list[tuple[str, int]];

    """Walk an expression looking for ``import <path>`` and
        ``callPackage <path> <args>`` applications. Returns a list of
        ``(target_path, line)`` tuples for each match.

        Recurses through ``apply_expression`` (so ``import ./x.nix { ... }``
        and ``pkgs.callPackage ./y.nix { }`` are both caught) and descends
        into bodies of ``let_expression`` / ``parenthesized_expression`` /
        ``function_expression`` / ``attrset_expression`` / ``list_expression``
        so a ``let pkgs = import nixpkgs; in { ... }`` body is scanned too.
        """
    def _extract_nix_import_targets(rhs_node) -> list[tuple[str, int]];

    """Handle a Nix ``binding`` node (``attrpath = expr;``).

        - Flattens dotted attrpaths into a single dotted node name
          (``packages.default``).
        - In ``flake.nix``, ``inputs.<name>.url = "..."`` bindings emit an
          ``IMPORTS_FROM`` edge with target = the URL string, and no node.
        - All other bindings become ``Function`` nodes (matching the
          Bash/Elixir convention for "the graph's addressable things") with a
          CONTAINS edge from the File.
        - The RHS is scanned for ``import <path>`` / ``callPackage <path> ...``
          applications; each emits an ``IMPORTS_FROM`` edge (relative paths
          are resolved against the caller's directory when possible).
        - Recurses into the RHS so nested bindings (e.g. inside
          ``let ... in { ... }`` or ``outputs = { ... }: { ... }``) are
          discovered and flattened as their own top-level nodes.

        Returns True (Nix has no other node-type dispatches in the walker).
        """
    def _extract_nix_constructs(
        `node,
        source: bytes,
        language: str,
        file_path: str,
        nodes: list[NodeInfo],
        edges: list[EdgeInfo],
        enclosing_class: Optional[str],
        enclosing_func: Optional[str],
        import_map: Optional[dict[str, str]],
        defined_names: Optional[set[str]],
        _depth: int,
    ) -> bool;

    """Handle an HCL ``block`` node and emit Class/Function/edge data.

        Mapping (see ``_HCL_BLOCK_CFG`` for the dispatch table):
        - ``resource/data``        → Class  ``resource.type.name`` / ``data.type.name``
        - ``module``               → Class  ``module.name`` + IMPORTS_FROM (source attr)
        - ``variable/output/provider`` → Function  ``var|output|provider.name``
        - ``locals``               → Function ``local.<key>`` per attribute
        - ``terraform`` / unknown  → skipped

        Returns True unconditionally so the main walker skips the subtree.
        """
    def _extract_hcl_constructs(
        `node, file_path: str, nodes: list[NodeInfo], edges: list[EdgeInfo]
    ) -> bool;

    """Emit one Function node per binding in a ``locals { ... }`` block."""
    def _emit_hcl_locals(
        body_node, file_path: str, nodes: list[NodeInfo], edges: list[EdgeInfo]
    ) -> bool;

    """Return the string value of a named attribute in an HCL body, or None."""
    def _hcl_get_attribute_string(body_node, attr_name: str) -> Optional[str];

    """Emit REFERENCES edges for every HCL variable reference under *node*.

        *local_names* accumulates iterator symbols introduced by enclosing
        ``dynamic`` blocks.  Any reference whose root matches a name in this
        set is suppressed, preventing spurious ``resource.<iterator>.*``
        edges from expressions like ``setting.value[...]`` or
        ``origin_group.key``.
        """
    def _walk_hcl_expressions(
        `node,
        file_path: str,
        edges: list[EdgeInfo],
        enclosing_name: str,
        local_names: frozenset[str] = local_names_default_,
        *,
        provider_body=None,
        provider_attributes: frozenset[str] = provider_attributes_default_,
        provider_context: bool = False,
    ) -> None;

    """Detect ``source foo.sh`` / ``. foo.sh`` and emit an IMPORTS_FROM
        edge. Returns True if handled (so the main loop skips recursing
        into this command). See: #197
        """
    def _extract_bash_source_command(`node, file_path: str, edges: list[EdgeInfo]) -> bool;

    """Detect Dart call sites from a parent node's children (#87 bug 1).

        tree-sitter-dart does not emit a single ``call_expression`` node for
        Dart calls.  Instead it produces ``identifier`` / method-selector
        siblings followed by a ``selector`` whose child is ``argument_part``:

            identifier "print"
            selector
              argument_part

        And for method calls like ``obj.foo()`` the middle selector is a
        ``unconditional_assignable_selector`` holding the method name:

            identifier "obj"
            selector
              unconditional_assignable_selector "."
                identifier "foo"
            selector
              argument_part

        This walker scans the immediate children of ``parent`` for either
        shape and emits a ``CALLS`` edge.  Nested calls are picked up as
        ``_extract_from_tree`` recurses into child nodes.
        """
    def _extract_dart_calls_from_children(
        parent,
        source: bytes,
        file_path: str,
        edges: list[EdgeInfo],
        enclosing_class: Optional[str],
        enclosing_func: Optional[str],
    ) -> None;

    """Handle R-specific AST nodes (assignments and class-defining calls).

        Returns True if the child was fully handled and should be skipped
        by the main loop.
        """
    def _extract_r_constructs(
        child,
        node_type: str,
        source: bytes,
        language: str,
        file_path: str,
        nodes: list[NodeInfo],
        edges: list[EdgeInfo],
        enclosing_class: Optional[str],
        enclosing_func: Optional[str],
        import_map: Optional[dict[str, str]],
        defined_names: Optional[set[str]],
    ) -> bool;

    """Return an identifier or quoted operator component name."""
    static def _julia_component_name(`node) -> Optional[str];

    """Flatten the identifier prefix of a Julia field expression."""
    def _julia_field_parts(field_expr) -> list[str];

    """Return ``(qualifier, leaf)`` for a Julia field expression."""
    def _julia_field_info(field_expr) -> tuple[Optional[str], Optional[str]];

    """Join Julia scope paths without repeating an existing prefix."""
    static def _julia_scope_join(outer: Optional[str], inner: Optional[str]) -> Optional[str];

    """Return the outer definition call inside a Julia signature."""
    def _julia_signature_call(function_node) -> any;

    """Return the definition target inside a Julia signature."""
    def _julia_signature_callee(function_node) -> any;

    def _julia_definition_qualifier(function_node) -> Optional[str];

    def _julia_short_qualifier(call_expr) -> Optional[str];

    """Resolve a Julia import alias from the nearest lexical scope."""
    def _resolve_julia_import_alias(
        alias: str,
        enclosing_class: Optional[str],
        enclosing_func: Optional[str],
        import_map: dict[str, str],
    ) -> Optional[str];

    """Return whether this is the signature's definition call."""
    def _julia_call_is_in_signature(call_node) -> bool;

    """Extract the name from a ``call_expression`` that is the LHS of
        a short-form function ``f(x) = expr`` or ``Base.f(x) = expr`` or
        ``Foo{T}(x) = expr``.
        """
    def _julia_short_func_name(call_expr) -> Optional[str];

    """Return the first string literal argument of a call_expression."""
    def _julia_string_arg(call_expr) -> Optional[str];

    """First identifier of a ``call_expression`` (the function being
        called). Used to detect ``include("...")``.
        """
    def _julia_call_first_identifier(call_expr) -> Optional[str];

    """Handle Julia-specific constructs the type tables can't cover.

        Returns True if the child was fully handled and should be skipped
        by the main dispatch loop.
        """
    def _extract_julia_constructs(
        child,
        node_type: str,
        source: bytes,
        language: str,
        file_path: str,
        nodes: list[NodeInfo],
        edges: list[EdgeInfo],
        enclosing_class: Optional[str],
        enclosing_func: Optional[str],
        import_map: Optional[dict[str, str]],
        defined_names: Optional[set[str]],
        _depth: int,
    ) -> bool;

    """Handle Lua-specific AST constructs.

        Returns True if the child was fully handled and should be skipped
        by the main loop.

        Handles:
        - variable_declaration with require() -> IMPORTS_FROM edge
        - variable_declaration with function_definition -> named Function node
        - function_declaration with dot/method name -> Function with table parent
        - top-level require() call -> IMPORTS_FROM edge
        """
    def _extract_lua_constructs(
        child,
        node_type: str,
        source: bytes,
        language: str,
        file_path: str,
        nodes: list[NodeInfo],
        edges: list[EdgeInfo],
        enclosing_class: Optional[str],
        enclosing_func: Optional[str],
        import_map: Optional[dict[str, str]],
        defined_names: Optional[set[str]],
        _depth: int,
    ) -> bool;

    """Handle Lua variable declarations that contain require() or
        anonymous function definitions.

        ``local json = require("json")``  -> IMPORTS_FROM edge
        ``local fn = function(x) ... end`` -> Function node named "fn"
        """
    def _handle_lua_variable_declaration(
        child,
        source: bytes,
        language: str,
        file_path: str,
        nodes: list[NodeInfo],
        edges: list[EdgeInfo],
        enclosing_class: Optional[str],
        enclosing_func: Optional[str],
        import_map: Optional[dict[str, str]],
        defined_names: Optional[set[str]],
        _depth: int,
    ) -> bool;

    """Handle Lua function declarations with table-qualified names.

        ``function Animal.new(name)``  -> Function "new", parent "Animal"
        ``function Animal:speak()``    -> Function "speak", parent "Animal"

        Plain ``function foo()`` is NOT handled here (returns False).
        """
    def _handle_lua_table_function(
        child,
        source: bytes,
        language: str,
        file_path: str,
        nodes: list[NodeInfo],
        edges: list[EdgeInfo],
        enclosing_class: Optional[str],
        enclosing_func: Optional[str],
        import_map: Optional[dict[str, str]],
        defined_names: Optional[set[str]],
        _depth: int,
    ) -> bool;

    """Extract the module path from a Lua require() call.

        Returns the string argument or None if this is not a require() call.
        """
    static def _lua_get_require_target(call_node) -> Optional[str];

    static has _ZIG_CONTAINER_KINDS: any = frozenset({"struct", "union", "enum", "opaque"});

    """Handle Zig's PascalCase AST shapes.

        Top-level forms recognised:
          - ``Decl > FnProto + Block``         -> Function/Test node
          - ``Decl > VarDecl`` with ``@import`` -> IMPORTS_FROM edge
          - ``Decl > VarDecl`` with ``ContainerDecl`` (struct/union/enum/
            opaque) -> Class node, recurse for nested methods
          - ``TestDecl``                        -> Test node

        Returns True if the construct was fully handled and the main loop
        should skip generic recursion. Returns False to let generic
        recursion continue (e.g. unknown / line_comment children).
        """
    def _extract_zig_constructs(
        child,
        node_type: str,
        source: bytes,
        language: str,
        file_path: str,
        nodes: list[NodeInfo],
        edges: list[EdgeInfo],
        enclosing_class: Optional[str],
        enclosing_func: Optional[str],
        import_map: Optional[dict[str, str]],
        defined_names: Optional[set[str]],
        _depth: int,
    ) -> bool;

    """Emit a Function/Test node for ``fn name(...) ReturnType { body }``."""
    def _handle_zig_fn_decl(
        decl,
        fn_proto,
        body_block,
        source: bytes,
        language: str,
        file_path: str,
        nodes: list[NodeInfo],
        edges: list[EdgeInfo],
        enclosing_class: Optional[str],
        enclosing_func: Optional[str],
        import_map: Optional[dict[str, str]],
        defined_names: Optional[set[str]],
        _depth: int,
    ) -> bool;

    """Handle ``const Name = <expr>;`` decls.

        Recognises @import (-> IMPORTS_FROM) and struct/union/enum/opaque
        ContainerDecl (-> Class node + recurse). For other expressions,
        scans the RHS for nested call sites so call edges aren't lost.
        """
    def _handle_zig_var_decl(
        decl,
        var_decl,
        source: bytes,
        language: str,
        file_path: str,
        nodes: list[NodeInfo],
        edges: list[EdgeInfo],
        enclosing_class: Optional[str],
        enclosing_func: Optional[str],
        import_map: Optional[dict[str, str]],
        defined_names: Optional[set[str]],
        _depth: int,
    ) -> bool;

    """Handle ``test "label" { ... }`` blocks."""
    def _handle_zig_test_decl(
        child,
        source: bytes,
        language: str,
        file_path: str,
        nodes: list[NodeInfo],
        edges: list[EdgeInfo],
        enclosing_class: Optional[str],
        enclosing_func: Optional[str],
        import_map: Optional[dict[str, str]],
        defined_names: Optional[set[str]],
        _depth: int,
    ) -> bool;

    """Pull the string argument out of ``@import("path")``.

        Walks FnCallArguments > ErrorUnionExpr > SuffixExpr >
        STRINGLITERALSINGLE. Returns the unquoted contents or None.
        """
    static def _zig_extract_import_target(args_node) -> Optional[str];

    """Walk a subtree and emit a CALLS edge for each call site.

        A call site is a ``SuffixExpr`` or ``FieldOrFnCall`` node whose
        direct children include a ``FnCallArguments``; the callee is the
        IDENTIFIER (or BUILTINIDENTIFIER) immediately preceding it. The
        builtin ``@import`` is skipped here because it's already modelled
        as IMPORTS_FROM by _handle_zig_var_decl.
        """
    def _extract_zig_calls_in_subtree(
        `root,
        file_path: str,
        edges: list[EdgeInfo],
        enclosing_class: Optional[str],
        enclosing_func: Optional[str],
    ) -> None;

    static has _JS_FUNC_VALUE_TYPES: any = frozenset({
        "arrow_function",
        "function_expression",
        "function",
        "generator_function",
    });

    static has _JS_WRAPPER_MAX_DEPTH: any = 3;

    static has _JS_COMPONENT_WRAPPERS: any = frozenset({
        "forwardRef",
        "memo",
        "observer",
        "withRouter",
        "withStyles",
        "withTheme",
        "connect",
        "styled",
        "inject",
        "withTranslation",
        "withErrorBoundary",
    });

    static has _JS_CURRIED_WRAPPERS: any = frozenset({
        "connect",
        "withStyles",
        "inject",
        "withTranslation",
        "styled",
    });

    static has _JS_COMMENT_TYPES: any = frozenset({"comment", "html_comment"});

    """The arguments of a call, without the comments between them.

        ``forwardRef(/* why */ fn)`` passes one argument, not two.
        """
    def _js_argument_values(arguments) -> list;

    """The wrapper a call applies, or None when the callee is not one we can name.

        ``memo(fn)`` and ``React.memo(fn)`` both answer ``memo``; the curried
        ``styled(Base)(fn)`` and ``connect(map)(fn)`` answer through their own callee,
        followed no deeper than {@link _JS_WRAPPER_MAX_DEPTH}, the same bound the
        unwrapping keeps. A member callee answers only on ``React``: ``pool.connect(cb)``
        and ``utils.memo(fn)`` call methods that share a wrapper's name, and losing a
        namespace import such as ``ReactModule.forwardRef`` is the smaller mistake.
        """
    def _js_wrapper_name(call_node, _depth: int = 0) -> Optional[str];

    """Return the function literal a component wrapper call receives, if any.

        ``forwardRef(fn)``, ``memo(fn)``, ``observer(fn)``, ``withRouter(fn)`` and
        ``styled(Base)(fn)`` all put the component's function inside a
        ``call_expression`` instead of assigning it directly, and nested wrappers
        (``memo(forwardRef(fn))``) are unwrapped.

        Two things have to hold. The wrapper has to be one that returns a component
        ({@link _JS_COMPONENT_WRAPPERS}), and it has to take the function as its ONLY
        argument: a call that takes a callback among others is computing a value, and
        ``useMemo(() => x, [dep])`` assigns whatever it returns rather than the
        callback. ``memo`` is the one exception, its documented second argument is the
        props comparator: ``memo(fn, arePropsEqual)``. Calls without a function
        argument (``createClient({...})``) return None as well.

        ``chain``, when given, collects every wrapper call traversed, innermost first.
        Each of them runs where the declaration is, so the caller records them against
        the enclosing function rather than against the component.
        """
    def _js_wrapped_function(call_node, _depth: int = 0, chain=None) -> any;

    """Whether a declaration sits in the body of a test (``it``, ``describe``, ...).

        TESTED_BY edges are minted from the calls a test makes. A component a test
        builds for itself, ``const Probe = React.forwardRef(function Probe(props, ref)
        { ... useForkRef(handleOwnRef, ref) ... })`` inside ``it(...)``, is part of the
        test: indexing it would move ``useForkRef``'s caller onto the fixture and take
        the test out of ``tests_for(useForkRef)``. The enclosing function's node is
        added before its body is walked, so it is already in ``nodes``.
        """
    def _js_in_test_body(
        nodes: list[NodeInfo],
        file_path: str,
        enclosing_class: Optional[str],
        enclosing_func: Optional[str],
    ) -> bool;

    """Handle JS/TS variable declarations that assign functions.

        Patterns handled:
          const foo = () => {}
          let bar = function() {}
          export const baz = (x: number): string => x.toString()
          export const Button = forwardRef((props, ref) => <button ref={ref} />)

        Returns True if at least one function was extracted from the
        declaration, so the caller can skip generic recursion.
        """
    def _extract_js_var_functions(
        child,
        source: bytes,
        language: str,
        file_path: str,
        nodes: list[NodeInfo],
        edges: list[EdgeInfo],
        enclosing_class: Optional[str],
        enclosing_func: Optional[str],
        import_map: Optional[dict[str, str]],
        defined_names: Optional[set[str]],
        _depth: int,
    ) -> bool;

    """Handle class field arrow functions: handler = (e) => { ... }"""
    def _extract_js_field_function(
        child,
        source: bytes,
        language: str,
        file_path: str,
        nodes: list[NodeInfo],
        edges: list[EdgeInfo],
        enclosing_class: Optional[str],
        enclosing_func: Optional[str],
        import_map: Optional[dict[str, str]],
        defined_names: Optional[set[str]],
        _depth: int,
    ) -> bool;

    """Handle JS/TS member-assigned functions.

        Patterns handled (LHS is a ``member_expression``, RHS is a function):
          app.handle = function handle(req, res) {}
          Router.prototype.dispatch = (req) => {}
          exports.render = function () {}

        These prototype- and module-augmentation patterns carry the entire
        public API of Express, Koa and many older JS modules, but were
        previously invisible to the graph: only ``const x = fn``
        (:func:`_extract_js_var_functions`) and class fields
        (:func:`_extract_js_field_function`) produced Function nodes. The node
        is qualified by its full member path (``file::app.handle``), matching
        the ``file::Class.method`` shape used elsewhere.

        Returns True if a function was extracted, so the caller can skip
        generic recursion.
        """
    def _extract_js_member_functions(
        child,
        source: bytes,
        language: str,
        file_path: str,
        nodes: list[NodeInfo],
        edges: list[EdgeInfo],
        enclosing_class: Optional[str],
        enclosing_func: Optional[str],
        import_map: Optional[dict[str, str]],
        defined_names: Optional[set[str]],
        _depth: int,
    ) -> bool;

    """Return a stable identifier-only JS/TS member path."""
    static def _get_js_static_member_path(`node) -> Optional[str];

    """Return annotation names from the modifiers child of a Java class/method node."""
    static def _get_java_annotations(class_node) -> list[str];

    """Return the simple name of a Java annotation node."""
    static def _spring_config_annotation_name(annotation_node) -> Optional[str];

    static def _spring_config_string_literals(`node) -> list[str];

    """Read selected string arguments from a parsed Java annotation."""
    def _spring_config_annotation_values(
        annotation_node, accepted_keys: frozenset[str]
    ) -> list[str];

    """Emit Spring config dependencies while retaining no literal values."""
    def _emit_spring_config_edges(
        class_node,
        class_name: str,
        enclosing_class: Optional[str],
        file_path: str,
        edges: list[EdgeInfo],
    ) -> None;

    """Emit INJECTS edges for Spring DI injection points in a Java class.

        Handles four patterns:
        - @Autowired / @Inject / @Resource field injection
        - @Autowired constructor injection
        - Lombok @RequiredArgsConstructor with uninitialized final / @NonNull fields
        - Lombok @AllArgsConstructor with every non-static field
        """
    def _emit_spring_injections(
        class_node,
        class_name: str,
        class_annotations: list[str],
        language: str,
        file_path: str,
        edges: list[EdgeInfo],
        import_map: Optional[dict[str, str]] = None,
    ) -> None;

    """Emit one INJECTS edge per field selected by Spring/Lombok."""
    def _emit_spring_field_injection(
        field_node,
        qualified_source: str,
        file_path: str,
        edges: list[EdgeInfo],
        has_required_args: bool,
        has_all_args: bool,
        import_map: Optional[dict[str, str]],
    ) -> None;

    """Emit INJECTS edges for @Autowired constructor parameters."""
    def _emit_spring_constructor_injection(
        ctor_node,
        qualified_source: str,
        file_path: str,
        edges: list[EdgeInfo],
        import_map: Optional[dict[str, str]],
    ) -> None;

    """Return the simple name of a Java annotation AST node."""
    static def _java_annotation_name(annotation_node) -> Optional[str];

    """Collect direct and ``@Schedules``-contained ``@Scheduled`` nodes."""
    def _scheduled_annotations(method_node) -> list;

    """Extract named Java annotation arguments without evaluating them."""
    static def _java_annotation_attributes(annotation_node) -> dict[str, str];

    """Return string values nested below one Java annotation argument."""
    static def _java_string_literal_values(`node) -> list[str];

    """Extract only ``value``/``path`` route arguments from a mapping."""
    def _spring_mapping_paths(annotation_node) -> list[str];

    """Extract HTTP verbs from composed mappings or RequestMethod values."""
    def _spring_mapping_methods(annotation_node, name: str) -> list[str];

    """Join class and method mappings into one normalized route."""
    static def _join_spring_route(prefix: str, path: str) -> str;

    """Emit addressable endpoints and HANDLES edges for Spring mappings."""
    def _emit_spring_endpoint_nodes(
        method_node,
        method_name: str,
        class_name: Optional[str],
        file_path: str,
        import_map: dict[str, str],
        nodes: list[NodeInfo],
        edges: list[EdgeInfo],
    ) -> int;

    """Return whether a fluent Java invocation is rooted at ``route()``."""
    def _java_invocation_chain_has_route(invocation) -> bool;

    """Return a literal route and method-reference handler from one call."""
    static def _webflux_route_arguments(invocation) -> tuple[Optional[str], Optional[object]];

    """Resolve a WebFlux handler reference from lexical Java type evidence."""
    def _resolve_java_method_reference_target(
        reference,
        file_path: str,
        enclosing_class: Optional[str],
        import_map: dict[str, str],
        defined_names: set[str],
    ) -> Optional[str];

    """Link a direct functional WebFlux route to its actual handler."""
    def _emit_spring_webflux_endpoint(
        invocation,
        source: bytes,
        method: str,
        file_path: str,
        enclosing_class: Optional[str],
        import_map: dict[str, str],
        defined_names: set[str],
        nodes: list[NodeInfo],
        edges: list[EdgeInfo],
    ) -> bool;

    """Classify one Spring schedule by the trigger attribute it uses."""
    static def _spring_schedule_kind(attributes: dict[str, str]) -> str;

    """Emit one addressable Scheduler node and TRIGGERS edge per schedule."""
    def _emit_scheduled_nodes_from_method(
        method_node,
        method_name: str,
        class_name: Optional[str],
        file_path: str,
        nodes: list[NodeInfo],
        edges: list[EdgeInfo],
    ) -> int;

    """Return direct Java method annotations whose simple names match."""
    def _java_annotations_named(method_node, names: frozenset[str]) -> list;

    """Extract the outer Java reference type from a type-bearing AST node."""
    static def _java_type_name(`node) -> Optional[str];

    """Identity of a type in Spring DI, bare when a wildcard hides its package."""
    class def _spring_java_type(type_name: str, import_map: dict[str, str]) -> str;

    """Resolve a Java type to a stable package-qualified identity."""
    static def _resolve_java_type_identity(type_name: str, import_map: dict[str, str]) -> str;

    static def _descendants_of_type(`node, node_type: str) -> list;

    """Emit package-qualified HANDLES edges for ``@EventListener``."""
    def _emit_spring_event_listener_edges(
        method_node,
        method_name: str,
        class_name: Optional[str],
        file_path: str,
        import_map: dict[str, str],
        edges: list[EdgeInfo],
    ) -> int;

    """Emit PUBLISHES edges for direct ``publishEvent(new Event())`` calls."""
    def _emit_spring_event_publish_edges(
        method_node,
        method_name: str,
        class_name: Optional[str],
        file_path: str,
        import_map: dict[str, str],
        edges: list[EdgeInfo],
    ) -> int;

    """Emit TEMPORAL_STUB edges for Temporal activity/workflow stub fields.

        Detects fields whose type name ends with 'Activity' or 'Workflow' —
        the universal naming convention for Temporal interfaces. The temporal
        resolver validates these against nodes that have temporal_role in extra.
        Static fields are skipped (e.g. logger, constants).
        """
    def _emit_temporal_stub_fields(
        class_node, class_name: str, file_path: str, edges: list[EdgeInfo]
    ) -> None;

    """Extract topic strings from @KafkaListener(topics = "...") or topics = {"a","b"}."""
    static def _get_kafka_annotation_topics(annotation_node) -> list[str];

    """Emit CONSUMES/PRODUCES edges for Kafka field declarations.

        Handles:
        - KafkaReceiver / ReactiveKafkaConsumerTemplate → CONSUMES
        - KafkaTemplate / KafkaOperations / ReactiveKafkaProducerTemplate → PRODUCES
        Generic value type (e.g. KafkaReceiver<String, EquipmentMove>) is
        stored in extra.message_type for traceability.
        """
    def _emit_kafka_edges_from_class(
        class_node, class_name: str, file_path: str, edges: list[EdgeInfo]
    ) -> None;

    """Emit CONSUMES edges for @KafkaListener / @KafkaHandler annotated methods."""
    def _emit_kafka_edges_from_method(
        method_node,
        method_name: str,
        class_name: Optional[str],
        file_path: str,
        edges: list[EdgeInfo],
    ) -> None;

    """Extract a bounded documentation summary for a definition node."""
    def _get_docstring_summary(`node, language: str) -> Optional[str];

    """Return Python's actual string value for the first body statement.

        ``ast.literal_eval`` gives us CPython-compatible escape handling and
        implicit literal concatenation while naturally rejecting f-strings.
        A bytes literal evaluates successfully but is rejected by the final
        type check, matching ``__doc__`` semantics.
        """
    static def _python_docstring_value(`node) -> Optional[str];

    """Return one documentation-line payload, or ``None`` if not docs."""
    static def _line_doc_payload(text: str, language: str) -> Optional[str];

    """Return documentation directly attached above a definition."""
    def _preceding_doc_comment(`node, language: str) -> Optional[str];

    """Extract a class definition node and its inheritance edges.

        Returns True if the child was handled (class with a name found).
        """
    def _extract_classes(
        child,
        source: bytes,
        language: str,
        file_path: str,
        nodes: list[NodeInfo],
        edges: list[EdgeInfo],
        enclosing_class: Optional[str],
        import_map: Optional[dict[str, str]],
        defined_names: Optional[set[str]],
        _depth: int,
    ) -> bool;

    """Carry full method scopes only where legacy leaf scopes would collide.

        The per-file import map already carries internal resolver metadata.
        Keeping this index there avoids parser-instance state leaking between
        files (including recursive parsing). The tree is visited once.

        Python only: a Ruby class already descends with its full lexical scope,
        so its methods cannot collide on a leaf.
        """
    def _index_ambiguous_method_scopes(`root, language: str, import_map: dict) -> None;

    """Extract a function/method definition node.

        Returns True if the child was handled (function with a name found).
        """
    def _extract_functions(
        child,
        source: bytes,
        language: str,
        file_path: str,
        nodes: list[NodeInfo],
        edges: list[EdgeInfo],
        enclosing_class: Optional[str],
        import_map: Optional[dict[str, str]],
        defined_names: Optional[set[str]],
        _depth: int,
        enclosing_func: Optional[str] = None,
    ) -> bool;

    """Extract import edges from an import statement node.

        Returns True if at least one import edge was emitted. Some grammars
        reuse a single node type for both imports and ordinary calls (e.g.
        Ruby's ``call`` covers both ``require``/``require_relative`` and method
        invocation). Returning False lets the dispatcher fall through to call
        extraction instead of silently dropping the call. See: Ruby call graph.
        """
    def _extract_imports(
        child, language: str, source: bytes, file_path: str, edges: list[EdgeInfo]
    ) -> bool;

    """The single target one import statement names, and its scope.

        Most languages name a file, and the scope is ``None``. Two do not:
        a Go import names a PACKAGE, which is a directory of files, and
        Ruby's ``require_all`` names a directory tree. Both resolve to the
        directory itself with :data:`IMPORT_SCOPE_PACKAGE` or
        :data:`IMPORT_SCOPE_TREE`, and the read path expands the directory
        to its member files when a caller asks.

        Naming the directory rather than fanning out to one edge per file is
        what keeps the edge count proportional to the number of imports
        instead of imports times package size, and what makes an incremental
        update equal a rebuild: the target no longer depends on which files
        happened to be in the package when the importing file was parsed.
        """
    def _resolve_import_target(
        module: str, file_path: str, language: str, form: Optional[str] = None
    ) -> tuple[Optional[str], Optional[str]];

    """Extract call expressions, including test runner special cases.

        Returns True if the child was fully handled (a test runner call or a
        statically unreachable Python call that should skip default
        recursion). Returns False if the caller should continue to Solidity
        handling and default recursion.
        """
    def _extract_calls(
        child,
        source: bytes,
        language: str,
        file_path: str,
        nodes: list[NodeInfo],
        edges: list[EdgeInfo],
        enclosing_class: Optional[str],
        enclosing_func: Optional[str],
        import_map: Optional[dict[str, str]],
        defined_names: Optional[set[str]],
        _depth: int,
        _go_receiver_bindings: Optional[tuple[str, tuple[int, ...], tuple[int, ...]]] = None,
    ) -> bool;

    """Return a static JS/TS member-call expression, if present.

        ``_get_call_name`` intentionally reduces ``app.handle()`` to
        ``handle`` for general method-call handling. Retain ``app.handle`` as
        supplemental evidence so the same-file resolver can link it to a
        member-assigned definition without changing unresolved external calls.
        Computed and multiline expressions are intentionally excluded.
        """
    static def _get_js_member_call_name(`node) -> Optional[str];

    """Return a simple receiver name and method for a member call.

        ``self.field.save()`` and ``this.field.save()`` use ``field`` as the
        receiver so class-field annotations can resolve them. More complex
        receiver expressions are deliberately left unresolved.
        """
    def _get_member_call_receiver_method(
        `node, language: str
    ) -> tuple[Optional[str], Optional[str]];

    """Return ``(receiver, method)`` for a C# invocation expression.

        Handles ``obj.Method()`` / ``Class.Method()`` (member access),
        ``this.field.Method()`` (class-field receiver), and
        ``obj?.Method()`` (conditional access via a member binding).
        Chained or computed receivers keep the method name but no receiver.
        """
    static def _get_csharp_receiver_method(`node) -> tuple[Optional[str], Optional[str]];

    """Resolve PHP ``Class::method`` calls from lexical file evidence.

        Resolution happens during parsing, so incremental updates touch only
        the changed file. Bare cross-file class names are deliberately left
        unresolved; accepted evidence is a same-file method, ``self``/``static``,
        an explicit import, a qualified name, or the current PHP namespace.
        """
    def _resolve_php_scoped_calls(
        `root, nodes: list[NodeInfo], edges: list[EdgeInfo], file_path: str
    ) -> list[EdgeInfo];

    """Run evidence-gated Laravel analysis without altering generic calls."""
    def _extract_php_laravel_edges(
        `root, file_path: str, nodes: list[NodeInfo], edges: list[EdgeInfo]
    ) -> None;

    """Walk a PHP namespace scope, applying imports in source order."""
    def _walk_php_laravel_sequence(
        container, file_path: str, nodes: list[NodeInfo], edges: list[EdgeInfo], namespace: str
    ) -> None;

    """Walk one PHP subtree with its namespace and enclosing-class evidence."""
    def _walk_php_laravel_node(
        `node,
        file_path: str,
        nodes: list[NodeInfo],
        edges: list[EdgeInfo],
        namespace: str,
        imports: dict[str, str],
        enclosing_class: Optional[str],
        enclosing_func: Optional[str],
        eloquent_model: bool,
    ) -> None;

    static def _php_namespace_name(`node) -> str;

    """Return case-insensitive local class aliases for a PHP use statement."""
    static def _php_import_bindings(`node) -> dict[str, str];

    """Resolve a PHP class reference through aliases and its namespace."""
    static def _php_resolve_class_reference(
        reference: str, namespace: str, imports: dict[str, str]
    ) -> str;

    def _php_class_extends_eloquent_model(`node, namespace: str, imports: dict[str, str]) -> bool;

    """Return the static receiver and method for a PHP scoped call."""
    static def _php_scoped_call_parts(`node) -> tuple[Optional[str], Optional[str]];

    static def _php_class_constant_reference(`node) -> Optional[str];

    def _php_route_handler(`node) -> Optional[tuple[str, str]];

    static def _php_route_arguments(`node) -> list;

    """Return a quoted PHP string's value without interpolation or escapes, else None.

        Single-quoted strings are decoded (``\\'`` and ``\\\\``); double-quoted strings
        with escape sequences or interpolation are rejected.
        """
    static def _php_string_literal(value) -> Optional[str];

    class def _php_route_literal(`node) -> Optional[str];

    def _php_route_facade_call(`node, namespace: str, imports: dict[str, str]) -> Optional[str];

    """Read literal prefix and controller from a Route group call chain."""
    def _php_route_group_settings(
        call, namespace: str, imports: dict[str, str]
    ) -> Optional[tuple[str, Optional[str]]];

    def _php_route_enclosing_groups(
        `node, namespace: str, imports: dict[str, str]
    ) -> Optional[tuple[str, Optional[str]]];

    def _php_endpoint_handler(
        argument, group_controller: Optional[str]
    ) -> Optional[tuple[str, str]];

    """Emit parse-time Laravel endpoints using Spring's node and edge shape."""
    def _emit_laravel_endpoint_nodes(
        `node,
        file_path: str,
        nodes: list[NodeInfo],
        edges: list[EdgeInfo],
        namespace: str,
        imports: dict[str, str],
    ) -> None;

    def _php_semantic_target(
        class_reference: str,
        namespace: str,
        imports: dict[str, str],
        file_path: str,
        method: Optional[str] = None,
    ) -> str;

    def _php_laravel_caller(
        file_path: str, enclosing_class: Optional[str], enclosing_func: Optional[str]
    ) -> str;

    def _emit_laravel_route_edge(
        `node,
        file_path: str,
        edges: list[EdgeInfo],
        namespace: str,
        imports: dict[str, str],
        enclosing_class: Optional[str],
        enclosing_func: Optional[str],
    ) -> None;

    def _emit_laravel_relationship_edge(
        `node,
        file_path: str,
        edges: list[EdgeInfo],
        namespace: str,
        imports: dict[str, str],
        enclosing_class: Optional[str],
        enclosing_func: Optional[str],
    ) -> None;

    """For a Java method_invocation node, return (method_name, receiver_name).

        Pattern: [receiver_identifier, '.', method_identifier, argument_list]
        Chained: [inner_method_invocation, '.', method_identifier, argument_list]

        Returns (None, None) for unrecognised shapes.
        """
    static def _get_java_method_and_receiver(`node) -> tuple[Optional[str], Optional[str]];

    """Whether a Java call is made on ``this.field``."""
    static def _java_this_field_call(`node) -> bool;

    """Whether a Java call is made on an expression with no name or type.

        ``items.stream().count()`` and ``"x".length()`` say nothing about which
        class answers them. ``new Cart().total()`` and ``this.x()`` do.
        """
    class def _java_expression_receiver(`node) -> bool;

    """Emit a synthetic CALLS edge for JSX component usage.

        React-style component invocations use JSX rather than ``call_expression``.
        Treat uppercase component tags such as ``<MarkdownMsg />`` as call-like
        edges so caller/impact queries can cross the JSX boundary. Intrinsic DOM
        tags (``<div>``) are ignored.

        Module-scope JSX (e.g. a top-level ``<App />`` render call) attributes
        to the File node.
        """
    def _extract_jsx_component_call(
        child,
        language: str,
        file_path: str,
        edges: list[EdgeInfo],
        enclosing_class: Optional[str],
        enclosing_func: Optional[str],
        import_map: Optional[dict[str, str]],
        defined_names: Optional[set[str]],
    ) -> None;

    """Resolve a JSX component element to a call target."""
    def _resolve_jsx_component_target(
        `node, language: str, file_path: str, import_map: dict[str, str], defined_names: set[str]
    ) -> Optional[str];

    static has _PAIR_TYPES: any = frozenset({"pair"});

    static has _ARRAY_TYPES: any = frozenset({"array", "list"});

    static has _ARGUMENTS_TYPES: any = frozenset({"arguments", "argument_list"});

    static has _VALUE_REF_SKIP_NAMES: any = frozenset({
        "true",
        "false",
        "null",
        "undefined",
        "None",
        "True",
        "False",
        "self",
        "this",
        "cls",
        "super",
    });

    """Emit a ``REFERENCES`` edge for a type used in a TS type position.

        ``function summarize(items: Finding[])`` is a real dependency on
        ``Finding``, but a type annotation is not call syntax, so neither
        _extract_calls nor _extract_value_references sees it and callers_of on
        an interface stays empty.

        ``REFERENCES`` (0.6 in IMPACT_EDGE_WEIGHTS) rather than ``CALLS`` (1.0):
        a type use is a weaker signal than an invocation, and folding the two
        together would let type churn outrank call churn in impact ranking.
        """
    def _extract_ts_type_reference(
        child,
        language: str,
        file_path: str,
        edges: list[EdgeInfo],
        enclosing_class: Optional[str],
        enclosing_func: Optional[str],
        import_map: Optional[dict[str, str]],
        defined_names: Optional[set[str]],
    ) -> None;

    """Emit ``REFERENCES`` edges for function-as-value patterns.

        Detects identifiers in value positions that likely refer to
        functions — object literal values, map property assignments,
        array elements, and callback arguments.  This reduces false
        positives in dead-code detection for dispatch-map patterns
        like ``Record<string, Handler>``.

        Only emits edges when the identifier matches a locally defined
        name or an imported symbol, avoiding noise from arbitrary
        variable references.
        """
    def _extract_value_references(
        child,
        node_type: str,
        source: bytes,
        language: str,
        file_path: str,
        edges: list[EdgeInfo],
        enclosing_class: Optional[str],
        enclosing_func: Optional[str],
        import_map: Optional[dict[str, str]],
        defined_names: Optional[set[str]],
    ) -> None;

    """Emit a ``REFERENCES`` edge if *name* is a known function/import."""
    def _emit_reference_if_known(
        name: str,
        language: str,
        file_path: str,
        caller: str,
        edges: list[EdgeInfo],
        import_map: dict[str, str],
        defined_names: set[str],
        line: int = 0,
    ) -> None;

    """Extract a REFERENCES edge from an object/dict literal pair value."""
    def _ref_from_pair(
        pair_node,
        source: bytes,
        language: str,
        file_path: str,
        caller: str,
        edges: list[EdgeInfo],
        import_map: dict[str, str],
        defined_names: set[str],
    ) -> None;

    """Extract REFERENCES from ``obj.key = fnRef`` or ``obj['key'] = fnRef``."""
    def _ref_from_assignment(
        assign_node,
        source: bytes,
        language: str,
        file_path: str,
        caller: str,
        edges: list[EdgeInfo],
        import_map: dict[str, str],
        defined_names: set[str],
    ) -> None;

    """Extract REFERENCES from array/list elements that are identifiers."""
    def _ref_from_array(
        array_node,
        source: bytes,
        language: str,
        file_path: str,
        caller: str,
        edges: list[EdgeInfo],
        import_map: dict[str, str],
        defined_names: set[str],
    ) -> None;

    """Extract REFERENCES from identifier arguments (callbacks)."""
    def _ref_from_arguments(
        args_node,
        source: bytes,
        language: str,
        file_path: str,
        caller: str,
        edges: list[EdgeInfo],
        import_map: dict[str, str],
        defined_names: set[str],
    ) -> None;

    """Handle Solidity-specific AST constructs (emit, state vars, etc.).

        Returns True if the child was fully handled and should skip
        default recursion.
        """
    def _extract_solidity_constructs(
        child,
        node_type: str,
        source: bytes,
        file_path: str,
        nodes: list[NodeInfo],
        edges: list[EdgeInfo],
        enclosing_class: Optional[str],
        enclosing_func: Optional[str],
    ) -> bool;

    """Return semantic Rust path segments while discarding type arguments."""
    def _rust_path_segments(`node) -> list[str];

    """Flatten nested Rust use trees into local-name/original-path pairs."""
    def _parse_rust_use_node(`node, prefix: tuple[str, ...] = ()) -> list[tuple[str, str]];

    """Resolve a Rust type path only when file evidence is available."""
    def _resolve_rust_type_target(
        segments: list[str], file_path: str, import_map: dict[str, str], defined_names: set[str]
    ) -> str;

    """Use impl blocks as method scopes without emitting duplicate types."""
    def _extract_rust_impl(
        impl_node,
        source: bytes,
        file_path: str,
        nodes: list[NodeInfo],
        edges: list[EdgeInfo],
        import_map: dict[str, str],
        defined_names: set[str],
        depth: int,
    ) -> None;

    """Index module-level RTL declarations without inventing local globals.

        Signal-like declarations use Function nodes for backward-compatible
        storage, but carry ``extra["verilog_kind"]`` so function-oriented
        analyses can exclude them. Function/task-local declarations are
        intentionally consumed without emission because the graph has no
        variable-scope identity model.
        """
    def _extract_verilog_constructs(
        child,
        node_type: str,
        file_path: str,
        nodes: list[NodeInfo],
        edges: list[EdgeInfo],
        enclosing_class: Optional[str],
        enclosing_func: Optional[str],
    ) -> bool;

    """Pre-scan top-level AST to collect import mappings and defined names.

        ``file_path`` is what makes a Python relative import resolvable —
        ``.graph`` names a different module from every directory — so callers
        that have it must pass it.

        Returns:
            (import_map, defined_names) where import_map maps imported names
            to their source module/path, and defined_names is the set of
            function/class names defined at file scope.
        """
    def _collect_file_scope(
        `root, language: str, source: bytes, file_path: Optional[str] = None
    ) -> tuple[dict[str, str], set[str]];

    """Collect Julia aliases without leaking them across modules."""
    def _collect_julia_scoped_import_names(
        `node, source: bytes, import_map: dict[str, str], scope: Optional[str] = None
    ) -> None;

    """Add public names from repository-local Python star imports."""
    def _expand_python_star_imports(
        `root,
        file_path: str,
        import_map: dict[str, str],
        resolving: frozenset[str] = resolving_default_,
    ) -> None;

    """Return exported names mapped to their repository-local origin files."""
    def _get_python_star_exports(
        module_file: str, resolving: frozenset[str] = resolving_default__
    ) -> dict[str, str];

    """Read and parse one Python module for star-export discovery."""
    def _read_python_star_exports(module_path: Path, resolving: frozenset[str]) -> dict[str, str];

    """Return literal string names from ``__all__``, or None if absent."""
    static def _extract_python_dunder_all(`root) -> Optional[set[str]];

    """Return the filesystem boundary for safe import lookup.

        Shared by every language whose resolver walks the filesystem: the
        configured repository root when there is one, else the nearest VCS
        checkout at or above the caller.
        """
    def _import_repo_boundary(file_path: str) -> Path;

    """Return whether *path* is *boundary* or one of its descendants."""
    static def _path_is_within(path: Path, boundary: Path) -> bool;

    """Case-exact ``is_file`` for module lookup in any language.

        ``Path.is_file()`` answers "yes" to ``Registry.py`` on APFS/NTFS when
        only ``registry.py`` exists, which is how a wrong import target
        reached the graph as a confident, real-looking file path and stayed
        invisible to everyone not on Linux. Module resolution therefore
        compares against the directory's real listing, cached per directory
        because a package is probed once per import that names it.

        A file marked via :meth:`exclude_files` answers False. ``forget`` asks
        for the graph a build without that file would have produced, and in
        that build the file is simply not on disk — so the probe must miss it
        here rather than be filtered out one layer up in
        :meth:`_resolve_module_to_file`, which every Python-specific caller
        below reaches around. Missing *here* also lets resolution fall through
        to the next candidate, exactly as the real absence would.
        """
    def _file_exists_exact(path: Path) -> bool;

    """The real names in *directory*, cached per directory.

        One listing backs every case-exact probe below, because a package is
        probed once per import that names it.
        """
    def _dir_entry_names(directory: Path) -> frozenset[str];

    """:meth:`_path_is_indexed` under this parser's repository, for aliases."""
    def _npm_alias_path_is_indexed(path: Path) -> bool;

    """Whether a build would index *path*, so an edge may name it.

        The ignore patterns are the single source of truth for what becomes a
        node. Resolving an import into ``vendor/`` -- excluded by the default
        ``**/vendor/**`` -- produced 73,507 kubernetes edges naming files that
        no node answers to: a confident-looking path that resolves to
        nothing, which reads worse than the bare module string it replaced.
        An import that lands on an unindexed path therefore resolves to
        nothing, and the edge keeps the bare module string.

        ``incremental`` imports this module, so the patterns can only be
        fetched at call time; the answer is memoised per boundary, and a
        parser is rebuilt for every build and every update.
        """
    def _path_is_indexed(path: Path, boundary: Path) -> bool;

    """The uncached body of :meth:`_path_is_indexed`."""
    def _compute_path_is_indexed(path: Path, boundary: Path) -> bool;

    """The ignore patterns in force under *boundary*, or ``None``."""
    def _ignore_patterns(boundary: Path) -> Optional[list[str]];

    """Case-exact ``is_dir`` for package lookup in any language.

        Same reason as :meth:`_file_exists_exact`: a PEP 420 namespace
        package is a directory, and ``Path.is_dir()`` would confirm a
        spelling that is not on disk.
        """
    def _dir_exists_exact(path: Path) -> bool;

    """Original (pre-alias) names bound after ``import`` in a from-import."""
    static def _python_imported_names(`node) -> list[str];

    """Directory of the package *module* names, or None if it is not one.

        Covers both kinds of package CPython recognises: a regular one, whose
        directory holds ``__init__.py``, and a PEP 420 namespace package,
        which is a bare directory. A namespace package has no file of its own
        — nothing for an ``IMPORTS_FROM`` edge to point at — but its
        submodules are ordinary files, so callers still need its directory.
        """
    def _python_package_dir(module: str, file_path: Optional[str]) -> Optional[Path];

    """File backing submodule *name* of the package at *package_dir*.

        ``None`` for a name that is a symbol rather than a module, and for a
        namespace subpackage, which has no file of its own.
        """
    def _python_submodule_file(package_dir: Path, name: str) -> Optional[str];

    static has _PY_MODULE_ALIAS_MAX_DEPTH: any = 5;

    """The module that really answers an import of *module_file*.

        A compatibility shim such as::

            import importlib, sys
            sys.modules[__name__] = importlib.import_module("pkg.real")

        swaps itself out of ``sys.modules`` on first import, so ``import shim``
        hands the caller ``pkg/real.py``. Treating the five-line shim as the
        module left every ``shim.func()`` without a definition to land on and
        recorded the shim as the file importers depend on. Follows chains of
        shims; returns *module_file* unchanged for an ordinary module, a
        target outside the repository, or a target excluded via
        :meth:`exclude_files` (a build without that file would not see it).
        """
    def _python_module_alias_target(module_file: str) -> str;

    """One hop of :meth:`_python_module_alias_target`, cached per file."""
    def _python_module_alias(module_file: str) -> Optional[str];

    """:meth:`_read_python_module_alias`, cached by the file's mtime and size."""
    class def _cached_python_module_alias(module_path: Path) -> Optional[str];

    """Dotted module a file installs as ``sys.modules[__name__]``, if any.

        Only the literal, module-level form counts:
        ``sys.modules[__name__] = importlib.import_module("dotted.name")``
        (or ``import_module(...)`` imported from ``importlib``). A computed or
        relative module name, a swap inside a function or ``if`` block, or a
        later write that replaces the literal swap is not something static
        analysis can follow, so the file stays the module. Of several
        module-level swaps the last one is what importers get.
        """
    static def _read_python_module_alias(module_path: Path) -> Optional[str];

    """How *local* is bound anywhere in *tree*, one entry per binding.

        An import binding is ``(module, imported name)``: ``import importlib``
        gives ``("importlib", None)`` and ``from importlib import
        import_module`` gives ``("importlib", "import_module")``. Any other
        binding (def, class, assignment, loop or ``with`` target, ``global``)
        is ``("", None)``, which matches no expected import.
        """
    static def _python_name_bindings(
        tree: ast.Module, local: str
    ) -> list[tuple[str, Optional[str]]];

    """Imported names that are themselves modules inside *package_dir*.

        ``from . import incremental`` and ``from .tools import query`` import a
        MODULE through a package: the statement's real dependency is that
        submodule's file, not only the package ``__init__.py``. Only names
        that answer to a module in the package directory qualify, so
        ``from .graph import GraphStore`` (a class) stays a single edge and
        edge counts do not inflate.
        """
    def _python_submodule_names(`node, package_dir: Path) -> list[str];

    """Every module one ``from X import a, b`` statement depends on.

        The package itself, plus any imported name that is a submodule rather
        than a symbol. A PEP 420 namespace package contributes no target of
        its own — it has no file — only its submodules; emitting the raw
        ``.ns`` specifier there would be a target no node can ever answer to.
        """
    def _python_from_import_targets(`node, module: str, file_path: Optional[str]) -> list[str];

    """Resolve an ``import_map`` value for Python to a repository file.

        Values are either a dotted module name (absolute import) or an
        already-resolved absolute file path — relative imports and star
        imports both store the path, because a relative module string cannot
        be resolved without the importing file's package.
        """
    def _python_import_origin(module: str, file_path: str) -> Optional[str];

    """``(search roots, boundary, module tail)`` for a Python module.

        The leading dots of a relative import ARE the resolution: one dot is
        the caller's own package, each further dot one package up, and there
        is exactly one place to look. An absolute import walks up from the
        caller's directory, never past the repository root — a match above it
        is another checkout or a site-packages copy, not this repository's
        module.
        """
    def _python_module_search(module: str, file_path: str) -> tuple[list[Path], Path, Path];

    """Whether *folder* cannot be where an absolute standard library import lands.

        Python 3 looks on ``sys.path``, and a package's own folder is not on it,
        so ``pkg/typing.py`` does not answer ``import typing``.
        """
    def _python_folder_hides_module(module: str, folder: Path) -> bool;

    """The files CPython would load for a module rooted at *base*, in order.

        ``FileFinder`` checks the package directory before the same-named
        module file, so with both ``pkg/m/__init__.py`` and ``pkg/m.py`` on
        disk ``import pkg.m`` loads the package — verified against the
        interpreter, not inferred. Probing ``m.py`` first silently bound
        every such import to the wrong file.
        """
    static def _python_module_candidates(base: Path, has_tail: bool) -> tuple[Path, ...];

    """Resolve a Python module without traversing above the repository."""
    def _resolve_python_module_in_repo(module: str, file_path: str) -> Optional[str];

    """Directory of the PEP 420 namespace package *module* names.

        Only reached once :meth:`_resolve_python_module_in_repo` has found no
        file, which keeps CPython's precedence intact: a real ``m.py`` wins
        over a same-named directory with no ``__init__.py``, because the
        namespace package is what the finder falls back to, not what it
        prefers.
        """
    def _resolve_python_namespace_dir(module: str, file_path: str) -> Optional[Path];

    """Collect locally exported JS/TS names from export statements."""
    def _collect_js_exported_local_names(`node, defined_names: set[str]) -> None;

    """Return a literal module target from ``require``/``import``.

        Only direct calls with exactly one non-empty string (or a template
        literal without substitutions) are accepted. Expressions such as
        ``path.join(...)`` and interpolated templates are deliberately
        ignored because reducing them to a path prefix creates false edges.
        """
    static def _js_static_module_target(call_node) -> Optional[str];

    """Emit one file-level IMPORTS_FROM edge for a static module call."""
    def _extract_js_module_call(
        call_node, file_path: str, language: str, edges: list[EdgeInfo]
    ) -> None;

    """Whether a ``require``/``import()`` call runs after its file has loaded."""
    static def _js_module_call_is_deferred(call_node) -> bool;

    """Collect direct and shorthand-destructured CommonJS bindings."""
    def _collect_js_require_names(declaration, import_map: dict[str, str]) -> None;

    """Extract imported names and their source modules into import_map."""
    def _collect_import_names(
        `node,
        language: str,
        source: bytes,
        import_map: dict[str, str],
        file_path: Optional[str] = None,
    ) -> None;

    """Walk JS/TS import_clause to extract named and default imports."""
    def _collect_js_import_names(clause_node, module: str, import_map: dict[str, str]) -> None;

    """Return the exported name behind a local JS/TS import alias."""
    static def _js_imported_symbol_name(local_name: str, import_map: dict[str, str]) -> str;

    """Treat these files as absent when resolving imports.

        ``forget`` calls this before re-parsing the surviving referrers of a
        forgotten file so their imports resolve exactly as they would in a
        build where the forgotten files never existed: an import that would
        point at a forgotten file falls back to a bare module, and the calls
        it feeds stay bare too.
        """
    def exclude_files(paths: set[str]) -> None;

    """Resolve a module/import path to an absolute file path.

        Uses self._module_file_cache to avoid repeated filesystem lookups.
        Files marked via :meth:`exclude_files` resolve to ``None`` so callers
        fall back to the bare module string, matching a build without them.

        *form* distinguishes two import keywords that take identical module
        strings and resolve them differently -- Ruby's ``require`` against
        the load paths, ``require_relative`` against the requiring file's
        own directory -- so it is part of the cache key, not just an
        argument. See :class:`_ImportSpec`.
        """
    def _resolve_module_to_file(
        module: str, file_path: str, language: str, form: Optional[str] = None
    ) -> Optional[str];

    """Language-aware module-to-file resolution."""
    def _do_resolve_module(
        module: str, file_path: str, language: str, form: Optional[str] = None
    ) -> Optional[str];

    """Join *relative* onto *base*, as parts relative to *boundary*.

        ``None`` when the result leaves *boundary*. That is the repository
        rule: a go.mod ``replace => ../outside`` and a
        ``require_relative "../../../elsewhere"`` both name real files, and
        neither may become an edge target.
        """
    def _parts_within(base: Path, relative: str, boundary: Path) -> Optional[tuple[str, ...]];

    """Walk *parts* below *boundary*, each component case-exactly.

        Empty *parts* is *boundary* itself, which is what a Go import equal
        to the module path (``import "github.com/spf13/cobra"``) names.
        """
    def _exact_dir(boundary: Path, parts: tuple[str, ...]) -> Optional[Path];

    """The file at *parts* below *boundary*, every component case-exact."""
    def _exact_file(boundary: Path, parts: tuple[str, ...]) -> Optional[Path];

    """The ``go.mod`` declared in *directory*, if there is one."""
    def _go_module_at(directory: Path) -> Optional[_GoModule];

    """Every go.mod from *caller_dir* up to *boundary*, nearest first.

        Nearest first is what makes a nested module win over its ancestor.
        Keeping the ancestors in the chain is what lets a file inside a
        nested module (cli/cli has one under .github/codeql) still resolve
        an import of the outer module's own packages.
        """
    def _go_module_chain(caller_dir: Path, boundary: Path) -> list[_GoModule];

    """The directory *module* names within one module, or ``None``."""
    def _go_package_dir(record: _GoModule, module: str, boundary: Path) -> Optional[Path];

    """Whether *package_dir* holds at least one indexed ``.go`` file.

        A Go import path names a package, and a directory with no indexed Go
        source is not one that this graph can answer for: ``vendor/`` is
        excluded by the default ignore patterns, and ``k8s.io/kubernetes``
        has an ``api/`` directory of OpenAPI specs that no import can mean.
        Only PRESENCE is tested, never how many files, so adding a file to a
        package -- the case that made an incremental update disagree with a
        rebuild -- never changes what an import of it resolves to.
        """
    def _go_package_holds_source(package_dir: Path, boundary: Path) -> bool;

    """Resolve one Go import path to the package DIRECTORY it names.

        A directory, not a file: a Go import names a package, and every file
        in that directory is part of it. Emitting the directory once is what
        keeps the edge count proportional to the number of import statements
        rather than to imports times package size; the read path expands the
        directory to its files. See :meth:`_resolve_import_target`.

        Returns ``None`` for the standard library, for any dependency that is
        neither vendored nor ``replace``d into this repository, and for any
        directory the build does not index, so the caller keeps the bare
        import string rather than naming a path nothing will answer to.
        """
    def _resolve_go_package_dir(module: str, file_path: str) -> Optional[Path];

    """The uncached body of :meth:`_resolve_go_package_dir`."""
    def _do_resolve_go_package_dir(module: str, file_path: str) -> Optional[Path];

    """Whether *boundary* is shaped like a Rails application."""
    def _ruby_looks_like_rails(boundary: Path) -> bool;

    """``require_paths`` declared by the gemspecs at the repository root."""
    def _ruby_gemspec_require_paths(boundary: Path) -> tuple[str, ...];

    """Directories a repository-root script adds to ``$LOAD_PATH``.

        Only the scripts a build can afford to read are scanned: the root's
        own ``.rb`` files, ``Rakefile``, ``Gemfile``, the gemspecs, and the
        two conventional test helpers. A ``$LOAD_PATH`` push written
        anywhere else is not visible here. That is a stated limit, not a
        guarantee -- the alternative is reading every file in the repository
        before resolving the first import.
        """
    def _ruby_load_path_additions(boundary: Path) -> list[Path];

    """The directories a bare ``require`` searches in this repository.

        Discovered from the repository rather than guessed: the gemspec's
        ``require_paths`` (``lib`` when it declares none), ``lib``/``test``/
        ``spec`` when they exist, the Rails ``app`` autoload roots, and any
        directory a ``$LOAD_PATH.unshift`` in a repository-root script
        names.

        Rails' implicit Zeitwerk autoloading by constant name is out of
        scope and deliberately absent: a bare ``Jekyll::Drops::Drop``
        reference is not an import statement, so there is nothing for a
        module-to-file import resolver to resolve. Supporting it needs a
        constant-reference resolver and autoload-root discovery from
        config/application.rb, which is a separate feature.
        """
    def _ruby_load_roots(boundary: Path) -> tuple[Path, ...];

    """Whether any indexed ``.rb`` file sits below *directory*.

        Like :meth:`_go_package_holds_source`, this tests presence and never
        counts: what a ``require_all`` resolves to does not change when a
        file is added to or removed from the tree it names.
        """
    def _ruby_tree_holds_source(directory: Path, boundary: Path) -> bool;

    """Resolve ``require_all "jekyll/commands"`` to the DIRECTORY it names.

        The ``require_all`` gem loads every ``.rb`` file below the directory
        it names, so it is a directory-scoped import like a Go package
        import, not a single file. jekyll declares six subsystems this way
        (commands, converters, converters/markdown, drops, generators, tags)
        and every one of them was invisible to the graph.

        ``None`` when the name is not an indexed directory, which sends the
        caller to the ordinary ``require`` probe -- what the gem itself does
        for a plain file argument.
        """
    def _resolve_ruby_require_all_dir(module: str, file_path: str) -> Optional[Path];

    """Return a Java file's Maven or Gradle source root and the others it sees.

        ``src/test/java`` compiles against ``src/main/java``, but the two share
        no directory the import walk climbs through, so a test's own module was
        out of its reach. ``main`` sees none of the others. Returns
        ``(None, [])`` outside that layout.
        """
    def _java_source_roots(file_path: str) -> tuple[Optional[Path], list[Path]];

    """Return the file of a class in this file's package, in any source set.

        Java asks for no import here, so a test beside its class has no other
        evidence to offer. The file name is what ties the class to the package,
        so a class written inside another file's body is not found.
        """
    def _java_same_package_file(class_name: str, file_path: str) -> Optional[str];

    """Point ``new Cart()`` at ``Cart`` when it lives in this file's package.

        An import wins over the package in Java, so a name this file imports is
        left alone even when the import leads outside the repository.
        """
    def _qualify_java_same_package_constructors(
        edges: list[EdgeInfo], file_path: str, import_map: dict[str, str]
    ) -> list[EdgeInfo];

    """Stop a Java test's call on an unknown type matching by name alone.

        Now that a test's imports resolve, ``items.size()`` on a ``List`` would
        otherwise bind to ``size`` in any class the test imports, and claim
        coverage of it. A receiver with a known type already has a target.
        """
    static def _mark_java_unknown_test_receivers(edges: list[EdgeInfo]) -> list[EdgeInfo];

    """Resolve one Ruby require/autoload/load to a file in this repository.

        ``require_relative`` resolves against the requiring file's own
        directory. ``require``, ``load`` and ``autoload`` resolve against
        the repository's load roots. A gem or a stdlib feature matches no
        root and stays ``None``, so the edge keeps the bare string --
        ``nokogiri`` must never bind to a repository file.
        """
    def _resolve_ruby_module_file(
        module: str, file_path: str, form: Optional[str]
    ) -> Optional[str];

    """Collect Cargo dependency tables, including target-specific ones."""
    static def _rust_dependency_specs(manifest: dict[str, Any]) -> dict[str, Any];

    """Return ``(source root, crate root module)`` for a local crate."""
    static def _rust_crate_layout(crate_root: Path) -> Optional[tuple[Path, Path]];

    """Discover a bounded Cargo crate/workspace once per source directory."""
    def _rust_project_context(
        file_path: str
    ) -> Optional[tuple[Path, Path, Path, dict[str, Path], Path]];

    static def _rust_current_module_parts(file_path: Path, source_root: Path) -> list[str];

    static def _rust_module_file_for_parts(
        source_root: Path, root_file: Path, parts: list[str]
    ) -> Optional[Path];

    """Is every name below *source_root* spelt on disk as in *candidate*?

        macOS and Windows find ``src/Glob.rs`` when only ``src/glob.rs`` exists,
        and the type ``Glob`` would then pass for the module ``glob`` (#984).
        """
    static def _rust_names_match_case(source_root: Path, candidate: Path) -> bool;

    """Resolve crate/self/super and local path dependencies to source files."""
    def _resolve_rust_module_file(module: str, file_path: str) -> Optional[str];

    """Resolve a PHP class through the nearest bounded Composer project."""
    def _resolve_php_composer_module(module: str, caller_dir: Path) -> Optional[str];

    """Return a safe Composer search boundary for *start*."""
    def _php_repository_boundary(start: Path) -> Optional[Path];

    """Find and parse the nearest composer.json without crossing *boundary*."""
    def _find_php_composer_psr4(start: Path, boundary: Path) -> _PhpPsr4Mappings;

    """Walk up from ``start`` to find a ``pubspec.yaml`` whose ``name:``
        matches ``pkg_name``. Returns the directory containing that pubspec,
        or None if no match is found. Result is cached per (start, pkg_name)
        pair so repeated lookups within one parse pass are cheap.
        """
    def _find_dart_pubspec_root(start: Path, pkg_name: str) -> Optional[Path];

    """Resolve associated/module Rust calls with alias provenance."""
    def _resolve_rust_scoped_call(
        call_name: str, file_path: str, import_map: dict[str, str], defined_names: set[str]
    ) -> Optional[str];

    """Resolve a bare call name to a qualified target, with fallback."""
    def _resolve_call_target(
        call_name: str,
        file_path: str,
        language: str,
        import_map: dict[str, str],
        defined_names: set[str],
    ) -> str;

    """Resolve an imported symbol to its defining qualified name when possible."""
    def _resolve_imported_symbol(
        symbol_name: str, module: str, file_path: str, language: str
    ) -> Optional[str];

    """Follow a package's re-exports to the file that defines *symbol_name*.

        ``from .tools import query_graph`` resolves to ``tools/__init__.py``,
        but the function lives in ``tools/query.py``, so qualifying the symbol
        against the package file produced ``tools/__init__.py::query_graph`` —
        a confident-looking target that matches no node. The package's own
        export map already knows where each name came from; reuse it. Returns
        *module_file* unchanged when the name is defined there, when the
        origin is outside the repository, or when the module cannot be read.
        """
    def _python_reexport_origin(module_file: str, symbol_name: str) -> str;

    """Resolve a JS/TS symbol through common re-export/barrel patterns."""
    def _resolve_exported_symbol(
        module_file: str, symbol_name: str, seen: Optional[set[tuple[str, str]]] = None
    ) -> Optional[str];

    """Create a qualified name: file_path::ClassName.name or file_path::name.

        The path component is normalized to POSIX separators so identities
        are stable across operating systems (#774). ``name`` and
        ``enclosing_class`` are never touched — PHP namespace identifiers
        legitimately contain backslashes.
        """
    def _qualify(name: str, file_path: str, enclosing_class: Optional[str]) -> str;

    """Return the parser identity for a node without changing display name."""
    def _node_qualified(`node: NodeInfo) -> str;

    static has _CUSTOM_NAME_LEAF_TYPES: any = (
        "word",
        "identifier",
        "name",
        "simple_identifier",
        "command_name",
        "key_brace",
        "type_identifier",
        "property_identifier",
        "constant",
    );

    static has _MAX_CUSTOM_NAME_DEPTH: any = 4;

    static has _MAX_CUSTOM_NAME_LEN: any = 256;

    """Return the first text-bearing leaf of a known name type within
        ``depth`` levels of ``node`` (preorder), or None."""
    def _custom_name_leaf(`node, depth: int) -> any;

    """Return the first descendant of ``node`` whose type == ``type_name``
        within ``depth`` levels (preorder), or None."""
    def _find_custom_descendant(`node, type_name: str, depth: int) -> any;

    """Strip wrapping braces/quotes/whitespace; reject empty, multi-line,
        or oversized text so a bad target never becomes a garbage name."""
    def _clean_custom_name(text: str) -> Optional[str];

    """Resolve a configured ``name_field`` target node to a clean name.

        Prefers a text-bearing leaf of a known name type; falls back to the
        target's own text (covers fieldless wrappers like Markdown ``inline``).
        """
    def _custom_leaf_name(`node) -> Optional[str];

    """Resolve a definition name for a config-driven custom language using
        the language's ordered ``name_field`` candidates.

        Two passes so grammar *fields* are always preferred over a broader
        *type* search: this avoids matching an unrelated same-typed node in a
        different field (e.g. LaTeX ``\\newcommand`` whose ``implementation``
        body contains a ``text`` node — the ``declaration`` field must win).
        Returns None when no candidate resolves (caller then applies the legacy
        ``name`` field fallback).
        """
    def _resolve_custom_name(`node, language: str) -> Optional[str];

    """Extract the name from a class/function definition node."""
    def _get_name(`node, language: str, kind: str) -> Optional[str];

    """Extract the receiver type from a Go method_declaration.

        For ``func (s *T) Foo() {...}`` returns ``"T"``. For ``func (T) Foo()``
        also returns ``"T"``. Generic receivers ``T[P]`` and ``*T[P]`` return
        ``"T"``. Returns None if no receiver is present. See: #190, #832
        """
    def _get_go_receiver_type(`node) -> Optional[str];

    """Return the variable name from a Go method receiver."""
    static def _get_go_receiver_name(`node) -> Optional[str];

    static has _GO_LEXICAL_SCOPE_TYPES: any = frozenset({
        "block",
        "communication_case",
        "default_case",
        "expression_case",
        "type_case",
    });

    static has _GO_DECLARATION_NAME_FIELDS: any = {
        "const_spec": "name",
        "type_alias": "name",
        "type_spec": "name",
        "var_spec": "name",
    };

    static has _GO_INIT_SCOPE_PARENTS: any = frozenset({
        "expression_switch_statement",
        "if_statement",
        "type_switch_statement",
    });

    static has _GO_PARAMETER_TYPES: any = frozenset({
        "parameter_declaration",
        "variadic_parameter_declaration",
    });

    """Return whether a grammar field declares ``name``."""
    static def _go_field_binds_name(`node, field: str, name: str) -> bool;

    """Return whether a function's parameters or named results bind ``name``."""
    class def _go_function_parameters_bind_name(`node, name: str) -> bool;

    """Build merged lexical-shadow intervals for one Go method."""
    def _go_receiver_binding_index(
        method, receiver_name: str
    ) -> tuple[str, tuple[int, ...], tuple[int, ...]];

    """Return whether a pre-indexed Go binding shadows the receiver."""
    static def _go_receiver_is_shadowed(
        `node, bindings: tuple[str, tuple[int, ...], tuple[int, ...]]
    ) -> bool;

    static def _cpp_scope_join(outer: Optional[str], inner: Optional[str]) -> Optional[str];

    """Return the dotted namespace path containing a C++ AST node."""
    def _cpp_lexical_namespace(`node) -> Optional[str];

    """Return containing C++ class names from outermost to innermost."""
    def _cpp_lexical_class_names(`node) -> list[str];

    """Return explicit scope, signature identity, and raw C++ parameters."""
    def _cpp_function_identity(
        `node, name: str, source: bytes
    ) -> tuple[Optional[str], str, Optional[str]];

    """Find the callable declarator through reference/pointer wrappers."""
    def _cpp_find_function_declarator(declarator) -> any;

    """Return whether a declaration names a function, not a function pointer."""
    def _cpp_is_callable_declaration(declarator) -> bool;

    """Limit callable declarations to file, namespace, and class scopes."""
    static def _cpp_declaration_has_callable_scope(declaration) -> bool;

    """Find the callable's qualified identifier outside its parameters."""
    def _cpp_find_qualified_identifier(declarator) -> any;

    """Return a C++ callable name without confusing it with its return type."""
    def _cpp_callable_name(declarator) -> Optional[str];

    """Find one declarator node kind while ignoring parameter declarations."""
    def _cpp_find_declarator_kind(declarator, kind: str) -> any;

    """Normalize one C++ parameter to its type-only identity fragment."""
    def _cpp_parameter_type(parameter, source: bytes) -> str;

    """Find the declared identifier while avoiding nested parameter types."""
    def _cpp_declarator_name(declarator) -> any;

    """Extract parameter list as a string."""
    def _get_params(`node, language: str, source: bytes) -> Optional[str];

    """Extract return type annotation if present."""
    def _get_return_type(`node, language: str, source: bytes) -> Optional[str];

    """Extract base classes / implemented interfaces."""
    def _get_bases(`node, language: str, source: bytes) -> list[str];

    """Every specifier of one Go import declaration, at its own line.

        Covers all eight forms: single, grouped, named (``alias "path"``),
        blank (``_ "path"``), dot (``. "path"``), vendored, internal and
        standard library. The alias, the blank and the dot are discarded --
        they change what the importing file may call the package, never
        which package is imported.

        The line comes from the ``import_spec``, not the enclosing
        ``import_declaration``: every spec in a grouped block used to be
        stamped with the line of the ``import (`` token.
        """
    static def _extract_go_import_specs(`node) -> list[_ImportSpec];

    """The literal value of a Ruby string node, or ``None``.

        ``None`` for anything that is not a plain literal -- an
        interpolated string, an escape, a ``File.join(...)`` call, a bare
        variable. A path a program builds at runtime is not a path this
        parser may guess at: ``require File.join(__dir__, "app", "helper")``
        used to become an edge to ``app``, the first quoted string in the
        call.
        """
    static def _ruby_string_literal(`node) -> Optional[str];

    """The file one Ruby ``call`` node loads, if it loads one at all.

        Dispatches on the call's METHOD, not on whether the node's text
        happens to contain the letters "require". The substring test made
        14% of jekyll's ruby import edges false positives, with targets
        like ``Missing --ssl_cert or --ssl_key. Both are required.`` from a
        ``raise``, and it never saw ``autoload``, which is how jekyll
        declares its entire internal module graph (49 statements).
        """
    def _extract_ruby_import_specs(`node) -> list[_ImportSpec];

    """Import statements as (module, line, form) triples.

        Most grammars give one form and one line per statement, so those
        come straight from :meth:`_extract_import`. Go and Ruby do not: a Go
        ``import ( ... )`` block holds many specifiers at many lines, and
        Ruby's ``require`` and ``require_relative`` resolve identical
        strings by different algorithms, so the keyword has to survive as
        far as the resolver.
        """
    def _extract_import_specs(
        `node, language: str, source: bytes, file_path: Optional[str] = None
    ) -> list[_ImportSpec];

    """Say when an import statement does not run as its file loads."""
    def _import_context(
        `node, language: str, source: bytes, file_path: Optional[str]
    ) -> Optional[str];

    """``TYPE_CHECKING`` wins: such an import never runs, even in a function."""
    static def _python_import_context(`node, source: bytes) -> Optional[str];

    """Whether *module* is only the route to siblings of the importing file.

        ``from . import sibling`` emits an edge to the package and one to the
        sibling. The file's own package is loaded before the file is, so the
        package edge is no dependency, unless a name is a symbol read from it:
        ``from . import app`` with ``app`` set in ``__init__.py`` really needs it.
        """
    def _python_names_parent_package(`node, module: str, file_path: Optional[str]) -> bool;

    """``import type X`` or ``import { type A, type B }``; a value makes it real.

        The second form is only dropped when the compiler drops unused imports.
        Under ``verbatimModuleSyntax`` it is emitted as ``import {} from "./b"``,
        which still runs ``b``.
        """
    def _js_import_is_type_only(`node, file_path: Optional[str]) -> bool;

    """Extract import targets as module/path strings."""
    def _extract_import(
        `node, language: str, source: bytes, file_path: Optional[str] = None
    ) -> list[str];

    """Extract the function/method name being called."""
    def _get_call_name(`node, language: str, source: bytes) -> Optional[str];

    static has _CUSTOM_CALLEE_FIELDS: any = ("function", "callee", "expr", "name");

    static has _MAX_CUSTOM_CALLEE_DESCENT: any = 32;

    """Generic callee extraction for config-driven custom languages.

        Tries common tree-sitter field names for the callee.  When the field
        child is itself an application node carrying the same field (curried
        calls, e.g. Haskell ``f x y`` = ``apply(apply(f, x), y)``), descend
        to the leaf callee.  Multi-line or oversized callee text (a lambda
        being invoked, for instance) is rejected rather than recorded as a
        garbage call target.
        """
    def _get_custom_call_name(`node) -> Optional[str];

    """Extract ``(base_name, component_name)`` for a JSX element.

        ``base_name`` is set for member-style elements such as
        ``<UI.MarkdownMsg />`` and ``None`` for plain component tags such as
        ``<MarkdownMsg />``.
        """
    def _get_jsx_component_reference(`node) -> Optional[tuple[Optional[str], str]];

    """Return the leftmost identifier for a nested member expression."""
    def _get_member_expression_root_name(`node) -> Optional[str];

    """Return True for JSX names that look like user components."""
    static def _looks_like_component_name(name: str) -> bool;

    static has _TEST_MODIFIER_SUFFIXES: any = frozenset({
        "only",
        "skip",
        "each",
        "todo",
        "concurrent",
        "failing",
    });

    """Return the base object name for member-expression calls like describe.only()."""
    def _get_base_call_name(`node, source: bytes) -> Optional[str];

    """Extract the function name from an R call node."""
    static def _r_call_func_name(call_node) -> Optional[str];

    """Extract the first string argument value from an R call node."""
    static def _r_first_string_arg(call_node) -> Optional[str];

    """Yield (name_str, value_node) pairs from an R call's arguments."""
    static def _r_iter_args(call_node) -> Generator[any, any, any];

    """Find a named argument's value node in an R call."""
    class def _r_find_named_arg(call_node, arg_name: str) -> any;

    """Handle R binary_operator nodes: name <- function(...) { ... }."""
    def _handle_r_binary_operator(
        `node,
        source: bytes,
        language: str,
        file_path: str,
        nodes: list[NodeInfo],
        edges: list[EdgeInfo],
        enclosing_class: Optional[str],
        enclosing_func: Optional[str],
        import_map: Optional[dict[str, str]],
        defined_names: Optional[set[str]],
    ) -> bool;

    """Handle R call nodes for imports and class definitions."""
    def _handle_r_call(
        `node,
        source: bytes,
        language: str,
        file_path: str,
        nodes: list[NodeInfo],
        edges: list[EdgeInfo],
        enclosing_class: Optional[str],
        enclosing_func: Optional[str],
        import_map: Optional[dict[str, str]],
        defined_names: Optional[set[str]],
    ) -> bool;

    """Handle setClass/setRefClass/setGeneric calls -> Class nodes."""
    def _handle_r_class_call(
        `node,
        source: bytes,
        language: str,
        file_path: str,
        nodes: list[NodeInfo],
        edges: list[EdgeInfo],
        enclosing_class: Optional[str],
        enclosing_func: Optional[str],
        import_map: Optional[dict[str, str]],
        defined_names: Optional[set[str]],
        assign_name: Optional[str] = None,
    ) -> bool;

    """Extract methods from a setRefClass methods = list(...) call."""
    def _extract_r_methods(
        list_call,
        source: bytes,
        language: str,
        file_path: str,
        nodes: list[NodeInfo],
        edges: list[EdgeInfo],
        class_name: str,
        import_map: Optional[dict[str, str]],
        defined_names: Optional[set[str]],
    ) -> None;
}
