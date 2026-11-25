import from __future__ { annotations }

import importlib, operator, builtins, sys;
import argparse, contextlib, difflib, fnmatch, io, json, logging, os, sqlite3;
import from functools { partial }
import from importlib.metadata { PackageNotFoundError }
import from importlib.metadata { version as pkg_version }
import from pathlib { Path }
import from typing { TYPE_CHECKING, Callable, Iterable, TypedDict }

with entry {
    if sys.version_info < (3, 10) {
        print("code-review-graph requires Python 3.10 or higher.");
        print(f"  You are running Python {sys.version}");
        print();
        print("Install Python 3.10+: https://www.python.org/downloads/");
        sys.exit(1);
    }
}

glob logger: any = logging.getLogger(__name__);

glob _PLATFORM_CHOICES: any = ("codex claude claude-code cursor windsurf zed continue opencode mimo antigravity gemini-cli "
    "qwen kiro qoder copilot copilot-cli codebuddy hermes dsh all").split();

glob _GITIGNORE_HELP: any = "Also add the files and folders this run creates, and git does not track, to a marked block in .gitignore. Off by default; uninstall removes the block";

class _EmbeddingRefreshKwargs(TypedDict, total=False) {
    has embedding_provider: str;

    has embedding_model: str;
}

class _FollowSymlinksKwargs(TypedDict, total=False) {
    has follow_symlinks: bool;
}

def _get_version -> str {
    try {
        v: any = pkg_version("code-review-graph");
        if v {
            return v;
        }
    } except PackageNotFoundError as exc {
        logger.debug("Package metadata unavailable: %s", exc);
    }
    try {
        fallback_version = lazy("", "__version__");

        if fallback_version {
            return fallback_version;
        }
    } except (ImportError, AttributeError) {}
    return "dev";
}

def _supports_color -> bool {
    if os.environ.get("NO_COLOR") {
        return False;
    }
    if not hasattr(sys.stdout, "isatty") {
        return False;
    }
    return sys.stdout.isatty();
}

def _print_banner {
    color: any = _supports_color();
    version: any = _get_version();
    c: any = "\x1b[36m" if color else "";
    y: any = "\x1b[33m" if color else "";
    b: any = "\x1b[1m" if color else "";
    d: any = "\x1b[2m" if color else "";
    g: any = "\x1b[32m" if color else "";
    r: any = "\x1b[0m" if color else "";

    print(
        f"\n{c}  ●──●──●{r}\n{c}  │╲ │ ╱│{r}       {b}code-review-graph{r}  {d}v{version}{r}\n{c}  ●──{y}◆{c}──●{r}\n{c}  │╱ │ ╲│{r}       {d}Structural knowledge graph for{r}\n{c}  ●──●──●{r}       {d}smarter code reviews{r}\n\n  {b}Start:{r} code-review-graph install && code-review-graph build\n\n{_banner_commands(b, g, r)}\n  {d}Run{r} {b}code-review-graph <command> --help{r} {d}for details{r}\n",
    );
}

glob _BANNER_GROUPS: tuple[tuple[str, tuple[tuple[str, str], ...]], ...] = (
    (
        "Set up",
        (
            ("install", "Set up the MCP server, hooks and skills for your AI tools"),
            ("init", "Same as install"),
            ("uninstall", "Remove what install added"),
            ("doctor", "Check which copies run, the graph and the hooks"),
        ),
    ),
    (
        "Build the graph",
        (
            ("build", "Parse every file into a new graph"),
            ("update", "Parse only the files that changed"),
            ("watch", "Update the graph as files change"),
            ("status", "Show graph counts"),
            ("postprocess", "Redo flows, communities and the search index"),
            ("embed", "Add vectors for search by meaning"),
            ("forget", "Drop files from the graph"),
        ),
    ),
    (
        "Review",
        (
            ("detect-changes", "Score the risk of your changes (read-only)"),
            ("impact", "Show what a change can reach"),
            ("dead-code", "Find code that nothing calls or tests"),
            ("refactor", "Preview a rename, dead code or suggestions"),
        ),
    ),
    (
        "Explore",
        (
            ("query", "Callers, callees, imports, tests and more"),
            ("search", "Find code by name or keyword"),
            ("architecture", "Show the main parts of the code"),
            ("flows", "List execution flows"),
            ("flow", "Show one execution flow"),
            ("communities", "List groups of related code"),
            ("community", "Show one group"),
            ("large-functions", "Find very long functions and classes"),
            ("visualize", "Draw the graph as an interactive page"),
            ("wiki", "Write a Markdown wiki from the graph"),
            ("context-history", "Show the saved-context log"),
        ),
    ),
    (
        "Serve and more",
        (
            ("serve", "Start the MCP server (stdio, or --http on localhost)"),
            ("mcp", "Same as serve"),
            ("daemon", "Watch many repositories in the background"),
            ("register", "Add a repository to the multi-repo list"),
            ("unregister", "Remove a repository from that list"),
            ("repos", "Show the listed repositories"),
            ("eval", "Run the benchmarks"),
        ),
    ),
);

glob _HIDDEN_COMMANDS: any = frozenset({"enrich", "hook-update", "hook-status"});

def _banner_commands(bold: str, green: str, reset: str) -> str {
    name: any;
    width: any = max(len(name) for (_, rows) in _BANNER_GROUPS for (name, _) in rows) + 2;
    lines: list[str] = [];
    for (title, rows) in _BANNER_GROUPS {
        lines.append(f"  {bold}{title}:{reset}");
        for (name, text) in rows {
            lines.append(f"    {green}{name}{reset}{" " * (width - len(name))}{text}");
        }
        lines.append("");
    }
    return "\n".join(lines);
}

def _instruction_files_to_modify(
    repo_root: Path, target: str, platforms: Iterable[str] | None = None
) -> list[tuple[str, str]] {
    targets: list[tuple[str, str]];
    _CLAUDE_MD_SECTION = lazy("skills", "_CLAUDE_MD_SECTION");
    _CLAUDE_MD_SECTION_MARKER = lazy("skills", "_CLAUDE_MD_SECTION_MARKER");
    _COPILOT_SECTION = lazy("skills", "_COPILOT_SECTION");
    _PLATFORM_INSTRUCTION_CUSTOM_SECTIONS = lazy("skills", "_PLATFORM_INSTRUCTION_CUSTOM_SECTIONS");
    _PLATFORM_INSTRUCTION_FILES = lazy("skills", "_PLATFORM_INSTRUCTION_FILES");
    _upgrade_managed_block = lazy("skills", "_upgrade_managed_block");
    instruction_file_wanted = lazy("skills", "instruction_file_wanted");

    targets = [];

    def _describe(filename: str, path: Path, section: str) {
        if not install_plan.exists(path) {
            targets.append((filename, "new"));
            return;
        }
        content: any = install_plan.read_text(path, encoding="utf-8", errors="replace");
        if _CLAUDE_MD_SECTION_MARKER not in content {
            targets.append((filename, "append"));
        } elif _upgrade_managed_block(content, section) is not None {
            targets.append((filename, "update"));
        }
    }

    if instruction_file_wanted(("claude",), target, platforms) {
        _describe("CLAUDE.md", repo_root / "CLAUDE.md", _CLAUDE_MD_SECTION);
    }

    for (filename, owners) in _PLATFORM_INSTRUCTION_FILES.items() {
        if not instruction_file_wanted(owners, target, platforms) {
            continue;
        }
        section: any = _COPILOT_SECTION
            if filename in _PLATFORM_INSTRUCTION_CUSTOM_SECTIONS
            else _CLAUDE_MD_SECTION;
        _describe(filename, repo_root / filename, section);
    }

    return targets;
}

def _confirm_yes_no(
    prompt: str,
    default_yes: bool = True,
    *,
    cancel_on_interrupt: bool = False,
    no_terminal_hint: str = "",
) -> bool {
    def take_default -> bool {
        answer: any = "yes" if default_yes else "no";
        print(f"No terminal: taking the default ({answer}). {no_terminal_hint}".rstrip());
        return default_yes;
    }

    if not sys.stdin.isatty() {
        return take_default();
    }
    suffix: any = "[Y/n]" if default_yes else "[y/N]";
    try {
        answer: any = builtins.input(f"{prompt} {suffix} ").strip().lower();
    } except KeyboardInterrupt {
        print();
        if cancel_on_interrupt {
            raise;
        }
        return False;
    } except EOFError {
        print();
        return take_default();
    }
    if not answer {
        return default_yes;
    }
    return answer in ("y", "yes");
}

