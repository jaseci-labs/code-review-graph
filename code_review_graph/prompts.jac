import from __future__ { annotations }

"""MCP prompt templates for Code Review Graph.

Provides 5 pre-built prompt workflows, all enforcing token-efficient
detail_level="minimal" first patterns with get_minimal_context_tool entry point.

1. review_changes   - pre-commit review using detect_changes_tool + affected_flows
2. architecture_map - architecture docs using communities, flows, Mermaid
3. debug_issue      - guided debugging using search, flow tracing
4. onboard_developer - new dev orientation using stats, architecture, flows
5. pre_merge_check  - PR readiness with risk scoring, test gaps, dead code
"""

import from fastmcp.prompts { Message }

glob _TOKEN_EFFICIENCY_PREAMBLE: any = "## Rules for Token-Efficient Graph Usage\n1. ALWAYS call `get_minimal_context_tool` first with a task description.\n2. Use `detail_level=\"minimal\"` on all tool calls unless the minimal output is insufficient.\n3. Only escalate to `detail_level=\"standard\"` or `\"verbose\"` for the specific entities that need deeper inspection.\n4. Never request more than 3 tool calls per turn unless absolutely necessary.\n5. Prefer targeted queries (query_graph_tool with a specific symbol) over broad scans (list_communities_tool with full members).\n6. When reviewing changes: detect_changes_tool(detail_level=\"minimal\") → only expand on high-risk items.\n";

"""Wrap content as a single-message user prompt.

    fastmcp >=3.2 rejects raw dicts in prompt return values; each message
    must be a ``Message`` instance (or a plain ``str``). We standardise on
    ``Message`` so role is explicit and future multi-turn prompts compose
    naturally.
    """
def _user(content: str) -> list[Message];

"""Pre-commit review workflow.

    Args:
        base: Git ref to diff against. Default: HEAD~1.
    """
def review_changes_prompt(base: str = "HEAD~1") -> list[Message];

"""Architecture documentation workflow."""
def architecture_map_prompt -> list[Message];

"""Guided debugging workflow.

    Args:
        description: Description of the issue to debug.
    """
def debug_issue_prompt(description: str = "") -> list[Message];

"""New developer orientation workflow."""
def onboard_developer_prompt -> list[Message];

"""PR readiness check workflow.

    Args:
        base: Git ref to diff against. Default: HEAD~1.
    """
def pre_merge_check_prompt(base: str = "HEAD~1") -> list[Message];
