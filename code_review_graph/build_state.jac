import from __future__ { annotations }

import operator, sqlite3;

import from typing { Any }

glob BUILD_STATE_KEY: any = "build_state";

glob BUILD_IN_PROGRESS: any = "in-progress";

glob POSTPROCESS_PENDING: any = "postprocess-pending";

glob BUILD_COMPLETE: any = "complete";

glob INCOMPLETE_BUILD_STATES: any = frozenset({BUILD_IN_PROGRESS, POSTPROCESS_PENDING});

def read_build_state(store: Any) -> str;
def graph_contents_are_complete(state: str) -> bool;
def advance_to_postprocess_pending(store: Any);
