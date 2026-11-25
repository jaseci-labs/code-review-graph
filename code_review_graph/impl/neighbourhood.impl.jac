impl _sanitize_name(value: str) -> str {
    _impl = lazy("graph", "_sanitize_name");

    return _impl(value);
}

impl SeedResolutionError.__repr__ -> str {
    return (getattr(builtins.super(SeedResolutionError, self), "__repr__") as any)();
}

impl SeedResolutionError.__eq__(other: any) -> bool {
    return self is other;
}

impl SeedResolutionError.__hash__ -> int {
    return id(self);
}

impl NeighbourhoodSpec.validate -> "NeighbourhoodSpec" {
    if (self.path_from is None) != (self.path_to is None) {
        raise ValueError("--path-from and --path-to must be given together");
    }
    if self.depth < 0 {
        raise ValueError(f"depth must be >= 0, got {self.depth}");
    }
    if self.render_depth is not None and self.render_depth < 0 {
        raise ValueError(f"render-depth must be >= 0, got {self.render_depth}");
    }
    if self.render_depth is not None and self.render_depth > self.depth {
        raise ValueError(
            f"render-depth {self.render_depth} exceeds depth {self.depth}; the payload stops at hop {self.depth}",
        );
    }
    if self.max_nodes < 1 {
        raise ValueError(f"max-nodes must be >= 1, got {self.max_nodes}");
    }
    return self;
}

impl NeighbourhoodSpec.from_args(
    *,
    seed_symbols: Sequence[str] | None = None,
    seed_files: Sequence[str] | None = None,
    seed_flow: str | None = None,
    path_from: str | None = None,
    path_to: str | None = None,
    depth: int = depth_default_,
    render_depth: int | None = None,
    max_nodes: int = max_nodes_default_,
) -> "NeighbourhoodSpec" {
    return cls(
        symbols=`tuple(seed_symbols or ()),
        files=`tuple(seed_files or ()),
        flow=seed_flow,
        path_from=path_from,
        path_to=path_to,
        depth=depth,
        render_depth=render_depth,
        max_nodes=max_nodes,
    );
}

impl build_adjacency(
    edges: Iterable[dict],
    kinds: Sequence[str] | None = None,
    *,
    exclude: Sequence[str] = (),
    directed: bool = False,
) -> dict[str, set[str]] {
    allowed: any = `set(kinds) if kinds is not None else None;
    denied: any = `set(exclude);
    adjacency: dict[str, set[str]] = {};
    for `edge in edges {
        kind: any = `edge.get("kind");
        if allowed is not None and kind not in allowed {
            continue;
        }
        if kind in denied {
            continue;
        }
        source: any = `edge.get("source");
        target: any = `edge.get("target");
        if not source or not target {
            continue;
        }
        adjacency.setdefault(source, set[any]()).add(target);
        if directed {
            adjacency.setdefault(target, set[any]());
        } else {
            adjacency.setdefault(target, set[any]()).add(source);
        }
    }
    return adjacency;
}

impl hop_distances(
    adjacency: dict[str, set[str]], seeds: Iterable[str], depth: int
) -> dict[str, int] {
    hops: dict[str, int] = {seed: 0 for seed in seeds};
    queue: deque[str] = deque(hops);
    while queue {
        current: any = queue.popleft();
        distance: any = hops[current];
        if distance >= depth {
            continue;
        }
        for neighbour in adjacency.get(current, ()) {
            if neighbour not in hops {
                hops[neighbour] = distance + 1;
                queue.append(neighbour);
            }
        }
    }
    return hops;
}

