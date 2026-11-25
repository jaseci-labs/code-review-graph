import from __future__ { annotations }

import importlib;

import json;

import logging;

import from typing { Any, Callable }

glob logger: any;

glob ALL_WORKFLOWS: dict[str, Callable[..., dict]];

with entry {
    logger = logging.getLogger(__name__);
}

def estimate_tokens(`obj: Any) -> int;
def benchmark_review_workflow(repo_root: str, base: str = "HEAD~1") -> dict;
def benchmark_architecture_workflow(repo_root: str) -> dict;
def benchmark_debug_workflow(repo_root: str) -> dict;
def benchmark_onboard_workflow(repo_root: str) -> dict;
def benchmark_pre_merge_workflow(repo_root: str, base: str = "HEAD~1") -> dict;

with entry {
    ALL_WORKFLOWS = {
        "review": benchmark_review_workflow,
        "architecture": benchmark_architecture_workflow,
        "debug": benchmark_debug_workflow,
        "onboard": benchmark_onboard_workflow,
        "pre_merge": benchmark_pre_merge_workflow,
    };
}

def run_all_benchmarks(repo_root: str, base: str = "HEAD~1") -> list[dict];
