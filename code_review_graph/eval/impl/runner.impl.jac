impl _require_yaml -> any {
    if yaml is None {
        raise ImportError("pyyaml is required: pip install \"code-review-graph[eval]\"");
    }
}

impl _validate_config(config: object, path: Path) -> dict {
    if not isinstance(config, `dict) {
        raise ValueError(f"{path}: evaluation config must be a mapping");
    }
    test_commits: any = config.get("test_commits", []);
    if test_commits {
        latest: any = test_commits[-1].get("sha");
        if not latest or config.get("commit") != latest {
            raise ValueError(f"{path}: commit pin must equal latest test_commit {latest}");
        }
    }
    return config;
}

impl load_config(name: str) -> dict {
    _require_yaml();
    path: any = CONFIGS_DIR / f"{name}.yaml";
    f: any;
    with open(path, encoding="utf-8") as f {
        return _validate_config(yaml.safe_load(f), path);
    }
}

impl load_all_configs -> list[dict] {
    _require_yaml();
    configs: any = [];
    for p in sorted(CONFIGS_DIR.glob("*.yaml")) {
        f: any;
        with open(p, encoding="utf-8") as f {
            configs.append(_validate_config(yaml.safe_load(f), p));
        }
    }
    return configs;
}

impl _assert_standalone_repo(repo_path: Path) -> None {
    proc: any = subprocess.run(
        ["git", "rev-parse", "--show-toplevel"], cwd=`str(repo_path), capture_output=True, text=True
    );
    toplevel: any = Path(proc.stdout.strip()).resolve()
        if proc.returncode == 0 and proc.stdout.strip()
        else None;
    if toplevel != repo_path.resolve() {
        raise RuntimeError(
            format(repo_path, "")
                + " exists but is not a standalone git repository (git resolves it to "
                + format(toplevel or "no repository", "")
                + "). Refusing to fetch or check out there, because those commands would operate on the enclosing repository instead. Remove "
                + format(repo_path, "")
                + " and re-run to get a clean clone.",
        );
    }
}

impl clone_or_update(config: dict, repos_dir: Path | None = None) -> Path {
    repos_dir = repos_dir or DEFAULT_REPOS;
    repos_dir.mkdir(parents=True, exist_ok=True);
    repo_path: any = repos_dir / config["name"];

