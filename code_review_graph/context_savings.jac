import from __future__ { annotations }

import json;

import from pathlib { Path }

import from typing { Any, Iterable }

glob CHARS_PER_TOKEN: any = 4;
def estimate_tokens(value: Any) -> int;
def estimate_file_tokens(repo_root: Path, files: Iterable[str]) -> int;

def _token_counts(
    original_context: Any | None,
    returned_context: Any | None,
    original_tokens: int | None,
    returned_tokens: int | None,
) -> tuple[int, int];

def _savings(baseline: int, returned: int) -> dict[str, int | bool] | None;
def estimate_context_savings(
    *,
    original_context: Any | None = None,
    returned_context: Any | None = None,
    original_tokens: int | None = None,
    returned_tokens: int | None = None,
) -> dict[str, int | bool] | None;
def attach_context_savings(
    result: dict[str, Any],
    *,
    original_context: Any | None = None,
    original_tokens: int | None = None,
    returned_context: Any | None = None,
    returned_tokens: int | None = None,
    call: CallInfo | None = None,
) -> dict[str, Any];
def format_context_savings(estimate: dict[str, Any] | None) -> str | None;
def _fmt_compact(n: int) -> str;
def _breakdown_from_response(response: dict[str, Any]) -> dict[str, int];
def verify_with_tiktoken(
    repo_root: "Path | str",
    changed_files: Iterable[str],
    response: Any,
    encoding_name: str = "cl100k_base",
) -> dict[str, int] | None;
def format_context_savings_panel(
    estimate: dict[str, Any] | None,
    *,
    original_tokens: int | None = None,
    returned_tokens: int | None = None,
    response: dict[str, Any] | None = None,
    breakdown: dict[str, int] | None = None,
    verified: dict[str, int] | None = None,
    title: str = "Token Savings",
    width: int = 64,
) -> str | None;
