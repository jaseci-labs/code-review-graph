impl history_enabled -> bool {
    value: any = os.environ.get("CRG_CONTEXT_HISTORY", "").strip().lower();
    return value in {"1", "true", "yes", "on"};
}

impl recorded_as(label: str) -> Generator[any, any, any] {
    token: any = _label.set(label);
    try {
        yield;
    } finally {
        _label.reset(token);
    }
}

impl _count(value: Any) -> int | None {
    if isinstance(value, `bool) or not isinstance(value, `int) {
        return None;
    }
    return value;
}

impl record_call(call: CallInfo, *, baseline: int, returned: int, saved: int) {
    if not history_enabled() or read_only_requested() {
        return;
    }
    `entry: dict[str, Any] = {
        "v": SCHEMA_VERSION,
        "ts": datetime.now(timezone.utc).strftime(_TS_FORMAT),
        "tool": _label.get() or call.tool,
        "baseline_tokens": `int(baseline),
        "returned_tokens": `int(returned),
        "saved_tokens": `int(saved),
    };
    if call.detail_level is not None {
        `entry["detail_level"] = "minimal" if call.detail_level == "minimal" else "standard";
    }
    for key in ("files", "depth") {
        count: any = _count(getattr(call, key));
        if count is not None {
            `entry[key] = count;
        }
    }
    line: any = (json.dumps(`entry, separators=(",", ":")) + "\n").encode("utf-8");

    path: any = Path(call.data_dir) / HISTORY_FILE;
    try {
        if not path.parent.is_dir() {
            return;
        }
        with _locked(path.with_name(LOCK_FILE)) {
            _roll_over_if_full(path);
            flags: any = os.O_WRONLY | os.O_APPEND | os.O_CREAT | getattr(os, "O_BINARY", 0);
            fd: any = os.open(path, flags, 384);
            try {
                os.write(fd, line);
            } finally {
                os.close(fd);
            }
        }
    } except OSError as exc {
        logger.warning("Could not write context history to %s: %s", path, exc);
    }
}

impl _locked(lock_path: Path) -> Generator[any, any, any] {
    if operator.eq(sys.platform, "win32") {
        yield;
        return;
    }
    import fcntl;

    fd: any = os.open(lock_path, os.O_WRONLY | os.O_CREAT, 384);
    try {
        fcntl.flock(fd, fcntl.LOCK_EX);
        yield;
    } finally {
        os.close(fd);
    }
}

impl _roll_over_if_full(path: Path) {
    try {
        size: any = path.stat().st_size;
    } except FileNotFoundError {
        return;
    }
    if size >= MAX_BYTES {
        os.replace(path, path.with_name(path.name + ".1"));
    }
}

impl history_files(data_dir: Path) -> list[Path] {
    return [data_dir / (HISTORY_FILE + ".1"), data_dir / HISTORY_FILE];
}

impl _parse(line: str) -> dict[str, Any] | None {
    try {
        `entry: any = json.loads(line);
    } except ValueError {
        return None;
    }
    if not isinstance(`entry, `dict) or `entry.get("v") != SCHEMA_VERSION {
        return None;
    }
    ts: any;
    tool: any;
    (ts, tool) = (`entry.get("ts"), `entry.get("tool"));
    if not isinstance(ts, `str) or not isinstance(tool, `str) {
        return None;
    }
    try {
        datetime.strptime(ts, _TS_FORMAT);
    } except ValueError {
        return None;
    }
    for key in _TOKEN_KEYS {
        value: any = _count(`entry.get(key));
        if value is None or value < 0 {
            return None;
        }
    }
    return `entry;
}

impl read_history(
    data_dir: Path, *, since: datetime | None = None
) -> tuple[list[dict[str, Any]], int] {
    cutoff: any = since.astimezone(timezone.utc).strftime(_TS_FORMAT) if since else None;
    entries: list[dict[str, Any]] = [];
    skipped: any = 0;
    for path in history_files(Path(data_dir)) {
        try {
            fh: any;
            with path.open("r", encoding="utf-8", errors="replace") as fh {
                for line in fh {
                    if not line.strip() {
                        continue;
                    }
                    `entry: any = _parse(line);
                    if `entry is None {
                        skipped += 1;
                    } elif cutoff is None or `entry["ts"] >= cutoff {
                        entries.append(`entry);
                    }
                }
            }
        } except FileNotFoundError {
            continue;
        } except OSError as exc {
            logger.warning("Could not read context history from %s: %s", path, exc);
        }
    }
    return (entries, skipped);
}

impl _empty(key: str) -> dict[str, Any] {
    return {
        "key": key,
        "calls": 0,
        "baseline_tokens": 0,
        "returned_tokens": 0,
        "saved_tokens": 0,
        "largest_returned": 0,
    };
}

impl _add(row: dict[str, Any], `entry: dict[str, Any]) {
    row["calls"] += 1;
    row["baseline_tokens"] += `entry["baseline_tokens"];
    row["returned_tokens"] += `entry["returned_tokens"];
    row["saved_tokens"] = row["baseline_tokens"] - row["returned_tokens"];
    row["largest_returned"] = max(row["largest_returned"], `entry["returned_tokens"]);
}

impl summarise(entries: Iterable[dict[str, Any]], *, `by: str) -> list[dict[str, Any]] {
    rows: dict[str, dict[str, Any]] = {};
    for `entry in entries {
        key: any = `entry["ts"][:10] if `by == "day" else `entry["tool"];
        _add(rows.setdefault(key, _empty(key)), `entry);
    }
    if `by == "day" {
        return [rows[k] for k in sorted(rows)];
    }
    return sorted(rows.values(), key=lambda (r) -> any { (-r["calls"], r["key"]) });
}

impl total(entries: Iterable[dict[str, Any]]) -> dict[str, Any] {
    row: any = _empty("Total");
    for `entry in entries {
        _add(row, `entry);
    }
    return row;
}

impl _percent(row: dict[str, Any]) -> int {
    baseline: any = row["baseline_tokens"];
    return round(row["saved_tokens"] * 100 / baseline) if baseline else 0;
}

impl format_table(rows: list[dict[str, Any]], totals: dict[str, Any], *, `by: str) -> str {
    head: any = "Day (UTC)" if `by == "day" else "Tool";
    width: any = max([len(head), len("Total"), *(len(r["key"]) for r in rows)]);
    header: any = format(head, f"<{width}")
        + "  "
        + format("Calls", ">6")
        + "  "
        + format("Full context", ">13")
        + "  "
        + format("Graph context", ">13")
        + "  "
        + format("Saved", ">17")
        + "  "
        + format("Largest reply", ">13");
    out: any = [header];
    for row in [*rows, totals] {
        saved: any = f"{row["saved_tokens"]:,} ({_percent(row)}%)";
        out.append(
            format(row["key"], f"<{width}")
                + "  "
                + format(row["calls"], ">6,")
                + "  "
                + format(row["baseline_tokens"], ">13,")
                + "  "
                + format(row["returned_tokens"], ">13,")
                + "  "
                + format(saved, ">17")
                + "  "
                + format(row["largest_returned"], ">13,"),
        );
    }
    if `any(operator.lt(row["saved_tokens"], 0) for row in rows) {
        out.append("");
        out.append(
            "A negative Saved means the graph replies were bigger than the files they stand for."
        );
    }
    return "\n".join(out);
}
