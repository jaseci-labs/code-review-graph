"""Schema migration framework for the code-review-graph SQLite database.

Manages incremental schema changes via versioned migration functions.
Each migration is idempotent (uses IF NOT EXISTS / column existence checks).

Idempotence used to be "check, then act", which is only safe for one process.
A watcher child, a PostToolUse hook and a hand-run ``build`` can all open the
same fresh ``graph.db`` at once, and every one of them runs the pending
migrations from :meth:`GraphStore.__init__`.  Two openers could both see a
column missing, both issue the ``ALTER``, and the loser died with
``duplicate column name: signature`` before its caller had a database at all.

The check is therefore a fast path only.  The act itself is now idempotent at
the SQL level: :func:`_apply` treats "already exists" as success, so whichever
opener loses the race simply adopts the winner's schema.  Contention on the
write lock is retried rather than raised, because a migration is a handful of
statements and the other process is about to finish.
"""

import operator;

import from __future__ { annotations }

import contextlib;

import contextvars;

import logging;

import os;

import sqlite3;

import time;

import from typing { Callable, Iterator }

glob logger: any;

glob _progress_level: contextvars.ContextVar[int];

glob _MAX_ATTEMPTS: any;

glob _RETRY_BASE_SECONDS: any;

glob _ALREADY_APPLIED: any;

glob _CONTENDED: any;

glob _KNOWN_TABLES: any;

glob NODES_FTS_COLUMNS: tuple[str, ...];

glob NODES_FTS_DDL: any;

glob NODES_FTS_STATE_TABLE: any;

glob FTS_STATE_METADATA_KEY: any;

glob FTS_STATE_VERSION: any;

glob _BACKFILL_BATCH: any;

glob TARGET_RESOLUTION_KINDS: any;

glob _TARGET_RESOLUTION_TEMPLATE: any;

glob _ALLOWED_EDGE_ALIASES: any;

glob TARGET_RESOLUTION_EXPR: any;

glob MIGRATIONS: dict[int, Callable[[sqlite3.Connection], None]];

glob LATEST_VERSION: any;

glob _REBUILD_AFTER: frozenset[int];

glob _REBUILD_HINT: any;

with entry {
    logger = logging.getLogger(__name__);
    _progress_level = contextvars.ContextVar("crg_migration_progress_level", default=logging.INFO);
}

"""Log one migration progress line at the current progress level."""
def _progress(msg: str, *args_: object) -> None;

with entry {
    _MAX_ATTEMPTS = 5;
    _RETRY_BASE_SECONDS = 0.05;
    _ALREADY_APPLIED = ("duplicate column name", "already exists");
    _CONTENDED = (
        "database is locked",
        "database table is locked",
        "database schema is locked",
        "cannot start a transaction within a transaction",
    );
}

def _matches(exc: sqlite3.Error, needles: tuple[str, ...]) -> bool;

"""Execute one DDL statement, tolerating a peer that already applied it.

    Returns True when this process made the change, False when it found the
    change already present.  Any other error is re-raised: a migration that
    fails for a real reason must still stop the opener.
    """
def _apply(conn: sqlite3.Connection, sql: str, *, what: str) -> bool;

"""Run the block as one write that no other opener can come between.

    A peer that wants to write waits on SQLite's busy timeout until this
    commits. Inside a transaction the caller already owns, it adds nothing.
    """
@contextlib.contextmanager
def _write_lock_held(conn: sqlite3.Connection) -> Generator[any, any, any];

"""Read the current schema version from the metadata table.

    Returns:
        int: The schema version (0 if metadata table doesn't exist, 1 if not set).
    """
def get_schema_version(conn: sqlite3.Connection) -> int;

"""Set the schema version in the metadata table."""
def _set_schema_version(conn: sqlite3.Connection, version: int) -> None;

with entry {
    _KNOWN_TABLES = frozenset({
        "nodes",
        "edges",
        "metadata",
        "communities",
        "flows",
        "flow_memberships",
        "nodes_fts",
        "nodes_fts_state",
    });
}

"""Check if a column exists in a table."""
def _has_column(conn: sqlite3.Connection, table: str, column: str) -> bool;

"""Check if a table exists."""
def _table_exists(conn: sqlite3.Connection, table: str) -> bool;

with entry {
    NODES_FTS_COLUMNS = (
        "name",
        "qualified_name",
        "file_path",
        "signature",
        "docstring",
        "name_tokens",
    );
    NODES_FTS_DDL = "\nCREATE VIRTUAL TABLE nodes_fts USING fts5(\n    {columns},\n    content='nodes', content_rowid='rowid',\n    tokenize='porter unicode61'\n)\n".format(
        columns=", ".join(NODES_FTS_COLUMNS)
    );
    NODES_FTS_STATE_TABLE = "nodes_fts_state";
    FTS_STATE_METADATA_KEY = "fts_state_synced";
    FTS_STATE_VERSION = "2";
}

