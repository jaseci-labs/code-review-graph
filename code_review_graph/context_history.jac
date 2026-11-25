"""Opt-in local log of context savings, and the reader behind ``context-history``.

Issue #813. Off unless ``CRG_CONTEXT_HISTORY`` is set to ``1``, ``true``,
``yes`` or ``on``. When it is on, every response that carries a
``context_savings`` estimate also appends one JSON line to
``context-history.jsonl`` next to ``graph.db``. Nothing is sent anywhere.

One line holds only numbers and fixed labels::

    {"v":1,"ts":"2026-11-09T18:59:01Z","tool":"detect_changes_tool",
     "baseline_tokens":12932,"returned_tokens":773,"saved_tokens":12159,
     "detail_level":"minimal","files":3,"depth":2}

No file names, paths, symbol names, source text or free text from a client
is ever written: ``tool`` is a constant from the code, ``detail_level`` is
reduced to the two values the tools act on, and the rest are counts. When the
file reaches ``MAX_BYTES`` it is renamed to ``context-history.jsonl.1``
(replacing the older one), so the two files together never pass twice that
by more than one line. Writers take ``context-history.lock`` around the size
check, the roll-over and the append, so two writers that both see a full log
cannot roll it over twice and lose the older file.
"""

import operator;

import from jaclang.comptime { target }

import from __future__ { annotations }

import contextlib;

import contextvars;

import json;

import logging;

import os;

import sys;

import from dataclasses { dataclass }

import from datetime { datetime, timezone }

import from pathlib { Path }

import from typing { Any, Iterable, Iterator }

glob logger: any;

glob HISTORY_ENV: any;

glob HISTORY_FILE: any;

glob LOCK_FILE: any;

glob SCHEMA_VERSION: any;

glob MAX_BYTES: any;

glob _TS_FORMAT: any;

glob _TOKEN_KEYS: any;

glob _label: contextvars.ContextVar[str | None];

with entry {
    logger = logging.getLogger(__name__);

    HISTORY_ENV = "CRG_CONTEXT_HISTORY";
    HISTORY_FILE = "context-history.jsonl";
    LOCK_FILE = "context-history.lock";
    SCHEMA_VERSION = 1;
    MAX_BYTES = 1024 * 1024;

    _TS_FORMAT = "%Y-%m-%dT%H:%M:%SZ";
    _TOKEN_KEYS = ("baseline_tokens", "returned_tokens", "saved_tokens");
    _label = contextvars.ContextVar("crg_context_history_label", default=None);
}

"""Where to log one call, and the coarse facts about it.

    Only these fields can reach the log, so nothing else about a call can.
    """
@dataclass(frozen=True)
class CallInfo {
    has data_dir: Path;

    has tool: str;

    has detail_level: str | None = None;

    has files: int | None = None;

    has depth: int | None = None;
}

"""True when the person has turned the log on."""
def history_enabled -> bool;

"""Log calls made inside this block under *label* instead of the tool name."""
@contextlib.contextmanager
def recorded_as(label: str) -> Generator[any, any, any];

def _count(value: Any) -> int | None;

"""Append one line for *call* when the log is on. Never raises."""
def record_call(call: CallInfo, *, baseline: int, returned: int, saved: int) -> None;

"""Hold an exclusive ``flock`` on *lock_path* for the block.

    Each call opens its own descriptor, so threads in one process wait for
    each other as well as other processes. Windows has no ``flock``; there
    the block runs unguarded, as the graph write lock does.
    """
@contextlib.contextmanager
def _locked(lock_path: Path) -> Generator[any, any, any];

def _roll_over_if_full(path: Path) -> None;

"""The log files, oldest first."""
def history_files(data_dir: Path) -> list[Path];

def _parse(line: str) -> dict[str, Any] | None;

"""Return ``(entries, skipped_lines)``, oldest first.

    Lines that are not a valid version-1 entry are counted and skipped, so a
    half-written line or a hand edit never stops the report.
    """
def read_history(
    data_dir: Path, *, since: datetime | None = None
) -> tuple[list[dict[str, Any]], int];

def _empty(key: str) -> dict[str, Any];

def _add(row: dict[str, Any], `entry: dict[str, Any]) -> None;

"""Group entries per UTC day (date order) or per tool (busiest first).

    ``saved_tokens`` in a row is net: full context minus graph context, which
    is negative when the graph replies were bigger than the files.
    """
def summarise(entries: Iterable[dict[str, Any]], *, `by: str) -> list[dict[str, Any]];

"""One row over every entry."""
def total(entries: Iterable[dict[str, Any]]) -> dict[str, Any];

def _percent(row: dict[str, Any]) -> int;

"""Render the trend as a plain text table."""
def format_table(rows: list[dict[str, Any]], totals: dict[str, Any], *, `by: str) -> str;
