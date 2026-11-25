import from __future__ { annotations }

import builtins, sqlite3;

obj CodeReviewGraphError(Exception) {
    def __repr__ -> str;

    def __eq__(other: any) -> bool;

    def __hash__ -> int;
}

obj GraphStoreError(CodeReviewGraphError) {
    def __repr__ -> str;

    def __eq__(other: any) -> bool;

    def __hash__ -> int;
}

obj GraphRootMismatchError(GraphStoreError) {
    def __repr__ -> str;

    def __eq__(other: any) -> bool;

    def __hash__ -> int;
}

obj ChangeDiscoveryError(CodeReviewGraphError, RuntimeError) {
    def __repr__ -> str;

    def __eq__(other: any) -> bool;

    def __hash__ -> int;
}

glob _LOCK_ERRORS: any = (
    "database is locked",
    "database table is locked",
    "database schema is locked",
);
def is_lock_error(exc: BaseException) -> bool;

glob __all__: any = [
    "ChangeDiscoveryError",
    "CodeReviewGraphError",
    "GraphRootMismatchError",
    "GraphStoreError",
    "is_lock_error",
];
