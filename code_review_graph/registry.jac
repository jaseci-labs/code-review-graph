"""Multi-repo registry and connection pool.

Manages a registry of multiple repositories at ``~/.code-review-graph/registry.json``
and provides a connection pool for concurrent access to multiple graph databases.
"""

import builtins;

import from __future__ { annotations }

import json;

import logging;

import sqlite3;

import threading;

import from collections { OrderedDict }

import from pathlib { Path }

glob logger: any;

with entry {
    logger = logging.getLogger(__name__);
}

"""Return the full path to ``registry.json``.

    Lives under :func:`~code_review_graph.constants.crg_home`, so ``$CRG_HOME``
    redirects it along with the rest of the per-user state.
    """
def default_registry_path -> Path;

"""Manages a JSON-based registry of code-review-graph repositories.

    Each entry stores the repo path and an optional alias.
    The registry lives at ``~/.code-review-graph/registry.json``, or under
    ``$CRG_HOME`` when that is set.
    """
obj Registry {
    has _path: any,
        _lock: any,
        _repos: any;

    def init(path: Path | None = None);

    """Load registry from disk."""
    def _load -> None;

    """Write registry to disk."""
    def _save -> None;

    """Register a repository path.

        Validates that the path contains a ``.git`` or ``.code-review-graph``
        directory.

        Args:
            path: Absolute or relative path to the repository root.
            alias: Optional short alias for the repository.
            data_dir: Optional external directory for graph database.

        Returns:
            The registered entry dict.

        Raises:
            ValueError: If the path is not a valid repository.
        """
    def register(
        path: str, alias: str | None = None, data_dir: str | None = None
    ) -> dict[str, str];

    """Remove a repository by path or alias.

        Args:
            path_or_alias: Either the absolute path or the alias.

        Returns:
            True if an entry was removed, False otherwise.
        """
    def unregister(path_or_alias: str) -> bool;

    """Return list of all registered repositories.

        Returns:
            List of dicts with 'path' and optional 'alias' keys.
        """
    def list_repos -> list[dict[str, str]];

    """Look up a repository by its alias.

        Args:
            alias: The alias to search for.

        Returns:
            The matching entry, or None.
        """
    def find_by_alias(alias: str) -> dict[str, str] | None;

    """Look up a repository by its path.

        Args:
            path: The path to search for.

        Returns:
            The matching entry, or None.
        """
    def find_by_path(path: str) -> dict[str, str] | None;

    """Set the external data directory for a repository.

        Args:
            path: Repository path (absolute or relative).
            data_dir: External directory path to store graph database.

        Returns:
            The updated or created registry entry.
        """
    def set_data_dir(path: str, data_dir: str) -> dict[str, str];

    """Get the stored data directory for a repository.

        Args:
            path: Repository path (absolute or relative).

        Returns:
            The stored data_dir path, or None if not set.
        """
    def get_data_dir_for_repo(path: str) -> str | None;

    def __repr__ -> str;

    def __eq__(other: any) -> bool;

    def __hash__ -> int;
}

"""LRU connection pool for SQLite graph databases.

    Caches open connections keyed by database path, evicting the least
    recently used connection when the pool is full.
    """
obj ConnectionPool {
    has _max_size: any,
        _pool: any,
        _lock: any;

    def init(max_size: int = 10);

    """Get or create a connection for the given database path.

        Args:
            db_path: Path to the SQLite database file.

        Returns:
            An open SQLite connection.
        """
    def get(db_path: str) -> sqlite3.Connection;

    """Close all connections in the pool."""
    def close_all -> None;

    """Current number of open connections."""
    has size: int {
        getter {
            with self._lock {
                return len(self._pool);
            }
        }
    }

    def __repr__ -> str;

    def __eq__(other: any) -> bool;

    def __hash__ -> int;
}

"""Resolve a repo parameter to an absolute path.

    Resolution order:
    1. If repo is given, try as alias first.
    2. If repo is given and not an alias, try as a direct path.
    3. If repo is None, use cwd.

    Args:
        registry: The Registry instance.
        repo: Alias or path string, or None.
        cwd: Current working directory fallback.

    Returns:
        Resolved absolute path string, or None if unresolvable.
    """
def resolve_repo(registry: Registry, repo: str | None, cwd: str | None = None) -> str | None;
