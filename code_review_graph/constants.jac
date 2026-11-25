import from __future__ { annotations }

import logging, math, os;

import from pathlib { Path, PurePath }

glob logger: any = logging.getLogger(__name__);

glob READ_ONLY_ENV: any = "CRG_READ_ONLY";

def read_only_requested -> bool {
    return os.environ.get(READ_ONLY_ENV, "").strip().lower() in {"1", "true", "yes", "on"};
}

glob _warned_env_vars: any = set[any]();

def _warn_invalid_env(name: str, raw: str, `default: object) {
    if name in _warned_env_vars {
        return;
    }
    _warned_env_vars.add(name);
    logger.warning(
        "Ignoring invalid %s=%r (not a number); using the default %s.", name, raw, `default
    );
}

def env_int(name: str, `default: int) -> int {
    raw: any = os.environ.get(name);
    if raw is None {
        return `default;
    }
    try {
        return `int(raw.strip());
    } except (TypeError, ValueError) {
        _warn_invalid_env(name, raw, `default);
        return `default;
    }
}

def env_float(name: str, `default: float) -> float {
    raw: any = os.environ.get(name);
    if raw is None {
        return `default;
    }
    try {
        value: any = `float(raw.strip());
    } except (TypeError, ValueError) {
        _warn_invalid_env(name, raw, `default);
        return `default;
    }
    if not math.isfinite(value) {
        _warn_invalid_env(name, raw, `default);
        return `default;
    }
    return value;
}

def _bounded_float_env(name: str, `default: float, *, lower: float, upper: float) -> float {
    raw: any = os.environ.get(name);
    if raw is None {
        return `default;
    }
    try {
        value: any = `float(raw);
    } except (TypeError, ValueError) {
        return `default;
    }
    if not math.isfinite(value) or not lower < value < upper {
        return `default;
    }
    return value;
}

glob SECURITY_KEYWORDS: frozenset[str] = frozenset(
    ("auth login password token session crypt secret credential permission sql query execute "
        "connect socket request http sanitize validate encrypt decrypt hash sign verify admin "
        "privilege").split(),
);

glob GIT_TIMEOUT: any = env_int("CRG_GIT_TIMEOUT", 30);

glob DISCOVERY_TIMEOUT_DEFAULT: any = 5.0;

glob DISCOVERY_TIMEOUT_ENV: any = "CRG_DISCOVERY_TIMEOUT";

glob GIT_TIMEOUT_ENV: any = "CRG_GIT_TIMEOUT";

def discovery_timeout -> float {
    explicit_git: any = os.environ.get(GIT_TIMEOUT_ENV);
    if explicit_git is not None and explicit_git.strip() {
        fallback: any = `float(GIT_TIMEOUT);
    } else {
        fallback = min(DISCOVERY_TIMEOUT_DEFAULT, `float(GIT_TIMEOUT));
    }

    raw: any = os.environ.get(DISCOVERY_TIMEOUT_ENV);
    if raw is None or not raw.strip() {
        return fallback;
    }
    value: any = env_float(DISCOVERY_TIMEOUT_ENV, fallback);
    if value < 0 {
        logger.warning(
            "Ignoring invalid %s=%r (negative); using %.3gs for change discovery.",
            DISCOVERY_TIMEOUT_ENV,
            raw,
            fallback,
        );
        return fallback;
    }
    return value;
}

glob MAX_IMPACT_NODES: any = env_int("CRG_MAX_IMPACT_NODES", 500);

glob MAX_IMPACT_DEPTH: any = env_int("CRG_MAX_IMPACT_DEPTH", 2);

glob MAX_BFS_DEPTH: any = env_int("CRG_MAX_BFS_DEPTH", 15);

glob MAX_SEARCH_RESULTS: any = env_int("CRG_MAX_SEARCH_RESULTS", 20);

glob CALLER_TEST_ROUTE_DEPTH: any = env_int("CRG_CALLER_TEST_ROUTE_DEPTH", 2);

glob CALLER_TEST_ROUTE_MAX_CALLERS: any = env_int("CRG_CALLER_TEST_ROUTE_MAX_CALLERS", 500);

glob BFS_ENGINE: any = os.environ.get("CRG_BFS_ENGINE", "sql");

glob IMPACT_EDGE_WEIGHTS: dict[str, float] = {
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

glob IMPACT_DEFAULT_EDGE_WEIGHT: any = 0.5;

glob IMPACT_DIRECTION_INCOMING: any = "incoming";

glob IMPACT_DIRECTION_OUTGOING: any = "outgoing";

glob IMPACT_DIRECTION_NONE: any = "none";

glob IMPACT_EDGE_DIRECTIONS: dict[str, str] = {
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

glob IMPACT_DEFAULT_EDGE_DIRECTION: any = IMPACT_DIRECTION_INCOMING;

glob IMPACT_DEPTH_DECAY: any = _bounded_float_env(
    "CRG_IMPACT_DEPTH_DECAY", 0.6, lower=0.0, upper=1.0
);

glob IMPACT_SCORE_FLOOR: any = _bounded_float_env(
    "CRG_IMPACT_SCORE_FLOOR", 0.05, lower=0.0, upper=1.0
);

glob CRG_HOME_ENV: any = "CRG_HOME";

def crg_home -> Path {
    `override: any = os.environ.get(CRG_HOME_ENV, "").strip();
    if `override {
        return Path(`override).expanduser();
    }
    return Path.home() / ".code-review-graph";
}

glob IMPORT_SCOPE_KEY: any = "import_scope";

glob CLAIMED_ENDPOINT_KEY: any = "claimed_endpoint";

glob INHERITED_ENDPOINT_KEY: any = "inherited_endpoint";

glob INHERITED_THROUGH_KEY: any = "inherited_through";

glob IMPORT_SCOPE_PACKAGE: any = "package";

glob IMPORT_SCOPE_TREE: any = "tree";

glob IMPORT_SCOPES: any = (IMPORT_SCOPE_PACKAGE, IMPORT_SCOPE_TREE);

def normalize_file_path(path: "str | os.PathLike[str]") -> str {
    if isinstance(path, `str) {
        return path.replace("\\", "/") if "\\" in path else path;
    }
    if isinstance(path, PurePath) {
        return path.as_posix();
    }
    return `str(path).replace("\\", "/");
}

glob _MALLOC_TRIM_FN: object | None = None;

glob _MALLOC_TRIM_PROBED: any = False;

def release_os_memory {
    import gc;
    import sys;

    gc.collect();
    if sys.platform.startswith("linux") {
        if not _MALLOC_TRIM_PROBED {
            _MALLOC_TRIM_PROBED = True;
            try {
                import ctypes;

                _MALLOC_TRIM_FN = ctypes.CDLL("libc.so.6").malloc_trim;
            } except Exception {
                _MALLOC_TRIM_FN = None;
            }
        }
        if callable(_MALLOC_TRIM_FN) {
            try {
                _MALLOC_TRIM_FN(0);
            } except Exception as exc {
                logger.debug("malloc_trim(0) failed: %s", exc);
            }
        }
    }
}

glob IMPORT_CONTEXT_KEY: any = "import_context";

glob IMPORT_CONTEXT_TYPE_ONLY: any = "type_only";

glob IMPORT_CONTEXT_DEFERRED: any = "deferred";

glob IMPORT_CONTEXT_PARENT_PACKAGE: any = "parent_package";

glob QUERY_PATTERNS: any = {
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
