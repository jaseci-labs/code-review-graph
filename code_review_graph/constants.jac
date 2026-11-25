"""Shared constants for code-review-graph."""

import from __future__ { annotations }

import logging;

import math;

import os;

import from pathlib { Path, PurePath }

glob logger: any;

glob READ_ONLY_ENV: any;

glob _warned_env_vars: any;

glob SECURITY_KEYWORDS: frozenset[str];

glob GIT_TIMEOUT: any;

glob DISCOVERY_TIMEOUT_DEFAULT: any;

glob DISCOVERY_TIMEOUT_ENV: any;

glob GIT_TIMEOUT_ENV: any;

glob MAX_IMPACT_NODES: any;

glob MAX_IMPACT_DEPTH: any;

glob MAX_BFS_DEPTH: any;

glob MAX_SEARCH_RESULTS: any;

glob CALLER_TEST_ROUTE_DEPTH: any;

glob CALLER_TEST_ROUTE_MAX_CALLERS: any;

glob BFS_ENGINE: any;

glob IMPACT_EDGE_WEIGHTS: dict[str, float];

glob IMPACT_DEFAULT_EDGE_WEIGHT: any;

glob IMPACT_DIRECTION_INCOMING: any;

glob IMPACT_DIRECTION_OUTGOING: any;

glob IMPACT_DIRECTION_NONE: any;

glob IMPACT_EDGE_DIRECTIONS: dict[str, str];

glob IMPACT_DEFAULT_EDGE_DIRECTION: any;

glob IMPACT_DEPTH_DECAY: any;

glob IMPACT_SCORE_FLOOR: any;

glob CRG_HOME_ENV: any;

glob IMPORT_SCOPE_KEY: any;

glob CLAIMED_ENDPOINT_KEY: any;

glob INHERITED_ENDPOINT_KEY: any;

glob INHERITED_THROUGH_KEY: any;

glob IMPORT_SCOPE_PACKAGE: any;

glob IMPORT_SCOPE_TREE: any;

glob IMPORT_SCOPES: any;

glob _MALLOC_TRIM_FN: object | None;

glob _MALLOC_TRIM_PROBED: any;

glob IMPORT_CONTEXT_KEY: any;

glob IMPORT_CONTEXT_TYPE_ONLY: any;

glob IMPORT_CONTEXT_DEFERRED: any;

glob IMPORT_CONTEXT_PARENT_PACKAGE: any;

glob QUERY_PATTERNS: any;

with entry {
    logger = logging.getLogger(__name__);

    READ_ONLY_ENV = "CRG_READ_ONLY";
}

"""Return whether this process must avoid writes to graph state."""
def read_only_requested -> bool;

with entry {
    _warned_env_vars = set[any]();
}

"""Warn once per variable that its value was ignored."""
def _warn_invalid_env(name: str, raw: str, `default: object) -> None;

"""Read *name* as an int, falling back to *default* when it is unusable.

    An unset variable is the default silently; a set-but-unparseable one
    (empty string, word, version number) is the default *and* a warning
    naming the variable, so the operator can find the typo.
    """
def env_int(name: str, `default: int) -> int;

"""Read *name* as a float. See :func:`env_int` for the fallback rules.

    NaN and infinity are rejected alongside unparseable text: they are
    accepted by ``float()`` but poison every comparison they reach.
    """
def env_float(name: str, `default: float) -> float;

"""Read a finite float strictly inside ``(lower, upper)``.

    Invalid environment configuration falls back to the documented default
    instead of making graph traversal unbounded or failing during import.
    """
def _bounded_float_env(name: str, `default: float, *, lower: float, upper: float) -> float;

with entry {
    SECURITY_KEYWORDS = frozenset({
        "auth",
        "login",
        "password",
        "token",
        "session",
        "crypt",
        "secret",
        "credential",
        "permission",
        "sql",
        "query",
        "execute",
        "connect",
        "socket",
        "request",
        "http",
        "sanitize",
        "validate",
        "encrypt",
        "decrypt",
        "hash",
        "sign",
        "verify",
        "admin",
        "privilege",
    });
    GIT_TIMEOUT = env_int("CRG_GIT_TIMEOUT", 30);
    DISCOVERY_TIMEOUT_DEFAULT = 5.0;
    DISCOVERY_TIMEOUT_ENV = "CRG_DISCOVERY_TIMEOUT";
    GIT_TIMEOUT_ENV = "CRG_GIT_TIMEOUT";
}

