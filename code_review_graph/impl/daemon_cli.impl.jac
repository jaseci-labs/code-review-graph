impl _process_already_gone(error: OSError) -> bool {
    return isinstance(error, ProcessLookupError)
        or operator.eq(getattr(error, "winerror", None), 87);
}

impl _handle_start(args: argparse.Namespace) {
    import from code_review_graph.daemon { DaemonAlreadyRunningError }
    WatchDaemon = lazy("daemon", "WatchDaemon");
    claim_daemon_lock = lazy("daemon", "claim_daemon_lock");
    is_daemon_running = lazy("daemon", "is_daemon_running");
    load_config = lazy("daemon", "load_config");
    reap_orphaned_watchers = lazy("daemon", "reap_orphaned_watchers");
    write_pid = lazy("daemon", "write_pid");

    if is_daemon_running() {
        print("Error: Daemon is already running.");
        sys.exit(1);
    }
    try {
        claim_daemon_lock();
    } except DaemonAlreadyRunningError as exc {
        print(f"Error: Daemon is already running: {exc}.");
        sys.exit(1);
    }
    reaped: any = reap_orphaned_watchers();
    for orphan in reaped {
        print(
            "Reaped orphaned watcher for '"
                + format(orphan["alias"], "")
                + "' (PID "
                + format(orphan["pid"], "")
                + ") left by a previous daemon.",
        );
    }

    config: any = load_config();
    daemon: any = WatchDaemon(config=config);

    if not args.foreground {
        daemon.daemonize();
    } else {
        write_pid();
    }

    try {
        if args.foreground {
            daemon._setup_signal_handlers();
        }
        daemon.start();
        daemon.run_forever();
    } finally {
        daemon.stop();
    }
}

impl _handle_stop(_args: argparse.Namespace) {
    clear_pid = lazy("daemon", "clear_pid");
    is_daemon_running = lazy("daemon", "is_daemon_running");
    pid_alive = lazy("daemon", "pid_alive");
    read_pid = lazy("daemon", "read_pid");
    reap_orphaned_watchers = lazy("daemon", "reap_orphaned_watchers");

    if not is_daemon_running() {
        reaped: any = reap_orphaned_watchers();
        if reaped {
            for orphan in reaped {
                print(
                    "Stopped orphaned watcher for '"
                        + format(orphan["alias"], "")
                        + "' (PID "
                        + format(orphan["pid"], "")
                        + ") left by a crashed daemon.",
                );
            }
            clear_pid();
            print("Daemon stopped.");
            return;
        }
        print("Daemon is not running.");
        sys.exit(1);
    }

    pid: any = read_pid();
    if pid is None {
        print("Error: Could not read daemon PID.");
        sys.exit(1);
    }

    print(f"Stopping daemon (PID {pid})...");
    stopped: any = False;
    try {
        os.kill(pid, signal.SIGTERM);
    } except PermissionError {
        print(f"Error: Permission denied sending signal to PID {pid}.");
        sys.exit(1);
    } except OSError as exc {
        if not _process_already_gone(exc) {
            raise;
        }
        clear_pid();
        _reap_watchers_left_behind();
        print("Daemon stopped (process already gone).");
        return;
    }

    try {
        _: any;
        for _ in range(50) {
            if not pid_alive(pid) {
                stopped = True;
                break;
            }
            time.sleep(0.1);
        } else {
            print("Daemon did not stop gracefully, force-stopping...");
            force_signal: any = getattr(signal, "SIGKILL", signal.SIGTERM);
            try {
                os.kill(pid, force_signal);
            } except OSError as exc {
                if not _process_already_gone(exc) {
                    raise;
                }
                stopped = True;
            } else {
                for _ in range(50) {
                    if not pid_alive(pid) {
                        stopped = True;
                        break;
                    }
                    time.sleep(0.1);
                }
            }
        }
    } finally {
        if stopped {
            clear_pid();
        }
    }

    if not stopped {
        print(f"Error: Daemon PID {pid} is still running; refusing to clear its PID file.");
        sys.exit(1);
    }

    _reap_watchers_left_behind();
    print("Daemon stopped.");
}

impl _reap_watchers_left_behind {
    reap_orphaned_watchers = lazy("daemon", "reap_orphaned_watchers");

    for orphan in reap_orphaned_watchers() {
        print(
            "Stopped watcher for '"
                + format(orphan["alias"], "")
                + "' (PID "
                + format(orphan["pid"], "")
                + ") that outlived the daemon.",
        );
    }
}

impl _handle_restart(args: argparse.Namespace) {
    is_daemon_running = lazy("daemon", "is_daemon_running");

    if is_daemon_running() {
        _handle_stop(args);
    } else {
        print("Daemon is not running, starting fresh.");
    }

