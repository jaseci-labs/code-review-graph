impl _import_segments(target: str) -> list[str] {
    normalized: any = target;
    for sep in _IMPORT_SEGMENT_SEPARATORS[1:] {
        normalized = normalized.replace(sep, "::");
    }
    return [seg for seg in normalized.split("::") if seg];
}

impl _fold(name: str, language: str) -> str {
    return name.casefold() if language == "php" else name;
}

impl _path_tokens(file_path: str) -> list[str] {
    parts: any = [p for p in file_path.replace("\\", "/").split("/") if p];
    if parts {
        parts[-1] = parts[-1].rsplit(".", 1)[0];
    }
    return parts;
}

impl _path_key(file_path: str) -> str {
    return file_path.replace("\\", "/");
}

impl _path_ends_with(path_tokens: list[str], suffix: list[str], language: str) -> bool {
    if not suffix or len(suffix) > len(path_tokens) {
        return False;
    }
    path_tail: any = path_tokens[-len(suffix):];
    return all(
        operator.eq(_fold(left, language), _fold(right, language))
        for (left, right) in zip(path_tail, suffix),
    );
}

impl _safe_import_suffixes(segments: list[str], language: str) -> list[list[str]] {
    if language == "php" {
        suffixes: any = [segments];
        if len(segments) > 2 {
            suffixes.append(segments[1:]);
        }
        return [suffix for suffix in suffixes if len(suffix) >= 2];
    }

    if language == "rust" and len(segments) >= 2 {
        module_path: any = segments[:-1];
        suffixes = [module_path];
        if module_path and module_path[0] in {"crate", "self", "super"} {
            suffixes.append(module_path[1:]);
        }
        return [suffix for suffix in suffixes if suffix];
    }

    return [];
}

impl _is_unresolved_scoped_target(target: str) -> bool {
    if "::" not in target {
        return False;
    }
    head: any = target.split("::", 1)[0];
    if "/" in head {
        return False;
    }
    tail: any = target.rsplit("::", 1)[1];
    if "." in tail {
        return False;
    }
    return True;
}

impl _enclosing_class(source_qualified: str) -> Optional[str] {
    if "::" not in source_qualified {
        return None;
    }
    tail: any = source_qualified.split("::", 1)[1];
    if "." not in tail {
        return None;
    }
    return tail.rsplit(".", 1)[0];
}

impl _scope_and_method(target: str, language: str) -> Optional[tuple[Optional[str], str, bool]] {
    if language == "php" {
        scope: any;
        _: any;
        method: any;
        (scope, _, method) = target.partition("::") as any;
        if not scope or not method or "::" in method {
            return None;
        }
        lowered: any = scope.strip("\\").casefold();
        if lowered in _PHP_SELF_SCOPES {
            return (None, method, True);
        }
        if lowered == "parent" {
            return None;
        }
        class_name: any = scope.strip("\\").rsplit("\\", 1)[-1];
        if not class_name {
            return None;
        }
        return (class_name, method, False);
    }

    if language == "rust" {
        segments: any = target.split("::");
        if len(segments) != 2 {
            return None;
        }
        (scope, method) = segments as any;
        if not scope or not method {
            return None;
        }
        if scope == "Self" {
            return (None, method, True);
        }
        if scope == "self" {
            return None;
        }
        return (scope, method, False);
    }

    return None;
}

impl resolve_scoped_calls(store: GraphStore, repo_root: Path | None = None) -> dict {
    file_of: dict[str, str];
    row: any;
    imports_by_file: dict[str, set[str]];
    php_namespaces: dict[str, set[str]];
    csharp_stats: any = resolve_csharp_calls(store, repo_root);
    conn: any = store._conn;