impl shortest_path(
    edges: Iterable[dict], source: str, target: str, kinds: Sequence[str] = kinds_default_
) -> tuple[list[str], bool] {
    edges = `list(edges);
    if source == target {
        return ([source], True);
    }
    directed_adjacency: any = build_adjacency(edges, kinds, directed=True);
    path: any = _bfs_path(directed_adjacency, source, target);
    if path {
        return (path, True);
    }
    undirected_adjacency: any = build_adjacency(edges, kinds, directed=False);
    return (_bfs_path(undirected_adjacency, source, target), False);
}

impl _bfs_path(adjacency: dict[str, set[str]], source: str, target: str) -> list[str] {
    if source not in adjacency or target not in adjacency {
        return [];
    }
    previous: dict[str, str | None] = {source: None};
    queue: deque[str] = deque([source]);
    visits: any = 0;
    while queue {
        current: any = queue.popleft();
        visits += 1;
        if visits > _MAX_PATH_VISITS {
            return [];
        }
        if current == target {
            path: any = [current];
            while previous[path[-1]] is not None {
                path.append(previous[path[-1]]);
            }
            path.reverse();
            return path;
        }
        for neighbour in sorted(adjacency.get(current, ())) {
            if neighbour not in previous {
                previous[neighbour] = current;
                queue.append(neighbour);
            }
        }
    }
    return [];
}

impl _normalise_path(value: str) -> str {
    cleaned: any = value.replace("\\", "/").strip();
    while cleaned.startswith("./") {
        cleaned = cleaned[2:];
    }
    return cleaned.lstrip("/");
}

impl resolve_symbol(nodes: Sequence[dict], query: str) -> list[str] {
    by_qn: any = {`node["qualified_name"] for `node in nodes};
    if query in by_qn {
        return [query];
    }

    normalised: any = _normalise_path(query);
    if normalised in by_qn {
        return [normalised];
    }

    suffix_matches: any = sorted(
        qn for qn in by_qn if qn.endswith("::" + query) or qn.endswith("/" + normalised)
    );
    if suffix_matches {
        return suffix_matches;
    }

    name_matches: any = sorted(
        `node["qualified_name"] for `node in nodes if `node.get("name") == query
    );
    if name_matches {
        return name_matches;
    }

    raise SeedResolutionError(
        f"no node in the graph matches symbol {_sanitize_name(query)!r}; pass a qualified name such as 'pkg/mod.py::func'",
    );
}

impl resolve_files(nodes: Sequence[dict], patterns: Sequence[str]) -> list[str] {
    file_paths: any = {`node["file_path"] for `node in nodes if `node.get("file_path")};
    matched: set[str] = set[any]();
    for pattern in patterns {
        normalised: any = _normalise_path(pattern);
        if not normalised {
            continue;
        }
        for file_path in file_paths {
            candidate: any = _normalise_path(file_path);
            if candidate == normalised
                or candidate.endswith("/" + normalised)
                or fnmatch.fnmatch(candidate, normalised)
            {
                matched.add(file_path);
            }
        }
    }
    if not matched {
        joined: any = ", ".join(_sanitize_name(p) for p in patterns[:5]);
        raise SeedResolutionError(f"no indexed file matches: {joined}");
    }
    seeds: any = {`node["qualified_name"] for `node in nodes if `node.get("file_path") in matched};
    return sorted(seeds);
}

impl resolve_flow(flows: Sequence[dict], nodes: Sequence[dict], query: str) -> list[str] {
    id_to_qn: any = {
        `node["id"]: `node["qualified_name"]
        for `node in nodes
        if `node.get("id") is not None
    };
    lowered: any = query.strip().lower();
    chosen: dict | None = None;
    `flow: any;
    for `flow in flows {
        if `str(`flow.get("id")) == query or `str(`flow.get("name", "")).lower() == lowered {
            chosen = `flow;
            break;
        }
    }
    if chosen is None {
        for `flow in flows {
            if lowered and lowered in `str(`flow.get("name", "")).lower() {
                chosen = `flow;
                break;
            }
        }
    }
    if chosen is None {
        raise SeedResolutionError(
            f"no execution flow matches {_sanitize_name(query)!r}; run 'code-review-graph postprocess' to detect flows",
        );
    }
    seeds: any = [id_to_qn[node_id] for node_id in chosen.get("path", []) if node_id in id_to_qn];
    if not seeds {
        raise SeedResolutionError(
            "flow "
                + format(repr(_sanitize_name(`str(chosen.get("name")))), "")
                + " has no nodes present in the exported graph",
        );
    }
    return seeds;
}

