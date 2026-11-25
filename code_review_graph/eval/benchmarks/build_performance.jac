import from __future__ { annotations }

import importlib;

import logging;

import time;

import from pathlib { Path }

glob logger: any;

with entry {
    logger = logging.getLogger(__name__);
}

def run(repo_path: Path, store, config: dict) -> list[dict];