def _match_files_to_forget(
    stored_files: Iterable[str], patterns: Iterable[str], repo_root: Path
) -> list[str] {
    `root: any = repo_root.resolve();
    stored: any = `list(stored_files);
    matched: set[str] = set[any]();

    for raw in patterns {
        pattern: any = `str(raw).strip();
        if not pattern {
            continue;
        }
        expanded: any = Path(pattern).expanduser();
        absolute: any = expanded if expanded.is_absolute() else `root / expanded;
        absolute_str: any = os.path.normpath(`str(absolute));
        dir_prefix: any = absolute_str.rstrip(os.sep) + os.sep;

        for stored_path in stored {
            normalised: any = os.path.normpath(stored_path);
            try {
                relative: any = os.path.relpath(normalised, `str(`root));
            } except ValueError {
                relative = None;
            }
            if normalised == absolute_str {
                matched.add(stored_path);
                continue;
            }
            if relative is not None and os.path.normpath(relative) == os.path.normpath(pattern) {
                matched.add(stored_path);
                continue;
            }
            if normalised.startswith(dir_prefix) {
                matched.add(stored_path);
                continue;
            }
            if fnmatch.fnmatch(normalised, absolute_str)
                or relative is not None and fnmatch.fnmatch(relative, pattern)
            {
                matched.add(stored_path);
            }
        }
    }

    return sorted(matched);
}

glob _STEERING_HELP: any = "Claude Code only: add (or, with --no-steering, remove) a hook that puts graph context beside each search and read. Off unless asked for; it uses a few hundred tokens at most on each call";

def _say_nothing(*_args_: object, **_kwargs: object) {
    _args: any = tuple(_args_);
}

def _apply_steering_choice(
    repo_root: Path, target: str, steering: bool, *, skip_hooks: bool, dry_run: bool
) {
    install_steering_hook = lazy("skills", "install_steering_hook");
    remove_steering_hook = lazy("uninstall", "remove_steering_hook");

    lead: any = "[dry-run] " if dry_run else "";
    if target not in ("claude", "all") {
        print(f"{lead}Skipped the steering hook: it is only for Claude Code.");
        return;
    }
    if not steering {
        `report: any = remove_steering_hook(repo_root);
        for skipped in `report.skipped_paths {
            print(f"{lead}Could not remove the steering hook: {skipped}");
        }
        if `report.errors {
            for error in `report.errors {
                print(f"{lead}Could not remove the steering hook: {error}");
            }
        } elif `report.total_actions == 0 {
            if not `report.skipped_paths {
                print(f"{lead}No steering hook to remove.");
            }
        } elif dry_run {
            print("[dry-run] Would remove the steering hook.");
        } else {
            print("Removed the steering hook.");
        }
        return;
    }
    if skip_hooks {
        print(f"{lead}Skipped the steering hook: --no-hooks was given.");
        return;
    }
    path: any = install_steering_hook(repo_root);
    if path and dry_run {
        print(f"[dry-run] Would add the steering hook to {path}.");
    } elif path {
        print(f"Installed the steering hook in {path}. Remove it with --no-steering.");
    }
}

def _report_gitignore_block(repo_root: Path, plan: _GitignorePlan, *, dry_run: bool) {
    install_gitignore: any = lazy("install_gitignore");

    result: any = install_gitignore.apply(repo_root, plan, dry_run=False);
    lead: any = "[dry-run] " if dry_run else "";
    if result.status == "written" {
        if result.added {
            verb: any = "Would add" if dry_run else "Added";
            print(f"{lead}{verb} to .gitignore, in the code-review-graph install files block:");
            for `entry in result.added {
                print(f"    /{`entry}");
            }
        } else {
            verb = "Would drop" if dry_run else "Dropped";
            print(f"{lead}{verb} entries for paths that are gone from the .gitignore block.");
        }
    } elif result.status == "unchanged" {
        if result.entries {
            print(f"{lead}The .gitignore block already lists every file install created.");
        } else {
            print(f"{lead}No files to add to .gitignore: install created none that git shows.");
        }
    } elif result.status == "edited" {
        print(
            f"{lead}Left the code-review-graph install files block in .gitignore alone: it was edited by hand.",
        );
    } elif result.status == "not-git" {
        print(f"{lead}Skipped --gitignore: {repo_root} is not a Git work tree.");
    } else {
        print(f"{lead}Could not update .gitignore: {result.detail}", file=sys.stderr);
    }
}

def _handle_init(args: argparse.Namespace) {
    name: any;
    path: any;
    find_repo_root = lazy("incremental", "find_repo_root");
    inject_instruction_files = lazy("skills", "inject_instruction_files");
    selected_platforms = lazy("skills", "selected_platforms");

    repo_root: any = Path(args.repo) if args.repo else find_repo_root();
    if not repo_root {
        repo_root = Path.cwd();
    }

    dry_run: any = getattr(args, "dry_run", False);
    target: any = getattr(args, "platform", "all") or "all";
    if target == "claude-code" {
        target = "claude";
    }
    auto_yes: any = getattr(args, "yes", False);
    skip_instructions: any = getattr(args, "no_instructions", False);
    skip_hooks: any = getattr(args, "no_hooks", False);
    steering: any = getattr(args, "steering", None);
    platforms: any = selected_platforms(repo_root, target);
    gitignore_plan: _GitignorePlan | None = None;
    if getattr(args, "gitignore", False) {
        _plan_gitignore = lazy("install_gitignore", "plan");

        gitignore_plan = _plan_gitignore(
            repo_root,
            target,
            with_skills=not getattr(args, "no_skills", False),
            with_hooks=not skip_hooks,
            with_instructions=not skip_instructions,
            platforms=platforms,
        );
    }
    `report: any = io.StringIO();
    try {
        plan: any;
        with install_plan.planning() as plan {
            quiet: any = contextlib.nullcontext()
                if dry_run
                else contextlib.redirect_stdout(`report);
            with quiet {
                _plan_mcp_configs(repo_root, target, dry_run, platforms);
                codex_skill_error: any = _plan_integrations(
                    args,
                    repo_root,
                    target,
                    platforms,
                    say=_say_nothing if dry_run else builtins.print,
                );
                if steering is not None {
                    _apply_steering_choice(
                        repo_root, target, steering, skip_hooks=skip_hooks, dry_run=dry_run
                    );
                }
            }
            instr_targets: list[tuple[str, str]] = [];
            outcomes: dict[str, str] = {};
            before_instructions: any = plan.checkpoint();
            if not skip_instructions {
                instr_targets = _instruction_files_to_modify(repo_root, target, platforms);
                outcomes = inject_instruction_files(repo_root, target=target, platforms=platforms);
            }
            instr_changes: any = plan.changes_since(before_instructions);
            gitignore_report: any = io.StringIO();
            if gitignore_plan is not None {
                to: any = sys.stdout if dry_run else gitignore_report;
                with contextlib.redirect_stdout(to) {
                    print();
                    _report_gitignore_block(repo_root, gitignore_plan, dry_run=dry_run);
                }
            }
            install_manifest.plan_record(repo_root, plan);

            if dry_run {
                _print_instruction_conflicts(outcomes);
                if codex_skill_error and target == "codex" {
                    print(f"[dry-run] {codex_skill_error}", file=sys.stderr);
                }
                _print_dry_run(plan, repo_root);
                return;
            }

            _print_planned_files(plan, repo_root, skip=instr_changes);
            inject: any = False;
            if instr_changes {
                named: any = {(repo_root / name).resolve() for (name, _) in instr_targets};
                change: any;
                for change in instr_changes {
                    if change.path not in named {
                        shown: any = install_plan.display_path(change.path, repo_root);
                        how: any = "old file removed"
                            if change.after is None
                            else "old section removed";
                        instr_targets.append((shown, how));
                    }
                }
                print();
                print("Graph instructions will be injected into:");
                for (name, how) in instr_targets {
                    print(f"  {name} ({how})");
                }
                if not auto_yes and sys.stdin.isatty() {
                    print("Ctrl-C now to stop; nothing has been written yet.");
                }
                try {
                    inject = auto_yes
                        or _confirm_yes_no(
                            "Inject graph instructions into these files?",
                            default_yes=True,
                            cancel_on_interrupt=True,
                            no_terminal_hint="Use --no-instructions to skip them.",
                        );
                } except KeyboardInterrupt {
                    print("Install cancelled. No files were written.");
                    raise SystemExit(130) from None;
                }
            }
            if instr_changes and not inject {
                plan.rollback(before_instructions);
                if gitignore_plan is not None {
                    gitignore_report = io.StringIO();
                    with contextlib.redirect_stdout(gitignore_report) {
                        print();
                        _report_gitignore_block(repo_root, gitignore_plan, dry_run=False);
                    }
                }
                install_manifest.plan_record(repo_root, plan);
            }
            with contextlib.redirect_stdout(`report) {
                if inject {
                    for (label, wording) in (
                        ("created", "Injected graph instructions into"),
                        ("updated", "Updated graph instructions in"),
                    ) {
                        names: any = [f for (f, o) in outcomes.items() if o == label];
                        if names {
                            print(f"{wording}: {", ".join(names)}");
                        }
                    }
                    _print_instruction_conflicts(outcomes);
                } elif skip_instructions {
                    print("Skipped instruction injection (--no-instructions).");
                } elif instr_changes {
                    print("Skipped instruction injection (user declined).");
                } else {
                    _print_instruction_conflicts(outcomes);
                }
            }
            `report.write(gitignore_report.getvalue());
        }
    } except Exception {
        print("Install stopped before writing any file.", file=sys.stderr);
        raise;
    }
    planned: any = plan.changes();
    failures: any = plan.apply();

    print();
    if failures {
        failed: any = {path for (path, _) in failures};
        written: any = [change for change in planned if change.path not in failed];
        if written {
            print("These files were written:");
            for change in written {
                print(f"  {install_plan.display_path(change.path, repo_root)}");
            }
        }
        for (path, reason) in failures {
            print(f"Could not write {path}: {reason}", file=sys.stderr);
        }
        raise CodeReviewGraphError(
            f"install could not write {len(failures)} file(s); see the messages above"
        );
    }
    sys.stdout.write(`report.getvalue());
    if codex_skill_error and target == "codex" {
        raise CodeReviewGraphError(codex_skill_error);
    }
    print();
    print("Next steps:");
    print("  1. code-review-graph build    # build the knowledge graph");
    print("  2. Restart your AI coding tool to pick up the new config");
}

def _plan_mcp_configs(
    repo_root: Path, target: str, dry_run: bool, platforms: Iterable[str] | None = None
) {
    PLATFORMS = lazy("skills", "PLATFORMS");
    install_platform_configs = lazy("skills", "install_platform_configs");

    print("Installing MCP server config...");
    configured: any = install_platform_configs(
        repo_root, target=target, dry_run=dry_run, platforms=platforms
    );
    if not configured {
        print("No platforms detected.");
    } elif dry_run {
        print(
            f"\n[dry-run] Would configure {len(configured)} platform(s): {", ".join(configured)}"
        );
    } else {
        print(f"\nConfigured {len(configured)} platform(s): {", ".join(configured)}");
    }
    if target == "all" and platforms is not None {
        missing: any = [key for key in PLATFORMS if key not in `set(platforms)];
        if missing {
            print(f"Not found here, so not set up: {", ".join(missing)}.");
            print("Add one anyway with: code-review-graph install --platform NAME");
        }
    }
}

def _plan_integrations(
    args: argparse.Namespace,
    repo_root: Path,
    target: str,
    platforms: Iterable[str] | None = None,
    *,
    say: Callable[[str], None],
) -> str | None {
    ensure_repo_gitignore_excludes_crg = lazy("incremental", "ensure_repo_gitignore_excludes_crg");
    _git_hooks_dir = lazy("skills", "_git_hooks_dir");
    generate_skills = lazy("skills", "generate_skills");
    install_codebuddy_hooks = lazy("skills", "install_codebuddy_hooks");
    install_codebuddy_skills = lazy("skills", "install_codebuddy_skills");
    install_codex_hooks = lazy("skills", "install_codex_hooks");
    install_codex_skill = lazy("skills", "install_codex_skill");
    install_cursor_hooks = lazy("skills", "install_cursor_hooks");
    install_gemini_cli_hooks = lazy("skills", "install_gemini_cli_hooks");
    install_gemini_cli_skills = lazy("skills", "install_gemini_cli_skills");
    install_git_hook = lazy("skills", "install_git_hook");
    install_git_sync_hooks = lazy("skills", "install_git_sync_hooks");
    install_hermes_skills = lazy("skills", "install_hermes_skills");
    install_hooks = lazy("skills", "install_hooks");
    install_opencode_plugin = lazy("skills", "install_opencode_plugin");
    install_qoder_skills = lazy("skills", "install_qoder_skills");
    selected_platforms = lazy("skills", "selected_platforms");

    def shown(path: Path) -> str {
        return install_plan.display_path(path, repo_root);
    }

    chosen: any = frozenset(
        selected_platforms(repo_root, target) if platforms is None else platforms
    );
    gitignore_state: any = ensure_repo_gitignore_excludes_crg(repo_root);
    if gitignore_state == "created" {
        say("Created .gitignore and added .code-review-graph/.");
    } elif gitignore_state == "updated" {
        say("Updated .gitignore with .code-review-graph/.");
    } else {
        say(".gitignore already contains .code-review-graph/.");
    }

    skip_skills: any = getattr(args, "no_skills", False);
    skip_hooks: any = getattr(args, "no_hooks", False);
    codex_skill_error: str | None = None;
    if not skip_skills {
        if "codex" in chosen {
            try {
                codex_skill_dir: any = install_codex_skill();
            } except OSError as exc {
                codex_skill_dir = None;
                codex_skill_error = f"Could not install Codex skill: {exc}";
            }
            if codex_skill_dir is None {
                codex_skill_error = codex_skill_error
                    or "Codex skill installation refused existing files; check the warning above";
                if target == "all" {
                    print(codex_skill_error, file=sys.stderr);
                }
            } else {
                say(f"Installed Codex skill in {shown(codex_skill_dir)}");
            }
        }

        if "claude" in chosen {
            skills_dir: any = generate_skills(repo_root);
            say(f"Generated Claude Code skills in {shown(skills_dir)}");
        }
        if "gemini-cli" in chosen {
            gemini_skills_dir: any = install_gemini_cli_skills(repo_root);
            say(f"Installed Gemini CLI skills in {shown(gemini_skills_dir)}");
        }
        if "codebuddy" in chosen {
            codebuddy_skills_dir: any = install_codebuddy_skills(repo_root);
            say(f"Installed CodeBuddy skills in {shown(codebuddy_skills_dir)}");
        }
        if "hermes" in chosen {
            hermes_skills_dir: any = install_hermes_skills(repo_root);
            say(f"Installed Hermes Agent skills in {shown(hermes_skills_dir)}");
        }
        if "qoder" in chosen {
            qoder_skills_dir: any = install_qoder_skills(repo_root);
            if qoder_skills_dir {
                say(f"Installed Qoder skills in {shown(qoder_skills_dir)}");
            }
        }
    }

    if not skip_hooks and "codebuddy" in chosen {
        try {
            codebuddy_settings: any = install_codebuddy_hooks(repo_root);
            if codebuddy_settings {
                say(f"Installed CodeBuddy hooks in {shown(codebuddy_settings)}");
            }
        } except Exception as exc {
            logger.warning("Could not install CodeBuddy hooks: %s", exc);
        }
    }
    if not skip_hooks and "codex" in chosen {
        hooks_path: any = install_codex_hooks(repo_root);
        if hooks_path {
            say(f"Installed Codex hooks in {shown(hooks_path)}");
        }
    }
    if not skip_hooks {
        for plat in ("claude", "qoder") {
            if plat not in chosen {
                continue;
            }
            settings_path: any = install_hooks(repo_root, platform=plat);
            if settings_path {
                say(f"Installed hooks in {shown(settings_path)}");
            }
        }
    }
    if not skip_hooks
        and target in ("all", "claude", "qoder", "codex")
        and _git_hooks_dir(repo_root) is not None
    {
        git_hook: any = install_git_hook(repo_root);
        if git_hook {
            say(f"Installed git pre-commit hook in {shown(git_hook)}");
        }
        for sync_hook in install_git_sync_hooks(repo_root) {
            say(f"Installed git {sync_hook.name} hook in {shown(sync_hook)}");
        }
    }
    if not skip_hooks and "cursor" in chosen {
        try {
            hooks_path = install_cursor_hooks();
            if hooks_path {
                say(f"Installed Cursor hooks in {shown(hooks_path)}");
            }
        } except Exception as exc {
            logger.warning("Could not install Cursor hooks: %s", exc);
        }
    }

    if not skip_hooks and "gemini-cli" in chosen {
        try {
            gemini_settings: any = install_gemini_cli_hooks(repo_root);
            if gemini_settings {
                say(f"Installed Gemini CLI hooks in {shown(gemini_settings)}");
            }
        } except Exception as exc {
            logger.warning("Could not install Gemini CLI hooks: %s", exc);
        }
    }
    if not skip_hooks and "opencode" in chosen {
        try {
            plugin_path: any = install_opencode_plugin();
            say(f"Installed OpenCode plugin in {shown(plugin_path)}");
        } except Exception as exc {
            logger.warning("Could not install OpenCode plugin: %s", exc);
        }
    }
    return codex_skill_error;
}

def _print_instruction_conflicts(outcomes: dict[str, str]) {
    stale: any = [f for (f, o) in outcomes.items() if o == "conflict"];
    if stale {
        print(
            "Left edited graph instructions alone in: "
                + format(", ".join(stale), "")
                + ". Delete the section between <!-- code-review-graph MCP tools --> and its closing marker and reinstall to pick up the current text.",
        );
    }
}

def _print_planned_files(
    plan: install_plan.Plan, repo_root: Path, `skip: Iterable[install_plan.FileChange] = ()
) {
    change: any;

    skipped: any = {change.path for change in `skip};
    changes: any = [change for change in plan.changes() if change.path not in skipped];
    print();
    if not changes {
        print("No config, hook or skill files need changing.");
        return;
    }
    print("Install will change these files:");
    for change in changes {
        shown: any = install_plan.display_path(change.path, repo_root);
        print(f"  {shown} ({install_plan.describe(change)})");
    }
    print("Run with --dry-run to see each change first.");
}

def _print_dry_run(plan: install_plan.Plan, repo_root: Path) {
    changes: any = plan.changes();
    print();
    if not changes {
        print("[dry-run] Every file is already up to date.");
    } else {
        print(f"[dry-run] Install would change {len(changes)} file(s):");
        print();
        sys.stdout.write(install_plan.render(changes, repo_root));
    }
    print();
    print("[dry-run] No files were modified.");
}

