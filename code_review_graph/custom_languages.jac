import from __future__ { annotations }

import logging, re, sys, threading;

import from collections.abc { Mapping }

import from dataclasses { dataclass, field }

import from pathlib { Path }

import from typing { Optional }

glob tomllib: any;

with entry {
    if sys.version_info >= (3, 11) {
        import tomllib;
    } else {
        try {
            import tomli as tomllib;
        } except ImportError {
            tomllib = None;
        }
    }
}

glob logger: any = logging.getLogger(__name__);

glob CONFIG_RELATIVE_PATH: any = Path(".code-review-graph") / "languages.toml";

glob MAX_CUSTOM_LANGUAGES: any = 20;

glob _NAME_RE: any = re.compile("^[a-z][a-z0-9_-]{0,31}$");

glob _EXTENSION_RE: any = re.compile("^\\.[a-z0-9_+-]{1,15}$");

glob _NODE_TYPE_KEYS: any = (
    "function_node_types",
    "class_node_types",
    "import_node_types",
    "call_node_types",
);

glob MAX_NAME_FIELD_CANDIDATES: any = 8;

@dataclass(frozen=True)
class CustomLanguage {
    has name: str;

    has grammar: str;

    has extensions: tuple[str, ...];

    has function_node_types: tuple[str, ...] = ();

    has class_node_types: tuple[str, ...] = ();

    has import_node_types: tuple[str, ...] = ();

    has call_node_types: tuple[str, ...] = ();

    has comment: str = "";

    has name_field: tuple[str, ...] = ();
}

@dataclass(frozen=True)
class _CacheEntry {
    has mtime_ns: int;

    has size: int;

    has languages: dict[str, CustomLanguage] = field(default_factory=dict[any, any]);
}

glob _cache_lock: any = threading.Lock();

glob _cache: dict[str, _CacheEntry] = {};

def clear_cache;
def load_custom_languages(
    repo_root: Path, *, builtin_extensions: Mapping[str, str], builtin_languages: frozenset[str]
) -> dict[str, CustomLanguage];

def _load_uncached(
    config_path: Path, builtin_extensions: Mapping[str, str], builtin_languages: frozenset[str]
) -> dict[str, CustomLanguage];
def _validate_entry(
    name: object,
    table: object,
    builtin_extensions: Mapping[str, str],
    builtin_languages: frozenset[str],
    claimed_extensions: set[str],
    config_path: Path,
) -> Optional[CustomLanguage];

def __getattr__(name: str) -> any;
