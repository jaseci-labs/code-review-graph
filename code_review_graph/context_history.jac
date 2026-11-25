import from __future__ { annotations }

import operator;

import from jaclang.comptime { target }

import contextlib, contextvars, json, logging, os, sys;

import from dataclasses { dataclass }

import from datetime { datetime, timezone }

import from pathlib { Path }

import from typing { Any, Iterable, Iterator }

glob logger: any = logging.getLogger(__name__);

glob HISTORY_ENV: any = "CRG_CONTEXT_HISTORY";

glob HISTORY_FILE: any = "context-history.jsonl";

glob LOCK_FILE: any = "context-history.lock";

glob SCHEMA_VERSION: any = 1;

glob MAX_BYTES: any = 1024 * 1024;

glob _TS_FORMAT: any = "%Y-%m-%dT%H:%M:%SZ";

glob _TOKEN_KEYS: any = ("baseline_tokens", "returned_tokens", "saved_tokens");

glob _label: contextvars.ContextVar[str | None] = contextvars.ContextVar(
    "crg_context_history_label", default=None
);

@dataclass(frozen=True)
class CallInfo {
    has data_dir: Path;

    has tool: str;

    has detail_level: str | None = None;

    has files: int | None = None;

    has depth: int | None = None;
}

def history_enabled -> bool;
@contextlib.contextmanager
def recorded_as(label: str) -> Generator[any, any, any];

def _count(value: Any) -> int | None;
def record_call(call: CallInfo, *, baseline: int, returned: int, saved: int);
@contextlib.contextmanager
def _locked(lock_path: Path) -> Generator[any, any, any];

def _roll_over_if_full(path: Path);
def history_files(data_dir: Path) -> list[Path];

def _parse(line: str) -> dict[str, Any] | None;
def read_history(
    data_dir: Path, *, since: datetime | None = None
) -> tuple[list[dict[str, Any]], int];

def _empty(key: str) -> dict[str, Any];

def _add(row: dict[str, Any], `entry: dict[str, Any]);
def summarise(entries: Iterable[dict[str, Any]], *, `by: str) -> list[dict[str, Any]];
def total(entries: Iterable[dict[str, Any]]) -> dict[str, Any];

def _percent(row: dict[str, Any]) -> int;
def format_table(rows: list[dict[str, Any]], totals: dict[str, Any], *, `by: str) -> str;
