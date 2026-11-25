impl FileChange.is_change -> bool {
    if self.link is not None or self.after != self.before {
        return True;
    }
    return self.after is not None and _mode_changes(self.before_mode, self.mode);
}

impl _mode_changes(before: int | None, after: int | None) -> bool {
    if after is None or os.name == "nt" {
        return False;
    }
    return before is None or operator.ne(before & 511, after & 511);
}

impl _key(path: PathLike) -> Path {
    return Path(os.path.abspath(os.fspath(path)));
}

impl _real_key(path: PathLike) -> Path {
    return Path(os.path.realpath(os.fspath(path)));
}

impl _disk_state(path: Path) -> tuple[bytes | None, int | None] {
    try {
        info: any = os.stat(path);
    } except (FileNotFoundError, NotADirectoryError) {
        return (None, None);
    }
    if not stat.S_ISREG(info.st_mode) {
        return (None, None);
    }
    return (path.read_bytes(), stat.S_IMODE(info.st_mode));
}

impl _encode_text(text: str, encoding: str) -> bytes {
    if os.linesep != "\n" {
        text = text.replace("\n", os.linesep);
    }
    return text.encode(encoding);
}

impl _decode_text(data: bytes, encoding: str, errors: str) -> str {
    reader: any;
    with io.TextIOWrapper(io.BytesIO(data), encoding=encoding, errors=errors) as reader {
        return reader.read();
    }
}

impl Plan.init {
    self._files = {};
}

impl Plan._link_entry(path: PathLike) -> FileChange | None {
    `entry: any = self._files.get(_key(path));
    return `entry if `entry is not None and `entry.link is not None else None;
}

impl Plan._planned(path: PathLike) -> FileChange | None {
    return self._link_entry(path) or self._files.get(_real_key(path));
}

impl Plan.exists(path: PathLike) -> bool {
    planned: any = self._planned(path);
    if planned is not None {
        return planned.after is not None;
    }
    return Path(path).exists();
}

impl Plan.is_file(path: PathLike) -> bool {
    planned: any = self._planned(path);
    if planned is not None {
        return planned.after is not None;
    }
    return Path(path).is_file();
}

impl Plan.read_bytes(path: PathLike) -> bytes {
    planned: any = self._planned(path);
    if planned is None {
        return Path(path).read_bytes();
    }
    if planned.after is None {
        raise FileNotFoundError(errno.ENOENT, os.strerror(errno.ENOENT), `str(path));
    }
    return planned.after;
}

impl Plan.lexists(path: PathLike) -> bool {
    planned: any = self._planned(path);
    if planned is not None {
        return planned.after is not None;
    }
    key: any = _real_key(path);
    for `entry in self._files.values() {
        if `entry.after is not None and key in `entry.path.parents {
            return True;
        }
    }
    return os.path.lexists(path);
}

impl Plan.mode(path: PathLike) -> int | None {
    planned: any = self._planned(path);
    if planned is None {
        return _disk_state(_real_key(path))[1];
    }
    if planned.after is None {
        return None;
    }
    return planned.mode if planned.mode is not None else planned.before_mode;
}

impl Plan._entry(path: PathLike) -> FileChange {
    link_entry: any = self._link_entry(path);
    if link_entry is not None {
        return link_entry;
    }
    key: any = _real_key(path);
    `entry: any = self._files.get(key);
    if `entry is None {
        before: any;
        before_mode: any;
        (before, before_mode) = _disk_state(key) as any;
        `entry = FileChange(key, before, before, before_mode, None);
        self._files[key] = `entry;
    }
    return `entry;
}

impl Plan._check_can_create(key: Path) -> None {
    planned: any = self._files.get(key);
    if planned is not None and planned.after is not None {
        return;
    }
    if key.is_dir() {
        raise IsADirectoryError(errno.EISDIR, os.strerror(errno.EISDIR), `str(key));
    }
    for parent in key.parents {
        planned = self._files.get(parent);
        if planned is not None and planned.after is not None {
            raise NotADirectoryError(errno.ENOTDIR, os.strerror(errno.ENOTDIR), `str(parent));
        }
        if parent.is_dir() {
            return;
        }
        if os.path.lexists(parent) {
            raise NotADirectoryError(errno.ENOTDIR, os.strerror(errno.ENOTDIR), `str(parent));
        }
    }
}

