"""Graph-powered refactoring operations.

Provides rename previews, dead code detection, refactoring suggestions,
and safe application of refactoring edits to source files. All file writes
go through a preview-then-apply workflow with expiry enforcement and path
traversal prevention.
"""

import importlib;

import builtins;

import operator;

import from __future__ { annotations }

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

"""Remove expired refactors from the pending dict.  Returns count removed."""
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

"""Match *name* as a whole identifier, never inside a longer one."""
def _ident_pattern(name: str) -> re.Pattern[str];

"""Decode *data* as UTF-8, returning ``(text, had_bom)``.

    ``None`` means the file is not UTF-8. Such a file is never rewritten:
    decoding it with replacement characters and writing it back would
    corrupt every byte that did not decode.
    """
def _decode_source(data: bytes) -> Optional[tuple[str, bool]];

"""One file as a rename preview sees it, read once.

    Lines are split on ``\\n`` only, so a CRLF line keeps its ``\\r`` and
    line numbers agree with the parsers. Columns are 0-based characters.
    """
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

    """Character column of a UTF-8 byte column on *lineno*."""
    def char_col(lineno: int, byte_col: int) -> int;

    def python_tree -> Optional[ast.Module];

    """``(line, col, is_attribute)`` for every NAME token spelling *name*.

        Comments and strings are separate tokens, so they never match.
        """
    def python_name_tokens(name: str) -> Optional[list[tuple[int, int, bool]]];

    """``(line, col, is_attribute)`` where *node* spells *name*, if it does."""
    def _python_name_at(`node: ast.AST, name: str) -> Optional[tuple[int, int, bool]];

    def _python_fstring_names(name: str) -> list[tuple[int, int, bool]];

    """Calls of *name*, keyed by the line their call expression starts on.

        The parser dates a call edge by that line, so a call chained over
        several lines (``(obj  # comment`` then ``.name())``) sits on the
        receiver's line while the name is on a later one.
        """
    def python_call_names(name: str) -> dict[int, list[tuple[int, int, bool]]];

    def __repr__ -> str;

    def __eq__(other: any) -> bool;

    def __hash__ -> int;
}

"""Files read, parsed and language-detected at most once per preview."""
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

    """Tree-sitter tree for *path*, or ``None`` without a grammar."""
    def tree(path: str) -> Any;

    def resolve_js_module(spec: str, from_file: str) -> Optional[str];

    def __repr__ -> str;

    def __eq__(other: any) -> bool;

    def __hash__ -> int;
}

with entry {
    _Occurrence = builtins.tuple[int, int, str, Optional[str]];
}

"""IMPORTS_FROM targets of *file_path*, keyed by the statement's line."""
def _import_targets_by_line(store: GraphStore, file_path: str) -> dict[int, set[str]];

"""Files with an IMPORTS_FROM edge into *module_file*."""
def _importer_files(store: GraphStore, module_file: str) -> list[str];

"""A Python scope, as far as one name is concerned."""
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

    def bind(target: bool = False) -> None;

    """Where a class body looks up a name it has not bound yet."""
    def outside_class -> _PyScope;

    def __repr__ -> str;

    def __eq__(other: any) -> bool;

    def __hash__ -> int;
}

"""Whether *target* is the file of the module spelled *module_path*."""
def _py_module_matches(target: str, module_path: str, exact: bool) -> bool;

"""The directory that holds the top package of *dotted*, from the
    files the graph resolved an import of it to (``/repo`` for
    ``pkg.util`` resolved to ``/repo/pkg/util.py``)."""
def _py_module_base(dotted: str, targets: set[str]) -> Optional[str];

"""``a.b.c`` for a Name/Attribute chain, else ``None``."""
def _dotted(expr: ast.expr) -> Optional[str];

"""Every place one Python module spells the symbol being renamed.

    Python resolves a name per scope, so this does too: an occurrence is
    renamed when it resolves to a scope whose binding of the name is the
    symbol itself -- its definition, or an import of it from a module that
    exports it. A parameter, a local variable or a class attribute that
    happens to share the name resolves elsewhere and is left alone.
    Comments and strings are not names at all, except the string entries of
    ``__all__``, which are renamed where the module's own binding is.
    """
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

    """Return the occurrences to rename and whether the module binds it.

        The second value says the module's own global name is renamed, so
        the module now exports the new name and its importers must follow.
        """
    def run(tree: ast.Module) -> tuple[list[_Occurrence], bool];

    """Whether ``dotted`` is a module that exports the symbol."""
    def _names_exporter(dotted: Optional[str]) -> bool;

    """The scope whose binding an occurrence in *scope* refers to."""
    def _owner(scope: _PyScope) -> _PyScope;

    def _use(scope: _PyScope, line: int, byte_col: int, site: str = "reference") -> None;

    """Record the first whole-word occurrence after a byte column."""
    def _use_after(scope: _PyScope, line: int, byte_col: int, prefix: str = "") -> None;

    def _def_name_col(
        `node: Union[ast.FunctionDef, ast.AsyncFunctionDef, ast.ClassDef]
    ) -> Optional[int];

    """Column of the name inside a one-line ``"name"`` literal."""
    def _string_entry_col(const: ast.Constant) -> Optional[int];

    """Remember ``__all__`` string entries spelling the name."""
    def _collect_all(stmt: ast.stmt) -> None;

    def _visit(`node: ast.AST, scope: _PyScope) -> None;

    """``mod = importlib.import_module("pkg.util")`` binds a module."""
    def _bind_import_module(`node: ast.Assign) -> None;

    def _visit_function(
        `node: Union[ast.FunctionDef, ast.AsyncFunctionDef], scope: _PyScope
    ) -> None;

    def _visit_class(`node: ast.ClassDef, scope: _PyScope) -> None;

    def _bind_definition(
        `node: Union[ast.FunctionDef, ast.AsyncFunctionDef, ast.ClassDef], scope: _PyScope
    ) -> None;

    def _visit_arguments(args: ast.arguments, scope: _PyScope) -> None;

    def _bind_arguments(args: ast.arguments, inner: _PyScope) -> None;

    def _visit_comprehension(
        `node: Union[ast.ListComp, ast.SetComp, ast.GeneratorExp, ast.DictComp], scope: _PyScope
    ) -> None;

    def _alias_name_col(alias: ast.alias) -> int;

    def _alias_asname_col(alias: ast.alias) -> tuple[int, int];

    def _visit_import(`node: ast.Import, scope: _PyScope) -> None;

    def _visit_import_from(`node: ast.ImportFrom, scope: _PyScope) -> None;

    def __repr__ -> str;

    def __eq__(other: any) -> bool;

    def __hash__ -> int;
}

