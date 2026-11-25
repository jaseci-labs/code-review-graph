import from __future__ { annotations }

import builtins, fnmatch, json, logging, os;

import from dataclasses { dataclass, field }

import from pathlib { Path, PurePosixPath }

import from typing { Any, Callable, Optional }

glob _yaml: any;

with entry {
    try {
        import yaml as _yaml;
    } except ImportError {
        _yaml = None;
    }
}

glob logger: any = logging.getLogger(__name__);

glob _LOOKUP_ERRORS: any = (OSError, ValueError, TypeError, RuntimeError);

glob _BUILD_OUTPUT_DIRS: any = frozenset({"dist", "build", "out", "lib"});

glob _FORMAT_DIRS: any = frozenset({"esm", "cjs", "mjs", "es", "umd", "types"});

glob _COMPILED_SUFFIXES: any = (".d.ts", ".d.mts", ".d.cts", ".js", ".mjs", ".cjs", ".jsx");

glob _NATIVE_SOURCE_SUFFIXES: any = {
    ".d.mts": ".mts",
    ".mjs": ".mts",
    ".d.cts": ".cts",
    ".cjs": ".cts",
};

glob _SOURCE_SUBSTITUTIONS: any = {
    ".js": (".ts", ".tsx", ".jsx"),
    ".jsx": (".ts", ".tsx"),
    ".mjs": (".mts", ".ts", ".tsx"),
    ".cjs": (".cts", ".ts", ".tsx"),
};

glob _CONDITION_ORDER: any = tuple(
    "source import module default require node browser types".split()
);

glob _ENTRY_FIELDS: any = ("source", "module", "main", "types", "typings");

glob _DEPENDENCY_FIELDS: any = (
    "dependencies",
    "devDependencies",
    "peerDependencies",
    "optionalDependencies",
);

glob _NODE_BUILTINS: any = frozenset(
    ("assert async_hooks buffer child_process cluster console constants crypto dgram "
        "diagnostics_channel dns domain events fs http http2 https inspector module net os path "
        "perf_hooks process punycode querystring readline repl stream string_decoder sys timers tls "
        "trace_events tty url util v8 vm wasi worker_threads zlib").split(),
);

glob _MAX_EXPORTS_DEPTH: any = 8;

