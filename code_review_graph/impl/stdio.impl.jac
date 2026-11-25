impl configure_utf8_stdio -> None {
    for stream in (sys.stdout, sys.stderr) {
        encoding: any = getattr(stream, "encoding", None);
        if not encoding or encoding.lower().replace("-", "") == "utf8" {
            continue;
        }
        reconfigure: any = getattr(stream, "reconfigure", None);
        if reconfigure is None {
            continue;
        }
        try {
            reconfigure(encoding="utf-8");
        } except (OSError, ValueError) {}
    }
}
