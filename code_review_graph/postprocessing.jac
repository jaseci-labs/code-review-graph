"""Shared post-build processing pipeline.

After the core Tree-sitter parse (full_build or incremental_update), five
post-processing steps must run to populate derived tables:

1. Resolve evidence-backed bare edge endpoints
2. Compute node signatures
3. Sync the FTS5 search index (per-file delta, or a full rebuild)
4. Trace execution flows
5. Detect code communities

An embedding refresh can be added as an explicit fifth step by supplying an
exact provider and model.  It is default-off because cloud providers transmit
source-derived text and may incur API cost.

This module extracts that pipeline so every entry point — MCP tool, CLI
commands, and watch mode — produces identical results.
"""

import from code_review_graph._lazy { lazy }

import importlib;

import from __future__ { annotations }

import logging;

import sqlite3;

import from collections.abc { Sequence }

import from typing { Any }

glob logger: any;

with entry {
    logger = logging.getLogger(__name__);
}

"""Run all post-build steps on a populated graph.

    Each step is non-fatal: failures are logged and collected as warnings
    so the primary build result is never lost.

    Args:
        store: An open GraphStore with nodes and edges already populated.
        changed_files: Files this update re-parsed, when the caller knows
            them. The FTS5 step then rewrites only those files' index
            entries instead of dropping and repopulating the index.
        embedding_provider: Exact provider for an explicit embedding
            refresh. Must be supplied with ``embedding_model``.
        embedding_model: Exact model for an explicit embedding refresh.
            Must be supplied with ``embedding_provider``.

    Returns:
        Dict with keys for each step's result count and a ``warnings``
        list, present when at least one step failed or when an explicit
        refresh found no index (``embeddings_refresh_skipped``).
    """
def run_post_processing(
    store: GraphStore,
    *,
    changed_files: Sequence[str] | None = None,
    embedding_provider: str | None = None,
    embedding_model: str | None = None,
) -> dict[str, Any];

"""Resolve bare and C++ scoped call targets before derived graph steps."""
def _resolve_bare_endpoints(store: GraphStore, result: dict[str, Any], warnings: list[str]) -> None;

"""Compute human-readable signatures for nodes that lack one."""
def _compute_signatures(store: GraphStore, result: dict[str, Any], warnings: list[str]) -> None;

"""Bring the FTS5 full-text search index in step with the nodes table.

    Rewrites only the changed files' entries when that is cheaper; falls
    back to a full rebuild on its own when it is not.
    """
def _sync_fts_index(
    store: GraphStore,
    result: dict[str, Any],
    warnings: list[str],
    changed_files: Sequence[str] | None = None,
) -> None;

"""Trace execution flows from entry points."""
def _trace_flows(store: GraphStore, result: dict[str, Any], warnings: list[str]) -> None;

"""Detect code communities via Leiden algorithm or file grouping."""
def _detect_communities(store: GraphStore, result: dict[str, Any], warnings: list[str]) -> None;

"""Run an explicitly requested embedding refresh without failing a build."""
def _refresh_embeddings(
    store: GraphStore,
    result: dict[str, Any],
    warnings: list[str],
    *,
    provider: str | None,
    model: str | None,
) -> None;
