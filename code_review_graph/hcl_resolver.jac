"""Post-build resolution for Terraform module-scoped graph relationships."""

import from __future__ { annotations }

import json;

import logging;

import from pathlib { Path }

import from typing { TYPE_CHECKING }

glob logger: any;

with entry {
    logger = logging.getLogger(__name__);
}

"""Connect Terraform references across sibling files in one module.

    Terraform treats every ``.tf`` file in a directory as one module. The
    parser is intentionally file-local, so it emits a same-file placeholder
    target first; this pass replaces it only when one node with that name
    exists in the source file's directory. Local module sources are also
    connected to a parsed target file, preferring ``main.tf``.
    """
def resolve_hcl_module_references(store: GraphStore) -> dict[str, int];
