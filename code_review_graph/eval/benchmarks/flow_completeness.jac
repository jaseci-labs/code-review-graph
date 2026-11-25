"""Flow completeness benchmark: evaluates entry point detection and flow tracing."""

import importlib;

import from __future__ { annotations }

import logging;

import from pathlib { Path }

glob logger: any;

with entry {
    logger = logging.getLogger(__name__);
}

"""Run flow completeness benchmark."""
def run(repo_path: Path, store, config: dict) -> list[dict];
