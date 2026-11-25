import from __future__ { annotations }

import json;

import logging;

import from typing { TYPE_CHECKING }

glob logger: any;

with entry {
    logger = logging.getLogger(__name__);
}

def resolve_temporal_calls(store: GraphStore) -> dict;
