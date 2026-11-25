"""Config-driven custom language support ("bring your own language").

Repos can teach the parser new tree-sitter languages without forking by
dropping a ``languages.toml`` file into ``.code-review-graph/``::

    [languages.erlang]
    extensions = [".erl", ".hrl"]
    grammar = "erlang"                        # tree_sitter_language_pack name
    function_node_types = ["function_clause"]
    class_node_types = ["record_decl"]
    import_node_types = ["import_attribute"]
    call_node_types = ["call"]
    comment = "Erlang via the bundled tree-sitter-erlang grammar"

The loader is deliberately defensive: a broken config must never crash a
build.  Invalid entries are skipped with a ``logger.warning``, and built-in
languages always win — custom entries can neither override built-in file
extensions nor reuse built-in language names.  At most
``MAX_CUSTOM_LANGUAGES`` entries are honoured per repo.

See docs/CUSTOM_LANGUAGES.md for the full schema reference (answers #320).
"""

import from __future__ { annotations }

import logging;

import re;

import sys;

import threading;

import from collections.abc { Mapping }

import from dataclasses { dataclass, field }

import from pathlib { Path }

import from typing { Optional }

glob tomllib: any;

glob logger: any;

glob CONFIG_RELATIVE_PATH: any;

glob MAX_CUSTOM_LANGUAGES: any;

glob _NAME_RE: any;

glob _EXTENSION_RE: any;

glob _NODE_TYPE_KEYS: any;

glob MAX_NAME_FIELD_CANDIDATES: any;

glob _cache_lock: any;

glob _cache: dict[str, _CacheEntry];

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

    logger = logging.getLogger(__name__);
    CONFIG_RELATIVE_PATH = Path(".code-review-graph") / "languages.toml";
    MAX_CUSTOM_LANGUAGES = 20;
    _NAME_RE = re.compile("^[a-z][a-z0-9_-]{0,31}$");
    _EXTENSION_RE = re.compile("^\\.[a-z0-9_+-]{1,15}$");
    _NODE_TYPE_KEYS = (
        "function_node_types",
        "class_node_types",
        "import_node_types",
        "call_node_types",
    );
    MAX_NAME_FIELD_CANDIDATES = 8;
}

"""One validated ``[languages.<name>]`` entry from languages.toml."""
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

with entry {
    _cache_lock = threading.Lock();
    _cache = {};
}

"""Drop the loader cache (used by tests)."""
def clear_cache -> None;

"""Load and validate ``<repo_root>/.code-review-graph/languages.toml``.

    Returns a mapping of custom language name -> :class:`CustomLanguage`.
    Always returns (possibly empty) — a broken config never raises.

    Args:
        repo_root: Repository root containing ``.code-review-graph/``.
        builtin_extensions: The parser's built-in extension map; custom
            entries colliding with these are skipped (built-ins win).
        builtin_languages: All built-in language identifiers; custom names
            shadowing these are skipped.
    """
def load_custom_languages(
    repo_root: Path, *, builtin_extensions: Mapping[str, str], builtin_languages: frozenset[str]
) -> dict[str, CustomLanguage];

def _load_uncached(
    config_path: Path, builtin_extensions: Mapping[str, str], builtin_languages: frozenset[str]
) -> dict[str, CustomLanguage];

"""Validate one ``[languages.<name>]`` table; None (after a warning) on
    any problem so a bad entry can never break a build."""
def _validate_entry(
    name: object,
    table: object,
    builtin_extensions: Mapping[str, str],
    builtin_languages: frozenset[str],
    claimed_extensions: set[str],
    config_path: Path,
) -> Optional[CustomLanguage];

def __getattr__(name: str) -> any;
