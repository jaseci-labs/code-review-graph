"""Multi-hop retrieval benchmark.

Tests a two-step tool chain that mimics how an LLM agent actually uses the
graph for complex tasks:

  1. ``hybrid_search(nl_query)`` to find a starting anchor from a natural-
     language question.
  2. ``query_graph(pattern, target=anchor)`` to traverse one hop along the
     requested edge kind (callers_of / callees_of / tests_for / ...).

For each task the benchmark records:

- ``anchor_found`` — did semantic search return a node whose qualified_name
  ends with the expected suffix in the top-K?
- ``anchor_rank`` — index in the search result list (lower is better).
- ``neighbor_count`` — number of neighbors returned by the traversal.
- ``neighbor_recall`` — fraction of ``expected_neighbor_names`` that appear
  among the neighbor names.
- ``score`` — ``int(anchor_found) * neighbor_recall``. Range 0–1.

Tasks are defined per-config under ``multi_hop_tasks:`` in
``code_review_graph/eval/configs/*.yaml``. See
``docs/REPRODUCING.md`` for the schema and the curated canonical task set.
"""

import from code_review_graph._lazy { lazy }

import importlib;

import from __future__ { annotations }

import logging;

import from pathlib { Path }

import from typing { Any }

glob logger: any;

with entry {
    logger = logging.getLogger(__name__);
}

def _name_set(rows: list[dict[str, Any]]) -> set[str];

"""Run the multi-hop retrieval benchmark for one repo."""
def run(repo_path: Path, store, config: dict) -> list[dict];