"""Create or widen ``nodes_fts_state`` to mirror every indexed column.

    Idempotent, and safe on a database created by any earlier version: the
    table is created when missing and otherwise gains only the columns it
    does not already have.
    """
def ensure_nodes_fts_state(conn: sqlite3.Connection) -> None;

with entry {
    _BACKFILL_BATCH = 5000;
}

"""v2: Add signature column to nodes table."""
def _migrate_v2(conn: sqlite3.Connection) -> None;

"""v3: Create flows and flow_memberships tables."""
def _migrate_v3(conn: sqlite3.Connection) -> None;

"""v4: Create communities table, add community_id to nodes."""
def _migrate_v4(conn: sqlite3.Connection) -> None;

"""v5: Create FTS5 virtual table for nodes."""
def _migrate_v5(conn: sqlite3.Connection) -> None;

"""v6: Add pre-computed summary tables for token-efficient queries."""
def _migrate_v6(conn: sqlite3.Connection) -> None;

"""v7: Add compound edge indexes for summary and risk queries."""
def _migrate_v7(conn: sqlite3.Connection) -> None;

"""v8: Add composite index on edges for upsert_edge performance.

    ``edges.line`` comes from the base schema, which ``_init_schema`` applies
    before the migrations run.  A database that predates it (or one built by
    something other than ``GraphStore``) would otherwise fail the whole open
    with ``no such column: line`` — an index is a speed-up, never a reason to
    refuse to open the graph.
    """
def _migrate_v8(conn: sqlite3.Connection) -> None;

"""v9: Add confidence scoring to edges."""
def _migrate_v9(conn: sqlite3.Connection) -> None;

"""v10: Add the indexed ``nodes.symbol`` column used by tail lookups.

    ``symbol`` holds the portion of ``qualified_name`` after the first ``::``.
    Storing it lets a dotted-target lookup be an indexed equality test; the
    previous ``substr(qualified_name, -n)`` predicate could not use any index
    and scanned the whole table on every dotted symbol query.
    """
def _migrate_v10(conn: sqlite3.Connection) -> None;

with entry {
    TARGET_RESOLUTION_KINDS = ("CALLS", "REFERENCES");

    _TARGET_RESOLUTION_TEMPLATE = "CASE WHEN EXISTS (SELECT 1 FROM nodes crg_res_n WHERE crg_res_n.qualified_name = {alias}.target_qualified) THEN 'direct' ELSE 'unresolved' END";
    _ALLOWED_EDGE_ALIASES = frozenset({"edges", "e"});
}

"""Return the classification expression bound to one ``edges`` alias."""
def target_resolution_expr(alias: str = "edges") -> str;

with entry {
    TARGET_RESOLUTION_EXPR = target_resolution_expr();
}

"""v11: Add the indexed ``edges.target_resolution`` column.

    A CALLS edge either points at an indexed node or carries a bare name that
    the read path can only match by name, subject to a receiver-evidence
    check. Both kinds lived in one undifferentiated pile, so an answer could
    not say how much of itself was certain. Storing the classification makes
    the split an indexed group-by rather than a scan that re-derives it, and
    lets impact analysis exclude the guessed hops.

    ``IMPORTS_FROM`` and the other kinds keep NULL: their targets are file
    paths and module names, for which "unresolved" would be a false claim.
    """
def _migrate_v11(conn: sqlite3.Connection) -> None;

"""v12: Add ``nodes_fts_state``, the mirror of what ``nodes_fts`` holds.

    ``nodes_fts`` is an external content table, so deleting one of its
    entries requires the column values that were indexed, and those are
    gone once the node row is deleted.  Mirroring the indexed text here lets
    an incremental update rewrite just the rows that changed instead of
    dropping and repopulating the whole index.  The table starts empty; the
    first index sync after the migration fills it with a full rebuild.
    """
def _migrate_v12(conn: sqlite3.Connection) -> None;

"""v13: index node docstrings and identifier word splits in FTS5.

    ``nodes.extra['docstring']`` was already extracted by the parser and fed
    to the embedding text builder, but the FTS5 index could not see it: an
    external-content table can only index real columns of its content table.
    Two columns are added and backfilled, then ``nodes_fts`` is recreated
    with both so existing graphs gain the prose without a full reparse.

    ``name_tokens`` carries the camelCase/PascalCase splits that the
    ``unicode61`` tokenizer cannot produce (``hashPassword`` is one token to
    it, so ``password`` never matched).

    The v12 index-state mirror is widened to the same two columns and
    refilled from the rebuild this migration just ran, so the incremental
    delta path keeps the values it needs to delete an entry with.
    """
