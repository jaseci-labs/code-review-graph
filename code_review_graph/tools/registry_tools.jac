import from __future__ { annotations }

import importlib, logging;

import from pathlib { Path }

import from typing { Any }

glob logger: any = logging.getLogger(__name__);

glob _MAX_CROSS_REPO_RESULTS: any = 100;

glob _MAX_ECHOED_NAMES: any = 20;

def list_repos_func -> dict[str, Any];
def _select_repos(
    repos: list[dict[str, Any]], names: list[str]
) -> tuple[list[dict[str, Any]], list[str], list[str]];
def _echoed(names: list[str]) -> tuple[list[str], int, bool];
def cross_repo_search_func(
    query: str,
    kind: str | None = None,
    limit: int = 20,
    max_results: int = 50,
    repos: list[str] | None = None,
) -> dict[str, Any];
