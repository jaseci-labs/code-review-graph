impl codex_home -> Path {
    configured: any = os.environ.get("CODEX_HOME", "").strip();
    if configured {
        return Path(configured).expanduser().resolve();
    }
    return (Path.home() / ".codex").resolve();
}

impl codex_skill_dir -> Path {
    return codex_home() / "skills" / CODEX_SKILL_NAME;
}

impl bundled_skill_dir -> Path {
    return _RESOURCE_ROOT;
}

impl _iter_resource_files(`root: Path) -> dict[str, Path] {
    if not `root.is_dir() {
        raise FileNotFoundError(f"bundled Codex skill is missing: {`root}");
    }
    files: dict[str, Path] = {};
    for path in sorted(`root.rglob("*")) {
        relative: any = path.relative_to(`root);
        if "__pycache__" in relative.parts or path.suffix in {".pyc", ".pyo"} {
            continue;
        }
        if path.is_file() {
            files[relative.as_posix()] = path;
        }
    }
    if "SKILL.md" not in files {
        raise FileNotFoundError(f"bundled Codex skill has no SKILL.md: {`root}");
    }
    return files;
}

impl _read_manifest(skill_dir: Path) -> dict[str, str] | None {
    path: any = skill_dir / MANIFEST_NAME;
    if skill_dir.is_symlink()
        or not _safe_target(skill_dir, path)
        or not install_plan.is_file(path)
    {
        return None;
    }
    try {
        parsed: Any = json.loads(install_plan.read_text(path, encoding="utf-8"));
    } except (OSError, json.JSONDecodeError) {
        return None;
    }
    files: any = parsed.get("files") if isinstance(parsed, `dict) else None;
    if not isinstance(files, `dict)
        or not all(
            isinstance(key, `str) and isinstance(value, `str) and _is_safe_relative(key)
            for (key, value) in files.items(),
        )
    {
        return None;
    }
    return `dict(files);
}

impl _is_safe_relative(relative: str) -> bool {
    path: any = Path(relative);
    return not path.is_absolute()
        and ".." not in path.parts
        and operator.eq(path.as_posix(), relative)
        and relative not in {"", "."};
}

impl _safe_target(`root: Path, target: Path) -> bool {
    try {
        target.resolve(strict=False).relative_to(`root.resolve(strict=False));
    } except (OSError, RuntimeError, ValueError) {
        return False;
    }
    current: any = target;
    while current != `root {
        try {
            if current.is_symlink() {
                return False;
            }
        } except OSError {
            return False;
        }
        current = current.parent;
    }
    return True;
}

impl _write_manifest(skill_dir: Path, hashes: dict[str, str]) {
    payload: any = {"version": 1, "files": `dict(sorted(hashes.items()))};
    install_plan.write_text(
        skill_dir / MANIFEST_NAME, json.dumps(payload, indent=2, ensure_ascii=False) + "\n"
    );
}

impl _file_hash(path: Path) -> str | None {
    try {
        return hashlib.sha256(install_plan.read_bytes(path)).hexdigest();
    } except OSError {
        return None;
    }
}

impl install_codex_skill -> Path | None {
    source_files: any = _iter_resource_files(bundled_skill_dir());
    destination: any = codex_skill_dir();
    if destination.is_symlink() or not _safe_target(codex_home(), destination) {
        logger.warning("Cannot install Codex skill through symlink: %s", destination);
        return None;
    }
    if not _safe_target(destination, destination / MANIFEST_NAME) {
        logger.warning("Unsafe Codex skill manifest; leaving %s unchanged", destination);
        return None;
    }

    manifest: any = _read_manifest(destination);
    if install_plan.exists(destination / MANIFEST_NAME) and manifest is None {
        logger.warning(
            "Existing Codex skill manifest is invalid; leaving %s unchanged", destination
        );
        return None;
    }

    if manifest is None {
        manifest = {};
    }

    relative: any;
    for relative in (*source_files, *manifest) {
        if not _is_safe_relative(relative)
            or not _safe_target(destination, destination / relative)
        {
            logger.warning("Unsafe Codex skill path; leaving %s unchanged", destination);
            return None;
        }
    }
    conflicts: any = [
        relative
        for (relative, source) in source_files.items()
        if relative not in manifest
            and install_plan.exists(destination / relative)
            and _file_hash(destination / relative)
                != hashlib.sha256(source.read_bytes()).hexdigest()
    ];
    if conflicts {
        logger.warning(
            "Unmanaged Codex skill files differ (%s); leaving %s unchanged",
            ", ".join(conflicts),
            destination,
        );
        return None;
    }

    current_hashes: dict[str, str] = {};
    preserved_files: set[str] = set[any]();
    for (relative, source) in source_files.items() {
        target: any = destination / relative;
        source_hash: any = hashlib.sha256(source.read_bytes()).hexdigest();
        old_hash: any = manifest.get(relative);
        if install_plan.exists(target)
            and old_hash is not None
            and _file_hash(target) not in {old_hash, source_hash}
        {
            logger.warning("Preserving user-edited Codex skill file: %s", target);
            preserved_files.add(relative);
            continue;
        }
        install_plan.copy_file(source, target);
        current_hashes[relative] = source_hash;
    }
    for (relative, old_hash) in manifest.items() {
        if relative in source_files {
            continue;
        }
        old_path: any = destination / relative;
        if install_plan.is_file(old_path) and _file_hash(old_path) == old_hash {
            install_plan.unlink(old_path);
        }
    }
    _write_manifest(
        destination, {**current_hashes, **{key: manifest[key] for key in preserved_files}}
    );
    logger.info("Installed Codex skill in %s", destination);
    return destination;
}

impl manifest_path(skill_dir: Path | None = None) -> Path {
    return (skill_dir or codex_skill_dir()) / MANIFEST_NAME;
}

impl owned_skill_files(skill_dir: Path | None = None) -> list[Path] {
    destination: any = skill_dir or codex_skill_dir();
    manifest: any = _read_manifest(destination);
    if manifest is None {
        return [];
    }
    expected: any = manifest;
    owned: list[Path] = [];
    for (relative, expected_hash) in expected.items() {
        path: any = destination / relative;
        if _safe_target(destination, path)
            and path.is_file()
            and _file_hash(path) == expected_hash
        {
            owned.append(path);
        }
    }
    manifest_file: any = manifest_path(destination);
    if manifest is not None and manifest_file.is_file() {
        owned.append(manifest_file);
    }
    return owned;
}