"""Return the per-subprocess budget for read-only change discovery.

    Discovery is what a review tool runs when the caller did **not** pass
    ``changed_files``: ``resolve_review_base`` -> ``get_changed_files`` ->
    ``get_staged_and_unstaged``, three or four Git subprocesses in series. At
    the 30-second :data:`GIT_TIMEOUT` default that chain has a two-minute
    worst case, which is how one MCP review call overruns a client's request
    ceiling and comes back as MCP error -32001 (#262). All discovery is ever
    answering is "what am I looking at?", so it gets its own, far shorter
    budget by default, and build/update/watch keep the generous one.

    A short budget is only safe because discovery runs with ``require_vcs``:
    exhausting it raises
    :class:`~code_review_graph.errors.ChangeDiscoveryError` rather than
    returning an empty list. Shortening a budget that failed *silently* would
    only make a wrong all-clear more likely; shortening one that fails *loudly*
    trades a client-side -32001 for a message naming the knob.

    Resolved on **every call**, deliberately. ``CRG_GIT_TIMEOUT`` is parsed
    once at import into :data:`GIT_TIMEOUT`, so a test or a long-lived MCP
    server that sets that variable afterwards never sees the new value.
    Whatever these variables say when a discovery call starts is what that
    call uses.

    Precedence:

    1. ``CRG_DISCOVERY_TIMEOUT``, when it parses as a number >= 0. Used as
       given, including values above :data:`GIT_TIMEOUT` -- an explicit
       override is an instruction, not a hint.
    2. Otherwise ``CRG_GIT_TIMEOUT`` when the operator set it, verbatim.
       Raising that variable is the documented answer to slow Git, and it
       predates this one; a new default must not quietly cap it. Someone who
       asked for 120 seconds of Git gets 120 seconds of discovery.
    3. Otherwise :data:`DISCOVERY_TIMEOUT_DEFAULT`, capped at
       :data:`GIT_TIMEOUT` so an unset-but-lowered general budget still wins.

    An unparseable or negative value logs a warning and falls back to the next
    rule rather than leaving discovery unbounded or raising inside a tool call.
    """
def discovery_timeout -> float;

with entry {
    MAX_IMPACT_NODES = env_int("CRG_MAX_IMPACT_NODES", 500);
    MAX_IMPACT_DEPTH = env_int("CRG_MAX_IMPACT_DEPTH", 2);
    MAX_BFS_DEPTH = env_int("CRG_MAX_BFS_DEPTH", 15);
    MAX_SEARCH_RESULTS = env_int("CRG_MAX_SEARCH_RESULTS", 20);
    CALLER_TEST_ROUTE_DEPTH = env_int("CRG_CALLER_TEST_ROUTE_DEPTH", 2);
    CALLER_TEST_ROUTE_MAX_CALLERS = env_int("CRG_CALLER_TEST_ROUTE_MAX_CALLERS", 500);
    BFS_ENGINE = os.environ.get("CRG_BFS_ENGINE", "sql");
    IMPACT_EDGE_WEIGHTS = {
        "CALLS": 1.0,
        "INHERITS": 0.9,
        "OVERRIDES": 0.9,
        "IMPLEMENTS": 0.9,
        "TESTED_BY": 0.7,
        "REFERENCES": 0.6,
        "DEPENDS_ON": 0.6,
        "IMPORTS_FROM": 0.5,
        "CONTAINS": 0.3,
    };
    IMPACT_DEFAULT_EDGE_WEIGHT = 0.5;
    IMPACT_DIRECTION_INCOMING = "incoming";
    IMPACT_DIRECTION_OUTGOING = "outgoing";
    IMPACT_DIRECTION_NONE = "none";
    IMPACT_EDGE_DIRECTIONS = {
        "CALLS": IMPACT_DIRECTION_INCOMING,
        "INHERITS": IMPACT_DIRECTION_INCOMING,
        "OVERRIDES": IMPACT_DIRECTION_INCOMING,
        "IMPLEMENTS": IMPACT_DIRECTION_INCOMING,
        "TESTED_BY": IMPACT_DIRECTION_OUTGOING,
        "REFERENCES": IMPACT_DIRECTION_INCOMING,
        "DEPENDS_ON": IMPACT_DIRECTION_INCOMING,
        "IMPORTS_FROM": IMPACT_DIRECTION_INCOMING,
        "CONTAINS": IMPACT_DIRECTION_NONE,
    };
    IMPACT_DEFAULT_EDGE_DIRECTION = IMPACT_DIRECTION_INCOMING;

    IMPACT_DEPTH_DECAY = _bounded_float_env("CRG_IMPACT_DEPTH_DECAY", 0.6, lower=0.0, upper=1.0);
    IMPACT_SCORE_FLOOR = _bounded_float_env("CRG_IMPACT_SCORE_FLOOR", 0.05, lower=0.0, upper=1.0);
    CRG_HOME_ENV = "CRG_HOME";
}