impl _parent_files(edges: Sequence[dict], members: set[str]) -> dict[str, str] {
    parents: dict[str, str] = {};
    for `edge in edges {
        if `edge.get("kind") != "CONTAINS" {
            continue;
        }
        target: any = `edge.get("target");
        if target in members {
            parents.setdefault(target, `edge["source"]);
        }
    }
    return parents;
}

impl _select_within_budget(
    hops: dict[str, int],
    degrees: dict[str, int],
    parents: dict[str, str],
    max_nodes: int,
    pinned: Sequence[str] = (),
) -> tuple[dict[str, int], bool] {
    selected: dict[str, int] = {};
    truncated: any = False;
    qualified_name: any;
    for qualified_name in pinned {
        if len(selected) >= max_nodes {
            truncated = True;
            break;
        }
        if qualified_name in hops and qualified_name not in selected {
            selected[qualified_name] = hops[qualified_name];
        }
    }
    ordered: any = sorted(
        hops.items(), key=lambda (item) -> any { (item[1], -degrees.get(item[0], 0), item[0]) }
    );
    for (qualified_name, distance) in ordered {
        already: any = qualified_name in selected;
        if already and selected[qualified_name] > distance {
            selected[qualified_name] = distance;
        }
        addition: any = [] if already else [qualified_name];
        parent: any = parents.get(qualified_name);
        if parent is not None and parent not in selected {
            addition.append(parent);
        }
        if not addition {
            continue;
        }
        if len(selected) + len(addition) > max_nodes {
            if len(addition) > 1 and len(selected) + 1 <= max_nodes {
                addition = [qualified_name];
            } else {
                truncated = True;
                continue;
            }
        }
        for member in addition {
            previous: any = selected.get(member);
            if previous is None or previous > distance {
                selected[member] = distance;
            }
        }
    }
    return (selected, truncated);
}