glob _BLOCKED: list[str] = [];

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
    ) {
        self._repo_root = Path(repo_root).resolve() if repo_root is not None else None;
        self._listings = {};
        self._file_exists = file_exists or self._exists_exact;
        self._raw_dir_cache = {};
        self._dir_cache = {};
        self._declared_cache = {};
        self._result_cache = {};
    }

    def resolve(import_str: str, file_path: str) -> Optional[str] {
        split: any = _split_specifier(import_str);
        if split is None {
            return None;
        }
        name: any;
        subpath: any;
        (name, subpath) = split as any;
        if not name.startswith("@") and name in _NODE_BUILTINS {
            return None;
        }

        importer_dir: any = os.path.dirname(file_path);
        workspace: any = self._workspace_for(importer_dir);
        if workspace is None {
            return None;
        }
        package: any = workspace.packages.get(name);
        if package is None {
            return None;
        }
        if not name.startswith("@") and not self._declares(importer_dir, workspace, name) {
            return None;
        }

        key: any = (`str(workspace.root), import_str);
        if key not in self._result_cache {
            try {
                result: any = self._resolve_in_package(package, subpath);
            } except _LOOKUP_ERRORS {
                logger.warning(
                    "WorkspaceResolver: cannot resolve %s in %s",
                    import_str,
                    package.directory,
                    exc_info=True,
                );
                result = None;
            }
            self._result_cache[key] = result;
        }
        return self._result_cache[key];
    }

    def resolve_in_package(
        directory: Path, manifest: dict[str, Any], subpath: str
    ) -> Optional[str] {
        try {
            return self._resolve_in_package(_Package(directory, manifest), subpath);
        } except _LOOKUP_ERRORS {
            logger.warning(
                "WorkspaceResolver: cannot resolve %s in %s", subpath, directory, exc_info=True
            );
            return None;
        }
    }

    def _workspace_for(raw_dir: str) -> Optional[_Workspace] {
        if raw_dir not in self._raw_dir_cache {
            try {
                start: any = Path(raw_dir).resolve();
            } except _LOOKUP_ERRORS {
                start = None;
            }
            self._raw_dir_cache[raw_dir] = self._find_workspace(start)
                if start is not None
                else None;
        }
        return self._raw_dir_cache[raw_dir];
    }

    def _find_workspace(start_dir: Path) -> Optional[_Workspace] {
        if self._repo_root is not None and not start_dir.is_relative_to(self._repo_root) {
            return None;
        }
        current: any = start_dir;
        visited: list[str] = [];
        result: Optional[_Workspace] = None;

        try {
            while True {
                dir_str: any = `str(current);
                if dir_str in self._dir_cache {
                    result = self._dir_cache[dir_str];
                    break;
                }
                visited.append(dir_str);
                patterns: any = _workspace_patterns(current);
                if patterns is not None {
                    result = _load_workspace(current, patterns);
                    break;
                }
                parent: any = current.parent;
                if parent == current or current == self._repo_root {
                    break;
                }
                current = parent;
            }
        } except _LOOKUP_ERRORS {
            logger.warning(
                "WorkspaceResolver: cannot read the workspace around %s", start_dir, exc_info=True
            );
            result = None;
        }

        for visited_dir in visited {
            self._dir_cache[visited_dir] = result;
        }
        return result;
    }

    def _declares(importer_dir: str, workspace: _Workspace, name: str) -> bool {
        if importer_dir not in self._declared_cache {
            try {
                declared: any = _declared_names(Path(importer_dir).resolve(), workspace.root);
            } except _LOOKUP_ERRORS {
                logger.warning(
                    "WorkspaceResolver: cannot read the manifest above %s", importer_dir
                );
                declared = frozenset();
            }
            self._declared_cache[importer_dir] = declared;
        }
        return name in self._declared_cache[importer_dir];
    }

    def _resolve_in_package(package: _Package, subpath: str) -> Optional[str] {
        base: any = package.directory;
        targets: any = _entry_targets(package.manifest, subpath);
        if targets is _BLOCKED {
            return None;
        }

        candidates: list[Path] = [];
        for target in targets {
            candidates.extend(_target_candidates(base, target, subpath));
        }
        rest: any = [] if subpath == "." else subpath[2:].split("/");
        candidates.append(base.joinpath("src", *rest) if rest else base / "src" / "index");
        candidates.append(base.joinpath(*rest) if rest else base / "index");

        package_root: any = base.resolve();
        for candidate in candidates {
            found: any = self._probe(candidate);
            if found is None or not self._exact_under(base, found) {
                continue;
            }
            resolved: any = found.resolve();
            if not resolved.is_relative_to(package_root) {
                continue;
            }
            if self._repo_root is not None and not resolved.is_relative_to(self._repo_root) {
                continue;
            }
            return `str(resolved);
        }
        return None;
    }

    def _probe(base: Path) -> Optional[Path] {
        exists: any = self._file_exists;
        if exists(base) {
            return base;
        }
        ext: any;
        for ext in _PROBE_EXTENSIONS {
            candidate: any = base.with_suffix(ext) if not base.suffix else Path(`str(base) + ext);
            if exists(candidate) {
                return candidate;
            }
        }
        for ext in _SOURCE_SUBSTITUTIONS.get(base.suffix, ()) {
            candidate = base.with_suffix(ext);
            if exists(candidate) {
                return candidate;
            }
        }
        if base.is_dir() {
            for ext in _PROBE_EXTENSIONS {
                candidate = base / f"index{ext}";
                if exists(candidate) {
                    return candidate;
                }
            }
        }
        return None;
    }

    def _exact_under(base: Path, found: Path) -> bool {
        try {
            parts: any = found.relative_to(base).parts;
        } except ValueError {
            return False;
        }
        current: any = base;
        for part in parts {
            if part not in self._listing(current) {
                return False;
            }
            current = current / part;
        }
        return True;
    }

    def _exists_exact(path: Path) -> bool {
        return path.name in self._listing(path.parent) and path.is_file();
    }

    def _listing(directory: Path) -> frozenset[str] {
        key: any = `str(directory);
        names: any = self._listings.get(key);
        if names is None {
            try {
                names = frozenset(os.listdir(directory));
            } except OSError {
                names = frozenset();
            }
            self._listings[key] = names;
        }
        return names;
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

def _split_specifier(spec: str) -> Optional[tuple[str, str]] {
    if not spec or spec[0] in "./\\" or ":" in spec {
        return None;
    }
    parts: any = spec.split("/");
    if spec.startswith("@") {
        if len(parts) < 2 or len(parts[0]) < 2 or not parts[1] {
            return None;
        }
        name: any;
        rest: any;
        (name, rest) = ("/".join(parts[:2]), parts[2:]);
    } else {
        (name, rest) = (parts[0], parts[1:]);
    }
    if `any(not segment for segment in rest) {
        return None;
    }
    return (name, "./" + "/".join(rest) if rest else ".");
}

