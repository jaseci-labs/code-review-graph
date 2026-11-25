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

def _python_qualified_class_identity(file_path: str, class_name: str) -> str;

def _python_split_class_identity(identity: str) -> Optional[tuple[str, str]];

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
def _read_cargo_manifest(manifest_path: str, _mtime_ns: int, _size: int) -> dict[str, Any];

def _load_cargo_manifest(path: Path) -> dict[str, Any];

class _PythonScopeBindingVisitor(ast.NodeVisitor) {
    def init;

    def visit_Name(`node: ast.Name);

    def visit_FunctionDef(`node: ast.FunctionDef);

    def visit_AsyncFunctionDef(`node: ast.AsyncFunctionDef);

    def visit_ClassDef(`node: ast.ClassDef);

    def visit_Lambda(`node: ast.Lambda);

    def visit_Import(`node: ast.Import);

    def visit_ImportFrom(`node: ast.ImportFrom);

    def visit_Global(`node: ast.Global);
}

def _python_function_scope_bindings(
    source: bytes
) -> dict[tuple[int, int], tuple[frozenset[str], frozenset[str]]];
def _python_type_checking_aliases(tree: ast.Module) -> tuple[frozenset[str], frozenset[str]];

glob type_checking_names_default_: any = frozenset();

glob typing_modules_default_: any = frozenset();

def _python_static_truth(
    `node: ast.expr,
    type_checking_names: frozenset[str] = type_checking_names_default_,
    typing_modules: frozenset[str] = typing_modules_default_,
) -> Optional[bool];

glob _TRY_STMT_TYPES: tuple[Any, ...] = (ast.Try, ast.TryStar)
    if hasattr(ast, "TryStar")
    else (ast.Try,);

glob _MATCH_STMT_TYPES: tuple[Any, ...] = (ast.Match,) if hasattr(ast, "Match") else ();

class _PythonUnreachableCallVisitor(ast.NodeVisitor) {
    def init(type_checking_names: frozenset[str], typing_modules: frozenset[str]);

    def visit_Module(`node: ast.Module);

    def visit_Call(`node: ast.Call);

    def visit_Attribute(`node: ast.Attribute);

    def visit_If(`node: ast.If);

    def visit_FunctionDef(`node: ast.FunctionDef);

    def visit_AsyncFunctionDef(`node: ast.AsyncFunctionDef);

    def visit_ClassDef(`node: ast.ClassDef);

    def _visit_function(`node: ast.FunctionDef | ast.AsyncFunctionDef);

    def _visit_statements(statements: list[ast.stmt], *, dead: bool);
}

@lru_cache(maxsize=128)
def _python_unreachable_call_positions(source: bytes) -> frozenset[tuple[int, int]];

class _PythonUnreachableImportVisitor(_PythonUnreachableCallVisitor) {
    def visit_Call(`node: ast.Call);

    def visit_Attribute(`node: ast.Attribute);

    def visit_Import(`node: ast.Import);

    def visit_ImportFrom(`node: ast.ImportFrom);
}

@lru_cache(maxsize=128)
def _python_unreachable_import_positions(source: bytes) -> frozenset[tuple[int, int]];
def _node_is_in_child(`node, child_node) -> bool;
def _is_statically_false_condition(cond) -> bool;
def _is_static_dead_guard_child(parent, child) -> bool;
def _is_in_static_dead_guard(`node) -> bool;
def _is_in_rust_dead_guard(`node) -> bool;

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

def _parser_load_timeout_seconds -> float;
def _parser_probe_env -> dict[str, str];
def _install_hint_for_probe_failure(detail: str) -> str | None;
def _run_parser_load_probe(grammar: str, timeout_seconds: float) -> bool;
def _parser_load_probe_succeeds(grammar: str, timeout_seconds: float | None = None) -> bool;
def _mark_parser_unavailable(grammar: str);
def _clear_parser_probe_cache;
def _load_tree_sitter_parser(grammar: str) -> any;

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
) -> tuple[str, tuple[tuple[str, str], ...]];
@lru_cache(maxsize=64)
def _read_gemspec_require_paths(gemspec_path: str, _mtime_ns: int, _size: int) -> tuple[str, ...];
def _path_is_within(path: Path, `root: Path) -> bool;
@lru_cache(maxsize=128)
def _read_php_composer_psr4(
    composer_path: str, repo_root: str, _mtime_ns: int, _size: int
) -> _PhpPsr4Mappings;

def _with_post_init(cls: any) -> any;

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

    def postinit;
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

    def postinit;
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

def _builtin_language_names -> frozenset[str];

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

def _vbnet_normalize_name(value: str) -> str;
def _strip_vbnet_noise(text: str) -> str;
def _vbnet_logical_lines(cleaned: str) -> list[tuple[int, int, str]];
def _vbnet_parenthesized(text: str, start: int) -> tuple[str, int] | None;
def _vbnet_split_top_level(value: str) -> list[str];

def _vbnet_type_parameters(rest: str) -> tuple[list[str], str];
def _vbnet_signature_parts(rest: str) -> tuple[Optional[str], Optional[str], list[str]];

def _vbnet_relationship_targets(value: str) -> list[str];

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

def _strip_rescript_noise(text: str) -> str;
def _rescript_brace_depth_array(cleaned: str) -> list[int];
def _scan_rescript_modules(cleaned: str, offset_to_line) -> list[dict];
@lru_cache(maxsize=64)
def _repo_root_prefixes(repo_root: str) -> tuple[str, ...];
@lru_cache(maxsize=2048)
def _resolved_dir(directory: str) -> str;

def _strip_prefix(normalized: str, `root: str) -> Optional[str];
def _repo_relative_path(normalized: str, repo_root: "str | PurePath | None") -> Optional[str];
@lru_cache(maxsize=256)
def _is_python_package_dir(directory: str) -> bool;
def _is_shipped_test_package(
    normalized: str, relative: str, repo_root: "str | PurePath | None"
) -> bool;
def repo_relative_path(
    path: "str | PurePath", repo_root: "str | PurePath | None" = None
) -> Optional[str];
def is_test_file(
    path: "str | PurePath",
    repo_root: "str | PurePath | None" = None,
    *,
    include_helper_dirs: bool = False,
) -> bool;

