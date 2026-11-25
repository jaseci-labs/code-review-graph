"""Hybrid search engine combining FTS5 (BM25) and vector embeddings.

Uses Reciprocal Rank Fusion (RRF) to merge results from full-text search
and semantic similarity, with query-aware kind boosting and context-file
boosting for relevance tuning.
"""

import operator;

import from __future__ { annotations }

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

"""Create the index-state mirror, or widen one that predates a column."""
def _ensure_fts_state_table(conn: sqlite3.Connection) -> None;

def _table_exists(conn: sqlite3.Connection, name: str) -> bool;

"""Rebuild the FTS5 index from the nodes table.

    Checks whether the ``nodes_fts`` virtual table exists, clears it, then
    repopulates it from every row in ``nodes``.

    Returns:
        Number of rows indexed.
    """
def rebuild_fts_index(store: GraphStore) -> int;

"""Normalise caller-supplied paths to the spelling stored in ``nodes``."""
def _stored_path_hints(file_paths: Sequence[str] | None) -> list[str];

def _batched(values: list[Any]) -> list[list[Any]];

"""Return every rowid whose index entry has to be rewritten.

    Two of the three sources run whatever the caller passed, because they
    are what keeps the index honest: a node with no index entry would be
    unfindable, and an index entry with no node is a phantom hit.  The
    third narrows the rewrite to the files the caller named; without a
    hint it compares the indexed text against the nodes table instead.
    """
def _collect_delta_rowids(conn: sqlite3.Connection, paths: list[str]) -> set[int];

"""Re-sync *rowids* in the index, one batch at a time.

    Deletes come first within a batch: a rowid whose text changed is present
    on both sides, and inserting before deleting would index it twice.
    """
def _apply_fts_delta(conn: sqlite3.Connection, rowids: list[int]) -> tuple[int, int];

"""Bring the FTS5 index in step with ``nodes`` without a full rebuild.

    Rewrites only the entries that changed: the rows of the files in
    *file_paths* plus any row that drifted out of sync.  Falls back to
    :func:`rebuild_fts_index` when the index state is unusable (a database
    that predates it, or one whose state was cleared) or when so much of the
    graph moved that a rebuild is the cheaper way to get there.

    Args:
        store: An open GraphStore.
        file_paths: Files whose rows changed, in any path spelling. Omitting
            them is safe: the drift comparison then covers the whole table.
        _out_mode: Optional output list; a single ``"delta"`` or
            ``"rebuild"`` is appended to say which path ran.

    Returns:
        Number of rows the index now covers.
    """
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

"""Pull out identifier-shaped tokens from anywhere in a query.

    Catches dotted forms (``Context.Next``), snake_case (``get_dependant``),
    and CamelCase (``APIRoute``) even when they're embedded in a natural-
    language sentence. Used to boost search hits whose qualified_name
    contains any of these tokens, so an LLM asking "Who advances the gin
    middleware chain via Context.Next" lands on ``Context.Next`` instead of
    the bare ``Context`` class.
    """
def extract_query_identifiers(query: str) -> list[str];

"""Detect query patterns and return per-node boost multipliers.

    Heuristics:
    - PascalCase queries (e.g. ``MyClass``) boost Class/Type by 1.5x
    - snake_case queries (e.g. ``get_users``) boost Function by 1.5x
    - Queries containing ``.`` boost qualified name matches by 2.0x
    - Identifier-shaped tokens *anywhere* in the query (dotted, snake_case,
      CamelCase) boost results whose qualified_name contains them by 2.0x.
      See ``extract_query_identifiers``.
    - A query that is *only* an identifier names one symbol, so the node
      whose name is exactly that identifier is boosted hardest. This is what
      keeps ``_sanitize_name`` first now that prefix matching widens the
      candidate set and docstrings that merely mention a symbol are indexed.

    Returns:
        Dict whose keys are either node kind strings (mapped to float
        multipliers) or one of the special keys ``_qualified``,
        ``_qualified_identifiers``, ``_exact_name``.
    """
def detect_query_kind_boost(query: str) -> dict[str, Any];

"""Merge multiple ranked result lists using Reciprocal Rank Fusion.

    Each input list contains ``(id, score)`` tuples, ordered by score
    descending. The RRF score for each item is the sum of
    ``1 / (k + rank + 1)`` across all lists it appears in, where rank is
    the 0-based position.

    Args:
        *result_lists: Variable number of ranked result lists.
        k: RRF constant (default 60). Higher values reduce the impact of
           rank differences.

    Returns:
        Merged list of ``(id, rrf_score)`` tuples sorted by score descending.
    """
