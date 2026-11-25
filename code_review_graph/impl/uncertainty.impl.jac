impl gap_note(language: str | None, pattern: str) -> str | None {
    if not language {
        return None;
    }
    normalized: any = language.strip().lower();
    for gap in LANGUAGE_GAPS {
        if normalized in gap.languages and pattern in gap.patterns {
            return gap.note;
        }
    }
    return None;
}

impl _clip(text: str, limit: int) -> str {
    if len(text) <= limit {
        return text;
    }
    return text[:max(1, limit - 1)] + "~";
}

impl _clean(text: str) -> str {
    cleaned: any = _sanitize_name(text, max_len=MAX_CONFIDENCE_CHARS);
    return _WHITESPACE.sub(" ", cleaned).strip();
}

impl _fragment(text: str, limit: int) -> str {
    return _clip(_clean(text), max(1, limit));
}

impl _bounded(note: str) -> str {
    return _fragment(note, MAX_CONFIDENCE_CHARS);
}

impl _interpolated(prefix: str, value: str, suffix: str) -> str {
    budget: any = MAX_CONFIDENCE_CHARS - len(prefix) - len(suffix);
    return f"{prefix}{_fragment(value, budget)}{suffix}";
}

impl _target_fragment(target: str, limit: int) -> str {
    cleaned: any = _clean(target);
    if len(cleaned) <= limit {
        return cleaned;
    }
    if "::" in target {
        symbol: any = _clean(target.rsplit("::", 1)[-1]);
        if 0 < len(symbol) <= limit {
            return symbol;
        }
    }
    return _clip(cleaned, max(1, limit));
}

impl _interpolated_target(prefix: str, target: str, suffix: str) -> str {
    budget: any = MAX_CONFIDENCE_CHARS - len(prefix) - len(suffix);
    return f"{prefix}{_target_fragment(target, budget)}{suffix}";
}

impl not_indexed_note(target: str) -> str {
    return _interpolated_target(
        "target not indexed: no node matching '",
        target,
        "', so this 0 is not evidence that none exist",
    );
}

impl unresolved_stale_note(target: str) -> str {
    return _interpolated_target(
        "graph is stale: no node matching '",
        target,
        "'; the graph predates HEAD, so run `code-review-graph update` first",
    );
}

impl _confirmed_note(target: str, current: bool) -> str {
    if current {
        return _interpolated_target(
            "'", target, "' is indexed and the graph is current, so this 0 is a real absence"
        );
    }
    return _interpolated_target(
        "'", target, "' is indexed and no such edge is recorded; graph currency unverified"
    );
}

impl _live_git_head(`root: Path) -> str | None {
    _read_live_git_head = lazy("tools._common", "_read_live_git_head");

    return _read_live_git_head(`root);
}

impl _untracked_sources(`root: Path, store: GraphStore) -> int | None {
    try {
        result: any = subprocess.run(
            ["git", "ls-files", "--others", "--exclude-standard", "-z", "--", "."],
            capture_output=True,
            cwd=`str(`root),
            timeout=GIT_TIMEOUT,
            stdin=subprocess.DEVNULL,
        );
    } except (OSError, subprocess.SubprocessError) {
        return None;
    }
    if result.returncode != 0 {
        return None;
    }
    candidates: any = [os.fsdecode(record) for record in result.stdout.split(b"\x00") if record];
    if not candidates {
        return 0;
    }
    indexed_files: any = {normalize_file_path(`root / stored) for stored in store.get_all_files()};
    indexed_suffixes: any = {
        suffix
        for suffix in (Path(stored).suffix.lower() for stored in indexed_files)
        if suffix
    };
    if not indexed_suffixes {
        return 0;
    }
    ignore_patterns: any = _load_ignore_patterns(`root);
    return sum(
        1
        for relative in candidates
        if Path(relative).suffix.lower() in indexed_suffixes
            and normalize_file_path(`root / relative) not in indexed_files
            and not _should_ignore(relative, ignore_patterns),
    );
}

impl _is_untracked_note(note: str) -> bool {
    return "untracked by git" in note;
}

