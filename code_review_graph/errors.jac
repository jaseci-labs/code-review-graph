import from __future__ { annotations }

import builtins, sqlite3;

obj CodeReviewGraphError(Exception) {
    def __repr__ -> str {
        return (getattr(builtins.super(CodeReviewGraphError, self), "__repr__") as any)();
    }

    def __eq__(other: any) -> bool {
        return self is other;
    }

    def __hash__ -> int {
        return id(self);
    }
}

obj GraphStoreError(CodeReviewGraphError) {
    def __repr__ -> str {
        return (getattr(builtins.super(GraphStoreError, self), "__repr__") as any)();
    }

    def __eq__(other: any) -> bool {
        return self is other;
    }

    def __hash__ -> int {
        return id(self);
    }
}

obj GraphRootMismatchError(GraphStoreError) {
    def __repr__ -> str {
        return (getattr(builtins.super(GraphRootMismatchError, self), "__repr__") as any)();
    }

    def __eq__(other: any) -> bool {
        return self is other;
    }

    def __hash__ -> int {
        return id(self);
    }
}

obj ChangeDiscoveryError(CodeReviewGraphError, RuntimeError) {
    def __repr__ -> str {
        return (getattr(builtins.super(ChangeDiscoveryError, self), "__repr__") as any)();
    }

    def __eq__(other: any) -> bool {
        return self is other;
    }

    def __hash__ -> int {
        return id(self);
    }
}

glob _LOCK_ERRORS: any = (
    "database is locked",
    "database table is locked",
    "database schema is locked",
);

def is_lock_error(exc: BaseException) -> bool {
    return isinstance(exc, sqlite3.OperationalError)
        and `any(needle in `str(exc).lower() for needle in _LOCK_ERRORS);
}

glob __all__: any = [
    "ChangeDiscoveryError",
    "CodeReviewGraphError",
    "GraphRootMismatchError",
    "GraphStoreError",
    "is_lock_error",
];
