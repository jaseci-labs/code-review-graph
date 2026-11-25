import from __future__ { annotations }

import logging, sqlite3;

import from pathlib { Path }

import from typing { Any }

glob logger: any = logging.getLogger(__name__);

glob _SAMPLE_QUESTIONS: any = [
    "how does authentication work",
    "what is the main entry point",
    "how are database connections managed",
    "what error handling patterns are used",
    "how do tests verify core functionality",
];

def estimate_tokens(text: str) -> int;
def compute_naive_tokens(repo_root: Path) -> int;
def run_token_benchmark(
    store: GraphStore, repo_root: Path, questions: list[str] | None = None
) -> dict[str, Any];