    if repo_path.exists() {
        _assert_standalone_repo(repo_path);
        proc: any = subprocess.run(
            ["git", "fetch", "--all", "--tags"], cwd=`str(repo_path), capture_output=True, text=True
        );
        if proc.returncode != 0 {
            raise RuntimeError(f"git fetch failed in {repo_path}: {proc.stderr.strip()}");
        }
    } else {
        proc = subprocess.run(
            ["git", "clone", config["url"], `str(repo_path)], capture_output=True, text=True
        );
        if proc.returncode != 0 {
            raise RuntimeError(
                "git clone failed for "
                    + format(config["url"], "")
                    + ": "
                    + format(proc.stderr.strip(), ""),
            );
        }
    }

    commit: any = config.get("commit", "HEAD");
    if commit != "HEAD" {
        proc = subprocess.run(
            ["git", "checkout", commit], cwd=`str(repo_path), capture_output=True, text=True
        );
        if proc.returncode != 0 {
            raise RuntimeError(
                f"git checkout {commit} failed in {repo_path}: {proc.stderr.strip()}"
            );
        }
    }

    return repo_path;
}

impl write_csv(results: list[dict], path: Path) -> None {
    if not results {
        return;
    }
    path.parent.mkdir(parents=True, exist_ok=True);
    fieldnames: any = `list(results[0].keys());
    f: any;
    with open(path, "w", encoding="utf-8", newline="") as f {
        writer: any = csv.DictWriter(f, fieldnames=fieldnames);
        writer.writeheader();
        writer.writerows(results);
    }
}

impl _embedding_count(store) -> int | None {
    try {
        row: any = store._conn.execute("SELECT count(*) FROM embeddings").fetchone();
    } except sqlite3.OperationalError as exc {
        if "no such table" in `str(exc).lower() {
            return None;
        }
        raise;
    }
    return `int(row[0]) if row else 0;
}

impl _build_embedding_index(store, db_path, provider: str | None, model: str | None) -> None {
    import from code_review_graph.embeddings { EmbeddingStore, embed_all_nodes }

    try {
        emb_store: any = EmbeddingStore(db_path, provider=provider, model=model);
    } except ValueError as exc {
        logger.error("  embedding index unavailable: %s", exc);
        return;
    }

    try {
        if not emb_store.available {
            logger.error(
                "  embedding provider %r is not available — install code-review-graph[embeddings] for the local provider, or check the cloud provider's environment variables. Semantic benchmarks will report no_graph_results.",
                provider or "local",
            );
            return;
        }
        embedded: any = embed_all_nodes(store, emb_store);
        logger.info("  embedding index: %d new vector(s), %d total", embedded, emb_store.count());
    } finally {
        emb_store.close();
    }
}

impl _warn_if_semantic_index_missing(store, benchmark_names: list[str]) -> None {
    requested: any = SEMANTIC_BENCHMARKS.intersection(benchmark_names);
    if not requested or _embedding_count(store) {
        return;
    }
    logger.warning(
        "  no vector index — %s will score natural-language questions against FTS5 alone and return zero hits. Re-run with --embed.",
        ", ".join(sorted(requested)),
    );
}

impl run_eval(
    repos: list[str] | None = None,
    benchmarks: list[str] | None = None,
    output_dir: str | Path | None = None,
    embed: bool = False,
    embedding_provider: str | None = None,
    embedding_model: str | None = None,
) -> dict[str, list[dict]] {
    output_dir = Path(output_dir) if output_dir else DEFAULT_OUTPUT;
    output_dir.mkdir(parents=True, exist_ok=True);

    if repos {
        configs: any = [load_config(r) for r in repos];
    } else {
        configs = load_all_configs();
    }

    benchmark_names: any = benchmarks or `list(BENCHMARK_REGISTRY.keys());
    all_results: dict[str, list[dict]] = {};
    today: any = date.today().isoformat();

    for config in configs {
        name: any = config["name"];
        logger.info("Evaluating %s...", name);
        repo_path: any = clone_or_update(config).resolve();
        import from code_review_graph.graph { GraphStore }
        import from code_review_graph.incremental { full_build, get_db_path }
        import from code_review_graph.postprocessing { run_post_processing }

        db_path: any = get_db_path(repo_path);
        store: any = GraphStore(db_path);

        try {
            full_build(repo_path, store);
            pp_result: any = run_post_processing(store);
            for warning in pp_result.get("warnings", []) {
                logger.warning("  postprocessing: %s", warning);
            }
            if embed {
                _build_embedding_index(store, db_path, embedding_provider, embedding_model);
            }
            _warn_if_semantic_index_missing(store, benchmark_names);
        } except BaseException {
            store.close();
            raise;
        }
        benchmark_config: any = `dict(config);
        if embed {
            benchmark_config["_embedding_provider"] = embedding_provider;
            benchmark_config["_embedding_model"] = embedding_model;
        }

        for bench_name in benchmark_names {
            if bench_name not in BENCHMARK_REGISTRY {
                logger.warning("Unknown benchmark: %s", bench_name);
                continue;
            }

            logger.info("  Running %s...", bench_name);
            try {
                bench_fn: any = BENCHMARK_REGISTRY[bench_name];
                results: any = bench_fn(repo_path, store, benchmark_config);

                key: any = f"{name}_{bench_name}";
                all_results[key] = results;
                write_csv(results, output_dir / f"{key}_{today}.csv");
                logger.info("  %s: %d result(s)", bench_name, len(results));
            } except Exception as e {
                logger.error("  %s failed: %s", bench_name, e);
                all_results[f"{name}_{bench_name}"] = [];
            }
        }

        store.close();
    }

    return all_results;
}
