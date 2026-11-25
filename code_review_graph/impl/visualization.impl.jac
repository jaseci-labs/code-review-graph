impl _d3_script_tags -> str {
    local_tag: any = f"<script src=\"{D3_LOCAL_FILENAME}\" integrity=\"{D3_SRI_HASH}\"></script>";
    cdn_tag: any = f"<script src=\"{D3_CDN_URL}\" integrity=\"{D3_SRI_HASH}\" crossorigin=\"anonymous\"><\\/script>";
    fallback_tag: any = f"<script>window.d3 || document.write('{cdn_tag}');</script>";
    return local_tag + "\n" + fallback_tag;
}

impl _write_d3_asset(directory: Path) -> Path | None {
    dest: any = directory / D3_LOCAL_FILENAME;
    try {
        asset: any = resources.files("code_review_graph") / "assets" / D3_LOCAL_FILENAME;
        data: any = asset.read_bytes();
    } except OSError as exc {
        logger.warning("Bundled D3 asset unavailable (%s); page will use the CDN fallback.", exc);
        return None;
    }
    digest: any = base64.b64encode(hashlib.sha384(data).digest()).decode();
    if f"sha384-{digest}" != D3_SRI_HASH and b"\r\n" in data {
        normalized: any = data.replace(b"\r\n", b"\n");
        normalized_digest: any = base64.b64encode(hashlib.sha384(normalized).digest()).decode();
        if f"sha384-{normalized_digest}" == D3_SRI_HASH {
            (data, digest) = (normalized, normalized_digest);
        }
    }
    if f"sha384-{digest}" != D3_SRI_HASH {
        logger.error(
            "Bundled D3 asset does not match the pinned SRI hash; refusing to write %s. The page will use the CDN fallback.",
            dest,
        );
        return None;
    }
    try {
        dest.write_bytes(data);
    } except OSError as exc {
        logger.warning("Could not write %s (%s); page will use the CDN fallback.", dest, exc);
        return None;
    }
    return dest;
}

impl _NameIndex.init {
    super.init();
    self._sorted = {};
}

impl _NameIndex.only_under_prefix(key: str, prefix: str) -> str | None {
    ranked: any = self._sorted.get(key);
    if ranked is None {
        value_: any = sorted(super.__getitem__(key));
        ranked = value_;
        self._sorted[key] = value_;
    }
    start: any = bisect_left(ranked, prefix);
    if start == len(ranked) or not ranked[start].startswith(prefix) {
        return None;
    }
    if start + 1 < len(ranked) and ranked[start + 1].startswith(prefix) {
        return None;
    }
    return ranked[start];
}

impl _build_name_index(nodes: list[dict], seen_qn: set[str]) -> _NameIndex {
    index: any = _NameIndex();
    for n in nodes {
        qn: any = n["qualified_name"];
        for key in _name_index_keys(n) {
            index.setdefault(key, []).append(qn);
        }
    }
    return index;
}

impl _name_index_keys(n: dict) -> Generator[any, any, any] {
    qn: any = n["qualified_name"];
    yield n["name"];
    if "::" in qn {
        yield qn.rsplit("/", 1)[-1];
    }
    fp: any = n.get("file_path", "");
    if fp {
        mod: any = fp.replace("/", ".").replace(".py", "");
        if n["kind"] == "File" {
            yield mod;
            parts: any = fp.replace("\\", "/").split("/");
            for i in range(len(parts)) {
                suffix: any = "/".join(parts[i:]);
                if suffix {
                    yield suffix;
                }
            }
        } else {
            yield mod + "." + n["name"];
        }
    }
}

impl _resolve_target(target: str, source: str, seen_qn: set[str], name_index: _NameIndex) -> str
    | None {
    if target in seen_qn {
        return target;
    }

    candidates: any = name_index.get(target);
    if not candidates {
        return None;
    }

    if len(candidates) == 1 {
        return candidates[0];
    }
    src_file: any = source.split("::")[0] if "::" in source else source;
    same_file: any = name_index.only_under_prefix(target, src_file);
    if same_file is not None {
        return same_file;
    }
    src_parts: any = src_file.rsplit("/", 1)[0] if "/" in src_file else "";
    same_dir: any = name_index.only_under_prefix(target, src_parts);
    if same_dir is not None {
        return same_dir;
    }
    return candidates[0];
}

