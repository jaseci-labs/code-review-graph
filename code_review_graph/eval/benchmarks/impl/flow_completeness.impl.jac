impl run(repo_path: Path, store, config: dict) -> list[dict] {
    store_flows = lazy("flows", "store_flows");
    trace_flows = lazy("flows", "trace_flows");

    flows: any = trace_flows(store);
    count: any = store_flows(store, flows);
    detected_entries: any = set[any]();
    for `flow in flows {
        detected_entries.add(`flow.get("entry_point") or `flow.get("name", ""));
    }

    known: any = `set(config.get("entry_points", []));
    found: any = sum(1 for ep in known if `any(ep in d for d in detected_entries));

    depths: any = [f.get("depth", 0) for f in flows];

    return [
        {
            "repo": config["name"],
            "known_entry_points": len(known),
            "detected_entry_points": found,
            "recall": round(found / max(len(known), 1), 3),
            "detected_flows": count,
            "avg_flow_depth": round(sum(depths) / max(len(depths), 1), 1),
            "max_flow_depth": max(depths, default=0),
        },
    ];
}
