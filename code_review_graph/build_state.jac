"""How much of a build actually finished, recorded in the graph itself.

Freshness metadata cannot express "half built".  ``full_build`` records
``last_updated`` and the VCS anchor as soon as the last file is stored, so a
process killed between that point and post-processing left a graph with every
node in place, a current anchor, an empty FTS index and no flows, and the next
``update`` read the anchor, reported "no changes" and repaired nothing.  One
metadata row is the evidence that the previous run did not finish.

It has three states, not two, because "incomplete" hides two different
failures that need opposite repairs:

``in-progress``
    Files are still being stored, or the process storing them died.  The graph
    is missing nodes for files that exist.  Only a build can repair that:
    post-processing computes flows, communities and a search index *from* the
    stored nodes, so running it over this state produces derived data that is
    correct for a graph nobody asked for.  It must never be recorded as
    complete.

``postprocess-pending``
    Every file the build set out to store was stored and the anchor written,
    but the derived data (call-target resolution, signatures, FTS, flows,
    communities) did not finish.  The graph's contents are whole.
    ``code-review-graph postprocess`` exists for exactly this state, and
    clearing the marker after it succeeds is the whole point of the command.

``complete``
    Post-processing finished over a whole graph.

Keeping those apart is what stops the hand repair from declaring a graph with
missing files healthy, while still letting it clear the marker after the
repair it can actually perform.
"""

import operator;

import from __future__ { annotations }

import sqlite3;

import from typing { Any }

glob BUILD_STATE_KEY: any = "build_state";

glob BUILD_IN_PROGRESS: any = "in-progress";

glob POSTPROCESS_PENDING: any = "postprocess-pending";

glob BUILD_COMPLETE: any = "complete";

glob INCOMPLETE_BUILD_STATES: any;

with entry {
    INCOMPLETE_BUILD_STATES = frozenset({BUILD_IN_PROGRESS, POSTPROCESS_PENDING});
}

"""The recorded state, or ``""`` when the graph carries no marker."""
def read_build_state(store: Any) -> str;

"""True when every file the last build set out to store was stored.

    A state this module does not recognise counts as stored: the empty
    string for a graph built before the marker existed, or a value written by
    a newer release.  The marker is evidence of damage, not evidence of
    health: reading its absence as "missing files" would make every older
    graph one that a hand repair can never finish.
    """
def graph_contents_are_complete(state: str) -> bool;

"""Record that storing finished and only post-processing is outstanding.

    Only a build that recorded itself as in progress is advanced.  ``full_build``
    and ``incremental_update`` are also driven directly by tools, benchmarks and
    tests that never set the marker, and those must not come away with a
    half-built verdict they never had.
    """
def advance_to_postprocess_pending(store: Any) -> None;
