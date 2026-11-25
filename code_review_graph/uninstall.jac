import from __future__ { annotations }

import builtins, operator, copy, importlib, json, os, shutil, stat, subprocess, sys, tempfile;

import from dataclasses { dataclass, field }

import from pathlib { Path }

import from typing { Any, Callable, Sequence }

glob _tomllib: Any = importlib.import_module("tomllib" if sys.version_info >= (3, 11) else "tomli");

glob _ENTRY_NAME: any = "code-review-graph";

glob _GIT_HOOK_MARKER: any = skills._GIT_HOOK_NOTE;

glob _GITIGNORE_BANNER: any = "# Added by code-review-graph";

@dataclass
class UninstallReport {
    has removed_paths: list[str] = field(default_factory=list[any]);

    has edited_paths: list[str] = field(default_factory=list[any]);

    has skipped_paths: list[str] = field(default_factory=list[any]);

    has errors: list[str] = field(default_factory=list[any]);

    has touched: list[Path] = field(default_factory=list[any], repr=False, compare=False);

    has install_only: frozenset[str] = field(
        default_factory=builtins.frozenset, repr=False, compare=False
    );

    has total_actions: int {
        getter {
            return len(self.removed_paths) + len(self.edited_paths);
        }
    }
}

glob _remove_jsonc_paths: any = jsonc.remove_paths;

def _absolute(path: Path) -> Path;

def _is_lexical_child(path: Path, boundary: Path) -> bool;
def _safe_path(
    path: Path, boundary: Path, `report: UninstallReport, *, describe_skip: bool = True
) -> bool;
def _done(detail: str, dry_run: bool) -> str;

def _record_edit(`report: UninstallReport, path: Path, detail: str, dry_run: bool);

def _record_remove(`report: UninstallReport, path: Path, detail: str, dry_run: bool);

def _read_text(path: Path, `report: UninstallReport) -> str | None;

def _write_text(path: Path, text: str, `report: UninstallReport, *, detail: str, dry_run: bool);

def _parse_jsonc(path: Path, raw: str, `report: UninstallReport) -> dict[str, Any] | None;

def _remove_mcp_entry(
    path: Path,
    *,
    key: str,
    format_name: str,
    boundary: Path,
    `report: UninstallReport,
    dry_run: bool,
);

def _remove_toml_entry(
    path: Path, key: str, boundary: Path, `report: UninstallReport, *, dry_run: bool
);
def _remove_dsh_patch_entry(path: Path, boundary: Path, `report: UninstallReport, *, dry_run: bool);
def _remove_yaml_entry(
    path: Path, key: str, boundary: Path, `report: UninstallReport, *, dry_run: bool
);

def _commands(value: Any) -> set[str];
def _legacy_repo_hook_commands(repo_root: Path) -> set[str];
def _legacy_codex_hook_commands -> set[str];
def _steering_hook_scopes -> dict[str, tuple[str, Any]];
def _steering_hook_scope -> tuple[str, Any];
def _clean_hook_data(
    data: dict[str, Any],
    owned_commands: set[str],
    scoped_commands: dict[str, tuple[str, Any]] | None = None,
    *,
    owns: Callable[[str], bool] | None = None,
    scoped_owns: tuple[Callable[[str], bool], tuple[str, Any]] | None = None,
) -> tuple[dict[str, Any], list[tuple[str | int, ...]]];
def remove_steering_hook(repo_root: Path, *, dry_run: bool = False) -> UninstallReport;
def _without_our_servers(data: dict[str, Any]) -> dict[str, Any];
def _remove_backup_of_ours(
    path: Path,
    owned_commands: set[str],
    boundary: Path,
    `report: UninstallReport,
    *,
    dry_run: bool,
    scoped_commands: dict[str, tuple[str, Any]] | None,
    owns: Callable[[str], bool] | None,
    scoped_owns: tuple[Callable[[str], bool], tuple[str, Any]] | None,
);
def _remove_hooks(
    path: Path,
    owned_commands: set[str],
    boundary: Path,
    `report: UninstallReport,
    *,
    dry_run: bool,
    scoped_commands: dict[str, tuple[str, Any]] | None = None,
    owns: Callable[[str], bool] | None = None,
    scoped_owns: tuple[Callable[[str], bool], tuple[str, Any]] | None = None,
    backup: bool = True,
);
def _holds_nothing(value: Any) -> bool;
def _write_or_drop(
    path: Path, text: str, boundary: Path, `report: UninstallReport, *, detail: str, dry_run: bool
);
def _install_only_files(repo_root: Path) -> list[str];
def _prune_install_folders(repo_root: Path, relative_files: Sequence[str]);

def _remove_file(
    path: Path,
    boundary: Path,
    `report: UninstallReport,
    *,
    dry_run: bool,
    detail: str = "remove owned file",
);

def _remove_tree(path: Path, boundary: Path, `report: UninstallReport, *, dry_run: bool);

def _prune_empty_directory(path: Path, boundary: Path);

def _remove_skill_file(path: Path, boundary: Path, `report: UninstallReport, *, dry_run: bool);
def _join_without_instruction(before: str, after: str) -> str;
def _remove_instruction(path: Path, boundary: Path, `report: UninstallReport, *, dry_run: bool);

def _resolve_git_hook(repo_root: Path, name: str = "pre-commit") -> Path;
def _strip_git_hook_blocks(raw: str) -> tuple[str, bool];

def _remove_git_hook(repo_root: Path, `report: UninstallReport, *, dry_run: bool);
def _rewrite_or_remove_hook(
    path: Path,
    new_text: str,
    repo_root: Path,
    `report: UninstallReport,
    *,
    detail: str,
    dry_run: bool,
);
def _remove_git_sync_hooks(repo_root: Path, `report: UninstallReport, *, dry_run: bool);

def _remove_gitignore(repo_root: Path, `report: UninstallReport, *, dry_run: bool);

def _scope_for_config(
    path: Path, repo_root: Path, home: Path, extra_user_boundaries: Sequence[Path] = ()
) -> tuple[str, Path] | None;

def _process_platform_configs(
    repo_root: Path,
    home: Path,
    `report: UninstallReport,
    *,
    scope: str,
    dry_run: bool,
    platforms: frozenset[str] | None = None,
);

def _generated_skill_slugs -> list[str];
def _qoder_skill_names(repo_root: Path, `report: UninstallReport) -> list[str];
def _remove_legacy_mcp_configs(
    repo_root: Path, home: Path, `report: UninstallReport, *, scope: str, dry_run: bool
);

def _process_repo(
    repo_root: Path,
    home: Path,
    `report: UninstallReport,
    *,
    keep_data: bool,
    dry_run: bool,
    platforms: frozenset[str] | None = None,
);

def _process_repo_files(
    repo_root: Path,
    home: Path,
    `report: UninstallReport,
    *,
    keep_data: bool,
    dry_run: bool,
    platforms: frozenset[str] | None = None,
);

def _process_user(
    reference_repo: Path,
    home: Path,
    `report: UninstallReport,
    *,
    keep_data: bool,
    dry_run: bool,
    platforms: frozenset[str] | None = None,
);

def _registry_repo_paths(home: Path, `report: UninstallReport) -> list[Path];

def _normalise_repo(path: Path, home: Path, `report: UninstallReport) -> Path | None;
def _normalise_platform_filter(platforms: Sequence[str] | None) -> frozenset[str] | None;
def run(
    *,
    repo: Path | None = None,
    all_repos: bool = False,
    keep_data: bool = False,
    keep_user_configs: bool = False,
    dry_run: bool = False,
    platforms: Sequence[str] | None = None,
) -> UninstallReport;