impl _node_payload(gnode: GraphNode, community_id: int | None) -> dict {
    d: any = node_to_dict(gnode);
    d["params"] = gnode.params;
    d["return_type"] = gnode.return_type;
    d["community_id"] = community_id;
    return d;
}

impl _export_flows(store: GraphStore) -> list[dict] {
    try {
        get_flows = importlib.import_module("code_review_graph.flows").get_flows;
        return get_flows(store, limit=100);
    } except (ImportError, sqlite3.OperationalError) as exc {
        logger.debug("flows unavailable for export: %s", exc);
        return [];
    }
}

impl _export_communities(
    store: GraphStore, members_by_community: dict[int, list[str]] | None = None
) -> list[dict] {
    try {
        get_communities = importlib.import_module("code_review_graph.communities").get_communities;
        return get_communities(store, members_by_community=members_by_community);
    } except (ImportError, sqlite3.OperationalError) as exc {
        logger.debug("communities unavailable for export: %s", exc);
        return [];
    }
}

impl _read_node_identities(store: GraphStore) -> list[dict] | None {
    if store.has_edge_with_backslash_path() {
        return None;
    }
    identities: list[dict] = [];
    listed_files: set[str] = set[any]();
    for row in store.iter_node_identities() {
        file_path: any = row["file_path"];
        if normalize_file_path(file_path) != file_path {
            return None;
        }
        if row["listed"] {
            listed_files.add(file_path);
        }
        identities.append({
            "id": row["id"],
            "stored_name": row["qualified_name"],
            "qualified_name": _sanitize_name(row["qualified_name"]),
            "name": _sanitize_name(row["name"]),
            "kind": row["kind"],
            "file_path": file_path,
            "community_id": row["community_id"],
        });
    }
    unlisted: any = {n["file_path"] for n in identities} - listed_files;
    hidden: any = unlisted - store.get_files_with_edges(unlisted);
    if hidden {
        identities = [n for n in identities if n["file_path"] not in hidden];
    }
    return identities;
}

