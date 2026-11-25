"""npm / yarn / pnpm workspace package resolver.

Resolves bare imports of sibling workspace packages (``@acme/shared``,
``@acme/sdk/browser``) to the package's source files, so that
``IMPORTS_FROM`` edges cross package boundaries (#1030). In a workspace
these names are package-manager links, not ``compilerOptions.paths``
aliases, so :class:`~code_review_graph.tsconfig_resolver.TsconfigResolver`
never sees them.

Entry points come from ``exports`` (subpaths, conditions, fallback arrays
and ``*`` patterns, with Node's key priority and ``null`` blocking; a
subpath a package's ``exports`` does not list stays unresolved), then
``source``/``module``/``main``/``types``. Packages usually point those at
compiled output under ``dist/``, which a checkout does not contain, so a
build-output target is first retried under ``src/`` with source
extensions, then probed as written.

A wrong edge is worse than a missing one, so the resolver stays inside the
repository, probes case-exactly, never claims Node builtin names, skips a
name two members share, and only maps an unscoped name when the importing
package declares it.
"""

import builtins;

import from __future__ { annotations }

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

"""Resolves workspace package names to source files.

    One resolver belongs to one ``CodeParser``; parse workers each own a
    parser (see ``incremental._parse_single_file``), so the caches here are
    never shared between threads.

    *repo_root* bounds the upward search and every answer. *file_exists* is
    the case-exact file probe; ``CodeParser`` passes its own so that files
    hidden by ``forget`` stay hidden here too.
    """
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

    """Resolve a workspace package import to an absolute file path, or None."""
    def resolve(import_str: str, file_path: str) -> Optional[str];

    """Resolve an ``exports`` subpath key (``"."``, ``"./x"``) inside one package.

        For a package found some other way than workspace membership, such
        as the target of an npm alias (see ``npm_alias_resolver``).
        """
    def resolve_in_package(
        directory: Path, manifest: dict[str, Any], subpath: str
    ) -> Optional[str];

    """The workspace enclosing *raw_dir*, cached on the unresolved spelling."""
    def _workspace_for(raw_dir: str) -> Optional[_Workspace];

    """Return the nearest enclosing workspace, walking up from *start_dir*."""
    def _find_workspace(start_dir: Path) -> Optional[_Workspace];

    """Whether the importer's own package depends on (or is) *name*."""
    def _declares(importer_dir: str, workspace: _Workspace, name: str) -> bool;

    """Resolve an ``exports`` subpath key inside one package."""
    def _resolve_in_package(package: _Package, subpath: str) -> Optional[str];

    """Case-exact probe of *base*, *base* + source extensions, then index files."""
    def _probe(base: Path) -> Optional[Path];

    """Whether every component of *found* below *base* has its on-disk case.

        NTFS and APFS open ``Utils/`` when only ``utils/`` exists, so a probe
        alone would give Windows and macOS edges that Linux never sees.
        """
    def _exact_under(base: Path, found: Path) -> bool;

    """``is_file`` that also requires the exact name in the directory listing."""
    def _exists_exact(path: Path) -> bool;

    def _listing(directory: Path) -> frozenset[str];

    def __repr__ -> str;

    def __eq__(other: any) -> bool;

    def __hash__ -> int;
}

"""Split a bare specifier into (package name, ``exports`` subpath key).

    Follows npm naming: a scoped name is exactly ``@scope/name`` and an
    unscoped name is one segment; the rest is the subpath. Relative paths,
    absolute paths, ``node:`` builtins and ``@/`` style aliases return None.
    """
def _split_specifier(spec: str) -> Optional[tuple[str, str]];

def _read_json(path: Path) -> Any;

"""Workspace globs declared in *directory*, or None if it is not a root."""
def _workspace_patterns(directory: Path) -> Optional[list[str]];

"""A workspace glob relative to the root, or None if it could escape it."""
def _clean_pattern(raw: str) -> Optional[str];

"""Map every member package name to its directory and manifest."""
def _load_workspace(`root: Path, patterns: list[str]) -> _Workspace;

"""Directories under *root* matching workspace globs, without node_modules."""
def _expand_patterns(`root: Path, patterns: list[str]) -> list[Path];

"""Match by path component: ``**`` spans any number, ``*`` stays inside one."""
def _glob_match(path: str, pattern: str) -> bool;

"""Expand a ``**`` workspace glob with os.walk, pruning node_modules."""
def _walk_globstar(`root: Path, pattern: str) -> list[Path];

"""Names the importer's nearest named package.json depends on, plus its own name.

    Manifests without a ``name`` (``{"type": "module"}`` markers) are skipped.
    """
def _declared_names(importer_dir: Path, workspace_root: Path) -> frozenset[str];

"""Candidate target strings for *subpath*, or ``_BLOCKED``."""
def _entry_targets(manifest: dict[str, Any], subpath: str) -> list[str];

"""Targets ``exports`` maps *subpath* to, or ``_BLOCKED`` when Node would refuse it.

    A matched entry with no reachable target (``null``, ``[null]``, ``[]``,
    all conditions ``null``) blocks the subpath, and so does a subpath the map
    does not list (``ERR_PACKAGE_PATH_NOT_EXPORTED``). A malformed ``exports``
    counts as absent.
    """
def _exports_targets(exports: Any, subpath: str) -> list[str];

"""Every target string reachable through conditions and fallback arrays."""
def _flatten_targets(value: Any, depth: int = 0) -> list[str];

"""Source-first probe bases for one target string."""
def _target_candidates(base: Path, target: str, subpath: str) -> list[Path];

"""Names a compiled file's source may have, its own module format first."""
def _source_names(name: str) -> list[str];
