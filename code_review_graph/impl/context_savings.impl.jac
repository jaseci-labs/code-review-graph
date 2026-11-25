impl estimate_tokens(value: Any) -> int {
    if value is None {
        return 0;
    }
    if isinstance(value, `str) {
        text: any = value;
    } else {
        text = json.dumps(
            value, default=str, ensure_ascii=True, separators=(",", ":"), sort_keys=True
        );
    }
    if not text {
        return 0;
    }
    return max(1, (len(text) + CHARS_PER_TOKEN - 1) // CHARS_PER_TOKEN);
}

impl estimate_file_tokens(repo_root: Path, files: Iterable[str]) -> int {
    total: any = 0;
    `root: any = repo_root.resolve();
    for file_name in files {
        path: any = Path(file_name);
        full_path: any = path if path.is_absolute() else `root / path;
        try {
            if full_path.is_file() {
                total += max(
                    1, (full_path.stat().st_size + CHARS_PER_TOKEN - 1) // CHARS_PER_TOKEN
                );
            }
        } except OSError {
            continue;
        }
    }
    return total;
}

impl _token_counts(
    original_context: Any | None,
    returned_context: Any | None,
    original_tokens: int | None,
    returned_tokens: int | None,
) -> tuple[int, int] {
    baseline: any = original_tokens
        if original_tokens is not None
        else estimate_tokens(original_context);
    returned: any = returned_tokens
        if returned_tokens is not None
        else estimate_tokens(returned_context);
    return (baseline, returned);
}

impl _savings(baseline: int, returned: int) -> dict[str, int | bool] | None {
    if baseline <= 0 {
        return None;
    }

    saved: any = max(0, baseline - returned);
    percent: any = round(saved / baseline * 100) if baseline else 0;
    return {"estimated": True, "saved_tokens": `int(saved), "saved_percent": `int(percent)};
}

impl estimate_context_savings(
    *,
    original_context: Any | None = None,
    returned_context: Any | None = None,
    original_tokens: int | None = None,
    returned_tokens: int | None = None,
) -> dict[str, int | bool] | None {
    return _savings(
        *_token_counts(original_context, returned_context, original_tokens, returned_tokens)
    );
}

impl attach_context_savings(
    result: dict[str, Any],
    *,
    original_context: Any | None = None,
    original_tokens: int | None = None,
    returned_context: Any | None = None,
    returned_tokens: int | None = None,
    call: CallInfo | None = None,
) -> dict[str, Any] {
    baseline: any;
    returned: any;
    (baseline, returned) = _token_counts(
        original_context,
        result if returned_context is None else returned_context,
        original_tokens,
        returned_tokens,
    ) as any;
    estimate: any = _savings(baseline, returned);
    if estimate is not None {
        result["context_savings"] = estimate;
        if call is not None {
            record_call(
                call, baseline=baseline, returned=returned, saved=`int(estimate["saved_tokens"])
            );
        }
    }
    return result;
}

impl format_context_savings(estimate: dict[str, Any] | None) -> str | None {
    if not estimate {
        return None;
    }
    saved: any = `int(estimate.get("saved_tokens", 0));
    percent: any = `int(estimate.get("saved_percent", 0));
    return f"Estimated context saved: ~{saved:,} tokens (~{percent}%)";
}

impl _fmt_compact(n: int) -> str {
    if n >= 10000 {
        return f"{n // 1000:,}k";
    }
    if n >= 1000 {
        return f"{n / 1000:.1f}k";
    }
    return `str(n);
}

impl _breakdown_from_response(response: dict[str, Any]) -> dict[str, int] {
    fields: any = [
        ("Functions", "changed_functions"),
        ("Flows", "affected_flows"),
        ("Tests", "test_gaps"),
        ("Risk", "review_priorities"),
        ("Impact", "impacted_nodes"),
        ("Edges", "edges"),
        ("Source", "source_snippets"),
        ("Imports", "imports"),
    ];
    out: dict[str, int] = {};
    for (label, key) in fields {
        value: any = response.get(key);
        if not value {
            continue;
        }
        tokens: any = estimate_tokens(value);
        if tokens > 0 {
            out[label] = tokens;
        }
    }
    return out;
}

impl verify_with_tiktoken(
    repo_root: "Path | str",
    changed_files: Iterable[str],
    response: Any,
    encoding_name: str = "cl100k_base",
) -> dict[str, int] | None {
    try {
        import tiktoken;
    } except ImportError {
        return None;
    }

    enc: any = tiktoken.get_encoding(encoding_name);
    `root: any = Path(repo_root).resolve();