def _read_json(path: Path) -> Any {
    try {
        return json.loads(path.read_text(encoding="utf-8-sig"));
    } except _LOOKUP_ERRORS {
        logger.debug("WorkspaceResolver: cannot read %s", path);
        return None;
    }
}

def _workspace_patterns(directory: Path) -> Optional[list[str]] {
    pnpm_file: any = directory / "pnpm-workspace.yaml";
    if pnpm_file.is_file() {
        data: Any = None;
        if _yaml is not None {
            try {
                data = _yaml.safe_load(pnpm_file.read_text(encoding="utf-8-sig"));
            } except Exception as exc {
                if not isinstance(exc, _LOOKUP_ERRORS + (_yaml.YAMLError,)) {
                    raise;
                }
                logger.warning("WorkspaceResolver: cannot read %s", pnpm_file);
            }
        }
        packages: any = data.get("packages") if isinstance(data, `dict) else None;
        return [p for p in packages if isinstance(p, `str)] if isinstance(packages, `list) else [];
    }

    manifest_path: any = directory / "package.json";
    if not manifest_path.is_file() {
        return None;
    }
    manifest: any = _read_json(manifest_path);
    if not isinstance(manifest, `dict) {
        return None;
    }
    workspaces: any = manifest.get("workspaces");
    if isinstance(workspaces, `dict) {
        workspaces = workspaces.get("packages");
    }
    if not isinstance(workspaces, `list) {
        return None;
    }
    return [p for p in workspaces if isinstance(p, `str)];
}

def _clean_pattern(raw: str) -> Optional[str] {
    pattern: any = raw.strip().replace("\\", "/");
    if not pattern or pattern.startswith("/") or ":" in pattern {
        return None;
    }
    pattern = pattern.removeprefix("./").strip("/");
    if not pattern or ".." in pattern.split("/") {
        return None;
    }
    return pattern;
}

def _load_workspace(`root: Path, patterns: list[str]) -> _Workspace {
    cleaned: any;
    `include: any = [p for p in patterns if not p.strip().startswith("!")];
    exclude: any = [
        cleaned
        for p in patterns
        if p.strip().startswith("!")
        if (cleaned := _clean_pattern(p.strip()[1:])) is not None
    ];
    packages: dict[str, _Package] = {};
    duplicates: set[str] = set[any]();

    for package_dir in _expand_patterns(`root, `include) {
        rel: any = package_dir.relative_to(`root).as_posix();
        if `any(_glob_match(rel, pattern) for pattern in exclude) {
            continue;
        }
        manifest: any = _read_json(package_dir / "package.json");
        if not isinstance(manifest, `dict) {
            continue;
        }
        name: any = manifest.get("name");
        if not isinstance(name, `str) or not name {
            continue;
        }
        if name in packages {
            duplicates.add(name);
        }
        packages[name] = _Package(package_dir, manifest);
    }
    for name in sorted(duplicates) {
        logger.warning("WorkspaceResolver: skipping %s, used by several members", name);
        del packages[name];
    }

    return _Workspace(`root, packages);
}

