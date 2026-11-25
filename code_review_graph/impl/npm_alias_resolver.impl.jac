impl NpmAliasResolver.init(
    repo_root: Optional[Path] = None,
    *,
    package_resolver: Optional[WorkspaceResolver] = None,
    path_is_indexed: Optional[Callable[[Path], bool]] = None,
) {
    self._repo_root = Path(repo_root).resolve() if repo_root is not None else None;
    self._package_resolver = package_resolver or WorkspaceResolver(self._repo_root);
    self._path_is_indexed = path_is_indexed;
    self._manifest_cache = {};
    self._alias_cache = {};
    self._package_roots = None;
}

impl NpmAliasResolver.governs(import_str: str, file_path: str) -> bool {
    if not import_str or import_str.startswith(".") {
        return False;
    }
    return self._longest_matching_alias(import_str, self._aliases_for_file(file_path)) is not None;
}

impl NpmAliasResolver.resolve_alias(import_str: str, file_path: str) -> Optional[str] {
    if not import_str or import_str.startswith(".") {
        return None;
    }

    aliases: any = self._aliases_for_file(file_path);
    matching_alias: any = self._longest_matching_alias(import_str, aliases);
    if matching_alias is None {
        return None;
    }

    parsed: any = _parse_alias_spec(aliases[matching_alias]);
    if parsed is None {
        return None;
    }
    real_name: any;
    version_range: any;
    (real_name, version_range) = parsed as any;

    package_roots: any = self._local_package_roots();
    candidates: any = package_roots.get(real_name, []);
    if len(candidates) != 1 {
        return None;
    }

    package_root: any = candidates[0];
    manifest: any = self._read_manifest(package_root / "package.json");
    if manifest is None {
        return None;
    }
    if not version_satisfies(manifest.get("version"), version_range) {
        return None;
    }
    subpath: any = import_str[len(matching_alias) + 1:];
    if not _safe_subpath(subpath) {
        return None;
    }

    resolved: any = self._package_resolver.resolve_in_package(
        package_root, manifest, "./" + subpath if subpath else "."
    );
    if resolved is None {
        return None;
    }
    found: any = Path(resolved);

    try {
        package_root_resolved: any = package_root.resolve();
        found_resolved: any = found.resolve();
        if package_root_resolved not in found_resolved.parents {
            return None;
        }
    } except (OSError, ValueError, RuntimeError) {
        return None;
    }
    return found_resolved.as_posix();
}

impl NpmAliasResolver._aliases_for_file(file_path: str) -> dict[str, str] {
    try {
        start: any = Path(file_path).parent.resolve();
    } except (OSError, ValueError, RuntimeError) {
        return {};
    }

    cache_key: any = start;
    if cache_key in self._alias_cache {
        return self._alias_cache[cache_key];
    }

