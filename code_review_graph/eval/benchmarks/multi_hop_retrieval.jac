import from __future__ { annotations }

import importlib, logging;

import from pathlib { Path }

import from typing { Any }

glob logger: any = logging.getLogger(__name__);

def _name_set(rows: list[dict[str, Any]]) -> set[str];
def run(repo_path: Path, store, config: dict) -> list[dict];
