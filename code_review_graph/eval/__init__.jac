"""Evaluation framework for code-review-graph.

Provides scoring metrics (token efficiency, MRR, precision/recall),
benchmark runners, and report generators for benchmarking graph-based code reviews.
"""

import from __future__ { annotations }

"""Lazy-import runner functions (require pyyaml)."""
def __getattr__(name: str) -> any;

glob __all__: any = [
    "compute_mrr",
    "compute_precision_recall",
    "compute_token_efficiency",
    "generate_full_report",
    "generate_markdown_report",
    "generate_readme_tables",
    "load_all_configs",
    "load_config",
    "run_eval",
    "write_csv",
];
