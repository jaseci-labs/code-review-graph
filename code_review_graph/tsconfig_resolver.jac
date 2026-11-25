import from __future__ { annotations }

import builtins, json, logging, os, re;

import from pathlib { Path }

import from typing { Optional }

glob logger: any = logging.getLogger(__name__);

glob _PROBE_EXTENSIONS: any = [".ts", ".tsx", ".js", ".jsx", ".vue", ".mts", ".cts"];

glob _TSCONFIG_NAMES: any = ["tsconfig.json", "tsconfig.app.json", "jsconfig.json"];

obj TsconfigResolver {
    has _cache: any;

    def init;
    def resolve_alias(import_str: str, file_path: str) -> Optional[str];
    def keeps_empty_imports(file_path: str) -> bool;
    def _load_tsconfig_for_file(file_path: str) -> Optional[dict];
    def _parse_tsconfig(tsconfig_path: Path) -> dict;
    def _resolve_extends(tsconfig_path: Path, seen: set[str]) -> dict;
    def _strip_jsonc_comments(text: str) -> str;
    def _match_and_probe(
        import_str: str, paths: dict[str, list[str]], base_dir: Path
    ) -> Optional[str];

    def __repr__ -> str;

    def __eq__(other: any) -> bool;

    def __hash__ -> int;
}

def _match_pattern(pattern: str, import_str: str) -> Optional[str];
def _stays_under_base_url(import_str: str) -> bool;
def _probe_path(base: Path) -> Optional[Path];
