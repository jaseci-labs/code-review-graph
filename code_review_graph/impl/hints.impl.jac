impl SessionState.init {
    self.tools_called = deque(maxlen=_MAX_TOOLS_HISTORY);
    self.nodes_queried = set[any]();
    self.files_touched = set[any]();
    self.inferred_intent = None;
    self.last_tool_time = 0.0;
}

impl SessionState.record_tool_call(tool_name: str) -> None {
    self.tools_called.append(tool_name);
    self.last_tool_time = time.time();
}

impl SessionState.record_nodes(node_ids: list[str]) -> None {
    for nid in node_ids {
        if len(self.nodes_queried) >= _MAX_NODES_TRACKED {
            break;
        }
        self.nodes_queried.add(nid);
    }
}

impl SessionState.record_files(files: list[str]) -> None {
    self.files_touched.update(files);
}

impl SessionState.__repr__ -> str {
    return (getattr(builtins.object, "__repr__") as any)(self);
}

impl SessionState.__eq__(other: any) -> bool {
    return self is other;
}

impl SessionState.__hash__ -> int {
    return id(self);
}

impl infer_intent(session: SessionState) -> str {
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

impl generate_hints(
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

impl _track_result(result: dict[str, Any], session: SessionState) -> None {
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

impl _build_next_steps(tool_name: str, session: SessionState) -> list[dict[str, str]] {
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

impl _extract_warnings(result: dict[str, Any]) -> list[str] {
    warnings: list[str] = [];
    test_gaps: any = result.get("test_gaps");
    if isinstance(test_gaps, `list) and test_gaps {
        names: any = [g.get("name", g) if isinstance(g, `dict) else `str(g) for g in test_gaps[:5]];
        warnings.append("Test coverage gaps: " + format(", ".join(names), ""));
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

impl _build_related(tool_name: str, result: dict[str, Any], session: SessionState) -> list[str] {
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

impl get_session -> SessionState {
    return _session;
}

impl reset_session -> None {
    _session = SessionState();
}