def _migrate_v13(conn: sqlite3.Connection) -> None;

"""v14: invalidate indexed Ruby files so the next update re-keys them.

    Ruby class identities changed. A class declared inside any namespace now
    carries that namespace in ``parent_name``, and its methods qualify against
    the class's own key, so ``Auth::User#to_s`` moves from ``user.rb::User.to_s``
    to ``user.rb::Auth.User.to_s``. Both the compact spelling
    (``class Auth::User``) and the nested one are affected.

    Without this, an incremental ``update`` keeps the old rows for every Ruby
    file whose content has not changed and writes the new shape only for files
    that happen to be touched, leaving one database holding both. Nothing
    reports an error in that state: ``children_of`` simply answers from
    whichever shape a file was last indexed under, so the damage is silent.

    The fix is to clear ``file_hash`` on the Ruby File nodes rather than to
    delete any row. ``get_file_hashes`` reads that column to decide what has
    changed, so an empty hash can never match the file on disk and the next
    update re-parses it and replaces its rows through the normal path.

    Deleting the rows here would work too, and is the obvious reading of
    "force a reparse", but it breaks the invariant that opening a database
    only migrates it: ``test_opening_loses_no_nodes_or_edges`` requires the
    node and edge counts to be identical after open, because nothing has been
    re-parsed yet. Invalidating the hash defers the change to the update that
    does the parsing, which is where the upgrade path already tolerates churn.

    Rewriting the identities in place is not an option either: the namespace
    the new key needs was never recorded, so a rewrite would have to guess it.
    """
def _migrate_v14(conn: sqlite3.Connection) -> None;

"""v15: drop three tables nothing reads and three indexes others cover.

    ``community_summaries``, ``flow_snapshots`` and ``risk_index`` were rewritten
    on every full postprocess and read by nothing, and their rows kept pointing
    at deleted nodes.

    ``idx_nodes_qualified`` repeats the UNIQUE index on ``nodes.qualified_name``.
    ``idx_edges_source`` and ``idx_edges_target`` are the leading columns of
    ``idx_edges_source_kind`` and ``idx_edges_target_kind``, which serve the same
    lookups.

    Dropping puts the pages on the free list, where later writes reuse them. The
    file itself only shrinks on VACUUM, left out on purpose: it rewrites the whole
    database while the opener waits and needs twice the disk space. ``IF EXISTS``
    lets a migration cut off half way finish on the next open.
    """
def _migrate_v15(conn: sqlite3.Connection) -> None;

with entry {
    MIGRATIONS = {
        2: _migrate_v2,
        3: _migrate_v3,
        4: _migrate_v4,
        5: _migrate_v5,
        6: _migrate_v6,
        7: _migrate_v7,
        8: _migrate_v8,
        9: _migrate_v9,
        10: _migrate_v10,
        11: _migrate_v11,
        12: _migrate_v12,
        13: _migrate_v13,
        14: _migrate_v14,
        15: _migrate_v15,
    };

    LATEST_VERSION = max(MIGRATIONS.keys());
    _REBUILD_AFTER = frozenset({15});

    _REBUILD_HINT = "Graph upgraded to schema v%d. Run code-review-graph build once (and code-review-graph embed if you use embeddings): an update parses only changed files, so files this release can newly read stay out until then.";
}

"""Apply a single migration, surviving a peer doing the same thing.

    Two kinds of failure are not failures here:

    * the change is already present, because another opener won the race —
      :func:`_apply` absorbs those at the statement that hits them, so the
      rest of the migration still runs and nothing is half-applied;
    * the write lock is held, because another opener is mid-migration — the
      attempt is retried, by which time the peer has committed and every
      statement takes the "already present" path.

    Anything else is re-raised.
    """
def _run_one(conn: sqlite3.Connection, version: int) -> None;

"""True for a graph that was just created and holds nothing yet.

    ``GraphStore`` creates the base schema and stamps it version 1 before
    calling :func:`run_migrations`, so a new file reaches here at version 1
    with an empty ``nodes`` table. An old version-1 graph with no nodes in it
    is the same thing in every way that matters to the user.
    """
def _is_new_database(conn: sqlite3.Connection, current: int) -> bool;

"""Run all pending migrations in order.

    Safe to run from several processes at once: each statement tolerates a
    peer having already applied it, and lock contention is retried rather
    than raised.  The schema_version metadata entry is updated after each
    successful migration.

    On a brand-new database the per-migration lines log at DEBUG and one
    INFO line says the graph was created; an upgrade still logs each step.
    """
def run_migrations(conn: sqlite3.Connection) -> None;