    _handle_start(args);
}

impl _format_age(seconds: float | None) -> str {
    if seconds is None {
        return "-";
    }
    seconds = max(0.0, `float(seconds));
    if seconds < 60 {
        return f"{seconds:.0f}s";
    }
    if seconds < 3600 {
        return f"{seconds / 60:.0f}m";
    }
    if seconds < 86400 {
        return f"{seconds / 3600:.0f}h";
    }
    return f"{seconds / 86400:.0f}d";
}

impl _handle_status(_args: argparse.Namespace) {
    orphan: any;
    find_orphaned_watchers = lazy("daemon", "find_orphaned_watchers");
    is_daemon_running = lazy("daemon", "is_daemon_running");
    load_config = lazy("daemon", "load_config");
    load_state = lazy("daemon", "load_state");
    pid_alive = lazy("daemon", "pid_alive");
    read_pid = lazy("daemon", "read_pid");
    read_watch_health = lazy("daemon", "read_watch_health");
    watcher_status = lazy("daemon", "watcher_status");

    config: any = load_config();
    running: any = is_daemon_running();

    if running {
        pid: any = read_pid();
        print(f"Daemon:  running (PID {pid})");
    } else {
        print("Daemon:  not running");
    }
    orphans: any = [] if running else find_orphaned_watchers();

    print(f"Name:    {config.session_name}");
    print(f"Log dir: {config.log_dir}");
    print(f"Poll:    {config.poll_interval}s");
    print();

    if not config.repos {
        print("No repositories configured.");
        print("Use: crg-daemon add <path> [--alias NAME]");
        return;
    }
    alias_width: any = max(len(r.alias) for r in config.repos);
    alias_width = max(alias_width, 5);

    if running {
        state: any = load_state();
        header: any = "  "
            + format("Alias", f"<{alias_width}")
            + "  "
            + format("Status", "<8")
            + "  "
            + format("Watcher", "<8")
            + "  "
            + format("PID", "<8")
            + "  "
            + format("Event", "<6")
            + "  Path";
        print(header);
        print(f"  {"-" * alias_width}  {"-" * 8}  {"-" * 8}  {"-" * 8}  {"-" * 6}  {"-" * 40}");
        stalled: any = False;
        degraded: any = False;
        repo: any;
        for repo in config.repos {
            `entry: any = state.get(repo.alias, {});
            child_pid: int | None = `entry.get("pid");
            alive: any = child_pid is not None and pid_alive(child_pid);
            status_str: any = "alive" if alive else "dead";
            pid_str: any = `str(child_pid) if child_pid is not None else "-";
            health: any = read_watch_health(repo.path);
            watcher: any = watcher_status(alive, health);
            stalled = stalled or operator.eq(watcher, "stalled");
            degraded = degraded or operator.eq(watcher, "partial");
            last_event: any = health.get("last_event_at") if health else None;
            event_str: any = _format_age(time.time() - last_event)
                if isinstance(last_event, (`int, `float))
                else "-";
            print(
                "  "
                    + format(repo.alias, f"<{alias_width}")
                    + "  "
                    + format(status_str, "<8")
                    + "  "
                    + format(watcher, "<8")
                    + "  "
                    + format(pid_str, "<8")
                    + "  "
                    + format(event_str, "<6")
                    + "  "
                    + format(repo.path, ""),
            );
        }
        if stalled {
            print();
            print(
                "  A stalled watcher means the process is up but its filesystem observer is not;"
            );
            print("  the graph is no longer updating. Check the log, then: crg-daemon restart");
        }
        if degraded {
            print();
            print("  A partial watcher is running with reduced coverage. The health file's");
            print("  failed_paths field lists directories the OS could not register;");
            print("  when it is empty, watch slots ran out and one recursive watch");
            print("  replaced the filtered plan; raise CRG_MAX_WATCH_SCHEDULES then.");
        }
    } else {
        by_alias: any = {orphan["alias"]: orphan for orphan in orphans};
        print(
            "  "
                + format("Alias", f"<{alias_width}")
                + "  "
                + format("Status", "<8")
                + "  "
                + format("PID", "<8")
                + "  Path",
        );
        print(f"  {"-" * alias_width}  {"-" * 8}  {"-" * 8}  {"-" * 40}");
        for repo in config.repos {
            orphan = by_alias.get(repo.alias);
            status_str = "orphan" if orphan else "-";
            pid_str = `str(orphan["pid"]) if orphan else "-";
            print(
                "  "
                    + format(repo.alias, f"<{alias_width}")
                    + "  "
                    + format(status_str, "<8")
                    + "  "
                    + format(pid_str, "<8")
                    + "  "
                    + format(repo.path, ""),
            );
        }
        if orphans {
            print();
            print(
                f"  {len(orphans)} watcher(s) outlived the daemon and are still writing their graph.",
            );
            print(
                "  Run 'crg-daemon stop' to reap them, or 'crg-daemon start' which reaps them first.",
            );
        }
    }
}

impl _handle_logs(args: argparse.Namespace) {
    load_config = lazy("daemon", "load_config");

    config: any = load_config();

    if args.repo {
        log_file: any = config.log_dir / f"{args.repo}.log";
    } else {
        log_file = config.log_dir / "daemon.log";
    }

    if not log_file.exists() {
        print(f"Log file not found: {log_file}");
        sys.exit(1);
    }

    if args.follow {
        try {
            subprocess.run(["tail", "-f", `str(log_file)], check=False);
        } except KeyboardInterrupt {}
        return;
    }
    lines_count: any = args.lines;
    try {
        text: any = log_file.read_text(encoding="utf-8", errors="replace");
    } except OSError as exc {
        print(f"Error reading log file: {exc}");
        sys.exit(1);
    }

    lines: any = text.splitlines();
    tail: any = lines[-lines_count:] if len(lines) > lines_count else lines;
    for line in tail {
        print(line);
    }
}

