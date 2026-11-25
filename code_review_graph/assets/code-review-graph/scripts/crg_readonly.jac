"""Run safe, read-only code-review-graph CLI queries for one repository."""

import from __future__ { annotations }

import argparse;

import os;

import shutil;

import subprocess;

import sys;

import from pathlib { Path }

glob QUERY_PATTERNS: any = (
    "callers_of",
    "references_to",
    "callees_of",
    "imports_of",
    "importers_of",
    "children_of",
    "tests_for",
    "inheritors_of",
    "triggers_of",
    "triggered_by",
    "publishers_of",
    "listeners_of",
    "advises",
    "advised_by",
    "handlers_of",
    "endpoints_for",
    "consumers_of",
    "file_summary",
    "path_to",
);

glob SEARCH_KINDS: any = ("File", "Class", "Function", "Type", "Test");

glob READ_ONLY_COMMANDS: any = {
    "status",
    "search",
    "query",
    "impact",
    "detect-changes",
    "architecture",
    "flows",
    "flow",
    "communities",
    "community",
    "large-functions",
    "refactor",
};

def _resolve_repo(raw: str | None) -> Path;

def _crg_command -> list[str];

def _add_common(parser: argparse.ArgumentParser) -> None;

def _build_parser -> argparse.ArgumentParser;

def _command_args(args: argparse.Namespace, `root: Path) -> list[str];

def main -> int;

with entry:__main__ {
    raise SystemExit(main());
}
