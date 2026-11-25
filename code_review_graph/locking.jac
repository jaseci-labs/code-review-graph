"""Cross-process single-flight guard for graph writes.

``build`` and ``update`` are not only typed by hand.  They are fired from
commit hooks, editor-save hooks, agent tool hooks and the file watcher, and
several of those can start the same command within seconds of each other.
Until this module existed the only cross-process protection the graph had was
SQLite's busy timeout, which is not reached until the *first write*: every
duplicate run therefore paid for a complete parse — including spawning its own
process pool — before discovering that an older run had already done that work.
A hook firing ten times in a row started ten builds of the same working tree,
and the machine spent its CPU on nine builds whose output the last one
overwrote.

The lock is taken at the front door instead.  One run parses, a later run
returns immediately and names the process that owns the work, so a queue of
pending hook invocations collapses into a single build of the newest state.
``postprocess`` takes the same lock: it rewrites derived data (flows,
communities, FTS) for a graph another process may be half way through
building, which was the other half of the report in #1073. So do ``forget`` and
``embed``, for their whole run. ``watch`` takes it for each write and lets go
between them: it runs for days, and holding it throughout would stop every
build for as long as the watcher lived.

Properties this relies on, all of them deliberate:

* **Advisory and exclusive.** A cooperating process must ask for it; nothing
  else is prevented from reading or writing the database.
* **Scoped to one repository's database.** The lock file sits in the data
  directory next to ``graph.db``, so two repositories built at once never
  block each other. The name is fixed (``write.lock``) and documented, so
  external writers can exclude themselves from a build with
  ``flock -n .code-review-graph/write.lock external-writer``. Invoke CRG's
  protected commands directly: wrapping them in another flock makes them
  contend with their own wrapper (or deadlock with ``--wait``).
* **Non-blocking by default.** Skipping is the right answer for a hook: the
  in-flight build already covers the same working tree. Callers that want to
  wait (a human running ``build``/``update`` by hand) ask for it.
* **Kernel-released.** ``flock`` drops the lock when the holder dies, including
  on ``SIGKILL`` where no cleanup code of ours runs, so a crashed build never
  wedges a repository. A forked child would keep it alive, so children close
  their copy straight away.
* **``flock``, not ``lockf``.** flock locks belong to the open file
  description, so a probe from a second descriptor cannot silently drop a lock
  this process already holds.
"""

import builtins;

import operator;

import from __future__ { annotations }

import errno;

import logging;

import os;

import sys;

import from pathlib { Path }

import from typing { Any }

import from weakref { WeakSet }

glob logger: any;

glob _open_locks: WeakSet[WriteLock];

glob WRITE_LOCK_NAME: any;

with entry {
    logger = logging.getLogger(__name__);
    _open_locks = WeakSet();
}

def _close_inherited_locks -> None;

with entry {
    if hasattr(os, "register_at_fork") {
        os.register_at_fork(after_in_child=_close_inherited_locks);
    }
    WRITE_LOCK_NAME = "write.lock";
}

"""Return the write-lock path that governs *db_path*.

    Lives in the data directory rather than the repository so a graph stored
    outside the working tree (``CRG_DATA_DIR``, ``--data-dir``) keeps its lock
    with it. One database, one lock: everything sharing a ``graph.db`` also
    shares this file, which is what makes the exclusion complete.
    """
def write_lock_path(db_path: Path) -> Path;

def _flock_supported -> bool;

"""Take an exclusive lock on *handle*. Returns False when it is held."""
def _flock(handle: Any, blocking: bool) -> bool;

"""Return the PID that recorded itself as the lock holder, if any.

    Only meaningful while the lock is actually held: a released lock is
    truncated by [_WriteLock.release], so an empty file reads as ``None``.
    """
def read_write_lock_holder(db_path: Path) -> int | None;

"""Exclusive, per-repository guard held for the whole write window.

    ``acquire`` is idempotent within one instance so a caller can hold the lock
    across several stages, and re-entrancy is per instance rather than global:
    a second instance in the same process still contends, which is what makes
    the overlap testable without spawning a second process.
    """
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

    """Claim the lock, or report that somebody else holds it.

        Returns True when this instance owns the lock afterwards. On platforms
        without ``flock`` this is a no-op that reports success, so behaviour
        there is exactly what it was before this module existed.
        """
    def acquire(*, blocking: bool = False) -> bool;

    """Write this process's PID so a skipped run can name it.

        Best effort: the diagnostic is not worth failing a build over, and a
        stale PID here can only be read by a process that just failed to take
        the lock, which means a live holder is about to overwrite it.
        """
    def _record_holder(handle: Any) -> None;

    """Drop the lock if this instance holds it."""
    def release -> None;

    """PID of the process holding the lock, as recorded by its holder."""
    def holder_pid -> int | None;

    def __enter__ -> WriteLock;

    def __exit__(*_exc_: object) -> None;

    def __repr__ -> str;

    def __eq__(other: any) -> bool;

    def __hash__ -> int;
}