impl _untracked_note(count: int) -> str {
    return _interpolated(
        "",
        `str(count),
        " source file(s) untracked by git, absent from the index, so this 0 may be short; `git add` them, then `code-review-graph update`",
    );
}

impl _settled(`root: Path, store: GraphStore, verified: bool) -> tuple[str | None, bool] {
    untracked: any = _untracked_sources(`root, store);
    if untracked is None {
        return (None, False);
    }
    if untracked {
        return (_untracked_note(untracked), False);
    }
    return (None, verified);
}

impl _staleness(store: GraphStore, `root: Path, file_path: str | None) -> tuple[str | None, bool] {
    stored_sha: any = store.get_metadata("git_head_sha");
    live_sha: any = _live_git_head(`root) if stored_sha else None;
    if stored_sha and live_sha and live_sha != stored_sha {
        return (
            f"graph is stale: built at an older commit than HEAD, so this 0 may be out of date; {_UPDATE_HINT}",
            False,
        );
    }
    commit_verified: any = `bool(stored_sha and live_sha);

    built_at_raw: any = store.get_metadata("last_updated");
    if not built_at_raw or not file_path {
        return _settled(`root, store, commit_verified and not file_path);
    }
    try {
        path: any = Path(file_path);
        if not path.is_absolute() {
            path = `root / path;
        }
        built_at: any = datetime.fromisoformat(built_at_raw);
        mtime: any = os.stat(path).st_mtime;
        changed_at: any = datetime.fromtimestamp(mtime, tz=built_at.tzinfo);
    } except (OSError, OverflowError, TypeError, ValueError) {
        return (None, False);
    }
    if changed_at > built_at {
        return (
            _interpolated(
                "graph is stale: ", path.name, f" changed after the last build; {_UPDATE_HINT}"
            ),
            False,
        );
    }
    return _settled(`root, store, commit_verified);
}

impl empty_query_confidence(
    store: GraphStore, `root: Path, pattern: str, target: str, `node: Any | None = None
) -> str | None {
    try {
        if `node is None {
            if store.get_stats().total_nodes == 0 {
                return _bounded(
                    "graph is empty: nothing is indexed, so this 0 says nothing about the code; run `code-review-graph build`",
                );
            }
            stale: any;
            _unused: any;
            (stale, _unused) = _staleness(store, `root, None) as any;
            if stale {
                return _bounded(
                    stale if _is_untracked_note(stale) else unresolved_stale_note(target)
                );
            }
            return _bounded(not_indexed_note(target));
        }

        current: any;
        (stale, current) = _staleness(store, `root, getattr(`node, "file_path", None)) as any;
        if stale {
            return _bounded(stale);
        }

        gap: any = gap_note(getattr(`node, "language", None), pattern);
        if gap {
            return _bounded(gap);
        }

        return _bounded(_confirmed_note(target, current));
    } except Exception {
        logger.debug("Could not compute empty-result confidence", exc_info=True);
        return None;
    }
}

impl empty_impact_confidence(
    store: GraphStore,
    `root: Path,
    changed_files: list[str],
    resolved_files: list[str],
    language: str | None = None,
) -> str | None {
    try {
        if not resolved_files {
            unknown: any = changed_files[0] if changed_files else "";
            return _bounded(not_indexed_note(Path(unknown).name if unknown else ""));
        }

        stale: any;
        current: any;
        (stale, current) = _staleness(store, `root, resolved_files[0]) as any;
        if stale {
            return _bounded(stale);
        }

        gap: any = gap_note(language, IMPACT_PATTERN);
        if gap {
            return _bounded(gap);
        }

        if current {
            return _bounded(
                "changed files are indexed and the graph is current, so this 0 is a real absence"
            );
        }
        return _bounded(
            "changed files are indexed and nothing depends on them; graph currency unverified"
        );
    } except Exception {
        logger.debug("Could not compute empty-impact confidence", exc_info=True);
        return None;
    }
}

impl guessed_calls_confidence(split: dict[str, int] | None) -> str | None {
    if not split or not split.get("unresolved") {
        return None;
    }
    total: any = split["unresolved"] + split.get("direct", 0);
    return _bounded(
        format(split["unresolved"], "")
            + " of "
            + format(total, "")
            + " call sites match by name only and may be wrong; resolution='direct' keeps the confirmed ones",
    );
}

impl empty_search_confidence(store: GraphStore, `root: Path, query: str) -> str | None {
    try {
        if store.get_stats().total_nodes == 0 {
            return _bounded(
                "graph is empty: nothing is indexed, so this 0 says nothing about the code; run `code-review-graph build`",
            );
        }

        stale: any;
        _current: any;
        (stale, _current) = _staleness(store, `root, None) as any;
        if stale {
            return _bounded(stale);
        }

        return _bounded(
            _interpolated(
                "no indexed node matches '",
                query,
                "'; search covers names, paths and signatures, not source text",
            ),
        );
    } except Exception {
        logger.debug("Could not compute empty-search confidence", exc_info=True);
        return None;
    }
}