    naive_real: any = 0;
    for f in changed_files {
        p: any = `root / f;
        try {
            if p.is_file() {
                naive_real += len(enc.encode(p.read_text(errors="replace")));
            }
        } except OSError {
            continue;
        }
    }

    if isinstance(response, `str) {
        graph_real: any = len(enc.encode(response));
    } else {
        text: any = json.dumps(
            response, default=str, ensure_ascii=True, separators=(",", ":"), sort_keys=True
        );
        graph_real = len(enc.encode(text));
    }

    saved: any = max(0, naive_real - graph_real);
    pct: any = round(saved * 100 / naive_real) if naive_real > 0 else 0;
    return {
        "verified_baseline": naive_real,
        "verified_returned": graph_real,
        "verified_saved": saved,
        "verified_percent": pct,
    };
}

impl format_context_savings_panel(
    estimate: dict[str, Any] | None,
    *,
    original_tokens: int | None = None,
    returned_tokens: int | None = None,
    response: dict[str, Any] | None = None,
    breakdown: dict[str, int] | None = None,
    verified: dict[str, int] | None = None,
    title: str = "Token Savings",
    width: int = 64,
) -> str | None {
    inner_w: any;
    s: any;
    if not estimate {
        return None;
    }

    saved: any = `int(estimate.get("saved_tokens", 0));
    percent: any = `int(estimate.get("saved_percent", 0));
    if original_tokens is None {
        if percent > 0 {
            original_tokens = `int(round(saved * 100 / percent));
        } else {
            original_tokens = saved;
        }
    }
    if returned_tokens is None {
        returned_tokens = max(0, (original_tokens or 0) - saved);
    }

    if breakdown is None and response is not None {
        breakdown = _breakdown_from_response(response);
    }
    if breakdown and returned_tokens is not None {
        labelled_sum: any = sum(breakdown.values());
        remainder: any = returned_tokens - labelled_sum;
        if remainder > 0 {
            breakdown = `dict(breakdown);
            breakdown["Other"] = remainder;
        }
    }
    inner_lines: list[str] = [
        f"Full context would be:  {original_tokens:>9,} tokens",
        f"Graph context used:     {returned_tokens:>9,} tokens",
        f"Saved:                  {saved:>9,} tokens (~{percent}%)",
    ];
    if verified {
        vb: any = verified["verified_baseline"];
        vr: any = verified["verified_returned"];
        vs: any = verified["verified_saved"];
        vp: any = verified["verified_percent"];
        inner_lines.append(f"Verified (tiktoken):    {vs:>9,} tokens (~{vp}%)  [{vb:,} → {vr:,}]");
    }
    if breakdown {
        parts: any = [f"{label} {_fmt_compact(tok)}" for (label, tok) in breakdown.items()];
        bd_line: any = "Breakdown: " + " · ".join(parts);
        inner_lines.append(bd_line);
    }
    content_width: any = max(len(s) for s in inner_lines);
    inner_w = max(width - 2, content_width + 2);
    title_str: any = f" {title} ";
    dash_total: any = inner_w - len(title_str);
    if dash_total < 4 {
        dash_total = 4;
    }
    left_dash: any = dash_total // 2;
    right_dash: any = dash_total - left_dash;
    top: any = "┌" + "─" * left_dash + title_str + "─" * right_dash + "┐";
    bottom: any = "└" + "─" * inner_w + "┘";

    def _box_line(content: str) -> str {
        pad: any = inner_w - 2 - len(content);
        if pad < 0 {
            pad = 0;
        }
        return "│ " + format(content, "") + format(" " * pad, "") + " │";
    }

    lines: any = [top];
    for s in inner_lines {
        lines.append(_box_line(s));
    }
    lines.append(bottom);
    return "\n".join(lines);
}
