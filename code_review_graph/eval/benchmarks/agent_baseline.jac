import from __future__ { annotations }

import importlib;

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

def derive_search_terms(question: str) -> list[str];
def iter_source_files(repo_path: Path) -> Generator[any, any, any];

glob k_default_: any;

with entry {
    k_default_ = DEFAULT_TOP_K;
}

def grep_rank(repo_path: Path, terms: list[str], k: int = k_default_) -> list[tuple[str, int]];
def run(repo_path: Path, store, config: dict) -> list[dict];
def aggregate(results: list[dict]) -> dict;
