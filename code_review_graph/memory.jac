import from __future__ { annotations }

import logging;

import re;

import time;

import from pathlib { Path }

import from typing { Any }

glob logger: any;

with entry {
    logger = logging.getLogger(__name__);
}

def save_result(
    question: str,
    answer: str,
    nodes: list[str] | None = None,
    result_type: str = "query",
    memory_dir: Path | None = None,
    repo_root: Path | None = None,
) -> Path;
def list_memories(
    memory_dir: Path | None = None, repo_root: Path | None = None
) -> list[dict[str, Any]];
def clear_memories(memory_dir: Path | None = None, repo_root: Path | None = None) -> int;
