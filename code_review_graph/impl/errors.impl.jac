impl CodeReviewGraphError.__repr__ -> str {
    return (getattr(builtins.super(CodeReviewGraphError, self), "__repr__") as any)();
}

impl CodeReviewGraphError.__eq__(other: any) -> bool {
    return self is other;
}

impl CodeReviewGraphError.__hash__ -> int {
    return id(self);
}

impl GraphStoreError.__repr__ -> str {
    return (getattr(builtins.super(GraphStoreError, self), "__repr__") as any)();
}

impl GraphStoreError.__eq__(other: any) -> bool {
    return self is other;
}

impl GraphStoreError.__hash__ -> int {
    return id(self);
}

impl GraphRootMismatchError.__repr__ -> str {
    return (getattr(builtins.super(GraphRootMismatchError, self), "__repr__") as any)();
}

impl GraphRootMismatchError.__eq__(other: any) -> bool {
    return self is other;
}

impl GraphRootMismatchError.__hash__ -> int {
    return id(self);
}

impl ChangeDiscoveryError.__repr__ -> str {
    return (getattr(builtins.super(ChangeDiscoveryError, self), "__repr__") as any)();
}

impl ChangeDiscoveryError.__eq__(other: any) -> bool {
    return self is other;
}

impl ChangeDiscoveryError.__hash__ -> int {
    return id(self);
}

impl is_lock_error(exc: BaseException) -> bool {
    return isinstance(exc, sqlite3.OperationalError)
        and `any(needle in `str(exc).lower() for needle in _LOCK_ERRORS);
}
