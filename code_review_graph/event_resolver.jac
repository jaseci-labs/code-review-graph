import from __future__ { annotations }

import json, logging;

import from typing { TYPE_CHECKING }

glob logger: any = logging.getLogger(__name__);

glob _EVENT_NODE_FILE: any = "event";

glob _DERIVED_FLAG: any = "spring_event_resolved";

def _clear_derived_event_data(store: GraphStore) -> tuple[int, int];
def resolve_spring_events(store: GraphStore) -> dict[str, int];
