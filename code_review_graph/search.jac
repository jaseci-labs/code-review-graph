import from __future__ { annotations }

import importlib;

import operator;

import logging;

import re;

import sqlite3;

import from collections.abc { Sequence }

import from pathlib { Path }

import from typing { Any, NamedTuple, Optional }

glob logger: any;

glob _UNSEARCHED_KIND: any;

glob _FTS_COLUMN_WEIGHTS: dict[str, float];

glob _FTS_DEFAULT_WEIGHT: any;

glob _EXACT_NAME_BOOST: any;

glob _EXACT_SYMBOL_BOOST: any;

glob _NAME_COVERAGE_BOOST: any;

glob _NAME_EXACT_COVERAGE_BOOST: any;

glob _TEST_RANK_PENALTY: any;

glob _TEST_INTENT_WORDS: any;

glob _JSON_RANK_PENALTY: any;

glob _FTS_STATE_TABLE: any;

glob _FTS_STATE_METADATA_KEY: any;

glob _FTS_STATE_VERSION: any;

glob _FTS_COLUMN_SQL: any;

glob _FTS_COLUMN_PLACEHOLDERS: any;

glob _FTS_DELTA_MAX_RATIO: any;

glob _FTS_DELTA_MIN_ROWS: any;

glob _FTS_SQL_BATCH: any;

glob _EXACT_IDENT_QUERY_RE: any;

glob _DOTTED_IDENT_RE: any;

glob _SNAKE_IDENT_RE: any;

glob _PASCAL_IDENT_RE: any;

glob _EXPLICIT_PHRASE_RE: any;

glob _HAS_ALNUM_RE: any;

glob _MIN_PREFIX_ALNUM: any;

glob _MAX_FTS_TERMS: any;

with entry {
    logger = logging.getLogger(__name__);
    _UNSEARCHED_KIND = "Output";
    _FTS_COLUMN_WEIGHTS = {
        "name": 10.0,
        "qualified_name": 6.0,
        "file_path": 1.0,
        "signature": 2.0,
        "docstring": 1.5,
        "name_tokens": 4.0,
    };
    _FTS_DEFAULT_WEIGHT = 1.0;
    _EXACT_NAME_BOOST = 4.0;
    _EXACT_SYMBOL_BOOST = 3.0;
    _NAME_COVERAGE_BOOST = 1.0;
    _NAME_EXACT_COVERAGE_BOOST = 2.0;
    _TEST_RANK_PENALTY = 0.4;
    _TEST_INTENT_WORDS = frozenset({
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
    _JSON_RANK_PENALTY = 0.25;
    _FTS_STATE_TABLE = NODES_FTS_STATE_TABLE;
    _FTS_STATE_METADATA_KEY = FTS_STATE_METADATA_KEY;
    _FTS_STATE_VERSION = FTS_STATE_VERSION;
    _FTS_COLUMN_SQL = ", ".join(NODES_FTS_COLUMNS);
    _FTS_COLUMN_PLACEHOLDERS = ", ".join("?" * len(NODES_FTS_COLUMNS));
    _FTS_DELTA_MAX_RATIO = 0.35;
    _FTS_DELTA_MIN_ROWS = 500;
    _FTS_SQL_BATCH = 450;
}

def _ensure_fts_state_table(conn: sqlite3.Connection);

def _table_exists(conn: sqlite3.Connection, name: str) -> bool;
def rebuild_fts_index(store: GraphStore) -> int;
def _stored_path_hints(file_paths: Sequence[str] | None) -> list[str];

def _batched(values: list[Any]) -> list[list[Any]];
def _collect_delta_rowids(conn: sqlite3.Connection, paths: list[str]) -> set[int];
def _apply_fts_delta(conn: sqlite3.Connection, rowids: list[int]) -> tuple[int, int];
def update_fts_index(
    store: GraphStore,
    file_paths: Sequence[str] | None = None,
    *,
    _out_mode: Optional[list[str]] = None,
) -> int;

with entry {
    _EXACT_IDENT_QUERY_RE = re.compile("^[A-Za-z_][\\w.]*$");
    _DOTTED_IDENT_RE = re.compile("\\b[A-Za-z_][\\w]*(?:\\.[A-Za-z_][\\w]*)+\\b");
    _SNAKE_IDENT_RE = re.compile("\\b[a-z][a-z0-9]*(?:_[a-z0-9]+)+\\b");
    _PASCAL_IDENT_RE = re.compile("\\b[A-Z][a-z0-9]+(?:[A-Z][a-z0-9]+)+\\b");
}

def extract_query_identifiers(query: str) -> list[str];
def detect_query_kind_boost(query: str) -> dict[str, Any];
def rrf_merge(*result_lists_: list[tuple[int, float]], k: int = 60) -> list[tuple[int, float]];

with entry {
    _EXPLICIT_PHRASE_RE = re.compile("\"([^\"]*)\"");
    _HAS_ALNUM_RE = re.compile("[0-9A-Za-z]");
    _MIN_PREFIX_ALNUM = 3;
    _MAX_FTS_TERMS = 12;
}

def _quote_term(text: str) -> str;

def _alnum_count(text: str) -> int;

class _QueryTerm(NamedTuple) {
    has key: str;

    has expression: str;

    has is_phrase: bool;
}

def _split_query_terms(query: str) -> list[_QueryTerm];
def _rarity_key(term: _QueryTerm, position: int) -> tuple[int, int, int];
def _cap_terms(terms: list[_QueryTerm]) -> list[_QueryTerm];
def build_fts_queries(query: str) -> list[str];
def _covered_word_count(query_words: set[str], symbol_words: set[str]) -> int;
def _fts_column_weights(conn: sqlite3.Connection) -> str;
def _fts_search(
    conn: sqlite3.Connection,
    query: str,
    limit: int = 50,
    kind: str | None = None,
    skip_json: bool = False,
) -> list[tuple[int, float]];
def _embedding_search(
    store: GraphStore,
    query: str,
    limit: int = 50,
    model: str | None = None,
    provider: str | None = None,
    kind: str | None = None,
) -> list[tuple[int, float]];
def _keyword_search(
    conn: sqlite3.Connection, query: str, limit: int = 50, kind: str | None = None
) -> list[tuple[int, float]];
def _has_json_intent(query: str, kind: Optional[str]) -> bool;
def _fts_search_past_json(
    conn: sqlite3.Connection,
    query: str,
    results: list[tuple[int, float]],
    limit: int,
    kind: Optional[str] = None,
) -> list[tuple[int, float]];
def hybrid_search(
    store: GraphStore,
    query: str,
    kind: Optional[str] = None,
    limit: int = 20,
    context_files: Optional[list[str]] = None,
    model: Optional[str] = None,
    provider: Optional[str] = None,
    _out_mode: Optional[list[str]] = None,
    repo_root: Optional[str | Path] = None,
    _out_ids: Optional[list[int]] = None,
) -> list[dict[str, Any]];