impl _handle_add(args: argparse.Namespace) {
    add_repo_to_config = lazy("daemon", "add_repo_to_config");
    is_daemon_running = lazy("daemon", "is_daemon_running");

    try {
        add_repo_to_config(args.path, alias=args.alias);
    } except ValueError as exc {
        print(f"Error: {exc}");
        sys.exit(1);
    }
    alias: any = args.alias or os.path.basename(os.path.abspath(args.path));
    print(f"Added repository: {args.path} (alias: {alias})");

    if is_daemon_running() {
        print("Daemon will pick up the change automatically.");
    }
}

impl _handle_remove(args: argparse.Namespace) {
    is_daemon_running = lazy("daemon", "is_daemon_running");
    load_config = lazy("daemon", "load_config");
    remove_repo_from_config = lazy("daemon", "remove_repo_from_config");

    config_before: any = load_config();
    count_before: any = len(config_before.repos);

    config_after: any = remove_repo_from_config(args.path_or_alias);
    count_after: any = len(config_after.repos);

    if count_before == count_after {
        print(f"No repository matching '{args.path_or_alias}' found in config.");
        sys.exit(1);
    }

    print(f"Removed repository: {args.path_or_alias}");

    if is_daemon_running() {
        print("Daemon will pick up the change automatically.");
    }
}

impl main {
    configure_utf8_stdio();
    logging.basicConfig(level=logging.INFO, format="%(levelname)s: %(message)s");

    ap: any = argparse.ArgumentParser(
        prog="crg-daemon", description="Multi-repo watch daemon for code-review-graph"
    );
    sub: any = ap.add_subparsers(dest="command");
    start_cmd: any = sub.add_parser("start", help="Start the daemon");
    start_cmd.add_argument(
        "--foreground", action="store_true", help="Run in the foreground instead of daemonizing"
    );
    sub.add_parser("stop", help="Stop the daemon");
    restart_cmd: any = sub.add_parser("restart", help="Restart the daemon");
    restart_cmd.add_argument(
        "--foreground", action="store_true", help="Run in the foreground instead of daemonizing"
    );
    sub.add_parser("status", help="Show daemon status and configuration");
    logs_cmd: any = sub.add_parser("logs", help="Show daemon or per-repo logs");
    logs_cmd.add_argument(
        "--repo", default=None, metavar="ALIAS", help="Show logs for a specific repo (by alias)"
    );
    logs_cmd.add_argument(
        "--follow", "-f", action="store_true", help="Follow log output (tail -f)"
    );
    logs_cmd.add_argument(
        "--lines", "-n", type=int, default=50, help="Number of lines to show (default: 50)"
    );
    add_cmd: any = sub.add_parser("add", help="Add a repository to the daemon config");
    add_cmd.add_argument("path", help="Path to the repository");
    add_cmd.add_argument(
        "--alias", default=None, help="Short alias for the repository (default: directory name)"
    );
    remove_cmd: any = sub.add_parser("remove", help="Remove a repository from the daemon config");
    remove_cmd.add_argument("path_or_alias", help="Repository path or alias to remove");

    args: any = ap.parse_args();

    if not args.command {
        ap.print_help();
        sys.exit(0);
    }

    handlers: dict[str, object] = {
        "start": _handle_start,
        "stop": _handle_stop,
        "restart": _handle_restart,
        "status": _handle_status,
        "logs": _handle_logs,
        "add": _handle_add,
        "remove": _handle_remove,
    };

    handler: any = handlers.get(args.command);
    if handler is None {
        ap.print_help();
        sys.exit(1);
    }

    handler(args);
}
