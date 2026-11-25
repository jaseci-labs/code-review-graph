import from __future__ { annotations }

import builtins, time;

import from collections { deque }

import from typing { Any }

glob _INTENT_TOOLS: dict[str, set[str]] = {
    "reviewing": {
        "detect_changes_tool",
        "get_review_context_tool",
        "get_affected_flows_tool",
        "get_impact_radius_tool",
    },
    "debugging": {"query_graph_tool", "get_flow_tool", "semantic_search_nodes_tool"},
    "refactoring": {"refactor_tool", "apply_refactor_tool"},
    "exploring": {
        "list_communities_tool",
        "get_architecture_overview_tool",
        "list_flows_tool",
        "list_graph_stats_tool",
    },
};

glob _WORKFLOW: dict[str, list[dict[str, str]]] = {
    "list_flows_tool": [
        {
            "tool": "get_flow_tool",
            "suggestion": "Drill into a specific flow for step-by-step details",
        },
        {
            "tool": "get_affected_flows_tool",
            "suggestion": "Check which flows are affected by recent changes",
        },
        {"tool": "get_architecture_overview_tool", "suggestion": "See the high-level architecture"},
    ],
    "get_flow_tool": [
        {
            "tool": "query_graph_tool",
            "suggestion": "Inspect callers/callees of a step in this flow",
        },
        {"tool": "get_affected_flows_tool", "suggestion": "Check if changes affect this flow"},
        {"tool": "list_flows_tool", "suggestion": "Browse other execution flows"},
    ],
    "get_affected_flows_tool": [
        {"tool": "detect_changes_tool", "suggestion": "Get risk-scored change analysis"},
        {"tool": "get_flow_tool", "suggestion": "Inspect a specific affected flow"},
        {
            "tool": "get_review_context_tool",
            "suggestion": "Build a full review context for the changes",
        },
    ],
    "list_communities_tool": [
        {"tool": "get_community_tool", "suggestion": "Inspect a specific community's members"},
        {
            "tool": "get_architecture_overview_tool",
            "suggestion": "See cross-community coupling and warnings",
        },
        {"tool": "list_flows_tool", "suggestion": "See execution flows across communities"},
    ],
    "get_community_tool": [
        {"tool": "query_graph_tool", "suggestion": "Explore callers/callees of community members"},
        {"tool": "list_communities_tool", "suggestion": "Browse other communities"},
        {
            "tool": "get_architecture_overview_tool",
            "suggestion": "See how this community fits the architecture",
        },
    ],
    "get_architecture_overview_tool": [
        {"tool": "list_communities_tool", "suggestion": "Drill into individual communities"},
        {
            "tool": "detect_changes_tool",
            "suggestion": "See how recent changes affect the architecture",
        },
        {"tool": "list_flows_tool", "suggestion": "Explore execution flows"},
    ],
    "detect_changes_tool": [
        {
            "tool": "get_review_context_tool",
            "suggestion": "Build a full review context with source snippets",
        },
        {"tool": "get_affected_flows_tool", "suggestion": "See which execution flows are affected"},
        {"tool": "get_impact_radius_tool", "suggestion": "Expand the blast radius analysis"},
        {
            "tool": "refactor_tool",
            "suggestion": "Look for refactoring opportunities in changed code",
        },
    ],
    "refactor_tool": [
        {"tool": "query_graph_tool", "suggestion": "Verify call sites before applying a rename"},
        {"tool": "detect_changes_tool", "suggestion": "Check risk of the refactored code"},
        {"tool": "semantic_search_nodes_tool", "suggestion": "Find related symbols to also rename"},
    ],
    "semantic_search_nodes_tool": [
        {"tool": "query_graph_tool", "suggestion": "Inspect callers/callees of a search result"},
        {"tool": "get_flow_tool", "suggestion": "See the execution flow through a matched node"},
        {
            "tool": "get_impact_radius_tool",
            "suggestion": "Check the blast radius from matched nodes",
        },
    ],
};

glob _MAX_PER_CATEGORY: any = 3;

glob _MAX_TOOLS_HISTORY: any = 100;

glob _MAX_NODES_TRACKED: any = 1000;

