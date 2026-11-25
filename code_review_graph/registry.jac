import from __future__ { annotations }

import builtins, json, logging, sqlite3, threading;

import from collections { OrderedDict }

import from pathlib { Path }

glob logger: any = logging.getLogger(__name__);

def default_registry_path -> Path;

obj Registry {
    has _path: any,
        _lock: any,
        _repos: any;

    def init(path: Path | None = None);
    def _load;
    def _save;
    def register(
        path: str, alias: str | None = None, data_dir: str | None = None
    ) -> dict[str, str];
    def unregister(path_or_alias: str) -> bool;
    def list_repos -> list[dict[str, str]];
    def find_by_alias(alias: str) -> dict[str, str] | None;
    def find_by_path(path: str) -> dict[str, str] | None;
    def set_data_dir(path: str, data_dir: str) -> dict[str, str];
    def get_data_dir_for_repo(path: str) -> str | None;

    def __repr__ -> str;

    def __eq__(other: any) -> bool;

    def __hash__ -> int;
}

obj ConnectionPool {
    has _max_size: any,
        _pool: any,
        _lock: any;

    def init(max_size: int = 10);
    def get(db_path: str) -> sqlite3.Connection;
    def close_all;

    has size: int {
        getter {
            with self._lock {
                return len(self._pool);
            }
        }
    }

    def __repr__ -> str;

    def __eq__(other: any) -> bool;

    def __hash__ -> int;
}

def resolve_repo(registry: Registry, repo: str | None, cwd: str | None = None) -> str | None;
