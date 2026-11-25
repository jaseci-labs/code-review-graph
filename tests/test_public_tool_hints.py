"""Recommendations must name tools exposed by the MCP server."""

import asyncio

from code_review_graph import main
from code_review_graph.hints import _INTENT_TOOLS, _WORKFLOW, SessionState, generate_hints


def test_all_hints_name_registered_mcp_tools():
    registered = {tool.name for tool in asyncio.run(main.mcp.list_tools())}
    assert registered
    referenced = set(_WORKFLOW)
    for intent in _INTENT_TOOLS.values():
        referenced.update(intent)
    for tool_name in _WORKFLOW:
        hints = generate_hints(tool_name, {}, SessionState())
        referenced.update(step["tool"] for step in hints["next_steps"])
    assert referenced <= registered, sorted(referenced - registered)
