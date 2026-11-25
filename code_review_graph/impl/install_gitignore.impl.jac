impl _relative(repo_root: Path, path: Path) -> str | None {
    try {
        relative: any = os.path.normpath(os.path.relpath(path, repo_root));
    } except ValueError {
        return None;
    }
    parts: any = PurePath(relative).parts;
    if not parts or relative == "." or parts[0] in ("..", ".git") or os.path.isabs(relative) {
        return None;
    }
    return PurePosixPath(*parts).as_posix();
}

impl repo_files(
    repo_root: Path,
    target: str,
    *,
    with_skills: bool,
    with_hooks: bool,
    with_instructions: bool,
    platforms: Iterable[str] | None = None,
) -> list[str] {
    folder: any;
    chosen: any = frozenset(
        skills.selected_platforms(repo_root, target) if platforms is None else platforms
    );
    files: list[Path] = [
        spec["config_path"](repo_root)
        for (key, spec) in skills.PLATFORMS.items()
        if key in chosen
    ];
    config_files: any = `set(files);
    codex: any = "codex" in chosen;
    codex_home: any = codex_skill.codex_home();

    if with_skills {
        slugs: any = [name.rsplit(".", 1)[0] for name in skills._SKILLS];
        owner: any;
        for item_ in (
            (".claude", "claude"),
            (".gemini", "gemini-cli"),
            (".codebuddy", "codebuddy"),
        ) {
            (folder, owner) = item_;
            if owner in chosen {
                files.extend(repo_root / folder / "skills" / slug / "SKILL.md" for slug in slugs);
            }
        }
        if "qoder" in chosen {
            files.extend(
                repo_root / ".qoder" / "skills" / name / "SKILL.md"
                for name in skills.bundled_skill_names(),
            );
        }
        if codex {
            try {
                bundled: any = codex_skill._iter_resource_files(codex_skill.bundled_skill_dir());
            } except OSError {
                bundled = {};
            }
            skill_dir: any = codex_skill.codex_skill_dir();
            files.extend(skill_dir / name for name in (*bundled, codex_skill.MANIFEST_NAME));
        }
    }

    if with_hooks {
        settings_folders: any = [
            folder
            for (folder, owner) in (
                (".claude", "claude"),
                (".qoder", "qoder"),
                (".codebuddy", "codebuddy"),
                (".gemini", "gemini-cli"),
            )
            if owner in chosen
        ];
        for folder_ in settings_folders {
            folder = folder_;
            settings: any = repo_root / folder / "settings.json";
            files.append(settings);
            if settings.exists() or settings in config_files {
                files.append(repo_root / folder / "settings.json.bak");
            }
        }
        if codex {
            codex_hooks: any = codex_home / "hooks.json";
            files.append(codex_hooks);
            if codex_hooks.exists() {
                files.append(codex_home / "hooks.json.bak");
            }
        }
        if "gemini-cli" in chosen {
            files.extend(
                repo_root / ".gemini" / "hooks" / name for name in skills._GEMINI_CLI_HOOK_FILENAMES
            );
        }
        if target in ("all", "claude", "qoder", "codex") {
            hooks_dir: any = skills._git_hooks_dir(repo_root);
            if hooks_dir is not None {
                files.extend(
                    hooks_dir / name for name in ("pre-commit", *skills._GIT_SYNC_HOOK_NAMES)
                );
            }
        }
    }

    if with_instructions {
        if skills.instruction_file_wanted(("claude",), target, chosen) {
            files.append(repo_root / "CLAUDE.md");
        }
        for (filename, owners) in skills._PLATFORM_INSTRUCTION_FILES.items() {
            if skills.instruction_file_wanted(owners, target, chosen) {
                files.append(repo_root / filename);
            }
        }
    }

    relative: any = (_relative(repo_root, path) for path in files);
    return sorted({path for path in relative if path is not None});
}

impl _with_folders(files: Iterable[str]) -> dict[str, bool] {
    paths: dict[str, bool] = {};
    for file in files {
        paths.setdefault(file, False);
        for parent in PurePosixPath(file).parents {
            if parent.as_posix() == "." {
                break;
            }
            paths[parent.as_posix()] = True;
        }
    }
    return paths;
}

impl plan(
    repo_root: Path,
    target: str,
    *,
    with_skills: bool,
    with_hooks: bool,
    with_instructions: bool,
    platforms: Iterable[str] | None = None,
) -> Plan {
    files: any = repo_files(
        repo_root,
        target,
        with_skills=with_skills,
        with_hooks=with_hooks,
        with_instructions=with_instructions,
        platforms=platforms,
    );
    existed: any = frozenset(
        path for path in _with_folders(files) if os.path.lexists(repo_root / path)
    );
    return Plan(files=`tuple(files), existed=existed);
}

