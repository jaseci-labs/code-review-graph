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

def _clear_derived_event_data(store: GraphStore) -> tuple[int, int];
def resolve_spring_events(store: GraphStore) -> dict[str, int];
