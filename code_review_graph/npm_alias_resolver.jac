import from __future__ { annotations }

import builtins;

import operator;

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

obj NpmAliasResolver {
    has _repo_root: any,
        _package_resolver: any,
        _path_is_indexed: any,
        _manifest_cache: any,
        _alias_cache: any,
        _package_roots: any;
    def init(
        repo_root: Optional[Path] = None,
        *,
        package_resolver: Optional[WorkspaceResolver] = None,
        path_is_indexed: Optional[Callable[[Path], bool]] = None,
    );
    def governs(import_str: str, file_path: str) -> bool;
    def resolve_alias(import_str: str, file_path: str) -> Optional[str];
    def _aliases_for_file(file_path: str) -> dict[str, str];
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

def version_satisfies(version: object, version_range: str) -> bool;

def _parse_version(text: str) -> Optional[_Version];

def _version_key(version: _Version) -> tuple;
def _parse_comparator_set(text: str) -> Optional[list[_Comparator]];

def _partial(text: str) -> Optional[tuple[Optional[int], Optional[int], Optional[int], tuple]];

def _token_comparators(token: str) -> Optional[list[_Comparator]];

def _hyphen_comparators(low_text: str, high_text: str) -> Optional[list[_Comparator]];

def _set_matches(version: _Version, comparators: list[_Comparator]) -> bool;

def _safe_subpath(subpath: str) -> bool;