    declared: dict[str, str] = {};
    current: any = start;
    while True {
        manifest_path: any = current / "package.json";
        manifest: any = self._read_manifest(manifest_path);
        if manifest is None and manifest_path.is_file() {
            break;
        }
        if manifest is not None {
            for section_name in _DEPENDENCY_SECTIONS {
                section: any = manifest.get(section_name);
                if not isinstance(section, `dict) {
                    continue;
                }
                for (alias, specification) in section.items() {
                    if not isinstance(alias, `str) or not isinstance(specification, `str) {
                        continue;
                    }
                    declared.setdefault(alias, specification.strip());
                }
            }
        }

        if self._repo_root is not None and current == self._repo_root {
            break;
        }
        parent: any = current.parent;
        if parent == current {
            break;
        }
        current = parent;
    }

    aliases: any = {
        alias: specification
        for (alias, specification) in declared.items()
        if specification.startswith("npm:")
    };
    self._alias_cache[cache_key] = aliases;
    return aliases;
}

impl NpmAliasResolver._local_package_roots -> dict[str, list[Path]] {
    name: any;
    if self._package_roots is not None {
        return self._package_roots;
    }

    roots: dict[str, list[Path]] = {};
    scan_root: any = self._repo_root;
    if scan_root is None {
        self._package_roots = roots;
        return roots;
    }

    for (directory, directory_names, file_names) in os.walk(
        scan_root, topdown=True, followlinks=False
    ) {
        directory_names[:] = [
            name
            for name in directory_names
            if name not in _SKIPPED_DIRECTORIES and not name.startswith(".")
        ];
        if "package.json" not in file_names {
            continue;
        }
        current: any = Path(directory);
        if self._path_is_indexed is not None
            and not self._path_is_indexed(current / "package.json")
        {
            continue;
        }
        manifest: any = self._read_manifest(current / "package.json");
        name = manifest.get("name") if manifest is not None else None;
        if not isinstance(name, `str) or not name {
            continue;
        }
        package_names: any = roots.setdefault(name, []);
        if current not in package_names {
            package_names.append(current);
        }
    }

    self._package_roots = roots;
    return roots;
}

impl NpmAliasResolver._read_manifest(path: Path) -> Optional[dict] {
    try {
        canonical: any = path.resolve();
    } except (OSError, ValueError, RuntimeError) {
        return None;
    }
    if canonical in self._manifest_cache {
        return self._manifest_cache[canonical];
    }

    manifest: Optional[dict] = None;
    try {
        if path.is_file() and path.stat().st_size <= 1048576 {
            data: any = json.loads(path.read_text(encoding="utf-8-sig"));
            if isinstance(data, `dict) {
                manifest = data;
            }
        }
    } except (OSError, UnicodeError, json.JSONDecodeError, RuntimeError) {
        manifest = None;
    }

    self._manifest_cache[canonical] = manifest;
    return manifest;
}

impl NpmAliasResolver._longest_matching_alias(
    import_str: str, aliases: dict[str, str]
) -> Optional[str] {
    matches: any = [
        alias
        for alias in aliases
        if import_str == alias or import_str.startswith(alias + "/")
    ];
    if not matches {
        return None;
    }
    return max(matches, key=builtins.len);
}

impl NpmAliasResolver.__repr__ -> str {
    return (getattr(builtins.object, "__repr__") as any)(self);
}

impl NpmAliasResolver.__eq__(other: any) -> bool {
    return self is other;
}

impl NpmAliasResolver.__hash__ -> int {
    return id(self);
}

impl _parse_alias_spec(specification: str) -> Optional[tuple[str, str]] {
    value: any = specification[4:].strip();
    version_separator: any = value.find("@", 1) if value.startswith("@") else value.find("@");
    if version_separator < 0 {
        name: any;
        version_range: any;
        (name, version_range) = (value, "");
    } else {
        (name, version_range) = (value[:version_separator], value[version_separator + 1:]);
    }
    if not _PACKAGE_NAME.match(name) {
        return None;
    }
    return (name, version_range.strip());
}

impl version_satisfies(version: object, version_range: str) -> bool {
    if version_range in _TAG_RANGES {
        return True;
    }
    if not isinstance(version, `str) {
        return version is None and version_range in _STAR_RANGES;
    }
    parsed: any = _parse_version(version.strip());
    if parsed is None {
        return False;
    }
    for comparator_set in version_range.split("||") {
        comparators: any = _parse_comparator_set(comparator_set);
        if comparators is not None and _set_matches(parsed, comparators) {
            return True;
        }
    }
    return False;
}

impl _parse_version(text: str) -> Optional[_Version] {
    `match: any = _FULL_VERSION.match(text);
    if `match is None {
        return None;
    }
    prerelease: any = `tuple(`match.group(4).split(".")) if `match.group(4) else ();
    return (`int(`match.group(1)), `int(`match.group(2)), `int(`match.group(3)), prerelease);
}

impl _version_key(version: _Version) -> tuple {
    major: any;
    minor: any;
    patch: any;
    prerelease: any;
    (major, minor, patch, prerelease) = version as any;
    if not prerelease {
        return (major, minor, patch, (1,));
    }
    identifiers: any = `tuple(
        (0, `int(part), "") if part.isdigit() else (1, 0, part) for part in prerelease
    );
    return (major, minor, patch, (0, identifiers));
}

impl _parse_comparator_set(text: str) -> Optional[list[_Comparator]] {
    text = re.sub("(<=|>=|<|>|=|~>|~|\\^)\\s+", "\\1", text.strip());
    if not text {
        return [];
    }
    hyphen: any = _HYPHEN.match(text);
    if hyphen is not None {
        return _hyphen_comparators(hyphen.group(1), hyphen.group(2));
    }
    comparators: list[_Comparator] = [];
    for token in text.split() {
        parsed: any = _token_comparators(token);
        if parsed is None {
            return None;
        }
        comparators.extend(parsed);
    }
    return comparators;
}

impl _partial(text: str) -> Optional[tuple[Optional[int], Optional[int], Optional[int], tuple]] {
    `match: any = _PARTIAL_VERSION.match(text);
    if `match is None {
        return None;
    }
    numbers: list[Optional[int]] = [];
    for group in `match.groups()[:3] {
        numbers.append(None if group is None or group in "xX*" else `int(group));
    }
    for index in range(1, 3) {
        if numbers[index - 1] is None {
            numbers[index] = None;
        }
    }
    prerelease: any = `tuple(`match.group(4).split(".")) if `match.group(4) else ();
    return (numbers[0], numbers[1], numbers[2], prerelease);
}

impl _token_comparators(token: str) -> Optional[list[_Comparator]] {
    `match: any = _OPERATOR.match(token);
    if `match is None {
        return None;
    }
    operator: any = `match.group(1) or "=";
    partial: any = _partial(`match.group(2));
    if partial is None {
        return None;
    }
    major: any;
    minor: any;
    patch: any;
    prerelease: any;
    (major, minor, patch, prerelease) = partial as any;
    nothing: list[_Comparator] = [("<", (0, 0, 0, _LOWEST_PRERELEASE))];

    if major is None {
        return nothing if operator in ("<", ">") else [];
    }
    if operator == "^" {
        low: any = (major, minor or 0, patch or 0, prerelease);
        if major > 0 or minor is None {
            high: any = (major + 1, 0, 0, _LOWEST_PRERELEASE);
        } elif minor > 0 or patch is None {
            high = (0, minor + 1, 0, _LOWEST_PRERELEASE);
        } else {
            high = (0, 0, patch + 1, _LOWEST_PRERELEASE);
        }
        return [(">=", low), ("<", high)];
    }
    if operator in ("~", "~>") or operator == "=" and patch is None {
        low = (major, minor or 0, patch or 0, prerelease);
        if minor is None {
            high = (major + 1, 0, 0, _LOWEST_PRERELEASE);
        } else {
            high = (major, minor + 1, 0, _LOWEST_PRERELEASE);
        }
        return [(">=", low), ("<", high)];
    }
    if operator == "=" {
        return [("=", (major, minor or 0, patch or 0, prerelease))];
    }
    if minor is None or patch is None {
        if operator == ">" {
            bump: any = (major + 1, 0, 0, ()) if minor is None else (major, minor + 1, 0, ());
            return [(">=", bump)];
        }
        if operator == ">=" {
            return [(">=", (major, minor or 0, 0, ()))];
        }
        if operator == "<" {
            return [("<", (major, minor or 0, 0, _LOWEST_PRERELEASE))];
        }
        bump = (major + 1, 0, 0, ()) if minor is None else (major, minor + 1, 0, ());
        return [("<", bump[:3] + (_LOWEST_PRERELEASE,))];
    }
    return [(operator, (major, minor, patch, prerelease))];
}

impl _hyphen_comparators(low_text: str, high_text: str) -> Optional[list[_Comparator]] {
    low: any = _partial(low_text);
    high: any = _partial(high_text);
    if low is None or high is None {
        return None;
    }
    comparators: list[_Comparator] = [];
    if low[0] is not None {
        comparators.append((">=", (low[0], low[1] or 0, low[2] or 0, low[3])));
    }
    major: any;
    minor: any;
    patch: any;
    prerelease: any;
    (major, minor, patch, prerelease) = high as any;
    if major is None {
        return comparators;
    }
    if minor is None {
        comparators.append(("<", (major + 1, 0, 0, _LOWEST_PRERELEASE)));
    } elif patch is None {
        comparators.append(("<", (major, minor + 1, 0, _LOWEST_PRERELEASE)));
    } else {
        comparators.append(("<=", (major, minor, patch, prerelease)));
    }
    return comparators;
}

impl _set_matches(version: _Version, comparators: list[_Comparator]) -> bool {
    key: any = _version_key(version);
    for (operator, bound) in comparators {
        other: any = _version_key(bound);
        if operator == "=" and key != other {
            return False;
        }
        if operator == "<" and not key < other {
            return False;
        }
        if operator == "<=" and not key <= other {
            return False;
        }
        if operator == ">" and not key > other {
            return False;
        }
        if operator == ">=" and not key >= other {
            return False;
        }
    }
    if version[3] {
        return `any(bound[3] and bound[:3] == version[:3] for (_operator, bound) in comparators);
    }
    return True;
}

impl _safe_subpath(subpath: str) -> bool {
    if not subpath {
        return True;
    }
    if "\\" in subpath or ":" in subpath or `any(operator.lt(ord(char), 32) for char in subpath) {
        return False;
    }
    return all(part not in ("", ".", "..") for part in subpath.split("/"));
}