"""The ``def``/``class`` named *name* at *line*, and where it lives.

    The place is ``"module"``, ``"function"`` (nested in a function) or
    ``"class"`` (a method or nested class, reached as an attribute).
    """
def _py_find_definition(tree: ast.Module, name: str, line: int) -> tuple[Optional[ast.AST], str];

"""Exact sites for a Python function or class reached by its name.

    Covers the defining module and, for a module-level symbol, every module
    that imports it -- directly, through a package that re-exports it, or
    through ``import module`` and attribute access -- and every module in
    *call_files* (those with a call edge to the bare name), where a call
    such as ``pkg.util.name()`` after ``import pkg``, or through a module
    bound by ``importlib``, reaches it without an import that names it.
    Returns ``None`` when the symbol is a method (reached as an attribute,
    so only the graph's call sites can find it) or the source cannot be
    parsed; the caller then falls back to the graph.
    """
def _python_rename_sites(
    store: GraphStore, `node: GraphNode, sources: _Sources, call_files: set[str]
) -> Optional[dict[str, list[_Occurrence]]];

def _ts_text(`node: Any) -> str;

def _ts_same(a: Any, b: Any) -> bool;

def _ts_string_value(`node: Any) -> str;

"""The specifier string of ``import('./m')`` or ``require('./m')``."""
def _js_module_call_spec(`node: Any) -> Any;

