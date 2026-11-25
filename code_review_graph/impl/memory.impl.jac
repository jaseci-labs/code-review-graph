impl save_result(
    question: str,
    answer: str,
    nodes: list[str] | None = None,
    result_type: str = "query",
    memory_dir: Path | None = None,
    repo_root: Path | None = None,
) -> Path {
    if memory_dir is None {
        if repo_root is None {
            raise ValueError("Either memory_dir or repo_root required");
        }
        memory_dir = repo_root / ".code-review-graph" / "memory";
    }

    memory_dir.mkdir(parents=True, exist_ok=True);
    slug: any = re.sub("[^\\w\\s-]", "", question.lower());
    slug = re.sub("[\\s_]+", "-", slug).strip("-")[:60];
    timestamp: any = `int(time.time());
    filename: any = f"{slug}-{timestamp}.md";
    lines: any = ["---", f"type: {result_type}", f"timestamp: {timestamp}"];
    if nodes {
        lines.append("nodes:");
        for n in nodes[:20] {
            lines.append(f"  - {n}");
        }
    }
    lines.extend(["---", "", f"# {question}", "", answer]);

    path: any = memory_dir / filename;
    path.write_text("\n".join(lines), encoding="utf-8");
    logger.info("Saved result to %s", path);
    return path;
}

impl list_memories(
    memory_dir: Path | None = None, repo_root: Path | None = None
) -> list[dict[str, Any]] {
    if memory_dir is None {
        if repo_root is None {
            return [];
        }
        memory_dir = repo_root / ".code-review-graph" / "memory";
    }

    if not memory_dir.exists() {
        return [];
    }

    results: any = [];
    for f in sorted(memory_dir.glob("*.md")) {
        try {
            text: any = f.read_text(encoding="utf-8");
            meta: dict[str, Any] = {"path": `str(f)};
            if text.startswith("---") {
                parts: any = text.split("---", 2);
                if len(parts) >= 3 {
                    fm_lines: any = parts[1].strip().split("\n");
                    line: any;
                    for line in fm_lines {
                        if ": " in line and not line.startswith(" ") {
                            k: any;
                            v: any;
                            (k, v) = line.split(": ", 1) as any;
                            meta[k.strip()] = v.strip();
                        }
                    }
                }
            }
            for line in text.split("\n") {
                if line.startswith("# ") {
                    meta["question"] = line[2:].strip();
                    break;
                }
            }
            results.append(meta);
        } except OSError {
            continue;
        }
    }

    return results;
}

impl clear_memories(memory_dir: Path | None = None, repo_root: Path | None = None) -> int {
    if memory_dir is None {
        if repo_root is None {
            return 0;
        }
        memory_dir = repo_root / ".code-review-graph" / "memory";
    }

    if not memory_dir.exists() {
        return 0;
    }

    count: any = 0;
    for f in memory_dir.glob("*.md") {
        f.unlink();
        count += 1;
    }

    logger.info("Cleared %d memory files", count);
    return count;
}
