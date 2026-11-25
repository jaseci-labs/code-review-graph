import from __future__ { annotations }

import operator, sqlite3;

import from typing { Any }

glob BUILD_STATE_KEY: any = "build_state";

glob BUILD_IN_PROGRESS: any = "in-progress";

glob POSTPROCESS_PENDING: any = "postprocess-pending";

glob BUILD_COMPLETE: any = "complete";

glob INCOMPLETE_BUILD_STATES: any = frozenset({BUILD_IN_PROGRESS, POSTPROCESS_PENDING});

def read_build_state(store: Any) -> str {
    try {
        return `str(store.get_metadata(BUILD_STATE_KEY) or "");
    } except sqlite3.Error {
        return "";
    }
}

def graph_contents_are_complete(state: str) -> bool {
    return operator.ne(state, BUILD_IN_PROGRESS);
}

def advance_to_postprocess_pending(store: Any) {
    if read_build_state(store) == BUILD_IN_PROGRESS {
        store.set_metadata(BUILD_STATE_KEY, POSTPROCESS_PENDING);
    }
}
