"""Forget parsed files from the graph while keeping every derived layer sane.

Dropping a file's own nodes and edges is not enough to match the graph a full
rebuild without that file would produce:

* surviving files that referenced it keep dangling, still-qualified edges
  (a call resolved to ``other.py::helper`` stays pointing at a node that no
  longer exists instead of falling back to the bare ``helper``);
* the derived layers — execution flows, communities, the FTS index, and
  embeddings — continue to reference the deleted nodes.

``forget_files`` therefore removes the files, re-parses the surviving referrers
so their cross-file edges are re-derived exactly as a build would, re-runs the
repository-wide Python import resolver and shared post-processing pipeline
(which fully recomputes flows, communities, signatures, and FTS and re-resolves
bare endpoints), and purges embedding vectors whose node is gone. The result is
equivalent to building the graph without the forgotten files.
"""

import importlib;

import from __future__ { annotations }

import hashlib;

import logging;

import from pathlib { Path }

import from typing { Any }

glob logger: any;

glob _SQL_PARAM_CHUNK: any;

with entry {
    logger = logging.getLogger(__name__);
    _SQL_PARAM_CHUNK = 400;
}

"""Return surviving files whose edges point at any forgotten node.

    Those edges are precisely the ones a rebuild would re-derive (usually
    dropping back to a bare endpoint), so the files owning them must be
    re-parsed for parity.
    """
def _referrer_files(
    store: GraphStore, deleted_qualified_names: set[str], forgotten: set[str]
) -> list[str];

"""Delete embedding vectors whose graph node no longer exists.

    Mirrors :meth:`embeddings.EmbeddingStore.purge_orphans` but runs on the
    graph's own connection so we never open a second writer. A graph without
    an embeddings table is a no-op.
    """
def _purge_orphan_embeddings(store: GraphStore) -> int;

"""Remove ``targets`` from the graph and repair every derived layer.

    Args:
        store: An open graph store.
        repo_root: Repository root, used to re-parse surviving referrers.
        targets: Absolute file paths (as stored in the graph) to forget.

    Returns:
        A summary dict with the forgotten files, the referrer files that were
        re-parsed, and the number of orphaned embedding vectors purged.
    """
def forget_files(store: GraphStore, repo_root: Path, targets: list[str]) -> dict[str, Any];
