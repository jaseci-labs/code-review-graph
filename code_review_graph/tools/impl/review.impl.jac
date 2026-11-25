impl _project(rows: list[dict[str, Any]], fields: tuple[str, ...]) -> list[dict[str, Any]] {
    return [{k: r[k] for k in fields if k in r} for r in rows];
}

impl _bound_flow_steps(flows: list[dict[str, Any]]) -> tuple[list[dict[str, Any]], bool] {
    budget: any = _MAX_AFFECTED_FLOW_STEPS;
    truncated: any = False;
    bounded: list[dict[str, Any]] = [];
    for `flow in flows {
        out: any = `dict(`flow);
        steps: any = out.get("steps") or [];
        out["total_steps"] = len(steps);
        if len(steps) > budget {
            out["steps"] = steps[:budget];
            out["steps_omitted"] = True;
            truncated = True;
        }
        budget -= min(len(steps), budget);
        bounded.append(out);
    }
    return (bounded, truncated);
}

impl _nodes_by_rel_path(
    `root: Path, rel_files: list[str], changed_nodes: list[GraphNode]
) -> dict[str, list[GraphNode]] {
    by_path: dict[str, list[GraphNode]] = {};
    for `node in changed_nodes {
        if `node.file_path {
            by_path.setdefault(`node.file_path, []).append(`node);
        }
    }

    grouped: dict[str, list[GraphNode]] = {};
    for rel in rel_files {
        joined: any = `root / rel;
        grouped[rel] = by_path.get(normalize_file_path(joined))
            or by_path.get(`str(joined))
            or by_path.get(normalize_file_path(rel))
            or [];
    }
    return grouped;
}

impl _risk_by_file(
    store: Any, rel_files: list[str], nodes_by_rel: dict[str, list[GraphNode]]
) -> dict[str, float] {
    rel: any;
    risks: dict[str, float] = {rel: 0.0 for rel in rel_files};
    if not rel_files {
        return risks;
    }

    candidates: dict[str, list[GraphNode]] = {};
    for rel in rel_files {
        scorable: list[GraphNode] = [];
        for `node in nodes_by_rel.get(rel, ()) {
            if `node.kind not in _RISK_SCORED_KINDS {
                continue;
            }
            if isinstance(`node.extra, `dict) and `node.extra.get("verilog_kind") {
                continue;
            }
            scorable.append(`node);
            if len(scorable) >= _MAX_RISK_NODES_PER_FILE {
                break;
            }
        }
        candidates[rel] = scorable;
    }

    remaining: any = _MAX_RISK_SCORED_NODES;
    try {
        for depth in range(_MAX_RISK_NODES_PER_FILE) {
            if remaining <= 0 {
                break;
            }
            progressed: any = False;
            for rel in rel_files {
                if remaining <= 0 {
                    break;
                }
                nodes: any = candidates[rel];
                if depth >= len(nodes) {
                    continue;
                }
                score: any = compute_risk_score(store, nodes[depth]);
                remaining -= 1;
                progressed = True;
                if score > risks[rel] {
                    risks[rel] = score;
                }
            }
            if not progressed {
                break;
            }
        }
    } except (sqlite3.Error, ValueError, AttributeError) {
        logger.warning("Risk ranking failed; falling back to diff order", exc_info=True);
    }
    return risks;
}

