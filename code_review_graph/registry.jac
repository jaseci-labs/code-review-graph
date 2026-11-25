import from __future__ { annotations }

import builtins, json, logging, sqlite3, threading;

import from collections { OrderedDict }

import from pathlib { Path }

glob logger: any = logging.getLogger(__name__);

def default_registry_path -> Path {
    return crg_home() / "registry.json";
}

obj Registry {
    has _path: any,
        _lock: any,
        _repos: any;

    def init(path: Path | None = None) {
        self._path = path or default_registry_path();
        self._path.parent.mkdir(parents=True, exist_ok=True);
        self._lock = threading.Lock();
        self._repos = [];
        self._load();
    }

    def _load {
        if self._path.exists() {
            try {
                data: any = json.loads(self._path.read_text(encoding="utf-8", errors="replace"));
                self._repos = data.get("repos", []);
            } except (json.JSONDecodeError, KeyError, TypeError) {
                logger.warning("Invalid registry file, starting fresh: %s", self._path);
                self._repos = [];
            }
        } else {
            self._repos = [];
        }
    }

    def _save {
        self._path.parent.mkdir(parents=True, exist_ok=True);
        data: any = {"repos": self._repos};
        self._path.write_text(
            json.dumps(data, indent=2, ensure_ascii=False) + "\n", encoding="utf-8"
        );
    }

    def register(
        path: str, alias: str | None = None, data_dir: str | None = None
    ) -> dict[str, str] {
        resolved: any = Path(path).resolve();
        if not resolved.is_dir() {
            raise ValueError(f"Path is not a directory: {resolved}");
        }
        has_repo_marker: any = (resolved / ".git").exists()
            or (resolved / ".svn").exists()
            or (resolved / ".code-review-graph").exists();
        if not has_repo_marker {
            raise ValueError(
                f"Path does not look like a repository (no .git, .svn, or .code-review-graph): {resolved}",
            );
        }

        with self._lock {
            str_path: any = `str(resolved);
            for `entry in self._repos {
                if `entry["path"] == str_path {
                    if alias {
                        `entry["alias"] = alias;
                    }
                    if data_dir {
                        `entry["data_dir"] = `str(Path(data_dir).resolve());
                    }
                    self._save();
                    return `entry;
                }
            }

            new_entry: dict[str, str] = {"path": str_path};
            if alias {
                new_entry["alias"] = alias;
            }
            if data_dir {
                new_entry["data_dir"] = `str(Path(data_dir).resolve());
            }
            self._repos.append(new_entry);
            self._save();
            return new_entry;
        }
    }

    def unregister(path_or_alias: str) -> bool {
        with self._lock {
            resolved: any = `str(Path(path_or_alias).resolve());
            original_len: any = len(self._repos);
            self._repos = [
                `entry
                for `entry in self._repos
                if `entry["path"] != resolved and `entry.get("alias") != path_or_alias
            ];
            if len(self._repos) < original_len {
                self._save();
                return True;
            }
            return False;
        }
    }

    def list_repos -> list[dict[str, str]] {
        with self._lock {
            return `list(self._repos);
        }
    }

    def find_by_alias(alias: str) -> dict[str, str] | None {
        with self._lock {
            for `entry in self._repos {
                if `entry.get("alias") == alias {
                    return `dict(`entry);
                }
            }
            return None;
        }
    }

    def find_by_path(path: str) -> dict[str, str] | None {
        resolved: any = `str(Path(path).resolve());
        with self._lock {
            for `entry in self._repos {
                if `entry["path"] == resolved {
                    return `dict(`entry);
                }
            }
            return None;
        }
    }

    def set_data_dir(path: str, data_dir: str) -> dict[str, str] {
        resolved: any = `str(Path(path).resolve());
        data_resolved: any = `str(Path(data_dir).resolve());

        with self._lock {
            for `entry in self._repos {
                if `entry["path"] == resolved {
                    `entry["data_dir"] = data_resolved;
                    self._save();
                    return `dict(`entry);
                }
            }
            new_entry: any = {"path": resolved, "data_dir": data_resolved};
            self._repos.append(new_entry);
            self._save();
            return new_entry;
        }
    }

    def get_data_dir_for_repo(path: str) -> str | None {
        resolved: any = `str(Path(path).resolve());
        with self._lock {
            for `entry in self._repos {
                if `entry["path"] == resolved {
                    return `entry.get("data_dir");
                }
            }
            return None;
        }
    }

    def __repr__ -> str {
        return (getattr(builtins.object, "__repr__") as any)(self);
    }

    def __eq__(other: any) -> bool {
        return self is other;
    }

    def __hash__ -> int {
        return id(self);
    }
}

obj ConnectionPool {
    has _max_size: any,
        _pool: any,
        _lock: any;

    def init(max_size: int = 10) {
        self._max_size = max_size;
        self._pool = OrderedDict();
        self._lock = threading.Lock();
    }

    def get(db_path: str) -> sqlite3.Connection {
        key: any = `str(Path(db_path).resolve());
        with self._lock {
            if key in self._pool {
                self._pool.move_to_end(key);
                return self._pool[key];
            }
            while len(self._pool) >= self._max_size {
                evict_key: any;
                evict_conn: any;
                (evict_key, evict_conn) = self._pool.popitem(last=False) as any;
                try {
                    evict_conn.close();
                } except sqlite3.Error {
                    logger.debug("Failed to close evicted connection: %s", evict_key);
                }
                logger.debug("Evicted connection: %s", evict_key);
            }

            conn: any = sqlite3.connect(
                key, timeout=30, check_same_thread=False, isolation_level=None
            );
            conn.row_factory = sqlite3.Row;
            conn.execute("PRAGMA journal_mode=WAL");
            conn.execute("PRAGMA busy_timeout=5000");
            self._pool[key] = conn;
            return conn;
        }
    }

    def close_all {
        with self._lock {
            for (key, conn) in self._pool.items() {
                try {
                    conn.close();
                } except sqlite3.Error {
                    logger.debug("Failed to close connection: %s", key);
                }
            }
            self._pool.clear();
        }
    }

    has size: int {
        getter {
            with self._lock {
                return len(self._pool);
            }
        }
    }

    def __repr__ -> str {
        return (getattr(builtins.object, "__repr__") as any)(self);
    }

    def __eq__(other: any) -> bool {
        return self is other;
    }

    def __hash__ -> int {
        return id(self);
    }
}

def resolve_repo(registry: Registry, repo: str | None, cwd: str | None = None) -> str | None {
    if repo {
        `entry: any = registry.find_by_alias(repo);
        if `entry {
            return `entry["path"];
        }
        path: any = Path(repo).resolve();
        if path.is_dir() {
            return `str(path);
        }
    }
    if cwd {
        return `str(Path(cwd).resolve());
    }

    return None;
}
