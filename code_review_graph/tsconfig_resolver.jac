"""TypeScript tsconfig.json / jsconfig.json path alias resolver.

Resolves TypeScript path aliases (e.g., ``@/ -> src/``) declared in
``compilerOptions.paths``, and non-relative specifiers against
``compilerOptions.baseUrl`` when no ``paths`` pattern matches them, so that
``IMPORTS_FROM`` edges can point to real file paths instead of raw alias
strings. Plain-JS projects (Vue,
Nuxt, Vite) declare the same aliases in ``jsconfig.json``, which shares
the ``compilerOptions`` schema, so it is handled by the same parser.
"""

import builtins;

import from __future__ { annotations }

import json;

import logging;

import os;

import re;

import from pathlib { Path }

import from typing { Optional }

glob logger: any;

glob _PROBE_EXTENSIONS: any;

glob _TSCONFIG_NAMES: any;

with entry {
    logger = logging.getLogger(__name__);
    _PROBE_EXTENSIONS = [".ts", ".tsx", ".js", ".jsx", ".vue", ".mts", ".cts"];
    _TSCONFIG_NAMES = ["tsconfig.json", "tsconfig.app.json", "jsconfig.json"];
}

"""Resolves TypeScript path aliases (e.g., @/ -> src/) using tsconfig.json."""
obj TsconfigResolver {
    has _cache: any;

    def init;

    """Resolve a TS path alias to an absolute file path, or None."""
    def resolve_alias(import_str: str, file_path: str) -> Optional[str];

    """Whether tsc keeps an import whose names are all ``type`` ones.

        It is then emitted as ``import {} from "./b"``, which still loads ``b``.
        """
    def keeps_empty_imports(file_path: str) -> bool;

    """Find and load tsconfig.json for the given file."""
    def _load_tsconfig_for_file(file_path: str) -> Optional[dict];

    """Parse a tsconfig.json file (supports JSONC comments)."""
    def _parse_tsconfig(tsconfig_path: Path) -> dict;

    """Recursively resolve the tsconfig extends chain.

        ``baseUrl`` and ``paths`` are relative to the config file that declares
        them, so a root ``tsconfig.base.json`` extended from ``apps/api/`` still
        maps ``libs/*`` to ``<root>/libs/*``. The absolute anchors are kept in
        ``_base_url_dir`` and ``_paths_dir`` and inherited unchanged until a
        config down the chain declares its own; ``"baseUrl": null`` unsets the
        inherited ``baseUrl``. As in tsc, a config is located by the path it was
        opened through, normalized without following symlinks, so a base config
        reached through a symlink anchors where the link sits.
        """
    def _resolve_extends(tsconfig_path: Path, seen: set[str]) -> dict;

    """Remove // and /* */ comments and trailing commas from JSONC."""
    def _strip_jsonc_comments(text: str) -> str;

    """Match import_str against alias patterns and probe the filesystem."""
    def _match_and_probe(
        import_str: str, paths: dict[str, list[str]], base_dir: Path
    ) -> Optional[str];

    def __repr__ -> str;

    def __eq__(other: any) -> bool;

    def __hash__ -> int;
}

"""Return the wildcard-matched suffix if pattern matches import_str."""
def _match_pattern(pattern: str, import_str: str) -> Optional[str];

"""Whether joining *import_str* to baseUrl cannot leave baseUrl."""
def _stays_under_base_url(import_str: str) -> bool;

"""Probe base and base + extensions for an existing file."""
def _probe_path(base: Path) -> Optional[Path];
