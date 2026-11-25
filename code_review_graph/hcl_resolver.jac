import from __future__ { annotations }

import json;

import logging;

import from pathlib { Path }

import from typing { TYPE_CHECKING }

glob logger: any;

with entry {
    logger = logging.getLogger(__name__);
}

def resolve_hcl_module_references(store: GraphStore) -> dict[str, int];
