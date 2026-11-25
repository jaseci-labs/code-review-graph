"""Post-build resolver for PHP/Rust/C# scoped calls and receiver-typed calls.

Tree-sitter extraction records a scoped/static call such as ``Mailer::send($x)``
(PHP) or ``Mailer::send(x)`` / ``Self::new()`` (Rust) as a ``CALLS`` edge whose
target is the intermediate ``Class::method`` string.  That string matches
neither the canonical node key (``<file>::Class.method``) nor a bare method
name, so ``callers_of``, ``get_impact_radius`` and ``tests_for`` never see the
edge and report zero callers for a method that is obviously being called
(GitHub #567).

PHP instance calls keep their historical bare method target during parsing.
When a local receiver was directly constructed (``$x = new Type(); $x->run()``),
the parser stores the class as ``extra.receiver_scope`` and this pass uses that
evidence to resolve the call without changing parse-only output (GitHub #745).

C# calls use the dedicated namespace-aware pass in ``csharp_resolver``.

This module runs after the graph is built and rewrites the resolvable
``Class::method`` targets to the canonical qualified name of the defined
method node, in the same style as the Spring/Temporal/ReScript resolvers.

It is deliberately conservative so it never fabricates an edge:

* Only genuine ``Class::method`` targets are considered; already-resolved
  targets (``<file>::Class.method``) are left alone.
* ``self`` / ``static`` (PHP) and ``self`` / ``Self`` (Rust) resolve to the
  enclosing class/type of the caller.
* A target resolves when exactly one ``(class, method)`` node exists in the
  graph and the caller's file backs it (same file, an import naming the class,
  or for PHP the caller's own namespace), or when the caller file's
  ``IMPORTS_FROM`` edges disambiguate between several same-named definitions.
  Being the only match in the graph is not enough on its own.
* Ambiguous or unknown targets (external types such as ``Vec::new`` or
  ``Redis::get`` with no in-graph definition) are left untouched, keeping the
  behaviour of unresolved external calls exactly as it is today.

Rewritten edges are tagged ``confidence_tier = INFERRED`` to distinguish a
heuristically resolved scoped call from a directly-extracted one.

Language notes:

* PHP scopes are namespace-qualified (``App\\Mail\\Mailer``) and PHP keywords
  are case-insensitive, so ``self`` / ``static`` (any case) mean the enclosing
  class.
* Rust scoped calls come through as ``::``-joined path segments.  Only genuine
  two-segment ``Type::method`` targets are resolved; multi-segment module paths
  (``crate::mailer::Mailer::new``) are left alone because resolving them by
  their last two segments would point at an unrelated type.  ``Self`` (the
  associated-function receiver) resolves to the enclosing type, while lowercase
  ``self`` is a *module* path — never a type — so it is not resolved here.
"""

import operator;

import from __future__ { annotations }

import json;

import logging;

import from pathlib { Path }

import from typing { TYPE_CHECKING, Optional }

glob logger: any;

glob _SCOPED_LANGUAGES: any;

glob _RECEIVER_SCOPE_LANGUAGES: any;

glob _METHOD_KINDS: any;

glob _PHP_SELF_SCOPES: any;

glob _IMPORT_SEGMENT_SEPARATORS: any;

with entry {
    logger = logging.getLogger(__name__);
    _SCOPED_LANGUAGES = ("php", "rust");
    _RECEIVER_SCOPE_LANGUAGES = ("php",);
    _METHOD_KINDS = ("Function", "Test", "Method");
    _PHP_SELF_SCOPES = {"self", "static"};
    _IMPORT_SEGMENT_SEPARATORS = ("::", "\\", "/");
}

"""Split an import target into its path segments on any separator."""
def _import_segments(target: str) -> list[str];

"""Case-fold identifiers for PHP (case-insensitive) but not Rust.

    PHP class and function names are matched case-insensitively by the language,
    so ``Mailer::DISPATCH`` and ``mailer::dispatch`` name the same symbol.  Rust
    identifiers are case-sensitive, so ``Mailer::send`` and ``Mailer::Send`` are
    different symbols and must never be conflated.
    """
def _fold(name: str, language: str) -> str;

"""Path split into segments, with the file extension stripped off the last.

    ``/repo/src/Queue/Mailer.php`` → ``["repo", "src", "Queue", "Mailer"]``;
    ``/repo/src/mailer.rs`` → ``["repo", "src", "mailer"]``.
    """
def _path_tokens(file_path: str) -> list[str];

"""Normalize path separators for exact resolved-import comparisons."""
def _path_key(file_path: str) -> str;

"""Whether a complete import/module suffix matches a defining file path."""
def _path_ends_with(path_tokens: list[str], suffix: list[str], language: str) -> bool;

"""Return complete import suffixes that can safely identify a source path.

    PHP projects commonly map one leading namespace root (for example ``App``)
    onto a source directory. Rust imports carry a trailing type and may start
    with a module-root keyword. We strip only those known structural segments;
    arbitrary leading namespace/module segments are never discarded.
    """
def _safe_import_suffixes(segments: list[str], language: str) -> list[list[str]];

"""True when *target* is a raw ``Class::method`` string, not a node key.

    Canonical node names have the shape ``<abs-file>::Class.method`` — the head
    before the first ``::`` is a filesystem path and the tail after the last
    ``::`` contains a ``.``.  A raw scoped call (``Mailer::dispatch``,
    ``App\\Mail\\Mailer::dispatch``) has neither, so it is what we resolve.
    """
def _is_unresolved_scoped_target(target: str) -> bool;

"""Return the class/type short name that encloses a caller node, if any.

    ``<file>::Mailer.dispatch`` → ``Mailer``; a free function
    ``<file>::register`` (no ``.``) → ``None``.
    """
def _enclosing_class(source_qualified: str) -> Optional[str];

"""Parse a raw scoped target into ``(class, method, needs_enclosing)``.

    ``class`` is ``None`` when ``needs_enclosing`` is set (``self`` / ``Self`` /
    ``static``), signalling the caller's enclosing class should be used.
    Returns ``None`` for targets that must be left untouched (``parent::``, a
    Rust module path, a lowercase ``self::`` module call, …).
    """
def _scope_and_method(target: str, language: str) -> Optional[tuple[Optional[str], str, bool]];

"""Rewrite evidence-backed scoped CALLS targets to node qualified names.

    Safe to call repeatedly. PHP/Rust skip resolved edges; C# re-evaluates
    retained source references and only writes bindings that have changed.

    Returns a dict with resolution counts for telemetry.
    """
def resolve_scoped_calls(store: GraphStore, repo_root: Path | None = None) -> dict;
