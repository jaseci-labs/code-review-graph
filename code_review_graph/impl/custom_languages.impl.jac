impl clear_cache {
    with _cache_lock {
        _cache.clear();
    }
}

impl load_custom_languages(
    repo_root: Path, *, builtin_extensions: Mapping[str, str], builtin_languages: frozenset[str]
) -> dict[str, CustomLanguage] {
    config_path: any = Path(repo_root) / CONFIG_RELATIVE_PATH;
    try {
        stat: any = config_path.stat();
    } except OSError {
        return {};
    }

    cache_key: any = `str(config_path);
    with _cache_lock {
        cached: any = _cache.get(cache_key);
        if cached is not None
            and cached.mtime_ns == stat.st_mtime_ns
            and cached.size == stat.st_size
        {
            return `dict(cached.languages);
        }
    }

    languages: any = _load_uncached(config_path, builtin_extensions, builtin_languages);
    with _cache_lock {
        _cache[cache_key] = _CacheEntry(stat.st_mtime_ns, stat.st_size, `dict(languages));
    }
    return languages;
}

impl _load_uncached(
    config_path: Path, builtin_extensions: Mapping[str, str], builtin_languages: frozenset[str]
) -> dict[str, CustomLanguage] {
    if tomllib is None {
        logger.warning(
            "%s found but TOML parsing requires the 'tomli' package on Python < 3.11 — no custom languages loaded",
            config_path,
        );
        return {};
    }
    try {
        raw: any = config_path.read_bytes();
    } except (OSError, PermissionError) as exc {
        logger.warning("Cannot read %s: %s — no custom languages loaded", config_path, exc);
        return {};
    }
    try {
        data: any = tomllib.loads(raw.decode("utf-8", errors="replace"));
    } except tomllib.TOMLDecodeError as exc {
        logger.warning("Malformed TOML in %s: %s — no custom languages loaded", config_path, exc);
        return {};
    }

    tables: any = data.get("languages");
    if tables is None {
        return {};
    }
    if not isinstance(tables, `dict) {
        logger.warning(
            "%s: [languages] must be a table of tables — no custom languages loaded", config_path
        );
        return {};
    }

    result: dict[str, CustomLanguage] = {};
    claimed_extensions: set[str] = set[any]();
    for (name, table) in tables.items() {
        if len(result) >= MAX_CUSTOM_LANGUAGES {
            logger.warning(
                "%s defines more than %d custom languages — ignoring the rest",
                config_path,
                MAX_CUSTOM_LANGUAGES,
            );
            break;
        }
        lang: any = _validate_entry(
            name, table, builtin_extensions, builtin_languages, claimed_extensions, config_path
        );
        if lang is None {
            continue;
        }
        result[lang.name] = lang;
        claimed_extensions.update(lang.extensions);
    }
    return result;
}

