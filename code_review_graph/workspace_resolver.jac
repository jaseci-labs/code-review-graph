import from __future__ { annotations }

import builtins;

import fnmatch;

import json;

import logging;

import os;

import from dataclasses { dataclass, field }

import from pathlib { Path, PurePosixPath }

import from typing { Any, Callable, Optional }

glob _yaml: any;

glob logger: any;

glob _LOOKUP_ERRORS: any;

glob _BUILD_OUTPUT_DIRS: any;

glob _FORMAT_DIRS: any;

glob _COMPILED_SUFFIXES: any;

glob _NATIVE_SOURCE_SUFFIXES: any;

glob _SOURCE_SUBSTITUTIONS: any;

glob _CONDITION_ORDER: any;

glob _ENTRY_FIELDS: any;

glob _DEPENDENCY_FIELDS: any;

glob _NODE_BUILTINS: any;

glob _MAX_EXPORTS_DEPTH: any;

glob _BLOCKED: list[str];

with entry {
    try {
        import yaml as _yaml;
    } except ImportError {
        _yaml = None;
    }

    logger = logging.getLogger(__name__);
    _LOOKUP_ERRORS = (OSError, ValueError, TypeError, RuntimeError);
    _BUILD_OUTPUT_DIRS = frozenset({"dist", "build", "out", "lib"});
    _FORMAT_DIRS = frozenset({"esm", "cjs", "mjs", "es", "umd", "types"});
    _COMPILED_SUFFIXES = (".d.ts", ".d.mts", ".d.cts", ".js", ".mjs", ".cjs", ".jsx");
    _NATIVE_SOURCE_SUFFIXES = {".d.mts": ".mts", ".mjs": ".mts", ".d.cts": ".cts", ".cjs": ".cts"};
    _SOURCE_SUBSTITUTIONS = {
        ".js": (".ts", ".tsx", ".jsx"),
        ".jsx": (".ts", ".tsx"),
        ".mjs": (".mts", ".ts", ".tsx"),
        ".cjs": (".cts", ".ts", ".tsx"),
    };
    _CONDITION_ORDER = (
        "source",
        "import",
        "module",
        "default",
        "require",
        "node",
        "browser",
        "types",
    );
    _ENTRY_FIELDS = ("source", "module", "main", "types", "typings");

    _DEPENDENCY_FIELDS = (
        "dependencies",
        "devDependencies",
        "peerDependencies",
        "optionalDependencies",
    );
    _NODE_BUILTINS = frozenset({
        "assert",
        "async_hooks",
        "buffer",
        "child_process",
        "cluster",
        "console",
        "constants",
        "crypto",
        "dgram",
        "diagnostics_channel",
        "dns",
        "domain",
        "events",
        "fs",
        "http",
        "http2",
        "https",
        "inspector",
        "module",
        "net",
        "os",
        "path",
        "perf_hooks",
        "process",
        "punycode",
        "querystring",
        "readline",
        "repl",
        "stream",
        "string_decoder",
        "sys",
        "timers",
        "tls",
        "trace_events",
        "tty",
        "url",
        "util",
        "v8",
        "vm",
        "wasi",
        "worker_threads",
        "zlib",
    });

    _MAX_EXPORTS_DEPTH = 8;
    _BLOCKED = [];
}

@dataclass(frozen=True)
class _Package {
    has directory: Path;

    has manifest: dict[str, Any];
}

@dataclass(frozen=True)
class _Workspace {
    has `root: Path;

    has packages: dict[str, _Package] = field(default_factory=dict[any, any]);
}

obj WorkspaceResolver {
    has _repo_root: any,
        _listings: any,
        _file_exists: any,
        _raw_dir_cache: any,
        _dir_cache: any,
        _declared_cache: any,
        _result_cache: any;

    def init(
        repo_root: Optional[Path] = None, file_exists: Optional[Callable[[Path], bool]] = None
    );
    def resolve(import_str: str, file_path: str) -> Optional[str];
    def resolve_in_package(
        directory: Path, manifest: dict[str, Any], subpath: str
    ) -> Optional[str];
    def _workspace_for(raw_dir: str) -> Optional[_Workspace];
    def _find_workspace(start_dir: Path) -> Optional[_Workspace];
    def _declares(importer_dir: str, workspace: _Workspace, name: str) -> bool;
    def _resolve_in_package(package: _Package, subpath: str) -> Optional[str];
    def _probe(base: Path) -> Optional[Path];
    def _exact_under(base: Path, found: Path) -> bool;
    def _exists_exact(path: Path) -> bool;

    def _listing(directory: Path) -> frozenset[str];

    def __repr__ -> str;

    def __eq__(other: any) -> bool;

    def __hash__ -> int;
}

def _split_specifier(spec: str) -> Optional[tuple[str, str]];

def _read_json(path: Path) -> Any;
def _workspace_patterns(directory: Path) -> Optional[list[str]];
def _clean_pattern(raw: str) -> Optional[str];
def _load_workspace(`root: Path, patterns: list[str]) -> _Workspace;
def _expand_patterns(`root: Path, patterns: list[str]) -> list[Path];
def _glob_match(path: str, pattern: str) -> bool;
def _walk_globstar(`root: Path, pattern: str) -> list[Path];
def _declared_names(importer_dir: Path, workspace_root: Path) -> frozenset[str];
def _entry_targets(manifest: dict[str, Any], subpath: str) -> list[str];
def _exports_targets(exports: Any, subpath: str) -> list[str];
def _flatten_targets(value: Any, depth: int = 0) -> list[str];
def _target_candidates(base: Path, target: str, subpath: str) -> list[Path];
def _source_names(name: str) -> list[str];
