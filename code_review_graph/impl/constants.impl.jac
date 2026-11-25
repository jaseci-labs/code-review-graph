impl read_only_requested -> bool {
    return os.environ.get(READ_ONLY_ENV, "").strip().lower() in {"1", "true", "yes", "on"};
}

impl _warn_invalid_env(name: str, raw: str, `default: object) -> None {
    if name in _warned_env_vars {
        return;
    }
    _warned_env_vars.add(name);
    logger.warning(
        "Ignoring invalid %s=%r (not a number); using the default %s.", name, raw, `default
    );
}

impl env_int(name: str, `default: int) -> int {
    raw: any = os.environ.get(name);
    if raw is None {
        return `default;
    }
    try {
        return `int(raw.strip());
    } except (TypeError, ValueError) {
        _warn_invalid_env(name, raw, `default);
        return `default;
    }
}

impl env_float(name: str, `default: float) -> float {
    raw: any = os.environ.get(name);
    if raw is None {
        return `default;
    }
    try {
        value: any = `float(raw.strip());
    } except (TypeError, ValueError) {
        _warn_invalid_env(name, raw, `default);
        return `default;
    }
    if not math.isfinite(value) {
        _warn_invalid_env(name, raw, `default);
        return `default;
    }
    return value;
}

impl _bounded_float_env(name: str, `default: float, *, lower: float, upper: float) -> float {
    raw: any = os.environ.get(name);
    if raw is None {
        return `default;
    }
    try {
        value: any = `float(raw);
    } except (TypeError, ValueError) {
        return `default;
    }
    if not math.isfinite(value) or not lower < value < upper {
        return `default;
    }
    return value;
}

impl discovery_timeout -> float {
    explicit_git: any = os.environ.get(GIT_TIMEOUT_ENV);
    if explicit_git is not None and explicit_git.strip() {
        fallback: any = `float(GIT_TIMEOUT);
    } else {
        fallback = min(DISCOVERY_TIMEOUT_DEFAULT, `float(GIT_TIMEOUT));
    }

    raw: any = os.environ.get(DISCOVERY_TIMEOUT_ENV);
    if raw is None or not raw.strip() {
        return fallback;
    }
    value: any = env_float(DISCOVERY_TIMEOUT_ENV, fallback);
    if value < 0 {
        logger.warning(
            "Ignoring invalid %s=%r (negative); using %.3gs for change discovery.",
            DISCOVERY_TIMEOUT_ENV,
            raw,
            fallback,
        );
        return fallback;
    }
    return value;
}

impl crg_home -> Path {
    `override: any = os.environ.get(CRG_HOME_ENV, "").strip();
    if `override {
        return Path(`override).expanduser();
    }
    return Path.home() / ".code-review-graph";
}

impl normalize_file_path(path: "str | os.PathLike[str]") -> str {
    if isinstance(path, `str) {
        return path.replace("\\", "/") if "\\" in path else path;
    }
    if isinstance(path, PurePath) {
        return path.as_posix();
    }
    return `str(path).replace("\\", "/");
}

impl release_os_memory -> None {
    import gc;
    import sys;

    gc.collect();
    if sys.platform.startswith("linux") {
        if not _MALLOC_TRIM_PROBED {
            _MALLOC_TRIM_PROBED = True;
            try {
                import ctypes;

                _MALLOC_TRIM_FN = ctypes.CDLL("libc.so.6").malloc_trim;
            } except Exception {
                _MALLOC_TRIM_FN = None;
            }
        }
        if callable(_MALLOC_TRIM_FN) {
            try {
                _MALLOC_TRIM_FN(0);
            } except Exception as exc {
                logger.debug("malloc_trim(0) failed: %s", exc);
            }
        }
    }
}