impl resolve_seeds(
    nodes: Sequence[dict], edges: Sequence[dict], flows: Sequence[dict], spec: NeighbourhoodSpec
) -> ResolvedSeeds {
    seeds: list[str] = [];
    seed_kind: any = "symbol";
    path: list[str] = [];
    path_directed: any = True;
    path_error: any = "";

    if spec.path_from is not None and spec.path_to is not None {
        seed_kind = "path";
        source: any = resolve_symbol(nodes, spec.path_from)[0];
        target: any = resolve_symbol(nodes, spec.path_to)[0];
        (path, path_directed) = shortest_path(edges, source, target) as any;
        if path {
            seeds.extend(path);
        } else {
            path_error = "no path from "
                + format(_sanitize_name(source), "")
                + " to "
                + format(_sanitize_name(target), "")
                + " through "
                + format("/".join(PATH_EDGE_KINDS), "");
            seeds.extend([source, target]);
        }
    }

    if spec.symbols {
        if seed_kind == "path" {
            seed_kind = "mixed";
        }
        for query in spec.symbols {
            seeds.extend(resolve_symbol(nodes, query));
        }
    }
    if spec.files {
        seed_kind = "file" if seed_kind == "symbol" else "mixed";
        seeds.extend(resolve_files(nodes, spec.files));
    }
    if spec.flow {
        seed_kind = "flow" if seed_kind == "symbol" else "mixed";
        seeds.extend(resolve_flow(flows, nodes, spec.flow));
    }
    return ResolvedSeeds(`list(dict.fromkeys(seeds)), seed_kind, path, path_directed, path_error);
}

impl extract(
    data: dict,
    spec: NeighbourhoodSpec,
    *,
    resolved: ResolvedSeeds | None = None,
    totals: tuple[int, int] | None = None,
) -> dict {
    spec.validate();
    nodes: list[dict] = data["nodes"];
    edges: list[dict] = data["edges"];

    if resolved is None {
        resolved = resolve_seeds(nodes, edges, data.get("flows", []), spec);
    }
    seeds: any = resolved.seeds;
    seed_kind: any = resolved.seed_kind;
    path: any = resolved.path;
    path_directed: any = resolved.path_directed;
    path_error: any = resolved.path_error;
    total_nodes: any;
    total_edges: any;
    (total_nodes, total_edges) = (
        totals if totals is not None else (len(nodes), len(edges))
    ) as any;
    if len(path) > spec.max_nodes {
        raise ValueError(
            f"max-nodes {spec.max_nodes} is below the {len(path)} nodes on the path from {_sanitize_name(path[0])} to {_sanitize_name(path[-1])}; raise it to at least {len(path)}",
        );
    }

    adjacency: any = build_adjacency(edges, exclude=STRUCTURAL_EDGE_KINDS);
    hops: any = hop_distances(adjacency, seeds, spec.depth);

    degrees: dict[str, int] = {};
    for `edge in edges {
        degrees[`edge["source"]] = degrees.get(`edge["source"], 0) + 1;
        degrees[`edge["target"]] = degrees.get(`edge["target"], 0) + 1;
    }
    parents: any = _parent_files(edges, `set(hops));
    truncated: any;
    (hops, truncated) = _select_within_budget(
        hops, degrees, parents, spec.max_nodes, pinned=path
    ) as any;

    selected: any = `set(hops);
    seeds_requested: any = len(seeds);
    seeds = [seed for seed in seeds if seed in selected];
    seeds_dropped: any = seeds_requested - len(seeds);
    out_nodes: any = [];
    emitted: set[str] = set[any]();
    for `node in nodes {
        qualified_name: any = `node["qualified_name"];
        if qualified_name in selected and qualified_name not in emitted {
            emitted.add(qualified_name);
            out_nodes.append(`node);
        }
    }
    out_edges: any = [e for e in edges if e["source"] in selected and e["target"] in selected];

    kept_ids: any = {n["id"] for n in out_nodes if n.get("id") is not None};
    out_flows: any = [
        f
        for f in data.get("flows", [])
        if `any(nid in kept_ids for nid in f.get("path", []))
    ];
    out_communities: any = [];
    for community in data.get("communities", []) {
        members: any = [m for m in community.get("members", []) if m in selected];
        if members {
            trimmed: any = `dict(community);
            trimmed["members"] = members;
            out_communities.append(trimmed);
        }
    }

    frontier: any = sorted(qn for (qn, d) in hops.items() if d >= spec.depth);

    return {
        "nodes": out_nodes,
        "edges": out_edges,
        "stats": data.get("stats", {}),
        "flows": out_flows,
        "communities": out_communities,
        "mode": "neighbourhood",
        "neighbourhood": {
            "seeds": seeds,
            "seeds_requested": seeds_requested,
            "seeds_dropped": seeds_dropped,
            "seed_kind": seed_kind,
            "seed_query": [_sanitize_name(q) for q in (*spec.symbols, *spec.files)]
                or ([_sanitize_name(spec.flow)] if spec.flow else []),
            "depth": spec.depth,
            "render_depth": spec.effective_render_depth,
            "hops": hops,
            "frontier": frontier,
            "path": path,
            "path_directed": path_directed,
            "path_edge_kinds": `list(PATH_EDGE_KINDS),
            "path_error": path_error,
            "structural_edge_kinds": `list(STRUCTURAL_EDGE_KINDS),
            "truncated": truncated,
            "max_nodes": spec.max_nodes,
            "total_nodes": total_nodes,
            "total_edges": total_edges,
        },
    };
}
