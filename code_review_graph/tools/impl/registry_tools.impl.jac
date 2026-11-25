impl list_repos_func -> dict[str, Any] {
    import from ..registry { Registry }

    try {
        registry: any = Registry();
        repos: any = registry.list_repos();
        return {
            "status": "ok",
            "summary": f"{len(repos)} registered repository(ies)",
            "repos": repos,
        };
    } except Exception as exc {
        return {"status": "error", "error": `str(exc)};
    }
}

impl _select_repos(
    repos: list[dict[str, Any]], names: list[str]
) -> tuple[list[dict[str, Any]], list[str], list[str]] {
    by_alias: dict[str, list[int]] = {};
    by_folder: dict[str, list[int]] = {};
    for (index, `entry) in enumerate(repos) {
        folder: any = Path(`entry["path"]).name;
        alias: any = `entry.get("alias");
        if alias {
            by_alias.setdefault(alias, []).append(index);
        }
        by_folder.setdefault(folder, []).append(index);
    }

    wanted: set[int] = set[any]();
    unknown: list[str] = [];
    ambiguous: list[str] = [];
    for name in names {
        matches: any = by_alias.get(name) or by_folder.get(name);
        if not matches {
            unknown.append(name);
            continue;
        }
        wanted.update(matches);
        if len(matches) > 1 {
            ambiguous.append(name);
        }
    }

    selected: any = [`entry for (i, `entry) in enumerate(repos) if i in wanted];
    return (selected, unknown, ambiguous);
}

impl _echoed(names: list[str]) -> tuple[list[str], int, bool] {
    cleaned: any = [_sanitize_name(name) for name in names];
    return _bounded(cleaned, _MAX_ECHOED_NAMES, _MAX_ECHOED_NAMES);
}

impl cross_repo_search_func(
    query: str,
    kind: str | None = None,
    limit: int = 20,
    max_results: int = 50,
    repos: list[str] | None = None,
) -> dict[str, Any] {
    import from ..registry { Registry }

    _validate_positive_int(limit, "limit");
    _validate_positive_int(max_results, "max_results");

    try {
        registry: any = Registry();
        all_repos: any = registry.list_repos();
        if not all_repos {
            return {
                "status": "ok",
                "summary": "No repositories registered. Use 'register' to add repos.",
                "results": [],
            };
        }

        unknown: list[str] = [];
        ambiguous: list[str] = [];
        unknown_shown: list[str] = [];
        unknown_total: any = 0;
        unknown_truncated: any = False;
        ambiguous_shown: list[str] = [];
        ambiguous_total: any = 0;
        ambiguous_truncated: any = False;
        if repos {
            selected: any;
            (selected, unknown, ambiguous) = _select_repos(all_repos, repos) as any;
            (unknown_shown, unknown_total, unknown_truncated) = _echoed(unknown) as any;
            (ambiguous_shown, ambiguous_total, ambiguous_truncated) = _echoed(ambiguous) as any;
            if not selected {
                return {
                    "status": "ok",
                    "summary": f"No registered repository matches the {unknown_total} name(s) given. Use 'repos' to list the registry.",
                    "results": [],
                    "total": 0,
                    "truncated": False,
                    "repos_searched": [],
                    "unknown": unknown_shown,
                    "unknown_total": unknown_total,
                    "unknown_truncated": unknown_truncated,
                    "ambiguous": ambiguous_shown,
                    "ambiguous_total": ambiguous_total,
                    "ambiguous_truncated": ambiguous_truncated,
                };
            }
        } else {
            selected = all_repos;
        }

        ranked_results: list[tuple[int, int, dict[str, Any]]] = [];
        searched_repos: list[str] = [];

        for (repo_index, repo_entry) in enumerate(selected) {
            repo_path: any = Path(repo_entry["path"]);
            db_path: any = get_db_path(repo_path);
            if not db_path.exists() {
                continue;
            }

            try {
                store: any = GraphStore(`str(db_path));
                try {
                    results: any = hybrid_search(store, query, kind=kind, limit=limit);
                    alias: any = repo_entry.get("alias", repo_path.name);
                    for (local_rank, r) in enumerate(results) {
                        r["repo"] = alias;
                        r["repo_path"] = `str(repo_path);
                        ranked_results.append((local_rank, repo_index, r));
                    }
                    searched_repos.append(alias);
                } finally {
                    store.close();
                }
            } except Exception as exc {
                logger.warning("Search failed for %s: %s", repo_path, exc);
            }
        }
        ranked_results.sort(key=lambda (item) -> any { (item[0], item[1]) });
        all_results: any;
        total: any;
        truncated: any;
        (all_results, total, truncated) = _bounded(
            [result for (_, _, result) in ranked_results], max_results, _MAX_CROSS_REPO_RESULTS
        ) as any;
        notes: any = "";
        if unknown_total {
            notes += f"; {unknown_total} name(s) matched no repository";
        }
        if ambiguous_total {
            notes += f"; {ambiguous_total} name(s) matched several";
        }

        response: any = {
            "status": "ok",
            "summary": f"Found {total} result(s) across {len(searched_repos)} repo(s) for '{query}'"
                + _shown_of(len(all_results), total)
                + notes,
            "results": all_results,
            "total": total,
            "truncated": truncated,
            "repos_searched": searched_repos,
        };
        if repos {
            response["unknown"] = unknown_shown;
            response["unknown_total"] = unknown_total;
            response["unknown_truncated"] = unknown_truncated;
            response["ambiguous"] = ambiguous_shown;
            response["ambiguous_total"] = ambiguous_total;
            response["ambiguous_truncated"] = ambiguous_truncated;
        }
        return response;
    } except Exception as exc {
        return {"status": "error", "error": `str(exc)};
    }
}
