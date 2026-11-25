"""``code-review-graph doctor``: check the setup without changing anything.

Most "it does not work" reports come down to one of a few things, and each
is easy to see once it is named:

* two copies are installed, and the MCP entry or a hook runs the other one,
  which then refuses a graph a newer copy wrote;
* there is no graph yet, or it was built at another commit;
* the last build did not finish;
* hooks are missing, or cannot find the program they call.

``doctor`` reads files and runs ``--version`` on each copy it finds. It never
writes, and it never starts a download: an unpinned ``uvx`` entry with no
``uv tool install`` behind it is reported as unknown, not resolved. Only MCP
entries in the repository's own config files are checked; entries in a home
folder config are shared by every repository and left to the tool itself.

Exit 0 when nothing failed, 1 when something did.
"""

import from code_review_graph._lazy { lazy }

import importlib;

import builtins;

import operator;

import from jaclang.comptime { target }

import from __future__ { annotations }

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

"""One line of the report."""
@dataclass
class Finding {
    has status: str;

    has message: str;

    has fix: str = "";
}

"""A ``code-review-graph`` program found on PATH."""
@dataclass
class Copy {
    has path: str;

    has version: str | None;
}

"""The ``code-review-graph`` MCP entry in one config file."""
@dataclass
class McpEntry {
    has file: str;

    has platforms: list[str];

    has command: str;

    has version: str | None;

    has source: str;
}

"""Everything ``doctor`` found, for the text and the JSON output."""
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

"""Run ``argv`` and return its output, or None when it could not run."""
def _run_quietly(argv: list[str], cwd: Path | None) -> str | None;

"""Ask each copy for its version once per run."""
obj _Prober {
    has _run: any,
        _seen: any;

    def init(run: Callable[[list[str], Path | None], str | None]);

    def version(argv: list[str], cwd: Path | None = None) -> str | None;

    """The version ``uv tool install`` put in place, read without a download."""
    def uv_tool_version -> str | None;

    def __repr__ -> str;

    def __eq__(other: any) -> bool;

    def __hash__ -> int;
}

def _program_names -> list[str];

"""Every ``code-review-graph`` on PATH, first one first, each file once."""
def copies_on_path(path_env: str | None = None) -> list[Path];

def _version_key(version: str) -> tuple[int, ...] | None;

def _older_than_this(version: str) -> bool | None;

"""Say which side to upgrade when two copies disagree."""
def _mismatch_fix(version: str, where: str, upgrade: str) -> str;

"""The upgrade command that most likely fits the copy at ``path``."""
def _upgrade_for(path: str) -> str;

def _read_json(path: Path) -> Any;

"""``{config file: (key, [platform names])}`` for JSON configs in ``root``."""
def _repo_mcp_configs(`root: Path) -> dict[Path, tuple[str, list[str]]];

def _entry_tokens(`entry: dict[str, Any]) -> list[str] | None;

def _launcher(token: str) -> str;

"""The package spec a ``uvx`` command line asks for."""
def _uvx_spec(rest: list[str]) -> str | None;

"""What an MCP command line runs, as far as doctor can tell."""
@dataclass
class _Resolved {
    has version: str | None;

    has source: str;

    has upgrade: str = _UPGRADE_ANY;
}

"""Return the program to ask for its version, or None when doctor must not run it.

    MCP configs and hook files are part of the repository, so whoever wrote the
    repository chose the commands in them. Doctor runs only a bare name it finds
    on PATH, or an absolute path, and never a program inside the repository.
    """
def _program_doctor_may_run(exe: str, `root: Path) -> str | None;

with entry {
    _NOT_RUN = "doctor does not run a program inside the repository or named by a relative path, because the repository chose it";
}

"""Find the version an MCP command line runs, without a download.

    Nothing the repository ships is run: see ``_program_doctor_may_run``.
    """
def resolve_mcp_entry(tokens: list[str], `root: Path, prober: _Prober) -> _Resolved;

def check_mcp_entries(`root: Path, prober: _Prober) -> tuple[list[McpEntry], list[Finding]];

"""Open SQLite without creating or updating any side file."""
def _read_only_uri(db_path: Path) -> str;

"""The checked-out commit, or None outside git or before the first commit."""
def _live_head(`root: Path) -> str | None;

"""Whether the graph holds every file changed between ``built`` and HEAD."""
def _holds_commits_since(`root: Path, db_path: Path, built: str) -> bool;

def check_graph(`root: Path) -> tuple[dict[str, Any], list[Finding]];

def _git_hooks_dir(`root: Path) -> Path | None;

def _ours(text: str) -> bool;

"""What a hook runs: full paths it names, ``uvx``, or ``PATH`` when it names neither."""
def _runners(text: str) -> set[str];

"""Event names whose hooks in ``path`` call code-review-graph."""
def _settings_hook_events(path: Path) -> list[str];

def _hook_settings_files(`root: Path) -> list[tuple[str, Path]];

"""Check hooks that run ``uvx code-review-graph``, without starting uvx."""
def _check_uvx_hooks(prober: _Prober, path_copies: list[Copy]) -> list[Finding];

def check_hooks(
    `root: Path, prober: _Prober, path_copies: list[Copy]
) -> tuple[list[dict[str, Any]], list[Finding]];

def check_path_copies(prober: _Prober) -> tuple[list[Copy], list[Finding]];

glob run_default_: any;

with entry {
    run_default_ = _run_quietly;
}

"""Run every check and return the report. Reads only."""
def diagnose(
    repo_root: Path, run: Callable[[list[str], Path | None], str | None] = run_default_
) -> Report;

def render(`report: Report) -> str;

"""Print the report and return the exit code: 0 healthy, 1 not."""
def run_doctor(repo_root: Path, *, as_json: bool = False) -> int;