def _expand_patterns(`root: Path, patterns: list[str]) -> list[Path] {
    resolved_root: any = `root.resolve();
    found: dict[str, Path] = {};
    for raw in patterns {
        pattern: any = _clean_pattern(raw);
        if pattern is None {
            continue;
        }
        try {
            if "**" in pattern {
                matches: any = _walk_globstar(`root, pattern);
            } else {
                matches = [p.parent for p in `root.glob(f"{pattern}/package.json")];
            }
        } except _LOOKUP_ERRORS {
            logger.warning("WorkspaceResolver: skipping workspace pattern %r", raw);
            continue;
        }
        for directory in matches {
            try {
                inside: any = directory.resolve().is_relative_to(resolved_root);
                rel_parts: any = directory.relative_to(`root).parts;
            } except _LOOKUP_ERRORS {
                continue;
            }
            if inside and "node_modules" not in rel_parts {
                found.setdefault(`str(directory), directory);
            }
        }
    }
    return [found[key] for key in sorted(found)];
}

def _glob_match(path: str, pattern: str) -> bool {
    parts: any = path.split("/");
    reachable: any = [True] + [False] * len(parts);
    for piece in pattern.split("/") {
        if piece == "**" {
            for i in range(1, len(reachable)) {
                reachable[i] = reachable[i] or reachable[i - 1];
            }
        } else {
            reachable = [False] + [
                reachable[i] and fnmatch.fnmatchcase(parts[i], piece)
                for i in range(len(parts))
            ];
        }
    }
    return reachable[-1];
}