impl _source_share_cap(total_budget: int, per_file_limit: int) -> int {
    return max(1, min(per_file_limit, `int(total_budget * _MAX_SOURCE_SHARE_PER_FILE)));
}

impl _diff_hunks(`root: Path, base: str) -> dict[str, list[tuple[int, int]]] {
    try {
        return parse_diff_ranges(`str(`root), base);
    } except (OSError, ValueError) as exc {
        logger.warning("Diff hunk lookup failed: %s", exc);
        return {};
    }
}

impl _file_regions(
    line_count: int, hunks: list[tuple[int, int]], nodes: list[GraphNode], region_cap: int
) -> list[tuple[int, int]] {
    start: any;
    end: any;
    if line_count <= 0 {
        return [];
    }
    if line_count <= region_cap {
        return [(0, line_count)];
    }

    spans: list[tuple[int, int]] = [];
    if hunks {
        node_spans: any = [
            (n.line_start, n.line_end)
            for n in nodes
            if n.line_start and n.line_end and n.line_end >= n.line_start
        ];
        for (h_start, h_end) in hunks {
            enclosing: any = [
                (end - start, start, end)
                for (start, end) in node_spans
                if start <= h_end and end >= h_start and end - start + 1 <= _MAX_WIDEN_SPAN
            ];
            if enclosing {
                _: any;
                (_, start, end) = min(enclosing) as any;
                spans.append((min(h_start, start), max(h_end, end)));
            } else {
                spans.append((h_start - _REGION_CONTEXT, h_end + _REGION_CONTEXT));
            }
        }
    } else {
        spans = [
            (n.line_start, n.line_end)
            for n in nodes
            if n.line_start and n.line_end and n.line_end >= n.line_start
        ];
    }

    if not spans {
        head: any = min(_FALLBACK_HEAD_LINES, line_count);
        return [(0, head)] if head > 0 else [];
    }

    regions: any = sorted(
        (start, end)
        for (start, end) in ((max(0, s - 3), min(line_count, e + 2)) for (s, e) in spans)
        if end > start,
    );
    if not regions {
        return [];
    }

    merged: any = [regions[0]];
    for (start, end) in regions[1:] {
        last_start: any;
        last_end: any;
        (last_start, last_end) = merged[-1] as any;
        if start <= last_end + 1 and max(end, last_end) - last_start <= region_cap {
            merged[-1] = (last_start, max(end, last_end));
        } else {
            merged.append((start, end));
        }
    }
    return merged;
}

impl _allocate_regions(
    ranked_files: list[str],
    regions_by_file: dict[str, list[tuple[int, int]]],
    total_budget: int,
    per_file_limit: int,
) -> tuple[dict[str, list[tuple[int, int]]], dict[str, int]] {
    rel: any;
    granted: dict[str, list[tuple[int, int]]] = {};
    if ranked_files and total_budget > 0 and per_file_limit > 0 {
        share_cap: any = _source_share_cap(total_budget, per_file_limit);
        region_cap: any = min(_MAX_REGION_LINES, share_cap);
        used: dict[str, int] = dict.fromkeys(ranked_files, 0);
        remaining: any = total_budget;
        depth: any = 0;
        deepest: any = max((len(regions_by_file.get(rel, ())) for rel in ranked_files), default=0);
        while depth < deepest and remaining > 0 {
            for rel in ranked_files {
                regions: any = regions_by_file.get(rel, ());
                if depth >= len(regions) {
                    continue;
                }
                start: any;
                end: any;
                (start, end) = regions[depth] as any;
                cost: any = min(end - start, region_cap);
                if cost <= 0 or cost > min(remaining, share_cap - used[rel]) {
                    continue;
                }
                granted.setdefault(rel, []).append((start, start + cost));
                used[rel] += cost;
                remaining -= cost;
            }
            depth += 1;
        }
        for regions in granted.values() {
            regions.sort();
        }
    }

    omitted: any = {
        rel: len(regions_by_file.get(rel, ())) - len(granted.get(rel, ()))
        for rel in ranked_files
        if len(regions_by_file.get(rel, ())) > len(granted.get(rel, ()))
    };
    return (granted, omitted);
}

impl _render_regions(lines: list[str], regions: list[tuple[int, int]], omitted: int) -> str {
    parts: list[str] = [];
    previous_end: int | None = None;
    for (start, end) in regions {
        if previous_end is not None and start > previous_end {
            parts.append("...");
        }
        parts.extend(f"{i + 1}: {lines[i]}" for i in range(start, end));
        previous_end = end;
    }
    if omitted > 0 {
        parts.append(f"... ({omitted} more changed region(s) not shown)");
    }
    return "\n".join(parts);
}

impl get_review_context(
    changed_files: list[str] | None = None,
    max_depth: int = 2,
    include_source: bool = True,
    max_lines_per_file: int = 200,
    repo_root: str | None = None,
    base: str = "HEAD~1",
    detail_level: str = "standard",
    max_results: int = 50,
    max_files: int = 25,
) -> dict[str, Any] {
    `root: any;
    tested_qualified: any;
    file_risk: any;
    regions: any;
    _validate_positive_int(max_results, "max_results");
    _validate_positive_int(max_files, "max_files");
    _validate_positive_int(max_lines_per_file, "max_lines_per_file");

    store: any;
    (store, `root) = _get_store(repo_root) as any;
    try {
        if changed_files is None {
            (changed_files, base) = discover_review_changes(`root, base) as any;
        } else {
            base = resolve_review_base(`root, base);
        }

        if not changed_files {
            return {
                "status": "ok",
                "summary": "No changes detected. Nothing to review.",
                "context": {},
            };
        }

        graph_files: any;
        unmatched_files: any;
        (graph_files, unmatched_files) = _resolve_graph_file_paths_with_unmatched(
            store, `root, changed_files
        ) as any;
        shown_unmatched: any;
        unmatched_total: any;
        unmatched_cut: any;
        (shown_unmatched, unmatched_total, unmatched_cut) = _bounded(
            unmatched_files, 5 if detail_level == "minimal" else max_files, _MAX_REVIEW_FILES
        ) as any;
        original_tokens: any = estimate_file_tokens(`root, changed_files);
        history_call: any = CallInfo(
            data_dir=store.db_path.parent,
            tool="get_review_context_tool",
            detail_level=detail_level,
            files=len(changed_files),
            depth=max_depth,
        );
        impact: any = store.get_impact_radius(graph_files, max_depth=max_depth);
        impacted_count: any = impact.get("total_impacted", len(impact["impacted_nodes"]));
        risk: any = "unknown"
            if not graph_files
            else "high" if impacted_count > 20 else "medium" if impacted_count > 5 else "low";

        if detail_level == "minimal" {
            key_entities: any = [n.name for n in impact["changed_nodes"][:5]];
            changed_funcs: any = [
                n
                for n in impact["changed_nodes"]
                if n.kind == "Function" and not n.is_test and not is_test_file(n.file_path, `root)
            ];
            test_edges: any = [e for e in impact["edges"] if e.kind == "TESTED_BY"];
            tested_qualified = {e.source_qualified for e in test_edges};
            test_gap_count: any = sum(
                1
                for f in changed_funcs
                if f.qualified_name not in tested_qualified and not is_test_gap_exempt(f, `root),
            );

            summary_parts: any = [
                f"Review context for {len(changed_files)} changed file(s):",
                f"  - Risk: {risk}",
                "  - "
                    + format(len(impact["impacted_nodes"]), "")
                    + " impacted nodes in "
                    + format(len(impact["impacted_files"]), "")
                    + " files",
            ];
            if unmatched_files {
                summary_parts.append(_unmatched_file_warning(unmatched_files));
            }

            result: any = {
                "status": "ok",
                "summary": "\n".join(summary_parts),
                "risk": risk,
                "unmatched_files": shown_unmatched,
                "unmatched_files_total": unmatched_total,
                "unmatched_files_truncated": unmatched_cut,
                "changed_file_count": len(changed_files),
                "impacted_file_count": len(impact["impacted_files"]),
                "key_entities": key_entities,
                "test_gaps": test_gap_count,
                "next_tool_suggestions": [
                    "detect_changes_tool",
                    "get_affected_flows_tool",
                    "get_impact_radius_tool",
                ],
            };
            attach_context_savings(result, original_tokens=original_tokens, call=history_call);
            return result;
        }
        nodes_by_rel: any = _nodes_by_rel_path(`root, changed_files, impact["changed_nodes"]);
        file_risk = _risk_by_file(store, changed_files, nodes_by_rel);
        ranked_files: any = [
            rel
            for (_, rel) in sorted(
                ((-file_risk.get(rel, 0.0), i), rel) for (i, rel) in enumerate(changed_files)
            )
        ];
        shown_files: any;
        files_total: any;
        files_cut: any;
        (shown_files, files_total, files_cut) = _bounded(
            ranked_files, max_files, _MAX_REVIEW_FILES
        ) as any;
        impacted_files: any;
        impacted_total: any;
        impacted_cut: any;
        (impacted_files, impacted_total, impacted_cut) = _bounded(
            impact["impacted_files"], max_files, _MAX_REVIEW_FILES
        ) as any;
        changed_nodes: any;
        changed_nodes_total: any;
        cn_cut: any;
        (changed_nodes, changed_nodes_total, cn_cut) = _bounded(
            impact["changed_nodes"], max_results, _MAX_REVIEW_NODES
        ) as any;
        impacted_nodes: any;
        impacted_nodes_total: any;
        in_cut: any;
        (impacted_nodes, impacted_nodes_total, in_cut) = _bounded(
            impact["impacted_nodes"], max_results, _MAX_REVIEW_NODES
        ) as any;
        edges: any;
        edges_total: any;
        edges_cut: any;
        (edges, edges_total, edges_cut) = _bounded(
            impact["edges"], max_results, _MAX_REVIEW_EDGES
        ) as any;
        truncated: any = files_cut
            or impacted_cut
            or cn_cut
            or in_cut
            or edges_cut
            or unmatched_cut;

        context: dict[str, Any] = {
            "changed_files": shown_files,
            "changed_files_total": files_total,
            "file_risk": {rel: round(file_risk.get(rel, 0.0), 4) for rel in shown_files},
            "impacted_files": impacted_files,
            "impacted_files_total": impacted_total,
            "graph": {
                "changed_nodes": [node_to_dict(n) for n in changed_nodes],
                "changed_nodes_total": changed_nodes_total,
                "impacted_nodes": [node_to_dict(n) for n in impacted_nodes],
                "impacted_nodes_total": impacted_nodes_total,
                "edges": [edge_to_dict(e) for e in edges],
                "edges_total": edges_total,
            },
            "truncated": truncated,
        };
        if include_source {
            per_file: any = min(max_lines_per_file, _MAX_LINES_PER_FILE);
            region_cap: any = min(
                _MAX_REGION_LINES, _source_share_cap(_MAX_REVIEW_SOURCE_LINES, per_file)
            );
            hunks: any = _diff_hunks(`root, base);
            file_lines: dict[str, list[str]] = {};
            regions_by_file: dict[str, list[tuple[int, int]]] = {};
            snippets: dict[str, str] = {};
            followed: any = followed_files(store);
            rel_path: any;
            for rel_path in shown_files {
                full_path: any = `root / rel_path;
                if not full_path.is_file() {
                    continue;
                }
                if not path_within_repo(`root, full_path, followed) {
                    snippets[rel_path] = "(outside the repository)";
                    continue;
                }
                try {
                    lines: any = full_path.read_text(
                        encoding="utf-8", errors="replace"
                    ).splitlines();
                } except (OSError, UnicodeDecodeError) {
                    snippets[rel_path] = "(could not read file)";
                    continue;
                }
                file_lines[rel_path] = lines;
                regions_by_file[rel_path] = _file_regions(
                    len(lines),
                    hunks.get(rel_path) or hunks.get(PurePath(rel_path).as_posix(), []),
                    nodes_by_rel.get(rel_path, []),
                    region_cap,
                );
            }

