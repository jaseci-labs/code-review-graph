"""Honest uncertainty markers for graph results (#314, #819, #850, #851, #984).

A bare ``result_count: 0`` is ambiguous. It can mean "the code really has no
such relationship", or it can mean "this graph cannot see that relationship":
the target was never indexed, the graph is behind the working tree, or the
target's language has a known static-analysis blind spot. Reading agents take
the first meaning, and then either draw a wrong conclusion or abandon the
graph and grep the whole repository.

One short sentence on the empty case is therefore a *token saving*, not a
cost: it replaces a multi-thousand-token fallback search with roughly thirty
tokens of honesty. To keep that trade favourable the marker is hard-capped at
``MAX_CONFIDENCE_CHARS`` and is attached only when a result list is empty, or
when call-site rows in it are name matches rather than confirmed links, so a
response whose results are all certain stays byte-identical to before.

The language table below is data, not scattered conditionals. Every entry
describes a gap that is real in this codebase *today*; capabilities that have
since been implemented (Go struct/interface embedding, Kotlin imports,
dotted-stem JS/TS import resolution, Python keyword-argument callbacks) are
deliberately absent.
"""

import from code_review_graph._lazy { lazy }

import importlib;

import from __future__ { annotations }

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

"""One verified blind spot in the parser, scoped to the queries it affects.

    ``patterns`` is what keeps the note honest: a container-resolution caveat
    belongs on ``callers_of`` and ``tests_for``, and never on ``file_summary``,
    whose empty result has nothing to do with call resolution.
    """
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

"""Return the first verified gap note for *language* under *pattern*."""
def gap_note(language: str | None, pattern: str) -> str | None;

"""Truncate *text* to *limit* characters, marking the cut."""
def _clip(text: str, limit: int) -> str;

"""Make attacker-controlled source text safe to embed in one line.

    ``_sanitize_name`` is the project's established defence: it strips ASCII
    control characters and caps length. It deliberately keeps tabs and
    newlines, which would let a crafted node name break this single-line
    advisory into fake extra lines, so they are collapsed here as well.
    """
def _clean(text: str) -> str;

"""Sanitized text, guaranteed to fit *limit* characters."""
def _fragment(text: str, limit: int) -> str;

"""Final gate: nothing leaves this module over the budget."""
def _bounded(note: str) -> str;

"""Build ``prefix + value + suffix`` without letting *value* blow the cap."""
def _interpolated(prefix: str, value: str, suffix: str) -> str;

"""Fit a query target into *limit*, keeping the half that identifies it.

    Qualified names are ``path::symbol``, so a left-anchored truncation throws
    away the symbol and keeps a directory prefix, the least useful half. Drop
    to the bare symbol before resorting to clipping. The split runs on the raw
    target because sanitising first can cut the ``::`` off a very long path.
    """
def _target_fragment(target: str, limit: int) -> str;

"""``_interpolated`` for query targets, which are qualified names."""
def _interpolated_target(prefix: str, target: str, suffix: str) -> str;

"""Say that the graph never saw *target*, so the zero proves nothing."""
def not_indexed_note(target: str) -> str;

"""Say the target is missing from a graph that predates HEAD.

    A stale graph explains the miss and has a remedy, so it outranks the
    flat "not indexed" wording, which reads like a permanent limitation.
    """
def unresolved_stale_note(target: str) -> str;

"""Say the zero is a real absence, so the agent can stop searching.

    The strong wording is only used when currency was actually checked. When
    it could not be (no VCS, no build metadata), the weaker sentence still
    saves the fallback search without claiming something unverified.
    """
def _confirmed_note(target: str, current: bool) -> str;

"""Read the checked-out commit.

    Imported lazily: ``tools._common`` pulls in the tool modules, which import
    this module, so a module-level import would be circular. The call costs a
    subprocess, which is why staleness is only ever checked on an empty result
    and never on the hot path.
    """
def _live_git_head(`root: Path) -> str | None;

"""Count source files git has never seen, which the index cannot contain.

    ``update`` discovers changes through git, so a file that was never added
    is absent from the graph however current the build is. Neither signal in
    ``_staleness`` can see it: the build commit still matches HEAD, and a file
    the graph holds no row for has no mtime to compare against. The gap is
    widest exactly when it matters most, because the files an agent has just
    written are the ones it is about to ask about.

    "Source" is calibrated from the graph rather than a fixed extension list,
    so a repo whose languages this build does not parse never reports a file
    the index was never going to hold. ``--exclude-standard`` honours
    ``.gitignore``, and the graph's own ignore rules are applied on top, since
    ``git add`` cannot bring in a file the graph is told to skip.

    A file the graph already holds is not counted: ``watch`` indexes a new
    file whether or not git has seen it. ``ls-files`` lists only what lies
    under ``root`` (``-- .`` says so explicitly), so a graph rooted below the
    repository top level never counts its siblings, and it prints paths
    relative to ``root``. ``git status --porcelain`` does neither: it reports
    the whole repository relative to the top level, and those paths never
    match a stored one once the graph root is a subfolder.

    Returns ``None`` when the scan could not run, which proves nothing either
    way. A clean tree returns before the graph's file inventory is read.
    """
def _untracked_sources(`root: Path, store: GraphStore) -> int | None;

"""Distinguish the untracked signal from the two commit/mtime ones.

    An unresolved target on a stale graph is rewritten into wording about the
    target; that rewrite would drop the file count, which is the actionable
    part here.
    """
def _is_untracked_note(note: str) -> bool;

"""Say the working tree holds source the index was never offered."""
def _untracked_note(count: int) -> str;

"""Last check before a caller is allowed to treat the graph as current.

    Reached from both places where the commit and mtime signals find nothing
    wrong, including the early return taken when a graph carries no build
    timestamp. Untracked source is the only remaining way for the index to be
    missing content, so it has to be answered on every such path rather than
    on the one that happens to have metadata.
    """
def _settled(`root: Path, store: GraphStore, verified: bool) -> tuple[str | None, bool];

"""Return ``(stale_note, currency_verified)`` for the graph.

    Two independent signals, either of which can prove staleness: the build
    commit versus the checked-out commit, and the target file's mtime versus
    the build timestamp. The second matters because a commit match says
    nothing about uncommitted edits. ``currency_verified`` is only ``True``
    when a check actually ran and passed, so callers never confuse "checked
    and fresh" with "could not check".
    """
def _staleness(store: GraphStore, `root: Path, file_path: str | None) -> tuple[str | None, bool];

"""Return the marker for an empty ``query_graph`` result, or ``None``.

    The priority order is deliberate: an unresolved target makes the zero
    meaningless, a stale graph makes it untrustworthy, and a known language
    gap makes it incomplete. Only when none of those hold is the zero worth
    believing, and saying so is what stops an agent grepping anyway.
    """
def empty_query_confidence(
    store: GraphStore, `root: Path, pattern: str, target: str, `node: Any | None = None
) -> str | None;

"""Return the marker for an empty ``get_impact_radius`` blast radius."""
def empty_impact_confidence(
    store: GraphStore,
    `root: Path,
    changed_files: list[str],
    resolved_files: list[str],
    language: str | None = None,
) -> str | None;

"""Return the marker for call-site rows that are only name matches.

    A row marked ``target_resolution`` says it is a guess; this says how much of
    the answer is, and how to ask for the rest.
    """
def guessed_calls_confidence(split: dict[str, int] | None) -> str | None;

"""Return the marker for a ``semantic_search_nodes`` run with zero hits."""
def empty_search_confidence(store: GraphStore, `root: Path, query: str) -> str | None;
