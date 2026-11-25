impl _cap_members(community: dict[str, Any], max_members: int) -> dict[str, Any] {
    capped: any = `dict(community);
    for key in ("members", "member_details") {
        rows: any = capped.get(key);
        if not isinstance(rows, `list) {
            continue;
        }
        visible: any;
        total: any;
        truncated: any;
        (visible, total, truncated) = _bounded(rows, max_members, _MAX_MEMBERS) as any;
        capped[key] = visible;
        if truncated {
            capped[f"{key}_total"] = total;
            capped["members_truncated"] = True;
        }
    }
    return capped;
}

impl list_communities_func(
    repo_root: str | None = None,
    sort_by: str = "size",
    min_size: int = 0,
    detail_level: str = "standard",
    max_results: int = 50,
    max_members: int = 10,
) -> dict[str, Any] {
    _validate_positive_int(max_results, "max_results");
    _validate_positive_int(max_members, "max_members");

    store: any;
    `root: any;
    (store, `root) = _get_store(repo_root) as any;
    try {
        communities: any;
        total: any;
        truncated: any;
        (communities, total, truncated) = _bounded(
            get_communities(store, sort_by=sort_by, min_size=min_size),
            max_results,
            _MAX_COMMUNITIES,
        ) as any;
        if detail_level == "minimal" {
            communities = [
                {"name": c["name"], "size": c["size"], "cohesion": c["cohesion"]}
                for c in communities
            ];
        } else {
            communities = [_cap_members(c, max_members) for c in communities];
        }
        result: dict[str, object] = {
            "status": "ok",
            "summary": f"Found {total} communities" + _shown_of(len(communities), total),
            "communities": communities,
            "total": total,
            "truncated": truncated,
        };
        result["_hints"] = generate_hints("list_communities_tool", result, get_session());
        return result;
    } except Exception as exc {
        return {"status": "error", "error": `str(exc)};
    } finally {
        store.close();
    }
}

impl get_community_func(
    community_name: str | None = None,
    community_id: int | None = None,
    include_members: bool = False,
    repo_root: str | None = None,
    max_members: int = 25,
) -> dict[str, Any] {
    _validate_positive_int(max_members, "max_members");

    store: any;
    `root: any;
    (store, `root) = _get_store(repo_root) as any;
    try {
        community: dict | None = None;
        all_communities: any = get_communities(store);

        if community_id is not None {
            c: any;
            for c in all_communities {
                if c.get("id") == community_id {
                    community = c;
                    break;
                }
            }
        } elif community_name is not None {
            for c in all_communities {
                if community_name.lower() in c["name"].lower() {
                    community = c;
                    break;
                }
            }
        }

        if community is None {
            return {
                "status": "not_found",
                "summary": "No community found matching the given criteria.",
            };
        }

        if include_members {
            cid: any = community.get("id");
            if cid is not None {
                member_nodes: any = store.get_nodes_by_community_id(cid);
                members: any = [node_to_dict(n) for n in member_nodes];
                community["member_details"] = members;
            }
        }

        community = _cap_members(community, max_members);

        result: any = {
            "status": "ok",
            "summary": "Community '"
                + format(community["name"], "")
                + "': "
                + format(community["size"], "")
                + " nodes, cohesion "
                + format(community["cohesion"], ".4f"),
            "community": community,
        };
        result["_hints"] = generate_hints("get_community_tool", result, get_session());
        return result;
    } except Exception as exc {
        return {"status": "error", "error": `str(exc)};
    } finally {
        store.close();
    }
}

impl _minimal_overview(overview: dict[str, Any]) -> dict[str, Any] {
    communities: any = [
        {k: c[k] for k in _MINIMAL_COMMUNITY_FIELDS if k in c}
        for c in overview.get("communities", [])
    ];
    id_to_name: any = {c["id"]: c["name"] for c in communities if "id" in c};

    edge_pair_counts: Counter[tuple[int, int]] = Counter();
    edge_pair_kinds: dict[tuple[int, int], Counter[str]] = {};
    for e in overview.get("cross_community_edges", []) {
        a: any;
        b: any;
        (a, b) = (e["source_community"], e["target_community"]);
        pair: any = (a, b) if a <= b else (b, a);
        edge_pair_counts[pair] += 1;
        edge_pair_kinds.setdefault(pair, Counter())[e["edge_kind"]] += 1;
    }

    cross_pairs: any = [
        {
            "source_community": id_to_name.get(a, f"community-{a}"),
            "target_community": id_to_name.get(b, f"community-{b}"),
            "edge_count": count,
            "top_kinds": [k for (k, _) in edge_pair_kinds[a, b].most_common(3)],
        }
        for ((a, b), count) in edge_pair_counts.most_common()
    ];
    return {
        "communities": communities,
        "cross_community_edges": cross_pairs,
        "warnings": overview.get("warnings", []),
    };
}

impl get_architecture_overview_func(
    repo_root: str | None = None,
    detail_level: str = "minimal",
    max_results: int = 100,
    max_members: int = 10,
) -> dict[str, Any] {
    _validate_positive_int(max_results, "max_results");
    _validate_positive_int(max_members, "max_members");

    store: any;
    `root: any;
    (store, `root) = _get_store(repo_root) as any;
    try {
        full_overview: any = get_architecture_overview(store);
        overview: any = full_overview;
        if detail_level == "minimal" {
            overview = _minimal_overview(full_overview);
        } else {
            overview = `dict(full_overview);
            overview["communities"] = [
                _cap_members(c, max_members)
                for c in overview.get("communities", [])
            ];
        }
        cross: any;
        cross_total: any;
        truncated: any;
        (cross, cross_total, truncated) = _bounded(
            overview["cross_community_edges"], max_results, _MAX_CROSS_EDGES
        ) as any;
        overview["cross_community_edges"] = cross;
        warnings: any;
        warn_total: any;
        warn_cut: any;
        (warnings, warn_total, warn_cut) = _bounded(
            overview["warnings"], max_results, _MAX_CROSS_EDGES
        ) as any;
        overview["warnings"] = warnings;
        truncated = truncated or warn_cut;
        n_communities: any = len(overview["communities"]);
        n_cross: any = len(cross);
        n_warnings: any = warn_total;
        cross_label: any = "community pairs"
            if detail_level == "minimal"
            else "cross-community edges";
        result: any = {
            "status": "ok",
            "summary": f"Architecture: {n_communities} communities, {cross_total} {cross_label}"
                + _shown_of(n_cross, cross_total)
                + f", {n_warnings} warning(s)",
            **overview,
            "cross_community_edges_total": cross_total,
            "truncated": truncated,
        };
        result["_hints"] = generate_hints("get_architecture_overview_tool", result, get_session());
        if detail_level == "minimal" {
            attach_context_savings(
                result,
                original_context=full_overview,
                call=CallInfo(
                    data_dir=store.db_path.parent,
                    tool="get_architecture_overview_tool",
                    detail_level=detail_level,
                ),
            );
        }
        return result;
    } except Exception as exc {
        return {"status": "error", "error": `str(exc)};
    } finally {
        store.close();
    }
}
