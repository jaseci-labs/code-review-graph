impl read_build_state(store: Any) -> str {
    try {
        return `str(store.get_metadata(BUILD_STATE_KEY) or "");
    } except sqlite3.Error {
        return "";
    }
}

impl graph_contents_are_complete(state: str) -> bool {
    return operator.ne(state, BUILD_IN_PROGRESS);
}

impl advance_to_postprocess_pending(store: Any) {
    if read_build_state(store) == BUILD_IN_PROGRESS {
        store.set_metadata(BUILD_STATE_KEY, POSTPROCESS_PENDING);
    }
}
