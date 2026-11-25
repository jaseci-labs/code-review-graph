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
def _user(content: str) -> list[Message] {
    return [Message(role="user", content=content)];
}

"""Pre-commit review workflow.

    Args:
        base: Git ref to diff against. Default: HEAD~1.
    """
def review_changes_prompt(base: str = "HEAD~1") -> list[Message] {
    return _user(
        f"{_TOKEN_EFFICIENCY_PREAMBLE}\n## Review Workflow\n1. Call `get_minimal_context_tool(task=\"review changes against {base}\", base=\"{base}\")` to get risk overview.\n2. If risk is \"low\": call `detect_changes_tool(base=\"{base}\", detail_level=\"minimal\")` → report summary + any test gaps.\n3. If risk is \"medium\" or \"high\":\n   a. Call `detect_changes_tool(base=\"{base}\", detail_level=\"standard\")` for full change list.\n   b. For each high-risk function, call `query_graph_tool(pattern=\"callers_of\", target=<func>, detail_level=\"minimal\")`.\n   c. Call `get_affected_flows_tool(base=\"{base}\", detail_level=\"minimal\")` only if >3 changed functions.\n4. Summarize: risk level, what changed, test gaps, specific improvements needed.\n\nDo NOT call get_review_context_tool unless you need source code snippets for a specific function.",
    );
}

"""Architecture documentation workflow."""
def architecture_map_prompt -> list[Message] {
    return _user(
        f"{_TOKEN_EFFICIENCY_PREAMBLE}\n## Architecture Mapping Workflow\n1. Call `get_minimal_context_tool(task=\"map architecture\")`.\n2. Call `get_architecture_overview_tool(detail_level=\"minimal\")` for community coupling summary.\n3. Call `list_flows_tool(detail_level=\"minimal\")` for critical flow names + criticality scores.\n4. Only call `get_community_tool(name=<X>, detail_level=\"standard\")` for the 1-2 communities the user is most interested in.\n5. Produce a concise Mermaid diagram showing communities as boxes and key flows as arrows.",
    );
}

"""Guided debugging workflow.

    Args:
        description: Description of the issue to debug.
    """
def debug_issue_prompt(description: str = "") -> list[Message] {
    desc_part: any = description or "<description>";
    return _user(
        f"{_TOKEN_EFFICIENCY_PREAMBLE}\n## Debug Workflow\n1. Call `get_minimal_context_tool(task=\"debug: {desc_part}\")`.\n2. Call `semantic_search_nodes_tool(query=<keywords from description>, detail_level=\"minimal\", limit=5)`.\n3. For the top 1-2 results, call `query_graph_tool(pattern=\"callers_of\", target=<name>, detail_level=\"minimal\")`.\n4. If the issue involves execution flow: call `get_flow_tool(name=<relevant flow>)` for the single most relevant flow.\n5. Only call `get_review_context_tool` or `get_impact_radius_tool` if you need to trace the blast radius of a specific change.",
    );
}

"""New developer orientation workflow."""
def onboard_developer_prompt -> list[Message] {
    return _user(
        f"{_TOKEN_EFFICIENCY_PREAMBLE}\n## Onboarding Workflow\n1. Call `get_minimal_context_tool(task=\"onboard developer\")`.\n2. Call `list_graph_stats_tool()` for technology overview.\n3. Call `get_architecture_overview_tool(detail_level=\"minimal\")` for the 30-second mental model.\n4. Call `list_communities_tool(detail_level=\"minimal\")` — present as a table of module names + sizes.\n5. Call `list_flows_tool(detail_level=\"minimal\")` — highlight the top 3 critical flows.\n6. Only drill into a specific community or flow if the developer asks.",
    );
}

"""PR readiness check workflow.

    Args:
        base: Git ref to diff against. Default: HEAD~1.
    """
def pre_merge_check_prompt(base: str = "HEAD~1") -> list[Message] {
    return _user(
        f"{_TOKEN_EFFICIENCY_PREAMBLE}\n## Pre-Merge Check Workflow\n1. Call `get_minimal_context_tool(task=\"pre-merge check\", base=\"{base}\")`.\n2. Call `detect_changes_tool(base=\"{base}\", detail_level=\"minimal\")` for risk score and test gaps.\n3. If risk > 0.4: call `get_affected_flows_tool(base=\"{base}\", detail_level=\"minimal\")`.\n4. If test_gap_count > 0: call `query_graph_tool(pattern=\"tests_for\", target=<each untested function>, detail_level=\"minimal\")` for up to 3 functions.\n5. Call `refactor_tool(mode=\"dead_code\", detail_level=\"minimal\")` to check for newly dead code.\n6. Only call `find_large_functions_tool` or `get_impact_radius_tool` if risk > 0.7.\n7. Output: GO/NO-GO recommendation with 1-sentence justification + list of required follow-ups.",
    );
}
