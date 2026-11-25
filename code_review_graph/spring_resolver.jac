"""Post-build Spring DI call resolver.

After tree-sitter parsing, Java CALLS edges whose target is a bare method
name (e.g. ``calculate``) carry ``extra.receiver`` naming the local variable
that was called on (e.g. ``invoiceCalculationService``).  This module
resolves those receivers through the INJECTS map to their declared type, then
optionally to the unique concrete implementation via INHERITS edges.

Resolution chain:
    receiver variable name
        → injected interface/class (from INJECTS.extra.field_name)
        → concrete implementation (from INHERITS, when unique)

Only Java files are processed.  Edges that are already qualified (contain
``::``) or have no ``receiver`` extra key are skipped.
"""

import from __future__ { annotations }

import json;

import logging;

import from typing { TYPE_CHECKING }

glob logger: any;

with entry {
    logger = logging.getLogger(__name__);
}

"""Resolve Java CALLS edges whose receiver is a Spring-injected field.

    Safe to call multiple times — already-resolved edges (targets containing
    ``::``) are skipped.

    Returns a dict with resolution counts for telemetry.
    """
def resolve_spring_di_calls(store: GraphStore) -> dict;
