impl __getattr__(name: str) -> any {
    _runner_names: any = {"load_all_configs", "load_config", "run_eval", "write_csv"};
    if name in _runner_names {
        return getattr(importlib.import_module("code_review_graph.eval.runner"), name);
    }
    raise AttributeError(f"module {__name__!r} has no attribute {name!r}");
}
