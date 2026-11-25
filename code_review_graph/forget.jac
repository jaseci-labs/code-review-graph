import from __future__ { annotations }

import importlib, hashlib, logging;

import from pathlib { Path }

import from typing { Any }

glob logger: any = logging.getLogger(__name__);

glob _SQL_PARAM_CHUNK: any = 400;

def _referrer_files(
    store: GraphStore, deleted_qualified_names: set[str], forgotten: set[str]
) -> list[str];
def _purge_orphan_embeddings(store: GraphStore) -> int;
def forget_files(store: GraphStore, repo_root: Path, targets: list[str]) -> dict[str, Any];
