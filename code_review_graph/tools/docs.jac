"""Tools 7, 8, 19, 20: embed_graph, get_docs_section, wiki tools."""

import operator;

import from __future__ { annotations }

import logging;

import from pathlib { Path }

import from typing { Any }

glob logger: any;

glob _MAX_WIKI_CHARS: any;

with entry {
    logger = logging.getLogger(__name__);
    _MAX_WIKI_CHARS = 80000;
}

"""Compute vector embeddings for all graph nodes to enable semantic search.

    Requires: ``pip install "code-review-graph[embeddings]"`` (local provider only;
    cloud providers like ``openai`` / ``google`` / ``minimax`` / ``voyage`` use
    stdlib ``urllib``).
    Default model: all-MiniLM-L6-v2. Override via ``model`` param or
    provider-specific env vars such as CRG_EMBEDDING_MODEL, CRG_OPENAI_MODEL, or
    CRG_VOYAGE_MODEL.
    Changing the model or provider re-embeds all nodes automatically.

    Only embeds nodes that don't already have up-to-date embeddings.

    Args:
        repo_root: Repository root path. Auto-detected if omitted.
        model: Embedding model name. For local: HuggingFace ID or path;
               for openai: model ID (e.g. ``text-embedding-3-small``);
               for google: Gemini model ID; for voyage: Voyage model ID
               (e.g. ``voyage-code-3``). Falls back to CRG_EMBEDDING_MODEL /
               CRG_OPENAI_MODEL / CRG_VOYAGE_MODEL env vars as appropriate.
        provider: Provider name: ``local`` (default), ``openai``, ``google``,
                  ``minimax``, or ``voyage``. ``openai`` requires CRG_OPENAI_BASE_URL +
                  CRG_OPENAI_API_KEY + CRG_OPENAI_MODEL env vars and accepts
                  any OpenAI-compatible endpoint.
                  ``voyage`` requires VOYAGE_API_KEY and defaults to
                  voyage-code-3 unless a model arg or CRG_VOYAGE_MODEL is
                  supplied.
        wait_for_lock: Block until another write to this graph finishes rather
                  than stand down. The CLI's ``--wait``.

    Returns:
        Number of nodes embedded and total embedding count. The summary reports
        semantic search as unavailable when no embeddings exist. A run that
        stood down because another writer holds the graph's write lock returns
        ``status: contended`` and embeds nothing.
    """
def embed_graph(
    repo_root: str | None = None,
    model: str | None = None,
    provider: str | None = None,
    wait_for_lock: bool = False,
) -> dict[str, Any];

"""Return a specific section from the LLM-optimized reference.

    Used by skills and Claude Code to load only the exact documentation
    section needed, keeping token usage minimal (90%+ savings).

    Args:
        section_name: Exact section name. One of: usage, review-delta,
                      review-pr, commands, legal, watch, embeddings,
                      languages, troubleshooting.
        repo_root: Repository root path. Auto-detected from current
                   directory if omitted.

    Returns:
        The section content, or an error if not found.
    """
def get_docs_section(section_name: str, repo_root: str | None = None) -> dict[str, Any];

"""Generate a markdown wiki from the community structure.

    [DOCS] Creates a wiki page for each detected community and an index
    page. Pages are written to ``.code-review-graph/wiki/`` inside the
    repository. Only regenerates pages whose content has changed unless
    force=True.

    Args:
        repo_root: Repository root path. Auto-detected if omitted.
        force: If True, regenerate all pages even if content is unchanged.

    Returns:
        Status with pages_generated, pages_updated, pages_unchanged counts.
    """
def generate_wiki_func(repo_root: str | None = None, force: bool = False) -> dict[str, Any];

"""Retrieve a specific wiki page by community name.

    [DOCS] Returns the markdown content of the wiki page for the given
    community. The wiki must have been generated first via generate_wiki.

    Args:
        community_name: Community name to look up (slugified for filename).
        repo_root: Repository root path. Auto-detected if omitted.
        max_chars: Maximum characters of page content to return (default
            20000, capped at 80000). A wiki page grows with its community,
            so a 3000-member community produces a page no context window
            wants in one call. ``total_chars`` reports the real length.

    Returns:
        Page content or not_found status, with ``truncated`` when cut.
    """
def get_wiki_page_func(
    community_name: str, repo_root: str | None = None, max_chars: int = 20000
) -> dict[str, Any];
