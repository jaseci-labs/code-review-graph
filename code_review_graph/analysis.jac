import from __future__ { annotations }

import logging;

import from collections { Counter, defaultdict, deque }

import from pathlib { Path }

glob logger: any = logging.getLogger(__name__);

glob _MAX_CYCLE_FILES: any = 10;

glob _MAX_CYCLE_HOPS: any = 10;

def find_hub_nodes(store: GraphStore, top_n: int = 10) -> list[dict];
def find_bridge_nodes(store: GraphStore, top_n: int = 10) -> list[dict];
def _shortest_loop(adjacency: dict[str, set[str]], start: str) -> list[str];
def find_import_cycles(
    store: GraphStore, edges: list[GraphEdge] | None = None, repo_root: Path | None = None
) -> list[dict];
def find_knowledge_gaps(store: GraphStore, repo_root: Path | None = None) -> dict[str, list[dict]];
def find_surprising_connections(store: GraphStore, top_n: int = 15) -> list[dict];
def generate_suggested_questions(store: GraphStore) -> list[dict];
