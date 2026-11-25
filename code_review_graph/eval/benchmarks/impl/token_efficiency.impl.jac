impl _count_tokens(text: str) -> int {
    return len(text) // 4;
}

impl _get_changed_files(repo_path: Path, sha: str) -> list[str] {
    result: any = subprocess.run(
        ["git", "diff", "--name-only", f"{sha}~1", sha],
        cwd=`str(repo_path),
        capture_output=True,
        text=True,
    );
    if result.returncode != 0 {
        result = subprocess.run(
            ["git", "diff", "--name-only", "HEAD~1", "HEAD"],
            cwd=`str(repo_path),
            capture_output=True,
            text=True,
        );
    }
    return [f.strip() for f in result.stdout.strip().splitlines() if f.strip()];
}

impl _count_file_tokens(repo_path: Path, files: list[str]) -> int {
    total: any = 0;
    for f in files {
        fp: any = repo_path / f;
        if fp.is_file() {
            try {
                total += _count_tokens(fp.read_text(encoding="utf-8", errors="replace"));
            } except OSError {}
        }
    }
    return total;
}

impl _count_diff_tokens(repo_path: Path, sha: str) -> int {
    result: any = subprocess.run(
        ["git", "diff", f"{sha}~1", sha], cwd=`str(repo_path), capture_output=True, text=True
    );
    if result.returncode != 0 {
        result = subprocess.run(
            ["git", "diff", "HEAD~1", "HEAD"], cwd=`str(repo_path), capture_output=True, text=True
        );
    }
    return _count_tokens(result.stdout);
}

impl run(repo_path: Path, store, config: dict) -> list[dict] {
    results: any = [];
    for tc in config.get("test_commits", []) {
        changed: any = _get_changed_files(repo_path, tc["sha"]);
        if not changed {
            continue;
        }

        naive_tokens: any = _count_file_tokens(repo_path, changed);
        standard_tokens: any = _count_diff_tokens(repo_path, tc["sha"]);

        row: dict = {
            "repo": config["name"],
            "commit": tc["sha"],
            "description": tc.get("description", ""),
            "changed_files": len(changed),
            "naive_tokens": naive_tokens,
            "standard_tokens": standard_tokens,
            "graph_tokens": "",
            "naive_to_graph_ratio": "",
            "standard_to_graph_ratio": "",
            "status": "ok",
            "error": "",
        };
        try {
            get_review_context = importlib.import_module("code_review_graph.tools.review").get_review_context;
            ctx: any = get_review_context(changed_files=changed, repo_root=`str(repo_path));
            graph_tokens: any = _count_tokens(json.dumps(ctx));
        } except Exception as exc {
            logger.warning("get_review_context failed on %s: %s", tc["sha"], exc);
            row["status"] = "error";
            row["error"] = `str(exc)[:200];
            results.append(row);
            continue;
        }

        row["graph_tokens"] = graph_tokens;
        row["naive_to_graph_ratio"] = round(naive_tokens / max(graph_tokens, 1), 1);
        row["standard_to_graph_ratio"] = round(standard_tokens / max(graph_tokens, 1), 1);
        results.append(row);
    }
    return results;
}

impl aggregate(results: list[dict]) -> dict {
    ok: any = [r for r in results if r.get("status") == "ok"];
    ratios: any = [`float(r["naive_to_graph_ratio"]) for r in ok];
    return {
        "total_rows": len(results),
        "ok_rows": len(ok),
        "error_rows": sum(1 for r in results if r.get("status") == "error"),
        "median_naive_to_graph_ratio": round(statistics.median(ratios), 1) if ratios else None,
        "mean_naive_to_graph_ratio": round(statistics.mean(ratios), 1) if ratios else None,
    };
}