    lang_placeholders: any = ",".join("?" for _ in _SCOPED_LANGUAGES);
    file_language: dict[str, str] = {
        row["file_path"]: row["language"]
        for row in conn.execute(
            f"SELECT DISTINCT file_path, language FROM nodes WHERE language IN ({lang_placeholders})",
            _SCOPED_LANGUAGES,
        ).fetchall()
    };
    if not file_language {
        return csharp_stats;
    }
    method_map: dict[tuple[str, str, str], list[str]] = {};
    file_of = {};
    kind_placeholders: any = ",".join("?" for _ in _METHOD_KINDS);
    for row in conn.execute(
        f"SELECT name, parent_name, qualified_name, file_path, language FROM nodes WHERE kind IN ({kind_placeholders}) AND language IN ({lang_placeholders}) AND parent_name IS NOT NULL",
        (*_METHOD_KINDS, *_SCOPED_LANGUAGES),
    ).fetchall() {
        lang: any = row["language"];
        key: any = (lang, _fold(row["parent_name"], lang), _fold(row["name"], lang));
        method_map.setdefault(key, []).append(row["qualified_name"]);
        file_of[row["qualified_name"]] = row["file_path"];
    }

    if not method_map {
        return {
            "files_indexed": len(file_language) + csharp_stats["files_indexed"],
            "calls_resolved": csharp_stats["calls_resolved"],
        };
    }
    imports_by_file = {};
    scoped_file_list: any = sorted(file_language.keys());
    start: any;
    for start in range(0, len(scoped_file_list), 450) {
        batch: any = scoped_file_list[start:start + 450];
        placeholders: any = ",".join("?" for _ in batch);
        for row in conn.execute(
            f"SELECT file_path, target_qualified FROM edges WHERE kind = 'IMPORTS_FROM' AND file_path IN ({placeholders})",
            batch,
        ).fetchall() {
            imports_by_file.setdefault(row["file_path"], set[any]()).add(row["target_qualified"]);
        }
    }

