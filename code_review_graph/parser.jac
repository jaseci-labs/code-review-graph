import from __future__ { annotations }

import builtins, operator, ast, hashlib, html, importlib, importlib.util, json, logging, math, os, re, subprocess, sys, threading;

import from bisect { bisect_left, bisect_right }

import from collections { deque }

import from collections.abc { Iterator }

import from dataclasses { dataclass, field }

import from functools { lru_cache }

import from pathlib { Path, PurePath }

import from typing { Any, NamedTuple, Optional }

import tomllib, yaml as _yaml;

import from yaml { MappingNode as _YamlMapping }

import from yaml { ScalarNode as _YamlScalar }

import from yaml { SequenceNode as _YamlSequence }

import from yaml.events { AliasEvent as _YamlAliasEvent }

class CellInfo(NamedTuple) {
    has cell_index: int;

    has language: str;

    has source: str;
}

glob _SQL_TABLE_RE: any = re.compile(
    "(?:FROM|JOIN|INTO|CREATE\\s+(?:OR\\s+REPLACE\\s+)?(?:TABLE|VIEW)(?:\\s+IF\\s+NOT\\s+EXISTS)?|INSERT\\s+OVERWRITE)\\s+((?:`[^`]+`|\\w+)(?:\\.(?:`[^`]+`|\\w+))*)",
    re.IGNORECASE,
);

glob _DBT_REF_RE: any = re.compile(
    "\\{\\{-?\\s*(ref|source)\\s*\\(\\s*['\\\"]([^'\\\"]+)['\\\"](?:\\s*,\\s*['\\\"]([^'\\\"]+)['\\\"])?\\s*\\)",
);

glob _PYTHON_STAR_CACHE_MAX: any = 15000;

glob _PYTHON_STAR_EXPORT_CACHE: dict[tuple[str, int, int], dict[str, str]] = {};

glob _PYTHON_STAR_EXPORT_CACHE_LOCK: any = threading.RLock();

glob _PYTHON_MODULE_ALIAS_CACHE: dict[tuple[str, int, int], Optional[str]] = {};

glob _PYTHON_MODULE_ALIAS_CACHE_LOCK: any = threading.Lock();

glob _PYTHON_RETURN_ANNOTATION_CACHE: dict[tuple[str, int, int], dict[str, str]] = {};

glob _PYTHON_RETURN_ANNOTATION_CACHE_LOCK: any = threading.RLock();

glob _PYTHON_PROPERTY_RETURN_ANNOTATION_CACHE: dict[tuple[str, int, int], dict[tuple[str, str], str]] = {};

glob _PYTHON_MODULE_CLASS_IDENTITY_CACHE: dict[tuple[str, int, int], dict[str, tuple[str, str]]] = {};

glob _PYTHON_MODULE_CLASS_IDENTITY_CACHE_LOCK: any = threading.RLock();

glob _PY_EXPR_RECEIVER_KEY: any = "\x00expr:";

glob _PY_CLASS_IDENTITY_PREFIX: any = "\x00python-class\x00";

glob _PY_TUPLE_ANNOTATION_NAMES: any = frozenset({"Tuple", "tuple"});

glob _PY_TARGET_PATTERN_TYPES: any = frozenset({
    "list",
    "list_pattern",
    "pattern_list",
    "tuple",
    "tuple_pattern",
});

glob _PY_SPLAT_PATTERN_TYPES: any = frozenset({"list_splat", "list_splat_pattern"});

def _python_qualified_class_identity(file_path: str, class_name: str) -> str {
    return f"{_PY_CLASS_IDENTITY_PREFIX}{file_path}\x00{class_name}";
}

def _python_split_class_identity(identity: str) -> Optional[tuple[str, str]] {
    if not identity.startswith(_PY_CLASS_IDENTITY_PREFIX) {
        return None;
    }
    file_path: any;
    separator: any;
    class_name: any;
    (file_path, separator, class_name) = identity[len(_PY_CLASS_IDENTITY_PREFIX):].partition(
        "\x00"
    ) as any;
    if not separator or not file_path or not class_name {
        return None;
    }
    return (file_path, class_name);
}

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

class _NodeGroup(NamedTuple) {
    has children: list;
}

@lru_cache(maxsize=512)
def _read_cargo_manifest(manifest_path: str, _mtime_ns: int, _size: int) -> dict[str, Any] {
    try {
        parsed: any = tomllib.loads(
            Path(manifest_path).read_text(encoding="utf-8", errors="replace")
        );
    } except (OSError, tomllib.TOMLDecodeError) {
        return {};
    }
    return parsed if isinstance(parsed, `dict) else {};
}

def _load_cargo_manifest(path: Path) -> dict[str, Any] {
    try {
        stat: any = path.stat();
        resolved: any = path.resolve();
    } except (OSError, RuntimeError, ValueError) {
        return {};
    }
    return _read_cargo_manifest(`str(resolved), stat.st_mtime_ns, stat.st_size);
}

class _PythonScopeBindingVisitor(ast.NodeVisitor) {
    def init {
        self.names = set[any]();
    }

    def visit_Name(`node: ast.Name) {
        if isinstance(`node.ctx, (ast.Store, ast.Del)) {
            self.names.add(`node.id);
        }
    }

    def visit_FunctionDef(`node: ast.FunctionDef) {
        self.names.add(`node.name);
    }

    def visit_AsyncFunctionDef(`node: ast.AsyncFunctionDef) {
        self.names.add(`node.name);
    }

    def visit_ClassDef(`node: ast.ClassDef) {
        self.names.add(`node.name);
    }

    def visit_Lambda(`node: ast.Lambda) {
        return;
    }

    def visit_Import(`node: ast.Import) {
        for alias in `node.names {
            self.names.add(alias.asname or alias.name.split(".", 1)[0]);
        }
    }

    def visit_ImportFrom(`node: ast.ImportFrom) {
        for alias in `node.names {
            if alias.name != "*" {
                self.names.add(alias.asname or alias.name);
            }
        }
    }

    def visit_Global(`node: ast.Global) {
        self.names.update(`node.names);
    }
}

def _python_function_scope_bindings(
    source: bytes
) -> dict[tuple[int, int], tuple[frozenset[str], frozenset[str]]] {
    try {
        tree: any = ast.parse(source.decode("utf-8"));
    } except (SyntaxError, UnicodeDecodeError, ValueError) {
        return {};
    }
    scopes: dict[tuple[int, int], tuple[frozenset[str], frozenset[str]]] = {};
    for `node in ast.walk(tree) {
        if not isinstance(`node, (ast.FunctionDef, ast.AsyncFunctionDef)) {
            continue;
        }
        arguments: any = `node.args;
        parameter_names: any = {
            argument.arg
            for argument in (*arguments.posonlyargs, *arguments.args, *arguments.kwonlyargs)
        };
        if arguments.vararg is not None {
            parameter_names.add(arguments.vararg.arg);
        }
        if arguments.kwarg is not None {
            parameter_names.add(arguments.kwarg.arg);
        }
        bindings: any = _PythonScopeBindingVisitor();
        for statement in `node.body {
            bindings.visit(statement);
        }
        bindings.names.update(parameter_names);
        scopes[`node.lineno, `node.col_offset] = (
            frozenset(parameter_names),
            frozenset(bindings.names),
        );
    }
    return scopes;
}

def _python_type_checking_aliases(tree: ast.Module) -> tuple[frozenset[str], frozenset[str]] {
    alias: any;
    has_typing_import: any = False;
    statement: any;
    for statement in tree.body {
        if isinstance(statement, ast.Import) {
            if `any(operator.eq(alias.name, "typing") for alias in statement.names) {
                has_typing_import = True;
                break;
            }
        } elif isinstance(statement, ast.ImportFrom) and statement.module == "typing" {
            if `any(operator.eq(alias.name, "TYPE_CHECKING") for alias in statement.names) {
                has_typing_import = True;
                break;
            }
        }
    }
    if not has_typing_import {
        return (frozenset(), frozenset());
    }

    names: set[str] = set[any]();
    modules: set[str] = set[any]();
    shadowed: set[str] = set[any]();
    for statement in tree.body {
        if isinstance(statement, ast.Import) {
            for alias in statement.names {
                if alias.name == "typing" {
                    modules.add(alias.asname or "typing");
                } else {
                    shadowed.add(alias.asname or alias.name.split(".", 1)[0]);
                }
            }
        } elif isinstance(statement, ast.ImportFrom) and statement.module == "typing" {
            for alias in statement.names {
                if alias.name == "TYPE_CHECKING" {
                    names.add(alias.asname or alias.name);
                } elif alias.name != "*" {
                    shadowed.add(alias.asname or alias.name);
                }
            }
        } else {
            bindings: any = _PythonScopeBindingVisitor();
            bindings.visit(statement);
            shadowed.update(bindings.names);
        }
    }
    return (frozenset(names - shadowed), frozenset(modules - shadowed));
}

glob type_checking_names_default_: any = frozenset();

glob typing_modules_default_: any = frozenset();

def _python_static_truth(
    `node: ast.expr,
    type_checking_names: frozenset[str] = type_checking_names_default_,
    typing_modules: frozenset[str] = typing_modules_default_,
) -> Optional[bool] {
    if isinstance(`node, ast.Constant) and isinstance(`node.value, (`bool, `int)) {
        return `bool(`node.value);
    }
    if isinstance(`node, ast.Name) and `node.id in type_checking_names {
        return False;
    }
    if isinstance(`node, ast.Attribute)
        and `node.attr == "TYPE_CHECKING"
        and isinstance(`node.value, ast.Name)
        and `node.value.id in typing_modules
    {
        return False;
    }
    if isinstance(`node, ast.UnaryOp) and isinstance(`node.op, ast.Not) {
        value: any = _python_static_truth(`node.operand, type_checking_names, typing_modules);
        return None if value is None else not value;
    }
    if isinstance(`node, ast.BoolOp) {
        values: any = [
            _python_static_truth(value, type_checking_names, typing_modules)
            for value in `node.values
        ];
        if isinstance(`node.op, ast.And) {
            if False in values {
                return False;
            }
            return True if all(value is True for value in values) else None;
        }
        if isinstance(`node.op, ast.Or) {
            if True in values {
                return True;
            }
            return False if all(value is False for value in values) else None;
        }
    }
    return None;
}

glob _TRY_STMT_TYPES: tuple[Any, ...] = (ast.Try, ast.TryStar)
    if hasattr(ast, "TryStar")
    else (ast.Try,);

glob _MATCH_STMT_TYPES: tuple[Any, ...] = (ast.Match,) if hasattr(ast, "Match") else ();

class _PythonUnreachableCallVisitor(ast.NodeVisitor) {
    def init(type_checking_names: frozenset[str], typing_modules: frozenset[str]) {
        self._dead = False;
        self.positions = set[any]();
        self._type_checking_names = type_checking_names;
        self._typing_modules = typing_modules;
    }

    def visit_Module(`node: ast.Module) {
        self._visit_statements(`node.body, dead=False);
    }

    def visit_Call(`node: ast.Call) {
        if self._dead {
            self.positions.add((`node.lineno, `node.col_offset));
        }
        self.generic_visit(`node);
    }

    def visit_Attribute(`node: ast.Attribute) {
        if self._dead {
            self.positions.add((`node.lineno, `node.col_offset));
        }
        self.generic_visit(`node);
    }

    def visit_If(`node: ast.If) {
        if self._dead {
            self.visit(`node.test);
        }
        truth: any = _python_static_truth(
            `node.test, self._type_checking_names, self._typing_modules
        );
        self._visit_statements(`node.body, dead=truth is False);
        self._visit_statements(`node.orelse, dead=truth is True);
    }

    def visit_FunctionDef(`node: ast.FunctionDef) {
        self._visit_function(`node);
    }

    def visit_AsyncFunctionDef(`node: ast.AsyncFunctionDef) {
        self._visit_function(`node);
    }

    def visit_ClassDef(`node: ast.ClassDef) {
        if self._dead {
            for decorator in `node.decorator_list {
                self.visit(decorator);
            }
            for base in `node.bases {
                self.visit(base);
            }
            for keyword in `node.keywords {
                self.visit(keyword.value);
            }
        }

        outer_names: any = self._type_checking_names;
        outer_modules: any = self._typing_modules;
        if outer_names or outer_modules {
            bindings: any = _PythonScopeBindingVisitor();
            for statement in `node.body {
                bindings.visit(statement);
            }
            self._type_checking_names = outer_names - bindings.names;
            self._typing_modules = outer_modules - bindings.names;
        }
        self._visit_statements(`node.body, dead=False);
        self._type_checking_names = outer_names;
        self._typing_modules = outer_modules;
    }

    def _visit_function(`node: ast.FunctionDef | ast.AsyncFunctionDef) {
        if self._dead {
            for decorator in `node.decorator_list {
                self.visit(decorator);
            }
            for `default in (*`node.args.defaults, *`node.args.kw_defaults) {
                if `default is not None {
                    self.visit(`default);
                }
            }
            all_args: any = (*`node.args.posonlyargs, *`node.args.args, *`node.args.kwonlyargs);
            for argument in all_args {
                if argument.annotation is not None {
                    self.visit(argument.annotation);
                }
            }
            for optional_argument in (`node.args.vararg, `node.args.kwarg) {
                if optional_argument is not None and optional_argument.annotation is not None {
                    self.visit(optional_argument.annotation);
                }
            }
            if `node.returns is not None {
                self.visit(`node.returns);
            }
        } else {
            all_args = (*`node.args.posonlyargs, *`node.args.args, *`node.args.kwonlyargs);
        }

        outer_names: any = self._type_checking_names;
        outer_modules: any = self._typing_modules;
        if outer_names or outer_modules {
            bindings: any = _PythonScopeBindingVisitor();
            for statement in `node.body {
                bindings.visit(statement);
            }
            bindings.names.update(argument.arg for argument in all_args);
            bindings.names.update(
                argument.arg
                for argument in (`node.args.vararg, `node.args.kwarg)
                if argument is not None,
            );
            self._type_checking_names = outer_names - bindings.names;
            self._typing_modules = outer_modules - bindings.names;
        }
        self._visit_statements(`node.body, dead=False);
        self._type_checking_names = outer_names;
        self._typing_modules = outer_modules;
    }

    def _visit_statements(statements: list[ast.stmt], *, dead: bool) {
        outer_dead: any = self._dead;
        is_dead: any = outer_dead or dead;
        self._dead = is_dead;
        if is_dead {
            statement: any;
            for statement in statements {
                self.visit(statement);
            }
        } else {
            for statement in statements {
                if isinstance(
                    statement, (ast.If, ast.FunctionDef, ast.AsyncFunctionDef, ast.ClassDef)
                ) {
                    self.visit(statement);
                } elif isinstance(statement, (ast.For, ast.AsyncFor, ast.While)) {
                    self._visit_statements(statement.body, dead=False);
                    if statement.orelse {
                        self._visit_statements(statement.orelse, dead=False);
                    }
                } elif isinstance(statement, (ast.With, ast.AsyncWith)) {
                    self._visit_statements(statement.body, dead=False);
                } elif isinstance(statement, _TRY_STMT_TYPES) {
                    try_body: any = getattr(statement, "body", None);
                    if try_body {
                        self._visit_statements(try_body, dead=False);
                    }
                    for handler in getattr(statement, "handlers", ()) {
                        handler_body: any = getattr(handler, "body", None);
                        if handler_body {
                            self._visit_statements(handler_body, dead=False);
                        }
                    }
                    try_orelse: any = getattr(statement, "orelse", None);
                    if try_orelse {
                        self._visit_statements(try_orelse, dead=False);
                    }
                    try_finalbody: any = getattr(statement, "finalbody", None);
                    if try_finalbody {
                        self._visit_statements(try_finalbody, dead=False);
                    }
                } elif _MATCH_STMT_TYPES and isinstance(statement, _MATCH_STMT_TYPES) {
                    for `case in getattr(statement, "cases", ()) {
                        case_body: any = getattr(`case, "body", None);
                        if case_body {
                            self._visit_statements(case_body, dead=False);
                        }
                    }
                }
            }
        }
        self._dead = outer_dead;
    }
}

@lru_cache(maxsize=128)
def _python_unreachable_call_positions(source: bytes) -> frozenset[tuple[int, int]] {
    try {
        tree: any = ast.parse(source.decode("utf-8"));
    } except (SyntaxError, UnicodeDecodeError, ValueError) {
        return frozenset();
    }
    type_checking_names: any;
    typing_modules: any;
    (type_checking_names, typing_modules) = _python_type_checking_aliases(tree) as any;
    `visitor: any = _PythonUnreachableCallVisitor(type_checking_names, typing_modules);
    `visitor.visit(tree);
    return frozenset(`visitor.positions);
}

class _PythonUnreachableImportVisitor(_PythonUnreachableCallVisitor) {
    def visit_Call(`node: ast.Call) {
        self.generic_visit(`node);
    }

    def visit_Attribute(`node: ast.Attribute) {
        self.generic_visit(`node);
    }

    def visit_Import(`node: ast.Import) {
        if self._dead {
            self.positions.add((`node.lineno, `node.col_offset));
        }
    }

    def visit_ImportFrom(`node: ast.ImportFrom) {
        if self._dead {
            self.positions.add((`node.lineno, `node.col_offset));
        }
    }
}

@lru_cache(maxsize=128)
def _python_unreachable_import_positions(source: bytes) -> frozenset[tuple[int, int]] {
    try {
        tree: any = ast.parse(source.decode("utf-8"));
    } except (SyntaxError, UnicodeDecodeError, ValueError) {
        return frozenset();
    }
    type_checking_names: any;
    typing_modules: any;
    (type_checking_names, typing_modules) = _python_type_checking_aliases(tree) as any;
    `visitor: any = _PythonUnreachableImportVisitor(
        type_checking_names | {"TYPE_CHECKING"}, typing_modules
    );
    `visitor.visit(tree);
    return frozenset(`visitor.positions);
}

def _node_is_in_child(`node, child_node) -> bool {
    start_byte: any;
    end_byte: any;
    (start_byte, end_byte) = (child_node.start_byte, child_node.end_byte);
    cursor: any = `node;
    while cursor is not None {
        if cursor.start_byte == start_byte and cursor.end_byte == end_byte {
            return True;
        }
        cursor = cursor.parent;
    }
    return False;
}

def _is_statically_false_condition(cond) -> bool {
    if cond.type == "parenthesized_expression" {
        inner: any = cond.named_children;
        return _is_statically_false_condition(inner[0]) if inner else False;
    }
    if cond.type == "false" {
        return True;
    }
    if cond.type == "number" and cond.text == b"0" {
        return True;
    }
    return False;
}

def _is_static_dead_guard_child(parent, child) -> bool {
    if parent.type == "if_statement" {
        condition: any = parent.child_by_field_name("condition");
        consequence: any = parent.child_by_field_name("consequence");
        return condition is not None
            and consequence is not None
            and _is_statically_false_condition(condition)
            and operator.eq(child.start_byte, consequence.start_byte)
            and operator.eq(child.end_byte, consequence.end_byte);
    }

    if parent.type in ("preproc_if", "preproc_elif") {
        condition = parent.child_by_field_name("condition");
        if condition is None or condition.type != "number_literal" or condition.text != b"0" {
            return False;
        }
        alternative: any = parent.child_by_field_name("alternative");
        return not (
            alternative is not None
            and child.start_byte == alternative.start_byte
            and child.end_byte == alternative.end_byte
        );
    }

    return False;
}

def _is_in_static_dead_guard(`node) -> bool {
    child: any = `node;
    parent: any = child.parent;
    while parent is not None {
        if _is_static_dead_guard_child(parent, child) {
            return True;
        }
        child = parent;
        parent = parent.parent;
    }
    return False;
}

def _is_in_rust_dead_guard(`node) -> bool {
    cursor: any = `node.parent;
    while cursor is not None {
        if cursor.type == "impl_item" {
            return False;
        }
        if cursor.type == "if_expression" {
            condition: any = cursor.child_by_field_name("condition");
            consequence: any = cursor.child_by_field_name("consequence");
            while condition is not None and condition.type == "parenthesized_expression" {
                condition = next((child for child in condition.children if child.is_named), None);
            }
            if condition is not None
                and consequence is not None
                and condition.type == "boolean_literal"
                and condition.text == b"false"
                and _node_is_in_child(`node, consequence)
            {
                return True;
            }
        }
        cursor = cursor.parent;
    }
    return False;
}

glob _SQL_KEYWORDS: frozenset[str] = frozenset(
    ("SELECT WHERE GROUP ORDER HAVING LIMIT OFFSET UNION INTERSECT EXCEPT AS ON USING SET VALUES "
        "DEFAULT NULL TRUE FALSE INNER OUTER LEFT RIGHT FULL CROSS NATURAL LATERAL RECURSIVE ONLY "
        "WITH IF NOT EXISTS").split(),
);

glob logger: any = logging.getLogger(__name__);

glob _DEFAULT_PARSER_LOAD_TIMEOUT_SECONDS: any = 5.0;

glob _PARSER_PROBE_RESULTS: dict[str, bool] = {};

glob _PARSER_PROBE_FAILURE_DETAILS: dict[str, str] = {};

glob _PARSER_PROBE_LOCK: any = threading.Lock();

glob _PARSER_PROBE_GRAMMAR_LOCKS: dict[str, threading.Lock] = {};

glob _EXPECTED_PARSER_LOAD_ERRORS: any = (ImportError, LookupError, OSError, ValueError);

def _parser_load_timeout_seconds -> float {
    raw: any = os.environ.get(
        "CRG_PARSER_LOAD_TIMEOUT_SECONDS", `str(_DEFAULT_PARSER_LOAD_TIMEOUT_SECONDS)
    );
    try {
        timeout: any = `float(raw);
    } except ValueError {
        timeout = _DEFAULT_PARSER_LOAD_TIMEOUT_SECONDS;
    }
    if not math.isfinite(timeout) or timeout <= 0 {
        timeout = _DEFAULT_PARSER_LOAD_TIMEOUT_SECONDS;
    }
    return timeout;
}

def _parser_probe_env -> dict[str, str] {
    env: any = os.environ.copy();
    try {
        spec: any = importlib.util.find_spec("tree_sitter_language_pack");
    } except (ImportError, OSError, ValueError) {
        return env;
    }
    module_file: any = spec.origin if spec is not None else None;
    if not module_file {
        return env;
    }
    pack_parent: any = `str(Path(module_file).resolve().parent.parent);
    existing: any = env.get("PYTHONPATH", "");
    parts: any = [part for part in existing.split(os.pathsep) if part];
    if pack_parent not in parts {
        env["PYTHONPATH"] = os.pathsep.join([pack_parent, *parts]) if parts else pack_parent;
    }
    return env;
}

def _install_hint_for_probe_failure(detail: str) -> str | None {
    lowered: any = detail.lower();
    if "tree_sitter_language_pack" in lowered
        and (
            "modulenotfounderror" in lowered
            or "no module named" in lowered
            or "import error" in lowered
            or "importerror" in lowered
        )
    {
        return "Install tree-sitter-language-pack for the same Python that runs code-review-graph: pip install 'tree-sitter-language-pack>=0.3.0,<1'";
    }
    if "could not find language library" in lowered or "lookuperror" in lowered {
        return "This grammar may be missing from the installed tree-sitter-language-pack; upgrade it (pip install -U 'tree-sitter-language-pack>=0.3.0,<1') or rebuild its native extensions";
    }
    return None;
}

def _run_parser_load_probe(grammar: str, timeout_seconds: float) -> bool {
    code: any = "from tree_sitter_language_pack import get_parser\nimport sys\nget_parser(sys.argv[1])\n";
    try {
        completed: any = subprocess.run(
            [sys.executable, "-c", code, grammar],
            stdin=subprocess.DEVNULL,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.PIPE,
            timeout=timeout_seconds,
            check=False,
            env=_parser_probe_env(),
        );
    } except (OSError, subprocess.TimeoutExpired) as exc {
        _PARSER_PROBE_FAILURE_DETAILS[grammar] = `str(exc);
        logger.debug("tree-sitter parser probe failed for %s: %s", grammar, exc);
        return False;
    }
    if completed.returncode == 0 {
        _PARSER_PROBE_FAILURE_DETAILS.pop(grammar, None);
        return True;
    }

    raw_stderr: any = getattr(completed, "stderr", b"");
    if isinstance(raw_stderr, `bytes) {
        stderr: any = raw_stderr.decode("utf-8", errors="replace");
    } else {
        stderr = `str(raw_stderr);
    }
    detail: any = next(
        (line.strip() for line in reversed(stderr.splitlines()) if line.strip()),
        f"probe exited with status {completed.returncode}",
    );
    _PARSER_PROBE_FAILURE_DETAILS[grammar] = detail[:500];
    return False;
}

def _parser_load_probe_succeeds(grammar: str, timeout_seconds: float | None = None) -> bool {
    with _PARSER_PROBE_LOCK {
        cached: any = _PARSER_PROBE_RESULTS.get(grammar);
        if cached is not None {
            return cached;
        }
        grammar_lock: any = _PARSER_PROBE_GRAMMAR_LOCKS.get(grammar);
        if grammar_lock is None {
            grammar_lock = threading.Lock();
            _PARSER_PROBE_GRAMMAR_LOCKS[grammar] = grammar_lock;
        }
    }

    with grammar_lock {
        with _PARSER_PROBE_LOCK {
            cached = _PARSER_PROBE_RESULTS.get(grammar);
            if cached is not None {
                return cached;
            }
        }
        timeout: any = _parser_load_timeout_seconds()
            if timeout_seconds is None
            else timeout_seconds;
        result: any = _run_parser_load_probe(grammar, timeout);
        with _PARSER_PROBE_LOCK {
            _PARSER_PROBE_RESULTS[grammar] = result;
            detail: any = _PARSER_PROBE_FAILURE_DETAILS.get(grammar) if not result else None;
        }
        if not result {
            if detail {
                hint: any = _install_hint_for_probe_failure(detail);
                if hint {
                    logger.warning(
                        "Skipping unavailable tree-sitter parser for %s: %s. %s",
                        grammar,
                        detail,
                        hint,
                    );
                } else {
                    logger.warning(
                        "Skipping unavailable tree-sitter parser for %s: %s", grammar, detail
                    );
                }
            } else {
                logger.warning("Skipping unavailable tree-sitter parser for %s", grammar);
            }
        }
        return result;
    }
}

def _mark_parser_unavailable(grammar: str) {
    with _PARSER_PROBE_LOCK {
        _PARSER_PROBE_RESULTS[grammar] = False;
    }
}

def _clear_parser_probe_cache {
    with _PARSER_PROBE_LOCK {
        _PARSER_PROBE_RESULTS.clear();
        _PARSER_PROBE_FAILURE_DETAILS.clear();
        _PARSER_PROBE_GRAMMAR_LOCKS.clear();
    }
}

def _load_tree_sitter_parser(grammar: str) -> any {
    if not _parser_load_probe_succeeds(grammar) {
        return None;
    }
    try {
        language_pack: any = importlib.import_module("tree_sitter_language_pack");
        return language_pack.get_parser(grammar);
    } except _EXPECTED_PARSER_LOAD_ERRORS as exc {
        _mark_parser_unavailable(grammar);
        logger.debug("tree-sitter parser unavailable for %s: %s", grammar, exc);
        return None;
    }
}

glob _PhpPsr4Mappings: any = builtins.tuple[builtins.tuple[str, builtins.tuple[str, ...]], ...];

class _ImportSpec(NamedTuple) {
    has module: str;

    has line: int;

    has form: Optional[str] = None;

    has context: Optional[str] = None;
}

class _GoModule(NamedTuple) {
    has `root: Path;

    has path: str;

    has replacements: tuple[tuple[str, str], ...];
}

glob _GO_MODULE_LINE_RE: any = re.compile("^\\s*module\\s+\"?([^\\s\"]+)\"?\\s*(?://.*)?$");

glob _GO_REPLACE_LINE_RE: any = re.compile(
    "^\\s*(?:replace\\s+)?([^\\s=>]+)(?:\\s+v\\S+)?\\s*=>\\s*(\\S+)(?:\\s+v\\S+)?\\s*(?://.*)?$"
);

glob _RUBY_REQUIRE_PATHS_RE: any = re.compile(
    "require_paths?\\s*=\\s*(?:\\[([^\\]]*)\\]|%w[\\[({]([^\\])}]*)[\\])}]|(['\"])([^'\"]+)\\3)"
);

glob _RUBY_LOAD_PATH_RE: any = re.compile(
    "(?:\\$LOAD_PATH|\\$:)\\s*(?:\\.unshift|\\.push|<<)\\s*\\(?\\s*(?:File\\.expand_path\\(\\s*)?(['\"])([^'\"]+)\\1\\s*(?:,\\s*(__dir__|__FILE__))?",
);

glob _RUBY_IMPORT_METHODS: any = frozenset({
    "require",
    "require_relative",
    "load",
    "autoload",
    "require_all",
});

glob _RUBY_IMPORT_PATH_ARGUMENT: any = {"autoload": 1};

glob _GO_MOD_MAX_LINES: any = 2000;

@lru_cache(maxsize=256)
def _read_go_mod(
    go_mod_path: str, _mtime_ns: int, _size: int
) -> tuple[str, tuple[tuple[str, str], ...]] {
    try {
        text: any = Path(go_mod_path).read_text(encoding="utf-8", errors="replace");
    } except OSError {
        return ("", ());
    }
    module_path: any = "";
    replacements: list[tuple[str, str]] = [];
    in_replace_block: any = False;
    for raw_line in text.splitlines()[:_GO_MOD_MAX_LINES] {
        line: any = raw_line.strip();
        if not line or line.startswith("//") {
            continue;
        }
        if not module_path {
            `match: any = _GO_MODULE_LINE_RE.match(raw_line);
            if `match {
                module_path = `match.group(1);
                continue;
            }
        }
        if line.startswith("replace") and line.endswith("(") {
            in_replace_block = True;
            continue;
        }
        if in_replace_block and line == ")" {
            in_replace_block = False;
            continue;
        }
        if "=>" not in line or not (in_replace_block or line.startswith("replace")) {
            continue;
        }
        `match = _GO_REPLACE_LINE_RE.match(raw_line);
        if `match is None {
            continue;
        }
        old: any;
        new: any;
        (old, new) = (`match.group(1), `match.group(2));
        if new.startswith(("./", "../", "/")) or new in (".", "..") {
            replacements.append((old, new));
        }
    }
    replacements.sort(key=lambda (item) -> any { len(item[0]) }, reverse=True);
    return (module_path, `tuple(replacements));
}

@lru_cache(maxsize=64)
def _read_gemspec_require_paths(gemspec_path: str, _mtime_ns: int, _size: int) -> tuple[str, ...] {
    try {
        text: any = Path(gemspec_path).read_text(encoding="utf-8", errors="replace");
    } except OSError {
        return ();
    }
    `match: any = _RUBY_REQUIRE_PATHS_RE.search(text);
    if `match is None {
        return ("lib",);
    }
    bracketed: any;
    word_array: any;
    _quote: any;
    single: any;
    (bracketed, word_array, _quote, single) = `match.groups() as any;
    if single {
        return (single,);
    }
    if word_array is not None {
        return `tuple(word for word in word_array.split() if word);
    }
    values: any = `tuple(re.findall("['\"]([^'\"]+)['\"]", bracketed or ""));
    return values or ("lib",);
}

def _path_is_within(path: Path, `root: Path) -> bool {
    try {
        path.relative_to(`root);
    } except ValueError {
        return False;
    }
    return True;
}

@lru_cache(maxsize=128)
def _read_php_composer_psr4(
    composer_path: str, repo_root: str, _mtime_ns: int, _size: int
) -> _PhpPsr4Mappings {
    composer: any = Path(composer_path);
    `root: any = Path(repo_root);
    try {
        data: any = json.loads(composer.read_text(encoding="utf-8", errors="replace"));
    } except (OSError, json.JSONDecodeError) {
        return ();
    }
    if not isinstance(data, `dict) {
        return ();
    }

    combined: dict[str, list[str]] = {};
    for section_name in ("autoload", "autoload-dev") {
        section: any = data.get(section_name);
        if not isinstance(section, `dict) {
            continue;
        }
        psr4: any = section.get("psr-4");
        if not isinstance(psr4, `dict) {
            continue;
        }
        for (raw_prefix, raw_paths) in psr4.items() {
            if not isinstance(raw_prefix, `str) {
                continue;
            }
            prefix: any = raw_prefix.lstrip("\\").rstrip("\\");
            candidate_paths: any = [raw_paths]
                if isinstance(raw_paths, `str)
                else raw_paths if isinstance(raw_paths, `list) else [];
            destinations: any = combined.setdefault(prefix, []);
            for raw_path in candidate_paths {
                if not isinstance(raw_path, `str) {
                    continue;
                }
                try {
                    destination: any = (composer.parent / raw_path).resolve();
                } except (OSError, RuntimeError, ValueError) {
                    continue;
                }
                if not _path_is_within(destination, `root) {
                    continue;
                }
                destination_str: any = `str(destination);
                if destination_str not in destinations {
                    destinations.append(destination_str);
                }
            }
        }
    }

    return `tuple(
        (prefix, `tuple(destinations))
        for (prefix, destinations) in sorted(
            combined.items(), key=lambda (item) -> any { (-len(item[0]), item[0]) }
        )
        if destinations,
    );
}

def _with_post_init(cls: any) -> any {
    setattr(cls, "__post_init__", cls.postinit);
    return cls;
}

@dataclass
@_with_post_init
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

    def postinit {
        self.file_path = normalize_file_path(self.file_path);
        if self.kind == "File" {
            self.name = normalize_file_path(self.name);
        }
    }
}

@dataclass
@_with_post_init
class EdgeInfo {
    has kind: str;

    has source: str;

    has target: str;

    has file_path: str;

    has line: int = 0;

    has extra: dict = field(default_factory=dict[any, any]);

    def postinit {
        self.file_path = normalize_file_path(self.file_path);
    }
}

glob EXTENSION_TO_LANGUAGE: dict[str, str] = {
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

glob _CPP_HEADER_EVIDENCE_TYPES: any = frozenset(
    ("access_specifier alias_declaration base_class_clause class_specifier concept_definition "
        "lambda_expression namespace_definition noexcept template_declaration trailing_return_type "
        "using_declaration").split(),
);

glob _CPP_HEADER_EVIDENCE_QUALIFIERS: any = frozenset({b"consteval", b"constinit"});

glob _CPP_HEADER_NON_CODE_RE: any = re.compile(
    b"/\\*.*?(?:\\*/|\\Z)|//[^\\n]*|\"(?:[^\"\\\\\\n]|\\\\.)*\"|'(?:[^'\\\\\\n]|\\\\.)*'", re.DOTALL
);

glob _CPP_HEADER_TEXT_EVIDENCE_RE: any = re.compile(
    b"\\b(?:class|namespace|template|concept|using|public|private|protected|constexpr|noexcept|consteval|constinit|Q_SIGNALS)\\b|::|->|\\benum\\b[^;{}]{0,1024}\\bstruct\\b|\\b(?:struct|union)\\b[^;{}]{0,1024}:|\\]\\s*(?:\\[\\[|[^\\s;,)=\\[\\].+\\-*/%&|^!?:>])",
);

glob _CPP_QT_STRUCTURAL_MACRO_REPLACEMENTS: any = {
    b"QT_BEGIN_NAMESPACE": b" " * len(b"QT_BEGIN_NAMESPACE"),
    b"QT_END_NAMESPACE": b" " * len(b"QT_END_NAMESPACE"),
    b"Q_OBJECT": b" " * len(b"Q_OBJECT"),
    b"Q_SIGNALS": b"public" + b" " * (len(b"Q_SIGNALS") - len(b"public")),
    b"Q_SLOTS": b" " * len(b"Q_SLOTS"),
    b"Q_EMIT": b" " * len(b"Q_EMIT"),
};

glob SHEBANG_INTERPRETER_TO_LANGUAGE: dict[str, str] = {
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

glob _SHEBANG_PROBE_BYTES: any = 256;

glob _ANSIBLE_PATH_COMPONENTS: frozenset[str] = frozenset({
    "playbooks",
    "roles",
    "tasks",
    "handlers",
    "group_vars",
    "host_vars",
});

glob _ANSIBLE_PLAYBOOK_NAMES: frozenset[str] = frozenset(
    ("site.yml site.yaml main.yml main.yaml install.yml install.yaml deploy.yml deploy.yaml").split(),
);

glob _ANSIBLE_PLAY_KEYS: frozenset[str] = frozenset(
    ("tasks handlers pre_tasks post_tasks roles gather_facts become become_user become_method "
        "serial strategy vars_files vars_prompt any_errors_fatal max_fail_percentage ignore_errors").split(),
);

glob _ANSIBLE_MODULE_KEYS: frozenset[str] = frozenset(
    ("apt yum dnf package pip copy template file service systemd command shell raw git user stat "
        "include_tasks import_tasks include_role import_role set_fact debug fail assert wait_for "
        "pause lineinfile blockinfile get_url uri unarchive add_host group_by include_vars").split(),
);

glob _TASK_META_KEYS: frozenset[str] = frozenset(
    ("name when loop loop_control with_items with_first_found with_fileglob with_dict "
        "with_subelements with_nested with_sequence with_indexed_items register notify tags become "
        "become_user become_method ignore_errors vars no_log check_mode environment any_errors_fatal "
        "run_once delegate_to delegate_facts block rescue always changed_when failed_when retries "
        "delay until listen connection timeout").split(),
);

glob _CLASS_TYPES: dict[str, list[str]] = {
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
    "php": ["class_declaration", "interface_declaration", "trait_declaration", "enum_declaration"],
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

glob _TS_HERITAGE_CLAUSES: any = frozenset({
    "extends_clause",
    "implements_clause",
    "extends_type_clause",
});

glob _TS_TYPE_DECLARATIONS: any = frozenset({
    "class_declaration",
    "abstract_class_declaration",
    "interface_declaration",
    "type_alias_declaration",
    "enum_declaration",
});

glob _FUNCTION_TYPES: dict[str, list[str]] = {
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

glob _IMPORT_TYPES: dict[str, list[str]] = {
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

glob _CALL_TYPES: dict[str, list[str]] = {
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

def _builtin_language_names -> frozenset[str] {
    return frozenset(EXTENSION_TO_LANGUAGE.values())
        | frozenset(_CLASS_TYPES)
        | frozenset(_FUNCTION_TYPES)
        | frozenset(_IMPORT_TYPES)
        | frozenset(_CALL_TYPES);
}

glob _TEST_PATTERNS: any = [
    re.compile("^test_"),
    re.compile("^Test"),
    re.compile("_test$"),
    re.compile("\\.test\\."),
    re.compile("\\.spec\\."),
    re.compile("_spec$"),
];

glob _SEP: any = "(?:^|[\\\\/])";

glob _ABSOLUTE_PATH_RE: any = re.compile("^(?:/|[A-Za-z]:/|//)");

glob _TEST_DIR_PATTERNS: any = [
    re.compile(_SEP + "tests[\\\\/]"),
    re.compile(_SEP + "__tests__[\\\\/]"),
    re.compile(_SEP + "e2e[_-]?tests?[\\\\/]"),
    re.compile(_SEP + "testthat[\\\\/]"),
    re.compile(_SEP + "specs?[\\\\/].*\\.(?:rb|rake)$"),
];

glob _SINGULAR_TEST_DIR_RE: any = re.compile(_SEP + "test[\\\\/]");

glob _TEST_HELPER_DIR_PATTERNS: any = [re.compile(_SEP + "test[_-]utils?[\\\\/]")];

glob _STORYBOOK_FILE_RE: any = re.compile("\\.stories\\.[jt]sx?$");

glob _TEST_NAME_PATTERNS: any = [
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

glob _TEST_RUNNER_NAMES: any = frozenset(
    ("describe it test beforeEach afterEach beforeAll afterAll suite").split()
);

glob _RUBY_TEST_BLOCK_NAMES: any = frozenset({
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

glob _RUBY_MEMO_BLOCK_NAMES: any = frozenset({"let", "let!", "subject", "subject!"});

glob _RUBY_DESCRIBING_BLOCK_NAMES: any = frozenset({"describe", "context"});

glob _RUBY_CONSTANT_PATH_RE: any = re.compile("^[A-Z]\\w*(?:\\.[A-Z]\\w*)*$");

glob _RubyClassRef: any = builtins.tuple[str, builtins.tuple[str, ...]];

glob _JAVA_PACKAGE_QUALIFIED_TYPE: any = re.compile("(?:[a-z_$][\\w$]*\\.)+[A-Z][\\w$]*");

glob _TEST_ANNOTATIONS: any = frozenset(
    ("Test ParameterizedTest RepeatedTest TestFactory org.junit.Test org.junit.jupiter.api.Test "
        "test tokio::test async_std::test rstest rstest::rstest proptest").split(),
);

glob _SPRING_STEREOTYPE_ANNOTATIONS: any = frozenset(
    ("Component Service Repository Controller RestController Configuration Indexed "
        "ControllerAdvice RestControllerAdvice EventListener").split(),
);

glob _SPRING_INJECT_ANNOTATIONS: any = frozenset({"Autowired", "Inject", "Resource"});

glob _SPRING_PLACEHOLDER_RE: any = re.compile("\\$\\{([^{}]+)\\}");

glob _TEMPORAL_INTERFACE_ANNOTATIONS: any = frozenset({"WorkflowInterface", "ActivityInterface"});

glob _TEMPORAL_METHOD_ANNOTATIONS: any = frozenset({
    "WorkflowMethod",
    "ActivityMethod",
    "SignalMethod",
    "QueryMethod",
});

glob _KAFKA_LISTENER_ANNOTATIONS: any = frozenset({"KafkaListener", "KafkaHandler"});

glob _KAFKA_CONSUMER_TYPES: any = frozenset({
    "KafkaReceiver",
    "ReactiveKafkaConsumerTemplate",
    "MessageListenerContainer",
    "ConcurrentMessageListenerContainer",
});

glob _KAFKA_PRODUCER_TYPES: any = frozenset({
    "KafkaTemplate",
    "KafkaOperations",
    "ReactiveKafkaProducerTemplate",
    "KafkaSender",
});

glob _SPRING_SCHEDULED_ANNOTATIONS: any = frozenset({"Scheduled", "Schedules"});

glob _SPRING_EVENT_LISTENER_ANNOTATIONS: any = frozenset({"EventListener"});

glob _SPRING_EVENT_PUBLISH_METHODS: any = frozenset({"publishEvent"});

glob _JAVA_PACKAGE_KEY: any = "__crg_java_package__";

glob _JAVA_WILDCARD_KEY: any = "__crg_java_wildcard__";

glob _SPRING_REQUEST_PREFIX_KEY: any = "__crg_spring_request_prefix__:";

glob _JS_IMPORT_ORIGINAL_PREFIX_KEY: any = "__crg_js_import_original__:";

glob _PY_MODULE_BINDING_KEY: any = "__crg_py_module_binding__:";

glob _RUST_INLINE_MODULE_KEY: any = "__crg_rust_inline_module__:";

glob _PY_LITERAL_VALUE_TYPES: any = frozenset(
    ("concatenated_string dictionary dictionary_comprehension false float generator_expression "
        "integer list list_comprehension set set_comprehension string true tuple").split(),
);

glob _SPRING_REQUEST_MAPPINGS: any = {
    "DeleteMapping": ("DELETE",),
    "GetMapping": ("GET",),
    "PatchMapping": ("PATCH",),
    "PostMapping": ("POST",),
    "PutMapping": ("PUT",),
    "RequestMapping": (),
};

glob _SPRING_WEBFLUX_HTTP_VERBS: any = frozenset({"DELETE", "GET", "PATCH", "POST", "PUT"});

glob _HTTP_REQUEST_METHODS: any = frozenset(
    "CONNECT DELETE GET HEAD OPTIONS PATCH POST PUT TRACE".split()
);

glob _VBNET_IDENT: any = "(?:[A-Za-z_][A-Za-z0-9_]*|\\[[^\\]\\r\\n]+\\])";

glob _VBNET_DOTTED_IDENT: any = f"{_VBNET_IDENT}(?:\\.{_VBNET_IDENT})*";

glob _VBNET_MODIFIER_WORDS: any = tuple(
    ("Public Private Protected Friend Partial Shared Static MustInherit NotInheritable Overridable "
        "Overrides MustOverride Overloads Default ReadOnly WriteOnly Shadows Async Iterator Declare "
        "Narrowing Widening").split(),
);

glob _VBNET_MODIFIER_RE: any = f"(?:(?:{"|".join(_VBNET_MODIFIER_WORDS)})\\s+)*";

glob _VBNET_IMPORT_RE: any = re.compile("^\\s*Imports\\s+(.+?)\\s*$", re.IGNORECASE);

glob _VBNET_NAMESPACE_RE: any = re.compile(
    f"^\\s*Namespace\\s+(?P<name>{_VBNET_DOTTED_IDENT})\\s*$", re.IGNORECASE
);

glob _VBNET_END_NAMESPACE_RE: any = re.compile("^\\s*End\\s+Namespace\\b", re.IGNORECASE);

glob _VBNET_TYPE_RE: any = re.compile(
    f"^\\s*{_VBNET_MODIFIER_RE}(?P<kind>Class|Interface|Structure|Module|Enum)\\s+(?P<name>{_VBNET_IDENT})\\b(?P<rest>.*)$",
    re.IGNORECASE,
);

glob _VBNET_END_TYPE_RE: any = re.compile(
    "^\\s*End\\s+(?P<kind>Class|Interface|Structure|Module|Enum)\\b", re.IGNORECASE
);

glob _VBNET_MEMBER_RE: any = re.compile(
    f"^\\s*(?P<mods>{_VBNET_MODIFIER_RE})(?P<kind>Function|Sub|Property)\\s+(?P<name>{_VBNET_IDENT})\\b(?P<rest>.*)$",
    re.IGNORECASE,
);

glob _VBNET_OPERATOR_RE: any = re.compile(
    f"^\\s*(?P<mods>{_VBNET_MODIFIER_RE})(?P<kind>Operator)\\s+(?P<name>\\S+)\\s*(?P<rest>.*)$",
    re.IGNORECASE,
);

glob _VBNET_END_MEMBER_RE: any = re.compile(
    "^\\s*End\\s+(Function|Sub|Property|Operator)\\b", re.IGNORECASE
);

glob _VBNET_INHERITS_RE: any = re.compile("\\bInherits\\s+(.+?)\\s*$", re.IGNORECASE);

glob _VBNET_IMPLEMENTS_RE: any = re.compile("\\bImplements\\s+(.+?)\\s*$", re.IGNORECASE);

glob _VBNET_NEW_RE: any = re.compile(
    f"\\bNew\\s+(?P<target>{_VBNET_DOTTED_IDENT})\\s*(?:\\(Of\\b[^)]*\\))?\\s*\\(", re.IGNORECASE
);

glob _VBNET_CALL_RE: any = re.compile(
    f"(?<![A-Za-z0-9_.])(?P<target>{_VBNET_DOTTED_IDENT})\\s*\\(", re.IGNORECASE
);

glob _VBNET_CALL_KEYWORDS: any = frozenset(
    ("addhandler and andalso as call case catch class cobj continue ctype directcast do each else "
        "elseif end enum erase error event exit finally for function get gettype getxmlnamespace "
        "global gosub goto if implements imports inherits interface loop module mustinherit new next "
        "not nothing operator option or orelse property raiseevent redim rem removehandler resume "
        "return select set step stop structure sub synclock then throw to try typeof until using when "
        "while with withevents xor").split(),
);

def _vbnet_normalize_name(value: str) -> str {
    return ".".join(
        part[1:-1] if part.startswith("[") and part.endswith("]") else part
        for part in value.strip().split("."),
    );
}

def _strip_vbnet_noise(text: str) -> str {
    cleaned_lines: list[str] = [];
    for raw_line in text.splitlines(keepends=True) {
        line: any = raw_line.rstrip("\r\n");
        ending: any = raw_line[len(line):];
        if re.match("^\\s*Rem\\b", line, re.IGNORECASE) {
            cleaned_lines.append(" " * len(line) + ending);
            continue;
        }

        out: list[str] = [];
        in_string: any = False;
        i: any = 0;
        while i < len(line) {
            char: any = line[i];
            if char == "\"" {
                out.append(char);
                if in_string and i + 1 < len(line) and line[i + 1] == "\"" {
                    out.append(" ");
                    i += 2;
                    continue;
                }
                in_string = not in_string;
                i += 1;
                continue;
            }
            if not in_string and char == "'" {
                out.append(" " * (len(line) - i));
                break;
            }
            out.append(" " if in_string else char);
            i += 1;
        }
        cleaned_lines.append("".join(out) + ending);
    }
    return "".join(cleaned_lines);
}

def _vbnet_logical_lines(cleaned: str) -> list[tuple[int, int, str]] {
    logical: list[tuple[int, int, str]] = [];
    parts: list[str] = [];
    start_line: any = 1;
    depth: any = 0;
    for (line_no, raw_line) in enumerate(cleaned.splitlines(), 1) {
        stripped: any = raw_line.strip();
        if not stripped and not parts {
            continue;
        }
        if not parts {
            start_line = line_no;
        }
        explicit: any = stripped.endswith("_");
        if explicit {
            stripped = stripped[:-1].rstrip();
        }
        parts.append(stripped);
        depth += stripped.count("(") - stripped.count(")");
        if explicit or depth > 0 {
            continue;
        }
        logical.append((start_line, line_no, " ".join(parts)));
        parts = [];
        depth = 0;
    }
    if parts {
        logical.append((start_line, len(cleaned.splitlines()) or 1, " ".join(parts)));
    }
    return logical;
}

def _vbnet_parenthesized(text: str, start: int) -> tuple[str, int] | None {
    if start >= len(text) or text[start] != "(" {
        return None;
    }
    depth: any = 0;
    for index in range(start, len(text)) {
        if text[index] == "(" {
            depth += 1;
        } elif text[index] == ")" {
            depth -= 1;
            if depth == 0 {
                return (text[start + 1:index], index + 1);
            }
        }
    }
    return None;
}

def _vbnet_split_top_level(value: str) -> list[str] {
    parts: list[str] = [];
    start: any = 0;
    depth: any = 0;
    for (index, char) in enumerate(value) {
        if char == "(" {
            depth += 1;
        } elif char == ")" {
            depth = max(0, depth - 1);
        } elif char == "," and depth == 0 {
            parts.append(value[start:index]);
            start = index + 1;
        }
    }
    parts.append(value[start:]);
    return parts;
}

def _vbnet_type_parameters(rest: str) -> tuple[list[str], str] {
    tail: any = rest.lstrip();
    if not tail.lower().startswith("(of ") {
        return ([], rest);
    }
    group: any = _vbnet_parenthesized(tail, 0);
    if group is None {
        return ([], rest);
    }
    content: any;
    end: any;
    (content, end) = group as any;
    params: any = [
        part.strip().split()[0]
        for part in _vbnet_split_top_level(content[3:])
        if part.strip()
    ];
    return (params, tail[end:]);
}

def _vbnet_signature_parts(rest: str) -> tuple[Optional[str], Optional[str], list[str]] {
    type_params: any;
    tail: any;
    (type_params, tail) = _vbnet_type_parameters(rest) as any;
    tail = tail.lstrip();
    params: Optional[str] = None;
    if tail.startswith("(") {
        group: any = _vbnet_parenthesized(tail, 0);
        if group is not None {
            raw_params: any;
            end: any;
            (raw_params, end) = group as any;
            params = re.sub("\\s+", " ", raw_params).strip();
            tail = tail[end:];
        }
    }

    return_type: any = None;
    return_match: any = re.search(
        "\\bAs\\s+(.+?)(?=\\s+(?:Implements|Handles)\\b|$)", tail, re.IGNORECASE
    );
    if return_match {
        return_type = re.sub("\\s+", " ", return_match.group(1)).strip();
    }
    return (params, return_type, type_params);
}

def _vbnet_relationship_targets(value: str) -> list[str] {
    targets: list[str] = [];
    for raw_part in _vbnet_split_top_level(value) {
        part: any = raw_part.strip();
        if not part {
            continue;
        }
        if "=" in part {
            part = part.split("=", 1)[1].strip();
        }
        if part.lower().startswith("global.") {
            part = part[7:];
        }
        part = re.sub("\\s*\\(Of\\b.*\\)\\s*$", "", part, flags=re.IGNORECASE);
        if re.fullmatch(_VBNET_DOTTED_IDENT, part) {
            targets.append(_vbnet_normalize_name(part));
        }
    }
    return targets;
}

glob _RESCRIPT_IDENT: any = "[A-Za-z_][A-Za-z0-9_']*";

glob _RESCRIPT_MODULE_RE: any = re.compile(
    "^\\s*module\\s+(?:type\\s+)?([A-Z][A-Za-z0-9_']*)\\s*[:=]", re.MULTILINE
);

glob _RESCRIPT_DECORATOR_PREFIX: any = "(?:@[A-Za-z_][A-Za-z0-9_']*(?:\\([^)]*\\))?\\s+)*";

glob _RESCRIPT_LET_RE: any = re.compile(
    f"^\\s*{_RESCRIPT_DECORATOR_PREFIX}(?:let\\s+(?:rec\\s+)?|and\\s+)({_RESCRIPT_IDENT})\\b",
    re.MULTILINE,
);

glob _RESCRIPT_EXTERNAL_RE: any = re.compile(
    f"^\\s*{_RESCRIPT_DECORATOR_PREFIX}external\\s+({_RESCRIPT_IDENT})\\s*:", re.MULTILINE
);

glob _RESCRIPT_TYPE_RE: any = re.compile(
    f"^\\s*{_RESCRIPT_DECORATOR_PREFIX}type\\s+(?:rec\\s+)?({_RESCRIPT_IDENT})\\b", re.MULTILINE
);

glob _RESCRIPT_OPEN_RE: any = re.compile(
    "^\\s*(open|include)\\s+([A-Z][A-Za-z0-9_'.]*)", re.MULTILINE
);

glob _RESCRIPT_MODULE_ALIAS_RE: any = re.compile(
    "^\\s*module\\s+([A-Z][A-Za-z0-9_']*)\\s*=\\s*([A-Z][A-Za-z0-9_']*(?:\\.[A-Za-z_][A-Za-z0-9_']*)*)\\s*$",
    re.MULTILINE,
);

glob _RESCRIPT_JSX_RE: any = re.compile(
    "(?:^|(?<=[\\s{(,>}]))<([A-Z][A-Za-z0-9_']*(?:\\.[A-Z][A-Za-z0-9_']*)*)\\b", re.MULTILINE
);

glob _RESCRIPT_MODULE_ATTR_RE: any = re.compile("@module\\(\\s*\"([^\"]+)\"\\s*\\)");

glob _RESCRIPT_CALL_RE: any = re.compile(
    f"(?<![A-Za-z0-9_']){_RESCRIPT_IDENT}(?:\\.{_RESCRIPT_IDENT})*\\s*\\("
);

with entry {
    _RESCRIPT_CALL_RE = re.compile(
        "(?<![A-Za-z0-9_'])([A-Za-z_][A-Za-z0-9_']*(?:\\.[A-Za-z_][A-Za-z0-9_']*)*)\\s*\\("
    );
}

glob _RESCRIPT_KEYWORDS: any = frozenset(
    ("let rec and type module open include external if else switch when match fun true false for "
        "while mutable try catch throw assert lazy do in of as exception private constraint with "
        "downto to unpack async await").split(),
);

def _strip_rescript_noise(text: str) -> str {
    out: list[str] = [];
    i: any = 0;
    n: any = len(text);
    while i < n {
        c: any = text[i];
        nxt: any = text[i + 1] if i + 1 < n else "";
        if c == "/" and nxt == "/" {
            while i < n and text[i] != "\n" {
                out.append(" ");
                i += 1;
            }
            continue;
        }
        if c == "/" and nxt == "*" {
            depth: any = 1;
            out.append("  ");
            i += 2;
            while i < n and depth > 0 {
                if i + 1 < n and text[i] == "/" and text[i + 1] == "*" {
                    depth += 1;
                    out.append("  ");
                    i += 2;
                } elif i + 1 < n and text[i] == "*" and text[i + 1] == "/" {
                    depth -= 1;
                    out.append("  ");
                    i += 2;
                } else {
                    out.append("\n" if text[i] == "\n" else " ");
                    i += 1;
                }
            }
            continue;
        }
        if c == "\"" {
            out.append("\"");
            i += 1;
            while i < n and text[i] != "\"" {
                if text[i] == "\\" and i + 1 < n {
                    out.append("  ");
                    i += 2;
                    continue;
                }
                out.append("\n" if text[i] == "\n" else " ");
                i += 1;
            }
            if i < n {
                out.append("\"");
                i += 1;
            }
            continue;
        }
        if c == "`" {
            out.append("`");
            i += 1;
            while i < n and text[i] != "`" {
                out.append("\n" if text[i] == "\n" else " ");
                i += 1;
            }
            if i < n {
                out.append("`");
                i += 1;
            }
            continue;
        }
        out.append(c);
        i += 1;
    }
    return "".join(out);
}

def _rescript_brace_depth_array(cleaned: str) -> list[int] {
    depth: any = [0] * (len(cleaned) + 1);
    d: any = 0;
    for (i, c) in enumerate(cleaned) {
        depth[i] = d;
        if c == "{" {
            d += 1;
        } elif c == "}" {
            d = max(0, d - 1);
        }
    }
    depth[len(cleaned)] = d;
    return depth;
}

def _scan_rescript_modules(cleaned: str, offset_to_line) -> list[dict] {
    m: any;
    modules: list[dict] = [];
    n: any = len(cleaned);
    alias_starts: any = {m.start() for m in _RESCRIPT_MODULE_ALIAS_RE.finditer(cleaned)};
    for `match in _RESCRIPT_MODULE_RE.finditer(cleaned) {
        if `match.start() in alias_starts {
            continue;
        }
        name: any = `match.group(1);
        header_start: any = `match.start();
        brace_open: any = cleaned.find("{", `match.end());
        if brace_open == -1 {
            continue;
        }
        between: any = cleaned[`match.end():brace_open];
        if re.search("(?:^|\\s)(?:let|type|module|external|and)\\s", between) {
            continue;
        }
        depth: any = 1;
        j: any = brace_open + 1;
        while j < n and depth > 0 {
            c: any = cleaned[j];
            if c == "{" {
                depth += 1;
            } elif c == "}" {
                depth -= 1;
            }
            j += 1;
        }
        brace_close: any = j - 1 if depth == 0 else n - 1;
        modules.append({
            "name": name,
            "start_off": header_start,
            "end_off": brace_close,
            "body_start_off": brace_open + 1,
            "start_line": offset_to_line(header_start),
            "end_line": offset_to_line(brace_close),
            "parent": None,
        });
    }
    for (i, m) in enumerate(modules) {
        parent_name: any = None;
        parent_start: any = -1;
        for (j, other) in enumerate(modules) {
            if i == j {
                continue;
            }
            if other["start_off"] < m["start_off"]
                and other["end_off"] > m["end_off"]
                and other["start_off"] > parent_start
            {
                parent_name = other["name"];
                parent_start = other["start_off"];
            }
        }
        m["parent"] = parent_name;
    }
    return modules;
}

@lru_cache(maxsize=64)
def _repo_root_prefixes(repo_root: str) -> tuple[str, ...] {
    `root: any = normalize_file_path(repo_root).rstrip("/");
    if not `root {
        return ();
    }
    prefixes: any = [`root];
    try {
        resolved: any = normalize_file_path(Path(repo_root).resolve()).rstrip("/");
    } except (OSError, ValueError, RuntimeError) {
        resolved = "";
    }
    if resolved and resolved not in prefixes {
        prefixes.append(resolved);
    }
    return `tuple(prefixes);
}

@lru_cache(maxsize=2048)
def _resolved_dir(directory: str) -> str {
    try {
        return normalize_file_path(Path(directory).resolve());
    } except (OSError, ValueError, RuntimeError) {
        return "";
    }
}

def _strip_prefix(normalized: str, `root: str) -> Optional[str] {
    if normalized == `root {
        return "";
    }
    if normalized.startswith(`root + "/") {
        return normalized[len(`root) + 1:];
    }
    if normalized.lower().startswith(`root.lower() + "/") {
        return normalized[len(`root) + 1:];
    }
    return None;
}

def _repo_relative_path(normalized: str, repo_root: "str | PurePath | None") -> Optional[str] {
    if not _ABSOLUTE_PATH_RE.match(normalized) {
        return normalized;
    }
    if repo_root is None {
        return None;
    }
    prefixes: any = _repo_root_prefixes(`str(repo_root));
    `root: any;
    for `root in prefixes {
        relative: any = _strip_prefix(normalized, `root);
        if relative is not None {
            return relative;
        }
    }
    directory: any;
    _: any;
    name: any;
    (directory, _, name) = normalized.rpartition("/") as any;
    resolved: any = _resolved_dir(directory) if directory else "";
    if resolved and resolved != directory {
        candidate: any = f"{resolved}/{name}";
        for `root in prefixes {
            relative = _strip_prefix(candidate, `root);
            if relative is not None {
                return relative;
            }
        }
    }
    return None;
}

@lru_cache(maxsize=256)
def _is_python_package_dir(directory: str) -> bool {
    try {
        return os.path.isfile(os.path.join(directory, "__init__.py"));
    } except (OSError, ValueError) {
        return False;
    }
}

def _is_shipped_test_package(
    normalized: str, relative: str, repo_root: "str | PurePath | None"
) -> bool {
    if not relative.endswith(".py") {
        return False;
    }
    segments: any = relative.split("/");
    dirs: any = segments[:-1];
    try {
        index: any = len(dirs) - 1 - dirs[::-1].index("test");
    } except ValueError {
        return False;
    }
    if index == 0 {
        return False;
    }
    if len(normalized) > len(relative) and normalized.endswith(relative) {
        prefix: any = normalized[:len(normalized) - len(relative)];
    } elif repo_root is not None {
        prefix = normalize_file_path(repo_root).rstrip("/") + "/";
    } else {
        return False;
    }
    test_dir: any = prefix + "/".join(dirs[:index + 1]);
    parent_dir: any = prefix + "/".join(dirs[:index]);
    return _is_python_package_dir(test_dir) and _is_python_package_dir(parent_dir);
}

def repo_relative_path(
    path: "str | PurePath", repo_root: "str | PurePath | None" = None
) -> Optional[str] {
    return _repo_relative_path(normalize_file_path(path), repo_root);
}

def is_test_file(
    path: "str | PurePath",
    repo_root: "str | PurePath | None" = None,
    *,
    include_helper_dirs: bool = False,
) -> bool {
    normalized: any = normalize_file_path(path);
    basename: any = normalized.rsplit("/", 1)[-1];
    if `any(p.search(basename) for p in _TEST_NAME_PATTERNS) {
        return True;
    }

    relative: any = _repo_relative_path(normalized, repo_root);
    if relative is None {
        return False;
    }
    if `any(p.search(relative) for p in _TEST_DIR_PATTERNS) {
        return True;
    }
    if include_helper_dirs and `any(p.search(relative) for p in _TEST_HELPER_DIR_PATTERNS) {
        return True;
    }
    if _SINGULAR_TEST_DIR_RE.search(relative) {
        return not _is_shipped_test_package(normalized, relative, repo_root);
    }
    return False;
}

glob _is_test_file: any = is_test_file;

def _is_test_function(
    name: str,
    file_path: str,
    decorators: tuple[str, ...] = (),
    repo_root: "str | PurePath | None" = None,
) -> bool {
    if `any(p.search(name) for p in _TEST_PATTERNS) {
        return True;
    }
    if is_test_file(file_path, repo_root) and name in _TEST_RUNNER_NAMES {
        return True;
    }
    if decorators and `any(d in _TEST_ANNOTATIONS for d in decorators) {
        return True;
    }
    return False;
}

glob _MAX_DOCSTRING_CHARS: any = 400;

glob _DOC_COMMENT_NODE_TYPES: any = frozenset({
    "comment",
    "block_comment",
    "line_comment",
    "doc_comment",
});

glob _DOC_COMMENT_SKIP_TYPES: any = frozenset({"attribute_item", "decorator"});

glob _DOC_COMMENT_WRAPPER_TYPES: any = frozenset({"export_statement", "template_declaration"});

glob _CSHARP_SUMMARY_RE: any = re.compile(
    "<summary(?:\\s[^>]*)?>(.*?)</summary\\s*>", re.IGNORECASE | re.DOTALL
);

glob _XML_TAG_RE: any = re.compile("<[^>]+>");

glob _DOC_PARAGRAPH_TAG_RE: any = re.compile("</?(?:p|para)(?:\\s[^>]*)?>", re.IGNORECASE);

glob _DOC_INLINE_TAG_RE: any = re.compile("\\{@(?:code|literal|link)\\s+([^}]+)\\}", re.IGNORECASE);

glob _DOC_BRIEF_RE: any = re.compile("^\\s*[@\\\\]brief\\s+", re.IGNORECASE);

def _clean_docstring_summary(raw: str, language: str) -> str {
    line: any;
    text: any = raw.replace("\r\n", "\n").replace("\r", "\n");
    if language == "csharp" {
        summary: any = _CSHARP_SUMMARY_RE.search(text);
        if summary {
            text = summary.group(1);
        }
    }
    if language != "python" {
        text = _DOC_PARAGRAPH_TAG_RE.sub("\n\n", text);
        text = _DOC_INLINE_TAG_RE.sub("\\1", text);
        text = _XML_TAG_RE.sub(" ", text);
        text = html.unescape(text);
        text = _DOC_BRIEF_RE.sub("", text);
    }

    lines: any = [line.strip() for line in text.splitlines()];
    while lines and not lines[0] {
        lines.pop(0);
    }
    paragraph: list[str] = [];
    for line in lines {
        if not line {
            break;
        }
        if paragraph and line.startswith(("@param", "@return", "\\param", "\\return")) {
            break;
        }
        paragraph.append(line);
    }
    return " ".join(" ".join(paragraph).split())[:_MAX_DOCSTRING_CHARS];
}

def _strip_block_doc_comment(text: str) -> str {
    if text.startswith(("/**", "/*!")) {
        text = text[3:];
    } elif text.startswith("/*") {
        text = text[2:];
    }
    if text.endswith("*/") {
        text = text[:-2];
    }

    lines: list[str] = [];
    for line in text.splitlines() {
        stripped: any = line.lstrip();
        if stripped.startswith("*") {
            stripped = stripped[1:];
            if stripped.startswith(" ") {
                stripped = stripped[1:];
            }
        }
        lines.append(stripped);
    }
    return "\n".join(lines);
}

def _modifier_annotation_names(`node) -> list[str] {
    names: list[str] = [];
    for sub in `node.children {
        if sub.type == "modifiers" {
            for mod in sub.children {
                if mod.type in ("annotation", "marker_annotation") {
                    text: any = mod.text.decode("utf-8", errors="replace");
                    names.append(text.lstrip("@").strip());
                }
            }
        }
    }
    return names;
}

def _python_decorator_names(`node) -> list[str] {
    parent: any = `node.parent;
    if parent is None or parent.type != "decorated_definition" {
        return [];
    }

    names: list[str] = [];
    for sibling in parent.children {
        if sibling.type != "decorator" {
            continue;
        }
        text: any = sibling.text.decode("utf-8", errors="replace");
        names.append(text.lstrip("@").strip());
    }
    return names;
}

def _csharp_attribute_names(`node) -> list[str] {
    names: list[str] = [];
    for sub in `node.children {
        if sub.type != "attribute_list" {
            continue;
        }
        for attr in sub.children {
            if attr.type != "attribute" {
                continue;
            }
            for ident in attr.children {
                if ident.type in ("identifier", "qualified_name") {
                    names.append(ident.text.decode("utf-8", errors="replace").strip());
                    break;
                }
            }
        }
    }
    return names;
}

glob _PHPUNIT_TEST_ATTRIBUTE: any = "phpunit\\framework\\attributes\\test";

def _php_attribute_aliases(`node) -> dict[str, str] {
    `root: any = `node;
    while `root.parent is not None {
        `root = `root.parent;
    }

    aliases: dict[str, str] = {};
    stack: any = [`root];
    while stack {
        current: any = stack.pop();
        if current.type == "namespace_use_clause" {
            alias: any = current.child_by_field_name("alias");
            if alias is not None {
                target: any = next(
                    (child
                    for child in current.children
                    if child.type in ("name", "qualified_name") and child != alias),
                    None,
                );
                if target is not None {
                    alias_text: any = alias.text.decode("utf-8", errors="replace").strip();
                    target_text: any = target.text.decode("utf-8", errors="replace").strip();
                    if current.parent.type == "namespace_use_group" {
                        declaration: any = current.parent.parent;
                        prefix: any = next(
                            (child
                            for child in declaration.children
                            if child.type == "namespace_name"),
                            None,
                        );
                        if prefix is not None {
                            prefix_text: any = prefix.text.decode(
                                "utf-8", errors="replace"
                            ).strip();
                            target_text = f"{prefix_text}\\{target_text}";
                        }
                    }
                    normalized_target: any = target_text.lstrip("\\").casefold();
                    if normalized_target == _PHPUNIT_TEST_ATTRIBUTE {
                        aliases[alias_text.casefold()] = "Test";
                    }
                }
            }
        }
        stack.extend(reversed(current.children));
    }
    return aliases;
}

def _php_attribute_names(`node) -> list[str] {
    names: list[str] = [];
    for sub in `node.children {
        if sub.type != "attribute_list" {
            continue;
        }
        for group in sub.children {
            if group.type != "attribute_group" {
                continue;
            }
            for attr in group.children {
                if attr.type != "attribute" {
                    continue;
                }
                for ident in attr.children {
                    if ident.type in ("name", "qualified_name") {
                        raw_name: any = ident.text.decode("utf-8", errors="replace").strip();
                        normalized: any = raw_name.lstrip("\\");
                        if normalized.casefold() == _PHPUNIT_TEST_ATTRIBUTE {
                            names.append("Test");
                        } else {
                            names.append(normalized);
                        }
                        break;
                    }
                }
            }
        }
    }
    if not names {
        return [];
    }
    aliases: any = _php_attribute_aliases(`node);
    return [aliases.get(name.casefold(), name) for name in names];
}

glob _PHP_TEST_DOC_TAG_RE: any = re.compile("(?<![\\w-])@test(?![\\w-])");

def _php_docblock_marks_test(`node) -> bool {
    sib: any = `node.prev_sibling;
    return `bool(
        sib is not None
            and operator.eq(sib.type, "comment")
            and _PHP_TEST_DOC_TAG_RE.search(sib.text.decode("utf-8", errors="replace")),
    );
}

glob _SEPARATE_SCOPE_RULE_LANGUAGES: any = frozenset({"python", "cpp", "julia", "csharp"});

def _nested_import_chain(module: str, resolved: str, symbol: str) -> str {
    parts: any = module.split(".");
    if len(parts) < 2 or parts[-1] != symbol {
        return symbol;
    }
    stem: any = Path(resolved).stem;
    for index in range(len(parts) - 2, -1, -1) {
        if parts[index] == stem {
            return ".".join(parts[index:]);
        }
    }
    return symbol;
}

class _OuterBinding(builtins.str) {
    has levels: int;

    static def __new__(cls, value: str, levels: int) -> "_OuterBinding" {
        binding: any = super.__new__(cls, value);
        binding.levels = levels;
        return binding;
    }
}

def _csharp_name(`node) -> str {
    parts: any = [];
    pending: any = [`node] if `node is not None else [];
    while pending {
        current: any = pending.pop();
        if current.type == "comment" {
            continue;
        }
        if current.children {
            pending.extend(reversed(current.children));
        } else {
            parts.append(current.text.decode("utf-8", errors="replace").removeprefix("@"));
        }
    }
    return "".join(parts);
}

def _csharp_namespace_context(`node) -> list[tuple[str, int]] {
    declarations: any = [];
    current: any = `node.parent;
    while current is not None {
        if current.type in ("namespace_declaration", "file_scoped_namespace_declaration") {
            declarations.append(current);
        }
        if current.parent is None and not declarations {
            for child in current.named_children {
                if child.start_byte >= `node.start_byte {
                    break;
                }
                if child.type == "file_scoped_namespace_declaration" {
                    declarations.append(child);
                    break;
                }
                if child.type in _CLASS_TYPES["csharp"] or child.type == "namespace_declaration" {
                    break;
                }
            }
        }
        current = current.parent;
    }
    scopes: any = [("", -1)];
    namespace: any = "";
    for declaration in reversed(declarations) {
        name: any = _csharp_name(declaration.child_by_field_name("name"));
        namespace = f"{namespace}.{name}" if namespace else name;
        scopes.append((namespace, declaration.start_byte));
    }
    return `list(reversed(scopes));
}

def _php_namespaces(root_node) -> list[str] {
    namespaces: list[str] = [];
    for child in root_node.children {
        if child.type != "namespace_definition" {
            continue;
        }
        for part in child.children {
            if part.type == "namespace_name" {
                name: any = part.text.decode("utf-8", errors="replace").strip("\\");
                if name and name not in namespaces {
                    namespaces.append(name);
                }
            }
        }
    }
    return namespaces;
}

def _csharp_namespaces(root_node) -> list[str] {
    namespaces: list[str] = [];
    stack: any = [(root_node, "")];

    while stack {
        `node: any;
        parent_namespace: any;
        (`node, parent_namespace) = stack.pop() as any;
        current_namespace: any = parent_namespace;
        if `node.type in ("namespace_declaration", "file_scoped_namespace_declaration") {
            for c in `node.children {
                if c.type in ("qualified_name", "identifier") {
                    text: any = _csharp_name(c);
                    if text {
                        current_namespace = f"{parent_namespace}.{text}"
                            if parent_namespace
                            else text;
                        namespaces.append(current_namespace);
                    }
                    break;
                }
            }
        }
        stack.extend((child, current_namespace) for child in reversed(`node.children));
    }
    return namespaces;
}

def file_hash(path: Path) -> str {
    return hashlib.sha256(path.read_bytes()).hexdigest();
}

def _hcl_text(`node) -> str {
    return `node.text.decode("utf-8", errors="replace");
}

def _hcl_child(`node, *types_: str) -> any {
    types: any = tuple(types_);
    return next((c for c in `node.children if c.type in types), None);
}

def _hcl_block_name(prefix: str, labels: list[str], n_labels: int) -> Optional[str] {
    if len(labels) < n_labels {
        return None;
    }
    return ".".join([prefix] + labels[:n_labels]);
}

glob _HCL_REF_PREFIXES: frozenset[str] = frozenset(
    ("var module local data each count self path terraform").split()
);

def _hcl_ref_target(`root: str, attrs: list[str], *, provider: bool = False) -> Optional[str] {
    if provider and `root not in {"each", "count", "self"} {
        return ".".join(["provider", `root] + attrs[:1]);
    }
    if `root == "var" and attrs {
        return f"var.{attrs[0]}";
    }
    if `root == "module" and attrs {
        return f"module.{attrs[0]}";
    }
    if `root == "local" and attrs {
        return f"local.{attrs[0]}";
    }
    if `root == "data" and len(attrs) >= 2 {
        return f"data.{attrs[0]}.{attrs[1]}";
    }
    if `root not in _HCL_REF_PREFIXES and attrs {
        return f"resource.{`root}.{attrs[0]}";
    }
    return None;
}

def _hcl_variable_refs(expr_node) -> Generator[any, any, any] {
    children: any = expr_node.children;
    i: any = 0;
    while i < len(children) {
        child: any = children[i];
        if child.type != "variable_expr" {
            i += 1;
            continue;
        }
        ident: any = _hcl_child(child, "identifier");
        if ident is None {
            i += 1;
            continue;
        }
        j: any;
        attrs: any;
        (j, attrs) = (i + 1, []);
        while j < len(children) and children[j].type == "get_attr" {
            id_node: any = _hcl_child(children[j], "identifier");
            if id_node {
                attrs.append(_hcl_text(id_node));
            }
            j += 1;
        }
        yield (_hcl_text(ident), attrs, child.start_point[0] + 1);
        i = j;
    }
}

glob _HCL_RECURSE_TYPES: frozenset[str] = frozenset(
    ("expression body block attribute tuple object object_elem collection_value template_expr "
        "for_expr for_tuple_expr for_object_expr for_intro for_cond conditional function_call "
        "function_arguments quoted_template template_interpolation").split(),
);

def _hcl_for_iterator_names(for_expr_node) -> frozenset[str] {
    stack: any = [for_expr_node];
    while stack {
        current: any = stack.pop();
        if current.type == "for_intro" {
            return frozenset(
                _hcl_text(child) for child in current.children if child.type == "identifier"
            );
        }
        stack.extend(reversed(current.children));
    }
    return frozenset();
}

def _hcl_dynamic_iterator_name(block_node) -> Optional[str] {
    id_node: any = _hcl_child(block_node, "identifier");
    if id_node is None or _hcl_text(id_node) != "dynamic" {
        return None;
    }
    default_name: Optional[str] = None;
    for child in block_node.children {
        if child.type == "string_lit" {
            tmpl: any = _hcl_child(child, "template_literal");
            default_name = _hcl_text(tmpl) if tmpl is not None else _hcl_text(child).strip("\"");
            break;
        }
    }
    if default_name is None {
        return None;
    }
    body_node: any = _hcl_child(block_node, "body");
    if body_node is not None {
        for attr in body_node.children {
            if attr.type != "attribute" {
                continue;
            }
            key: any = _hcl_child(attr, "identifier");
            if key is None or _hcl_text(key) != "iterator" {
                continue;
            }
            expr: any = _hcl_child(attr, "expression");
            if expr is None {
                continue;
            }
            raw: any = _hcl_text(expr).strip().strip("\"");
            if raw and raw.isidentifier() {
                return raw;
            }
        }
    }

    return default_name;
}

glob _HCL_BLOCK_CFG: dict[str, tuple[str, str, int, bool]] = {
    "resource": ("Class", "resource", 2, True),
    "data": ("Class", "data", 2, True),
    "module": ("Class", "module", 1, True),
    "variable": ("Function", "var", 1, False),
    "output": ("Function", "output", 1, True),
    "provider": ("Function", "provider", 1, True),
};

def _is_ansible_path(path: Path) -> bool {
    parts: any = {p.lower() for p in path.parts};
    return `bool(parts & _ANSIBLE_PATH_COMPONENTS) or path.name.lower() in _ANSIBLE_PLAYBOOK_NAMES;
}

def _is_ansible_content(source: bytes) -> bool {
    try {
        text: any = source.decode("utf-8", errors="replace");
    } except Exception {
        return False;
    }
    for line in text.splitlines() {
        stripped: any = line.strip();
        if not stripped or stripped.startswith("#") or stripped == "---" {
            continue;
        }
        if not (line.startswith("- ") or line == "-") {
            return False;
        }
        break;
    } else {
        return False;
    }
    has_hosts: any = `bool(re.search("^\\s+hosts\\s*:", text, re.MULTILINE));
    has_tasks: any = `bool(re.search("^\\s+tasks\\s*:", text, re.MULTILINE));
    has_handlers: any = `bool(re.search("^\\s+handlers\\s*:", text, re.MULTILINE));
    has_import_pb: any = `bool(re.search("^\\s+import_playbook\\s*:", text, re.MULTILINE));
    has_name: any = `bool(re.search("^\\s+-?\\s*name\\s*:", text, re.MULTILINE));
    has_module: any = `any(
        re.search(f"^\\s+{re.escape(k)}\\s*:", text, re.MULTILINE) for k in _ANSIBLE_MODULE_KEYS
    )
        or `bool(re.search("^\\s+ansible\\.\\w+\\.\\w+\\s*:", text, re.MULTILINE));
    return has_hosts or has_import_pb or has_tasks or has_handlers or has_name and has_module;
}

def _ansible_file_type(path: Path) -> str {
    parts_lower: any = [p.lower() for p in path.parts];
    name_lower: any = path.name.lower();
    if "meta" in parts_lower and name_lower in ("main.yml", "main.yaml") {
        return "meta";
    }
    if "handlers" in parts_lower {
        return "handlers";
    }
    if "tasks" in parts_lower {
        return "tasks";
    }
    if `any(p in parts_lower for p in ("group_vars", "host_vars", "vars", "defaults")) {
        return "vars";
    }
    if "playbooks" in parts_lower or name_lower in _ANSIBLE_PLAYBOOK_NAMES {
        return "playbook";
    }
    return "unknown";
}

def _ansible_fqcn_short(key: str) -> str {
    return key.rsplit(".", 1)[-1];
}

def _yaml_line(`node: object) -> int {
    return `node.start_mark.line + 1;
}

def _yaml_end_line(`node: object) -> int {
    mark: any = `node.end_mark;
    buffer: any;
    line_start: any;
    (buffer, line_start) = (mark.buffer, mark.pointer - mark.column);
    if buffer is None or buffer[line_start:mark.pointer].strip() {
        return mark.line + 1;
    }
    line: any = mark.line;
    while line > 1 {
        previous: any = buffer.rfind("\n", 0, line_start - 1) + 1;
        if buffer[previous:line_start].strip() {
            break;
        }
        line_start = previous;
        line -= 1;
    }
    return max(line, 1);
}

def _yaml_get_key(mapping_node: object, key: str) -> Optional[object] {
    for (k_node, v_node) in mapping_node.value {
        if isinstance(k_node, _YamlScalar) and k_node.value == key {
            return v_node;
        }
    }
    return None;
}

glob _JSON_VALUE_TYPES: any = {
    "array": "array",
    "false": "boolean",
    "null": "null",
    "number": "number",
    "object": "object",
    "string": "string",
    "true": "boolean",
};

glob _JSON_DATA_DIR_NAMES: any = frozenset(
    ("__fixtures__ __mocks__ __snapshots__ data datasets demo demos doc docs example examples "
        "fixtures mocks sample samples snapshots test-data test_data testdata").split(),
);

def _is_storable_key(key: str) -> bool {
    try {
        key.encode("utf-8");
    } except UnicodeEncodeError {
        return False;
    }
    return True;
}

def _json_key(key_node: Any) -> Optional[str] {
    if key_node is None or key_node.type != "string" {
        return None;
    }
    raw: any = key_node.text.decode("utf-8", errors="replace");
    try {
        key: any = json.loads(raw);
    } except ValueError {
        key = raw[1:-1];
    }
    return key if isinstance(key, `str) and _is_storable_key(key) else None;
}

def _yaml_scalar(`node: object) -> Optional[str] {
    if isinstance(`node, _YamlScalar) {
        return `node.value;
    }
    return None;
}

glob _HTML_SECTION_TAGS: any = frozenset({"article", "div", "section"});

glob _HTML_HEADING_TAGS: any = frozenset({"h1", "h2", "h3", "h4", "h5", "h6"});

glob _HTML_TEMPLATE_MARKERS: any = ("{{", "{%", "<%", "${");

glob _HTML_JAVASCRIPT_TYPES: any = frozenset({
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

glob _HTML_TYPESCRIPT_TYPES: any = frozenset({"application/typescript", "text/typescript"});

def _html_start_tag(element: Any) -> Any {
    for child in element.children {
        if child.type in ("start_tag", "self_closing_tag") {
            return child;
        }
    }
    return None;
}

def _html_tag_name(start_tag: Any) -> str {
    for child in start_tag.children {
        if child.type == "tag_name" {
            return child.text.decode("utf-8", errors="replace").lower();
        }
    }
    return "";
}

def _html_attributes(start_tag: Any) -> dict[str, str] {
    attributes: dict[str, str] = {};
    for attribute in start_tag.children {
        if attribute.type != "attribute" {
            continue;
        }
        name: any = "";
        value: any = "";
        for part in attribute.children {
            if part.type == "attribute_name" {
                name = part.text.decode("utf-8", errors="replace").lower();
            } elif part.type == "attribute_value" {
                value = part.text.decode("utf-8", errors="replace");
            } elif part.type == "quoted_attribute_value" {
                for inner in part.children {
                    if inner.type == "attribute_value" {
                        value = inner.text.decode("utf-8", errors="replace");
                    }
                }
            }
        }
        if name and name not in attributes {
            attributes[name] = html.unescape(value);
        }
    }
    return attributes;
}

def _html_script_language(attributes: dict[str, str]) -> Optional[str] {
    if attributes.get("lang", "").strip().lower() in ("ts", "typescript") {
        return "typescript";
    }
    script_type: any = attributes.get("type", "").split(";")[0].strip().lower();
    if script_type in _HTML_TYPESCRIPT_TYPES {
        return "typescript";
    }
    return "javascript" if script_type in _HTML_JAVASCRIPT_TYPES else None;
}

def _html_is_local_src(src: str) -> bool {
    if not src or src.startswith("//") or re.match("[A-Za-z][A-Za-z0-9+.-]*:", src) {
        return False;
    }
    return not `any(marker in src for marker in _HTML_TEMPLATE_MARKERS);
}

def _html_first_heading(element: Any, max_chars: int) -> Optional[str] {
    stack: any = `list(reversed(element.children));
    while stack {
        `node: any = stack.pop();
        if `node.type != "element" {
            continue;
        }
        start_tag: any = _html_start_tag(`node);
        tag: any = _html_tag_name(start_tag) if start_tag is not None else "";
        if tag in _HTML_HEADING_TAGS {
            pieces: list[str] = [];
            last_end: Optional[int] = None;
            parts: any = `list(reversed(`node.children));
            while parts {
                part: any = parts.pop();
                if part.type in ("text", "entity") {
                    if last_end is not None and part.start_byte != last_end {
                        pieces.append(" ");
                    }
                    pieces.append(part.text.decode("utf-8", errors="replace"));
                    last_end = part.end_byte;
                } else {
                    parts.extend(reversed(part.children));
                }
            }
            heading: any = " ".join(html.unescape("".join(pieces)).split());
            return heading[:max_chars] or None;
        }
        if tag in _HTML_SECTION_TAGS
            and start_tag is not None
            and _html_attributes(start_tag).get("id", "").strip()
        {
            continue;
        }
        stack.extend(reversed(`node.children));
    }
    return None;
}

glob _XSLT_NAMESPACE: any = "http://www.w3.org/1999/XSL/Transform";

glob _XSLT_NAMED_STEP_RE: any = re.compile("@?[^\\W\\d][\\w.-]*(?::[^\\W\\d][\\w.-]*)?");

def _xml_name(element: Any) -> str {
    for child in element.children {
        if child.type in ("STag", "EmptyElemTag") {
            for part in child.children {
                if part.type == "Name" {
                    return part.text.decode("utf-8", errors="replace");
                }
            }
        }
    }
    return "";
}

def _xml_attributes(element: Any) -> dict[str, str] {
    attributes: dict[str, str] = {};
    for child in element.children {
        if child.type not in ("STag", "EmptyElemTag") {
            continue;
        }
        for attribute in child.children {
            if attribute.type != "Attribute" {
                continue;
            }
            value_: any = "";
            name: any = value_;
            value: any = value_;
            for part in attribute.children {
                if part.type == "Name" {
                    name = part.text.decode("utf-8", errors="replace");
                } elif part.type == "AttValue" {
                    value = part.text.decode("utf-8", errors="replace")[1:-1];
                }
            }
            if name and name not in attributes {
                attributes[name] = html.unescape(value);
            }
        }
    }
    return attributes;
}

def _xml_scope(element: Any, parent: dict[str, str]) -> dict[str, str] {
    declared: any = {
        name[len("xmlns:"):] if name.startswith("xmlns:") else "": value
        for (name, value) in _xml_attributes(element).items()
        if name == "xmlns" or name.startswith("xmlns:")
    };
    return {**parent, **declared} if declared else parent;
}

def _xslt_local_name(element: Any, scope: dict[str, str]) -> str {
    prefix: any;
    _: any;
    local: any;
    (prefix, _, local) = _xml_name(element).rpartition(":") as any;
    return local if scope.get(prefix) == _XSLT_NAMESPACE else "";
}

def _xml_child_elements(element: Any) -> list[Any] {
    children: list[Any] = [];
    for child in element.children {
        if child.type == "element" {
            children.append(child);
        } elif child.type == "content" {
            children.extend(c for c in child.children if c.type == "element");
        }
    }
    return children;
}

def _xslt_split(expression: str, separator: str) -> list[str] {
    parts: list[str] = [];
    depth: any = 0;
    quote: any = "";
    current: list[str] = [];
    for char in expression {
        if quote {
            quote = "" if char == quote else quote;
        } elif char in "'\"" {
            quote = char;
        } elif char in "[(" {
            depth += 1;
        } elif char in "])" {
            depth -= 1;
        } elif char == separator and depth == 0 {
            parts.append("".join(current));
            current = [];
            continue;
        }
        current.append(char);
    }
    parts.append("".join(current));
    return parts;
}

def _xslt_named_steps(expression: str) -> set[str] {
    steps: set[str] = set[any]();
    for alternative in _xslt_split(expression, "|") {
        last: any = _xslt_split(alternative, "/")[-1].strip();
        last = last.split("[", 1)[0].strip();
        if last.startswith("child::") {
            last = last[len("child::"):];
        }
        if not _XSLT_NAMED_STEP_RE.fullmatch(last) {
            return set[any]();
        }
        steps.add(last);
    }
    return steps;
}

@dataclass
class _XsltTemplate {
    has element: Any;

    has scope: dict[str, str];

    has `node: NodeInfo;

    has qualified: str;

    has modes: set[str];

    has steps: set[str];

    has matches: bool {
        getter {
            return operator.ne(self.node.extra["xslt_kind"], "function")
                and "match" in self.node.extra;
        }
    }
}

glob _YAML_SIMPLE_PATH_SEGMENT: any = re.compile("^[A-Za-z_][A-Za-z0-9_-]*$");

glob _LOCALE_DIR_NAMES: any = frozenset({"i18n", "l10n", "locale", "locales", "translations"});

glob _LANGUAGE_TAG_RE: any = re.compile("([a-z]{2,3})(?:[-_@][a-z0-9]{2,8})*");

glob _LANGUAGE_CODES: any = frozenset(
    ("aa ab ae af ak am an ar as av ay az ba be bg bh bi bm bn bo br bs ca ce ch co cr cs cu "
        "cv cy da de dv dz ee el en eo es et eu fa ff fi fj fo fr fy ga gd gl gn gu gv ha he hi "
        "ho hr ht hu hy hz ia id ie ig ii ik io is it iu ja jv ka kg ki kj kk kl km kn ko kr ks "
        "ku kv kw ky la lb lg li ln lo lt lu lv mg mh mi mk ml mn mr ms mt my na nb nd ne ng nl "
        "nn no nr nv ny oc oj om or os pa pi pl ps pt qu rm rn ro ru rw sa sc sd se sg si sk sl "
        "sm sn so sq sr ss st su sv sw ta te tg th ti tk tl tn to tr ts tt tw ty ug uk ur uz ve "
        "vi vo wa wo xh yi yo za zh zu ast ceb ckb fil gsw haw hsb kab kmr nds sco szl tok tzl "
        "yue zgh").split(),
);

def _yaml_path_child(prefix: str, segment: str) -> str {
    if _YAML_SIMPLE_PATH_SEGMENT.fullmatch(segment) {
        return f"{prefix}.{segment}" if prefix else segment;
    }
    quoted: any = json.dumps(segment, ensure_ascii=False);
    return f"{prefix}[{quoted}]" if prefix else f"[{quoted}]";
}

def _yaml_value_type(`node: object) -> str {
    if isinstance(`node, _YamlMapping) {
        return "mapping";
    }
    if isinstance(`node, _YamlSequence) {
        return "sequence";
    }
    tag: any = `str(getattr(`node, "tag", ""));
    scalar_type: any = tag.rsplit(":", 1)[-1];
    if scalar_type in {"binary", "bool", "float", "int", "null", "str", "timestamp"} {
        return scalar_type;
    }
    return "scalar";
}

def _is_language_tag(text: str) -> bool {
    `match: any = _LANGUAGE_TAG_RE.fullmatch(text.lower());
    return `match is not None and `match.group(1) in _LANGUAGE_CODES;
}

def _is_locale_yaml(path: "str | PurePath", repo_root: "str | PurePath | None") -> bool {
    relative: any = repo_relative_path(path, repo_root);
    if relative is None {
        return False;
    }
    items_: any = list(relative.lower().split("/") as any);
    if len(items_) < 1 {
        raise ValueError(f"not enough values to unpack (expected at least 1, got {len(items_)})");
    }
    folders: any = items_[0:len(items_) - 1];
    filename: any = items_[len(items_) - 1];
    names: any = [folder.lstrip("_") for folder in folders];
    if not _LOCALE_DIR_NAMES.intersection(names) {
        return False;
    }
    if `any(_is_language_tag(part) for part in filename.split(".")[:-1]) {
        return True;
    }
    return `any(
        parent in _LOCALE_DIR_NAMES and _is_language_tag(child)
        for (parent, child) in zip(names, names[1:]),
    );
}

def _ansible_is_play_item(item: object) -> bool {
    if not isinstance(item, _YamlMapping) {
        return False;
    }
    keys: set[Optional[str]] = {
        _yaml_scalar(k)
        for (k, _) in item.value
        if isinstance(k, _YamlScalar)
    };
    if "import_playbook" in keys {
        return True;
    }
    return "hosts" in keys and `bool(keys & _ANSIBLE_PLAY_KEYS);
}

glob _POWERSHELL_NUMBER_PATTERN: any = "[+-]?(?:(?:0x[0-9a-f]+|0b[01]+)(?:u[ysl]?|[ysln])?|\\d+(?:u[ysl]?|[yslnd])?|(?:\\d+(?:\\.\\d*)?|\\.\\d+)(?:e[+-]?\\d+)?d?)(?:[kmgtp]b)?";

glob _POWERSHELL_RANGE_RE: any = re.compile(
    f"{_POWERSHELL_NUMBER_PATTERN}\\.\\.(?:{_POWERSHELL_NUMBER_PATTERN}|\\$.*)?", re.IGNORECASE
);

glob _POWERSHELL_SCOPE_RE: any = re.compile("^(?:global|local|private|script):", re.IGNORECASE);

glob _PLSQL_IDENT_RE: any = "[^\\W\\d][\\w$#]*";

glob _PLSQL_ROUTINE_RE: any = f"{_PLSQL_IDENT_RE}(?:\\.{_PLSQL_IDENT_RE})*(?![\\w$#])\\s*(?:\\((?:[^();]|\\([^()]*\\))*\\)\\s*)?";

glob local_names_default_: any = frozenset();

glob provider_attributes_default_: any = frozenset();

glob resolving_default_: any = frozenset();

glob resolving_default__: any = frozenset();

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

    static has _LARAVEL_ROUTE_VERBS: any = frozenset(
        ("get post put patch delete options any match resource apiResource").split()
    );

    static has _LARAVEL_RELATIONSHIPS: any = frozenset(
        ("hasMany hasOne belongsTo belongsToMany morphTo morphMany morphOne morphToMany "
            "morphedByMany hasManyThrough hasOneThrough").split(),
    );

    def init(repo_root: Optional[Path] = None) {
        self._repo_root = Path(repo_root).resolve() if repo_root is not None else None;
        self._dbt_model_paths_cache = {};
        self._parsers = {};
        self._module_file_cache = {};
        self._ignore_patterns_cache = {};
        self._indexed_path_cache = {};
        self._dir_entries_cache = {};
        self._go_module_cache = {};
        self._ruby_load_roots_cache = {};
        self._python_reexport_cache = {};
        self._python_module_alias_cache = {};
        self._excluded_files = set[any]();
        self._export_symbol_cache = {};
        self._tsconfig_resolver = TsconfigResolver();
        self._workspace_resolver = WorkspaceResolver(
            repo_root=self._repo_root, file_exists=self._file_exists_exact
        );
        self._npm_alias_resolver = NpmAliasResolver(
            self._repo_root,
            package_resolver=self._workspace_resolver,
            path_is_indexed=self._npm_alias_path_is_indexed,
        );
        self._dart_pubspec_cache = {};
        self._rust_project_cache = {};
        self._extension_map = EXTENSION_TO_LANGUAGE;
        self._class_types = _CLASS_TYPES;
        self._function_types = _FUNCTION_TYPES;
        self._import_types = _IMPORT_TYPES;
        self._call_types = _CALL_TYPES;
        self._node_type_sets = {};
        self._custom_languages = {};
        if repo_root is not None {
            self._custom_languages = load_custom_languages(
                Path(repo_root),
                builtin_extensions=EXTENSION_TO_LANGUAGE,
                builtin_languages=_builtin_language_names(),
            );
        }
        if self._custom_languages {
            self._extension_map = `dict(EXTENSION_TO_LANGUAGE);
            self._class_types = `dict(_CLASS_TYPES);
            self._function_types = `dict(_FUNCTION_TYPES);
            self._import_types = `dict(_IMPORT_TYPES);
            self._call_types = `dict(_CALL_TYPES);
            for custom in self._custom_languages.values() {
                for ext in custom.extensions {
                    self._extension_map[ext] = custom.name;
                }
                self._class_types[custom.name] = `list(custom.class_node_types);
                self._function_types[custom.name] = `list(custom.function_node_types);
                self._import_types[custom.name] = `list(custom.import_node_types);
                self._call_types[custom.name] = `list(custom.call_node_types);
            }
        }
    }

    def _get_parser(language: str) -> any {
        if language not in self._parsers {
            custom: any = self._custom_languages.get(language);
            grammar: any = custom.grammar if custom is not None else language;
            parser: any = _load_tree_sitter_parser(grammar);
            if parser is None {
                return None;
            }
            self._parsers[language] = parser;
        }
        return self._parsers[language];
    }

    def clear_caches(include_parsers: bool = False, release_memory: bool = True) {
        self._dbt_model_paths_cache.clear();
        self._module_file_cache.clear();
        self._ignore_patterns_cache.clear();
        self._indexed_path_cache.clear();
        self._dir_entries_cache.clear();
        self._go_module_cache.clear();
        self._ruby_load_roots_cache.clear();
        self._python_reexport_cache.clear();
        self._export_symbol_cache.clear();
        self._dart_pubspec_cache.clear();
        self._rust_project_cache.clear();
        self._tsconfig_resolver = TsconfigResolver();
        if include_parsers {
            self._parsers.clear();
        }
        with _PYTHON_STAR_EXPORT_CACHE_LOCK {
            _PYTHON_STAR_EXPORT_CACHE.clear();
        }
        with _PYTHON_RETURN_ANNOTATION_CACHE_LOCK {
            _PYTHON_RETURN_ANNOTATION_CACHE.clear();
        }
        for _cached_fn in (
            _read_cargo_manifest,
            _python_unreachable_call_positions,
            _read_go_mod,
            _read_gemspec_require_paths,
            _read_php_composer_psr4,
            _repo_root_prefixes,
            _resolved_dir,
            _is_python_package_dir,
        ) {
            _cached_fn.cache_clear();
        }
        if release_memory {
            release_os_memory();
        }
    }

    def detect_language(path: Path, source: Optional[bytes] = None) -> Optional[str] {
        if path.name.lower().endswith(".blade.php") {
            return "blade";
        }
        suffix: any = path.suffix.lower();
        lang: any = self._extension_map.get(suffix);
        if lang == "yaml" and _is_ansible_path(path) {
            return "ansible";
        }
        if lang in ("properties", "yaml") and is_spring_config_path(path) {
            return "spring_config";
        }
        if lang == "properties" {
            return None;
        }
        if lang is not None {
            return lang;
        }
        if suffix == "" {
            head: any = source[:_SHEBANG_PROBE_BYTES] if source is not None else None;
            return self._detect_language_from_shebang(path, head);
        }
        return None;
    }

    static def _detect_language_from_shebang(
        path: Path, head: Optional[bytes] = None
    ) -> Optional[str] {
        if head is None {
            try {
                fh: any;
                with path.open("rb") as fh {
                    head = fh.read(_SHEBANG_PROBE_BYTES);
                }
            } except (OSError, PermissionError) {
                return None;
            }
        }
        if not head.startswith(b"#!") {
            return None;
        }
        first_line: any = head.split(b"\n", 1)[0].split(b"\x00", 1)[0];
        try {
            line: any = first_line[2:].decode("utf-8", errors="strict").strip();
        } except UnicodeDecodeError {
            return None;
        }
        if not line {
            return None;
        }

        tokens: any = line.split();
        if not tokens {
            return None;
        }

        first: any = tokens[0];
        if first.endswith("/env") or first == "env" {
            interpreter_token: Optional[str] = None;
            for tok in tokens[1:] {
                if tok.startswith("-") {
                    continue;
                }
                interpreter_token = tok;
                break;
            }
            if interpreter_token is None {
                return None;
            }
            interpreter: any = interpreter_token.rsplit("/", 1)[-1];
        } else {
            interpreter = first.rsplit("/", 1)[-1];
        }

        return SHEBANG_INTERPRETER_TO_LANGUAGE.get(interpreter);
    }

    def _is_test_path(path: "str | PurePath") -> bool {
        return is_test_file(path, self._repo_root);
    }

    def parse_file(path: Path) -> tuple[list[NodeInfo], list[EdgeInfo]] {
        try {
            source: any = path.read_bytes();
        } except (OSError, PermissionError) {
            return ([], []);
        }
        return self.parse_bytes(path, source);
    }

    def parse_bytes(path: Path, source: bytes) -> tuple[list[NodeInfo], list[EdgeInfo]] {
        nodes: any;
        edges: any;
        (nodes, edges) = self._extract_bytes(path, source) as any;
        fallback_path: any = normalize_file_path(path);
        for `node in nodes {
            if not `node.is_test and self._is_test_path(`node.file_path or fallback_path) {
                `node.is_test = True;
            }
        }
        return (nodes, edges);
    }

    def _extract_bytes(path: Path, source: bytes) -> tuple[list[NodeInfo], list[EdgeInfo]] {
        language: any = self.detect_language(path, source);
        if not language {
            return ([], []);
        }

        parser: any = None;
        tree: any = None;
        parse_source: any = source;
        if language == "c" and path.suffix.lower() == ".h" {
            if self._has_cpp_header_text_evidence(source) {
                cpp_parser: any = self._get_parser("cpp");
                if cpp_parser is not None {
                    cpp_source: any = self._mask_cpp_qt_macros(source);
                    cpp_tree: any = cpp_parser.parse(cpp_source);
                    if self._has_cpp_header_evidence(cpp_tree.root_node) {
                        language = "cpp";
                        parser = cpp_parser;
                        tree = cpp_tree;
                        parse_source = cpp_source;
                    }
                }
            }
        } elif language == "cpp" {
            parse_source = self._mask_cpp_qt_macros(source);
        }

        if language == "blade" {
            return self._parse_blade(path, source);
        }
        if language == "liquid" {
            return self._parse_liquid(path, source);
        }
        if language == "vue" {
            return self._parse_vue(path, source);
        }
        if language == "svelte" {
            return self._parse_svelte(path, source);
        }
        if language == "html" {
            return self._parse_html(path, source);
        }
        if language == "xslt" {
            return self._parse_xslt(path, source);
        }
        if language == "notebook" {
            return self._parse_notebook(path, source);
        }
        if language == "python" {
            first_newline: any = source.find(b"\n");
            first_line: any = source[:first_newline].rstrip(b"\r")
                if first_newline != -1
                else source.rstrip(b"\r");
            if first_line == b"# Databricks notebook source" {
                return self._parse_databricks_py_notebook(path, source);
            }
        }
        if language == "vbnet" {
            return self._parse_vbnet(path, source);
        }
        if language == "rescript" {
            return self._parse_rescript(path, source);
        }
        if language == "robot" {
            return self._parse_robot(path, source);
        }
        if language == "sql" {
            return self._parse_sql(path, source);
        }
        if language == "ansible" {
            if _yaml is None {
                return ([], []);
            }
            file_type: any = _ansible_file_type(path);
            if file_type in ("vars", "meta") or _is_ansible_content(source) {
                return self._parse_ansible(path, source);
            }
            return self._parse_yaml(path, source);
        }
        if language == "spring_config" {
            if _yaml is None {
                return ([], []);
            }
            is_yaml: any = path.suffix.lower() in (".yaml", ".yml");
            if is_yaml and _is_locale_yaml(path, self._repo_root) {
                return self._parse_yaml(path, source);
            }
            if is_yaml and _is_ansible_content(source) {
                return self._parse_ansible(path, source);
            }
            spring_nodes: any;
            spring_edges: any;
            (spring_nodes, spring_edges) = self._parse_spring_config(path, source) as any;
            if spring_nodes or path.suffix.lower() == ".properties" {
                return (spring_nodes, spring_edges);
            }
            return self._parse_yaml(path, source);
        }
        if language == "yaml" {
            if _yaml is None {
                return ([], []);
            }
            return self._parse_yaml(path, source);
        }
        if language == "json" {
            return self._parse_json(path, source);
        }

        if parser is None {
            parser = self._get_parser(language);
        }
        if not parser {
            return ([], []);
        }

        if tree is None {
            tree = parser.parse(parse_source);
        }
        nodes: list[NodeInfo] = [];
        edges: list[EdgeInfo] = [];
        file_path_str: any = normalize_file_path(path);
        test_file: any = self._is_test_path(file_path_str);
        file_extra: dict = {};
        if language == "csharp" {
            ns_list: any = _csharp_namespaces(tree.root_node);
            if ns_list {
                file_extra["csharp_namespaces"] = ns_list;
            }
        }
        if language == "php" {
            php_namespaces: any = _php_namespaces(tree.root_node);
            if php_namespaces {
                file_extra["php_namespaces"] = php_namespaces;
            }
        }
        nodes.append(
            NodeInfo(
                "File",
                file_path_str,
                file_path_str,
                1,
                source.count(b"\n") + 1,
                language=language,
                is_test=test_file,
                extra=file_extra,
            ),
        );
        import_map: any;
        defined_names: any;
        (import_map, defined_names) = self._collect_file_scope(
            tree.root_node, language, source, file_path_str
        ) as any;
        self._index_ambiguous_method_scopes(tree.root_node, language, import_map);
        if language == "python" {
            self._expand_python_star_imports(tree.root_node, file_path_str, import_map);
        }

        typed_call_targets: any = self._collect_typed_call_targets(
            tree.root_node, language, file_path_str, import_map, defined_names
        );
        if language == "python" {
            python_receiver_evidence: any;
            python_property_read_edges: any;
            (
                python_receiver_evidence,
                python_property_read_edges,
            ) = self._collect_python_receiver_evidence(
                tree.root_node, file_path_str, source
            ) as any;
        } else {
            python_receiver_evidence = {};
            python_property_read_edges = [];
        }
        self._extract_from_tree(
            tree.root_node,
            source,
            language,
            file_path_str,
            nodes,
            edges,
            import_map=import_map,
            defined_names=defined_names,
        );

        if language == "elixir" {
            (nodes, edges) = self._merge_elixir_clauses(nodes, edges) as any;
        }
        if language == "ruby" and test_file {
            edges = self._apply_ruby_test_receivers(
                edges, self._collect_ruby_test_receivers(tree.root_node)
            );
        }

        if language == "php" {
            self._extract_php_laravel_edges(tree.root_node, file_path_str, nodes, edges);
            edges = self._resolve_php_scoped_calls(tree.root_node, nodes, edges, file_path_str);
        }

        edges = self._apply_typed_call_targets(edges, typed_call_targets, language);
        if language == "csharp" {
            `edge: any;
            for `edge in edges {
                if `edge.kind != "CALLS" {
                    continue;
                }
                receiver: any = `edge.extra.get("receiver_scope") or `edge.extra.get("receiver");
                if receiver {
                    `edge.target = f"{receiver}::{`edge.target}";
                }
                `edge.extra["csharp_raw_target"] = `edge.target;
            }
        }

        if language == "python" {
            edges = self._apply_python_receiver_evidence(edges, python_receiver_evidence);
            edges.extend(python_property_read_edges);
        }
        edges = self._resolve_call_targets(nodes, edges, file_path_str);

        if language == "java" {
            edges = self._qualify_java_same_package_constructors(edges, file_path_str, import_map);
            if test_file {
                edges = self._mark_java_unknown_test_receivers(edges);
            }
        }
        test_qnames: any = set[any]();
        for n in nodes {
            if n.is_test {
                qn: any = self._node_qualified(n);
                test_qnames.add(qn);
            }
        }
        if test_qnames {
            for `edge in `list(edges) {
                if `edge.kind == "CALLS" and `edge.source in test_qnames {
                    edges.append(
                        EdgeInfo(
                            "TESTED_BY",
                            `edge.target,
                            `edge.source,
                            `edge.file_path,
                            `edge.line,
                            extra=`edge.extra.copy(),
                        ),
                    );
                }
            }
        }

        return (nodes, edges);
    }

    static def _has_cpp_header_evidence(`root) -> bool {
        child: any;
        pending: any = [(`root, False)];
        while pending {
            `node: any;
            in_dead_guard: any;
            (`node, in_dead_guard) = pending.pop() as any;
            if `node.type == "ERROR" or in_dead_guard {
                continue;
            }

            previous: any = `node.prev_named_sibling;
            recovered_after_error: any = previous is not None
                and operator.eq(previous.type, "ERROR")
                and operator.eq(previous.end_byte, `node.start_byte);
            if recovered_after_error {
                continue;
            }

            if `node.type in _CPP_HEADER_EVIDENCE_TYPES {
                return True;
            }
            if `node.type == "enum_specifier"
                and `any(child.type in ("class", "struct") for child in `node.children)
            {
                return True;
            }
            if `node.type == "type_qualifier" and `node.text in _CPP_HEADER_EVIDENCE_QUALIFIERS {
                return True;
            }
            for child in `node.named_children {
                pending.append((child, in_dead_guard or _is_static_dead_guard_child(`node, child)));
            }
        }
        return False;
    }

    static def _has_cpp_header_text_evidence(source: bytes) -> bool {
        code: any = _CPP_HEADER_NON_CODE_RE.sub(b" ", source);
        return _CPP_HEADER_TEXT_EVIDENCE_RE.search(code) is not None;
    }

    static def _mask_cpp_qt_macros(source: bytes) -> bytes {
        if b"Q_" not in source and b"QT_" not in source {
            return source;
        }
        masked: any = bytearray(source);
        length: any = len(source);
        index: any = 0;
        line_has_code: any = False;

        def skip_quoted(start: int, quote: int) -> int {
            cursor: any = start + 1;
            while cursor < length {
                if source[cursor] == ord("\\") {
                    cursor += 2;
                } elif source[cursor] == quote {
                    return cursor + 1;
                } else {
                    cursor += 1;
                }
            }
            return length;
        }

        def raw_string_end(start: int) -> Optional[int] {
            for prefix in (b"u8R\"", b"LR\"", b"UR\"", b"uR\"", b"R\"") {
                if not source.startswith(prefix, start) {
                    continue;
                }
                delimiter_start: any = start + len(prefix);
                opening: any = source.find(b"(", delimiter_start, delimiter_start + 17);
                if opening == -1 {
                    return None;
                }
                delimiter: any = source[delimiter_start:opening];
                if `any(byte in b" ()\\\t\r\n" for byte in delimiter) {
                    return None;
                }
                closing: any = source.find(b")" + delimiter + b"\"", opening + 1);
                return length if closing == -1 else closing + len(delimiter) + 2;
            }
            return None;
        }

        while index < length {
            byte: any = source[index];
            if byte == ord("\n") {
                line_has_code = False;
                index += 1;
                continue;
            }

            if source.startswith(b"//", index) {
                newline: any = source.find(b"\n", index + 2);
                index = length if newline == -1 else newline;
                continue;
            }
            if source.startswith(b"/*", index) {
                closing: any = source.find(b"*/", index + 2);
                comment_end: any = length if closing == -1 else closing + 2;
                if b"\n" in source[index:comment_end] {
                    line_has_code = False;
                }
                index = comment_end;
                continue;
            }

            if byte == ord("#") and not line_has_code {
                cursor: any = index;
                while cursor < length {
                    newline = source.find(b"\n", cursor);
                    if newline == -1 {
                        cursor = length;
                        break;
                    }
                    previous: any = newline - 1;
                    if previous >= cursor and source[previous] == ord("\r") {
                        previous -= 1;
                    }
                    if previous < cursor or source[previous] != ord("\\") {
                        cursor = newline;
                        break;
                    }
                    cursor = newline + 1;
                }
                index = cursor;
                continue;
            }

            raw_end: any = raw_string_end(index);
            if raw_end is not None {
                line_has_code = True;
                index = raw_end;
                continue;
            }
            if byte in (ord("\""), ord("'")) {
                line_has_code = True;
                index = skip_quoted(index, byte);
                continue;
            }

            if byte == ord("_") or chr(byte).isalpha() {
                end: any = index + 1;
                while end < length {
                    candidate: any = source[end];
                    if candidate != ord("_") and not chr(candidate).isalnum() {
                        break;
                    }
                    end += 1;
                }
                token: any = source[index:end];
                replacement: any = _CPP_QT_STRUCTURAL_MACRO_REPLACEMENTS.get(token);
                if replacement is not None {
                    masked[index:end] = replacement;
                }
                line_has_code = True;
                index = end;
                continue;
            }

            if byte not in b" \t\x0b\x0c\r" {
                line_has_code = True;
            }
            index += 1;
        }

        return `bytes(masked);
    }

    class def _mask_blade_comments(text: str) -> str {
        def replace_comment(`match: re.Match[str]) -> str {
            return "".join(char if char in "\r\n" else " " for char in `match.group(0));
        }

        return cls._BLADE_COMMENT_RE.sub(replace_comment, text);
    }

    def _parse_blade(path: Path, source: bytes) -> tuple[list[NodeInfo], list[EdgeInfo]] {
        text: any = source.decode("utf-8", errors="replace");
        masked: any = self._mask_blade_comments(text);
        file_path: any = normalize_file_path(path);
        nodes: any = [
            NodeInfo(
                "File",
                file_path,
                file_path,
                1,
                source.count(b"\n") + 1,
                language="blade",
                is_test=self._is_test_path(file_path),
            ),
        ];
        edges: list[EdgeInfo] = [];
        for `match in self._BLADE_DIRECTIVE_RE.finditer(masked) {
            directive: any = `match.group(1);
            target: any = `match.group(3);
            edges.append(
                EdgeInfo(
                    "REFERENCES" if directive == "livewire" else "IMPORTS_FROM",
                    file_path,
                    target,
                    file_path,
                    masked.count("\n", 0, `match.start()) + 1,
                    extra={"blade_directive": directive},
                ),
            );
        }
        return (nodes, edges);
    }

    static def _blank_liquid_span(`match: re.Match[str]) -> str {
        return "".join(character if character in "\r\n" else " " for character in `match.group(0));
    }

    def _liquid_statements(masked: str) -> Generator[any, any, any] {
        for tag in self._LIQUID_TAG_RE.finditer(masked) {
            if tag.group(1) != "liquid" {
                yield (tag.group(1), tag.group(2), tag.start(2));
                continue;
            }
            offset: any = tag.start(2);
            in_comment: any = False;
            for line in tag.group(2).split("\n") {
                words: any = line.split(maxsplit=1);
                directive: any = words[0] if words else "";
                if directive == "comment" {
                    in_comment = True;
                } elif directive == "endcomment" {
                    in_comment = False;
                } elif directive and not directive.startswith("#") and not in_comment {
                    yield (directive, words[1] if len(words) > 1 else "", offset);
                }
                offset += len(line) + 1;
            }
        }
    }

    def _resolve_liquid_snippet(path: Path, name: str) -> Optional[str] {
        if self._repo_root is None or not path.resolve().is_relative_to(self._repo_root) {
            return None;
        }
        if ".." in Path(name).parts or Path(name).is_absolute() {
            return None;
        }
        filename: any = name if name.endswith(".liquid") else f"{name}.liquid";
        directory: any = path.parent;
        while True {
            candidate: any = directory / "snippets" / filename;
            if self._file_exists_exact(candidate) {
                return normalize_file_path(candidate);
            }
            if directory.resolve() == self._repo_root or directory.parent == directory {
                return None;
            }
            directory = directory.parent;
        }
    }

    def _liquid_output_name(expression: str) -> str {
        if len(expression) <= self._LIQUID_MAX_OUTPUT_NAME {
            return f"output:{expression}";
        }
        digest: any = hashlib.sha256(expression.encode("utf-8")).hexdigest()[:8];
        return f"output:{expression[:self._LIQUID_MAX_OUTPUT_NAME]}#{digest}";
    }

    def _parse_liquid(path: Path, source: bytes) -> tuple[list[NodeInfo], list[EdgeInfo]] {
        text: any = source.decode("utf-8", errors="replace");
        masked: any = self._LIQUID_LITERAL_RE.sub(CodeParser._blank_liquid_span, text);
        file_path: any = normalize_file_path(path);
        nodes: any = [
            NodeInfo(
                "File",
                file_path,
                file_path,
                1,
                source.count(b"\n") + 1,
                language="liquid",
                is_test=self._is_test_path(file_path),
            ),
        ];
        edges: list[EdgeInfo] = [];

        def line_at(offset: int) -> int {
            return masked.count("\n", 0, offset) + 1;
        }
        children: dict[str, tuple[str, list[int], int]] = {};

        for (directive, arguments, offset) in self._liquid_statements(masked) {
            if directive == "assign" {
                assign: any = self._LIQUID_ASSIGN_RE.match(arguments);
                if assign {
                    line: any = line_at(offset);
                    children.setdefault(assign.group(1), ("Variable", [], line))[1].append(line);
                }
            } elif directive in ("render", "include") {
                target: any = self._LIQUID_TARGET_RE.match(arguments);
                if target {
                    edges.append(
                        EdgeInfo(
                            "IMPORTS_FROM",
                            file_path,
                            self._resolve_liquid_snippet(path, target.group(2)) or target.group(2),
                            file_path,
                            line_at(offset),
                            extra={"liquid_directive": directive},
                        ),
                    );
                }
            }
        }
        for `match in self._LIQUID_OUTPUT_RE.finditer(
            self._LIQUID_TAG_RE.sub(CodeParser._blank_liquid_span, masked)
        ) {
            expression: any = " ".join(`match.group(1).split());
            if expression {
                children.setdefault(
                    self._liquid_output_name(expression), ("Output", [], line_at(`match.end()))
                )[1].append(line_at(`match.start()));
            }
        }

        for (name, (kind, lines, line_end)) in children.items() {
            nodes.append(
                NodeInfo(
                    kind,
                    name,
                    file_path,
                    lines[0],
                    line_end,
                    language="liquid",
                    extra={"lines": lines} if len(lines) > 1 else {},
                ),
            );
            edges.append(
                EdgeInfo("CONTAINS", file_path, f"{file_path}::{name}", file_path, lines[0])
            );
        }

        return (nodes, edges);
    }

    def _add_tested_by(nodes: list[NodeInfo], edges: list[EdgeInfo]) {
        test_qnames: any = {
            self._qualify(n.name, n.file_path, n.parent_name)
            for n in nodes
            if n.is_test
        };
        for `edge in `list(edges) {
            if `edge.kind == "CALLS" and `edge.source in test_qnames {
                edges.append(
                    EdgeInfo("TESTED_BY", `edge.target, `edge.source, `edge.file_path, `edge.line)
                );
            }
        }
    }

    def _parse_vue(path: Path, source: bytes) -> tuple[list[NodeInfo], list[EdgeInfo]] {
        return self._parse_sfc(path, source, "vue");
    }

    def _parse_svelte(path: Path, source: bytes) -> tuple[list[NodeInfo], list[EdgeInfo]] {
        return self._parse_sfc(path, source, "svelte");
    }

    def _parse_sfc(
        path: Path, source: bytes, language: str
    ) -> tuple[list[NodeInfo], list[EdgeInfo]] {
        sfc_parser: any = self._get_parser(language) or self._get_parser("vue");
        if not sfc_parser {
            return ([], []);
        }

        tree: any = sfc_parser.parse(source);
        file_path_str: any = normalize_file_path(path);
        test_file: any = self._is_test_path(file_path_str);

        all_nodes: list[NodeInfo] = [
            NodeInfo(
                "File",
                file_path_str,
                file_path_str,
                1,
                source.count(b"\n") + 1,
                language=language,
                is_test=test_file,
            ),
        ];
        all_edges: list[EdgeInfo] = [];
        for child in tree.root_node.children {
            if child.type != "script_element" {
                continue;
            }
            script_lang: any = "javascript";
            start_tag: any = None;
            raw_text_node: any = None;
            for sub in child.children {
                if sub.type == "start_tag" {
                    start_tag = sub;
                } elif sub.type == "raw_text" {
                    raw_text_node = sub;
                }
            }

            if start_tag {
                for attr in start_tag.children {
                    if attr.type == "attribute" {
                        attr_name: any = None;
                        attr_value: any = None;
                        for a in attr.children {
                            if a.type == "attribute_name" {
                                attr_name = a.text.decode("utf-8", errors="replace");
                            } elif a.type == "quoted_attribute_value" {
                                for v in a.children {
                                    if v.type == "attribute_value" {
                                        attr_value = v.text.decode("utf-8", errors="replace");
                                    }
                                }
                            }
                        }
                        if attr_name == "lang" and attr_value in ("ts", "typescript") {
                            script_lang = "typescript";
                        }
                    }
                }
            }

            if not raw_text_node {
                continue;
            }

            script_source: any = raw_text_node.text;
            line_offset: any = raw_text_node.start_point[0];
            script_parser: any = self._get_parser(script_lang);
            if not script_parser {
                continue;
            }

            script_tree: any = script_parser.parse(script_source);
            import_map: any;
            defined_names: any;
            (import_map, defined_names) = self._collect_file_scope(
                script_tree.root_node, script_lang, script_source, file_path_str
            ) as any;

            nodes: list[NodeInfo] = [];
            edges: list[EdgeInfo] = [];
            self._extract_from_tree(
                script_tree.root_node,
                script_source,
                script_lang,
                file_path_str,
                nodes,
                edges,
                import_map=import_map,
                defined_names=defined_names,
            );
            for `node in nodes {
                `node.line_start += line_offset;
                `node.line_end += line_offset;
                `node.language = language;
            }
            `edge: any;
            for `edge in edges {
                `edge.line += line_offset;
            }

            all_nodes.extend(nodes);
            all_edges.extend(edges);
        }
        if test_file {
            self._add_tested_by(all_nodes, all_edges);
        }

        return (all_nodes, all_edges);
    }

    def _parse_html(path: Path, source: bytes) -> tuple[list[NodeInfo], list[EdgeInfo]] {
        html_parser: any = self._get_parser("html");
        if not html_parser {
            return ([], []);
        }

        file_path_str: any = normalize_file_path(path);
        test_file: any = self._is_test_path(file_path_str);
        file_node: any = NodeInfo(
            "File",
            file_path_str,
            file_path_str,
            1,
            source.count(b"\n") + 1,
            language="html",
            is_test=test_file,
        );
        if len(source) > self._MAX_HTML_BYTES {
            file_node.extra["html_truncated"] = True;
            return ([file_node], []);
        }

        tree: any = html_parser.parse(source);
        all_nodes: list[NodeInfo] = [file_node];
        all_edges: list[EdgeInfo] = [];
        scripts: list[Any] = [];
        sections: dict[str, NodeInfo] = {};
        handlers: list[tuple[str, str, int]] = [];
        stack: any = [tree.root_node];
        while stack {
            `node: any = stack.pop();
            if `node.type == "script_element" {
                scripts.append(`node);
                continue;
            }
            if `node.type == "style_element" {
                continue;
            }
            if `node.type == "element"
                or `node.type in ("start_tag", "self_closing_tag")
                    and `node.parent is not None
                    and `node.parent.type == "ERROR"
            {
                start_tag: any = `node if `node.type != "element" else _html_start_tag(`node);
                if start_tag is not None {
                    attributes: any = _html_attributes(start_tag);
                    line: any = start_tag.start_point[0] + 1;
                    value: any;
                    for (name, value) in attributes.items() {
                        if name.startswith("on") and value {
                            handlers.append((name, value, line));
                        }
                    }
                    self._add_html_section(
                        `node,
                        _html_tag_name(start_tag),
                        attributes,
                        file_path_str,
                        test_file,
                        sections,
                        file_node,
                    );
                }
            }
            stack.extend(reversed(`node.children));
        }

        for section in sections.values() {
            all_nodes.append(section);
            all_edges.append(
                EdgeInfo(
                    "CONTAINS",
                    file_path_str,
                    self._qualify(section.name, file_path_str, None),
                    file_path_str,
                    section.line_start,
                ),
            );
        }

        classic_nodes: any = self._extract_html_scripts(
            scripts, file_path_str, all_nodes, all_edges
        );
        page_functions: any = {
            `node.name: self._qualify(`node.name, file_path_str, None)
            for `node in classic_nodes
            if `node.kind in ("Function", "Test") and not `node.parent_name
        };
        for (event, value, line) in handlers if page_functions else [] {
            seen: set[str] = set[any]();
            for called in self._html_handler_calls(value) {
                if called in page_functions and called not in seen {
                    seen.add(called);
                    all_edges.append(
                        EdgeInfo(
                            "CALLS",
                            file_path_str,
                            page_functions[called],
                            file_path_str,
                            line,
                            extra={"html_event": event},
                        ),
                    );
                }
            }
        }
        test_qnames: any = {
            self._qualify(n.name, n.file_path, n.parent_name)
            for n in all_nodes
            if n.is_test and n.kind != "File"
        };
        if test_qnames {
            for `edge in `list(all_edges) {
                if `edge.kind == "CALLS" and `edge.source in test_qnames {
                    all_edges.append(
                        EdgeInfo(
                            "TESTED_BY", `edge.target, `edge.source, `edge.file_path, `edge.line
                        ),
                    );
                }
            }
        }

        return (all_nodes, all_edges);
    }

    def _add_html_section(
        element: Any,
        tag: str,
        attributes: dict[str, str],
        file_path: str,
        test_file: bool,
        sections: dict[str, NodeInfo],
        file_node: NodeInfo,
    ) {
        html_id: any = attributes.get("id", "").strip();
        if tag not in _HTML_SECTION_TAGS
            or not html_id
            or `any(marker in html_id for marker in _HTML_TEMPLATE_MARKERS)
        {
            return;
        }
        name: any = f"#{html_id}";
        existing: any = sections.get(name);
        if existing is not None {
            existing.extra["html_id_occurrences"] += 1;
            return;
        }
        if len(sections) >= self._MAX_HTML_SECTIONS {
            file_node.extra["html_truncated"] = True;
            return;
        }
        extra: dict[str, Any] = {"html_id": html_id, "html_tag": tag, "html_id_occurrences": 1};
        heading: any = _html_first_heading(element, self._MAX_HTML_HEADING_CHARS);
        if heading {
            extra["docstring"] = heading;
        }
        sections[name] = NodeInfo(
            "DocSection",
            name,
            file_path,
            element.start_point[0] + 1,
            element.end_point[0] + 1,
            language="html",
            is_test=test_file,
            extra=extra,
        );
    }

    def _extract_html_scripts(
        scripts: list[Any], file_path: str, all_nodes: list[NodeInfo], all_edges: list[EdgeInfo]
    ) -> list[NodeInfo] {
        blocks: list[tuple[Any, bytes, str, int, dict[str, str], set[str], bool]] = [];
        shared_imports: dict[str, str] = {};
        shared_names: set[str] = set[any]();
        for script in scripts {
            start_tag: any = _html_start_tag(script);
            attributes: any = _html_attributes(start_tag) if start_tag is not None else {};
            if "src" in attributes {
                self._add_html_script_import(
                    attributes["src"], file_path, script.start_point[0] + 1, all_edges
                );
                continue;
            }
            script_lang: any = _html_script_language(attributes);
            raw_text: any = next(
                (child for child in script.children if child.type == "raw_text"), None
            );
            if script_lang is None or raw_text is None or not raw_text.text.strip() {
                continue;
            }
            script_parser: any = self._get_parser(script_lang);
            if not script_parser {
                continue;
            }
            script_tree: any = script_parser.parse(raw_text.text);
            import_map: any;
            defined_names: any;
            (import_map, defined_names) = self._collect_file_scope(
                script_tree.root_node, script_lang, raw_text.text, file_path
            ) as any;
            is_module: any = operator.eq(attributes.get("type", "").strip().lower(), "module");
            blocks.append((
                script_tree.root_node,
                raw_text.text,
                script_lang,
                raw_text.start_point[0],
                import_map,
                defined_names,
                is_module,
            ));
            if not is_module {
                shared_imports.update(import_map);
                shared_names |= defined_names;
            }
        }

        extracted: list[tuple[list[NodeInfo], list[EdgeInfo], dict[str, str], bool]] = [];
        classic_nodes: list[NodeInfo] = [];
        for (
            `root,
            text,
            script_lang,
            line_offset,
            import_map,
            defined_names,
            is_module,
        ) in blocks {
            nodes: list[NodeInfo] = [];
            edges: list[EdgeInfo] = [];
            self._extract_from_tree(
                `root,
                text,
                script_lang,
                file_path,
                nodes,
                edges,
                import_map={**shared_imports, **import_map},
                defined_names=shared_names - import_map.keys() | defined_names,
            );
            for `node in nodes {
                `node.line_start += line_offset;
                `node.line_end += line_offset;
                `node.language = "html";
            }
            for `edge in edges {
                `edge.line += line_offset;
            }
            extracted.append((nodes, edges, import_map, is_module));
            if not is_module {
                classic_nodes.extend(nodes);
            }
        }
        for (nodes, edges, import_map, is_module) in extracted {
            visible: any = classic_nodes;
            if is_module {
                visible = nodes + [
                    `node
                    for `node in classic_nodes
                    if `node.name not in import_map
                ];
            }
            all_nodes.extend(nodes);
            all_edges.extend(self._resolve_call_targets(visible, edges, file_path));
        }
        return classic_nodes;
    }

    def _html_handler_calls(handler: str) -> list[str] {
        js_parser: any = self._get_parser("javascript");
        if not js_parser {
            return [];
        }
        called: list[str] = [];
        stack: any = [js_parser.parse(handler.encode("utf-8", errors="replace")).root_node];
        while stack {
            `node: any = stack.pop();
            if `node.type == "call_expression" {
                function: any = `node.child_by_field_name("function");
                if function is not None and function.type == "identifier" {
                    called.append(function.text.decode("utf-8", errors="replace"));
                }
            }
            stack.extend(reversed(`node.children));
        }
        return called;
    }

    def _add_html_script_import(src: str, file_path: str, line: int, edges: list[EdgeInfo]) {
        src = src.strip();
        if not _html_is_local_src(src) {
            return;
        }
        relative: any = src.split("#", 1)[0].split("?", 1)[0];
        if not relative {
            return;
        }
        resolved: Optional[str] = None;
        if relative.startswith("/") {
            if self._repo_root is not None {
                parts: list[str] = [];
                for part in relative.split("/") {
                    if part == ".." {
                        if parts {
                            parts.pop();
                        }
                    } elif part not in ("", ".") {
                        parts.append(part);
                    }
                }
                try {
                    candidate: any = self._repo_root.joinpath(*parts).resolve();
                    found: any = `bool(parts) and candidate.is_file();
                } except (OSError, RuntimeError) {
                    found = False;
                }
                if found {
                    canonical: any = normalize_file_path(candidate);
                    if canonical not in self._excluded_files {
                        resolved = canonical;
                    }
                }
            }
        } else {
            module: any = relative if relative.startswith(".") else f"./{relative}";
            resolved = self._resolve_module_to_file(module, file_path, "javascript");
        }
        edges.append(EdgeInfo("IMPORTS_FROM", file_path, resolved or relative, file_path, line));
    }

    def _parse_xslt(path: Path, source: bytes) -> tuple[list[NodeInfo], list[EdgeInfo]] {
        xml_parser: any = self._get_parser("xml");
        if not xml_parser {
            return ([], []);
        }

        file_path: any = normalize_file_path(path);
        file_node: any = NodeInfo(
            "File",
            file_path,
            file_path,
            1,
            source.count(b"\n") + 1,
            language="xslt",
            is_test=self._is_test_path(file_path),
        );
        if len(source) > self._MAX_XSLT_BYTES {
            file_node.extra["xslt_truncated"] = True;
            return ([file_node], []);
        }

        nodes: list[NodeInfo] = [file_node];
        edges: list[EdgeInfo] = [];
        `root: any = next(
            (child
            for child in xml_parser.parse(source).root_node.children
            if child.type == "element"),
            None,
        );
        if `root is None {
            return (nodes, edges);
        }
        root_scope: any = _xml_scope(`root, {"xsl": _XSLT_NAMESPACE});

        templates: list[_XsltTemplate] = [];
        seen: set[str] = set[any]();
        top_level: any = _xml_child_elements(`root);
        is_stylesheet: any = _xslt_local_name(`root, root_scope) in ("stylesheet", "transform");
        for element in top_level if is_stylesheet else [] {
            scope: any = _xml_scope(element, root_scope);
            local: any = _xslt_local_name(element, scope);
            if local in ("import", "include") {
                self._add_xslt_import(element, local, file_path, edges);
            } elif local in ("template", "function") {
                template: any = self._xslt_template(element, local, scope, file_path, seen);
                if template is not None {
                    templates.append(template);
                    nodes.append(template.node);
                    edges.append(
                        EdgeInfo(
                            "CONTAINS",
                            file_path,
                            template.qualified,
                            file_path,
                            template.node.line_start,
                        ),
                    );
                }
            }
        }
        named: any = {
            template.node.name: template.qualified
            for template in templates
            if template.node.extra["xslt_kind"] == "named_template"
        };
        for template in templates {
            self._walk_xslt_body(
                template.element, template.scope, template, templates, named, file_path, edges
            );
        }
        if not is_stylesheet {
            self._walk_xslt_body(`root, root_scope, None, templates, named, file_path, edges);
        }
        return (nodes, edges);
    }

    def _add_xslt_import(element: Any, how: str, file_path: str, edges: list[EdgeInfo]) {
        href: any = _xml_attributes(element).get("href", "").strip();
        if not href or re.match("[A-Za-z][A-Za-z0-9+.-]*:", href) {
            return;
        }
        target: any = href;
        candidate: any = (Path(file_path).parent / href).resolve();
        if candidate.is_file()
            and (self._repo_root is None or _path_is_within(candidate, self._repo_root))
            and normalize_file_path(candidate) not in self._excluded_files
        {
            target = normalize_file_path(candidate);
        }
        edges.append(
            EdgeInfo(
                "IMPORTS_FROM",
                file_path,
                target,
                file_path,
                element.start_point[0] + 1,
                extra={"xslt_import": how},
            ),
        );
    }

    def _xslt_template(
        element: Any, local_name: str, scope: dict[str, str], file_path: str, seen: set[str]
    ) -> Optional[_XsltTemplate] {
        attributes: any = _xml_attributes(element);
        declared: any = " ".join(attributes.get("name", "").split());
        `match: any = " ".join(attributes.get("match", "").split());
        mode: any = " ".join(attributes.get("mode", "").split());
        if not declared and not `match {
            return None;
        }

        extra: dict[str, Any] = {
            "xslt_kind": "function"
                if local_name == "function"
                else "named_template" if declared else "match_template",
        };
        if `match {
            extra["match"] = `match[:self._MAX_XSLT_PATTERN_CHARS];
        }
        if mode {
            extra["mode"] = mode[:self._MAX_XSLT_PATTERN_CHARS];
        }
        if attributes.get("priority") {
            extra["priority"] = attributes["priority"][:32];
        }

        name: any = declared or f"match={`match}" + (f" mode={mode}" if mode else "");
        name = name[:self._MAX_XSLT_NAME_CHARS];
        params: any = [
            _xml_attributes(child).get("name", "")
            for child in _xml_child_elements(element)
            if _xslt_local_name(child, _xml_scope(child, scope)) == "param"
        ];
        line_start: any = element.start_point[0] + 1;
        identity: any = None;
        if name in seen {
            identity = f"{name}@L{line_start}";
            if identity in seen {
                identity = f"{identity}C{element.start_point[1] + 1}";
            }
        }
        seen.add(identity or name);
        `node: any = NodeInfo(
            "Function",
            name,
            file_path,
            line_start,
            element.end_point[0] + 1,
            language="xslt",
            params=f"({", ".join(params)})" if params else None,
            extra=extra,
            identity_name=identity,
        );
        return _XsltTemplate(
            element=element,
            scope=scope,
            node=`node,
            qualified=self._qualify(identity or name, file_path, None),
            modes=`set(mode.split()) or {"#default"},
            steps=_xslt_named_steps(`match) if `match else set[any](),
        );
    }

    def _walk_xslt_body(
        element: Any,
        scope: dict[str, str],
        owner: Optional[_XsltTemplate],
        templates: list[_XsltTemplate],
        named: dict[str, str],
        file_path: str,
        edges: list[EdgeInfo],
    ) {
        child: any;
        source: any = owner.qualified if owner is not None else file_path;
        stack: any = [(child, scope) for child in reversed(_xml_child_elements(element))];
        while stack {
            parent_scope: any;
            (child, parent_scope) = stack.pop() as any;
            child_scope: any = _xml_scope(child, parent_scope);
            name: any = _xslt_local_name(child, child_scope);
            line: any = child.start_point[0] + 1;
            if name == "call-template" {
                called: any = " ".join(_xml_attributes(child).get("name", "").split());
                if called {
                    edges.append(
                        EdgeInfo(
                            "CALLS",
                            source,
                            named.get(called, called),
                            file_path,
                            line,
                            extra={"xslt_call": "call-template"},
                        ),
                    );
                }
            } elif name == "apply-templates" {
                self._add_xslt_apply(child, owner, source, templates, file_path, line, edges);
            }
            stack.extend(
                (grandchild, child_scope) for grandchild in reversed(_xml_child_elements(child))
            );
        }
    }

    def _add_xslt_apply(
        element: Any,
        owner: Optional[_XsltTemplate],
        source: str,
        templates: list[_XsltTemplate],
        file_path: str,
        line: int,
        edges: list[EdgeInfo],
    ) {
        attributes: any = _xml_attributes(element);
        select: any = " ".join(attributes.get("select", "").split());
        written_mode: any = attributes.get("mode", "").strip();
        modes: any = {"#default"} if not written_mode else {written_mode};
        if written_mode == "#current" {
            modes = owner.modes if owner is not None else {"#default"};
        }
        in_mode: any = [
            template
            for template in templates
            if template.matches and ("#all" in template.modes or modes & template.modes)
        ];
        steps: any = _xslt_named_steps(select) if select else set[any]();
        if steps {
            targets: any = [template for template in in_mode if steps & template.steps];
        } elif written_mode
            and written_mode != "#default"
            and len(in_mode) <= self._MAX_XSLT_MODE_FANOUT
        {
            targets = in_mode;
        } else {
            targets = [];
        }

        extra: dict[str, Any] = {"xslt_call": "apply-templates"};
        if select {
            extra["select"] = select[:self._MAX_XSLT_PATTERN_CHARS];
        }
        shown_mode: any = " ".join(sorted(modes));
        if shown_mode != "#default" {
            extra["mode"] = shown_mode[:self._MAX_XSLT_PATTERN_CHARS];
        }

        target_names: any = [template.qualified for template in targets];
        if not target_names and steps {
            suffix: any = f" mode={shown_mode}" if shown_mode != "#default" else "";
            target_names = [f"match={step}{suffix}" for step in sorted(steps)];
        }
        if not target_names {
            if owner is not None {
                owner.node.extra["dynamic_apply_count"] = owner.node.extra.get(
                    "dynamic_apply_count", 0
                )
                    + 1;
            }
            return;
        }
        for target in target_names {
            edges.append(EdgeInfo("CALLS", source, target, file_path, line, extra=`dict(extra)));
        }
    }

    def _parse_notebook(path: Path, source: bytes) -> tuple[list[NodeInfo], list[EdgeInfo]] {
        try {
            nb: any = json.loads(source);
        } except (json.JSONDecodeError, UnicodeDecodeError) {
            return ([], []);
        }
        kernel_lang: any = (
            nb.get("metadata", {}).get("kernelspec", {}).get("language")
            or nb.get("metadata", {}).get("language_info", {}).get("name")
            or "python"
        ).lower();
        supported: any = {"python", "r"};
        if kernel_lang not in supported {
            return ([], []);
        }
        cells: list[CellInfo] = [];
        magic_lang_map: any = {"%python": "python", "%sql": "sql", "%r": "r"};
        skip_magics: any = {"%scala", "%md", "%sh"};

        for (cell_idx, cell) in enumerate(nb.get("cells", [])) {
            if cell.get("cell_type") != "code" {
                continue;
            }
            lines: any = cell.get("source", []);
            if isinstance(lines, `str) {
                lines = lines.splitlines(keepends=True);
            }
            if not lines {
                continue;
            }
            first_line: any = lines[0].strip();
            cell_lang: any = kernel_lang;
            cell_lines: any = lines;

            for (magic, lang) in magic_lang_map.items() {
                if first_line == magic or first_line.startswith(magic + " ") {
                    cell_lang = lang;
                    cell_lines = lines[1:];
                    break;
                }
            } else {
                for `skip in skip_magics {
                    if first_line == `skip or first_line.startswith(`skip + " ") {
                        cell_lines = [];
                        break;
                    }
                }
            }
            if cell_lang in ("python", "r") {
                filtered: any = [ln for ln in cell_lines if not ln.lstrip().startswith(("%", "!"))];
            } else {
                filtered = cell_lines;
            }
            if not filtered {
                continue;
            }

            cell_source: any = "".join(filtered);
            cells.append(CellInfo(cell_index=cell_idx, language=cell_lang, source=cell_source));
        }

        if not cells {
            file_path_str: any = normalize_file_path(path);
            return (
                [
                    NodeInfo(
                        "File",
                        file_path_str,
                        file_path_str,
                        1,
                        1,
                        language=kernel_lang,
                        is_test=self._is_test_path(file_path_str),
                    ),
                ],
                [],
            );
        }

        return self._parse_notebook_cells(path, cells, kernel_lang);
    }

    def _parse_notebook_cells(
        path: Path, cells: list[CellInfo], default_language: str
    ) -> tuple[list[NodeInfo], list[EdgeInfo]] {
        file_path_str: any = normalize_file_path(path);
        test_file: any = self._is_test_path(file_path_str);
        lang_cells: dict[str, list[CellInfo]] = {};
        cell: any;
        for cell in cells {
            lang_cells.setdefault(cell.language, []).append(cell);
        }

        all_nodes: list[NodeInfo] = [];
        all_edges: list[EdgeInfo] = [];
        all_cell_offsets: list[tuple[int, int, int]] = [];
        max_line: any = 1;

        for (lang, lang_group) in lang_cells.items() {
            if lang == "sql" {
                for cell in lang_group {
                    for `match in _SQL_TABLE_RE.finditer(cell.source) {
                        table_name: any = `match.group(1).replace("`", "");
                        all_edges.append(
                            EdgeInfo("IMPORTS_FROM", file_path_str, table_name, file_path_str, 1)
                        );
                    }
                }
                continue;
            }

            if lang not in ("python", "r") {
                continue;
            }

            ts_parser: any = self._get_parser(lang);
            if not ts_parser {
                continue;
            }
            code_chunks: list[str] = [];
            cell_offsets: list[tuple[int, int, int]] = [];
            current_line: any = 1;

            for cell in lang_group {
                cell_line_count: any = cell.source.count("\n")
                    + (1 if not cell.source.endswith("\n") else 0);
                cell_offsets.append((
                    cell.cell_index,
                    current_line,
                    current_line + cell_line_count - 1,
                ));
                code_chunks.append(cell.source);
                current_line += cell_line_count + 1;
            }

            concatenated: any = "\n".join(code_chunks);
            concat_bytes: any = concatenated.encode("utf-8");

            tree: any = ts_parser.parse(concat_bytes);

            import_map: any;
            defined_names: any;
            (import_map, defined_names) = self._collect_file_scope(
                tree.root_node, lang, concat_bytes, file_path_str
            ) as any;
            if lang == "python" {
                self._expand_python_star_imports(tree.root_node, file_path_str, import_map);
            }
            self._extract_from_tree(
                tree.root_node,
                concat_bytes,
                lang,
                file_path_str,
                all_nodes,
                all_edges,
                import_map=import_map,
                defined_names=defined_names,
            );

            all_cell_offsets.extend(cell_offsets);
            max_line = max(max_line, current_line);
        }
        file_node: any = NodeInfo(
            "File",
            file_path_str,
            file_path_str,
            1,
            max_line,
            language=default_language,
            is_test=test_file,
        );
        all_nodes.insert(0, file_node);
        all_edges = self._resolve_call_targets(all_nodes, all_edges, file_path_str);
        for `node in all_nodes {
            if `node.kind == "File" {
                continue;
            }
            for (cell_idx, start, end) in all_cell_offsets {
                if start <= `node.line_start <= end {
                    `node.extra["cell_index"] = cell_idx;
                    break;
                }
            }
        }
        if test_file {
            self._add_tested_by(all_nodes, all_edges);
        }

        return (all_nodes, all_edges);
    }

    def _parse_databricks_py_notebook(
        path: Path, source: bytes
    ) -> tuple[list[NodeInfo], list[EdgeInfo]] {
        text: any = source.decode("utf-8", errors="replace");
        lines: any = text.split("\n");
        if lines and lines[0].strip() == "# Databricks notebook source" {
            lines = lines[1:];
        }
        cell_chunks: list[list[str]] = [[]];
        for line in lines {
            if re.match("^# COMMAND\\s*-+\\s*$", line) {
                cell_chunks.append([]);
            } else {
                cell_chunks[-1].append(line);
            }
        }
        cells: list[CellInfo] = [];
        magic_lang_map: any = {"# MAGIC %sql": "sql", "# MAGIC %r": "r"};
        skip_prefixes: any = ("# MAGIC %md", "# MAGIC %sh");

        for (cell_idx, chunk) in enumerate(cell_chunks) {
            non_empty: any = [ln for ln in chunk if ln.strip()];
            if not non_empty {
                continue;
            }

            first_line: any = non_empty[0];
            all_magic: any = all(ln.startswith("# MAGIC ") for ln in non_empty);
            cell_lang: any = None;
            if all_magic {
                for (prefix, lang) in magic_lang_map.items() {
                    if first_line.startswith(prefix) {
                        cell_lang = lang;
                        break;
                    }
                }
            }

            if cell_lang {
                stripped: any = [ln[8:] if ln.startswith("# MAGIC ") else ln for ln in chunk];
                stripped_non_empty: any = [ln for ln in stripped if ln.strip()];
                if stripped_non_empty and stripped_non_empty[0].strip().startswith("%") {
                    first_directive: any = stripped_non_empty[0];
                    stripped = [ln for ln in stripped if ln != first_directive];
                }
                cell_source: any = "\n".join(stripped);
                cells.append(CellInfo(cell_index=cell_idx, language=cell_lang, source=cell_source));
                continue;
            }
            if all_magic and first_line.startswith(skip_prefixes) {
                continue;
            }
            py_lines: any = [ln for ln in chunk if not ln.startswith("# MAGIC ")];
            cell_source = "\n".join(py_lines);
            cells.append(CellInfo(cell_index=cell_idx, language="python", source=cell_source));
        }

        if not cells {
            file_path_str: any = normalize_file_path(path);
            file_node: any = NodeInfo(
                "File",
                file_path_str,
                file_path_str,
                1,
                1,
                language="python",
                is_test=self._is_test_path(file_path_str),
            );
            file_node.extra["notebook_format"] = "databricks_py";
            return ([file_node], []);
        }

        nodes: any;
        edges: any;
        (nodes, edges) = self._parse_notebook_cells(path, cells, "python") as any;
        for `node in nodes {
            if `node.kind == "File" {
                `node.extra["notebook_format"] = "databricks_py";
                break;
            }
        }

        return (nodes, edges);
    }

    def _parse_vbnet(path: Path, source: bytes) -> tuple[list[NodeInfo], list[EdgeInfo]] {
        edges: list[EdgeInfo];
        namespace_stack: list[dict];
        type_stack: list[dict];
        member_stack: list[dict];
        text: any = source.decode("utf-8", errors="replace");
        cleaned: any = _strip_vbnet_noise(text);
        statements: any = _vbnet_logical_lines(cleaned);
        file_path: any = normalize_file_path(path);
        line_count: any = text.count("\n") + 1;
        test_file: any = self._is_test_path(file_path);

        nodes: any = [
            NodeInfo(
                "File", file_path, file_path, 1, line_count, language="vbnet", is_test=test_file
            ),
        ];
        edges = [];
        namespace_stack = [];
        type_stack = [];
        member_stack = [];
        member_nodes: dict[tuple[str, str], int] = {};

        def namespace_scope -> Optional[str] {
            return namespace_stack[-1]["full"] if namespace_stack else None;
        }

        def current_type -> Optional[dict] {
            return type_stack[-1] if type_stack else None;
        }

        def parent_scope -> Optional[str] {
            current: any = current_type();
            return current["full"] if current else namespace_scope();
        }

        def container_qn(scope: Optional[str]) -> str {
            return self._qualify(scope, file_path, None) if scope else file_path;
        }

        def close_member(line_no: int) {
            if not member_stack {
                return;
            }
            `entry: any = member_stack.pop();
            `node: any = nodes[`entry["node_index"]];
            `node.line_end = max(`node.line_end, line_no);
        }

        def close_type(line_no: int, kind: Optional[str] = None) {
            while member_stack {
                close_member(line_no);
            }
            if not type_stack {
                return;
            }
            if kind is None {
                `entry: any = type_stack.pop();
            } else {
                wanted: any = kind.casefold();
                index: any = next(
                    (pos
                    for pos in range(len(type_stack) - 1, -1, -1)
                    if type_stack[pos]["kind"] == wanted),
                    len(type_stack) - 1,
                );
                `entry = type_stack.pop(index);
            }
            nodes[`entry["node_index"]].line_end = line_no;
        }

        def emit_relationships(statement: str, source_qn: str, line_no: int) {
            for (pattern, edge_kind) in (
                (_VBNET_INHERITS_RE, "INHERITS"),
                (_VBNET_IMPLEMENTS_RE, "IMPLEMENTS"),
            ) {
                `match: any = pattern.search(statement);
                if `match is None {
                    continue;
                }
                for target in _vbnet_relationship_targets(`match.group(1)) {
                    edges.append(
                        EdgeInfo(
                            edge_kind,
                            source_qn,
                            target,
                            file_path,
                            line_no,
                            extra={"vbnet_unresolved": True},
                        ),
                    );
                }
            }
        }

        def emit_calls(statement: str, source_qn: str, line_no: int) {
            `match: any;
            new_spans: list[tuple[int, int]] = [];
            for match_ in _VBNET_NEW_RE.finditer(statement) {
                `match = match_;
                target: any = _vbnet_normalize_name(`match.group("target"));
                new_spans.append(`match.span());
                edges.append(
                    EdgeInfo(
                        "CALLS",
                        source_qn,
                        target,
                        file_path,
                        line_no,
                        extra={"vbnet_unresolved": True, "constructor": True},
                    ),
                );
            }

            for match__ in _VBNET_CALL_RE.finditer(statement) {
                `match = match__;
                if `any(
                    operator.le(start, compared_ := `match.start()) and operator.lt(compared_, end)
                    for (start, end) in new_spans,
                ) {
                    continue;
                }
                target = _vbnet_normalize_name(`match.group("target"));
                first: any = target.split(".", 1)[0].casefold();
                if first in _VBNET_CALL_KEYWORDS {
                    continue;
                }
                edges.append(
                    EdgeInfo(
                        "CALLS",
                        source_qn,
                        target,
                        file_path,
                        line_no,
                        extra={"vbnet_unresolved": True},
                    ),
                );
            }
        }

        for (line_start, line_end, statement) in statements {
            if not statement {
                continue;
            }

            import_match: any = _VBNET_IMPORT_RE.match(statement);
            if import_match {
                target: any;
                for target in _vbnet_relationship_targets(import_match.group(1)) {
                    edges.append(
                        EdgeInfo("IMPORTS_FROM", file_path, target, file_path, line_start)
                    );
                }
                continue;
            }

            if _VBNET_END_NAMESPACE_RE.match(statement) {
                while type_stack {
                    close_type(line_end);
                }
                if namespace_stack {
                    `entry: any = namespace_stack.pop();
                    nodes[`entry["node_index"]].line_end = line_end;
                }
                continue;
            }

            namespace_match: any = _VBNET_NAMESPACE_RE.match(statement);
            if namespace_match {
                raw_name: any = _vbnet_normalize_name(namespace_match.group("name"));
                outer: any = namespace_scope();
                full_name: any = ".".join(filter(None, (outer, raw_name)));
                node_index: any = len(nodes);
                nodes.append(
                    NodeInfo(
                        "Class",
                        raw_name,
                        file_path,
                        line_start,
                        line_end,
                        language="vbnet",
                        parent_name=outer,
                        extra={"vbnet_kind": "namespace"},
                    ),
                );
                edges.append(
                    EdgeInfo(
                        "CONTAINS",
                        container_qn(outer),
                        self._qualify(raw_name, file_path, outer),
                        file_path,
                        line_start,
                    ),
                );
                namespace_stack.append({"full": full_name, "node_index": node_index});
                continue;
            }

            end_member: any = _VBNET_END_MEMBER_RE.match(statement);
            if end_member {
                close_member(line_end);
                continue;
            }

            end_type: any = _VBNET_END_TYPE_RE.match(statement);
            if end_type {
                close_type(line_end, end_type.group("kind"));
                continue;
            }

            type_match: any = _VBNET_TYPE_RE.match(statement);
            if type_match {
                while member_stack {
                    close_member(line_start);
                }
                name: any = _vbnet_normalize_name(type_match.group("name"));
                kind: any = type_match.group("kind").casefold();
                scope: any = parent_scope();
                full_scope: any = ".".join(filter(None, (scope, name)));
                type_params: any;
                _: any;
                (type_params, _) = _vbnet_type_parameters(type_match.group("rest")) as any;
                extra: dict = {"vbnet_kind": kind};
                if type_params {
                    extra["vbnet_type_parameters"] = type_params;
                }
                node_index = len(nodes);
                nodes.append(
                    NodeInfo(
                        "Class",
                        name,
                        file_path,
                        line_start,
                        line_end,
                        language="vbnet",
                        parent_name=scope,
                        extra=extra,
                    ),
                );
                type_qn: any = self._qualify(name, file_path, scope);
                edges.append(
                    EdgeInfo("CONTAINS", container_qn(scope), type_qn, file_path, line_start)
                );
                type_stack.append({"full": full_scope, "kind": kind, "node_index": node_index});
                emit_relationships(type_match.group("rest"), type_qn, line_start);
                continue;
            }

            type_entry: any = current_type();
            if type_entry
                and re.match("^\\s*(?:Inherits|Implements)\\b", statement, re.IGNORECASE)
            {
                emit_relationships(
                    statement, self._qualify(type_entry["full"], file_path, None), line_start
                );
                continue;
            }

            member_match: any = _VBNET_MEMBER_RE.match(statement)
                or _VBNET_OPERATOR_RE.match(statement);
            if member_match {
                while member_stack {
                    close_member(line_start);
                }
                member_kind: any = member_match.group("kind").casefold();
                name = _vbnet_normalize_name(member_match.group("name"));
                if member_kind == "operator" {
                    name = f"operator_{name}";
                }
                modifiers: any = re.sub("\\s+", " ", member_match.group("mods").strip()) or None;
                params: any;
                return_type: any;
                (params, return_type, type_params) = _vbnet_signature_parts(
                    member_match.group("rest")
                ) as any;
                scope = parent_scope();
                qn: any = self._qualify(name, file_path, scope);
                key: any = ((scope or "").casefold(), name.casefold());
                member_index: any = member_nodes.get(key);
                if member_index is None {
                    is_test: any = _is_test_function(name, file_path, repo_root=self._repo_root);
                    extra = {"vbnet_kind": member_kind};
                    if type_params {
                        extra["vbnet_type_parameters"] = type_params;
                    }
                    member_index = len(nodes);
                    nodes.append(
                        NodeInfo(
                            "Test" if is_test else "Function",
                            name,
                            file_path,
                            line_start,
                            line_end,
                            language="vbnet",
                            parent_name=scope,
                            params=params,
                            return_type=return_type,
                            modifiers=modifiers,
                            is_test=is_test,
                            extra=extra,
                        ),
                    );
                    member_nodes[key] = member_index;
                    edges.append(
                        EdgeInfo("CONTAINS", container_qn(scope), qn, file_path, line_start)
                    );
                } else {
                    existing: any = nodes[member_index];
                    overloads: any = existing.extra.setdefault(
                        "vbnet_overloads", [existing.params or ""]
                    );
                    overloads.append(params or "");
                    existing.line_end = max(existing.line_end, line_end);
                }

                implements: any = _VBNET_IMPLEMENTS_RE.search(member_match.group("rest"));
                if implements {
                    for target in _vbnet_relationship_targets(implements.group(1)) {
                        edges.append(
                            EdgeInfo(
                                "IMPLEMENTS",
                                qn,
                                target,
                                file_path,
                                line_start,
                                extra={"vbnet_unresolved": True},
                            ),
                        );
                    }
                }

                modifier_words: any = {word.casefold() for word in (modifiers or "").split()};
                has_body: any = (not type_entry or operator.ne(type_entry["kind"], "interface"))
                    and not modifier_words.intersection({"mustoverride", "declare"});
                if has_body {
                    member_stack.append({"node_index": member_index, "qn": qn});
                }
                continue;
            }

            if member_stack {
                emit_calls(statement, member_stack[-1]["qn"], line_start);
            }
        }

        while member_stack {
            close_member(line_count);
        }
        while type_stack {
            close_type(line_count);
        }
        while namespace_stack {
            `entry = namespace_stack.pop();
            nodes[`entry["node_index"]].line_end = line_count;
        }

        edges = self._resolve_vbnet_edges(nodes, edges, file_path);
        if test_file {
            test_qnames: any = {
                self._qualify(`node.name, file_path, `node.parent_name)
                for `node in nodes
                if `node.is_test
            };
            for `edge in `list(edges) {
                if `edge.kind == "CALLS" and `edge.source in test_qnames {
                    edges.append(
                        EdgeInfo(
                            "TESTED_BY", `edge.target, `edge.source, `edge.file_path, `edge.line
                        ),
                    );
                }
            }
        }
        return (nodes, edges);
    }

    def _parse_robot(path: Path, source: bytes) -> tuple[list[NodeInfo], list[EdgeInfo]] {
        edges: list[EdgeInfo];
        current: Optional[tuple[str, str, int, str]];
        cell: any;
        `node: any;
        text: any = source.decode("utf-8-sig", errors="replace");
        file_path: any = normalize_file_path(path);
        lines: any = text.splitlines();
        nodes: any = [
            NodeInfo(
                "File",
                file_path,
                file_path,
                1,
                max(1, len(lines)),
                language="robot",
                is_test=_is_test_file(file_path),
            ),
        ];
        edges = [];
        section: Optional[str] = None;
        current = None;
        ignored_settings: any = {
            "[arguments]",
            "[documentation]",
            "[return]",
            "[returns]",
            "[timeout]",
            "[tags]",
        };
        keyword_settings: any = {"[setup]", "[teardown]", "[template]"};
        suite_keyword_settings: any = {
            "suite setup",
            "suite teardown",
            "test setup",
            "test teardown",
            "test template",
            "task setup",
            "task teardown",
            "task template",
        };
        block_starts: any = {"IF", "FOR", "WHILE", "TRY", "GROUP"};
        block_branches: any = {"ELSE IF", "ELSE", "EXCEPT", "FINALLY"};
        statements: any = {"BREAK", "CONTINUE", "RETURN", "VAR"};
        control_words: any = block_starts | block_branches | statements | {"END"};
        section_names: any = {
            "setting": "settings",
            "test case": "test cases",
            "task": "tasks",
            "keyword": "keywords",
        };

        def qualified(name: str) -> str {
            return f"{file_path}::{name}";
        }

        def normalize_keyword(name: str) -> str {
            return re.sub("[\\s_]+", "", name).casefold();
        }

        def add_call(source_name: str, target: str, line: int) {
            edges.append(EdgeInfo("CALLS", source_name, target, file_path, line));
        }

        def finish(end_line: int) {
            if current is None {
                return;
            }
            _: any;
            name: any;
            start_line: any;
            (_, name, start_line, _) = current as any;
            for `node in reversed(nodes) {
                if `node.name == name and `node.line_start == start_line {
                    `node.line_end = max(start_line, end_line);
                    break;
                }
            }
            current = None;
        }

        for (line_number, raw_line) in enumerate(lines, 1) {
            stripped: any = raw_line.strip();
            if not stripped or stripped.startswith("#") {
                continue;
            }
            if stripped.startswith("|") {
                row: any = re.split("\\s\\|(?:\\s|$)", stripped[1:] + " ");
                is_body_row: any = not row[0].strip();
                cells: any = [cell.strip() for cell in row if cell.strip()];
            } else {
                is_body_row = raw_line[:1].isspace();
                cells = [
                    cell.strip()
                    for cell in re.split("\\s{2,}|\\t+", raw_line)
                    if cell.strip()
                ];
            }
            if not cells {
                continue;
            }
            section_match: any = re.fullmatch("\\*+\\s*(.+?)\\s*\\*+", cells[0]);
            if section_match {
                finish(line_number - 1);
                section = section_match.group(1).casefold();
                section = section_names.get(section, section);
                continue;
            }
            if cells[0] == "..." {
                continue;
            }

            if section == "settings" {
                setting: any = cells[0].casefold();
                if setting in suite_keyword_settings and len(cells) > 1 {
                    if cells[1].casefold() != "none" {
                        add_call(file_path, cells[1], line_number);
                    }
                    continue;
                }
                if setting in {"library", "resource", "variables"} and len(cells) > 1 {
                    target: any = cells[1];
                    if setting == "resource" {
                        target = target.replace("${CURDIR}", `str(path.parent));
                        if "${" not in target {
                            target = normalize_file_path(os.path.normpath(path.parent / target));
                        }
                    }
                    edges.append(
                        EdgeInfo(
                            "IMPORTS_FROM",
                            file_path,
                            target,
                            file_path,
                            line_number,
                            extra={"robot_setting": setting},
                        ),
                    );
                }
                continue;
            }

            if section not in {"test cases", "tasks", "keywords"} {
                continue;
            }

            if not is_body_row {
                finish(line_number - 1);
                name: any = cells[0];
                is_test: any = section in {"test cases", "tasks"};
                node_kind: any = "Test" if is_test else "Function";
                qname: any = qualified(name);
                current = (node_kind, name, line_number, qname);
                nodes.append(
                    NodeInfo(
                        node_kind,
                        name,
                        file_path,
                        line_number,
                        line_number,
                        language="robot",
                        is_test=is_test,
                    ),
                );
                edges.append(EdgeInfo("CONTAINS", file_path, qname, file_path, line_number));
                continue;
            }

            if current is None {
                continue;
            }
            first: any = re.fullmatch("([$@&]\\{[^}]+\\}\\s*=)\\s+(.+)", cells[0]);
            if first is not None {
                cells = [first.group(2), *cells[1:]];
            }
            while cells and re.fullmatch("[$@&]\\{[^}]+\\}\\s*=?", cells[0]) {
                cells = cells[1:];
            }
            if not cells {
                continue;
            }
            keyword: any = cells[0];
            setting = keyword.casefold();
            if setting in keyword_settings {
                if len(cells) > 1 and cells[1].casefold() != "none" {
                    add_call(current[3], cells[1], line_number);
                }
                continue;
            }
            if setting in ignored_settings {
                continue;
            }
            if keyword == "IF" and len(cells) > 2 {
                branches: any = [cells[2]];
                for (index, cell) in enumerate(cells) {
                    if cell == "ELSE IF" and index + 2 < len(cells) {
                        branches.append(cells[index + 2]);
                    } elif cell == "ELSE" and index + 1 < len(cells) {
                        branches.append(cells[index + 1]);
                    }
                }
                for branch in branches {
                    if branch not in control_words {
                        add_call(current[3], branch, line_number);
                    }
                }
                continue;
            }
            if keyword not in control_words {
                add_call(current[3], keyword, line_number);
            }
        }

        finish(len(lines));
        test_names: any = {`node.name for `node in nodes if `node.kind == "Test"};
        keyword_names: any = {`node.name for `node in nodes if `node.kind == "Function"};
        shared_names: any = test_names & keyword_names;
        if shared_names {
            for `node in nodes {
                if `node.kind not in {"Test", "Function"} or `node.name not in shared_names {
                    continue;
                }
                previous_qname: any = qualified(`node.name);
                `node.identity_name = f"{`node.kind}::{`node.name}";
                new_qname: any = self._node_qualified(`node);
                `edge: any;
                for `edge in edges {
                    if `edge.kind == "CONTAINS"
                        and `edge.target == previous_qname
                        and `edge.line == `node.line_start
                    {
                        `edge.target = new_qname;
                    } elif `edge.kind == "CALLS"
                        and `edge.source == previous_qname
                        and `node.line_start <= `edge.line <= `node.line_end
                    {
                        `edge.source = new_qname;
                    }
                }
            }
        }

        keyword_definitions: dict[str, list[NodeInfo]] = {};
        for `node in nodes {
            if `node.kind == "Function" {
                normalized: any = normalize_keyword(`node.name);
                keyword_definitions.setdefault(normalized, []).append(`node);
            }
        }

        for `edge in edges {
            if `edge.kind != "CALLS" {
                continue;
            }
            matches: any = keyword_definitions.get(normalize_keyword(`edge.target), []);
            if not matches {
                `edge.target = re.sub(
                    "^(?:given|when|then|and|but)\\s+", "", `edge.target, flags=re.IGNORECASE
                );
                matches = keyword_definitions.get(normalize_keyword(`edge.target), []);
            }
            if len(matches) == 1 {
                `edge.target = self._node_qualified(matches[0]);
            }
        }

        test_qnames: any = {self._node_qualified(`node) for `node in nodes if `node.kind == "Test"};
        for `edge in `list(edges) {
            if `edge.kind == "CALLS" and `edge.source in test_qnames {
                edges.append(
                    EdgeInfo(
                        "TESTED_BY",
                        `edge.target,
                        `edge.source,
                        `edge.file_path,
                        `edge.line,
                        extra=`edge.extra.copy(),
                    ),
                );
            }
        }
        return (nodes, edges);
    }

    def _resolve_vbnet_edges(
        nodes: list[NodeInfo], edges: list[EdgeInfo], file_path: str
    ) -> list[EdgeInfo] {
        symbols: dict[str, list[str]];
        bare_symbols: dict[str, list[str]];
        prefix: any = f"{file_path}::";
        symbols = {};
        bare_symbols = {};
        for `node in nodes {
            if `node.kind not in ("Class", "Function", "Test", "Type") {
                continue;
            }
            qn: any = self._qualify(`node.name, file_path, `node.parent_name);
            tail: any = qn.removeprefix(prefix);
            symbols.setdefault(tail.casefold(), []).append(qn);
            bare_symbols.setdefault(`node.name.casefold(), []).append(qn);
        }

        def unique(candidate: str) -> Optional[str] {
            matches: any = symbols.get(candidate.casefold(), []);
            return matches[0] if len(matches) == 1 else None;
        }

        def resolve(`edge: EdgeInfo) -> Optional[str] {
            raw: any = `edge.target;
            if "::" in raw {
                return raw;
            }
            target: any = _vbnet_normalize_name(raw);
            source_tail: any = `edge.source.removeprefix(prefix);
            source_parts: any = source_tail.split(".") if source_tail else [];
            scope_parts: any = source_parts[:-1];

            lowered: any = target.casefold();
            if lowered.startswith("global.") {
                target = target[7:];
            } elif lowered.startswith("me.") {
                target = target[3:];
            } elif lowered.startswith("myclass.") {
                target = target[8:];
            }

            for size in range(len(scope_parts), -1, -1) {
                candidate: any = ".".join((*scope_parts[:size], target));
                found: any = unique(candidate);
                if found is not None {
                    return found;
                }
            }
            found = unique(target);
            if found is not None {
                return found;
            }
            bare: any = bare_symbols.get(target.casefold(), []);
            return bare[0] if len(bare) == 1 else None;
        }

        resolved: list[EdgeInfo] = [];
        for `edge in edges {
            if `edge.kind not in ("CALLS", "INHERITS", "IMPLEMENTS") {
                resolved.append(`edge);
                continue;
            }
            target: any = resolve(`edge);
            if target is None {
                resolved.append(`edge);
                continue;
            }
            extra: any = `dict(`edge.extra);
            extra.pop("vbnet_unresolved", None);
            resolved.append(
                EdgeInfo(`edge.kind, `edge.source, target, `edge.file_path, `edge.line, extra=extra)
            );
        }
        return resolved;
    }

    def _parse_rescript(path: Path, source: bytes) -> tuple[list[NodeInfo], list[EdgeInfo]] {
        off: any;
        e: any;
        text: any = source.decode("utf-8", errors="replace");
        file_path_str: any = normalize_file_path(path);
        test_file: any = self._is_test_path(file_path_str);
        is_interface: any = operator.eq(path.suffix.lower(), ".resi");
        cleaned: any = _strip_rescript_noise(text);
        line_starts: any = [0];
        i: any;
        for (i, ch) in enumerate(cleaned) {
            if ch == "\n" {
                line_starts.append(i + 1);
            }
        }

        def offset_to_line(off: int) -> int {
            lo: any;
            hi: any;
            (lo, hi) = (0, len(line_starts) - 1);
            while lo < hi {
                mid: any = (lo + hi + 1) // 2;
                if line_starts[mid] <= off {
                    lo = mid;
                } else {
                    hi = mid - 1;
                }
            }
            return lo + 1;
        }

        nodes: list[NodeInfo] = [];
        edges: list[EdgeInfo] = [];

        file_extra: dict = {};
        if is_interface {
            file_extra["rescript_interface"] = True;
        }
        nodes.append(
            NodeInfo(
                "File",
                file_path_str,
                file_path_str,
                1,
                text.count("\n") + 1,
                language="rescript",
                is_test=test_file,
                extra=file_extra,
            ),
        );
        modules: any = _scan_rescript_modules(cleaned, offset_to_line);
        depth_arr: any = _rescript_brace_depth_array(cleaned);
        def is_top_level(off: int, parent_mod: Optional[str]) -> bool {
            d: any = depth_arr[off] if off < len(depth_arr) else 0;
            if parent_mod is None {
                return operator.eq(d, 0);
            }
            for m in modules {
                if m["name"] == parent_mod and m["start_off"] <= off <= m["end_off"] {
                    expected: any = depth_arr[m["body_start_off"]];
                    return operator.eq(d, expected);
                }
            }
            return False;
        }
        m: any;
        for m in modules {
            nodes.append(
                NodeInfo(
                    "Class",
                    m["name"],
                    file_path_str,
                    m["start_line"],
                    m["end_line"],
                    language="rescript",
                    parent_name=m["parent"],
                    extra={"rescript_kind": "module"},
                ),
            );
        }

        def enclosing_module(off: int) -> Optional[str] {
            innermost_name: any = None;
            innermost_start: any = -1;
            for m in modules {
                if m["start_off"] <= off <= m["end_off"] and m["start_off"] > innermost_start {
                    innermost_name = m["name"];
                    innermost_start = m["start_off"];
                }
            }
            return innermost_name;
        }
        let_entries: list[dict] = [];
        `match: any;
        for `match in _RESCRIPT_LET_RE.finditer(cleaned) {
            name: any = `match.group(1);
            if name in _RESCRIPT_KEYWORDS {
                continue;
            }
            off = `match.start(1);
            parent: any = enclosing_module(off);
            if not is_top_level(off, parent) {
                continue;
            }
            line_start: any = offset_to_line(off);
            is_test_fn: any = _is_test_function(name, file_path_str, repo_root=self._repo_root);
            let_entries.append({
                "name": name,
                "start_off": off,
                "line_start": line_start,
                "parent": parent,
                "is_test": is_test_fn,
            });
        }
        let_entries.sort(key=lambda (e) -> any { e["start_off"] });
        `entry: any;
        for (i, `entry) in enumerate(let_entries) {
            nxt: any = len(cleaned);
            for later in let_entries[i + 1:] {
                nxt = later["start_off"];
                break;
            }
            if `entry["parent"] {
                for m in modules {
                    if m["name"] == `entry["parent"]
                        and m["start_off"] <= `entry["start_off"] <= m["end_off"]
                    {
                        nxt = min(nxt, m["end_off"]);
                        break;
                    }
                }
            }
            `entry["end_off"] = max(nxt, `entry["start_off"] + 1);
            `entry["line_end"] = offset_to_line(`entry["end_off"] - 1);
        }

        for `entry in let_entries {
            nodes.append(
                NodeInfo(
                    "Test" if `entry["is_test"] else "Function",
                    `entry["name"],
                    file_path_str,
                    `entry["line_start"],
                    `entry["line_end"],
                    language="rescript",
                    parent_name=`entry["parent"],
                    is_test=`entry["is_test"],
                ),
            );
        }
        for `match in _RESCRIPT_EXTERNAL_RE.finditer(cleaned) {
            name = `match.group(1);
            if name in _RESCRIPT_KEYWORDS {
                continue;
            }
            off = `match.start(1);
            parent = enclosing_module(off);
            if not is_top_level(off, parent) {
                continue;
            }
            line_start = offset_to_line(off);
            nodes.append(
                NodeInfo(
                    "Function",
                    name,
                    file_path_str,
                    line_start,
                    line_start,
                    language="rescript",
                    parent_name=parent,
                    extra={"rescript_external": True},
                ),
            );
            look_start: any = max(0, off - 200);
            snippet: any = text[look_start:off];
            for attr in _RESCRIPT_MODULE_ATTR_RE.finditer(snippet) {
                edges.append(
                    EdgeInfo(
                        "IMPORTS_FROM",
                        file_path_str,
                        attr.group(1),
                        file_path_str,
                        line_start,
                        extra={"rescript_import_kind": "external_module"},
                    ),
                );
            }
        }
        for `match in _RESCRIPT_TYPE_RE.finditer(cleaned) {
            name = `match.group(1);
            if name in _RESCRIPT_KEYWORDS {
                continue;
            }
            off = `match.start(1);
            parent = enclosing_module(off);
            if not is_top_level(off, parent) {
                continue;
            }
            line_start = offset_to_line(off);
            nodes.append(
                NodeInfo(
                    "Type",
                    name,
                    file_path_str,
                    line_start,
                    line_start,
                    language="rescript",
                    parent_name=parent,
                ),
            );
        }
        for `match in _RESCRIPT_OPEN_RE.finditer(cleaned) {
            kind: any = `match.group(1);
            target: any = `match.group(2);
            off = `match.start();
            line: any = offset_to_line(off);
            edges.append(
                EdgeInfo(
                    "IMPORTS_FROM",
                    file_path_str,
                    target,
                    file_path_str,
                    line,
                    extra={"rescript_import_kind": kind},
                ),
            );
        }
        for `match in _RESCRIPT_MODULE_ALIAS_RE.finditer(cleaned) {
            alias_name: any = `match.group(1);
            target = `match.group(2);
            off = `match.start();
            if `any(operator.eq(m["start_off"], off) for m in modules) {
                continue;
            }
            line = offset_to_line(off);
            edges.append(
                EdgeInfo(
                    "IMPORTS_FROM",
                    file_path_str,
                    target,
                    file_path_str,
                    line,
                    extra={"rescript_import_kind": "module_alias", "alias_name": alias_name},
                ),
            );
        }
        if not is_interface {
            for `match in _RESCRIPT_JSX_RE.finditer(cleaned) {
                target = `match.group(1);
                off = `match.start(1);
                `root: any = target.split(".", 1)[0];
                line = offset_to_line(off);
                edges.append(
                    EdgeInfo(
                        "IMPORTS_FROM",
                        file_path_str,
                        `root,
                        file_path_str,
                        line,
                        extra={"rescript_import_kind": "jsx"},
                    ),
                );
                caller: any = None;
                caller_parent: any = None;
                for `entry in let_entries {
                    if `entry["start_off"] <= off < `entry["end_off"] {
                        caller = `entry["name"];
                        caller_parent = `entry["parent"];
                    } elif `entry["start_off"] > off {
                        break;
                    }
                }
                if caller is not None {
                    edges.append(
                        EdgeInfo(
                            "CALLS",
                            self._qualify(caller, file_path_str, caller_parent),
                            target,
                            file_path_str,
                            line,
                            extra={"rescript_call_kind": "jsx"},
                        ),
                    );
                }
            }
        }
        if not is_interface and let_entries {
            for `match in _RESCRIPT_CALL_RE.finditer(cleaned) {
                target = `match.group(1);
                off = `match.start(1);
                top: any = target.split(".", 1)[0];
                if top in _RESCRIPT_KEYWORDS or target in _RESCRIPT_KEYWORDS {
                    continue;
                }
                caller = None;
                caller_parent = None;
                for `entry in let_entries {
                    if `entry["start_off"] <= off < `entry["end_off"] {
                        caller = `entry["name"];
                        caller_parent = `entry["parent"];
                    } elif `entry["start_off"] > off {
                        break;
                    }
                }
                if caller is None {
                    continue;
                }
                if caller == target
                    and off
                        == next((e["start_off"] for e in let_entries if e["name"] == caller), -1)
                {
                    continue;
                }
                line = offset_to_line(off);
                source_qn: any = self._qualify(caller, file_path_str, caller_parent);
                edges.append(EdgeInfo("CALLS", source_qn, target, file_path_str, line));
            }
        }
        n: any;
        for n in nodes {
            if n.kind in ("Function", "Type", "Test") and n.parent_name {
                edges.append(
                    EdgeInfo(
                        "CONTAINS",
                        self._qualify(n.parent_name, file_path_str, None),
                        self._qualify(n.name, file_path_str, n.parent_name),
                        file_path_str,
                        n.line_start,
                    ),
                );
            }
        }
        member_funcs: dict[str, list[NodeInfo]] = {};
        for n in nodes {
            if n.kind == "Function" and n.parent_name {
                member_funcs.setdefault(n.parent_name, []).append(n);
            }
        }
        for mod_node in nodes {
            if mod_node.kind != "Class" {
                continue;
            }
            members: any = member_funcs.get(mod_node.name, []);
            if members and all(m.extra.get("rescript_external") for m in members) {
                mod_node.extra["rescript_kind"] = "js_binding";
            }
        }
        seen_imports: set[tuple[str, str]] = set[any]();
        deduped_edges: list[EdgeInfo] = [];
        for e in edges {
            if e.kind == "IMPORTS_FROM" {
                key: any = (e.source, e.target);
                if key in seen_imports {
                    continue;
                }
                seen_imports.add(key);
            }
            deduped_edges.append(e);
        }
        edges = deduped_edges;

        edges = self._resolve_call_targets(nodes, edges, file_path_str);

        if test_file {
            self._add_tested_by(nodes, edges);
        }

        return (nodes, edges);
    }

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

    has _PLSQL_CALL_KEYWORDS: frozenset[str] = frozenset(
        ("if elsif else then end loop while for case when begin declare exception return raise is "
            "as procedure function trigger package cursor type record table pragma and or not in "
            "exists between into over varchar varchar2 nvarchar2 number char nchar date timestamp raw "
            "boolean clob blob long float integer int smallint decimal numeric double real "
            "pls_integer binary_integer urowid rowid bfile xmltype sys_refcursor interval").split(),
    );

    has _PLSQL_BUILTIN_FUNCS: frozenset[str] = frozenset(
        ("count sum avg max min greatest least to_char to_date to_number to_timestamp cast nvl "
            "nvl2 coalesce nullif decode substr substrb instr trim ltrim rtrim upper lower initcap "
            "length lengthb replace lpad rpad concat round trunc mod abs ceil floor power sqrt "
            "extract sysdate systimestamp raise_application_error").split(),
    );

    static has _PLSQL_BUILTIN_PACKAGE_PREFIXES: any = ("dbms_", "utl_");

    static has _PLSQL_BUILTIN_RECEIVERS: any = frozenset({"", "sys", "standard"});

    static has _PLSQL_COLLECTION_METHODS: any = frozenset({"count", "trim"});

    static has _INTO_LOOKBACK: any = 60;

    static has _ORACLE_EXTENSIONS: any = frozenset(
        ".pls .plb .pks .pkb .pck .prc .fnc .trg".split()
    );

    static has _PLSQL_ROUTINE: any = _PLSQL_ROUTINE_RE;

    static has _ORACLE_SIGNAL_RE: any = re.compile(
        f"%TYPE\\b|%ROWTYPE\\b|\\bVARCHAR2\\b|\\bPLS_INTEGER\\b|\\bBINARY_INTEGER\\b|\\bSYS_REFCURSOR\\b|\\bDBMS_OUTPUT\\b|:(?:NEW|OLD)\\.|\\bCREATE\\s+(?:OR\\s+REPLACE\\s+)?PACKAGE\\b|\\bCREATE\\s+(?:OR\\s+REPLACE\\s+)?FUNCTION\\s+{_PLSQL_ROUTINE_RE}RETURN\\b|\\bCREATE\\s+(?:OR\\s+REPLACE\\s+)?PROCEDURE\\s+{_PLSQL_ROUTINE_RE}IS\\b|\\bCREATE\\s+OR\\s+REPLACE\\s+PROCEDURE\\s+{_PLSQL_ROUTINE_RE}AS\\s+[^\\s$']",
        re.IGNORECASE,
    );

    class def _is_plsql_dialect(path: Path, text: str) -> bool {
        if path.suffix.lower() in cls._ORACLE_EXTENSIONS {
            return True;
        }
        return `bool(cls._ORACLE_SIGNAL_RE.search(text));
    }

    static has _PLSQL_Q_DELIM_CLOSE: any = {"[": "]", "{": "}", "(": ")", "<": ">"};

    static def _strip_plsql_noise(text: str) -> str {
        out: list[str] = [];
        i: any;
        n: any;
        (i, n) = (0, len(text));
        in_single: any = False;
        q_close: str | None = None;
        while i < n {
            c: any = text[i];
            if q_close is not None {
                if text[i:i + len(q_close)] == q_close {
                    out.append(" " * (len(q_close) - 1) + "'");
                    i += len(q_close);
                    q_close = None;
                } else {
                    out.append("\n" if c == "\n" else " ");
                    i += 1;
                }
                continue;
            }
            if in_single {
                if c == "'" {
                    if i + 1 < n and text[i + 1] == "'" {
                        out.append("  ");
                        i += 2;
                        continue;
                    }
                    out.append("'");
                    in_single = False;
                    i += 1;
                    continue;
                }
                out.append("\n" if c == "\n" else " ");
                i += 1;
                continue;
            }
            if c == "-" and i + 1 < n and text[i + 1] == "-" {
                nl: any = text.find("\n", i);
                end: any = n if nl == -1 else nl;
                out.append(" " * (end - i));
                i = end;
                continue;
            }
            if c == "/" and i + 1 < n and text[i + 1] == "*" {
                close: any = text.find("*/", i + 2);
                seg_end: any = n if close == -1 else close + 2;
                out.append("".join("\n" if ch == "\n" else " " for ch in text[i:seg_end]));
                i = seg_end;
                continue;
            }
            if c in "qQ"
                and i + 2 < n
                and text[i + 1] == "'"
                and (i == 0 or not (text[i - 1].isalnum() or text[i - 1] == "_"))
            {
                open_delim: any = text[i + 2];
                out.append(c);
                out.append("'");
                out.append(" ");
                i += 3;
                q_close = CodeParser._PLSQL_Q_DELIM_CLOSE.get(open_delim, open_delim) + "'";
                continue;
            }
            if c == "'" {
                out.append("'");
                in_single = True;
                i += 1;
                continue;
            }
            out.append(c);
            i += 1;
        }
        return "".join(out);
    }

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

    static def _plsql_is_forward_decl(text: str, start: int) -> bool {
        depth: any = 0;
        i: any;
        n: any;
        (i, n) = (start, len(text));
        while i < n {
            c: any = text[i];
            if c == "-" and i + 1 < n and text[i + 1] == "-" {
                nl: any = text.find("\n", i);
                i = n if nl == -1 else nl + 1;
                continue;
            }
            if c == "/" and i + 1 < n and text[i + 1] == "*" {
                end: any = text.find("*/", i + 2);
                i = n if end == -1 else end + 2;
                continue;
            }
            if c == "(" {
                depth += 1;
            } elif c == ")" {
                depth -= 1;
            } elif depth <= 0 {
                if c == ";" {
                    return True;
                }
                if c.isalpha()
                    and (i == start or not (text[i - 1].isalnum() or text[i - 1] == "_"))
                {
                    if CodeParser._PLSQL_IS_AS_RE.match(text, i) {
                        return False;
                    }
                }
            }
            i += 1;
        }
        return True;
    }

    static def _plsql_member_signature(text: str, start: int) -> str {
        i: any;
        n: any;
        (i, n) = (start, len(text));
        while i < n and text[i].isspace() {
            i += 1;
        }
        if i >= n or text[i] != "(" {
            return "";
        }
        depth: any = 0;
        sig_start: any = i + 1;
        while i < n {
            c: any = text[i];
            if c == "-" and i + 1 < n and text[i + 1] == "-" {
                nl: any = text.find("\n", i);
                i = n if nl == -1 else nl + 1;
                continue;
            }
            if c == "/" and i + 1 < n and text[i + 1] == "*" {
                end: any = text.find("*/", i + 2);
                i = n if end == -1 else end + 2;
                continue;
            }
            if c == "'" {
                j: any = i + 1;
                while j < n {
                    if text[j] == "'" {
                        if j + 1 < n and text[j + 1] == "'" {
                            j += 2;
                            continue;
                        }
                        j += 1;
                        break;
                    }
                    j += 1;
                }
                i = j;
                continue;
            }
            if c == "(" {
                depth += 1;
            } elif c == ")" {
                depth -= 1;
                if depth == 0 {
                    return " ".join(text[sig_start:i].split());
                }
            }
            i += 1;
        }
        return " ".join(text[sig_start:].split());
    }

    def _parse_sql(path: Path, source: bytes) -> tuple[list[NodeInfo], list[EdgeInfo]] {
        text: any = source.decode("utf-8", errors="replace");
        file_path_str: any = normalize_file_path(path);
        test_file: any = self._is_test_path(file_path_str);

        nodes: list[NodeInfo] = [];
        edges: list[EdgeInfo] = [];

        nodes.append(
            NodeInfo(
                "File",
                file_path_str,
                file_path_str,
                1,
                text.count("\n") + 1,
                language="sql",
                is_test=test_file,
            ),
        );
        dbt_refs: any = `list(_DBT_REF_RE.finditer(text));
        dbt_model_path: any = self._is_dbt_model_path(path);
        if dbt_model_path is True or dbt_model_path is None and dbt_refs {
            self._extract_dbt_model(path, text, dbt_refs, file_path_str, test_file, nodes, edges);
            return (nodes, edges);
        }
        parser: any = self._get_parser("sql");
        if parser {
            tree: any = parser.parse(source);
            self._walk_sql_tree(tree.root_node, source, file_path_str, nodes, edges);
        }
        clean_text: any = text;
        is_plsql: any = self._is_plsql_dialect(path, text);
        if is_plsql {
            clean_text = self._strip_plsql_noise(text);
            is_plsql = self._is_plsql_dialect(path, clean_text);
            if not is_plsql {
                clean_text = text;
            }
        }
        existing_function_names: any = {
            n.name
            for n in nodes
            if n.kind == "Function" and n.extra.get("sql_kind") == "function"
        };
        m: any;
        for m in self._SQL_PROC_RE.finditer(clean_text) {
            raw_name: any = m.group(1);
            name: any = raw_name.split(".")[-1];
            line: any = clean_text[:m.start()].count("\n") + 1;
            qualified: any = f"{file_path_str}::{name}";
            line_end: any = line;
            if is_plsql {
                body_end: any = self._plsql_block_end(clean_text, m.end(), name);
                line_end = clean_text[:body_end].count("\n") + 1;
            }
            nodes.append(
                NodeInfo(
                    "Function",
                    name,
                    file_path_str,
                    line,
                    line_end,
                    language="sql",
                    extra={"sql_kind": "procedure"},
                ),
            );
            edges.append(EdgeInfo("CONTAINS", file_path_str, qualified, file_path_str, line));
            if is_plsql {
                self._extract_plsql_calls(
                    clean_text, m.end(), body_end, qualified, file_path_str, edges
                );
            }
        }
        for m in self._SQL_PLSQL_FUNC_RE.finditer(clean_text) if is_plsql else iter(()) {
            raw_name = m.group(1);
            name = raw_name.split(".")[-1];
            if name in existing_function_names {
                continue;
            }
            line = clean_text[:m.start()].count("\n") + 1;
            qualified = f"{file_path_str}::{name}";
            body_end = self._plsql_block_end(clean_text, m.end(), name);
            nodes.append(
                NodeInfo(
                    "Function",
                    name,
                    file_path_str,
                    line,
                    clean_text[:body_end].count("\n") + 1,
                    language="sql",
                    extra={"sql_kind": "function"},
                ),
            );
            edges.append(EdgeInfo("CONTAINS", file_path_str, qualified, file_path_str, line));
            self._extract_plsql_calls(
                clean_text, m.end(), body_end, qualified, file_path_str, edges
            );
        }
        for m in self._SQL_TRIGGER_RE.finditer(clean_text) if is_plsql else iter(()) {
            raw_name = m.group(1);
            name = raw_name.split(".")[-1];
            line = clean_text[:m.start()].count("\n") + 1;
            qualified = f"{file_path_str}::{name}";
            body_end = self._plsql_block_end(clean_text, m.end(), name);
            nodes.append(
                NodeInfo(
                    "Function",
                    name,
                    file_path_str,
                    line,
                    clean_text[:body_end].count("\n") + 1,
                    language="sql",
                    extra={"sql_kind": "trigger"},
                ),
            );
            edges.append(EdgeInfo("CONTAINS", file_path_str, qualified, file_path_str, line));
            self._extract_plsql_calls(
                clean_text, m.end(), body_end, qualified, file_path_str, edges
            );
        }
        for m in self._SQL_PACKAGE_RE.finditer(clean_text) if is_plsql else iter(()) {
            raw_name = m.group(1);
            name = raw_name.split(".")[-1];
            line = clean_text[:m.start()].count("\n") + 1;
            qualified = f"{file_path_str}::{name}";
            body_end = self._plsql_block_end(clean_text, m.end(), name);
            nodes.append(
                NodeInfo(
                    "Class",
                    name,
                    file_path_str,
                    line,
                    clean_text[:body_end].count("\n") + 1,
                    language="sql",
                    extra={"sql_kind": "package"},
                ),
            );
            edges.append(EdgeInfo("CONTAINS", file_path_str, qualified, file_path_str, line));
        }
        for m in self._SQL_PACKAGE_BODY_RE.finditer(clean_text) if is_plsql else iter(()) {
            raw_name = m.group(1);
            pkg_name: any = raw_name.split(".")[-1];
            body_identity: any = f"{pkg_name}$body";
            line = clean_text[:m.start()].count("\n") + 1;
            body_qualified: any = f"{file_path_str}::{body_identity}";
            body_start: any = m.end();
            body_end = self._plsql_block_end(clean_text, body_start, pkg_name, package=True);
            nodes.append(
                NodeInfo(
                    "Class",
                    pkg_name,
                    identity_name=body_identity,
                    file_path=file_path_str,
                    line_start=line,
                    line_end=clean_text[:body_end].count("\n") + 1,
                    language="sql",
                    extra={"sql_kind": "package_body"},
                ),
            );
            edges.append(EdgeInfo("CONTAINS", file_path_str, body_qualified, file_path_str, line));

            body_text: any = clean_text[body_start:body_end];
            named_ends: dict[str, list[int]] = {};
            for em in self._PLSQL_NAMED_END_RE.finditer(clean_text, body_start, body_end) {
                named_ends.setdefault(em.group(1).lower(), []).append(em.end());
            }
            members: any = `list(self._SQL_PACKAGE_MEMBER_RE.finditer(body_text));
            member_limits: any = [body_end] * len(members);
            next_of_name: dict[str, int] = {};
            for index in range(len(members) - 1, -1, -1) {
                key: any = members[index].group(2).lower();
                member_limits[index] = next_of_name.get(key, body_end);
                next_of_name[key] = body_start + members[index].start();
            }
            for (mm, member_limit) in zip(members, member_limits) {
                member_start: any = body_start + mm.end();
                if self._plsql_is_forward_decl(clean_text, member_start) {
                    continue;
                }
                member_kind: any = mm.group(1).lower();
                member_name: any = mm.group(2);
                member_sig: any = self._plsql_member_signature(clean_text, member_start);
                member_identity: any = f"{member_name}({member_sig})";
                member_line: any = clean_text[:body_start + mm.start()].count("\n") + 1;
                member_body_end: any = self._plsql_block_end(
                    clean_text, member_start, member_name, limit=member_limit, named_ends=named_ends
                );
                member_qualified: any = f"{body_qualified}.{member_identity}";
                nodes.append(
                    NodeInfo(
                        "Function",
                        member_name,
                        identity_name=member_identity,
                        file_path=file_path_str,
                        line_start=member_line,
                        line_end=clean_text[:member_body_end].count("\n") + 1,
                        language="sql",
                        parent_name=body_identity,
                        extra={
                            "sql_kind": "procedure" if member_kind == "procedure" else "function",
                        },
                    ),
                );
                edges.append(
                    EdgeInfo(
                        "CONTAINS", body_qualified, member_qualified, file_path_str, member_line
                    ),
                );
                self._extract_plsql_calls(
                    clean_text,
                    member_start,
                    member_body_end,
                    member_qualified,
                    file_path_str,
                    edges,
                );
            }
        }
        seen_refs: set[str] = set[any]();
        for m in _SQL_TABLE_RE.finditer(clean_text) {
            raw_ref: any = m.group(1).strip("`");
            ref: any = raw_ref.split(".")[-1];
            if ref and ref.upper() not in _SQL_KEYWORDS and ref not in seen_refs {
                seen_refs.add(ref);
                line = clean_text[:m.start()].count("\n") + 1;
                edges.append(EdgeInfo("IMPORTS_FROM", file_path_str, ref, file_path_str, line));
            }
        }

        return (nodes, edges);
    }

    def _is_dbt_model_path(path: Path) -> Optional[bool] {
        if self._repo_root is None {
            return None;
        }

        resolved_path: any = path.resolve();
        try {
            resolved_path.relative_to(self._repo_root);
        } except ValueError {
            return None;
        }

        directory: any = resolved_path.parent;
        while True {
            project_file: any = directory / "dbt_project.yml";
            if project_file.is_file() {
                return `any(
                    resolved_path.is_relative_to(model_path)
                    for model_path in self._dbt_model_paths(project_file),
                );
            }
            if directory == self._repo_root {
                return None;
            }
            parent: any = directory.parent;
            if parent == directory or not parent.is_relative_to(self._repo_root) {
                return None;
            }
            directory = parent;
        }
    }

    def _dbt_model_paths(project_file: Path) -> tuple[Path, ...] {
        cached: any = self._dbt_model_paths_cache.get(project_file);
        if cached is not None {
            return cached;
        }

        configured_paths: object = ["models"];
        if _yaml is not None {
            try {
                config: any = _yaml.safe_load(project_file.read_text(encoding="utf-8"));
                if isinstance(config, `dict) {
                    configured_paths = config.get("model-paths", ["models"]);
                }
            } except (OSError, _yaml.YAMLError) {
                configured_paths = ["models"];
            }
        }

        if isinstance(configured_paths, `str) {
            configured_paths = [configured_paths];
        }
        if not isinstance(configured_paths, `list) {
            configured_paths = ["models"];
        }

        model_paths: any = `tuple(
            (project_file.parent / configured_path).resolve()
            for configured_path in configured_paths
            if isinstance(configured_path, `str) and configured_path,
        );
        self._dbt_model_paths_cache[project_file] = model_paths;
        return model_paths;
    }

    def _extract_dbt_model(
        path: Path,
        text: str,
        dbt_refs: list[re.Match],
        file_path_str: str,
        test_file: bool,
        nodes: list[NodeInfo],
        edges: list[EdgeInfo],
    ) {
        model_name: any = path.stem;
        qualified: any = f"{file_path_str}::{model_name}";
        nodes.append(
            NodeInfo(
                "Class",
                model_name,
                file_path_str,
                1,
                text.count("\n") + 1,
                language="sql",
                is_test=test_file,
                extra={"sql_kind": "dbt_model"},
            ),
        );
        edges.append(EdgeInfo("CONTAINS", file_path_str, qualified, file_path_str, 1));

        seen_targets: set[str] = set[any]();
        for m in dbt_refs {
            func: any;
            first_arg: any;
            second_arg: any;
            (func, first_arg, second_arg) = (m.group(1), m.group(2), m.group(3));
            if func == "source" {
                if second_arg is None {
                    continue;
                }
                target: any = f"{first_arg}.{second_arg}";
            } elif second_arg is not None {
                target = f"{first_arg}.{second_arg}";
            } else {
                target = first_arg;
            }
            if target and target != model_name and target not in seen_targets {
                seen_targets.add(target);
                edges.append(
                    EdgeInfo(
                        "IMPORTS_FROM",
                        file_path_str,
                        target,
                        file_path_str,
                        text[:m.start()].count("\n") + 1,
                    ),
                );
            }
        }
    }

    static def _plsql_block_end(
        text: str,
        start: int,
        name: str,
        limit: int | None = None,
        named_ends: dict[str, list[int]] | None = None,
        package: bool = False,
    ) -> int {
        if limit is None {
            next_stmt: any = CodeParser._SQL_NEXT_STMT_RE.search(text, start);
            limit = next_stmt.start() if next_stmt else len(text);
        }
        if named_ends is not None {
            ends: any = named_ends.get(name.lower(), []);
            at: any = bisect_left(ends, start);
            if at < len(ends) and ends[at] <= limit {
                return ends[at];
            }
        } else {
            named: any = re.compile(
                f"\\bEND\\b\\s*{re.escape(name)}(?![\\w$#])\\s*;", re.IGNORECASE
            ).search(text, start, limit);
            if named {
                return named.end();
            }
        }
        return CodeParser._plsql_bare_end(text, start, limit, package);
    }

    static def _plsql_bare_end(text: str, start: int, limit: int, package: bool) -> int {
        open_blocks: list[str] = [];
        last_end: any = limit;
        for m in CodeParser._PLSQL_BLOCK_WORD_RE.finditer(text, start, limit) {
            if m.group("open") {
                open_blocks.append(m.group("open").upper());
                continue;
            }
            if m.group("skip") {
                continue;
            }
            semicolon: any = text.find(";", m.end(), limit);
            end: any = m.end() if semicolon == -1 else semicolon + 1;
            if not open_blocks {
                return end;
            }
            closed: any = open_blocks.pop();
            is_bare: any = not text[m.end():end - 1].strip();
            if not open_blocks and closed == "BEGIN" and is_bare and not package {
                return end;
            }
            last_end = end;
        }
        return last_end;
    }

    def _extract_plsql_calls(
        text: str,
        body_start: int,
        body_end: int,
        caller_qualified: str,
        file_path_str: str,
        edges: list[EdgeInfo],
    ) {
        body_text: any = text[body_start:body_end];
        seen: set[str] = set[any]();
        line: any = text.count("\n", 0, body_start) + 1;
        counted_to: any = 0;
        for m in self._PLSQL_CALL_RE.finditer(body_text) {
            target: any = m.group(1);
            first: any = target.split(".", 1)[0];
            receiver: any;
            _: any;
            last: any;
            (receiver, _, last) = target.rpartition(".") as any;
            if last.lower() in self._PLSQL_CALL_KEYWORDS {
                continue;
            }
            if last.upper() in _SQL_KEYWORDS {
                continue;
            }
            if receiver.lower() in self._PLSQL_BUILTIN_RECEIVERS
                and last.lower() in self._PLSQL_BUILTIN_FUNCS
            {
                continue;
            }
            if receiver and last.lower() in self._PLSQL_COLLECTION_METHODS {
                continue;
            }
            if first.lower().startswith(self._PLSQL_BUILTIN_PACKAGE_PREFIXES) {
                continue;
            }
            lookback_start: any = max(0, m.start() - self._INTO_LOOKBACK);
            if re.search("\\bINTO\\s*$", body_text[lookback_start:m.start()], re.IGNORECASE) {
                continue;
            }
            if target in seen {
                continue;
            }
            seen.add(target);
            line += body_text.count("\n", counted_to, m.start());
            counted_to = m.start();
            edges.append(
                EdgeInfo(
                    "CALLS",
                    caller_qualified,
                    last,
                    file_path_str,
                    line,
                    extra={"receiver": receiver} if receiver else {},
                ),
            );
        }
    }

    def _walk_sql_tree(
        `node, source: bytes, file_path_str: str, nodes: list[NodeInfo], edges: list[EdgeInfo]
    ) {
        if `node.type in self._SQL_DDL_NODE_TYPES {
            self._extract_sql_ddl(`node, source, file_path_str, nodes, edges);
            return;
        }
        for child in `node.children {
            self._walk_sql_tree(child, source, file_path_str, nodes, edges);
        }
    }

    def _extract_sql_ddl(
        `node, source: bytes, file_path_str: str, nodes: list[NodeInfo], edges: list[EdgeInfo]
    ) {
        node_type: any = `node.type;
        line_start: any = `node.start_point[0] + 1;
        line_end: any = `node.end_point[0] + 1;
        name: Optional[str] = None;
        for child in `node.children {
            if child.type in ("identifier", "object_reference", "dotted_name") {
                raw: any = source[child.start_byte:child.end_byte].decode(
                    "utf-8", errors="replace"
                );
                name = raw.strip("`\"").split(".")[-1];
                break;
            }
            if child.type == "relation" {
                for gc in child.children {
                    if gc.type in ("object_reference", "identifier") {
                        raw = source[gc.start_byte:gc.end_byte].decode("utf-8", errors="replace");
                        name = raw.strip("`\"").split(".")[-1];
                        break;
                    }
                }
                if name {
                    break;
                }
            }
        }

        if not name {
            return;
        }

        if node_type == "create_table" {
            kind: any = "Class";
            sql_kind: any = "table";
        } elif node_type == "create_view" {
            kind = "Class";
            sql_kind = "view";
        } else {
            kind = "Function";
            sql_kind = "function";
        }

        qualified: any = f"{file_path_str}::{name}";
        nodes.append(
            NodeInfo(
                kind,
                name,
                file_path_str,
                line_start,
                line_end,
                language="sql",
                extra={"sql_kind": sql_kind},
            ),
        );
        edges.append(EdgeInfo("CONTAINS", file_path_str, qualified, file_path_str, line_start));
    }

    def _resolve_call_targets(
        nodes: list[NodeInfo], edges: list[EdgeInfo], file_path: str
    ) -> list[EdgeInfo] {
        symbols: dict[str, list[tuple[str, Optional[str]]]];
        callable_symbols: dict[str, list[tuple[str, Optional[str]]]];
        `node: any;
        if `any(operator.eq(`node.language, "julia") for `node in nodes) {
            return self._resolve_julia_call_targets(nodes, edges, file_path);
        }
        if `any(operator.eq(`node.language, "csharp") for `node in nodes) {
            return edges;
        }

        is_cpp: any = `any(operator.eq(`node.language, "cpp") for `node in nodes);
        is_go: any = `any(operator.eq(`node.language, "go") for `node in nodes);

        def cpp_resolution_extra(extra: dict, resolution: str, candidates: list[str]) -> dict {
            limit: any = 20;
            return {
                **extra,
                f"{resolution}_targets": candidates[:limit],
                f"{resolution}_target_count": len(candidates),
                f"{resolution}_targets_truncated": operator.gt(len(candidates), limit),
            };
        }
        symbols = {};
        callable_symbols = {};
        source_scopes: dict[str, Optional[str]] = {};
        for `node in nodes {
            if `node.kind in ("Function", "Class", "Type", "Test") {
                bare: any = `node.name;
                qualified: any = self._node_qualified(`node);
                `entry: any = (qualified, `node.parent_name);
                if `entry not in symbols.setdefault(bare, []) {
                    symbols[bare].append(`entry);
                }
                if `node.kind in ("Function", "Test")
                    and `entry not in callable_symbols.setdefault(bare, [])
                {
                    callable_symbols[bare].append(`entry);
                }
                source_scopes[qualified] = `node.parent_name;
            }
        }

        go_receivers: any = {
            self._node_qualified(`node): `node.extra["go_receiver"]
            for `node in nodes
            if `node.language == "go" and "go_receiver" in `node.extra
        };
        disambiguated_leaves: any = {
            `node.parent_name.rsplit(".", 1)[-1]
            for `node in nodes
            if `node.language == "python"
                and `node.parent_name
                and "." in `node.parent_name
                and `node.kind in ("Function", "Test")
        };
        chained_scopes_by_leaf: dict[str, set[str]] = {};
        for `node in nodes {
            if `node.language not in _SEPARATE_SCOPE_RULE_LANGUAGES
                and `node.parent_name
                and `node.kind in ("Function", "Test")
            {
                chained_scopes_by_leaf.setdefault(
                    `node.parent_name.rsplit(".", 1)[-1], set[any]()
                ).add(`node.parent_name);
            }
        }
        disambiguated_leaves.update(
            leaf for (leaf, scopes) in chained_scopes_by_leaf.items() if len(scopes) > 1
        );
        disambiguated_scopes: any = {
            `node.parent_name
            for `node in nodes
            if `node.language not in ("cpp", "julia", "csharp")
                and `node.parent_name
                and `node.kind in ("Function", "Test")
                and `node.parent_name.rsplit(".", 1)[-1] in disambiguated_leaves
        };

        def candidate_entries(target: str, edge_kind: str) -> list[tuple[str, Optional[str]]] {
            entries: any = symbols.get(target, []);
            if is_cpp and edge_kind == "CALLS" {
                return callable_symbols.get(target) or entries;
            }
            return entries;
        }

        resolved: list[EdgeInfo] = [];
        `edge: any;
        for `edge in edges {
            if `edge.kind == "REFERENCES" and `edge.extra.get("julia_qualified_def") {
                resolved.append(`edge);
                continue;
            }
            if `edge.extra.get("receiver_constant") {
                resolved.append(`edge);
                continue;
            }
            receiver: any = `edge.extra.get("receiver");
            has_receiver: any = `bool(receiver)
                or operator.eq(`edge.extra.get("receiver_form"), "expression");
            scope: any = source_scopes.get(`edge.source);
            if scope in disambiguated_scopes
                and `edge.kind in ("CALLS", "REFERENCES")
                and "::" not in `edge.target
                and (not has_receiver or receiver in ("self", "this"))
            {
                entries: any = candidate_entries(`edge.target, `edge.kind);
                local: any = [qualified for (qualified, parent) in entries if parent == scope];
                if len(local) == 1 {
                    `edge = EdgeInfo(
                        `edge.kind,
                        `edge.source,
                        local[0],
                        `edge.file_path,
                        `edge.line,
                        extra=`edge.extra,
                    );
                    resolved.append(`edge);
                    continue;
                }
                if entries and not `any(parent is None for (_, parent) in entries) {
                    `edge = EdgeInfo(
                        `edge.kind,
                        `edge.source,
                        `edge.target,
                        `edge.file_path,
                        `edge.line,
                        extra={**`edge.extra, "receiver_binding": "class", "receiver_class": scope},
                    );
                    resolved.append(`edge);
                    continue;
                }
            }
            if is_go
                and `edge.kind == "CALLS"
                and `edge.extra.get("go_method_receiver")
                and receiver == go_receivers.get(`edge.source)
            {
                candidates: any = [
                    qualified
                    for (qualified, parent_scope) in candidate_entries(`edge.target, `edge.kind)
                    if parent_scope == source_scopes.get(`edge.source)
                ];
                if len(candidates) == 1 {
                    `edge = EdgeInfo(
                        `edge.kind,
                        `edge.source,
                        candidates[0],
                        `edge.file_path,
                        `edge.line,
                        extra=`edge.extra,
                    );
                    resolved.append(`edge);
                    continue;
                }
            }
            if `edge.kind in ("CALLS", "REFERENCES") and "::" not in `edge.target {
                member_call: any = `edge.extra.get("member_call");
                member_candidates: any = symbols.get(member_call, []);
                if member_candidates {
                    `edge = EdgeInfo(
                        `edge.kind,
                        `edge.source,
                        member_candidates[0][0],
                        `edge.file_path,
                        `edge.line,
                        extra=`edge.extra,
                    );
                    resolved.append(`edge);
                    continue;
                }
            }
            cpp_lexical_receiver: any = is_cpp and operator.eq(receiver, "this");
            if is_cpp
                and has_receiver
                and not cpp_lexical_receiver
                and `edge.kind in ("CALLS", "REFERENCES")
                and "::" not in `edge.target
            {
                receiver_candidates: any = [
                    qualified
                    for (qualified, _) in candidate_entries(`edge.target, `edge.kind)
                ];
                `edge = EdgeInfo(
                    `edge.kind,
                    `edge.source,
                    `edge.target,
                    `edge.file_path,
                    `edge.line,
                    extra=cpp_resolution_extra(`edge.extra, "unresolved", receiver_candidates),
                );
                resolved.append(`edge);
                continue;
            }
            if is_cpp
                and `edge.kind in ("CALLS", "REFERENCES")
                and "::" in `edge.target
                and not `edge.target.startswith(f"{file_path}::")
            {
                explicit_scope: any;
                bare_target: any;
                (explicit_scope, bare_target) = `edge.target.rsplit("::", 1) as any;
                global_scope: any = `edge.target.startswith("::");
                explicit_scope = explicit_scope.lstrip(":").replace("::", ".");
                scoped_entries: any = candidate_entries(bare_target, `edge.kind);
                if explicit_scope {
                    explicit_preferred_scopes: list[str] = [];
                    source_scope: any = source_scopes.get(`edge.source);
                    if not global_scope {
                        while source_scope {
                            explicit_preferred_scopes.append(f"{source_scope}.{explicit_scope}");
                            source_scope = source_scope.rsplit(".", 1)[0]
                                if "." in source_scope
                                else None;
                        }
                    }
                    explicit_preferred_scopes.append(explicit_scope);
                    matching_entries: any = [];
                    preferred_scope: any;
                    for preferred_scope in explicit_preferred_scopes {
                        matching_entries = [
                            (qualified, parent_scope)
                            for (qualified, parent_scope) in scoped_entries
                            if parent_scope == preferred_scope
                        ];
                        if matching_entries {
                            break;
                        }
                    }
                } else {
                    matching_entries = [
                        (qualified, parent_scope)
                        for (qualified, parent_scope) in scoped_entries
                        if parent_scope is None
                    ];
                }
                scoped_candidates: any = [qualified for (qualified, _) in matching_entries];
                if scoped_candidates {
                    if len(scoped_candidates) > 1 {
                        `edge = EdgeInfo(
                            `edge.kind,
                            `edge.source,
                            `edge.target,
                            `edge.file_path,
                            `edge.line,
                            extra=cpp_resolution_extra(`edge.extra, "ambiguous", scoped_candidates),
                        );
                    } else {
                        `edge = EdgeInfo(
                            `edge.kind,
                            `edge.source,
                            scoped_candidates[0],
                            `edge.file_path,
                            `edge.line,
                            extra=`edge.extra,
                        );
                    }
                    resolved.append(`edge);
                    continue;
                }
            }
            if `edge.kind in ("CALLS", "REFERENCES")
                and "::" not in `edge.target
                and (not has_receiver or cpp_lexical_receiver)
            {
                entries = candidate_entries(`edge.target, `edge.kind);
                candidates = [qualified for (qualified, _) in entries];
                if is_cpp and entries {
                    source_scope = source_scopes.get(`edge.source);
                    preferred_scopes: list[Optional[str]] = [];
                    while source_scope {
                        preferred_scopes.append(source_scope);
                        source_scope = source_scope.rsplit(".", 1)[0]
                            if "." in source_scope
                            else None;
                    }
                    preferred_scopes.append(None);
                    candidates = [];
                    for preferred_scope in preferred_scopes {
                        candidates = [
                            qualified
                            for (qualified, parent_scope) in entries
                            if parent_scope == preferred_scope
                        ];
                        if candidates {
                            break;
                        }
                    }
                    if not candidates {
                        `edge = EdgeInfo(
                            `edge.kind,
                            `edge.source,
                            `edge.target,
                            `edge.file_path,
                            `edge.line,
                            extra=cpp_resolution_extra(
                                `edge.extra, "unresolved", [qualified for (qualified, _) in entries]
                            ),
                        );
                        resolved.append(`edge);
                        continue;
                    }
                }
                if candidates {
                    if is_cpp and len(candidates) > 1 {
                        `edge = EdgeInfo(
                            `edge.kind,
                            `edge.source,
                            `edge.target,
                            `edge.file_path,
                            `edge.line,
                            extra=cpp_resolution_extra(`edge.extra, "ambiguous", candidates),
                        );
                        resolved.append(`edge);
                        continue;
                    }
                    `edge = EdgeInfo(
                        `edge.kind,
                        `edge.source,
                        candidates[0],
                        `edge.file_path,
                        `edge.line,
                        extra=`edge.extra,
                    );
                }
            }
            resolved.append(`edge);
        }
        return resolved;
    }

    def _resolve_julia_call_targets(
        nodes: list[NodeInfo], edges: list[EdgeInfo], file_path: str
    ) -> list[EdgeInfo] {
        qualified_boundaries: list[tuple[str, str]];
        prefix: any = f"{file_path}::";
        qualified_boundaries = [];
        `node: any;
        for `node in nodes {
            qualifier: any = `node.extra.get("julia_module_qualifier");
            if not isinstance(qualifier, `str) or not qualifier {
                continue;
            }
            identity_parent: any = `node.parent_name or "";
            parent_parts: any = identity_parent.split(".") if identity_parent else [];
            qualifier_parts: any = qualifier.split(".");
            if parent_parts[-len(qualifier_parts):] != qualifier_parts {
                continue;
            }
            lexical_parent: any = ".".join(parent_parts[:-len(qualifier_parts)]);
            identity_path: any = ".".join(part for part in (identity_parent, `node.name) if part);
            qualified_boundaries.append((identity_path, lexical_parent));
        }
        qualified_boundaries.sort(key=lambda (item) -> any { len(item[0]) }, reverse=True);

        symbols: dict[str, str] = {};
        for `node in nodes {
            if `node.kind not in ("Function", "Class", "Type", "Test") {
                continue;
            }
            qualified: any = self._qualify(`node.name, file_path, `node.parent_name);
            identity_path = qualified.removeprefix(prefix);
            symbols[identity_path] = qualified;
        }

        seen_default_: any = frozenset();

        def _search_scopes(
            source_scope: str, seen: frozenset[str] = seen_default_
        ) -> Generator[any, any, any] {
            if source_scope in seen {
                return;
            }
            next_seen: any = seen | {source_scope};
            boundary: any = next(
                (item
                for item in qualified_boundaries
                if source_scope == item[0] or source_scope.startswith(f"{item[0]}.")),
                None,
            );
            scope_parts: any = source_scope.split(".") if source_scope else [];
            if boundary is None {
                size: any;
                for size in range(len(scope_parts), -1, -1) {
                    yield ".".join(scope_parts[:size]);
                }
                return;
            }

            identity_boundary: any;
            lexical_parent: any;
            (identity_boundary, lexical_parent) = boundary as any;
            boundary_depth: any = len(identity_boundary.split("."));
            for size in range(len(scope_parts), boundary_depth - 1, -1) {
                yield ".".join(scope_parts[:size]);
            }
            yield from _search_scopes(lexical_parent, next_seen);
        }

        resolved: list[EdgeInfo] = [];
        `edge: any;
        for `edge in edges {
            if `edge.kind == "REFERENCES" and `edge.extra.get("julia_qualified_def") {
                resolved.append(`edge);
                continue;
            }
            if `edge.kind not in ("CALLS", "REFERENCES") or "::" in `edge.target {
                resolved.append(`edge);
                continue;
            }

            source_tail: any = `edge.source.removeprefix(prefix)
                if `edge.source.startswith(prefix)
                else "";
            target: any = None;
            for scope in _search_scopes(source_tail) {
                candidate: any = f"{scope}.{`edge.target}" if scope else `edge.target;
                target = symbols.get(candidate);
                if target is not None {
                    break;
                }
            }
            if target is not None {
                `edge = EdgeInfo(
                    `edge.kind, `edge.source, target, `edge.file_path, `edge.line, extra=`edge.extra
                );
            }
            resolved.append(`edge);
        }
        return resolved;
    }

    static has _TYPED_CALL_LANGUAGES: any = frozenset(
        ("python kotlin java javascript typescript tsx php csharp").split()
    );

    static has _UNRESOLVED_TYPE_LANGUAGES: any = frozenset({
        "java",
        "kotlin",
        "javascript",
        "typescript",
        "tsx",
    });

    static has _TRANSPARENT_TYPE_WRAPPERS: any = frozenset({"Annotated", "Optional", "Type"});

    static has _NON_RECEIVER_TYPE_NAMES: any = frozenset(
        ("Array Collection Dict Iterable List Map Mapping MutableList MutableMap MutableMapping "
            "ReadonlyArray Sequence Set Tuple Union dict frozenset list set tuple").split(),
    );

    def _collect_typed_call_targets(
        `root, language: str, file_path: str, import_map: dict[str, str], defined_names: set[str]
    ) -> dict[tuple[int, str, str], tuple[Optional[str], str, str]] {
        targets: dict[tuple[int, str, str], tuple[Optional[str], str, str]];
        declared_type_parameters: list[set[str]];
        if language not in self._TYPED_CALL_LANGUAGES {
            return {};
        }

        class_types: any = `set(self._class_types.get(language, []));
        function_types: any = `set(self._function_types.get(language, []));
        if language == "csharp" {
            function_types.add("local_function_statement");
        }
        call_types: any = `set(self._call_types.get(language, []));
        block_types: any = {
            "java": {"block"},
            "kotlin": {"statements"},
            "javascript": {"statement_block"},
            "typescript": {"statement_block"},
            "tsx": {"statement_block"},
            "php": {"compound_statement"},
            "csharp": {"block"},
        }.get(language)
            or set[any]();
        targets = {};
        declared_type_parameters = [];
        def type_parameters -> set[str] {
            if not declared_type_parameters {
                names: set[str] = set[any]();
                stack: any = [`root];
                while stack {
                    current: any = stack.pop();
                    if current.type == "type_parameter" {
                        name_node: any = next(
                            (child
                            for child in current.named_children
                            if child.type in ("type_identifier", "identifier")),
                            None,
                        );
                        if name_node is not None {
                            names.add(name_node.text.decode("utf-8", errors="replace"));
                        }
                        continue;
                    }
                    stack.extend(current.children);
                }
                declared_type_parameters.append(names);
            }
            return declared_type_parameters[0];
        }

        def walk(`node, bindings: dict[str, str], class_fields: dict[str, str], depth: int = 0) {
            if depth > self._MAX_AST_DEPTH {
                return;
            }
            if `node.type in class_types {
                fields: any = self._collect_class_typed_fields(
                    `node, language, function_types, class_types
                );
                class_bindings: dict[str, str] = `dict(bindings);
                if language == "csharp" {
                    name: any;
                    type_name: any;
                    for (name, type_name) in bindings.items() {
                        class_bindings[name] = _OuterBinding(
                            type_name, getattr(type_name, "levels", 0) + 1
                        );
                    }
                }
                class_bindings.update(fields);
                child: any;
                for child in `node.children {
                    walk(child, class_bindings, fields, depth + 1);
                }
                return;
            }

            if `node.type in function_types {
                scoped: any = `dict(bindings);
                scoped.update(class_fields);
                scoped.update(self._collect_function_typed_parameters(`node, language));
                for child in `node.children {
                    walk(child, scoped, class_fields, depth + 1);
                }
                return;
            }

            if `node.type in block_types {
                scoped = `dict(bindings);
                if language == "csharp" {
                    for child in `node.named_children {
                        if child.type == "local_function_statement" {
                            scoped[_csharp_name(child.child_by_field_name("name"))] = "";
                        }
                    }
                }
                for child in `node.children {
                    walk(child, scoped, class_fields, depth + 1);
                }
                return;
            }

            new_bindings: any = self._typed_bindings_from_node(`node, language);
            assigned_names: any = self._php_assigned_variables(`node)
                if language == "php"
                else set[any]();
            if new_bindings or assigned_names {
                for child in `node.children {
                    walk(child, bindings, class_fields, depth + 1);
                }
                for name in assigned_names {
                    bindings.pop(name, None);
                }
                bindings.update(new_bindings);
                return;
            }

            if `node.type in call_types {
                if language == "csharp" {
                    callee: any = `node.child_by_field_name("function");
                    if callee is not None and callee.type == "identifier" {
                        name = _csharp_name(callee);
                        if name in bindings {
                            targets[`node.start_byte, "", name] = ("", "", "shadowed_callable");
                        }
                    }
                }
                receiver: any;
                method: any;
                (receiver, method) = self._get_member_call_receiver_method(`node, language) as any;
                if receiver and method {
                    this_field: any = operator.eq(language, "java")
                        and self._java_this_field_call(`node);
                    type_name = class_fields.get(receiver)
                        if this_field
                        else bindings.get(receiver);
                    evidence: any = "constructed_receiver"
                        if language == "php"
                        else "typed_receiver";
                    if type_name is None
                        and not this_field
                        and (receiver[:1].isupper() or language == "csharp")
                        and not (language == "csharp" and receiver.split(".", 1)[0] in bindings)
                    {
                        if receiver in import_map
                            or receiver in defined_names
                            or language == "csharp"
                            or language == "java"
                                and self._java_same_package_file(receiver, file_path)
                        {
                            type_name = receiver;
                            evidence = "class_receiver";
                        }
                    }
                    if type_name {
                        target: any = self._resolve_typed_method_target(
                            type_name, method, file_path, language, import_map, defined_names
                        );
                        position: any = `node.start_byte
                            if language == "csharp"
                            else `node.start_point[0] + 1;
                        key: any = (position, receiver, method);
                        if target {
                            targets[key] = (target, type_name, evidence);
                        } elif evidence == "typed_receiver"
                            and language in self._UNRESOLVED_TYPE_LANGUAGES
                        {
                            base_type: any = self._base_type_name(type_name);
                            if base_type
                                and base_type != "var"
                                and base_type not in type_parameters()
                            {
                                targets[key] = (None, base_type, "typed_receiver_unresolved");
                            }
                        }
                    }
                }
            }

            for child in `node.children {
                walk(child, bindings, class_fields, depth + 1);
            }
        }

        walk(`root, {}, {});
        return targets;
    }

    def _collect_class_typed_fields(
        class_node, language: str, function_types: set[str], class_types: set[str]
    ) -> dict[str, str] {
        fields: dict[str, str];
        fields = {};

        def `visit(`node, depth: int = 0) {
            if depth > self._MAX_AST_DEPTH {
                return;
            }
            if `node is not class_node and `node.type in class_types {
                return;
            }
            if `node is not class_node and `node.type in function_types {
                if language in ("javascript", "typescript", "tsx") {
                    name: any = `node.child_by_field_name("name");
                    if name is not None and name.text == b"constructor" {
                        fields.update(self._collect_ts_parameter_properties(`node));
                    }
                }
                return;
            }
            fields.update(self._typed_bindings_from_node(`node, language));
            for child in `node.children {
                `visit(child, depth + 1);
            }
        }

        `visit(class_node);
        return fields;
    }

    def _collect_function_typed_parameters(function_node, language: str) -> dict[str, str] {
        bindings: dict[str, str];
        bindings = {};
        parameter_types: any = {
            "python": {"typed_parameter", "typed_default_parameter"},
            "kotlin": {"parameter"},
            "java": {"formal_parameter", "spread_parameter"},
            "javascript": {"required_parameter", "optional_parameter"},
            "typescript": {"required_parameter", "optional_parameter"},
            "tsx": {"required_parameter", "optional_parameter"},
            "csharp": {"parameter"},
        }.get(language)
            or set[any]();

        def `visit(`node, depth: int = 0) {
            if depth > self._MAX_AST_DEPTH {
                return;
            }
            if `node is not function_node and `node.type in self._function_types.get(language, []) {
                return;
            }
            if `node.type in parameter_types {
                bindings.update(self._typed_bindings_from_node(`node, language));
                return;
            }
            if `node.type in ("block", "statement_block", "function_body") {
                return;
            }
            for child in `node.children {
                `visit(child, depth + 1);
            }
        }

        `visit(function_node);
        return bindings;
    }

    def _collect_ts_parameter_properties(constructor_node) -> dict[str, str] {
        bindings: dict[str, str];
        bindings = {};

        def `visit(`node, depth: int = 0) {
            child: any;
            if depth > self._MAX_AST_DEPTH {
                return;
            }
            if `node.type in ("required_parameter", "optional_parameter") {
                has_field_modifier: any = `any(
                    child.type in ("accessibility_modifier", "override_modifier", "readonly")
                    for child in `node.children,
                );
                if has_field_modifier {
                    bindings.update(self._typed_bindings_from_node(`node, "typescript"));
                }
                return;
            }
            if `node.type == "statement_block" {
                return;
            }
            for child in `node.children {
                `visit(child, depth + 1);
            }
        }

        `visit(constructor_node);
        return bindings;
    }

    def _typed_bindings_from_node(`node, language: str) -> dict[str, str] {
        child: any;
        result: dict[str, str] = {};

        if language == "python"
            and `node.type in ("assignment", "typed_parameter", "typed_default_parameter")
        {
            name_node: any = `node.child_by_field_name("left");
            if name_node is None {
                name_node = next(
                    (child for child in `node.children if child.type == "identifier"), None
                );
            }
            type_node: any = `node.child_by_field_name("type");
            self._store_typed_binding(result, name_node, type_node);
        } elif language == "kotlin"
            and `node.type in ("class_parameter", "parameter", "variable_declaration")
        {
            name_node = next(
                (child for child in `node.children if child.type == "simple_identifier"), None
            );
            type_node = next(
                (child for child in `node.children if child.type in ("user_type", "nullable_type")),
                None,
            );
            self._store_typed_binding(result, name_node, type_node);
        } elif language == "java" and `node.type in ("formal_parameter", "spread_parameter") {
            self._store_java_typed_binding(
                result, `node.child_by_field_name("name"), `node.child_by_field_name("type")
            );
        } elif language == "java"
            and `node.type in ("field_declaration", "local_variable_declaration")
        {
            type_node = `node.child_by_field_name("type");
            for child in `node.children {
                if child.type == "variable_declarator" {
                    declared: any = type_node;
                    value: any = child.child_by_field_name("value");
                    if type_node is not None
                        and type_node.text == b"var"
                        and value is not None
                        and value.type == "object_creation_expression"
                    {
                        declared = value.child_by_field_name("type") or type_node;
                    }
                    self._store_java_typed_binding(
                        result, child.child_by_field_name("name"), declared
                    );
                }
            }
        } elif language in ("javascript", "typescript", "tsx")
            and `node.type
                in (
                    "required_parameter",
                    "optional_parameter",
                    "variable_declarator",
                    "public_field_definition",
                )
        {
            name_node = `node.child_by_field_name("name") or `node.child_by_field_name("pattern");
            if name_node is None {
                name_node = next(
                    (child for child in `node.children if child.type == "identifier"), None
                );
            }
            self._store_typed_binding(result, name_node, `node.child_by_field_name("type"));
        } elif language == "csharp" and `node.type == "variable_declaration" {
            type_node = `node.child_by_field_name("type");
            if type_node is not None and type_node.type == "implicit_type" {
                type_node = None;
            }
            for child in `node.children {
                if child.type != "variable_declarator" {
                    continue;
                }
                declared_type: any = type_node;
                if declared_type is None {
                    creation: any = next(
                        (sub for sub in child.children if sub.type == "object_creation_expression"),
                        None,
                    );
                    if creation is not None {
                        declared_type = creation.child_by_field_name("type");
                    }
                }
                self._store_typed_binding(
                    result, child.child_by_field_name("name"), declared_type, csharp=True
                );
            }
        } elif language == "csharp" and `node.type in ("parameter", "property_declaration") {
            self._store_typed_binding(
                result,
                `node.child_by_field_name("name"),
                `node.child_by_field_name("type"),
                csharp=True,
            );
        } elif language == "php" and `node.type == "assignment_expression" {
            name_node = `node.child_by_field_name("left");
            value_node: any = `node.child_by_field_name("right");
            if name_node is not None
                and name_node.type == "variable_name"
                and value_node is not None
                and value_node.type == "object_creation_expression"
            {
                type_node = next(
                    (child
                    for child in value_node.children
                    if child.type in ("name", "qualified_name")),
                    None,
                );
                if type_node is not None {
                    name: any = name_node.text.decode("utf-8", errors="replace");
                    type_name: any = type_node.text.decode("utf-8", errors="replace").strip("\\");
                    if name and type_name {
                        result[name] = type_name;
                    }
                }
            }
        }

        return result;
    }

    static def _php_assigned_variables(`node) -> set[str] {
        if `node.type != "assignment_expression" {
            return set[any]();
        }
        name_node: any = `node.child_by_field_name("left");
        if name_node is None or name_node.type != "variable_name" {
            return set[any]();
        }
        name: any = name_node.text.decode("utf-8", errors="replace");
        return {name} if name else set[any]();
    }

    class def _store_typed_binding(
        result: dict[str, str], name_node, type_node, *, csharp: bool = False
    ) {
        if name_node is None {
            return;
        }
        if csharp {
            result[_csharp_name(name_node)] = _csharp_name(type_node);
            return;
        }
        if type_node is None {
            return;
        }
        name: any = name_node.text.decode("utf-8", errors="replace");
        type_name: any = cls._base_type_name(type_node.text.decode("utf-8", errors="replace"));
        if name and type_name {
            result[name] = type_name;
        }
    }

    class def _store_java_typed_binding(result: dict[str, str], name_node, type_node) {
        cls._store_typed_binding(result, name_node, type_node);
        if name_node is None or type_node is None {
            return;
        }
        name: any = name_node.text.decode("utf-8", errors="replace");
        qualified: any = _JAVA_PACKAGE_QUALIFIED_TYPE.match(
            type_node.text.decode("utf-8", errors="replace").strip()
        );
        if name in result
            and qualified is not None
            and qualified.group(0).rsplit(".", 1)[-1] == result[name]
        {
            result[name] = qualified.group(0);
        }
    }

    class def _base_type_name(annotation: str) -> Optional[str] {
        current: any = annotation.strip();
        for _ in range(4) {
            `match: any = re.search("[\\\"']?([A-Za-z_][A-Za-z0-9_.]*)", current);
            if `match is None {
                return None;
            }
            outer: any = `match.group(1).rsplit(".", 1)[-1];
            remainder: any = current[`match.end():].lstrip();
            if remainder.startswith("[]") {
                return None;
            }
            if outer in cls._TRANSPARENT_TYPE_WRAPPERS {
                openings: any = [
                    index
                    for index in (current.find("["), current.find("<"))
                    if index >= 0
                ];
                if not openings {
                    return None;
                }
                current = current[min(openings) + 1:].lstrip();
                continue;
            }
            if outer in cls._NON_RECEIVER_TYPE_NAMES {
                return None;
            }
            if outer
                in tuple("None bool boolean float int number str string unknown void".split())
            {
                return None;
            }
            return outer;
        }
        return None;
    }

    def _resolve_typed_method_target(
        type_name: str,
        method: str,
        file_path: str,
        language: str,
        import_map: dict[str, str],
        defined_names: set[str],
    ) -> Optional[str] {
        if language == "php" {
            normalized: any = type_name.strip("\\");
            if not normalized {
                return None;
            }
            local_name: any = normalized.rsplit("\\", 1)[-1];
            imported: any = import_map.get(local_name.casefold());
            scope: any = imported or normalized;
            return f"{scope}::{method}";
        }

        if language == "csharp" {
            return f"{type_name}::{method}" if type_name else None;
        }

        if language == "java" and _JAVA_PACKAGE_QUALIFIED_TYPE.fullmatch(type_name) {
            package_file: any = self._resolve_module_to_file(type_name, file_path, language);
            if not package_file {
                return None;
            }
            class_name: any = type_name.rsplit(".", 1)[-1];
            return f"{self._qualify(class_name, package_file, None)}.{method}";
        }

        base_type: any = self._base_type_name(type_name);
        if not base_type {
            return None;
        }
        if base_type in import_map {
            resolved: any = self._resolve_imported_symbol(
                self._js_imported_symbol_name(base_type, import_map),
                import_map[base_type],
                file_path,
                language,
            );
            if resolved {
                return f"{resolved}.{method}";
            }
        }
        if base_type in defined_names {
            return f"{file_path}::{base_type}.{method}";
        }
        if language == "java" and base_type not in import_map {
            same_package: any = self._java_same_package_file(base_type, file_path);
            if same_package {
                return f"{same_package}::{base_type}.{method}";
            }
        }
        return None;
    }

    static def _apply_typed_call_targets(
        edges: list[EdgeInfo],
        targets: dict[tuple[int, str, str], tuple[Optional[str], str, str]],
        language: str,
    ) -> list[EdgeInfo] {
        if not targets {
            return edges;
        }
        resolved: list[EdgeInfo] = [];
        `edge: any;
        for `edge in edges {
            receiver: any = `edge.extra.get("receiver");
            method: any = `edge.target.rsplit(".", 1)[-1].rsplit("::", 1)[-1];
            position: any = `edge.extra.get("source_offset", -1)
                if language == "csharp"
                else `edge.line;
            evidence: any = targets.get((position, receiver or "", method))
                if receiver or language == "csharp"
                else None;
            if `edge.kind == "CALLS" and evidence {
                target: any;
                type_name: any;
                evidence_kind: any;
                (target, type_name, evidence_kind) = evidence as any;
                extra: any = `dict(`edge.extra);
                extra.update({"receiver_type": type_name, "receiver_resolution": evidence_kind});
                resolved_target: any = target;
                if target is None {
                    resolved_target = `edge.target;
                } elif evidence_kind == "constructed_receiver" or language == "csharp" {
                    scope: any;
                    separator: any;
                    _: any;
                    (scope, separator, _) = target.rpartition("::") as any;
                    if separator and scope {
                        extra["receiver_scope"] = scope;
                    }
                    resolved_target = `edge.target;
                    levels: any = getattr(type_name, "levels", 0);
                    if language == "csharp" and levels {
                        extra["csharp_receiver_levels"] = levels;
                    }
                }
                `edge = EdgeInfo(
                    `edge.kind,
                    `edge.source,
                    resolved_target,
                    `edge.file_path,
                    `edge.line,
                    extra=extra,
                );
            }
            resolved.append(`edge);
        }
        return resolved;
    }

    def _collect_python_receiver_evidence(
        `root, file_path: str, source: bytes
    ) -> tuple[dict[tuple[int, str], tuple[str, str]], list[EdgeInfo]] {
        module_bindings: dict[str, set[str]];
        imported_names: set[str];
        class_names: set[str];
        ambiguous_property_classes: set[str];
        symbol_binding_candidates: dict[str, set[tuple[str, str]]];
        local_returns: dict[str, str];
        property_returns: dict[tuple[str, str], str];
        ambiguous_returns: set[str];
        name: any;
        evidence: dict[tuple[int, str], tuple[str, str]];
        expression_evidence: dict[tuple[int, str], list[tuple[str, str]]];
        property_read_edges: list[EdgeInfo];
        key: any;
        module_bindings = {};
        imported_names = set[any]();
        class_names = set[any]();
        ambiguous_property_classes = set[any]();
        symbol_binding_candidates = {};
        local_returns = {};
        property_returns = {};
        ambiguous_returns = set[any]();

        def scan_declarations(
            `node, owner_class: Optional[str], in_function: bool = False, depth: int = 0
        ) {
            if depth > self._MAX_AST_DEPTH {
                return;
            }
            if `node.type == "class_definition" {
                name_node: any = `node.child_by_field_name("name");
                if name_node is not None {
                    owner_class = name_node.text.decode("utf-8", errors="replace");
                    if owner_class in class_names {
                        ambiguous_property_classes.add(owner_class);
                    }
                    class_names.add(owner_class);
                }
                in_function = False;
            } elif `node.type == "function_definition" and owner_class and not in_function {
                name_node = `node.child_by_field_name("name");
                return_node: any = `node.child_by_field_name("return_type");
                decorators: any = _python_decorator_names(`node);
                if name_node is not None
                    and `any(
                        operator.eq(decorator.rsplit(".", 1)[-1], "property")
                        for decorator in decorators,
                    )
                {
                    property_name: any = name_node.text.decode("utf-8", errors="replace");
                    property_returns[owner_class, property_name] = return_node.text.decode(
                        "utf-8", errors="replace"
                    )
                        if return_node is not None
                        else "";
                }
            } elif `node.type == "function_definition" and owner_class is None and not in_function {
                name_node = `node.child_by_field_name("name");
                type_node: any = `node.child_by_field_name("return_type");
                if name_node is not None and type_node is not None {
                    name: any = name_node.text.decode("utf-8", errors="replace");
                    annotation: any = type_node.text.decode("utf-8", errors="replace");
                    if local_returns.get(name, annotation) != annotation {
                        ambiguous_returns.add(name);
                    }
                    local_returns[name] = annotation;
                }
            } elif `node.type == "import_statement" {
                self._python_plain_import_bindings(
                    `node, file_path, module_bindings, imported_names
                );
            } elif `node.type == "import_from_statement" {
                import_origins: dict[str, str] = {};
                import_names: dict[str, str] = {};
                self._python_from_import_bindings(
                    `node, file_path, module_bindings, imported_names, import_origins, import_names
                );
                for (name, origin) in import_origins.items() {
                    imported_name: any = import_names.get(name);
                    if imported_name is not None {
                        symbol_binding_candidates.setdefault(name, set[any]()).add((
                            origin,
                            imported_name,
                        ));
                    }
                }
            }
            for child in `node.children {
                scan_declarations(
                    child,
                    owner_class,
                    in_function or operator.eq(`node.type, "function_definition"),
                    depth + 1,
                );
            }
        }

        scan_declarations(`root, None);
        symbol_origins: any = {
            name: next(iter(bindings))[0]
            for (name, bindings) in symbol_binding_candidates.items()
            if len(bindings) == 1
        };
        symbol_names: any = {
            name: next(iter(bindings))[1]
            for (name, bindings) in symbol_binding_candidates.items()
            if len(bindings) == 1
        };
        for name in ambiguous_returns {
            local_returns.pop(name, None);
        }
        if ambiguous_property_classes {
            property_returns = {
                key: annotation
                for (key, annotation) in property_returns.items()
                if key[0] not in ambiguous_property_classes
            };
        }

        context: any = _PyReceiverContext(
            file_path=file_path,
            class_names=frozenset(class_names),
            imported_names=frozenset(imported_names),
            module_bindings=module_bindings,
            symbol_origins=symbol_origins,
            symbol_names=symbol_names,
            local_returns=local_returns,
            property_returns=property_returns,
        );

        module_env: dict[str, tuple[str, str]] = {};
        for name in imported_names | class_names {
            module_env[name] = ("class", name);
        }
        for (name, files) in module_bindings.items() {
            module_env[name] = ("module", next(iter(files)))
                if len(files) == 1
                else ("unknown", "");
        }

        evidence = {};
        expression_evidence = {};
        property_read_edges = [];
        unreachable_positions: any = _python_unreachable_call_positions(source);
        function_scopes: any = _python_function_scope_bindings(source);
        def bind_targets(
            left,
            value,
            type_node,
            env,
            class_fields,
            current_class,
            instance_receiver_name,
            class_receiver_name,
        ) {
            for (name, path) in self._python_binding_targets(left) {
                bound: any = self._python_binding_evidence(
                    value,
                    type_node,
                    path,
                    context,
                    env,
                    class_fields,
                    current_class,
                    instance_receiver_name,
                    class_receiver_name,
                );
                if bound is not None {
                    env[name] = bound;
                }
            }
        }

        def first_parameter_name(function_node) -> Optional[str] {
            parameters: any = function_node.child_by_field_name("parameters");
            if parameters is None or not parameters.named_children {
                return None;
            }
            first: any = parameters.named_children[0];
            if first.type == "identifier" {
                return first.text.decode("utf-8", errors="replace");
            }
            if first.type in ("typed_parameter", "typed_default_parameter", "default_parameter") {
                name: any = next(
                    (child for child in first.children if child.type == "identifier"), None
                );
                return name.text.decode("utf-8", errors="replace") if name is not None else None;
            }
            return None;
        }
        def instance_receiver_parameter(function_node) -> Optional[str] {
            if `any(
                decorator.rsplit(".", 1)[-1] in {"classmethod", "staticmethod"}
                for decorator in _python_decorator_names(function_node),
            ) {
                return None;
            }
            return first_parameter_name(function_node);
        }
        def class_receiver_parameter(function_node) -> Optional[str] {
            if `any(
                operator.eq(decorator.rsplit(".", 1)[-1], "classmethod")
                for decorator in _python_decorator_names(function_node),
            ) {
                return first_parameter_name(function_node);
            }
            return None;
        }

        def is_named_receiver(expression, receiver_name: Optional[str]) -> bool {
            return expression is not None
                and operator.eq(expression.type, "identifier")
                and receiver_name is not None
                and operator.eq(expression.text.decode("utf-8", errors="replace"), receiver_name);
        }
        def is_attribute_store_target(attribute_node) -> bool {
            parent: any = attribute_node.parent;
            while parent is not None {
                if parent.type in ("attribute", "subscript", "augmented_assignment") {
                    return False;
                }
                if parent.type in ("assignment", "for_statement", "for_in_clause") {
                    target: any = parent.child_by_field_name("left")
                        or parent.child_by_field_name("target");
                    return target is not None
                        and operator.le(target.start_byte, attribute_node.start_byte)
                        and operator.le(attribute_node.end_byte, target.end_byte);
                }
                if parent.type == "as_pattern" {
                    alias: any = parent.child_by_field_name("alias");
                    return alias is not None and _node_is_in_child(attribute_node, alias);
                }
                if parent.type == "delete_statement" {
                    return True;
                }
                parent = parent.parent;
            }
            return False;
        }

        def walk(
            `node,
            env: dict[str, tuple[str, str]],
            class_fields: dict[str, tuple[str, str]],
            current_class: Optional[str] = None,
            current_function: Optional[str] = None,
            depth: int = 0,
            instance_receiver_name: Optional[str] = None,
            class_receiver_name: Optional[str] = None,
        ) {
            if depth > self._MAX_AST_DEPTH {
                return;
            }
            node_type: any = `node.type;
            if node_type == "class_definition" {
                fields: any = self._collect_python_class_fields(`node, context);
                name_node: any = `node.child_by_field_name("name");
                nested_class: any = name_node.text.decode("utf-8", errors="replace")
                    if name_node is not None
                    else current_class;
                class_env: any = `dict(env);
                class_env.update(fields);
                child: any;
                for child in `node.children {
                    walk(
                        child,
                        class_env,
                        fields,
                        nested_class,
                        current_function,
                        depth + 1,
                        None,
                        class_receiver_name,
                    );
                }
                return;
            }
            if node_type == "function_definition" {
                scoped: any = `dict(env);
                scoped.update(class_fields);
                function_key: any = (`node.start_point[0] + 1, `node.start_point[1]);
                parameter_names: any;
                local_names: any;
                (parameter_names, local_names) = function_scopes.get(
                    function_key, (frozenset(), frozenset())
                ) as any;
                for parameter_name in parameter_names {
                    scoped.pop(parameter_name, None);
                }
                for (name, type_name) in self._collect_function_typed_parameters(
                    `node, "python"
                ).items() {
                    scoped[name] = ("class", type_name);
                }
                name_node = `node.child_by_field_name("name");
                function_name: any = name_node.text.decode("utf-8", errors="replace")
                    if name_node is not None
                    else current_function;
                receiver_name: any = instance_receiver_parameter(`node)
                    if current_class and current_function is None
                    else instance_receiver_name
                        if instance_receiver_name is not None
                            and instance_receiver_name not in local_names
                        else None;
                class_receiver: any = class_receiver_parameter(`node)
                    if current_class and current_function is None
                    else class_receiver_name
                        if class_receiver_name is not None
                            and class_receiver_name not in local_names
                        else None;
                for child in `node.children {
                    walk(
                        child,
                        scoped,
                        class_fields,
                        current_class,
                        function_name,
                        depth + 1,
                        receiver_name,
                        class_receiver,
                    );
                }
                return;
            }
            if node_type == "assignment" {
                for child in `node.children {
                    walk(
                        child,
                        env,
                        class_fields,
                        current_class,
                        current_function,
                        depth + 1,
                        instance_receiver_name,
                        class_receiver_name,
                    );
                }
                bind_targets(
                    `node.child_by_field_name("left"),
                    `node.child_by_field_name("right"),
                    `node.child_by_field_name("type"),
                    env,
                    class_fields,
                    current_class,
                    instance_receiver_name,
                    class_receiver_name,
                );
                return;
            }
            if node_type == "as_pattern" {
                for child in `node.children {
                    walk(
                        child,
                        env,
                        class_fields,
                        current_class,
                        current_function,
                        depth + 1,
                        instance_receiver_name,
                        class_receiver_name,
                    );
                }
                alias: any = `node.child_by_field_name("alias");
                value: any = `node.children[0] if `node.children else None;
                if alias is not None and value is not None and value is not alias {
                    bind_targets(
                        alias.children[0]
                            if alias.type == "as_pattern_target" and alias.children
                            else alias,
                        value,
                        None,
                        env,
                        class_fields,
                        current_class,
                        instance_receiver_name,
                        class_receiver_name,
                    );
                }
                return;
            }
            if node_type == "attribute" {
                owner: any = `node.child_by_field_name("object");
                property_name_node: any = `node.child_by_field_name("attribute");
                owner_evidence: any = self._python_expression_class_evidence(
                    owner,
                    env,
                    class_fields,
                    current_class,
                    context,
                    instance_receiver_name,
                    class_receiver_name,
                );
                if not is_attribute_store_target(`node)
                    and (`node.start_point[0] + 1, `node.start_point[1])
                        not in unreachable_positions
                    and owner_evidence is not None
                    and owner_evidence[0] == "class"
                    and property_name_node is not None
                {
                    property_name: any = property_name_node.text.decode("utf-8", errors="replace");
                    definition: any = self._python_property_definition(
                        owner_evidence[1], property_name, context
                    );
                    if definition is not None
                        and not is_named_receiver(owner, class_receiver_name)
                    {
                        target_file: any;
                        target_class: any;
                        _: any;
                        (target_file, target_class, _) = definition as any;
                        caller: any = self._qualify(current_function, file_path, current_class)
                            if current_function
                            else file_path;
                        property_read_edges.append(
                            EdgeInfo(
                                "CALLS",
                                caller,
                                self._qualify(property_name, target_file, target_class),
                                file_path,
                                `node.start_point[0] + 1,
                                extra={"python_property_read": True},
                            ),
                        );
                    }
                }
            }
            if node_type == "call" {
                receiver: any;
                method: any;
                (receiver, method) = self._get_member_call_receiver_method(`node, "python") as any;
                if receiver and method {
                    evidence[`node.start_point[0] + 1, receiver] = env.get(
                        receiver, ("unknown", "")
                    );
                } elif method {
                    constructed: any = self._python_expression_receiver_evidence(`node, context);
                    if constructed is None {
                        callee: any = `node.child_by_field_name("function");
                        receiver_node: any = callee.child_by_field_name("object")
                            if callee is not None and callee.type == "attribute"
                            else None;
                        constructed = self._python_expression_class_evidence(
                            receiver_node,
                            env,
                            class_fields,
                            current_class,
                            context,
                            instance_receiver_name,
                            class_receiver_name,
                        );
                    }
                    if constructed is not None {
                        key: any = (`node.start_point[0] + 1, _PY_EXPR_RECEIVER_KEY + method);
                        expression_evidence.setdefault(key, []).append(constructed);
                    }
                }
            }
            for child in `node.children {
                walk(
                    child,
                    env,
                    class_fields,
                    current_class,
                    current_function,
                    depth + 1,
                    instance_receiver_name,
                    class_receiver_name,
                );
            }
        }

        walk(`root, module_env, {});
        for (key, found) in expression_evidence.items() {
            evidence[key] = self._merge_python_evidence(found);
        }
        return (evidence, property_read_edges);
    }

    def _collect_python_class_fields(
        class_node, context: _PyReceiverContext
    ) -> dict[str, tuple[str, str]] {
        gathered: dict[str, list[tuple[str, str]]];
        gathered = {};

        def record(left, value, type_node, nested: bool) {
            for (name, path) in self._python_binding_targets(left) {
                if nested and not self._python_target_is_attribute(left, name) {
                    continue;
                }
                bound: any = self._python_binding_evidence(value, type_node, path, context);
                if bound is not None {
                    gathered.setdefault(name, []).append(bound);
                }
            }
        }

        def `visit(`node, in_function: bool, depth: int = 0) {
            if depth > self._MAX_AST_DEPTH {
                return;
            }
            if `node is not class_node and `node.type == "class_definition" {
                return;
            }
            nested: any = in_function
                or `node is not class_node and operator.eq(`node.type, "function_definition");
            if `node.type == "as_pattern" {
                alias: any = `node.child_by_field_name("alias");
                value: any = `node.children[0] if `node.children else None;
                if alias is not None and value is not None and value is not alias {
                    record(
                        alias.children[0]
                            if alias.type == "as_pattern_target" and alias.children
                            else alias,
                        value,
                        None,
                        nested,
                    );
                }
            }
            if `node.type == "assignment" {
                left: any = `node.child_by_field_name("left");
                if left is not None {
                    record(
                        left,
                        `node.child_by_field_name("right"),
                        `node.child_by_field_name("type"),
                        nested,
                    );
                }
            }
            for child in `node.children {
                `visit(child, nested, depth + 1);
            }
        }

        `visit(class_node, False);
        return {name: self._merge_python_evidence(found) for (name, found) in gathered.items()};
    }

    def _python_property_definition(
        owner_type: str, property_name: str, context: _PyReceiverContext
    ) -> Optional[tuple[str, str, str]] {
        identity: any = _python_split_class_identity(owner_type);
        if identity is not None {
            origin: any;
            actual_class: any;
            (origin, actual_class) = identity as any;
            annotations: any = self._python_module_property_return_annotations(origin);
            key: any = (actual_class, property_name);
            if key not in annotations {
                return None;
            }
            return (origin, actual_class, annotations[key]);
        }

        local_key: any = (owner_type, property_name);
        if local_key in context.property_returns {
            return (context.file_path, owner_type, context.property_returns[local_key]);
        }

        origin = context.symbol_origins.get(owner_type);
        if not origin {
            return None;
        }
        actual_class = context.symbol_names.get(owner_type, owner_type);
        annotations = self._python_module_property_return_annotations(origin);
        key = (actual_class, property_name);
        if key not in annotations {
            return None;
        }
        return (origin, actual_class, annotations[key]);
    }

    def _python_module_property_return_annotations(module_file: str) -> dict[tuple[str, str], str] {
        if not module_file.endswith(".py") {
            return {};
        }
        try {
            module_path: any = Path(module_file).resolve();
            file_stat: any = module_path.stat();
        } except (OSError, ValueError) {
            return {};
        }
        resolved: any = normalize_file_path(module_path);
        if self._excluded_files and resolved in self._excluded_files {
            return {};
        }
        cache_key: any = (resolved, file_stat.st_mtime_ns, file_stat.st_size);
        with _PYTHON_RETURN_ANNOTATION_CACHE_LOCK {
            cached: any = _PYTHON_PROPERTY_RETURN_ANNOTATION_CACHE.get(cache_key);
            if cached is not None {
                return cached;
            }
            properties: any = self._read_python_property_return_annotations(module_path);
            for stale in [
                key
                for key in _PYTHON_PROPERTY_RETURN_ANNOTATION_CACHE
                if key[0] == resolved and key != cache_key
            ] {
                _PYTHON_PROPERTY_RETURN_ANNOTATION_CACHE.pop(stale, None);
            }
            if len(_PYTHON_PROPERTY_RETURN_ANNOTATION_CACHE) >= _PYTHON_STAR_CACHE_MAX {
                for oldest in `list(
                    _PYTHON_PROPERTY_RETURN_ANNOTATION_CACHE
                )[:_PYTHON_STAR_CACHE_MAX // 2] {
                    _PYTHON_PROPERTY_RETURN_ANNOTATION_CACHE.pop(oldest, None);
                }
            }
            _PYTHON_PROPERTY_RETURN_ANNOTATION_CACHE[cache_key] = properties;
            return properties;
        }
    }

    def _python_module_class_identities(module_file: str) -> dict[str, tuple[str, str]] {
        class_counts: dict[str, int];
        imported_names: set[str];
        module_bindings: dict[str, set[str]];
        symbol_bindings: dict[str, set[tuple[str, str]]];
        name: any;
        try {
            module_path: any = Path(module_file).resolve();
            file_stat: any = module_path.stat();
            source: any = module_path.read_bytes();
        } except (OSError, RuntimeError, ValueError) {
            return {};
        }
        resolved: any = normalize_file_path(module_path);
        if self._excluded_files and resolved in self._excluded_files {
            return {};
        }
        cache_key: any = (resolved, file_stat.st_mtime_ns, file_stat.st_size);
        with _PYTHON_MODULE_CLASS_IDENTITY_CACHE_LOCK {
            cached: any = _PYTHON_MODULE_CLASS_IDENTITY_CACHE.get(cache_key);
            if cached is not None {
                return cached;
            }
        }

        parser: any = self._get_parser("python");
        if not parser {
            return {};
        }
        try {
            tree: any = parser.parse(source);
        } except (RecursionError, ValueError) {
            return {};
        }

        class_counts = {};
        imported_names = set[any]();
        module_bindings = {};
        symbol_bindings = {};

        def `visit(`node, depth: int = 0) {
            if depth > self._MAX_AST_DEPTH or `node.type == "function_definition" {
                return;
            }
            if `node.type == "class_definition" {
                name_node: any = `node.child_by_field_name("name");
                if name_node is not None {
                    name: any = name_node.text.decode("utf-8", errors="replace");
                    class_counts[name] = class_counts.get(name, 0) + 1;
                }
            } elif `node.type == "import_statement" {
                self._python_plain_import_bindings(
                    `node, resolved, module_bindings, imported_names
                );
            } elif `node.type == "import_from_statement" {
                import_origins: dict[str, str] = {};
                import_names: dict[str, str] = {};
                self._python_from_import_bindings(
                    `node, resolved, module_bindings, imported_names, import_origins, import_names
                );
                for (name, origin) in import_origins.items() {
                    imported_name: any = import_names.get(name);
                    if imported_name is not None {
                        symbol_bindings.setdefault(name, set[any]()).add((origin, imported_name));
                    }
                }
            }
            for child in `node.children {
                `visit(child, depth + 1);
            }
        }

        `visit(tree.root_node);
        identities: any = {
            name: (resolved, name)
            for (name, count) in class_counts.items()
            if count == 1 and name not in symbol_bindings
        };
        for (name, bindings) in symbol_bindings.items() {
            if len(bindings) == 1 and name not in class_counts {
                identities[name] = next(iter(bindings));
            }
        }

        with _PYTHON_MODULE_CLASS_IDENTITY_CACHE_LOCK {
            for stale in [
                key
                for key in _PYTHON_MODULE_CLASS_IDENTITY_CACHE
                if key[0] == resolved and key != cache_key
            ] {
                _PYTHON_MODULE_CLASS_IDENTITY_CACHE.pop(stale, None);
            }
            if len(_PYTHON_MODULE_CLASS_IDENTITY_CACHE) >= _PYTHON_STAR_CACHE_MAX {
                for oldest in `list(_PYTHON_MODULE_CLASS_IDENTITY_CACHE)[:_PYTHON_STAR_CACHE_MAX
                    // 2] {
                    _PYTHON_MODULE_CLASS_IDENTITY_CACHE.pop(oldest, None);
                }
            }
            _PYTHON_MODULE_CLASS_IDENTITY_CACHE[cache_key] = identities;
        }
        return identities;
    }

    def _read_python_property_return_annotations(module_path: Path) -> dict[tuple[str, str], str] {
        properties: dict[tuple[str, str], str];
        class_names: set[str];
        ambiguous_classes: set[str];
        try {
            source: any = module_path.read_bytes();
        } except (OSError, PermissionError) {
            return {};
        }
        parser: any = self._get_parser("python");
        if not parser {
            return {};
        }
        try {
            tree: any = parser.parse(source);
        } except (RecursionError, ValueError) as exc {
            logger.debug("Property-annotation parse failed for %s: %s", module_path, exc);
            return {};
        }

        properties = {};
        class_names = set[any]();
        ambiguous_classes = set[any]();

        def `visit(
            `node, owner_class: Optional[str] = None, in_function: bool = False, depth: int = 0
        ) -> any {
            if depth > self._MAX_AST_DEPTH {
                return;
            }
            if `node.type == "class_definition" {
                name_node: any = `node.child_by_field_name("name");
                nested_class: any = name_node.text.decode("utf-8", errors="replace")
                    if name_node is not None
                    else owner_class;
                if name_node is not None {
                    if nested_class in class_names {
                        ambiguous_classes.add(nested_class);
                    }
                    class_names.add(nested_class);
                }
                child: any;
                for child in `node.children {
                    `visit(child, nested_class, False, depth + 1);
                }
                return;
            }
            if `node.type == "function_definition" {
                if owner_class and not in_function {
                    name_node = `node.child_by_field_name("name");
                    if name_node is not None
                        and `any(
                            operator.eq(decorator.rsplit(".", 1)[-1], "property")
                            for decorator in _python_decorator_names(`node),
                        )
                    {
                        return_node: any = `node.child_by_field_name("return_type");
                        properties[owner_class, name_node.text.decode(
                            "utf-8", errors="replace"
                        )] = return_node.text.decode("utf-8", errors="replace")
                            if return_node is not None
                            else "";
                    }
                }
                for child in `node.children {
                    `visit(child, owner_class, True, depth + 1);
                }
                return;
            }
            for child in `node.children {
                `visit(child, owner_class, in_function, depth + 1);
            }
        }

        `visit(tree.root_node);
        if ambiguous_classes {
            properties = {
                key: annotation
                for (key, annotation) in properties.items()
                if key[0] not in ambiguous_classes
            };
        }
        return properties;
    }

    def _python_expression_class_evidence(
        expression,
        env: dict[str, tuple[str, str]],
        class_fields: dict[str, tuple[str, str]],
        current_class: Optional[str],
        context: _PyReceiverContext,
        instance_receiver_name: Optional[str] = None,
        class_receiver_name: Optional[str] = None,
    ) -> Optional[tuple[str, str]] {
        if expression is None {
            return None;
        }
        if expression.type == "identifier" {
            name: any = expression.text.decode("utf-8", errors="replace");
            if name == class_receiver_name {
                return ("class", current_class) if current_class else None;
            }
            if name == instance_receiver_name {
                return ("class", current_class) if current_class else None;
            }
            if name in context.class_names or name in context.imported_names {
                return None;
            }
            return env.get(name);
        }
        if expression.type != "attribute" {
            return None;
        }
        owner: any = expression.child_by_field_name("object");
        attribute: any = expression.child_by_field_name("attribute");
        if attribute is None {
            return None;
        }
        owner_evidence: any = self._python_expression_class_evidence(
            owner,
            env,
            class_fields,
            current_class,
            context,
            instance_receiver_name,
            class_receiver_name,
        );
        if owner_evidence is None or owner_evidence[0] != "class" {
            return None;
        }
        member: any = attribute.text.decode("utf-8", errors="replace");
        is_class_receiver: any = operator.eq(owner.type, "identifier")
            and class_receiver_name is not None
            and operator.eq(owner.text.decode("utf-8", errors="replace"), class_receiver_name);
        if is_class_receiver
            and self._python_property_definition(owner_evidence[1], member, context) is not None
        {
            return ("unknown", "");
        }
        if owner_evidence[1] == current_class {
            field_evidence: any = class_fields.get(member);
            if field_evidence is not None and field_evidence[0] == "class" {
                return field_evidence;
            }
        }
        definition: any = self._python_property_definition(owner_evidence[1], member, context);
        if definition is None {
            return None;
        }
        annotation: any = definition[2];
        if not annotation {
            return ("unknown", "");
        }
        type_name: any = self._base_type_name(annotation);
        if not type_name {
            return ("builtin", "");
        }
        defining_file: any = definition[0];
        if defining_file == context.file_path {
            origin: any = context.symbol_origins.get(type_name);
            if origin {
                if type_name in context.class_names or type_name in context.imported_names {
                    return ("unknown", "");
                }
                return (
                    "class",
                    _python_qualified_class_identity(
                        origin, context.symbol_names.get(type_name, type_name)
                    ),
                );
            }
            return ("class", type_name);
        }
        identity: any = self._python_module_class_identities(defining_file).get(type_name);
        if identity is None {
            return ("unknown", "");
        }
        return ("class", _python_qualified_class_identity(*identity));
    }

    static def _merge_python_evidence(found: list[tuple[str, str]]) -> tuple[str, str] {
        classes: any = {detail for (kind, detail) in found if kind == "class"};
        modules: any = {detail for (kind, detail) in found if kind == "module"};
        builtin: any = `any(operator.eq(kind, "builtin") for (kind, _) in found);
        kinds: any = operator.gt(len(classes), 0) + operator.gt(len(modules), 0) + builtin;
        if kinds != 1 {
            return ("unknown", "");
        }
        if len(classes) == 1 {
            return ("class", next(iter(classes)));
        }
        if len(modules) == 1 {
            return ("module", next(iter(modules)));
        }
        if builtin {
            return ("builtin", "");
        }
        return ("unknown", "");
    }

    class def _python_binding_targets(left) -> list[tuple[str, tuple[int, ...]]] {
        found: list[tuple[str, tuple[int, ...]]];
        found = [];

        def `visit(`node, path: tuple[int, ...], depth: int = 0) {
            if `node is None or depth > 8 {
                return;
            }
            if `node.type == "parenthesized_expression" {
                inner: any = `node.named_children;
                if len(inner) == 1 {
                    `visit(inner[0], path, depth + 1);
                }
                return;
            }
            if `node.type in _PY_TARGET_PATTERN_TYPES {
                for (index, child) in enumerate(`node.named_children) {
                    if child.type in _PY_SPLAT_PATTERN_TYPES {
                        return;
                    }
                    `visit(child, path + (index,), depth + 1);
                }
                return;
            }
            name: any = CodeParser._python_binding_target_name(`node);
            if name {
                found.append((name, path));
            }
        }

        `visit(left, ());
        return found;
    }

    static def _python_target_is_attribute(left, name: str) -> bool {
        if left is None {
            return False;
        }
        if left.type == "attribute" {
            return True;
        }
        for `node in left.named_children {
            if `node.type == "attribute" {
                attribute: any = `node.child_by_field_name("attribute");
                if attribute is not None
                    and attribute.text.decode("utf-8", errors="replace") == name
                {
                    return True;
                }
            }
        }
        return False;
    }

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
    ) -> Optional[tuple[str, str]] {
        if type_node is not None {
            annotation: any = self._python_annotation_at_path(
                type_node.text.decode("utf-8", errors="replace"), path
            );
            if annotation is None {
                return None;
            }
            type_name: any = self._base_type_name(annotation);
            return ("class", type_name) if type_name else ("builtin", "");
        }
        if value is None {
            return None;
        }
        if value.type == "none" {
            return None;
        }
        if value.type in ("tuple", "list") and path {
            elements: any = value.named_children;
            if path[0] >= len(elements) {
                return ("unknown", "");
            }
            return self._python_binding_evidence(
                elements[path[0]],
                None,
                path[1:],
                context,
                env,
                class_fields,
                current_class,
                instance_receiver_name,
                class_receiver_name,
            );
        }
        if value.type in _PY_LITERAL_VALUE_TYPES {
            return ("builtin", "");
        }
        if value.type == "call" {
            return self._python_call_evidence(value, path, context);
        }
        if value.type == "attribute" {
            return self._python_expression_class_evidence(
                value,
                env or {},
                class_fields or {},
                current_class,
                context,
                instance_receiver_name,
                class_receiver_name,
            )
                or ("unknown", "");
        }
        return ("unknown", "");
    }

    def _python_call_evidence(
        call, path: tuple[int, ...], context: _PyReceiverContext
    ) -> tuple[str, str] {
        callee: any = call.child_by_field_name("function");
        if callee is None {
            return ("unknown", "");
        }
        annotation: any = self._python_callee_return_annotation(callee, context);
        if annotation is not None {
            element: any = self._python_annotation_at_path(annotation, path);
            if element is not None {
                type_name: any = self._base_type_name(element);
                return ("class", type_name) if type_name else ("builtin", "");
            }
            return ("unknown", "");
        }
        if path {
            return ("unknown", "");
        }
        constructed: any = self._python_constructor_class(callee, context);
        return ("class", constructed) if constructed else ("unknown", "");
    }

    def _python_constructor_class(callee, context: _PyReceiverContext) -> Optional[str] {
        callee = self._python_unwrap_callee(callee);
        if callee is None {
            return None;
        }
        if callee.type == "identifier" {
            name: any = callee.text.decode("utf-8", errors="replace");
            if name in context.class_names or name in context.imported_names {
                return name;
            }
            return None;
        }
        if callee.type != "attribute" {
            return None;
        }
        attribute: any = callee.child_by_field_name("attribute");
        if attribute is None {
            return None;
        }
        name = attribute.text.decode("utf-8", errors="replace");
        `root: any = self._python_dotted_root(callee.child_by_field_name("object"));
        if `root is None {
            return None;
        }
        if `root not in context.module_bindings and `root not in context.imported_names {
            return None;
        }
        if name in context.class_names {
            return name;
        }
        return name if name[:1].isupper() else None;
    }

    static def _python_unwrap_callee(`node) -> any {
        for _ in range(4) {
            if `node is None {
                return None;
            }
            if `node.type in _PY_SPLAT_PATTERN_TYPES {
                named: any = `node.named_children;
                `node = named[0] if len(named) == 1 else None;
                continue;
            }
            if `node.type == "parenthesized_expression" {
                named = `node.named_children;
                `node = named[0] if len(named) == 1 else None;
                continue;
            }
            return `node;
        }
        return None;
    }

    static def _python_dotted_root(`node) -> Optional[str] {
        for _ in range(8) {
            if `node is None {
                return None;
            }
            if `node.type == "identifier" {
                return `node.text.decode("utf-8", errors="replace");
            }
            if `node.type != "attribute" {
                return None;
            }
            `node = `node.child_by_field_name("object");
        }
        return None;
    }

    def _python_callee_return_annotation(callee, context: _PyReceiverContext) -> Optional[str] {
        if callee.type == "identifier" {
            name: any = callee.text.decode("utf-8", errors="replace");
            local: any = context.local_returns.get(name);
            if local is not None {
                return local;
            }
            origin: any = context.symbol_origins.get(name);
            if origin {
                return self._python_module_return_annotations(origin).get(name);
            }
            return None;
        }
        if callee.type != "attribute" {
            return None;
        }
        attribute: any = callee.child_by_field_name("attribute");
        `obj: any = callee.child_by_field_name("object");
        if attribute is None or `obj is None or `obj.type != "identifier" {
            return None;
        }
        module_files: any = context.module_bindings.get(
            `obj.text.decode("utf-8", errors="replace"), set[any]()
        );
        if len(module_files) != 1 {
            return None;
        }
        return self._python_module_return_annotations(next(iter(module_files))).get(
            attribute.text.decode("utf-8", errors="replace")
        );
    }

    def _python_expression_receiver_evidence(
        call, context: _PyReceiverContext
    ) -> Optional[tuple[str, str]] {
        callee: any = call.child_by_field_name("function");
        if callee is None or callee.type != "attribute" {
            return None;
        }
        `obj: any = callee.child_by_field_name("object");
        if `obj is None {
            return None;
        }
        if `obj.type == "call" {
            inner: any = `obj.child_by_field_name("function");
            if inner is None {
                return None;
            }
            constructed: any = self._python_constructor_class(inner, context);
            return ("class", constructed) if constructed else None;
        }
        module_file: any = self._python_dotted_module_file(`obj, context);
        return ("module", module_file) if module_file else None;
    }

    def _python_dotted_module_file(prefix, context: _PyReceiverContext) -> Optional[str] {
        if prefix is None or prefix.type != "attribute" {
            return None;
        }
        `root: any = self._python_dotted_root(prefix);
        if `root is None or `root not in context.module_bindings {
            return None;
        }
        return self._resolve_module_to_file(
            prefix.text.decode("utf-8", errors="replace"), context.file_path, "python"
        );
    }

    class def _python_annotation_at_path(annotation: str, path: tuple[int, ...]) -> Optional[str] {
        current: any = annotation.strip();
        if len(current) >= 2 and current[0] in "\"'" and current[-1] == current[0] {
            current = current[1:-1].strip();
        }
        for index in path {
            elements: any = cls._python_tuple_annotation_elements(current);
            if elements is None {
                return None;
            }
            if len(elements) == 2 and elements[1] == "..." {
                current = elements[0];
                continue;
            }
            if index >= len(elements) {
                return None;
            }
            current = elements[index];
        }
        return current;
    }

    static def _python_tuple_annotation_elements(annotation: str) -> Optional[list[str]] {
        opening: any = annotation.find("[");
        if opening < 0 or not annotation.rstrip().endswith("]") {
            return None;
        }
        head: any = annotation[:opening].strip().rsplit(".", 1)[-1];
        if head not in _PY_TUPLE_ANNOTATION_NAMES {
            return None;
        }
        inner: any = annotation.rstrip()[opening + 1:-1];
        elements: list[str] = [];
        depth: any = 0;
        start: any = 0;
        quote: any = "";
        for (position, character) in enumerate(inner) {
            if quote {
                if character == quote {
                    quote = "";
                }
                continue;
            }
            if character in "\"'" {
                quote = character;
            } elif character in "[({" {
                depth += 1;
            } elif character in "])}" {
                depth -= 1;
            } elif character == "," and depth == 0 {
                elements.append(inner[start:position].strip());
                start = position + 1;
            }
        }
        elements.append(inner[start:].strip());
        return [element for element in elements if element];
    }

    def _python_module_return_annotations(module_file: str) -> dict[str, str] {
        if not module_file.endswith(".py") {
            return {};
        }
        try {
            module_path: any = Path(module_file).resolve();
            file_stat: any = module_path.stat();
        } except (OSError, ValueError) {
            return {};
        }
        resolved: any = normalize_file_path(module_path);
        if self._excluded_files and resolved in self._excluded_files {
            return {};
        }
        cache_key: any = (resolved, file_stat.st_mtime_ns, file_stat.st_size);
        with _PYTHON_RETURN_ANNOTATION_CACHE_LOCK {
            cached: any = _PYTHON_RETURN_ANNOTATION_CACHE.get(cache_key);
            if cached is not None {
                return cached;
            }
            annotations: any = self._read_python_return_annotations(module_path);
            for stale in [
                key
                for key in _PYTHON_RETURN_ANNOTATION_CACHE
                if key[0] == resolved and key != cache_key
            ] {
                _PYTHON_RETURN_ANNOTATION_CACHE.pop(stale, None);
            }
            if len(_PYTHON_RETURN_ANNOTATION_CACHE) >= _PYTHON_STAR_CACHE_MAX {
                for oldest in `list(_PYTHON_RETURN_ANNOTATION_CACHE)[:_PYTHON_STAR_CACHE_MAX // 2] {
                    _PYTHON_RETURN_ANNOTATION_CACHE.pop(oldest, None);
                }
            }
            _PYTHON_RETURN_ANNOTATION_CACHE[cache_key] = annotations;
            return annotations;
        }
    }

    def _read_python_return_annotations(module_path: Path) -> dict[str, str] {
        annotations: dict[str, str];
        try {
            source: any = module_path.read_bytes();
        } except (OSError, PermissionError) {
            return {};
        }
        parser: any = self._get_parser("python");
        if not parser {
            return {};
        }
        try {
            tree: any = parser.parse(source);
        } except (RecursionError, ValueError) as exc {
            logger.debug("Return-annotation parse failed for %s: %s", module_path, exc);
            return {};
        }
        annotations = {};
        ambiguous: set[str] = set[any]();
        for child in tree.root_node.children {
            `node: any = child;
            if `node.type == "decorated_definition" {
                `node = `node.child_by_field_name("definition") or `node;
            }
            if `node.type != "function_definition" {
                continue;
            }
            name_node: any = `node.child_by_field_name("name");
            type_node: any = `node.child_by_field_name("return_type");
            if name_node is None or type_node is None {
                continue;
            }
            name: any = name_node.text.decode("utf-8", errors="replace");
            annotation: any = type_node.text.decode("utf-8", errors="replace");
            if annotations.get(name, annotation) != annotation {
                ambiguous.add(name);
            }
            annotations[name] = annotation;
        }
        for name in ambiguous {
            annotations.pop(name, None);
        }
        return annotations;
    }

    def _python_plain_import_bindings(
        `node, file_path: str, module_bindings: dict[str, set[str]], imported_names: set[str]
    ) {
        for child in `node.children {
            local: Optional[str] = None;
            module: Optional[str] = None;
            if child.type == "dotted_name" {
                module = child.text.decode("utf-8", errors="replace");
                local = module.split(".", 1)[0];
                module = local;
            } elif child.type == "aliased_import" {
                names: any = [
                    sub.text.decode("utf-8", errors="replace")
                    for sub in child.children
                    if sub.type in ("identifier", "dotted_name")
                ];
                if len(names) >= 2 {
                    (module, local) = (names[0], names[-1]);
                }
            }
            if not local or not module {
                continue;
            }
            resolved: any = self._resolve_module_to_file(module, file_path, "python");
            if resolved {
                module_bindings.setdefault(local, set[any]()).add(resolved);
            } else {
                imported_names.add(local);
            }
        }
    }

    def _python_from_import_bindings(
        `node,
        file_path: str,
        module_bindings: dict[str, set[str]],
        imported_names: set[str],
        symbol_origins: Optional[dict[str, str]] = None,
        symbol_names: Optional[dict[str, str]] = None,
    ) {
        module_node: any = `node.child_by_field_name("module_name");
        if module_node is None {
            return;
        }
        module: any = module_node.text.decode("utf-8", errors="replace");
        package_dir: any = self._python_package_dir(module, file_path);
        submodules: any = `set(self._python_submodule_names(`node, package_dir))
            if package_dir is not None
            else set[any]();
        module_file: any = self._resolve_module_to_file(module, file_path, "python")
            if symbol_origins is not None
            else None;

        def bind(local: str, imported: str) {
            if package_dir is not None and imported in submodules {
                target: any = self._python_submodule_file(package_dir, imported);
                if target is not None {
                    module_bindings.setdefault(local, set[any]()).add(target);
                    return;
                }
            }
            imported_names.add(local);
            if symbol_names is not None {
                symbol_names[local] = imported;
            }
            if symbol_origins is not None and module_file {
                symbol_origins[local] = self._python_reexport_origin(module_file, imported);
            }
        }

        seen_import_keyword: any = False;
        for child in `node.children {
            if child.type == "import" {
                seen_import_keyword = True;
            } elif seen_import_keyword {
                if child.type in ("identifier", "dotted_name") {
                    name: any = child.text.decode("utf-8", errors="replace");
                    bind(name, name);
                } elif child.type == "aliased_import" {
                    names: any = [
                        sub.text.decode("utf-8", errors="replace")
                        for sub in child.children
                        if sub.type in ("identifier", "dotted_name")
                    ];
                    if names {
                        bind(names[-1], names[0]);
                    }
                }
            }
        }
    }

    static def _python_binding_target_name(left) -> Optional[str] {
        if left is None {
            return None;
        }
        if left.type == "identifier" {
            return left.text.decode("utf-8", errors="replace");
        }
        if left.type == "attribute" {
            `obj: any = left.child_by_field_name("object");
            attribute: any = left.child_by_field_name("attribute");
            if `obj is not None and attribute is not None and `obj.text in (b"self", b"cls") {
                return attribute.text.decode("utf-8", errors="replace");
            }
        }
        return None;
    }

    def _apply_python_receiver_evidence(
        edges: list[EdgeInfo], evidence: dict[tuple[int, str], tuple[str, str]]
    ) -> list[EdgeInfo] {
        annotated: list[EdgeInfo] = [];
        for `edge in edges {
            receiver: any = `edge.extra.get("receiver");
            if `edge.kind != "CALLS"
                or "::" in `edge.target
                or not receiver and not `edge.extra.get("receiver_form")
            {
                annotated.append(`edge);
                continue;
            }
            kind: any;
            detail: any;
            (kind, detail) = evidence.get(
                (`edge.line, receiver or _PY_EXPR_RECEIVER_KEY + `edge.target), ("unknown", "")
            ) as any;
            extra: any = `dict(`edge.extra);
            extra["receiver_binding"] = kind;
            if kind == "module" {
                extra["receiver_module"] = self._python_reexport_origin(detail, `edge.target)
                    if detail
                    else detail;
            } elif kind == "class" {
                identity: any = _python_split_class_identity(detail);
                if identity is None {
                    extra["receiver_class"] = detail;
                } else {
                    (extra["receiver_class_file"], extra["receiver_class"]) = (identity);
                }
            }
            annotated.append(
                EdgeInfo(
                    `edge.kind, `edge.source, `edge.target, `edge.file_path, `edge.line, extra=extra
                ),
            );
        }
        return annotated;
    }

    static has _MAX_AST_DEPTH: any = 180;

    static has _MAX_TEST_DESCRIPTION_LEN: any = 200;

    def _get_test_description(call_node, source: bytes) -> Optional[str] {
        for child in call_node.children {
            if child.type == "arguments" {
                for arg in child.children {
                    if arg.type in ("string", "template_string") {
                        raw: any = arg.text.decode("utf-8", errors="replace");
                        stripped: any = raw.strip("'\"`");
                        normalized: any = re.sub("\\s+", " ", stripped).strip();
                        if len(normalized) > self._MAX_TEST_DESCRIPTION_LEN {
                            normalized = normalized[:self._MAX_TEST_DESCRIPTION_LEN];
                        }
                        return normalized;
                    }
                }
            }
        }
        return None;
    }

    def _is_ruby_test_block(`node, call_name: str, file_path: str) -> bool {
        if call_name not in _RUBY_TEST_BLOCK_NAMES {
            return False;
        }
        if `node.child_by_field_name("block") is None {
            return False;
        }
        receiver: any = `node.child_by_field_name("receiver");
        if receiver is not None and receiver.text != b"RSpec" {
            return False;
        }
        return self._is_test_path(file_path);
    }

    def _get_ruby_test_description(call_node) -> Optional[str] {
        arguments: any = call_node.child_by_field_name("arguments");
        if arguments is None or not arguments.named_children {
            return None;
        }
        first: any = arguments.named_children[0];
        if first.type not in ("string", "constant", "scope_resolution", "simple_symbol") {
            return None;
        }
        raw: any = first.text.decode("utf-8", errors="replace").strip("'\":");
        normalized: any = re.sub("\\s+", " ", raw).replace("::", ".").strip();
        return normalized[:self._MAX_TEST_DESCRIPTION_LEN] or None;
    }

    static def _ruby_constant_path(`node) -> Optional[str] {
        if `node is None or `node.type not in ("constant", "scope_resolution") {
            return None;
        }
        path: any = `node.text.decode("utf-8", errors="replace").lstrip(":").replace("::", ".");
        return path if _RUBY_CONSTANT_PATH_RE.match(path) else None;
    }

    class def _ruby_class_ref(`node, nesting: tuple[str, ...]) -> Optional[_RubyClassRef] {
        path: any = cls._ruby_constant_path(`node);
        if path is None {
            return None;
        }
        return (path, () if `node.text.startswith(b"::") else nesting);
    }

    class def _ruby_nesting(`node, nesting: tuple[str, ...]) -> tuple[str, ...] {
        if `node.type not in ("module", "class") {
            return nesting;
        }
        name: any = `node.child_by_field_name("name");
        path: any = cls._ruby_constant_path(name);
        if name is None or path is None {
            return nesting;
        }
        if nesting and not name.text.startswith(b"::") {
            path = f"{nesting[0]}.{path}";
        }
        return (path, *nesting);
    }

    def _collect_ruby_test_receivers(
        `root
    ) -> dict[tuple[int, str], list[tuple[bool, Optional[_RubyClassRef]]]] {
        shared: dict[str, Optional[_RubyClassRef]];
        found: dict[tuple[int, str], list[tuple[bool, Optional[_RubyClassRef]]]];
        shared = {};

        def text_of(`node) -> str {
            return `node.text.decode("utf-8", errors="replace") if `node is not None else "";
        }

        def share(name: str, class_ref: Optional[_RubyClassRef]) {
            shared[name] = class_ref if shared.get(name, class_ref) == class_ref else None;
        }

        def constructed(
            `node, described: Optional[_RubyClassRef], nesting: tuple[str, ...]
        ) -> Optional[_RubyClassRef] {
            if `node is None or `node.type != "call" {
                return None;
            }
            if text_of(`node.child_by_field_name("method")) != "new" {
                return None;
            }
            receiver: any = `node.child_by_field_name("receiver");
            if receiver is not None and text_of(receiver) == "described_class" {
                return described;
            }
            return self._ruby_class_ref(receiver, nesting);
        }

        def narrowed(
            `node, described: Optional[_RubyClassRef], nesting: tuple[str, ...]
        ) -> Optional[_RubyClassRef] {
            if `node.type == "call"
                and text_of(`node.child_by_field_name("method")) in _RUBY_DESCRIBING_BLOCK_NAMES
            {
                arguments: any = `node.child_by_field_name("arguments");
                if arguments is not None and arguments.named_children {
                    return self._ruby_class_ref(arguments.named_children[0], nesting) or described;
                }
            }
            return described;
        }

        def gather(
            `node, described: Optional[_RubyClassRef], nesting: tuple[str, ...], depth: int = 0
        ) {
            if depth > self._MAX_AST_DEPTH {
                return;
            }
            if `node.type == "assignment" {
                left: any = `node.child_by_field_name("left");
                if left is not None and left.type == "instance_variable" {
                    share(
                        text_of(left),
                        constructed(`node.child_by_field_name("right"), described, nesting),
                    );
                }
            } elif `node.type == "call"
                and text_of(`node.child_by_field_name("method")) in _RUBY_MEMO_BLOCK_NAMES
                and `node.child_by_field_name("receiver") is None
            {
                block: any = `node.child_by_field_name("block");
                body: any = block.child_by_field_name("body") if block is not None else None;
                arguments: any = `node.child_by_field_name("arguments");
                name: any = text_of(arguments.named_children[0]).lstrip(":")
                    if arguments is not None and arguments.named_children
                    else "subject";
                share(
                    name,
                    constructed(
                        body.named_children[-1]
                            if body is not None and body.named_children
                            else None,
                        described,
                        nesting,
                    ),
                );
            }
            described = narrowed(`node, described, nesting);
            nesting = self._ruby_nesting(`node, nesting);
            for child in `node.children {
                gather(child, described, nesting, depth + 1);
            }
        }

        gather(`root, None, ());

        found = {};

        def class_of(
            receiver,
            local: dict[str, Optional[_RubyClassRef]],
            described: Optional[_RubyClassRef],
            nesting: tuple[str, ...],
        ) -> Optional[_RubyClassRef] {
            if receiver.type == "instance_variable" {
                return shared.get(text_of(receiver));
            }
            if receiver.type == "identifier" {
                name: any = text_of(receiver);
                if name == "described_class" {
                    return described;
                }
                return local[name] if name in local else shared.get(name);
            }
            return self._ruby_class_ref(receiver, nesting)
                or constructed(receiver, described, nesting);
        }

        def walk(
            `node,
            local: dict[str, Optional[_RubyClassRef]],
            described: Optional[_RubyClassRef],
            nesting: tuple[str, ...],
            depth: int = 0,
        ) {
            if depth > self._MAX_AST_DEPTH {
                return;
            }
            if `node.type in ("method", "singleton_method", "block", "do_block") {
                local = {} if `node.type in ("method", "singleton_method") else `dict(local);
                parameters: any = `node.child_by_field_name("parameters");
                if parameters is not None {
                    for parameter in parameters.named_children {
                        if parameter.type == "identifier" {
                            local[text_of(parameter)] = None;
                        }
                    }
                }
            }
            if `node.type == "call" {
                receiver: any = `node.child_by_field_name("receiver");
                method: any = `node.child_by_field_name("method");
                if method is not None {
                    has_receiver: any = receiver is not None and operator.ne(receiver.type, "self");
                    found.setdefault((`node.start_point[0] + 1, text_of(method)), []).append((
                        has_receiver,
                        class_of(receiver, local, described, nesting) if has_receiver else None,
                    ));
                }
            }
            described = narrowed(`node, described, nesting);
            nesting = self._ruby_nesting(`node, nesting);
            for child in `node.children {
                walk(child, local, described, nesting, depth + 1);
            }
            if `node.type == "assignment" {
                left: any = `node.child_by_field_name("left");
                if left is not None and left.type == "identifier" {
                    local[text_of(left)] = constructed(
                        `node.child_by_field_name("right"), described, nesting
                    );
                }
            }
        }

        walk(`root, {}, None, ());
        return found;
    }

    static def _apply_ruby_test_receivers(
        edges: list[EdgeInfo],
        receivers: dict[tuple[int, str], list[tuple[bool, Optional[_RubyClassRef]]]],
    ) -> list[EdgeInfo] {
        calls: any;
        pending: any = {key: iter(calls) for (key, calls) in receivers.items()};
        for `edge in edges {
            if `edge.kind != "CALLS" {
                continue;
            }
            method: any = `edge.target.rsplit("::", 1)[-1];
            calls = pending.get((`edge.line, method));
            has_receiver: any;
            class_ref: any;
            (has_receiver, class_ref) = (
                next(calls, (False, None)) if calls else (False, None)
            ) as any;
            if not has_receiver {
                continue;
            }
            `edge.target = method;
            if class_ref is None {
                `edge.extra = {
                    **`edge.extra,
                    "receiver_binding": "unknown",
                    "receiver_form": "expression",
                };
                continue;
            }
            class_path: any;
            scopes: any;
            (class_path, scopes) = class_ref as any;
            `edge.extra = {
                **`edge.extra,
                "receiver_binding": "class",
                "receiver_class": class_path,
                "receiver_constant": True,
                **{"receiver_scopes": `list(scopes)} if scopes else {},
            };
        }
        return edges;
    }

    def _parse_yaml(path: Path, source: bytes) -> tuple[list[NodeInfo], list[EdgeInfo]] {
        alias_lines_by_anchor: dict[str, list[int]];
        event: any;
        file_path: any;
        edges: list[EdgeInfo];
        shared_targets: dict[int, str];
        shared_anchor_names: dict[int, str];
        path_nodes: dict[tuple[int, str], NodeInfo];
        path_value_types: dict[tuple[int, str], set[str]];
        path_key_tags: dict[tuple[int, str], set[str]];
        contains_edges: set[tuple[str, str]];
        duplicate_summaries: list[dict[str, Any]];
        alias_indices: dict[str, int];
        skipped_seen: set[int];
        if len(source) > self._MAX_GENERIC_YAML_BYTES {
            logger.debug(
                "Skipping generic YAML file %s: %d bytes exceeds the %d-byte limit",
                path,
                len(source),
                self._MAX_GENERIC_YAML_BYTES,
            );
            return ([], []);
        }

        if _is_locale_yaml(path, self._repo_root) {
            locale_file_path: any = normalize_file_path(path);
            return (
                [
                    NodeInfo(
                        "File",
                        locale_file_path,
                        locale_file_path,
                        1,
                        source.count(b"\n") + 1,
                        language="yaml",
                        extra={
                            "config_format": path.suffix.lower().lstrip("."),
                            "yaml_locale_file": True,
                            "values_indexed": False,
                        },
                    ),
                ],
                [],
            );
        }

        text: any = source.decode("utf-8", errors="replace");
        try {
            documents: any = `list(_yaml.compose_all(text));
            yaml_events: any = `list(_yaml.parse(text)) if b"&" in source else [];
            anchor_definitions: any = {
                event.start_mark.index: `str(event.anchor)
                for event in yaml_events
                if not isinstance(event, _YamlAliasEvent)
                    and getattr(event, "anchor", None) is not None
            };
            alias_lines_by_anchor = {};
            for event in yaml_events {
                if isinstance(event, _YamlAliasEvent) {
                    alias_lines_by_anchor.setdefault(`str(event.anchor), []).append(
                        event.start_mark.line + 1
                    );
                }
            }
        } except (_yaml.YAMLError, RecursionError) as exc {
            logger.debug("YAML parse error in %s: %s", path, exc);
            return ([], []);
        }

        file_path = normalize_file_path(path);
        file_extra: dict[str, Any] = {
            "config_format": path.suffix.lower().lstrip("."),
            "yaml_document_count": len(documents),
            "yaml_duplicate_key_count": 0,
            "yaml_duplicate_keys": [],
            "yaml_unsupported_key_count": 0,
            "yaml_truncated": False,
            "values_indexed": False,
        };
        nodes: any = [
            NodeInfo(
                "File",
                file_path,
                file_path,
                1,
                source.count(b"\n") + 1,
                language="yaml",
                extra=file_extra,
            ),
        ];
        edges = [];
        shared_targets = {};
        shared_anchor_names = {};
        path_nodes = {};
        path_value_types = {};
        path_key_tags = {};
        contains_edges = set[any]();
        duplicate_summaries = [];
        duplicate_count: any = 0;
        unsupported_key_count: any = 0;
        alias_indices = {};
        skipped_seen = set[any]();
        truncated: any = False;

        def qualified(schema_path: str, document_index: int) -> str {
            return f"{file_path}::yaml:{document_index}:{schema_path}";
        }

        def can_emit(schema_path: str, depth: int, *source_paths_: str) -> bool {
            source_paths: any = tuple(source_paths_);
            if len(nodes) - 1 >= self._MAX_YAML_NODES
                or depth > self._MAX_YAML_DEPTH
                or len(schema_path) > self._MAX_YAML_PATH_LENGTH
                or `any(
                    operator.gt(len(source_path), self._MAX_YAML_PATH_LENGTH)
                    for source_path in source_paths,
                )
            {
                truncated = True;
                return False;
            }
            return True;
        }

        def add_contains(parent: str, target: str, line: int) {
            edge_key: any = (parent, target);
            if edge_key in contains_edges {
                return;
            }
            contains_edges.add(edge_key);
            edges.append(EdgeInfo("CONTAINS", parent, target, file_path, line));
        }

        def next_alias_line(value_node: object, fallback: int) -> int {
            anchor_name: any = shared_anchor_names.get(id(value_node));
            if anchor_name is None {
                return fallback;
            }
            lines: any = alias_lines_by_anchor.get(anchor_name, []);
            alias_index: any = alias_indices.get(anchor_name, 0);
            if alias_index >= len(lines) {
                return fallback;
            }
            line: any = lines[alias_index];
            alias_indices[anchor_name] = alias_index + 1;
            return line;
        }

        def emit_alias(
            value_node: object,
            exact_path: str,
            schema_path: str,
            identity_path: str,
            parent_qualified: str,
            document_index: int,
            depth: int,
            line_start: int,
            extra: dict[str, Any],
            yaml_merge: bool,
            line_is_key: bool,
        ) {
            if not can_emit(schema_path, depth, exact_path, identity_path) {
                return;
            }
            original_target: any = shared_targets[id(value_node)];
            reference_line: any = next_alias_line(value_node, line_start);
            node_line_start: any = min(line_start, reference_line)
                if line_is_key
                else reference_line;
            node_line_end: any = max(node_line_start, reference_line);
            alias_identity: any = f"alias:{identity_path}@{reference_line}";
            target: any = qualified(alias_identity, document_index);
            nodes.append(
                NodeInfo(
                    "YamlPath",
                    exact_path,
                    file_path,
                    node_line_start,
                    node_line_end,
                    language="yaml",
                    extra={
                        "document_index": document_index,
                        "path": exact_path,
                        "schema_path": schema_path,
                        "source_file": path.name,
                        "value_type": "alias",
                        "is_alias": True,
                        "yaml_merge": yaml_merge,
                        **extra,
                    },
                    identity_name=f"yaml:{document_index}:{alias_identity}",
                ),
            );
            add_contains(parent_qualified, target, node_line_start);
            edges.append(
                EdgeInfo(
                    "REFERENCES",
                    target,
                    original_target,
                    file_path,
                    reference_line,
                    extra={"yaml_alias": True, "yaml_merge": yaml_merge},
                ),
            );
        }

        def emit_node(
            value_node: object,
            exact_path: str,
            schema_path: str,
            identity_path: str,
            parent_qualified: str,
            document_index: int,
            depth: int,
            line_start: int,
            line_end: int,
            extra: dict[str, Any],
            ancestors: frozenset[int],
            yaml_merge: bool = False,
            line_is_key: bool = False,
        ) {
            if not can_emit(schema_path, depth, exact_path, identity_path) {
                return;
            }
            value_id: any = id(value_node);
            if value_id in shared_targets {
                emit_alias(
                    value_node,
                    exact_path,
                    schema_path,
                    identity_path,
                    parent_qualified,
                    document_index,
                    depth,
                    line_start,
                    extra,
                    yaml_merge,
                    line_is_key,
                );
                return;
            }

            node_mark: any = getattr(value_node, "start_mark", None);
            anchor_name: any = anchor_definitions.get(getattr(node_mark, "index", -1));
            if anchor_name is not None {
                anchor_identity: any = "anchor:"
                    + format(getattr(node_mark, "index", line_start), "")
                    + ":"
                    + format(identity_path, "");
                target: any = qualified(anchor_identity, document_index);
                value_type: any = _yaml_value_type(value_node);
                node_extra: any = {
                    "document_index": document_index,
                    "path": schema_path,
                    "schema_path": schema_path,
                    "example_path": exact_path,
                    "source_file": path.name,
                    "value_type": value_type,
                    "value_types": [value_type],
                    "occurrence_count": 1,
                    "line_samples": [line_start],
                    "range_samples": [[line_start, max(line_start, line_end)]],
                    "lines_truncated": False,
                    "is_alias": False,
                    "anchor_definition": True,
                    **extra,
                };
                key_tag: any = extra.get("key_tag");
                if isinstance(key_tag, `str) {
                    node_extra["key_tags"] = [key_tag];
                }
                if extra.get("duplicate_key") {
                    node_extra["duplicate_key_occurrence_count"] = 1;
                    if extra.get("duplicate_group_start") {
                        node_extra["duplicate_group_count"] = 1;
                        node_extra["duplicate_group_samples"] = [extra["duplicate_group"]];
                    }
                }
                nodes.append(
                    NodeInfo(
                        "YamlPath",
                        schema_path,
                        file_path,
                        line_start,
                        max(line_start, line_end),
                        language="yaml",
                        extra=node_extra,
                        identity_name=f"yaml:{document_index}:{anchor_identity}",
                    ),
                );
                add_contains(parent_qualified, target, line_start);
                shared_targets[value_id] = target;
                shared_anchor_names[value_id] = anchor_name;
                value_ancestors: any = ancestors | {value_id};
                if isinstance(value_node, _YamlMapping) {
                    visit_mapping(
                        value_node,
                        exact_path,
                        schema_path,
                        identity_path,
                        target,
                        document_index,
                        depth + 1,
                        value_ancestors,
                    );
                } elif isinstance(value_node, _YamlSequence) {
                    visit_sequence(
                        value_node,
                        exact_path,
                        schema_path,
                        identity_path,
                        target,
                        document_index,
                        depth + 1,
                        value_ancestors,
                        merge_context=yaml_merge or `bool(extra.get("merge_key")),
                    );
                }
                return;
            }

            path_key: any = (document_index, schema_path);
            `node: any = path_nodes.get(path_key);
            if `node is None {
                target = qualified(schema_path, document_index);
                value_type = _yaml_value_type(value_node);
                node_extra = {
                    "document_index": document_index,
                    "path": schema_path,
                    "schema_path": schema_path,
                    "example_path": exact_path,
                    "source_file": path.name,
                    "value_type": value_type,
                    "value_types": [value_type],
                    "occurrence_count": 1,
                    "line_samples": [line_start],
                    "range_samples": [[line_start, max(line_start, line_end)]],
                    "lines_truncated": False,
                    "is_alias": False,
                    **extra,
                };
                `node = NodeInfo(
                    "YamlPath",
                    schema_path,
                    file_path,
                    line_start,
                    max(line_start, line_end),
                    language="yaml",
                    extra=node_extra,
                    identity_name=f"yaml:{document_index}:{schema_path}",
                );
                nodes.append(`node);
                path_nodes[path_key] = `node;
                path_value_types[path_key] = {value_type};
                key_tag = extra.get("key_tag");
                path_key_tags[path_key] = {key_tag} if isinstance(key_tag, `str) else set[any]();
                add_contains(parent_qualified, target, line_start);
            } else {
                add_contains(parent_qualified, qualified(schema_path, document_index), line_start);
                `node.line_start = min(`node.line_start, line_start);
                `node.line_end = max(`node.line_end, line_end);
                `node.extra["occurrence_count"] += 1;
                line_samples: any = `node.extra["line_samples"];
                if len(line_samples) < self._MAX_YAML_OCCURRENCE_SAMPLES {
                    line_samples.append(line_start);
                    `node.extra["range_samples"].append([line_start, max(line_start, line_end)]);
                } else {
                    `node.extra["lines_truncated"] = True;
                }
                value_types: any = path_value_types[path_key];
                value_types.add(_yaml_value_type(value_node));
                `node.extra["value_types"] = sorted(value_types);
                `node.extra["value_type"] = next(iter(value_types))
                    if len(value_types) == 1
                    else "mixed";
                key_tag = extra.get("key_tag");
                if isinstance(key_tag, `str) {
                    key_tags: any = path_key_tags[path_key];
                    key_tags.add(key_tag);
                    `node.extra["key_tags"] = sorted(key_tags);
                }
            }

            if extra.get("duplicate_key") {
                `node.extra["duplicate_key"] = True;
                `node.extra["duplicate_key_occurrence_count"] = `node.extra.get(
                    "duplicate_key_occurrence_count", 0
                )
                    + 1;
                if extra.get("duplicate_group_start") {
                    `node.extra["duplicate_group_count"] = `node.extra.get(
                        "duplicate_group_count", 0
                    )
                        + 1;
                    group_samples: any = `node.extra.setdefault("duplicate_group_samples", []);
                    if len(group_samples) < self._MAX_YAML_DUPLICATE_GROUP_SAMPLES {
                        group_samples.append(extra["duplicate_group"]);
                    } else {
                        `node.extra["duplicate_groups_truncated"] = True;
                    }
                }
            }

            shared_targets[value_id] = qualified(schema_path, document_index);
            value_ancestors = ancestors | {value_id};
            if isinstance(value_node, _YamlMapping) {
                visit_mapping(
                    value_node,
                    exact_path,
                    schema_path,
                    identity_path,
                    qualified(schema_path, document_index),
                    document_index,
                    depth + 1,
                    value_ancestors,
                );
            } elif isinstance(value_node, _YamlSequence) {
                visit_sequence(
                    value_node,
                    exact_path,
                    schema_path,
                    identity_path,
                    qualified(schema_path, document_index),
                    document_index,
                    depth + 1,
                    value_ancestors,
                    merge_context=yaml_merge or `bool(extra.get("merge_key")),
                );
            }
        }
        def consume_skipped_aliases(skipped_node: object) {
            skipped_id: any = id(skipped_node);
            if skipped_id in shared_targets {
                next_alias_line(skipped_node, _yaml_line(skipped_node));
                return;
            }
            if skipped_id in skipped_seen {
                return;
            }
            skipped_seen.add(skipped_id);
            if isinstance(skipped_node, _YamlMapping) {
                for (child_key, child_value) in skipped_node.value {
                    consume_skipped_aliases(child_key);
                    consume_skipped_aliases(child_value);
                }
            } elif isinstance(skipped_node, _YamlSequence) {
                for child in skipped_node.value {
                    consume_skipped_aliases(child);
                }
            }
        }

        def visit_mapping(
            mapping_node: object,
            exact_prefix: str,
            schema_prefix: str,
            identity_prefix: str,
            parent_qualified: str,
            document_index: int,
            depth: int,
            ancestors: frozenset[int],
        ) {
            pairs: any = `list(mapping_node.value);
            key_counts: dict[tuple[str, str], int] = {};
            key_line_samples: dict[tuple[str, str], list[int]] = {};
            key_node: any;
            for (key_node, _) in pairs {
                raw_key: any = _yaml_scalar(key_node);
                if raw_key is None {
                    continue;
                }
                signature: any = (`str(getattr(key_node, "tag", "")), raw_key);
                key_counts[signature] = key_counts.get(signature, 0) + 1;
                samples: any = key_line_samples.setdefault(signature, []);
                if len(samples) < self._MAX_YAML_DUPLICATE_LINE_SAMPLES {
                    samples.append(_yaml_line(key_node));
                }
            }

            occurrences: dict[tuple[str, str], int] = {};
            identity_occurrences: dict[str, int] = {};
            for (key_node, value_node) in pairs {
                raw_key = _yaml_scalar(key_node);
                if raw_key is None or not _is_storable_key(raw_key) {
                    unsupported_key_count += 1;
                    consume_skipped_aliases(key_node);
                    consume_skipped_aliases(value_node);
                    continue;
                }
                key_tag: any = `str(getattr(key_node, "tag", ""));
                signature = (key_tag, raw_key);
                occurrence: any = occurrences.get(signature, 0) + 1;
                occurrences[signature] = occurrence;
                exact_path: any = _yaml_path_child(exact_prefix, raw_key);
                schema_path: any = _yaml_path_child(schema_prefix, raw_key);
                base_identity: any = _yaml_path_child(identity_prefix, raw_key);
                identity_occurrence: any = identity_occurrences.get(base_identity, 0) + 1;
                identity_occurrences[base_identity] = identity_occurrence;
                identity_path: any = f"{base_identity}#{identity_occurrence}"
                    if identity_occurrence > 1
                    else base_identity;
                duplicate: any = operator.gt(key_counts[signature], 1);
                bounded_exact_path: any = exact_path[:self._MAX_YAML_PATH_LENGTH];
                duplicate_group: any = {
                    "example_path": bounded_exact_path,
                    "occurrence_count": key_counts[signature],
                    "line_samples": key_line_samples[signature],
                    "lines_truncated": operator.gt(
                        key_counts[signature], self._MAX_YAML_DUPLICATE_LINE_SAMPLES
                    ),
                };
                extra: dict[str, Any] = {
                    "raw_key": raw_key,
                    "key_tag": key_tag,
                    "duplicate_key": duplicate,
                    "key_occurrence": occurrence,
                };
                if duplicate {
                    extra["duplicate_group"] = duplicate_group;
                    extra["duplicate_group_start"] = operator.eq(occurrence, 1);
                    if occurrence == 1 {
                        duplicate_count += 1;
                        if len(duplicate_summaries) < self._MAX_YAML_DUPLICATE_GROUP_SAMPLES {
                            duplicate_summaries.append({
                                "document_index": document_index,
                                "path": bounded_exact_path,
                                **duplicate_group,
                            });
                        }
                    }
                }
                is_merge: any = operator.eq(key_tag, "tag:yaml.org,2002:merge");
                if is_merge {
                    extra["merge_key"] = True;
                }
                emit_node(
                    value_node,
                    exact_path,
                    schema_path,
                    identity_path,
                    parent_qualified,
                    document_index,
                    depth,
                    _yaml_line(key_node),
                    _yaml_end_line(value_node),
                    extra,
                    ancestors,
                    yaml_merge=is_merge,
                    line_is_key=True,
                );
            }
        }

        def visit_sequence(
            sequence_node: object,
            exact_prefix: str,
            schema_prefix: str,
            identity_prefix: str,
            parent_qualified: str,
            document_index: int,
            depth: int,
            ancestors: frozenset[int],
            merge_context: bool = False,
        ) {
            for (index, item) in enumerate(sequence_node.value) {
                exact_path: any = f"{exact_prefix}[{index}]";
                schema_path: any = f"{schema_prefix}[*]";
                identity_path: any = f"{identity_prefix}[{index}]";
                emit_node(
                    item,
                    exact_path,
                    schema_path,
                    identity_path,
                    parent_qualified,
                    document_index,
                    depth,
                    _yaml_line(item),
                    _yaml_end_line(item),
                    {"sequence_index_sample": index},
                    ancestors,
                    yaml_merge=merge_context,
                );
            }
        }

        for (document_index, document) in enumerate(documents) {
            if document is None {
                continue;
            }
            emit_node(
                document,
                "$",
                "$",
                "$",
                file_path,
                document_index,
                0,
                _yaml_line(document),
                _yaml_end_line(document),
                {"document_root": True},
                frozenset(),
            );
        }

        file_extra["yaml_duplicate_key_count"] = duplicate_count;
        file_extra["yaml_duplicate_keys"] = duplicate_summaries;
        file_extra["yaml_unsupported_key_count"] = unsupported_key_count;
        file_extra["yaml_truncated"] = truncated;
        return (nodes, edges);
    }

    def _parse_json(path: Path, source: bytes) -> tuple[list[NodeInfo], list[EdgeInfo]] {
        file_path: any = normalize_file_path(path);
        file_extra: dict[str, Any] = {
            "config_format": "json",
            "json_truncated": False,
            "values_indexed": False,
        };
        nodes: any = [
            NodeInfo(
                "File",
                file_path,
                file_path,
                1,
                source.count(b"\n") + 1,
                language="json",
                extra=file_extra,
            ),
        ];
        edges: list[EdgeInfo] = [];
        if _is_locale_yaml(path, self._repo_root) {
            file_extra["json_locale_file"] = True;
            return (nodes, edges);
        }
        relative: any = repo_relative_path(path, self._repo_root);
        if self._is_test_path(file_path)
            or relative is not None
                and _JSON_DATA_DIR_NAMES.intersection(relative.lower().split("/")[:-1])
        {
            file_extra["json_data_file"] = True;
            return (nodes, edges);
        }
        if len(source) > self._MAX_JSON_BYTES {
            file_extra["json_truncated"] = True;
            return (nodes, edges);
        }
        json_parser: any = self._get_parser("json");
        if not json_parser {
            return (nodes, edges);
        }

        def qualified(schema_path: str) -> str {
            return f"{file_path}::json:{schema_path}";
        }

        path_nodes: dict[str, NodeInfo] = {};
        path_value_types: dict[str, set[str]] = {};
        queue: deque[tuple[Any, str, str, str, int, int]] = deque(
            (child, "$", "$", file_path, 0, child.start_point[0] + 1)
            for child in json_parser.parse(source).root_node.children
            if child.type in _JSON_VALUE_TYPES,
        );
        while queue {
            value: any;
            exact_path: any;
            schema_path: any;
            parent: any;
            depth: any;
            line_start: any;
            (value, exact_path, schema_path, parent, depth, line_start) = queue.popleft() as any;
            line_end: any = value.end_point[0] + 1;
            value_type: any = _JSON_VALUE_TYPES[value.type];
            `node: any = path_nodes.get(schema_path);
            if `node is None {
                if len(path_nodes) >= self._MAX_JSON_NODES
                    or depth > self._MAX_JSON_DEPTH
                    or len(schema_path) > self._MAX_YAML_PATH_LENGTH
                {
                    file_extra["json_truncated"] = True;
                    continue;
                }
                `node = NodeInfo(
                    "JsonPath",
                    schema_path,
                    file_path,
                    line_start,
                    line_end,
                    language="json",
                    extra={
                        "path": schema_path,
                        "schema_path": schema_path,
                        "example_path": exact_path[:self._MAX_YAML_PATH_LENGTH],
                        "source_file": path.name,
                        "value_type": value_type,
                        "value_types": [value_type],
                        "occurrence_count": 1,
                        "line_samples": [line_start],
                        "range_samples": [[line_start, line_end]],
                        "lines_truncated": False,
                    },
                    identity_name=f"json:{schema_path}",
                );
                nodes.append(`node);
                path_nodes[schema_path] = `node;
                path_value_types[schema_path] = {value_type};
                edges.append(
                    EdgeInfo("CONTAINS", parent, qualified(schema_path), file_path, line_start)
                );
            } else {
                `node.line_start = min(`node.line_start, line_start);
                `node.line_end = max(`node.line_end, line_end);
                `node.extra["occurrence_count"] += 1;
                if len(`node.extra["line_samples"]) < self._MAX_JSON_OCCURRENCE_SAMPLES {
                    `node.extra["line_samples"].append(line_start);
                    `node.extra["range_samples"].append([line_start, line_end]);
                } else {
                    `node.extra["lines_truncated"] = True;
                }
                value_types: any = path_value_types[schema_path];
                value_types.add(value_type);
                `node.extra["value_types"] = sorted(value_types);
                `node.extra["value_type"] = value_type if len(value_types) == 1 else "mixed";
            }

            this_path: any = qualified(schema_path);
            if value.type == "object" {
                pairs: any = [child for child in value.children if child.type == "pair"];
                is_table: any = operator.gt(len(pairs), self._MAX_JSON_OBJECT_KEYS);
                for pair in pairs {
                    key: any = _json_key(pair.child_by_field_name("key"));
                    child_value: any = pair.child_by_field_name("value");
                    if key is None or child_value is None {
                        continue;
                    }
                    if child_value.type not in _JSON_VALUE_TYPES {
                        continue;
                    }
                    queue.append((
                        child_value,
                        _yaml_path_child(exact_path, key),
                        f"{schema_path}.*" if is_table else _yaml_path_child(schema_path, key),
                        this_path,
                        depth + 1,
                        pair.start_point[0] + 1,
                    ));
                }
            } elif value.type == "array" {
                items: any = (child for child in value.children if child.type in _JSON_VALUE_TYPES);
                for (index, item) in enumerate(items) {
                    queue.append((
                        item,
                        f"{exact_path}[{index}]",
                        f"{schema_path}[*]",
                        this_path,
                        depth + 1,
                        item.start_point[0] + 1,
                    ));
                }
            }
        }
        return (nodes, edges);
    }

    static def _spring_config_file_node(path: Path, source: bytes, language: str) -> NodeInfo {
        file_path: any = normalize_file_path(path);
        return NodeInfo(
            "File",
            file_path,
            file_path,
            1,
            source.count(b"\n") + 1,
            language=language,
            extra={"config_format": path.suffix.lower().lstrip(".")},
        );
    }

    def _parse_spring_config(path: Path, source: bytes) -> tuple[list[NodeInfo], list[EdgeInfo]] {
        if path.suffix.lower() == ".properties" {
            return self._parse_spring_properties(path, source);
        }
        return self._parse_spring_yaml(path, source);
    }

    def _parse_spring_yaml(path: Path, source: bytes) -> tuple[list[NodeInfo], list[EdgeInfo]] {
        emitted: set[str];
        try {
            documents: any = `list(_yaml.compose_all(source.decode("utf-8", errors="replace")));
        } except (_yaml.YAMLError, RecursionError) as exc {
            logger.debug("Spring YAML parse error in %s: %s", path, exc);
            return ([], []);
        }

        if self._is_non_spring_yaml(documents) {
            return ([], []);
        }

        file_path: any = normalize_file_path(path);
        nodes: any = [self._spring_config_file_node(path, source, "yaml")];
        emitted = set[any]();

        def emit(raw_key: str, value_node: object, document_index: int) {
            key: any = normalize_spring_config_key(raw_key);
            if not key or key in emitted {
                return;
            }
            emitted.add(key);
            tag: any = `str(getattr(value_node, "tag", ""));
            value_type: any = tag.rsplit(":", 1)[-1];
            if value_type not in {"bool", "float", "int", "null", "str", "timestamp"} {
                value_type = "scalar";
            }
            nodes.append(
                NodeInfo(
                    "ConfigProperty",
                    key,
                    file_path,
                    _yaml_line(value_node),
                    _yaml_end_line(value_node),
                    language="yaml",
                    extra={
                        "document_index": document_index,
                        "raw_key": raw_key,
                        "source_file": path.name,
                        "value_type": value_type,
                    },
                ),
            );
        }

        def `visit(`node: object, prefix: str, document_index: int, ancestors: frozenset[int]) {
            node_id: any = id(`node);
            if node_id in ancestors {
                return;
            }
            nested_ancestors: any = ancestors | {node_id};
            if isinstance(`node, _YamlMapping) {
                for (key_node, value_node) in `node.value {
                    raw_segment: any = _yaml_scalar(key_node);
                    if not raw_segment or raw_segment == "<<" {
                        continue;
                    }
                    raw_key: any = f"{prefix}.{raw_segment}" if prefix else raw_segment;
                    if isinstance(value_node, _YamlScalar) {
                        emit(raw_key, value_node, document_index);
                    } else {
                        `visit(value_node, raw_key, document_index, nested_ancestors);
                    }
                }
            } elif isinstance(`node, _YamlSequence) {
                for (index, item) in enumerate(`node.value) {
                    raw_key = f"{prefix}[{index}]";
                    if isinstance(item, _YamlScalar) {
                        emit(raw_key, item, document_index);
                    } else {
                        `visit(item, raw_key, document_index, nested_ancestors);
                    }
                }
            }
        }

        for (document_index, document) in enumerate(documents) {
            if document is not None {
                `visit(document, "", document_index, frozenset());
            }
        }
        return (nodes, []);
    }

    static def _is_non_spring_yaml(documents: list[object]) -> bool {
        key: any;
        signatures: any = (
            frozenset({"apiVersion", "kind"}),
            frozenset({"jobs", "on"}),
            frozenset({"openapi", "paths"}),
            frozenset({"paths", "swagger"}),
            frozenset({"services", "version"}),
            frozenset({"AWSTemplateFormatVersion", "Resources"}),
        );
        for document in documents {
            if document is None {
                continue;
            }
            if not isinstance(document, _YamlMapping) {
                return True;
            }
            top_level_keys: any = {
                key
                for (key_node, _) in document.value
                if (key := _yaml_scalar(key_node)) is not None
            };
            if `any(operator.le(signature, top_level_keys) for signature in signatures) {
                return True;
            }
        }
        return False;
    }

    static def _spring_property_logical_lines(text: str) -> list[tuple[int, str]] {
        logical: list[tuple[int, str]] = [];
        buffer: any = "";
        start_line: any = 1;
        for (line_number, physical) in enumerate(text.splitlines(), 1) {
            if not buffer {
                start_line = line_number;
            }
            buffer += physical.lstrip() if buffer else physical;
            backslashes: any = len(buffer) - len(buffer.rstrip("\\"));
            if backslashes % 2 {
                buffer = buffer[:-1];
                continue;
            }
            logical.append((start_line, buffer));
            buffer = "";
        }
        if buffer {
            logical.append((start_line, buffer));
        }
        return logical;
    }

    static def _spring_property_key(line: str) -> Optional[str] {
        stripped: any = line.lstrip();
        if not stripped or stripped.startswith(("#", "!")) {
            return None;
        }
        escaped: any = False;
        boundary: any = len(stripped);
        for (index, char) in enumerate(stripped) {
            if char == "\\" {
                escaped = not escaped;
                continue;
            }
            if not escaped and (char in "=:" or char.isspace()) {
                boundary = index;
                break;
            }
            escaped = False;
        }
        key: any = stripped[:boundary];
        for escaped_char in (" ", ":", "=", "#", "!") {
            key = key.replace(f"\\{escaped_char}", escaped_char);
        }
        return key or None;
    }

    def _parse_spring_properties(
        path: Path, source: bytes
    ) -> tuple[list[NodeInfo], list[EdgeInfo]] {
        text: any = source.decode("utf-8", errors="replace");
        file_path: any = normalize_file_path(path);
        nodes: any = [self._spring_config_file_node(path, source, "properties")];
        emitted: set[str] = set[any]();
        for (line_number, line) in self._spring_property_logical_lines(text) {
            raw_key: any = self._spring_property_key(line);
            if raw_key is None {
                continue;
            }
            key: any = normalize_spring_config_key(raw_key);
            if not key or key in emitted {
                continue;
            }
            emitted.add(key);
            nodes.append(
                NodeInfo(
                    "ConfigProperty",
                    key,
                    file_path,
                    line_number,
                    line_number,
                    language="properties",
                    extra={"raw_key": raw_key, "source_file": path.name, "value_type": "scalar"},
                ),
            );
        }
        return (nodes, []);
    }

    def _parse_ansible(path: Path, source: bytes) -> tuple[list[NodeInfo], list[EdgeInfo]] {
        try {
            `root: any = _yaml.compose(source.decode("utf-8", errors="replace"));
        } except (_yaml.YAMLError, RecursionError) as exc {
            logger.debug("Ansible YAML parse error in %s: %s", path, exc);
            return ([], []);
        }
        if `root is None {
            return ([], []);
        }

        file_path_str: any = normalize_file_path(path);
        line_count: any = source.count(b"\n") + 1;
        nodes: list[NodeInfo] = [
            NodeInfo("File", file_path_str, file_path_str, 1, line_count, language="ansible"),
        ];
        edges: list[EdgeInfo] = [];

        file_type: any = _ansible_file_type(path);
        if file_type == "vars" {
            return (nodes, edges);
        }
        if file_type in ("unknown", "playbook") {
            if isinstance(`root, _YamlSequence) and `root.value {
                is_pb: any = `any(_ansible_is_play_item(item) for item in `root.value);
                file_type = "playbook" if is_pb else "tasks";
            } else {
                file_type = "unknown";
            }
        }

        if file_type == "playbook" {
            self._parse_ansible_playbook(`root, file_path_str, nodes, edges);
        } elif file_type in ("tasks", "handlers") {
            self._parse_ansible_tasks(
                `root,
                file_path_str,
                nodes,
                edges,
                is_handler=operator.eq(file_type, "handlers"),
                parent_play=None,
            );
        } elif file_type == "meta" {
            self._parse_ansible_meta(`root, file_path_str, nodes, edges);
        }

        return (nodes, self._resolve_ansible_notify_targets(nodes, edges));
    }

    static def _ansible_unique_name(
        nodes: list[NodeInfo], file_path: str, parent_name: Optional[str], requested: str, line: int
    ) -> str {
        used: any = {
            `node.name
            for `node in nodes
            if `node.file_path == file_path and `node.parent_name == parent_name
        };
        if requested not in used {
            return requested;
        }
        candidate: any = f"{requested}@line{line}";
        suffix: any = 2;
        while candidate in used {
            candidate = f"{requested}@line{line}.{suffix}";
            suffix += 1;
        }
        return candidate;
    }

    def _resolve_ansible_notify_targets(
        nodes: list[NodeInfo], edges: list[EdgeInfo]
    ) -> list[EdgeInfo] {
        `node: any;
        node_by_qn: any = {
            self._qualify(`node.name, `node.file_path, `node.parent_name): `node
            for `node in nodes
        };
        handlers: dict[tuple[Optional[str], str], list[str]] = {};
        for `node in nodes {
            if `node.extra.get("ansible_kind") != "handler" {
                continue;
            }
            qn: any = self._qualify(`node.name, `node.file_path, `node.parent_name);
            labels: any = {`node.name, `str(`node.extra.get("ansible_name") or `node.name)};
            listen: any = `node.extra.get("ansible_listen");
            if isinstance(listen, `str) and listen {
                labels.add(listen);
            }
            for label in labels {
                handlers.setdefault((`node.parent_name, label), []).append(qn);
            }
        }

        resolved: list[EdgeInfo] = [];
        for `edge in edges {
            if `edge.extra.get("ansible_kind") != "notify" or "::" in `edge.target {
                resolved.append(`edge);
                continue;
            }
            source: any = node_by_qn.get(`edge.source);
            scope: any = source.parent_name if source is not None else None;
            candidates: any = handlers.get((scope, `edge.target), []);
            if len(candidates) != 1 {
                resolved.append(`edge);
                continue;
            }
            resolved.append(
                EdgeInfo(
                    `edge.kind,
                    `edge.source,
                    candidates[0],
                    `edge.file_path,
                    `edge.line,
                    extra=`edge.extra,
                ),
            );
        }
        return resolved;
    }

    def _parse_ansible_playbook(
        `root: object, file_path: str, nodes: list[NodeInfo], edges: list[EdgeInfo]
    ) {
        if not isinstance(`root, _YamlSequence) {
            return;
        }

        for item in `root.value {
            if not isinstance(item, _YamlMapping) {
                continue;
            }
            import_pb_node: any = _yaml_get_key(item, "import_playbook");
            if import_pb_node is not None {
                target: any = _yaml_scalar(import_pb_node);
                if target {
                    edges.append(
                        EdgeInfo(
                            "IMPORTS_FROM",
                            file_path,
                            target,
                            file_path,
                            _yaml_line(item),
                            extra={"ansible_kind": "import_playbook"},
                        ),
                    );
                }
                continue;
            }

            if not _ansible_is_play_item(item) {
                continue;
            }
            name_node: any = _yaml_get_key(item, "name");
            hosts_node: any = _yaml_get_key(item, "hosts");
            if name_node and _yaml_scalar(name_node) {
                play_name: any = _yaml_scalar(name_node);
            } elif hosts_node and _yaml_scalar(hosts_node) {
                play_name = f"play[{_yaml_scalar(hosts_node)}]";
            } else {
                play_name = f"play@line{_yaml_line(item)}";
            }

            play_line_start: any = _yaml_line(item);
            play_line_end: any = _yaml_end_line(item);
            play_name = self._ansible_unique_name(
                nodes, file_path, None, `str(play_name), play_line_start
            );
            play_qn: any = self._qualify(play_name, file_path, None);

            nodes.append(
                NodeInfo(
                    "Class",
                    play_name,
                    file_path,
                    play_line_start,
                    play_line_end,
                    language="ansible",
                    extra={"ansible_kind": "play"},
                ),
            );
            edges.append(EdgeInfo("CONTAINS", file_path, play_qn, file_path, play_line_start));
            vars_files_node: any = _yaml_get_key(item, "vars_files");
            if isinstance(vars_files_node, _YamlSequence) {
                for vf in vars_files_node.value {
                    vf_path: any = _yaml_scalar(vf);
                    if vf_path {
                        edges.append(
                            EdgeInfo(
                                "IMPORTS_FROM",
                                play_qn,
                                vf_path,
                                file_path,
                                _yaml_line(vf),
                                extra={"ansible_kind": "vars_files"},
                            ),
                        );
                    }
                }
            }
            roles_node: any = _yaml_get_key(item, "roles");
            if isinstance(roles_node, _YamlSequence) {
                for role_item in roles_node.value {
                    role_name: any = self._ansible_extract_role_name(role_item);
                    if role_name {
                        edges.append(
                            EdgeInfo(
                                "IMPORTS_FROM",
                                play_qn,
                                role_name,
                                file_path,
                                _yaml_line(role_item),
                                extra={"ansible_kind": "role_reference"},
                            ),
                        );
                    }
                }
            }
            for (section_key, is_handler) in (
                ("pre_tasks", False),
                ("tasks", False),
                ("post_tasks", False),
                ("handlers", True),
            ) {
                section_node: any = _yaml_get_key(item, section_key);
                if isinstance(section_node, _YamlSequence) {
                    self._parse_ansible_tasks(
                        section_node,
                        file_path,
                        nodes,
                        edges,
                        is_handler=is_handler,
                        parent_play=play_name,
                    );
                }
            }
        }
    }

    def _parse_ansible_tasks(
        tasks_node: object,
        file_path: str,
        nodes: list[NodeInfo],
        edges: list[EdgeInfo],
        is_handler: bool,
        parent_play: Optional[str],
    ) {
        if not isinstance(tasks_node, _YamlSequence) {
            return;
        }

        for task_node in tasks_node.value {
            if not isinstance(task_node, _YamlMapping) {
                continue;
            }
            module_key: Optional[str] = None;
            module_short: Optional[str] = None;
            module_args_node: Optional[object] = None;
            for (k_node, v_node) in task_node.value {
                k_str: any = _yaml_scalar(k_node);
                if not k_str {
                    continue;
                }
                if k_str in _TASK_META_KEYS or k_str.startswith("with_") {
                    continue;
                }
                module_key = k_str;
                module_short = _ansible_fqcn_short(k_str);
                module_args_node = v_node;
                break;
            }
            name_node: any = _yaml_get_key(task_node, "name");
            name_raw: any = _yaml_scalar(name_node) if name_node is not None else None;
            if name_raw {
                requested_name: any = name_raw;
            } elif module_short or module_key {
                requested_name = f"{module_short or module_key}@line{_yaml_line(task_node)}";
            } else {
                requested_name = f"task@line{_yaml_line(task_node)}";
            }

            task_name: any = self._ansible_unique_name(
                nodes, file_path, parent_play, requested_name, _yaml_line(task_node)
            );
            task_qn: any = self._qualify(task_name, file_path, parent_play);

            task_extra: dict = {
                "ansible_kind": "handler" if is_handler else "task",
                "ansible_module": module_key or "",
                "ansible_name": requested_name,
            };
            if is_handler {
                listen_node: any = _yaml_get_key(task_node, "listen");
                listen_val: any = _yaml_scalar(listen_node) if listen_node is not None else None;
                if listen_val {
                    task_extra["ansible_listen"] = listen_val;
                }
            }

            nodes.append(
                NodeInfo(
                    "Function",
                    task_name,
                    file_path,
                    _yaml_line(task_node),
                    _yaml_end_line(task_node),
                    language="ansible",
                    parent_name=parent_play,
                    extra=task_extra,
                ),
            );
            edges.append(
                EdgeInfo(
                    "CONTAINS",
                    self._qualify(parent_play, file_path, None)
                        if parent_play is not None
                        else file_path,
                    task_qn,
                    file_path,
                    _yaml_line(task_node),
                ),
            );
            notify_node: any = _yaml_get_key(task_node, "notify");
            if notify_node is not None {
                for handler_name in self._ansible_extract_notify_targets(notify_node) {
                    edges.append(
                        EdgeInfo(
                            "CALLS",
                            task_qn,
                            handler_name,
                            file_path,
                            _yaml_line(notify_node),
                            extra={"ansible_kind": "notify"},
                        ),
                    );
                }
            }
            if module_short in ("include_tasks", "import_tasks") {
                target_file: any = self._ansible_module_arg_str(module_args_node);
                if target_file {
                    edges.append(
                        EdgeInfo(
                            "IMPORTS_FROM",
                            task_qn,
                            target_file,
                            file_path,
                            _yaml_line(task_node),
                            extra={"ansible_kind": module_short},
                        ),
                    );
                }
            }
            if module_short in ("include_role", "import_role") {
                role_name: any = self._ansible_role_from_module_args(module_args_node);
                if role_name {
                    edges.append(
                        EdgeInfo(
                            "IMPORTS_FROM",
                            task_qn,
                            role_name,
                            file_path,
                            _yaml_line(task_node),
                            extra={"ansible_kind": module_short},
                        ),
                    );
                }
            }
            if module_short == "include_vars" {
                var_target: any = self._ansible_module_arg_str(module_args_node);
                if var_target {
                    edges.append(
                        EdgeInfo(
                            "IMPORTS_FROM",
                            task_qn,
                            var_target,
                            file_path,
                            _yaml_line(task_node),
                            extra={"ansible_kind": "include_vars"},
                        ),
                    );
                }
            }
            for block_key in ("block", "rescue", "always") {
                block_node: any = _yaml_get_key(task_node, block_key);
                if block_node is not None {
                    self._parse_ansible_tasks(
                        block_node,
                        file_path,
                        nodes,
                        edges,
                        is_handler=is_handler,
                        parent_play=parent_play,
                    );
                }
            }
        }
    }

    def _parse_ansible_meta(
        `root: object, file_path: str, nodes: list[NodeInfo], edges: list[EdgeInfo]
    ) {
        if not isinstance(`root, _YamlMapping) {
            return;
        }
        deps_node: any = _yaml_get_key(`root, "dependencies");
        if not isinstance(deps_node, _YamlSequence) {
            return;
        }
        for dep_item in deps_node.value {
            dep_name: any = self._ansible_extract_role_name(dep_item);
            if dep_name {
                edges.append(
                    EdgeInfo(
                        "DEPENDS_ON",
                        file_path,
                        dep_name,
                        file_path,
                        _yaml_line(dep_item),
                        extra={"ansible_kind": "role_dependency"},
                    ),
                );
            }
        }
    }

    def _ansible_extract_role_name(item: object) -> Optional[str] {
        if isinstance(item, _YamlScalar) {
            return item.value or None;
        }
        if isinstance(item, _YamlMapping) {
            for key in ("role", "name") {
                v: any = _yaml_get_key(item, key);
                val: any = _yaml_scalar(v);
                if val {
                    return val;
                }
            }
        }
        return None;
    }

    def _ansible_extract_notify_targets(notify_node: object) -> list[str] {
        if isinstance(notify_node, _YamlScalar) {
            return [notify_node.value] if notify_node.value else [];
        }
        if isinstance(notify_node, _YamlSequence) {
            return [
                item.value
                for item in notify_node.value
                if isinstance(item, _YamlScalar) and item.value
            ];
        }
        return [];
    }

    def _ansible_module_arg_str(args_node: Optional[object]) -> Optional[str] {
        if args_node is None {
            return None;
        }
        if isinstance(args_node, _YamlScalar) {
            return args_node.value or None;
        }
        if isinstance(args_node, _YamlMapping) {
            for key in ("file", "_raw_params") {
                v: any = _yaml_get_key(args_node, key);
                val: any = _yaml_scalar(v);
                if val {
                    return val;
                }
            }
        }
        return None;
    }

    def _ansible_role_from_module_args(args_node: Optional[object]) -> Optional[str] {
        if args_node is None {
            return None;
        }
        if isinstance(args_node, _YamlScalar) {
            return args_node.value or None;
        }
        if isinstance(args_node, _YamlMapping) {
            v: any = _yaml_get_key(args_node, "name");
            return _yaml_scalar(v);
        }
        return None;
    }

    """The class, function, import and call node types of `language`, made once per parser."""
    def _type_sets(language: str) -> any {
        sets: any = self._node_type_sets.get(language);
        if sets is None {
            sets = (
                frozenset(self._class_types.get(language, [])),
                frozenset(self._function_types.get(language, [])),
                frozenset(self._import_types.get(language, [])),
                frozenset(self._call_types.get(language, [])),
            );
            self._node_type_sets[language] = sets;
        }
        return sets;
    }

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
    ) {
        if _depth > self._MAX_AST_DEPTH {
            return;
        }
        (class_types, func_types, import_types, call_types) = self._type_sets(language);

        for child in `root.children {
            node_type: any = child.type;
            if language == "r"
                and self._extract_r_constructs(
                    child,
                    node_type,
                    source,
                    language,
                    file_path,
                    nodes,
                    edges,
                    enclosing_class,
                    enclosing_func,
                    import_map,
                    defined_names,
                )
            {
                continue;
            }
            if language in ("lua", "luau")
                and self._extract_lua_constructs(
                    child,
                    node_type,
                    source,
                    language,
                    file_path,
                    nodes,
                    edges,
                    enclosing_class,
                    enclosing_func,
                    import_map,
                    defined_names,
                    _depth,
                )
            {
                continue;
            }
            if language == "zig"
                and self._extract_zig_constructs(
                    child,
                    node_type,
                    source,
                    language,
                    file_path,
                    nodes,
                    edges,
                    enclosing_class,
                    enclosing_func,
                    import_map,
                    defined_names,
                    _depth,
                )
            {
                continue;
            }
            if language == "bash" and node_type == "command" {
                if self._extract_bash_source_command(child, file_path, edges) {
                    continue;
                }
            }
            if language == "elixir" and node_type == "call" {
                if self._extract_elixir_constructs(
                    child,
                    source,
                    language,
                    file_path,
                    nodes,
                    edges,
                    enclosing_class,
                    enclosing_func,
                    import_map,
                    defined_names,
                    _depth,
                ) {
                    continue;
                }
            }
            if language == "nix" and node_type == "binding" {
                if self._extract_nix_constructs(
                    child,
                    source,
                    language,
                    file_path,
                    nodes,
                    edges,
                    enclosing_class,
                    enclosing_func,
                    import_map,
                    defined_names,
                    _depth,
                ) {
                    continue;
                }
            }
            if language == "hcl" and node_type == "block" {
                if self._extract_hcl_constructs(child, file_path, nodes, edges) {
                    continue;
                }
            }
            if language == "julia"
                and self._extract_julia_constructs(
                    child,
                    node_type,
                    source,
                    language,
                    file_path,
                    nodes,
                    edges,
                    enclosing_class,
                    enclosing_func,
                    import_map,
                    defined_names,
                    _depth,
                )
            {
                continue;
            }
            if language == "verilog"
                and self._extract_verilog_constructs(
                    child, node_type, file_path, nodes, edges, enclosing_class, enclosing_func
                )
            {
                continue;
            }

            if language == "rust" and node_type == "impl_item" {
                self._extract_rust_impl(
                    child,
                    source,
                    file_path,
                    nodes,
                    edges,
                    import_map or {},
                    defined_names or set[any](),
                    _depth,
                );
                continue;
            }
            if language == "dart" {
                self._extract_dart_calls_from_children(
                    child, source, file_path, edges, enclosing_class, enclosing_func
                );
            }
            if language in ("javascript", "typescript", "tsx") and node_type == "call_expression" {
                self._extract_js_module_call(child, file_path, language, edges);
            }
            if language in ("javascript", "typescript", "tsx")
                and node_type in ("lexical_declaration", "variable_declaration")
                and self._extract_js_var_functions(
                    child,
                    source,
                    language,
                    file_path,
                    nodes,
                    edges,
                    enclosing_class,
                    enclosing_func,
                    import_map,
                    defined_names,
                    _depth,
                )
            {
                continue;
            }
            if node_type in class_types
                and self._extract_classes(
                    child,
                    source,
                    language,
                    file_path,
                    nodes,
                    edges,
                    enclosing_class,
                    import_map,
                    defined_names,
                    _depth,
                )
            {
                continue;
            }
            if language in ("javascript", "typescript", "tsx")
                and node_type == "public_field_definition"
                and self._extract_js_field_function(
                    child,
                    source,
                    language,
                    file_path,
                    nodes,
                    edges,
                    enclosing_class,
                    enclosing_func,
                    import_map,
                    defined_names,
                    _depth,
                )
            {
                continue;
            }
            if language in ("javascript", "typescript", "tsx")
                and node_type == "expression_statement"
                and self._extract_js_member_functions(
                    child,
                    source,
                    language,
                    file_path,
                    nodes,
                    edges,
                    enclosing_class,
                    enclosing_func,
                    import_map,
                    defined_names,
                    _depth,
                )
            {
                continue;
            }
            if node_type in func_types
                and self._extract_functions(
                    child,
                    source,
                    language,
                    file_path,
                    nodes,
                    edges,
                    enclosing_class,
                    import_map,
                    defined_names,
                    _depth,
                    enclosing_func,
                )
            {
                continue;
            }
            if node_type in import_types {
                if self._extract_imports(child, language, source, file_path, edges) {
                    continue;
                }
            }
            if node_type in call_types {
                if self._extract_calls(
                    child,
                    source,
                    language,
                    file_path,
                    nodes,
                    edges,
                    enclosing_class,
                    enclosing_func,
                    import_map,
                    defined_names,
                    _depth,
                    _go_receiver_bindings,
                ) {
                    continue;
                }
            }
            if language in ("javascript", "typescript", "tsx")
                and node_type in ("jsx_opening_element", "jsx_self_closing_element")
            {
                self._extract_jsx_component_call(
                    child,
                    language,
                    file_path,
                    edges,
                    enclosing_class,
                    enclosing_func,
                    import_map,
                    defined_names,
                );
            }
            if language in ("typescript", "tsx") and node_type == "type_identifier" {
                self._extract_ts_type_reference(
                    child,
                    language,
                    file_path,
                    edges,
                    enclosing_class,
                    enclosing_func,
                    import_map,
                    defined_names,
                );
            }
            self._extract_value_references(
                child,
                node_type,
                source,
                language,
                file_path,
                edges,
                enclosing_class,
                enclosing_func,
                import_map,
                defined_names,
            );
            if language == "solidity"
                and self._extract_solidity_constructs(
                    child,
                    node_type,
                    source,
                    file_path,
                    nodes,
                    edges,
                    enclosing_class,
                    enclosing_func,
                )
            {
                continue;
            }
            self._extract_from_tree(
                child,
                source,
                language,
                file_path,
                nodes,
                edges,
                enclosing_class=enclosing_class,
                enclosing_func=enclosing_func,
                import_map=import_map,
                defined_names=defined_names,
                _depth=_depth + 1,
                _go_receiver_bindings=_go_receiver_bindings,
            );
        }
    }

    def _elixir_call_identifier(`node) -> Optional[str] {
        if not `node.children {
            return None;
        }
        first: any = `node.children[0];
        if first.type == "identifier" {
            return first.text.decode("utf-8", errors="replace");
        }
        if first.type == "dot" {
            for child in reversed(first.children) {
                if child.type == "identifier" {
                    return child.text.decode("utf-8", errors="replace");
                }
            }
        }
        return None;
    }

    def _elixir_module_name(arguments) -> Optional[str] {
        for child in arguments.children {
            if child.type == "alias" {
                return child.text.decode("utf-8", errors="replace");
            }
            if child.type == "dot" {
                return child.text.decode("utf-8", errors="replace");
            }
        }
        return None;
    }

    def _elixir_function_name_and_params(
        arguments, source: bytes
    ) -> tuple[Optional[str], Optional[str]] {
        def function_head(`node) -> any {
            if `node.type != "binary_operator" {
                return `node;
            }
            operator: any = next(
                (child
                for child in `node.children
                if child.text.decode("utf-8", errors="replace") == "when"),
                None,
            );
            if operator is None {
                return None;
            }
            left: any = `node.child_by_field_name("left");
            if left is None {
                return None;
            }
            return function_head(left);
        }

        child: any;
        for child in arguments.children {
            child = function_head(child);
            if child is None {
                continue;
            }
            if child.type == "call" {
                name: Optional[str] = None;
                for sub in child.children {
                    if sub.type == "identifier" and name is None {
                        name = sub.text.decode("utf-8", errors="replace");
                    }
                }
                params_text: any = child.text.decode("utf-8", errors="replace");
                if name and params_text.startswith(name) {
                    params_text = params_text[len(name):];
                }
                return (name, params_text);
            }
            if child.type == "identifier" {
                return (child.text.decode("utf-8", errors="replace"), None);
            }
        }
        return (None, None);
    }

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
    ) -> bool {
        ident: any = self._elixir_call_identifier(`node);
        if ident is None {
            return False;
        }
        if ident == "defmodule" {
            arguments: any = None;
            do_block: any = None;
            sub: any;
            for sub in `node.children {
                if sub.type == "arguments" {
                    arguments = sub;
                } elif sub.type == "do_block" {
                    do_block = sub;
                }
            }
            if arguments is None {
                return False;
            }
            mod_name: any = self._elixir_module_name(arguments);
            if mod_name is None {
                return False;
            }
            qualified: any = self._qualify(mod_name, file_path, None);
            nodes.append(
                NodeInfo(
                    "Class",
                    mod_name,
                    file_path,
                    `node.start_point[0] + 1,
                    `node.end_point[0] + 1,
                    language=language,
                    parent_name=None,
                ),
            );
            edges.append(
                EdgeInfo("CONTAINS", file_path, qualified, file_path, `node.start_point[0] + 1)
            );
            if do_block is not None {
                self._extract_from_tree(
                    do_block,
                    source,
                    language,
                    file_path,
                    nodes,
                    edges,
                    enclosing_class=mod_name,
                    enclosing_func=None,
                    import_map=import_map,
                    defined_names=defined_names,
                    _depth=_depth + 1,
                );
            }
            return True;
        }
        if ident in ("def", "defp", "defmacro", "defmacrop") {
            arguments = None;
            do_block = None;
            for sub in `node.children {
                if sub.type == "arguments" {
                    arguments = sub;
                } elif sub.type == "do_block" {
                    do_block = sub;
                }
            }
            if arguments is None {
                return False;
            }
            fn_name: any;
            params: any;
            (fn_name, params) = self._elixir_function_name_and_params(arguments, source) as any;
            if fn_name is None {
                return False;
            }
            is_test: any = _is_test_function(fn_name, file_path, repo_root=self._repo_root);
            kind: any = "Test" if is_test else "Function";
            qualified = self._qualify(fn_name, file_path, enclosing_class);
            nodes.append(
                NodeInfo(
                    kind,
                    fn_name,
                    file_path,
                    `node.start_point[0] + 1,
                    `node.end_point[0] + 1,
                    language=language,
                    parent_name=enclosing_class,
                    params=params,
                    is_test=is_test,
                ),
            );
            container: any = self._qualify(enclosing_class, file_path, None)
                if enclosing_class
                else file_path;
            edges.append(
                EdgeInfo("CONTAINS", container, qualified, file_path, `node.start_point[0] + 1)
            );
            if do_block is not None {
                self._extract_from_tree(
                    do_block,
                    source,
                    language,
                    file_path,
                    nodes,
                    edges,
                    enclosing_class=enclosing_class,
                    enclosing_func=fn_name,
                    import_map=import_map,
                    defined_names=defined_names,
                    _depth=_depth + 1,
                );
            } else {
                for sub in arguments.children {
                    if sub.type == "keywords" {
                        self._extract_from_tree(
                            sub,
                            source,
                            language,
                            file_path,
                            nodes,
                            edges,
                            enclosing_class=enclosing_class,
                            enclosing_func=fn_name,
                            import_map=import_map,
                            defined_names=defined_names,
                            _depth=_depth + 1,
                        );
                    }
                }
            }
            return True;
        }
        if ident in ("alias", "import", "require", "use") {
            for sub in `node.children {
                if sub.type == "arguments" {
                    mod: any = self._elixir_module_name(sub);
                    if mod is not None {
                        edges.append(
                            EdgeInfo(
                                "IMPORTS_FROM", file_path, mod, file_path, `node.start_point[0] + 1
                            ),
                        );
                    }
                    break;
                }
            }
            return True;
        }
        call_name: any = ident;
        caller: any = self._qualify(enclosing_func, file_path, enclosing_class)
            if enclosing_func
            else file_path;
        target: any = self._resolve_call_target(
            call_name, file_path, language, import_map or {}, defined_names or set[any]()
        );
        edges.append(EdgeInfo("CALLS", caller, target, file_path, `node.start_point[0] + 1));
        for sub in `node.children {
            if sub.type in ("arguments", "do_block") {
                self._extract_from_tree(
                    sub,
                    source,
                    language,
                    file_path,
                    nodes,
                    edges,
                    enclosing_class=enclosing_class,
                    enclosing_func=enclosing_func,
                    import_map=import_map,
                    defined_names=defined_names,
                    _depth=_depth + 1,
                );
            }
        }
        return True;
    }

    def _merge_elixir_clauses(
        nodes: list[NodeInfo], edges: list[EdgeInfo]
    ) -> tuple[list[NodeInfo], list[EdgeInfo]] {
        first_clauses: dict[str, NodeInfo] = {};
        merged_nodes: list[NodeInfo] = [];
        for `node in nodes {
            if `node.kind not in ("Function", "Test") {
                merged_nodes.append(`node);
                continue;
            }
            first: any = first_clauses.setdefault(self._node_qualified(`node), `node);
            if first is `node {
                merged_nodes.append(`node);
                continue;
            }
            first.line_start = min(first.line_start, `node.line_start);
            first.line_end = max(first.line_end, `node.line_end);
        }

        contained: set[tuple[str, str]] = set[any]();
        merged_edges: list[EdgeInfo] = [];
        for `edge in edges {
            if `edge.kind == "CONTAINS" {
                if (`edge.source, `edge.target) in contained {
                    continue;
                }
                contained.add((`edge.source, `edge.target));
            }
            merged_edges.append(`edge);
        }
        return (merged_nodes, merged_edges);
    }

    static def _is_nix_flake_file(file_path: str) -> bool {
        return operator.eq(Path(file_path).name, "flake.nix");
    }

    def _nix_attrpath_parts(attrpath_node) -> list[str] {
        parts: list[str] = [];
        for child in attrpath_node.children {
            if child.type == "identifier" {
                parts.append(child.text.decode("utf-8", errors="replace"));
            }
        }
        return parts;
    }

    def _extract_nix_flake_input_urls(attrset_node) -> list[tuple[str, int]] {
        results: list[tuple[str, int]];
        results = [];

        def `visit(n) {
            if n is None {
                return;
            }
            if n.type == "binding" {
                inner_path: any = None;
                inner_rhs: any = None;
                for sub in n.children {
                    if sub.type == "attrpath" {
                        inner_path = sub;
                    } elif sub.type not in ("=", ";") and inner_path is not None {
                        if inner_rhs is None {
                            inner_rhs = sub;
                        }
                    }
                }
                if inner_path is not None and inner_rhs is not None {
                    parts: any = self._nix_attrpath_parts(inner_path);
                    if parts and parts[-1] == "url" and inner_rhs.type == "string_expression" {
                        c: any;
                        for c in inner_rhs.children {
                            if c.type == "string_fragment" {
                                url: any = c.text.decode("utf-8", errors="replace");
                                results.append((url, n.start_point[0] + 1));
                                break;
                            }
                        }
                        return;
                    }
                    if inner_rhs.type == "attrset_expression" {
                        `visit(inner_rhs);
                        return;
                    }
                }
            }
            for c in n.children {
                `visit(c);
            }
        }

        `visit(attrset_node);
        return results;
    }

    def _extract_nix_import_targets(rhs_node) -> list[tuple[str, int]] {
        results: list[tuple[str, int]];
        results = [];
        def head_call_name(apply) -> Optional[str] {
            cur: any = apply;
            while cur is not None and cur.type == "apply_expression" {
                cur = cur.children[0] if cur.children else None;
            }
            if cur is None {
                return None;
            }
            if cur.type == "variable_expression" {
                c: any;
                for c in cur.children {
                    if c.type == "identifier" {
                        return c.text.decode("utf-8", errors="replace");
                    }
                }
            }
            if cur.type == "select_expression" {
                last: Optional[str] = None;
                for c in cur.children {
                    if c.type == "attrpath" {
                        for ac in c.children {
                            if ac.type == "identifier" {
                                last = ac.text.decode("utf-8", errors="replace");
                            }
                        }
                    } elif c.type == "identifier" {
                        last = c.text.decode("utf-8", errors="replace");
                    }
                }
                return last;
            }
            if cur.type == "identifier" {
                return cur.text.decode("utf-8", errors="replace");
            }
            return None;
        }
        def first_path_arg(apply) -> Optional[str] {
            stack: list = [];
            cur: any = apply;
            while cur is not None and cur.type == "apply_expression" {
                if len(cur.children) >= 2 {
                    stack.append(cur.children[1]);
                }
                cur = cur.children[0] if cur.children else None;
            }
            for arg in reversed(stack) {
                if arg.type == "path_expression" {
                    return arg.text.decode("utf-8", errors="replace").strip();
                }
            }
            return None;
        }

        def `visit(n) {
            if n is None {
                return;
            }
            if n.type == "apply_expression" {
                name: any = head_call_name(n);
                if name in ("import", "callPackage") {
                    path: any = first_path_arg(n);
                    if path {
                        results.append((path, n.start_point[0] + 1));
                    }
                }
            }
            for c in n.children {
                `visit(c);
            }
        }

        `visit(rhs_node);
        return results;
    }

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
    ) -> bool {
        attrpath_node: any = None;
        rhs_node: any = None;
        for sub in `node.children {
            if sub.type == "attrpath" {
                attrpath_node = sub;
            } elif sub.type not in ("=", ";") and attrpath_node is not None {
                if rhs_node is None {
                    rhs_node = sub;
                }
            }
        }
        if attrpath_node is None or rhs_node is None {
            return False;
        }

        parts: any = self._nix_attrpath_parts(attrpath_node);
        if not parts {
            return False;
        }
        name: any = ".".join(parts);
        line: any = `node.start_point[0] + 1;
        if self._is_nix_flake_file(file_path)
            and len(parts) >= 2
            and parts[0] == "inputs"
            and parts[-1] == "url"
            and rhs_node.type == "string_expression"
        {
            url: Optional[str] = None;
            for c in rhs_node.children {
                if c.type == "string_fragment" {
                    url = c.text.decode("utf-8", errors="replace");
                    break;
                }
            }
            if url {
                edges.append(EdgeInfo("IMPORTS_FROM", file_path, url, file_path, line));
                return True;
            }
        }
        if self._is_nix_flake_file(file_path)
            and parts == ["inputs"]
            and rhs_node.type == "attrset_expression"
        {
            for (url, uline) in self._extract_nix_flake_input_urls(rhs_node) {
                edges.append(EdgeInfo("IMPORTS_FROM", file_path, url, file_path, uline));
            }
        }
        qualified: any = self._qualify(name, file_path, enclosing_class);
        nodes.append(
            NodeInfo(
                "Function",
                name,
                file_path,
                line,
                `node.end_point[0] + 1,
                language=language,
                parent_name=enclosing_class,
            ),
        );
        container: any = self._qualify(enclosing_class, file_path, None)
            if enclosing_class
            else file_path;
        edges.append(EdgeInfo("CONTAINS", container, qualified, file_path, line));
        for (target, tline) in self._extract_nix_import_targets(rhs_node) {
            resolved: any = self._resolve_module_to_file(target, file_path, "nix");
            edges.append(EdgeInfo("IMPORTS_FROM", file_path, resolved or target, file_path, tline));
        }
        self._extract_from_tree(
            rhs_node,
            source,
            language,
            file_path,
            nodes,
            edges,
            enclosing_class=enclosing_class,
            enclosing_func=enclosing_func,
            import_map=import_map,
            defined_names=defined_names,
            _depth=_depth + 1,
        );
        return True;
    }

    def _extract_hcl_constructs(
        `node, file_path: str, nodes: list[NodeInfo], edges: list[EdgeInfo]
    ) -> bool {
        tmpl: any;
        children: any = `node.children;
        if not children or children[0].type != "identifier" {
            return False;
        }

        block_type: any = _hcl_text(children[0]);
        labels: any = [
            _hcl_text(tmpl)
            for child in children[1:]
            if child.type == "string_lit"
            if (tmpl := _hcl_child(child, "template_literal")) is not None
        ];
        body_node: any = _hcl_child(`node, "body");
        line_start: any = `node.start_point[0] + 1;

        if block_type == "locals" {
            return self._emit_hcl_locals(body_node, file_path, nodes, edges);
        }

        cfg: any = _HCL_BLOCK_CFG.get(block_type);
        if cfg is None {
            return True;
        }

        kind: any;
        prefix: any;
        n_labels: any;
        emit_refs: any;
        (kind, prefix, n_labels, emit_refs) = cfg as any;
        name: any = _hcl_block_name(prefix, labels, n_labels);
        if name is None {
            return True;
        }

        if block_type == "provider" and body_node is not None {
            alias: any = self._hcl_get_attribute_string(body_node, "alias");
            if alias {
                name += f".{alias}";
            }
        }

        qualified: any = self._qualify(name, file_path, None);
        nodes.append(
            NodeInfo(
                kind,
                name,
                file_path,
                line_start,
                `node.end_point[0] + 1,
                language="hcl",
                extra={"hcl_type": block_type},
            ),
        );
        edges.append(EdgeInfo("CONTAINS", file_path, qualified, file_path, line_start));

        if body_node is None {
            return True;
        }

        if block_type == "module" {
            src: any = self._hcl_get_attribute_string(body_node, "source");
            if src {
                resolved: any = self._resolve_module_to_file(src, file_path, "hcl");
                edges.append(
                    EdgeInfo("IMPORTS_FROM", file_path, resolved or src, file_path, line_start)
                );
            }
        }

        if emit_refs {
            provider_attributes: any = frozenset({"provider"})
                if block_type in ("resource", "data")
                else frozenset({"providers"}) if block_type == "module" else frozenset();
            self._walk_hcl_expressions(
                body_node,
                file_path,
                edges,
                name,
                provider_body=body_node,
                provider_attributes=provider_attributes,
            );
        }

        return True;
    }

    def _emit_hcl_locals(
        body_node, file_path: str, nodes: list[NodeInfo], edges: list[EdgeInfo]
    ) -> bool {
        if body_node is None {
            return True;
        }
        for attr in body_node.children {
            if attr.type != "attribute" {
                continue;
            }
            key: any = _hcl_child(attr, "identifier");
            if key is None {
                continue;
            }
            lname: any = f"local.{_hcl_text(key)}";
            lline: any = attr.start_point[0] + 1;
            nodes.append(
                NodeInfo(
                    "Function",
                    lname,
                    file_path,
                    lline,
                    attr.end_point[0] + 1,
                    language="hcl",
                    extra={"hcl_type": "local"},
                ),
            );
            edges.append(
                EdgeInfo(
                    "CONTAINS", file_path, self._qualify(lname, file_path, None), file_path, lline
                ),
            );
            self._walk_hcl_expressions(attr, file_path, edges, lname);
        }
        return True;
    }

    def _hcl_get_attribute_string(body_node, attr_name: str) -> Optional[str] {
        for attr in body_node.children {
            if attr.type != "attribute" {
                continue;
            }
            key: any = _hcl_child(attr, "identifier");
            expr: any = _hcl_child(attr, "expression");
            if key is None or expr is None or _hcl_text(key) != attr_name {
                continue;
            }
            lit: any = _hcl_child(expr, "literal_value");
            if lit is None {
                continue;
            }
            str_lit: any = _hcl_child(lit, "string_lit");
            if str_lit is None {
                continue;
            }
            tmpl: any = _hcl_child(str_lit, "template_literal");
            if tmpl is not None {
                return _hcl_text(tmpl);
            }
        }
        return None;
    }

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
    ) {
        if `node.type in ("expression", "body") {
            for (`root, attrs, line) in _hcl_variable_refs(`node) {
                if `root in local_names {
                    continue;
                }
                ref: any = _hcl_ref_target(`root, attrs, provider=provider_context);
                if ref {
                    edges.append(
                        EdgeInfo(
                            "REFERENCES",
                            self._qualify(enclosing_name, file_path, None),
                            self._qualify(ref, file_path, None),
                            file_path,
                            line,
                        ),
                    );
                }
            }
        }
        for child in `node.children {
            if child.type not in _HCL_RECURSE_TYPES {
                continue;
            }
            if provider_context and `node.type == "object_elem" {
                if child == `node.child_by_field_name("key") {
                    continue;
                }
            }
            child_provider_context: any = provider_context;
            if child.type == "attribute" {
                key: any = _hcl_child(child, "identifier");
                child_provider_context = operator.eq(child.parent, provider_body)
                    and key is not None
                    and _hcl_text(key) in provider_attributes;
            }
            child_local_names: any = local_names;
            if child.type == "block" {
                iter_name: any = _hcl_dynamic_iterator_name(child);
                if iter_name {
                    child_local_names = local_names | {iter_name};
                }
            } elif child.type == "for_expr" {
                child_local_names = local_names | _hcl_for_iterator_names(child);
            }
            self._walk_hcl_expressions(
                child,
                file_path,
                edges,
                enclosing_name,
                child_local_names,
                provider_body=provider_body,
                provider_attributes=provider_attributes,
                provider_context=child_provider_context,
            );
        }
    }

    def _extract_bash_source_command(`node, file_path: str, edges: list[EdgeInfo]) -> bool {
        command_name: Optional[str] = None;
        args: list[str] = [];
        for sub in `node.children {
            if sub.type == "command_name" {
                command_name = sub.text.decode("utf-8", errors="replace").strip();
            } elif sub.type in ("word", "string", "raw_string") and command_name {
                txt: any = sub.text.decode("utf-8", errors="replace").strip();
                if len(txt) >= 2 and txt[0] in ("'", "\"") and txt[-1] == txt[0] {
                    txt = txt[1:-1];
                }
                if txt {
                    args.append(txt);
                }
            }
        }
        if command_name in ("source", ".") and args {
            target: any = args[0];
            resolved: any = self._resolve_module_to_file(target, file_path, "bash");
            edges.append(
                EdgeInfo(
                    "IMPORTS_FROM",
                    file_path,
                    resolved or target,
                    file_path,
                    `node.start_point[0] + 1,
                ),
            );
            return True;
        }
        return False;
    }

    def _extract_dart_calls_from_children(
        parent,
        source: bytes,
        file_path: str,
        edges: list[EdgeInfo],
        enclosing_class: Optional[str],
        enclosing_func: Optional[str],
    ) {
        call_name: Optional[str] = None;
        for sub in parent.children {
            if sub.type == "identifier" {
                call_name = sub.text.decode("utf-8", errors="replace");
                continue;
            }
            if sub.type == "selector" {
                method_name: Optional[str] = None;
                has_arguments: any = False;
                for ssub in sub.children {
                    if ssub.type == "unconditional_assignable_selector" {
                        for ident in ssub.children {
                            if ident.type == "identifier" {
                                method_name = ident.text.decode("utf-8", errors="replace");
                                break;
                            }
                        }
                    } elif ssub.type == "argument_part" {
                        has_arguments = True;
                    }
                }
                if method_name is not None {
                    call_name = method_name;
                }
                if has_arguments and call_name {
                    src_qn: any = self._qualify(enclosing_func, file_path, enclosing_class)
                        if enclosing_func
                        else file_path;
                    edges.append(
                        EdgeInfo("CALLS", src_qn, call_name, file_path, parent.start_point[0] + 1)
                    );
                    call_name = None;
                }
                continue;
            }
            if sub.type not in ("return", "await", "yield", "this", "const", "new") {
                call_name = None;
            }
        }
    }

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
    ) -> bool {
        if node_type == "binary_operator" {
            handled: any = self._handle_r_binary_operator(
                child,
                source,
                language,
                file_path,
                nodes,
                edges,
                enclosing_class,
                enclosing_func,
                import_map,
                defined_names,
            );
            if handled {
                return True;
            }
        }
        if node_type == "call" {
            handled = self._handle_r_call(
                child,
                source,
                language,
                file_path,
                nodes,
                edges,
                enclosing_class,
                enclosing_func,
                import_map,
                defined_names,
            );
            if handled {
                return True;
            }
        }

        return False;
    }

    static def _julia_component_name(`node) -> Optional[str] {
        if `node.type in ("identifier", "operator") {
            return `node.text.decode("utf-8", errors="replace");
        }
        if `node.type in ("quote_expression", "parenthesized_expression") {
            for child in `node.children {
                name: any = CodeParser._julia_component_name(child);
                if name is not None {
                    return name;
                }
            }
        }
        return None;
    }

    def _julia_field_parts(field_expr) -> list[str] {
        parts: list[str] = [];
        for child in field_expr.children {
            if child.type == "field_expression" {
                parts.extend(self._julia_field_parts(child));
            } elif child.type == "identifier" {
                parts.append(child.text.decode("utf-8", errors="replace"));
            }
        }
        return parts;
    }

    def _julia_field_info(field_expr) -> tuple[Optional[str], Optional[str]] {
        child: any;
        semantic_children: any = [
            child
            for child in field_expr.children
            if child.type in ("field_expression", "identifier", "quote_expression")
        ];
        if not semantic_children {
            return (None, None);
        }
        name: any = self._julia_component_name(semantic_children[-1]);
        qualifier_parts: list[str] = [];
        for child in semantic_children[:-1] {
            if child.type == "field_expression" {
                qualifier_parts.extend(self._julia_field_parts(child));
            } elif child.type == "identifier" {
                qualifier_parts.append(child.text.decode("utf-8", errors="replace"));
            }
        }
        qualifier: any = ".".join(qualifier_parts) or None;
        return (qualifier, name);
    }

    static def _julia_scope_join(outer: Optional[str], inner: Optional[str]) -> Optional[str] {
        if not outer {
            return inner;
        }
        if not inner {
            return outer;
        }
        if inner == outer or inner.startswith(f"{outer}.") {
            return inner;
        }
        return f"{outer}.{inner}";
    }

    def _julia_signature_call(function_node) -> any {
        signature: any = next(
            (child for child in function_node.children if child.type == "signature"), None
        );
        if signature is None {
            return None;
        }
        scope: any = signature;
        for _ in range(4) {
            call: any = next(
                (child for child in scope.children if child.type == "call_expression"), None
            );
            if call is not None {
                return call;
            }
            wrapper: any = next(
                (child
                for child in scope.children
                if child.type in ("where_expression", "typed_expression")),
                None,
            );
            if wrapper is None {
                break;
            }
            scope = wrapper;
        }
        return None;
    }

    def _julia_signature_callee(function_node) -> any {
        call: any = self._julia_signature_call(function_node);
        if call is not None {
            return call.children[0] if call.children else None;
        }
        signature: any = next(
            (child for child in function_node.children if child.type == "signature"), None
        );
        if signature is None {
            return None;
        }
        return next(
            (child
            for child in signature.children
            if child.type in ("field_expression", "identifier", "operator")),
            None,
        );
    }

    def _julia_definition_qualifier(function_node) -> Optional[str] {
        callee: any = self._julia_signature_callee(function_node);
        if callee is None or callee.type != "field_expression" {
            return None;
        }
        qualifier: any;
        _: any;
        (qualifier, _) = self._julia_field_info(callee) as any;
        return qualifier;
    }

    def _julia_short_qualifier(call_expr) -> Optional[str] {
        if not call_expr.children {
            return None;
        }
        callee: any = call_expr.children[0];
        if callee.type != "field_expression" {
            return None;
        }
        qualifier: any;
        _: any;
        (qualifier, _) = self._julia_field_info(callee) as any;
        return qualifier;
    }

    def _resolve_julia_import_alias(
        alias: str,
        enclosing_class: Optional[str],
        enclosing_func: Optional[str],
        import_map: dict[str, str],
    ) -> Optional[str] {
        scope: any = self._julia_scope_join(enclosing_class, enclosing_func);
        scope_parts: any = scope.split(".") if scope else [];
        for size in range(len(scope_parts), -1, -1) {
            prefix: any = ".".join(scope_parts[:size]);
            key: any = f"{prefix}.{alias}" if prefix else alias;
            if key in import_map {
                return import_map[key];
            }
        }
        return None;
    }

    def _julia_call_is_in_signature(call_node) -> bool {
        parent: any = call_node.parent;
        while parent is not None {
            if parent.type in ("function_definition", "macro_definition") {
                return operator.eq(self._julia_signature_call(parent), call_node);
            }
            if parent.type == "source_file" {
                break;
            }
            parent = parent.parent;
        }
        return False;
    }

    def _julia_short_func_name(call_expr) -> Optional[str] {
        for child in call_expr.children {
            if child.type == "identifier" {
                return child.text.decode("utf-8", errors="replace");
            }
            if child.type == "operator" {
                return child.text.decode("utf-8", errors="replace");
            }
            if child.type == "field_expression" {
                _: any;
                name: any;
                (_, name) = self._julia_field_info(child) as any;
                return name;
            }
            if child.type == "parametrized_type_expression" {
                for ident in child.children {
                    if ident.type == "identifier" {
                        return ident.text.decode("utf-8", errors="replace");
                    }
                }
                return None;
            }
        }
        return None;
    }

    def _julia_string_arg(call_expr) -> Optional[str] {
        for child in call_expr.children {
            if child.type != "argument_list" {
                continue;
            }
            for arg in child.children {
                if arg.type == "string_literal" {
                    for sub in arg.children {
                        if sub.type == "content" {
                            return sub.text.decode("utf-8", errors="replace");
                        }
                    }
                    raw: any = arg.text.decode("utf-8", errors="replace");
                    return raw.strip("\"").strip("'");
                }
            }
        }
        return None;
    }

    def _julia_call_first_identifier(call_expr) -> Optional[str] {
        for child in call_expr.children {
            if child.type == "identifier" {
                return child.text.decode("utf-8", errors="replace");
            }
        }
        return None;
    }

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
    ) -> bool {
        sub: any;
        if node_type == "const_statement" {
            assignment: any = next(
                (sub for sub in child.children if sub.type == "assignment"), None
            );
            if assignment is not None and len(assignment.children) >= 3 {
                name_node: any = assignment.children[0];
                value_node: any = assignment.children[-1];
                if name_node.type == "identifier"
                    and value_node.type in ("parametrized_type_expression", "curly_expression")
                {
                    name: any = name_node.text.decode("utf-8", errors="replace");
                    qualified: any = self._qualify(name, file_path, enclosing_class);
                    nodes.append(
                        NodeInfo(
                            "Type",
                            name,
                            file_path,
                            child.start_point[0] + 1,
                            child.end_point[0] + 1,
                            language=language,
                            parent_name=enclosing_class,
                        ),
                    );
                    container: any = self._qualify(enclosing_class, file_path, None)
                        if enclosing_class
                        else file_path;
                    edges.append(
                        EdgeInfo(
                            "CONTAINS", container, qualified, file_path, child.start_point[0] + 1
                        ),
                    );
                    return True;
                }
            }
        }
        if node_type == "assignment" {
            lhs: any = child.children[0] if child.children else None;
            if lhs is not None and lhs.type == "typed_expression" {
                for sub in lhs.children {
                    if sub.type == "call_expression" {
                        lhs = sub;
                        break;
                    }
                }
            }
            if lhs is not None and lhs.type == "call_expression" {
                name = self._julia_short_func_name(lhs);
                if name {
                    is_test: any = _is_test_function(
                        name, file_path, (), repo_root=self._repo_root
                    );
                    kind: any = "Test" if is_test else "Function";
                    lexical_parent: any = self._julia_scope_join(enclosing_class, enclosing_func);
                    qualifier: any = self._julia_short_qualifier(lhs);
                    identity_parent: any = self._julia_scope_join(lexical_parent, qualifier);
                    qualified = self._qualify(name, file_path, identity_parent);
                    extra: any = {};
                    if qualifier {
                        extra["julia_module_qualifier"] = qualifier;
                    }
                    nodes.append(
                        NodeInfo(
                            kind,
                            name,
                            file_path,
                            child.start_point[0] + 1,
                            child.end_point[0] + 1,
                            language=language,
                            parent_name=identity_parent,
                            is_test=is_test,
                            extra=extra,
                        ),
                    );
                    container = self._qualify(lexical_parent, file_path, None)
                        if lexical_parent
                        else file_path;
                    edges.append(
                        EdgeInfo(
                            "CONTAINS", container, qualified, file_path, child.start_point[0] + 1
                        ),
                    );
                    if qualifier {
                        edges.append(
                            EdgeInfo(
                                "REFERENCES",
                                qualified,
                                qualifier,
                                file_path,
                                child.start_point[0] + 1,
                                extra={"julia_qualified_def": True},
                            ),
                        );
                    }
                    call_types: any = `set(_CALL_TYPES.get(language, []));
                    seen_op: any = False;
                    for sub in child.children {
                        if not seen_op {
                            if sub.type == "operator" {
                                seen_op = True;
                            }
                            continue;
                        }
                        if sub.type in call_types {
                            self._extract_calls(
                                sub,
                                source,
                                language,
                                file_path,
                                nodes,
                                edges,
                                identity_parent,
                                name,
                                import_map,
                                defined_names,
                                _depth + 1,
                            );
                        }
                        self._extract_from_tree(
                            sub,
                            source,
                            language,
                            file_path,
                            nodes,
                            edges,
                            enclosing_class=identity_parent,
                            enclosing_func=name,
                            import_map=import_map,
                            defined_names=defined_names,
                            _depth=_depth + 1,
                        );
                    }
                    return True;
                }
            }
        }
        if node_type == "call_expression" and self._julia_call_is_in_signature(child) {
            return True;
        }
        if node_type == "call_expression" {
            if self._julia_call_first_identifier(child) == "include" {
                path_arg: any = self._julia_string_arg(child);
                if path_arg {
                    resolved: any = self._resolve_module_to_file(path_arg, file_path, language);
                    edges.append(
                        EdgeInfo(
                            "IMPORTS_FROM",
                            file_path,
                            resolved or path_arg,
                            file_path,
                            child.start_point[0] + 1,
                        ),
                    );
                    return False;
                }
            }
        }
        if node_type in ("export_statement", "public_statement") {
            source_qual: any = self._qualify(enclosing_class, file_path, None)
                if enclosing_class
                else file_path;
            marker: any = "julia_export" if node_type == "export_statement" else "julia_public";
            for sub in child.children {
                if sub.type == "identifier" {
                    name = sub.text.decode("utf-8", errors="replace");
                    edges.append(
                        EdgeInfo(
                            "REFERENCES",
                            source_qual,
                            name,
                            file_path,
                            child.start_point[0] + 1,
                            extra={marker: True},
                        ),
                    );
                }
            }
            return True;
        }
        if node_type == "macrocall_expression" {
            macro_name: any = None;
            for sub in child.children {
                if sub.type == "macro_identifier" {
                    for ident in sub.children {
                        if ident.type == "identifier" {
                            macro_name = ident.text.decode("utf-8", errors="replace");
                            break;
                        }
                    }
                    break;
                }
            }

            if macro_name == "enum" {
                type_name: Optional[str] = None;
                variant_identifiers: list = [];
                for sub in child.children {
                    if sub.type != "macro_argument_list" {
                        continue;
                    }
                    arg: any;
                    for arg in sub.children {
                        if arg.type != "identifier" {
                            continue;
                        }
                        if type_name is None {
                            type_name = arg.text.decode("utf-8", errors="replace");
                        } else {
                            variant_identifiers.append(arg);
                        }
                    }
                    break;
                }
                if type_name {
                    line_start: any = child.start_point[0] + 1;
                    line_end: any = child.end_point[0] + 1;
                    qualified_type: any = self._qualify(type_name, file_path, enclosing_class);
                    nodes.append(
                        NodeInfo(
                            "Class",
                            type_name,
                            file_path,
                            line_start,
                            line_end,
                            language=language,
                            parent_name=enclosing_class,
                            extra={"julia_kind": "enum"},
                        ),
                    );
                    container = self._qualify(enclosing_class, file_path, None)
                        if enclosing_class
                        else file_path;
                    edges.append(
                        EdgeInfo("CONTAINS", container, qualified_type, file_path, line_start)
                    );
                    for variant in variant_identifiers {
                        vname: any = variant.text.decode("utf-8", errors="replace");
                        variant_parent: any = self._julia_scope_join(enclosing_class, type_name);
                        qualified_v: any = self._qualify(vname, file_path, variant_parent);
                        nodes.append(
                            NodeInfo(
                                "Function",
                                vname,
                                file_path,
                                variant.start_point[0] + 1,
                                variant.end_point[0] + 1,
                                language=language,
                                parent_name=variant_parent,
                                extra={"julia_kind": "enum_variant"},
                            ),
                        );
                        edges.append(
                            EdgeInfo(
                                "CONTAINS",
                                qualified_type,
                                qualified_v,
                                file_path,
                                variant.start_point[0] + 1,
                            ),
                        );
                    }
                }
                return True;
            }

            if macro_name == "testset" {
                desc: any = None;
                body_parent: any = None;
                for sub in child.children {
                    if sub.type != "macro_argument_list" {
                        continue;
                    }
                    body_parent = sub;
                    for arg in sub.children {
                        if arg.type == "string_literal" {
                            for c in arg.children {
                                if c.type == "content" {
                                    desc = c.text.decode("utf-8", errors="replace");
                                    break;
                                }
                            }
                            break;
                        }
                    }
                }
                line_no: any = child.start_point[0] + 1;
                synth_base: any = f"testset:{desc}" if desc else "testset";
                synth_name: any = f"{synth_base}@L{line_no}";
                lexical_parent = self._julia_scope_join(enclosing_class, enclosing_func);
                qualified = self._qualify(synth_name, file_path, lexical_parent);
                nodes.append(
                    NodeInfo(
                        "Test",
                        synth_name,
                        file_path,
                        child.start_point[0] + 1,
                        child.end_point[0] + 1,
                        language=language,
                        parent_name=lexical_parent,
                        is_test=True,
                    ),
                );
                container = self._qualify(lexical_parent, file_path, None)
                    if lexical_parent
                    else file_path;
                edges.append(
                    EdgeInfo("CONTAINS", container, qualified, file_path, child.start_point[0] + 1)
                );
                if body_parent is not None {
                    self._extract_from_tree(
                        body_parent,
                        source,
                        language,
                        file_path,
                        nodes,
                        edges,
                        enclosing_class=lexical_parent,
                        enclosing_func=synth_name,
                        import_map=import_map,
                        defined_names=defined_names,
                        _depth=_depth + 1,
                    );
                }
                return True;
            }
            return False;
        }

        return False;
    }

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
    ) -> bool {
        if node_type == "variable_declaration" {
            return self._handle_lua_variable_declaration(
                child,
                source,
                language,
                file_path,
                nodes,
                edges,
                enclosing_class,
                enclosing_func,
                import_map,
                defined_names,
                _depth,
            );
        }
        if node_type == "function_declaration" {
            return self._handle_lua_table_function(
                child,
                source,
                language,
                file_path,
                nodes,
                edges,
                enclosing_class,
                enclosing_func,
                import_map,
                defined_names,
                _depth,
            );
        }
        if node_type == "function_call" and not enclosing_func {
            req_target: any = self._lua_get_require_target(child);
            if req_target is not None {
                resolved: any = self._resolve_module_to_file(req_target, file_path, language);
                edges.append(
                    EdgeInfo(
                        "IMPORTS_FROM",
                        file_path,
                        resolved or req_target,
                        file_path,
                        child.start_point[0] + 1,
                    ),
                );
                return True;
            }
        }

        return False;
    }

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
    ) -> bool {
        assign: any = None;
        sub: any;
        for sub in child.children {
            if sub.type == "assignment_statement" {
                assign = sub;
                break;
            }
        }
        if not assign {
            return False;
        }
        var_name: any = None;
        for sub in assign.children {
            if sub.type == "variable_list" {
                for ident in sub.children {
                    if ident.type == "identifier" {
                        var_name = ident.text.decode("utf-8", errors="replace");
                        break;
                    }
                }
                break;
            }
        }
        expr_list: any = None;
        for sub in assign.children {
            if sub.type == "expression_list" {
                expr_list = sub;
                break;
            }
        }

        if not var_name or not expr_list {
            return False;
        }
        expr: any;
        for expr in expr_list.children {
            if expr.type == "function_call" {
                req_target: any = self._lua_get_require_target(expr);
                if req_target is not None {
                    resolved: any = self._resolve_module_to_file(req_target, file_path, language);
                    edges.append(
                        EdgeInfo(
                            "IMPORTS_FROM",
                            file_path,
                            resolved or req_target,
                            file_path,
                            child.start_point[0] + 1,
                        ),
                    );
                    return True;
                }
            }
        }
        for expr in expr_list.children {
            if expr.type == "function_definition" {
                is_test: any = _is_test_function(var_name, file_path, repo_root=self._repo_root);
                kind: any = "Test" if is_test else "Function";
                qualified: any = self._qualify(var_name, file_path, enclosing_class);
                params: any = self._get_params(expr, language, source);

                nodes.append(
                    NodeInfo(
                        kind,
                        var_name,
                        file_path,
                        child.start_point[0] + 1,
                        child.end_point[0] + 1,
                        language=language,
                        parent_name=enclosing_class,
                        params=params,
                        is_test=is_test,
                    ),
                );
                container: any = self._qualify(enclosing_class, file_path, None)
                    if enclosing_class
                    else file_path;
                edges.append(
                    EdgeInfo("CONTAINS", container, qualified, file_path, child.start_point[0] + 1)
                );
                self._extract_from_tree(
                    expr,
                    source,
                    language,
                    file_path,
                    nodes,
                    edges,
                    enclosing_class=enclosing_class,
                    enclosing_func=var_name,
                    import_map=import_map,
                    defined_names=defined_names,
                    _depth=_depth + 1,
                );
                return True;
            }
        }

        return False;
    }

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
    ) -> bool {
        table_name: any = None;
        method_name: any = None;

        for sub in child.children {
            if sub.type in ("dot_index_expression", "method_index_expression") {
                identifiers: any = [c for c in sub.children if c.type == "identifier"];
                if len(identifiers) >= 2 {
                    table_name = identifiers[0].text.decode("utf-8", errors="replace");
                    method_name = identifiers[-1].text.decode("utf-8", errors="replace");
                }
                break;
            }
        }

        if not table_name or not method_name {
            return False;
        }

        is_test: any = _is_test_function(method_name, file_path, repo_root=self._repo_root);
        kind: any = "Test" if is_test else "Function";
        qualified: any = self._qualify(method_name, file_path, table_name);
        params: any = self._get_params(child, language, source);

        nodes.append(
            NodeInfo(
                kind,
                method_name,
                file_path,
                child.start_point[0] + 1,
                child.end_point[0] + 1,
                language=language,
                parent_name=table_name,
                params=params,
                is_test=is_test,
            ),
        );
        container: any = self._qualify(table_name, file_path, None);
        edges.append(
            EdgeInfo("CONTAINS", container, qualified, file_path, child.start_point[0] + 1)
        );
        self._extract_from_tree(
            child,
            source,
            language,
            file_path,
            nodes,
            edges,
            enclosing_class=table_name,
            enclosing_func=method_name,
            import_map=import_map,
            defined_names=defined_names,
            _depth=_depth + 1,
        );
        return True;
    }

    static def _lua_get_require_target(call_node) -> Optional[str] {
        first_child: any = call_node.children[0] if call_node.children else None;
        if not first_child or first_child.type != "identifier" or first_child.text != b"require" {
            return None;
        }
        for child in call_node.children {
            if child.type == "arguments" {
                for arg in child.children {
                    if arg.type == "string" {
                        for sub in arg.children {
                            if sub.type == "string_content" {
                                return sub.text.decode("utf-8", errors="replace");
                            }
                        }
                        raw: any = arg.text.decode("utf-8", errors="replace");
                        return raw.strip("'\"");
                    }
                }
            }
        }
        return None;
    }

    static has _ZIG_CONTAINER_KINDS: any = frozenset({"struct", "union", "enum", "opaque"});

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
    ) -> bool {
        if node_type == "TestDecl" {
            return self._handle_zig_test_decl(
                child,
                source,
                language,
                file_path,
                nodes,
                edges,
                enclosing_class,
                enclosing_func,
                import_map,
                defined_names,
                _depth,
            );
        }

        if node_type != "Decl" {
            return False;
        }

        fn_proto: any = None;
        body_block: any = None;
        var_decl: any = None;
        for sub in child.children {
            t: any = sub.type;
            if t == "FnProto" and fn_proto is None {
                fn_proto = sub;
            } elif t == "Block" and fn_proto is not None and body_block is None {
                body_block = sub;
            } elif t == "VarDecl" and var_decl is None {
                var_decl = sub;
            }
        }

        if fn_proto is not None {
            return self._handle_zig_fn_decl(
                child,
                fn_proto,
                body_block,
                source,
                language,
                file_path,
                nodes,
                edges,
                enclosing_class,
                enclosing_func,
                import_map,
                defined_names,
                _depth,
            );
        }

        if var_decl is not None {
            return self._handle_zig_var_decl(
                child,
                var_decl,
                source,
                language,
                file_path,
                nodes,
                edges,
                enclosing_class,
                enclosing_func,
                import_map,
                defined_names,
                _depth,
            );
        }

        return False;
    }

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
    ) -> bool {
        name: Optional[str] = None;
        for sub in fn_proto.children {
            if sub.type == "IDENTIFIER" {
                name = sub.text.decode("utf-8", errors="replace");
                break;
            }
        }
        if not name {
            return False;
        }

        is_test: any = _is_test_function(name, file_path, repo_root=self._repo_root);
        kind: any = "Test" if is_test else "Function";
        qualified: any = self._qualify(name, file_path, enclosing_class);

        nodes.append(
            NodeInfo(
                kind,
                name,
                file_path,
                decl.start_point[0] + 1,
                decl.end_point[0] + 1,
                language=language,
                parent_name=enclosing_class,
                is_test=is_test,
            ),
        );
        container: any = self._qualify(enclosing_class, file_path, None)
            if enclosing_class
            else file_path;
        edges.append(
            EdgeInfo("CONTAINS", container, qualified, file_path, decl.start_point[0] + 1)
        );

        if body_block is not None {
            self._extract_zig_calls_in_subtree(body_block, file_path, edges, enclosing_class, name);
        }
        return True;
    }

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
    ) -> bool {
        var_name: Optional[str] = None;
        rhs_suffix: any = None;
        for sub in var_decl.children {
            t: any = sub.type;
            if t == "IDENTIFIER" and var_name is None {
                var_name = sub.text.decode("utf-8", errors="replace");
            } elif t == "ErrorUnionExpr" and rhs_suffix is None {
                inner: any;
                for inner in sub.children {
                    if inner.type == "SuffixExpr" {
                        rhs_suffix = inner;
                        break;
                    }
                }
            }
        }

        if not var_name or rhs_suffix is None {
            return False;
        }

        suffix_children: any = `list(rhs_suffix.children);
        if len(suffix_children) >= 2
            and suffix_children[0].type == "BUILTINIDENTIFIER"
            and suffix_children[0].text == b"@import"
            and suffix_children[1].type == "FnCallArguments"
        {
            target: any = self._zig_extract_import_target(suffix_children[1]);
            if target is not None {
                resolved: any = self._resolve_module_to_file(target, file_path, language);
                edges.append(
                    EdgeInfo(
                        "IMPORTS_FROM",
                        file_path,
                        resolved or target,
                        file_path,
                        decl.start_point[0] + 1,
                    ),
                );
                return True;
            }
        }
        container_decl: any = None;
        for inner in suffix_children {
            if inner.type == "ContainerDecl" {
                container_decl = inner;
                break;
            }
        }

        if container_decl is not None {
            kind_label: any = "struct";
            for cd in container_decl.children {
                if cd.type == "ContainerDeclType" {
                    for kw in cd.children {
                        txt: any = kw.text.decode("utf-8", errors="replace");
                        if txt in self._ZIG_CONTAINER_KINDS {
                            kind_label = txt;
                            break;
                        }
                    }
                    break;
                }
            }

            nodes.append(
                NodeInfo(
                    "Class",
                    var_name,
                    file_path,
                    decl.start_point[0] + 1,
                    decl.end_point[0] + 1,
                    language=language,
                    parent_name=enclosing_class,
                    extra={"zig_kind": kind_label},
                ),
            );
            edges.append(
                EdgeInfo(
                    "CONTAINS",
                    self._qualify(enclosing_class, file_path, None)
                        if enclosing_class
                        else file_path,
                    self._qualify(var_name, file_path, enclosing_class),
                    file_path,
                    decl.start_point[0] + 1,
                ),
            );
            self._extract_from_tree(
                container_decl,
                source,
                language,
                file_path,
                nodes,
                edges,
                enclosing_class=var_name,
                enclosing_func=enclosing_func,
                import_map=import_map,
                defined_names=defined_names,
                _depth=_depth + 1,
            );
            return True;
        }
        self._extract_zig_calls_in_subtree(
            rhs_suffix, file_path, edges, enclosing_class, enclosing_func
        );
        return True;
    }

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
    ) -> bool {
        label: Optional[str] = None;
        body_block: any = None;
        for sub in child.children {
            if sub.type == "STRINGLITERALSINGLE" {
                raw: any = sub.text.decode("utf-8", errors="replace");
                stripped: any = raw.strip().strip("\"").strip("'");
                if stripped {
                    label = stripped;
                }
            } elif sub.type == "Block" {
                body_block = sub;
            }
        }

        line_no: any = child.start_point[0] + 1;
        base: any = f"test:{label}" if label else "test";
        synthetic: any = f"{base}@L{line_no}";
        qualified: any = self._qualify(synthetic, file_path, enclosing_class);

        nodes.append(
            NodeInfo(
                "Test",
                synthetic,
                file_path,
                child.start_point[0] + 1,
                child.end_point[0] + 1,
                language=language,
                parent_name=enclosing_class,
                is_test=True,
            ),
        );
        edges.append(
            EdgeInfo(
                "CONTAINS",
                self._qualify(enclosing_class, file_path, None) if enclosing_class else file_path,
                qualified,
                file_path,
                line_no,
            ),
        );

        if body_block is not None {
            self._extract_zig_calls_in_subtree(
                body_block, file_path, edges, enclosing_class, synthetic
            );
        }
        return True;
    }

    static def _zig_extract_import_target(args_node) -> Optional[str] {
        for arg in args_node.children {
            if arg.type != "ErrorUnionExpr" {
                continue;
            }
            for sub in arg.children {
                if sub.type != "SuffixExpr" {
                    continue;
                }
                for s in sub.children {
                    if s.type == "STRINGLITERALSINGLE" {
                        raw: any = s.text.decode("utf-8", errors="replace");
                        return raw.strip().strip("\"").strip("'");
                    }
                }
            }
        }
        return None;
    }

    def _extract_zig_calls_in_subtree(
        `root,
        file_path: str,
        edges: list[EdgeInfo],
        enclosing_class: Optional[str],
        enclosing_func: Optional[str],
    ) {
        src_qn: any = self._qualify(enclosing_func, file_path, enclosing_class)
            if enclosing_func
            else file_path;
        stack: any = [`root];
        while stack {
            `node: any = stack.pop();
            if `node.type in ("SuffixExpr", "FieldOrFnCall") {
                children: any = `node.children;
                ch: any;
                for (i, ch) in enumerate(children) {
                    if ch.type != "FnCallArguments" or i == 0 {
                        continue;
                    }
                    prev: any = children[i - 1];
                    callee: Optional[str] = None;
                    if prev.type == "IDENTIFIER" {
                        callee = prev.text.decode("utf-8", errors="replace");
                    } elif prev.type == "BUILTINIDENTIFIER" {
                        txt: any = prev.text.decode("utf-8", errors="replace");
                        if txt != "@import" {
                            callee = txt;
                        }
                    }
                    if callee {
                        edges.append(
                            EdgeInfo("CALLS", src_qn, callee, file_path, `node.start_point[0] + 1)
                        );
                    }
                    break;
                }
            }
            for ch in `node.children {
                stack.append(ch);
            }
        }
    }

    static has _JS_FUNC_VALUE_TYPES: any = frozenset({
        "arrow_function",
        "function_expression",
        "function",
        "generator_function",
    });

    static has _JS_WRAPPER_MAX_DEPTH: any = 3;

    static has _JS_COMPONENT_WRAPPERS: any = frozenset(
        ("forwardRef memo observer withRouter withStyles withTheme connect styled inject "
            "withTranslation withErrorBoundary").split(),
    );

    static has _JS_CURRIED_WRAPPERS: any = frozenset({
        "connect",
        "withStyles",
        "inject",
        "withTranslation",
        "styled",
    });

    static has _JS_COMMENT_TYPES: any = frozenset({"comment", "html_comment"});

    def _js_argument_values(arguments) -> list {
        return [arg for arg in arguments.named_children if arg.type not in self._JS_COMMENT_TYPES];
    }

    def _js_wrapper_name(call_node, _depth: int = 0) -> Optional[str] {
        callee: any = call_node.children[0] if call_node.children else None;
        if callee is None {
            return None;
        }
        if callee.type == "call_expression" {
            if _depth >= self._JS_WRAPPER_MAX_DEPTH {
                return None;
            }
            return self._js_wrapper_name(callee, _depth + 1);
        }
        if callee.type == "identifier" {
            return callee.text.decode("utf-8", errors="replace");
        }
        if callee.type == "member_expression" {
            `obj: any = callee.child_by_field_name("object");
            prop: any = callee.child_by_field_name("property");
            if `obj is None or prop is None or `obj.type != "identifier" or `obj.text != b"React" {
                return None;
            }
            return prop.text.decode("utf-8", errors="replace");
        }
        return None;
    }

    def _js_wrapped_function(call_node, _depth: int = 0, chain=None) -> any {
        name: any = self._js_wrapper_name(call_node);
        if name is None or name not in self._JS_COMPONENT_WRAPPERS {
            return None;
        }
        callee: any = call_node.children[0] if call_node.children else None;
        curried: any = name in self._JS_CURRIED_WRAPPERS;
        if curried and (callee is None or callee.type != "call_expression") {
            return None;
        }
        arguments: any = None;
        for sub in call_node.children {
            if sub.type == "arguments" {
                arguments = sub;
                break;
            }
        }
        if arguments is None {
            return None;
        }
        args: any = self._js_argument_values(arguments);
        if len(args) != 1 and not (name == "memo" and len(args) == 2) {
            return None;
        }
        arg: any = args[0];
        if arg.type in self._JS_FUNC_VALUE_TYPES and arg.type != "generator_function" {
            if chain is not None {
                chain.append(call_node);
            }
            return arg;
        }
        if arg.type == "call_expression" and _depth < self._JS_WRAPPER_MAX_DEPTH {
            inner: any = self._js_wrapped_function(arg, _depth + 1, chain);
            if inner is not None and chain is not None {
                chain.append(call_node);
            }
            return inner;
        }
        return None;
    }

    def _js_in_test_body(
        nodes: list[NodeInfo],
        file_path: str,
        enclosing_class: Optional[str],
        enclosing_func: Optional[str],
    ) -> bool {
        if not enclosing_func {
            return False;
        }
        qualified: any = self._qualify(enclosing_func, file_path, enclosing_class);
        return `any(
            `node.is_test and operator.eq(self._node_qualified(`node), qualified)
            for `node in reversed(nodes),
        );
    }

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
    ) -> bool {
        handled: any = False;
        unowned: any = [];
        declarator: any;
        for declarator in child.children {
            if declarator.type != "variable_declarator" {
                continue;
            }
            var_name: any = None;
            func_node: any = None;
            walk_node: any = None;
            wrapper_calls: any = [];
            for sub in declarator.children {
                if sub.type == "identifier" and var_name is None {
                    var_name = sub.text.decode("utf-8", errors="replace");
                } elif sub.type in self._JS_FUNC_VALUE_TYPES {
                    func_node = sub;
                    walk_node = sub;
                } elif sub.type == "call_expression" {
                    chain: list = [];
                    wrapped: any = self._js_wrapped_function(sub, chain=chain);
                    if wrapped is not None
                        and not self._js_in_test_body(
                            nodes, file_path, enclosing_class, enclosing_func
                        )
                    {
                        func_node = wrapped;
                        walk_node = wrapped;
                        wrapper_calls = chain;
                    }
                }
            }

            if not var_name or not func_node {
                unowned.append(declarator);
                continue;
            }

            is_test: any = _is_test_function(var_name, file_path, repo_root=self._repo_root);
            kind: any = "Test" if is_test else "Function";
            qualified: any = self._qualify(var_name, file_path, enclosing_class);
            params: any = self._get_params(func_node, language, source);
            ret_type: any = self._get_return_type(func_node, language, source);

            nodes.append(
                NodeInfo(
                    kind,
                    var_name,
                    file_path,
                    child.start_point[0] + 1,
                    child.end_point[0] + 1,
                    language=language,
                    parent_name=enclosing_class,
                    params=params,
                    return_type=ret_type,
                    is_test=is_test,
                ),
            );
            container: any = self._qualify(enclosing_class, file_path, None)
                if enclosing_class
                else file_path;
            edges.append(
                EdgeInfo("CONTAINS", container, qualified, file_path, child.start_point[0] + 1)
            );
            self._extract_from_tree(
                walk_node or func_node,
                source,
                language,
                file_path,
                nodes,
                edges,
                enclosing_class=enclosing_class,
                enclosing_func=var_name,
                import_map=import_map,
                defined_names=defined_names,
                _depth=_depth + 1,
            );
            rest: list = [];
            if wrapper_calls {
                rest = [sub for sub in declarator.children if sub.type == "type_annotation"];
            }
            for wrapper_call in wrapper_calls {
                self._extract_calls(
                    wrapper_call,
                    source,
                    language,
                    file_path,
                    nodes,
                    edges,
                    enclosing_class,
                    enclosing_func,
                    import_map,
                    defined_names,
                    _depth + 1,
                );
                arguments: any = wrapper_call.child_by_field_name("arguments");
                self._extract_value_references(
                    arguments,
                    arguments.type,
                    source,
                    language,
                    file_path,
                    edges,
                    enclosing_class,
                    enclosing_func,
                    import_map,
                    defined_names,
                );
                rest.extend(part for part in wrapper_call.children if part.type != "arguments");
                rest.extend(self._js_argument_values(arguments)[1:]);
            }
            if rest {
                self._extract_from_tree(
                    _NodeGroup(rest),
                    source,
                    language,
                    file_path,
                    nodes,
                    edges,
                    enclosing_class=enclosing_class,
                    enclosing_func=enclosing_func,
                    import_map=import_map,
                    defined_names=defined_names,
                    _depth=_depth + 1,
                );
            }
            handled = True;
        }

        if not handled {
            return False;
        }
        for declarator in unowned {
            self._extract_from_tree(
                declarator,
                source,
                language,
                file_path,
                nodes,
                edges,
                enclosing_class=enclosing_class,
                enclosing_func=enclosing_func,
                import_map=import_map,
                defined_names=defined_names,
                _depth=_depth + 1,
            );
        }
        return True;
    }

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
    ) -> bool {
        prop_name: any = None;
        func_node: any = None;
        for sub in child.children {
            if sub.type == "property_identifier" and prop_name is None {
                prop_name = sub.text.decode("utf-8", errors="replace");
            } elif sub.type in self._JS_FUNC_VALUE_TYPES {
                func_node = sub;
            }
        }

        if not prop_name or not func_node {
            return False;
        }

        is_test: any = _is_test_function(prop_name, file_path, repo_root=self._repo_root);
        kind: any = "Test" if is_test else "Function";
        qualified: any = self._qualify(prop_name, file_path, enclosing_class);
        params: any = self._get_params(func_node, language, source);

        nodes.append(
            NodeInfo(
                kind,
                prop_name,
                file_path,
                child.start_point[0] + 1,
                child.end_point[0] + 1,
                language=language,
                parent_name=enclosing_class,
                params=params,
                is_test=is_test,
            ),
        );
        container: any = self._qualify(enclosing_class, file_path, None)
            if enclosing_class
            else file_path;
        edges.append(
            EdgeInfo("CONTAINS", container, qualified, file_path, child.start_point[0] + 1)
        );

        self._extract_from_tree(
            func_node,
            source,
            language,
            file_path,
            nodes,
            edges,
            enclosing_class=enclosing_class,
            enclosing_func=prop_name,
            import_map=import_map,
            defined_names=defined_names,
            _depth=_depth + 1,
        );
        return True;
    }

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
    ) -> bool {
        assign: any = None;
        if child.type == "assignment_expression" {
            assign = child;
        } else {
            for sub in child.children {
                if sub.type == "assignment_expression" {
                    assign = sub;
                    break;
                }
            }
        }
        if assign is None {
            return False;
        }

        left: any = assign.child_by_field_name("left");
        right: any = assign.child_by_field_name("right");
        if left is None or right is None {
            return False;
        }
        if left.type != "member_expression" {
            return False;
        }
        if right.type not in self._JS_FUNC_VALUE_TYPES {
            return False;
        }
        if enclosing_func or child.parent is None or child.parent.type != "program" {
            return False;
        }

        member_name: any = self._get_js_static_member_path(left);
        if member_name is None {
            return False;
        }

        is_test: any = _is_test_function(member_name, file_path, repo_root=self._repo_root);
        kind: any = "Test" if is_test else "Function";
        qualified: any = self._qualify(member_name, file_path, enclosing_class);
        params: any = self._get_params(right, language, source);
        ret_type: any = self._get_return_type(right, language, source);

        nodes.append(
            NodeInfo(
                kind,
                member_name,
                file_path,
                child.start_point[0] + 1,
                child.end_point[0] + 1,
                language=language,
                parent_name=enclosing_class,
                params=params,
                return_type=ret_type,
                is_test=is_test,
            ),
        );
        container: any = self._qualify(enclosing_class, file_path, None)
            if enclosing_class
            else file_path;
        edges.append(
            EdgeInfo("CONTAINS", container, qualified, file_path, child.start_point[0] + 1)
        );
        self._extract_from_tree(
            right,
            source,
            language,
            file_path,
            nodes,
            edges,
            enclosing_class=enclosing_class,
            enclosing_func=member_name,
            import_map=import_map,
            defined_names=defined_names,
            _depth=_depth + 1,
        );
        return True;
    }

    static def _get_js_static_member_path(`node) -> Optional[str] {
        if `node.type != "member_expression" {
            return None;
        }
        text: any = `node.text.decode("utf-8", errors="replace");
        if not text or "[" in text or "\n" in text {
            return None;
        }

        parts: list[str] = [];
        current: any = `node;
        while current.type == "member_expression" {
            object_node: any = current.child_by_field_name("object");
            property_node: any = current.child_by_field_name("property");
            if object_node is None
                or property_node is None
                or property_node.type not in ("identifier", "property_identifier")
            {
                return None;
            }
            parts.append(property_node.text.decode("utf-8", errors="replace"));
            current = object_node;
        }

        if current.type not in ("identifier", "this") {
            return None;
        }
        parts.append(current.text.decode("utf-8", errors="replace"));
        return ".".join(reversed(parts));
    }

    static def _get_java_annotations(class_node) -> list[str] {
        names: list[str] = [];
        for child in class_node.children {
            if child.type != "modifiers" {
                continue;
            }
            for mod in child.children {
                if mod.type in ("marker_annotation", "annotation") {
                    for sub in mod.children {
                        if sub.type == "identifier" {
                            names.append(sub.text.decode("utf-8", errors="replace"));
                            break;
                        }
                    }
                }
            }
        }
        return names;
    }

    static def _spring_config_annotation_name(annotation_node) -> Optional[str] {
        for child in annotation_node.children {
            if child.type == "identifier" {
                return child.text.decode("utf-8", errors="replace");
            }
            if child.type in ("scoped_identifier", "qualified_name") {
                return child.text.decode("utf-8", errors="replace").rsplit(".", 1)[-1];
            }
        }
        return None;
    }

    static def _spring_config_string_literals(`node) -> list[str] {
        values: list[str] = [];
        if `node.type == "string_literal" {
            text: any = `node.text.decode("utf-8", errors="replace");
            if len(text) >= 2 {
                values.append(text[1:-1]);
            }
            return values;
        }
        for child in `node.children {
            values.extend(CodeParser._spring_config_string_literals(child));
        }
        return values;
    }

    def _spring_config_annotation_values(
        annotation_node, accepted_keys: frozenset[str]
    ) -> list[str] {
        values: list[str] = [];
        for child in annotation_node.children {
            if child.type != "annotation_argument_list" {
                continue;
            }
            for argument in child.children {
                if argument.type == "element_value_pair" {
                    named: any = [part for part in argument.children if part.is_named];
                    if len(named) < 2 {
                        continue;
                    }
                    key: any = named[0].text.decode("utf-8", errors="replace");
                    if key in accepted_keys {
                        values.extend(self._spring_config_string_literals(named[-1]));
                    }
                } elif argument.is_named and "value" in accepted_keys {
                    values.extend(self._spring_config_string_literals(argument));
                }
            }
        }
        return values;
    }

    def _emit_spring_config_edges(
        class_node,
        class_name: str,
        enclosing_class: Optional[str],
        file_path: str,
        edges: list[EdgeInfo],
    ) {
        source: any = self._qualify(class_name, file_path, enclosing_class);

        child: any;
        for child in class_node.children {
            if child.type != "modifiers" {
                continue;
            }
            annotation: any;
            for annotation in child.children {
                if self._spring_config_annotation_name(annotation) != "ConfigurationProperties" {
                    continue;
                }
                prefixes: any = self._spring_config_annotation_values(
                    annotation, frozenset({"prefix", "value"})
                );
                for prefix in prefixes {
                    key: any = normalize_spring_config_key(prefix);
                    if not key {
                        continue;
                    }
                    edges.append(
                        EdgeInfo(
                            "DEPENDS_ON_CONFIG",
                            source,
                            f"config:{key}.*",
                            file_path,
                            annotation.start_point[0] + 1,
                            extra={"config_key": key, "resolution": "configuration_properties"},
                        ),
                    );
                }
            }
        }

        for child in class_node.children {
            if child.type != "class_body" {
                continue;
            }
            for member in child.children {
                if member.type != "field_declaration" {
                    continue;
                }
                for modifiers in member.children {
                    if modifiers.type != "modifiers" {
                        continue;
                    }
                    for annotation in modifiers.children {
                        if self._spring_config_annotation_name(annotation) != "Value" {
                            continue;
                        }
                        expressions: any = self._spring_config_annotation_values(
                            annotation, frozenset({"value"})
                        );
                        for expression in expressions {
                            for `match in _SPRING_PLACEHOLDER_RE.finditer(expression) {
                                raw_key: any = `match.group(1).split(":", 1)[0].strip();
                                key = normalize_spring_config_key(raw_key);
                                if not key {
                                    continue;
                                }
                                edges.append(
                                    EdgeInfo(
                                        "DEPENDS_ON_CONFIG",
                                        source,
                                        f"config:{key}",
                                        file_path,
                                        annotation.start_point[0] + 1,
                                        extra={"config_key": key, "resolution": "value_annotation"},
                                    ),
                                );
                            }
                        }
                    }
                }
            }
        }
    }

    def _emit_spring_injections(
        class_node,
        class_name: str,
        class_annotations: list[str],
        language: str,
        file_path: str,
        edges: list[EdgeInfo],
        import_map: Optional[dict[str, str]] = None,
    ) {
        if language != "java" {
            return;
        }

        has_required_args: any = "RequiredArgsConstructor" in class_annotations;
        has_all_args: any = "AllArgsConstructor" in class_annotations;
        qualified_source: any = self._qualify(class_name, file_path, None);
        for `node in class_node.children {
            if `node.type != "class_body" {
                continue;
            }
            for member in `node.children {
                if member.type == "field_declaration" {
                    self._emit_spring_field_injection(
                        member,
                        qualified_source,
                        file_path,
                        edges,
                        has_required_args,
                        has_all_args,
                        import_map,
                    );
                } elif member.type == "constructor_declaration" {
                    self._emit_spring_constructor_injection(
                        member, qualified_source, file_path, edges, import_map
                    );
                }
            }
        }
    }

    def _emit_spring_field_injection(
        field_node,
        qualified_source: str,
        file_path: str,
        edges: list[EdgeInfo],
        has_required_args: bool,
        has_all_args: bool,
        import_map: Optional[dict[str, str]],
    ) {
        field_annotations: list[str] = [];
        has_final: any = False;
        has_static: any = False;
        field_type: Optional[str] = None;
        declarators: list[tuple[str, bool]] = [];

        for child in field_node.children {
            if child.type == "modifiers" {
                for mod in child.children {
                    text: any = mod.text.decode("utf-8", errors="replace");
                    if text == "final" {
                        has_final = True;
                    } elif text == "static" {
                        has_static = True;
                    } elif mod.type in ("marker_annotation", "annotation") {
                        sub: any;
                        for sub in mod.children {
                            if sub.type == "identifier" {
                                field_annotations.append(
                                    sub.text.decode("utf-8", errors="replace")
                                );
                                break;
                            }
                        }
                    }
                }
            } elif child.type in ("type_identifier", "generic_type", "array_type") {
                if child.type == "type_identifier" {
                    field_type = child.text.decode("utf-8", errors="replace");
                } elif child.type == "generic_type" {
                    for sub in child.children {
                        if sub.type == "type_identifier" {
                            field_type = sub.text.decode("utf-8", errors="replace");
                            break;
                        }
                    }
                } elif child.type == "array_type" {
                    for sub in child.children {
                        if sub.type == "type_identifier" {
                            field_type = sub.text.decode("utf-8", errors="replace");
                            break;
                        }
                    }
                }
            } elif child.type == "variable_declarator" {
                field_name: Optional[str] = None;
                for sub in child.children {
                    if sub.type == "identifier" {
                        field_name = sub.text.decode("utf-8", errors="replace");
                        break;
                    }
                }
                if field_name {
                    has_initializer: any = child.child_by_field_name("value") is not None;
                    declarators.append((field_name, has_initializer));
                }
            }
        }

        if not field_type or has_static or not declarators {
            return;
        }

        has_inject_annotation: any = `any(
            a in _SPRING_INJECT_ANNOTATIONS for a in field_annotations
        );
        has_non_null: any = "NonNull" in field_annotations;

        for (field_name, has_initializer) in declarators {
            if has_inject_annotation {
                injection_type: any = "field";
            } elif has_all_args {
                injection_type = "constructor_lombok_all";
            } elif has_required_args and not has_initializer and (has_final or has_non_null) {
                injection_type = "constructor_lombok";
            } else {
                continue;
            }

            extra: any = {"injection_type": injection_type, "field_name": field_name};
            if import_map is not None {
                extra["java_type"] = self._spring_java_type(field_type, import_map);
            }
            edges.append(
                EdgeInfo(
                    "INJECTS",
                    qualified_source,
                    field_type,
                    file_path,
                    field_node.start_point[0] + 1,
                    extra=extra,
                ),
            );
        }
    }

    def _emit_spring_constructor_injection(
        ctor_node,
        qualified_source: str,
        file_path: str,
        edges: list[EdgeInfo],
        import_map: Optional[dict[str, str]],
    ) {
        ctor_annotations: any = self._get_java_annotations(ctor_node);
        if not `any(a in _SPRING_INJECT_ANNOTATIONS for a in ctor_annotations) {
            return;
        }

        for child in ctor_node.children {
            if child.type != "formal_parameters" {
                continue;
            }
            for param in child.children {
                if param.type != "formal_parameter" {
                    continue;
                }
                param_type: Optional[str] = None;
                param_name: Optional[str] = None;
                for sub in param.children {
                    if sub.type == "type_identifier" and param_type is None {
                        param_type = sub.text.decode("utf-8", errors="replace");
                    } elif sub.type == "identifier" {
                        param_name = sub.text.decode("utf-8", errors="replace");
                    }
                }
                if param_type {
                    extra: dict = {"injection_type": "constructor"};
                    if param_name {
                        extra["field_name"] = param_name;
                    }
                    if import_map is not None {
                        extra["java_type"] = self._spring_java_type(param_type, import_map);
                    }
                    edges.append(
                        EdgeInfo(
                            "INJECTS",
                            qualified_source,
                            param_type,
                            file_path,
                            param.start_point[0] + 1,
                            extra=extra,
                        ),
                    );
                }
            }
        }
    }

    static def _java_annotation_name(annotation_node) -> Optional[str] {
        for child in annotation_node.children {
            if child.type == "identifier" {
                return child.text.decode("utf-8", errors="replace");
            }
            if child.type in ("scoped_identifier", "qualified_name") {
                return child.text.decode("utf-8", errors="replace").rsplit(".", 1)[-1];
            }
        }
        return None;
    }

    def _scheduled_annotations(method_node) -> list {
        found: list;
        found = [];

        def `visit(`node) {
            if `node.type == "annotation" {
                name: any = self._java_annotation_name(`node);
                if name == "Scheduled" {
                    found.append(`node);
                    return;
                }
                if name != "Schedules" {
                    return;
                }
            }
            for child in `node.children {
                `visit(child);
            }
        }

        for child in method_node.children {
            if child.type == "modifiers" {
                `visit(child);
            }
        }
        return found;
    }

    static def _java_annotation_attributes(annotation_node) -> dict[str, str] {
        attributes: dict[str, str] = {};
        for child in annotation_node.children {
            if child.type != "annotation_argument_list" {
                continue;
            }
            for pair in child.children {
                if pair.type != "element_value_pair" {
                    continue;
                }
                named: any = [part for part in pair.children if part.is_named];
                if len(named) < 2 or named[0].type != "identifier" {
                    continue;
                }
                key: any = named[0].text.decode("utf-8", errors="replace");
                value_node: any = named[-1];
                value: any = value_node.text.decode("utf-8", errors="replace");
                if value_node.type == "string_literal" and len(value) >= 2 {
                    value = value[1:-1];
                }
                attributes[key] = value;
            }
        }
        return attributes;
    }

    static def _java_string_literal_values(`node) -> list[str] {
        values: list[str] = [];
        if `node.type == "string_literal" {
            value: any = `node.text.decode("utf-8", errors="replace");
            if len(value) >= 2 {
                values.append(value[1:-1]);
            }
            return values;
        }
        for child in `node.children {
            values.extend(CodeParser._java_string_literal_values(child));
        }
        return values;
    }

    def _spring_mapping_paths(annotation_node) -> list[str] {
        paths: list[str] = [];
        for child in annotation_node.children {
            if child.type != "annotation_argument_list" {
                continue;
            }
            for argument in child.children {
                if argument.type == "element_value_pair" {
                    named: any = [part for part in argument.children if part.is_named];
                    if len(named) < 2 {
                        continue;
                    }
                    key: any = named[0].text.decode("utf-8", errors="replace");
                    if key not in ("path", "value") {
                        continue;
                    }
                    paths.extend(self._java_string_literal_values(named[-1]));
                } elif argument.is_named {
                    paths.extend(self._java_string_literal_values(argument));
                }
            }
        }
        return paths or [""];
    }

    def _spring_mapping_methods(annotation_node, name: str) -> list[str] {
        composed: any = _SPRING_REQUEST_MAPPINGS[name];
        if composed {
            return `list(composed);
        }

        methods: list[str] = [];
        for child in annotation_node.children {
            if child.type != "annotation_argument_list" {
                continue;
            }
            for argument in child.children {
                if argument.type != "element_value_pair" {
                    continue;
                }
                named: any = [part for part in argument.children if part.is_named];
                if len(named) < 2 {
                    continue;
                }
                key: any = named[0].text.decode("utf-8", errors="replace");
                if key != "method" {
                    continue;
                }
                value_node: any = named[-1];
                for value in self._descendants_of_type(value_node, "identifier") {
                    method: any = value.text.decode("utf-8", errors="replace");
                    if method in _HTTP_REQUEST_METHODS and method not in methods {
                        methods.append(method);
                    }
                }
            }
        }
        return methods or ["ANY"];
    }

    static def _join_spring_route(prefix: str, path: str) -> str {
        parts: any = [part.strip("/") for part in (prefix, path) if part.strip("/")];
        return "/" + "/".join(parts) if parts else "/";
    }

    def _emit_spring_endpoint_nodes(
        method_node,
        method_name: str,
        class_name: Optional[str],
        file_path: str,
        import_map: dict[str, str],
        nodes: list[NodeInfo],
        edges: list[EdgeInfo],
    ) -> int {
        prefix: any;
        annotations: any = self._java_annotations_named(
            method_node, frozenset(_SPRING_REQUEST_MAPPINGS)
        );
        if not annotations {
            return 0;
        }

        prefixes: any = [""];
        encoded_prefixes: any = import_map.get(f"{_SPRING_REQUEST_PREFIX_KEY}{class_name or ""}");
        if encoded_prefixes {
            try {
                parsed_prefixes: any = json.loads(encoded_prefixes);
            } except (TypeError, ValueError) {
                parsed_prefixes = None;
            }
            if isinstance(parsed_prefixes, `list)
                and all(isinstance(prefix, `str) for prefix in parsed_prefixes)
            {
                prefixes = parsed_prefixes or [""];
            }
        }

        source: any = self._qualify(method_name, file_path, class_name);
        emitted: any = 0;
        for (annotation_index, annotation) in enumerate(annotations) {
            annotation_name: any = self._java_annotation_name(annotation);
            if annotation_name is None {
                continue;
            }
            paths: any = self._spring_mapping_paths(annotation);
            methods: any = self._spring_mapping_methods(annotation, annotation_name);
            for prefix in prefixes {
                for path in paths {
                    route: any = self._join_spring_route(prefix, path);
                    for method in methods {
                        endpoint_name: any = f"{method_name}@{annotation_name}[{annotation_index}:{emitted}] {method} {route}";
                        metadata: any = {
                            "annotation": annotation_name,
                            "handler": method_name,
                            "http_method": method,
                            "route": route,
                        };
                        nodes.append(
                            NodeInfo(
                                "Endpoint",
                                endpoint_name,
                                file_path,
                                annotation.start_point[0] + 1,
                                annotation.end_point[0] + 1,
                                language="java",
                                parent_name=class_name,
                                extra=metadata,
                            ),
                        );
                        edges.append(
                            EdgeInfo(
                                "HANDLES",
                                source,
                                self._qualify(endpoint_name, file_path, class_name),
                                file_path,
                                annotation.start_point[0] + 1,
                                extra=metadata,
                            ),
                        );
                        emitted += 1;
                    }
                }
            }
        }
        return emitted;
    }

    def _java_invocation_chain_has_route(invocation) -> bool {
        current: any = invocation;
        _: any;
        for _ in range(32) {
            if current.type != "method_invocation" {
                return False;
            }
            method: any;
            (method, _) = self._get_java_method_and_receiver(current) as any;
            if method == "route" {
                return True;
            }
            current = next(
                (child for child in current.children if child.type == "method_invocation"), None
            );
            if current is None {
                return False;
            }
        }
        return False;
    }

    static def _webflux_route_arguments(invocation) -> tuple[Optional[str], Optional[object]] {
        arguments: any = next(
            (child for child in invocation.children if child.type == "argument_list"), None
        );
        if arguments is None {
            return (None, None);
        }
        named: any = [child for child in arguments.children if child.is_named];
        if len(named) < 2 or named[0].type != "string_literal" {
            return (None, None);
        }
        route_literal: any = named[0].text.decode("utf-8", errors="replace");
        if len(route_literal) < 2 {
            return (None, None);
        }
        route: any = route_literal[1:-1];
        if not route.startswith("/") {
            return (None, None);
        }
        handler: any = next(
            (child for child in named[1:] if child.type == "method_reference"), None
        );
        return (route, handler);
    }

    def _resolve_java_method_reference_target(
        reference,
        file_path: str,
        enclosing_class: Optional[str],
        import_map: dict[str, str],
        defined_names: set[str],
    ) -> Optional[str] {
        receiver: any;
        method: any;
        (receiver, method) = self._get_member_call_receiver_method(reference, "java") as any;
        if not receiver or not method {
            return None;
        }
        if receiver == "this" and enclosing_class {
            return self._qualify(method, file_path, enclosing_class);
        }

        function_types: any = `set(self._function_types.get("java", []));
        class_types: any = `set(self._class_types.get("java", []));
        bindings: dict[str, str] = {};
        function_node: any = None;
        class_node: any = None;
        ancestor: any = reference.parent;
        while ancestor is not None {
            if function_node is None and ancestor.type in function_types {
                function_node = ancestor;
            }
            if ancestor.type in class_types {
                class_node = ancestor;
                break;
            }
            ancestor = ancestor.parent;
        }
        if function_node is not None {
            bindings.update(self._collect_function_typed_parameters(function_node, "java"));
        }
        if class_node is not None {
            bindings.update(
                self._collect_class_typed_fields(class_node, "java", function_types, class_types)
            );
        }

        type_name: any = bindings.get(receiver);
        if type_name is None and receiver[:1].isupper() {
            if receiver in import_map or receiver in defined_names {
                type_name = receiver;
            }
        }
        if type_name is None {
            return None;
        }
        return self._resolve_typed_method_target(
            type_name, method, file_path, "java", import_map, defined_names
        );
    }

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
    ) -> bool {
        if method not in _SPRING_WEBFLUX_HTTP_VERBS
            or b"org.springframework.web.reactive.function.server" not in source
            or not self._java_invocation_chain_has_route(invocation)
        {
            return False;
        }

        ancestor: any = invocation.parent;
        while ancestor is not None and ancestor.type not in self._function_types.get("java", []) {
            if ancestor.type == "lambda_expression" {
                return False;
            }
            ancestor = ancestor.parent;
        }

        route: any;
        handler_reference: any;
        (route, handler_reference) = self._webflux_route_arguments(invocation) as any;
        if route is None or handler_reference is None {
            return False;
        }
        handler_target: any = self._resolve_java_method_reference_target(
            handler_reference, file_path, enclosing_class, import_map, defined_names
        );
        if handler_target is None {
            return False;
        }
        _: any;
        handler_method: any;
        (_, handler_method) = self._get_member_call_receiver_method(
            handler_reference, "java"
        ) as any;
        if handler_method is None {
            return False;
        }

        line: any = invocation.start_point[0] + 1;
        endpoint_name: any = f"{handler_method}@WebFlux[{line}] {method} {route}";
        endpoint_target: any = self._qualify(endpoint_name, file_path, enclosing_class);
        metadata: any = {
            "handler": handler_method,
            "handler_qualified": handler_target,
            "http_method": method,
            "mapping_style": "webflux_functional",
            "route": route,
        };
        nodes.append(
            NodeInfo(
                "Endpoint",
                endpoint_name,
                file_path,
                line,
                invocation.end_point[0] + 1,
                language="java",
                parent_name=enclosing_class,
                extra=metadata,
            ),
        );
        edges.append(
            EdgeInfo("HANDLES", handler_target, endpoint_target, file_path, line, extra=metadata)
        );
        return True;
    }

    static def _spring_schedule_kind(attributes: dict[str, str]) -> str {
        for (key, kind) in (
            ("cron", "cron"),
            ("fixedRate", "fixedRate"),
            ("fixedRateString", "fixedRate"),
            ("fixedDelay", "fixedDelay"),
            ("fixedDelayString", "fixedDelay"),
            ("initialDelay", "initialDelay"),
            ("initialDelayString", "initialDelay"),
        ) {
            if key in attributes {
                return kind;
            }
        }
        return "scheduled";
    }

    def _emit_scheduled_nodes_from_method(
        method_node,
        method_name: str,
        class_name: Optional[str],
        file_path: str,
        nodes: list[NodeInfo],
        edges: list[EdgeInfo],
    ) -> int {
        annotations: any = self._scheduled_annotations(method_node);
        target: any = self._qualify(method_name, file_path, class_name);
        for (index, annotation) in enumerate(annotations) {
            attributes: any = self._java_annotation_attributes(annotation);
            schedule_kind: any = self._spring_schedule_kind(attributes);
            schedule_name: any = f"{method_name}@Scheduled[{index}]:{schedule_kind}";
            metadata: any = {
                "annotation": "Scheduled",
                "schedule_kind": schedule_kind,
                **attributes,
            };
            nodes.append(
                NodeInfo(
                    "Scheduler",
                    schedule_name,
                    file_path,
                    annotation.start_point[0] + 1,
                    annotation.end_point[0] + 1,
                    language="java",
                    parent_name=class_name,
                    extra=metadata,
                ),
            );
            edges.append(
                EdgeInfo(
                    "TRIGGERS",
                    self._qualify(schedule_name, file_path, class_name),
                    target,
                    file_path,
                    annotation.start_point[0] + 1,
                    extra=metadata,
                ),
            );
        }
        return len(annotations);
    }

    def _java_annotations_named(method_node, names: frozenset[str]) -> list {
        matches: list = [];
        for child in method_node.children {
            if child.type != "modifiers" {
                continue;
            }
            for annotation in child.children {
                if annotation.type not in ("annotation", "marker_annotation") {
                    continue;
                }
                if self._java_annotation_name(annotation) in names {
                    matches.append(annotation);
                }
            }
        }
        return matches;
    }

    static def _java_type_name(`node) -> Optional[str] {
        if `node.type in ("type_identifier", "scoped_type_identifier") {
            return `node.text.decode("utf-8", errors="replace");
        }
        for child in `node.children {
            found: any = CodeParser._java_type_name(child);
            if found {
                return found;
            }
        }
        return None;
    }

    class def _spring_java_type(type_name: str, import_map: dict[str, str]) -> str {
        head: any = type_name.strip().partition(".")[0];
        if import_map.get(_JAVA_WILDCARD_KEY) and head not in import_map {
            return type_name.strip();
        }
        return cls._resolve_java_type_identity(type_name, import_map);
    }

    static def _resolve_java_type_identity(type_name: str, import_map: dict[str, str]) -> str {
        normalized: any = type_name.strip();
        if not normalized {
            return normalized;
        }
        head: any;
        separator: any;
        tail: any;
        (head, separator, tail) = normalized.partition(".") as any;
        imported: any = import_map.get(head);
        if imported {
            return f"{imported}.{tail}" if separator else imported;
        }
        if separator and head[:1].islower() {
            return normalized;
        }
        package: any = import_map.get(_JAVA_PACKAGE_KEY, "");
        return f"{package}.{normalized}" if package else normalized;
    }

    static def _descendants_of_type(`node, node_type: str) -> list {
        matches: list = [];
        if `node.type == node_type {
            matches.append(`node);
        }
        for child in `node.children {
            matches.extend(CodeParser._descendants_of_type(child, node_type));
        }
        return matches;
    }

    def _emit_spring_event_listener_edges(
        method_node,
        method_name: str,
        class_name: Optional[str],
        file_path: str,
        import_map: dict[str, str],
        edges: list[EdgeInfo],
    ) -> int {
        emitted: any = 0;
        source: any = self._qualify(method_name, file_path, class_name);
        for annotation in self._java_annotations_named(
            method_node, _SPRING_EVENT_LISTENER_ANNOTATIONS
        ) {
            type_names: list[str] = [];
            for class_literal in self._descendants_of_type(annotation, "class_literal") {
                type_name: any = self._java_type_name(class_literal);
                if type_name {
                    type_names.append(type_name);
                }
            }

            if not type_names {
                parameters: any = next(
                    (child for child in method_node.children if child.type == "formal_parameters"),
                    None,
                );
                if parameters is not None {
                    parameter: any = next(
                        (child
                        for child in parameters.children
                        if child.type == "formal_parameter"),
                        None,
                    );
                    if parameter is not None {
                        type_name = self._java_type_name(parameter);
                        if type_name {
                            type_names.append(type_name);
                        }
                    }
                }
            }

            attributes: any = self._java_annotation_attributes(annotation);
            seen: set[str] = set[any]();
            for type_name in type_names {
                identity: any = self._resolve_java_type_identity(type_name, import_map);
                if not identity or identity in seen {
                    continue;
                }
                seen.add(identity);
                extra: any = {"event_type": identity, "resolution": "spring_event_listener"};
                for key in ("condition", "id", "defaultExecution") {
                    if key in attributes {
                        extra[key] = attributes[key];
                    }
                }
                edges.append(
                    EdgeInfo(
                        "HANDLES",
                        source,
                        f"event::{identity}",
                        file_path,
                        annotation.start_point[0] + 1,
                        extra=extra,
                    ),
                );
                emitted += 1;
            }
        }
        return emitted;
    }

    def _emit_spring_event_publish_edges(
        method_node,
        method_name: str,
        class_name: Optional[str],
        file_path: str,
        import_map: dict[str, str],
        edges: list[EdgeInfo],
    ) -> int {
        source: any = self._qualify(method_name, file_path, class_name);
        emitted: any = 0;

        def `visit(`node) {
            child: any;
            if `node.type == "method_invocation" {
                receiver: any;
                invoked: any;
                (receiver, invoked) = self._get_member_call_receiver_method(`node, "java") as any;
                if invoked in _SPRING_EVENT_PUBLISH_METHODS {
                    arguments: any = next(
                        (child for child in `node.children if child.type == "argument_list"), None
                    );
                    if arguments is not None {
                        for argument in arguments.children {
                            if argument.type != "object_creation_expression" {
                                continue;
                            }
                            type_name: any = self._java_type_name(argument);
                            if not type_name {
                                continue;
                            }
                            identity: any = self._resolve_java_type_identity(type_name, import_map);
                            extra: any = {
                                "event_type": identity,
                                "resolution": "spring_publish_event",
                            };
                            if receiver {
                                extra["receiver"] = receiver;
                            }
                            edges.append(
                                EdgeInfo(
                                    "PUBLISHES",
                                    source,
                                    f"event::{identity}",
                                    file_path,
                                    `node.start_point[0] + 1,
                                    extra=extra,
                                ),
                            );
                            emitted += 1;
                        }
                    }
                }
            }
            for child in `node.children {
                `visit(child);
            }
        }

        body: any = next((child for child in method_node.children if child.type == "block"), None);
        if body is not None {
            `visit(body);
        }
        return emitted;
    }

    def _emit_temporal_stub_fields(
        class_node, class_name: str, file_path: str, edges: list[EdgeInfo]
    ) {
        qualified_source: any = self._qualify(class_name, file_path, None);

        for `node in class_node.children {
            if `node.type != "class_body" {
                continue;
            }
            for member in `node.children {
                if member.type != "field_declaration" {
                    continue;
                }
                has_static: any = False;
                field_type: Optional[str] = None;
                field_name: Optional[str] = None;

                for ch in member.children {
                    if ch.type == "modifiers" {
                        for mod in ch.children {
                            if mod.text and mod.text.decode("utf-8", errors="replace") == "static" {
                                has_static = True;
                            }
                        }
                    } elif ch.type == "type_identifier" {
                        field_type = ch.text.decode("utf-8", errors="replace");
                    } elif ch.type == "variable_declarator" {
                        for sub in ch.children {
                            if sub.type == "identifier" {
                                field_name = sub.text.decode("utf-8", errors="replace");
                                break;
                            }
                        }
                    }
                }

                if has_static or not field_type or not field_name {
                    continue;
                }
                if not (field_type.endswith("Activity") or field_type.endswith("Workflow")) {
                    continue;
                }

                edges.append(
                    EdgeInfo(
                        "TEMPORAL_STUB",
                        qualified_source,
                        field_type,
                        file_path,
                        member.start_point[0] + 1,
                        extra={
                            "field_name": field_name,
                            "stub_type": "activity"
                                if field_type.endswith("Activity")
                                else "workflow",
                        },
                    ),
                );
            }
        }
    }

    static def _get_kafka_annotation_topics(annotation_node) -> list[str] {
        topics: list[str] = [];
        for child in annotation_node.children {
            if child.type != "annotation_argument_list" {
                continue;
            }
            for pair in child.children {
                if pair.type != "element_value_pair" {
                    continue;
                }
                key_node: any = next((c for c in pair.children if c.type == "identifier"), None);
                if key_node is None {
                    continue;
                }
                key: any = key_node.text.decode("utf-8", errors="replace");
                if key not in ("topics", "topicPattern", "value") {
                    continue;
                }
                for val in pair.children {
                    if val.type == "string_literal" {
                        raw: any = val.text.decode("utf-8", errors="replace").strip("\"").strip(
                            "'"
                        );
                        if raw {
                            topics.append(raw);
                        }
                    } elif val.type in ("array_initializer", "element_value_array_initializer") {
                        for item in val.children {
                            if item.type == "string_literal" {
                                txt: any = item.text.decode("utf-8", errors="replace");
                                raw = txt.strip("\"").strip("'");
                                if raw {
                                    topics.append(raw);
                                }
                            }
                        }
                    }
                }
            }
        }
        return topics;
    }

    def _emit_kafka_edges_from_class(
        class_node, class_name: str, file_path: str, edges: list[EdgeInfo]
    ) {
        qualified_source: any = self._qualify(class_name, file_path, None);

        for `node in class_node.children {
            if `node.type != "class_body" {
                continue;
            }
            for member in `node.children {
                if member.type != "field_declaration" {
                    continue;
                }
                has_static: any = False;
                outer_type: Optional[str] = None;
                value_type: Optional[str] = None;
                field_name: Optional[str] = None;

                for ch in member.children {
                    if ch.type == "modifiers" {
                        for mod in ch.children {
                            if mod.text and mod.text.decode("utf-8", errors="replace") == "static" {
                                has_static = True;
                            }
                        }
                    } elif ch.type == "type_identifier" {
                        outer_type = ch.text.decode("utf-8", errors="replace");
                    } elif ch.type == "generic_type" {
                        type_args: list[str] = [];
                        sub: any;
                        for sub in ch.children {
                            if sub.type == "type_identifier" {
                                if outer_type is None {
                                    outer_type = sub.text.decode("utf-8", errors="replace");
                                }
                            } elif sub.type == "type_arguments" {
                                for arg in sub.children {
                                    if arg.type == "type_identifier" {
                                        type_args.append(
                                            arg.text.decode("utf-8", errors="replace")
                                        );
                                    }
                                }
                            }
                        }
                        if len(type_args) >= 2 {
                            value_type = type_args[-1];
                        }
                    } elif ch.type == "variable_declarator" {
                        for sub in ch.children {
                            if sub.type == "identifier" {
                                field_name = sub.text.decode("utf-8", errors="replace");
                                break;
                            }
                        }
                    }
                }

                if has_static or not outer_type or not field_name {
                    continue;
                }

                extra: dict = {"field_name": field_name};
                if value_type {
                    extra["message_type"] = value_type;
                }

                if outer_type in _KAFKA_CONSUMER_TYPES {
                    extra["kafka_type"] = outer_type;
                    edges.append(
                        EdgeInfo(
                            "CONSUMES",
                            qualified_source,
                            "kafka:config",
                            file_path,
                            member.start_point[0] + 1,
                            extra=extra,
                        ),
                    );
                } elif outer_type in _KAFKA_PRODUCER_TYPES {
                    extra["kafka_type"] = outer_type;
                    edges.append(
                        EdgeInfo(
                            "PRODUCES",
                            qualified_source,
                            "kafka:config",
                            file_path,
                            member.start_point[0] + 1,
                            extra=extra,
                        ),
                    );
                }
            }
        }
    }

    def _emit_kafka_edges_from_method(
        method_node,
        method_name: str,
        class_name: Optional[str],
        file_path: str,
        edges: list[EdgeInfo],
    ) {
        qualified_source: any = self._qualify(method_name, file_path, class_name);

        for child in method_node.children {
            if child.type != "modifiers" {
                continue;
            }
            for mod in child.children {
                if mod.type not in ("annotation", "marker_annotation") {
                    continue;
                }
                ann_name: Optional[str] = None;
                for sub in mod.children {
                    if sub.type == "identifier" {
                        ann_name = sub.text.decode("utf-8", errors="replace");
                        break;
                    }
                }
                if ann_name not in _KAFKA_LISTENER_ANNOTATIONS {
                    continue;
                }
                topics: any = self._get_kafka_annotation_topics(mod);
                if topics {
                    for topic in topics {
                        edges.append(
                            EdgeInfo(
                                "CONSUMES",
                                qualified_source,
                                f"kafka:{topic}",
                                file_path,
                                method_node.start_point[0] + 1,
                                extra={"topic": topic, "kafka_type": "KafkaListener"},
                            ),
                        );
                    }
                } else {
                    edges.append(
                        EdgeInfo(
                            "CONSUMES",
                            qualified_source,
                            "kafka:config",
                            file_path,
                            method_node.start_point[0] + 1,
                            extra={"kafka_type": ann_name},
                        ),
                    );
                }
            }
        }
    }

    def _get_docstring_summary(`node, language: str) -> Optional[str] {
        if language == "python" {
            raw: any = self._python_docstring_value(`node);
        } else {
            raw = self._preceding_doc_comment(`node, language);
        }
        if not raw {
            return None;
        }
        return _clean_docstring_summary(raw, language) or None;
    }

    static def _python_docstring_value(`node) -> Optional[str] {
        body: any = `node.child_by_field_name("body");
        if body is None {
            return None;
        }
        statement: any = next(
            (child for child in body.named_children if child.type != "comment"), None
        );
        if statement is None {
            return None;
        }
        expression: any = statement;
        if expression.type == "expression_statement" {
            named: any = expression.named_children;
            if len(named) != 1 {
                return None;
            }
            expression = named[0];
        }
        if expression.type not in ("string", "concatenated_string", "parenthesized_expression") {
            return None;
        }
        try {
            value: any = ast.literal_eval(expression.text.decode("utf-8", errors="strict"));
        } except (SyntaxError, ValueError, UnicodeDecodeError) {
            return None;
        }
        return value if isinstance(value, `str) else None;
    }

    static def _line_doc_payload(text: str, language: str) -> Optional[str] {
        stripped: any = text.strip();
        if language == "go" {
            if not stripped.startswith("//") {
                return None;
            }
            return stripped[2:].lstrip();
        }
        if language == "rust" {
            if not stripped.startswith("///") or stripped.startswith("////") {
                return None;
            }
            return stripped[3:].lstrip();
        }
        if stripped.startswith(("///", "//!")) {
            return stripped[3:].lstrip();
        }
        return None;
    }

    def _preceding_doc_comment(`node, language: str) -> Optional[str] {
        anchor: any = `node;
        while anchor.parent is not None and anchor.parent.type in _DOC_COMMENT_WRAPPER_TYPES {
            anchor = anchor.parent;
        }

        siblings: list = [];
        current_line: any = anchor.start_point[0];
        sibling: any = anchor.prev_sibling;
        while sibling is not None {
            if sibling.end_point[0] < current_line - 1 {
                break;
            }
            if sibling.type in _DOC_COMMENT_SKIP_TYPES {
                current_line = sibling.start_point[0];
                sibling = sibling.prev_sibling;
                continue;
            }
            if sibling.type not in _DOC_COMMENT_NODE_TYPES {
                break;
            }
            siblings.append(sibling);
            current_line = sibling.start_point[0];
            sibling = sibling.prev_sibling;
        }

        if not siblings {
            return None;
        }

        nearest: any = siblings[0].text.decode("utf-8", errors="replace").strip();
        if nearest.startswith("/*") {
            allowed: any = ("/**",) if language == "rust" else ("/**", "/*!");
            if not nearest.startswith(allowed) {
                return None;
            }
            return _strip_block_doc_comment(nearest);
        }
        payloads: list[str] = [];
        for comment in siblings {
            text: any = comment.text.decode("utf-8", errors="replace");
            payload: any = self._line_doc_payload(text, language);
            if payload is None {
                break;
            }
            if language == "go" and payload.startswith(("go:", "line ")) {
                continue;
            }
            payloads.append(payload);
        }
        if not payloads {
            return None;
        }
        payloads.reverse();
        return "\n".join(payloads);
    }

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
    ) -> bool {
        if language == "go"
            and child.type == "type_declaration"
            and `any(operator.eq(part.type, "(") for part in child.children)
        {
            for spec in child.named_children {
                if spec.type == "type_spec" {
                    self._extract_classes(
                        spec,
                        source,
                        language,
                        file_path,
                        nodes,
                        edges,
                        enclosing_class,
                        import_map,
                        defined_names,
                        _depth,
                    );
                }
            }
            return True;
        }

        name: any = self._get_name(child, language, "class");
        if not name {
            return False;
        }

        class_parent: any = enclosing_class;
        csharp_namespace: any = None;
        if language == "csharp" {
            name = _csharp_name(child.child_by_field_name("name"));
            csharp_namespace = _csharp_namespace_context(child)[0][0];
            class_parent = enclosing_class or csharp_namespace or None;
        }
        if language == "ruby" and child.type in ("class", "module") {
            _name_child: any = child.child_by_field_name("name");
            if _name_child is not None and _name_child.type == "scope_resolution" {
                _scope: any = _name_child.child_by_field_name("scope");
                _chain: any = (
                    _scope.text.decode("utf-8", errors="replace").replace("::", ".")
                        if _scope is not None
                        else ""
                ).lstrip(".");
                if _name_child.text.lstrip().startswith(b"::") {
                    class_parent = _chain or None;
                } elif _chain {
                    class_parent = f"{class_parent}.{_chain}" if class_parent else _chain;
                }
            }
        }
        extra: dict = {};
        if language == "csharp" {
            extra["csharp_namespace"] = csharp_namespace;
            parameters: any = next(
                (c for c in child.children if c.type == "type_parameter_list"), None
            );
            if parameters is not None {
                extra["csharp_arity"] = sum(
                    1 for c in parameters.named_children if c.type == "type_parameter"
                );
            }
            if `any(
                operator.eq(c.type, "modifier") and operator.eq(c.text, b"partial")
                for c in child.children,
            ) {
                extra["csharp_partial"] = True;
            }
        }
        if language in ("typescript", "tsx")
            and child.type in ("interface_declaration", "type_alias_declaration")
        {
            extra["typescript_kind"] = child.type;
        }
        if language == "php" and child.type in ("interface_declaration", "trait_declaration") {
            extra["php_kind"] = child.type.split("_", 1)[0];
        }
        if language == "swift" {
            if child.type == "class_declaration" {
                _swift_keywords: any = {"class", "struct", "enum", "actor", "extension"};
                for kw_child in child.children {
                    kw_text: any = kw_child.text.decode("utf-8", errors="replace");
                    if kw_text in _swift_keywords {
                        extra["swift_kind"] = kw_text;
                        break;
                    }
                }
            } elif child.type == "protocol_declaration" {
                extra["swift_kind"] = "protocol";
            }
        }
        class_annotations: list[str] = [];
        if language == "java" {
            package: any = (import_map or {}).get(_JAVA_PACKAGE_KEY);
            if package {
                extra["java_package"] = package;
            }
            if child.type == "interface_declaration" {
                extra["java_kind"] = "interface";
            } else {
                extra["java_kind"] = "abstract"
                    if `any(
                        operator.eq(grandchild.type, "abstract")
                        for modifier in child.children
                        if modifier.type == "modifiers"
                        for grandchild in modifier.children,
                    )
                    else "concrete";
            }
            class_annotations = self._get_java_annotations(child);
            spring_stereotypes: any = [
                a
                for a in class_annotations
                if a in _SPRING_STEREOTYPE_ANNOTATIONS
            ];
            if spring_stereotypes {
                extra["spring_stereotype"] = spring_stereotypes[0];
            }
            if class_annotations {
                extra["spring_annotations"] = class_annotations;
            }
            temporal_roles: any = [
                a
                for a in class_annotations
                if a in _TEMPORAL_INTERFACE_ANNOTATIONS
            ];
            if temporal_roles {
                is_wf: any = "WorkflowInterface" in temporal_roles;
                role: any = "workflow_interface" if is_wf else "activity_interface";
                extra["temporal_role"] = role;
            }
            if import_map is not None {
                java_package: any = import_map.get(_JAVA_PACKAGE_KEY, "");
                if java_package {
                    extra["java_package"] = java_package;
                }
                request_prefixes: list[str] = [];
                for annotation in self._java_annotations_named(
                    child, frozenset({"RequestMapping"})
                ) {
                    request_prefixes.extend(self._spring_mapping_paths(annotation));
                }
                if request_prefixes {
                    import_map[f"{_SPRING_REQUEST_PREFIX_KEY}{name}"] = json.dumps(
                        request_prefixes
                    );
                }
            }
        }
        if language == "java" {
            class_decorators: any = `list(class_annotations);
        } else {
            class_decorators = _modifier_annotation_names(child);
            if language == "python" {
                class_decorators.extend(_python_decorator_names(child));
            }
            if language == "csharp" {
                class_decorators.extend(_csharp_attribute_names(child));
            }
        }
        class_modifiers: Optional[str] = ",".join(class_decorators) if class_decorators else None;
        if class_decorators and "decorators" not in extra {
            extra["decorators"] = class_decorators;
        }

        docstring: any = self._get_docstring_summary(child, language);
        if docstring {
            extra["docstring"] = docstring;
        }

        `node: any = NodeInfo(
            "Class",
            name,
            file_path,
            child.start_point[0] + 1,
            child.end_point[0] + 1,
            language=language,
            parent_name=class_parent,
            modifiers=class_modifiers,
            extra=extra,
        );
        nodes.append(`node);
        class_container: any = self._qualify(enclosing_class, file_path, None)
            if enclosing_class and language not in ("python", "cpp")
            else file_path;
        edges.append(
            EdgeInfo(
                "CONTAINS",
                class_container,
                self._qualify(name, file_path, class_parent),
                file_path,
                child.start_point[0] + 1,
            ),
        );
        bases: any = self._get_bases(child, language, source);
        for base in bases {
            inheritance_extra: any = {};
            if language == "java" and import_map is not None {
                inheritance_extra["java_type"] = self._spring_java_type(base, import_map);
            }
            edges.append(
                EdgeInfo(
                    "INHERITS",
                    self._qualify(name, file_path, class_parent),
                    base,
                    file_path,
                    child.start_point[0] + 1,
                    extra=inheritance_extra,
                ),
            );
        }
        if language == "java" {
            self._emit_spring_injections(
                child, name, class_annotations, language, file_path, edges, import_map
            );
            self._emit_spring_config_edges(child, name, enclosing_class, file_path, edges);
            self._emit_temporal_stub_fields(child, name, file_path, edges);
            self._emit_kafka_edges_from_class(child, name, file_path, edges);
        }
        if language == "julia" {
            recursive_class: any = self._julia_scope_join(enclosing_class, name);
        } elif language in ("python", "cpp") {
            recursive_class = name;
        } elif class_parent {
            recursive_class = f"{class_parent}.{name}";
        } else {
            recursive_class = name;
        }
        self._extract_from_tree(
            child,
            source,
            language,
            file_path,
            nodes,
            edges,
            enclosing_class=recursive_class,
            enclosing_func=None,
            import_map=import_map,
            defined_names=defined_names,
            _depth=_depth + 1,
        );
        return True;
    }

    def _index_ambiguous_method_scopes(`root, language: str, import_map: dict) {
        scope: any;
        if language != "python" {
            return;
        }
        scopes: dict[str, set[str]] = {};
        methods: list[tuple[int, str, str]] = [];
        pending: any = [(`root, "")];
        while pending {
            `node: any;
            (`node, scope) = pending.pop() as any;
            if `node.type in self._class_types[language] {
                name: any = self._get_name(`node, language, "class");
                if name {
                    scope = f"{scope}.{name}" if scope else name;
                    scopes.setdefault(name, set[any]()).add(scope);
                }
            }
            if `node.type in self._function_types[language] and scope {
                methods.append((`node.id, scope.rsplit(".", 1)[-1], scope));
            }
            pending.extend((child, scope) for child in reversed(`node.named_children));
        }
        node_id: any;
        leaf: any;
        for item_ in methods {
            (node_id, leaf, scope) = item_;
            if len(scopes.get(leaf, ())) > 1 {
                import_map[f"__crg_method_scope__:{node_id}"] = scope;
            }
        }
    }

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
    ) -> bool {
        name: any = self._get_name(child, language, "function");
        if not name {
            return False;
        }
        if language == "csharp" {
            name = _csharp_name(child.child_by_field_name("name")) or name;
        }
        if language == "go" and child.type == "method_declaration" {
            receiver_type: any = self._get_go_receiver_type(child);
            if receiver_type {
                enclosing_class = receiver_type;
            }
        }
        decorators: tuple[str, ...] = ();
        deco_list: list[str] = [];
        sub: any;
        for sub in child.children {
            if sub.type == "modifiers" {
                for mod in sub.children {
                    if mod.type in ("annotation", "marker_annotation") {
                        text: any = mod.text.decode("utf-8", errors="replace");
                        deco_list.append(text.lstrip("@").strip());
                    }
                }
            }
        }
        if child.parent and child.parent.type == "decorated_definition" {
            sib: any;
            for sib in child.parent.children {
                if sib.type == "decorator" {
                    text = sib.text.decode("utf-8", errors="replace");
                    deco_list.append(text.lstrip("@").strip());
                }
            }
        }
        if language == "rust" {
            sib = child.prev_sibling;
            while sib is not None and sib.type == "attribute_item" {
                text = sib.text.decode("utf-8", errors="replace").strip();
                if text.startswith("#![") {
                    inner: any = text[3:].rstrip();
                } elif text.startswith("#[") {
                    inner = text[2:].rstrip();
                } else {
                    inner = text;
                }
                if inner.endswith("]") {
                    inner = inner[:-1];
                }
                deco_list.append(inner.strip());
                sib = sib.prev_sibling;
            }
        }
        if language == "csharp" {
            deco_list.extend(_csharp_attribute_names(child));
        }
        if language == "php" {
            deco_list.extend(_php_attribute_names(child));
            if _php_docblock_marks_test(child) {
                deco_list.append("Test");
            }
        }
        if deco_list {
            decorators = `tuple(deco_list);
        }

        is_test: any = _is_test_function(name, file_path, decorators, repo_root=self._repo_root);
        if language == "powershell" {
            is_test = self._is_test_path(file_path);
        }
        if language == "php"
            and child.type == "method_declaration"
            and self._is_test_path(file_path)
            and name.startswith("test")
        {
            is_test = True;
        }
        kind: any = "Test" if is_test else "Function";

        parent_name: any = enclosing_class;
        container_scope: any = enclosing_class;
        if language == "python" and import_map is not None {
            parent_name = import_map.get(f"__crg_method_scope__:{child.id}", parent_name);
            container_scope = ".".join(parent_name.split(".")[-2:]) if parent_name else parent_name;
            enclosing_class = parent_name;
        }
        julia_qualifier: Optional[str] = None;
        if language == "julia" {
            lexical_parent: any = self._julia_scope_join(enclosing_class, enclosing_func);
            julia_qualifier = self._julia_definition_qualifier(child);
            parent_name = self._julia_scope_join(lexical_parent, julia_qualifier);
            container_scope = lexical_parent;
        }

        identity_name: any = name;
        params: any = self._get_params(child, language, source);
        if language == "cpp" {
            explicit_scope: any;
            cpp_params: any;
            (explicit_scope, identity_name, cpp_params) = self._cpp_function_identity(
                child, name, source
            ) as any;
            lexical_namespace: any = self._cpp_lexical_namespace(child);
            lexical_classes: any = self._cpp_lexical_class_names(child);
            lexical_class_scope: any = ".".join(lexical_classes) or None;
            parent_name = self._cpp_scope_join(
                lexical_namespace, explicit_scope or lexical_class_scope or enclosing_class
            );
            if lexical_classes {
                container_scope = ".".join(lexical_classes[-2:]);
            } elif enclosing_class {
                container_scope = enclosing_class;
            }
            if cpp_params is not None {
                params = cpp_params;
            }
        }

        qualified: any = self._qualify(identity_name, file_path, parent_name);
        ret_type: any = self._get_return_type(child, language, source);
        method_extra: dict = {};
        if language == "csharp" {
            method_extra["csharp_namespace"] = _csharp_namespace_context(child)[0][0];
            method_extra["csharp_static"] = `any(
                operator.eq(c.type, "modifier") and operator.eq(c.text, b"static")
                for c in child.children,
            );
        }
        go_receiver_bindings: any = None;
        if language == "go" and child.type == "method_declaration" {
            receiver_name: any = self._get_go_receiver_name(child);
            if receiver_name {
                method_extra["go_receiver"] = receiver_name;
                go_receiver_bindings = self._go_receiver_binding_index(child, receiver_name);
            }
        }
        if julia_qualifier {
            method_extra["julia_module_qualifier"] = julia_qualifier;
        }
        if child.type == "abstract_method_signature" {
            method_extra["abstract"] = True;
        }
        if language == "java" and deco_list {
            endpoint_count: any = self._emit_spring_endpoint_nodes(
                child, name, enclosing_class, file_path, import_map or {}, nodes, edges
            );
            if endpoint_count {
                method_extra["spring_endpoint"] = True;
                method_extra["spring_endpoint_count"] = endpoint_count;
            }
            temporal_method_annots: any = [
                a
                for a in deco_list
                if a in _TEMPORAL_METHOD_ANNOTATIONS
            ];
            if temporal_method_annots {
                method_extra["temporal_role"] = temporal_method_annots[0].lower();
            }
            if `any(a.split("(")[0] in _KAFKA_LISTENER_ANNOTATIONS for a in deco_list) {
                method_extra["kafka_listener"] = True;
                self._emit_kafka_edges_from_method(child, name, enclosing_class, file_path, edges);
            }
            if `any(
                annotation.split("(", 1)[0] in _SPRING_SCHEDULED_ANNOTATIONS
                for annotation in deco_list,
            ) {
                schedule_count: any = self._emit_scheduled_nodes_from_method(
                    child, name, enclosing_class, file_path, nodes, edges
                );
                if schedule_count {
                    method_extra["scheduled"] = True;
                    method_extra["schedule_count"] = schedule_count;
                }
            }
            listener_count: any = self._emit_spring_event_listener_edges(
                child, name, enclosing_class, file_path, import_map or {}, edges
            );
            if listener_count {
                method_extra["spring_event_listener"] = True;
                method_extra["spring_event_type_count"] = listener_count;
            }

            publish_count: any = self._emit_spring_event_publish_edges(
                child, name, enclosing_class, file_path, import_map or {}, edges
            );
            if publish_count {
                method_extra["spring_event_publisher"] = True;
                method_extra["spring_event_publish_count"] = publish_count;
            }
        } elif language == "java" {
            publish_count = self._emit_spring_event_publish_edges(
                child, name, enclosing_class, file_path, import_map or {}, edges
            );
            if publish_count {
                method_extra["spring_event_publisher"] = True;
                method_extra["spring_event_publish_count"] = publish_count;
            }
        }
        modifiers_str: Optional[str] = ",".join(deco_list) if deco_list else None;
        if deco_list {
            method_extra["decorators"] = `list(deco_list);
        }
        if language == "java" and child.type == "constructor_declaration" {
            method_extra["java_constructor"] = True;
        }

        docstring: any = self._get_docstring_summary(child, language);
        if docstring {
            method_extra["docstring"] = docstring;
        }

        `node: any = NodeInfo(
            kind,
            name,
            file_path,
            child.start_point[0] + 1,
            child.end_point[0] + 1,
            language=language,
            parent_name=parent_name,
            params=params,
            return_type=ret_type,
            modifiers=modifiers_str,
            is_test=is_test,
            extra=method_extra,
            identity_name=identity_name,
        );
        nodes.append(`node);
        container: any = self._qualify(container_scope, file_path, None)
            if container_scope
            else file_path;
        edges.append(
            EdgeInfo("CONTAINS", container, qualified, file_path, child.start_point[0] + 1)
        );
        if julia_qualifier {
            edges.append(
                EdgeInfo(
                    "REFERENCES",
                    qualified,
                    julia_qualifier,
                    file_path,
                    child.start_point[0] + 1,
                    extra={"julia_qualified_def": True},
                ),
            );
        }
        if language == "solidity" {
            for sub in child.children {
                if sub.type == "modifier_invocation" {
                    for ident in sub.children {
                        if ident.type == "identifier" {
                            edges.append(
                                EdgeInfo(
                                    "CALLS",
                                    qualified,
                                    ident.text.decode("utf-8", errors="replace"),
                                    file_path,
                                    sub.start_point[0] + 1,
                                ),
                            );
                            break;
                        }
                    }
                }
            }
        }
        recursive_class: any = parent_name if language in ("julia", "cpp") else enclosing_class;
        self._extract_from_tree(
            child,
            source,
            language,
            file_path,
            nodes,
            edges,
            enclosing_class=recursive_class,
            enclosing_func=identity_name,
            import_map=import_map,
            defined_names=defined_names,
            _depth=_depth + 1,
            _go_receiver_bindings=go_receiver_bindings,
        );
        return True;
    }

    def _extract_imports(
        child, language: str, source: bytes, file_path: str, edges: list[EdgeInfo]
    ) -> bool {
        specs: any = self._extract_import_specs(child, language, source, file_path);
        csharp_extra: any = {};
        if language == "csharp" {
            scopes: any = _csharp_namespace_context(child);
            alias: any = next((c for c in child.children if c.type == "="), None);
            csharp_extra = {
                "source_offset": child.start_byte,
                "csharp_scopes": scopes,
                "csharp_global": `any(operator.eq(c.type, "global") for c in child.children),
                "csharp_using_kind": "alias"
                    if alias is not None
                    else "static"
                        if `any(operator.eq(c.type, "static") for c in child.children)
                        else "namespace",
            };
            if alias is not None {
                csharp_extra["csharp_alias"] = _csharp_name(
                    next(c for c in child.named_children if c.type != "comment")
                );
            }
        }
        for spec in specs {
            target: any;
            scope: any;
            (target, scope) = self._resolve_import_target(
                spec.module, file_path, language, spec.form
            ) as any;
            if target is None {
                (target, scope) = (spec.module, None);
            }
            extra: dict[str, str] = {};
            if scope {
                extra[IMPORT_SCOPE_KEY] = scope;
            }
            if spec.context {
                extra[IMPORT_CONTEXT_KEY] = spec.context;
            }
            edges.append(
                EdgeInfo(
                    "IMPORTS_FROM",
                    file_path,
                    target,
                    file_path,
                    spec.line,
                    extra={**csharp_extra, **extra},
                ),
            );
        }
        return `bool(specs);
    }

    def _resolve_import_target(
        module: str, file_path: str, language: str, form: Optional[str] = None
    ) -> tuple[Optional[str], Optional[str]] {
        if language == "go" {
            package_dir: any = self._resolve_go_package_dir(module, file_path);
            if package_dir is None {
                return (None, None);
            }
            return (normalize_file_path(package_dir), IMPORT_SCOPE_PACKAGE);
        }
        if language == "ruby" and form == "require_all" {
            directory: any = self._resolve_ruby_require_all_dir(module, file_path);
            if directory is not None {
                return (normalize_file_path(directory), IMPORT_SCOPE_TREE);
            }
            form = "require";
        }
        resolved: any = self._resolve_module_to_file(module, file_path, language, form=form);
        return (resolved, None) if resolved else (None, None);
    }

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
    ) -> bool {
        if language == "python"
            and (child.start_point[0] + 1, child.start_point[1])
                in _python_unreachable_call_positions(source)
        {
            return True;
        }
        if language == "rust" and _is_in_rust_dead_guard(child) {
            return True;
        }
        if language != "python" and _is_in_static_dead_guard(child) {
            return True;
        }

        call_name: any = self._get_call_name(child, language, source);
        effective_call_name: any = call_name;
        if call_name
            and language in ("javascript", "typescript", "tsx")
            and self._is_test_path(file_path)
            and call_name not in _TEST_RUNNER_NAMES
        {
            effective_call_name = self._get_base_call_name(child, source) or call_name;
        }
        if effective_call_name
            and (
                language in ("javascript", "typescript", "tsx")
                    and self._is_test_path(file_path)
                    and effective_call_name in _TEST_RUNNER_NAMES
                or language == "ruby"
                    and self._is_ruby_test_block(child, effective_call_name, file_path)
            )
        {
            test_desc: any = self._get_ruby_test_description(child)
                if language == "ruby"
                else self._get_test_description(child, source);
            line_no: any = child.start_point[0] + 1;
            synthetic_base: any = f"{effective_call_name}:{test_desc}"
                if test_desc
                else effective_call_name;
            synthetic_name: any = f"{synthetic_base}@L{line_no}";
            qualified: any = self._qualify(synthetic_name, file_path, enclosing_class);

            nodes.append(
                NodeInfo(
                    "Test",
                    synthetic_name,
                    file_path,
                    child.start_point[0] + 1,
                    child.end_point[0] + 1,
                    language=language,
                    parent_name=enclosing_class,
                    is_test=True,
                ),
            );
            container: any = self._qualify(enclosing_func, file_path, enclosing_class)
                if enclosing_func
                else file_path;
            edges.append(
                EdgeInfo("CONTAINS", container, qualified, file_path, child.start_point[0] + 1)
            );
            self._extract_from_tree(
                child,
                source,
                language,
                file_path,
                nodes,
                edges,
                enclosing_class=enclosing_class,
                enclosing_func=synthetic_name,
                import_map=import_map,
                defined_names=defined_names,
                _depth=_depth + 1,
            );
            return True;
        }

        if call_name {
            if enclosing_func {
                caller: any = self._qualify(enclosing_func, file_path, enclosing_class);
            } elif language in ("verilog", "julia") and enclosing_class {
                caller = self._qualify(enclosing_class, file_path, None);
            } else {
                caller = file_path;
            }
            call_extra: dict = {};
            if language in ("javascript", "typescript", "tsx") {
                member_call: any = self._get_js_member_call_name(child);
                if member_call {
                    call_extra["member_call"] = member_call;
                }
            }
            if language in self._TYPED_CALL_LANGUAGES or language in ("cpp", "go", "rust") {
                receiver: any;
                method_name: any;
                (receiver, method_name) = self._get_member_call_receiver_method(
                    child, language
                ) as any;
                if method_name {
                    call_name = method_name;
                }
                if receiver {
                    call_extra["receiver"] = receiver;
                    if language == "go"
                        and _go_receiver_bindings is not None
                        and receiver == _go_receiver_bindings[0]
                        and not self._go_receiver_is_shadowed(child, _go_receiver_bindings)
                    {
                        call_extra["go_method_receiver"] = True;
                    }
                } elif method_name and language in ("python", "php") {
                    call_extra["receiver_form"] = "expression";
                } elif method_name
                    and language == "java"
                    and self._java_expression_receiver(child)
                    and self._is_test_path(file_path)
                {
                    call_extra["receiver_form"] = "expression";
                }
                if language == "java" and child.type == "method_reference" {
                    call_extra["call_syntax"] = "method_reference";
                }
            }

            if language == "java" and child.type == "method_invocation" {
                self._emit_spring_webflux_endpoint(
                    child,
                    source,
                    call_name,
                    file_path,
                    enclosing_class,
                    import_map or {},
                    defined_names or set[any](),
                    nodes,
                    edges,
                );
            }
            if language == "julia"
                and child.children
                and child.children[0].type == "field_expression"
            {
                qualifier: any;
                qualified_name: any;
                (qualifier, qualified_name) = self._julia_field_info(child.children[0]) as any;
                if qualifier and qualified_name {
                    module_parts: any = qualifier.split(".");
                    imported_module: any = self._resolve_julia_import_alias(
                        module_parts[0], enclosing_class, enclosing_func, import_map or {}
                    );
                    if imported_module {
                        module_parts[0] = imported_module;
                    }
                    resolved_qualifier: any = ".".join(module_parts);
                    call_name = f"{resolved_qualifier}.{qualified_name}";
                    call_extra["julia_call_module"] = resolved_qualifier;
                }
            }

            if language == "julia" and "." not in call_name {
                imported_symbol: any = self._resolve_julia_import_alias(
                    call_name, enclosing_class, enclosing_func, import_map or {}
                );
                if imported_symbol {
                    call_name = imported_symbol;
                }
            }
            receiver_name: any = call_extra.get("receiver");
            if language == "csharp" {
                callee: any = child.child_by_field_name("function");
                if callee is not None and callee.type == "identifier" {
                    call_name = _csharp_name(callee) or call_name;
                }
                target: any = call_name;
                call_extra.update({
                    "source_offset": child.start_byte,
                    "csharp_raw_target": call_name,
                    "csharp_scopes": _csharp_namespace_context(child),
                    "csharp_containing_type": enclosing_class,
                    "csharp_call_kind": "constructor"
                        if child.type == "object_creation_expression"
                        else "unqualified"
                            if callee is not None and callee.type == "identifier"
                            else "member",
                    "unresolved_targets": [],
                });
                if child.type == "object_creation_expression" {
                    call_extra["receiver_scope"] = _csharp_name(child.child_by_field_name("type"));
                }
            } elif receiver_name in ("self", "cls", "this") and enclosing_class {
                target = call_name
                    if language == "cpp"
                    else self._qualify(call_name, file_path, enclosing_class);
            } elif language == "rust" and call_name.startswith("Self::") and enclosing_class {
                target = self._qualify(call_name.rsplit("::", 1)[-1], file_path, enclosing_class);
            } elif receiver_name or call_extra.get("receiver_form") == "expression" {
                target = call_name;
            } else {
                target = self._resolve_call_target(
                    call_name, file_path, language, import_map or {}, defined_names or set[any]()
                );
            }
            edges.append(
                EdgeInfo(
                    "CALLS", caller, target, file_path, child.start_point[0] + 1, extra=call_extra
                ),
            );
        }

        return False;
    }

    static def _get_js_member_call_name(`node) -> Optional[str] {
        callee: any = `node.child_by_field_name("function");
        if callee is None and `node.children {
            callee = `node.children[0];
        }
        if callee is None or callee.type != "member_expression" {
            return None;
        }
        return CodeParser._get_js_static_member_path(callee);
    }

    def _get_member_call_receiver_method(
        `node, language: str
    ) -> tuple[Optional[str], Optional[str]] {
        child: any;
        if language == "php"
            and `node.type in ("member_call_expression", "nullsafe_member_call_expression")
        {
            receiver: any = `node.child_by_field_name("object");
            method: any = `node.child_by_field_name("name");
            if method is None {
                return (None, None);
            }
            method_name: any = method.text.decode("utf-8", errors="replace");
            if receiver is None or receiver.type != "variable_name" {
                return (None, method_name);
            }
            return (receiver.text.decode("utf-8", errors="replace"), method_name);
        }

        if language == "rust" and `node.type == "call_expression" {
            callee: any = `node.child_by_field_name("function");
            while callee is not None and callee.type == "generic_function" {
                callee = callee.child_by_field_name("function");
            }
            if callee is None or callee.type != "field_expression" {
                return (None, None);
            }
            receiver = callee.child_by_field_name("value");
            method = callee.child_by_field_name("field");
            if receiver is None or method is None {
                return (None, None);
            }
            return (
                receiver.text.decode("utf-8", errors="replace"),
                method.text.decode("utf-8", errors="replace"),
            );
        }

        if language == "go" and `node.type == "call_expression" {
            callee = `node.child_by_field_name("function");
            if callee is None or callee.type != "selector_expression" {
                return (None, None);
            }
            receiver = callee.child_by_field_name("operand");
            method = callee.child_by_field_name("field");
            if receiver is None or method is None {
                return (None, None);
            }
            while receiver.type == "parenthesized_expression" {
                if len(receiver.named_children) != 1 {
                    break;
                }
                receiver = receiver.named_children[0];
            }
            if receiver.type == "unary_expression"
                and receiver.children
                and receiver.children[0].type == "*"
            {
                receiver = receiver.child_by_field_name("operand") or receiver;
            }
            return (
                receiver.text.decode("utf-8", errors="replace"),
                method.text.decode("utf-8", errors="replace"),
            );
        }

        if language == "cpp" and `node.type == "call_expression" {
            callee = `node.child_by_field_name("function");
            if callee is None or callee.type != "field_expression" {
                return (None, None);
            }
            receiver = callee.child_by_field_name("argument");
            method = callee.child_by_field_name("field");
            if receiver is None or method is None {
                return (None, None);
            }
            return (
                receiver.text.decode("utf-8", errors="replace"),
                method.text.decode("utf-8", errors="replace"),
            );
        }

        if language == "java" and `node.type == "method_invocation" {
            (method, receiver) = self._get_java_method_and_receiver(`node) as any;
            return (receiver, method);
        }

        if language == "java" and `node.type == "method_reference" {
            named: any = [child for child in `node.children if child.is_named];
            if len(named) < 2 {
                return (None, None);
            }
            receiver_node: any = named[0];
            method_node: any = named[-1];
            if method_node.type not in ("identifier", "type_identifier") {
                return (None, None);
            }
            receiver = receiver_node.text.decode("utf-8", errors="replace");
            method = method_node.text.decode("utf-8", errors="replace");
            return (receiver, method);
        }

        if language == "csharp" {
            if `node.type != "invocation_expression" {
                return (None, None);
            }
            return self._get_csharp_receiver_method(`node);
        }

        callee = `node.child_by_field_name("function");
        if callee is None and `node.children {
            callee = `node.children[0];
        }
        if callee is None {
            return (None, None);
        }

        if language == "kotlin" and callee.type == "navigation_expression" {
            receiver = next(
                (child.text.decode("utf-8", errors="replace")
                for child in callee.children
                if child.type == "simple_identifier"),
                None,
            );
            method = None;
            for child in callee.children {
                if child.type != "navigation_suffix" {
                    continue;
                }
                method = next(
                    (part.text.decode("utf-8", errors="replace")
                    for part in child.children
                    if part.type == "simple_identifier"),
                    None,
                );
            }
            return (receiver, method);
        }

        if callee.type not in ("attribute", "member_expression") {
            return (None, None);
        }
        object_node: any = callee.child_by_field_name("object");
        property_node: any = callee.child_by_field_name("attribute")
            or callee.child_by_field_name("property");
        if object_node is None or property_node is None {
            return (None, None);
        }

        method = property_node.text.decode("utf-8", errors="replace");
        if object_node.type in ("identifier", "simple_identifier", "self", "this") {
            return (object_node.text.decode("utf-8", errors="replace"), method);
        }

        if object_node.type in ("attribute", "member_expression") {
            `root: any = object_node.child_by_field_name("object");
            field_node: any = object_node.child_by_field_name("attribute")
                or object_node.child_by_field_name("property");
            if `root is not None
                and field_node is not None
                and `root.type in ("identifier", "self", "this")
                and `root.text in (b"self", b"this")
            {
                return (field_node.text.decode("utf-8", errors="replace"), method);
            }
        }

        return (None, method);
    }

    static def _get_csharp_receiver_method(`node) -> tuple[Optional[str], Optional[str]] {
        callee: any = `node.child_by_field_name("function");
        if callee is None and `node.children {
            callee = `node.children[0];
        }
        if callee is None {
            return (None, None);
        }

        if callee.type == "member_access_expression" {
            name_node: any = callee.child_by_field_name("name");
            if name_node is None {
                return (None, None);
            }
            method: any = _csharp_name(name_node);
            receiver_node: any = callee.child_by_field_name("expression");
            if receiver_node is None {
                return (None, method);
            }
            if receiver_node.type in ("identifier", "this", "this_expression") {
                return (_csharp_name(receiver_node), method);
            }
            if receiver_node.type == "member_access_expression" {
                `root: any = receiver_node.child_by_field_name("expression");
                field_node: any = receiver_node.child_by_field_name("name");
                if `root is not None
                    and field_node is not None
                    and `root.type in ("this", "this_expression")
                {
                    return (_csharp_name(field_node), method);
                }
            }
            pending: any = [receiver_node];
            while pending {
                part: any = pending.pop();
                if part.type
                    not in (
                        "identifier",
                        "member_access_expression",
                        "qualified_name",
                        "alias_qualified_name",
                        "comment",
                    )
                {
                    break;
                }
                pending.extend(part.named_children);
            } else {
                return (_csharp_name(receiver_node), method);
            }
            return (None, method);
        }

        if callee.type == "conditional_access_expression" {
            bindings: any = [
                child
                for child in callee.children
                if child.type == "member_binding_expression"
            ];
            if not bindings {
                return (None, None);
            }
            name_node = bindings[-1].child_by_field_name("name");
            if name_node is None {
                return (None, None);
            }
            method = _csharp_name(name_node);
            receiver_node = callee.child_by_field_name("condition");
            named_children: any = [child for child in callee.children if child.is_named];
            if receiver_node is not None
                and receiver_node.type == "identifier"
                and len(named_children) == 2
            {
                return (_csharp_name(receiver_node), method);
            }
            return (None, method);
        }

        return (None, None);
    }

    def _resolve_php_scoped_calls(
        `root, nodes: list[NodeInfo], edges: list[EdgeInfo], file_path: str
    ) -> list[EdgeInfo] {
        methods: dict[tuple[str, str], list[str]];
        resolutions: dict[tuple[int, str, str], tuple[str, str]];
        methods = {};
        for `node in nodes {
            if `node.language != "php"
                or `node.kind not in ("Function", "Test")
                or not `node.parent_name
            {
                continue;
            }
            key: any = (`node.parent_name.casefold(), `node.name.casefold());
            methods.setdefault(key, []).append(
                self._qualify(`node.name, file_path, `node.parent_name)
            );
        }

        def same_file_target(class_name: str, method: str) -> Optional[str] {
            candidates: any = methods.get((class_name.casefold(), method.casefold()), []);
            return candidates[0] if len(candidates) == 1 else None;
        }

        def resolve_target(
            scope: str,
            method: str,
            namespace: str,
            imports: dict[str, str],
            enclosing_class: Optional[str],
        ) -> tuple[Optional[str], Optional[str]] {
            normalized: any = scope.strip("\\");
            lowered: any = normalized.casefold();
            if lowered in ("self", "static") {
                if not enclosing_class {
                    return (None, None);
                }
                return (same_file_target(enclosing_class, method), "enclosing_class");
            }
            if lowered == "parent" {
                return (None, None);
            }

            if "\\" not in normalized {
                local: any = same_file_target(normalized, method);
                if local is not None {
                    return (local, "same_file");
                }
            }

            head: any = normalized.partition("\\")[0];
            imported: any = imports.get(head.casefold());
            absolute: any = scope.startswith("\\");
            if imported {
                qualified: any = self._php_resolve_class_reference(scope, namespace, imports);
                evidence: any = "import";
            } elif absolute {
                qualified = normalized;
                evidence = "fully_qualified";
            } elif "\\" in normalized {
                qualified = self._php_resolve_class_reference(scope, namespace, imports);
                evidence = "qualified";
            } elif namespace {
                qualified = f"{namespace}\\{normalized}";
                evidence = "same_namespace";
            } else {
                return (None, None);
            }

            resolved_file: any = self._resolve_module_to_file(qualified, file_path, "php");
            if resolved_file is None {
                return (None, None);
            }
            class_name: any = qualified.rsplit("\\", 1)[-1];
            return (f"{self._qualify(class_name, resolved_file, None)}.{method}", evidence);
        }

        resolutions = {};

        def walk_node(
            `node,
            namespace: str,
            imports: dict[str, str],
            enclosing_class: Optional[str],
            enclosing_func: Optional[str],
            depth: int = 0,
        ) {
            if depth > self._MAX_AST_DEPTH {
                return;
            }
            if `node.type in self._class_types["php"] {
                class_name: any = self._get_name(`node, "php", "class");
                child: any;
                for child in `node.children {
                    walk_node(
                        child, namespace, imports, class_name or enclosing_class, None, depth + 1
                    );
                }
                return;
            }

            if `node.type in self._function_types["php"] {
                function_name: any = self._get_name(`node, "php", "function");
                for child in `node.children {
                    walk_node(
                        child,
                        namespace,
                        imports,
                        enclosing_class,
                        function_name or enclosing_func,
                        depth + 1,
                    );
                }
                return;
            }

            scope: any;
            method: any;
            (scope, method) = self._php_scoped_call_parts(`node) as any;
            if scope and method {
                target: any;
                evidence: any;
                (target, evidence) = resolve_target(
                    scope, method, namespace, imports, enclosing_class
                ) as any;
                if target is not None and evidence is not None {
                    stable_scope: any = scope.lstrip("\\");
                    source_name: any = self._qualify(enclosing_func, file_path, enclosing_class)
                        if enclosing_func
                        else file_path;
                    resolutions[`node.start_point[0]
                        + 1, source_name, f"{stable_scope}::{method}"] = (target, evidence);
                }
            }

            for child in `node.children {
                walk_node(child, namespace, imports, enclosing_class, enclosing_func, depth + 1);
            }
        }

        def walk_sequence(container, namespace: str = "", depth: int = 0) {
            if depth > self._MAX_AST_DEPTH {
                return;
            }
            current_namespace: any = namespace;
            imports: dict[str, str] = {};
            for child in container.children {
                if child.type == "namespace_definition" {
                    child_namespace: any = self._php_namespace_name(child);
                    block: any = next(
                        (part for part in child.children if part.type == "compound_statement"), None
                    );
                    if block is not None {
                        walk_sequence(block, child_namespace, depth + 1);
                    } else {
                        current_namespace = child_namespace;
                        imports = {};
                    }
                    continue;
                }
                if child.type == "namespace_use_declaration" {
                    imports.update(self._php_import_bindings(child));
                    continue;
                }
                walk_node(
                    child,
                    current_namespace,
                    imports,
                    enclosing_class=None,
                    enclosing_func=None,
                    depth=depth + 1,
                );
            }
        }

        walk_sequence(`root);
        if not resolutions {
            return edges;
        }

        resolved: list[EdgeInfo] = [];
        for `edge in edges {
            resolution: any = resolutions.get((`edge.line, `edge.source, `edge.target));
            if `edge.kind != "CALLS" or resolution is None {
                resolved.append(`edge);
                continue;
            }
            target: any;
            evidence: any;
            (target, evidence) = resolution as any;
            extra: any = `dict(`edge.extra);
            extra["scoped_resolution"] = evidence;
            resolved.append(
                EdgeInfo(`edge.kind, `edge.source, target, `edge.file_path, `edge.line, extra=extra)
            );
        }
        return resolved;
    }

    def _extract_php_laravel_edges(
        `root, file_path: str, nodes: list[NodeInfo], edges: list[EdgeInfo]
    ) {
        self._walk_php_laravel_sequence(`root, file_path, nodes, edges, namespace="");
    }

    def _walk_php_laravel_sequence(
        container, file_path: str, nodes: list[NodeInfo], edges: list[EdgeInfo], namespace: str
    ) {
        current_namespace: any = namespace;
        imports: dict[str, str] = {};

        for child in container.children {
            if child.type == "namespace_definition" {
                child_namespace: any = self._php_namespace_name(child);
                block: any = next(
                    (part for part in child.children if part.type == "compound_statement"), None
                );
                if block is not None {
                    self._walk_php_laravel_sequence(
                        block, file_path, nodes, edges, namespace=child_namespace
                    );
                } else {
                    current_namespace = child_namespace;
                    imports = {};
                }
                continue;
            }

            if child.type == "namespace_use_declaration" {
                imports.update(self._php_import_bindings(child));
                continue;
            }

            self._walk_php_laravel_node(
                child,
                file_path,
                nodes,
                edges,
                current_namespace,
                imports,
                enclosing_class=None,
                enclosing_func=None,
                eloquent_model=False,
            );
        }
    }

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
    ) {
        if `node.type in self._class_types["php"] {
            class_name: any = self._get_name(`node, "php", "class");
            is_eloquent: any = operator.eq(`node.type, "class_declaration")
                and self._php_class_extends_eloquent_model(`node, namespace, imports);
            child: any;
            for child in `node.children {
                self._walk_php_laravel_node(
                    child,
                    file_path,
                    nodes,
                    edges,
                    namespace,
                    imports,
                    enclosing_class=class_name,
                    enclosing_func=None,
                    eloquent_model=is_eloquent,
                );
            }
            return;
        }

        if `node.type in self._function_types["php"] {
            function_name: any = self._get_name(`node, "php", "function");
            for child in `node.children {
                self._walk_php_laravel_node(
                    child,
                    file_path,
                    nodes,
                    edges,
                    namespace,
                    imports,
                    enclosing_class=enclosing_class,
                    enclosing_func=function_name or enclosing_func,
                    eloquent_model=eloquent_model,
                );
            }
            return;
        }

        if `node.type == "scoped_call_expression" {
            self._emit_laravel_route_edge(
                `node, file_path, edges, namespace, imports, enclosing_class, enclosing_func
            );
            self._emit_laravel_endpoint_nodes(`node, file_path, nodes, edges, namespace, imports);
        } elif `node.type == "member_call_expression" {
            if eloquent_model {
                self._emit_laravel_relationship_edge(
                    `node, file_path, edges, namespace, imports, enclosing_class, enclosing_func
                );
            }
            self._emit_laravel_endpoint_nodes(`node, file_path, nodes, edges, namespace, imports);
        }

        for child in `node.children {
            self._walk_php_laravel_node(
                child,
                file_path,
                nodes,
                edges,
                namespace,
                imports,
                enclosing_class,
                enclosing_func,
                eloquent_model,
            );
        }
    }

    static def _php_namespace_name(`node) -> str {
        for child in `node.children {
            if child.type == "namespace_name" {
                return child.text.decode("utf-8", errors="replace").strip("\\");
            }
        }
        return "";
    }

    static def _php_import_bindings(`node) -> dict[str, str] {
        child: any;
        statement: any = `node.text.decode("utf-8", errors="replace").lstrip();
        lowered: any = statement.casefold();
        if lowered.startswith("use function ") or lowered.startswith("use const ") {
            return {};
        }

        group: any = next(
            (child for child in `node.children if child.type == "namespace_use_group"), None
        );
        prefix: any = "";
        if group is not None {
            for child in `node.children {
                if child.type == "namespace_name" {
                    prefix = child.text.decode("utf-8", errors="replace").strip("\\");
                    break;
                }
            }
            clauses: any = [
                child
                for child in group.children
                if child.type == "namespace_use_clause"
            ];
        } else {
            clauses = [child for child in `node.children if child.type == "namespace_use_clause"];
        }

        bindings: dict[str, str] = {};
        for clause in clauses {
            imported: Optional[str] = None;
            alias: Optional[str] = None;
            seen_alias: any = False;
            for child in clause.children {
                if child.type == "as" {
                    seen_alias = True;
                    continue;
                }
                if imported is None and child.type in ("qualified_name", "name") {
                    imported = child.text.decode("utf-8", errors="replace").strip("\\");
                    continue;
                }
                if seen_alias and child.type == "name" {
                    alias = child.text.decode("utf-8", errors="replace");
                }
            }
            if not imported {
                continue;
            }
            qualified: any = f"{prefix}\\{imported}" if prefix else imported;
            local_name: any = alias or qualified.rsplit("\\", 1)[-1];
            bindings[local_name.casefold()] = qualified;
        }
        return bindings;
    }

    static def _php_resolve_class_reference(
        reference: str, namespace: str, imports: dict[str, str]
    ) -> str {
        absolute: any = reference.startswith("\\");
        normalized: any = reference.strip("\\");
        if not normalized {
            return "";
        }
        if absolute {
            return normalized;
        }

        head: any;
        separator: any;
        tail: any;
        (head, separator, tail) = normalized.partition("\\") as any;
        imported: any = imports.get(head.casefold());
        if imported {
            return f"{imported}\\{tail}" if separator else imported;
        }
        if namespace {
            return f"{namespace}\\{normalized}";
        }
        return normalized;
    }

    def _php_class_extends_eloquent_model(`node, namespace: str, imports: dict[str, str]) -> bool {
        for base in self._get_bases(`node, "php", b"") {
            resolved: any = self._php_resolve_class_reference(base, namespace, imports);
            if resolved.casefold() == self._LARAVEL_ELOQUENT_MODEL.casefold() {
                return True;
            }
        }
        return False;
    }

    static def _php_scoped_call_parts(`node) -> tuple[Optional[str], Optional[str]] {
        if `node.type != "scoped_call_expression" {
            return (None, None);
        }
        scope: any = `node.child_by_field_name("scope");
        name: any = `node.child_by_field_name("name");
        if scope is None or name is None {
            return (None, None);
        }
        receiver: any = scope.text.decode("utf-8", errors="replace");
        method: any = name.text.decode("utf-8", errors="replace");
        return (receiver or None, method or None);
    }

    static def _php_class_constant_reference(`node) -> Optional[str] {
        class_reference: Optional[str] = None;
        constant: Optional[str] = None;
        for child in `node.children {
            if class_reference is None and child.type in ("name", "qualified_name") {
                class_reference = child.text.decode("utf-8", errors="replace");
            } elif child.type == "name" {
                constant = child.text.decode("utf-8", errors="replace");
            }
        }
        if class_reference and constant and constant.casefold() == "class" {
            return class_reference;
        }
        return None;
    }

    def _php_route_handler(`node) -> Optional[tuple[str, str]] {
        arguments: any = next(
            (child for child in `node.children if child.type == "arguments"), None
        );
        if arguments is None {
            return None;
        }
        args: any = [child for child in arguments.children if child.type == "argument"];
        if len(args) < 2 {
            return None;
        }
        array: any = next(
            (child for child in args[1].children if child.type == "array_creation_expression"), None
        );
        if array is None {
            return None;
        }
        elements: any = [
            child
            for child in array.children
            if child.type == "array_element_initializer"
        ];
        if len(elements) != 2 {
            return None;
        }

        class_access: any = next(
            (child
            for child in elements[0].children
            if child.type == "class_constant_access_expression"),
            None,
        );
        method_string: any = next(
            (child
            for child in elements[1].children
            if child.type in ("string", "encapsed_string")),
            None,
        );
        if class_access is None or method_string is None {
            return None;
        }
        class_reference: any = self._php_class_constant_reference(class_access);
        method: any = method_string.text.decode("utf-8", errors="replace").strip("'\"");
        if not class_reference or re.fullmatch("[A-Za-z_][A-Za-z0-9_]*", method) is None {
            return None;
        }
        return (class_reference, method);
    }

    static def _php_route_arguments(`node) -> list {
        arguments: any = next((c for c in `node.children if c.type == "arguments"), None);
        return [c for c in arguments.children if c.type == "argument"] if arguments else [];
    }

    static def _php_string_literal(value) -> Optional[str] {
        if value is None {
            return None;
        }
        if value.type == "encapsed_string"
            and `any(c.is_named and operator.ne(c.type, "string_content") for c in value.children)
        {
            return None;
        }
        if value.type not in ("string", "encapsed_string") {
            return None;
        }
        text: any = value.text.decode("utf-8", errors="replace");
        if value.type == "string" and text.startswith("'") {
            return re.sub("\\\\([\\\\'])", "\\1", text[1:-1]);
        }
        return text[1:-1];
    }

    class def _php_route_literal(`node) -> Optional[str] {
        return cls._php_string_literal(next((c for c in `node.children if c.is_named), None));
    }

    def _php_route_facade_call(`node, namespace: str, imports: dict[str, str]) -> Optional[str] {
        receiver: any;
        method: any;
        (receiver, method) = self._php_scoped_call_parts(`node) as any;
        if not receiver or not method {
            return None;
        }
        resolved: any = self._php_resolve_class_reference(receiver, namespace, imports);
        return method if resolved.casefold() == self._LARAVEL_ROUTE_FACADE.casefold() else None;
    }

    def _php_route_group_settings(
        call, namespace: str, imports: dict[str, str]
    ) -> Optional[tuple[str, Optional[str]]] {
        prefix: any = "";
        controller: any = None;
        chain: any = [];
        current: any = call;
        while current.type == "member_call_expression" {
            name: any = current.child_by_field_name("name");
            if name is None {
                return None;
            }
            chain.append((name.text.decode("utf-8"), self._php_route_arguments(current)));
            current = current.child_by_field_name("object");
            if current is None {
                return None;
            }
        }
        base: any = self._php_route_facade_call(current, namespace, imports);
        if base is None {
            return None;
        }
        chain.append((base, self._php_route_arguments(current)));
        for (method, args) in reversed(chain) {
            if method == "prefix" {
                if not args or (part := self._php_route_literal(args[0])) is None {
                    return None;
                }
                prefix = self._join_spring_route(prefix, part);
            } elif method == "controller" {
                if not args {
                    return None;
                }
                access: any = next(
                    (c for c in args[0].children if c.type == "class_constant_access_expression"),
                    None,
                );
                controller = self._php_class_constant_reference(access) if access else None;
                if controller is None {
                    return None;
                }
            } elif method == "group" and len(args) > 1 {
                options: any = next((c for c in args[0].children if c.is_named), None);
                if options is None or options.type != "array_creation_expression" {
                    return None;
                }
                for item in options.children {
                    if item.type != "array_element_initializer" {
                        continue;
                    }
                    values: any = [c for c in item.children if c.is_named];
                    if len(values) != 2 {
                        return None;
                    }
                    key: any = self._php_string_literal(values[0]);
                    if key is None {
                        return None;
                    }
                    if key == "prefix" {
                        part = self._php_string_literal(values[1]);
                        if part is None {
                            return None;
                        }
                        prefix = self._join_spring_route(prefix, part);
                    } elif key == "controller" {
                        controller = self._php_class_constant_reference(values[1])
                            if values[1].type == "class_constant_access_expression"
                            else None;
                        if controller is None {
                            return None;
                        }
                    }
                }
            }
        }
        return (prefix, controller);
    }

    def _php_route_enclosing_groups(
        `node, namespace: str, imports: dict[str, str]
    ) -> Optional[tuple[str, Optional[str]]] {
        groups: any = [];
        current: any = `node.parent;
        while current is not None {
            if current.type in ("anonymous_function", "arrow_function") {
                argument: any = current.parent;
                if argument is not None and argument.type == "argument" {
                    arguments: any = argument.parent;
                    call: any = arguments.parent if arguments is not None else None;
                    if call is not None
                        and call.type in ("scoped_call_expression", "member_call_expression")
                    {
                        name: any = call.child_by_field_name("name");
                        if name is not None and name.text == b"group" {
                            settings: any = self._php_route_group_settings(
                                call, namespace, imports
                            );
                            if settings is None {
                                return None;
                            }
                            groups.append(settings);
                        }
                    }
                }
            }
            current = current.parent;
        }
        prefix: any = "";
        controller: any = None;
        for (group_prefix, group_controller) in reversed(groups) {
            prefix = self._join_spring_route(prefix, group_prefix);
            controller = group_controller or controller;
        }
        return (prefix, controller);
    }

    def _php_endpoint_handler(
        argument, group_controller: Optional[str]
    ) -> Optional[tuple[str, str]] {
        value: any = next((c for c in argument.children if c.is_named), None);
        if value is None {
            return None;
        }
        if value.type == "class_constant_access_expression" {
            controller: any = self._php_class_constant_reference(value);
            return (controller, "__invoke") if controller else None;
        }
        if value.type in ("string", "encapsed_string") {
            literal: any = self._php_route_literal(argument);
            if literal is None {
                return None;
            }
            if "@" in literal {
                class_name: any;
                method: any;
                (class_name, method) = literal.rsplit("@", 1) as any;
                controller = "\\" + class_name.lstrip("\\") if class_name.strip("\\") else None;
            } else {
                (controller, method) = (group_controller, literal);
            }
            if controller and re.fullmatch("[A-Za-z_][A-Za-z0-9_]*", method) {
                return (controller, method);
            }
            return None;
        }
        if value.type != "array_creation_expression" {
            return None;
        }
        elements: any = [c for c in value.children if c.type == "array_element_initializer"];
        if len(elements) != 2 {
            return None;
        }
        access: any = next(
            (c for c in elements[0].children if c.type == "class_constant_access_expression"), None
        );
        controller = self._php_class_constant_reference(access) if access else None;
        method = self._php_route_literal(elements[1]);
        if controller and method and re.fullmatch("[A-Za-z_][A-Za-z0-9_]*", method) {
            return (controller, method);
        }
        return None;
    }

    def _emit_laravel_endpoint_nodes(
        `node,
        file_path: str,
        nodes: list[NodeInfo],
        edges: list[EdgeInfo],
        namespace: str,
        imports: dict[str, str],
    ) {
        if Path(file_path).parent.name != "routes" {
            return;
        }
        fluent_prefix: any;
        fluent_controller: any;
        (fluent_prefix, fluent_controller) = ("", None);
        if `node.type == "member_call_expression" {
            name_node: any = `node.child_by_field_name("name");
            verb: any = name_node.text.decode("utf-8") if name_node is not None else None;
        } else {
            verb = self._php_route_facade_call(`node, namespace, imports);
        }
        if verb not in self._LARAVEL_ROUTE_VERBS or verb in {"resource", "apiResource"} {
            return;
        }
        if `node.type == "member_call_expression" {
            fluent: any = self._php_route_group_settings(`node, namespace, imports);
            if fluent is None {
                return;
            }
            (fluent_prefix, fluent_controller) = fluent as any;
        }
        args: any = self._php_route_arguments(`node);
        path_index: any = 1 if verb == "match" else 0;
        if len(args) <= path_index + 1 {
            return;
        }
        path: any = self._php_route_literal(args[path_index]);
        if path is None {
            return;
        }
        context: any = self._php_route_enclosing_groups(`node, namespace, imports);
        if context is None {
            return;
        }
        prefix: any = self._join_spring_route(context[0], fluent_prefix);
        group_controller: any = fluent_controller or context[1];
        handler: any = self._php_endpoint_handler(args[path_index + 1], group_controller);
        handler_value: any = next((c for c in args[path_index + 1].children if c.is_named), None);
        if handler is None
            and (
                handler_value is None
                or handler_value.type not in ("anonymous_function", "arrow_function")
            )
        {
            return;
        }
        methods: any = [verb.upper()];
        if verb == "match" {
            array: any = next(
                (c for c in args[0].children if c.type == "array_creation_expression"), None
            );
            if array is None {
                return;
            }
            methods = [];
            for item in array.children {
                if item.type == "array_element_initializer" {
                    method: any = self._php_route_literal(item);
                    if method is None {
                        return;
                    }
                    methods.append(method.upper());
                }
            }
        }
        route: any = self._join_spring_route(prefix, path);
        current: any = `node;
        while current.parent is not None
            and current.parent.type == "member_call_expression"
            and current.parent.child_by_field_name("object") == current
        {
            current = current.parent;
            name: any = current.child_by_field_name("name");
            if name is not None and name.text == b"prefix" {
                chain_args: any = self._php_route_arguments(current);
                part: any = self._php_route_literal(chain_args[0]) if chain_args else None;
                if part is None {
                    return;
                }
                route = self._join_spring_route(part, route);
            }
        }
        handler_name: any = handler[1] if handler else "closure";
        for method in dict.fromkeys(methods) {
            name = f"{handler_name}@Route {method} {route}";
            metadata: any = {"http_method": method, "route": route, "handler": handler_name};
            nodes.append(
                NodeInfo(
                    "Endpoint",
                    name,
                    file_path,
                    `node.start_point[0] + 1,
                    `node.end_point[0] + 1,
                    language="php",
                    extra=metadata,
                ),
            );
            if handler {
                edges.append(
                    EdgeInfo(
                        "HANDLES",
                        self._php_semantic_target(
                            handler[0], namespace, imports, file_path, handler[1]
                        ),
                        self._qualify(name, file_path, None),
                        file_path,
                        `node.start_point[0] + 1,
                        extra=metadata,
                    ),
                );
            }
        }
    }

    def _php_semantic_target(
        class_reference: str,
        namespace: str,
        imports: dict[str, str],
        file_path: str,
        method: Optional[str] = None,
    ) -> str {
        qualified_class: any = self._php_resolve_class_reference(
            class_reference, namespace, imports
        );
        short_name: any = qualified_class.rsplit("\\", 1)[-1];
        resolved_file: any = self._resolve_module_to_file(qualified_class, file_path, "php");
        if resolved_file {
            target: any = f"{resolved_file}::{short_name}";
        } else {
            target = short_name;
        }
        return f"{target}.{method}" if method else target;
    }

    def _php_laravel_caller(
        file_path: str, enclosing_class: Optional[str], enclosing_func: Optional[str]
    ) -> str {
        if enclosing_func {
            return self._qualify(enclosing_func, file_path, enclosing_class);
        }
        if enclosing_class {
            return self._qualify(enclosing_class, file_path, None);
        }
        return file_path;
    }

    def _emit_laravel_route_edge(
        `node,
        file_path: str,
        edges: list[EdgeInfo],
        namespace: str,
        imports: dict[str, str],
        enclosing_class: Optional[str],
        enclosing_func: Optional[str],
    ) {
        receiver: any;
        verb: any;
        (receiver, verb) = self._php_scoped_call_parts(`node) as any;
        if not receiver or verb not in self._LARAVEL_ROUTE_VERBS {
            return;
        }
        resolved_receiver: any = self._php_resolve_class_reference(receiver, namespace, imports);
        if resolved_receiver.casefold() != self._LARAVEL_ROUTE_FACADE.casefold() {
            return;
        }
        handler: any = self._php_route_handler(`node);
        if handler is None {
            return;
        }
        controller: any;
        method: any;
        (controller, method) = handler as any;
        edges.append(
            EdgeInfo(
                "CALLS",
                self._php_laravel_caller(file_path, enclosing_class, enclosing_func),
                self._php_semantic_target(controller, namespace, imports, file_path, method),
                file_path,
                `node.start_point[0] + 1,
                extra={"framework": "laravel", "laravel_kind": "route", "route_verb": verb},
            ),
        );
    }

    def _emit_laravel_relationship_edge(
        `node,
        file_path: str,
        edges: list[EdgeInfo],
        namespace: str,
        imports: dict[str, str],
        enclosing_class: Optional[str],
        enclosing_func: Optional[str],
    ) {
        if not `node.children or `node.children[0].type != "variable_name" {
            return;
        }
        receiver: any = `node.children[0].text.decode("utf-8", errors="replace");
        if receiver != "$this" {
            return;
        }
        method_node: any = next(
            (child for child in reversed(`node.children) if child.type == "name"), None
        );
        if method_node is None {
            return;
        }
        relationship: any = method_node.text.decode("utf-8", errors="replace");
        if relationship not in self._LARAVEL_RELATIONSHIPS {
            return;
        }

        arguments: any = next(
            (child for child in `node.children if child.type == "arguments"), None
        );
        if arguments is None {
            return;
        }
        first_argument: any = next(
            (child for child in arguments.children if child.type == "argument"), None
        );
        if first_argument is None {
            return;
        }
        class_access: any = next(
            (child
            for child in first_argument.children
            if child.type == "class_constant_access_expression"),
            None,
        );
        if class_access is None {
            return;
        }
        target_model: any = self._php_class_constant_reference(class_access);
        if target_model is None {
            return;
        }

        edges.append(
            EdgeInfo(
                "REFERENCES",
                self._php_laravel_caller(file_path, enclosing_class, enclosing_func),
                self._php_semantic_target(target_model, namespace, imports, file_path),
                file_path,
                `node.start_point[0] + 1,
                extra={
                    "framework": "laravel",
                    "laravel_kind": "eloquent_relationship",
                    "relationship": relationship,
                },
            ),
        );
    }

    static def _get_java_method_and_receiver(`node) -> tuple[Optional[str], Optional[str]] {
        children: any = `node.children;
        if len(children) == 2
            and children[0].type == "identifier"
            and children[-1].type == "argument_list"
        {
            return (children[0].text.decode("utf-8", errors="replace"), None);
        }
        if len(children) < 3 {
            return (None, None);
        }
        method_name: Optional[str] = None;
        receiver_name: Optional[str] = None;
        for i in range(len(children) - 1, -1, -1) {
            ch: any = children[i];
            if ch.type == "argument_list" {
                continue;
            }
            if ch.type == "identifier" {
                if method_name is None {
                    method_name = ch.text.decode("utf-8", errors="replace");
                } else {
                    receiver_name = ch.text.decode("utf-8", errors="replace");
                }
                break;
            }
            if ch.type == "." {
                continue;
            }
            break;
        }
        if method_name and children[0].type == "identifier" {
            first_text: any = children[0].text.decode("utf-8", errors="replace");
            if first_text != method_name {
                receiver_name = first_text;
            }
        } elif method_name and children[0].type == "field_access" {
            owner: any = children[0].child_by_field_name("object");
            field: any = children[0].child_by_field_name("field");
            if owner is not None and owner.type == "this" and field is not None {
                receiver_name = field.text.decode("utf-8", errors="replace");
            }
        } elif method_name and children[0].type == "this" and children[1].type == "." {
            receiver_name = "this";
        }

        return (method_name, receiver_name);
    }

    static def _java_this_field_call(`node) -> bool {
        receiver: any = `node.child_by_field_name("object");
        if receiver is None or receiver.type != "field_access" {
            return False;
        }
        owner: any = receiver.child_by_field_name("object");
        return owner is not None and operator.eq(owner.type, "this");
    }

    class def _java_expression_receiver(`node) -> bool {
        if `node.type != "method_invocation" {
            return False;
        }
        receiver: any = `node.child_by_field_name("object");
        return receiver is not None
            and receiver.type not in ("identifier", "this", "super", "object_creation_expression")
            and not cls._java_this_field_call(`node);
    }

    def _extract_jsx_component_call(
        child,
        language: str,
        file_path: str,
        edges: list[EdgeInfo],
        enclosing_class: Optional[str],
        enclosing_func: Optional[str],
        import_map: Optional[dict[str, str]],
        defined_names: Optional[set[str]],
    ) {
        target: any = self._resolve_jsx_component_target(
            child, language, file_path, import_map or {}, defined_names or set[any]()
        );
        if not target {
            return;
        }

        caller: any = self._qualify(enclosing_func, file_path, enclosing_class)
            if enclosing_func
            else file_path;
        edges.append(EdgeInfo("CALLS", caller, target, file_path, child.start_point[0] + 1));
    }

    def _resolve_jsx_component_target(
        `node, language: str, file_path: str, import_map: dict[str, str], defined_names: set[str]
    ) -> Optional[str] {
        component_ref: any = self._get_jsx_component_reference(`node);
        if component_ref is None {
            return None;
        }

        base_name: any;
        component_name: any;
        (base_name, component_name) = component_ref as any;
        if base_name is None {
            return self._resolve_call_target(
                component_name, file_path, language, import_map, defined_names
            );
        }

        if base_name in import_map {
            resolved: any = self._resolve_imported_symbol(
                component_name, import_map[base_name], file_path, language
            );
            if resolved {
                return resolved;
            }
        }

        return component_name;
    }

    static has _PAIR_TYPES: any = frozenset({"pair"});

    static has _ARRAY_TYPES: any = frozenset({"array", "list"});

    static has _ARGUMENTS_TYPES: any = frozenset({"arguments", "argument_list"});

    static has _VALUE_REF_SKIP_NAMES: any = frozenset(
        ("true false null undefined None True False self this cls super").split()
    );

    def _extract_ts_type_reference(
        child,
        language: str,
        file_path: str,
        edges: list[EdgeInfo],
        enclosing_class: Optional[str],
        enclosing_func: Optional[str],
        import_map: Optional[dict[str, str]],
        defined_names: Optional[set[str]],
    ) {
        parent: any = child.parent;
        if parent is not None {
            if parent.type in _TS_TYPE_DECLARATIONS {
                name_node: any = parent.child_by_field_name("name");
                if name_node is not None
                    and name_node.start_byte == child.start_byte
                    and name_node.end_byte == child.end_byte
                {
                    return;
                }
            }
            ancestor: any = parent;
            inside_type_arguments: any = False;
            while ancestor is not None {
                if ancestor.type == "type_arguments" {
                    inside_type_arguments = True;
                }
                if ancestor.type in _TS_HERITAGE_CLAUSES {
                    if not inside_type_arguments {
                        return;
                    }
                    break;
                }
                if ancestor.type in _TS_TYPE_DECLARATIONS {
                    break;
                }
                ancestor = ancestor.parent;
            }
        }
        if enclosing_func {
            caller: any = self._qualify(enclosing_func, file_path, enclosing_class);
        } elif enclosing_class {
            caller = self._qualify(enclosing_class, file_path, None);
        } else {
            caller = file_path;
        }

        self._emit_reference_if_known(
            child.text.decode("utf-8", errors="replace"),
            language,
            file_path,
            caller,
            edges,
            import_map or {},
            defined_names or set[any](),
            line=child.start_point[0] + 1,
        );
    }

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
    ) {
        imap: any = import_map or {};
        dnames: any = defined_names or set[any]();
        if enclosing_func {
            caller: any = self._qualify(enclosing_func, file_path, enclosing_class);
        } else {
            caller = file_path;
        }
        if node_type in self._PAIR_TYPES {
            self._ref_from_pair(child, source, language, file_path, caller, edges, imap, dnames);
            return;
        }
        if node_type == "shorthand_property_identifier"
            and language in ("javascript", "typescript", "tsx")
        {
            name: any = child.text.decode("utf-8", errors="replace");
            self._emit_reference_if_known(
                name,
                language,
                file_path,
                caller,
                edges,
                imap,
                dnames,
                line=child.start_point[0] + 1,
            );
            return;
        }
        if node_type in ("assignment_expression", "augmented_assignment", "assignment") {
            self._ref_from_assignment(
                child, source, language, file_path, caller, edges, imap, dnames
            );
            return;
        }
        if node_type in self._ARRAY_TYPES {
            self._ref_from_array(child, source, language, file_path, caller, edges, imap, dnames);
            return;
        }
        if node_type in self._ARGUMENTS_TYPES {
            self._ref_from_arguments(
                child, source, language, file_path, caller, edges, imap, dnames
            );
        }
    }

    def _emit_reference_if_known(
        name: str,
        language: str,
        file_path: str,
        caller: str,
        edges: list[EdgeInfo],
        import_map: dict[str, str],
        defined_names: set[str],
        line: int = 0,
    ) {
        if not name or name in self._VALUE_REF_SKIP_NAMES {
            return;
        }
        if name.isupper() or len(name) <= 1 {
            return;
        }
        if name not in defined_names and name not in import_map {
            return;
        }

        target: any = self._resolve_call_target(
            name, file_path, language, import_map, defined_names
        );
        edges.append(EdgeInfo("REFERENCES", caller, target, file_path, line));
    }

    def _ref_from_pair(
        pair_node,
        source: bytes,
        language: str,
        file_path: str,
        caller: str,
        edges: list[EdgeInfo],
        import_map: dict[str, str],
        defined_names: set[str],
    ) {
        children: any = pair_node.children;
        value_node: any = None;
        for ch in reversed(children) {
            if ch.type not in (":", ",", "comment") {
                value_node = ch;
                break;
            }
        }
        if value_node is None {
            return;
        }
        if value_node.type == "identifier" {
            name: any = value_node.text.decode("utf-8", errors="replace");
            self._emit_reference_if_known(
                name,
                language,
                file_path,
                caller,
                edges,
                import_map,
                defined_names,
                line=value_node.start_point[0] + 1,
            );
        }
    }

    def _ref_from_assignment(
        assign_node,
        source: bytes,
        language: str,
        file_path: str,
        caller: str,
        edges: list[EdgeInfo],
        import_map: dict[str, str],
        defined_names: set[str],
    ) {
        children: any = assign_node.children;
        if len(children) < 3 {
            return;
        }
        lhs: any = children[0];
        if lhs.type not in ("member_expression", "subscript_expression", "attribute", "subscript") {
            return;
        }
        rhs: any = None;
        for ch in reversed(children) {
            if ch.type not in ("=", ":", ",", "comment", "type_annotation") {
                rhs = ch;
                break;
            }
        }
        if rhs is None or rhs.type != "identifier" {
            return;
        }
        name: any = rhs.text.decode("utf-8", errors="replace");
        self._emit_reference_if_known(
            name,
            language,
            file_path,
            caller,
            edges,
            import_map,
            defined_names,
            line=rhs.start_point[0] + 1,
        );
    }

    def _ref_from_array(
        array_node,
        source: bytes,
        language: str,
        file_path: str,
        caller: str,
        edges: list[EdgeInfo],
        import_map: dict[str, str],
        defined_names: set[str],
    ) {
        for ch in array_node.children {
            if ch.type == "identifier" {
                name: any = ch.text.decode("utf-8", errors="replace");
                self._emit_reference_if_known(
                    name,
                    language,
                    file_path,
                    caller,
                    edges,
                    import_map,
                    defined_names,
                    line=ch.start_point[0] + 1,
                );
            }
        }
    }

    def _ref_from_arguments(
        args_node,
        source: bytes,
        language: str,
        file_path: str,
        caller: str,
        edges: list[EdgeInfo],
        import_map: dict[str, str],
        defined_names: set[str],
    ) {
        for ch in args_node.children {
            reference_node: any = ch;
            if ch.type == "keyword_argument" and language == "python" {
                reference_node = ch.child_by_field_name("value");
            }
            if reference_node is None or reference_node.type != "identifier" {
                continue;
            }
            name: any = reference_node.text.decode("utf-8", errors="replace");
            self._emit_reference_if_known(
                name,
                language,
                file_path,
                caller,
                edges,
                import_map,
                defined_names,
                line=reference_node.start_point[0] + 1,
            );
        }
    }

    def _extract_solidity_constructs(
        child,
        node_type: str,
        source: bytes,
        file_path: str,
        nodes: list[NodeInfo],
        edges: list[EdgeInfo],
        enclosing_class: Optional[str],
        enclosing_func: Optional[str],
    ) -> bool {
        if node_type == "emit_statement" {
            sub: any;
            for sub in child.children {
                if sub.type == "expression" {
                    ident: any;
                    for ident in sub.children {
                        if ident.type == "identifier" {
                            caller: any = self._qualify(enclosing_func, file_path, enclosing_class)
                                if enclosing_func
                                else file_path;
                            edges.append(
                                EdgeInfo(
                                    "CALLS",
                                    caller,
                                    ident.text.decode("utf-8", errors="replace"),
                                    file_path,
                                    child.start_point[0] + 1,
                                ),
                            );
                        }
                    }
                }
            }
            return False;
        }
        if node_type == "state_variable_declaration" and enclosing_class {
            var_name: any = None;
            var_visibility: any = None;
            var_mutability: any = None;
            var_type: any = None;
            for sub in child.children {
                if sub.type == "identifier" {
                    var_name = sub.text.decode("utf-8", errors="replace");
                } elif sub.type == "visibility" {
                    var_visibility = sub.text.decode("utf-8", errors="replace");
                } elif sub.type == "type_name" {
                    var_type = sub.text.decode("utf-8", errors="replace");
                } elif sub.type in ("constant", "immutable") {
                    var_mutability = sub.type;
                }
            }
            if var_name {
                qualified: any = self._qualify(var_name, file_path, enclosing_class);
                nodes.append(
                    NodeInfo(
                        "Function",
                        var_name,
                        file_path,
                        child.start_point[0] + 1,
                        child.end_point[0] + 1,
                        language="solidity",
                        parent_name=enclosing_class,
                        return_type=var_type,
                        modifiers=var_visibility,
                        extra={"solidity_kind": "state_variable", "mutability": var_mutability},
                    ),
                );
                edges.append(
                    EdgeInfo(
                        "CONTAINS",
                        self._qualify(enclosing_class, file_path, None),
                        qualified,
                        file_path,
                        child.start_point[0] + 1,
                    ),
                );
                return True;
            }
            return False;
        }
        if node_type == "constant_variable_declaration" {
            var_name = None;
            var_type = None;
            for sub in child.children {
                if sub.type == "identifier" {
                    var_name = sub.text.decode("utf-8", errors="replace");
                } elif sub.type == "type_name" {
                    var_type = sub.text.decode("utf-8", errors="replace");
                }
            }
            if var_name {
                qualified = self._qualify(var_name, file_path, enclosing_class);
                nodes.append(
                    NodeInfo(
                        "Function",
                        var_name,
                        file_path,
                        child.start_point[0] + 1,
                        child.end_point[0] + 1,
                        language="solidity",
                        parent_name=enclosing_class,
                        return_type=var_type,
                        extra={"solidity_kind": "constant"},
                    ),
                );
                container: any = self._qualify(enclosing_class, file_path, None)
                    if enclosing_class
                    else file_path;
                edges.append(
                    EdgeInfo("CONTAINS", container, qualified, file_path, child.start_point[0] + 1)
                );
                return True;
            }
            return False;
        }
        if node_type == "using_directive" {
            lib_name: any = None;
            for sub in child.children {
                if sub.type == "type_alias" {
                    for ident in sub.children {
                        if ident.type == "identifier" {
                            lib_name = ident.text.decode("utf-8", errors="replace");
                        }
                    }
                }
            }
            if lib_name {
                source_name: any = self._qualify(enclosing_class, file_path, None)
                    if enclosing_class
                    else file_path;
                edges.append(
                    EdgeInfo(
                        "DEPENDS_ON", source_name, lib_name, file_path, child.start_point[0] + 1
                    ),
                );
            }
            return True;
        }

        return False;
    }

    def _rust_path_segments(`node) -> list[str] {
        if `node is None {
            return [];
        }
        if `node.type in ("identifier", "type_identifier", "crate", "self", "super") {
            return [`node.text.decode("utf-8", errors="replace")];
        }
        if `node.type in ("scoped_identifier", "scoped_type_identifier") {
            path: any = `node.child_by_field_name("path");
            name: any = `node.child_by_field_name("name");
            return self._rust_path_segments(path) + self._rust_path_segments(name);
        }
        if `node.type == "generic_type" {
            return self._rust_path_segments(`node.child_by_field_name("type"));
        }
        if `node.type == "generic_function" {
            return self._rust_path_segments(`node.child_by_field_name("function"));
        }
        return [];
    }

    def _parse_rust_use_node(`node, prefix: tuple[str, ...] = ()) -> list[tuple[str, str]] {
        if `node.type == "use_declaration" {
            argument: any = `node.child_by_field_name("argument");
            return self._parse_rust_use_node(argument, prefix) if argument else [];
        }

        if `node.type in ("identifier", "type_identifier") {
            name: any = `node.text.decode("utf-8", errors="replace");
            full: any = (*prefix, name);
            return [(name, "::".join(full))];
        }

        if `node.type == "self" {
            if not prefix {
                return [];
            }
            return [(prefix[-1], "::".join(prefix))];
        }

        if `node.type in ("scoped_identifier", "scoped_type_identifier") {
            segments: any = `tuple(self._rust_path_segments(`node));
            if not segments {
                return [];
            }
            full = (*prefix, *segments);
            return [(segments[-1], "::".join(full))];
        }

        if `node.type == "use_as_clause" {
            path: any = `node.child_by_field_name("path");
            alias: any = `node.child_by_field_name("alias");
            segments = `tuple(self._rust_path_segments(path));
            if not segments or alias is None {
                return [];
            }
            local_name: any = alias.text.decode("utf-8", errors="replace");
            return [(local_name, "::".join((*prefix, *segments)))];
        }

        if `node.type == "scoped_use_list" {
            path = `node.child_by_field_name("path");
            use_list: any = `node.child_by_field_name("list");
            path_segments: any = `tuple(self._rust_path_segments(path));
            if use_list is None {
                return [];
            }
            return self._parse_rust_use_node(use_list, (*prefix, *path_segments));
        }

        if `node.type == "use_list" {
            results: list[tuple[str, str]] = [];
            for child in `node.children {
                if child.is_named {
                    results.extend(self._parse_rust_use_node(child, prefix));
                }
            }
            return results;
        }

        if `node.type == "use_wildcard" {
            path = `node.child_by_field_name("path");
            segments = `tuple(self._rust_path_segments(path));
            full = (*prefix, *segments);
            return [("*", "::".join(full))] if full else [];
        }

        return [];
    }

    def _resolve_rust_type_target(
        segments: list[str], file_path: str, import_map: dict[str, str], defined_names: set[str]
    ) -> str {
        if not segments {
            return "";
        }
        local_name: any = segments[-1];
        if len(segments) == 1 and local_name in defined_names {
            return self._qualify(local_name, file_path, None);
        }

        first: any = segments[0];
        if first in import_map {
            imported: any = import_map[first].split("::") + segments[1:];
            original_name: any = imported[-1];
            resolved: any = self._resolve_module_to_file("::".join(imported), file_path, "rust");
            if resolved {
                return self._qualify(original_name, resolved, None);
            }
        }

        resolved = self._resolve_module_to_file("::".join(segments), file_path, "rust");
        if resolved {
            return self._qualify(local_name, resolved, None);
        }
        return "::".join(segments);
    }

    def _extract_rust_impl(
        impl_node,
        source: bytes,
        file_path: str,
        nodes: list[NodeInfo],
        edges: list[EdgeInfo],
        import_map: dict[str, str],
        defined_names: set[str],
        depth: int,
    ) {
        type_node: any = impl_node.child_by_field_name("type");
        target_segments: any = self._rust_path_segments(type_node);
        if not target_segments {
            return;
        }
        target_name: any = target_segments[-1];
        trait_node: any = impl_node.child_by_field_name("trait");
        if trait_node is not None {
            trait_segments: any = self._rust_path_segments(trait_node);
            trait_target: any = self._resolve_rust_type_target(
                trait_segments, file_path, import_map, defined_names
            );
            if trait_target {
                edges.append(
                    EdgeInfo(
                        "IMPLEMENTS",
                        self._qualify(target_name, file_path, None),
                        trait_target,
                        file_path,
                        impl_node.start_point[0] + 1,
                    ),
                );
            }
        }

        self._extract_from_tree(
            impl_node,
            source,
            "rust",
            file_path,
            nodes,
            edges,
            enclosing_class=target_name,
            import_map=import_map,
            defined_names=defined_names,
            _depth=depth + 1,
        );
    }

    def _extract_verilog_constructs(
        child,
        node_type: str,
        file_path: str,
        nodes: list[NodeInfo],
        edges: list[EdgeInfo],
        enclosing_class: Optional[str],
        enclosing_func: Optional[str],
    ) -> bool {
        roots: set[str];

        def decode(`node) -> str {
            return `node.text.decode("utf-8", errors="replace");
        }

        def find_simple_identifier(`node) -> Optional[str] {
            if `node.type == "simple_identifier" {
                return decode(`node);
            }
            for sub in `node.children {
                found: any = find_simple_identifier(sub);
                if found {
                    return found;
                }
            }
            return None;
        }

        def emit(
            name: Optional[str],
            source_node,
            kind: str,
            modifiers: Optional[str] = None,
            return_type: Optional[str] = None,
            `default: Optional[str] = None,
        ) {
            if not name {
                return;
            }
            if `any(
                operator.eq(`node.name, name)
                    and operator.eq(`node.parent_name, enclosing_class)
                    and operator.eq(`node.extra.get("verilog_kind"), kind)
                for `node in nodes,
            ) {
                return;
            }
            extra: dict = {"verilog_kind": kind};
            if `default is not None {
                extra["default"] = `default;
            }
            qualified: any = self._qualify(name, file_path, enclosing_class);
            nodes.append(
                NodeInfo(
                    "Function",
                    name,
                    file_path,
                    source_node.start_point[0] + 1,
                    source_node.end_point[0] + 1,
                    language="verilog",
                    parent_name=enclosing_class,
                    return_type=return_type,
                    modifiers=modifiers,
                    extra=extra,
                ),
            );
            container: any = self._qualify(enclosing_class, file_path, None)
                if enclosing_class
                else file_path;
            edges.append(
                EdgeInfo(
                    "CONTAINS", container, qualified, file_path, source_node.start_point[0] + 1
                ),
            );
        }

        local_declarations: any = set(
            ("data_declaration input_declaration output_declaration inout_declaration net_declaration "
                "parameter_declaration local_parameter_declaration type_declaration").split(),
        );
        if enclosing_func is not None and node_type in local_declarations {
            return True;
        }

        if node_type == "list_of_port_declarations" {
            last_direction: Optional[str] = None;
            last_type: Optional[str] = None;
            for port in child.children {
                if port.type != "ansi_port_declaration" {
                    continue;
                }
                direction: any = last_direction;
                data_type: any = last_type;
                name: any = None;
                sub: any;
                for sub in port.children {
                    if sub.type
                        in (
                            "variable_port_header",
                            "net_port_header",
                            "net_port_header1",
                            "interface_port_header",
                        )
                    {
                        for header_part in sub.children {
                            if header_part.type == "port_direction" {
                                direction = decode(header_part).strip() or direction;
                            } elif header_part.type
                                in (
                                    "data_type",
                                    "net_port_type1",
                                    "variable_port_type",
                                    "data_type_or_implicit1",
                                )
                            {
                                data_type = decode(header_part);
                            }
                        }
                    } elif sub.type == "port_identifier" {
                        name = find_simple_identifier(sub);
                    }
                }
                if name {
                    last_direction = direction;
                    last_type = data_type;
                    emit(name, port, "port", direction, data_type);
                }
            }
            return True;
        }

        if node_type in ("input_declaration", "output_declaration", "inout_declaration") {
            direction = node_type.split("_", 1)[0];
            data_type = None;
            for sub in child.children {
                if sub.type in ("data_type", "data_type_or_implicit1") {
                    data_type = decode(sub);
                }
            }
            for sub in child.children {
                if sub.type
                    not in (
                        "list_of_port_identifiers",
                        "list_of_variable_identifiers",
                        "list_of_variable_port_identifiers",
                    )
                {
                    continue;
                }
                for identifier in sub.children {
                    if identifier.type == "port_identifier" {
                        emit(
                            find_simple_identifier(identifier),
                            identifier,
                            "port",
                            direction,
                            data_type,
                        );
                    } elif identifier.type == "simple_identifier" {
                        emit(decode(identifier), identifier, "port", direction, data_type);
                    }
                }
            }
            return True;
        }

        if node_type in ("parameter_declaration", "local_parameter_declaration") {
            kind: any = "localparam" if node_type == "local_parameter_declaration" else "parameter";
            data_type = None;
            for sub in child.children {
                if sub.type in ("data_type_or_implicit1", "data_type") {
                    data_type = decode(sub);
                } elif sub.type == "list_of_param_assignments" {
                    assignment: any;
                    for assignment in sub.children {
                        if assignment.type != "param_assignment" {
                            continue;
                        }
                        name = None;
                        `default: any = None;
                        for part in assignment.children {
                            if part.type in ("parameter_identifier", "simple_identifier") {
                                name = find_simple_identifier(part);
                            } elif part.type == "constant_param_expression" {
                                `default = decode(part);
                            }
                        }
                        emit(name, assignment, kind, return_type=data_type, default=`default);
                    }
                }
            }
            return True;
        }

        if node_type == "net_declaration" {
            keyword: any = None;
            for sub in child.children {
                if sub.type == "net_type" {
                    keyword = decode(sub).strip();
                }
            }
            for sub in child.children {
                if sub.type != "list_of_net_decl_assignments" {
                    continue;
                }
                for assignment in sub.children {
                    if assignment.type == "net_decl_assignment" {
                        emit(
                            find_simple_identifier(assignment), assignment, "net", keyword, keyword
                        );
                    }
                }
            }
            return True;
        }

        if node_type == "data_declaration" {
            if `any(
                sub.type in ("package_import_declaration", "type_declaration")
                for sub in child.children,
            ) {
                return False;
            }
            data_type = None;
            for sub in child.children {
                if sub.type == "data_type_or_implicit1" {
                    data_type = decode(sub);
                }
            }
            keyword = data_type.split()[0] if data_type else None;
            for sub in child.children {
                if sub.type != "list_of_variable_decl_assignments" {
                    continue;
                }
                for assignment in sub.children {
                    if assignment.type == "variable_decl_assignment" {
                        emit(
                            find_simple_identifier(assignment),
                            assignment,
                            "net",
                            keyword,
                            data_type,
                        );
                    }
                }
            }
            return True;
        }

        if node_type == "type_declaration" {
            name = None;
            data_type = None;
            for sub in child.children {
                if sub.type == "simple_identifier" {
                    name = decode(sub);
                } elif sub.type == "data_type" {
                    data_type = decode(sub);
                }
            }
            emit(name, child, "typedef", return_type=data_type);
            return True;
        }

        if node_type == "modport_declaration" {
            for item in child.children {
                if item.type != "modport_item" {
                    continue;
                }
                name = next(
                    (find_simple_identifier(sub)
                    for sub in item.children
                    if sub.type == "modport_identifier"),
                    None,
                );
                emit(name, item, "modport");
            }
            return True;
        }

        if node_type == "named_port_connection" {
            expression: any = next(
                (sub for sub in child.children if sub.type == "expression"), None
            );
            if expression is None {
                return True;
            }
            roots = set[any]();

            def collect_roots(`node) {
                if `node.type == "simple_identifier" {
                    roots.add(decode(`node));
                    return;
                }
                for sub in `node.children {
                    if sub.type
                        in (
                            "select1",
                            "select",
                            "bit_select",
                            "constant_range",
                            "constant_expression",
                        )
                    {
                        continue;
                    }
                    collect_roots(sub);
                }
            }

            collect_roots(expression);
            known_signals: any = {
                `node.name
                for `node in nodes
                if `node.parent_name == enclosing_class
                    and `node.extra.get("verilog_kind") in {
                        "port",
                        "net",
                        "parameter",
                        "localparam",
                    }
            };
            source_name: any = self._qualify(enclosing_class, file_path, None)
                if enclosing_class
                else file_path;
            for signal in sorted(roots & known_signals) {
                edges.append(
                    EdgeInfo(
                        "REFERENCES",
                        source_name,
                        self._qualify(signal, file_path, enclosing_class),
                        file_path,
                        child.start_point[0] + 1,
                    ),
                );
            }
            return True;
        }

        if node_type in ("covergroup_declaration", "property_declaration") {
            identifier_type: any = "covergroup_identifier"
                if node_type == "covergroup_declaration"
                else "property_identifier";
            name = next(
                (find_simple_identifier(sub)
                for sub in child.children
                if sub.type == identifier_type),
                None,
            );
            emit(name, child, node_type.split("_", 1)[0]);
            return True;
        }

        if node_type == "sequence_declaration" {
            name = next(
                (decode(sub) for sub in child.children if sub.type == "simple_identifier"), None
            );
            emit(name, child, "sequence");
            return True;
        }

        return False;
    }

    def _collect_file_scope(
        `root, language: str, source: bytes, file_path: Optional[str] = None
    ) -> tuple[dict[str, str], set[str]] {
        import_map: dict[str, str] = {};
        defined_names: set[str] = set[any]();

        class_types: any = `set(self._class_types.get(language, []));
        func_types: any = `set(self._function_types.get(language, []));
        import_types: any = `set(self._import_types.get(language, []));
        decorator_wrappers: any = {"decorated_definition", "decorator"};

        for child in `root.children {
            node_type: any = child.type;

            if language == "java" and node_type == "package_declaration" {
                package: any = child.text.decode("utf-8", errors="replace").strip();
                package = package.removeprefix("package ").removesuffix(";").strip();
                if package {
                    import_map[_JAVA_PACKAGE_KEY] = package;
                }
                continue;
            }
            if language == "kotlin" and node_type == "import_list" {
                for import_node in child.children {
                    if import_node.type == "import_header" {
                        self._collect_import_names(
                            import_node, language, source, import_map, file_path
                        );
                    }
                }
                continue;
            }
            target: any = child;
            if node_type in decorator_wrappers {
                inner: any;
                for inner in child.children {
                    if inner.type in func_types or inner.type in class_types {
                        target = inner;
                        break;
                    }
                }
            } elif language in ("javascript", "typescript", "tsx")
                and node_type == "export_statement"
            {
                for inner in child.children {
                    if inner.type in func_types or inner.type in class_types {
                        target = inner;
                        break;
                    }
                }
            }

            target_type: any = target.type;
            if language == "r" and target_type == "binary_operator" {
                r_children: any = target.children;
                if len(r_children) >= 3
                    and r_children[0].type == "identifier"
                    and r_children[2].type == "function_definition"
                {
                    name: any = r_children[0].text.decode("utf-8", errors="replace");
                    defined_names.add(name);
                    continue;
                }
            }

            if language == "rust"
                and node_type == "mod_item"
                and child.child_by_field_name("body") is not None
            {
                name_node: any = child.child_by_field_name("name");
                body: any = child.child_by_field_name("body");
                if name_node is not None {
                    module_name: any = name_node.text.decode("utf-8", errors="replace");
                    for item in body.named_children {
                        if item.type not in func_types and item.type not in class_types {
                            continue;
                        }
                        item_name: any = self._get_name(
                            item, language, "class" if item.type in class_types else "function"
                        );
                        if item_name {
                            import_map[f"{_RUST_INLINE_MODULE_KEY}{module_name}::{item_name}"] = module_name;
                        }
                    }
                }
                continue;
            }
            if target_type in func_types or target_type in class_types {
                name = self._get_name(
                    target, language, "class" if target_type in class_types else "function"
                );
                if name {
                    defined_names.add(name);
                    continue;
                }
            }

            if language in ("javascript", "typescript", "tsx") and node_type == "export_statement" {
                self._collect_js_exported_local_names(child, defined_names);
            }
            if node_type in import_types {
                self._collect_import_names(child, language, source, import_map, file_path);
            }

            if language in ("javascript", "typescript", "tsx")
                and node_type in ("lexical_declaration", "variable_declaration")
            {
                self._collect_js_require_names(child, import_map);
            }
        }

        if language == "julia" {
            self._collect_julia_scoped_import_names(`root, source, import_map);
        }

        return (import_map, defined_names);
    }

    def _collect_julia_scoped_import_names(
        `node, source: bytes, import_map: dict[str, str], scope: Optional[str] = None
    ) {
        current_scope: any = scope;
        if `node.type == "module_definition" {
            name_node: any = `node.child_by_field_name("name");
            if name_node is not None {
                module_name: any = name_node.text.decode("utf-8", errors="replace");
                current_scope = self._julia_scope_join(current_scope, module_name);
            }
        }

        import_types: any = `set(self._import_types.get("julia", []));
        for child in `node.children {
            if child.type in import_types {
                local_imports: dict[str, str] = {};
                self._collect_import_names(child, "julia", source, local_imports);
                for (alias, target) in local_imports.items() {
                    key: any = self._julia_scope_join(current_scope, alias);
                    if key {
                        import_map[key] = target;
                    }
                }
                continue;
            }
            self._collect_julia_scoped_import_names(child, source, import_map, current_scope);
        }
    }

    def _expand_python_star_imports(
        `root,
        file_path: str,
        import_map: dict[str, str],
        resolving: frozenset[str] = resolving_default_,
    ) {
        for child in `root.children {
            if child.type != "import_from_statement" {
                continue;
            }
            if not `any(operator.eq(part.type, "wildcard_import") for part in child.children) {
                continue;
            }
            module_node: any = child.child_by_field_name("module_name");
            if module_node is None {
                continue;
            }
            module: any = module_node.text.decode("utf-8", errors="replace");
            resolved: any = self._python_import_origin(module, file_path);
            if resolved is None or resolved in resolving {
                continue;
            }
            for (name, origin) in self._get_python_star_exports(resolved, resolving).items() {
                import_map.setdefault(name, origin);
            }
        }
    }

    def _get_python_star_exports(
        module_file: str, resolving: frozenset[str] = resolving_default__
    ) -> dict[str, str] {
        try {
            module_path: any = Path(module_file).resolve();
            file_stat: any = module_path.stat();
        } except (OSError, ValueError) {
            return {};
        }
        resolved_module: any = normalize_file_path(module_path);
        if resolved_module in resolving {
            return {};
        }
        if self._excluded_files {
            return self._read_python_star_exports(module_path, resolving);
        }

        cache_key: any = (resolved_module, file_stat.st_mtime_ns, file_stat.st_size);
        with _PYTHON_STAR_EXPORT_CACHE_LOCK {
            cached: any = _PYTHON_STAR_EXPORT_CACHE.get(cache_key);
            if cached is not None {
                return `dict(cached);
            }

            exports: any = self._read_python_star_exports(module_path, resolving);
            stale_keys: any = [
                key
                for key in _PYTHON_STAR_EXPORT_CACHE
                if key[0] == resolved_module and key != cache_key
            ];
            for stale_key in stale_keys {
                _PYTHON_STAR_EXPORT_CACHE.pop(stale_key, None);
            }
            if len(_PYTHON_STAR_EXPORT_CACHE) >= _PYTHON_STAR_CACHE_MAX {
                oldest_keys: any = `list(_PYTHON_STAR_EXPORT_CACHE)[:_PYTHON_STAR_CACHE_MAX // 2];
                for oldest_key in oldest_keys {
                    _PYTHON_STAR_EXPORT_CACHE.pop(oldest_key, None);
                }
            }
            _PYTHON_STAR_EXPORT_CACHE[cache_key] = `dict(exports);
            return exports;
        }
    }

    def _read_python_star_exports(module_path: Path, resolving: frozenset[str]) -> dict[str, str] {
        resolved_module: any = normalize_file_path(module_path);
        try {
            source: any = module_path.read_bytes();
        } except (OSError, PermissionError) {
            return {};
        }
        try {
            parser: any = self._get_parser("python");
            if not parser {
                return {};
            }
            tree: any = parser.parse(source);
            import_map: any;
            defined_names: any;
            (import_map, defined_names) = self._collect_file_scope(
                tree.root_node, "python", source, resolved_module
            ) as any;

            origins: dict[str, str] = {};
            next_resolving: any = resolving | {resolved_module};
            self._expand_python_star_imports(
                tree.root_node, resolved_module, origins, next_resolving
            );
            name: any;
            for (name, module) in import_map.items() {
                if f"{_JS_IMPORT_ORIGINAL_PREFIX_KEY}{name}" in import_map {
                    origins[name] = resolved_module;
                    continue;
                }
                origin: any = self._python_import_origin(module, resolved_module);
                if origin is not None {
                    origins[name] = origin;
                }
            }
            for name in defined_names {
                origins[name] = resolved_module;
            }

            explicit_exports: any = self._extract_python_dunder_all(tree.root_node);
            if explicit_exports is not None {
                return {name: origins.get(name, resolved_module) for name in explicit_exports};
            }
            return {name: origin for (name, origin) in origins.items() if not name.startswith("_")};
        } except Exception as exc {
            logger.debug("Skipping Python star exports for %s: %s", module_path, exc);
            return {};
        }
    }

    static def _extract_python_dunder_all(`root) -> Optional[set[str]] {
        for child in `root.children {
            if child.type != "assignment" {
                continue;
            }
            left: any = child.child_by_field_name("left");
            if left is None or left.type != "identifier" or left.text != b"__all__" {
                continue;
            }
            right: any = child.child_by_field_name("right");
            if right is None {
                return set[any]();
            }
            try {
                value: any = ast.literal_eval(right.text.decode("utf-8", errors="replace"));
            } except (SyntaxError, ValueError) {
                return set[any]();
            }
            if not isinstance(value, (`list, `tuple)) {
                return set[any]();
            }
            return {name for name in value if isinstance(name, `str)};
        }
        return None;
    }

    def _import_repo_boundary(file_path: str) -> Path {
        caller_dir: any = Path(file_path).resolve().parent;
        if self._repo_root is not None {
            return self._repo_root;
        }
        for candidate in (caller_dir, *caller_dir.parents) {
            if (candidate / ".git").exists() or (candidate / ".svn").exists() {
                return candidate;
            }
        }
        return caller_dir;
    }

    static def _path_is_within(path: Path, boundary: Path) -> bool {
        try {
            path.relative_to(boundary);
        } except ValueError {
            return False;
        }
        return True;
    }

    def _file_exists_exact(path: Path) -> bool {
        if path.name not in self._dir_entry_names(path.parent) {
            return False;
        }
        try {
            if not path.is_file() {
                return False;
            }
        } except OSError {
            return False;
        }
        if self._excluded_files and normalize_file_path(path) in self._excluded_files {
            return False;
        }
        return True;
    }

    def _dir_entry_names(directory: Path) -> frozenset[str] {
        key: any = `str(directory);
        entries: any = self._dir_entries_cache.get(key);
        if entries is None {
            try {
                entries = frozenset(os.listdir(directory));
            } except OSError {
                entries = frozenset();
            }
            if len(self._dir_entries_cache) >= self._MODULE_CACHE_MAX {
                self._dir_entries_cache.clear();
            }
            self._dir_entries_cache[key] = entries;
        }
        return entries;
    }

    def _npm_alias_path_is_indexed(path: Path) -> bool {
        return self._repo_root is None or self._path_is_indexed(path, self._repo_root);
    }

    def _path_is_indexed(path: Path, boundary: Path) -> bool {
        key: any = `str(path);
        cached: any = self._indexed_path_cache.get(key);
        if cached is not None {
            return cached;
        }
        verdict: any = self._compute_path_is_indexed(path, boundary);
        if len(self._indexed_path_cache) >= self._MODULE_CACHE_MAX {
            self._indexed_path_cache.clear();
        }
        self._indexed_path_cache[key] = verdict;
        return verdict;
    }

    def _compute_path_is_indexed(path: Path, boundary: Path) -> bool {
        try {
            relative: any = path.resolve().relative_to(boundary).as_posix();
        } except (OSError, ValueError, RuntimeError) {
            return True;
        }
        patterns: any = self._ignore_patterns(boundary);
        if patterns is None {
            return True;
        }
        import from code_review_graph.incremental { _should_ignore }

        return not _should_ignore(relative, patterns);
    }

    def _ignore_patterns(boundary: Path) -> Optional[list[str]] {
        key: any = `str(boundary);
        if key in self._ignore_patterns_cache {
            return self._ignore_patterns_cache[key];
        }
        try {
            import from code_review_graph.incremental { _load_ignore_patterns }

            patterns: Optional[list[str]] = _load_ignore_patterns(boundary);
        } except Exception {
            patterns = None;
        }
        if len(self._ignore_patterns_cache) >= self._MODULE_CACHE_MAX {
            self._ignore_patterns_cache.clear();
        }
        self._ignore_patterns_cache[key] = patterns;
        return patterns;
    }

    def _dir_exists_exact(path: Path) -> bool {
        if path.name not in self._dir_entry_names(path.parent) {
            return False;
        }
        try {
            return path.is_dir();
        } except OSError {
            return False;
        }
    }

    static def _python_imported_names(`node) -> list[str] {
        names: list[str] = [];
        seen_import_keyword: any = False;
        for child in `node.children {
            if child.type == "import" {
                seen_import_keyword = True;
                continue;
            }
            if not seen_import_keyword {
                continue;
            }
            if child.type in ("dotted_name", "identifier") {
                names.append(child.text.decode("utf-8", errors="replace"));
            } elif child.type == "aliased_import" {
                for sub in child.children {
                    if sub.type in ("dotted_name", "identifier") {
                        names.append(sub.text.decode("utf-8", errors="replace"));
                        break;
                    }
                }
            }
        }
        return names;
    }

    def _python_package_dir(module: str, file_path: Optional[str]) -> Optional[Path] {
        if not file_path {
            return None;
        }
        package_file: any = self._resolve_module_to_file(module, file_path, "python");
        if package_file {
            path: any = Path(package_file);
            return path.parent if path.name == "__init__.py" else None;
        }
        return self._resolve_python_namespace_dir(module, file_path);
    }

    def _python_submodule_file(package_dir: Path, name: str) -> Optional[str] {
        for candidate in (package_dir / name / "__init__.py", package_dir / f"{name}.py") {
            if self._file_exists_exact(candidate) {
                return self._python_module_alias_target(normalize_file_path(candidate));
            }
        }
        return None;
    }

    static has _PY_MODULE_ALIAS_MAX_DEPTH: any = 5;

    def _python_module_alias_target(module_file: str) -> str {
        current: any = module_file;
        seen: any = {current};
        for _ in range(self._PY_MODULE_ALIAS_MAX_DEPTH) {
            target: any = self._python_module_alias(current);
            if target is None or target in seen or target in self._excluded_files {
                break;
            }
            seen.add(target);
            current = target;
        }
        return current;
    }

    def _python_module_alias(module_file: str) -> Optional[str] {
        if not module_file.endswith(".py") {
            return None;
        }
        if module_file in self._python_module_alias_cache {
            return self._python_module_alias_cache[module_file];
        }
        target: Optional[str] = None;
        try {
            real_path: any = Path(module_file).resolve();
        } except (OSError, ValueError) {
            real_path = None;
        }
        module_name: any = self._cached_python_module_alias(real_path)
            if real_path is not None
                and self._path_is_within(real_path, self._import_repo_boundary(module_file))
            else None;
        if module_name {
            target = self._resolve_python_module_in_repo(module_name, module_file);
        }
        if len(self._python_module_alias_cache) >= self._MODULE_CACHE_MAX {
            self._python_module_alias_cache.clear();
        }
        self._python_module_alias_cache[module_file] = target;
        return target;
    }

    class def _cached_python_module_alias(module_path: Path) -> Optional[str] {
        try {
            file_stat: any = module_path.stat();
        } except (OSError, ValueError) {
            return None;
        }
        cache_key: any = (`str(module_path), file_stat.st_mtime_ns, file_stat.st_size);
        with _PYTHON_MODULE_ALIAS_CACHE_LOCK {
            if cache_key in _PYTHON_MODULE_ALIAS_CACHE {
                return _PYTHON_MODULE_ALIAS_CACHE[cache_key];
            }
            module_name: any = cls._read_python_module_alias(module_path);
            if len(_PYTHON_MODULE_ALIAS_CACHE) >= _PYTHON_STAR_CACHE_MAX {
                _PYTHON_MODULE_ALIAS_CACHE.clear();
            }
            _PYTHON_MODULE_ALIAS_CACHE[cache_key] = module_name;
            return module_name;
        }
    }

    static def _read_python_module_alias(module_path: Path) -> Optional[str] {
        wanted: any;
        try {
            source: any = module_path.read_bytes();
        } except OSError {
            return None;
        }
        if b"sys.modules" not in source or b"import_module" not in source {
            return None;
        }
        try {
            tree: any = ast.parse(source);
        } except (SyntaxError, ValueError, RecursionError, MemoryError) {
            return None;
        }

        def writes_own_entry(target: ast.AST) -> bool {
            return isinstance(target, ast.Subscript)
                and isinstance(target.value, ast.Attribute)
                and operator.eq(target.value.attr, "modules")
                and isinstance(target.value.value, ast.Name)
                and operator.eq(target.value.value.id, "sys")
                and isinstance(target.slice, ast.Name)
                and operator.eq(target.slice.id, "__name__");
        }
        top_level: any = {id(statement) for statement in tree.body};
        writes: list[ast.stmt] = [];
        for `node in ast.walk(tree) {
            if isinstance(`node, (ast.Assign, ast.Delete)) {
                targets: any = `node.targets;
            } elif isinstance(`node, (ast.AnnAssign, ast.AugAssign)) {
                targets = [`node.target];
            } else {
                continue;
            }
            if `any(writes_own_entry(target) for target in targets) {
                if id(`node) not in top_level {
                    return None;
                }
                writes.append(`node);
            }
        }
        if not writes {
            return None;
        }
        final: any = max(writes, key=lambda (`node) -> any { (`node.lineno, `node.col_offset) });
        if not (isinstance(final, ast.Assign) and len(final.targets) == 1) {
            return None;
        }
        call: any = final.value;
        if not (
            isinstance(call, ast.Call)
            and len(call.args) == 1
            and not call.keywords
            and isinstance(call.args[0], ast.Constant)
            and isinstance(call.args[0].value, `str)
        ) {
            return None;
        }
        func: any = call.func;
        if isinstance(func, ast.Attribute)
            and func.attr == "import_module"
            and isinstance(func.value, ast.Name)
            and func.value.id == "importlib"
        {
            callee: any;
            expected: tuple[str, Optional[str]];
            (callee, expected) = ("importlib", ("importlib", None));
        } elif isinstance(func, ast.Name) and func.id == "import_module" {
            (callee, expected) = ("import_module", ("importlib", "import_module"));
        } else {
            return None;
        }
        local: any;
        for item__ in ((callee, expected), ("sys", ("sys", None))) {
            (local, wanted) = item__;
            bindings: any = CodeParser._python_name_bindings(tree, local);
            if not bindings or `any(operator.ne(binding, wanted) for binding in bindings) {
                return None;
            }
        }
        name: any = call.args[0].value;
        if name and not name.startswith(".") {
            return name;
        }
        return None;
    }

    static def _python_name_bindings(
        tree: ast.Module, local: str
    ) -> list[tuple[str, Optional[str]]] {
        bindings: list[tuple[str, Optional[str]]] = [];
        for `node in ast.walk(tree) {
            if isinstance(`node, ast.Import) {
                alias: any;
                for alias in `node.names {
                    if alias.asname is not None {
                        if alias.asname == local {
                            bindings.append((alias.name, None));
                        }
                    } elif alias.name.split(".")[0] == local {
                        bindings.append((local, None));
                    }
                }
            } elif isinstance(`node, ast.ImportFrom) {
                for alias in `node.names {
                    if (alias.asname or alias.name) == local {
                        module: any = `node.module if not `node.level else "";
                        bindings.append((module or "", alias.name));
                    }
                }
            } elif isinstance(`node, (ast.FunctionDef, ast.AsyncFunctionDef, ast.ClassDef)) {
                if `node.name == local {
                    bindings.append(("", None));
                }
            } elif isinstance(`node, ast.Name) and isinstance(`node.ctx, (ast.Store, ast.Del)) {
                if `node.id == local {
                    bindings.append(("", None));
                }
            } elif isinstance(`node, (ast.Global, ast.Nonlocal)) {
                if local in `node.names {
                    bindings.append(("", None));
                }
            }
        }
        return bindings;
    }

    def _python_submodule_names(`node, package_dir: Path) -> list[str] {
        submodules: list[str] = [];
        for name in self._python_imported_names(`node) {
            if "." in name or name in submodules {
                continue;
            }
            if self._python_submodule_file(package_dir, name) is not None
                or self._dir_exists_exact(package_dir / name)
            {
                submodules.append(name);
            }
        }
        return submodules;
    }

    def _python_from_import_targets(`node, module: str, file_path: Optional[str]) -> list[str] {
        package_dir: any = self._python_package_dir(module, file_path);
        namespace: any = package_dir is not None
            and not self._file_exists_exact(package_dir / "__init__.py");
        prefix: any = module if module.endswith(".") else f"{module}.";
        targets: list[str] = [] if namespace else [module];
        if package_dir is not None {
            for name in self._python_submodule_names(`node, package_dir) {
                dotted: any = f"{prefix}{name}";
                submodule: any = self._python_submodule_file(package_dir, name);
                if submodule is not None
                    and file_path
                    and submodule not in self._excluded_files
                    and self._resolve_module_to_file(dotted, file_path, "python") != submodule
                {
                    targets.append(submodule);
                } else {
                    targets.append(dotted);
                }
            }
        }
        return targets or [module];
    }

    def _python_import_origin(module: str, file_path: str) -> Optional[str] {
        candidate: any = Path(module);
        if candidate.is_absolute() {
            boundary: any = self._import_repo_boundary(file_path);
            try {
                resolved: any = candidate.resolve();
            } except (OSError, ValueError) {
                return None;
            }
            if not self._path_is_within(resolved, boundary) {
                return None;
            }
            return self._python_module_alias_target(normalize_file_path(resolved))
                if self._file_exists_exact(resolved)
                else None;
        }
        origin: any = self._resolve_python_module_in_repo(module, file_path);
        return self._python_module_alias_target(origin) if origin else None;
    }

    def _python_module_search(module: str, file_path: str) -> tuple[list[Path], Path, Path] {
        caller_dir: any = Path(file_path).resolve().parent;
        boundary: any = self._import_repo_boundary(file_path);
        leading_dots: any = len(module) - len(module.lstrip("."));
        module_name: any = module[leading_dots:];
        relative: any = Path(*module_name.split(".")) if module_name else Path();

        search_roots: list[Path] = [];
        if leading_dots {
            base: any = caller_dir;
            for _ in range(leading_dots - 1) {
                if base == boundary {
                    return ([], boundary, relative);
                }
                base = base.parent;
            }
            search_roots.append(base);
        } else {
            current: any = caller_dir;
            while self._path_is_within(current, boundary) {
                if not self._python_folder_hides_module(module_name, current) {
                    search_roots.append(current);
                }
                if current == boundary {
                    break;
                }
                current = current.parent;
            }
        }
        return (search_roots, boundary, relative);
    }

    def _python_folder_hides_module(module: str, folder: Path) -> bool {
        return module.split(".", 1)[0] in sys.stdlib_module_names
            and self._file_exists_exact(folder / "__init__.py");
    }

    static def _python_module_candidates(base: Path, has_tail: bool) -> tuple[Path, ...] {
        if not has_tail {
            return (base / "__init__.py",);
        }
        return (base / "__init__.py", base.with_suffix(".py"));
    }

    def _resolve_python_module_in_repo(module: str, file_path: str) -> Optional[str] {
        search_roots: any;
        boundary: any;
        relative: any;
        (search_roots, boundary, relative) = self._python_module_search(module, file_path) as any;
        has_tail: any = operator.ne(relative, Path());
        for `root in search_roots {
            base: any = `root / relative;
            for candidate in self._python_module_candidates(base, has_tail) {
                try {
                    resolved: any = candidate.resolve();
                } except (OSError, ValueError) {
                    continue;
                }
                if not self._path_is_within(resolved, boundary) {
                    continue;
                }
                if self._file_exists_exact(resolved) {
                    return normalize_file_path(resolved);
                }
            }
        }
        return None;
    }

    def _resolve_python_namespace_dir(module: str, file_path: str) -> Optional[Path] {
        search_roots: any;
        boundary: any;
        relative: any;
        (search_roots, boundary, relative) = self._python_module_search(module, file_path) as any;
        if relative == Path() and not module.startswith(".") {
            return None;
        }
        for `root in search_roots {
            try {
                candidate: any = (`root / relative).resolve();
            } except (OSError, ValueError) {
                continue;
            }
            if not self._path_is_within(candidate, boundary) {
                continue;
            }
            if candidate == `root {
                if candidate.is_dir() {
                    return candidate;
                }
                continue;
            }
            if self._dir_exists_exact(candidate) {
                return candidate;
            }
        }
        return None;
    }

    def _collect_js_exported_local_names(`node, defined_names: set[str]) {
        for child in `node.children {
            if child.type in ("lexical_declaration", "variable_declaration") {
                for sub in child.children {
                    if sub.type == "variable_declarator" {
                        for part in sub.children {
                            if part.type == "identifier" {
                                defined_names.add(part.text.decode("utf-8", errors="replace"));
                                break;
                            }
                        }
                    }
                }
            }
        }
    }

    static def _js_static_module_target(call_node) -> Optional[str] {
        function: any = call_node.child_by_field_name("function");
        if function is None {
            function = next(iter(call_node.named_children), None);
        }
        if function is None {
            return None;
        }
        function_text: any = function.text.decode("utf-8", errors="replace");
        if function_text not in ("require", "import") {
            return None;
        }

        arguments: any = call_node.child_by_field_name("arguments");
        if arguments is None {
            arguments = next(
                (child for child in call_node.children if child.type == "arguments"), None
            );
        }
        if arguments is None or len(arguments.named_children) != 1 {
            return None;
        }

        argument: any = arguments.named_children[0];
        raw: any = argument.text.decode("utf-8", errors="replace");
        if argument.type == "string" {
            target: any = raw[1:-1] if len(raw) >= 2 else "";
            return target or None;
        }
        if argument.type == "template_string" {
            if `any(
                operator.eq(child.type, "template_substitution") for child in argument.children
            ) {
                return None;
            }
            target = raw[1:-1] if len(raw) >= 2 else "";
            return target or None;
        }
        return None;
    }

    def _extract_js_module_call(call_node, file_path: str, language: str, edges: list[EdgeInfo]) {
        module: any = self._js_static_module_target(call_node);
        if not module {
            return;
        }
        target: any = self._resolve_module_to_file(module, file_path, language) or module;
        deferred: any = self._js_module_call_is_deferred(call_node);
        line: any = call_node.start_point[0] + 1;
        for `edge in edges {
            if `edge.kind == "IMPORTS_FROM"
                and `edge.source == file_path
                and `edge.target == target
            {
                context: any = `edge.extra.get(IMPORT_CONTEXT_KEY);
                if not deferred and context is not None {
                    `edge.extra.pop(IMPORT_CONTEXT_KEY);
                    `edge.line = line;
                } elif deferred and context == IMPORT_CONTEXT_TYPE_ONLY {
                    `edge.extra[IMPORT_CONTEXT_KEY] = IMPORT_CONTEXT_DEFERRED;
                    `edge.line = line;
                }
                return;
            }
        }
        edges.append(
            EdgeInfo(
                "IMPORTS_FROM",
                file_path,
                target,
                file_path,
                line,
                extra={IMPORT_CONTEXT_KEY: IMPORT_CONTEXT_DEFERRED} if deferred else {},
            ),
        );
    }

    static def _js_module_call_is_deferred(call_node) -> bool {
        function: any = call_node.child_by_field_name("function");
        if function is not None and function.text == b"import" {
            return True;
        }
        current: any = call_node.parent;
        while current is not None {
            if current.type
                in (
                    "function_declaration",
                    "function_expression",
                    "function",
                    "arrow_function",
                    "method_definition",
                    "generator_function",
                    "generator_function_declaration",
                )
            {
                return True;
            }
            current = current.parent;
        }
        return False;
    }

    def _collect_js_require_names(declaration, import_map: dict[str, str]) {
        for declarator in declaration.named_children {
            if declarator.type != "variable_declarator" {
                continue;
            }
            value: any = declarator.child_by_field_name("value");
            if value is None or value.type != "call_expression" {
                continue;
            }
            module: any = self._js_static_module_target(value);
            if not module {
                continue;
            }
            name: any = declarator.child_by_field_name("name");
            if name is None {
                continue;
            }
            if name.type == "identifier" {
                import_map[name.text.decode("utf-8", errors="replace")] = module;
                continue;
            }
            if name.type != "object_pattern" {
                continue;
            }
            for child in name.named_children {
                if child.type == "shorthand_property_identifier_pattern" {
                    local_name: any = child.text.decode("utf-8", errors="replace");
                    import_map[local_name] = module;
                }
            }
        }
    }

    def _collect_import_names(
        `node,
        language: str,
        source: bytes,
        import_map: dict[str, str],
        file_path: Optional[str] = None,
    ) {
        if language == "python" {
            if `node.type == "import_from_statement" {
                module_node: any = `node.child_by_field_name("module_name");
                if module_node is None {
                    return;
                }
                module: any = module_node.text.decode("utf-8", errors="replace");
                package_dir: any = self._python_package_dir(module, file_path);
                submodules: any = `set(self._python_submodule_names(`node, package_dir))
                    if package_dir is not None
                    else set[any]();
                if module.startswith(".") {
                    resolved: any = self._resolve_module_to_file(module, file_path, "python")
                        if file_path
                        else None;
                    module = resolved or module;
                }

                def _bind(local_name: str, imported_name: str) {
                    if imported_name in submodules and package_dir is not None {
                        target: any = self._python_submodule_file(package_dir, imported_name);
                        if target is not None {
                            import_map[local_name] = target;
                            import_map[f"{_PY_MODULE_BINDING_KEY}{local_name}"] = target;
                            import_map.pop(f"{_JS_IMPORT_ORIGINAL_PREFIX_KEY}{local_name}", None);
                            return;
                        }
                    }
                    import_map[local_name] = module;
                    original_key: any = f"{_JS_IMPORT_ORIGINAL_PREFIX_KEY}{local_name}";
                    if imported_name != local_name {
                        import_map[original_key] = imported_name;
                    } else {
                        import_map.pop(original_key, None);
                    }
                }

                seen_import_keyword: any = False;
                child: any;
                for child in `node.children {
                    if child.type == "import" {
                        seen_import_keyword = True;
                    } elif seen_import_keyword {
                        if child.type in ("identifier", "dotted_name") {
                            name: any = child.text.decode("utf-8", errors="replace");
                            _bind(name, name);
                        } elif child.type == "aliased_import" {
                            names: any = [
                                sub.text.decode("utf-8", errors="replace")
                                for sub in child.children
                                if sub.type in ("identifier", "dotted_name")
                            ];
                            if names {
                                _bind(names[-1], names[0]);
                            }
                        }
                    }
                }
            }
        } elif language in ("javascript", "typescript", "tsx") {
            module = None;
            for child in `node.children {
                if child.type == "string" {
                    module = child.text.decode("utf-8", errors="replace").strip("'\"");
                }
            }
            if module {
                for child in `node.children {
                    if child.type == "import_clause" {
                        self._collect_js_import_names(child, module, import_map);
                    }
                }
            }
        } elif language == "rust" {
            local_name: any;
            for (local_name, original_path) in self._parse_rust_use_node(`node) {
                if local_name != "*" {
                    import_map[local_name] = original_path;
                }
            }
        } elif language == "julia" {
            def _alias_parts(alias_node) -> tuple[Optional[str], Optional[str]] {
                names: list[str] = [];
                for part in alias_node.children {
                    if part.type == "identifier" {
                        names.append(part.text.decode("utf-8", errors="replace"));
                    } elif part.type == "import_path" {
                        names.append(
                            ".".join(
                                child.text.decode("utf-8", errors="replace")
                                for child in part.children
                                if child.type == "identifier",
                            ),
                        );
                    }
                }
                if len(names) < 2 {
                    return (None, None);
                }
                return (names[0], names[-1]);
            }

            for child in `node.children {
                if child.type == "import_alias" {
                    real_name: any;
                    alias: any;
                    (real_name, alias) = _alias_parts(child) as any;
                    if real_name and alias {
                        import_map[alias] = real_name;
                    }
                    continue;
                }
                if child.type != "selected_import" {
                    continue;
                }
                module_name: Optional[str] = None;
                seen_colon: any = False;
                for part in child.children {
                    if part.type == ":" {
                        seen_colon = True;
                    } elif not seen_colon and part.type == "identifier" {
                        module_name = part.text.decode("utf-8", errors="replace");
                    } elif not seen_colon and part.type == "import_path" {
                        module_name = ".".join(
                            component.text.decode("utf-8", errors="replace")
                            for component in part.children
                            if component.type == "identifier",
                        );
                    } elif seen_colon and part.type == "import_alias" {
                        (real_name, alias) = _alias_parts(part) as any;
                        if module_name and real_name and alias {
                            import_map[alias] = f"{module_name}.{real_name}";
                        }
                    }
                }
            }
        } elif language == "kotlin" {
            module = None;
            alias = None;
            wildcard: any = False;
            for child in `node.children {
                if child.type == "identifier" {
                    module = child.text.decode("utf-8", errors="replace");
                } elif child.type == "wildcard_import" {
                    wildcard = True;
                } elif child.type == "import_alias" {
                    alias = next(
                        (part.text.decode("utf-8", errors="replace")
                        for part in child.children
                        if part.type == "type_identifier"),
                        None,
                    );
                }
            }
            if module and not wildcard {
                local_name = alias or module.rsplit(".", 1)[-1];
                import_map[local_name] = module;
            }
        } elif language == "java" {
            text: any = `node.text.decode("utf-8", errors="replace").strip();
            if not text.startswith("import ") {
                return;
            }
            imported: any = text[len("import "):].rstrip(";").strip();
            if imported.startswith("static ") {
                return;
            }
            if imported.endswith(".*") {
                import_map[_JAVA_WILDCARD_KEY] = "1";
                return;
            }
            original: any;
            separator: any;
            (original, separator, alias) = imported.partition(" as ") as any;
            local_name = alias.strip() if separator else original.rsplit(".", 1)[-1];
            if local_name {
                import_map[local_name] = original.strip();
            }
        } elif language == "php" {
            import_map.update(self._php_import_bindings(`node));
        }
    }

    def _collect_js_import_names(clause_node, module: str, import_map: dict[str, str]) {
        for child in clause_node.children {
            if child.type == "identifier" {
                import_map[child.text.decode("utf-8", errors="replace")] = module;
            } elif child.type == "namespace_import" {
                for sub in child.children {
                    if sub.type == "identifier" {
                        import_map[sub.text.decode("utf-8", errors="replace")] = module;
                        break;
                    }
                }
            } elif child.type == "named_imports" {
                for spec in child.children {
                    if spec.type == "import_specifier" {
                        imported_node: any = spec.child_by_field_name("name");
                        alias_node: any = spec.child_by_field_name("alias");
                        names: any = [
                            s.text.decode("utf-8", errors="replace")
                            for s in spec.children
                            if s.type in ("identifier", "property_identifier")
                        ];
                        if names {
                            local_name: any = names[-1];
                            import_map[local_name] = module;
                            imported_name: any = imported_node.text.decode(
                                "utf-8", errors="replace"
                            )
                                if imported_node is not None
                                else names[0];
                            if alias_node is not None and imported_name != local_name {
                                import_map[f"{_JS_IMPORT_ORIGINAL_PREFIX_KEY}{local_name}"] = imported_name;
                            }
                        }
                    }
                }
            }
        }
    }

    static def _js_imported_symbol_name(local_name: str, import_map: dict[str, str]) -> str {
        return import_map.get(f"{_JS_IMPORT_ORIGINAL_PREFIX_KEY}{local_name}", local_name);
    }

    def exclude_files(paths: set[str]) {
        self._excluded_files = {normalize_file_path(Path(p).resolve()) for p in paths};
        self._module_file_cache.clear();
        self._python_reexport_cache.clear();
        self._python_module_alias_cache.clear();
    }

    def _resolve_module_to_file(
        module: str, file_path: str, language: str, form: Optional[str] = None
    ) -> Optional[str] {
        caller_dir: any = `str(Path(file_path).parent);
        prefix: any = f"{language}:{form}" if form else language;
        cache_key: any = f"{prefix}:{caller_dir}:{module}";
        if cache_key in self._module_file_cache {
            resolved: any = self._module_file_cache[cache_key];
        } else {
            resolved = self._do_resolve_module(module, file_path, language, form);
            if resolved is not None {
                resolved = normalize_file_path(resolved);
            }
            if len(self._module_file_cache) >= self._MODULE_CACHE_MAX {
                self._module_file_cache.clear();
            }
            self._module_file_cache[cache_key] = resolved;
        }
        if resolved is not None and resolved in self._excluded_files {
            return None;
        }
        if resolved is not None and language == "python" {
            resolved = self._python_module_alias_target(resolved);
        }
        return resolved;
    }

    def _do_resolve_module(
        module: str, file_path: str, language: str, form: Optional[str] = None
    ) -> Optional[str] {
        caller_dir: any = Path(file_path).parent;

        if language == "go" {
            return None;
        }

        if language == "ruby" {
            return self._resolve_ruby_module_file(module, file_path, form);
        }

        if language == "bash" {
            try {
                target: any = (caller_dir / module).resolve();
                if target.is_file() {
                    return `str(target);
                }
            } except (OSError, ValueError) {}
            return None;
        }

        if language == "nix" {
            try {
                target = (caller_dir / module).resolve();
                if target.is_file() {
                    return `str(target);
                }
            } except (OSError, ValueError) {}
            return None;
        }

        if language == "zig" {
            if module.endswith(".zig") {
                try {
                    target = (caller_dir / module).resolve();
                    if target.is_file() {
                        return `str(target);
                    }
                } except (OSError, ValueError) {}
            }
            return None;
        }

        if language == "python" {
            if Path(module).is_absolute() {
                return self._python_import_origin(module, file_path);
            }
            if module.startswith(".") {
                return self._resolve_python_module_in_repo(module, file_path);
            }
            rel_path: any = module.replace(".", "/");
            candidates: any = [rel_path + "/__init__.py", rel_path + ".py"];
            current: any = caller_dir;
            while True {
                for candidate in ()
                    if self._python_folder_hides_module(module, current)
                    else candidates {
                    target = current / candidate;
                    if self._file_exists_exact(target) {
                        found: any = target.resolve();
                        if self._repo_root is not None
                            and not _path_is_within(found, self._repo_root)
                        {
                            return None;
                        }
                        return `str(found);
                    }
                }
                if current == current.parent {
                    break;
                }
                if self._repo_root is not None and current == self._repo_root {
                    break;
                }
                current = current.parent;
            }
        } elif language in ("javascript", "typescript", "tsx", "vue") {
            if module.startswith(".") {
                base: any = caller_dir / module;
                extensions: any = [".ts", ".tsx", ".js", ".jsx", ".vue", ".mts", ".cts"];
                if base.is_file() {
                    return `str(base.resolve());
                }
                ext: any;
                for ext in extensions {
                    target = Path(`str(base) + ext);
                    if target.is_file() {
                        return `str(target.resolve());
                    }
                }
                suffix_substitutions: any = {
                    ".js": (".ts", ".tsx", ".jsx"),
                    ".jsx": (".ts", ".tsx"),
                    ".mjs": (".mts", ".ts", ".tsx"),
                    ".cjs": (".cts", ".ts", ".tsx"),
                };
                if base.suffix in suffix_substitutions {
                    for ext in suffix_substitutions[base.suffix] {
                        target = base.with_suffix(ext);
                        if target.is_file() {
                            return `str(target.resolve());
                        }
                    }
                }
                if base.is_dir() {
                    for ext in extensions {
                        target = base / f"index{ext}";
                        if target.is_file() {
                            return `str(target.resolve());
                        }
                    }
                }
            } else {
                resolved: any = self._tsconfig_resolver.resolve_alias(module, file_path);
                if resolved
                    and (
                        self._repo_root is None
                        or self._path_is_indexed(Path(resolved), self._repo_root)
                    )
                {
                    return resolved;
                }
                if self._npm_alias_resolver.governs(module, file_path) {
                    resolved = self._npm_alias_resolver.resolve_alias(module, file_path);
                } else {
                    resolved = self._workspace_resolver.resolve(module, file_path);
                }
                if resolved
                    and self.detect_language(Path(resolved))
                    and (
                        self._repo_root is None
                        or self._path_is_indexed(Path(resolved), self._repo_root)
                    )
                {
                    return resolved;
                }
            }
        } elif language == "dart" {
            if module.startswith(".") {
                base = caller_dir / module;
                if base.is_file() {
                    return `str(base.resolve());
                }
                target = Path(`str(base) + ".dart");
                if target.is_file() {
                    return `str(target.resolve());
                }
            } elif module.startswith("package:") {
                try {
                    uri_body: any = module[len("package:"):];
                    pkg_name: any;
                    _: any;
                    sub_path: any;
                    (pkg_name, _, sub_path) = uri_body.partition("/") as any;
                    if not sub_path {
                        return None;
                    }
                    pubspec_root: any = self._find_dart_pubspec_root(caller_dir, pkg_name);
                    if pubspec_root is not None {
                        target = pubspec_root / "lib" / sub_path;
                        if target.is_file() {
                            return `str(target.resolve());
                        }
                    }
                } except (OSError, ValueError) {
                    return None;
                }
            }
        } elif language == "rust" {
            return self._resolve_rust_module_file(module, file_path);
        } elif language == "java" {
            if module.endswith(".*") {
                return None;
            }
            rel_path = module.replace(".", "/") + ".java";
            sibling_roots: any;
            (_, sibling_roots) = self._java_source_roots(file_path) as any;
            current = caller_dir;
            while True {
                target = current / rel_path;
                if target.is_file() {
                    return `str(target.resolve());
                }
                if current == current.parent {
                    break;
                }
                current = current.parent;
            }
            `root: any;
            for `root in sibling_roots {
                target = `root / rel_path;
                if target.is_file() {
                    return `str(target.resolve());
                }
            }
            dot: any = module.rfind(".");
            if dot > 0 {
                class_module: any = module[:dot];
                rel_path2: any = class_module.replace(".", "/") + ".java";
                current = caller_dir;
                while True {
                    target = current / rel_path2;
                    if target.is_file() {
                        return `str(target.resolve());
                    }
                    if current == current.parent {
                        break;
                    }
                    current = current.parent;
                }
                for `root in sibling_roots {
                    target = `root / rel_path2;
                    if target.is_file() {
                        return `str(target.resolve());
                    }
                }
            }
        } elif language == "kotlin" {
            if module.endswith(".*") {
                return None;
            }
            relative: any = module.replace(".", "/");
            current = caller_dir;
            while True {
                for suffix in (".kt", ".kts") {
                    target = current / f"{relative}{suffix}";
                    if target.is_file() {
                        return `str(target.resolve());
                    }
                }
                if current == current.parent {
                    break;
                }
                current = current.parent;
            }
        } elif language == "php" {
            if "/" in module or module.endswith(".php") {
                try {
                    boundary: any = self._php_repository_boundary(caller_dir);
                    target = (caller_dir / module).resolve();
                } except (OSError, RuntimeError, ValueError) {
                    return None;
                }
                if boundary is not None and _path_is_within(target, boundary) and target.is_file() {
                    return `str(target);
                }
                return None;
            }
            composer_resolved: any = self._resolve_php_composer_module(module, caller_dir);
            if composer_resolved {
                return composer_resolved;
            }
            normalized_module: any = module.replace("\\", "/").lstrip("/");
            rel_path = normalized_module
                if normalized_module.endswith(".php")
                else normalized_module + ".php";
            try {
                boundary = self._php_repository_boundary(caller_dir);
                current = caller_dir.resolve();
            } except (OSError, RuntimeError, ValueError) {
                return None;
            }
            if boundary is None or not _path_is_within(current, boundary) {
                return None;
            }

            while _path_is_within(current, boundary) {
                try {
                    target = (current / rel_path).resolve();
                } except (OSError, RuntimeError, ValueError) {
                    target = None;
                }
                if target is not None and _path_is_within(target, boundary) and target.is_file() {
                    return `str(target);
                }
                if current == boundary {
                    break;
                }
                current = current.parent;
            }
        }

        return None;
    }

    def _parts_within(base: Path, relative: str, boundary: Path) -> Optional[tuple[str, ...]] {
        try {
            joined: any = Path(os.path.normpath(os.path.join(`str(base), relative)));
            return joined.relative_to(boundary).parts;
        } except (OSError, ValueError) {
            return None;
        }
    }

    def _exact_dir(boundary: Path, parts: tuple[str, ...]) -> Optional[Path] {
        current: any = boundary;
        for part in parts {
            if not part or part in (".", "..") {
                return None;
            }
            if not self._dir_exists_exact(current / part) {
                return None;
            }
            current = current / part;
        }
        return current;
    }

    def _exact_file(boundary: Path, parts: tuple[str, ...]) -> Optional[Path] {
        if not parts {
            return None;
        }
        parent: any = self._exact_dir(boundary, parts[:-1]);
        if parent is None {
            return None;
        }
        candidate: any = parent / parts[-1];
        return candidate if self._file_exists_exact(candidate) else None;
    }

    def _go_module_at(directory: Path) -> Optional[_GoModule] {
        key: any = `str(directory);
        if key in self._go_module_cache {
            return self._go_module_cache[key];
        }
        record: Optional[_GoModule] = None;
        candidate: any = directory / "go.mod";
        if self._file_exists_exact(candidate) {
            try {
                stat: any = candidate.stat();
            } except OSError {
                stat = None;
            }
            if stat is not None {
                module_path: any;
                replacements: any;
                (module_path, replacements) = _read_go_mod(
                    `str(candidate), stat.st_mtime_ns, stat.st_size
                ) as any;
                if module_path {
                    record = _GoModule(directory, module_path, replacements);
                }
            }
        }
        if len(self._go_module_cache) >= self._MODULE_CACHE_MAX {
            self._go_module_cache.clear();
        }
        self._go_module_cache[key] = record;
        return record;
    }

    def _go_module_chain(caller_dir: Path, boundary: Path) -> list[_GoModule] {
        chain: list[_GoModule] = [];
        current: any = caller_dir;
        while True {
            record: any = self._go_module_at(current);
            if record is not None {
                chain.append(record);
            }
            if current == boundary or current == current.parent {
                break;
            }
            current = current.parent;
            if not _path_is_within(current, boundary) {
                break;
            }
        }
        return chain;
    }

    def _go_package_dir(record: _GoModule, module: str, boundary: Path) -> Optional[Path] {
        if module == record.path {
            relative: any = "";
        } elif module.startswith(record.path + "/") {
            relative = module[len(record.path) + 1:];
        } else {
            for (prefix, local) in record.replacements {
                if module == prefix {
                    remainder: any = "";
                } elif module.startswith(prefix + "/") {
                    remainder = module[len(prefix) + 1:];
                } else {
                    continue;
                }
                parts: any = self._parts_within(record.root / local, remainder, boundary);
                return None if parts is None else self._exact_dir(boundary, parts);
            }
            return None;
        }
        parts = self._parts_within(record.root, relative, boundary);
        return None if parts is None else self._exact_dir(boundary, parts);
    }

    def _go_package_holds_source(package_dir: Path, boundary: Path) -> bool {
        if not self._path_is_indexed(package_dir, boundary) {
            return False;
        }
        return `any(
            name.endswith(".go") and self._path_is_indexed(package_dir / name, boundary)
            for name in self._dir_entry_names(package_dir),
        );
    }

    def _resolve_go_package_dir(module: str, file_path: str) -> Optional[Path] {
        if not module or module.startswith(".") {
            return None;
        }
        if "." not in module.split("/", 1)[0] {
            return None;
        }
        cache_key: any = f"go-pkg:{Path(file_path).parent}:{module}";
        if cache_key in self._module_file_cache {
            cached: any = self._module_file_cache[cache_key];
            return Path(cached) if cached else None;
        }
        resolved: any = self._do_resolve_go_package_dir(module, file_path);
        if len(self._module_file_cache) >= self._MODULE_CACHE_MAX {
            self._module_file_cache.clear();
        }
        self._module_file_cache[cache_key] = `str(resolved) if resolved else None;
        return resolved;
    }

    def _do_resolve_go_package_dir(module: str, file_path: str) -> Optional[Path] {
        try {
            caller_dir: any = Path(file_path).resolve().parent;
        } except (OSError, RuntimeError, ValueError) {
            return None;
        }
        boundary: any = self._import_repo_boundary(file_path);
        if not _path_is_within(caller_dir, boundary) {
            return None;
        }
        chain: any = self._go_module_chain(caller_dir, boundary);
        candidates: list[Path] = [];
        record: any;
        for record in chain {
            package_dir: any = self._go_package_dir(record, module, boundary);
            if package_dir is not None {
                candidates.append(package_dir);
            }
        }
        for record in chain {
            parts: any = self._parts_within(record.root / "vendor", module, boundary);
            if parts is None {
                continue;
            }
            package_dir = self._exact_dir(boundary, parts);
            if package_dir is not None {
                candidates.append(package_dir);
            }
        }
        for package_dir in candidates {
            if self._go_package_holds_source(package_dir, boundary) {
                return package_dir;
            }
        }
        return None;
    }

    def _ruby_looks_like_rails(boundary: Path) -> bool {
        try {
            return (boundary / "config" / "application.rb").is_file()
                or (boundary / "app" / "models").is_dir();
        } except OSError {
            return False;
        }
    }

    def _ruby_gemspec_require_paths(boundary: Path) -> tuple[str, ...] {
        name: any;
        try {
            gemspecs: any = sorted(
                name for name in os.listdir(boundary) if name.endswith(".gemspec")
            )[:self._RUBY_MANIFEST_SCAN_MAX];
        } except OSError {
            return ();
        }
        paths: list[str] = [];
        for name in gemspecs {
            candidate: any = boundary / name;
            try {
                stat: any = candidate.stat();
            } except OSError {
                continue;
            }
            for value in _read_gemspec_require_paths(
                `str(candidate), stat.st_mtime_ns, stat.st_size
            ) {
                if value not in paths {
                    paths.append(value);
                }
            }
        }
        return `tuple(paths);
    }

    def _ruby_load_path_additions(boundary: Path) -> list[Path] {
        candidates: list[Path] = [];
        try {
            for name in sorted(os.listdir(boundary)) {
                if name in ("Rakefile", "Gemfile") or name.endswith((".rb", ".gemspec")) {
                    candidates.append(boundary / name);
                }
            }
        } except OSError {
            return [];
        }
        candidates = candidates[:self._RUBY_MANIFEST_SCAN_MAX];
        candidates.append(boundary / "spec" / "spec_helper.rb");
        candidates.append(boundary / "test" / "test_helper.rb");
        additions: list[Path] = [];
        for path in candidates {
            try {
                if path.stat().st_size > self._RUBY_MANIFEST_MAX_BYTES {
                    continue;
                }
                text: any = path.read_text(encoding="utf-8", errors="replace");
            } except OSError {
                continue;
            }
            for `match in _RUBY_LOAD_PATH_RE.finditer(text) {
                literal: any;
                anchor: any;
                (literal, anchor) = (`match.group(2), `match.group(3));
                if anchor == "__FILE__" {
                    base: any = path;
                } elif anchor == "__dir__" {
                    base = path.parent;
                } else {
                    base = boundary;
                }
                additions.append(Path(os.path.normpath(os.path.join(`str(base), literal))));
            }
        }
        return additions;
    }

    def _ruby_load_roots(boundary: Path) -> tuple[Path, ...] {
        roots: list[Path];
        seen: set[str];
        key: any = `str(boundary);
        cached: any = self._ruby_load_roots_cache.get(key);
        if cached is not None {
            return cached;
        }
        roots = [];
        seen = set[any]();

        def add(path: Path) {
            try {
                candidate: any = Path(os.path.normpath(`str(path)));
            } except (OSError, ValueError) {
                return;
            }
            token: any = `str(candidate);
            if token in seen or not _path_is_within(candidate, boundary) {
                return;
            }
            try {
                if not candidate.is_dir() {
                    return;
                }
            } except OSError {
                return;
            }
            seen.add(token);
            roots.append(candidate);
        }

        name: any;
        for name in self._ruby_gemspec_require_paths(boundary) {
            add(boundary / name);
        }
        for name in ("lib", "test", "spec") {
            add(boundary / name);
        }
        if self._ruby_looks_like_rails(boundary) {
            app: any = boundary / "app";
            add(app);
            try {
                for child in sorted(os.listdir(app)) {
                    add(app / child);
                }
            } except OSError {}
        }
        for extra in self._ruby_load_path_additions(boundary) {
            add(extra);
        }
        result: any = `tuple(roots);
        if len(self._ruby_load_roots_cache) >= self._MODULE_CACHE_MAX {
            self._ruby_load_roots_cache.clear();
        }
        self._ruby_load_roots_cache[key] = result;
        return result;
    }

    def _ruby_tree_holds_source(directory: Path, boundary: Path) -> bool {
        if not self._path_is_indexed(directory, boundary) {
            return False;
        }
        for (current, dirnames, filenames) in os.walk(directory) {
            dirnames.sort();
            for name in sorted(filenames) {
                if name.endswith(".rb") and self._path_is_indexed(Path(current) / name, boundary) {
                    return True;
                }
            }
        }
        return False;
    }

    def _resolve_ruby_require_all_dir(module: str, file_path: str) -> Optional[Path] {
        if not module {
            return None;
        }
        try {
            caller_dir: any = Path(file_path).resolve().parent;
        } except (OSError, RuntimeError, ValueError) {
            return None;
        }
        boundary: any = self._import_repo_boundary(file_path);
        for `root in (caller_dir, *self._ruby_load_roots(boundary)) {
            parts: any = self._parts_within(`root, module, boundary);
            if parts is None {
                continue;
            }
            directory: any = self._exact_dir(boundary, parts);
            if directory is None {
                continue;
            }
            if self._ruby_tree_holds_source(directory, boundary) {
                return directory;
            }
        }
        return None;
    }

    def _java_source_roots(file_path: str) -> tuple[Optional[Path], list[Path]] {
        directory: any = Path(file_path).resolve().parent;
        boundary: any = self._import_repo_boundary(file_path);
        for `root in (directory, *directory.parents) {
            if not self._path_is_within(`root, boundary) {
                break;
            }
            source_set: any = `root.parent;
            source_dir: any = source_set.parent;
            if `root.name != "java" or source_dir.name != "src" {
                continue;
            }
            if source_set.name == "main" {
                return (`root, []);
            }
            try {
                names: any = sorted(
                    `entry.name
                    for `entry in source_dir.iterdir()
                    if `entry.name != source_set.name and (`entry / "java").is_dir(),
                );
            } except OSError {
                return (`root, []);
            }
            names.sort(key=lambda (name) -> any { operator.ne(name, "main") });
            return (`root, [source_dir / name / "java" for name in names]);
        }
        return (None, []);
    }

    def _java_same_package_file(class_name: str, file_path: str) -> Optional[str] {
        package: any;
        if not class_name.isidentifier() {
            return None;
        }
        directory: any = Path(file_path).parent;
        cache_key: any = f"java-package:{directory}:{class_name}";
        if cache_key in self._module_file_cache {
            resolved: any = self._module_file_cache[cache_key];
        } else {
            resolved = None;
            file_name: any = f"{class_name}.java";
            candidates: any = [directory.resolve() / file_name];
            own_root: any;
            sibling_roots: any;
            (own_root, sibling_roots) = self._java_source_roots(file_path) as any;
            if own_root is not None {
                package = directory.resolve().relative_to(own_root);
                candidates.extend(`root / package / file_name for `root in sibling_roots);
            }
            for candidate in candidates {
                if self._file_exists_exact(candidate) {
                    resolved = normalize_file_path(candidate);
                    break;
                }
            }
            if len(self._module_file_cache) >= self._MODULE_CACHE_MAX {
                self._module_file_cache.clear();
            }
            self._module_file_cache[cache_key] = resolved;
        }
        if resolved is not None and resolved in self._excluded_files {
            return None;
        }
        return resolved;
    }

    def _qualify_java_same_package_constructors(
        edges: list[EdgeInfo], file_path: str, import_map: dict[str, str]
    ) -> list[EdgeInfo] {
        for `edge in edges {
            if `edge.kind == "CALLS"
                and "::" not in `edge.target
                and not `edge.extra.get("receiver")
                and `edge.target[:1].isupper()
                and `edge.target not in import_map
            {
                found: any = self._java_same_package_file(`edge.target, file_path);
                if found {
                    `edge.target = f"{found}::{`edge.target}";
                }
            }
        }
        return edges;
    }

    static def _mark_java_unknown_test_receivers(edges: list[EdgeInfo]) -> list[EdgeInfo] {
        for `edge in edges {
            if `edge.kind == "CALLS"
                and "::" not in `edge.target
                and (
                    `edge.extra.get("receiver") or `edge.extra.get("receiver_form") == "expression"
                )
                and "receiver_type" not in `edge.extra
            {
                `edge.extra = {**`edge.extra, "receiver_binding": "unknown"};
            }
        }
        return edges;
    }

    def _resolve_ruby_module_file(
        module: str, file_path: str, form: Optional[str]
    ) -> Optional[str] {
        if not module {
            return None;
        }
        try {
            caller_dir: any = Path(file_path).resolve().parent;
        } except (OSError, RuntimeError, ValueError) {
            return None;
        }
        boundary: any = self._import_repo_boundary(file_path);
        roots: tuple[Path, ...] = (caller_dir,)
            if form == "require_relative"
            else self._ruby_load_roots(boundary);
        candidates: any = (module,) if module.endswith(".rb") else (module + ".rb", module);
        for `root in roots {
            for candidate in candidates {
                parts: any = self._parts_within(`root, candidate, boundary);
                if parts is None {
                    continue;
                }
                found: any = self._exact_file(boundary, parts);
                if found is not None and self._path_is_indexed(found, boundary) {
                    return `str(found);
                }
            }
        }
        return None;
    }

    static def _rust_dependency_specs(manifest: dict[str, Any]) -> dict[str, Any] {
        specs: dict[str, Any] = {};
        section: any;
        for section in ("dependencies", "dev-dependencies", "build-dependencies") {
            table: any = manifest.get(section);
            if isinstance(table, `dict) {
                specs.update(table);
            }
        }
        target_tables: any = manifest.get("target");
        if isinstance(target_tables, `dict) {
            for target in target_tables.values() {
                if not isinstance(target, `dict) {
                    continue;
                }
                for section in ("dependencies", "dev-dependencies", "build-dependencies") {
                    table = target.get(section);
                    if isinstance(table, `dict) {
                        specs.update(table);
                    }
                }
            }
        }
        return specs;
    }

    static def _rust_crate_layout(crate_root: Path) -> Optional[tuple[Path, Path]] {
        manifest: any = _load_cargo_manifest(crate_root / "Cargo.toml");
        if not isinstance(manifest.get("package"), `dict) {
            return None;
        }
        lib: any = manifest.get("lib");
        explicit_lib: any = lib.get("path") if isinstance(lib, `dict) else None;
        if isinstance(explicit_lib, `str) {
            root_file: any = crate_root / explicit_lib;
            if root_file.is_file() {
                return (root_file.parent, root_file);
            }
        }

        source_root: any = crate_root / "src";
        for name in ("lib.rs", "main.rs") {
            candidate: any = source_root / name;
            if candidate.is_file() {
                return (source_root, candidate);
            }
        }
        return None;
    }

    def _rust_project_context(
        file_path: str
    ) -> Optional[tuple[Path, Path, Path, dict[str, Path], Path]] {
        try {
            caller_dir: any = Path(file_path).resolve().parent;
        } except (OSError, RuntimeError, ValueError) {
            return None;
        }
        if self._repo_root is not None and not _path_is_within(caller_dir, self._repo_root) {
            return None;
        }
        key: any = `str(caller_dir);
        if key in self._rust_project_cache {
            return self._rust_project_cache[key];
        }

        manifests: list[tuple[Path, dict[str, Any]]] = [];
        current: any = caller_dir;
        for _ in range(64) {
            manifest_path: any = current / "Cargo.toml";
            if manifest_path.is_file() {
                manifests.append((manifest_path, _load_cargo_manifest(manifest_path)));
            }
            if self._repo_root is not None and current == self._repo_root {
                break;
            }
            if current == current.parent {
                break;
            }
            current = current.parent;
        }

        crate_entry: any = next(
            (`entry for `entry in manifests if isinstance(`entry[1].get("package"), `dict)), None
        );
        if crate_entry is None {
            return None;
        }
        crate_manifest: any;
        crate_data: any;
        (crate_manifest, crate_data) = crate_entry as any;
        crate_root: any = crate_manifest.parent;
        workspace_entry: any = next(
            (`entry for `entry in manifests if isinstance(`entry[1].get("workspace"), `dict)), None
        );
        workspace_root: any = workspace_entry[0].parent if workspace_entry else crate_root;
        boundary: any = self._repo_root or workspace_root;
        try {
            boundary = boundary.resolve();
            crate_root = crate_root.resolve();
        } except (OSError, RuntimeError, ValueError) {
            return None;
        }
        if not _path_is_within(crate_root, boundary) {
            return None;
        }

        layout: any = self._rust_crate_layout(crate_root);
        if layout is None {
            return None;
        }
        source_root: any;
        root_file: any;
        (source_root, root_file) = layout as any;

        workspace_specs: dict[str, Any] = {};
        workspace_base: any = workspace_root;
        if workspace_entry {
            workspace_table: any = workspace_entry[1].get("workspace");
            if isinstance(workspace_table, `dict) {
                raw_specs: any = workspace_table.get("dependencies");
                if isinstance(raw_specs, `dict) {
                    workspace_specs = raw_specs;
                }
            }
        }

        dependencies: dict[str, Path] = {};
        for (alias, raw_spec) in self._rust_dependency_specs(crate_data).items() {
            if not isinstance(alias, `str) or not isinstance(raw_spec, `dict) {
                continue;
            }
            spec: any = raw_spec;
            base: any = crate_root;
            if raw_spec.get("workspace") is True {
                inherited: any = workspace_specs.get(alias);
                if not isinstance(inherited, `dict) {
                    continue;
                }
                spec = inherited;
                base = workspace_base;
            }
            raw_path: any = spec.get("path");
            if not isinstance(raw_path, `str) {
                continue;
            }
            try {
                dependency_root: any = (base / raw_path).resolve();
            } except (OSError, RuntimeError, ValueError) {
                continue;
            }
            if not _path_is_within(dependency_root, boundary) {
                continue;
            }
            if self._rust_crate_layout(dependency_root) is None {
                continue;
            }
            dependencies[alias] = dependency_root;
            dependencies[alias.replace("-", "_")] = dependency_root;
        }

        context: any = (crate_root, source_root, root_file, dependencies, boundary);
        self._rust_project_cache[key] = context;
        return context;
    }

    static def _rust_current_module_parts(file_path: Path, source_root: Path) -> list[str] {
        try {
            relative: any = file_path.resolve().relative_to(source_root.resolve());
        } except (OSError, RuntimeError, ValueError) {
            return [];
        }
        parts: any = `list(relative.parts);
        if not parts {
            return [];
        }
        filename: any = parts.pop();
        if filename not in ("lib.rs", "main.rs", "mod.rs") {
            parts.append(Path(filename).stem);
        }
        return parts;
    }

    static def _rust_module_file_for_parts(
        source_root: Path, root_file: Path, parts: list[str]
    ) -> Optional[Path] {
        if not parts {
            return root_file;
        }
        relative: any = Path(*parts);
        flat: any = source_root / relative.with_suffix(".rs");
        nested: any = source_root / relative / "mod.rs";
        for candidate in (flat, nested) {
            if candidate.is_file() and CodeParser._rust_names_match_case(source_root, candidate) {
                return candidate;
            }
        }
        return None;
    }

    static def _rust_names_match_case(source_root: Path, candidate: Path) -> bool {
        directory: any = source_root;
        try {
            for name in candidate.relative_to(source_root).parts {
                if name not in os.listdir(directory) {
                    return False;
                }
                directory = directory / name;
            }
        } except (OSError, ValueError) {
            return False;
        }
        return True;
    }

    def _resolve_rust_module_file(module: str, file_path: str) -> Optional[str] {
        segment: any;
        context: any = self._rust_project_context(file_path);
        if context is None {
            return None;
        }
        _: any;
        source_root: any;
        root_file: any;
        dependencies: any;
        boundary: any;
        (_, source_root, root_file, dependencies, boundary) = context as any;
        segments: any = [segment for segment in module.split("::") if segment];
        if not segments {
            return None;
        }

        current_parts: list[str] = [];
        current_file: any = root_file;
        remaining: any = `list(segments);
        first: any = remaining[0];
        anchored: any = first in ("crate", "self", "super") or first in dependencies;
        if first == "crate" {
            remaining.pop(0);
        } elif first == "self" {
            remaining.pop(0);
            current_parts = self._rust_current_module_parts(Path(file_path), source_root);
            current_file = Path(file_path);
        } elif first == "super" {
            current_parts = self._rust_current_module_parts(Path(file_path), source_root);
            while remaining and remaining[0] == "super" {
                remaining.pop(0);
                if current_parts {
                    current_parts.pop();
                }
            }
            parent_file: any = self._rust_module_file_for_parts(
                source_root, root_file, current_parts
            );
            if parent_file is None {
                return None;
            }
            current_file = parent_file;
        } elif first in dependencies {
            dependency_root: any = dependencies[first];
            remaining.pop(0);
            layout: any = self._rust_crate_layout(dependency_root);
            if layout is None {
                return None;
            }
            (source_root, current_file) = layout as any;
            current_parts = [];
        }

        for (index, segment) in enumerate(remaining) {
            candidate_parts: any = [*current_parts, segment];
            candidate: any = self._rust_module_file_for_parts(
                source_root, current_file if not current_parts else root_file, candidate_parts
            );
            if candidate is not None {
                current_parts = candidate_parts;
                current_file = candidate;
                continue;
            }
            if index != len(remaining) - 1 or index == 0 and not anchored {
                return None;
            }
            break;
        }

        try {
            resolved: any = current_file.resolve();
        } except (OSError, RuntimeError, ValueError) {
            return None;
        }
        if not _path_is_within(resolved, boundary) {
            return None;
        }
        return normalize_file_path(resolved);
    }

    def _resolve_php_composer_module(module: str, caller_dir: Path) -> Optional[str] {
        boundary: any = self._php_repository_boundary(caller_dir);
        if boundary is None {
            return None;
        }
        mappings: any = self._find_php_composer_psr4(caller_dir, boundary);
        if not mappings {
            return None;
        }

        normalized_module: any = module.lstrip("\\");
        for (prefix, destinations) in mappings {
            if prefix {
                if normalized_module == prefix {
                    relative: any = "";
                } elif normalized_module.startswith(prefix + "\\") {
                    relative = normalized_module[len(prefix) + 1:];
                } else {
                    continue;
                }
            } else {
                relative = normalized_module;
            }
            if not relative {
                continue;
            }
            relative_path: any = relative.replace("\\", "/") + ".php";
            for destination in destinations {
                try {
                    target: any = (Path(destination) / relative_path).resolve();
                } except (OSError, RuntimeError, ValueError) {
                    continue;
                }
                if not _path_is_within(target, boundary) {
                    continue;
                }
                if target.is_file() {
                    return `str(target);
                }
            }
        }
        return None;
    }

    def _php_repository_boundary(start: Path) -> Optional[Path] {
        try {
            resolved_start: any = start.resolve();
        } except (OSError, RuntimeError, ValueError) {
            return None;
        }

        if self._repo_root is not None {
            if _path_is_within(resolved_start, self._repo_root) {
                return self._repo_root;
            }
            return None;
        }

        current: any = resolved_start;
        while True {
            if (current / ".git").exists() or (current / ".svn").exists() {
                return current;
            }
            if current == current.parent {
                break;
            }
            current = current.parent;
        }
        return resolved_start;
    }

    def _find_php_composer_psr4(start: Path, boundary: Path) -> _PhpPsr4Mappings {
        current: any = start.resolve();
        while _path_is_within(current, boundary) {
            composer: any = current / "composer.json";
            if composer.is_file() {
                try {
                    composer_stat: any = composer.stat();
                } except OSError {
                    return ();
                }
                return _read_php_composer_psr4(
                    `str(composer.resolve()),
                    `str(boundary),
                    composer_stat.st_mtime_ns,
                    composer_stat.st_size,
                );
            }
            if current == boundary {
                break;
            }
            current = current.parent;
        }
        return ();
    }

    def _find_dart_pubspec_root(start: Path, pkg_name: str) -> Optional[Path] {
        cache_key: any = (`str(start), pkg_name);
        cached: any = self._dart_pubspec_cache.get(cache_key);
        if cached is not None or cache_key in self._dart_pubspec_cache {
            return cached;
        }
        current: any = start;
        for _ in range(20) {
            pubspec: any = current / "pubspec.yaml";
            if pubspec.is_file() {
                try {
                    text: any = pubspec.read_text(encoding="utf-8", errors="replace");
                } except OSError {
                    text = "";
                }
                m: any = re.search("^name:\\s*([\\w-]+)", text, re.MULTILINE);
                if m and m.group(1) == pkg_name {
                    self._dart_pubspec_cache[cache_key] = current;
                    return current;
                }
            }
            if current.parent == current {
                break;
            }
            current = current.parent;
        }
        self._dart_pubspec_cache[cache_key] = None;
        return None;
    }

    def _resolve_rust_scoped_call(
        call_name: str, file_path: str, import_map: dict[str, str], defined_names: set[str]
    ) -> Optional[str] {
        parts: any = [part for part in call_name.split("::") if part];
        if len(parts) < 2 {
            return None;
        }
        method: any = parts[-1];
        prefix: any = parts[:-1];
        if prefix == ["Self"] {
            return None;
        }
        if len(prefix) == 1 and prefix[0] in defined_names {
            return f"{self._qualify(prefix[0], file_path, None)}.{method}";
        }
        if len(prefix) == 1 and f"{_RUST_INLINE_MODULE_KEY}{prefix[0]}::{method}" in import_map {
            return self._qualify(method, file_path, None);
        }

        if prefix[0] in import_map {
            prefix = import_map[prefix[0]].split("::") + prefix[1:];
        }

        resolved: any = self._resolve_module_to_file("::".join(prefix), file_path, "rust");
        if resolved is None {
            return None;
        }
        parent_resolved: any = None;
        if len(prefix) > 1 {
            parent_resolved = self._resolve_module_to_file(
                "::".join(prefix[:-1]), file_path, "rust"
            );
        }
        if parent_resolved == resolved and prefix[-1] not in {"crate", "self", "super"} {
            return f"{self._qualify(prefix[-1], resolved, None)}.{method}";
        }
        return self._qualify(method, resolved, None);
    }

    def _resolve_call_target(
        call_name: str,
        file_path: str,
        language: str,
        import_map: dict[str, str],
        defined_names: set[str],
    ) -> str {
        if language == "rust" and "::" in call_name {
            resolved_rust: any = self._resolve_rust_scoped_call(
                call_name, file_path, import_map, defined_names
            );
            if resolved_rust {
                return resolved_rust;
            }
        }
        if call_name in defined_names {
            if language == "cpp" {
                return call_name;
            }
            return self._qualify(call_name, file_path, None);
        }
        if call_name in import_map {
            if language == "julia" {
                return import_map[call_name];
            }
            module_binding: any = import_map.get(f"{_PY_MODULE_BINDING_KEY}{call_name}");
            if module_binding {
                return module_binding;
            }
            resolved: any = self._resolve_imported_symbol(
                self._js_imported_symbol_name(call_name, import_map),
                import_map[call_name],
                file_path,
                language,
            );
            if resolved {
                return resolved;
            }
        }
        return call_name;
    }

    def _resolve_imported_symbol(
        symbol_name: str, module: str, file_path: str, language: str
    ) -> Optional[str] {
        module_path: any = Path(module);
        if language == "python" and module_path.is_absolute() {
            try {
                candidate: any = module_path.resolve();
            } except (OSError, ValueError) {
                return None;
            }
            boundary: any = self._import_repo_boundary(file_path);
            if not self._path_is_within(candidate, boundary) or not candidate.is_file() {
                return None;
            }
            resolved: any = normalize_file_path(candidate);
        } else {
            resolved = self._resolve_module_to_file(module, file_path, language);
        }
        if not resolved {
            return None;
        }

        if language == "python" {
            resolved = self._python_reexport_origin(resolved, symbol_name);
        }
        export_target: any = self._resolve_exported_symbol(resolved, symbol_name);
        if export_target {
            return export_target;
        }
        if language in ("java", "kotlin", "scala") {
            symbol_name = _nested_import_chain(module, resolved, symbol_name);
        }
        return self._qualify(symbol_name, resolved, None);
    }

    def _python_reexport_origin(module_file: str, symbol_name: str) -> str {
        if not module_file.endswith(".py") {
            return module_file;
        }
        cache_key: any = f"{module_file}::{symbol_name}";
        cached: any = self._python_reexport_cache.get(cache_key);
        if cached is not None {
            return cached;
        }
        try {
            real_path: Optional[Path] = Path(module_file).resolve();
        } except (OSError, ValueError) {
            real_path = None;
        }
        origin: any = self._get_python_star_exports(module_file).get(symbol_name)
            if real_path is not None
                and self._path_is_within(real_path, self._import_repo_boundary(module_file))
            else None;
        result: any = origin if origin and origin != module_file else module_file;
        if len(self._python_reexport_cache) >= self._MODULE_CACHE_MAX {
            self._python_reexport_cache.clear();
        }
        self._python_reexport_cache[cache_key] = result;
        return result;
    }

    def _resolve_exported_symbol(
        module_file: str, symbol_name: str, seen: Optional[set[tuple[str, str]]] = None
    ) -> Optional[str] {
        cache_key: any = f"{module_file}::{symbol_name}";
        if cache_key in self._export_symbol_cache {
            return self._export_symbol_cache[cache_key];
        }

        key: any = (module_file, symbol_name);
        if seen is None {
            seen = set[any]();
        }
        if key in seen {
            return None;
        }
        seen.add(key);

        path: any = Path(module_file);
        language: any = self.detect_language(path);
        if language not in ("javascript", "typescript", "tsx", "vue") {
            return None;
        }

        try {
            source: any = path.read_bytes();
        } except (OSError, PermissionError) {
            return None;
        }

        parser: any = self._get_parser(language);
        if not parser {
            return None;
        }

        tree: any = parser.parse(source);
        import_map: any;
        defined_names: any;
        (import_map, defined_names) = self._collect_file_scope(
            tree.root_node, language, source, module_file
        ) as any;
        if symbol_name in defined_names {
            result: any = self._qualify(symbol_name, module_file, None);
            self._export_symbol_cache[cache_key] = result;
            return result;
        }

        for child in tree.root_node.children {
            if child.type != "export_statement" {
                continue;
            }

            export_clause: any = None;
            target_module: any = None;
            has_star_export: any = False;

            for sub in child.children {
                if sub.type == "export_clause" {
                    export_clause = sub;
                } elif sub.type == "string" {
                    target_module = sub.text.decode("utf-8", errors="replace").strip("'\"");
                } elif sub.type == "*" {
                    has_star_export = True;
                }
            }
            if export_clause is not None {
                for spec in export_clause.children {
                    if spec.type != "export_specifier" {
                        continue;
                    }
                    names: any = [
                        part.text.decode("utf-8", errors="replace")
                        for part in spec.children
                        if part.type in ("identifier", "property_identifier")
                    ];
                    if not names {
                        continue;
                    }
                    exported_name: any = names[-1];
                    original_name: any = names[0];
                    if exported_name != symbol_name {
                        continue;
                    }
                    if target_module {
                        resolved_module: any = self._resolve_module_to_file(
                            target_module, module_file, language
                        );
                        if resolved_module {
                            result = self._resolve_exported_symbol(
                                resolved_module, original_name, seen
                            )
                                or self._qualify(original_name, resolved_module, None);
                            self._export_symbol_cache[cache_key] = result;
                            return result;
                        }
                    }
                    result = self._qualify(original_name, module_file, None);
                    self._export_symbol_cache[cache_key] = result;
                    return result;
                }
            }
            if has_star_export and target_module {
                resolved_module = self._resolve_module_to_file(
                    target_module, module_file, language
                );
                if resolved_module {
                    result = self._resolve_exported_symbol(resolved_module, symbol_name, seen);
                    if result {
                        self._export_symbol_cache[cache_key] = result;
                        return result;
                    }
                }
            }
        }

        self._export_symbol_cache[cache_key] = None;
        return None;
    }

    def _qualify(name: str, file_path: str, enclosing_class: Optional[str]) -> str {
        file_path = normalize_file_path(file_path);
        if enclosing_class {
            return f"{file_path}::{enclosing_class}.{name}";
        }
        return f"{file_path}::{name}";
    }

    def _node_qualified(`node: NodeInfo) -> str {
        return self._qualify(`node.identity_name or `node.name, `node.file_path, `node.parent_name);
    }

    static has _CUSTOM_NAME_LEAF_TYPES: any = tuple(
        ("word identifier name simple_identifier command_name key_brace type_identifier "
            "property_identifier constant").split(),
    );

    static has _MAX_CUSTOM_NAME_DEPTH: any = 4;

    static has _MAX_CUSTOM_NAME_LEN: any = 256;

    def _custom_name_leaf(`node, depth: int) -> any {
        if `node.type in self._CUSTOM_NAME_LEAF_TYPES and `node.child_count == 0 {
            return `node;
        }
        if depth <= 0 {
            return None;
        }
        for child in `node.children {
            found: any = self._custom_name_leaf(child, depth - 1);
            if found is not None {
                return found;
            }
        }
        return None;
    }

    def _find_custom_descendant(`node, type_name: str, depth: int) -> any {
        if depth <= 0 {
            return None;
        }
        for child in `node.children {
            if child.type == type_name {
                return child;
            }
            found: any = self._find_custom_descendant(child, type_name, depth - 1);
            if found is not None {
                return found;
            }
        }
        return None;
    }

    def _clean_custom_name(text: str) -> Optional[str] {
        cleaned: any = text.strip().strip("{}\"'").strip();
        if not cleaned or "\n" in cleaned or len(cleaned) > self._MAX_CUSTOM_NAME_LEN {
            return None;
        }
        return cleaned;
    }

    def _custom_leaf_name(`node) -> Optional[str] {
        leaf: any = self._custom_name_leaf(`node, self._MAX_CUSTOM_NAME_DEPTH);
        target: any = leaf if leaf is not None else `node;
        return self._clean_custom_name(target.text.decode("utf-8", errors="replace"));
    }

    def _resolve_custom_name(`node, language: str) -> Optional[str] {
        custom: any = self._custom_languages.get(language);
        candidates: any = custom.name_field if custom is not None else ();
        if not candidates {
            return None;
        }
        cand: any;
        for cand in candidates {
            target: any = `node.child_by_field_name(cand);
            if target is not None {
                resolved: any = self._custom_leaf_name(target);
                if resolved {
                    return resolved;
                }
            }
        }
        for cand in candidates {
            target = self._find_custom_descendant(`node, cand, self._MAX_CUSTOM_NAME_DEPTH);
            if target is not None {
                resolved = self._custom_leaf_name(target);
                if resolved {
                    return resolved;
                }
            }
        }
        return None;
    }

    def _get_name(`node, language: str, kind: str) -> Optional[str] {
        if language == "powershell" {
            child: any;
            for child in `node.children {
                if child.type in ("function_name", "simple_name") {
                    name: any = child.text.decode("utf-8", errors="replace");
                    return _POWERSHELL_SCOPE_RE.sub("", name);
                }
            }
            return None;
        }
        if language == "dart" and `node.type == "function_signature" {
            for child in `node.children {
                if child.type == "identifier" {
                    return child.text.decode("utf-8", errors="replace");
                }
            }
            return None;
        }
        if language == "solidity" {
            if `node.type == "constructor_definition" {
                return "constructor";
            }
            if `node.type == "fallback_receive_definition" {
                for child in `node.children {
                    if child.type in ("receive", "fallback") {
                        return child.text.decode("utf-8", errors="replace");
                    }
                }
            }
        }
        if language in ("lua", "luau") and `node.type == "function_declaration" {
            for child in `node.children {
                if child.type in ("dot_index_expression", "method_index_expression") {
                    sub: any;
                    for sub in reversed(child.children) {
                        if sub.type == "identifier" {
                            return sub.text.decode("utf-8", errors="replace");
                        }
                    }
                    return None;
                }
            }
        }
        if language == "perl" {
            for child in `node.children {
                if child.type == "bareword" {
                    return child.text.decode("utf-8", errors="replace");
                }
                if child.type == "package" and child.text != b"package" {
                    return child.text.decode("utf-8", errors="replace");
                }
            }
        }
        if language in ("java", "csharp")
            and kind == "function"
            and `node.type in ("method_declaration", "constructor_declaration")
        {
            name_node: any = `node.child_by_field_name("name");
            if name_node is not None {
                return name_node.text.decode("utf-8", errors="replace");
            }
        }

        if language == "cpp" and kind == "function" {
            declarator: any = `node.child_by_field_name("declarator");
            if `node.type in ("declaration", "field_declaration") {
                if not self._cpp_declaration_has_callable_scope(`node)
                    or not self._cpp_is_callable_declaration(declarator)
                {
                    return None;
                }
                return self._cpp_callable_name(declarator);
            }
            cpp_name: any = self._cpp_callable_name(declarator);
            if cpp_name {
                return cpp_name;
            }
        }
        if language in ("c", "cpp", "objc") and kind == "function" {
            for child in `node.children {
                if child.type in ("function_declarator", "pointer_declarator") {
                    for sub in child.children {
                        if sub.type == "qualified_identifier" {
                            for qsub in reversed(sub.children) {
                                if qsub.type in ("identifier", "field_identifier") {
                                    return qsub.text.decode("utf-8", errors="replace");
                                }
                            }
                        }
                    }
                    result: any = self._get_name(child, language, kind);
                    if result {
                        return result;
                    }
                }
            }
            if language == "cpp" and `node.type == "function_declarator" {
                def _leaf_name(qi) -> any {
                    for sub in reversed(qi.children) {
                        if sub.type in ("identifier", "destructor_name", "operator_name") {
                            return sub.text.decode("utf-8", errors="replace");
                        }
                        if sub.type == "qualified_identifier" {
                            inner: any = _leaf_name(sub);
                            if inner {
                                return inner;
                            }
                        }
                    }
                    return None;
                }
                for child in `node.children {
                    if child.type == "qualified_identifier" {
                        name = _leaf_name(child);
                        if name {
                            return name;
                        }
                    }
                    if child.type in ("field_identifier", "destructor_name", "operator_name") {
                        return child.text.decode("utf-8", errors="replace");
                    }
                }
            }
        }
        if language == "objc" and `node.type == "method_definition" {
            for child in `node.children {
                if child.type == "identifier" {
                    return child.text.decode("utf-8", errors="replace");
                }
            }
        }
        if language == "bash" and `node.type == "function_definition" {
            for child in `node.children {
                if child.type == "word" {
                    return child.text.decode("utf-8", errors="replace");
                }
            }
        }
        if language == "go" and `node.type == "method_declaration" {
            for child in `node.children {
                if child.type == "field_identifier" {
                    return child.text.decode("utf-8", errors="replace");
                }
            }
        }
        if language == "swift"
            and `node.type in ("init_declaration", "deinit_declaration", "subscript_declaration")
        {
            return `node.type.removesuffix("_declaration");
        }
        if language == "swift" and `node.type == "class_declaration" {
            for child in `node.children {
                if child.type == "user_type" {
                    for sub in child.children {
                        if sub.type == "type_identifier" {
                            return sub.text.decode("utf-8", errors="replace");
                        }
                    }
                }
            }
        }
        if language == "verilog" {
            if `node.type == "package_declaration" {
                for child in `node.children {
                    if child.type == "package_identifier" {
                        for sub in child.children {
                            if sub.type == "simple_identifier" {
                                return sub.text.decode("utf-8", errors="replace");
                            }
                        }
                    }
                }
            }
            if `node.type == "module_declaration" {
                for child in `node.children {
                    if child.type == "module_header" {
                        for sub in child.children {
                            if sub.type == "simple_identifier" {
                                return sub.text.decode("utf-8", errors="replace");
                            }
                        }
                    }
                }
            }
            if `node.type == "interface_declaration" {
                for child in `node.children {
                    if child.type in ("interface_header", "interface_ansi_header") {
                        for sub in child.children {
                            if sub.type == "simple_identifier" {
                                return sub.text.decode("utf-8", errors="replace");
                            }
                            if sub.type == "interface_identifier" {
                                for ss in sub.children {
                                    if ss.type == "simple_identifier" {
                                        return ss.text.decode("utf-8", errors="replace");
                                    }
                                }
                                return sub.text.decode("utf-8", errors="replace");
                            }
                        }
                    }
                }
            }
            if `node.type == "task_declaration" {
                for child in `node.children {
                    if child.type == "task_body_declaration" {
                        for sub in child.children {
                            if sub.type == "task_identifier" {
                                return sub.text.decode("utf-8", errors="replace");
                            }
                        }
                    }
                }
            }
            if `node.type == "function_declaration" {
                for child in `node.children {
                    if child.type == "function_body_declaration" {
                        for sub in child.children {
                            if sub.type == "function_identifier" {
                                return sub.text.decode("utf-8", errors="replace");
                            }
                        }
                    }
                }
            }
        }
        if language == "julia" {
            if `node.type in ("function_definition", "macro_definition") {
                callee: any = self._julia_signature_callee(`node);
                if callee is None {
                    return None;
                }
                if callee.type == "field_expression" {
                    _: any;
                    (_, name) = self._julia_field_info(callee) as any;
                    return name;
                }
                if callee.type == "parametrized_type_expression" {
                    for part in callee.children {
                        if part.type == "identifier" {
                            return part.text.decode("utf-8", errors="replace");
                        }
                    }
                    return None;
                }
                return self._julia_component_name(callee);
            }
            if `node.type in ("struct_definition", "abstract_definition") {
                for child in `node.children {
                    if child.type == "type_head" {
                        for sub in child.children {
                            if sub.type == "identifier" {
                                return sub.text.decode("utf-8", errors="replace");
                            }
                        }
                        for sub in child.children {
                            if sub.type == "binary_expression" {
                                for ident in sub.children {
                                    if ident.type == "identifier" {
                                        return ident.text.decode("utf-8", errors="replace");
                                    }
                                    if ident.type == "parametrized_type_expression" {
                                        p: any;
                                        for p in ident.children {
                                            if p.type == "identifier" {
                                                return p.text.decode("utf-8", errors="replace");
                                            }
                                        }
                                        return None;
                                    }
                                }
                                return None;
                            }
                        }
                        for sub in child.children {
                            if sub.type == "parametrized_type_expression" {
                                for p in sub.children {
                                    if p.type == "identifier" {
                                        return p.text.decode("utf-8", errors="replace");
                                    }
                                }
                                return None;
                            }
                        }
                    }
                }
                return None;
            }
        }
        if language in self._custom_languages {
            resolved: any = self._resolve_custom_name(`node, language);
            if resolved {
                return resolved;
            }
            name_child: any = `node.child_by_field_name("name");
            if name_child is not None {
                return name_child.text.decode("utf-8", errors="replace");
            }
        }
        if language == "ruby" and `node.type in ("class", "module") {
            name_child = `node.child_by_field_name("name");
            if name_child is not None and name_child.type == "scope_resolution" {
                scope: any = name_child.child_by_field_name("scope");
                while scope is not None and scope.type == "scope_resolution" {
                    scope = scope.child_by_field_name("scope");
                }
                if scope is None or scope.type == "constant" {
                    for sub in reversed(name_child.children) {
                        if sub.type == "constant" {
                            return sub.text.decode("utf-8", errors="replace");
                        }
                    }
                }
            }
        }
        for child in `node.children {
            if child.type
                in (
                    "identifier",
                    "name",
                    "type_identifier",
                    "property_identifier",
                    "simple_identifier",
                    "constant",
                    "field_identifier",
                )
            {
                return child.text.decode("utf-8", errors="replace");
            }
        }
        if language == "go" and `node.type == "type_declaration" {
            for child in `node.children {
                if child.type == "type_spec" {
                    return self._get_name(child, language, kind);
                }
            }
        }
        return None;
    }

    def _get_go_receiver_type(`node) -> Optional[str] {
        receiver: any = `node.child_by_field_name("receiver");
        if receiver is None {
            return None;
        }
        parameter: any = next(
            (child for child in receiver.named_children if child.type == "parameter_declaration"),
            None,
        );
        receiver_type: any = parameter.child_by_field_name("type") if parameter else None;
        while receiver_type is not None
            and receiver_type.type in {"generic_type", "pointer_type", "parenthesized_type"}
        {
            receiver_type = next(
                (child for child in receiver_type.named_children if child.type != "comment"), None
            );
        }
        if receiver_type is None or receiver_type.type != "type_identifier" {
            return None;
        }
        return receiver_type.text.decode("utf-8", errors="replace");
    }

    static def _get_go_receiver_name(`node) -> Optional[str] {
        receiver: any = `node.child_by_field_name("receiver");
        if receiver is None {
            return None;
        }
        parameter: any = next(
            (child for child in receiver.children if child.type == "parameter_declaration"), None
        );
        if parameter is None {
            return None;
        }
        name: any = next(
            (child for child in parameter.children if child.type == "identifier"), None
        );
        return name.text.decode("utf-8", errors="replace") if name else None;
    }

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

    static def _go_field_binds_name(`node, field: str, name: str) -> bool {
        for field_node in `node.children_by_field_name(field) {
            candidates: any = field_node.named_children
                if field_node.type == "expression_list"
                else (field_node,);
            if `any(
                candidate.type in {"identifier", "type_identifier"}
                    and operator.eq(candidate.text.decode("utf-8", errors="replace"), name)
                for candidate in candidates,
            ) {
                return True;
            }
        }
        return False;
    }

    class def _go_function_parameters_bind_name(`node, name: str) -> bool {
        for field_name in ("parameters", "result") {
            for parameter_list in `node.children_by_field_name(field_name) {
                if `any(
                    parameter.type in CodeParser._GO_PARAMETER_TYPES
                        and CodeParser._go_field_binds_name(parameter, "name", name)
                    for parameter in parameter_list.named_children,
                ) {
                    return True;
                }
            }
        }
        return False;
    }

    def _go_receiver_binding_index(
        method, receiver_name: str
    ) -> tuple[str, tuple[int, ...], tuple[int, ...]] {
        scope: any;
        body: any = method.child_by_field_name("body");
        if body is None {
            return (receiver_name, (), ());
        }

        def scope_key(scope) -> tuple[str, int, int] {
            return (scope.type, scope.start_byte, scope.end_byte);
        }

        intervals: list[tuple[int, int]] = [];
        receiver_scopes: any = {scope_key(body)};
        stack: any = [(body, body)];
        while stack {
            `node: any;
            (`node, scope) = stack.pop() as any;
            if `node.type in self._GO_LEXICAL_SCOPE_TYPES {
                scope = `node;
            }

            if `node.type == "func_literal" {
                function_body: any = `node.child_by_field_name("body");
                if function_body is not None
                    and self._go_function_parameters_bind_name(`node, receiver_name)
                {
                    intervals.append((function_body.start_byte, function_body.end_byte));
                    receiver_scopes.add(scope_key(function_body));
                }
            }

            if `node.type == "type_switch_statement"
                and self._go_field_binds_name(`node, "alias", receiver_name)
            {
                for `case in `node.named_children {
                    if `case.type not in {"default_case", "type_case"} {
                        continue;
                    }
                    statements: any = next(
                        (child for child in `case.named_children if child.type == "statement_list"),
                        None,
                    );
                    if statements is not None {
                        intervals.append((statements.start_byte, `case.end_byte));
                    }
                    receiver_scopes.add(scope_key(`case));
                }
            }

            declaration_field: any = self._GO_DECLARATION_NAME_FIELDS.get(`node.type);
            if declaration_field is not None
                and self._go_field_binds_name(`node, declaration_field, receiver_name)
            {
                intervals.append((`node.end_byte, scope.end_byte));
                receiver_scopes.add(scope_key(scope));
            }

            if `node.type == "short_var_declaration"
                and self._go_field_binds_name(`node, "left", receiver_name)
            {
                parent: any = `node.parent;
                if parent is not None and parent.type == "for_clause" {
                    binding_scope: any = parent.parent;
                } elif parent is not None and parent.type in self._GO_INIT_SCOPE_PARENTS {
                    binding_scope = parent;
                } else {
                    binding_scope = scope;
                }
                if binding_scope is not None and scope_key(binding_scope) not in receiver_scopes {
                    intervals.append((`node.end_byte, binding_scope.end_byte));
                    receiver_scopes.add(scope_key(binding_scope));
                }
            }

            if `node.type == "range_clause"
                and `any(operator.eq(child.type, ":=") for child in `node.children)
                and self._go_field_binds_name(`node, "left", receiver_name)
            {
                loop: any = `node.parent;
                loop_body: any = loop.child_by_field_name("body") if loop is not None else None;
                if loop_body is not None {
                    intervals.append((loop_body.start_byte, loop_body.end_byte));
                    receiver_scopes.add(scope_key(loop_body));
                }
            }

            if `node.type == "receive_statement"
                and `any(operator.eq(child.type, ":=") for child in `node.children)
                and self._go_field_binds_name(`node, "left", receiver_name)
                and `node.parent is not None
            {
                intervals.append((`node.end_byte, `node.parent.end_byte));
                receiver_scopes.add(scope_key(`node.parent));
            }

            stack.extend((child, scope) for child in reversed(`node.named_children));
        }

        merged: list[tuple[int, int]] = [];
        for (start, end) in sorted(intervals) {
            if start >= end {
                continue;
            }
            if merged and start <= merged[-1][1] {
                merged[-1] = (merged[-1][0], max(merged[-1][1], end));
            } else {
                merged.append((start, end));
            }
        }
        return (
            receiver_name,
            `tuple(start for (start, _) in merged),
            `tuple(end for (_, end) in merged),
        );
    }

    static def _go_receiver_is_shadowed(
        `node, bindings: tuple[str, tuple[int, ...], tuple[int, ...]]
    ) -> bool {
        index: any = bisect_right(bindings[1], `node.start_byte) - 1;
        return operator.ge(index, 0) and operator.lt(`node.start_byte, bindings[2][index]);
    }

    static def _cpp_scope_join(outer: Optional[str], inner: Optional[str]) -> Optional[str] {
        if outer and inner {
            return f"{outer}.{inner}";
        }
        return outer or inner;
    }

    def _cpp_lexical_namespace(`node) -> Optional[str] {
        namespaces: list[str] = [];
        ancestor: any = `node.parent;
        while ancestor is not None {
            if ancestor.type == "namespace_definition" {
                name_node: any = ancestor.child_by_field_name("name");
                namespace: any = name_node.text.decode("utf-8", errors="replace")
                    if name_node is not None
                    else "(anonymous)";
                namespaces.append(re.sub("\\s*::\\s*", ".", namespace));
            }
            ancestor = ancestor.parent;
        }
        namespaces.reverse();
        return ".".join(namespaces) or None;
    }

    def _cpp_lexical_class_names(`node) -> list[str] {
        classes: list[str] = [];
        ancestor: any = `node.parent;
        class_types: any = self._class_types.get("cpp", []);
        while ancestor is not None {
            if ancestor.type in class_types {
                name: any = self._get_name(ancestor, "cpp", "class");
                if name {
                    classes.append(name);
                }
            }
            ancestor = ancestor.parent;
        }
        classes.reverse();
        return classes;
    }

    def _cpp_function_identity(
        `node, name: str, source: bytes
    ) -> tuple[Optional[str], str, Optional[str]] {
        declarator_root: any = `node.child_by_field_name("declarator");
        declarator: any = self._cpp_find_function_declarator(declarator_root);
        if declarator is None {
            return (None, name, None);
        }

        callable_name: any = self._cpp_callable_name(declarator_root) or name;
        callable_node: any = declarator.child_by_field_name("declarator");
        if declarator_root is not None and declarator_root.type == "qualified_identifier" {
            callable_node = declarator_root;
        } elif callable_node is not None and callable_node.type != "qualified_identifier" {
            callable_node = self._cpp_find_qualified_identifier(callable_node);
        }
        explicit_scope: Optional[str] = None;
        if callable_node is not None and callable_node.type == "qualified_identifier" {
            callable_text: any = callable_node.text.decode("utf-8", errors="replace");
            if "::" in callable_text {
                scope_text: any = callable_text.rsplit("::", 1)[0].lstrip(":").strip();
                explicit_scope = re.sub("\\s*::\\s*", ".", scope_text);
            }
        }

        parameters: any = declarator.child_by_field_name("parameters");
        if parameters is None {
            return (explicit_scope, name, None);
        }

        parameter_types: any = [
            self._cpp_parameter_type(parameter, source)
            for parameter in parameters.named_children
            if parameter.type != "comment"
        ];
        parameter_types = [value for value in parameter_types if value];
        if `any(operator.eq(child.type, "...") for child in parameters.children) {
            parameter_types.append("...");
        }
        if parameter_types == ["void"] {
            parameter_types = [];
        }
        qualifiers: any = [
            child.text.decode("utf-8", errors="replace").strip()
            for child in declarator.children
            if child.type in ("type_qualifier", "ref_qualifier")
        ];
        qualifier_suffix: any = f" {" ".join(qualifiers)}" if qualifiers else "";
        raw_params: any = parameters.text.decode("utf-8", errors="replace");
        return (
            explicit_scope,
            f"{callable_name}({",".join(parameter_types)}){qualifier_suffix}",
            raw_params,
        );
    }

    def _cpp_find_function_declarator(declarator) -> any {
        if declarator is None {
            return None;
        }
        if declarator.type in ("function_declarator", "abstract_function_declarator") {
            nested: any = self._cpp_find_function_declarator(
                declarator.child_by_field_name("declarator")
            );
            if nested is not None {
                return nested;
            }
            return declarator;
        }
        for child in declarator.named_children {
            if child.type in ("parameter_list", "template_argument_list") {
                continue;
            }
            found: any = self._cpp_find_function_declarator(child);
            if found is not None {
                return found;
            }
        }
        return None;
    }

    def _cpp_is_callable_declaration(declarator) -> bool {
        function_declarator: any = self._cpp_find_function_declarator(declarator);
        if function_declarator is None {
            return False;
        }

        callable_declarator: any = function_declarator.child_by_field_name("declarator");
        if callable_declarator is None or callable_declarator.type != "parenthesized_declarator" {
            return True;
        }
        return self._cpp_find_function_declarator(callable_declarator) is not None;
    }

    static def _cpp_declaration_has_callable_scope(declaration) -> bool {
        scope: any = declaration.parent;
        while scope is not None {
            if scope.type
                in ("translation_unit", "namespace_definition", "field_declaration_list")
            {
                return not _is_in_static_dead_guard(declaration);
            }
            if scope.type in ("compound_statement", "function_definition", "lambda_expression") {
                return False;
            }
            scope = scope.parent;
        }
        return False;
    }

    def _cpp_find_qualified_identifier(declarator) -> any {
        if declarator is None {
            return None;
        }
        if declarator.type == "qualified_identifier" {
            return declarator;
        }
        for child in declarator.named_children {
            if child.type in ("parameter_list", "template_argument_list") {
                continue;
            }
            found: any = self._cpp_find_qualified_identifier(child);
            if found is not None {
                return found;
            }
        }
        return None;
    }

    def _cpp_callable_name(declarator) -> Optional[str] {
        if declarator is None {
            return None;
        }

        operator_cast: any = self._cpp_find_declarator_kind(declarator, "operator_cast");
        if operator_cast is not None {
            function_declarator: any = self._cpp_find_function_declarator(operator_cast);
            if function_declarator is not None {
                prefix_end: any = function_declarator.start_byte - operator_cast.start_byte;
                name: any = operator_cast.text[:prefix_end].decode("utf-8", errors="replace");
                name = re.sub("\\s+", " ", name).strip();
                return re.sub("\\s*([*&])\\s*", "\\1", name);
            }
        }

        def leaf_name(current) -> any {
            for child in reversed(current.named_children) {
                if child.type in ("parameter_list", "template_argument_list") {
                    continue;
                }
                if child.type
                    in ("identifier", "field_identifier", "destructor_name", "operator_name")
                {
                    return child.text.decode("utf-8", errors="replace");
                }
                found: any = leaf_name(child);
                if found {
                    return found;
                }
            }
            return None;
        }

        return leaf_name(declarator);
    }

    def _cpp_find_declarator_kind(declarator, kind: str) -> any {
        if declarator is None {
            return None;
        }
        if declarator.type == kind {
            return declarator;
        }
        for child in declarator.named_children {
            if child.type in ("parameter_list", "template_argument_list") {
                continue;
            }
            found: any = self._cpp_find_declarator_kind(child, kind);
            if found is not None {
                return found;
            }
        }
        return None;
    }

    def _cpp_parameter_type(parameter, source: bytes) -> str {
        end_byte: any = parameter.end_byte;
        for child in parameter.children {
            if child.type == "=" {
                end_byte = child.start_byte;
                break;
            }
        }

        declarator: any = parameter.child_by_field_name("declarator");
        name_node: any = self._cpp_declarator_name(declarator);
        if name_node is not None and name_node.start_byte < end_byte {
            raw: any = (
                source[parameter.start_byte:name_node.start_byte]
                + source[name_node.end_byte:end_byte]
            ).decode("utf-8", errors="replace");
        } else {
            raw = source[parameter.start_byte:end_byte].decode("utf-8", errors="replace");
        }

        raw = re.sub("/\\*.*?\\*/|//[^\\r\\n]*", " ", raw, flags=re.DOTALL);
        raw = re.sub("\\[\\[.*?\\]\\]", " ", raw, flags=re.DOTALL);
        normalized: any = re.sub("\\s+", " ", raw).strip();
        normalized = re.sub("\\s*::\\s*", "::", normalized);
        normalized = re.sub("\\s*([<>,*&()\\[\\]])\\s*", "\\1", normalized);
        return normalized;
    }

    def _cpp_declarator_name(declarator) -> any {
        if declarator is None {
            return None;
        }
        if declarator.type in ("identifier", "field_identifier") {
            return declarator;
        }

        nested: any = declarator.child_by_field_name("declarator");
        if nested is not None and nested != declarator {
            found: any = self._cpp_declarator_name(nested);
            if found is not None {
                return found;
            }
        }

        for child in declarator.named_children {
            if child.type in ("parameter_list", "template_argument_list") {
                continue;
            }
            found = self._cpp_declarator_name(child);
            if found is not None {
                return found;
            }
        }
        return None;
    }

    def _get_params(`node, language: str, source: bytes) -> Optional[str] {
        for child in `node.children {
            param_types: any = (
                "parameters",
                "formal_parameters",
                "parameter_list",
                "formal_parameter_list",
            );
            if child.type in param_types {
                return child.text.decode("utf-8", errors="replace");
            }
        }
        if language == "solidity" {
            params: any = [
                c.text.decode("utf-8", errors="replace")
                for c in `node.children
                if c.type == "parameter"
            ];
            if params {
                return f"({", ".join(params)})";
            }
        }
        return None;
    }

    def _get_return_type(`node, language: str, source: bytes) -> Optional[str] {
        child: any;
        for child in `node.children {
            if child.type in ("type", "return_type", "type_annotation", "return_type_definition") {
                return child.text.decode("utf-8", errors="replace");
            }
        }
        if language == "python" {
            for (i, child) in enumerate(`node.children) {
                if child.type == "->" and i + 1 < len(`node.children) {
                    return `node.children[i + 1].text.decode("utf-8", errors="replace");
                }
            }
        }
        return None;
    }

    def _get_bases(`node, language: str, source: bytes) -> list[str] {
        field: any;
        bases: any = [];
        if language == "python" {
            child: any;
            for child in `node.children {
                if child.type == "argument_list" {
                    for arg in child.children {
                        if arg.type in ("identifier", "attribute") {
                            bases.append(arg.text.decode("utf-8", errors="replace"));
                        }
                    }
                }
            }
        } elif language == "java" {
            for child in `node.children {
                if child.type == "superclass" {
                    sub: any;
                    for sub in child.children {
                        if sub.type in ("type_identifier", "generic_type") {
                            bases.append(sub.text.decode("utf-8", errors="replace"));
                        }
                    }
                } elif child.type == "super_interfaces" {
                    for sub in child.children {
                        if sub.type == "type_list" {
                            ident: any;
                            for ident in sub.children {
                                if ident.type in ("type_identifier", "generic_type") {
                                    bases.append(ident.text.decode("utf-8", errors="replace"));
                                }
                            }
                        }
                    }
                }
            }
        } elif language == "csharp" {
            if `node.type == "enum_declaration" {
                return bases;
            }
            for child in `node.children {
                if child.type != "base_list" {
                    continue;
                }
                for sub in child.children {
                    if not sub.is_named or sub.type == "argument_list" {
                        continue;
                    }
                    if sub.type == "primary_constructor_base_type" {
                        type_node: any = sub.child_by_field_name("type");
                        if type_node is not None {
                            bases.append(type_node.text.decode("utf-8", errors="replace"));
                        } else {
                            for nested in sub.children {
                                if nested.is_named and nested.type != "argument_list" {
                                    bases.append(nested.text.decode("utf-8", errors="replace"));
                                    break;
                                }
                            }
                        }
                        continue;
                    }
                    bases.append(sub.text.decode("utf-8", errors="replace"));
                }
            }
        } elif language == "kotlin" {
            for child in `node.children {
                if child.type
                    in (
                        "superclass",
                        "super_interfaces",
                        "extends_type",
                        "implements_type",
                        "type_identifier",
                        "supertype",
                        "delegation_specifier",
                    )
                {
                    text: any = child.text.decode("utf-8", errors="replace");
                    bases.append(text);
                }
            }
        } elif language == "scala" {
            for child in `node.children {
                if child.type == "extends_clause" {
                    for sub in child.children {
                        if sub.type == "type_identifier" {
                            bases.append(sub.text.decode("utf-8", errors="replace"));
                        } elif sub.type == "generic_type" {
                            for ident in sub.children {
                                if ident.type == "type_identifier" {
                                    bases.append(ident.text.decode("utf-8", errors="replace"));
                                    break;
                                }
                            }
                        }
                    }
                }
            }
        } elif language == "cpp" {
            for child in `node.children {
                if child.type == "base_class_clause" {
                    for sub in child.children {
                        if sub.type == "type_identifier" {
                            bases.append(sub.text.decode("utf-8", errors="replace"));
                        }
                    }
                }
            }
        } elif language in ("typescript", "javascript", "tsx") {
            clauses: list = [];
            for child in `node.children {
                if child.type == "class_heritage" {
                    clauses.extend(child.children);
                } else {
                    clauses.append(child);
                }
            }
            for clause in clauses {
                if clause.type not in _TS_HERITAGE_CLAUSES {
                    continue;
                }
                for sub in clause.children {
                    if sub.type in ("identifier", "type_identifier", "nested_identifier") {
                        bases.append(sub.text.decode("utf-8", errors="replace"));
                    } elif sub.type == "generic_type" {
                        for ident in sub.children {
                            if ident.type in ("type_identifier", "nested_type_identifier") {
                                bases.append(ident.text.decode("utf-8", errors="replace"));
                                break;
                            }
                        }
                    }
                }
            }
        } elif language == "solidity" {
            for child in `node.children {
                if child.type == "inheritance_specifier" {
                    for sub in child.children {
                        if sub.type == "user_defined_type" {
                            for ident in sub.children {
                                if ident.type == "identifier" {
                                    bases.append(ident.text.decode("utf-8", errors="replace"));
                                }
                            }
                        }
                    }
                }
            }
        } elif language == "go" {
            spec: any = `node
                if `node.type == "type_spec"
                else next(
                    (child for child in `node.named_children if child.type == "type_spec"), None
                );
            body: any = spec.child_by_field_name("type") if spec is not None else None;
            embedded_types: list = [];
            if body is not None and body.type == "struct_type" {
                for fields in body.named_children {
                    if fields.type != "field_declaration_list" {
                        continue;
                    }
                    for field in fields.named_children {
                        if field.type == "field_declaration"
                            and field.child_by_field_name("name") is None
                        {
                            embedded_types.append(field.child_by_field_name("type"));
                        }
                    }
                }
            } elif body is not None and body.type == "interface_type" {
                for element in body.named_children {
                    if element.type != "type_elem" {
                        continue;
                    }
                    types: any = [
                        part
                        for part in element.named_children
                        if part.type != "comment"
                    ];
                    if len(types) == 1 {
                        embedded_types.append(types[0]);
                    }
                }
            }
            embedded: any;
            for embedded in embedded_types {
                if embedded is not None and embedded.type == "generic_type" {
                    embedded = embedded.child_by_field_name("type");
                }
                if embedded is not None and embedded.type in ("type_identifier", "qualified_type") {
                    bases.append(embedded.text.decode("utf-8", errors="replace"));
                }
            }
        } elif language == "dart" {
            for child in `node.children {
                if child.type == "superclass" {
                    for sub in child.children {
                        if sub.type == "type_identifier" {
                            bases.append(sub.text.decode("utf-8", errors="replace"));
                        } elif sub.type == "mixins" {
                            for m in sub.children {
                                if m.type == "type_identifier" {
                                    bases.append(m.text.decode("utf-8", errors="replace"));
                                }
                            }
                        }
                    }
                } elif child.type == "interfaces" {
                    for sub in child.children {
                        if sub.type == "type_identifier" {
                            bases.append(sub.text.decode("utf-8", errors="replace"));
                        }
                    }
                }
            }
        } elif language == "swift" {
            for child in `node.children {
                if child.type == "inheritance_specifier" {
                    for sub in child.children {
                        if sub.type == "user_type" {
                            for ident in sub.children {
                                if ident.type == "type_identifier" {
                                    bases.append(ident.text.decode("utf-8", errors="replace"));
                                    break;
                                }
                            }
                        }
                    }
                }
            }
        } elif language == "julia" {
            if `node.type in ("struct_definition", "abstract_definition") {
                for child in `node.children {
                    if child.type != "type_head" {
                        continue;
                    }
                    for sub in child.children {
                        if sub.type != "binary_expression" {
                            continue;
                        }
                        has_subtype_op: any = False;
                        for op_child in sub.children {
                            if op_child.type == "operator" and op_child.text == b"<:" {
                                has_subtype_op = True;
                                break;
                            }
                        }
                        if not has_subtype_op {
                            continue;
                        }
                        idents: any = [c for c in sub.children if c.type == "identifier"];
                        if len(idents) >= 2 {
                            bases.append(idents[1].text.decode("utf-8", errors="replace"));
                        } elif len(idents) == 1 {
                            bases.append(idents[0].text.decode("utf-8", errors="replace"));
                        }
                    }
                }
            }
        } elif language == "php" {
            for child in `node.children {
                if child.type not in ("base_clause", "class_interface_clause") {
                    continue;
                }
                for base in child.children {
                    if base.type in ("name", "qualified_name") {
                        bases.append(base.text.decode("utf-8", errors="replace"));
                    }
                }
            }
        }
        return bases;
    }

    static def _extract_go_import_specs(`node) -> list[_ImportSpec] {
        specs: list[_ImportSpec];
        specs = [];

        def add(spec_node) {
            for part in spec_node.children {
                if part.type != "interpreted_string_literal" {
                    continue;
                }
                value: any = part.text.decode("utf-8", errors="replace").strip("\"");
                if value {
                    specs.append(_ImportSpec(value, spec_node.start_point[0] + 1));
                }
                return;
            }
        }

        for child in `node.children {
            if child.type == "import_spec_list" {
                for spec in child.children {
                    if spec.type == "import_spec" {
                        add(spec);
                    }
                }
            } elif child.type == "import_spec" {
                add(child);
            }
        }
        return specs;
    }

    static def _ruby_string_literal(`node) -> Optional[str] {
        if `node.type != "string" {
            return None;
        }
        parts: list[str] = [];
        for child in `node.children {
            if child.type == "string_content" {
                parts.append(child.text.decode("utf-8", errors="replace"));
            } elif child.type in ("interpolation", "escape_sequence") {
                return None;
            }
        }
        return "".join(parts) or None;
    }

    def _extract_ruby_import_specs(`node) -> list[_ImportSpec] {
        method: any = `node.child_by_field_name("method");
        if method is None or method.type != "identifier" {
            return [];
        }
        name: any = method.text.decode("utf-8", errors="replace");
        if name not in _RUBY_IMPORT_METHODS {
            return [];
        }
        receiver: any = `node.child_by_field_name("receiver");
        if receiver is not None
            and not (
                name == "autoload" and receiver.type in ("constant", "self", "scope_resolution")
            )
        {
            return [];
        }
        arguments: any = `node.child_by_field_name("arguments");
        if arguments is None {
            return [];
        }
        positional: any = [
            child
            for child in arguments.children
            if child.type not in (",", "(", ")")
        ];
        index: any = _RUBY_IMPORT_PATH_ARGUMENT.get(name, 0);
        if len(positional) <= index {
            return [];
        }
        value: any = self._ruby_string_literal(positional[index]);
        if value is None {
            return [];
        }
        return [_ImportSpec(value, `node.start_point[0] + 1, name)];
    }

    def _extract_import_specs(
        `node, language: str, source: bytes, file_path: Optional[str] = None
    ) -> list[_ImportSpec] {
        if language == "go" {
            return self._extract_go_import_specs(`node);
        }
        context: any = self._import_context(`node, language, source, file_path);
        if language == "ruby" {
            return [
                spec._replace(
                    context=IMPORT_CONTEXT_DEFERRED if spec.form == "autoload" else context
                )
                for spec in self._extract_ruby_import_specs(`node)
            ];
        }
        line: any = `node.start_point[0] + 1;
        specs: any = [
            _ImportSpec(module, line, context=context)
            for module in self._extract_import(`node, language, source, file_path)
        ];
        if language == "python"
            and specs
            and context != IMPORT_CONTEXT_TYPE_ONLY
            and self._python_names_parent_package(`node, specs[0].module, file_path)
        {
            specs[0] = specs[0]._replace(context=IMPORT_CONTEXT_PARENT_PACKAGE);
        }
        return specs;
    }

    def _import_context(
        `node, language: str, source: bytes, file_path: Optional[str]
    ) -> Optional[str] {
        if language == "python" {
            return self._python_import_context(`node, source);
        }
        if language in ("javascript", "typescript", "tsx") {
            return IMPORT_CONTEXT_TYPE_ONLY
                if self._js_import_is_type_only(`node, file_path)
                else None;
        }
        if language == "ruby" {
            current: any = `node.parent;
            while current is not None {
                if current.type in ("method", "singleton_method") {
                    return IMPORT_CONTEXT_DEFERRED;
                }
                current = current.parent;
            }
        }
        return None;
    }

    static def _python_import_context(`node, source: bytes) -> Optional[str] {
        if (`node.start_point[0] + 1, `node.start_point[1])
            in _python_unreachable_import_positions(source)
        {
            return IMPORT_CONTEXT_TYPE_ONLY;
        }
        current: any = `node.parent;
        while current is not None {
            if current.type == "function_definition" {
                return IMPORT_CONTEXT_DEFERRED;
            }
            current = current.parent;
        }
        return None;
    }

    def _python_names_parent_package(`node, module: str, file_path: Optional[str]) -> bool {
        if `node.type != "import_from_statement" or not file_path {
            return False;
        }
        package_dir: any = self._python_package_dir(module, file_path);
        if package_dir is None or package_dir not in Path(file_path).parents {
            return False;
        }
        names: any = `set(self._python_imported_names(`node));
        return `bool(names)
            and operator.eq(names, `set(self._python_submodule_names(`node, package_dir)));
    }

    def _js_import_is_type_only(`node, file_path: Optional[str]) -> bool {
        child: any;
        if `any(operator.eq(child.type, "type") for child in `node.children) {
            return True;
        }
        for child in `node.children {
            if child.type != "import_clause" {
                continue;
            }
            if len(child.named_children) != 1 {
                return False;
            }
            named: any = child.named_children[0];
            if named.type != "named_imports" {
                return False;
            }
            specifiers: any = [
                spec
                for spec in named.named_children
                if spec.type == "import_specifier"
            ];
            return `bool(specifiers)
                and all(
                    `any(operator.eq(part.type, "type") for part in spec.children)
                    for spec in specifiers,
                )
                and not (file_path and self._tsconfig_resolver.keeps_empty_imports(file_path));
        }
        return False;
    }

    def _extract_import(
        `node, language: str, source: bytes, file_path: Optional[str] = None
    ) -> list[str] {
        imports: any = [];
        text: any = `node.text.decode("utf-8", errors="replace").strip();

        if language == "python" {
            if `node.type == "import_from_statement" {
                module_node: any = `node.child_by_field_name("module_name");
                if module_node is not None {
                    module: any = module_node.text.decode("utf-8", errors="replace");
                    imports.extend(self._python_from_import_targets(`node, module, file_path));
                }
            } else {
                child: any;
                for child in `node.children {
                    if child.type == "dotted_name" {
                        imports.append(child.text.decode("utf-8", errors="replace"));
                    } elif child.type == "aliased_import" {
                        imported: any;
                        for imported in child.children {
                            if imported.type == "dotted_name" {
                                imports.append(imported.text.decode("utf-8", errors="replace"));
                                break;
                            }
                        }
                    }
                }
            }
        } elif language in ("javascript", "typescript", "tsx") {
            for child in `node.children {
                if child.type == "string" {
                    val: any = child.text.decode("utf-8", errors="replace").strip("'\"");
                    imports.append(val);
                }
            }
        } elif language == "go" {
            imports.extend(spec.module for spec in self._extract_go_import_specs(`node));
        } elif language == "rust" {
            imports.extend(
                original_path for (_, original_path) in self._parse_rust_use_node(`node)
            );
        } elif language in ("c", "cpp") {
            for child in `node.children {
                if child.type in ("system_lib_string", "string_literal") {
                    val = child.text.decode("utf-8", errors="replace").strip("<>\"");
                    imports.append(val);
                }
            }
        } elif language == "csharp" {
            names: any = [c for c in `node.named_children if c.type != "comment"];
            if names {
                imports.append(_csharp_name(names[-1]));
            }
        } elif language == "java" {
            parts: any = text.split();
            if len(parts) >= 2 {
                imports.append(parts[-1].rstrip(";"));
            }
        } elif language == "kotlin" {
            base: any = "";
            wildcard: any = False;
            for child in `node.children {
                if child.type == "identifier" {
                    base = child.text.decode("utf-8", errors="replace");
                } elif child.type == "wildcard_import" {
                    wildcard = True;
                }
            }
            if base {
                imports.append(f"{base}.*" if wildcard else base);
            }
        } elif language == "solidity" {
            for child in `node.children {
                if child.type == "string" {
                    val = child.text.decode("utf-8", errors="replace").strip("\"");
                    if val {
                        imports.append(val);
                    }
                }
            }
        } elif language == "scala" {
            parts = [];
            selectors: any = [];
            is_wildcard: any = False;
            for child in `node.children {
                if child.type == "identifier" {
                    parts.append(child.text.decode("utf-8", errors="replace"));
                } elif child.type == "namespace_selectors" {
                    sub: any;
                    for sub in child.children {
                        if sub.type == "identifier" {
                            selectors.append(sub.text.decode("utf-8", errors="replace"));
                        }
                    }
                } elif child.type == "namespace_wildcard" {
                    is_wildcard = True;
                }
            }
            base = ".".join(parts);
            if selectors {
                for name in selectors {
                    imports.append(f"{base}.{name}");
                }
            } elif is_wildcard {
                imports.append(f"{base}.*");
            } elif base {
                imports.append(base);
            }
        } elif language == "r" {
            func_name: any = self._r_call_func_name(`node);
            if func_name in ("library", "require", "source") {
                value: any;
                for (_name, value) in self._r_iter_args(`node) {
                    if value.type == "identifier" {
                        imports.append(value.text.decode("utf-8", errors="replace"));
                    } elif value.type == "string" {
                        val = self._r_first_string_arg(`node);
                        if val {
                            imports.append(val);
                        }
                    }
                    break;
                }
            }
        } elif language == "ruby" {
            imports.extend(spec.module for spec in self._extract_ruby_import_specs(`node));
        } elif language == "dart" {
            def _find_string_literal(n) -> Optional[str] {
                if n.type == "string_literal" {
                    return n.text.decode("utf-8", errors="replace").strip("'\"");
                }
                for c in n.children {
                    result: any = _find_string_literal(c);
                    if result is not None {
                        return result;
                    }
                }
                return None;
            }
            val = _find_string_literal(`node);
            if val {
                imports.append(val);
            }
        } elif language == "verilog" {
            for child in `node.children {
                if child.type == "package_import_item" {
                    for subchild in child.children {
                        if subchild.type == "package_identifier" {
                            imports.append(subchild.text.decode("utf-8", errors="replace"));
                        }
                    }
                }
            }
        } elif language == "julia" {
            def _import_path_text(n) -> str {
                parts: list[str] = [];
                for sub in n.children {
                    if sub.type == "identifier" {
                        parts.append(sub.text.decode("utf-8", errors="replace"));
                    }
                }
                return ".".join(parts);
            }

            def _alias_real_name(alias_node) -> Optional[str] {
                for sub in alias_node.children {
                    if sub.type == "as" {
                        break;
                    }
                    if sub.type == "identifier" {
                        return sub.text.decode("utf-8", errors="replace");
                    }
                    if sub.type == "import_path" {
                        path: any = _import_path_text(sub);
                        return path or None;
                    }
                }
                return None;
            }

            for child in `node.children {
                if child.type == "identifier" {
                    imports.append(child.text.decode("utf-8", errors="replace"));
                } elif child.type == "import_path" {
                    path: any = _import_path_text(child);
                    if path {
                        imports.append(path);
                    }
                } elif child.type == "import_alias" {
                    real_name: any = _alias_real_name(child);
                    if real_name {
                        imports.append(real_name);
                    }
                } elif child.type == "selected_import" {
                    module_name: Optional[str] = None;
                    seen_colon: any = False;
                    for sub in child.children {
                        if sub.type == ":" {
                            seen_colon = True;
                            continue;
                        }
                        if not seen_colon {
                            if sub.type == "identifier" {
                                module_name = sub.text.decode("utf-8", errors="replace");
                            } elif sub.type == "import_path" {
                                path = _import_path_text(sub);
                                if path {
                                    module_name = path;
                                }
                            }
                        } elif sub.type == "identifier" and module_name {
                            imported = sub.text.decode("utf-8", errors="replace");
                            imports.append(f"{module_name}.{imported}");
                        } elif sub.type == "import_alias" and module_name {
                            real_name = _alias_real_name(sub);
                            if real_name {
                                imports.append(f"{module_name}.{real_name}");
                            }
                        }
                    }
                }
            }
        } elif language == "gdscript" {
            for child in `node.children {
                if child.type == "type" {
                    txt: any = child.text.decode("utf-8", errors="replace").strip();
                    if txt {
                        imports.append(txt);
                    }
                } elif child.type == "string" {
                    val = child.text.decode("utf-8", errors="replace").strip("'\"");
                    if val {
                        imports.append(val);
                    }
                } elif child.type == "identifier" {
                    txt = child.text.decode("utf-8", errors="replace");
                    if txt and txt != "extends" {
                        imports.append(txt);
                    }
                }
            }
        } elif language == "php" {
            include_types: any = {
                "include_expression",
                "include_once_expression",
                "require_expression",
                "require_once_expression",
            };
            if `node.type in include_types {
                for child in `node.children {
                    if child.type == "string"
                        or child.type == "encapsed_string"
                            and all(
                                operator.eq(part.type, "string_content")
                                for part in child.named_children,
                            )
                    {
                        value = child.text.decode("utf-8", errors="replace").strip("'\"");
                        if value {
                            imports.append(value);
                        }
                    }
                }
                return imports;
            }
            def _php_clause_fqn(clause) -> Optional[str] {
                for sub in clause.children {
                    if sub.type in ("qualified_name", "name") {
                        return sub.text.decode("utf-8", errors="replace").lstrip("\\");
                    }
                }
                return None;
            }

            group_node: any = None;
            prefix: any = "";
            for child in `node.children {
                if child.type == "namespace_name" {
                    prefix = child.text.decode("utf-8", errors="replace").strip("\\");
                } elif child.type == "namespace_use_group" {
                    group_node = child;
                }
            }

            if group_node is not None {
                clause: any;
                for clause in group_node.children {
                    if clause.type == "namespace_use_clause" {
                        rel: any = _php_clause_fqn(clause);
                        if rel {
                            imports.append(f"{prefix}\\{rel}" if prefix else rel);
                        }
                    }
                }
            } else {
                for clause in `node.children {
                    if clause.type == "namespace_use_clause" {
                        fqn: any = _php_clause_fqn(clause);
                        if fqn {
                            imports.append(fqn);
                        }
                    }
                }
            }
        } elif language in self._custom_languages {
            for field_name in ("module", "name", "path", "source") {
                target: any = `node.child_by_field_name(field_name);
                if target is None {
                    continue;
                }
                val = target.text.decode("utf-8", errors="replace").strip().strip("'\"");
                if val {
                    imports.append(val);
                    break;
                }
            } else {
                imports.append(text);
            }
        } else {
            imports.append(text);
        }

        return imports;
    }

    def _get_call_name(`node, language: str, source: bytes) -> Optional[str] {
        if not `node.children {
            return None;
        }

        first: any = `node.children[0];

        if language == "rust" and `node.type == "call_expression" {
            callee: any = `node.child_by_field_name("function");
            segments: any = self._rust_path_segments(callee);
            if segments {
                return "::".join(segments);
            }
            while callee is not None and callee.type == "generic_function" {
                callee = callee.child_by_field_name("function");
            }
            if callee is not None and callee.type == "field_expression" {
                field: any = callee.child_by_field_name("field");
                if field is not None {
                    return field.text.decode("utf-8", errors="replace");
                }
            }
        }

        if language == "java" {
            if `node.type == "method_invocation" {
                method: any;
                _: any;
                (method, _) = self._get_java_method_and_receiver(`node) as any;
                return method;
            }
            if `node.type == "method_reference" {
                (_, method) = self._get_member_call_receiver_method(`node, language) as any;
                return method;
            }
            if `node.type == "object_creation_expression" {
                return self._java_type_name(`node);
            }
        }
        if language == "julia" and `node.type == "macrocall_expression" {
            child: any;
            for child in `node.children {
                if child.type == "macro_identifier" {
                    sub: any;
                    for sub in child.children {
                        if sub.type == "identifier" {
                            raw: any = sub.text.decode("utf-8", errors="replace");
                            return f"@{raw}";
                        }
                    }
                    return None;
                }
            }
            return None;
        }
        if language == "php" {
            def _normalize_php_name(text: str) -> str {
                return text.lstrip("\\");
            }

            if `node.type == "function_call_expression" {
                for child in `node.children {
                    if child.type in ("name", "qualified_name") {
                        raw = child.text.decode("utf-8", errors="replace");
                        return _normalize_php_name(raw);
                    }
                }
                return None;
            }

            if `node.type in ("member_call_expression", "nullsafe_member_call_expression") {
                for child in reversed(`node.children) {
                    if child.type == "name" {
                        return child.text.decode("utf-8", errors="replace");
                    }
                }
                return None;
            }

            if `node.type == "scoped_call_expression" {
                scope: any;
                (scope, method) = self._php_scoped_call_parts(`node) as any;
                if not scope or not method {
                    return None;
                }
                return f"{_normalize_php_name(scope)}::{method}";
            }

            if `node.type == "object_creation_expression" {
                for child in `node.children {
                    if child.type in ("name", "qualified_name") {
                        raw = child.text.decode("utf-8", errors="replace");
                        return _normalize_php_name(raw);
                    }
                }
                return None;
            }
        }
        if `node.type == "instance_expression" {
            for child in `node.children {
                if child.type in ("type_identifier", "identifier") {
                    return child.text.decode("utf-8", errors="replace");
                }
            }
            return None;
        }
        if language == "objc" and `node.type == "message_expression" {
            receiver_skipped: any = False;
            for child in `node.children {
                if child.type in ("[", "]") {
                    continue;
                }
                if not receiver_skipped {
                    receiver_skipped = True;
                    continue;
                }
                if child.type == "identifier" {
                    return child.text.decode("utf-8", errors="replace");
                }
            }
            return None;
        }
        if language == "ruby" and `node.type in ("call", "method_call") {
            method_node: any = `node.child_by_field_name("method");
            if method_node is not None {
                return method_node.text.decode("utf-8", errors="replace");
            }
        }
        if language in ("bash", "powershell") and `node.type == "command" {
            for child in `node.children {
                if child.type == "command_name" {
                    txt: any = child.text.decode("utf-8", errors="replace").strip();
                    if language == "powershell" and _POWERSHELL_RANGE_RE.fullmatch(txt) {
                        return None;
                    }
                    return txt or None;
                }
            }
            return None;
        }
        if language == "verilog"
            and `node.type in ("module_instantiation", "interface_instantiation")
        {
            if first.type == "simple_identifier" {
                return first.text.decode("utf-8", errors="replace");
            }
            return None;
        }
        if language == "solidity" and first.type == "expression" and first.children {
            first = first.children[0];
        }
        if language == "perl" and `node.type == "method_call_expression" {
            for child in `node.children {
                if child.type == "method" {
                    return child.text.decode("utf-8", errors="replace");
                }
            }
            return None;
        }
        if first.type in ("identifier", "simple_identifier") {
            return first.text.decode("utf-8", errors="replace");
        }
        if first.type == "function" {
            return first.text.decode("utf-8", errors="replace");
        }
        if language in ("lua", "luau")
            and first.type in ("dot_index_expression", "method_index_expression")
        {
            for child in reversed(first.children) {
                if child.type == "identifier" {
                    return child.text.decode("utf-8", errors="replace");
                }
            }
            return None;
        }
        member_types: any = (
            "attribute",
            "member_expression",
            "field_expression",
            "selector_expression",
            "navigation_expression",
            "member_access_expression",
            "conditional_access_expression",
        );
        if first.type in member_types {
            for child in reversed(first.children) {
                if child.type
                    in (
                        "identifier",
                        "property_identifier",
                        "field_identifier",
                        "field_name",
                        "simple_identifier",
                    )
                {
                    return child.text.decode("utf-8", errors="replace");
                }
                if child.type == "navigation_suffix" {
                    for sub in child.children {
                        if sub.type == "simple_identifier" {
                            return sub.text.decode("utf-8", errors="replace");
                        }
                    }
                }
                if child.type == "member_binding_expression" {
                    for sub in child.children {
                        if sub.type == "identifier" {
                            return sub.text.decode("utf-8", errors="replace");
                        }
                    }
                }
            }
            return first.text.decode("utf-8", errors="replace");
        }
        if first.type in ("scoped_identifier", "qualified_identifier", "qualified_name") {
            return first.text.decode("utf-8", errors="replace");
        }
        if first.type == "namespace_operator" {
            return first.text.decode("utf-8", errors="replace");
        }
        if language in self._custom_languages {
            return self._get_custom_call_name(`node);
        }

        return None;
    }

    static has _CUSTOM_CALLEE_FIELDS: any = ("function", "callee", "expr", "name");

    static has _MAX_CUSTOM_CALLEE_DESCENT: any = 32;

    def _get_custom_call_name(`node) -> Optional[str] {
        for field_name in self._CUSTOM_CALLEE_FIELDS {
            callee: any = `node.child_by_field_name(field_name);
            if callee is None {
                continue;
            }
            for _ in range(self._MAX_CUSTOM_CALLEE_DESCENT) {
                inner: any = callee.child_by_field_name(field_name);
                if inner is None {
                    break;
                }
                callee = inner;
            }
            text: any = callee.text.decode("utf-8", errors="replace").strip();
            if text and len(text) <= 256 and "\n" not in text {
                return text;
            }
            return None;
        }
        return None;
    }

    def _get_jsx_component_reference(`node) -> Optional[tuple[Optional[str], str]] {
        for child in `node.children {
            if child.type == "identifier" {
                name: any = child.text.decode("utf-8", errors="replace");
                if self._looks_like_component_name(name) {
                    return (None, name);
                }
                return None;
            }
            if child.type == "member_expression" {
                base_name: any = self._get_member_expression_root_name(child);
                component_name: any = None;
                sub: any;
                for sub in reversed(child.children) {
                    if sub.type in ("identifier", "property_identifier") {
                        component_name = sub.text.decode("utf-8", errors="replace");
                        break;
                    }
                }
                if component_name and self._looks_like_component_name(component_name) {
                    return (base_name, component_name);
                }
                for sub in reversed(child.children) {
                    if sub.type in ("identifier", "property_identifier") {
                        name = sub.text.decode("utf-8", errors="replace");
                        if self._looks_like_component_name(name) {
                            return (None, name);
                        }
                        return None;
                    }
                }
                text: any = child.text.decode("utf-8", errors="replace");
                tail: any = text.split(".")[-1];
                if self._looks_like_component_name(tail) {
                    return (None, tail);
                }
                return None;
            }
        }
        return None;
    }

    def _get_member_expression_root_name(`node) -> Optional[str] {
        for child in `node.children {
            if child.type == "identifier" {
                return child.text.decode("utf-8", errors="replace");
            }
            if child.type == "member_expression" {
                return self._get_member_expression_root_name(child);
            }
        }
        return None;
    }

    static def _looks_like_component_name(name: str) -> bool {
        return `bool(name) and name[0].isupper();
    }

    static has _TEST_MODIFIER_SUFFIXES: any = frozenset({
        "only",
        "skip",
        "each",
        "todo",
        "concurrent",
        "failing",
    });

    def _get_base_call_name(`node, source: bytes) -> Optional[str] {
        if not `node.children {
            return None;
        }
        first: any = `node.children[0];
        if first.type != "member_expression" {
            return None;
        }
        rightmost: Optional[str] = None;
        child: any;
        for child in reversed(first.children) {
            if child.type in ("identifier", "property_identifier") {
                rightmost = child.text.decode("utf-8", errors="replace");
                break;
            }
        }
        if rightmost not in self._TEST_MODIFIER_SUFFIXES {
            return None;
        }
        for child in first.children {
            if child.type == "identifier" {
                return child.text.decode("utf-8", errors="replace");
            }
            if child.type == "member_expression" {
                for inner in child.children {
                    if inner.type == "identifier" {
                        return inner.text.decode("utf-8", errors="replace");
                    }
                }
            }
        }
        return None;
    }

    static def _r_call_func_name(call_node) -> Optional[str] {
        for child in call_node.children {
            if child.type in ("identifier", "namespace_operator") {
                return child.text.decode("utf-8", errors="replace");
            }
        }
        return None;
    }

    static def _r_first_string_arg(call_node) -> Optional[str] {
        for child in call_node.children {
            if child.type == "arguments" {
                for arg in child.children {
                    if arg.type == "argument" {
                        for sub in arg.children {
                            if sub.type == "string" {
                                for sc in sub.children {
                                    if sc.type == "string_content" {
                                        return sc.text.decode("utf-8", errors="replace");
                                    }
                                }
                            }
                        }
                    }
                }
                break;
            }
        }
        return None;
    }

    static def _r_iter_args(call_node) -> Generator[any, any, any] {
        sub: any;
        for child in call_node.children {
            if child.type != "arguments" {
                continue;
            }
            for arg in child.children {
                if arg.type != "argument" {
                    continue;
                }
                has_eq: any = `any(operator.eq(sub.type, "=") for sub in arg.children);
                if has_eq {
                    name: any = None;
                    value: any = None;
                    for sub in arg.children {
                        if sub.type == "identifier" and name is None {
                            name = sub.text.decode("utf-8", errors="replace");
                        } elif sub.type not in ("=", ",") {
                            value = sub;
                        }
                    }
                    yield (name, value);
                } else {
                    for sub in arg.children {
                        if sub.type not in (",",) {
                            yield (None, sub);
                            break;
                        }
                    }
                }
            }
            break;
        }
    }

    class def _r_find_named_arg(call_node, arg_name: str) -> any {
        for (name, value) in cls._r_iter_args(call_node) {
            if name == arg_name {
                return value;
            }
        }
        return None;
    }

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
    ) -> bool {
        children: any = `node.children;
        if len(children) < 3 {
            return False;
        }

        left: any;
        op: any;
        right: any;
        (left, op, right) = (children[0], children[1], children[2]);
        if op.type not in ("<-", "=") {
            return False;
        }

        if right.type == "function_definition" and left.type == "identifier" {
            name: any = left.text.decode("utf-8", errors="replace");
            is_test: any = _is_test_function(name, file_path, repo_root=self._repo_root);
            kind: any = "Test" if is_test else "Function";
            qualified: any = self._qualify(name, file_path, enclosing_class);
            params: any = self._get_params(right, language, source);

            nodes.append(
                NodeInfo(
                    kind,
                    name,
                    file_path,
                    right.start_point[0] + 1,
                    right.end_point[0] + 1,
                    language=language,
                    parent_name=enclosing_class,
                    params=params,
                    is_test=is_test,
                ),
            );

            container: any = self._qualify(enclosing_class, file_path, None)
                if enclosing_class
                else file_path;
            edges.append(
                EdgeInfo("CONTAINS", container, qualified, file_path, right.start_point[0] + 1)
            );

            self._extract_from_tree(
                right,
                source,
                language,
                file_path,
                nodes,
                edges,
                enclosing_class=enclosing_class,
                enclosing_func=name,
                import_map=import_map,
                defined_names=defined_names,
            );
            return True;
        }

        if right.type == "call" and left.type == "identifier" {
            call_func: any = self._r_call_func_name(right);
            if call_func in ("setRefClass", "setClass", "setGeneric") {
                assign_name: any = left.text.decode("utf-8", errors="replace");
                return self._handle_r_class_call(
                    right,
                    source,
                    language,
                    file_path,
                    nodes,
                    edges,
                    enclosing_class,
                    enclosing_func,
                    import_map,
                    defined_names,
                    assign_name=assign_name,
                );
            }
        }

        return False;
    }

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
    ) -> bool {
        func_name: any = self._r_call_func_name(`node);
        if not func_name {
            return False;
        }

        if func_name in ("library", "require", "source") {
            imports: any = self._extract_import(`node, language, source);
            for imp_target in imports {
                edges.append(
                    EdgeInfo(
                        "IMPORTS_FROM", file_path, imp_target, file_path, `node.start_point[0] + 1
                    ),
                );
            }
            return True;
        }

        if func_name in ("setRefClass", "setClass", "setGeneric") {
            return self._handle_r_class_call(
                `node,
                source,
                language,
                file_path,
                nodes,
                edges,
                enclosing_class,
                enclosing_func,
                import_map,
                defined_names,
            );
        }
        call_name: any = self._get_call_name(`node, language, source);
        if call_name {
            caller: any = self._qualify(enclosing_func, file_path, enclosing_class)
                if enclosing_func
                else file_path;
            target: any = self._resolve_call_target(
                call_name, file_path, language, import_map or {}, defined_names or set[any]()
            );
            edges.append(EdgeInfo("CALLS", caller, target, file_path, `node.start_point[0] + 1));
        }

        self._extract_from_tree(
            `node,
            source,
            language,
            file_path,
            nodes,
            edges,
            enclosing_class=enclosing_class,
            enclosing_func=enclosing_func,
            import_map=import_map,
            defined_names=defined_names,
        );
        return True;
    }

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
    ) -> bool {
        class_name: any = self._r_first_string_arg(`node) or assign_name;
        if not class_name {
            return False;
        }

        qualified: any = self._qualify(class_name, file_path, enclosing_class);
        nodes.append(
            NodeInfo(
                "Class",
                class_name,
                file_path,
                `node.start_point[0] + 1,
                `node.end_point[0] + 1,
                language=language,
                parent_name=enclosing_class,
            ),
        );
        edges.append(
            EdgeInfo("CONTAINS", file_path, qualified, file_path, `node.start_point[0] + 1)
        );

        methods_list: any = self._r_find_named_arg(`node, "methods");
        if methods_list is not None {
            self._extract_r_methods(
                methods_list,
                source,
                language,
                file_path,
                nodes,
                edges,
                class_name,
                import_map,
                defined_names,
            );
        }

        return True;
    }

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
    ) {
        for (method_name, func_def) in self._r_iter_args(list_call) {
            if not method_name or func_def is None {
                continue;
            }
            if func_def.type != "function_definition" {
                continue;
            }

            qualified: any = self._qualify(method_name, file_path, class_name);
            params: any = self._get_params(func_def, language, source);
            nodes.append(
                NodeInfo(
                    "Function",
                    method_name,
                    file_path,
                    func_def.start_point[0] + 1,
                    func_def.end_point[0] + 1,
                    language=language,
                    parent_name=class_name,
                    params=params,
                ),
            );
            edges.append(
                EdgeInfo(
                    "CONTAINS",
                    self._qualify(class_name, file_path, None),
                    qualified,
                    file_path,
                    func_def.start_point[0] + 1,
                ),
            );
            self._extract_from_tree(
                func_def,
                source,
                language,
                file_path,
                nodes,
                edges,
                enclosing_class=class_name,
                enclosing_func=method_name,
                import_map=import_map,
                defined_names=defined_names,
            );
        }
    }
}
