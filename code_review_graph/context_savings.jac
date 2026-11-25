"""Compact estimated context savings helpers.

The project intentionally labels these values as estimates: the helper uses a
conservative character-count approximation instead of model-specific tokenizers.
"""

import from __future__ { annotations }

import json;

import from pathlib { Path }

import from typing { Any, Iterable }

glob CHARS_PER_TOKEN: any = 4;

"""Estimate token count with a conservative 4 chars/token approximation."""
def estimate_tokens(value: Any) -> int;

"""Estimate tokens for changed files using file sizes, not file contents."""
def estimate_file_tokens(repo_root: Path, files: Iterable[str]) -> int;

def _token_counts(
    original_context: Any | None,
    returned_context: Any | None,
    original_tokens: int | None,
    returned_tokens: int | None,
) -> tuple[int, int];

def _savings(baseline: int, returned: int) -> dict[str, int | bool] | None;

"""Return tiny savings metadata, or None when no baseline is available."""
def estimate_context_savings(
    *,
    original_context: Any | None = None,
    returned_context: Any | None = None,
    original_tokens: int | None = None,
    returned_tokens: int | None = None,
) -> dict[str, int | bool] | None;

"""Attach compact ``context_savings`` metadata when it can be estimated.

    With *call* given, the same estimate is also appended to the opt-in
    context history log (#813). That does nothing unless
    ``CRG_CONTEXT_HISTORY`` is on; see ``context_history.py``.
    """
def attach_context_savings(
    result: dict[str, Any],
    *,
    original_context: Any | None = None,
    original_tokens: int | None = None,
    returned_context: Any | None = None,
    returned_tokens: int | None = None,
    call: CallInfo | None = None,
) -> dict[str, Any];

"""Format a one-line human summary for CLI output."""
def format_context_savings(estimate: dict[str, Any] | None) -> str | None;

"""Compact integer formatting: 1234 -> '1.2k', 9876 -> '9.9k', 500 -> '500'."""
def _fmt_compact(n: int) -> str;

"""Pull a per-category token estimate from a detect-changes / review response.

    Only fields that exist and have content are reported, so the breakdown
    line stays meaningful instead of padding with zeros.
    """
def _breakdown_from_response(response: dict[str, Any]) -> dict[str, int];

"""Calibrate the chars/4 estimate against a real model tokenizer.

    Returns ``{"verified_baseline": int, "verified_returned": int,
    "verified_saved": int, "verified_percent": int}`` or ``None`` if
    tiktoken is not installed. Reads every changed file's content (unlike
    the stat-only ``estimate_file_tokens``) so the numbers reflect what
    an agent would actually consume.
    """
def verify_with_tiktoken(
    repo_root: "Path | str",
    changed_files: Iterable[str],
    response: Any,
    encoding_name: str = "cl100k_base",
) -> dict[str, int] | None;

"""Format the savings estimate as a boxed multi-line CLI panel.

    Example output (width=60)::

        ┌──────────────── Token Savings ────────────────┐
        │ Full context would be: 12,932 tokens          │
        │ Graph context used:       773 tokens          │
        │ Saved:                 12,159 tokens (~94%)   │
        │ Breakdown: Functions 580 · Tests 120 · ...    │
        └───────────────────────────────────────────────┘

    All numbers are labelled as estimates upstream (``estimated: true`` in the
    metadata dict) because the project uses a 4-chars-per-token approximation,
    not model-specific tokenization.

    Args:
        estimate: The ``context_savings`` dict from a tool response.
        original_tokens: Optional override for the naive baseline.
        returned_tokens: Optional override for the graph response size.
        response: When provided, breakdown is auto-derived from common keys
            (``changed_functions``, ``affected_flows``, ``test_gaps``,
            ``review_priorities``, ``impacted_nodes``, ``edges``,
            ``source_snippets``, ``imports``).
        breakdown: Explicit ``{label: tokens}`` map; takes precedence over
            ``response``-derived breakdown when both are provided.
        title: Title centered in the top border.
        width: Total panel width, capped at terminal width if larger.

    Returns:
        The panel as a single ``\\n``-joined string, or ``None`` when there
        is nothing meaningful to display.
    """
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