"""Return the per-user state directory for code-review-graph.

    ``$CRG_HOME`` wins when set and non-empty; otherwise
    ``~/.code-review-graph``.

    Resolved per call rather than captured in a module-level constant. An
    import-time constant cannot be redirected afterwards, which is what let
    the test suite write into the real home directory of whoever ran it: by
    the time a fixture set the variable, the value had already been frozen.
    """
def crg_home -> Path;

with entry {
    IMPORT_SCOPE_KEY = "import_scope";
    CLAIMED_ENDPOINT_KEY = "claimed_endpoint";
    INHERITED_ENDPOINT_KEY = "inherited_endpoint";
    INHERITED_THROUGH_KEY = "inherited_through";
    IMPORT_SCOPE_PACKAGE = "package";
    IMPORT_SCOPE_TREE = "tree";

    IMPORT_SCOPES = (IMPORT_SCOPE_PACKAGE, IMPORT_SCOPE_TREE);
}

"""Return *path* as a forward-slash (POSIX) string for graph identity.

    ``file_path`` values and the path component of qualified names are graph
    identity: they must be separator-stable across operating systems so a
    graph built on Windows produces the same identifiers as one built on
    Linux/macOS, and so consumers that reconstruct identifiers from ``Path``
    objects always agree with the parser. See issue #774.

    Only apply this to file *paths* — never to symbol names: PHP namespace
    identifiers (``App\\Domain\\Job``) legitimately contain backslashes.
    """
def normalize_file_path(path: "str | os.PathLike[str]") -> str;

with entry {
    _MALLOC_TRIM_FN = None;
    _MALLOC_TRIM_PROBED = False;
}

"""Run garbage collection and return free heap pages to the OS where supported.

    Python's pymalloc and glibc's ptmalloc retain freed arenas in the process
    address space after large graph builds, AST parses, or NetworkX/embedding
    operations. Calling ``malloc_trim(0)`` on Linux returns unused heap pages
    to the kernel, directly lowering resident memory (RSS).
    """
def release_os_memory -> None;

with entry {
    IMPORT_CONTEXT_KEY = "import_context";
    IMPORT_CONTEXT_TYPE_ONLY = "type_only";
    IMPORT_CONTEXT_DEFERRED = "deferred";
    IMPORT_CONTEXT_PARENT_PACKAGE = "parent_package";
    QUERY_PATTERNS = {
        "callers_of": "Find all functions that call a given function",
        "references_to": "Find all nodes that reference a given symbol",
        "callees_of": "Find all functions called by a given function",
        "imports_of": "Find all imports of a given file or module",
        "importers_of": "Find all files that import a given file or module",
        "children_of": "Find all nodes contained in a file or class",
        "tests_for": "Find all tests for a given function or class",
        "inheritors_of": "Find all classes that inherit from a given class",
        "triggers_of": "Find methods invoked by a scheduler or other trigger",
        "triggered_by": "Find schedulers or other triggers that invoke a method",
        "publishers_of": "Find methods that publish an event",
        "listeners_of": "Find methods that listen for an event",
        "advises": "Find methods an AOP advice targets via its pointcut",
        "advised_by": "Find AOP advice methods that intercept a given method",
        "handlers_of": "Find methods that handle an endpoint",
        "endpoints_for": "Find endpoints handled by a method",
        "consumers_of": "Find classes that consume a Spring configuration property",
        "file_summary": "Get a summary of all nodes in a file",
        "path_to": "Find how a given symbol or file reaches another",
    };
}
