import from __future__ { annotations }

import importlib, json, logging, statistics, subprocess;

import from pathlib { Path }

glob logger: any = logging.getLogger(__name__);

def _count_tokens(text: str) -> int;
def _get_changed_files(repo_path: Path, sha: str) -> list[str];
def _count_file_tokens(repo_path: Path, files: list[str]) -> int;
def _count_diff_tokens(repo_path: Path, sha: str) -> int;
def run(repo_path: Path, store, config: dict) -> list[dict];
def aggregate(results: list[dict]) -> dict;
