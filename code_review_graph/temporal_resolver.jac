import from __future__ { annotations }

import json, logging;

import from typing { TYPE_CHECKING }

glob logger: any = logging.getLogger(__name__);

def resolve_temporal_calls(store: GraphStore) -> dict;
