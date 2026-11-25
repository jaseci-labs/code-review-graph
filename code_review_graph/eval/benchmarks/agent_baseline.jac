"""Agent baseline benchmark: grep-and-read-top-k versus a graph query.

The whole-corpus baseline in the standalone token benchmark is an upper
bound no real agent pays: a competent agent greps for identifiers from the
question and reads only the best-matching files. This benchmark measures
that realistic baseline:

1. Derive search terms from the question (identifier-shaped tokens via
   ``search.extract_query_identifiers`` plus plain keywords).
2. Pure-python grep over the corpus (no external ``rg``/``grep`` binary),
   ranking files by total case-insensitive match count.
3. Read the top-k files (k=3) and token-count them with the chars/4 utility
   (``token_benchmark.estimate_tokens``) as ``baseline_tokens``.
4. Compare against the graph-query cost for the same question — hybrid
   search hits plus one hop of neighbor edges, the same accounting used by
   ``code_review_graph/token_benchmark.py``.

Questions come from ``agent_questions:`` in the repo config, falling back to
the ``search_queries`` query strings when absent.

Failure semantics match the other benchmarks: a thrown search is recorded
with ``status="error"`` and excluded from aggregates; rows where either side
of the ratio is zero get ``status="no_graph_results"`` /
``status="no_baseline_match"`` and are likewise excluded.
"""

import importlib;

import from __future__ { annotations }

import logging;

import statistics;

import from collections.abc { Iterator }

import from pathlib { Path }

glob logger: any;

glob DEFAULT_TOP_K: any;

glob _TEST_FILE_PENALTY: any;

glob _TEST_INTENT_TERMS: any;

glob _SOURCE_EXTS: any;

glob _SKIP_DIRS: any;

glob _STOPWORDS: any;

with entry {
    logger = logging.getLogger(__name__);

    DEFAULT_TOP_K = 3;
    _TEST_FILE_PENALTY = 0.4;
    _TEST_INTENT_TERMS = frozenset({
        "test",
        "tests",
        "tested",
        "testing",
        "spec",
        "specs",
        "fixture",
        "fixtures",
        "mock",
        "mocks",
        "stub",
        "stubs",
        "coverage",
    });

    _SOURCE_EXTS = (
        ".py",
        ".js",
        ".ts",
        ".tsx",
        ".go",
        ".rs",
        ".java",
        ".c",
        ".cpp",
        ".h",
        ".rb",
        ".php",
        ".swift",
        ".kt",
    );

    _SKIP_DIRS = {
        ".git",
        ".hg",
        ".svn",
        "node_modules",
        "__pycache__",
        ".code-review-graph",
        ".venv",
        "venv",
        "dist",
        "build",
    };

    _STOPWORDS = {
        "how",
        "does",
        "do",
        "the",
        "a",
        "an",
        "is",
        "are",
        "was",
        "what",
        "where",
        "when",
        "which",
        "who",
        "why",
        "and",
        "or",
        "in",
        "on",
        "of",
        "to",
        "for",
        "with",
        "via",
        "into",
        "from",
        "this",
        "that",
        "it",
        "its",
    };
}

"""Derive lowercase grep terms: identifiers first, then plain keywords.

    Identifier-shaped tokens (``Client.request``, ``get_users``, ``APIRoute``)
    are extracted via ``search.extract_query_identifiers``; remaining words of
    3+ characters that are not stopwords are appended. Order is deterministic.
    """
def derive_search_terms(question: str) -> list[str];

"""Yield source files under *repo_path*, skipping vendored/VCS dirs."""
def iter_source_files(repo_path: Path) -> Generator[any, any, any];

glob k_default_: any;

with entry {
    k_default_ = DEFAULT_TOP_K;
}

"""Rank source files by total case-insensitive term matches; take top-k.

    Pure python — no external grep/rg dependency. Deterministic: ties break
    on the relative path. Files with zero matches are dropped.

    Test files are down-weighted by :data:`_TEST_FILE_PENALTY` unless the
    question is about tests. A test names a symbol far more often than the
    one place it is defined, so raw match count puts the whole test suite
    above the implementation; left uncorrected this benchmark would compare
    the graph against a grep nobody would accept. The graph's own search
    carries the same correction
    (``search._TEST_RANK_PENALTY``), so both sides are ranked on the same
    footing.
    """
def grep_rank(repo_path: Path, terms: list[str], k: int = k_default_) -> list[tuple[str, int]];

"""Run the agent baseline benchmark for one repo."""
def run(repo_path: Path, store, config: dict) -> list[dict];

"""Aggregate over rows where both sides of the comparison exist."""
def aggregate(results: list[dict]) -> dict;
