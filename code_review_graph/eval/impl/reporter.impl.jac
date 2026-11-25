impl generate_markdown_report(results: list[dict[str, Any]]) -> str {
    if not results {
        return "# Evaluation Report\n\nNo benchmark results to report.\n";
    }

    lines: list[str] = [];
    lines.append("# Evaluation Report");
    lines.append("");
    all_keys: list[str] = [];
    seen: set[str] = set[any]();
    r: any;
    for r in results {
        k: any;
        for k in r {
            if k != "benchmark" and k not in seen {
                all_keys.append(k);
                seen.add(k);
            }
        }
    }
    lines.append("## Summary");
    lines.append("");

    header: any = "| Benchmark | " + " | ".join(all_keys) + " |";
    separator: any = "| --- | " + " | ".join("---" for _ in all_keys) + " |";
    lines.append(header);
    lines.append(separator);

    for r in results {
        name: any = r.get("benchmark", "unknown");
        values: any = [`str(r.get(k, "-")) for k in all_keys];
        lines.append(f"| {name} | " + " | ".join(values) + " |");
    }

    lines.append("");
    lines.append("## Details");
    lines.append("");
    for r in results {
        name = r.get("benchmark", "unknown");
        lines.append(f"### {name}");
        lines.append("");
        for k in all_keys {
            v: any = r.get(k, "-");
            lines.append(f"- **{k}**: {v}");
        }
        lines.append("");
    }

    return "\n".join(lines);
}

impl _newest_runs(results_dir: Path, prefix: str) -> list[Path] {
    newest: dict[str, Path] = {};
    marker: any = f"_{prefix}_";
    for p in results_dir.glob(f"*{marker}*.csv") {
        repo: any;
        _: any;
        stamp: any;
        (repo, _, stamp) = p.stem.rpartition(marker) as any;
        kept: any = newest.get(repo);
        if kept is None or stamp > kept.stem.rpartition(marker)[2] {
            newest[repo] = p;
        }
    }
    return [newest[repo] for repo in sorted(newest)];
}

impl _read_csvs(results_dir: Path, prefix: str) -> list[dict[str, str]] {
    rows: list[dict[str, str]] = [];
    for p in _newest_runs(results_dir, prefix) {
        f: any;
        with open(p, encoding="utf-8", newline="") as f {
            reader: any = csv.DictReader(f);
            rows.extend(reader);
        }
    }
    return rows;
}

impl _md_table(headers: list[str], rows: list[list[str]]) -> str {
    lines: any = [];
    lines.append("| " + " | ".join(headers) + " |");
    lines.append("| " + " | ".join("---" for _ in headers) + " |");
    for row in rows {
        lines.append("| " + " | ".join(row) + " |");
    }
    return "\n".join(lines);
}

impl generate_full_report(results_dir: str | Path) -> str {
    results_dir = Path(results_dir);
    lines: list[str] = [];
    lines.append("# Evaluation Report");
    lines.append("");
    lines.append("## Methodology");
    lines.append("");
    lines.append("Benchmarks are run against real open-source repositories.");
    lines.append("Token counts use a consistent `len(text) // 4` approximation.");
    lines.append(
        "Impact accuracy reports two ground-truth modes: graph-derived (circular — upper bound) and co-change (files co-changed in the same commit, seed excluded).",
    );
    lines.append(
        "Rows with `status=error` are kept for forensics but excluded from all aggregates."
    );
    lines.append(
        "Incremental fidelity compares an incrementally updated graph against a clean rebuild of the same tree; `status=known_failure` marks a divergence that is already recorded in `incremental_fidelity.KNOWN_FAILURES`.",
    );
    lines.append("");

    benchmark_types: any = [
        "token_efficiency",
        "impact_accuracy",
        "agent_baseline",
        "flow_completeness",
        "search_quality",
        "build_performance",
        "multi_hop_retrieval",
        "incremental_fidelity",
    ];

    for btype in benchmark_types {
        rows: any = _read_csvs(results_dir, btype);
        if not rows {
            continue;
        }

        title: any = btype.replace("_", " ").title();
        lines.append(f"## {title}");
        lines.append("");

        headers: any = `list(rows[0].keys());
        table_rows: any = [[r.get(h, "-") for h in headers] for r in rows];
        lines.append(_md_table(headers, table_rows));
        lines.append("");
    }

    if len(lines) <= 6 {
        lines.append("No benchmark results found.");
        lines.append("");
    }

    return "\n".join(lines);
}

impl generate_readme_tables(results_dir: str | Path) -> str {
    results_dir = Path(results_dir);
    lines: list[str] = [];
    te_rows: any = _read_csvs(results_dir, "token_efficiency");
    if te_rows {
        lines.append("### Token Efficiency");
        lines.append("");
        headers: any = [
            "Repo",
            "Files",
            "Naive Tokens",
            "Standard Tokens",
            "Graph Tokens",
            "Naive/Graph",
            "Std/Graph",
        ];
        table_rows: any = [];
        r: any;
        for r in te_rows {
            table_rows.append([
                r.get("repo", "-"),
                r.get("changed_files", "-"),
                r.get("naive_tokens", "-"),
                r.get("standard_tokens", "-"),
                r.get("graph_tokens", "-"),
                r.get("naive_to_graph_ratio", "-"),
                r.get("standard_to_graph_ratio", "-"),
            ]);
        }
        lines.append(_md_table(headers, table_rows));
        lines.append("");
    }
    ia_rows: any = _read_csvs(results_dir, "impact_accuracy");
    fc_rows: any = _read_csvs(results_dir, "flow_completeness");
    sq_rows: any = _read_csvs(results_dir, "search_quality");

    if ia_rows or fc_rows or sq_rows {
        lines.append("### Accuracy & Quality");
        lines.append("");
        headers = ["Repo", "Impact F1 (graph-derived)", "Flow Recall", "Search MRR"];
        repo_data: dict[str, dict[str, object]] = {};
        mrr_accum: dict[str, list[float]] = {};
        f1_accum: dict[str, list[float]] = {};
        for r in ia_rows {
            if r.get("status", "ok") not in ("", "ok") {
                continue;
            }
            mode: any = r.get("ground_truth_mode", "");
            if mode and not mode.startswith("graph-derived") {
                continue;
            }
            repo: any = r.get("repo", "?");
            repo_data.setdefault(repo, {});
            try {
                f1_accum.setdefault(repo, []).append(`float(r.get("f1", "")));
            } except (ValueError, TypeError) {}
        }
        for r in fc_rows {
            repo_data.setdefault(r.get("repo", "?"), {})["recall"] = r.get("recall", "-");
        }
        for r in sq_rows {
            repo = r.get("repo", "?");
            repo_data.setdefault(repo, {});
            try {
                mrr_accum.setdefault(repo, []).append(`float(r.get("reciprocal_rank", 0)));
            } except (ValueError, TypeError) {}
        }

        table_rows = [];
        for (repo, d) in sorted(repo_data.items()) {
            mrr_vals: any = mrr_accum.get(repo, []);
            mrr: any = `str(round(sum(mrr_vals) / len(mrr_vals), 3)) if mrr_vals else "-";
            f1_vals: any = f1_accum.get(repo, []);
            f1: any = `str(round(sum(f1_vals) / len(f1_vals), 3)) if f1_vals else "-";
            table_rows.append([repo, f1, `str(d.get("recall", "-")), mrr]);
        }
        lines.append(_md_table(headers, table_rows));
        lines.append("");
    }
    ab_rows: any = _read_csvs(results_dir, "agent_baseline");
    if ab_rows {
        lines.append("### Agent Baseline (grep top-k vs graph query)");
        lines.append("");
        headers = [
            "Repo",
            "Question",
            "Baseline Tokens",
            "Graph Tokens",
            "Baseline/Graph",
            "Status",
        ];
        table_rows = [];
        for r in ab_rows {
            table_rows.append([
                r.get("repo", "-"),
                r.get("question", "-"),
                r.get("baseline_tokens", "-"),
                r.get("graph_tokens", "-"),
                r.get("baseline_to_graph_ratio", "-"),
                r.get("status", "ok") or "ok",
            ]);
        }
        lines.append(_md_table(headers, table_rows));
        lines.append("");
    }
    if_rows: any = _read_csvs(results_dir, "incremental_fidelity");
    if if_rows {
        lines.append("### Incremental Fidelity (update vs clean rebuild)");
        lines.append("");
        headers = ["Repo", "Edit", "Status", "Differing Rows", "Worst Table", "Seconds"];
        table_rows = [];
        for r in if_rows {
            table_rows.append([
                r.get("repo", "-"),
                r.get("edit_kind", "-"),
                r.get("status", "-"),
                r.get("total_differing_rows", "-"),
                r.get("worst_table", "-") or "-",
                r.get("seconds", "-"),
            ]);
        }
        lines.append(_md_table(headers, table_rows));
        lines.append("");
    }
    bp_rows: any = _read_csvs(results_dir, "build_performance");
    if bp_rows {
        lines.append("### Performance");
        lines.append("");
        headers = ["Repo", "Files", "Nodes", "Flow Det. (s)", "Search (ms)"];
        table_rows = [];
        for r in bp_rows {
            table_rows.append([
                r.get("repo", "-"),
                r.get("file_count", "-"),
                r.get("node_count", "-"),
                r.get("flow_detection_seconds", "-"),
                r.get("search_avg_ms", "-"),
            ]);
        }
        lines.append(_md_table(headers, table_rows));
        lines.append("");
    }

    if not lines {
        return "No benchmark results found.\n";
    }

    return "\n".join(lines);
}
