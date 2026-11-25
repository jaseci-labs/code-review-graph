"""Post-build Temporal workflow/activity call resolver.

After tree-sitter parsing, Java CALLS edges whose target is a bare method
name carry ``extra.receiver`` naming the local variable called on.  This
module resolves those receivers through the TEMPORAL_STUB map to their
declared Temporal interface type, then optionally to the unique concrete
implementation via INHERITS edges.

Resolution chain:
    receiver variable name
        → temporal stub field type (from TEMPORAL_STUB.extra.field_name)
        → concrete implementation (from INHERITS, when unique)

Only Java files are processed.  TEMPORAL_STUB edges whose target is not a
node with ``temporal_role`` in extra are silently skipped (they may be
non-Temporal types that happen to end in 'Activity'/'Workflow').
"""

import from __future__ { annotations }

import json;

import logging;

import from typing { TYPE_CHECKING }

glob logger: any;

with entry {
    logger = logging.getLogger(__name__);
}

"""Resolve Java CALLS edges whose receiver is a Temporal activity/workflow stub.

    Safe to call multiple times — already-resolved edges (with
    ``extra.temporal_resolved``) are skipped.

    Returns a dict with resolution counts for telemetry.
    """
def resolve_temporal_calls(store: GraphStore) -> dict;
