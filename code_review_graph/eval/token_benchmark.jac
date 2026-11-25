"""Measures total tokens consumed by agent workflows against benchmark repos."""

import importlib;

import from __future__ { annotations }

import json;

import logging;

import from typing { Any, Callable }

glob logger: any;

glob ALL_WORKFLOWS: dict[str, Callable[..., dict]];

with entry {
    logger = logging.getLogger(__name__);
}

"""Estimate token count from JSON-serializable object.

    Uses character count / 4 as a rough approximation for English + code.
    """
def estimate_tokens(`obj: Any) -> int;

"""Simulate a review workflow and measure total tokens consumed."""
def benchmark_review_workflow(repo_root: str, base: str = "HEAD~1") -> dict;

"""Simulate an architecture exploration workflow."""
def benchmark_architecture_workflow(repo_root: str) -> dict;

"""Simulate a debug workflow."""
def benchmark_debug_workflow(repo_root: str) -> dict;

"""Simulate an onboarding workflow."""
def benchmark_onboard_workflow(repo_root: str) -> dict;

"""Simulate a pre-merge check workflow."""
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

"""Run all workflow benchmarks and return results."""
def run_all_benchmarks(repo_root: str, base: str = "HEAD~1") -> list[dict];
