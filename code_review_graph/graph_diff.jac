import from __future__ { annotations }

import json;

import logging;

import from pathlib { Path }

import from typing { Any }

glob logger: any;

with entry {
    logger = logging.getLogger(__name__);
}

def take_snapshot(store: GraphStore) -> dict[str, Any];
def save_snapshot(snapshot: dict, path: Path);
def load_snapshot(path: Path) -> dict;
def diff_snapshots(before: dict, after: dict) -> dict[str, Any];