def _js_is_declaration(leaf: Any) -> bool;

"""The nearest strict ancestor of one of *kinds*, else the root."""
def _ts_ancestor(`node: Any, kinds: frozenset[str]) -> Any;

"""The syntax node whose extent a JS/TS declaration is visible in."""
def _js_declaration_scope(leaf: Any) -> Any;

"""Import, export and reference sites of one name in one JS/TS module.

    Each declaration of the name is visible in a syntax range (a function,
    a block, the module). A plain occurrence belongs to the innermost range
    containing it, so a parameter or local that reuses the name shadows the
    symbol inside its own function and nowhere else.
    """
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

    def declare(`node: Any, target: bool) -> None;

    def statement_targets(statement: Any) -> set[str];

    def run(`root: Any) -> None;

    """Whether the innermost declaration around a range is the symbol.

        ``None`` when no declaration of the name is in scope there.
        """
    def resolves_to_symbol(start: int, end: int) -> Optional[bool];

    has bound: bool {
        getter {
            return `any(target for (_s, _e, target) in self.scopes);
        }
    }

    """The scan resolved every plain occurrence, so call sites add nothing."""
    has authoritative: bool {
        getter {
            return self.bound;
        }
    }

    """An ES module export of the symbol under its own name."""
    has exports_by_name: bool {
        getter {
            return self.reexports or self.local_export or self.exported_definition;
        }
    }

    """Importers of this module name the symbol as the rename changes it.

        A CommonJS home keeps its key (``module.exports = { name: new }``),
        so its importers keep the old name; any other home is taken to
        export the name, as an import of it would be an error otherwise.
        """
    has exports: bool {
        getter {
            return self.exports_by_name or self.def_lines is not None and not self.commonjs;
        }
    }

    def visit_name(leaf: Any) -> None;

    """Bind *ident* to a module namespace within *scope*.

        A module that is not (yet) known to export the symbol is a barrel
        candidate: if it turns out to re-export it, this file is scanned
        again and ``ident.name`` is renamed then.
        """
    def namespace(ident: Any, targets: set[str], scope: Any) -> None;

    """Files a module specifier (a string node) resolves to."""
    def module_targets(spec: Any) -> set[str];

    """``const ns = await import('./m')`` or ``const ns = require('./m')``."""
    def visit_module_value(declarator: Any) -> None;

    """``import('./m').then((ns) => ns.name())``."""
    def visit_import_then(call: Any) -> None;

    def visit_import(statement: Any) -> None;

    def visit_import_specifier(spec: Any, targets: set[str], from_exporter: bool) -> None;

    def visit_reexport(statement: Any) -> None;

    def __repr__ -> str;

    def __eq__(other: any) -> bool;

    def __hash__ -> int;
}

"""JS/TS files that spell ``export { name } from``.

    A re-export carries no graph edge, so a barrel that no file imports
    the name from by name (a package's public ``index.ts``) is found only
    by reading the files.
    """
def _js_reexport_files(store: GraphStore, sources: _Sources, name: str, home: str) -> list[str];

"""Exact sites for a top-level JS/TS symbol.

    Follows named imports (``import { name }``, ``import { name as x }``),
    namespace objects (``import * as ns``, ``import ns = require()``,
    ``const ns = require()``, ``await import()`` and ``import().then``,
    then ``ns.name``), local export lists and re-exporting barrels
    (``export { name } from``, ``export * from``). Re-exports carry no
    import edge, so barrels are found from the consumers that import
    through them and, for an exported symbol, by reading the files that
    spell ``export { name } from``. *graph_files* are the files with a call
    edge to the name; they are scanned too, so a namespace object there is
    followed.
    """