impl _count_exported_edges(store: GraphStore, seen_qn: set[str], name_index: _NameIndex) -> int
    | None {
    def resolves(name: str) -> bool {
        return `bool(_resolve_target(name, name, seen_qn, name_index));
    }

    total: any = 0;
    for (target, count) in store.iter_edge_end_counts("target_qualified") {
        exported: any = _sanitize_name(target);
        if resolves(exported) {
            if exported != target {
                return None;
            }
            total += count;
        }
    }
    lost_sources: list[str] = [];
    for (source, _count) in store.iter_edge_end_counts("source_qualified") {
        exported = _sanitize_name(source);
        if not resolves(exported) {
            lost_sources.append(source);
        } elif exported != source {
            return None;
        }
    }
    return total
        - sum(
            resolves(_sanitize_name(target))
            for target in store.iter_edge_targets_from(lost_sources),
        );
}

impl _read_edges_touching_nodes(
    store: GraphStore,
    names: Iterable[str],
    by_name: dict[str, list[dict]],
    seen_qn: set[str],
    name_index: _NameIndex,
) -> list[dict] {
    wanted: any = `set(names);
    stored_ends: any = `set(wanted);
    for name in wanted {
        for identity in by_name[name] {
            stored_ends.update(_name_index_keys(identity));
        }
    }
    found: any = [];
    for `edge in store.get_edges_touching(stored_ends) {
        e: any = edge_to_dict(`edge);
        src: any = _resolve_target(e["source"], e["source"], seen_qn, name_index);
        tgt: any = _resolve_target(e["target"], e["source"], seen_qn, name_index);
        if src and tgt and (src in wanted or tgt in wanted) {
            e["source"] = src;
            e["target"] = tgt;
            found.append(e);
        }
    }
    return found;
}

impl _export_seeded(store: GraphStore, spec: NeighbourhoodSpec) -> dict | None {
    e: any;
    if spec.path_from is not None {
        return None;
    }
    try {
        identities: any = _read_node_identities(store);
    } except sqlite3.OperationalError as exc {
        logger.debug("node identities unavailable for export: %s", exc);
        return None;
    }
    if identities is None {
        return None;
    }

    by_name: dict[str, list[dict]] = defaultdict(list[any]);
    identity: any;
    for identity in identities {
        by_name[identity["qualified_name"]].append(identity);
    }
    seen_qn: any = {n["stored_name"] for n in identities};
    name_index: any = _build_name_index(identities, seen_qn);
    total_edges: any = _count_exported_edges(store, seen_qn, name_index);
    if total_edges is None {
        return None;
    }

    flows: any = _export_flows(store);
    resolved: any = resolve_seeds(identities, [], flows, spec);

    limit: any = max(_SEEDED_READ_FALLBACK_NODES, len(identities) // 4);
    edges_by_id: dict[int, dict] = {};
    frontier: any = `set(resolved.seeds);
    reached: any = `set(frontier);
    for level in range(spec.depth + 1) {
        if len(reached) > limit {
            return None;
        }
        found: any = _read_edges_touching_nodes(store, frontier, by_name, seen_qn, name_index);
        edges_by_id.update((e["id"], e) for e in found);
        if level == spec.depth {
            break;
        }
        following: set[str] = set[any]();
        for e in found {
            if e["kind"] in STRUCTURAL_EDGE_KINDS {
                continue;
            }
            if e["source"] in frontier and e["target"] not in reached {
                following.add(e["target"]);
            }
            if e["target"] in frontier and e["source"] not in reached {
                following.add(e["source"]);
            }
        }
        if not following {
            break;
        }
        reached |= following;
        frontier = following;
    }
    edges: any = [edges_by_id[edge_id] for edge_id in sorted(edges_by_id)];
    parents: any = `set(_parent_files(edges, reached).values());
    edges_by_id.update(
        (e["id"], e)
        for e in _read_edges_touching_nodes(store, parents - reached, by_name, seen_qn, name_index),
    );

    wanted: any = reached | parents;
    gnodes: any = {
        g.qualified_name: g
        for g in store.get_nodes_by_qualified_names({
            n["stored_name"]
            for name in wanted
            for n in by_name[name]
        })
    };
    nodes: any = [];
    community_rows: dict[int, list[tuple[int, str]]] = defaultdict(list[any]);
    for identity in identities {
        gnode: any = gnodes.get(identity["stored_name"]);
        if gnode is None or identity["qualified_name"] not in wanted {
            continue;
        }
        nodes.append(_node_payload(gnode, identity["community_id"]));
        if identity["community_id"] is not None {
            community_rows[identity["community_id"]].append((
                identity["id"],
                identity["qualified_name"],
            ));
        }
    }

    data: any = {
        "nodes": nodes,
        "edges": [edges_by_id[edge_id] for edge_id in sorted(edges_by_id)],
        "stats": asdict(store.get_stats()),
        "flows": flows,
        "communities": _export_communities(
            store, {cid: [qn for (_, qn) in sorted(rows)] for (cid, rows) in community_rows.items()}
        ),
    };
    return extract_neighbourhood(
        data, spec, resolved=resolved, totals=(len(identities), total_edges)
    );
}

impl export_graph_data(
    store: GraphStore,
    *,
    seed_symbols: Sequence[str] | None = None,
    seed_files: Sequence[str] | None = None,
    seed_flow: str | None = None,
    path_from: str | None = None,
    path_to: str | None = None,
    depth: int = depth_default_,
    render_depth: int | None = None,
    max_nodes: int = max_nodes_default_,
) -> dict {
    e: any;
    spec: any = NeighbourhoodSpec.from_args(
        seed_symbols=seed_symbols,
        seed_files=seed_files,
        seed_flow=seed_flow,
        path_from=path_from,
        path_to=path_to,
        depth=depth,
        render_depth=render_depth,
        max_nodes=max_nodes,
    ).validate();
    if spec.is_active {
        seeded: any = _export_seeded(store, spec);
        if seeded is not None {
            return seeded;
        }
    }

    nodes: any = [];
    seen_qn: set[str] = set[any]();
    community_map: any = store.get_all_community_ids();

    for file_path in store.get_all_files() {
        for gnode in store.get_nodes_by_file(file_path) {
            if gnode.qualified_name in seen_qn {
                continue;
            }
            seen_qn.add(gnode.qualified_name);
            d: any = node_to_dict(gnode);
            d["params"] = gnode.params;
            d["return_type"] = gnode.return_type;
            d["community_id"] = community_map.get(gnode.qualified_name);
            nodes.append(d);
        }
    }

    name_index: any = _build_name_index(nodes, seen_qn);

    all_edges: any = [edge_to_dict(e) for e in store.get_all_edges()];
    edges: any = [];
    for e in all_edges {
        src: any = _resolve_target(e["source"], e["source"], seen_qn, name_index);
        tgt: any = _resolve_target(e["target"], e["source"], seen_qn, name_index);
        if src and tgt {
            e["source"] = src;
            e["target"] = tgt;
            edges.append(e);
        }
    }

    stats: any = store.get_stats();

    data: any = {
        "nodes": nodes,
        "edges": edges,
        "stats": asdict(stats),
        "flows": _export_flows(store),
        "communities": _export_communities(store),
    };
    if spec.is_active {
        return extract_neighbourhood(data, spec);
    }
    return data;
}

impl _aggregate_community(data: dict) -> dict {
    communities: any = data.get("communities") or [];
    nodes: any = data["nodes"];
    edges: any = data["edges"];
    qn_to_cid: dict[str, int] = {};
    c: any;
    for c in communities {
        qn: any;
        for qn in c.get("members", []) {
            qn_to_cid[qn] = c["id"];
        }
    }
    n: any;
    for n in nodes {
        if n.get("community_id") is not None and n["qualified_name"] not in qn_to_cid {
            qn_to_cid[n["qualified_name"]] = n["community_id"];
        }
    }
    uncategorized_members: list[str] = [];
    for n in nodes {
        if n["qualified_name"] not in qn_to_cid {
            qn_to_cid[n["qualified_name"]] = -1;
            uncategorized_members.append(n["qualified_name"]);
        }
    }
    cid_info: dict[int, dict] = {};
    for c in communities {
        cid_info[c["id"]] = c;
    }
    if uncategorized_members {
        cid_info[-1] = {
            "id": -1,
            "name": "Uncategorized",
            "size": len(uncategorized_members),
            "members": uncategorized_members,
            "dominant_language": "",
            "description": "Nodes not assigned to any community",
            "cohesion": 0,
            "level": 0,
        };
    }
    super_nodes: any = [];
    cid: any;
    for (cid, info) in cid_info.items() {
        size: any = info.get("size", len(info.get("members", [])));
        if size == 0 {
            continue;
        }
        super_nodes.append({
            "qualified_name": f"__community__{cid}",
            "name": info.get("name", f"Community {cid}"),
            "kind": "Community",
            "file_path": "",
            "line_start": None,
            "line_end": None,
            "language": info.get("dominant_language", ""),
            "community_id": cid,
            "member_count": size,
            "description": info.get("description", ""),
            "id": cid,
        });
    }
    cross_edge_counts: Counter[tuple[int, int]] = Counter();
    for e in edges {
        src_cid: any = qn_to_cid.get(e["source"]);
        tgt_cid: any = qn_to_cid.get(e["target"]);
        if src_cid is not None and tgt_cid is not None and src_cid != tgt_cid {
            pair: any = (min(src_cid, tgt_cid), max(src_cid, tgt_cid));
            cross_edge_counts[pair] += 1;
        }
    }

    super_edges: any = [];
    for ((c1, c2), count) in cross_edge_counts.items() {
        super_edges.append({
            "source": f"__community__{c1}",
            "target": f"__community__{c2}",
            "kind": "CROSS_COMMUNITY",
            "weight": count,
        });
    }
    community_details: dict[int, dict] = {};
    cid_members_set: dict[int, set[str]] = defaultdict(set[any]);
    for (qn, cid) in qn_to_cid.items() {
        cid_members_set[cid].add(qn);
    }

    for (cid, member_qns) in cid_members_set.items() {
        detail_nodes: any = [n for n in nodes if n["qualified_name"] in member_qns];
        detail_edges: any = [
            e
            for e in edges
            if e["source"] in member_qns and e["target"] in member_qns
        ];
        community_details[cid] = {"nodes": detail_nodes, "edges": detail_edges};
    }

    return {
        "nodes": super_nodes,
        "edges": super_edges,
        "stats": data["stats"],
        "flows": data.get("flows", []),
        "communities": communities,
        "mode": "community",
        "community_details": {`str(k): v for (k, v) in community_details.items()},
    };
}

impl _aggregate_file(data: dict) -> dict {
    nodes: any = data["nodes"];
    edges: any = data["edges"];
    file_symbol_count: Counter[str] = Counter();
    qn_to_file: dict[str, str] = {};
    file_languages: dict[str, str] = {};
    file_community: dict[str, Any] = {};

    for n in nodes {
        fp: any = n.get("file_path", "");
        if not fp {
            continue;
        }
        qn_to_file[n["qualified_name"]] = fp;
        if n["kind"] != "File" {
            file_symbol_count[fp] += 1;
        } else {
            file_symbol_count.setdefault(fp, 0);
        }
        if n.get("language") {
            file_languages[fp] = n["language"];
        }
        if n.get("community_id") is not None {
            file_community.setdefault(fp, n["community_id"]);
        }
    }
    file_nodes: any = [];
    count: any;
    for (fp, count) in file_symbol_count.items() {
        parts: any = fp.replace("\\", "/").split("/");
        short: any = parts[-1] if parts else fp;
        parent: any = parts[-2] if len(parts) >= 2 else "";
        label: any = f"{parent}/{short}" if parent else short;
        file_nodes.append({
            "qualified_name": fp,
            "name": label,
            "kind": "File",
            "file_path": fp,
            "line_start": None,
            "line_end": None,
            "language": file_languages.get(fp, ""),
            "community_id": file_community.get(fp),
            "symbol_count": count,
        });
    }
    cross_file_counts: Counter[tuple[str, str]] = Counter();
    for e in edges {
        src_fp: any = qn_to_file.get(e["source"]);
        tgt_fp: any = qn_to_file.get(e["target"]);
        if src_fp and tgt_fp and src_fp != tgt_fp {
            pair: any = (src_fp, tgt_fp);
            cross_file_counts[pair] += 1;
        }
    }

    file_edges: any = [];
    for ((f1, f2), count) in cross_file_counts.items() {
        file_edges.append({"source": f1, "target": f2, "kind": "DEPENDS_ON", "weight": count});
    }

    return {
        "nodes": file_nodes,
        "edges": file_edges,
        "stats": data["stats"],
        "flows": data.get("flows", []),
        "communities": data.get("communities", []),
        "mode": "file",
    };
}

impl _has_community_data(data: dict) -> bool {
    if data.get("communities") {
        return True;
    }
    return `any(n.get("community_id") is not None for n in data["nodes"]);
}

impl _resolve_auto_mode(
    node_count: int,
    edge_count: int,
    max_full_nodes: int,
    max_full_edges: int,
    has_communities: bool,
) -> str {
    if node_count <= max_full_nodes and edge_count <= max_full_edges {
        return "full";
    }
    return "community" if has_communities else "file";
}

impl _write_sidecar(output_path: Path, data_json: str, sidecar: bool) -> tuple[str, str] {
    if not sidecar {
        return ("", data_json);
    }
    stem: any = output_path.stem;
    if not _SAFE_SIDECAR_STEM.fullmatch(stem) {
        stem = "graph";
    }
    name: any = f"{stem}.data.js";
    (output_path.parent / name).write_text(f"{_SIDECAR_GLOBAL} = {data_json};\n", encoding="utf-8");
    return (f"<script src=\"{name}\"></script>", _SIDECAR_GLOBAL);
}

impl generate_html(
    store: GraphStore,
    output_path: str | Path,
    mode: str = "auto",
    max_full_nodes: int = max_full_nodes_default_,
    max_full_edges: int = max_full_edges_default_,
    *,
    seed_symbols: Sequence[str] | None = None,
    seed_files: Sequence[str] | None = None,
    seed_flow: str | None = None,
    path_from: str | None = None,
    path_to: str | None = None,
    depth: int = depth_default__,
    render_depth: int | None = None,
    max_nodes: int = max_nodes_default__,
    `report: dict | None = None,
    sidecar: bool = False,
) -> Path {
    output_path = Path(output_path);
    stats: any = store.get_stats();
    spec: any = NeighbourhoodSpec.from_args(
        seed_symbols=seed_symbols,
        seed_files=seed_files,
        seed_flow=seed_flow,
        path_from=path_from,
        path_to=path_to,
        depth=depth,
        render_depth=render_depth,
        max_nodes=max_nodes,
    ).validate();
    if spec.is_active and mode not in ("auto", "full") {
        raise ValueError(
            f"mode={mode!r} aggregates the graph into bubbles, which is the opposite of a seeded neighbourhood; use mode='full' (or drop the seed to draw the whole repository that way)",
        );
    }
    if stats.total_nodes > 50000 and not spec.is_active {
        logger.warning(
            "Graph has %d nodes — visualization may be slow. Consider seeding a neighbourhood with --seed-symbol / --seed-file / --seed-flow.",
            stats.total_nodes,
        );
    }
    data: any = export_graph_data(
        store,
        seed_symbols=seed_symbols,
        seed_files=seed_files,
        seed_flow=seed_flow,
        path_from=path_from,
        path_to=path_to,
        depth=depth,
        render_depth=render_depth,
        max_nodes=max_nodes,
    );
    if `report is not None {
        block: any = data.get("neighbourhood", {});
        `report.update({
            "seeds": len(block.get("seeds", [])),
            "seeds_requested": block.get("seeds_requested", 0),
            "seeds_dropped": block.get("seeds_dropped", 0),
            "truncated": `bool(block.get("truncated", False)),
            "max_nodes": block.get("max_nodes", max_nodes),
            "node_count": len(data["nodes"]),
        });
    }
    effective_mode: any = mode;
    if spec.is_active {
        effective_mode = "full";
    } elif effective_mode == "auto" {
        effective_mode = _resolve_auto_mode(
            node_count=len(data["nodes"]),
            edge_count=len(data["edges"]),
            max_full_nodes=max_full_nodes,
            max_full_edges=max_full_edges,
            has_communities=_has_community_data(data),
        );
        if effective_mode != "full" {
            logger.info(
                "auto mode: %d nodes / %d edges exceeds full-render budget (%d nodes / %d edges) — using %s aggregation",
                len(data["nodes"]),
                len(data["edges"]),
                max_full_nodes,
                max_full_edges,
                effective_mode,
            );
        }
    }

    if effective_mode == "community" {
        agg: any = _aggregate_community(data);
        data_json: any = json.dumps(agg, default=str).replace("</", "<\\/");
        template: any = _AGGREGATED_HTML_TEMPLATE;
    } elif effective_mode == "file" {
        agg = _aggregate_file(data);
        data_json = json.dumps(agg, default=str).replace("</", "<\\/");
        template = _AGGREGATED_HTML_TEMPLATE;
    } else {
        data_json = json.dumps(data, default=str).replace("</", "<\\/");
        template = _HTML_TEMPLATE;
    }
    html: any = template.replace("__D3_SCRIPTS__", _d3_script_tags());
    sidecar_tag: any;
    payload: any;
    (sidecar_tag, payload) = _write_sidecar(output_path, data_json, sidecar) as any;
    html = html.replace("__SIDECAR_SCRIPT__", sidecar_tag);
    html = html.replace("__GRAPH_DATA__", payload);
    output_path.write_text(html, encoding="utf-8");
    _write_d3_asset(output_path.parent);
    return output_path;
}
