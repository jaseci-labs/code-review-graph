import from __future__ { annotations }

import builtins, operator, contextlib, difflib, errno, io, os, shutil, stat;

import from contextvars { ContextVar }

import from dataclasses { dataclass }

import from pathlib { Path }

import from typing { Iterable, Iterator, Union }

glob PathLike: any = Union[str, "os.PathLike[str]"];

glob DIFF_LINE_LIMIT: any = 60;

glob _MIN_CUT: any = 5;

@dataclass
class FileChange {
    has path: Path;

    has before: bytes | None;

    has after: bytes | None;

    has before_mode: int | None;

    has mode: int | None;

    has link: str | None = None;

    def is_change -> bool;
}

def _mode_changes(before: int | None, after: int | None) -> bool;

def _key(path: PathLike) -> Path;

def _real_key(path: PathLike) -> Path;
def _disk_state(path: Path) -> tuple[bytes | None, int | None];

def _encode_text(text: str, encoding: str) -> bytes;

def _decode_text(data: bytes, encoding: str, errors: str) -> str;

obj Plan {
    has _files: any;

    def init;

    def _link_entry(path: PathLike) -> FileChange | None;

    def _planned(path: PathLike) -> FileChange | None;

    def exists(path: PathLike) -> bool;

    def is_file(path: PathLike) -> bool;

    def read_bytes(path: PathLike) -> bytes;
    def lexists(path: PathLike) -> bool;
    def mode(path: PathLike) -> int | None;

    def _entry(path: PathLike) -> FileChange;
    def _check_can_create(key: Path);

    def write_bytes(path: PathLike, data: bytes, mode: int | None = None);

    def chmod(path: PathLike, mode: int);

    def unlink(path: PathLike);
    def changes -> list[FileChange];
    def written -> list[Path];
    def checkpoint -> dict[Path, tuple[bytes | None, int | None]];
    def changes_since(saved: dict[Path, tuple[bytes | None, int | None]]) -> list[FileChange];
    def rollback(saved: dict[Path, tuple[bytes | None, int | None]]);
    def apply -> list[tuple[Path, str]];

    def __repr__ -> str;

    def __eq__(other: any) -> bool;

    def __hash__ -> int;
}

def _unchanged_on_disk(change: FileChange) -> bool;

glob _ACTIVE: ContextVar[Plan | None] = ContextVar("code_review_graph_install_plan", default=None);

def active -> Plan | None;
@contextlib.contextmanager
def planning -> Generator[any, any, any];

def exists(path: PathLike) -> bool;

def is_file(path: PathLike) -> bool;
def lexists(path: PathLike) -> bool;

def read_bytes(path: PathLike) -> bytes;

def read_text(path: PathLike, encoding: str = "utf-8", errors: str = "strict") -> str;
def write_text(path: PathLike, text: str, encoding: str = "utf-8");
def write_bytes(path: PathLike, data: bytes);
def copy_file(source: PathLike, destination: PathLike);

def chmod(path: PathLike, mode: int);

def unlink(path: PathLike);
def display_path(path: PathLike, repo_root: PathLike | None = None) -> str;
def diff_label(shown: str, side: str) -> str;
def describe(change: FileChange) -> str;

def _lines(data: bytes | None) -> list[str] | None;

glob limit_default_: any = DIFF_LINE_LIMIT;

def render(
    changes: Iterable[FileChange], repo_root: PathLike | None = None, limit: int = limit_default_
) -> str;
