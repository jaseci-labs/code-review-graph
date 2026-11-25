"""Memory/feedback loop -- persist Q&A results for graph enrichment."""

import from __future__ { annotations }

import logging;

import re;

import time;

import from pathlib { Path }

import from typing { Any }

glob logger: any;

with entry {
    logger = logging.getLogger(__name__);
}

"""Save a Q&A result as markdown for re-ingestion.

    Args:
        question: The question that was asked.
        answer: The answer/result.
        nodes: Related node qualified names.
        result_type: Type of result (query, review, debug).
        memory_dir: Directory to save to. Defaults to
            <repo>/.code-review-graph/memory/
        repo_root: Repository root for default memory_dir.

    Returns:
        Path to the saved file.
    """
def save_result(
    question: str,
    answer: str,
    nodes: list[str] | None = None,
    result_type: str = "query",
    memory_dir: Path | None = None,
    repo_root: Path | None = None,
) -> Path;

"""List all saved memory files.

    Returns list of dicts with: path, question, type, timestamp.
    """
def list_memories(
    memory_dir: Path | None = None, repo_root: Path | None = None
) -> list[dict[str, Any]];

"""Delete all memory files. Returns count deleted."""
def clear_memories(memory_dir: Path | None = None, repo_root: Path | None = None) -> int;