impl _git(repo_root: Path, args: list[str], stdin: str | None = None) -> str | None {
    try {
        result: any = subprocess.run(
            ["git", *args],
            cwd=`str(repo_root),
            input=stdin or "",
            capture_output=True,
            text=True,
            encoding="utf-8",
            timeout=30,
        );
    } except (OSError, subprocess.TimeoutExpired) as exc {
        logger.warning("git %s failed in %s: %s", args[0], repo_root, exc);
        return None;
    }
    if result.returncode not in (0, 1) {
        return None;
    }
    return result.stdout;
}

impl _in_git_work_tree(repo_root: Path) -> bool {
    out: any = _git(repo_root, ["rev-parse", "--is-inside-work-tree"]);
    return out is not None and operator.eq(out.strip(), "true");
}

impl _GitError.__repr__ -> str {
    return (getattr(builtins.super(_GitError, self), "__repr__") as any)();
}

impl _GitError.__eq__(other: any) -> bool {
    return self is other;
}

impl _GitError.__hash__ -> int {
    return id(self);
}

impl _tracked(repo_root: Path, paths: Iterable[str]) -> set[str] {
    names: any = [path.rstrip("/") for path in paths];
    if not names {
        return set[any]();
    }
    out: any = _git(repo_root, ["--literal-pathspecs", "ls-files", "-z", "--", *names]);
    if out is None {
        raise _GitError("git ls-files failed");
    }
    return {name for name in out.split("\x00") if name};
}

impl _holds_tracked(path: str, tracked: set[str]) -> bool {
    stem: any = path.rstrip("/");
    return `any(operator.eq(name, stem) or name.startswith(stem + "/") for name in tracked);
}

impl _ignored(repo_root: Path, entries: list[str]) -> set[str] {
    if not entries {
        return set[any]();
    }
    out: any = _git(
        repo_root, ["check-ignore", "-z", "--stdin"], stdin="\x00".join(entries) + "\x00"
    );
    return {name for name in (out or "").split("\x00") if name};
}

impl _created_entries(repo_root: Path, install_plan: Plan, dry_run: bool) -> list[str] {
    entries: list[str];
    paths: any = _with_folders(install_plan.files);
    created: any = {
        path
        for path in paths
        if path not in install_plan.existed and (dry_run or planned_files.lexists(repo_root / path))
    };
    tops: any = sorted(
        path for path in created if PurePosixPath(path).parent.as_posix() not in created
    );
    tracked: any = _tracked(repo_root, tops);

    entries = [];

    def `visit(path: str) {
        if not paths[path] {
            if path not in tracked {
                entries.append(path);
            }
            return;
        }
        if not _holds_tracked(path, tracked) {
            entries.append(path + "/");
            return;
        }
        for child in sorted(c for c in created if PurePosixPath(c).parent.as_posix() == path) {
            `visit(child);
        }
    }

