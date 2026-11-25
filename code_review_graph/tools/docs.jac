import from __future__ { annotations }

import importlib;

import operator;

import logging;

import from pathlib { Path }

import from typing { Any }

glob logger: any;

glob _MAX_WIKI_CHARS: any;

with entry {
    logger = logging.getLogger(__name__);
    _MAX_WIKI_CHARS = 80000;
}

def embed_graph(
    repo_root: str | None = None,
    model: str | None = None,
    provider: str | None = None,
    wait_for_lock: bool = False,
) -> dict[str, Any];
def get_docs_section(section_name: str, repo_root: str | None = None) -> dict[str, Any];
def generate_wiki_func(repo_root: str | None = None, force: bool = False) -> dict[str, Any];
def get_wiki_page_func(
    community_name: str, repo_root: str | None = None, max_chars: int = 20000
) -> dict[str, Any];
