import from __future__ { annotations }

import importlib, logging;

import from pathlib { Path }

glob logger: any = logging.getLogger(__name__);

def run(repo_path: Path, store, config: dict) -> list[dict];