def _walk_globstar(`root: Path, pattern: str) -> list[Path] {
    `static: list[str] = [];
    for part_ in PurePosixPath(pattern).parts {
        part: any = part_;
        if `any(ch in part for ch in "*?[") {
            break;
        }
        `static.append(part);
    }
    start: any = `root.joinpath(*`static);
    if not start.is_dir() {
        return [];
    }

    matches: list[Path] = [];
    for (dirpath, dirnames, filenames) in os.walk(start) {
        dirnames[:] = [d for d in dirnames if d != "node_modules" and not d.startswith(".")];
        if "package.json" not in filenames {
            continue;
        }
        directory: any = Path(dirpath);
        if _glob_match(directory.relative_to(`root).as_posix(), pattern) {
            matches.append(directory);
        }
    }
    return matches;
}

def _declared_names(importer_dir: Path, workspace_root: Path) -> frozenset[str] {
    current: any = importer_dir;
    while True {
        manifest: any = _read_json(current / "package.json")
            if (current / "package.json").is_file()
            else None;
        if isinstance(manifest, `dict) and isinstance(manifest.get("name"), `str) {
            names: set[str] = set[any]();
            `own: any = manifest.get("name");
            if isinstance(`own, `str) {
                names.add(`own);
            }
            for fld in _DEPENDENCY_FIELDS {
                deps: any = manifest.get(fld);
                if isinstance(deps, `dict) {
                    names.update(k for k in deps if isinstance(k, `str));
                }
            }
            return frozenset(names);
        }
        if current == workspace_root or current.parent == current {
            return frozenset();
        }
        current = current.parent;
    }
}

def _entry_targets(manifest: dict[str, Any], subpath: str) -> list[str] {
    targets: list[str] = [];
    exports: any = manifest.get("exports");
    if exports is not None {
        exported: any = _exports_targets(exports, subpath);
        if exported is _BLOCKED {
            return _BLOCKED;
        }
        targets.extend(exported);
    }
    if subpath == "." {
        for key in _ENTRY_FIELDS {
            value: any = manifest.get(key);
            if isinstance(value, `str) and value {
                targets.append(value);
            }
        }
    }
    return `list(dict.fromkeys(targets));
}

def _exports_targets(exports: Any, subpath: str) -> list[str] {
    if isinstance(exports, (`str, `list)) {
        return _flatten_targets(exports) or _BLOCKED if subpath == "." else _BLOCKED;
    }
    if not isinstance(exports, `dict) {
        return [];
    }
    keys: any = [k for k in exports if isinstance(k, `str)];
    if not `any(k.startswith(".") for k in keys) {
        return _flatten_targets(exports) or _BLOCKED if subpath == "." else _BLOCKED;
    }
    if subpath in exports {
        return _flatten_targets(exports[subpath]) or _BLOCKED;
    }
    best: Optional[tuple[int, int, str, str, str]] = None;
    key: any;
    for key in keys {
        prefix: any;
        star: any;
        suffix: any;
        (prefix, star, suffix) = key.partition("*") as any;
        if not star or "*" in suffix {
            continue;
        }
        if subpath.startswith(prefix)
            and subpath.endswith(suffix)
            and len(subpath) > len(prefix) + len(suffix)
        {
            rank: any = (len(prefix), len(key), prefix, suffix, key);
            if best is None or rank[:2] > best[:2] {
                best = rank;
            }
        }
    }
    if best is None {
        return _BLOCKED;
    }
    _: any;
    (_, _, prefix, suffix, key) = best as any;
    stem: any = subpath[len(prefix):len(subpath) - len(suffix)];
    return [t.replace("*", stem) for t in _flatten_targets(exports[key])] or _BLOCKED;
}

def _flatten_targets(value: Any, depth: int = 0) -> list[str] {
    if depth > _MAX_EXPORTS_DEPTH {
        return [];
    }
    if isinstance(value, `str) {
        return [value];
    }
    if isinstance(value, `list) {
        return [t for item in value for t in _flatten_targets(item, depth + 1)];
    }
    if isinstance(value, `dict) {
        rank: any = {name: i for (i, name) in enumerate(_CONDITION_ORDER)};
        ordered: any = sorted(value, key=lambda (k) -> any { rank.get(k, len(rank)) });
        return [t for k in ordered for t in _flatten_targets(value[k], depth + 1)];
    }
    return [];
}

def _target_candidates(base: Path, target: str, subpath: str) -> list[Path] {
    normalised: any = target.replace("\\", "/");
    if normalised.startswith("/") or ":" in normalised {
        return [];
    }
    parts: any = [p for p in PurePosixPath(normalised).parts if p not in ("", ".")];
    if not parts or ".." in parts {
        return [];
    }

    candidates: list[Path] = [];
    written: any = base.joinpath(*parts);
    if len(parts) > 1 and parts[0] in _BUILD_OUTPUT_DIRS {
        names: any = _source_names(parts[-1]);
        if names == [parts[-1]] and PurePosixPath(parts[-1]).suffix {
            candidates.append(written);
        }
        middle: any = parts[1:-1];
        for name in names {
            kept: any = base.joinpath("src", *middle, name);
            if middle and middle[0] in _FORMAT_DIRS {
                stripped: any = base.joinpath("src", *middle[1:], name);
                if middle[0] in subpath.split("/") {
                    candidates.extend([kept, stripped]);
                } else {
                    candidates.extend([stripped, kept]);
                }
            } else {
                candidates.append(kept);
            }
        }
    }
    candidates.append(written);
    return candidates;
}

def _source_names(name: str) -> list[str] {
    for suffix in _COMPILED_SUFFIXES {
        if name.endswith(suffix) and len(name) > len(suffix) {
            stem: any = name[:-len(suffix)];
            native: any = _NATIVE_SOURCE_SUFFIXES.get(suffix);
            return [stem + native, stem] if native else [stem];
        }
    }
    return [name];
}