impl Plan.write_bytes(path: PathLike, data: bytes, mode: int | None = None) -> None {
    self._check_can_create(_real_key(path));
    `entry: any = self._entry(path);
    `entry.after = data;
    if mode is not None {
        `entry.mode = mode;
    }
}

impl Plan.chmod(path: PathLike, mode: int) -> None {
    if not self.is_file(path) {
        raise FileNotFoundError(errno.ENOENT, os.strerror(errno.ENOENT), `str(path));
    }
    self._entry(path).mode = mode;
}

impl Plan.unlink(path: PathLike) -> None {
    if not self.is_file(path) {
        raise FileNotFoundError(errno.ENOENT, os.strerror(errno.ENOENT), `str(path));
    }
    key: any = _key(path);
    if self._link_entry(path) is None and os.path.islink(key) {
        before: any;
        before_mode: any;
        (before, before_mode) = _disk_state(key) as any;
        self._files[key] = FileChange(
            key, before, before, before_mode, None, link=os.readlink(key)
        );
    }
    `entry: any = self._entry(path);
    `entry.after = None;
    `entry.mode = None;
}

impl Plan.changes -> list[FileChange] {
    return [`entry for `entry in self._files.values() if `entry.is_change()];
}

impl Plan.written -> list[Path] {
    return [`entry.path for `entry in self._files.values() if `entry.after is not None];
}

impl Plan.checkpoint -> dict[Path, tuple[bytes | None, int | None]] {
    return {key: (`entry.after, `entry.mode) for (key, `entry) in self._files.items()};
}

impl Plan.changes_since(saved: dict[Path, tuple[bytes | None, int | None]]) -> list[FileChange] {
    return [
        `entry
        for (key, `entry) in self._files.items()
        if `entry.is_change() and saved.get(key) != (`entry.after, `entry.mode)
    ];
}

impl Plan.rollback(saved: dict[Path, tuple[bytes | None, int | None]]) -> None {
    for key in `list(self._files) {
        if key in saved {
            items_: any = list(saved[key] as any);
            if len(items_) != 2 {
                raise ValueError(
                    f"too many values to unpack (expected 2, got {len(items_)})"
                        if len(items_) > 2
                        else f"not enough values to unpack (expected 2, got {len(items_)})",
                );
            }
            self._files[key].after = items_[0];
            self._files[key].mode = items_[1];
        } else {
            del self._files[key];
        }
    }
}

impl Plan.apply -> list[tuple[Path, str]] {
    failures: list[tuple[Path, str]] = [];
    for change in self.changes() {
        try {
            if not _unchanged_on_disk(change) {
                failures.append((
                    change.path,
                    "it changed after the preview, so it was left alone",
                ));
                continue;
            }
            if change.link is not None {
                os.unlink(change.path);
            } elif change.after is None {
                change.path.unlink();
            }
            if change.after is None {
                continue;
            }
            if change.after != change.before or change.link is not None {
                change.path.parent.mkdir(parents=True, exist_ok=True);
                change.path.write_bytes(change.after);
            }
            if change.mode is not None {
                os.chmod(change.path, change.mode);
            }
        } except OSError as exc {
            failures.append((change.path, `str(exc)));
        }
    }
    return failures;
}

impl Plan.__repr__ -> str {
    return (getattr(builtins.object, "__repr__") as any)(self);
}

impl Plan.__eq__(other: any) -> bool {
    return self is other;
}

impl Plan.__hash__ -> int {
    return id(self);
}

impl _unchanged_on_disk(change: FileChange) -> bool {
    if change.link is not None {
        return os.path.islink(change.path) and operator.eq(os.readlink(change.path), change.link);
    }
    return operator.eq(_disk_state(change.path), (change.before, change.before_mode));
}

impl active -> Plan | None {
    return _ACTIVE.get();
}

impl planning -> Generator[any, any, any] {
    plan: any = Plan();
    token: any = _ACTIVE.set(plan);
    try {
        yield plan;
    } finally {
        _ACTIVE.reset(token);
    }
}

impl exists(path: PathLike) -> bool {
    plan: any = active();
    return plan.exists(path) if plan is not None else Path(path).exists();
}

impl is_file(path: PathLike) -> bool {
    plan: any = active();
    return plan.is_file(path) if plan is not None else Path(path).is_file();
}

impl lexists(path: PathLike) -> bool {
    plan: any = active();
    return plan.lexists(path) if plan is not None else os.path.lexists(path);
}

impl read_bytes(path: PathLike) -> bytes {
    plan: any = active();
    return plan.read_bytes(path) if plan is not None else Path(path).read_bytes();
}

impl read_text(path: PathLike, encoding: str = "utf-8", errors: str = "strict") -> str {
    plan: any = active();
    if plan is None or plan._planned(path) is None {
        return Path(path).read_text(encoding=encoding, errors=errors);
    }
    return _decode_text(plan.read_bytes(path), encoding, errors);
}

