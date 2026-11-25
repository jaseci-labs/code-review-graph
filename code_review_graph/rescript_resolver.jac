import from __future__ { annotations }

import json;

import logging;

import from pathlib { Path }

import from typing { TYPE_CHECKING }

glob logger: any;

with entry {
    logger = logging.getLogger(__name__);
}

def resolve_rescript_cross_module(store: GraphStore) -> dict;
def _resolve_call_target(
    target: str,
    file_path: str,
    basename_to_path: dict[str, str],
    opens_by_file: dict[str, list[str]],
    store: GraphStore,
) -> tuple[str | None, str | None];
def _pick_existing_qualified(target_file: str, rest: str, store: GraphStore) -> str | None;
