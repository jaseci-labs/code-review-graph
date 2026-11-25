import from __future__ { annotations }

import importlib, csv, logging, sqlite3, subprocess;

import from datetime { date }

import from pathlib { Path }

glob yaml: any;

with entry {
    try {
        import yaml;
    } except ImportError {
        yaml = None;
    }
}

glob logger: any = logging.getLogger(__name__);

glob BENCHMARK_REGISTRY: any = {
    "token_efficiency": token_efficiency.run,
    "impact_accuracy": impact_accuracy.run,
    "flow_completeness": flow_completeness.run,
    "search_quality": search_quality.run,
    "build_performance": build_performance.run,
    "multi_hop_retrieval": multi_hop_retrieval.run,
    "agent_baseline": agent_baseline.run,
    "incremental_fidelity": incremental_fidelity.run,
};

glob CONFIGS_DIR: any = Path(__file__).parent / "configs";

glob DEFAULT_OUTPUT: any = Path("evaluate/results");

glob DEFAULT_REPOS: any = Path("evaluate/test_repos");

def _require_yaml -> any;
def _validate_config(config: object, path: Path) -> dict;
def load_config(name: str) -> dict;
def load_all_configs -> list[dict];
def _assert_standalone_repo(repo_path: Path);
def clone_or_update(config: dict, repos_dir: Path | None = None) -> Path;
def write_csv(results: list[dict], path: Path);

glob SEMANTIC_BENCHMARKS: any = frozenset({
    "agent_baseline",
    "search_quality",
    "multi_hop_retrieval",
});

def _embedding_count(store) -> int | None;
def _build_embedding_index(store, db_path, provider: str | None, model: str | None);
def _warn_if_semantic_index_missing(store, benchmark_names: list[str]);
def run_eval(
    repos: list[str] | None = None,
    benchmarks: list[str] | None = None,
    output_dir: str | Path | None = None,
    embed: bool = False,
    embedding_provider: str | None = None,
    embedding_model: str | None = None,
) -> dict[str, list[dict]];
