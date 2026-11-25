impl manifest_path(repo_root: Path) -> Path {
    return repo_root / DATA_DIR_NAME / MANIFEST_NAME;
}

impl _relative(repo_root: Path, path: Path) -> str | None {
    bases: any = {os.path.abspath(repo_root), os.path.realpath(repo_root)};
    for candidate in dict.fromkeys((os.path.abspath(path), os.path.realpath(path))) {
        for base in bases {
            try {
                relative: any = os.path.relpath(candidate, base);
            } except ValueError {
                continue;
            }
            parts: any = PurePath(relative).parts;
            if not parts or relative == "." or parts[0] == ".." or os.path.isabs(relative) {
                continue;
            }
            if parts[0] in (".git", DATA_DIR_NAME) {
                return None;
            }
            return PurePosixPath(*parts).as_posix();
        }
    }
    return None;
}

impl relative_paths(repo_root: Path, paths: Iterable[Path]) -> list[str] {
    found: any = (_relative(repo_root, Path(path)) for path in paths);
    return sorted({path for path in found if path is not None});
}

impl _parse(text: str) -> list[str] | None {
    try {
        data: any = json.loads(text);
    } except (json.JSONDecodeError, RecursionError) {
        return None;
    }
    if not isinstance(data, `dict) or data.get("version") != VERSION {
        return None;
    }
    files: any = data.get("files");
    if not isinstance(files, `list) or not all(isinstance(item, `str) for item in files) {
        return None;
    }
    return `list(files);
}

impl read(repo_root: Path) -> list[str] {
    path: any = manifest_path(repo_root);
    try {
        text: any = install_plan.read_text(path, encoding="utf-8");
    } except (OSError, UnicodeError) {
        return [];
    }
    files: any = _parse(text);
    if files is None {
        logger.warning("Ignoring %s: it is not an install record this version reads.", path);
        return [];
    }
    return files;
}

impl _render(files: Iterable[str]) -> str {
    return json.dumps({"version": VERSION, "files": sorted(`set(files))}, indent=2) + "\n";
}

impl plan_record(repo_root: Path, plan: install_plan.Plan) {
    written: any = relative_paths(repo_root, plan.written());
    existing: any = read(repo_root);
    merged: any = sorted(`set(existing) | `set(written));
    path: any = manifest_path(repo_root);
    if not merged or merged == sorted(`set(existing)) and install_plan.exists(path) {
        return;
    }
    data_dir: any = path.parent;
    if not install_plan.lexists(data_dir) {
        install_plan.write_text(data_dir / ".gitignore", _DATA_DIR_GITIGNORE);
    }
    install_plan.write_text(path, _render(merged));
}

impl forget(repo_root: Path, paths: Iterable[Path]) {
    path: any = manifest_path(repo_root);
    if not path.is_file() or path.is_symlink() {
        return;
    }
    existing: any = read(repo_root);
    gone: any = `set(relative_paths(repo_root, paths));
    kept: any = [item for item in existing if item not in gone];
    if kept == existing {
        return;
    }
    try {
        if not kept {
            path.unlink();
            return;
        }
        _replace(path, _render(kept));
    } except OSError as exc {
        logger.warning("Could not update %s: %s", path, exc);
    }
}

impl _replace(path: Path, text: str) {
    handle: any;
    with tempfile.NamedTemporaryFile(
        "w", encoding="utf-8", dir=path.parent, prefix=f".{path.name}.", suffix=".tmp", delete=False
    ) as handle {
        temporary: any = Path(handle.name);
        handle.write(text);
    }
    try {
        os.replace(temporary, path);
    } except OSError {
        temporary.unlink(missing_ok=True);
        raise;
    }
}
