"""Additional export formats: JSON, GraphML, Neo4j Cypher, Obsidian, SVG."""

import builtins;

import from __future__ { annotations }

import html;

import json;

import logging;

import os;

import re;

import tempfile;

import from pathlib { Path }

glob logger: any;

glob GRAPHML_NS: any;

glob GRAPHML_SCHEMA: any;

glob _XML_ILLEGAL: any;

with entry {
    logger = logging.getLogger(__name__);
}

"""An export needs a package that a default install does not ship.

    Subclasses ``ImportError`` so existing callers keep working, but is
    specific enough that a CLI can catch it and print the one-line install
    hint instead of a traceback — without swallowing an ImportError raised
    by a genuinely broken install of a required package.
    """
obj MissingOptionalDependencyError(ImportError) {
    def __repr__ -> str;

    def __eq__(other: any) -> bool;

    def __hash__ -> int;
}

"""Export the complete local graph payload as UTF-8 JSON atomically.

    The payload can contain absolute local paths and code-structure metadata.
    Callers are responsible for deciding whether it is safe to publish.
    """
def export_json(store: GraphStore, output_path: Path) -> Path;

with entry {
    GRAPHML_NS = "http://graphml.graphdrawing.org/xmlns";
    GRAPHML_SCHEMA = "http://graphml.graphdrawing.org/xmlns/1.0/graphml.xsd";
    _XML_ILLEGAL = re.compile("[\\x00-\\x08\\x0b\\x0c\\x0e-\\x1f]");
}

"""Escape a value for XML element content.

    Drops the control characters XML 1.0 cannot represent at all, then
    escapes the markup characters. Element content (unlike an attribute
    value) is not whitespace-normalised, so a newline survives verbatim.
    """
def _xml_text(value: object) -> str;

"""Export the graph as GraphML XML.

    The document declares the official GraphML namespace and validates
    against the GraphML 1.0 schema. That schema types ``node/@id`` as an
    ``NMTOKEN``, which cannot hold the ``/`` in a qualified name, and XML
    attribute-value normalisation would fold a newline inside a name onto a
    space and silently merge two distinct nodes. So the identity travels in
    a ``<data key="qualified_name">`` element and the ids are synthetic.

    Returns the path to the written file.
    """
def export_graphml(store: GraphStore, output_path: Path) -> Path;

"""Export the graph as Neo4j Cypher CREATE statements.

    Returns the path to the written file.
    """
def export_neo4j_cypher(store: GraphStore, output_path: Path) -> Path;

"""Escape a string for Cypher single-quoted literals."""
def _cypher_escape(s: str) -> str;

"""Format a dict as Cypher property map.

    ``bool`` is tested before ``int`` because it is a subclass of ``int``:
    the other order makes the boolean branch unreachable and emits Python's
    ``True``/``False`` instead of Cypher's ``true``/``false``.
    """
def _cypher_props(d: dict) -> str;

"""Export the graph as an Obsidian vault with wikilinks.

    Creates:
    - One .md per node with YAML frontmatter and [[wikilinks]]
    - _COMMUNITY_*.md overview notes per community
    - _INDEX.md with links to all nodes

    Returns the output directory path.
    """
def export_obsidian_vault(store: GraphStore, output_dir: Path) -> Path;

"""Render a frontmatter value as a scalar any YAML parser will accept.

    A bare scalar cannot carry ``": "``, a leading ``#``, a quote or a
    newline, and a legal POSIX file path can contain all of them, so
    anything that is not a number is emitted double-quoted. JSON string
    syntax is a subset of YAML's double-quoted style, so ``json.dumps``
    produces exactly the escaping YAML expects. ``bool`` is tested before
    ``int`` because it is a subclass of ``int``.
    """
def _yaml_scalar(value: object) -> str;

"""Convert a name to an Obsidian-friendly filename slug."""
def _obsidian_slug(name: str) -> str;

"""Map each node's qualified name to a slug no other node has.

    A name that slugifies like an earlier one gets ``-1``, ``-2`` and so on.
    Taken slugs are kept in a set, and each base remembers the suffix it
    reached, so a thousand nodes named ``__init__`` cost a thousand steps,
    not a scan of every earlier slug for each suffix tried.
    """
def _obsidian_slugs(nodes: list[dict]) -> dict[str, str];

"""Export a static SVG graph visualization.

    Requires matplotlib (optional dependency).
    Returns the path to the written file.

    Raises:
        MissingOptionalDependencyError: If matplotlib is not installed.
            Callers on a user-facing surface should print the message and
            exit non-zero rather than let it become a traceback.
    """
def export_svg(store: GraphStore, output_path: Path) -> Path;
