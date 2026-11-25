import from __future__ { annotations }

import importlib;

import builtins;

import operator;

import from jaclang.comptime { target }

import json;

import os;

import re;

import shutil;

import sqlite3;

import subprocess;

import sys;

import tempfile;

import from dataclasses { asdict, dataclass, field }

import from pathlib { Path }

import from typing { Any, Callable }

glob OK: any = "ok";

glob INFO: any = "info";

glob WARN: any = "warn";

glob FAIL: any = "fail";

glob _PROBE_TIMEOUT_SECONDS: any = 30.0;

glob _NAMED_VERSION_RE: any;

glob _VERSION_RE: any;

glob _UV_TOOL_LINE_RE: any;

glob _PINNED_SPEC_RE: any;

glob _PYTHON_RE: any;

glob _ABSOLUTE_PROGRAM_RE: any;

glob _ABSOLUTE_PYTHON_RE: any;

glob _QUOTED_PYTHON_RE: any;

glob _UVX_HOOK_RE: any;

glob _GIT_HOOK_NAMES: any;

glob _HOOK_MARKERS: any;

glob _UPGRADE_ANY: any;

glob _NOT_RUN: any;

with entry {
    _NAMED_VERSION_RE = re.compile("code-review-graph\\s+v?(\\d+\\.\\d+\\.\\d+[0-9A-Za-z.+-]*)");
    _VERSION_RE = re.compile("(\\d+\\.\\d+\\.\\d+[0-9A-Za-z.+-]*)");
    _UV_TOOL_LINE_RE = re.compile("^code-review-graph v(\\S+)", re.MULTILINE);
    _PINNED_SPEC_RE = re.compile("^code-review-graph(?:\\[[^\\]]*\\])?(?:==|@)(\\d[^\\s,;]*)$");
    _PYTHON_RE = re.compile("\\Apythonw?[0-9]*(?:\\.[0-9]+)*\\Z");
    _ABSOLUTE_PROGRAM_RE = re.compile(
        "(?:^|[\\s\"'])((?:/|[A-Za-z]:[\\\\/])[^\\s\"']*code-review-graph(?:\\.exe)?)(?=[\"'\\s]|$)",
        re.MULTILINE,
    );
    _ABSOLUTE_PYTHON_RE = re.compile(
        "(?:^|[\\s\"'])((?:/|[A-Za-z]:[\\\\/])[^\\s\"']*pythonw?[0-9.]*(?:\\.exe)?)[\"']?\\s+-m\\s+code_review_graph\\b",
        re.MULTILINE,
    );
    _QUOTED_PYTHON_RE = re.compile(
        "'((?:/|[A-Za-z]:[\\\\/])[^']*pythonw?[0-9.]*(?:\\.exe)?)'\\s+-m\\s+code_review_graph\\b"
    );
    _UVX_HOOK_RE = re.compile("(?:^|[\\s;&|({])uvx\\s+code-review-graph\\b", re.MULTILINE);

    _GIT_HOOK_NAMES = ("pre-commit", "post-checkout", "post-merge", "post-rewrite");
    _HOOK_MARKERS = ("code-review-graph", "code_review_graph", "crg-");

    _UPGRADE_ANY = "pip install -U code-review-graph, pipx upgrade code-review-graph or uv tool upgrade code-review-graph, whichever installed it";
}

@dataclass
class Finding {
    has status: str;

    has message: str;

    has fix: str = "";
}

@dataclass
class Copy {
    has path: str;

    has version: str | None;
}

@dataclass
class McpEntry {
    has file: str;

    has platforms: list[str];

    has command: str;

    has version: str | None;

    has source: str;
}

@dataclass
class Report {
    has repo_root: str;

    has this_copy: dict[str, str];

    has path_copies: list[Copy] = field(default_factory=list[any]);

    has mcp_entries: list[McpEntry] = field(default_factory=list[any]);

    has `graph: dict[str, Any] = field(default_factory=dict[any, any]);

    has hooks: list[dict[str, Any]] = field(default_factory=list[any]);

    has findings: list[Finding] = field(default_factory=list[any]);

    has healthy: bool {
        getter {
            return not `any(operator.eq(f.status, FAIL) for f in self.findings);
        }
    }

    def to_json -> dict[str, Any];
}

def _run_quietly(argv: list[str], cwd: Path | None) -> str | None;

obj _Prober {
    has _run: any,
        _seen: any;

    def init(run: Callable[[list[str], Path | None], str | None]);

    def version(argv: list[str], cwd: Path | None = None) -> str | None;
    def uv_tool_version -> str | None;

    def __repr__ -> str;

    def __eq__(other: any) -> bool;

    def __hash__ -> int;
}

def _program_names -> list[str];
def copies_on_path(path_env: str | None = None) -> list[Path];

def _version_key(version: str) -> tuple[int, ...] | None;

def _older_than_this(version: str) -> bool | None;
def _mismatch_fix(version: str, where: str, upgrade: str) -> str;
def _upgrade_for(path: str) -> str;

def _read_json(path: Path) -> Any;
def _repo_mcp_configs(`root: Path) -> dict[Path, tuple[str, list[str]]];

def _entry_tokens(`entry: dict[str, Any]) -> list[str] | None;

def _launcher(token: str) -> str;
def _uvx_spec(rest: list[str]) -> str | None;

@dataclass
class _Resolved {
    has version: str | None;

    has source: str;

    has upgrade: str = _UPGRADE_ANY;
}

def _program_doctor_may_run(exe: str, `root: Path) -> str | None;

with entry {
    _NOT_RUN = "doctor does not run a program inside the repository or named by a relative path, because the repository chose it";
}

def resolve_mcp_entry(tokens: list[str], `root: Path, prober: _Prober) -> _Resolved;

def check_mcp_entries(`root: Path, prober: _Prober) -> tuple[list[McpEntry], list[Finding]];
def _read_only_uri(db_path: Path) -> str;
def _live_head(`root: Path) -> str | None;
def _holds_commits_since(`root: Path, db_path: Path, built: str) -> bool;

def check_graph(`root: Path) -> tuple[dict[str, Any], list[Finding]];

def _git_hooks_dir(`root: Path) -> Path | None;

def _ours(text: str) -> bool;
def _runners(text: str) -> set[str];
def _settings_hook_events(path: Path) -> list[str];

def _hook_settings_files(`root: Path) -> list[tuple[str, Path]];
def _check_uvx_hooks(prober: _Prober, path_copies: list[Copy]) -> list[Finding];

def check_hooks(
    `root: Path, prober: _Prober, path_copies: list[Copy]
) -> tuple[list[dict[str, Any]], list[Finding]];

def check_path_copies(prober: _Prober) -> tuple[list[Copy], list[Finding]];

glob run_default_: any;

with entry {
    run_default_ = _run_quietly;
}

def diagnose(
    repo_root: Path, run: Callable[[list[str], Path | None], str | None] = run_default_
) -> Report;

def render(`report: Report) -> str;
def run_doctor(repo_root: Path, *, as_json: bool = False) -> int;
