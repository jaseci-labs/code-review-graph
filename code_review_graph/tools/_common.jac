import from __future__ { annotations }

import importlib, operator, logging, sqlite3, subprocess;

import from datetime { datetime }

import from pathlib { Path }

import from typing { Any }

glob _PROVENANCE_READ_TIMEOUT_SECONDS: any = 0.05;

glob _PROVENANCE_GIT_TIMEOUT_SECONDS: any = 1.0;

glob logger: any = logging.getLogger(__name__);

def _error_response(message: str, status: str = "error", **extra: Any) -> dict[str, Any] {
    return {"status": status, "error": message, "summary": message, **extra};
}

def _read_live_git_head(`root: Path) -> str | None {
    if not (`root / ".git").exists() {
        return None;
    }
    try {
        result: any = subprocess.run(
            ["git", "rev-parse", "--verify", "HEAD"],
            capture_output=True,
            text=True,
            encoding="utf-8",
            errors="replace",
            cwd=`str(`root),
            timeout=_PROVENANCE_GIT_TIMEOUT_SECONDS,
            stdin=subprocess.DEVNULL,
            check=False,
        );
    } except (FileNotFoundError, OSError, subprocess.TimeoutExpired) {
        logger.debug("Could not read live Git HEAD for graph provenance", exc_info=True);
        return None;
    }
    if result.returncode != 0 {
        logger.debug("git rev-parse failed while reading graph provenance");
        return None;
    }
    head_sha: any = result.stdout.strip();
    return head_sha or None;
}

def graph_provenance(repo_root: str | None = None) -> dict[str, Any] | None {
    try {
        `root: any = _resolve_root(repo_root);
        db_path: any = get_db_path(`root, read_only=True);
        if not db_path.exists() {
            return None;
        }
        database_uri: any = f"{db_path.resolve().as_uri()}?mode=ro";
        connection: any = sqlite3.connect(
            database_uri, uri=True, timeout=_PROVENANCE_READ_TIMEOUT_SECONDS
        );
        try {
            rows: any = `dict(
                connection.execute(
                    "SELECT key, value FROM metadata WHERE key IN ('last_updated', 'git_branch', 'git_head_sha')",
                ).fetchall(),
            );
        } finally {
            connection.close();
        }

        provenance: dict[str, Any] = {};
        updated_at: any = rows.get("last_updated");
        if isinstance(updated_at, `str) and updated_at {
            provenance["updated_at"] = updated_at;
            try {
                built_at: any = datetime.fromisoformat(updated_at);
                now: any = datetime.now(tz=built_at.tzinfo);
                provenance["age_seconds"] = max(0, `int((now - built_at).total_seconds()));
            } except (OverflowError, TypeError, ValueError) {}
        }

        head_sha: any = rows.get("git_head_sha");
        if isinstance(head_sha, `str) and head_sha {
            provenance["built_at_sha"] = head_sha;
        }
        if provenance {
            branch: any = rows.get("git_branch");
            if isinstance(branch, `str) and branch {
                provenance["built_on_branch"] = branch;
            }
            live_head_sha: any = _read_live_git_head(`root);
            if live_head_sha {
                provenance["head_sha"] = live_head_sha;
                if isinstance(head_sha, `str) and head_sha {
                    provenance["head_matches_build"] = operator.eq(live_head_sha, head_sha);
                }
            }
        }
        return provenance or None;
    } except Exception {
        return None;
    }
}

def with_provenance(result: Any, repo_root: str | None = None) -> Any {
    if not isinstance(result, `dict) or "_graph" in result {
        return result;
    }
    provenance: any = graph_provenance(repo_root);
    if provenance {
        result["_graph"] = provenance;
    }
    return result;
}

glob _BUILTIN_CALL_NAMES: set[str] = set(
    ("map filter reduce reduceRight forEach find findIndex some every includes indexOf lastIndexOf "
        "push pop shift unshift splice slice concat join flat flatMap sort reverse fill keys values "
        "entries from isArray of at trim trimStart trimEnd split replace replaceAll match matchAll "
        "search substring substr toLowerCase toUpperCase startsWith endsWith padStart padEnd repeat "
        "charAt charCodeAt assign freeze defineProperty getOwnPropertyNames hasOwnProperty create is "
        "fromEntries log warn error info debug trace dir table time timeEnd assert clear count then "
        "catch finally resolve reject all allSettled race any parse stringify floor ceil round random "
        "max min abs pow sqrt addEventListener removeEventListener querySelector querySelectorAll "
        "getElementById createElement appendChild removeChild setAttribute getAttribute "
        "preventDefault stopPropagation setTimeout clearTimeout setInterval clearInterval toString "
        "valueOf toJSON toISOString getTime getFullYear now isNaN parseInt parseFloat toFixed "
        "encodeURIComponent decodeURIComponent call apply bind next emit on off once pipe write read "
        "end close destroy send status json redirect set get delete has findUnique findFirst findMany "
        "createMany update updateMany deleteMany upsert aggregate groupBy transaction describe it "
        "test expect beforeEach afterEach beforeAll afterAll mock spyOn require fetch").split(),
);

def _validate_repo_root(path: "Path | str") -> Path {
    resolved: any = Path(path).resolve();
    if not resolved.is_dir() {
        raise ValueError(f"repo_root is not an existing directory: {resolved}");
    }
    has_vcs: any = (resolved / ".git").exists()
        or (resolved / ".svn").exists()
        or (resolved / ".code-review-graph").exists();
    if not has_vcs {
        raise ValueError(
            f"repo_root does not look like a project root (no .git, .svn, or .code-review-graph directory found): {resolved}",
        );
    }
    return resolved;
}

def _resolve_root(repo_root: str | None = None) -> Path {
    return _validate_repo_root(Path(repo_root)) if repo_root else find_project_root();
}

def _open_graph_store(db_path: Path, command: str) -> any {
    import from code_review_graph.graph { CorruptGraphDatabaseError }
    import code_review_graph.graph as _graph;

    try {
        return _graph.GraphStore(db_path);
    } except CorruptGraphDatabaseError as exc {
        if command != "build" {
            raise;
        }
        logger.warning(
            "Graph database at %s is unusable (%s); discarding it and building from scratch.",
            db_path,
            exc.reason,
        );
        _graph.discard_corrupt_database(db_path);
        return _graph.GraphStore(db_path);
    }
}

def _get_store(
    repo_root: str | None = None, *, db_path: Path | None = None, recover_corrupt: bool = False
) -> tuple[GraphStore, Path] {
    import code_review_graph.incremental as _incremental;

    `root: any = _resolve_root(repo_root);
    if db_path is None {
        db_path = get_db_path(`root);
    }
    store: any = _open_graph_store(db_path, "build") if recover_corrupt else GraphStore(db_path);
    try {
        _incremental.assert_graph_serves_root(`root, store);
    } except BaseException {
        store.close();
        raise;
    }
    return (store, `root);
}

def _resolve_graph_file_paths(store: GraphStore, `root: Path, file_paths: list[str]) -> list[str] {
    return _resolve_graph_file_paths_with_unmatched(store, `root, file_paths)[0];
}

def _resolve_graph_file_paths_with_unmatched(
    store: GraphStore, `root: Path, file_paths: list[str]
) -> tuple[list[str], list[str]] {
    resolved: list[str];
    seen: set[str];
    resolved = [];
    unmatched: list[str] = [];
    seen = set[any]();
    unmatched_seen: set[str] = set[any]();

    def add(path: str) {
        if path not in seen {
            resolved.append(path);
            seen.add(path);
        }
    }

    for file_path in file_paths {
        matched: any = False;
        raw: any = file_path.replace("\\", "/");
        candidates: any = [raw];
        path: any = Path(file_path);
        if path.is_absolute() {
            try {
                candidates.append(`str(path.resolve().relative_to(`root)).replace("\\", "/"));
            } except ValueError {}
        } else {
            candidates.append(normalize_file_path(`root / path));
        }

        candidate: any;
        for candidate in candidates {
            if store.get_nodes_by_file(candidate) {
                matched = True;
                add(candidate);
            }
        }

        suffixes: any = [];
        for candidate in candidates {
            normalized: any = candidate.replace("\\", "/");
            if normalized not in suffixes {
                suffixes.append(normalized);
            }
        }

        for suffix in suffixes {
            for matched_path in store.get_files_matching(suffix) {
                matched = True;
                add(matched_path);
            }
        }
        if not matched and file_path not in unmatched_seen {
            unmatched_seen.add(file_path);
            unmatched.append(_sanitize_name(file_path).replace("\n", " "));
        }
    }

    return (resolved, unmatched);
}

