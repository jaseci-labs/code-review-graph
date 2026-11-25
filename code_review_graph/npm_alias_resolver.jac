"""Resolve npm dependency aliases to local workspace packages.

A package reaches the alias's entry points the same way a workspace member
does: :meth:`WorkspaceResolver.resolve_in_package` reads ``exports``, then
``source``/``module``/``main``, retries build output under ``src/``, and
probes case-exactly (#343).
"""

import builtins;

import operator;

import from __future__ { annotations }

import json;

import os;

import re;

import from pathlib { Path }

import from typing { Callable, Optional }

glob _DEPENDENCY_SECTIONS: any = (
    "dependencies",
    "devDependencies",
    "optionalDependencies",
    "peerDependencies",
);

glob _SKIPPED_DIRECTORIES: any = {".git", ".hg", ".svn", ".venv", "node_modules"};

"""Resolve ``alias/subpath`` imports declared with npm aliases.

    npm allows a dependency key to differ from its real package name:
    ``"sharedLib": "npm:@scope/shared@^1.0.0"``. Source imports then use
    ``sharedLib/...``. When the real package is also present as workspace
    source, resolve the import to that source instead of storing an external,
    unqueryable package string.
    """
obj NpmAliasResolver {
    has _repo_root: any,
        _package_resolver: any,
        _path_is_indexed: any,
        _manifest_cache: any,
        _alias_cache: any,
        _package_roots: any;

    """*package_resolver* finds entry points inside a package; ``CodeParser``
        passes its own so the probes share its case-exact, ``forget``-aware
        file check. *path_is_indexed* says whether a build indexes a path;
        a package the build ignores is never a candidate.
        """
    def init(
        repo_root: Optional[Path] = None,
        *,
        package_resolver: Optional[WorkspaceResolver] = None,
        path_is_indexed: Optional[Callable[[Path], bool]] = None,
    );

    """Whether the nearest manifest declares this import's package as an alias.

        Then npm installs the aliased package under that name, so no other
        resolver (a workspace member with the same name, say) may answer.
        """
    def governs(import_str: str, file_path: str) -> bool;

    """Return a local source file for an npm-aliased import, or ``None``."""
    def resolve_alias(import_str: str, file_path: str) -> Optional[str];

    """Collect npm aliases from the nearest package manifests.

        Node finds a dependency in the nearest ``node_modules`` that has it,
        so the nearest manifest declaring a name decides what it is. An
        ordinary dependency there hides an ``npm:`` alias of the same name
        further up, and the import stays external.
        """
    def _aliases_for_file(file_path: str) -> dict[str, str];

    """Index local package names without following generated/symlinked trees."""
    def _local_package_roots -> dict[str, list[Path]];

    def _read_manifest(path: Path) -> Optional[dict];

    static def _longest_matching_alias(import_str: str, aliases: dict[str, str]) -> Optional[str];

    def __repr__ -> str;

    def __eq__(other: any) -> bool;

    def __hash__ -> int;
}

glob _PACKAGE_NAME: any;

glob _Version: any;

glob _Comparator: any;

glob _TAG_RANGES: any;

glob _STAR_RANGES: any;

glob _FULL_VERSION: any;

glob _PARTIAL_VERSION: any;

glob _OPERATOR: any;

glob _HYPHEN: any;

glob _LOWEST_PRERELEASE: any;

with entry {
    _PACKAGE_NAME = re.compile("^(?:@[^/@\\s]+/)?[^/@\\s]+$");
}

"""Split ``npm:<name>@<range>`` into the real package name and the range."""
def _parse_alias_spec(specification: str) -> Optional[tuple[str, str]];

with entry {
    _Version = builtins.tuple[int, int, int, builtins.tuple[str, ...]];
    _Comparator = builtins.tuple[str, _Version];
    _TAG_RANGES = frozenset({"", "latest"});
    _STAR_RANGES = frozenset({"*", "x", "X"});
    _FULL_VERSION = re.compile(
        "^v?(\\d+)\\.(\\d+)\\.(\\d+)(?:-([0-9A-Za-z.-]+))?(?:\\+[0-9A-Za-z.-]+)?$"
    );
    _PARTIAL_VERSION = re.compile(
        "^v?(\\d+|[xX*])(?:\\.(\\d+|[xX*]))?(?:\\.(\\d+|[xX*]))?(?:-([0-9A-Za-z.-]+))?(?:\\+[0-9A-Za-z.-]+)?$",
    );
    _OPERATOR = re.compile("^(<=|>=|<|>|=|~>|~|\\^)?(.*)$");
    _HYPHEN = re.compile("^(\\S+)\\s+-\\s+(\\S+)$");
    _LOWEST_PRERELEASE = ("0",);
}

"""Whether a local package *version* satisfies an npm *version_range*."""
def version_satisfies(version: object, version_range: str) -> bool;

def _parse_version(text: str) -> Optional[_Version];

def _version_key(version: _Version) -> tuple;

"""Comparators that must all hold, or ``None`` when the set is unreadable."""
def _parse_comparator_set(text: str) -> Optional[list[_Comparator]];

def _partial(text: str) -> Optional[tuple[Optional[int], Optional[int], Optional[int], tuple]];

def _token_comparators(token: str) -> Optional[list[_Comparator]];

def _hyphen_comparators(low_text: str, high_text: str) -> Optional[list[_Comparator]];

def _set_matches(version: _Version, comparators: list[_Comparator]) -> bool;

def _safe_subpath(subpath: str) -> bool;
