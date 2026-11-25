import from __future__ { annotations }

import importlib, operator, contextlib, contextvars, logging, os, sqlite3, time;

import from typing { Callable, Iterator }

glob logger: any = logging.getLogger(__name__);

glob _progress_level: contextvars.ContextVar[int] = contextvars.ContextVar(
    "crg_migration_progress_level", default=logging.INFO
);

def _progress(msg: str, *args_: object);

glob _MAX_ATTEMPTS: any = 5;

glob _RETRY_BASE_SECONDS: any = 0.05;

glob _ALREADY_APPLIED: any = ("duplicate column name", "already exists");

glob _CONTENDED: any = (
    "database is locked",
    "database table is locked",
    "database schema is locked",
    "cannot start a transaction within a transaction",
);

def _matches(exc: sqlite3.Error, needles: tuple[str, ...]) -> bool;
def _apply(conn: sqlite3.Connection, sql: str, *, what: str) -> bool;
@contextlib.contextmanager
def _write_lock_held(conn: sqlite3.Connection) -> Generator[any, any, any];
def get_schema_version(conn: sqlite3.Connection) -> int;
def _set_schema_version(conn: sqlite3.Connection, version: int);

glob _KNOWN_TABLES: any = frozenset(
    ("nodes edges metadata communities flows flow_memberships nodes_fts nodes_fts_state").split()
);

def _has_column(conn: sqlite3.Connection, table: str, column: str) -> bool;
def _table_exists(conn: sqlite3.Connection, table: str) -> bool;

glob NODES_FTS_COLUMNS: tuple[str, ...] = (
    "name",
    "qualified_name",
    "file_path",
    "signature",
    "docstring",
    "name_tokens",
);

glob NODES_FTS_DDL: any = "\nCREATE VIRTUAL TABLE nodes_fts USING fts5(\n    {columns},\n    content='nodes', content_rowid='rowid',\n    tokenize='porter unicode61'\n)\n".format(
    columns=", ".join(NODES_FTS_COLUMNS)
);

glob NODES_FTS_STATE_TABLE: any = "nodes_fts_state";

glob FTS_STATE_METADATA_KEY: any = "fts_state_synced";

glob FTS_STATE_VERSION: any = "2";

def ensure_nodes_fts_state(conn: sqlite3.Connection);

glob _BACKFILL_BATCH: any = 5000;

def _migrate_v2(conn: sqlite3.Connection);
def _migrate_v3(conn: sqlite3.Connection);
def _migrate_v4(conn: sqlite3.Connection);
def _migrate_v5(conn: sqlite3.Connection);
def _migrate_v6(conn: sqlite3.Connection);
def _migrate_v7(conn: sqlite3.Connection);
def _migrate_v8(conn: sqlite3.Connection);
def _migrate_v9(conn: sqlite3.Connection);
def _migrate_v10(conn: sqlite3.Connection);

glob TARGET_RESOLUTION_KINDS: any = ("CALLS", "REFERENCES");

glob _TARGET_RESOLUTION_TEMPLATE: any = "CASE WHEN EXISTS (SELECT 1 FROM nodes crg_res_n WHERE crg_res_n.qualified_name = {alias}.target_qualified) THEN 'direct' ELSE 'unresolved' END";

glob _ALLOWED_EDGE_ALIASES: any = frozenset({"edges", "e"});

def target_resolution_expr(alias: str = "edges") -> str;

glob TARGET_RESOLUTION_EXPR: any = target_resolution_expr();

def _migrate_v11(conn: sqlite3.Connection);
def _migrate_v12(conn: sqlite3.Connection);
def _migrate_v13(conn: sqlite3.Connection);
def _migrate_v14(conn: sqlite3.Connection);
def _migrate_v15(conn: sqlite3.Connection);

glob MIGRATIONS: dict[int, Callable[[sqlite3.Connection], None]] = {
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

glob LATEST_VERSION: any = max(MIGRATIONS.keys());

glob _REBUILD_AFTER: frozenset[int] = frozenset({15});

glob _REBUILD_HINT: any = "Graph upgraded to schema v%d. Run code-review-graph build once (and code-review-graph embed if you use embeddings): an update parses only changed files, so files this release can newly read stay out until then.";

def _run_one(conn: sqlite3.Connection, version: int);
def _is_new_database(conn: sqlite3.Connection, current: int) -> bool;
def run_migrations(conn: sqlite3.Connection);
