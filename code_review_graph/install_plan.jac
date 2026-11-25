"""Hold the file changes ``install`` makes until they have been shown (#173).

The installer reads and writes files only through the helpers here. With no
plan active they work on the disk directly, as they always did. Inside
:func:`planning` a write is kept in memory, later reads in the same run see
it, and nothing reaches the disk until :meth:`Plan.apply`. ``install
--dry-run`` prints the plan as diffs and drops it. A real install lists the
plan, asks its question, and only then writes, so what is written is what
was shown.
"""

import builtins;

import operator;

import from __future__ { annotations }

import contextlib;

import difflib;

import errno;

import io;

import os;

import shutil;

import stat;

import from contextvars { ContextVar }

import from dataclasses { dataclass }

import from pathlib { Path }

import from typing { Iterable, Iterator, Union }

glob PathLike: any;

glob DIFF_LINE_LIMIT: any;

glob _MIN_CUT: any;

glob _ACTIVE: ContextVar[Plan | None];

with entry {
    PathLike = Union[str, "os.PathLike[str]"];
    DIFF_LINE_LIMIT = 60;
    _MIN_CUT = 5;
}

"""One file as it is on disk and as the plan leaves it.

    ``before`` and ``after`` are ``None`` when the file does not exist on that
    side. ``mode`` holds permission bits the plan sets, or ``None`` to leave
    them as they are. ``link`` is set when the plan removes a symlink itself
    rather than the file it points to, and holds where the link pointed.
    """
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

"""Return a regular file's bytes and permission bits, or ``(None, None)``."""
def _disk_state(path: Path) -> tuple[bytes | None, int | None];

def _encode_text(text: str, encoding: str) -> bytes;

def _decode_text(data: bytes, encoding: str, errors: str) -> str;

"""File writes held in memory, in the order they were made."""
obj Plan {
    has _files: any;

    def init;

    def _link_entry(path: PathLike) -> FileChange | None;

    def _planned(path: PathLike) -> FileChange | None;

    def exists(path: PathLike) -> bool;

    def is_file(path: PathLike) -> bool;

    def read_bytes(path: PathLike) -> bytes;

    """Return whether ``path`` will exist, as a file or as a folder of one."""
    def lexists(path: PathLike) -> bool;

    """Return the permission bits ``path`` will have, if known."""
    def mode(path: PathLike) -> int | None;

    def _entry(path: PathLike) -> FileChange;

    """Raise the error a real write would, so a dry run reports it too."""
    def _check_can_create(key: Path) -> None;

    def write_bytes(path: PathLike, data: bytes, mode: int | None = None) -> None;

    def chmod(path: PathLike, mode: int) -> None;

    def unlink(path: PathLike) -> None;

    """Return every file the plan changes, in the order first touched."""
    def changes -> list[FileChange];

    """Return every file the plan writes, also one whose bytes stay the same."""
    def written -> list[Path];

    """Return the plan as it stands, for :meth:`changes_since` and :meth:`rollback`."""
    def checkpoint -> dict[Path, tuple[bytes | None, int | None]];

    """Return the changes made to the plan after ``saved`` was taken."""
    def changes_since(saved: dict[Path, tuple[bytes | None, int | None]]) -> list[FileChange];

    """Drop every change made to the plan after ``saved`` was taken."""
    def rollback(saved: dict[Path, tuple[bytes | None, int | None]]) -> None;

    """Write the plan to disk and return ``(path, reason)`` for each failure.

        A file whose content or permissions changed on disk after the plan was
        made is left alone, so an edit made while the user read the preview is
        never overwritten.
        """
    def apply -> list[tuple[Path, str]];

    def __repr__ -> str;

    def __eq__(other: any) -> bool;

    def __hash__ -> int;
}

def _unchanged_on_disk(change: FileChange) -> bool;

with entry {
    _ACTIVE = ContextVar("code_review_graph_install_plan", default=None);
}

"""Return the plan writes go to, or ``None`` when they go to disk."""
def active -> Plan | None;

"""Hold every write made through this module until ``Plan.apply``."""
@contextlib.contextmanager
def planning -> Generator[any, any, any];

def exists(path: PathLike) -> bool;

def is_file(path: PathLike) -> bool;

"""Like ``os.path.lexists``, counting files and folders the plan creates."""
def lexists(path: PathLike) -> bool;

def read_bytes(path: PathLike) -> bytes;

def read_text(path: PathLike, encoding: str = "utf-8", errors: str = "strict") -> str;

"""Write ``text`` as ``Path.write_text`` would, creating parent folders."""
def write_text(path: PathLike, text: str, encoding: str = "utf-8") -> None;

"""Write ``data`` as it is, with no line ending change, creating parent folders."""
def write_bytes(path: PathLike, data: bytes) -> None;

"""Copy content and permission bits, as ``shutil.copy2`` does."""
def copy_file(source: PathLike, destination: PathLike) -> None;

def chmod(path: PathLike, mode: int) -> None;

def unlink(path: PathLike) -> None;

"""Show ``path`` relative to the repository or home folder when it is inside."""
def display_path(path: PathLike, repo_root: PathLike | None = None) -> str;

"""Name a file in a diff header: ``a/`` or ``b/`` only for repository paths."""
def diff_label(shown: str, side: str) -> str;

"""Say in a word or two what the plan does to the file."""
def describe(change: FileChange) -> str;

def _lines(data: bytes | None) -> list[str] | None;

glob limit_default_: any;

with entry {
    limit_default_ = DIFF_LINE_LIMIT;
}

"""Return each change as a short unified diff, cut at ``limit`` lines a file."""
def render(
    changes: Iterable[FileChange], repo_root: PathLike | None = None, limit: int = limit_default_
) -> str;
