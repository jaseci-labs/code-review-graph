"""Search quality benchmark: measures search result ranking via MRR."""

import importlib;

import from __future__ { annotations }

import logging;

import sqlite3;

import from pathlib { Path }

glob logger: any;

with entry {
    logger = logging.getLogger(__name__);
}

"""Run search quality benchmark."""
def run(repo_path: Path, store, config: dict) -> list[dict];
