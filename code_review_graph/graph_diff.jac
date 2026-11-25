"""Graph snapshot diffing -- compare graph state over time."""

import from __future__ { annotations }

import json;

import logging;

import from pathlib { Path }

import from typing { Any }

glob logger: any;

with entry {
    logger = logging.getLogger(__name__);
}

"""Take a snapshot of the current graph state.

    Returns a dict with node and edge counts, qualified names,
    and community assignments for later diffing.
    """
def take_snapshot(store: GraphStore) -> dict[str, Any];

"""Save a snapshot to a JSON file."""
def save_snapshot(snapshot: dict, path: Path) -> None;

"""Load a snapshot from a JSON file."""
def load_snapshot(path: Path) -> dict;

"""Compare two graph snapshots.

    Returns:
        Dict with new_nodes, removed_nodes, new_edges,
        removed_edges, community_changes, and summary
        statistics.
    """
def diff_snapshots(before: dict, after: dict) -> dict[str, Any];
