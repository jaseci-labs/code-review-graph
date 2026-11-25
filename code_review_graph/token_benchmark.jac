"""Token reduction benchmark -- measures graph query efficiency vs naive file reading."""

import from __future__ { annotations }

import logging;

import sqlite3;

import from pathlib { Path }

import from typing { Any }

glob logger: any;

glob _SAMPLE_QUESTIONS: any;

with entry {
    logger = logging.getLogger(__name__);
    _SAMPLE_QUESTIONS = [
        "how does authentication work",
        "what is the main entry point",
        "how are database connections managed",
        "what error handling patterns are used",
        "how do tests verify core functionality",
    ];
}

"""Rough token estimate: ~4 chars per token."""
def estimate_tokens(text: str) -> int;

"""Count tokens in all parseable source files."""
def compute_naive_tokens(repo_root: Path) -> int;

"""Run token reduction benchmark.

    Compares naive full-corpus token cost vs graph query token
    cost for a set of sample questions.

    The default sample questions are natural language and require semantic
    search to match. If no embeddings are present in the graph, ``hybrid_search``
    falls back to FTS5/LIKE matching on node names, which produces no hits for
    questions like "how does authentication work" — every per-question ratio
    becomes 0 and the benchmark silently appears to fail. We log a clear
    warning when that is the case so callers know to run ``embed_graph`` first
    (or to pass keyword-matching questions).
    """
def run_token_benchmark(
    store: GraphStore, repo_root: Path, questions: list[str] | None = None
) -> dict[str, Any];