glob _is_test_file: any = is_test_file;

def _is_test_function(
    name: str,
    file_path: str,
    decorators: tuple[str, ...] = (),
    repo_root: "str | PurePath | None" = None,
) -> bool;

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

def _clean_docstring_summary(raw: str, language: str) -> str;
def _strip_block_doc_comment(text: str) -> str;
def _modifier_annotation_names(`node) -> list[str];
def _python_decorator_names(`node) -> list[str];
def _csharp_attribute_names(`node) -> list[str];

glob _PHPUNIT_TEST_ATTRIBUTE: any = "phpunit\\framework\\attributes\\test";

def _php_attribute_aliases(`node) -> dict[str, str];
def _php_attribute_names(`node) -> list[str];

glob _PHP_TEST_DOC_TAG_RE: any = re.compile("(?<![\\w-])@test(?![\\w-])");

def _php_docblock_marks_test(`node) -> bool;

glob _SEPARATE_SCOPE_RULE_LANGUAGES: any = frozenset({"python", "cpp", "julia", "csharp"});

def _nested_import_chain(module: str, resolved: str, symbol: str) -> str;

class _OuterBinding(builtins.str) {
    has levels: int;

    static def __new__(cls, value: str, levels: int) -> "_OuterBinding";
}

def _csharp_name(`node) -> str;
def _csharp_namespace_context(`node) -> list[tuple[str, int]];
def _php_namespaces(root_node) -> list[str];
def _csharp_namespaces(root_node) -> list[str];
def file_hash(path: Path) -> str;
def _hcl_text(`node) -> str;
def _hcl_child(`node, *types_: str) -> any;
def _hcl_block_name(prefix: str, labels: list[str], n_labels: int) -> Optional[str];

glob _HCL_REF_PREFIXES: frozenset[str] = frozenset(
    ("var module local data each count self path terraform").split()
);

def _hcl_ref_target(`root: str, attrs: list[str], *, provider: bool = False) -> Optional[str];
def _hcl_variable_refs(expr_node) -> Generator[any, any, any];

glob _HCL_RECURSE_TYPES: frozenset[str] = frozenset(
    ("expression body block attribute tuple object object_elem collection_value template_expr "
        "for_expr for_tuple_expr for_object_expr for_intro for_cond conditional function_call "
        "function_arguments quoted_template template_interpolation").split(),
);

def _hcl_for_iterator_names(for_expr_node) -> frozenset[str];
def _hcl_dynamic_iterator_name(block_node) -> Optional[str];

glob _HCL_BLOCK_CFG: dict[str, tuple[str, str, int, bool]] = {
    "resource": ("Class", "resource", 2, True),
    "data": ("Class", "data", 2, True),
    "module": ("Class", "module", 1, True),
    "variable": ("Function", "var", 1, False),
    "output": ("Function", "output", 1, True),
    "provider": ("Function", "provider", 1, True),
};

def _is_ansible_path(path: Path) -> bool;
def _is_ansible_content(source: bytes) -> bool;
def _ansible_file_type(path: Path) -> str;
def _ansible_fqcn_short(key: str) -> str;

def _yaml_line(`node: object) -> int;
def _yaml_end_line(`node: object) -> int;

def _yaml_get_key(mapping_node: object, key: str) -> Optional[object];

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

def _is_storable_key(key: str) -> bool;
def _json_key(key_node: Any) -> Optional[str];

def _yaml_scalar(`node: object) -> Optional[str];

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

def _html_start_tag(element: Any) -> Any;

def _html_tag_name(start_tag: Any) -> str;
def _html_attributes(start_tag: Any) -> dict[str, str];
def _html_script_language(attributes: dict[str, str]) -> Optional[str];
def _html_is_local_src(src: str) -> bool;
def _html_first_heading(element: Any, max_chars: int) -> Optional[str];

glob _XSLT_NAMESPACE: any = "http://www.w3.org/1999/XSL/Transform";

glob _XSLT_NAMED_STEP_RE: any = re.compile("@?[^\\W\\d][\\w.-]*(?::[^\\W\\d][\\w.-]*)?");

def _xml_name(element: Any) -> str;
def _xml_attributes(element: Any) -> dict[str, str];
def _xml_scope(element: Any, parent: dict[str, str]) -> dict[str, str];
def _xslt_local_name(element: Any, scope: dict[str, str]) -> str;
def _xml_child_elements(element: Any) -> list[Any];
def _xslt_split(expression: str, separator: str) -> list[str];
def _xslt_named_steps(expression: str) -> set[str];

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

