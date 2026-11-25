"""Errors the CLI is expected to report as one line, never as a traceback.

Every exception here means "the tool cannot do the job, and it knows why".
``cli.main`` turns each of them into the house failure style — a single
``Error: ...`` line on stderr and exit 1 — so the message is the only thing
the user sees. The MCP tools turn them into ``{"status": "error", ...}``.

Keep the ``str()`` of each one short enough to read on a terminal line and
specific enough to act on: what is wrong, where, and what to do about it.
"""

import builtins;

import from __future__ { annotations }

import sqlite3;

"""Base class for every self-explaining failure in this package."""
obj CodeReviewGraphError(Exception) {
    def __repr__ -> str;

    def __eq__(other: any) -> bool;

    def __hash__ -> int;
}

"""The graph database cannot be opened, read, or written.

    Raised for a corrupt or foreign ``graph.db``, one written by a newer
    schema than this installation understands, and for a data directory the
    process may not write to.
    """
obj GraphStoreError(CodeReviewGraphError) {
    def __repr__ -> str;

    def __eq__(other: any) -> bool;

    def __hash__ -> int;
}

"""The graph on disk was built for a different repository root.

    Answering from it would serve one repository another repository's
    symbols, so every consumer refuses instead.
    """
obj GraphRootMismatchError(GraphStoreError) {
    def __repr__ -> str;

    def __eq__(other: any) -> bool;

    def __hash__ -> int;
}

"""The set of changed files or lines could not be determined.

    Distinct from "there are no changes" on purpose: a review gate keyed on
    an all-clear must not pass a pull request that was never looked at.
    Raised when the VCS binary is missing, times out, or fails.

    Also a ``RuntimeError``: ``get_changed_files(strict=True)`` has raised
    one since before this class existed, and callers that catch
    ``RuntimeError`` there keep working.
    """
obj ChangeDiscoveryError(CodeReviewGraphError, RuntimeError) {
    def __repr__ -> str;

    def __eq__(other: any) -> bool;

    def __hash__ -> int;
}

glob _LOCK_ERRORS: any = (
    "database is locked",
    "database table is locked",
    "database schema is locked",
);

"""True when SQLite refused because another process holds the write lock."""
def is_lock_error(exc: BaseException) -> bool;

glob __all__: any = [
    "ChangeDiscoveryError",
    "CodeReviewGraphError",
    "GraphRootMismatchError",
    "GraphStoreError",
    "is_lock_error",
];