def _unmatched_file_warning(unmatched: list[str]) -> str {
    if not unmatched {
        return "";
    }
    paths: any = ", ".join(unmatched[:5]);
    if len(unmatched) > 5 {
        paths += f" (+{len(unmatched) - 5} more)";
    }
    return f"  - {len(unmatched)} requested file(s) are not indexed: {paths}";
}

def _validate_positive_int(value: int, name: str) -> int {
    if isinstance(value, `bool) or value < 1 {
        raise ValueError(f"{name} must be an integer greater than or equal to 1");
    }
    return value;
}

def _bounded(items: "list[Any]", max_results: int, hard_cap: int) -> tuple[list[Any], int, bool] {
    total: any = len(items);
    limit: any = min(max_results, hard_cap);
    return (`list(items[:limit]), total, operator.gt(total, limit));
}

def _shown_of(shown: int, total: int) -> str {
    return f", showing {shown} of {total}" if shown < total else "";
}

def compact_response(
    summary: str,
    key_entities: list[str] | None = None,
    risk: str = "unknown",
    communities: list[str] | None = None,
    flows_affected: list[str] | None = None,
    next_tool_suggestions: list[str] | None = None,
    data: dict[str, Any] | None = None,
    detail_level: str = "minimal",
) -> dict[str, Any] {
    resp: dict[str, Any] = {"status": "ok", "summary": summary};
    if key_entities {
        resp["key_entities"] = key_entities[:10];
    }
    if risk != "unknown" {
        resp["risk"] = risk;
    }
    if communities {
        resp["communities"] = communities[:5];
    }
    if flows_affected {
        resp["flows_affected"] = flows_affected[:5];
    }
    if next_tool_suggestions {
        resp["next_tool_suggestions"] = next_tool_suggestions[:3];
    }
    if detail_level != "minimal" and data {
        resp["data"] = data;
    }
    return resp;
}
