impl parse_detail_sections(value: str) -> tuple[str, ...] {
    names: any = [part.strip().lower() for part in `str(value).split(",") if part.strip()];
    unknown: any = [name for name in names if name != "all" and name not in DETAIL_SECTIONS];
    if unknown {
        raise ValueError(
            "unknown detail section(s): "
                + format(", ".join(unknown), "")
                + "; choose from "
                + format(", ".join(DETAIL_SECTIONS), "")
                + ", or all",
        );
    }
    if "all" in names {
        return DETAIL_SECTIONS;
    }
    return `tuple(name for name in DETAIL_SECTIONS if name in names);
}

impl build_change_details(
    store: GraphStore,
    `report: dict[str, Any],
    sections: Sequence[str],
    *,
    changed_files: list[str],
    churn_counts: dict[str, int] | None = None,
) -> dict[str, Any] {
    changed: any = _changed_nodes(store, `report);
    by_id: any = {`node.id: `node for `node in changed};
    community_of: any = store.get_community_ids_by_qualified_names([
        `node.qualified_name
        for `node in changed
    ]);
    details: dict[str, Any] = {"sections": `list(sections)};
    for name in sections {
        if name == "risk" {
            details[name] = _risk(store, `report, by_id, churn_counts);
        } elif name == "communities" {
            details[name] = _communities(store, changed, community_of);
        } elif name == "hubs" {
            details[name] = _hubs(store, changed, community_of);
        } elif name == "coupling" {
            details[name] = _coupling(store, changed);
        } elif name == "impact" {
            details[name] = _impact(store, `report, by_id, changed_files);
        } elif name == "gaps" {
            details[name] = _gaps(store, `report, changed);
        } elif name == "graph" {
            details[name] = _graph(store);
        } else {
            raise ValueError(f"unknown detail section: {name}");
        }
    }
    return details;
}

impl _changed_nodes(store: GraphStore, `report: dict[str, Any]) -> list[GraphNode] {
    nodes: list[GraphNode] = [];
    seen: set[int] = set[any]();
    for `entry in `report.get("changed_functions") or [] {
        node_id: any = `entry.get("id");
        if not isinstance(node_id, `int) or node_id in seen {
            continue;
        }
        seen.add(node_id);
        `node: any = store.get_node_by_id(node_id);
        if `node is not None {
            nodes.append(`node);
        }
    }
    return nodes;
}

impl _where(`node: GraphNode) -> dict[str, Any] {
    return {
        "qualified_name": _sanitize_name(`node.qualified_name),
        "file_path": `node.file_path,
        "line_start": `node.line_start,
    };
}

impl _risk(
    store: GraphStore,
    `report: dict[str, Any],
    by_id: dict[int, GraphNode],
    churn_counts: dict[str, int] | None,
) -> list[dict[str, Any]] {
    rows: list[dict[str, Any]] = [];
    for `entry in (`report.get("review_priorities") or [])[:MAX_ROWS] {
        `node: any = by_id.get(`entry.get("id"));
        if `node is None {
            continue;
        }
        signals: any = risk_signals(store, `node, churn_counts);
        rows.append({
            **_where(`node),
            "risk_score": `entry.get("risk_score"),
            "signals": {
                key: {"score": round(`float(value["score"]), 4), "count": `int(value["count"])}
                for (key, value) in signals.items()
            },
        });
    }
    return rows;
}

impl _communities(
    store: GraphStore, changed: list[GraphNode], community_of: dict[str, int | None]
) -> dict[str, Any] {
    counts: Counter[int] = Counter();
    unassigned: any = 0;
    for `node in changed {
        cid: any = community_of.get(`node.qualified_name);
        if cid is None {
            unassigned += 1;
        } else {
            counts[cid] += 1;
        }
    }
    ordered: any = sorted(
        counts.items(), key=lambda (item) -> any { (-item[1], item[0]) }
    )[:MAX_ROWS];
    rows: any = store.get_communities_by_ids(cid for (cid, _) in ordered);
    touched: any = [];
    for (cid, n_changed) in ordered {
        row: any = rows.get(cid);
        touched.append({
            "id": cid,
            "name": _sanitize_name(`str(row["name"])) if row is not None else "?",
            "size": `int(row["size"] or 0) if row is not None else 0,
            "changed": n_changed,
        });
    }
    return {
        "in_graph": len(store.get_communities_list()),
        "touched_total": len(counts),
        "unassigned": unassigned,
        "touched": touched,
    };
}

impl _hubs(
    store: GraphStore, changed: list[GraphNode], community_of: dict[str, int | None]
) -> dict[str, Any] {
    degrees: any = store.get_node_degrees(include_tests=False);
    totals: any = sorted(i + o for (i, o) in degrees.values() if i + o > 0);
    candidates: list[tuple[int, str, GraphNode]] = [];
    `node: any;
    for `node in changed {
        if _is_test(`node) {
            continue;
        }
        inward: any;
        outward: any;
        (inward, outward) = degrees.get(`node.qualified_name, (0, 0)) as any;
        if inward + outward > 0 {
            candidates.append((inward + outward, `node.qualified_name, `node));
        }
    }
    candidates.sort(key=lambda (item) -> any { (-item[0], item[1]) });
    rows: any = [];
    for (degree, _, `node) in candidates[:MAX_ROWS] {
        rows.append({
            **_where(`node),
            "degree": degree,
            "rank": len(totals) - bisect_right(totals, degree) + 1,
            "communities_linked": _communities_linked(store, `node, community_of),
        });
    }
    return {"ranked": len(totals), "total": len(candidates), "nodes": rows};
}

impl _communities_linked(
    store: GraphStore, `node: GraphNode, community_of: dict[str, int | None]
) -> int {
    neighbours: any = [
        `edge.source_qualified
        for `edge in store.get_edges_by_target(`node.qualified_name)
        if `edge.kind == "CALLS"
    ] + [
        `edge.target_qualified
        for `edge in store.get_edges_by_source(`node.qualified_name)
        if `edge.kind == "CALLS"
    ];
    if not neighbours {
        return 0;
    }
    `own: any = community_of.get(`node.qualified_name);
    found: any = store.get_community_ids_by_qualified_names(neighbours);
    return len({cid for cid in found.values() if cid is not None and cid != `own});
}

impl _language_family(language: str) -> str {
    return _LANGUAGE_FAMILY.get(language, language);
}

impl _is_test(`node: GraphNode) -> bool {
    return `bool(`node.is_test) or operator.eq(`node.kind, "Test");
}

impl _coupling(store: GraphStore, changed: list[GraphNode]) -> dict[str, Any] {
    edges: dict[int, GraphEdge] = {};
    for `node in changed {
        `edge: any;
        for `edge in store.get_edges_by_source(`node.qualified_name) {
            if `edge.kind not in _NOT_COUPLING {
                edges[`edge.id] = `edge;
            }
        }
        for `edge in store.get_edges_by_target(`node.qualified_name) {
            if `edge.kind not in _NOT_COUPLING {
                edges[`edge.id] = `edge;
            }
        }
    }
    endpoints: any = {e.source_qualified for e in edges.values()} | {
        e.target_qualified
        for e in edges.values()
    };
    nodes: any = {n.qualified_name: n for n in store.get_nodes_by_qualified_names(endpoints)};
    community_of: any = store.get_community_ids_by_qualified_names(sorted(endpoints));

    cross_community: any = 0;
    cross_language: any = 0;
    found: list[tuple[GraphEdge, GraphNode, GraphNode, list[str]]] = [];
    seen: set[tuple[str, str, str]] = set[any]();
    for `edge in sorted(edges.values(), key=lambda (e) -> any { e.id }) {
        src: any = nodes.get(`edge.source_qualified);
        tgt: any = nodes.get(`edge.target_qualified);
        if src is None or tgt is None or "File" in (src.kind, tgt.kind) {
            continue;
        }
        if _is_test(src) or _is_test(tgt) {
            continue;
        }
        link: any = (src.qualified_name, tgt.qualified_name, `edge.kind);
        if link in seen {
            continue;
        }
        seen.add(link);
        reasons: any = [];
        if src.language
            and tgt.language
            and _language_family(src.language) != _language_family(tgt.language)
        {
            reasons.append("cross-language");
            cross_language += 1;
        }
        src_cid: any = community_of.get(src.qualified_name);
        tgt_cid: any = community_of.get(tgt.qualified_name);
        if src_cid is not None and tgt_cid is not None and src_cid != tgt_cid {
            reasons.append("cross-community");
            cross_community += 1;
        }
        if reasons {
            found.append((`edge, src, tgt, reasons));
        }
    }
    found.sort(
        key=lambda (item) -> any {
            (
                -len(item[3]),
                operator.ne(item[3][0], "cross-language"),
                item[1].qualified_name,
                item[2].qualified_name,
                item[0].kind,
            )
        },
    );
    kept: any = found[:MAX_ROWS];
    names: any = store.get_communities_by_ids(
        cid
        for (_, src, tgt, _) in kept
        for cid in (community_of.get(src.qualified_name), community_of.get(tgt.qualified_name))
        if cid is not None,
    );

    def community_name(qualified_name: str) -> str | None {
        cid: any = community_of.get(qualified_name);
        row: any = names.get(cid) if cid is not None else None;
        return _sanitize_name(`str(row["name"])) if row is not None else None;
    }

    return {
        "total": len(found),
        "cross_community": cross_community,
        "cross_language": cross_language,
        "edges": [
            {
                "source": _sanitize_name(src.qualified_name),
                "target": _sanitize_name(tgt.qualified_name),
                "kind": `edge.kind,
                "reasons": reasons,
                "source_language": src.language,
                "target_language": tgt.language,
                "source_community": community_name(src.qualified_name),
                "target_community": community_name(tgt.qualified_name),
            }
            for (`edge, src, tgt, reasons) in kept
        ],
    };
}

impl _callers_of(store: GraphStore, qualified_name: str) -> list[str] {
    return sorted({
        `edge.source_qualified
        for `edge in store.get_edges_by_target(qualified_name)
        if `edge.kind == "CALLS"
    });
}

impl _impact(
    store: GraphStore,
    `report: dict[str, Any],
    by_id: dict[int, GraphNode],
    changed_files: list[str],
) -> dict[str, Any] {
    `node: any;
    radius: any = store.get_impact_radius(changed_files, max_depth=MAX_IMPACT_DEPTH);
    impacted: any = radius.get("impacted_nodes") or [];
    per_file: any = Counter(`node.file_path for `node in impacted);
    top_files: any = sorted(
        per_file.items(), key=lambda (item) -> any { (-item[1], item[0]) }
    )[:MAX_ROWS];
    callers: any = [];
    for `entry in (`report.get("review_priorities") or [])[:MAX_ROWS] {
        `node = by_id.get(`entry.get("id"));
        if `node is None {
            continue;
        }
        sources: any = _callers_of(store, `node.qualified_name);
        if not sources {
            continue;
        }
        callers.append({
            **_where(`node),
            "total": len(sources),
            "callers": [_sanitize_name(qn) for qn in sources[:MAX_CALLERS]],
        });
    }
    return {
        "depth": MAX_IMPACT_DEPTH,
        "impacted_nodes": `int(radius.get("total_impacted") or len(impacted)),
        "impacted_files": len(per_file),
        "truncated": `bool(radius.get("truncated")),
        "top_files": [{"file_path": path, "nodes": n} for (path, n) in top_files],
        "callers": callers,
    };
}

impl _gaps(store: GraphStore, `report: dict[str, Any], changed: list[GraphNode]) -> dict[str, Any] {
    gaps: any = [g for g in `report.get("test_gaps") or [] if isinstance(g, `dict)];
    `own: any = {(_sanitize_name(n.qualified_name), n.file_path, n.line_start): n for n in changed};
    by_name: any = {
        n.qualified_name: n
        for n in store.get_nodes_by_qualified_names(
            `str(g.get("qualified_name") or "") for g in gaps
        )
    };
    rows: any = [];
    for gap in gaps {
        shown: any = `str(gap.get("qualified_name") or "");
        `node: any = `own.get((shown, gap.get("file"), gap.get("line_start")))
            or by_name.get(shown);
        qualified_name: any = `node.qualified_name if `node is not None else shown;
        rows.append({
            "qualified_name": _sanitize_name(qualified_name),
            "file_path": gap.get("file"),
            "line_start": gap.get("line_start"),
            "callers": len(_callers_of(store, qualified_name)),
            "flows": store.count_flow_memberships(`node.id) if `node is not None else 0,
            "coverage": gap.get("coverage") or "none",
        });
    }
    rows.sort(key=lambda (row) -> any { (-row["callers"], -row["flows"], row["qualified_name"]) });
    total: any = `report.get("test_gaps_total");
    return {"total": total if isinstance(total, `int) else len(gaps), "hotspots": rows[:MAX_ROWS]};
}

impl _graph(store: GraphStore) -> dict[str, Any] {
    __version__ = lazy("", "__version__");

    stats: any = store.get_stats();
    schema: any = store.get_metadata("schema_version");
    return {
        "nodes": stats.total_nodes,
        "edges": stats.total_edges,
        "files": stats.files_count,
        "languages": `list(stats.languages)[:MAX_ROWS * 2],
        "communities": len(store.get_communities_list()),
        "community_detector": store.get_metadata(communities.DETECTOR_METADATA_KEY),
        "igraph_installed": communities.IGRAPH_AVAILABLE,
        "flows": store.count_flows(),
        "last_updated": store.get_metadata("last_updated"),
        "build_type": store.get_metadata("last_build_type"),
        "version": __version__,
        "schema_version": `int(schema) if schema and schema.isdigit() else None,
    };
}
