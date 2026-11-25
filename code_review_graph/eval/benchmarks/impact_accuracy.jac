import from __future__ { annotations }

import importlib;

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

def _get_changed_files(repo_path: Path, sha: str) -> list[str];
def _files_from_analysis(analysis: dict) -> set[str];
def _graph_neighbor_files(store, files: list[str]) -> set[str];

def _base_row(repo: str, sha: str, mode: str, seed: str) -> dict;

def _scored_row(
    repo: str, sha: str, mode: str, seed: str, predicted: set[str], actual: set[str]
) -> dict;

def _error_row(repo: str, sha: str, mode: str, seed: str, exc: Exception) -> dict;
def run(repo_path: Path, store, config: dict) -> list[dict];
def aggregate(results: list[dict]) -> dict;
