import from __future__ { annotations }

import logging, re, sqlite3, unicodedata;

import from collections { Counter }

import from pathlib { Path }

import from typing { Any }

glob logger: any = logging.getLogger(__name__);

def _md_cell(value: Any) -> str;
def _slugify(name: str) -> str;
def _generate_community_page(store: GraphStore, community: dict[str, Any]) -> str;
def generate_wiki(store: GraphStore, wiki_dir: str | Path, force: bool = False) -> dict[str, Any];
def get_wiki_page(wiki_dir: str | Path, page_name: str) -> str | None;