def _js_rename_sites(
    store: GraphStore, `node: GraphNode, new_name: str, sources: _Sources, graph_files: set[str]
) -> Optional[dict[str, _JsScan]];

def _ts_is_name_leaf(kind: str) -> bool;

"""The row where the call that *leaf* names as its callee starts.

    ``None`` when *leaf* is not a callee: an argument, or a name in a
    statement that is not a call.
    """
def _ts_call_row(leaf: Any) -> Optional[int];

"""Whether bytes ``start:end`` of *row* lie in a comment or a string.

    Code embedded in a string (``"$(name)"`` in a shell script, ``"#{name}"``)
    is code: the walk stops at the substitution or interpolation.
    """
def _ts_in_comment_or_string(tree: Any, row: int, start: int, end: int) -> bool;

"""The name as a code token on each of *lines* (line -> site).

    Python files are tokenized and other files read through their
    Tree-sitter grammar, so a comment, a string or a longer identifier
    never matches. A call the parser dates by the line its expression
    starts on (a chain split over several lines) is found where its name
    is. *mode* ``"attribute"`` keeps only ``x.name`` (Python) and
    ``"bare"`` only the plain name. In a file that is not Python, a line
    where no token spells the name falls back to the first whole-word
    match outside comments and strings, so a grammar that hides embedded
    code (a Vue template, a notebook) still gets its edit.
    """
def _lexical_sites(
    sources: _Sources,
    source: _Source,
    lines: dict[int, str],
    name: str,
    new_name: str,
    mode: str = "any",
) -> list[_Occurrence];

"""The definition's name as a code token, searching past decorators."""
def _locate_definition(
    sources: _Sources, source: _Source, `node: GraphNode, new_name: str
) -> Optional[_Occurrence];

"""The node *old_name* names exactly, or ``None``.

    A qualified name (absolute, or ``path/to/file.py::Symbol`` relative to
    the repository) picks one node. Otherwise the name must equal a symbol
    (``helper``, ``Widget.render``) or, failing that, a node's bare name;
    of several such nodes the first by file and line is taken, and the
    preview's ``qualified_name`` says which. There is no fuzzy fallback:
    the edits rename the node's own name, so asking for ``helper`` must
    never rename ``helper_count``.
    """
def _rename_target(store: GraphStore, old_name: str) -> Optional[GraphNode];

"""Build a rename edit list for *old_name* -> *new_name*.

    *old_name* is a symbol name, a dotted symbol (``Widget.render``) or a
    qualified name (``pkg/util.py::helper``). Every edit names one exact
    place: a line and a 1-based ``column`` where the old name starts as a
    code token, plus the ``site`` it is (``definition``, ``call``,
    ``reference``, ``import``, ``export``, ``attribute`` or ``__all__``).
    Import statements are covered: ``from module import name``, its
    multi-line and aliased forms, relative imports, package re-exports with
    their ``__all__`` entries, ``import module`` with ``module.name``, and
    the JS/TS ``import { name }`` family. An alias keeps its own name, and
    a comment, a string or an unrelated name that contains the old one is
    never an edit. An edit carries no ``column`` only when its file could
    not be read; applying it then takes the first whole-word match.

    Returns:
        The preview dict, stored for ``apply_refactor``; ``None`` if no
        symbol has that name or its definition is no longer where the graph
        says (the graph is stale).
    """
def rename_preview(store: GraphStore, old_name: str, new_name: str) -> Optional[dict[str, Any]];

"""Every edit renaming *node*, sorted; ``None`` if its definition moved."""
def _rename_edits(
    store: GraphStore, `node: GraphNode, new_name: str
) -> Optional[list[dict[str, Any]]];

"""Check if a node looks like an entry point by name or decorator.

    Unlike ``flows.detect_entry_points()`` which treats ALL uncalled functions
    as entry points, this checks only for conventional name patterns and
    framework decorators -- the indicators that a function is *intentionally*
    an entry point rather than simply unreferenced dead code.
    """
def _is_entry_point(`node: Any) -> bool;

with entry {
    _MIN_PKG_SEGMENT_LEN = 4;
}

"""Return directory segments long enough to serve as package-name anchors."""
@functools.lru_cache(maxsize=4096)
def _path_segments(file_path: str) -> tuple[str, ...];

