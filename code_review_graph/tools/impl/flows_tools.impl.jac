impl list_flows(
    repo_root: str | None = None,
    sort_by: str = "criticality",
    limit: int = 50,
    kind: str | None = None,
    detail_level: str = "standard",
) -> dict[str, Any] {
    _validate_positive_int(limit, "limit");

    store: any;
    `root: any;
    (store, `root) = _get_store(repo_root) as any;
    try {
        flows: any = get_flows(store, sort_by=sort_by, limit=_FETCH_ALL);

        if kind {
            filtered: any = [];
            for f in flows {
                ep_id: any = f.get("entry_point_id");
                if ep_id is not None {
                    node_kind: any = store.get_node_kind_by_id(ep_id);
                    if node_kind == kind {
                        filtered.append(f);
                    }
                }
            }
            flows = filtered;
        }

        total: any;
        truncated: any;
        (flows, total, truncated) = _bounded(flows, limit, _MAX_FLOWS) as any;

        if detail_level == "minimal" {
            flows = [
                {"name": f["name"], "criticality": f["criticality"], "node_count": f["node_count"]}
                for f in flows
            ];
        }

        result: dict[str, object] = {
            "status": "ok",
            "summary": f"Found {total} execution flow(s)" + _shown_of(len(flows), total),
            "flows": flows,
            "total": total,
            "truncated": truncated,
        };
        result["_hints"] = generate_hints("list_flows_tool", result, get_session());
        return result;
    } except Exception as exc {
        return {"status": "error", "error": `str(exc)};
    } finally {
        store.close();
    }
}

impl get_flow(
    flow_id: int | None = None,
    flow_name: str | None = None,
    include_source: bool = False,
    repo_root: str | None = None,
    max_steps: int = 50,
    max_source_lines: int = 400,
) -> dict[str, Any] {
    lines: any;
    _validate_positive_int(max_steps, "max_steps");
    _validate_positive_int(max_source_lines, "max_source_lines");

    store: any;
    `root: any;
    (store, `root) = _get_store(repo_root) as any;
    try {
        `flow: dict | None = None;

        if flow_id is not None {
            `flow = get_flow_by_id(store, flow_id);
        } elif flow_name is not None {
            all_flows: any = get_flows(store, sort_by="criticality", limit=500);
            for f in all_flows {
                if flow_name.lower() in f["name"].lower() {
                    `flow = get_flow_by_id(store, f["id"]);
                    break;
                }
            }
        }

        if `flow is None {
            return {"status": "not_found", "summary": "No flow found matching the given criteria."};
        }

        steps: any;
        total_steps: any;
        truncated: any;
        (steps, total_steps, truncated) = _bounded(
            `flow.get("steps") or [], max_steps, _MAX_FLOW_STEPS
        ) as any;
        `flow["steps"] = steps;
        `flow["total_steps"] = total_steps;
        `flow["truncated"] = truncated;
        if include_source {
            budget: any = min(max_source_lines, _MAX_FLOW_SOURCE_LINES);
            followed: any = followed_files(store);
            for step in steps {
                if budget <= 0 {
                    `flow["truncated"] = True;
                    `flow["source_truncated"] = True;
                    break;
                }
                fp: any = Path(step["file"]) if step.get("file") else None;
                if fp is not None and not fp.is_absolute() {
                    fp = `root / fp;
                }
                file_path: any = fp;
                if file_path
                    and file_path.is_file()
                    and path_within_repo(`root, file_path, followed)
                {
                    try {
                        lines = file_path.read_text(
                            encoding="utf-8", errors="replace"
                        ).splitlines();
                        start: any = max(0, (step.get("line_start") or 1) - 1);
                        end: any = min(
                            len(lines), step.get("line_end") or len(lines), start + budget
                        );
                        step["source"] = "\n".join(
                            f"{i + 1}: {lines[i]}" for i in range(start, end)
                        );
                        budget -= max(0, end - start);
                    } except (OSError, UnicodeDecodeError) {
                        step["source"] = "(could not read file)";
                    }
                }
            }
        }

        result: any = {
            "status": "ok",
            "summary": "Flow '"
                + format(`flow["name"], "")
                + "': "
                + format(`flow["node_count"], "")
                + " nodes, depth "
                + format(`flow["depth"], "")
                + ", criticality "
                + format(`flow["criticality"], ".4f")
                + _shown_of(len(steps), total_steps),
            "flow": `flow,
        };
        result["_hints"] = generate_hints("get_flow_tool", result, get_session());
        return result;
    } except Exception as exc {
        return {"status": "error", "error": `str(exc)};
    } finally {
        store.close();
    }
}