    for top in tops {
        `visit(top);
    }
    entries = [`entry for `entry in entries if _ENTRY.fullmatch(f"/{`entry}")];
    ignored: any = _ignored(repo_root, entries);
    return [`entry for `entry in entries if `entry not in ignored];
}

impl _find_block(lines: list[str]) -> tuple[int, int] | str | None {
    line: any;
    bare: any = [line.rstrip("\r\n") for line in lines];
    starts: any = [index for (index, line) in enumerate(bare) if line == BLOCK_START];
    ends: any = [index for (index, line) in enumerate(bare) if line == BLOCK_END];
    if not starts and not ends {
        return None;
    }
    if len(starts) != 1 or len(ends) != 1 or ends[0] < starts[0] {
        return "edited";
    }
    start: any;
    end: any;
    (start, end) = (starts[0], ends[0]);
    for line in bare[start + 1:end] {
        if line != BLOCK_NOTE and not _ENTRY.fullmatch(line) {
            return "edited";
        }
    }
    return (start, end);
}

impl _block_entries(lines: list[str], start: int, end: int) -> list[str] {
    return [
        line.rstrip("\r\n")[1:]
        for line in lines[start + 1:end]
        if line.rstrip("\r\n") != BLOCK_NOTE
    ];
}

impl _render(entries: list[str], newline: str) -> str {
    body: any = [BLOCK_START, BLOCK_NOTE, *(f"/{`entry}" for `entry in entries), BLOCK_END];
    return newline.join(body) + newline;
}

impl _replace_block(
    lines: list[str], start: int, end: int, entries: list[str], newline: str
) -> str {
    before: any = "".join(lines[:start]);
    owns_newline: any = operator.gt(start, 0)
        and operator.eq(end, len(lines) - 1)
        and not lines[end].endswith("\n");
    if not owns_newline {
        block: any = _render(entries, newline) if entries else "";
        return before + block + "".join(lines[end + 1:]);
    }
    if entries {
        return before + _render(entries, newline).removesuffix(newline);
    }
    previous: any = lines[start - 1];
    return before[:-2 if previous.endswith("\r\n") else -1];
}

impl remove_block(text: str) -> tuple[str, str] {
    lines: any = text.splitlines(keepends=True);
    found: any = _find_block(lines);
    if found is None {
        return (text, "absent");
    }
    if isinstance(found, `str) {
        return (text, found);
    }
    start: any;
    end: any;
    (start, end) = found as any;
    return (_replace_block(lines, start, end, [], "\n"), "removed");
}

impl apply(repo_root: Path, install_plan: Plan, *, dry_run: bool) -> Result {
    if not _in_git_work_tree(repo_root) {
        return Result("not-git");
    }
    gitignore: any = repo_root / ".gitignore";
    if gitignore.is_symlink() {
        return Result("error", detail=f"{gitignore} is a symlink; left alone");
    }
    try {
        text: any = planned_files.read_bytes(gitignore).decode("utf-8")
            if planned_files.exists(gitignore)
            else "";
    } except (OSError, UnicodeError) as exc {
        logger.warning("Could not read %s: %s", gitignore, exc);
        return Result("error", detail=`str(exc));
    }

    lines: any = text.splitlines(keepends=True);
    found: any = _find_block(lines);
    if isinstance(found, `str) {
        return Result("edited");
    }

    old: list[str] = [];
    try {
        if found is not None {
            old = _block_entries(lines, *found);
            planned: any = _with_folders(install_plan.files) if dry_run else {};
            tracked: any = _tracked(repo_root, old);
            old = [
                `entry
                for `entry in old
                if (
                    planned_files.lexists(repo_root / `entry.rstrip("/"))
                    or `entry.rstrip("/") in planned
                )
                    and not _holds_tracked(`entry, tracked)
            ];
        }
        created: any = _created_entries(repo_root, install_plan, dry_run);
    } except _GitError as exc {
        return Result("error", detail=`str(exc));
    }
    entries: any = sorted(`set(old) | `set(created));
    added: any = [`entry for `entry in entries if `entry not in old];

    newline: any = "\r\n" if lines and lines[0].endswith("\r\n") else "\n";
    if found is not None {
        new_text: any = _replace_block(lines, *found, entries, newline);
    } elif entries and text and not text.endswith("\n") {
        new_text = text + newline + _render(entries, newline).removesuffix(newline);
    } elif entries {
        new_text = text + _render(entries, newline);
    } else {
        new_text = text;
    }

    if new_text == text {
        return Result("unchanged", entries=entries);
    }
    if not dry_run {
        try {
            planned_files.write_bytes(gitignore, new_text.encode("utf-8"));
        } except OSError as exc {
            logger.warning("Could not write %s: %s", gitignore, exc);
            return Result("error", detail=`str(exc));
        }
    }
    return Result("written", added=added, entries=entries);
}