def _handle_data_dir_option(args, repo_root: Path) {
    if hasattr(args, "data_dir") and args.data_dir {
        try {
            Registry = lazy("registry", "Registry");
            data_dir_path: any = Path(args.data_dir).expanduser().resolve();
            data_dir_path.mkdir(parents=True, exist_ok=True);
            Registry().set_data_dir(`str(repo_root), `str(data_dir_path));
            logging.info(f"Graph database will be stored at: {data_dir_path}");
        } except Exception as exc {
            logging.error(f"Failed to set data directory: {exc}");
            sys.exit(1);
        }
    }
}

def _add_embedding_refresh_args(command) {
    command.add_argument(
        "--embedding-provider",
        choices=["local", "openai", "google", "minimax", "voyage"],
        default=None,
        help="Explicitly refresh an existing embedding index with this provider; requires --embedding-model (default: disabled)",
    );
    command.add_argument(
        "--embedding-model",
        default=None,
        help="Exact model for --embedding-provider. Cloud providers may transmit source-derived text and incur API cost",
    );
}

def _add_follow_symlinks_arg(command) {
    command.add_argument(
        "--follow-symlinks",
        action=argparse.BooleanOptionalAction,
        default=None,
        help="Also index files in symlinked folders, inside or outside the repository, stored under their path inside it. Links that loop are skipped, and at most CRG_MAX_FOLLOWED_FILES files are taken. Default: off, or CRG_FOLLOW_SYMLINKS",
    );
}

def _follow_symlinks_kwargs(args) -> _FollowSymlinksKwargs {
    value: any = getattr(args, "follow_symlinks", None);
    if value is None {
        return {};
    }
    return {"follow_symlinks": `bool(value)};
}

def _embedding_refresh_kwargs(args, parser) -> _EmbeddingRefreshKwargs {
    provider: any = getattr(args, "embedding_provider", None);
    model: any = getattr(args, "embedding_model", None);
    if `bool(provider) != `bool(model) {
        parser.error("--embedding-provider and --embedding-model must be supplied together");
    }
    if not provider {
        return {};
    }
    assert isinstance(provider, `str);
    assert isinstance(model, `str);
    return {"embedding_provider": provider, "embedding_model": model};
}

def _non_negative_int(value: str) -> int {
    try {
        parsed: any = `int(value);
    } except ValueError as exc {
        raise argparse.ArgumentTypeError("must be an integer") from exc;
    }
    if parsed < 0 {
        raise argparse.ArgumentTypeError("must be zero or greater");
    }
    return parsed;
}

def _positive_int(value: str) -> int {
    parsed: any = _non_negative_int(value);
    if parsed == 0 {
        raise argparse.ArgumentTypeError("must be greater than zero");
    }
    return parsed;
}

def _detail_sections_arg(value: str) -> tuple[str, ...] {
    parse_detail_sections = lazy("change_details", "parse_detail_sections");

    try {
        return parse_detail_sections(value);
    } except ValueError as exc {
        raise argparse.ArgumentTypeError(`str(exc)) from exc;
    }
}

glob _GRAPH_TOOL_COMMANDS: any = set(
    ("query impact search flows flow communities community architecture large-functions refactor").split(),
);

glob _PATH_REPO_COMMANDS: any = frozenset({
    "context-history",
    "doctor",
    "install",
    "init",
    "uninstall",
    "build",
    "update",
    "postprocess",
    "embed",
    "watch",
    "status",
    "forget",
    "visualize",
    "wiki",
    "detect-changes",
    "dead-code",
    "serve",
    "mcp",
    *_GRAPH_TOOL_COMMANDS,
});

def _canonicalize_repo_argument(args: argparse.Namespace) {
    repo: any = getattr(args, "repo", None);
    if args.command in _PATH_REPO_COMMANDS and repo {
        args.repo = `str(Path(repo).expanduser().resolve());
    }
}

def _find_explicit_repo_root(start: Path) -> "Path | None" {
    current: any = start.resolve();
    if not current.is_dir() {
        return None;
    }
    while True {
        if `any((current / marker).exists() for marker in (".code-review-graph", ".git", ".svn")) {
            return current;
        }
        if current == current.parent {
            return None;
        }
        current = current.parent;
    }
}

def _handle_doctor(args) {
    run_doctor = lazy("doctor", "run_doctor");
    find_project_root = lazy("incremental", "find_project_root");

    if args.repo {
        given: any = Path(args.repo).expanduser();
        repo_root: any = _find_explicit_repo_root(given) or given.resolve();
    } else {
        repo_root = find_project_root();
    }
    code: any = run_doctor(repo_root, as_json=args.json_output);
    if code {
        raise SystemExit(code);
    }
}

def _handle_context_history(args) {
    import from datetime { datetime, time, timedelta, timezone }

    ch: any = lazy("context_history");
    find_project_root = lazy("incremental", "find_project_root");
    get_data_dir = lazy("incremental", "get_data_dir");

    if args.repo {
        given: any = Path(args.repo).expanduser();
        repo_root: any = _find_explicit_repo_root(given) or given;
    } else {
        repo_root = find_project_root();
    }
    if args.data_dir {
        data_dir: any = Path(args.data_dir).expanduser().resolve();
    } else {
        data_dir = get_data_dir(repo_root, create=False);
    }
    since: any = None;
    if args.days {
        first_day: any = datetime.now(timezone.utc).date() - timedelta(days=args.days - 1);
        since = datetime.combine(first_day, time(), tzinfo=timezone.utc);
    }
    entries: any;
    skipped: any;
    (entries, skipped) = ch.read_history(data_dir, since=since) as any;
    recording: any = ch.history_enabled();
    rows: any = ch.summarise(entries, by=args.by);
    totals: any = ch.total(entries);
    log_path: any = data_dir / ch.HISTORY_FILE;

    if args.json_output {
        print(
            json.dumps(
                {
                    "log": `str(log_path),
                    "recording": recording,
                    "by": args.by,
                    "days": args.days,
                    "rows": rows,
                    "total": totals,
                    "skipped_lines": skipped,
                },
                indent=2,
            ),
        );
        return;
    }

    window: any = f"last {args.days} day(s)" if args.days else "whole log";
    if not entries {
        if recording {
            print(f"No context history ({window}) in {log_path}.");
        } else {
            print(f"No context history ({window}). Recording is off.");
            print(
                f"Set {ch.HISTORY_ENV}=1 where the MCP server or the CLI runs, and each call that reports context savings adds one line to {log_path}.",
            );
            print("The log stays on this machine and holds only token counts and tool names.");
        }
        if skipped {
            print(f"Skipped {skipped} line(s) that could not be read.");
        }
        return;
    }

    print(
        "Context history ("
            + format(window, "")
            + "): "
            + format(totals["calls"], ",")
            + " call(s). Token counts are estimates (about 4 characters per token).",
    );
    print(f"Log: {log_path}");
    print();
    print(ch.format_table(rows, totals, by=args.by));
    if skipped {
        print(f"\nSkipped {skipped} line(s) that could not be read.");
    }
    if not recording {
        print(f"\nRecording is off. Set {ch.HISTORY_ENV}=1 to add new calls.");
    }
}

def _run_graph_tool_command(args, repo_root: Path) {
    tools: any = lazy("tools");

    `root: any = `str(repo_root);
    if args.command == "query" {
        result: any = tools.query_graph(
            pattern=args.pattern,
            target=args.target,
            repo_root=`root,
            **({"to": args.to} if args.to else {}),
        );
    } elif args.command == "impact" {
        result = tools.get_impact_radius(
            changed_files=args.files,
            max_depth=args.depth,
            max_results=args.max_results,
            repo_root=`root,
            base=args.base,
            detail_level=args.detail_level,
            max_files=args.max_files,
        );
    } elif args.command == "search" {
        result = tools.semantic_search_nodes(
            query=args.query, kind=args.kind, limit=args.limit, repo_root=`root
        );
    } elif args.command == "flows" {
        result = tools.list_flows(
            repo_root=`root, sort_by=args.sort, limit=args.limit, kind=args.kind
        );
    } elif args.command == "flow" {
        result = tools.get_flow(
            flow_id=args.id, flow_name=args.name, include_source=args.source, repo_root=`root
        );
    } elif args.command == "communities" {
        result = tools.list_communities_func(
            repo_root=`root, sort_by=args.sort, min_size=args.min_size
        );
    } elif args.command == "community" {
        result = tools.get_community_func(
            community_name=args.name,
            community_id=args.id,
            include_members=args.members,
            repo_root=`root,
        );
    } elif args.command == "architecture" {
        result = tools.get_architecture_overview_func(
            repo_root=`root, detail_level=args.detail_level
        );
    } elif args.command == "large-functions" {
        result = tools.find_large_functions(
            min_lines=args.min_lines,
            kind=args.kind,
            file_path_pattern=args.path,
            limit=args.limit,
            repo_root=`root,
        );
    } else {
        result = tools.refactor_func(
            mode=args.mode,
            old_name=args.old_name,
            new_name=args.new_name,
            kind=args.kind,
            file_pattern=args.path,
            repo_root=`root,
        );
    }
    print(json.dumps(result, indent=2, default=str));
}

glob EXIT_TEMPFAIL: any = getattr(os, "EX_TEMPFAIL", 75);

def _exit_if_contended(result: dict) {
    if result.get("status") != "contended" {
        return;
    }
    print(f"Skipped: {result.get("summary", "another write is running")}", file=sys.stderr);
    sys.exit(EXIT_TEMPFAIL);
}