            granted: any;
            omitted: any;
            (granted, omitted) = _allocate_regions(
                shown_files, regions_by_file, _MAX_REVIEW_SOURCE_LINES, per_file
            ) as any;
            shown_regions: any = 0;
            total_regions: any = 0;
            clipped: any = False;
            incomplete: dict[str, list[int]] = {};
            for rel_path in shown_files {
                if rel_path not in file_lines {
                    continue;
                }
                regions = regions_by_file.get(rel_path, []);
                held: any = granted.get(rel_path, []);
                have: any = len(held);
                want: any = len(regions);
                shown_regions += have;
                total_regions += want;
                if have < want {
                    incomplete[rel_path] = [have, want];
                }
                clipped = clipped or `any(r not in `set(regions) for r in held);
                if not have {
                    continue;
                }
                snippets[rel_path] = _render_regions(
                    file_lines[rel_path], granted[rel_path], omitted.get(rel_path, 0)
                );
            }
            context["source_snippets"] = snippets;
            context["source_regions"] = {
                "shown": shown_regions,
                "total": total_regions,
                "incomplete": incomplete,
            };
            if shown_regions < total_regions or clipped {
                context["source_truncated"] = True;
                context["truncated"] = True;
            }
        }
        guidance: any = _generate_review_guidance(impact, changed_files, `root, store)
            if graph_files
            else "- None of these files are in the graph, so the blast radius is unknown.";
        context["review_guidance"] = guidance;

        summary_parts = [
            f"Review context for {files_total} changed file(s)"
                + _shown_of(len(shown_files), files_total)
                + ":",
            f"  - {changed_nodes_total} directly changed nodes"
                + _shown_of(len(changed_nodes), changed_nodes_total),
            f"  - {impacted_nodes_total} impacted nodes in {impacted_total} files"
                + _shown_of(len(impacted_nodes), impacted_nodes_total),
            "",
            "Review guidance:",
            guidance,
        ];
        if unmatched_files {
            summary_parts.append(_unmatched_file_warning(unmatched_files));
        }

        result = {
            "status": "ok",
            "risk": risk,
            "unmatched_files": shown_unmatched,
            "unmatched_files_total": unmatched_total,
            "unmatched_files_truncated": unmatched_cut,
            "summary": "\n".join(summary_parts),
            "context": context,
        };
        attach_context_savings(result, original_tokens=original_tokens, call=history_call);
        return result;
    } except ChangeDiscoveryError as exc {
        return _error_response(`str(exc));
    } finally {
        store.close();
    }
}

