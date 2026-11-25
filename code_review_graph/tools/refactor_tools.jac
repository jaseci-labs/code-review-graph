import from __future__ { annotations }

import from pathlib { Path }

import from typing { Any }

glob _MAX_REFACTOR_RESULTS: any = 150;

glob _MINIMAL_DEAD_FIELDS: any = ("name", "kind", "relative_path", "line");

glob _MINIMAL_SUGGESTION_FIELDS: any = ("type", "description", "symbols");

glob _MINIMAL_EDIT_FIELDS: any = ("file", "line", "confidence");

def _project(rows: list[dict[str, Any]], fields: tuple[str, ...]) -> list[dict[str, Any]] {
    return [{k: r[k] for k in fields if k in r} for r in rows];
}

def refactor_func(
    mode: str = "rename",
    old_name: str | None = None,
    new_name: str | None = None,
    kind: str | None = None,
    file_pattern: str | None = None,
    repo_root: str | None = None,
    max_results: int = 50,
    detail_level: str = "standard",
) -> dict[str, Any] {
    valid_modes: any = {"rename", "dead_code", "suggest"};
    if mode not in valid_modes {
        return {
            "status": "error",
            "error": f"Invalid mode '{mode}'. Must be one of: {", ".join(sorted(valid_modes))}",
        };
    }
    _validate_positive_int(max_results, "max_results");

    store: any;
    `root: any;
    (store, `root) = _get_store(repo_root) as any;
    try {
        if mode == "rename" {
            if not old_name or not new_name {
                return {
                    "status": "error",
                    "error": "rename mode requires both old_name and new_name.",
                };
            }
            preview: any = rename_preview(store, old_name, new_name);
            if preview is None {
                return {"status": "not_found", "summary": f"No node found matching '{old_name}'."};
            }
            edits: any;
            total: any;
            truncated: any;
            (edits, total, truncated) = _bounded(
                preview["edits"], max_results, _MAX_REFACTOR_RESULTS
            ) as any;
            if detail_level == "minimal" {
                edits = _project(edits, _MINIMAL_EDIT_FIELDS);
            }
            result: any = {
                "status": "ok",
                "summary": f"Rename preview: {old_name} -> {new_name}, {total} edit(s)"
                    + _shown_of(len(edits), total)
                    + (
                        ". Use apply_refactor_tool(refactor_id='"
                        + format(preview["refactor_id"], "")
                        + "') to apply."
                    ),
                **preview,
                "edits": edits,
                "total": total,
                "truncated": truncated,
            };
            result["_hints"] = generate_hints("refactor_tool", result, get_session());
            return result;
        } elif mode == "dead_code" {
            dead: any;
            (dead, total, truncated) = _bounded(
                find_dead_code(store, kind=kind, file_pattern=file_pattern, root=`root),
                max_results,
                _MAX_REFACTOR_RESULTS,
            ) as any;
            if detail_level == "minimal" {
                dead = _project(dead, _MINIMAL_DEAD_FIELDS);
            }
            result = {
                "status": "ok",
                "summary": f"Found {total} dead code symbol(s)" + _shown_of(len(dead), total) + ".",
                "dead_code": dead,
                "total": total,
                "truncated": truncated,
            };
            result["_hints"] = generate_hints("refactor_tool", result, get_session());
            return result;
        } else {
            suggestions: any;
            (suggestions, total, truncated) = _bounded(
                suggest_refactorings(store), max_results, _MAX_REFACTOR_RESULTS
            ) as any;
            if detail_level == "minimal" {
                suggestions = _project(suggestions, _MINIMAL_SUGGESTION_FIELDS);
            }
            result = {
                "status": "ok",
                "summary": f"Generated {total} refactoring suggestion(s)"
                    + _shown_of(len(suggestions), total)
                    + ".",
                "suggestions": suggestions,
                "total": total,
                "truncated": truncated,
            };
            result["_hints"] = generate_hints("refactor_tool", result, get_session());
            return result;
        }
    } except Exception as exc {
        return {"status": "error", "error": `str(exc)};
    } finally {
        store.close();
    }
}

def apply_refactor_func(
    refactor_id: str, repo_root: str | None = None, dry_run: bool = False, max_diff_files: int = 25
) -> dict[str, Any] {
    _validate_positive_int(max_diff_files, "max_diff_files");

    try {
        `root: any = _validate_repo_root(Path(repo_root)) if repo_root else find_project_root();
    } except (RuntimeError, ValueError) as exc {
        return {"status": "error", "error": `str(exc)};
    }

    result: any = apply_refactor(refactor_id, `root, dry_run=dry_run);

    diffs: any = result.get("diffs");
    if isinstance(diffs, `dict) and diffs {
        limit: any = min(max_diff_files, _MAX_REFACTOR_RESULTS);
        if len(diffs) > limit {
            kept: any = sorted(diffs)[:limit];
            result["diffs"] = {path: diffs[path] for path in kept};
            result["diffs_total"] = len(diffs);
            result["diffs_truncated"] = True;
        }
    }
    return result;
}