with entry {
    _TYPE_IDENT_RE = re.compile("[A-Z][A-Za-z0-9_]*");
}

"""Collect class names that appear in function params or return types."""
def _collect_type_referenced_names(store: GraphStore) -> set[str];

with entry {
    _ASCII_FOLD = str.maketrans("ABCDEFGHIJKLMNOPQRSTUVWXYZ", "abcdefghijklmnopqrstuvwxyz");
}

"""Fold case the way SQLite ``LIKE`` does: ASCII letters only.

    ``str.lower`` also folds other scripts, which merges distinct names and,
    because a final sigma lowers differently from an inner one, can make
    ``"ΟΣ"`` miss itself inside ``"ΟΣ.run"``.
    """
def _ascii_fold(text: str) -> str;

"""Map each C# type's leaf name to the parent names its members use."""
def _csharp_member_scopes(conn: Any) -> dict[str, set[str]];

"""Find functions/classes with no callers, no test refs, no importers, and no references.

    Entry points (functions matching framework decorators or conventional name
    patterns like ``main``, ``test_*``, ``handle_*``) are excluded.

    .. note::

        **Caveats — dynamic dispatch patterns.**  Static analysis cannot track
        all runtime-determined call patterns.  Functions registered via fully
        dynamic keys (``map[computedKey()] = fn``), ``Reflect.apply``, or
        runtime ``require()`` may still appear as dead code.  Treat results as
        hints, especially for TypeScript projects that use map-based dispatch,
        plugin registries, or dynamic requires.

    Args:
        store: The GraphStore instance.
        kind: Optional filter (e.g. ``"Function"`` or ``"Class"``).
        file_pattern: Optional file-path substring filter.
        root: Optional repo root path for computing ``relative_path``.

    Returns:
        List of dead-code dicts with name, qualified_name, kind, file_path,
        relative_path, line, and language fields.
    """
def find_dead_code(
    store: GraphStore,
    kind: Optional[str] = None,
    file_pattern: Optional[str] = None,
    `root: Optional[Union[str, Path]] = None,
) -> list[dict[str, Any]];

"""Produce community-driven refactoring suggestions.

    Currently two categories:
    - **move**: Functions in Community A only called by Community B.
    - **remove**: Dead code (no callers, tests, or importers and not entry points).

    Returns:
        List of suggestion dicts with type, description, symbols, rationale.
    """
def suggest_refactorings(store: GraphStore) -> list[dict[str, Any]];

"""Apply one file's rename edits; return ``(new_text, applied, skipped)``.

    An edit with a ``column`` replaces the old name at exactly that place and
    is skipped if the file no longer has it there. An edit without one (a
    preview of a file that could not be read) takes the first whole-word
    match on its line that no other edit claimed. Nothing is ever replaced
    outside the edit's own line, and never inside a longer identifier.
    Every edit is located against the original text and the replacements
    are made right to left, so edits on one line cannot shift each other.
    """
def _apply_file_edits(text: str, file_edits: list[dict[str, Any]]) -> tuple[str, int, int];

"""Apply a previously previewed refactoring to source files.

    Validates the refactor_id, checks expiry, ensures all edit paths are
    within the repo root, then performs exact string replacements on the
    target files.

    Args:
        refactor_id: ID from a prior ``rename_preview`` call.
        repo_root: Validated repository root path.
        dry_run: If True, compute the would-be changes and return a
            unified-diff representation per affected file, but do NOT
            write anything to disk. The ``refactor_id`` is preserved so
            the same preview can be committed afterwards via a second
            call without ``dry_run``. See: #176

    Returns:
        Status dict with applied count and modified files. When
        ``dry_run=True`` the dict additionally contains:

        - ``dry_run``: ``True``
        - ``would_modify``: list of file paths that would be changed
        - ``diffs``: map of file path → unified diff string showing the
          proposed change
    """
def apply_refactor(refactor_id: str, repo_root: Path, dry_run: bool = False) -> dict[str, Any];
