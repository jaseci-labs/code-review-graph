"""Tools 21, 22: list_repos_func, cross_repo_search_func."""

import from __future__ { annotations }

import logging;

import from pathlib { Path }

import from typing { Any }

glob logger: any;

glob _MAX_CROSS_REPO_RESULTS: any;

glob _MAX_ECHOED_NAMES: any;

with entry {
    logger = logging.getLogger(__name__);
    _MAX_CROSS_REPO_RESULTS = 100;
    _MAX_ECHOED_NAMES = 20;
}

"""List all registered repositories.

    [REGISTRY] Returns the list of repositories registered in the global
    multi-repo registry at ``~/.code-review-graph/registry.json``.

    Returns:
        List of registered repos with paths and aliases.
    """
def list_repos_func -> dict[str, Any];

"""Pick the registry entries named by ``names``, preserving registry order.

    A name matches an entry's alias first, and only if no alias matches does
    it match the final component of an entry's path, so an entry registered
    as ``{"path": ".../billing-api", "alias": "billing"}`` is selected by
    either ``["billing"]`` or ``["billing-api"]``. Aliases are resolved
    before folder names across the WHOLE registry, so an explicit alias
    always beats another entry's incidental folder name.

    A name that matches several entries selects ALL of them. Selecting only
    the first would search fewer repositories than the caller asked for
    while reporting nothing missing, which is the failure ``unknown`` exists
    to prevent; sibling checkouts sharing a folder name are the normal case
    this parameter was added for.

    Registry order is preserved so the caller cannot change the merge
    tie-breaker by reordering ``names``.

    Returns the selected entries, the names that matched nothing, and the
    names that matched more than one entry.
    """
def _select_repos(
    repos: list[dict[str, Any]], names: list[str]
) -> tuple[list[dict[str, Any]], list[str], list[str]];

"""Bound and sanitise a caller-supplied name list before echoing it back.

    ``repos`` is the only unbounded input this tool echoes. Returning it
    verbatim let a single call carry many times the tool's own token budget
    while reporting ``truncated: False``. Sanitising matches what every
    other name in a response gets and caps each entry at 256 characters.
    """
def _echoed(names: list[str]) -> tuple[list[str], int, bool];

"""Search across registered repositories.

    [REGISTRY] Runs hybrid_search on each registered repo's graph database
    and merges the results.

    Args:
        query: Search query string.
        kind: Optional node kind filter (e.g. "Function", "Class").
        limit: Maximum results per repo (default: 20).
        max_results: Maximum merged results to return across all repos
            (default 50, capped at 100). ``total`` reports the untruncated
            merged count; without it the response grew with the number of
            registered repos rather than with the caller's ``limit``.
        repos: Optional aliases or folder names to search. Omitted or empty
            searches every registered repo. A registry that spans unrelated
            products otherwise contributes each repo's best local rank to the
            top of the merged list, so the caller pays for repositories that
            cannot answer the question. Matching is exact and case-sensitive
            and paths are not accepted, unlike ``Registry.resolve_repo``:
            this parameter only ever narrows an already-trusted registry, and
            a name that does not match is reported rather than guessed at.
            Names matching no entry are returned in ``unknown`` rather than
            dropped, since a silently skipped repo is indistinguishable from
            one that simply had no matches; names matching several entries
            select all of them and are listed in ``ambiguous``.

    Returns:
        Combined search results from the searched repos, plus ``total``
        and ``truncated``. When ``repos`` was given, also ``unknown`` and
        ``ambiguous`` with their ``*_total`` counts, both bounded like every
        other list in a response.
    """
def cross_repo_search_func(
    query: str,
    kind: str | None = None,
    limit: int = 20,
    max_results: int = 50,
    repos: list[str] | None = None,
) -> dict[str, Any];
