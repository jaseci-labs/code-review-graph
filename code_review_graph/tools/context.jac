"""Tool: get_minimal_context — ultra-compact context for token-efficient workflows."""

import importlib;

import from __future__ { annotations }

import logging;

import sqlite3;

import subprocess;

import from typing { Any }

glob logger: any;

with entry {
    logger = logging.getLogger(__name__);
}

"""Return a compact response that directs callers to initialize the graph."""
def _not_ready(reason: str, summary: str) -> dict[str, Any];

"""Return minimum context an agent needs to start any task (~100 tokens).

    Combines graph stats, top communities, top flows, risk score,
    and suggested next tools into an ultra-compact response.

    Args:
        task: Natural language description of what the agent is doing
              (e.g. "review PR #42", "debug login timeout").
        changed_files: Explicit changed files. Auto-detected from git if None.
        repo_root: Repository root path. Auto-detected if None.
        base: Git ref for diff comparison.

    Returns:
        Compact graph context, or ``status: not_ready`` when the graph is
        missing, empty, or known to have been built at a different Git commit.
    """
def get_minimal_context(
    task: str = "",
    changed_files: list[str] | None = None,
    repo_root: str | None = None,
    base: str = "HEAD~1",
) -> dict[str, Any];
