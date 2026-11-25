impl _close_inherited_locks {
    for lock in `list(_open_locks) {
        (handle, lock._handle) = (lock._handle, None);
        if handle is not None {
            handle.close();
        }
    }
    _open_locks.clear();
}

impl write_lock_path(db_path: Path) -> Path {
    return db_path.with_name(WRITE_LOCK_NAME);
}

impl _flock_supported -> bool {
    return operator.ne(sys.platform, "win32");
}

impl _flock(handle: Any, blocking: bool) -> bool {
    import fcntl;

    flags: any = fcntl.LOCK_EX if blocking else fcntl.LOCK_EX | fcntl.LOCK_NB;
    try {
        fcntl.flock(handle.fileno(), flags);
    } except OSError as exc {
        if exc.errno in (errno.EACCES, errno.EAGAIN) {
            return False;
        }
        raise;
    }
    return True;
}

impl read_write_lock_holder(db_path: Path) -> int | None {
    try {
        raw: any = write_lock_path(db_path).read_text(encoding="utf-8").strip();
    } except OSError {
        return None;
    }
    try {
        return `int(raw);
    } except ValueError {
        return None;
    }
}

impl WriteLock.init(db_path: Path) {
    self.db_path = db_path;
    self.path = write_lock_path(db_path);
    self._handle = None;
}

impl WriteLock.acquire(*, blocking: bool = False) -> bool {
    if self._handle is not None {
        return True;
    }
    if not _flock_supported() {
        return True;
    }
    try {
        self.path.parent.mkdir(parents=True, exist_ok=True);
        handle: any = open(self.path, "a+", encoding="utf-8");
    } except OSError as exc {
        logger.warning("Cannot open write lock %s: %s", self.path, exc);
        return True;
    }
    self._handle = handle;
    _open_locks.add(self);
    acquired: any = False;
    try {
        acquired = _flock(handle, blocking);
    } except OSError as exc {
        logger.warning("Cannot lock %s: %s", self.path, exc);
        return True;
    } finally {
        if not acquired {
            self._handle = None;
            _open_locks.discard(self);
            handle.close();
        }
    }
    if not acquired {
        return False;
    }
    self._record_holder(handle);
    return True;
}

impl WriteLock._record_holder(handle: Any) {
    try {
        handle.seek(0);
        handle.truncate();
        handle.write(f"{os.getpid()}\n");
        handle.flush();
    } except OSError {
        logger.debug("Cannot record write lock holder in %s", self.path);
    }
}

impl WriteLock.release {
    (handle, self._handle) = (self._handle, None);
    _open_locks.discard(self);
    if handle is None {
        return;
    }
    try {
        handle.seek(0);
        handle.truncate();
        handle.flush();
    } except OSError {}
    try {
        handle.close();
    } except OSError {}
}

impl WriteLock.holder_pid -> int | None {
    return read_write_lock_holder(self.db_path);
}

impl WriteLock.__enter__ -> WriteLock {
    self.acquire();
    return self;
}

impl WriteLock.__exit__(*_exc_: object) {
    _exc: any = tuple(_exc_);
    self.release();
}

impl WriteLock.__repr__ -> str {
    return (getattr(builtins.object, "__repr__") as any)(self);
}

impl WriteLock.__eq__(other: any) -> bool {
    return self is other;
}

impl WriteLock.__hash__ -> int {
    return id(self);
}
