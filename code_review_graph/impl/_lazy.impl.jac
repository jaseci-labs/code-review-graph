impl lazy(module: str, name: str = "") -> any {
    loaded: any = importlib.import_module(
        f"code_review_graph.{module}" if module else "code_review_graph"
    );
    if not name {
        return loaded;
    }
    try {
        return getattr(loaded, name);
    } except AttributeError as exc {
        raise ImportError(f"cannot import name {name!r} from {loaded.__name__!r}") from exc;
    }
}