def _warn_failed_files(result: dict) {
    failed: any = result.get("errors") or [];
    if not failed {
        return;
    }
    names: any = ", ".join(`str(item.get("file", "?")) for item in failed[:5]);
    extra: any = f" (+{len(failed) - 5} more)" if len(failed) > 5 else "";
    print(
        f"Warning: {len(failed)} file(s) failed to parse and were not updated: {names}{extra}",
        file=sys.stderr,
    );
}

def _open_graph_store(db_path: Path, command: str) -> any {
    open_store = lazy("tools._common", "_open_graph_store");

    return open_store(db_path, command);
}

def _require_repo_folder(repo_root: Path) {
    if not repo_root.is_dir() {
        raise CodeReviewGraphError(
            f"--repo is not a folder: {repo_root}. Check the path and try again."
        );
    }
}

def _ensure_project_marker(repo_root: Path) {
    if repo_root.is_dir()
        and not `any(
            (repo_root / marker).exists() for marker in (".git", ".svn", ".code-review-graph")
        )
    {
        _create_data_dir = lazy("incremental", "_create_data_dir");
        _create_data_dir(repo_root / ".code-review-graph");
    }
}

def _enrich_kwargs(args) -> dict {
    return {"enrich": True} if getattr(args, "enrich", False) else {};
}

glob _BUILD_NEXT_STEP: any = "Next: code-review-graph detect-changes --brief, or ask your assistant \"Review my changes\".";

def _handle_build_update(args, repo_root: Path, embedding_refresh_kwargs) {
    assert_graph_serves_root = lazy("incremental", "assert_graph_serves_root");
    get_db_path = lazy("incremental", "get_db_path");

    _ensure_project_marker(repo_root);
    if args.command == "build" {
        pp: any = "none"
            if getattr(args, "skip_postprocess", False)
            else "minimal" if getattr(args, "skip_flows", False) else "full";
        build_or_update_graph = lazy("tools.build", "build_or_update_graph");

        previous_disable: any = logging.root.manager.disable;
        if args.quiet {
            logging.disable(logging.INFO);
        }
        try {
            result: any = build_or_update_graph(
                full_rebuild=True,
                recover_corrupt=True,
                repo_root=`str(repo_root),
                postprocess=pp,
                wait_for_lock=getattr(args, "wait", False),
                **_enrich_kwargs(args),
                **embedding_refresh_kwargs,
                **_follow_symlinks_kwargs(args),
            );
        } finally {
            logging.disable(previous_disable);
        }
        _exit_if_contended(result);
        parsed: any = result.get("files_parsed", 0);
        nodes: any = result.get("total_nodes", 0);
        edges: any = result.get("total_edges", 0);
        if not args.quiet {
            print(f"Full build: {parsed} files, {nodes} nodes, {edges} edges (postprocess={pp})");
            if result.get("errors") {
                print(f"Errors: {len(result["errors"])}");
            }
            if parsed == 0 and not result.get("errors") {
                sys.stdout.flush();
                print(
                    f"Warning: no source files found under {repo_root}. Is this the project root?",
                    file=sys.stderr,
                );
            } elif parsed {
                print(_BUILD_NEXT_STEP);
            }
        }
    } elif args.command == "update" {
        pp = "none"
            if getattr(args, "skip_postprocess", False)
            else "minimal" if getattr(args, "skip_flows", False) else "full";
        build_or_update_graph = lazy("tools.build", "build_or_update_graph");

        previous_disable = logging.root.manager.disable;
        if args.quiet {
            logging.disable(logging.INFO);
        }
        try {
            result = build_or_update_graph(
                full_rebuild=False,
                repo_root=`str(repo_root),
                base=args.base,
                postprocess=pp,
                wait_for_lock=getattr(args, "wait", False),
                **_enrich_kwargs(args),
                **embedding_refresh_kwargs,
                **_follow_symlinks_kwargs(args),
            );
        } except RuntimeError as exc {
            print(f"Error: {exc}", file=sys.stderr);
            sys.exit(1);
        } finally {
            logging.disable(previous_disable);
        }
        _exit_if_contended(result);
        if result.get("status") == "error" {
            print(f"Error: {result.get("summary", "update failed")}", file=sys.stderr);
            sys.exit(1);
        }
        nodes = result.get("total_nodes", 0);
        edges = result.get("total_edges", 0);
        if not args.quiet {
            if result.get("build_type") == "full" {
                parsed = result.get("files_parsed", 0);
                print(
                    f"Full rebuild (no usable incremental base): {parsed} files, {nodes} nodes, {edges} edges (postprocess={pp})",
                );
            } else {
                updated: any = result.get("files_updated", 0);
                print(
                    f"Incremental: {updated} files updated, {nodes} nodes, {edges} edges (postprocess={pp})",
                );
            }
        }
        _warn_failed_files(result);
        if getattr(args, "brief", False) and not args.quiet {
            analyze_changes = lazy("changes", "analyze_changes");
            CallInfo = lazy("context_history", "CallInfo");
            attach_context_savings = lazy("context_savings", "attach_context_savings");
            estimate_file_tokens = lazy("context_savings", "estimate_file_tokens");
            discover_review_changes = lazy("incremental", "discover_review_changes");
            changed: any;
            brief_base: any;
            (changed, brief_base) = discover_review_changes(
                repo_root, result.get("base_resolved") or "HEAD~1"
            ) as any;
            if changed {
                WriteLock = lazy("locking", "WriteLock");

                db_path: any = get_db_path(repo_root, read_only=True);
                brief_lock: any = WriteLock(db_path);
                if not brief_lock.acquire(blocking=True) {
                    _write_skipped_response = lazy("tools.build", "_write_skipped_response");
                    _exit_if_contended(_write_skipped_response(db_path, brief_lock.holder_pid()));
                }
                store: any = None;
                try {
                    store = _open_graph_store(db_path, "update");
                    assert_graph_serves_root(repo_root, store);
                    impact: any = analyze_changes(
                        store, changed, repo_root=`str(repo_root), base=brief_base
                    );
                    original_tokens: any = estimate_file_tokens(repo_root, changed);
                    attach_context_savings(
                        impact,
                        original_tokens=original_tokens,
                        call=CallInfo(
                            data_dir=store.db_path.parent, tool="update --brief", files=len(changed)
                        ),
                    );
                    summary: any = impact.get("summary", "");
                    if summary {
                        print(summary);
                    }
                    _print_savings_panel(args, repo_root, changed, impact, original_tokens);
                } finally {
                    try {
                        if store is not None {
                            store.close();
                        }
                    } finally {
                        brief_lock.release();
                    }
                }
            }
        }
    }
}

def _print_savings_panel(
    args, repo_root: Path, changed: list[str], response: dict, original_tokens: int
) {
    format_context_savings_panel = lazy("context_savings", "format_context_savings_panel");
    verify_with_tiktoken = lazy("context_savings", "verify_with_tiktoken");

    if not response.get("changed_functions") {
        print("Token Savings: none to show, as no functions changed.");
        return;
    }
    verified: any = None;
    if getattr(args, "verify", False) {
        verified = verify_with_tiktoken(repo_root, changed, response);
        if verified is None {
            print("Note: --verify requires tiktoken. Install with `pip install tiktoken`.");
        }
    }
    panel: any = format_context_savings_panel(
        response.get("context_savings"),
        original_tokens=original_tokens,
        response=response,
        verified=verified,
    );
    if panel {
        print(panel);
    }
}

def _handle_forget(args, repo_root: Path, db_path: Path, *, legacy: bool = False) {
    _prepare_db_path = lazy("incremental", "_prepare_db_path");
    assert_graph_serves_root = lazy("incremental", "assert_graph_serves_root");

    lock: any = None;
    if not args.dry_run {
        _lock_or_skip = lazy("tools.build", "_lock_or_skip");

        contended: any;
        (lock, contended) = _lock_or_skip(
            db_path, args.wait, outcome="nothing was forgotten"
        ) as any;
        if contended is not None {
            _exit_if_contended(contended);
        }
    }
    store: any = None;
    try {
        if args.dry_run {
            GraphStore = lazy("graph", "GraphStore");

            store = GraphStore(
                repo_root / ".code-review-graph.db" if legacy else db_path, read_only=True
            );
        } else {
            if legacy {
                _prepare_db_path(repo_root, db_path);
            }
            store = _open_graph_store(db_path, args.command);
        }
        assert_graph_serves_root(repo_root, store);
        stored_files: any = store.get_all_files();
        targets: any = _match_files_to_forget(stored_files, args.paths, repo_root);
        if not targets {
            print("No parsed files matched the given path(s).");
            print(f"The graph currently tracks {len(stored_files)} file(s).");
            return;
        }
        print("[dry-run] Would forget these files:" if args.dry_run else "Forgetting these files:");
        for file_path in targets {
            try {
                display: any = os.path.relpath(file_path, `str(repo_root));
            } except ValueError {
                display = file_path;
            }
            print(f"  {display}");
        }
        if args.dry_run {
            print(
                f"\n[dry-run] {len(targets)} file(s) would be removed from the graph. No changes made.",
            );
            return;
        }

        forget_files = lazy("forget", "forget_files");

        summary: any = forget_files(store, repo_root, targets);
        reparsed: any = summary.get("reparsed", []);
        if reparsed {
            print(f"  re-resolved {len(reparsed)} referring file(s) so no edges dangle");
        }
        remaining: any = len(stored_files) - len(targets);
        print(f"\nForgot {len(targets)} file(s); {remaining} file(s) remain in the graph.");
    } finally {
        try {
            if store is not None {
                store.close();
            }
        } finally {
            if lock is not None {
                lock.release();
            }
        }
    }
}

def main {
    try {
        _dispatch();
    } except CodeReviewGraphError as exc {
        print(f"Error: {exc}", file=sys.stderr);
        raise SystemExit(1) from None;
    } except sqlite3.OperationalError as exc {
        if not is_lock_error(exc) {
            raise;
        }
        print(
            f"Error: another process is updating this graph ({exc}).\nNothing was written, and no freshness anchor was recorded, so the graph is unchanged.\nWait for the other process (a watcher, a daemon, or another code-review-graph run) to finish and try again.",
            file=sys.stderr,
        );
        raise SystemExit(1) from None;
    }
}

glob _SUBCOMMANDS: dict[str, argparse.ArgumentParser] = {};

def _is_seeded(args: argparse.Namespace) -> bool {
    return `bool(
        getattr(args, "seed_symbol", None)
            or getattr(args, "seed_file", None)
            or getattr(args, "seed_changed", False)
            or getattr(args, "seed_flow", None)
            or getattr(args, "path_from", None)
            or getattr(args, "path_to", None),
    );
}

def _check_visualize_flags(args: argparse.Namespace, fmt: str) {
    error: any = _SUBCOMMANDS["visualize"].error;
    seeded: any = _is_seeded(args);
    tuning: any = [
        name
        for name in ("depth", "render_depth", "max_nodes")
        if getattr(args, name, None) is not None
    ];
    if getattr(args, "seed_changed_base", None) is not None
        and not getattr(args, "seed_changed", False)
    {
        error("--seed-changed-base requires --seed-changed");
    }
    if fmt != "html" {
        if seeded {
            error(
                f"the seed flags build an interactive page and have no effect on --format {fmt}; drop the seed or use --format html",
            );
        }
        if tuning {
            flag: any = "--" + tuning[0].replace("_", "-");
            error(f"{flag} has no effect on --format {fmt}");
        }
        if getattr(args, "sidecar", False) {
            error(f"--sidecar has no effect on --format {fmt}");
        }
    }
    if tuning and not seeded {
        flag = "--" + tuning[0].replace("_", "-");
        error(
            f"{flag} only applies to a seeded view; add --seed-symbol, --seed-file, --seed-changed, --seed-flow or --path-from/--path-to",
        );
    }
    if seeded and (getattr(args, "mode", "auto") or "auto") not in ("auto", "full") {
        error(
            f"--mode {args.mode} aggregates the graph into bubbles, which is the opposite of a seeded neighbourhood; use --mode full or drop the seed",
        );
    }
}

def _print_seed_budget(`report: dict) {
    if not `report {
        return;
    }
    dropped: any = `report.get("seeds_dropped", 0);
    if dropped {
        kept: any = `report.get("seeds", 0);
        requested: any = `report.get("seeds_requested", kept + dropped);
        print(
            "  --max-nodes "
                + format(`report.get("max_nodes"), "")
                + " kept the "
                + format(kept, "")
                + " best-connected of "
                + format(requested, "")
                + " seed nodes; "
                + format(dropped, "")
                + " seeds and every context hop were dropped",
        );
    } elif `report.get("truncated") {
        print(
            "  --max-nodes "
                + format(`report.get("max_nodes"), "")
                + " trimmed the outer hops; every seed kept, "
                + format(`report.get("node_count"), "")
                + " nodes shipped",
        );
    }
}

def _describe_visualization(args: argparse.Namespace, vis_mode: str, depth: int) -> str {
    if getattr(args, "path_from", None) {
        return f"path {args.path_from} -> {args.path_to}, depth {depth}";
    }
    seeds: list[str] = [];
    seeds.extend(getattr(args, "seed_symbol", None) or []);
    seeds.extend(getattr(args, "seed_file", None) or []);
    if getattr(args, "seed_changed", False) {
        seeds.append("changed files");
    }
    if getattr(args, "seed_flow", None) {
        seeds.append(f"flow {args.seed_flow}");
    }
    if seeds {
        shown: any = ", ".join(seeds[:3]);
        if len(seeds) > 3 {
            shown += f", +{len(seeds) - 3} more";
        }
        return f"neighbourhood of {shown}, depth {depth}";
    }
    return vis_mode;
}

def build_parser -> argparse.ArgumentParser {
    ap: any = argparse.ArgumentParser(
        prog="code-review-graph",
        description="Persistent incremental knowledge graph for code reviews",
        epilog="Start: code-review-graph install && code-review-graph build",
    );
    ap.add_argument("-v", "--version", action="store_true", help="Show version and exit");
    sub: any = ap.add_subparsers(dest="command", metavar="<command>");
    install_cmd: any = sub.add_parser(
        "install", help="Register MCP server with AI coding platforms"
    );
    install_cmd.add_argument("--repo", default=None, help="Repository root (auto-detected)");
    install_cmd.add_argument(
        "--dry-run",
        action="store_true",
        help="Show each file install would change, as a diff, and write nothing",
    );
    install_cmd.add_argument(
        "--no-skills", action="store_true", help="Skip generating platform-native skill files"
    );
    install_cmd.add_argument(
        "--no-hooks", action="store_true", help="Skip installing platform-native hooks"
    );
    install_cmd.add_argument(
        "--steering", action=argparse.BooleanOptionalAction, default=None, help=_STEERING_HELP
    );
    install_cmd.add_argument(
        "--no-instructions",
        action="store_true",
        help="Skip injecting graph instructions into CLAUDE.md / AGENTS.md / etc.",
    );
    install_cmd.add_argument(
        "-y",
        "--yes",
        action="store_true",
        help="Auto-confirm instruction injection without an interactive prompt",
    );
    install_cmd.add_argument("--gitignore", action="store_true", help=_GITIGNORE_HELP);
    install_cmd.add_argument("--skills", action="store_true", help=argparse.SUPPRESS);
    install_cmd.add_argument("--hooks", action="store_true", help=argparse.SUPPRESS);
    install_cmd.add_argument(
        "--all", action="store_true", dest="install_all", help=argparse.SUPPRESS
    );
    install_cmd.add_argument(
        "--platform",
        choices=_PLATFORM_CHOICES,
        default="all",
        help="Target platform for MCP config (default: all detected)",
    );

    init_cmd: any = sub.add_parser("init", help="Alias for install");
    init_cmd.add_argument("--repo", default=None, help="Repository root (auto-detected)");
    init_cmd.add_argument(
        "--dry-run",
        action="store_true",
        help="Show each file install would change, as a diff, and write nothing",
    );
    init_cmd.add_argument(
        "--no-skills", action="store_true", help="Skip generating platform-native skill files"
    );
    init_cmd.add_argument(
        "--no-hooks", action="store_true", help="Skip installing platform-native hooks"
    );
    init_cmd.add_argument(
        "--steering", action=argparse.BooleanOptionalAction, default=None, help=_STEERING_HELP
    );
    init_cmd.add_argument(
        "--no-instructions",
        action="store_true",
        help="Skip injecting graph instructions into CLAUDE.md / AGENTS.md / etc.",
    );
    init_cmd.add_argument(
        "-y",
        "--yes",
        action="store_true",
        help="Auto-confirm instruction injection without an interactive prompt",
    );
    init_cmd.add_argument("--gitignore", action="store_true", help=_GITIGNORE_HELP);
    init_cmd.add_argument("--skills", action="store_true", help=argparse.SUPPRESS);
    init_cmd.add_argument("--hooks", action="store_true", help=argparse.SUPPRESS);
    init_cmd.add_argument("--all", action="store_true", dest="install_all", help=argparse.SUPPRESS);
    init_cmd.add_argument(
        "--platform",
        choices=_PLATFORM_CHOICES,
        default="all",
        help="Target platform for MCP config (default: all detected)",
    );

    uninstall_cmd: any = sub.add_parser(
        "uninstall",
        help="Safely remove code-review-graph data, configs, hooks, and generated skills",
    );
    uninstall_cmd.add_argument(
        "--repo",
        default=None,
        help="Path inside a Git/SVN repository to clean (default: current directory)",
    );
    uninstall_cmd.add_argument(
        "--all-repos",
        action="store_true",
        help="Also clean every repository listed in the CRG registry",
    );
    uninstall_cmd.add_argument(
        "--keep-data",
        action="store_true",
        help="Keep graph databases while removing installed integrations",
    );
    uninstall_cmd.add_argument(
        "--keep-user-configs",
        action="store_true",
        help="Clean repositories only; do not edit files under the user home",
    );
    uninstall_cmd.add_argument(
        "--platform",
        choices=_PLATFORM_CHOICES,
        default="all",
        help="Unbind only this platform's MCP registration and keep the graph data and every other integration. Default: all (full uninstall).",
    );
    uninstall_cmd.add_argument(
        "--dry-run",
        action="store_true",
        help="Print every planned action without writing or deleting anything",
    );
    uninstall_cmd.add_argument(
        "-y", "--yes", action="store_true", help="Apply without an interactive confirmation"
    );
    doctor_cmd: any = sub.add_parser(
        "doctor",
        help="Check which copies run, the graph and the hooks (read-only)",
        description="Check the setup without changing anything: every code-review-graph on PATH and its version, the version the MCP entries in this repository's configs run, the graph's schema and whether it is current, and which hooks are installed. Exit 0 when nothing failed, 1 when something did.",
    );
    doctor_cmd.add_argument("--repo", default=None, help="Repository root (auto-detected)");
    doctor_cmd.add_argument(
        "--json",
        action="store_true",
        dest="json_output",
        help="Output one machine-readable JSON object",
    );
    build_cmd: any = sub.add_parser("build", help="Full graph build (re-parse all files)");
    build_cmd.add_argument("--repo", default=None, help="Repository root (auto-detected)");
    build_cmd.add_argument("-q", "--quiet", action="store_true", help="Suppress output");
    build_cmd.add_argument(
        "--skip-flows",
        action="store_true",
        help="Skip flow/community detection (signatures + FTS only)",
    );
    build_cmd.add_argument(
        "--skip-postprocess", action="store_true", help="Skip all post-processing (raw parse only)"
    );
    build_cmd.add_argument(
        "--data-dir",
        default=None,
        help="External directory to store graph database (useful for network shares)",
    );
    _add_embedding_refresh_args(build_cmd);
    _add_follow_symlinks_arg(build_cmd);
    build_cmd.add_argument(
        "--enrich",
        action="store_true",
        help="Also resolve Python method calls with Jedi (needs the 'enrichment' extra; about a second more per Python file). Same as CRG_ENABLE_ENRICHMENT=1. Default: off",
    );
    build_cmd.add_argument(
        "--wait",
        action="store_true",
        help="If a build for this repository is already running, wait for it to finish instead of skipping. Default: report the overlap and exit without re-parsing the same files.",
    );
    update_cmd: any = sub.add_parser("update", help="Incremental update (only changed files)");
    update_cmd.add_argument(
        "--base",
        default=None,
        help="Git diff base (default: the commit the graph was last built at)",
    );
    update_cmd.add_argument("--repo", default=None, help="Repository root (auto-detected)");
    update_cmd.add_argument("-q", "--quiet", action="store_true", help="Suppress output");
    update_cmd.add_argument(
        "--skip-flows",
        action="store_true",
        help="Skip flow/community detection (signatures + FTS only)",
    );
    update_cmd.add_argument(
        "--skip-postprocess", action="store_true", help="Skip all post-processing (raw parse only)"
    );
    update_cmd.add_argument(
        "--brief",
        action="store_true",
        help="After re-parsing changed files into the graph, also print the risk summary + Token Savings panel that 'detect-changes --brief' prints. Use this after a rebase or large change set when you want to refresh the graph AND see the impact in one command; use 'detect-changes --brief' alone when the graph is already up to date (analysis only, no re-parse).",
    );
    update_cmd.add_argument(
        "--verify",
        action="store_true",
        help="Calibrate the estimated savings against tiktoken's cl100k_base tokenizer (the GPT-4 family tokenizer). Adds a second row to the panel with the real token counts. Requires `pip install tiktoken`.",
    );
    update_cmd.add_argument(
        "--data-dir",
        default=None,
        help="External directory to store graph database (useful for network shares)",
    );
    _add_embedding_refresh_args(update_cmd);
    _add_follow_symlinks_arg(update_cmd);
    update_cmd.add_argument(
        "--enrich",
        action="store_true",
        help="Also resolve Python method calls with Jedi (needs the 'enrichment' extra; about a second more per Python file). Same as CRG_ENABLE_ENRICHMENT=1. Default: off",
    );
    update_cmd.add_argument(
        "--wait",
        action="store_true",
        help="If a build for this repository is already running, wait for it to finish instead of skipping. Default: report the overlap and exit without re-parsing the same files.",
    );
    pp_cmd: any = sub.add_parser(
        "postprocess", help="Run post-processing on existing graph (flows, communities, FTS)"
    );
    pp_cmd.add_argument("--repo", default=None, help="Repository root (auto-detected)");
    pp_cmd.add_argument("--no-flows", action="store_true", help="Skip flow detection");
    pp_cmd.add_argument("--no-communities", action="store_true", help="Skip community detection");
    pp_cmd.add_argument("--no-fts", action="store_true", help="Skip FTS rebuild");
    pp_cmd.add_argument(
        "--data-dir",
        default=None,
        help="External directory to store graph database (useful for network shares)",
    );
    _add_embedding_refresh_args(pp_cmd);
    pp_cmd.add_argument(
        "--wait",
        action="store_true",
        help="If a build, update or postprocess is already running for this repository, wait for it to finish instead of skipping.",
    );
    embed_cmd: any = sub.add_parser("embed", help="Compute vector embeddings for semantic search");
    embed_cmd.add_argument("--repo", default=None, help="Repository root (auto-detected)");
    embed_cmd.add_argument(
        "--provider",
        choices=["local", "openai", "google", "minimax", "voyage"],
        default=None,
        help="Embedding provider (default: local, needs pip install \"code-review-graph[embeddings]\")",
    );
    embed_cmd.add_argument(
        "--model",
        default=None,
        help="Embedding model. For local: HuggingFace ID (default all-MiniLM-L6-v2); for openai/google/minimax/voyage: provider-specific model ID.",
    );
    embed_cmd.add_argument(
        "--data-dir",
        default=None,
        help="External directory to store graph database (useful for network shares)",
    );
    embed_cmd.add_argument(
        "--wait",
        action="store_true",
        help="If another write to this graph is running, wait for it to finish instead of exiting without embedding.",
    );
    watch_cmd: any = sub.add_parser("watch", help="Watch for changes and auto-update");
    watch_cmd.add_argument("--repo", default=None, help="Repository root (auto-detected)");
    watch_cmd.add_argument(
        "--data-dir",
        default=None,
        help="External directory to store graph database (useful for network shares)",
    );
    _add_embedding_refresh_args(watch_cmd);
    _add_follow_symlinks_arg(watch_cmd);
    status_cmd: any = sub.add_parser("status", help="Show graph statistics");
    status_cmd.add_argument("--repo", default=None, help="Repository root (auto-detected)");
    status_cmd.add_argument("-q", "--quiet", action="store_true", help="Suppress output");
    status_cmd.add_argument(
        "--json",
        action="store_true",
        dest="json_output",
        help="Output one machine-readable JSON object",
    );
    status_cmd.add_argument(
        "--data-dir",
        default=None,
        help="External directory to store graph database (useful for network shares)",
    );
    history_cmd: any = sub.add_parser(
        "context-history",
        help="Show the opt-in context savings log as a per-day or per-tool trend",
        description="Read the local context history log and print a trend. Recording is off unless CRG_CONTEXT_HISTORY=1 is set; the log stays on this machine and holds only token counts and tool names.",
    );
    history_cmd.add_argument("--repo", default=None, help="Repository root (auto-detected)");
    history_cmd.add_argument(
        "--by", choices=["day", "tool"], default="day", help="Group by UTC day (default) or by tool"
    );
    history_cmd.add_argument(
        "--days",
        type=_positive_int,
        default=None,
        help="Only the last N days (default: everything in the log)",
    );
    history_cmd.add_argument(
        "--json",
        action="store_true",
        dest="json_output",
        help="Output one machine-readable JSON object",
    );
    history_cmd.add_argument(
        "--data-dir", default=None, help="Directory that holds graph.db, when it is not the default"
    );
    forget_cmd: any = sub.add_parser(
        "forget", help="Remove already-parsed files from the graph without a full rebuild"
    );
    forget_cmd.add_argument(
        "paths",
        nargs="+",
        metavar="PATH",
        help="Files, directories, or glob patterns to drop from the graph. Paths may be absolute or relative to the repository root.",
    );
    forget_cmd.add_argument("--repo", default=None, help="Repository root (auto-detected)");
    forget_cmd.add_argument(
        "--dry-run",
        action="store_true",
        help="List the files that would be forgotten without modifying the graph",
    );
    forget_cmd.add_argument(
        "--data-dir",
        default=None,
        help="External directory to store graph database (useful for network shares)",
    );
    forget_cmd.add_argument(
        "--wait",
        action="store_true",
        help="If another write to this graph is running, wait for it to finish instead of exiting without forgetting anything.",
    );
    vis_cmd: any = sub.add_parser(
        "visualize", help="Generate an interactive HTML graph visualisation"
    );
    vis_cmd.add_argument("--repo", default=None, help="Repository root (auto-detected)");
    vis_cmd.add_argument(
        "--mode",
        choices=["auto", "full", "community", "file"],
        default="auto",
        help="Rendering mode: auto (default), full, community, or file",
    );
    vis_cmd.add_argument(
        "--serve",
        action="store_true",
        help="Start a local HTTP server to view the visualisation (localhost:8765)",
    );
    vis_group: any = vis_cmd.add_argument_group(
        "neighbourhood view",
        "Draw a neighbourhood instead of the whole repository. Seeded views carry only the nodes within --depth hops of the seed; everything else is left out of the payload, not dimmed.",
    );
    vis_group.add_argument(
        "--seed-symbol",
        action="append",
        default=None,
        metavar="SYMBOL",
        help="Seed from a symbol (qualified name, 'file.py::name', or a bare name). Repeatable.",
    );
    vis_group.add_argument(
        "--seed-file",
        action="append",
        default=None,
        metavar="PATH",
        help="Seed from a file and its symbols; glob patterns allowed. Repeatable.",
    );
    vis_group.add_argument(
        "--seed-changed",
        action="store_true",
        help="Seed from the files changed against --seed-changed-base",
    );
    vis_group.add_argument(
        "--seed-changed-base",
        default=None,
        metavar="REF",
        help="Git ref --seed-changed diffs against (default: HEAD~1)",
    );
    vis_group.add_argument(
        "--seed-flow",
        default=None,
        metavar="FLOW",
        help="Seed from an execution flow (name or id); see 'flows'",
    );
    vis_group.add_argument(
        "--path-from", default=None, metavar="SYMBOL", help="Start symbol of a shortest-path query"
    );
    vis_group.add_argument(
        "--path-to",
        default=None,
        metavar="SYMBOL",
        help="End symbol of a shortest-path query; the path through CALLS, IMPORTS_FROM and INHERITS is highlighted",
    );
    vis_group.add_argument(
        "--depth",
        type=int,
        default=None,
        metavar="K",
        help=f"Hops of context to include around the seed (default: {NB_DEFAULT_DEPTH})",
    );
    vis_group.add_argument(
        "--render-depth",
        type=int,
        default=None,
        metavar="K",
        help="Hops drawn before expanding on click (default: 1)",
    );
    vis_group.add_argument(
        "--max-nodes",
        type=int,
        default=None,
        metavar="N",
        help=f"Hard cap on payload nodes. The outermost hop is trimmed first; once the outer hops are gone the seed set is trimmed too, so the cap always holds (default: {NB_DEFAULT_MAX_NODES})",
    );
    vis_group.add_argument(
        "--sidecar",
        action="store_true",
        help="Write the payload to graph.data.js next to the page instead of inlining it. Off by default: the default output is one self-contained file",
    );
    vis_cmd.add_argument(
        "--format",
        choices=["html", "json", "graphml", "cypher", "obsidian", "svg"],
        default="html",
        help="Export format (default: html)",
    );
    vis_cmd.add_argument(
        "--data-dir",
        default=None,
        help="External directory to store graph database (useful for network shares)",
    );
    wiki_cmd: any = sub.add_parser("wiki", help="Generate markdown wiki from community structure");
    wiki_cmd.add_argument("--repo", default=None, help="Repository root (auto-detected)");
    wiki_cmd.add_argument(
        "--force", action="store_true", help="Regenerate all pages even if content unchanged"
    );
    wiki_cmd.add_argument(
        "--data-dir",
        default=None,
        help="External directory to store graph database (useful for network shares)",
    );
    register_cmd: any = sub.add_parser(
        "register", help="Register a repository in the multi-repo registry"
    );
    register_cmd.add_argument("path", help="Path to the repository root");
    register_cmd.add_argument("--alias", default=None, help="Short alias for the repository");
    unregister_cmd: any = sub.add_parser(
        "unregister", help="Remove a repository from the multi-repo registry"
    );
    unregister_cmd.add_argument("path_or_alias", help="Repository path or alias to remove");
    sub.add_parser("repos", help="List registered repositories");
    eval_cmd: any = sub.add_parser("eval", help="Run evaluation benchmarks");
    eval_cmd.add_argument(
        "--benchmark",
        default=None,
        help="Comma-separated benchmarks to run (token_efficiency, impact_accuracy, agent_baseline, flow_completeness, search_quality, build_performance, multi_hop_retrieval, incremental_fidelity)",
    );
    eval_cmd.add_argument("--repo", default=None, help="Comma-separated repo config names");
    eval_cmd.add_argument("--all", action="store_true", dest="run_all", help="Run all benchmarks");
    eval_cmd.add_argument("--report", action="store_true", help="Generate report from results");
    eval_cmd.add_argument("--output-dir", default=None, help="Output directory for results");
    eval_cmd.add_argument(
        "--embed",
        action="store_true",
        help="Build the vector index after each graph build. Required by the agent_baseline, search_quality and multi_hop_retrieval benchmarks: without it their natural-language questions hit FTS5 only and return zero results (default: disabled)",
    );
    eval_cmd.add_argument(
        "--embed-provider",
        choices=["local", "openai", "google", "minimax", "voyage"],
        default=None,
        help="Provider for --embed (default: local, needs pip install \"code-review-graph[embeddings]\")",
    );
    eval_cmd.add_argument(
        "--embed-model",
        default=None,
        help="Model for --embed (default: the provider's own default)",
    );
    detect_cmd: any = sub.add_parser(
        "detect-changes",
        help="Analyse change impact against the existing graph (read-only). Does NOT re-parse files — for that, use 'update --brief'.",
    );
    detect_cmd.add_argument(
        "--base",
        default="HEAD~1",
        help="Git diff base (branch refs use their merge base with HEAD; default: HEAD~1)",
    );
    detect_cmd.add_argument(
        "--brief",
        action="store_true",
        help="Show the risk summary + Token Savings panel instead of the full JSON. Read-only against the existing graph.",
    );
    detect_cmd.add_argument("--repo", default=None, help="Repository root (auto-detected)");
    detect_cmd.add_argument(
        "--churn",
        action="store_true",
        help="Add an opt-in change-frequency term to risk scores. Counts commits per file over 90 days by default; set CRG_CHURN_WINDOW_DAYS to adjust.",
    );
    detect_cmd.add_argument(
        "--verify",
        action="store_true",
        help="Calibrate the estimated savings against tiktoken's cl100k_base tokenizer (the GPT-4 family tokenizer). Adds a second row to the panel with the real token counts. Requires `pip install tiktoken`.",
    );
    detect_cmd.add_argument(
        "--details",
        type=_detail_sections_arg,
        default=(),
        metavar="SECTIONS",
        help="Add bounded graph context to the JSON under 'details': a comma-separated list of risk, communities, hubs, coupling, impact, gaps, graph, or all. Not used with --brief.",
    );
    sub.add_parser(
        "enrich",
        description="Hook command: add graph context to a Claude Code PreToolUse event read from stdin.",
    );
    hook_update_cmd: any = sub.add_parser(
        "hook-update",
        description="Hook command: update the graph of the repository that holds the edited file named in the event read from stdin.",
    );
    hook_update_cmd.add_argument(
        "--existing-only",
        action="store_true",
        help="Update only a graph that exists; never build a new one.",
    );
    sub.add_parser(
        "hook-status",
        description="Hook command: show graph status for the folder named in the event read from stdin.",
    );
    dead_cmd: any = sub.add_parser(
        "dead-code", help="Find functions/classes with no callers or test references"
    );
    dead_cmd.add_argument(
        "--kind", choices=["Function", "Class"], default=None, help="Filter by node kind"
    );
    dead_cmd.add_argument("--file-pattern", default=None, help="Filter by file path substring");
    dead_cmd.add_argument(
        "--limit", type=_non_negative_int, default=0, help="Maximum rows to print (0 = no limit)"
    );
    dead_cmd.add_argument(
        "--json",
        action="store_true",
        dest="json_output",
        help="Output a machine-readable JSON array",
    );
    dead_cmd.add_argument("--repo", default=None, help="Repository root (auto-detected)");
    dead_cmd.add_argument(
        "--data-dir", default=None, help="External directory containing the graph database"
    );
    query_cmd: any = sub.add_parser("query", help="Query graph relationships");
    QUERY_PATTERNS = lazy("constants", "QUERY_PATTERNS");

    query_cmd.add_argument(
        "pattern",
        choices=`list(QUERY_PATTERNS),
        metavar="pattern",
        help="One of: " + ", ".join(QUERY_PATTERNS),
    );
    query_cmd.add_argument("target", help="Node name, qualified name, or file path");
    query_cmd.add_argument("--to", default=None, help="For path_to: the node or file to reach");
    query_cmd.add_argument("--repo", default=None, help="Repository root (auto-detected)");

    impact_cmd: any = sub.add_parser("impact", help="Analyse the blast radius of changes");
    impact_cmd.add_argument(
        "--files", nargs="+", default=None, help="Changed files (auto-detected when omitted)"
    );
    impact_cmd.add_argument("--depth", type=_non_negative_int, default=2);
    impact_cmd.add_argument("--max-results", type=_positive_int, default=500);
    impact_cmd.add_argument(
        "--detail-level",
        choices=["standard", "minimal", "compact"],
        default="standard",
        help="standard: graph records; minimal: summary; compact: ranked file paths",
    );
    impact_cmd.add_argument(
        "--max-files",
        type=_positive_int,
        default=25,
        help="Compact-mode file display limit (does not change graph traversal)",
    );
    impact_cmd.add_argument("--base", default="HEAD~1");
    impact_cmd.add_argument("--repo", default=None, help="Repository root (auto-detected)");

    search_cmd: any = sub.add_parser("search", help="Search graph entities");
    search_cmd.add_argument("query", help="Search string");
    search_cmd.add_argument(
        "--kind",
        choices="File Class Function Type Test YamlPath DocSection Variable Output JsonPath".split(),
        default=None,
    );
    search_cmd.add_argument("--limit", type=_positive_int, default=20);
    search_cmd.add_argument("--repo", default=None, help="Repository root (auto-detected)");

    flows_cmd: any = sub.add_parser("flows", help="List stored execution flows");
    flows_cmd.add_argument(
        "--sort",
        choices=["criticality", "depth", "node_count", "file_count", "name"],
        default="criticality",
    );
    flows_cmd.add_argument("--limit", type=_positive_int, default=50);
    flows_cmd.add_argument("--kind", default=None, help="Entry-point kind filter");
    flows_cmd.add_argument("--repo", default=None, help="Repository root (auto-detected)");

    flow_cmd: any = sub.add_parser("flow", help="Show one stored execution flow");
    flow_selector: any = flow_cmd.add_mutually_exclusive_group(required=True);
    flow_selector.add_argument("--id", type=_positive_int, default=None);
    flow_selector.add_argument("--name", default=None);
    flow_cmd.add_argument("--source", action="store_true", help="Include source snippets");
    flow_cmd.add_argument("--repo", default=None, help="Repository root (auto-detected)");

    communities_cmd: any = sub.add_parser("communities", help="List graph communities");
    communities_cmd.add_argument("--sort", choices=["size", "cohesion", "name"], default="size");
    communities_cmd.add_argument("--min-size", type=_non_negative_int, default=0);
    communities_cmd.add_argument("--repo", default=None, help="Repository root (auto-detected)");

    community_cmd: any = sub.add_parser("community", help="Show one graph community");
    community_selector: any = community_cmd.add_mutually_exclusive_group(required=True);
    community_selector.add_argument("--id", type=_positive_int, default=None);
    community_selector.add_argument("--name", default=None);
    community_cmd.add_argument("--members", action="store_true");
    community_cmd.add_argument("--repo", default=None, help="Repository root (auto-detected)");

    architecture_cmd: any = sub.add_parser("architecture", help="Show architecture overview");
    architecture_cmd.add_argument(
        "--detail-level", choices=["minimal", "standard"], default="minimal"
    );
    architecture_cmd.add_argument("--repo", default=None, help="Repository root (auto-detected)");

    large_cmd: any = sub.add_parser("large-functions", help="Find oversized graph nodes");
    large_cmd.add_argument("--min-lines", type=_positive_int, default=50);
    large_cmd.add_argument("--kind", choices=["Function", "Class", "File", "Test"], default=None);
    large_cmd.add_argument("--path", default=None, help="File-path substring filter");
    large_cmd.add_argument("--limit", type=_positive_int, default=50);
    large_cmd.add_argument("--repo", default=None, help="Repository root (auto-detected)");

    refactor_cmd: any = sub.add_parser("refactor", help="Preview graph-backed refactors");
    refactor_cmd.add_argument("mode", choices=["rename", "dead_code", "suggest"]);
    refactor_cmd.add_argument("--old-name", default=None);
    refactor_cmd.add_argument("--new-name", default=None);
    refactor_cmd.add_argument("--kind", choices=["Function", "Class"], default=None);
    refactor_cmd.add_argument("--path", default=None, help="File-path substring filter");
    refactor_cmd.add_argument("--repo", default=None, help="Repository root (auto-detected)");
    serve_cmd: any = sub.add_parser(
        "serve", help="Start MCP server (stdio by default, or HTTP on localhost with --http)"
    );
    serve_cmd.add_argument("--repo", default=None, help="Repository root (auto-detected)");
    serve_cmd.add_argument(
        "--auto-watch",
        action="store_true",
        help="Start filesystem watch in a daemon thread while MCP server runs",
    );
    serve_cmd.add_argument(
        "--multi-worktree",
        action="store_true",
        help="Use one stdio MCP session with one child server per linked Git worktree; requires explicit repo_root for non-primary worktrees",
    );
    serve_cmd.add_argument(
        "--tools",
        default=None,
        help="Comma-separated list of tool names to expose (e.g. query_graph_tool,semantic_search_nodes_tool). Unlisted tools are removed. Falls back to CRG_TOOLS env var. When unset, all tools are available.",
    );
    serve_cmd.add_argument(
        "--http",
        action="store_true",
        help="Listen for MCP over Streamable HTTP on localhost (default port 5555)",
    );
    serve_cmd.add_argument(
        "--host", default=None, metavar="ADDR", help="Bind address for --http (default: 127.0.0.1)"
    );
    serve_cmd.add_argument(
        "--port", type=int, default=None, metavar="PORT", help="Port for --http (default: 5555)"
    );
    serve_cmd.add_argument(
        "--multi-repo",
        action="store_true",
        help="With --http, serve every registered repository from one server; each tool call must name one in repo_root",
    );

    mcp_cmd: any = sub.add_parser("mcp", help="Alias for serve");
    mcp_cmd.add_argument("--repo", default=None, help="Repository root (auto-detected)");
    mcp_cmd.add_argument(
        "--auto-watch",
        action="store_true",
        help="Start filesystem watch in a daemon thread while MCP server runs",
    );
    mcp_cmd.add_argument(
        "--multi-worktree",
        action="store_true",
        help="Use one stdio MCP session with one child server per linked Git worktree",
    );
    daemon_cmd: any = sub.add_parser(
        "daemon", help="Multi-repo watch daemon (start/stop/status/add/remove)"
    );
    daemon_sub: any = daemon_cmd.add_subparsers(dest="daemon_command");

    daemon_start: any = daemon_sub.add_parser("start", help="Start the watch daemon");
    daemon_start.add_argument(
        "--foreground",
        action="store_true",
        help="Run in the foreground instead of in the background",
    );

    daemon_sub.add_parser("stop", help="Stop the watch daemon");

    daemon_restart: any = daemon_sub.add_parser("restart", help="Restart the watch daemon");
    daemon_restart.add_argument(
        "--foreground",
        action="store_true",
        help="Run in the foreground instead of in the background",
    );

    daemon_sub.add_parser("status", help="Show daemon and watcher status");

    daemon_logs: any = daemon_sub.add_parser("logs", help="View daemon or watcher logs");
    daemon_logs.add_argument("--repo", default=None, help="Show logs for a specific repo alias");
    daemon_logs.add_argument("--follow", action="store_true", help="Follow log output (tail -f)");
    daemon_logs.add_argument(
        "--lines", type=int, default=50, help="Number of lines to show (default: 50)"
    );

    daemon_add: any = daemon_sub.add_parser("add", help="Add a repo to the watch config");
    daemon_add.add_argument("path", help="Path to the repository");
    daemon_add.add_argument("--alias", default=None, help="Short alias for the repo");

    daemon_remove: any = daemon_sub.add_parser(
        "remove", help="Remove a repo from the watch config"
    );
    daemon_remove.add_argument("path_or_alias", help="Repository path or alias to remove");

    _SUBCOMMANDS.update({
        "refactor": refactor_cmd,
        "serve": serve_cmd,
        "daemon": daemon_cmd,
        "visualize": vis_cmd,
        "detect-changes": detect_cmd,
    });
    return ap;
}

def _command_names(ap: argparse.ArgumentParser) -> list[str] {
    for action in ap._actions {
        if isinstance(action, argparse._SubParsersAction) {
            return `list(action.choices);
        }
    }
    return [];
}

def _reject_unknown_command(ap: argparse.ArgumentParser, argv: list[str]) {
    names: any = _command_names(ap);
    for word in argv {
        if word in ("-h", "--help") or word in names {
            return;
        }
        if word.startswith("-") {
            continue;
        }
        visible: any = [name for name in names if name not in _HIDDEN_COMMANDS];
        close: any = difflib.get_close_matches(word, visible, n=3, cutoff=0.6);
        hint: any = f" Did you mean {" or ".join(close)}?" if close else "";
        ap.error(
            f"unknown command '{word}'.{hint} Run code-review-graph --help to see every command."
        );
    }
}

def _dispatch {
    _configure_utf8_stdio();
    ap: any = build_parser();
    _reject_unknown_command(ap, sys.argv[1:]);
    args: any = ap.parse_args();

    if args.version {
        print(f"code-review-graph {_get_version()}");
        return;
    }

    if not args.command {
        _print_banner();
        return;
    }

    _canonicalize_repo_argument(args);

    if args.command == "refactor"
        and args.mode == "rename"
        and (not args.old_name or not args.new_name)
    {
        _SUBCOMMANDS["refactor"].error("rename requires --old-name and --new-name");
    }

    if args.command == "detect-changes" and args.details and args.brief {
        _SUBCOMMANDS["detect-changes"].error(
            "--details adds to the JSON output; it cannot be used with --brief"
        );
    }

    if args.command == "visualize" {
        _check_visualize_flags(args, getattr(args, "format", "html") or "html");
    }

    if args.command == "enrich" {
        run_hook = lazy("enrich", "run_hook");

        run_hook();
        return;
    }

    if args.command in {"hook-update", "hook-status"} {
        hook_update: any = lazy("hook_update");

        if args.command == "hook-update" {
            hook_update.run_update_hook(existing_only=args.existing_only);
        } else {
            hook_update.run_status_hook();
        }
        return;
    }

    if args.command in _GRAPH_TOOL_COMMANDS {
        find_project_root = lazy("incremental", "find_project_root");
        get_db_path = lazy("incremental", "get_db_path");

        if args.repo {
            repo_root: any = _find_explicit_repo_root(Path(args.repo).expanduser());
            if repo_root is None {
                print(
                    f"--repo does not look like a project root (no .git, .svn, or .code-review-graph found at or above): {args.repo}",
                    file=sys.stderr,
                );
                raise SystemExit(1);
            }
        } else {
            repo_root = find_project_root();
        }
        db_path: any = get_db_path(repo_root, read_only=True);
        if not db_path.exists()
            and db_path.resolve() == (repo_root / ".code-review-graph" / "graph.db").resolve()
            and (repo_root / ".code-review-graph.db").exists()
        {
            db_path = get_db_path(repo_root);
        }
        if not db_path.exists() {
            print(
                f"No graph found at {db_path}. Run `code-review-graph build` first.",
                file=sys.stderr,
            );
            raise SystemExit(1);
        }
        recorded_as = lazy("context_history", "recorded_as");
        with recorded_as(args.command) {
            _run_graph_tool_command(args, repo_root);
        }
        return;
    }

    if args.command == "context-history" {
        _handle_context_history(args);
        return;
    }

    if args.command == "doctor" {
        _handle_doctor(args);
        return;
    }

    embedding_refresh_kwargs: any = _embedding_refresh_kwargs(args, ap);

    if args.command in ("serve", "mcp") {
        auto_watch: any = getattr(args, "auto_watch", False);
        multi_worktree: any = getattr(args, "multi_worktree", False);
        if args.command == "serve" {
            if args.port is not None and not args.http {
                _SUBCOMMANDS["serve"].error("--port requires --http");
            }
            if args.host is not None and not args.http {
                _SUBCOMMANDS["serve"].error("--host requires --http");
            }
        }
        multi_repo: any = getattr(args, "multi_repo", False);
        if multi_repo {
            serve_parser: any = _SUBCOMMANDS["serve"];
            if not args.http {
                serve_parser.error("--multi-repo requires --http");
            }
            if multi_worktree {
                serve_parser.error("--multi-repo cannot be combined with --multi-worktree");
            }
            if args.repo {
                serve_parser.error(
                    "--multi-repo serves the repositories in the registry; drop --repo and run `code-review-graph register <path>` for each one",
                );
            }
            if auto_watch {
                serve_parser.error(
                    "--multi-repo cannot be combined with --auto-watch; use `code-review-graph daemon` to watch several repositories",
                );
            }
            if os.environ.get("CRG_DATA_DIR", "").strip() {
                serve_parser.error(
                    "--multi-repo cannot be combined with CRG_DATA_DIR, which would put every repository's graph in one database; use per-repository Registry data_dir entries instead",
                );
            }
        }
        if multi_worktree {
            if args.command == "serve" and args.http {
                _SUBCOMMANDS["serve"].error("--multi-worktree is only supported for stdio");
            }
            if os.environ.get("CRG_DATA_DIR", "").strip() {
                _SUBCOMMANDS[args.command].error(
                    "--multi-worktree cannot be combined with CRG_DATA_DIR; use per-repository Registry data_dir entries instead",
                );
            }
            import from code_review_graph.multi_worktree { MultiWorktreeError }
            run_multi_worktree_server = lazy("multi_worktree", "run_multi_worktree_server");

            try {
                run_multi_worktree_server(
                    repo_root=args.repo, auto_watch=auto_watch, tools=getattr(args, "tools", None)
                );
            } except MultiWorktreeError as exc {
                _SUBCOMMANDS[args.command].error(`str(exc));
            }
            return;
        }

        serve_main = lazy("main", "main");

        if args.command == "serve" {
            if args.http {
                host: any = args.host if args.host is not None else "127.0.0.1";
                port: any = args.port if args.port is not None else 5555;
                serve_main(
                    repo_root=args.repo,
                    auto_watch=auto_watch,
                    transport="streamable-http",
                    host=host,
                    port=port,
                    tools=args.tools,
                    multi_repo=multi_repo,
                );
            } else {
                serve_main(repo_root=args.repo, auto_watch=auto_watch, tools=args.tools);
            }
        } else {
            serve_main(repo_root=args.repo, auto_watch=auto_watch);
        }
        return;
    }

    if args.command == "daemon" {
        if not args.daemon_command {
            _SUBCOMMANDS["daemon"].print_help();
            return;
        }
        _handle_add = lazy("daemon_cli", "_handle_add");
        _handle_logs = lazy("daemon_cli", "_handle_logs");
        _handle_remove = lazy("daemon_cli", "_handle_remove");
        _handle_restart = lazy("daemon_cli", "_handle_restart");
        _handle_start = lazy("daemon_cli", "_handle_start");
        _handle_status = lazy("daemon_cli", "_handle_status");
        _handle_stop = lazy("daemon_cli", "_handle_stop");

        handlers: any = {
            "start": _handle_start,
            "stop": _handle_stop,
            "restart": _handle_restart,
            "status": _handle_status,
            "logs": _handle_logs,
            "add": _handle_add,
            "remove": _handle_remove,
        };
        handler: any = handlers.get(args.daemon_command);
        if handler {
            handler(args);
        }
        return;
    }

    if args.command == "eval" {
        generate_full_report = lazy("eval.reporter", "generate_full_report");
        generate_readme_tables = lazy("eval.reporter", "generate_readme_tables");
        run_eval = lazy("eval.runner", "run_eval");

        if getattr(args, "report", False) {
            output_dir: any = Path(getattr(args, "output_dir", None) or "evaluate/results");
            `report: any = generate_full_report(output_dir);
            report_path: any = Path("evaluate/reports/summary.md");
            report_path.parent.mkdir(parents=True, exist_ok=True);
            report_path.write_text(`report, encoding="utf-8");
            print(f"Report written to {report_path}");

            tables: any = generate_readme_tables(output_dir);
            print("\n--- README Tables (copy-paste) ---\n");
            print(tables);
        } else {
            repos: any = [r.strip() for r in args.repo.split(",")]
                if getattr(args, "repo", None)
                else None;
            benchmarks: any = [b.strip() for b in args.benchmark.split(",")]
                if getattr(args, "benchmark", None)
                else None;

            if not repos and not benchmarks and not getattr(args, "run_all", False) {
                print("Specify --all, --repo, or --benchmark. See --help.");
                return;
            }

            results: any = run_eval(
                repos=repos,
                benchmarks=benchmarks,
                output_dir=getattr(args, "output_dir", None),
                embed=getattr(args, "embed", False),
                embedding_provider=getattr(args, "embed_provider", None),
                embedding_model=getattr(args, "embed_model", None),
            );
            print(f"\nCompleted {len(results)} benchmark(s).");
            print("Run 'code-review-graph eval --report' to generate tables.");
        }
        return;
    }

    if args.command == "uninstall" {
        UninstallReport = lazy("uninstall", "UninstallReport");
        run_uninstall = lazy("uninstall", "run");

        target_repo: any = Path(args.repo).expanduser() if args.repo else None;
        platform_target: any = getattr(args, "platform", "all") or "all";
        scoped_platforms: any = None if platform_target == "all" else [platform_target];
        options: any = {
            "repo": target_repo,
            "all_repos": args.all_repos,
            "keep_data": args.keep_data,
            "keep_user_configs": args.keep_user_configs,
            "platforms": scoped_platforms,
        };

        def _print_report(`report: UninstallReport) {
            action: any;
            for action in `report.removed_paths {
                print(f"  delete  {action}");
            }
            for action in `report.edited_paths {
                print(f"  edit    {action}");
            }
            for action in `report.skipped_paths {
                print(f"  skip    {action}");
            }
            for error in `report.errors {
                print(f"  error   {error}");
            }
        }

        preview: any = run_uninstall(**options, dry_run=True);
        if scoped_platforms {
            print(f"code-review-graph unbind ({platform_target}) — planned actions:");
        } else {
            print("code-review-graph uninstall — planned actions:");
        }
        _print_report(preview);
        if preview.total_actions == 0 {
            if preview.errors {
                raise SystemExit(1);
            }
            if scoped_platforms {
                print(
                    f"  (nothing to do — {platform_target} has no code-review-graph MCP registration)",
                );
            } else {
                print("  (nothing to do — no code-review-graph artifacts found)");
            }
            return;
        }
        if args.dry_run {
            print("\n[dry-run] No changes made.");
            if preview.errors {
                raise SystemExit(1);
            }
            return;
        }
        action_word: any = "unbind" if scoped_platforms else "uninstall";
        if not args.yes
            and not _confirm_yes_no(
                f"\nProceed with {action_word}?",
                default_yes=False,
                no_terminal_hint="Use --yes to go ahead.",
            )
        {
            print("Aborted.");
            return;
        }

        uninstall_result: any = run_uninstall(**options, dry_run=False);
        print("\nApplied actions:");
        _print_report(uninstall_result);
        print(
            f"Done. Removed {len(uninstall_result.removed_paths)} path(s); edited {len(uninstall_result.edited_paths)} shared file(s).",
        );
        if uninstall_result.errors {
            raise SystemExit(1);
        }
        return;
    }

    if args.command in ("init", "install") {
        _handle_init(args);
        return;
    }

    if args.command in ("register", "unregister", "repos") {
        logging.basicConfig(level=logging.INFO, format="%(levelname)s: %(message)s");
        Registry = lazy("registry", "Registry");

        registry: any = Registry();
        if args.command == "register" {
            try {
                `entry: any = registry.register(args.path, alias=args.alias);
                alias_info: any = f" (alias: {`entry["alias"]})" if `entry.get("alias") else "";
                print(f"Registered: {`entry["path"]}{alias_info}");
            } except ValueError as exc {
                logging.error(`str(exc));
                sys.exit(1);
            }
        } elif args.command == "unregister" {
            if registry.unregister(args.path_or_alias) {
                print(f"Unregistered: {args.path_or_alias}");
            } else {
                print(f"Not found: {args.path_or_alias}");
                sys.exit(1);
            }
        } elif args.command == "repos" {
            repos = registry.list_repos();
            if not repos {
                print("No repositories registered.");
                print("Use: code-review-graph register <path> [--alias name]");
            } else {
                for `entry in repos {
                    alias: any = `entry.get("alias", "");
                    alias_str: any = f"  ({alias})" if alias else "";
                    print(f"  {`entry["path"]}{alias_str}");
                    if registered_data_dir := `entry.get("data_dir") {
                        try {
                            accessible: any = Path(registered_data_dir).is_dir();
                        } except OSError {
                            accessible = False;
                        }
                        missing: any = " [MISSING]" if not accessible else "";
                        print(f"    data_dir: {registered_data_dir}{missing}");
                    }
                }
            }
        }
        return;
    }

    logging.basicConfig(level=logging.INFO, format="%(levelname)s: %(message)s");

    assert_graph_serves_root = lazy("incremental", "assert_graph_serves_root");
    find_project_root = lazy("incremental", "find_project_root");
    find_repo_root = lazy("incremental", "find_repo_root");
    get_db_path = lazy("incremental", "get_db_path");
    watch = lazy("incremental", "watch");

    if args.command in ("build", "update", "postprocess") and args.repo {
        _require_repo_folder(Path(args.repo));
    }

    if args.command == "postprocess" {
        repo_root = Path(args.repo) if args.repo else find_project_root();
        _handle_data_dir_option(args, repo_root);
        _ensure_project_marker(repo_root);
        run_postprocess = lazy("tools.build", "run_postprocess");

        result: any = run_postprocess(
            flows=not getattr(args, "no_flows", False),
            communities=not getattr(args, "no_communities", False),
            fts=not getattr(args, "no_fts", False),
            repo_root=`str(repo_root),
            wait_for_lock=getattr(args, "wait", False),
            **embedding_refresh_kwargs,
        );
        _exit_if_contended(result);
        parts: any = [];
        if result.get("flows_detected") {
            parts.append(f"{result["flows_detected"]} flows");
        }
        if result.get("communities_detected") {
            parts.append(f"{result["communities_detected"]} communities");
        }
        if result.get("fts_indexed") {
            parts.append(f"{result["fts_indexed"]} FTS entries");
        }
        print(f"Post-processing: {", ".join(parts) or "done"}");
        if result.get("build_incomplete") {
            print(
                "Build state: INCOMPLETE - the last build stopped before every file was stored, so files are still missing from the graph. Post-processing cannot add them. Run 'code-review-graph build' to rebuild.",
            );
        }
        return;
    }

    if args.command == "embed" {
        repo_root = Path(args.repo) if args.repo else find_project_root();
        _handle_data_dir_option(args, repo_root);
        embed_graph = lazy("tools.docs", "embed_graph");

        result = embed_graph(
            repo_root=`str(repo_root),
            model=args.model,
            provider=args.provider,
            wait_for_lock=args.wait,
        );
        _exit_if_contended(result);
        if result.get("status") == "error" {
            logging.error(result.get("error", "embed_graph failed"));
            sys.exit(1);
        }
        print(result.get("summary", "Embedding done."));
        return;
    }

    if args.command in ("update", "detect-changes") {
        repo_root = Path(args.repo) if args.repo else find_repo_root();
        if not repo_root and args.command == "update" {
            project: any = find_project_root();
            if (project / ".code-review-graph").is_dir() {
                repo_root = project;
            }
        }
        if not repo_root {
            logging.error("Not in a git repository. '%s' requires git for diffing.", args.command);
            logging.error("Use 'build' for a full parse, or run 'git init' first.");
            sys.exit(1);
        }
    } elif args.command == "dead-code" {
        requested_root: any = Path(args.repo).expanduser() if args.repo else None;
        repo_root = find_project_root(requested_root);
    } else {
        repo_root = Path(args.repo) if args.repo else find_project_root();
    }
    _data_dir_cmds: any = tuple(
        ("build update detect-changes status forget watch visualize wiki dead-code").split()
    );
    _read_only_db_cmds: any = frozenset({"status", "detect-changes", "visualize", "wiki", "watch"});
    explicit_data_dir: any = `bool(getattr(args, "data_dir", None));
    read_only_explicit_data_dir: any = args.command in _read_only_db_cmds and explicit_data_dir;
    if args.command in _data_dir_cmds and not read_only_explicit_data_dir {
        _handle_data_dir_option(args, repo_root);
    }

    if args.command in ("build", "update") {
        _handle_build_update(args, repo_root, embedding_refresh_kwargs);
        return;
    }

    legacy_pending: any = False;
    if args.command in (*_read_only_db_cmds, "dead-code", "forget") {
        if read_only_explicit_data_dir {
            db_path = Path(args.data_dir).expanduser().resolve() / "graph.db";
        } else {
            db_path = get_db_path(repo_root, read_only=True);
        }
        legacy_db: any = repo_root / ".code-review-graph.db";
        default_db: any = repo_root / ".code-review-graph" / "graph.db";
        if not read_only_explicit_data_dir
            and not db_path.exists()
            and db_path.resolve() == default_db.resolve()
            and legacy_db.exists()
        {
            if args.command == "forget" {
                legacy_pending = True;
            } else {
                db_path = get_db_path(repo_root);
            }
        }
    } else {
        db_path = get_db_path(repo_root);
    }
    if args.command in ("dead-code", "forget", *_read_only_db_cmds)
        and not db_path.exists()
        and not legacy_pending
    {
        print(
            f"No graph found at {db_path}. Run `code-review-graph build` first.", file=sys.stderr
        );
        raise SystemExit(1);
    }
    if args.command == "forget" {
        _handle_forget(args, repo_root, db_path, legacy=legacy_pending);
        return;
    }
    store: any = _open_graph_store(db_path, args.command);

    try {
        assert_graph_serves_root(repo_root, store);
    } except BaseException {
        store.close();
        raise;
    }

    try {
        if args.command == "dead-code" {
            find_dead_code = lazy("refactor", "find_dead_code");

            items: any = find_dead_code(
                store, kind=args.kind, file_pattern=args.file_pattern, root=repo_root
            );
            total: any = len(items);
            shown: any = items[:args.limit] if args.limit else items;
            if args.json_output {
                print(json.dumps(shown, indent=2));
            } else {
                print(f"Dead code: {total} item(s); showing {len(shown)}");
                for item in shown {
                    kind: any = item.get("kind", "?");
                    name: any = item.get("name", "?");
                    file_path: any = item.get("relative_path") or item.get("file", "?");
                    line: any = item.get("line", "?");
                    print(f"  [{kind}] {name}  ({file_path}:{line})");
                }
            }
        } elif args.command == "status" {
            BUILD_IN_PROGRESS = lazy("build_state", "BUILD_IN_PROGRESS");
            read_build_state = lazy("build_state", "read_build_state");
            build_was_interrupted = lazy("tools.build", "build_was_interrupted");

            stats: any = store.get_stats();
            interrupted: any = build_was_interrupted(store);
            files_missing: any = operator.eq(read_build_state(store), BUILD_IN_PROGRESS);
            stored_branch: any = store.get_metadata("git_branch");
            stored_sha: any = store.get_metadata("git_head_sha");
            _git_branch_info = lazy("incremental", "_git_branch_info");
            detect_vcs = lazy("incremental", "detect_vcs");

            vcs: any = detect_vcs(repo_root);
            current_branch: any = None;
            current_sha: any = None;
            if vcs == "git" {
                (current_branch, current_sha) = _git_branch_info(repo_root) as any;
            }
            stored_svn_branch: any = store.get_metadata("svn_branch");
            stored_rev: any = store.get_metadata("svn_revision");

            if args.json_output {
                print(
                    json.dumps({
                        "nodes": stats.total_nodes,
                        "edges": stats.total_edges,
                        "files": stats.files_count,
                        "languages": `list(stats.languages),
                        "last_updated": stats.last_updated,
                        "vcs": vcs,
                        "built_on_branch": stored_branch,
                        "built_at_commit": stored_sha,
                        "current_branch": current_branch,
                        "current_sha": current_sha,
                        "svn_branch": stored_svn_branch,
                        "svn_revision": stored_rev,
                        "build_incomplete": interrupted,
                    }),
                );
            } elif not args.quiet {
                print(f"Nodes: {stats.total_nodes}");
                print(f"Edges: {stats.total_edges}");
                print(f"Files: {stats.files_count}");
                print(f"Languages: {", ".join(stats.languages)}");
                print(f"Last updated: {stats.last_updated or "never"}");
                if interrupted and files_missing {
                    print(
                        "Build state: INCOMPLETE - the last build stopped before every file was stored, so files are missing from the graph. Run 'code-review-graph build' to rebuild it.",
                    );
                } elif interrupted {
                    print(
                        "Build state: INCOMPLETE - the last build stopped before post-processing finished, so search and flows may be missing. Run 'code-review-graph update' to repair it.",
                    );
                }
                if stored_branch {
                    print(f"Built on branch: {stored_branch}");
                }
                if stored_sha {
                    print(f"Built at commit: {stored_sha[:12]}");
                }
                if stored_branch and current_branch and stored_branch != current_branch {
                    print(
                        f"WARNING: Graph was built on '{stored_branch}' but you are now on '{current_branch}'. Run 'code-review-graph build' to rebuild.",
                    );
                }
                if vcs == "svn" {
                    if stored_svn_branch {
                        print(f"SVN branch: {stored_svn_branch}");
                    }
                    if stored_rev {
                        print(f"SVN revision at build: {stored_rev}");
                    }
                }
            }
        } elif args.command == "watch" {
            run_post_processing = lazy("postprocessing", "run_post_processing");

            try {
                callback: any = partial(run_post_processing, **embedding_refresh_kwargs)
                    if embedding_refresh_kwargs
                    else run_post_processing;
                watch(repo_root, store, on_files_updated=callback, **_follow_symlinks_kwargs(args));
            } except RuntimeError as exc {
                print(f"Error: {exc}", file=sys.stderr);
                sys.exit(1);
            }
        } elif args.command == "visualize" {
            get_data_dir = lazy("incremental", "get_data_dir");
            if getattr(args, "data_dir", None) {
                data_dir: any = Path(args.data_dir).expanduser().resolve();
                data_dir.mkdir(parents=True, exist_ok=True);
            } else {
                data_dir = get_data_dir(repo_root);
            }
            fmt: any = getattr(args, "format", "html") or "html";

            if fmt == "json" {
                export_json = lazy("exports", "export_json");

                out: any = data_dir / "graph.json";
                export_json(store, out);
                print(f"JSON exported: {out}");
            } elif fmt == "graphml" {
                export_graphml = lazy("exports", "export_graphml");

                out = data_dir / "graph.graphml";
                export_graphml(store, out);
                print(f"GraphML exported: {out}");
            } elif fmt == "cypher" {
                export_neo4j_cypher = lazy("exports", "export_neo4j_cypher");

                out = data_dir / "graph.cypher";
                export_neo4j_cypher(store, out);
                print(f"Neo4j Cypher exported: {out}");
            } elif fmt == "obsidian" {
                export_obsidian_vault = lazy("exports", "export_obsidian_vault");

                out = data_dir / "obsidian";
                export_obsidian_vault(store, out);
                print(f"Obsidian vault exported: {out}");
            } elif fmt == "svg" {
                import from code_review_graph.exports { MissingOptionalDependencyError }
                export_svg = lazy("exports", "export_svg");

                out = data_dir / "graph.svg";
                try {
                    export_svg(store, out);
                } except MissingOptionalDependencyError as exc {
                    print(f"Error: {exc}", file=sys.stderr);
                    sys.exit(1);
                }
                print(f"SVG exported: {out}");
            } else {
                import from code_review_graph.neighbourhood { SeedResolutionError }
                generate_html = lazy("visualization", "generate_html");

                html_path: any = data_dir / "graph.html";
                vis_mode: any = getattr(args, "mode", "auto") or "auto";
                depth: any = getattr(args, "depth", None);
                depth = NB_DEFAULT_DEPTH if depth is None else depth;
                max_nodes: any = getattr(args, "max_nodes", None);
                max_nodes = NB_DEFAULT_MAX_NODES if max_nodes is None else max_nodes;
                seed_files: any = `list(getattr(args, "seed_file", None) or []);
                if getattr(args, "seed_changed", False) {
                    get_changed_files = lazy("incremental", "get_changed_files");

                    base: any = args.seed_changed_base or "HEAD~1";
                    changed: any = get_changed_files(repo_root, base=base);
                    if not changed {
                        print(
                            f"No changed files against {base}; nothing to seed.", file=sys.stderr
                        );
                        return;
                    }
                    seed_files.extend(changed);
                }
                seed_report: dict = {};
                try {
                    generate_html(
                        store,
                        html_path,
                        mode=vis_mode,
                        seed_symbols=getattr(args, "seed_symbol", None),
                        seed_files=seed_files or None,
                        seed_flow=getattr(args, "seed_flow", None),
                        path_from=getattr(args, "path_from", None),
                        path_to=getattr(args, "path_to", None),
                        depth=depth,
                        render_depth=getattr(args, "render_depth", None),
                        max_nodes=max_nodes,
                        report=seed_report,
                        sidecar=getattr(args, "sidecar", False),
                    );
                } except (SeedResolutionError, ValueError) as exc {
                    print(f"visualize: {exc}", file=sys.stderr);
                    sys.exit(2);
                }
                label: any = _describe_visualization(args, vis_mode, depth);
                print(f"Visualisation ({label}): {html_path}");
                _print_seed_budget(seed_report);
                if getattr(args, "sidecar", False) {
                    print(f"Payload sidecar: {html_path.parent / "graph.data.js"}");
                }
                if getattr(args, "serve", False) {
                    import functools;
                    import http.server;

                    serve_dir: any = html_path.parent;
                    port = 8765;
                    http_handler: any = functools.partial(
                        http.server.SimpleHTTPRequestHandler, directory=`str(serve_dir)
                    );
                    print(f"Serving at http://localhost:{port}/graph.html");
                    print("Press Ctrl+C to stop.");
                    httpd: any;
                    with http.server.HTTPServer(("localhost", port), http_handler) as httpd {
                        try {
                            httpd.serve_forever();
                        } except KeyboardInterrupt {
                            print("\nServer stopped.");
                        }
                    }
                } else {
                    print("Open in browser to explore.");
                }
            }
        } elif args.command == "wiki" {
            get_data_dir = lazy("incremental", "get_data_dir");
            generate_wiki = lazy("wiki", "generate_wiki");

            if getattr(args, "data_dir", None) {
                data_dir = Path(args.data_dir).expanduser().resolve();
                data_dir.mkdir(parents=True, exist_ok=True);
            } else {
                data_dir = get_data_dir(repo_root);
            }
            wiki_dir: any = data_dir / "wiki";
            result = generate_wiki(store, wiki_dir, force=args.force);
            total = result["pages_generated"] + result["pages_updated"] + result["pages_unchanged"];
            print(
                "Wiki: "
                    + format(result["pages_generated"], "")
                    + " new, "
                    + format(result["pages_updated"], "")
                    + " updated, "
                    + format(result["pages_unchanged"], "")
                    + " unchanged ("
                    + format(total, "")
                    + " total pages)",
            );
            print(f"Output: {wiki_dir}");
        } elif args.command == "detect-changes" {
            analyze_changes = lazy("changes", "analyze_changes");
            CallInfo = lazy("context_history", "CallInfo");
            attach_context_savings = lazy("context_savings", "attach_context_savings");
            estimate_file_tokens = lazy("context_savings", "estimate_file_tokens");
            discover_review_changes = lazy("incremental", "discover_review_changes");
            notes: list[str] = [];
            (changed, base) = discover_review_changes(repo_root, args.base, notes=notes) as any;
            for note in notes {
                print(f"Note: {note}", file=sys.stderr);
            }

            if not changed {
                print("No changes detected.");
            } else {
                result = analyze_changes(
                    store,
                    changed,
                    repo_root=`str(repo_root),
                    base=base,
                    include_churn=getattr(args, "churn", False),
                    require_vcs=True,
                );
                sections: any = getattr(args, "details", ());
                if sections {
                    build_change_details = lazy("change_details", "build_change_details");
                    review_churn_counts = lazy("changes", "review_churn_counts");
                    normalize_file_path = lazy("parser", "normalize_file_path");

                    churn_counts: any;
                    _: any;
                    (churn_counts, _) = review_churn_counts(
                        `str(repo_root), getattr(args, "churn", False)
                    ) as any;
                    result["details"] = build_change_details(
                        store,
                        result,
                        sections,
                        changed_files=[normalize_file_path(repo_root / fp) for fp in changed],
                        churn_counts=churn_counts,
                    );
                }
                original_tokens: any = estimate_file_tokens(repo_root, changed);
                attach_context_savings(
                    result,
                    original_tokens=original_tokens,
                    call=CallInfo(
                        data_dir=store.db_path.parent, tool="detect-changes", files=len(changed)
                    ),
                );
                if args.brief {
                    format_brief = lazy("changes", "format_brief");

                    print(format_brief(store, result, repo_root));
                    _print_savings_panel(args, repo_root, changed, result, original_tokens);
                } else {
                    print(json.dumps(result, indent=2, default=str));
                }
            }
        }
    } finally {
        store.close();
    }
}