def _yaml_path_child(prefix: str, segment: str) -> str;
def _yaml_value_type(`node: object) -> str;
def _is_language_tag(text: str) -> bool;
def _is_locale_yaml(path: "str | PurePath", repo_root: "str | PurePath | None") -> bool;
def _ansible_is_play_item(item: object) -> bool;

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

    def init(repo_root: Optional[Path] = None);

    def _get_parser(language: str) -> any;
    def clear_caches(include_parsers: bool = False, release_memory: bool = True);
    def detect_language(path: Path, source: Optional[bytes] = None) -> Optional[str];
    static def _detect_language_from_shebang(
        path: Path, head: Optional[bytes] = None
    ) -> Optional[str];
    def _is_test_path(path: "str | PurePath") -> bool;
    def parse_file(path: Path) -> tuple[list[NodeInfo], list[EdgeInfo]];
    def parse_bytes(path: Path, source: bytes) -> tuple[list[NodeInfo], list[EdgeInfo]];
    def _extract_bytes(path: Path, source: bytes) -> tuple[list[NodeInfo], list[EdgeInfo]];
    static def _has_cpp_header_evidence(`root) -> bool;
    static def _has_cpp_header_text_evidence(source: bytes) -> bool;
    static def _mask_cpp_qt_macros(source: bytes) -> bytes;
    class def _mask_blade_comments(text: str) -> str;
    def _parse_blade(path: Path, source: bytes) -> tuple[list[NodeInfo], list[EdgeInfo]];
    static def _blank_liquid_span(`match: re.Match[str]) -> str;
    def _liquid_statements(masked: str) -> Generator[any, any, any];
    def _resolve_liquid_snippet(path: Path, name: str) -> Optional[str];
    def _liquid_output_name(expression: str) -> str;
    def _parse_liquid(path: Path, source: bytes) -> tuple[list[NodeInfo], list[EdgeInfo]];
    def _parse_vue(path: Path, source: bytes) -> tuple[list[NodeInfo], list[EdgeInfo]];
    def _parse_svelte(path: Path, source: bytes) -> tuple[list[NodeInfo], list[EdgeInfo]];
    def _parse_html(path: Path, source: bytes) -> tuple[list[NodeInfo], list[EdgeInfo]];
    def _add_html_section(
        element: Any,
        tag: str,
        attributes: dict[str, str],
        file_path: str,
        test_file: bool,
        sections: dict[str, NodeInfo],
        file_node: NodeInfo,
    );
    def _extract_html_scripts(
        scripts: list[Any], file_path: str, all_nodes: list[NodeInfo], all_edges: list[EdgeInfo]
    ) -> list[NodeInfo];
    def _html_handler_calls(handler: str) -> list[str];
    def _add_html_script_import(src: str, file_path: str, line: int, edges: list[EdgeInfo]);
    def _parse_xslt(path: Path, source: bytes) -> tuple[list[NodeInfo], list[EdgeInfo]];
    def _add_xslt_import(element: Any, how: str, file_path: str, edges: list[EdgeInfo]);
    def _xslt_template(
        element: Any, local_name: str, scope: dict[str, str], file_path: str, seen: set[str]
    ) -> Optional[_XsltTemplate];
    def _walk_xslt_body(
        element: Any,
        scope: dict[str, str],
        owner: Optional[_XsltTemplate],
        templates: list[_XsltTemplate],
        named: dict[str, str],
        file_path: str,
        edges: list[EdgeInfo],
    );
    def _add_xslt_apply(
        element: Any,
        owner: Optional[_XsltTemplate],
        source: str,
        templates: list[_XsltTemplate],
        file_path: str,
        line: int,
        edges: list[EdgeInfo],
    );
    def _parse_notebook(path: Path, source: bytes) -> tuple[list[NodeInfo], list[EdgeInfo]];
    def _parse_notebook_cells(
        path: Path, cells: list[CellInfo], default_language: str
    ) -> tuple[list[NodeInfo], list[EdgeInfo]];
    def _parse_databricks_py_notebook(
        path: Path, source: bytes
    ) -> tuple[list[NodeInfo], list[EdgeInfo]];
    def _parse_vbnet(path: Path, source: bytes) -> tuple[list[NodeInfo], list[EdgeInfo]];
    def _parse_robot(path: Path, source: bytes) -> tuple[list[NodeInfo], list[EdgeInfo]];
    def _resolve_vbnet_edges(
        nodes: list[NodeInfo], edges: list[EdgeInfo], file_path: str
    ) -> list[EdgeInfo];
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
    class def _is_plsql_dialect(path: Path, text: str) -> bool;

    static has _PLSQL_Q_DELIM_CLOSE: any = {"[": "]", "{": "}", "(": ")", "<": ">"};
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
    static def _plsql_is_forward_decl(text: str, start: int) -> bool;
    static def _plsql_member_signature(text: str, start: int) -> str;
    def _parse_sql(path: Path, source: bytes) -> tuple[list[NodeInfo], list[EdgeInfo]];
    def _is_dbt_model_path(path: Path) -> Optional[bool];
    def _dbt_model_paths(project_file: Path) -> tuple[Path, ...];
    def _extract_dbt_model(
        path: Path,
        text: str,
        dbt_refs: list[re.Match],
        file_path_str: str,
        test_file: bool,
        nodes: list[NodeInfo],
        edges: list[EdgeInfo],
    );
    static def _plsql_block_end(
        text: str,
        start: int,
        name: str,
        limit: int | None = None,
        named_ends: dict[str, list[int]] | None = None,
        package: bool = False,
    ) -> int;
    static def _plsql_bare_end(text: str, start: int, limit: int, package: bool) -> int;
    def _extract_plsql_calls(
        text: str,
        body_start: int,
        body_end: int,
        caller_qualified: str,
        file_path_str: str,
        edges: list[EdgeInfo],
    );
    def _walk_sql_tree(
        `node, source: bytes, file_path_str: str, nodes: list[NodeInfo], edges: list[EdgeInfo]
    );
    def _extract_sql_ddl(
        `node, source: bytes, file_path_str: str, nodes: list[NodeInfo], edges: list[EdgeInfo]
    );
    def _resolve_call_targets(
        nodes: list[NodeInfo], edges: list[EdgeInfo], file_path: str
    ) -> list[EdgeInfo];
    def _resolve_julia_call_targets(
        nodes: list[NodeInfo], edges: list[EdgeInfo], file_path: str
    ) -> list[EdgeInfo];

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
    ) -> dict[tuple[int, str, str], tuple[Optional[str], str, str]];
    def _collect_class_typed_fields(
        class_node, language: str, function_types: set[str], class_types: set[str]
    ) -> dict[str, str];
    def _collect_function_typed_parameters(function_node, language: str) -> dict[str, str];
    def _collect_ts_parameter_properties(constructor_node) -> dict[str, str];
    def _typed_bindings_from_node(`node, language: str) -> dict[str, str];
    static def _php_assigned_variables(`node) -> set[str];

    class def _store_typed_binding(
        result: dict[str, str], name_node, type_node, *, csharp: bool = False
    );
    class def _store_java_typed_binding(result: dict[str, str], name_node, type_node);
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
    def _collect_python_receiver_evidence(
        `root, file_path: str, source: bytes
    ) -> tuple[dict[tuple[int, str], tuple[str, str]], list[EdgeInfo]];
    def _collect_python_class_fields(
        class_node, context: _PyReceiverContext
    ) -> dict[str, tuple[str, str]];
    def _python_property_definition(
        owner_type: str, property_name: str, context: _PyReceiverContext
    ) -> Optional[tuple[str, str, str]];
    def _python_module_property_return_annotations(module_file: str) -> dict[tuple[str, str], str];
    def _python_module_class_identities(module_file: str) -> dict[str, tuple[str, str]];
    def _read_python_property_return_annotations(module_path: Path) -> dict[tuple[str, str], str];
    def _python_expression_class_evidence(
        expression,
        env: dict[str, tuple[str, str]],
        class_fields: dict[str, tuple[str, str]],
        current_class: Optional[str],
        context: _PyReceiverContext,
        instance_receiver_name: Optional[str] = None,
        class_receiver_name: Optional[str] = None,
    ) -> Optional[tuple[str, str]];
    static def _merge_python_evidence(found: list[tuple[str, str]]) -> tuple[str, str];
    class def _python_binding_targets(left) -> list[tuple[str, tuple[int, ...]]];
    static def _python_target_is_attribute(left, name: str) -> bool;
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
    def _python_call_evidence(
        call, path: tuple[int, ...], context: _PyReceiverContext
    ) -> tuple[str, str];
    def _python_constructor_class(callee, context: _PyReceiverContext) -> Optional[str];
    static def _python_unwrap_callee(`node) -> any;
    static def _python_dotted_root(`node) -> Optional[str];
    def _python_callee_return_annotation(callee, context: _PyReceiverContext) -> Optional[str];
    def _python_expression_receiver_evidence(
        call, context: _PyReceiverContext
    ) -> Optional[tuple[str, str]];
    def _python_dotted_module_file(prefix, context: _PyReceiverContext) -> Optional[str];
    class def _python_annotation_at_path(annotation: str, path: tuple[int, ...]) -> Optional[str];
    static def _python_tuple_annotation_elements(annotation: str) -> Optional[list[str]];
    def _python_module_return_annotations(module_file: str) -> dict[str, str];
    def _read_python_return_annotations(module_path: Path) -> dict[str, str];
    def _python_plain_import_bindings(
        `node, file_path: str, module_bindings: dict[str, set[str]], imported_names: set[str]
    );
    def _python_from_import_bindings(
        `node,
        file_path: str,
        module_bindings: dict[str, set[str]],
        imported_names: set[str],
        symbol_origins: Optional[dict[str, str]] = None,
        symbol_names: Optional[dict[str, str]] = None,
    );
    static def _python_binding_target_name(left) -> Optional[str];
    def _apply_python_receiver_evidence(
        edges: list[EdgeInfo], evidence: dict[tuple[int, str], tuple[str, str]]
    ) -> list[EdgeInfo];

    static has _MAX_AST_DEPTH: any = 180;

    static has _MAX_TEST_DESCRIPTION_LEN: any = 200;
    def _get_test_description(call_node, source: bytes) -> Optional[str];
    def _is_ruby_test_block(`node, call_name: str, file_path: str) -> bool;
    def _get_ruby_test_description(call_node) -> Optional[str];
    static def _ruby_constant_path(`node) -> Optional[str];
    class def _ruby_class_ref(`node, nesting: tuple[str, ...]) -> Optional[_RubyClassRef];
    class def _ruby_nesting(`node, nesting: tuple[str, ...]) -> tuple[str, ...];
    def _collect_ruby_test_receivers(
        `root
    ) -> dict[tuple[int, str], list[tuple[bool, Optional[_RubyClassRef]]]];
    static def _apply_ruby_test_receivers(
        edges: list[EdgeInfo],
        receivers: dict[tuple[int, str], list[tuple[bool, Optional[_RubyClassRef]]]],
    ) -> list[EdgeInfo];
    def _parse_yaml(path: Path, source: bytes) -> tuple[list[NodeInfo], list[EdgeInfo]];
    def _parse_json(path: Path, source: bytes) -> tuple[list[NodeInfo], list[EdgeInfo]];

    static def _spring_config_file_node(path: Path, source: bytes, language: str) -> NodeInfo;
    def _parse_spring_config(path: Path, source: bytes) -> tuple[list[NodeInfo], list[EdgeInfo]];
    def _parse_spring_yaml(path: Path, source: bytes) -> tuple[list[NodeInfo], list[EdgeInfo]];
    static def _is_non_spring_yaml(documents: list[object]) -> bool;
    static def _spring_property_logical_lines(text: str) -> list[tuple[int, str]];
    static def _spring_property_key(line: str) -> Optional[str];
    def _parse_spring_properties(
        path: Path, source: bytes
    ) -> tuple[list[NodeInfo], list[EdgeInfo]];
    def _parse_ansible(path: Path, source: bytes) -> tuple[list[NodeInfo], list[EdgeInfo]];
    static def _ansible_unique_name(
        nodes: list[NodeInfo], file_path: str, parent_name: Optional[str], requested: str, line: int
    ) -> str;
    def _resolve_ansible_notify_targets(
        nodes: list[NodeInfo], edges: list[EdgeInfo]
    ) -> list[EdgeInfo];
    def _parse_ansible_playbook(
        `root: object, file_path: str, nodes: list[NodeInfo], edges: list[EdgeInfo]
    );
    def _parse_ansible_tasks(
        tasks_node: object,
        file_path: str,
        nodes: list[NodeInfo],
        edges: list[EdgeInfo],
        is_handler: bool,
        parent_play: Optional[str],
    );
    def _parse_ansible_meta(
        `root: object, file_path: str, nodes: list[NodeInfo], edges: list[EdgeInfo]
    );
    def _ansible_extract_role_name(item: object) -> Optional[str];
    def _ansible_extract_notify_targets(notify_node: object) -> list[str];
    def _ansible_module_arg_str(args_node: Optional[object]) -> Optional[str];
    def _ansible_role_from_module_args(args_node: Optional[object]) -> Optional[str];
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
    );
    def _elixir_call_identifier(`node) -> Optional[str];
    def _elixir_module_name(arguments) -> Optional[str];
    def _elixir_function_name_and_params(
        arguments, source: bytes
    ) -> tuple[Optional[str], Optional[str]];
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
    def _merge_elixir_clauses(
        nodes: list[NodeInfo], edges: list[EdgeInfo]
    ) -> tuple[list[NodeInfo], list[EdgeInfo]];
    static def _is_nix_flake_file(file_path: str) -> bool;
    def _nix_attrpath_parts(attrpath_node) -> list[str];
    def _extract_nix_flake_input_urls(attrset_node) -> list[tuple[str, int]];
    def _extract_nix_import_targets(rhs_node) -> list[tuple[str, int]];
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
    def _extract_hcl_constructs(
        `node, file_path: str, nodes: list[NodeInfo], edges: list[EdgeInfo]
    ) -> bool;
    def _emit_hcl_locals(
        body_node, file_path: str, nodes: list[NodeInfo], edges: list[EdgeInfo]
    ) -> bool;
    def _hcl_get_attribute_string(body_node, attr_name: str) -> Optional[str];
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
    );
    def _extract_bash_source_command(`node, file_path: str, edges: list[EdgeInfo]) -> bool;
    def _extract_dart_calls_from_children(
        parent,
        source: bytes,
        file_path: str,
        edges: list[EdgeInfo],
        enclosing_class: Optional[str],
        enclosing_func: Optional[str],
    );
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
    static def _julia_component_name(`node) -> Optional[str];
    def _julia_field_parts(field_expr) -> list[str];
    def _julia_field_info(field_expr) -> tuple[Optional[str], Optional[str]];
    static def _julia_scope_join(outer: Optional[str], inner: Optional[str]) -> Optional[str];
    def _julia_signature_call(function_node) -> any;
    def _julia_signature_callee(function_node) -> any;

    def _julia_definition_qualifier(function_node) -> Optional[str];

    def _julia_short_qualifier(call_expr) -> Optional[str];
    def _resolve_julia_import_alias(
        alias: str,
        enclosing_class: Optional[str],
        enclosing_func: Optional[str],
        import_map: dict[str, str],
    ) -> Optional[str];
    def _julia_call_is_in_signature(call_node) -> bool;
    def _julia_short_func_name(call_expr) -> Optional[str];
    def _julia_string_arg(call_expr) -> Optional[str];
    def _julia_call_first_identifier(call_expr) -> Optional[str];
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
    static def _lua_get_require_target(call_node) -> Optional[str];

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
    ) -> bool;
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
    static def _zig_extract_import_target(args_node) -> Optional[str];
    def _extract_zig_calls_in_subtree(
        `root,
        file_path: str,
        edges: list[EdgeInfo],
        enclosing_class: Optional[str],
        enclosing_func: Optional[str],
    );

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
    def _js_argument_values(arguments) -> list;
    def _js_wrapper_name(call_node, _depth: int = 0) -> Optional[str];
    def _js_wrapped_function(call_node, _depth: int = 0, chain=None) -> any;
    def _js_in_test_body(
        nodes: list[NodeInfo],
        file_path: str,
        enclosing_class: Optional[str],
        enclosing_func: Optional[str],
    ) -> bool;
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
    static def _get_js_static_member_path(`node) -> Optional[str];
    static def _get_java_annotations(class_node) -> list[str];
    static def _spring_config_annotation_name(annotation_node) -> Optional[str];

    static def _spring_config_string_literals(`node) -> list[str];
    def _spring_config_annotation_values(
        annotation_node, accepted_keys: frozenset[str]
    ) -> list[str];
    def _emit_spring_config_edges(
        class_node,
        class_name: str,
        enclosing_class: Optional[str],
        file_path: str,
        edges: list[EdgeInfo],
    );
    def _emit_spring_injections(
        class_node,
        class_name: str,
        class_annotations: list[str],
        language: str,
        file_path: str,
        edges: list[EdgeInfo],
        import_map: Optional[dict[str, str]] = None,
    );
    def _emit_spring_field_injection(
        field_node,
        qualified_source: str,
        file_path: str,
        edges: list[EdgeInfo],
        has_required_args: bool,
        has_all_args: bool,
        import_map: Optional[dict[str, str]],
    );
    def _emit_spring_constructor_injection(
        ctor_node,
        qualified_source: str,
        file_path: str,
        edges: list[EdgeInfo],
        import_map: Optional[dict[str, str]],
    );
    static def _java_annotation_name(annotation_node) -> Optional[str];
    def _scheduled_annotations(method_node) -> list;
    static def _java_annotation_attributes(annotation_node) -> dict[str, str];
    static def _java_string_literal_values(`node) -> list[str];
    def _spring_mapping_paths(annotation_node) -> list[str];
    def _spring_mapping_methods(annotation_node, name: str) -> list[str];
    static def _join_spring_route(prefix: str, path: str) -> str;
    def _emit_spring_endpoint_nodes(
        method_node,
        method_name: str,
        class_name: Optional[str],
        file_path: str,
        import_map: dict[str, str],
        nodes: list[NodeInfo],
        edges: list[EdgeInfo],
    ) -> int;
    def _java_invocation_chain_has_route(invocation) -> bool;
    static def _webflux_route_arguments(invocation) -> tuple[Optional[str], Optional[object]];
    def _resolve_java_method_reference_target(
        reference,
        file_path: str,
        enclosing_class: Optional[str],
        import_map: dict[str, str],
        defined_names: set[str],
    ) -> Optional[str];
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
    static def _spring_schedule_kind(attributes: dict[str, str]) -> str;
    def _emit_scheduled_nodes_from_method(
        method_node,
        method_name: str,
        class_name: Optional[str],
        file_path: str,
        nodes: list[NodeInfo],
        edges: list[EdgeInfo],
    ) -> int;
    def _java_annotations_named(method_node, names: frozenset[str]) -> list;
    static def _java_type_name(`node) -> Optional[str];
    class def _spring_java_type(type_name: str, import_map: dict[str, str]) -> str;
    static def _resolve_java_type_identity(type_name: str, import_map: dict[str, str]) -> str;

    static def _descendants_of_type(`node, node_type: str) -> list;
    def _emit_spring_event_listener_edges(
        method_node,
        method_name: str,
        class_name: Optional[str],
        file_path: str,
        import_map: dict[str, str],
        edges: list[EdgeInfo],
    ) -> int;
    def _emit_spring_event_publish_edges(
        method_node,
        method_name: str,
        class_name: Optional[str],
        file_path: str,
        import_map: dict[str, str],
        edges: list[EdgeInfo],
    ) -> int;
    def _emit_temporal_stub_fields(
        class_node, class_name: str, file_path: str, edges: list[EdgeInfo]
    );
    static def _get_kafka_annotation_topics(annotation_node) -> list[str];
    def _emit_kafka_edges_from_class(
        class_node, class_name: str, file_path: str, edges: list[EdgeInfo]
    );
    def _emit_kafka_edges_from_method(
        method_node,
        method_name: str,
        class_name: Optional[str],
        file_path: str,
        edges: list[EdgeInfo],
    );
    def _get_docstring_summary(`node, language: str) -> Optional[str];
    static def _python_docstring_value(`node) -> Optional[str];
    static def _line_doc_payload(text: str, language: str) -> Optional[str];
    def _preceding_doc_comment(`node, language: str) -> Optional[str];
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
    def _index_ambiguous_method_scopes(`root, language: str, import_map: dict);
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
    def _extract_imports(
        child, language: str, source: bytes, file_path: str, edges: list[EdgeInfo]
    ) -> bool;
    def _resolve_import_target(
        module: str, file_path: str, language: str, form: Optional[str] = None
    ) -> tuple[Optional[str], Optional[str]];
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
    static def _get_js_member_call_name(`node) -> Optional[str];
    def _get_member_call_receiver_method(
        `node, language: str
    ) -> tuple[Optional[str], Optional[str]];
    static def _get_csharp_receiver_method(`node) -> tuple[Optional[str], Optional[str]];
    def _resolve_php_scoped_calls(
        `root, nodes: list[NodeInfo], edges: list[EdgeInfo], file_path: str
    ) -> list[EdgeInfo];
    def _extract_php_laravel_edges(
        `root, file_path: str, nodes: list[NodeInfo], edges: list[EdgeInfo]
    );
    def _walk_php_laravel_sequence(
        container, file_path: str, nodes: list[NodeInfo], edges: list[EdgeInfo], namespace: str
    );
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
    );

    static def _php_namespace_name(`node) -> str;
    static def _php_import_bindings(`node) -> dict[str, str];
    static def _php_resolve_class_reference(
        reference: str, namespace: str, imports: dict[str, str]
    ) -> str;

    def _php_class_extends_eloquent_model(`node, namespace: str, imports: dict[str, str]) -> bool;
    static def _php_scoped_call_parts(`node) -> tuple[Optional[str], Optional[str]];

    static def _php_class_constant_reference(`node) -> Optional[str];

    def _php_route_handler(`node) -> Optional[tuple[str, str]];

    static def _php_route_arguments(`node) -> list;
    static def _php_string_literal(value) -> Optional[str];

    class def _php_route_literal(`node) -> Optional[str];

    def _php_route_facade_call(`node, namespace: str, imports: dict[str, str]) -> Optional[str];
    def _php_route_group_settings(
        call, namespace: str, imports: dict[str, str]
    ) -> Optional[tuple[str, Optional[str]]];

    def _php_route_enclosing_groups(
        `node, namespace: str, imports: dict[str, str]
    ) -> Optional[tuple[str, Optional[str]]];

    def _php_endpoint_handler(
        argument, group_controller: Optional[str]
    ) -> Optional[tuple[str, str]];
    def _emit_laravel_endpoint_nodes(
        `node,
        file_path: str,
        nodes: list[NodeInfo],
        edges: list[EdgeInfo],
        namespace: str,
        imports: dict[str, str],
    );

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
    );

    def _emit_laravel_relationship_edge(
        `node,
        file_path: str,
        edges: list[EdgeInfo],
        namespace: str,
        imports: dict[str, str],
        enclosing_class: Optional[str],
        enclosing_func: Optional[str],
    );
    static def _get_java_method_and_receiver(`node) -> tuple[Optional[str], Optional[str]];
    static def _java_this_field_call(`node) -> bool;
    class def _java_expression_receiver(`node) -> bool;
    def _extract_jsx_component_call(
        child,
        language: str,
        file_path: str,
        edges: list[EdgeInfo],
        enclosing_class: Optional[str],
        enclosing_func: Optional[str],
        import_map: Optional[dict[str, str]],
        defined_names: Optional[set[str]],
    );
    def _resolve_jsx_component_target(
        `node, language: str, file_path: str, import_map: dict[str, str], defined_names: set[str]
    ) -> Optional[str];

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
    );
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
    );
    def _emit_reference_if_known(
        name: str,
        language: str,
        file_path: str,
        caller: str,
        edges: list[EdgeInfo],
        import_map: dict[str, str],
        defined_names: set[str],
        line: int = 0,
    );
    def _ref_from_pair(
        pair_node,
        source: bytes,
        language: str,
        file_path: str,
        caller: str,
        edges: list[EdgeInfo],
        import_map: dict[str, str],
        defined_names: set[str],
    );
    def _ref_from_assignment(
        assign_node,
        source: bytes,
        language: str,
        file_path: str,
        caller: str,
        edges: list[EdgeInfo],
        import_map: dict[str, str],
        defined_names: set[str],
    );
    def _ref_from_array(
        array_node,
        source: bytes,
        language: str,
        file_path: str,
        caller: str,
        edges: list[EdgeInfo],
        import_map: dict[str, str],
        defined_names: set[str],
    );
    def _ref_from_arguments(
        args_node,
        source: bytes,
        language: str,
        file_path: str,
        caller: str,
        edges: list[EdgeInfo],
        import_map: dict[str, str],
        defined_names: set[str],
    );
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
    def _rust_path_segments(`node) -> list[str];
    def _parse_rust_use_node(`node, prefix: tuple[str, ...] = ()) -> list[tuple[str, str]];
    def _resolve_rust_type_target(
        segments: list[str], file_path: str, import_map: dict[str, str], defined_names: set[str]
    ) -> str;
    def _extract_rust_impl(
        impl_node,
        source: bytes,
        file_path: str,
        nodes: list[NodeInfo],
        edges: list[EdgeInfo],
        import_map: dict[str, str],
        defined_names: set[str],
        depth: int,
    );
    def _extract_verilog_constructs(
        child,
        node_type: str,
        file_path: str,
        nodes: list[NodeInfo],
        edges: list[EdgeInfo],
        enclosing_class: Optional[str],
        enclosing_func: Optional[str],
    ) -> bool;
    def _collect_file_scope(
        `root, language: str, source: bytes, file_path: Optional[str] = None
    ) -> tuple[dict[str, str], set[str]];
    def _collect_julia_scoped_import_names(
        `node, source: bytes, import_map: dict[str, str], scope: Optional[str] = None
    );
    def _expand_python_star_imports(
        `root,
        file_path: str,
        import_map: dict[str, str],
        resolving: frozenset[str] = resolving_default_,
    );
    def _get_python_star_exports(
        module_file: str, resolving: frozenset[str] = resolving_default__
    ) -> dict[str, str];
    def _read_python_star_exports(module_path: Path, resolving: frozenset[str]) -> dict[str, str];
    static def _extract_python_dunder_all(`root) -> Optional[set[str]];
    def _import_repo_boundary(file_path: str) -> Path;
    static def _path_is_within(path: Path, boundary: Path) -> bool;
    def _file_exists_exact(path: Path) -> bool;
    def _dir_entry_names(directory: Path) -> frozenset[str];
    def _npm_alias_path_is_indexed(path: Path) -> bool;
    def _path_is_indexed(path: Path, boundary: Path) -> bool;
    def _compute_path_is_indexed(path: Path, boundary: Path) -> bool;
    def _ignore_patterns(boundary: Path) -> Optional[list[str]];
    def _dir_exists_exact(path: Path) -> bool;
    static def _python_imported_names(`node) -> list[str];
    def _python_package_dir(module: str, file_path: Optional[str]) -> Optional[Path];
    def _python_submodule_file(package_dir: Path, name: str) -> Optional[str];

    static has _PY_MODULE_ALIAS_MAX_DEPTH: any = 5;
    def _python_module_alias_target(module_file: str) -> str;
    def _python_module_alias(module_file: str) -> Optional[str];
    class def _cached_python_module_alias(module_path: Path) -> Optional[str];
    static def _read_python_module_alias(module_path: Path) -> Optional[str];
    static def _python_name_bindings(
        tree: ast.Module, local: str
    ) -> list[tuple[str, Optional[str]]];
    def _python_submodule_names(`node, package_dir: Path) -> list[str];
    def _python_from_import_targets(`node, module: str, file_path: Optional[str]) -> list[str];
    def _python_import_origin(module: str, file_path: str) -> Optional[str];
    def _python_module_search(module: str, file_path: str) -> tuple[list[Path], Path, Path];
    def _python_folder_hides_module(module: str, folder: Path) -> bool;
    static def _python_module_candidates(base: Path, has_tail: bool) -> tuple[Path, ...];
    def _resolve_python_module_in_repo(module: str, file_path: str) -> Optional[str];
    def _resolve_python_namespace_dir(module: str, file_path: str) -> Optional[Path];
    def _collect_js_exported_local_names(`node, defined_names: set[str]);
    static def _js_static_module_target(call_node) -> Optional[str];
    def _extract_js_module_call(call_node, file_path: str, language: str, edges: list[EdgeInfo]);
    static def _js_module_call_is_deferred(call_node) -> bool;
    def _collect_js_require_names(declaration, import_map: dict[str, str]);
    def _collect_import_names(
        `node,
        language: str,
        source: bytes,
        import_map: dict[str, str],
        file_path: Optional[str] = None,
    );
    def _collect_js_import_names(clause_node, module: str, import_map: dict[str, str]);
    static def _js_imported_symbol_name(local_name: str, import_map: dict[str, str]) -> str;
    def exclude_files(paths: set[str]);
    def _resolve_module_to_file(
        module: str, file_path: str, language: str, form: Optional[str] = None
    ) -> Optional[str];
    def _do_resolve_module(
        module: str, file_path: str, language: str, form: Optional[str] = None
    ) -> Optional[str];
    def _parts_within(base: Path, relative: str, boundary: Path) -> Optional[tuple[str, ...]];
    def _exact_dir(boundary: Path, parts: tuple[str, ...]) -> Optional[Path];
    def _exact_file(boundary: Path, parts: tuple[str, ...]) -> Optional[Path];
    def _go_module_at(directory: Path) -> Optional[_GoModule];
    def _go_module_chain(caller_dir: Path, boundary: Path) -> list[_GoModule];
    def _go_package_dir(record: _GoModule, module: str, boundary: Path) -> Optional[Path];
    def _go_package_holds_source(package_dir: Path, boundary: Path) -> bool;
    def _resolve_go_package_dir(module: str, file_path: str) -> Optional[Path];
    def _do_resolve_go_package_dir(module: str, file_path: str) -> Optional[Path];
    def _ruby_looks_like_rails(boundary: Path) -> bool;
    def _ruby_gemspec_require_paths(boundary: Path) -> tuple[str, ...];
    def _ruby_load_path_additions(boundary: Path) -> list[Path];
    def _ruby_load_roots(boundary: Path) -> tuple[Path, ...];
    def _ruby_tree_holds_source(directory: Path, boundary: Path) -> bool;
    def _resolve_ruby_require_all_dir(module: str, file_path: str) -> Optional[Path];
    def _java_source_roots(file_path: str) -> tuple[Optional[Path], list[Path]];
    def _java_same_package_file(class_name: str, file_path: str) -> Optional[str];
    def _qualify_java_same_package_constructors(
        edges: list[EdgeInfo], file_path: str, import_map: dict[str, str]
    ) -> list[EdgeInfo];
    static def _mark_java_unknown_test_receivers(edges: list[EdgeInfo]) -> list[EdgeInfo];
    def _resolve_ruby_module_file(
        module: str, file_path: str, form: Optional[str]
    ) -> Optional[str];
    static def _rust_dependency_specs(manifest: dict[str, Any]) -> dict[str, Any];
    static def _rust_crate_layout(crate_root: Path) -> Optional[tuple[Path, Path]];
    def _rust_project_context(
        file_path: str
    ) -> Optional[tuple[Path, Path, Path, dict[str, Path], Path]];

    static def _rust_current_module_parts(file_path: Path, source_root: Path) -> list[str];

    static def _rust_module_file_for_parts(
        source_root: Path, root_file: Path, parts: list[str]
    ) -> Optional[Path];
    static def _rust_names_match_case(source_root: Path, candidate: Path) -> bool;
    def _resolve_rust_module_file(module: str, file_path: str) -> Optional[str];
    def _resolve_php_composer_module(module: str, caller_dir: Path) -> Optional[str];
    def _php_repository_boundary(start: Path) -> Optional[Path];
    def _find_php_composer_psr4(start: Path, boundary: Path) -> _PhpPsr4Mappings;
    def _find_dart_pubspec_root(start: Path, pkg_name: str) -> Optional[Path];
    def _resolve_rust_scoped_call(
        call_name: str, file_path: str, import_map: dict[str, str], defined_names: set[str]
    ) -> Optional[str];
    def _resolve_call_target(
        call_name: str,
        file_path: str,
        language: str,
        import_map: dict[str, str],
        defined_names: set[str],
    ) -> str;
    def _resolve_imported_symbol(
        symbol_name: str, module: str, file_path: str, language: str
    ) -> Optional[str];
    def _python_reexport_origin(module_file: str, symbol_name: str) -> str;
    def _resolve_exported_symbol(
        module_file: str, symbol_name: str, seen: Optional[set[tuple[str, str]]] = None
    ) -> Optional[str];
    def _qualify(name: str, file_path: str, enclosing_class: Optional[str]) -> str;
    def _node_qualified(`node: NodeInfo) -> str;

    static has _CUSTOM_NAME_LEAF_TYPES: any = tuple(
        ("word identifier name simple_identifier command_name key_brace type_identifier "
            "property_identifier constant").split(),
    );

    static has _MAX_CUSTOM_NAME_DEPTH: any = 4;

    static has _MAX_CUSTOM_NAME_LEN: any = 256;
    def _custom_name_leaf(`node, depth: int) -> any;
    def _find_custom_descendant(`node, type_name: str, depth: int) -> any;
    def _clean_custom_name(text: str) -> Optional[str];
    def _custom_leaf_name(`node) -> Optional[str];
    def _resolve_custom_name(`node, language: str) -> Optional[str];
    def _get_name(`node, language: str, kind: str) -> Optional[str];
    def _get_go_receiver_type(`node) -> Optional[str];
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
    static def _go_field_binds_name(`node, field: str, name: str) -> bool;
    class def _go_function_parameters_bind_name(`node, name: str) -> bool;
    def _go_receiver_binding_index(
        method, receiver_name: str
    ) -> tuple[str, tuple[int, ...], tuple[int, ...]];
    static def _go_receiver_is_shadowed(
        `node, bindings: tuple[str, tuple[int, ...], tuple[int, ...]]
    ) -> bool;

    static def _cpp_scope_join(outer: Optional[str], inner: Optional[str]) -> Optional[str];
    def _cpp_lexical_namespace(`node) -> Optional[str];
    def _cpp_lexical_class_names(`node) -> list[str];
    def _cpp_function_identity(
        `node, name: str, source: bytes
    ) -> tuple[Optional[str], str, Optional[str]];
    def _cpp_find_function_declarator(declarator) -> any;
    def _cpp_is_callable_declaration(declarator) -> bool;
    static def _cpp_declaration_has_callable_scope(declaration) -> bool;
    def _cpp_find_qualified_identifier(declarator) -> any;
    def _cpp_callable_name(declarator) -> Optional[str];
    def _cpp_find_declarator_kind(declarator, kind: str) -> any;
    def _cpp_parameter_type(parameter, source: bytes) -> str;
    def _cpp_declarator_name(declarator) -> any;
    def _get_params(`node, language: str, source: bytes) -> Optional[str];
    def _get_return_type(`node, language: str, source: bytes) -> Optional[str];
    def _get_bases(`node, language: str, source: bytes) -> list[str];
    static def _extract_go_import_specs(`node) -> list[_ImportSpec];
    static def _ruby_string_literal(`node) -> Optional[str];
    def _extract_ruby_import_specs(`node) -> list[_ImportSpec];
    def _extract_import_specs(
        `node, language: str, source: bytes, file_path: Optional[str] = None
    ) -> list[_ImportSpec];
    def _import_context(
        `node, language: str, source: bytes, file_path: Optional[str]
    ) -> Optional[str];
    static def _python_import_context(`node, source: bytes) -> Optional[str];
    def _python_names_parent_package(`node, module: str, file_path: Optional[str]) -> bool;
    def _js_import_is_type_only(`node, file_path: Optional[str]) -> bool;
    def _extract_import(
        `node, language: str, source: bytes, file_path: Optional[str] = None
    ) -> list[str];
    def _get_call_name(`node, language: str, source: bytes) -> Optional[str];

    static has _CUSTOM_CALLEE_FIELDS: any = ("function", "callee", "expr", "name");

    static has _MAX_CUSTOM_CALLEE_DESCENT: any = 32;
    def _get_custom_call_name(`node) -> Optional[str];
    def _get_jsx_component_reference(`node) -> Optional[tuple[Optional[str], str]];
    def _get_member_expression_root_name(`node) -> Optional[str];
    static def _looks_like_component_name(name: str) -> bool;

    static has _TEST_MODIFIER_SUFFIXES: any = frozenset({
        "only",
        "skip",
        "each",
        "todo",
        "concurrent",
        "failing",
    });
    def _get_base_call_name(`node, source: bytes) -> Optional[str];
    static def _r_call_func_name(call_node) -> Optional[str];
    static def _r_first_string_arg(call_node) -> Optional[str];
    static def _r_iter_args(call_node) -> Generator[any, any, any];
    class def _r_find_named_arg(call_node, arg_name: str) -> any;
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
    );
}
