"""Seeded k-hop neighbourhood extraction and path-between-symbols queries.

The whole-repository force layout is only viable while the rendered graph
stays inside the budget in :mod:`code_review_graph.visualization`
(``DEFAULT_MAX_FULL_NODES`` / ``DEFAULT_MAX_FULL_EDGES``).  Past that the page
aggregates into one bubble per community, which is fine for an architecture
sketch and useless for review.  This module builds the other view: pick a
seed, keep the *k* hops around it, and leave the rest of the graph out of the
payload entirely.

Hop semantics
-------------
A hop is any edge that is not containment: ``CALLS``, ``IMPORTS_FROM``,
``INHERITS``, ``IMPLEMENTS``, ``TESTED_BY``, ``DEPENDS_ON``, ``REFERENCES``,
and whatever a language pack adds next.  The rule is an exclusion rather than
an allow-list on purpose: an allow-list silently drops a whole relationship
class the day a parser starts emitting it, and the neighbourhood then quietly
omits nodes a reviewer needed.  ``CONTAINS`` is structural and is deliberately
*not* a hop — otherwise the file of any seed would be one hop
away and every sibling symbol in that file two hops away, so a depth-2
neighbourhood of one function would swallow its whole module.  Containing
``File`` nodes are still attached to the payload (at the hop of their closest
member) because the renderer's collapse/expand and file clustering are built
on ``CONTAINS``; they simply do not act as transit.

Everything here operates on the already-exported, already-name-resolved data
produced by :func:`code_review_graph.visualization.export_graph_data`, so a
neighbourhood is a strict subset of what the whole-repo view would have drawn.
That function need not read the whole repository to supply it: :func:`extract`
gives the same answer given the seeds, every edge touching a node it could keep,
and the graph-wide totals.
"""

import builtins;

import from __future__ { annotations }

import fnmatch;

import from collections { deque }

import from dataclasses { dataclass }

import from typing { Iterable, Sequence }

"""Delegate to :func:`code_review_graph.graph._sanitize_name`.

    Imported lazily so that ``cli.py`` can pull this module in at import time
    for its flag defaults without paying for ``graph`` (and therefore
    ``networkx``) on every invocation, including ``--version``.
    """
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

"""Raised when a seed symbol, file or flow matches no node in the graph."""
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

"""What to seed the view with and how far to grow it.

    Attributes:
        symbols: Symbol queries (qualified name, ``file::name``, or bare name).
        files: File path queries; a file seeds itself and its direct members.
        flow: Execution flow name or id; every node on the flow is a seed.
        path_from: Start symbol of a shortest-path query.
        path_to: End symbol of a shortest-path query.
        depth: Hops to include in the payload.
        render_depth: Hops drawn before the user expands; defaults to
            ``min(DEFAULT_RENDER_DEPTH, depth)``.
        max_nodes: Hard cap on payload nodes.  The outermost hop is trimmed
            first, and the seed set itself is trimmed once the outer hops are
            gone -- the cap is a cap, not a suggestion.
    """
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

    """True when any seed was supplied, i.e. this is a neighbourhood view."""
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

    """Reject contradictory flag combinations.  Returns *self*."""
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

"""Adjacency map over *edges*, restricted to *kinds* and minus *exclude*."""
def build_adjacency(
    edges: Iterable[dict],
    kinds: Sequence[str] | None = None,
    *,
    exclude: Sequence[str] = (),
    directed: bool = False,
) -> dict[str, set[str]];

"""Breadth-first hop distance from *seeds*, capped at *depth*."""
def hop_distances(
    adjacency: dict[str, set[str]], seeds: Iterable[str], depth: int
) -> dict[str, int];

glob kinds_default_: any;

with entry {
    kinds_default_ = PATH_EDGE_KINDS;
}

"""Shortest path from *source* to *target* through *kinds*.

    Tries the directed graph first (``source`` calls/imports/inherits its way
    to ``target``), then falls back to the undirected graph so a pair that is
    only *related* still shows a route.  Returns ``(path, directed)``; the path
    is empty when the two symbols are not connected through *kinds* at all.
    """
