import from __future__ { annotations }

import importlib;

import logging;

import os;

import re;

import subprocess;

import from dataclasses { dataclass }

import from datetime { datetime }

import from pathlib { Path }

import from typing { TYPE_CHECKING, Any }

glob logger: any;

glob MAX_CONFIDENCE_CHARS: any;

glob IMPACT_PATTERN: any;

glob _UPDATE_HINT: any;

glob _WHITESPACE: any;

glob _JS_FAMILY: any;

glob _CALL_PATTERNS: any;

glob _IMPORT_PATTERNS: any;

glob LANGUAGE_GAPS: tuple[LanguageGap, ...];

with entry {
    logger = logging.getLogger(__name__);
    MAX_CONFIDENCE_CHARS = 140;
    IMPACT_PATTERN = "impact_radius";

    _UPDATE_HINT = "run `code-review-graph update`";

    _WHITESPACE = re.compile("\\s+");
}

@dataclass(frozen=True)
class LanguageGap {
    has languages: frozenset[str];

    has patterns: frozenset[str];

    has note: str;
}

with entry {
    _JS_FAMILY = frozenset({"javascript", "typescript", "tsx"});
    _CALL_PATTERNS = frozenset({
        "callers_of",
        "callees_of",
        "tests_for",
        "advises",
        "advised_by",
        IMPACT_PATTERN,
    });
    _IMPORT_PATTERNS = frozenset({"imports_of", "importers_of", IMPACT_PATTERN});
    LANGUAGE_GAPS = (
        LanguageGap(
            languages=frozenset({"php"}),
            patterns=_IMPORT_PATTERNS,
            note="php dynamic include/require paths are not evaluated, so importers can be missing here (#819)",
        ),
        LanguageGap(
            languages=frozenset({"php"}),
            patterns=_CALL_PATTERNS,
            note="php container-resolved and constructor-injected calls are not statically traced, so callers can be missing (#850, #851)",
        ),
        LanguageGap(
            languages=_JS_FAMILY,
            patterns=frozenset({"handlers_of", "endpoints_for"}),
            note="js/ts route registration is not indexed and endpoint edges are spring-only, so handlers can be missing",
        ),
        LanguageGap(
            languages=_JS_FAMILY,
            patterns=_IMPORT_PATTERNS,
            note="npm-aliased imports resolve only to one local package whose version fits the alias, so importers can be missing here (#343)",
        ),
        LanguageGap(
            languages=_JS_FAMILY,
            patterns=_CALL_PATTERNS,
            note="js/ts callbacks land on REFERENCES not CALLS, and obj[name]() is unresolved, so callers can be missing",
        ),
        LanguageGap(
            languages=frozenset({"java"}),
            patterns=_CALL_PATTERNS,
            note="java aop pointcuts (within/args/target/this, cross-aspect refs, compound booleans) and reflective calls are not resolved (#592)",
        ),
        LanguageGap(
            languages=frozenset({"go"}),
            patterns=frozenset({"inheritors_of"}),
            note="go interface satisfaction is structural, never declared, so implementers can be missing from inheritors_of",
        ),
        LanguageGap(
            languages=frozenset({"csharp"}),
            patterns=_CALL_PATTERNS,
            note="c# di-container registrations are not statically traced, so interface-typed callers can be missing here",
        ),
        LanguageGap(
            languages=frozenset({"python"}),
            patterns=_CALL_PATTERNS,
            note="python getattr dispatch and decorator-based registration are not statically traced, so callers can be missing here",
        ),
    );
}

def gap_note(language: str | None, pattern: str) -> str | None;
def _clip(text: str, limit: int) -> str;
def _clean(text: str) -> str;
def _fragment(text: str, limit: int) -> str;
def _bounded(note: str) -> str;
def _interpolated(prefix: str, value: str, suffix: str) -> str;
def _target_fragment(target: str, limit: int) -> str;
def _interpolated_target(prefix: str, target: str, suffix: str) -> str;
def not_indexed_note(target: str) -> str;
def unresolved_stale_note(target: str) -> str;
def _confirmed_note(target: str, current: bool) -> str;
def _live_git_head(`root: Path) -> str | None;
def _untracked_sources(`root: Path, store: GraphStore) -> int | None;
def _is_untracked_note(note: str) -> bool;
def _untracked_note(count: int) -> str;
def _settled(`root: Path, store: GraphStore, verified: bool) -> tuple[str | None, bool];
def _staleness(store: GraphStore, `root: Path, file_path: str | None) -> tuple[str | None, bool];
def empty_query_confidence(
    store: GraphStore, `root: Path, pattern: str, target: str, `node: Any | None = None
) -> str | None;
def empty_impact_confidence(
    store: GraphStore,
    `root: Path,
    changed_files: list[str],
    resolved_files: list[str],
    language: str | None = None,
) -> str | None;
def guessed_calls_confidence(split: dict[str, int] | None) -> str | None;
def empty_search_confidence(store: GraphStore, `root: Path, query: str) -> str | None;