    def disambiguate(
        candidates: list[str], caller_file: str, class_name: str, language: str
    ) -> Optional[str] {
        candidate: any;
        tokens: any;
        target: any;
        imported: any = imports_by_file.get(caller_file, set[any]());
        if not imported {
            return None;
        }
        imported_paths: any = {
            _path_key(target)
            for target in imported
            if "/" in target or "\\" in target
        };
        matched: any = [
            candidate
            for candidate in candidates
            if _path_key(file_of.get(candidate, "")) in imported_paths
        ];
        if len(matched) == 1 {
            return matched[0];
        }
        matched_by_suffix: set[str] = set[any]();
        for candidate in candidates {
            tokens = _path_tokens(file_of.get(candidate, ""));
            for target in imported {
                segments: any = _import_segments(target);
                if not segments {
                    continue;
                }
                if _fold(segments[-1], language) != _fold(class_name, language) {
                    continue;
                }
                suffixes: any = _safe_import_suffixes(segments, language);
                if `any(_path_ends_with(tokens, suffix, language) for suffix in suffixes) {
                    matched_by_suffix.add(candidate);
                    break;
                }
            }
        }
        if len(matched_by_suffix) == 1 {
            return next(iter(matched_by_suffix));
        }
        return None;
    }
    php_namespaces = {};
    for row in conn.execute(
        "SELECT file_path, extra FROM nodes WHERE kind = 'File' AND language = 'php'"
    ).fetchall() {
        try {
            file_extra: any = json.loads(row["extra"] or "{}");
        } except (json.JSONDecodeError, TypeError) {
            file_extra = {};
        }
        declared: any = file_extra.get("php_namespaces") if isinstance(file_extra, `dict) else None;
        if isinstance(declared, `list) {
            php_namespaces[row["file_path"]] = {
                name.casefold()
                for name in declared
                if isinstance(name, `str)
            };
        }
    }

    """Is the class the scope names in the candidate's namespace?"""
    def php_namespace_backs(candidate_file: str, caller_file: str, scope: str) -> bool {
        theirs: any;
        written: any;
        theirs = php_namespaces.get(candidate_file, set[any]());
        ours: any = php_namespaces.get(caller_file, set[any]());
        written = scope.strip("\\").rpartition("\\")[0].casefold();
        if not written {
            return `bool(theirs & ours) or not theirs and not ours;
        }
        if scope.startswith("\\") {
            return written in theirs;
        }
        return written in theirs or `any(f"{ns}\\{written}" in theirs for ns in ours);
    }

    """Does the caller's file say *candidate* is the class it means?

        Being the one match in the whole graph is no evidence on its own: a
        vendor class or another crate's type of the same name may be meant.
        """
    def backed(
        candidate: str, caller_file: str, class_name: str, scope: str, language: str
    ) -> bool {
        candidate_file: any = file_of.get(candidate, "");
        if candidate_file == caller_file {
            return True;
        }
        if disambiguate([candidate], caller_file, class_name, language) is not None {
            return True;
        }
        folded: any = _fold(class_name, language);
        for target in imports_by_file.get(caller_file, ()) {
            segments: any = _import_segments(target);
            if segments and _fold(segments[-1], language) == folded {
                return True;
            }
        }
        if language == "php" {
            return php_namespace_backs(candidate_file, caller_file, scope);
        }
        return False;
    }

    calls_rows: any = [];
    for start in range(0, len(scoped_file_list), 450) {
        batch = scoped_file_list[start:start + 450];
        placeholders = ",".join("?" for _ in batch);
        calls_rows.extend(
            conn.execute(
                f"SELECT id, source_qualified, target_qualified, extra, file_path, line FROM edges WHERE kind = 'CALLS' AND file_path IN ({placeholders})",
                batch,
            ).fetchall(),
        );
    }

    resolved: any = 0;
    for row in calls_rows {
        language: any = file_language.get(row["file_path"]);
        if language is None {
            continue;
        }
        target: any = row["target_qualified"];
        try {
            extra: any = json.loads(row["extra"] or "{}");
        } except (json.JSONDecodeError, TypeError) {
            extra = {};
        }
        if not isinstance(extra, `dict) {
            extra = {};
        }

        resolution_target: any = target;
        receiver_scope: any = extra.get("receiver_scope");
        if language in _RECEIVER_SCOPE_LANGUAGES
            and "::" not in target
            and isinstance(receiver_scope, `str)
            and receiver_scope
        {
            resolution_target = f"{receiver_scope}::{target}";
        } elif not _is_unresolved_scoped_target(target) {
            continue;
        }

        parsed: any = _scope_and_method(resolution_target, language);
        if parsed is None {
            continue;
        }
        class_name: any;
        method: any;
        needs_enclosing: any;
        (class_name, method, needs_enclosing) = parsed as any;

        if needs_enclosing {
            enclosing: any = _enclosing_class(row["source_qualified"]);
            if not enclosing {
                continue;
            }
            class_name = enclosing;
        }
        assert class_name is not None;

        candidates: any = method_map.get((
            language,
            _fold(class_name, language),
            _fold(method, language),
        ));
        if not candidates {
            continue;
        }

        if len(candidates) == 1 {
            new_target: any = candidates[0];
            via: any = "single_match";
            if not needs_enclosing
                and not backed(
                    new_target,
                    row["file_path"],
                    class_name,
                    resolution_target.partition("::")[0],
                    language,
                )
            {
                continue;
            }
        } else {
            new_target = disambiguate(candidates, row["file_path"], class_name, language);
            if new_target is None {
                continue;
            }
            via = "import";
        }

        extra["scoped_resolved"] = True;
        extra["scoped_via"] = via;
        serialized_extra: any = json.dumps(extra);

        conn.execute(
            "UPDATE edges SET target_qualified = ?, extra = ?, confidence_tier = 'INFERRED' WHERE id = ?",
            (new_target, serialized_extra, row["id"]),
        );
        conn.execute(
            "UPDATE edges SET source_qualified = ?, extra = ?, confidence_tier = 'INFERRED' WHERE kind = 'TESTED_BY' AND source_qualified = ? AND target_qualified = ? AND file_path = ? AND line = ?",
            (
                new_target,
                serialized_extra,
                target,
                row["source_qualified"],
                row["file_path"],
                row["line"],
            ),
        );
        resolved += 1;
        logger.debug("Scoped resolver: %s → %s (via %s)", resolution_target, new_target, via);
    }

    if resolved {
        store.commit();
    }

    logger.info(
        "Scoped resolver: resolved %d CALLS edges across %d files", resolved, len(file_language)
    );
    return {
        "files_indexed": len(file_language) + csharp_stats["files_indexed"],
        "calls_resolved": resolved + csharp_stats["calls_resolved"],
    };
}