def shortest_path(
    edges: Iterable[dict], source: str, target: str, kinds: Sequence[str] = kinds_default_
) -> tuple[list[str], bool];

def _bfs_path(adjacency: dict[str, set[str]], source: str, target: str) -> list[str];

def _normalise_path(value: str) -> str;

"""Resolve a symbol query to qualified names, best match first.

    Accepts a full qualified name, a ``path::name`` suffix, or a bare symbol
    name.  Raises :class:`SeedResolutionError` when nothing matches.
    """
def resolve_symbol(nodes: Sequence[dict], query: str) -> list[str];

"""Resolve file patterns to the File nodes *and* their direct members."""
def resolve_files(nodes: Sequence[dict], patterns: Sequence[str]) -> list[str];

"""Resolve a flow name or id to the qualified names on its path."""
def resolve_flow(flows: Sequence[dict], nodes: Sequence[dict], query: str) -> list[str];

"""Map member qualified name -> containing File qualified name."""
def _parent_files(edges: Sequence[dict], members: set[str]) -> dict[str, str];

"""Pick the payload node set, never returning more than *max_nodes* nodes.

    A symbol costs its own slot plus, the first time it appears, a slot for
    the ``File`` that contains it, because the renderer needs that File for
    clustering and collapse.  The budget therefore has to be applied to the
    *final* set, not to the semantic hop set alone.  When a symbol fits but
    the pair does not, the symbol is kept and its File is given up: the File
    is a rendering nicety, the symbol is the thing the reviewer asked for.

    *pinned* nodes (the answer to a path query, which is the whole point of
    that query) are placed first, bare, so no other node's containing File
    can crowd the answer out of its own view; the caller refuses a budget
    smaller than the path before it gets here.  Everything else is ranked
    nearest-hop first, then best-connected first by whole-graph degree, ties
    broken by name so the output is deterministic.  Hop 0 is ranked first but
    is **not** exempt: on ``--seed-changed`` the seed set is the large thing,
    so exempting it made ``--max-nodes`` do nothing exactly when it was
    needed.  A seed that does not fit is dropped like any other node, and the
    caller reports how many.
    """
def _select_within_budget(
    hops: dict[str, int],
    degrees: dict[str, int],
    parents: dict[str, str],
    max_nodes: int,
    pinned: Sequence[str] = (),
) -> tuple[dict[str, int], bool];

"""The nodes a spec seeds, and the answer to its path query if it has one."""
@dataclass(frozen=True)
class ResolvedSeeds {
    has seeds: list[str];

    has seed_kind: str;

    has path: list[str];

    has path_directed: bool;

    has path_error: str;
}

"""Resolve *spec* against the graph's *nodes*, de-duplicated in first-seen order.

    Each node needs only ``qualified_name``, ``name``, ``file_path`` and ``id``,
    and *edges* are read only for a path query. Raises
    :class:`SeedResolutionError` when a seed matches nothing.
    """
def resolve_seeds(
    nodes: Sequence[dict], edges: Sequence[dict], flows: Sequence[dict], spec: NeighbourhoodSpec
) -> ResolvedSeeds;

"""Reduce exported graph *data* to the neighbourhood described by *spec*.

    Returns a payload of the same shape as :func:`export_graph_data` with an
    extra ``"neighbourhood"`` block describing the seeds, the hop label of
    every node, the render depth and (for a path query) the highlighted path.
    Nodes outside the neighbourhood are absent, not dimmed.

    *data* may be just the part of the graph around the seeds if the caller
    has already resolved them and passes the whole graph's ``(nodes, edges)``
    counts as *totals*. It must then hold every edge touching a node within
    *depth* hops, plus every edge touching a node that contains one of those,
    and those containing nodes themselves.
    """
def extract(
    data: dict,
    spec: NeighbourhoodSpec,
    *,
    resolved: ResolvedSeeds | None = None,
    totals: tuple[int, int] | None = None,
) -> dict;
