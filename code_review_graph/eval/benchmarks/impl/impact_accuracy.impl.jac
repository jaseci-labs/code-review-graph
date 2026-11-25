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

impl _files_from_analysis(analysis: dict) -> set[str] {
    predicted: set[str] = set[any]();
    for f in analysis.get("changed_functions", []) {
        if isinstance(f, `dict) and "file_path" in f {
            predicted.add(f["file_path"]);
        } elif isinstance(f, `dict) and "file" in f {
            predicted.add(f["file"]);
        }
    }
    for `flow in analysis.get("affected_flows", []) {
        if isinstance(`flow, `dict) {
            for `node in `flow.get("nodes", []) {
                if isinstance(`node, `dict) and "file_path" in `node {
                    predicted.add(`node["file_path"]);
                }
            }
        }
    }
    return predicted;
}

impl _graph_neighbor_files(store, files: list[str]) -> set[str] {
    out: set[str] = set[any]();
    for f in files {
        for `node in store.get_nodes_by_file(f) {
            for `edge in store.get_edges_by_target(`node.qualified_name) {
                if `edge.kind in ("CALLS", "IMPORTS_FROM") {
                    src_qual: any = `edge.source_qualified;
                    src_file: any = src_qual.split("::")[0];
                    if "/" in src_file {
                        out.add(src_file);
                    }
                }
            }
        }
    }
    return out;
}

impl _base_row(repo: str, sha: str, mode: str, seed: str) -> dict {
    return {
        "repo": repo,
        "commit": sha,
        "ground_truth_mode": mode,
        "seed_file": seed,
        "predicted_files": "",
        "actual_files": "",
        "true_positives": "",
        "precision": "",
        "recall": "",
        "f1": "",
        "status": "ok",
        "error": "",
    };
}

impl _scored_row(
    repo: str, sha: str, mode: str, seed: str, predicted: set[str], actual: set[str]
) -> dict {
    tp: any = len(predicted & actual);
    precision: any = tp / max(len(predicted), 1);
    recall: any = tp / max(len(actual), 1);
    f1: any = 2 * precision * recall / max(precision + recall, 0.001);
    row: any = _base_row(repo, sha, mode, seed);
    row.update({
        "predicted_files": len(predicted),
        "actual_files": len(actual),
        "true_positives": tp,
        "precision": round(precision, 3),
        "recall": round(recall, 3),
        "f1": round(f1, 3),
    });
    return row;
}

impl _error_row(repo: str, sha: str, mode: str, seed: str, exc: Exception) -> dict {
    row: any = _base_row(repo, sha, mode, seed);
    row["status"] = "error";
    row["error"] = `str(exc)[:200];
    return row;
}

impl run(repo_path: Path, store, config: dict) -> list[dict] {
    import from code_review_graph.changes { analyze_changes }

    results: any = [];
    repo: any = config["name"];
    `root: any = Path(repo_path).expanduser().resolve();
    for tc in config.get("test_commits", []) {
        sha: any = tc["sha"];
        changed: any = _get_changed_files(`root, sha);
        if not changed {
            continue;
        }
        rel_of: any = {normalize_file_path(`root / f): normalize_file_path(f) for f in changed};
        changed_abs: any = `set(rel_of);
        try {
            analysis: any = analyze_changes(
                store, sorted(changed_abs), repo_root=`str(`root), base=sha + "~1"
            );
        } except Exception as exc {
            logger.warning("analyze_changes failed on %s: %s", sha, exc);
            results.append(_error_row(repo, sha, MODE_GRAPH_DERIVED, "", exc));
            analysis = None;
        }

        if analysis is not None {
            predicted: any = changed_abs | _files_from_analysis(analysis);
            actual: any = changed_abs | _graph_neighbor_files(store, sorted(changed_abs));
            results.append(_scored_row(repo, sha, MODE_GRAPH_DERIVED, "", predicted, actual));
        }
        seed: any = sorted(changed_abs)[0];
        seed_rel: any = rel_of[seed];
        co_actual: any = changed_abs - {seed};
        if not co_actual {
            row: any = _base_row(repo, sha, MODE_CO_CHANGE, seed_rel);
            row["status"] = "skipped";
            row["error"] = "single-file commit: no co-changed files to grade against";
            results.append(row);
            continue;
        }

        try {
            seed_analysis: any = analyze_changes(store, [seed]);
        } except Exception as exc {
            logger.warning("analyze_changes (seed=%s) failed on %s: %s", seed, sha, exc);
            results.append(_error_row(repo, sha, MODE_CO_CHANGE, seed_rel, exc));
            continue;
        }

        co_predicted: any = _files_from_analysis(seed_analysis);
        co_predicted |= _graph_neighbor_files(store, [seed]);
        co_predicted.discard(seed);
        results.append(_scored_row(repo, sha, MODE_CO_CHANGE, seed_rel, co_predicted, co_actual));
    }

    return results;
}

impl aggregate(results: list[dict]) -> dict {
    out: dict = {
        "total_rows": len(results),
        "error_rows": sum(1 for r in results if r.get("status") == "error"),
        "skipped_rows": sum(1 for r in results if r.get("status") == "skipped"),
    };
    for (key, mode) in (("graph_derived", MODE_GRAPH_DERIVED), ("co_change", MODE_CO_CHANGE)) {
        rows: any = [
            r
            for r in results
            if r.get("ground_truth_mode") == mode and r.get("status") == "ok"
        ];
        out[key] = {
            "ok_rows": len(rows),
            "mean_precision": round(statistics.mean(`float(r["precision"]) for r in rows), 3)
                if rows
                else None,
            "mean_recall": round(statistics.mean(`float(r["recall"]) for r in rows), 3)
                if rows
                else None,
            "mean_f1": round(statistics.mean(`float(r["f1"]) for r in rows), 3) if rows else None,
        };
    }
    return out;
}