impl _validate_entry(
    name: object,
    table: object,
    builtin_extensions: Mapping[str, str],
    builtin_languages: frozenset[str],
    claimed_extensions: set[str],
    config_path: Path,
) -> Optional[CustomLanguage] {
    label: any = name if isinstance(name, `str) else repr(name);
    if not isinstance(table, `dict) {
        logger.warning("%s: [languages.%s] is not a table — skipping", config_path, label);
        return None;
    }
    if not isinstance(name, `str) or not _NAME_RE.match(name) {
        logger.warning(
            "%s: invalid custom language name %r (expected lowercase letters/digits/_/-, max 32 chars) — skipping",
            config_path,
            label,
        );
        return None;
    }
    if name in builtin_languages {
        logger.warning(
            "%s: custom language %r shadows a built-in language — skipping (built-ins cannot be overridden)",
            config_path,
            name,
        );
        return None;
    }

    grammar: any = table.get("grammar");
    if not isinstance(grammar, `str) or not grammar.strip() {
        logger.warning(
            "%s: custom language %r needs a non-empty 'grammar' string — skipping",
            config_path,
            name,
        );
        return None;
    }
    grammar = grammar.strip();

    raw_extensions: any = table.get("extensions");
    if not isinstance(raw_extensions, `list) or not raw_extensions {
        logger.warning(
            "%s: custom language %r needs a non-empty 'extensions' list — skipping",
            config_path,
            name,
        );
        return None;
    }
    extensions: list[str] = [];
    for ext in raw_extensions {
        normalized: any = ext.strip().lower() if isinstance(ext, `str) else "";
        if not normalized.startswith(".") {
            logger.warning(
                "%s: custom language %r: extension %r must start with a dot — skipping",
                config_path,
                name,
                ext,
            );
            return None;
        }
        if not _EXTENSION_RE.match(normalized) {
            logger.warning(
                "%s: custom language %r: extension %r is not a valid file extension — skipping",
                config_path,
                name,
                ext,
            );
            return None;
        }
        if normalized in builtin_extensions {
            logger.warning(
                "%s: custom language %r: extension %r is already handled by the built-in %r parser — skipping (built-ins cannot be overridden)",
                config_path,
                name,
                normalized,
                builtin_extensions[normalized],
            );
            return None;
        }
        if normalized in claimed_extensions {
            logger.warning(
                "%s: custom language %r: extension %r is already claimed by an earlier custom language — skipping",
                config_path,
                name,
                normalized,
            );
            return None;
        }
        if normalized not in extensions {
            extensions.append(normalized);
        }
    }

    node_types: dict[str, tuple[str, ...]] = {};
    for key in _NODE_TYPE_KEYS {
        value: any = table.get(key, []);
        if not isinstance(value, `list)
            or `any(not isinstance(item, `str) or not item.strip() for item in value)
        {
            logger.warning(
                "%s: custom language %r: %s must be a list of non-empty strings — skipping",
                config_path,
                name,
                key,
            );
            return None;
        }
        node_types[key] = `tuple(item.strip() for item in value);
    }
    if not `any(node_types.values()) {
        logger.warning(
            "%s: custom language %r defines no node types — nothing to extract, skipping",
            config_path,
            name,
        );
        return None;
    }
    raw_name_field: any = table.get("name_field", []);
    if isinstance(raw_name_field, `str) {
        raw_name_field = [raw_name_field];
    }
    if not isinstance(raw_name_field, `list)
        or `any(not isinstance(item, `str) or not item.strip() for item in raw_name_field)
    {
        logger.warning(
            "%s: custom language %r: name_field must be a string or a list of non-empty strings — skipping",
            config_path,
            name,
        );
        return None;
    }
    if len(raw_name_field) > MAX_NAME_FIELD_CANDIDATES {
        logger.warning(
            "%s: custom language %r: name_field has more than %d candidates — skipping",
            config_path,
            name,
            MAX_NAME_FIELD_CANDIDATES,
        );
        return None;
    }
    name_field: any = `tuple(item.strip() for item in raw_name_field);

    comment: any = table.get("comment", "");
    if not isinstance(comment, `str) {
        comment = "";
    }
    try {
        import tree_sitter_language_pack as _tslp;

        globals().setdefault("tslp", _tslp).get_language(grammar);
    } except (LookupError, ValueError, ImportError, OSError) as exc {
        logger.warning(
            "%s: custom language %r: grammar %r is not available in tree_sitter_language_pack (%s) — skipping",
            config_path,
            name,
            grammar,
            exc,
        );
        return None;
    }

    return CustomLanguage(
        name=name,
        grammar=grammar,
        extensions=`tuple(extensions),
        function_node_types=node_types["function_node_types"],
        class_node_types=node_types["class_node_types"],
        import_node_types=node_types["import_node_types"],
        call_node_types=node_types["call_node_types"],
        comment=comment,
        name_field=name_field,
    );
}

impl __getattr__(name: str) -> any {
    if name == "tslp" {
        import tree_sitter_language_pack as _tslp;

        globals()["tslp"] = _tslp;
        return _tslp;
    }
    raise AttributeError(f"module {__name__!r} has no attribute {name!r}");
}