obj SessionState {
    has tools_called: any,
        nodes_queried: any,
        files_touched: any,
        inferred_intent: any,
        last_tool_time: any;

    def init {
        self.tools_called = deque(maxlen=_MAX_TOOLS_HISTORY);
        self.nodes_queried = set[any]();
        self.files_touched = set[any]();
        self.inferred_intent = None;
        self.last_tool_time = 0.0;
    }

    def record_tool_call(tool_name: str) {
        self.tools_called.append(tool_name);
        self.last_tool_time = time.time();
    }

    def record_nodes(node_ids: list[str]) {
        for nid in node_ids {
            if len(self.nodes_queried) >= _MAX_NODES_TRACKED {
                break;
            }
            self.nodes_queried.add(nid);
        }
    }

    def record_files(files: list[str]) {
        self.files_touched.update(files);
    }

    def __repr__ -> str {
        return (getattr(builtins.object, "__repr__") as any)(self);
    }

    def __eq__(other: any) -> bool {
        return self is other;
    }

    def __hash__ -> int {
        return id(self);
    }
}

def infer_intent(session: SessionState) -> str {
    scores: dict[str, int];
    intent: any;
    if not session.tools_called {
        return "exploring";
    }
    recent: any = `list(session.tools_called)[-10:];
    scores = {intent: 0 for intent in _INTENT_TOOLS};
    for tool in recent {
        for (intent, tools) in _INTENT_TOOLS.items() {
            if tool in tools {
                scores[intent] += 1;
            }
        }
    }

    best: any = max(scores, key=lambda (k) -> any { scores[k] });
    if scores[best] == 0 {
        return "exploring";
    }
    return best;
}

def generate_hints(
    tool_name: str, result: dict[str, Any], session: SessionState
) -> dict[str, Any] {
    session.record_tool_call(tool_name);
    session.inferred_intent = infer_intent(session);

    next_steps: any = _build_next_steps(tool_name, session);
    warnings: any = _extract_warnings(result);
    related: any = _build_related(tool_name, result, session);
    _track_result(result, session);

    return {
        "next_steps": next_steps[:_MAX_PER_CATEGORY],
        "related": related[:_MAX_PER_CATEGORY],
        "warnings": warnings[:_MAX_PER_CATEGORY],
    };
}

def _track_result(result: dict[str, Any], session: SessionState) {
    key: any;
    for key in ("changed_files", "impacted_files") {
        files: any = result.get(key);
        if isinstance(files, `list) {
            session.record_files([f for f in files if isinstance(f, `str)]);
        }
    }
    node_ids: list[str] = [];
    for key in ("results", "changed_nodes", "impacted_nodes") {
        items: any = result.get(key);
        if isinstance(items, `list) {
            for item in items {
                if isinstance(item, `dict) {
                    qn: any = item.get("qualified_name");
                    if qn {
                        node_ids.append(qn);
                    }
                }
            }
        }
    }
    if node_ids {
        session.record_nodes(node_ids);
    }
}

def _build_next_steps(tool_name: str, session: SessionState) -> list[dict[str, str]] {
    called: any = `set(session.tools_called);
    candidates: any = _WORKFLOW.get(tool_name, []);
    out: list[dict[str, str]] = [];
    for c in candidates {
        if c["tool"] not in called {
            out.append(c);
        }
    }
    return out;
}

def _extract_warnings(result: dict[str, Any]) -> list[str] {
    warnings: list[str] = [];
    test_gaps: any = result.get("test_gaps");
    if isinstance(test_gaps, `list) and test_gaps {
        names: any = [g.get("name", g) if isinstance(g, `dict) else `str(g) for g in test_gaps[:5]];
        warnings.append(f"Test coverage gaps: {", ".join(names)}");
    }
    risk: any = result.get("risk_score");
    if isinstance(risk, (`int, `float)) and risk > 0.7 {
        warnings.append(f"High risk score ({risk:.2f}) — review carefully");
    }
    arch_warnings: any = result.get("warnings");
    if isinstance(arch_warnings, `list) {
        for w in arch_warnings[:3] {
            if isinstance(w, `str) {
                warnings.append(w);
            } elif isinstance(w, `dict) and "message" in w {
                warnings.append(w["message"]);
            }
        }
    }

    return warnings;
}

def _build_related(tool_name: str, result: dict[str, Any], session: SessionState) -> list[str] {
    related: list[str] = [];
    seen: set[str] = set[any]();
    impacted: any = result.get("impacted_files");
    if isinstance(impacted, `list) {
        for f in impacted {
            if isinstance(f, `str) and f not in session.files_touched and f not in seen {
                related.append(f);
                seen.add(f);
                if len(related) >= _MAX_PER_CATEGORY {
                    break;
                }
            }
        }
    }

    return related;
}

glob _session: any;

with entry {
    _session = SessionState();
}

def get_session -> SessionState {
    return _session;
}

def reset_session {
    _session = SessionState();
}
