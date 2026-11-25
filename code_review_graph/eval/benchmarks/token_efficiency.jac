"""Token efficiency benchmark: compares naive, standard, and graph-based token counts.

Failure semantics: if ``get_review_context`` throws, the row is recorded with
``status="error"`` and empty metric fields. It stays in the CSV for forensics
but is excluded from every aggregate — a failed tool call is not a
measurement. (Previously a failure silently produced ``graph_tokens=0`` and
``ratio = naive / 1``, inflating the results.)
"""

import from code_review_graph._lazy { lazy }

import importlib;

import from __future__ { annotations }

import json;

import logging;

import statistics;

import subprocess;

import from pathlib { Path }

glob logger: any;

with entry {
    logger = logging.getLogger(__name__);
}

"""Approximate token count (1 token ~ 4 chars)."""
def _count_tokens(text: str) -> int;

"""Get list of changed files for a commit."""
def _get_changed_files(repo_path: Path, sha: str) -> list[str];

"""Count tokens from full file contents (naive approach)."""
def _count_file_tokens(repo_path: Path, files: list[str]) -> int;

"""Count tokens from git diff output (standard approach)."""
def _count_diff_tokens(repo_path: Path, sha: str) -> int;

"""Run token efficiency benchmark."""
def run(repo_path: Path, store, config: dict) -> list[dict];

"""Aggregate token-efficiency rows, excluding failed measurements.

    Rows with ``status != "ok"`` stay in the CSV for forensics but must not
    contribute to any headline number.
    """
def aggregate(results: list[dict]) -> dict;
