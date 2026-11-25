import from __future__ { annotations }

import importlib;

import logging;

import sqlite3;

import subprocess;

import from typing { Any }

glob logger: any;

with entry {
    logger = logging.getLogger(__name__);
}

def _not_ready(reason: str, summary: str) -> dict[str, Any];
def get_minimal_context(
    task: str = "",
    changed_files: list[str] | None = None,
    repo_root: str | None = None,
    base: str = "HEAD~1",
) -> dict[str, Any];
