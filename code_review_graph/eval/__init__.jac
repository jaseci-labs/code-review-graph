import from __future__ { annotations }

import importlib;

def __getattr__(name: str) -> any {
    _runner_names: any = {"load_all_configs", "load_config", "run_eval", "write_csv"};
    if name in _runner_names {
        return getattr(lazy("eval.runner"), name);
    }
    raise AttributeError(f"module {__name__!r} has no attribute {name!r}");
}

glob __all__: any = ("compute_mrr compute_precision_recall compute_token_efficiency generate_full_report "
    "generate_markdown_report generate_readme_tables load_all_configs load_config run_eval "
    "write_csv").split();
