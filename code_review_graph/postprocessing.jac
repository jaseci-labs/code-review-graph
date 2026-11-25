import from __future__ { annotations }

import importlib;

import logging;

import sqlite3;

import from collections.abc { Sequence }

import from typing { Any }

glob logger: any;

with entry {
    logger = logging.getLogger(__name__);
}

def run_post_processing(
    store: GraphStore,
    *,
    changed_files: Sequence[str] | None = None,
    embedding_provider: str | None = None,
    embedding_model: str | None = None,
) -> dict[str, Any];
def _resolve_bare_endpoints(store: GraphStore, result: dict[str, Any], warnings: list[str]);
def _compute_signatures(store: GraphStore, result: dict[str, Any], warnings: list[str]);
def _sync_fts_index(
    store: GraphStore,
    result: dict[str, Any],
    warnings: list[str],
    changed_files: Sequence[str] | None = None,
);
def _trace_flows(store: GraphStore, result: dict[str, Any], warnings: list[str]);
def _detect_communities(store: GraphStore, result: dict[str, Any], warnings: list[str]);
def _refresh_embeddings(
    store: GraphStore,
    result: dict[str, Any],
    warnings: list[str],
    *,
    provider: str | None,
    model: str | None,
);
