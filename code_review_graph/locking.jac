import from __future__ { annotations }

import builtins, operator, errno, logging, os, sys;

import from pathlib { Path }

import from typing { Any }

import from weakref { WeakSet }

glob logger: any = logging.getLogger(__name__);

glob _open_locks: WeakSet[WriteLock] = WeakSet();

def _close_inherited_locks;

with entry {
    if hasattr(os, "register_at_fork") {
        os.register_at_fork(after_in_child=_close_inherited_locks);
    }
}

glob WRITE_LOCK_NAME: any = "write.lock";

def write_lock_path(db_path: Path) -> Path;

def _flock_supported -> bool;
def _flock(handle: Any, blocking: bool) -> bool;
def read_write_lock_holder(db_path: Path) -> int | None;

obj WriteLock {
    has db_path: any,
        path: any,
        _handle: any;

    def init(db_path: Path);

    has held: bool {
        getter {
            return self._handle is not None;
        }
    }

    def acquire(*, blocking: bool = False) -> bool;
    def _record_holder(handle: Any);
    def release;
    def holder_pid -> int | None;

    def __enter__ -> WriteLock;

    def __exit__(*_exc_: object);

    def __repr__ -> str;

    def __eq__(other: any) -> bool;

    def __hash__ -> int;
}
