"""Resolve Spring application-event publishers to package-matched listeners."""

import from __future__ { annotations }

import json;

import logging;

import from typing { TYPE_CHECKING }

glob logger: any;

glob _EVENT_NODE_FILE: any;

glob _DERIVED_FLAG: any;

with entry {
    logger = logging.getLogger(__name__);

    _EVENT_NODE_FILE = "event";
    _DERIVED_FLAG = "spring_event_resolved";
}

"""Remove event nodes and derived calls before rebuilding the relation."""
def _clear_derived_event_data(store: GraphStore) -> tuple[int, int];

"""Rebuild Event nodes and derived publisher-to-listener CALLS edges.

    The rebuild is intentionally global whenever Java changes. It prevents a
    listener deletion, rename, or event-type change from leaving a stale CALLS
    edge whose owning publisher file was not itself reparsed.
    """
def resolve_spring_events(store: GraphStore) -> dict[str, int];