impl write_text(path: PathLike, text: str, encoding: str = "utf-8") -> None {
    plan: any = active();
    if plan is not None {
        plan.write_bytes(path, _encode_text(text, encoding));
        return;
    }
    target: any = Path(path);
    target.parent.mkdir(parents=True, exist_ok=True);
    target.write_text(text, encoding=encoding);
}

impl write_bytes(path: PathLike, data: bytes) -> None {
    plan: any = active();
    if plan is not None {
        plan.write_bytes(path, data);
        return;
    }
    target: any = Path(path);
    target.parent.mkdir(parents=True, exist_ok=True);
    target.write_bytes(data);
}

impl copy_file(source: PathLike, destination: PathLike) -> None {
    plan: any = active();
    if plan is None {
        Path(destination).parent.mkdir(parents=True, exist_ok=True);
        shutil.copy2(source, destination);
        return;
    }
    plan.write_bytes(destination, plan.read_bytes(source), mode=plan.mode(source));
}

impl chmod(path: PathLike, mode: int) -> None {
    plan: any = active();
    if plan is not None {
        plan.chmod(path, mode);
    } else {
        os.chmod(path, mode);
    }
}

impl unlink(path: PathLike) -> None {
    plan: any = active();
    if plan is not None {
        plan.unlink(path);
    } else {
        Path(path).unlink();
    }
}

impl display_path(path: PathLike, repo_root: PathLike | None = None) -> str {
    target: any = _key(path);
    bases: list[tuple[str, str]] = [];
    if repo_root is not None {
        base: any;
        for base in {os.path.abspath(repo_root), os.path.realpath(repo_root)} {
            bases.append((base, ""));
        }
    }
    home: any = `str(Path.home());
    for base in {os.path.abspath(home), os.path.realpath(home)} {
        bases.append((base, "~/"));
    }
    for candidate in (`str(target), os.path.realpath(target)) {
        for (base, prefix) in bases {
            try {
                relative: any = Path(candidate).relative_to(base);
            } except ValueError {
                continue;
            }
            if relative.parts {
                return prefix + relative.as_posix();
            }
        }
    }
    return target.as_posix();
}

impl diff_label(shown: str, side: str) -> str {
    if shown.startswith("~/") or Path(shown).is_absolute() {
        return shown;
    }
    return f"{side}/{shown}";
}

impl describe(change: FileChange) -> str {
    if change.before is None {
        return "new";
    }
    if change.after is None {
        return "removed";
    }
    if change.after == change.before {
        return "permissions";
    }
    return "update";
}

impl _lines(data: bytes | None) -> list[str] | None {
    if data is None {
        return [];
    }
    if b"\x00" in data {
        return None;
    }
    return data.decode("utf-8", errors="replace").splitlines();
}

impl render(
    changes: Iterable[FileChange], repo_root: PathLike | None = None, limit: int = limit_default_
) -> str {
    blocks: list[str] = [];
    for change in changes {
        shown: any = display_path(change.path, repo_root);
        out: list[str] = [];
        if change.before is not None
            and change.after is not None
            and _mode_changes(change.before_mode, change.mode)
        {
            out.append(f"mode {change.before_mode or 0:o} -> {change.mode or 0:o}: {shown}");
        } elif change.before is None and change.mode is not None and change.mode & 73 {
            out.append(f"new file, executable: {shown}");
        }

        if change.after != change.before {
            before: any;
            after: any;
            (before, after) = (_lines(change.before), _lines(change.after));
            if before is None or after is None {
                size: any = len(change.after or b"");
                out.append(f"binary file: {shown} ({size} bytes)");
            } else {
                diff: any = `list(
                    difflib.unified_diff(
                        before,
                        after,
                        fromfile="/dev/null" if change.before is None else diff_label(shown, "a"),
                        tofile="/dev/null" if change.after is None else diff_label(shown, "b"),
                        lineterm="",
                    ),
                );
                if not diff {
                    what: any = "new empty file"
                        if change.before is None
                        else "line endings change";
                    out.append(f"{what}: {shown}");
                }
                head: any;
                body: any;
                (head, body) = (diff[:2], diff[2:]);
                out.extend(head);
                if len(body) <= limit + _MIN_CUT {
                    out.extend(body);
                } else {
                    out.extend(body[:limit]);
                    out.append(f"... {len(body) - limit} more lines not shown");
                }
            }
        }
        blocks.append("\n".join(out));
    }
    return "\n\n".join(blocks) + ("\n" if blocks else "");
}
