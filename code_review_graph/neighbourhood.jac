import from __future__ { annotations }

import importlib;

import builtins;

import fnmatch;

import from collections { deque }

import from dataclasses { dataclass }

import from typing { Iterable, Sequence }
def _sanitize_name(value: str) -> str;

glob __all__: any = [
    "DEFAULT_DEPTH",
    "DEFAULT_MAX_NODES",
    "DEFAULT_RENDER_DEPTH",
    "PATH_EDGE_KINDS",
    "STRUCTURAL_EDGE_KINDS",
    "NeighbourhoodSpec",
    "ResolvedSeeds",
    "SeedResolutionError",
    "extract",
    "hop_distances",
    "resolve_seeds",
    "shortest_path",
];

glob STRUCTURAL_EDGE_KINDS: tuple[str, ...];

glob PATH_EDGE_KINDS: tuple[str, ...];

glob DEFAULT_DEPTH: any;

glob DEFAULT_RENDER_DEPTH: any;

glob DEFAULT_MAX_NODES: any;

glob _MAX_PATH_VISITS: any;

with entry {
    STRUCTURAL_EDGE_KINDS = ("CONTAINS",);
    PATH_EDGE_KINDS = ("CALLS", "IMPORTS_FROM", "INHERITS");

    DEFAULT_DEPTH = 2;
    DEFAULT_RENDER_DEPTH = 1;
    DEFAULT_MAX_NODES = 1500;
    _MAX_PATH_VISITS = 2000000;
}

obj SeedResolutionError(ValueError) {
    def __repr__ -> str;

    def __eq__(other: any) -> bool;

    def __hash__ -> int;
}

glob depth_default_: any;

glob max_nodes_default_: any;

with entry {
    depth_default_ = DEFAULT_DEPTH;
    max_nodes_default_ = DEFAULT_MAX_NODES;
}

@dataclass(frozen=True)
class NeighbourhoodSpec {
    has symbols: tuple[str, ...] = ();

    has files: tuple[str, ...] = ();

    has `flow: str | None = None;

    has path_from: str | None = None;

    has path_to: str | None = None;

    has depth: int = DEFAULT_DEPTH;

    has render_depth: int | None = None;

    has max_nodes: int = DEFAULT_MAX_NODES;

    has is_active: bool {
        getter {
            return `bool(self.symbols or self.files or self.flow or self.path_from or self.path_to);
        }
    }

    has effective_render_depth: int {
        getter {
            if self.render_depth is None {
                return min(DEFAULT_RENDER_DEPTH, self.depth);
            }
            return max(0, min(self.render_depth, self.depth));
        }
    }

    def validate -> "NeighbourhoodSpec";

    class def from_args(
        *,
        seed_symbols: Sequence[str] | None = None,
        seed_files: Sequence[str] | None = None,
        seed_flow: str | None = None,
        path_from: str | None = None,
        path_to: str | None = None,
        depth: int = depth_default_,
        render_depth: int | None = None,
        max_nodes: int = max_nodes_default_,
    ) -> "NeighbourhoodSpec";
}

def build_adjacency(
    edges: Iterable[dict],
    kinds: Sequence[str] | None = None,
    *,
    exclude: Sequence[str] = (),
    directed: bool = False,
) -> dict[str, set[str]];
def hop_distances(
    adjacency: dict[str, set[str]], seeds: Iterable[str], depth: int
) -> dict[str, int];

glob kinds_default_: any;

with entry {
    kinds_default_ = PATH_EDGE_KINDS;
}

def shortest_path(
    edges: Iterable[dict], source: str, target: str, kinds: Sequence[str] = kinds_default_
) -> tuple[list[str], bool];

def _bfs_path(adjacency: dict[str, set[str]], source: str, target: str) -> list[str];

def _normalise_path(value: str) -> str;
def resolve_symbol(nodes: Sequence[dict], query: str) -> list[str];
def resolve_files(nodes: Sequence[dict], patterns: Sequence[str]) -> list[str];
def resolve_flow(flows: Sequence[dict], nodes: Sequence[dict], query: str) -> list[str];
def _parent_files(edges: Sequence[dict], members: set[str]) -> dict[str, str];
def _select_within_budget(
    hops: dict[str, int],
    degrees: dict[str, int],
    parents: dict[str, str],
    max_nodes: int,
    pinned: Sequence[str] = (),
) -> tuple[dict[str, int], bool];

@dataclass(frozen=True)
class ResolvedSeeds {
    has seeds: list[str];

    has seed_kind: str;

    has path: list[str];

    has path_directed: bool;

    has path_error: str;
}

def resolve_seeds(
    nodes: Sequence[dict], edges: Sequence[dict], flows: Sequence[dict], spec: NeighbourhoodSpec
) -> ResolvedSeeds;
def extract(
    data: dict,
    spec: NeighbourhoodSpec,
    *,
    resolved: ResolvedSeeds | None = None,
    totals: tuple[int, int] | None = None,
) -> dict;
