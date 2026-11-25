"""Impact accuracy benchmark: measures precision/recall of change impact analysis.

Two ground-truth modes are emitted side by side (``ground_truth_mode`` column):

- **graph-derived (circular — upper bound)** — the historical mode. Ground
  truth is the changed files plus files with CALLS/IMPORTS_FROM edges into
  them, i.e. derived from the same graph the predictor traverses. Recall in
  this mode is an upper bound by construction, not independent evidence.
- **co-change (same commit, seed excluded)** — the honest mode. The predictor
  is seeded with a single changed file and graded against the *other* files
  the author actually touched in the same commit. The ground truth comes from
  git history, not from the graph.

Failure semantics: if ``analyze_changes`` throws, the row is recorded with
``status="error"`` and empty metric fields — it stays in the CSV but is
excluded from aggregates. (Previously a failure silently set
``predicted = set(changed)``, guaranteeing a fake recall of 1.0.)
"""

import from code_review_graph._lazy { lazy }

import importlib;

import from __future__ { annotations }

import logging;

import statistics;

import subprocess;

import from pathlib { Path }

glob logger: any;

glob MODE_GRAPH_DERIVED: any;

glob MODE_CO_CHANGE: any;

with entry {
    logger = logging.getLogger(__name__);

    MODE_GRAPH_DERIVED = "graph-derived (circular — upper bound)";
    MODE_CO_CHANGE = "co-change (same commit, seed excluded)";
}

"""Get list of changed files for a commit."""
def _get_changed_files(repo_path: Path, sha: str) -> list[str];

"""Extract predicted file paths from an ``analyze_changes`` result."""
def _files_from_analysis(analysis: dict) -> set[str];

"""Files with CALLS/IMPORTS_FROM edges into any node of *files* (one hop)."""
def _graph_neighbor_files(store, files: list[str]) -> set[str];

def _base_row(repo: str, sha: str, mode: str, seed: str) -> dict;

def _scored_row(
    repo: str, sha: str, mode: str, seed: str, predicted: set[str], actual: set[str]
) -> dict;

def _error_row(repo: str, sha: str, mode: str, seed: str, exc: Exception) -> dict;

"""Run impact accuracy benchmark (both ground-truth modes)."""
def run(repo_path: Path, store, config: dict) -> list[dict];

"""Per-mode means over successful rows only.

    Error/skipped rows stay in the CSV but never contribute to a number.
    """
def aggregate(results: list[dict]) -> dict;
