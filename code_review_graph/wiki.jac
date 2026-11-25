"""Wiki generation from community structure.

Generates markdown pages for each detected community and an index page,
providing a navigable documentation wiki for the codebase architecture.
"""

import from __future__ { annotations }

import logging;

import re;

import sqlite3;

import unicodedata;

import from collections { Counter }

import from pathlib { Path }

import from typing { Any }

glob logger: any;

with entry {
    logger = logging.getLogger(__name__);
}

"""Render a value as one line of Markdown: a table cell or a heading.

    A ``|`` inside a table cell opens another column and a newline ends the
    row, so a node or community name carrying either corrupts the table it
    is written into (and a newline spills the tail of a heading into the
    page body). Pipes become the ``&#124;`` character reference, which
    renders as ``|`` without being read as a column separator; ``&`` is
    escaped first so the substitution stays reversible, and line breaks
    collapse to a space.
    """
def _md_cell(value: Any) -> str;

"""Convert a community name to a safe filename slug."""
def _slugify(name: str) -> str;

"""Build markdown content for a single community.

    Includes: heading, overview (size, cohesion, language), members table
    (top 50), execution flows through the community, and dependencies.

    Args:
        store: The graph store.
        community: Community dict from get_communities().

    Returns:
        Markdown string for the community page.
    """
def _generate_community_page(store: GraphStore, community: dict[str, Any]) -> str;

"""Generate a markdown wiki from the community structure.

    For each community, generates a markdown page. Also generates an
    index.md with links to all community pages.

    Args:
        store: The graph store.
        wiki_dir: Directory to write wiki pages into.
        force: If True, regenerate all pages even if content unchanged.

    Returns:
        Dict with pages_generated, pages_updated, pages_unchanged counts.
    """
def generate_wiki(store: GraphStore, wiki_dir: str | Path, force: bool = False) -> dict[str, Any];

"""Retrieve a specific wiki page by community name.

    Args:
        wiki_dir: Directory containing wiki pages.
        page_name: Community name (will be slugified for filename lookup).

    Returns:
        Page content as a string, or None if the page does not exist.
    """
def get_wiki_page(wiki_dir: str | Path, page_name: str) -> str | None;
