import from __future__ { annotations }

import importlib;

import operator;

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

def _progress(msg: str, *args_: object);

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
def _apply(conn: sqlite3.Connection, sql: str, *, what: str) -> bool;
@contextlib.contextmanager
def _write_lock_held(conn: sqlite3.Connection) -> Generator[any, any, any];
def get_schema_version(conn: sqlite3.Connection) -> int;
def _set_schema_version(conn: sqlite3.Connection, version: int);

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

def _has_column(conn: sqlite3.Connection, table: str, column: str) -> bool;
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

def ensure_nodes_fts_state(conn: sqlite3.Connection);

with entry {
    _BACKFILL_BATCH = 5000;
}

def _migrate_v2(conn: sqlite3.Connection);
def _migrate_v3(conn: sqlite3.Connection);
def _migrate_v4(conn: sqlite3.Connection);
def _migrate_v5(conn: sqlite3.Connection);
def _migrate_v6(conn: sqlite3.Connection);
def _migrate_v7(conn: sqlite3.Connection);
def _migrate_v8(conn: sqlite3.Connection);
def _migrate_v9(conn: sqlite3.Connection);
def _migrate_v10(conn: sqlite3.Connection);

with entry {
    TARGET_RESOLUTION_KINDS = ("CALLS", "REFERENCES");

    _TARGET_RESOLUTION_TEMPLATE = "CASE WHEN EXISTS (SELECT 1 FROM nodes crg_res_n WHERE crg_res_n.qualified_name = {alias}.target_qualified) THEN 'direct' ELSE 'unresolved' END";
    _ALLOWED_EDGE_ALIASES = frozenset({"edges", "e"});
}

def target_resolution_expr(alias: str = "edges") -> str;

with entry {
    TARGET_RESOLUTION_EXPR = target_resolution_expr();
}

def _migrate_v11(conn: sqlite3.Connection);
def _migrate_v12(conn: sqlite3.Connection);
def _migrate_v13(conn: sqlite3.Connection);
def _migrate_v14(conn: sqlite3.Connection);
def _migrate_v15(conn: sqlite3.Connection);

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

def _run_one(conn: sqlite3.Connection, version: int);
def _is_new_database(conn: sqlite3.Connection, current: int) -> bool;
def run_migrations(conn: sqlite3.Connection);