def rrf_merge(*result_lists_: list[tuple[int, float]], k: int = 60) -> list[tuple[int, float]];

with entry {
    _EXPLICIT_PHRASE_RE = re.compile("\"([^\"]*)\"");
    _HAS_ALNUM_RE = re.compile("[0-9A-Za-z]");
    _MIN_PREFIX_ALNUM = 3;
    _MAX_FTS_TERMS = 12;
}

"""Return *text* as a single FTS5 string, with inner quotes doubled.

    Quoting is what keeps the term a term: it neutralizes the operators
    (``AND``/``OR``/``NOT``/``NEAR``), the column filter ``col:``, the
    initial-token ``^``, parentheses and ``*`` that a user may legitimately
    have typed as part of what they are looking for.
    """
def _quote_term(text: str) -> str;

def _alnum_count(text: str) -> int;

"""One term of a MATCH expression, with what is needed to rank it."""
class _QueryTerm(NamedTuple) {
    has key: str;

    has expression: str;

    has is_phrase: bool;
}

"""Split *query* into the distinct terms a MATCH expression may carry.

    Explicit phrases come first, then the loose tokens, each in the order
    typed. Terms that repeat are dropped after their first occurrence:
    ``bm25()`` already weights a term by its frequency in the *document*, so
    repeating it in the query buys no ranking signal and costs one more
    doclist read per matching row. Comparison is case-insensitive because
    the index is.
    """
def _split_query_terms(query: str) -> list[_QueryTerm];

"""Sort key putting the term most worth keeping first.

    A phrase the user quoted is always kept: it is both the most selective
    kind of term and an explicit request. Loose tokens are ordered by length,
    descending. Across natural language the commonest words are the shortest
    ones, so the long token is the rarer one and the one that carries what
    the question is about; the short ones are the scaffolding ("how does the
    ... so that it can ...") that a prose question is mostly made of.

    Rarity measured against the index itself was tried instead and measured
    worse -- see the module docstring of ``tests/test_search_quality.py``.
    An index over a repository holds every node's file path and qualified
    name, so this project's own words ("graph", "search", "parser") are the
    commonest terms in it while "today" and "whether" are rare. Index rarity
    therefore drops exactly the words that name the answer.

    Position breaks ties, so the choice never depends on set ordering.
    """
def _rarity_key(term: _QueryTerm, position: int) -> tuple[int, int, int];

"""Reduce *terms* to at most :data:`_MAX_FTS_TERMS`, keeping the rarest.

    Truncating to the first N would keep "how does the" and throw away the
    words that say what is being asked about, so the terms are ranked by
    :func:`_rarity_key` and the survivors are put back in the order they
    were typed.
    """
def _cap_terms(terms: list[_QueryTerm]) -> list[_QueryTerm];

"""Build the FTS5 MATCH expressions to try for *query*, in order.

    The previous implementation wrapped the entire query in one pair of
    double quotes, which made every search an exact-adjacency phrase match:
    ``password hashing`` found nothing unless some node carried those two
    tokens side by side. Instead the query is split into tokens, each token
    is quoted (and given a prefix ``*`` when long enough), and the tokens are
    combined:

    * the first expression ``AND``s the tokens, which is the precise reading
      of a multi-word query;
    * the second ``OR``s them, and is only reached when the ``AND`` finds
      nothing, so recall is widened without ever costing precision.

    A phrase the user typed in double quotes is kept as a phrase, takes no
    prefix, and suppresses the ``OR`` widening: the quotes are a request for
    exactness and are honoured.

    Repeated terms are dropped and the count is capped at
    :data:`_MAX_FTS_TERMS`, because the cost of an expression grows with the
    number of terms in it and a question asked in prose -- exactly what
    token-based matching invites -- would otherwise grow one term per word.
    When the cap bites, the terms kept are the rarest ones rather than the
    first ones typed: see :func:`_rarity_key`.

    Degenerate inputs collapse to an empty list, which the caller treats as
    "FTS has nothing to say" and falls through to the LIKE keyword path:
    an empty query, whitespace, and text with no alphanumeric character at
    all (``...``).

    Returns:
        Zero, one or two FTS5 MATCH expressions.
    """
def build_fts_queries(query: str) -> list[str];

