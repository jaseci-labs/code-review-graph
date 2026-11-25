import from __future__ { annotations }

import builtins, operator, logging, os, re, subprocess;

import from collections.abc { Iterable }

import from dataclasses { dataclass, field }

import from pathlib { Path, PurePath, PurePosixPath }

glob logger: any = logging.getLogger(__name__);

glob BLOCK_START: any = "# >>> code-review-graph install files >>>";

glob BLOCK_NOTE: any = "# Added by `code-review-graph install --gitignore`. `uninstall` removes this block.";

glob BLOCK_END: any = "# <<< code-review-graph install files <<<";

glob _ENTRY: any = re.compile("/[A-Za-z0-9._-]+(?:/[A-Za-z0-9._-]+)*/?");

@dataclass(frozen=True)
class Plan {
    has files: tuple[str, ...];

    has existed: frozenset[str];
}

@dataclass
class Result {
    has status: str;

    has added: list[str] = field(default_factory=list[any]);

    has entries: list[str] = field(default_factory=list[any]);

    has detail: str = "";
}

def _relative(repo_root: Path, path: Path) -> str | None;
def repo_files(
    repo_root: Path,
    target: str,
    *,
    with_skills: bool,
    with_hooks: bool,
    with_instructions: bool,
    platforms: Iterable[str] | None = None,
) -> list[str];
def _with_folders(files: Iterable[str]) -> dict[str, bool];
def plan(
    repo_root: Path,
    target: str,
    *,
    with_skills: bool,
    with_hooks: bool,
    with_instructions: bool,
    platforms: Iterable[str] | None = None,
) -> Plan;

def _git(repo_root: Path, args: list[str], stdin: str | None = None) -> str | None;

def _in_git_work_tree(repo_root: Path) -> bool;

obj _GitError(Exception) {
    def __repr__ -> str;

    def __eq__(other: any) -> bool;

    def __hash__ -> int;
}

def _tracked(repo_root: Path, paths: Iterable[str]) -> set[str];

def _holds_tracked(path: str, tracked: set[str]) -> bool;
def _ignored(repo_root: Path, entries: list[str]) -> set[str];
def _created_entries(repo_root: Path, install_plan: Plan, dry_run: bool) -> list[str];
def _find_block(lines: list[str]) -> tuple[int, int] | str | None;

def _block_entries(lines: list[str], start: int, end: int) -> list[str];

def _render(entries: list[str], newline: str) -> str;
def _replace_block(lines: list[str], start: int, end: int, entries: list[str], newline: str) -> str;
def remove_block(text: str) -> tuple[str, str];
def apply(repo_root: Path, install_plan: Plan, *, dry_run: bool) -> Result;
