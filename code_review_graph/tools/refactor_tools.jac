import from __future__ { annotations }

import from pathlib { Path }

import from typing { Any }

glob _MAX_REFACTOR_RESULTS: any = 150;

glob _MINIMAL_DEAD_FIELDS: any = ("name", "kind", "relative_path", "line");

glob _MINIMAL_SUGGESTION_FIELDS: any = ("type", "description", "symbols");

glob _MINIMAL_EDIT_FIELDS: any = ("file", "line", "confidence");
def _project(rows: list[dict[str, Any]], fields: tuple[str, ...]) -> list[dict[str, Any]];
def refactor_func(
    mode: str = "rename",
    old_name: str | None = None,
    new_name: str | None = None,
    kind: str | None = None,
    file_pattern: str | None = None,
    repo_root: str | None = None,
    max_results: int = 50,
    detail_level: str = "standard",
) -> dict[str, Any];
def apply_refactor_func(
    refactor_id: str, repo_root: str | None = None, dry_run: bool = False, max_diff_files: int = 25
) -> dict[str, Any];