impl _generate_review_guidance(
    impact: dict,
    changed_files: list[str],
    repo_root: "str | Path | None" = None,
    store: "GraphStore | None" = None,
) -> str {
    guidance_parts: any = [];
    changed_funcs: any = [n for n in impact["changed_nodes"] if n.kind == "Function"];
    test_edges: any = [e for e in impact["edges"] if e.kind == "TESTED_BY"];
    tested_funcs: any = {e.source_qualified for e in test_edges};

    untested: any = [
        f
        for f in changed_funcs
        if f.qualified_name not in tested_funcs
            and not f.is_test
            and not is_test_file(f.file_path, repo_root)
            and not is_test_gap_exempt(f, repo_root)
    ];
    if untested {
        routes: dict = {};
        if store is not None {
            try {
                routes = store.get_caller_test_routes(
                    (f.qualified_name for f in untested),
                    repo_root=`str(repo_root) if repo_root else None,
                );
            } except Exception as exc {
                logger.warning("caller-route lookup failed: %s", exc);
                routes = {};
            }
        }
        unreached: any = [f for f in untested if f.qualified_name not in routes];
        indirect: any = [f for f in untested if f.qualified_name in routes];
        guidance_parts.append(
            f"- {len(untested)} changed function(s) have no direct test: "
                + ", ".join(n.name for n in untested[:5]),
        );
        if indirect {
            guidance_parts.append(
                f"  - of those, {len(indirect)} are reached only through a caller (a call path, not a record of execution): "
                    + ", ".join(n.name for n in indirect[:5]),
            );
            guidance_parts.append(
                f"  - {len(unreached)} have no tested caller found: "
                    + ", ".join(n.name for n in unreached[:5]),
            );
        }
    }
    if len(impact["impacted_nodes"]) > 20 {
        guidance_parts.append(
            "- Wide blast radius: "
                + format(len(impact["impacted_nodes"]), "")
                + " nodes impacted. Review callers and dependents carefully.",
        );
    }
    inheritance_edges: any = [e for e in impact["edges"] if e.kind in ("INHERITS", "IMPLEMENTS")];
    if inheritance_edges {
        guidance_parts.append(
            f"- {len(inheritance_edges)} inheritance/implementation relationship(s) affected. Check for Liskov substitution violations.",
        );
    }
    impacted_file_count: any = len(impact["impacted_files"]);
    if impacted_file_count > 3 {
        guidance_parts.append(
            f"- Changes impact {impacted_file_count} other files. Consider splitting into smaller PRs.",
        );
    }

    if not guidance_parts {
        guidance_parts.append("- Changes appear well-contained with minimal blast radius.");
    }

    return "\n".join(guidance_parts);
}

impl get_affected_flows_func(
    changed_files: list[str] | None = None,
    base: str = "HEAD~1",
    repo_root: str | None = None,
    detail_level: str = "standard",
    max_flows: int = 50,
) -> dict[str, Any] {
    store: any;
    `root: any;
    (store, `root) = _get_store(repo_root) as any;
    try {
        if changed_files is None {
            (changed_files, base) = discover_review_changes(`root, base) as any;
        }

        if not changed_files {
            return {
                "status": "ok",
                "summary": "No changed files detected.",
                "affected_flows": [],
                "total": 0,
                "truncated": False,
            };
        }
        abs_files: any = [normalize_file_path(`root / f) for f in changed_files];
        result: any = _get_affected_flows(store, abs_files);

        total: any = result["total"];
        flows: any = result["affected_flows"];
        ceiling: any = _MAX_AFFECTED_FLOWS_MINIMAL
            if detail_level == "minimal"
            else _MAX_AFFECTED_FLOWS_STANDARD;
        limit: any = ceiling if max_flows <= 0 else min(max_flows, ceiling);
        truncated: any = operator.gt(total, limit);
        flows = flows[:limit];
        if detail_level == "minimal" {
            flows = _project(flows, _DETECT_FLOW_FIELDS);
        } else {
            steps_cut: any;
            (flows, steps_cut) = _bound_flow_steps(flows) as any;
            truncated = truncated or steps_cut;
        }
        out: any = {
            "status": "ok",
            "summary": f"{total} flow(s) affected by changes in {len(changed_files)} file(s)"
                + _shown_of(len(flows), total),
            "changed_files": changed_files,
            "affected_flows": flows,
            "total": total,
            "truncated": truncated,
        };
        out["_hints"] = generate_hints("get_affected_flows_tool", out, get_session());
        return out;
    } except Exception as exc {
        return {"status": "error", "error": `str(exc)};
    } finally {
        store.close();
    }
}

impl detect_changes_func(
    base: str = "HEAD~1",
    changed_files: list[str] | None = None,
    include_source: bool = False,
    max_depth: int = 2,
    repo_root: str | None = None,
    detail_level: str = "standard",
    max_results: int = 25,
    max_flows: int = 20,
) -> dict[str, Any] {
    lines: any;
    _validate_positive_int(max_results, "max_results");
    _validate_positive_int(max_flows, "max_flows");

    store: any;
    `root: any;
    (store, `root) = _get_store(repo_root) as any;
    notes: list[str] = [];
    try {
        if changed_files is None {
            (changed_files, base) = discover_review_changes(`root, base, notes=notes) as any;
        } else {
            base = resolve_review_base(`root, base);
        }

        if not changed_files {
            return {
                "status": "ok",
                "summary": "No changed files detected.",
                "risk_score": 0.0,
                "changed_functions": [],
                "changed_yaml_paths": [],
                "changed_json_paths": [],
                "affected_flows": [],
                "test_gaps": [],
                "review_priorities": [],
            };
        }

        original_tokens: any = estimate_file_tokens(`root, changed_files);
        abs_files: any = [normalize_file_path(`root / f) for f in changed_files];
        diff_ranges: any = parse_diff_ranges(`str(`root), base);
        if not isinstance(diff_ranges, DiffRanges) {
            diff_ranges = DiffRanges(diff_ranges);
        }
        abs_ranges: any = diff_ranges.remapped(`root);

        analysis: any = analyze_changes(
            store,
            changed_files=abs_files,
            changed_ranges=abs_ranges or None,
            repo_root=`str(`root),
            base=base,
            include_churn=True,
        );
        if include_source {
            budget: any = _MAX_DETECT_SOURCE_LINES;
            followed: any = followed_files(store);
            for func in analysis.get("changed_functions", []) {
                if budget <= 0 {
                    break;
                }
                fp: any = func.get("file_path");
                ls: any = func.get("line_start");
                le: any = func.get("line_end");
                if fp and ls and le {
                    file_path: any = Path(fp);
                    if file_path.is_file() and path_within_repo(`root, file_path, followed) {
                        try {
                            lines = file_path.read_text(
                                encoding="utf-8", errors="replace"
                            ).splitlines();
                            start: any = max(0, ls - 1);
                            end: any = min(len(lines), le, start + budget);
                            func["source"] = "\n".join(
                                f"{i + 1}: {lines[i]}" for i in range(start, end)
                            );
                            budget -= max(0, end - start);
                        } except (OSError, UnicodeDecodeError) {
                            func["source"] = "(could not read file)";
                        }
                    }
                }
            }
        }

        if detail_level == "minimal" {
            priorities: any = analysis.get("review_priorities", []);
            top_priorities: any = [
                p.get("name", p.get("qualified_name", ""))
                for p in priorities[:3]
            ];
            result: dict[str, Any] = {
                "status": "ok",
                "summary": analysis.get("summary", ""),
                "risk_score": analysis.get("risk_score", 0.0),
                "changed_file_count": len(changed_files),
                "changed_yaml_path_count": len(analysis.get("changed_yaml_paths", [])),
                "changed_json_path_count": len(analysis.get("changed_json_paths", [])),
                "test_gap_count": len(analysis.get("test_gaps", [])),
                "removed_symbol_count": analysis.get("removed_symbols_total", 0),
                "review_priorities": top_priorities,
                "churn_status": analysis.get("churn_status", "off"),
            };
        } else {
            funcs: any;
            funcs_total: any;
            funcs_cut: any;
            (funcs, funcs_total, funcs_cut) = _bounded(
                analysis.get("changed_functions", []), max_results, _MAX_CHANGED_FUNCTIONS
            ) as any;
            gaps: any;
            gaps_total: any;
            gaps_cut: any;
            (gaps, gaps_total, gaps_cut) = _bounded(
                analysis.get("test_gaps", []), max_results, _MAX_CHANGED_FUNCTIONS
            ) as any;
            flows: any;
            flows_total: any;
            flows_cut: any;
            (flows, flows_total, flows_cut) = _bounded(
                analysis.get("affected_flows", []), max_flows, _MAX_DETECT_FLOWS
            ) as any;
            files: any;
            files_total: any;
            files_cut: any;
            (files, files_total, files_cut) = _bounded(
                changed_files, max_results, _MAX_REVIEW_FILES
            ) as any;
            yaml_paths: any;
            yaml_paths_total: any;
            yaml_paths_cut: any;
            (yaml_paths, yaml_paths_total, yaml_paths_cut) = _bounded(
                analysis.get("changed_yaml_paths", []), max_results, _MAX_CHANGED_FUNCTIONS
            ) as any;
            json_paths: any;
            json_paths_total: any;
            json_paths_cut: any;
            (json_paths, json_paths_total, json_paths_cut) = _bounded(
                analysis.get("changed_json_paths", []), max_results, _MAX_CHANGED_FUNCTIONS
            ) as any;
            removed: any;
            _: any;
            removed_cut: any;
            (removed, _, removed_cut) = _bounded(
                analysis.get("removed_symbols", []), max_results, _MAX_REMOVED_SYMBOLS
            ) as any;
            removed_total: any = analysis.get("removed_symbols_total", len(removed));
            removed_cut = removed_cut or operator.gt(removed_total, len(removed));
            any_cut: any = funcs_cut
                or gaps_cut
                or flows_cut
                or files_cut
                or yaml_paths_cut
                or json_paths_cut
                or removed_cut
                or `bool(analysis.get("yaml_paths_truncated"))
                or `bool(analysis.get("json_paths_truncated"));
            summary: any = analysis.get("summary", "");
            if any_cut {
                summary += f"\n  - Response bounded: {len(funcs)} of {funcs_total} changed function(s), {len(yaml_paths)} of {yaml_paths_total} changed YAML path(s), "
                    + (
                        f"{len(json_paths)} of {json_paths_total} changed JSON path(s), "
                            if json_paths_total
                            else ""
                    )
                    + f"{len(gaps)} of {gaps_total} test gap(s), {len(flows)} of {flows_total} flow(s)"
                    + (
                        f", {len(removed)} of {removed_total} removed symbol(s)"
                            if removed_total
                            else ""
                    )
                    + " shown";
            }
            result = {
                "status": "ok",
                **analysis,
                "summary": summary,
                "changed_files": files,
                "changed_file_count": files_total,
                "changed_functions": funcs,
                "changed_functions_total": funcs_total,
                "changed_yaml_paths": yaml_paths,
                "changed_yaml_paths_total": yaml_paths_total,
                "changed_json_paths": json_paths,
                "changed_json_paths_total": json_paths_total,
                "test_gaps": gaps,
                "test_gaps_total": gaps_total,
                "removed_symbols": removed,
                "removed_symbols_total": removed_total,
                "affected_flows": _project(flows, _DETECT_FLOW_FIELDS),
                "affected_flows_total": flows_total,
                "truncated": any_cut,
            };
        }
        if notes {
            result["summary"] = "\n".join([
                *(f"Note: {note}" for note in notes),
                result["summary"],
            ]);
        }
        result["_hints"] = generate_hints("detect_changes_tool", result, get_session());
        attach_context_savings(
            result,
            original_tokens=original_tokens,
            call=CallInfo(
                data_dir=store.db_path.parent,
                tool="detect_changes_tool",
                detail_level=detail_level,
                files=len(changed_files),
                depth=max_depth,
            ),
        );
        return result;
    } except Exception as exc {
        return {"status": "error", "error": `str(exc)};
    } finally {
        store.close();
    }
}
