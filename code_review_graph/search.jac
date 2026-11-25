import from __future__ { annotations }

import importlib, operator, logging, re, sqlite3;

import from collections.abc { Sequence }

import from pathlib { Path }

import from typing { Any, NamedTuple, Optional }

glob logger: any = logging.getLogger(__name__);

glob _UNSEARCHED_KIND: any = "Output";

glob _FTS_COLUMN_WEIGHTS: dict[str, float] = {
    "name": 10.0,
    "qualified_name": 6.0,
    "file_path": 1.0,
    "signature": 2.0,
    "docstring": 1.5,
    "name_tokens": 4.0,
};

glob _FTS_DEFAULT_WEIGHT: any = 1.0;

glob _EXACT_NAME_BOOST: any = 4.0;

glob _EXACT_SYMBOL_BOOST: any = 3.0;

glob _NAME_COVERAGE_BOOST: any = 1.0;

glob _NAME_EXACT_COVERAGE_BOOST: any = 2.0;

glob _TEST_RANK_PENALTY: any = 0.4;

glob _TEST_INTENT_WORDS: any = frozenset(
    ("test tests tested testing spec specs fixture fixtures mock mocks stub stubs coverage").split()
);

glob _JSON_RANK_PENALTY: any = 0.25;

glob _FTS_STATE_TABLE: any = NODES_FTS_STATE_TABLE;

glob _FTS_STATE_METADATA_KEY: any = FTS_STATE_METADATA_KEY;

glob _FTS_STATE_VERSION: any = FTS_STATE_VERSION;

glob _FTS_COLUMN_SQL: any = ", ".join(NODES_FTS_COLUMNS);

glob _FTS_COLUMN_PLACEHOLDERS: any = ", ".join("?" * len(NODES_FTS_COLUMNS));

glob _FTS_DELTA_MAX_RATIO: any = 0.35;

glob _FTS_DELTA_MIN_ROWS: any = 500;

glob _FTS_SQL_BATCH: any = 450;

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

glob _EXACT_IDENT_QUERY_RE: any = re.compile("^[A-Za-z_][\\w.]*$");

glob _DOTTED_IDENT_RE: any = re.compile("\\b[A-Za-z_][\\w]*(?:\\.[A-Za-z_][\\w]*)+\\b");

glob _SNAKE_IDENT_RE: any = re.compile("\\b[a-z][a-z0-9]*(?:_[a-z0-9]+)+\\b");

glob _PASCAL_IDENT_RE: any = re.compile("\\b[A-Z][a-z0-9]+(?:[A-Z][a-z0-9]+)+\\b");

def extract_query_identifiers(query: str) -> list[str];
def detect_query_kind_boost(query: str) -> dict[str, Any];
def rrf_merge(*result_lists_: list[tuple[int, float]], k: int = 60) -> list[tuple[int, float]];

glob _EXPLICIT_PHRASE_RE: any = re.compile("\"([^\"]*)\"");

glob _HAS_ALNUM_RE: any = re.compile("[0-9A-Za-z]");

glob _MIN_PREFIX_ALNUM: any = 3;

glob _MAX_FTS_TERMS: any = 12;

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
