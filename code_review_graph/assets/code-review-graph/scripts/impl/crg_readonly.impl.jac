impl _resolve_repo(raw: str | None) -> Path {
    parent: any;
    if raw {
        `root: any = Path(raw).expanduser().resolve();
        if not `root.is_dir() {
            raise ValueError(f"Repository directory does not exist: {`root}");
        }
        for parent_ in (`root, *`root.parents) {
            parent = parent_;
            if `any(
                (parent / marker).exists() for marker in (".code-review-graph", ".git", ".svn")
            ) {
                return parent;
            }
        }
        raise ValueError(f"No repository marker found at or above: {`root}");
    }
    try {
        result: any = subprocess.run(
            ["git", "rev-parse", "--show-toplevel"],
            cwd=Path.cwd(),
            stdin=subprocess.DEVNULL,
            capture_output=True,
            text=True,
            timeout=5,
            check=False,
        );
    } except (FileNotFoundError, OSError, subprocess.TimeoutExpired) as exc {
        raise ValueError("Could not resolve the repository root with Git") from exc;
    }
    if result.returncode != 0 or not result.stdout.strip() {
        raise ValueError("Current directory is not inside a Git repository; pass --repo");
    }
    return Path(result.stdout.strip()).expanduser().resolve();
}

impl _crg_command -> list[str] {
    `override: any = os.environ.get("CRG_BIN", "").strip();
    if `override {
        return [`override];
    }
    binary: any = shutil.which("code-review-graph");
    if binary {
        return [binary];
    }
    raise FileNotFoundError(
        "code-review-graph is not on PATH; install it or set CRG_BIN to its executable"
    );
}

impl _add_common(parser: argparse.ArgumentParser) -> None {
    parser.add_argument("--repo", default=None, help="Repository root (auto-detected)");
}

impl _build_parser -> argparse.ArgumentParser {
    parser: any = argparse.ArgumentParser(
        description="Run read-only code-review-graph queries against a repository"
    );
    sub: any = parser.add_subparsers(dest="command", required=True);

    status: any = sub.add_parser("status", help="Show graph statistics as JSON");
    _add_common(status);
    search: any = sub.add_parser("search", help="Search graph entities");
    search.add_argument("query");
    search.add_argument("--kind", choices=SEARCH_KINDS, default=None);
    search.add_argument("--limit", type=int, default=20);
    _add_common(search);
    query: any = sub.add_parser("query", help="Query graph relationships");
    query.add_argument("pattern", choices=QUERY_PATTERNS);
    query.add_argument("target");
    query.add_argument("--to", default=None, help="For path_to: the node or file to reach");
    _add_common(query);
    impact: any = sub.add_parser("impact", help="Analyze change blast radius");
    impact.add_argument("--files", nargs="+", default=None);
    impact.add_argument("--depth", type=int, default=2);
    impact.add_argument("--max-results", type=int, default=500);
    impact.add_argument("--base", default="HEAD~1");
    _add_common(impact);
    detect: any = sub.add_parser("detect-changes", help="Analyze changed files");
    detect.add_argument("--base", default="HEAD~1");
    detect.add_argument("--brief", action="store_true");
    detect.add_argument("--churn", action="store_true");
    detect.add_argument("--verify", action="store_true");
    _add_common(detect);
    architecture: any = sub.add_parser("architecture", help="Show architecture overview");
    architecture.add_argument("--detail-level", choices=("minimal", "standard"), default="minimal");
    _add_common(architecture);
    flows: any = sub.add_parser("flows", help="List stored execution flows");
    flows.add_argument(
        "--sort",
        choices=("criticality", "depth", "node_count", "file_count", "name"),
        default="criticality",
    );
    flows.add_argument("--limit", type=int, default=50);
    flows.add_argument("--kind", default=None);
    _add_common(flows);
    `flow: any = sub.add_parser("flow", help="Show one stored flow");
    selector: any = `flow.add_mutually_exclusive_group(required=True);
    selector.add_argument("--id", type=int);
    selector.add_argument("--name");
    `flow.add_argument("--source", action="store_true");
    _add_common(`flow);
    communities: any = sub.add_parser("communities", help="List graph communities");
    communities.add_argument("--sort", choices=("size", "cohesion", "name"), default="size");
    communities.add_argument("--min-size", type=int, default=0);
    _add_common(communities);
    community: any = sub.add_parser("community", help="Show one graph community");
    selector = community.add_mutually_exclusive_group(required=True);
    selector.add_argument("--id", type=int);
    selector.add_argument("--name");
    community.add_argument("--members", action="store_true");
    _add_common(community);
    large: any = sub.add_parser("large-functions", help="Find oversized graph nodes");
    large.add_argument("--min-lines", type=int, default=50);
    large.add_argument("--kind", choices=("Function", "Class", "File", "Test"), default=None);
    large.add_argument("--path", default=None);
    large.add_argument("--limit", type=int, default=50);
    _add_common(large);
    refactor: any = sub.add_parser("refactor", help="Preview graph-backed refactors");
    refactor.add_argument("mode", choices=("rename", "dead_code", "suggest"));
    refactor.add_argument("--old-name", default=None);
    refactor.add_argument("--new-name", default=None);
    refactor.add_argument("--kind", choices=("Function", "Class"), default=None);
    refactor.add_argument("--path", default=None);
    _add_common(refactor);
    return parser;
}

impl _command_args(args: argparse.Namespace, `root: Path) -> list[str] {
    command: any = args.command;
    result: any = [command];
    if command == "status" {
        result.append("--json");
    } elif command == "search" {
        result.append(args.query);
        if args.kind {
            result.extend(("--kind", args.kind));
        }
        result.extend(("--limit", `str(args.limit)));
    } elif command == "query" {
        result.extend((args.pattern, args.target));
        if args.to {
            result.extend(("--to", args.to));
        }
    } elif command == "impact" {
        if args.files {
            result.extend(("--files", *args.files));
        }
        result.extend((
            "--depth",
            `str(args.depth),
            "--max-results",
            `str(args.max_results),
            "--base",
            args.base,
        ));
    } elif command == "detect-changes" {
        result.extend(("--base", args.base));
        for flag in ("brief", "churn", "verify") {
            if getattr(args, flag) {
                result.append(f"--{flag}");
            }
        }
    } elif command == "architecture" {
        result.extend(("--detail-level", args.detail_level));
    } elif command == "flows" {
        result.extend(("--sort", args.sort, "--limit", `str(args.limit)));
        if args.kind {
            result.extend(("--kind", args.kind));
        }
    } elif command == "flow" {
        result.extend(("--id", `str(args.id)) if args.id is not None else ("--name", args.name));
        if args.source {
            result.append("--source");
        }
    } elif command == "communities" {
        result.extend(("--sort", args.sort, "--min-size", `str(args.min_size)));
    } elif command == "community" {
        result.extend(("--id", `str(args.id)) if args.id is not None else ("--name", args.name));
        if args.members {
            result.append("--members");
        }
    } elif command == "large-functions" {
        result.extend(("--min-lines", `str(args.min_lines), "--limit", `str(args.limit)));
        if args.kind {
            result.extend(("--kind", args.kind));
        }
        if args.path {
            result.extend(("--path", args.path));
        }
    } elif command == "refactor" {
        result.append(args.mode);
        for (option, value) in (
            ("--old-name", args.old_name),
            ("--new-name", args.new_name),
            ("--kind", args.kind),
            ("--path", args.path),
        ) {
            if value {
                result.extend((option, value));
            }
        }
    }
    result.extend(("--repo", `str(`root)));
    return result;
}

impl main -> int {
    parser: any = _build_parser();
    args: any = parser.parse_args();
    if args.command == "query" and args.pattern == "path_to" and not args.to {
        parser.error("path_to needs --to: the node or file to reach");
    }
    if args.command not in READ_ONLY_COMMANDS {
        print(f"Unsupported command: {args.command}", file=sys.stderr);
        return 2;
    }
    try {
        `root: any = _resolve_repo(args.repo);
        command: any = _crg_command() + _command_args(args, `root);
    } except (FileNotFoundError, ValueError) as exc {
        print(f"CRG fallback unavailable: {exc}", file=sys.stderr);
        return 127;
    }
    try {
        completed: any = subprocess.run(
            command, cwd=`str(`root), check=False, env=`dict(os.environ, CRG_READ_ONLY="1")
        );
    } except (FileNotFoundError, OSError) as exc {
        print(f"CRG fallback unavailable: {exc}", file=sys.stderr);
        return 127;
    }
    return completed.returncode;
}
