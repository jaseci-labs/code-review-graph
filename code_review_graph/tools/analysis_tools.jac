import from __future__ { annotations }

import from typing { Any }

glob _FETCH_ALL: any = 10 ** 9;

glob _MAX_HUB_NODES: any = 100;

glob _MAX_BRIDGE_NODES: any = 100;

glob _MAX_SURPRISING: any = 100;

glob _MAX_GAPS_PER_CATEGORY: any = 50;

glob _MINIMAL_HUB_FIELDS: any = ("name", "kind", "total_degree");

glob _MINIMAL_BRIDGE_FIELDS: any = ("name", "kind", "betweenness");

glob _MINIMAL_SURPRISE_FIELDS: any = ("source", "target", "edge_kind", "surprise_score");

glob _MINIMAL_GAP_FIELDS: any = (
    "name",
    "qualified_name",
    "community_id",
    "size",
    "degree",
    "load_time",
);

def _project(rows: list[dict[str, Any]], fields: tuple[str, ...]) -> list[dict[str, Any]] {
    return [{k: r[k] for k in fields if k in r} for r in rows];
}

def get_hub_nodes_func(
    repo_root: str | None = None, top_n: int = 10, detail_level: str = "standard"
) -> dict[str, Any] {
    _validate_positive_int(top_n, "top_n");

    store: any;
    _root: any;
    (store, _root) = _get_store(repo_root or None) as any;
    try {
        hubs: any;
        total: any;
        truncated: any;
        (hubs, total, truncated) = _bounded(
            find_hub_nodes(store, top_n=_FETCH_ALL), top_n, _MAX_HUB_NODES
        ) as any;
        if detail_level == "minimal" {
            hubs = _project(hubs, _MINIMAL_HUB_FIELDS);
        }
        return {
            "status": "ok",
            "summary": f"{total} hub node(s) ranked by degree" + _shown_of(len(hubs), total),
            "hub_nodes": hubs,
            "count": len(hubs),
            "total": total,
            "truncated": truncated,
            "next_tool_suggestions": [
                "get_impact_radius_tool -- check blast radius of a hub",
                "query_graph_tool callers_of -- see what calls a hub",
                "get_bridge_nodes_tool -- find architectural chokepoints",
            ],
        };
    } finally {
        store.close();
    }
}

def get_bridge_nodes_func(
    repo_root: str | None = None, top_n: int = 10, detail_level: str = "standard"
) -> dict[str, Any] {
    _validate_positive_int(top_n, "top_n");

    store: any;
    _root: any;
    (store, _root) = _get_store(repo_root or None) as any;
    try {
        bridges: any;
        total: any;
        truncated: any;
        (bridges, total, truncated) = _bounded(
            find_bridge_nodes(store, top_n=_FETCH_ALL), top_n, _MAX_BRIDGE_NODES
        ) as any;
        if detail_level == "minimal" {
            bridges = _project(bridges, _MINIMAL_BRIDGE_FIELDS);
        }
        return {
            "status": "ok",
            "summary": f"{total} bridge node(s) ranked by betweenness"
                + _shown_of(len(bridges), total),
            "bridge_nodes": bridges,
            "count": len(bridges),
            "total": total,
            "truncated": truncated,
            "next_tool_suggestions": [
                "get_hub_nodes_tool -- find most connected nodes",
                "get_impact_radius_tool -- check blast radius",
                "detect_changes_tool -- see if bridges are affected",
            ],
        };
    } finally {
        store.close();
    }
}

def get_knowledge_gaps_func(
    repo_root: str | None = None, max_per_category: int = 15, detail_level: str = "standard"
) -> dict[str, Any] {
    category: any;
    rows: any;
    _validate_positive_int(max_per_category, "max_per_category");

    store: any;
    `root: any;
    (store, `root) = _get_store(repo_root or None) as any;
    try {
        raw: any = find_knowledge_gaps(store, repo_root=`root);
        totals: any = {category: len(rows) for (category, rows) in raw.items()};

        gaps: dict[str, list[dict[str, Any]]] = {};
        truncated: any = False;
        for (category, rows) in raw.items() {
            visible: any;
            _total: any;
            cut: any;
            (visible, _total, cut) = _bounded(
                rows, max_per_category, _MAX_GAPS_PER_CATEGORY
            ) as any;
            if detail_level == "minimal" {
                visible = _project(visible, _MINIMAL_GAP_FIELDS);
            }
            gaps[category] = visible;
            truncated = truncated or cut;
        }

        total: any = sum(totals.values());
        return {
            "status": "ok",
            "summary": totals,
            "gaps": gaps,
            "total_gaps": total,
            "truncated": truncated,
            "next_tool_suggestions": [
                "refactor_tool dead_code -- find unused symbols",
                "get_hub_nodes_tool -- find high-impact nodes",
                "get_suggested_questions_tool -- review prompts",
            ],
        };
    } finally {
        store.close();
    }
}

def get_surprising_connections_func(
    repo_root: str | None = None, top_n: int = 15, detail_level: str = "standard"
) -> dict[str, Any] {
    _validate_positive_int(top_n, "top_n");

    store: any;
    _root: any;
    (store, _root) = _get_store(repo_root or None) as any;
    try {
        surprises: any;
        total: any;
        truncated: any;
        (surprises, total, truncated) = _bounded(
            find_surprising_connections(store, top_n=_FETCH_ALL), top_n, _MAX_SURPRISING
        ) as any;
        if detail_level == "minimal" {
            surprises = _project(surprises, _MINIMAL_SURPRISE_FIELDS);
        }
        return {
            "status": "ok",
            "summary": f"{total} surprising connection(s) ranked by surprise score"
                + _shown_of(len(surprises), total),
            "surprising_connections": surprises,
            "count": len(surprises),
            "total": total,
            "truncated": truncated,
            "next_tool_suggestions": [
                "get_architecture_overview_tool -- community structure",
                "query_graph_tool callers_of -- trace the coupling",
                "get_bridge_nodes_tool -- find chokepoints",
            ],
        };
    } finally {
        store.close();
    }
}

def get_suggested_questions_func(repo_root: str | None = None) -> dict[str, Any] {
    store: any;
    _root: any;
    (store, _root) = _get_store(repo_root or None) as any;
    try {
        questions: any = generate_suggested_questions(store);
        by_priority: dict[str, list[dict[str, Any]]] = {"high": [], "medium": [], "low": []};
        for q in questions {
            prio: any = q.get("priority", "medium");
            if prio in by_priority {
                by_priority[prio].append(q);
            }
        }
        return {
            "questions": questions,
            "count": len(questions),
            "by_priority": {k: len(v) for (k, v) in by_priority.items()},
            "next_tool_suggestions": [
                "get_knowledge_gaps_tool -- structural weaknesses",
                "detect_changes_tool -- risk-scored review",
                "get_architecture_overview_tool -- community map",
            ],
        };
    } finally {
        store.close();
    }
}
