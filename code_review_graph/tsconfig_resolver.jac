import from __future__ { annotations }

import builtins, json, logging, os, re;

import from pathlib { Path }

import from typing { Optional }

glob logger: any = logging.getLogger(__name__);

glob _PROBE_EXTENSIONS: any = [".ts", ".tsx", ".js", ".jsx", ".vue", ".mts", ".cts"];

glob _TSCONFIG_NAMES: any = ["tsconfig.json", "tsconfig.app.json", "jsconfig.json"];

obj TsconfigResolver {
    has _cache: any;

    def init {
        self._cache = {};
    }

    def resolve_alias(import_str: str, file_path: str) -> Optional[str] {
        try {
            config: any = self._load_tsconfig_for_file(file_path);
            if config is None {
                return None;
            }

            paths: dict[str, list[str]] = config.get("paths", {});
            if paths {
                anchor: str = config.get("_base_url_dir")
                    or config.get("_paths_dir")
                    or config.get("_tsconfig_dir", "");
                resolved: any = self._match_and_probe(import_str, paths, Path(anchor));
                if resolved or `any(_match_pattern(p, import_str) is not None for p in paths) {
                    return resolved;
                }
            }
            base_url_dir: Optional[str] = config.get("_base_url_dir");
            if base_url_dir and _stays_under_base_url(import_str) {
                joined: any = os.path.normpath(Path(base_url_dir) / import_str);
                found: any = _probe_path(Path(joined).resolve());
                return `str(found) if found else None;
            }
            return None;
        } except (OSError, ValueError, TypeError) {
            logger.debug("TsconfigResolver: unexpected error for %s", file_path, exc_info=True);
            return None;
        }
    }

    def keeps_empty_imports(file_path: str) -> bool {
        try {
            config: any = self._load_tsconfig_for_file(file_path);
        } except (OSError, ValueError) {
            return False;
        }
        options: any = config.get("compilerOptions") if config else None;
        if not isinstance(options, `dict) {
            return False;
        }
        return options.get("verbatimModuleSyntax") is True
            or options.get("importsNotUsedAsValues") in ("preserve", "error");
    }

    def _load_tsconfig_for_file(file_path: str) -> Optional[dict] {
        start_dir: any = Path(file_path).parent.resolve();
        current: any = start_dir;
        visited: list[str] = [];

        while True {
            dir_str: any = `str(current);
            if dir_str in self._cache {
                result: any = self._cache[dir_str];
                visited_dir: any;
                for visited_dir in visited {
                    self._cache[visited_dir] = result;
                }
                return result;
            }

            visited.append(dir_str);

            for name in _TSCONFIG_NAMES {
                candidate: any = current / name;
                if candidate.is_file() {
                    config: any = self._parse_tsconfig(candidate);
                    config["_tsconfig_dir"] = dir_str;
                    for visited_dir in visited {
                        self._cache[visited_dir] = config;
                    }
                    return config;
                }
            }

            parent: any = current.parent;
            if parent == current {
                for visited_dir in visited {
                    self._cache[visited_dir] = None;
                }
                return None;
            }
            current = parent;
        }
    }

    def _parse_tsconfig(tsconfig_path: Path) -> dict {
        seen: set[str] = set[any]();
        return self._resolve_extends(tsconfig_path, seen);
    }

    def _resolve_extends(tsconfig_path: Path, seen: set[str]) -> dict {
        canonical: any = os.path.abspath(tsconfig_path);
        if canonical in seen {
            logger.debug("TsconfigResolver: cycle detected at %s", canonical);
            return {};
        }
        seen = seen | {canonical};

        try {
            raw: any = tsconfig_path.read_text(encoding="utf-8", errors="replace");
        } except OSError {
            logger.debug("TsconfigResolver: cannot read %s", tsconfig_path);
            return {};
        }

        stripped: any = self._strip_jsonc_comments(raw);
        try {
            data: dict = json.loads(stripped);
        } except json.JSONDecodeError {
            logger.debug("TsconfigResolver: invalid JSON in %s", tsconfig_path);
            return {};
        }

        result: dict = {};

        extends: Optional[str] = data.get("extends");
        if extends and isinstance(extends, `str) and extends.startswith(".") {
            parent_path: any = Path(os.path.abspath(tsconfig_path.parent / extends));
            if not parent_path.suffix {
                parent_path = parent_path.with_suffix(".json");
            }
            if parent_path.is_file() {
                parent_config: any = self._resolve_extends(parent_path, seen);
                parent_opts: any = parent_config.get("compilerOptions", {});
                result.setdefault("compilerOptions", {}).update(parent_opts);
                for anchor in ("_base_url_dir", "_paths_dir") {
                    if anchor in parent_config {
                        result[anchor] = parent_config[anchor];
                    }
                }
            }
        }

        child_opts: dict = data.get("compilerOptions", {});
        result.setdefault("compilerOptions", {}).update(child_opts);
        if isinstance(child_opts, `dict) {
            config_dir: any = os.path.abspath(tsconfig_path.parent);
            base_url: any = child_opts.get("baseUrl");
            if isinstance(base_url, `str) {
                result["_base_url_dir"] = os.path.normpath(os.path.join(config_dir, base_url));
            } elif base_url is None and "baseUrl" in child_opts {
                result.pop("_base_url_dir", None);
            }
            if "paths" in child_opts {
                result["_paths_dir"] = config_dir;
            }
        }

        compiler_options: any = result.get("compilerOptions", {});
        if "baseUrl" in compiler_options {
            result["baseUrl"] = compiler_options["baseUrl"];
        }
        if "paths" in compiler_options {
            result["paths"] = compiler_options["paths"];
        }

        return result;
    }

    def _strip_jsonc_comments(text: str) -> str {
        result: list[str] = [];
        i: any = 0;
        n: any = len(text);

        while i < n {
            ch: any = text[i];

            if ch == "\"" {
                result.append(ch);
                i += 1;
                while i < n {
                    c: any = text[i];
                    result.append(c);
                    if c == "\\" and i + 1 < n {
                        i += 1;
                        result.append(text[i]);
                    } elif c == "\"" {
                        break;
                    }
                    i += 1;
                }
                i += 1;
                continue;
            }

            if ch == "/" and i + 1 < n and text[i + 1] == "*" {
                i += 2;
                while i < n - 1 {
                    if text[i] == "*" and text[i + 1] == "/" {
                        i += 2;
                        break;
                    }
                    i += 1;
                } else {
                    i = n;
                }
                continue;
            }

            if ch == "/" and i + 1 < n and text[i + 1] == "/" {
                i += 2;
                while i < n and text[i] != "\n" {
                    i += 1;
                }
                continue;
            }

            result.append(ch);
            i += 1;
        }

        stripped: any = "".join(result);
        stripped = re.sub(",\\s*([\\]}])", "\\1", stripped);
        return stripped;
    }

    def _match_and_probe(
        import_str: str, paths: dict[str, list[str]], base_dir: Path
    ) -> Optional[str] {
        def _pattern_specificity(item: tuple[str, list[str]]) -> int {
            pat: any = item[0];
            return len(pat.partition("*")[0]);
        }

        sorted_paths: any = sorted(paths.items(), key=_pattern_specificity, reverse=True);

        for (pattern, replacements) in sorted_paths {
            suffix: any = _match_pattern(pattern, import_str);
            if suffix is None {
                continue;
            }

            for replacement in replacements {
                if "*" in replacement {
                    mapped: any = replacement.replace("*", suffix, 1);
                } else {
                    mapped = replacement;
                }
                candidate_base: any = Path(os.path.normpath(base_dir / mapped)).resolve();
                found: any = _probe_path(candidate_base);
                if found {
                    return `str(found);
                }
            }
        }

        return None;
    }

    def __repr__ -> str {
        return (getattr(builtins.object, "__repr__") as any)(self);
    }

    def __eq__(other: any) -> bool {
        return self is other;
    }

    def __hash__ -> int {
        return id(self);
    }
}

def _match_pattern(pattern: str, import_str: str) -> Optional[str] {
    if "*" not in pattern {
        return "" if import_str == pattern else None;
    }

    prefix: any;
    _: any;
    suffix_pat: any;
    (prefix, _, suffix_pat) = pattern.partition("*") as any;
    if not (import_str.startswith(prefix) and import_str.endswith(suffix_pat)) {
        return None;
    }

    end: any = len(import_str) - len(suffix_pat) if suffix_pat else len(import_str);
    return import_str[len(prefix):end];
}

def _stays_under_base_url(import_str: str) -> bool {
    return not os.path.isabs(import_str) and ".." not in re.split("[\\\\/]", import_str);
}

def _probe_path(base: Path) -> Optional[Path] {
    if base.is_file() {
        return base;
    }
    ext: any;
    for ext in _PROBE_EXTENSIONS {
        candidate: any = base.with_suffix(ext) if not base.suffix else Path(`str(base) + ext);
        if candidate.is_file() {
            return candidate;
        }
    }
    if base.is_dir() {
        for ext in _PROBE_EXTENSIONS {
            candidate = base / f"index{ext}";
            if candidate.is_file() {
                return candidate;
            }
        }
    }
    return None;
}