"""Count query words this symbol's own name accounts for.

    A query word counts when a symbol word equals it or starts with it, which
    is the same rule the prefix terms in :func:`build_fts_queries` apply, so
    ``parse`` is accounted for by ``CodeParser``. Words shorter than the
    prefix threshold must match exactly, for the same reason a one or two
    character prefix term is not issued.
    """
def _covered_word_count(query_words: set[str], symbol_words: set[str]) -> int;

"""Return the BM25 weight arguments matching the live nodes_fts shape.

    Read from the table itself rather than hard-coded so an index created by
    an older schema version (no ``docstring``/``name_tokens`` columns) still
    gets a well-formed ``bm25()`` call instead of a wrong-arity error.
    """
def _fts_column_weights(conn: sqlite3.Connection) -> str;

"""Run an FTS5 BM25 search against the nodes_fts table.

    Tries each expression from :func:`build_fts_queries` in turn and returns
    the first non-empty result, so the precise reading of a query wins and
    the widened one is only a fallback. *kind* filters inside the statement, so
    rows of another kind neither use up *limit* nor count as an answer. Without
    *kind*, ``_UNSEARCHED_KIND`` rows are left out there for the same reason.
    With *skip_json*, JSON rows are left out, so an expression that matches
    only JSON falls through as it did before JSON was indexed.

    Returns list of ``(node_id, bm25_score)`` tuples. The BM25 score is
    negated so higher = better (FTS5 returns negative BM25).
    """
def _fts_search(
    conn: sqlite3.Connection,
    query: str,
    limit: int = 50,
    kind: str | None = None,
    skip_json: bool = False,
) -> list[tuple[int, float]];

"""Run a vector similarity search using the embedding store.

    Vectors do not carry a node kind, so with *kind* set every one is ranked
    and the filter runs on that whole list, before *limit* cuts it.

    Returns list of ``(node_id, similarity_score)`` tuples.
    Gracefully returns an empty list if embeddings are not available.
    """
def _embedding_search(
    store: GraphStore,
    query: str,
    limit: int = 50,
    model: str | None = None,
    provider: str | None = None,
    kind: str | None = None,
) -> list[tuple[int, float]];

"""Fall back to simple LIKE keyword matching.

    Each word in the query must match independently (AND logic), and *kind*
    filters before *limit* cuts the rows. Without *kind*, ``_UNSEARCHED_KIND``
    rows are left out before *limit* cuts them.
    Returns ``(node_id, score)`` tuples with a basic relevance score.
    """
def _keyword_search(
    conn: sqlite3.Connection, query: str, limit: int = 50, kind: str | None = None
) -> list[tuple[int, float]];

"""Whether the caller asked for JSON: by kind, a ``$`` path or a file name."""
def _has_json_intent(query: str, kind: Optional[str]) -> bool;

"""Add the best other matches when JSON rows take places in a full window.

    On next-i18next, six ``translation.json`` files filled the window for
    "translation" and pushed ``appWithTranslation`` out of the results. The
    other rows are fetched on their own, up to *limit* of them, and merged in
    by score, so no number of JSON rows ahead of the code can hide it.
    """
def _fts_search_past_json(
    conn: sqlite3.Connection,
    query: str,
    results: list[tuple[int, float]],
    limit: int,
    kind: Optional[str] = None,
) -> list[tuple[int, float]];

"""Hybrid search combining FTS5 BM25 and vector embeddings via RRF.

    Attempts FTS5 + embedding search first, falling back to FTS5-only,
    then keyword LIKE matching if FTS5 is unavailable.

    Args:
        store: The graph store to search.
        query: Search query string.
        kind: Optional node kind filter (e.g. ``"Function"``, ``"Class"``).
        limit: Maximum results to return (default 20).
        context_files: Optional list of file paths. Nodes in these files
            receive a 1.5x score boost.
        _out_mode: Optional output list. If provided, a single string is
            appended indicating which search path(s) contributed:
            ``"hybrid"`` (FTS + embeddings), ``"fts"`` (FTS only),
            ``"semantic"`` (embeddings only), ``"keyword"`` (LIKE fallback),
            or ``"none"`` (empty query, or all search paths returned 0 results).
        _out_ids: Optional output list. If provided, each result's node id is
            appended in order. A result's ``qualified_name`` is cut at 256
            characters, so a caller that must find the node again uses this.

    Returns:
        List of dicts with node metadata and ``score`` field.
    """
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
