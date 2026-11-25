import from __future__ { annotations }

import builtins, operator, typing, logging, re;

import from collections { defaultdict, deque }

import from pathlib { Path }

import from typing { Any }

glob _HOP_DIRECT: any;

glob _HOP_UNIQUE_NAME: any;

glob _HOP_SHARED_NAME: any;

glob logger: any = logging.getLogger(__name__);

glob _MAX_IMPACT_NODES_SHOWN: any = 100;

glob _MAX_IMPACT_EDGES: any = 150;

glob _MAX_IMPACT_FILES: any = 200;

glob _MAX_SEARCH_RESULTS_STANDARD: any = 100;

glob _MAX_SEARCH_RESULTS_MINIMAL: any = 5;

glob _MAX_LARGE_FUNCTIONS_STANDARD: any = 100;

glob _MAX_LARGE_FUNCTIONS_MINIMAL: any = 25;

glob _MAX_TRAVERSAL_TOKEN_BUDGET: any = 10000;

glob _SEARCH_WINDOW_FACTOR: any = 3;

glob _MAX_SEARCH_SOURCE_LINES: any = 240;

glob _MAX_SEARCH_SOURCE_LINES_PER_NODE: any = 60;

glob _MAX_EXPANDED_SOURCE_LINES: any = 700;

glob _MAX_EXPANDED_HITS: any = 3;

glob _MAX_NEIGHBORS_PER_HIT: any = 4;

glob _MAX_SEARCH_SOURCE_CHARS: any = 80000;

glob _MAX_SEARCH_SOURCE_CHARS_PER_NODE: any = 12000;

glob _SANITIZED_NAME_MAX: any = 256;

glob _QUERY_PATTERNS: any = QUERY_PATTERNS;

glob _JAVA_FQN_PART: any = re.compile("^[A-Za-z_$][A-Za-z0-9_$]*$");

glob _TEST_BLOCK_NAME: any = re.compile("@L\\d+$");

glob _MAX_DOTTED_TARGET_CANDIDATES: any = 100;

glob _MAX_BARE_TARGET_CANDIDATES: any = 20;

glob _CALL_SITE_PATTERNS: any = frozenset({"callers_of", "callees_of", "references_to"});

def _attach_call_site(result: dict[str, Any], `edge: GraphEdge) -> dict[str, Any] {
    call_site: dict[str, Any] = {"line": `edge.line};
    if `edge.file_path != result.get("file_path") {
        call_site["file"] = `edge.file_path;
    }
    result["call_site"] = call_site;
    return result;
}

def _interleave_call_sites(
    sites: list[tuple[str, dict[str, Any], GraphEdge]]
) -> list[tuple[dict[str, Any], GraphEdge]] {
    seen_order: dict[str, int] = {};
    occurrence: dict[str, int] = {};
    keyed: list[tuple[int, bool, int, int, dict[str, Any], GraphEdge]] = [];
    for (index, (key, result, `edge)) in enumerate(sites) {
        seen_order.setdefault(key, len(seen_order));
        round_index: any = occurrence.get(key, 0);
        occurrence[key] = round_index + 1;
        is_guess: any = operator.eq(result.get("target_resolution"), RESOLUTION_UNRESOLVED);
        keyed.append((round_index, is_guess, seen_order[key], index, result, `edge));
    }
    keyed.sort(key=lambda (item) -> any { item[:4] });
    return [(result, `edge) for (_, _, _, _, result, `edge) in keyed];
}

def _test_is_named_after(`test: GraphNode, name: str) -> bool {
    if not _TEST_BLOCK_NAME.search(`test.name) {
        return True;
    }
    word: any = re.escape(name.lower());
    return `bool(
        re.search(f"(?:^|[^a-z0-9]){word}(?:[^a-z0-9]|$)", Path(`test.file_path).name.lower())
    );
}

def _looks_like_java_method_fqn(target: str) -> bool {
    if "::" in target {
        return False;
    }
    parts: any = target.split(".");
    if len(parts) < 2 or not all(_JAVA_FQN_PART.fullmatch(part) for part in parts) {
        return False;
    }
    return operator.ge(len(parts), 3) or parts[-2][:1].isupper();
}

def _java_fqn_candidates(store: GraphStore, target: str) -> list[GraphNode] | None {
    if not _looks_like_java_method_fqn(target) {
        return None;
    }

    parts: any = target.split(".");
    class_name: any;
    method_name: any;
    (class_name, method_name) = parts[-2:] as any;
    matches: list[GraphNode] = [];
    for candidate in store.search_nodes(method_name, limit=_MAX_DOTTED_TARGET_CANDIDATES) {
        if candidate.language.lower() != "java" or candidate.name != method_name {
            continue;
        }
        parent_name: any = candidate.parent_name or "";
        parent_match: any = operator.eq(parent_name.rsplit(".", 1)[-1], class_name);
        file_match: any = operator.eq(Path(candidate.file_path).stem, class_name);
        qualified_tail: any = candidate.qualified_name.rsplit("::", 1)[-1];
        qualified_match: any = qualified_tail.endswith(f"{class_name}.{method_name}");
        if parent_match or file_match or qualified_match {
            matches.append(candidate);
        }
    }
    return matches;
}

def _namespaced_member_candidates(store: GraphStore, target: str) -> list[GraphNode] {
    method_name: any = target.rsplit(".", 1)[-1];
    return [
        candidate
        for candidate in store.search_nodes(method_name, limit=_MAX_DOTTED_TARGET_CANDIDATES)
        if candidate.language.lower() in ("ruby", "csharp")
            and candidate.name == method_name
            and candidate.qualified_name.endswith(f".{target}")
    ];
}

def _exact_name_candidates(
    store: GraphStore, `root: Path, target: str
) -> tuple[list[GraphNode], int] {
    exact: any = store.get_nodes_by_name(target);
    real: any = [
        candidate
        for candidate in exact
        if not candidate.is_test and not is_test_file(candidate.file_path, `root)
    ];
    if real {
        return (real, len(exact) - len(real));
    }
    return (exact, 0);
}

def _selectable_qualified_name(`node: GraphNode, `root: Path) -> str {
    qualified: any = `node.qualified_name;
    prefix: any = f"{normalize_file_path(`root)}/";
    if len(qualified) > _SANITIZED_NAME_MAX and qualified.startswith(prefix) {
        qualified = qualified[len(prefix):];
    }
    return _sanitize_name(qualified);
}

def _rank_disambiguation_candidates(
    candidates: list[GraphNode], target: str, `root: Path
) -> list[dict[str, Any]] {
    target_lower: any = target.lower();

    def score(`node: GraphNode) -> tuple[int, str] {
        if `node.qualified_name == target {
            rank: any = 0;
        } elif `node.name == target {
            rank = 1;
        } elif target_lower in `node.qualified_name.lower() {
            rank = 2;
        } else {
            rank = 3;
        }
        return (rank, `node.qualified_name);
    }

    return [
        {**node_to_dict(`node), "qualified_name": _selectable_qualified_name(`node, `root)}
        for `node in sorted(candidates, key=score)
    ];
}

def _compact_impact_response(
    result: dict[str, Any],
    `root: Path,
    changed_files: list[str],
    unmatched_files: list[str],
    max_files: int,
    resolution: str,
    unresolved_call_sites: int,
) -> dict[str, Any] {
    def requested_path(path: str) -> str {
        relative: any = repo_relative_path(path, `root);
        return path if relative is None else relative;
    }

    def graph_path(path: str) -> str {
        relative: any = repo_relative_path(path, `root);
        if relative is None {
            return path;
        }
        stored_relative: any = repo_relative_path(path) is not None;
        if stored_relative and not (`root / relative).exists() {
            parts: any = relative.split("/");
            for k in range(min(len(`root.parts), len(parts) - 1), 0, -1) {
                if `tuple(parts[:k]) == `root.parts[-k:] {
                    return "/".join(parts[k:]);
                }
            }
        }
        return relative;
    }
    file_set: any = `set(result["impacted_files"]);
    ranked_files: any = `list(
        dict.fromkeys(
            `node.file_path for `node in result["impacted_nodes"] if `node.file_path in file_set
        ),
    );
    ranked_set: any = `set(ranked_files);
    ranked_files.extend(sorted(file_set - ranked_set));
    shown: any;
    total: any;
    cut: any;
    (shown, total, cut) = _bounded(ranked_files, max_files, _MAX_IMPACT_FILES) as any;
    changed_shown: any;
    changed_total: any;
    changed_cut: any;
    (changed_shown, changed_total, changed_cut) = _bounded(
        changed_files, max_files, _MAX_IMPACT_FILES
    ) as any;
    unmatched_shown: any;
    unmatched_total: any;
    unmatched_cut: any;
    (unmatched_shown, unmatched_total, unmatched_cut) = _bounded(
        unmatched_files, max_files, _MAX_IMPACT_FILES
    ) as any;
    return {
        "status": "ok",
        "summary": f"Showing {len(shown)} of {total} impacted files (best-first).",
        "changed_files": [requested_path(path) for path in changed_shown],
        "changed_file_count": changed_total,
        "changed_files_omitted": changed_total - len(changed_shown),
        "unmatched_files": [requested_path(path) for path in unmatched_shown],
        "unmatched_files_total": unmatched_total,
        "unmatched_files_truncated": unmatched_cut,
        "impacted_files": [graph_path(path) for path in shown],
        "impacted_file_count": total,
        "impacted_files_omitted": total - len(shown),
        "total_impacted": result["total_impacted"],
        "truncated": result["truncated"] or cut or changed_cut or unmatched_cut,
        "resolution": resolution,
        "unresolved_call_sites": unresolved_call_sites,
    };
}

glob _HOP_CERTAINTY: any = ("direct", "unique_name", "shared_name");

with entry {
    (_HOP_DIRECT, _HOP_UNIQUE_NAME, _HOP_SHARED_NAME) = range(len(_HOP_CERTAINTY)) as any;
}

glob _ROUTE_EDGE_KINDS: any = frozenset({
    "CALLS",
    "REFERENCES",
    "INHERITS",
    "IMPLEMENTS",
    "IMPORTS_FROM",
    "CONTAINS",
});

glob _NAME_MATCH_EDGE_KINDS: any = frozenset({"CALLS", "REFERENCES", "INHERITS", "IMPLEMENTS"});

glob _MAX_NAME_MATCH_CANDIDATES: any = 10;

glob _MAX_ROUTE_VISITS: any = 200000;

glob _MAX_ROUTE_HOPS: any = 30;

glob _Hop: any = builtins.tuple[str, int, GraphEdge];

glob _Route: any = typing.List[typing.Tuple[str, str, int, GraphEdge]];

glob _CANDIDATE_KEYS: any = (
    ("ambiguous_targets", "ambiguous_target_count"),
    ("unresolved_targets", "unresolved_target_count"),
);

obj _RouteGraph {
    has _store: any,
        _root: any,
        _nodes: any,
        _by_name: any,
        _direct: any,
        _all: any,
        _edges: any;

    def init(store: GraphStore, `root: Path) {
        self._store = store;
        self._root = `root;
        self._nodes = {};
        self._by_name = None;
        self._direct = {};
        self._all = {};
        self._edges = {};
    }

    def `node(qualified_name: str) -> GraphNode | None {
        if qualified_name not in self._nodes {
            self._nodes[qualified_name] = self._store.get_node(qualified_name);
        }
        return self._nodes[qualified_name];
    }

    def _is_test(`node: GraphNode) -> bool {
        return `node.is_test or is_test_file(`node.file_path, self._root);
    }

    def _edges_from(qualified_name: str) -> list[GraphEdge] {
        if qualified_name not in self._edges {
            self._edges[qualified_name] = [
                `edge
                for `edge in self._store.iter_edges_by_source(qualified_name)
                if `edge.kind in _ROUTE_EDGE_KINDS
                    and not (
                        `edge.kind == "IMPORTS_FROM"
                        and `edge.extra.get(IMPORT_CONTEXT_KEY) == IMPORT_CONTEXT_TYPE_ONLY
                    )
            ];
        }
        return self._edges[qualified_name];
    }

    def _named(name: str) -> list[GraphNode] {
        if self._by_name is None {
            self._by_name = defaultdict(list[any]);
            for `node in self._store.get_all_nodes(exclude_files=True) {
                self._by_name[`node.name].append(`node);
            }
        }
        return self._by_name.get(name, []);
    }

    def _name_matches(`edge: GraphEdge, source: GraphNode) -> list[GraphNode] {
        name: any = `edge.target_qualified;
        if name in _BUILTIN_CALL_NAMES or "::" in name {
            return [];
        }
        languages: any = _compatible_edge_languages(source.language) if source.language else None;
        matches: any = [
            candidate
            for candidate in self._named(name)
            if candidate.kind != "File"
                and not self._is_test(candidate)
                and (languages is None or candidate.language in languages)
                and GraphStore.receiver_evidence_admits(`edge.extra, candidate)
        ];
        return matches if len(matches) <= _MAX_NAME_MATCH_CANDIDATES else [];
    }

    def _guessed_hops(`edge: GraphEdge, source: GraphNode) -> list[_Hop] {
        if `edge.kind not in _NAME_MATCH_EDGE_KINDS {
            return [];
        }
        for (key, count_key) in _CANDIDATE_KEYS {
            named: any = `edge.extra.get(key);
            if isinstance(named, `list) {
                recorded: any = `edge.extra.get(count_key);
                total: any = max(len(named), recorded if isinstance(recorded, `int) else 0);
                if total > _MAX_NAME_MATCH_CANDIDATES {
                    return [];
                }
                hops: list[_Hop] = [];
                for candidate in named {
                    `node: any = self.node(candidate) if isinstance(candidate, `str) else None;
                    if `node is not None and not self._is_test(`node) {
                        hops.append((`node.qualified_name, _HOP_SHARED_NAME, `edge));
                    }
                }
                return hops;
            }
        }
        matches: any = self._name_matches(`edge, source);
        certainty: any = _HOP_UNIQUE_NAME if len(matches) == 1 else _HOP_SHARED_NAME;
        return [(`match.qualified_name, certainty, `edge) for `match in matches];
    }

    static def _ordered(hops: list[_Hop]) -> list[_Hop] {
        return sorted(hops, key=lambda (hop) -> any { (hop[1], hop[0], hop[2].line) });
    }

    def hops_from(qualified_name: str, weakest_allowed: int) -> list[_Hop] {
        if qualified_name not in self._direct {
            direct: list[_Hop] = [];
            `edge: any;
            for `edge in self._edges_from(qualified_name) {
                `node: any = self.node(`edge.target_qualified);
                if `node is not None {
                    direct.append((`node.qualified_name, _HOP_DIRECT, `edge));
                }
            }
            self._direct[qualified_name] = self._ordered(direct);
        }
        if weakest_allowed == _HOP_DIRECT {
            return self._direct[qualified_name];
        }
        if qualified_name not in self._all {
            source: any = self.node(qualified_name);
            guessed: list[_Hop] = [];
            if source is not None {
                for `edge in self._edges_from(qualified_name) {
                    if self.node(`edge.target_qualified) is None {
                        guessed.extend(self._guessed_hops(`edge, source));
                    }
                }
            }
            self._all[qualified_name] = self._ordered(self._direct[qualified_name] + guessed);
        }
        return self._all[qualified_name];
    }

    def _search(source: str, target: str, weakest_allowed: int) -> tuple[_Route | None, bool] {
        came_from: dict[str, tuple[str, int, GraphEdge] | None] = {source: None};
        queue: any = deque([source]);
        visits: any = 0;
        while queue and visits < _MAX_ROUTE_VISITS {
            visits += 1;
            current: any = queue.popleft();
            for (next_name, certainty, `edge) in self.hops_from(current, weakest_allowed) {
                if certainty > weakest_allowed or next_name in came_from {
                    continue;
                }
                came_from[next_name] = (current, certainty, `edge);
                if next_name == target {
                    route: _Route = [];
                    step: any = next_name;
                    while (`entry := came_from[step]) is not None {
                        route.append((`entry[0], step, `entry[1], `entry[2]));
                        step = `entry[0];
                    }
                    return (route[::-1], True);
                }
                queue.append(next_name);
            }
        }
        return (None, not queue);
    }

    def route(source: str, target: str) -> tuple[_Route | None, bool] {
        for weakest_allowed in range(len(_HOP_CERTAINTY)) {
            route: any;
            complete: any;
            (route, complete) = self._search(source, target, weakest_allowed) as any;
            if route is not None or not complete {
                return (route, complete);
            }
        }
        return (None, True);
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

def _route_endpoint_candidates(
    store: GraphStore, `root: Path, `graph: _RouteGraph, name: str
) -> tuple[list[GraphNode], int] {
    for key in (name, normalize_file_path(`root / name)) {
        if (`node := `graph.node(key)) is not None {
            return ([`node], 1);
        }
    }
    exact: any = store.get_nodes_by_name(name);
    real: any = [
        candidate
        for candidate in exact
        if not candidate.is_test and not is_test_file(candidate.file_path, `root)
    ];
    candidates: any = sorted(real or exact, key=lambda (`node) -> any { `node.qualified_name });
    if candidates {
        return (candidates, len(candidates));
    }
    if java_candidates := _java_fqn_candidates(store, name) {
        return (java_candidates, len(java_candidates));
    }
    if "." in name {
        tail: any = store.search_nodes_by_qualified_tail(name, limit=_MAX_DOTTED_TARGET_CANDIDATES);
        if tail {
            return (tail, store.count_nodes_by_qualified_tail(name));
        }
    }
    return (store.search_nodes(name, limit=20), store.count_search_nodes(name));
}

def _unresolved_route_endpoint(
    store: GraphStore,
    `root: Path,
    name: str,
    which: str,
    candidates: list[GraphNode],
    count: int,
    minimal: bool,
) -> dict[str, Any] {
    if not candidates {
        response: dict[str, Any] = {
            "status": "not_found",
            "endpoint": which,
            "summary": f"No node found matching {which} '{name}'.",
        };
        note: any = empty_query_confidence(store, `root, "path_to", name, None);
        if note {
            response["confidence"] = note;
        }
        return response;
    }
    ranked: any = _rank_disambiguation_candidates(candidates[:20], name, `root);
    if minimal {
        ranked = [{key: row[key] for key in ("qualified_name", "kind")} for row in ranked[:5]];
    }
    response = {
        "status": "ambiguous",
        "endpoint": which,
        "summary": f"{which} '{name}' matches {count} node(s). Re-run with a qualified_name from candidates.",
        "candidates": ranked,
        "candidate_count": count,
        "candidates_truncated": operator.gt(count, len(ranked)),
        "hint": f"Use a qualified_name from candidates as {which}.",
    };
    if not minimal {
        response["disambiguation"] = ranked;
    }
    return response;
}

def _query_route(
    store: GraphStore, `root: Path, target: str, to: str, minimal: bool
) -> dict[str, Any] {
    `graph: any;
    `graph = _RouteGraph(store, `root);
    ends: list[GraphNode] = [];
    for (name, which) in ((target, "target"), (to, "to")) {
        candidates: any;
        count: any;
        (candidates, count) = _route_endpoint_candidates(store, `root, `graph, name) as any;
        if len(candidates) != 1 {
            return _unresolved_route_endpoint(
                store, `root, name, which, candidates, count, minimal
            );
        }
        ends.append(candidates[0]);
    }
    start: any;
    finish: any;
    (start, finish) = ends as any;
    root_prefix: any = f"{normalize_file_path(`root)}/";

    def relative(path: str) -> str {
        return _sanitize_name(path.removeprefix(root_prefix));
    }
    def label(`node: GraphNode) -> str {
        return relative(`node.qualified_name);
    }

    response: dict[str, Any] = {
        "status": "ok",
        "pattern": "path_to",
        "target": start.qualified_name,
        "to": finish.qualified_name,
        "description": _QUERY_PATTERNS["path_to"],
        "result_count": 0,
        "results_omitted": 0,
        "results": [],
    };
    if start.qualified_name == finish.qualified_name {
        response["summary"] = "target and to are the same node, so there are no hops.";
        return response;
    }

    route: any;
    complete: any;
    (route, complete) = `graph.route(start.qualified_name, finish.qualified_name) as any;
    if route is None and not complete {
        response["search_incomplete"] = True;
        response["summary"] = f"The search stopped after {_MAX_ROUTE_VISITS} nodes without reaching '{label(finish)}', so a route may still exist. Try nearer ends.";
        return response;
    }
    if route is None {
        response["summary"] = f"No route from '{label(start)}' to '{label(finish)}' through calls, references, inheritance, imports or containment. Callbacks and dynamic dispatch are not in the graph, so this does not prove there is none.";
        if `graph.route(finish.qualified_name, start.qualified_name)[0] is not None {
            response["reverse_route_exists"] = True;
            response["summary"] += " There is a route the other way: swap target and to.";
        }
        note: any = empty_query_confidence(store, `root, "path_to", target, start);
        if note {
            response["confidence"] = note;
        }
        return response;
    }

    def hop_row(source: str, destination: str, certainty: int, `edge: GraphEdge) -> dict[str, Any] {
        if minimal {
            row: dict[str, Any] = {
                "from": relative(source),
                "to": relative(destination),
                "kind": `edge.kind,
                "line": `edge.line,
                "certainty": _HOP_CERTAINTY[certainty],
            };
            source_node: any = `graph.node(source);
            if source_node is not None and `edge.file_path != source_node.file_path {
                row["file"] = relative(`edge.file_path);
            }
            return row;
        }
        row = {
            "from": _sanitize_name(source),
            "to": _sanitize_name(destination),
            "kind": `edge.kind,
            "file_path": `edge.file_path,
            "line": `edge.line,
            "certainty": _HOP_CERTAINTY[certainty],
        };
        if `edge.confidence < 1.0 {
            row["confidence"] = round(`edge.confidence, 2);
        }
        return row;
    }
    weakest: any = max(route, key=lambda (hop) -> any { (hop[2], -hop[3].confidence) });
    weakest_name: any = _HOP_CERTAINTY[weakest[2]];
    response["result_count"] = len(route);
    response["results_omitted"] = max(0, len(route) - _MAX_ROUTE_HOPS);
    response["results"] = [hop_row(*hop) for hop in route[:_MAX_ROUTE_HOPS]];
    response["certainty"] = weakest_name;
    response["weakest_hop"] = hop_row(*weakest);
    response["summary"] = f"'{label(start)}' reaches '{label(finish)}' in {len(route)} hop(s); weakest hop: {weakest_name}.";
    return response;
}

glob max_results_default_: any = MAX_IMPACT_NODES;

glob resolution_default_: any = RESOLUTION_ALL;

def get_impact_radius(
    changed_files: list[str] | None = None,
    max_depth: int = 2,
    max_results: int = max_results_default_,
    repo_root: str | None = None,
    base: str = "HEAD~1",
    detail_level: str = "standard",
    resolution: str = resolution_default_,
    max_files: int = 25,
) -> dict[str, Any] {
    if isinstance(max_results, `bool) or max_results < 1 {
        raise ValueError("max_results must be an integer greater than or equal to 1");
    }
    if isinstance(max_files, `bool) or not isinstance(max_files, `int) or max_files < 1 {
        raise ValueError("max_files must be an integer greater than or equal to 1");
    }
    if resolution not in IMPACT_RESOLUTIONS {
        raise ValueError(
            f"resolution must be one of {`list(IMPACT_RESOLUTIONS)}, got {resolution!r}"
        );
    }

    store: any;
    `root: any;
    (store, `root) = _get_store(repo_root) as any;
    try {
        if changed_files is None {
            (changed_files, base) = discover_review_changes(`root, base) as any;
        }

        if not changed_files {
            if detail_level == "compact" {
                return _compact_impact_response(
                    {
                        "impacted_files": [],
                        "impacted_nodes": [],
                        "total_impacted": 0,
                        "truncated": False,
                    },
                    `root,
                    [],
                    [],
                    max_files,
                    resolution,
                    0,
                );
            }
            return {
                "status": "ok",
                "summary": "No changed files detected.",
                "changed_nodes": [],
                "impacted_nodes": [],
                "impacted_files": [],
                "truncated": False,
                "total_impacted": 0,
            };
        }
        original_tokens: any = estimate_file_tokens(`root, changed_files);
        history_call: any = CallInfo(
            data_dir=store.db_path.parent,
            tool="get_impact_radius_tool",
            detail_level=detail_level,
            files=len(changed_files),
            depth=max_depth,
        );
        abs_files: any;
        unmatched_files: any;
        (abs_files, unmatched_files) = _resolve_graph_file_paths_with_unmatched(
            store, `root, changed_files
        ) as any;
        shown_unmatched: any;
        unmatched_total: any;
        unmatched_cut: any;
        (shown_unmatched, unmatched_total, unmatched_cut) = _bounded(
            unmatched_files, 5 if detail_level == "minimal" else max_results, _MAX_IMPACT_FILES
        ) as any;
        result: any = store.get_impact_radius(
            abs_files, max_depth=max_depth, max_nodes=max_results, resolution=resolution
        );

        if detail_level == "compact" {
            compact_response: any = _compact_impact_response(
                result,
                `root,
                changed_files,
                unmatched_files,
                max_files,
                resolution,
                store.count_unresolved_call_sites({
                    n.name
                    for n in result["changed_nodes"]
                    if n.kind != "File"
                }),
            );
            if not result["impacted_nodes"] {
                language: any = next(
                    (n.language for n in result["changed_nodes"] if n.language), None
                );
                confidence: any = empty_impact_confidence(
                    store, `root, changed_files, abs_files, language
                );
                if confidence {
                    compact_response["confidence"] = confidence;
                }
            }
            attach_context_savings(
                compact_response, original_tokens=original_tokens, call=history_call
            );
            return compact_response;
        }

        impact_scores: any = result.get("impact_scores", {});
        changed_dicts: any = [node_to_dict(n) for n in result["changed_nodes"]];
        changed_qns: any = {n.qualified_name for n in result["changed_nodes"]};
        direct_sites: dict[str, list[Any]] = {};
        for `edge in result["edges"] {
            if `edge.kind in ("CALLS", "REFERENCES")
                and `edge.target_qualified in changed_qns
                and `edge.source_qualified not in changed_qns
            {
                direct_sites.setdefault(`edge.source_qualified, []).append(`edge);
            }
        }
        impacted_dicts: any = [];
        shown_impacted: any;
        _total_shown: any;
        _cut: any;
        (shown_impacted, _total_shown, _cut) = _bounded(
            result["impacted_nodes"], max_results, _MAX_IMPACT_NODES_SHOWN
        ) as any;
        for `node in shown_impacted {
            node_dict: any = node_to_dict(`node);
            score: any = impact_scores.get(`node.qualified_name);
            if score is not None {
                node_dict["impact_score"] = score;
            }
            node_sites: any = direct_sites.get(`node.qualified_name);
            if node_sites {
                first: any = min(node_sites, key=lambda (e) -> any { (e.file_path, e.line) });
                _attach_call_site(node_dict, first);
                if len(node_sites) > 1 {
                    node_dict["call_site_count"] = len(node_sites);
                }
            }
            impacted_dicts.append(node_dict);
        }
        ordered_edges: any = sorted(
            result["edges"],
            key=lambda (e) -> any {
                (e.source_qualified not in changed_qns and e.target_qualified not in changed_qns,)
            },
        );
        shown_edges: any;
        edges_total: any;
        _edges_cut: any;
        (shown_edges, edges_total, _edges_cut) = _bounded(
            ordered_edges, max_results, _MAX_IMPACT_EDGES
        ) as any;
        edge_dicts: any = [edge_to_dict(e) for e in shown_edges];
        edges_omitted: any = edges_total - len(edge_dicts);
        changed_total: any;
        _cn_cut: any;
        (changed_dicts, changed_total, _cn_cut) = _bounded(
            changed_dicts, max_results, _MAX_IMPACT_NODES_SHOWN
        ) as any;
        changed_nodes_omitted: any = changed_total - len(changed_dicts);
        shown_files: any;
        files_total: any;
        _files_cut: any;
        (shown_files, files_total, _files_cut) = _bounded(
            result["impacted_files"], max_results, _MAX_IMPACT_FILES
        ) as any;
        files_omitted: any = files_total - len(shown_files);
        unresolved_call_sites: any = store.count_unresolved_call_sites({
            n.name
            for n in result["changed_nodes"]
            if n.kind != "File"
        });
        truncated: any = result["truncated"]
            or operator.lt(len(impacted_dicts), len(result["impacted_nodes"]))
            or operator.gt(edges_omitted, 0)
            or operator.gt(changed_nodes_omitted, 0)
            or operator.gt(files_omitted, 0);
        total_impacted: any = result["total_impacted"];
        risk: any = "unknown"
            if not abs_files
            else "high" if total_impacted > 20 else "medium" if total_impacted > 5 else "low";

        summary_parts: any = [
            f"Blast radius for {len(changed_files)} changed file(s):",
            f"  - {len(result["changed_nodes"])} nodes directly changed",
            f"  - {total_impacted} nodes impacted (within {max_depth} hops)",
            f"  - {files_total} additional files affected",
        ];
        if unmatched_files {
            summary_parts.append(_unmatched_file_warning(unmatched_files));
        }
        if len(impacted_dicts) < total_impacted {
            summary_parts.append(
                f"  - Results truncated: showing {len(impacted_dicts)} of {total_impacted} impacted nodes",
            );
        }
        if edges_omitted or changed_nodes_omitted or files_omitted {
            summary_parts.append(
                f"  - Also truncated: {edges_omitted} edges, {changed_nodes_omitted} changed nodes, {files_omitted} impacted files omitted",
            );
        }
        confidence = None;
        if not impacted_dicts {
            changed_language: any = next(
                (n.language for n in result["changed_nodes"] if n.language), None
            );
            confidence = empty_impact_confidence(
                store, `root, changed_files, abs_files, changed_language
            );
        }

        if detail_level == "minimal" {
            key_entities: any = [n["name"] for n in impacted_dicts[:5]];
            minimal_response: any = {
                "status": "ok",
                "summary": "\n".join(summary_parts),
                "risk": risk,
                "unmatched_files": shown_unmatched,
                "unmatched_files_total": unmatched_total,
                "unmatched_files_truncated": unmatched_cut,
                "impacted_file_count": len(result["impacted_files"]),
                "key_entities": key_entities,
                "truncated": truncated or unmatched_cut,
                "nodes_omitted": max(0, total_impacted - len(impacted_dicts)),
                "unresolved_call_sites": unresolved_call_sites,
            };
            if confidence {
                minimal_response["confidence"] = confidence;
            }
            attach_context_savings(
                minimal_response, original_tokens=original_tokens, call=history_call
            );
            return minimal_response;
        }

        response: dict[str, Any] = {
            "status": "ok",
            "risk": risk,
            "unmatched_files": shown_unmatched,
            "unmatched_files_total": unmatched_total,
            "unmatched_files_truncated": unmatched_cut,
            "summary": "\n".join(summary_parts),
            "changed_files": changed_files,
            "changed_nodes": changed_dicts,
            "changed_nodes_omitted": changed_nodes_omitted,
            "impacted_nodes": impacted_dicts,
            "impacted_files": shown_files,
            "impacted_files_omitted": files_omitted,
            "edges": edge_dicts,
            "edges_omitted": edges_omitted,
            "truncated": truncated or unmatched_cut,
            "total_impacted": total_impacted,
            "nodes_omitted": max(0, total_impacted - len(impacted_dicts)),
            "resolution": resolution,
            "unresolved_call_sites": unresolved_call_sites,
        };
        if confidence {
            response["confidence"] = confidence;
        }
        attach_context_savings(response, original_tokens=original_tokens, call=history_call);
        return response;
    } except ChangeDiscoveryError as exc {
        return _error_response(`str(exc));
    } finally {
        store.close();
    }
}

glob resolution_default__: any = RESOLUTION_ALL;

def query_graph(
    pattern: str,
    target: str,
    repo_root: str | None = None,
    detail_level: str = "standard",
    max_results: int = 100,
    resolution: str = resolution_default__,
    to: str | None = None,
) -> dict[str, Any] {
    store: any;
    results: list[dict[str, Any]];
    edges_out: list[dict[str, Any]];
    call_sites: list[tuple[str, dict[str, Any], GraphEdge]];
    node_cache: dict[str, GraphNode | None];
    `node: any;
    row: dict[str, Any];
    t: any;
    key: any;
    if isinstance(max_results, `bool) or max_results < 1 {
        raise ValueError("max_results must be an integer greater than or equal to 1");
    }
    if resolution not in QUERY_RESOLUTIONS {
        raise ValueError(
            f"resolution must be one of {`list(QUERY_RESOLUTIONS)}, got {resolution!r}"
        );
    }

    `root: any;
    (store, `root) = _get_store(repo_root) as any;
    try {
        if pattern not in _QUERY_PATTERNS {
            return {
                "status": "error",
                "error": f"Unknown pattern '{pattern}'. Available: {`list(_QUERY_PATTERNS.keys())}",
            };
        }

        minimal: any = operator.eq(detail_level, "minimal");
        if pattern == "path_to" {
            if not to {
                return {"status": "error", "error": "path_to needs to: the node or file to reach."};
            }
            return _query_route(store, `root, target, to, minimal);
        }
        response_limit: any = min(max_results, 5) if minimal else max_results;
        results = [];
        edges_out = [];
        total_results: any = 0;
        inferred_results: any = 0;
        call_sites = [];
        def add_result(result: dict[str, Any], `edge: Any | None = None) {
            total_results += 1;
            if result.get("inferred_by") {
                inferred_results += 1;
            }
            if len(results) >= response_limit {
                return;
            }
            results.append(result);
            if `edge is not None {
                edges_out.append(edge_to_dict(`edge));
            }
        }
        node_cache = {};

        def lookup_node(qualified: str) -> GraphNode | None {
            if qualified not in node_cache {
                node_cache[qualified] = store.get_node(qualified);
            }
            return node_cache[qualified];
        }
        def add_call_site(key: str, result: dict[str, Any], `edge: GraphEdge, certain: bool) {
            if not certain {
                result["target_resolution"] = RESOLUTION_UNRESOLVED;
            }
            if resolution == RESOLUTION_DIRECT and not certain {
                return;
            }
            if resolution == RESOLUTION_UNRESOLVED and certain {
                return;
            }
            call_sites.append((key, _attach_call_site(result, `edge), `edge));
        }
        if pattern == "callers_of" and target in _BUILTIN_CALL_NAMES and "::" not in target {
            return {
                "status": "ok",
                "pattern": pattern,
                "target": target,
                "description": _QUERY_PATTERNS[pattern],
                "summary": f"'{target}' is a common builtin — callers_of skipped to avoid noise.",
                "result_count": 0,
                "results_omitted": 0,
                "results": [],
                "edges": [],
            };
        }
        `node = None;
        same_name_tests: any = 0;
        raw_config_target: any = operator.eq(pattern, "consumers_of") and "::" not in target;
        if pattern != "file_summary" and not raw_config_target {
            `node = store.get_node(target);
            if not `node {
                target_path: any;
                separator: any;
                symbol: any;
                (target_path, separator, symbol) = target.partition("::") as any;
                abs_target: any = f"{normalize_file_path(`root / target_path)}{separator}{symbol}";
                `node = store.get_node(abs_target);
            }
            if not `node {
                exact_candidates: list[GraphNode] = [];
                qualified_tail_candidates: any = [];
                if "." in target {
                    qualified_tail_candidates = store.search_nodes_by_qualified_tail(
                        target, limit=_MAX_DOTTED_TARGET_CANDIDATES
                    );
                }
                java_candidates: any = _java_fqn_candidates(store, target);
                if java_candidates {
                    candidates: any = java_candidates;
                } elif qualified_tail_candidates {
                    candidates = qualified_tail_candidates;
                } elif java_candidates is not None {
                    candidates = _namespaced_member_candidates(store, target);
                } else {
                    (exact_candidates, same_name_tests) = _exact_name_candidates(
                        store, `root, target
                    ) as any;
                    candidates = exact_candidates
                        or store.search_nodes(target, limit=_MAX_BARE_TARGET_CANDIDATES);
                }
                if pattern == "inheritors_of" and "::" not in target {
                    exact_type_candidates: any = [
                        candidate
                        for candidate in candidates
                        if candidate.name == target
                            and candidate.kind in {
                                "Class",
                                "Interface",
                                "Type",
                                "Struct",
                                "Enum",
                                "Trait",
                            }
                    ];
                    if exact_type_candidates {
                        candidates = exact_type_candidates;
                    }
                }
                if len(candidates) == 1 {
                    `node = candidates[0];
                    target = `node.qualified_name;
                } elif len(candidates) > 1 {
                    if java_candidates {
                        candidate_count: any = len(candidates);
                    } elif qualified_tail_candidates {
                        candidate_count = store.count_nodes_by_qualified_tail(target);
                    } elif java_candidates is not None {
                        candidate_count = len(candidates);
                    } elif exact_candidates {
                        candidate_count = len(candidates);
                        candidates = candidates[:_MAX_BARE_TARGET_CANDIDATES];
                    } else {
                        candidate_count = store.count_search_nodes(target);
                    }
                    ranked: any = _rank_disambiguation_candidates(candidates, target, `root);
                    if minimal {
                        shortlist: any = [
                            {key: row[key] for key in ("qualified_name", "kind")}
                            for row in ranked[:response_limit]
                        ];
                        truncated: any = operator.gt(candidate_count, len(shortlist));
                        return {
                            "status": "ambiguous",
                            "summary": f"'{target}' matches {candidate_count} node(s). Re-run with a qualified_name from candidates.",
                            "candidates": shortlist,
                            "candidate_count": candidate_count,
                            "candidates_truncated": truncated,
                            "hint": "Use a qualified_name from candidates as the target parameter."
                                + (" detail_level='standard' lists more." if truncated else ""),
                        };
                    }
                    return {
                        "status": "ambiguous",
                        "summary": f"'{target}' matches {candidate_count} node(s). Re-run with a qualified_name from disambiguation.",
                        "candidates": ranked,
                        "disambiguation": ranked,
                        "candidate_count": candidate_count,
                        "candidates_truncated": operator.gt(candidate_count, len(candidates)),
                        "hint": "Use a qualified_name from disambiguation as the target parameter.",
                    };
                }
            }
        }

        if not `node and pattern not in ("consumers_of", "file_summary") {
            unresolved: dict[str, Any] = {
                "status": "not_found",
                "summary": f"No node found matching '{target}'.",
            };
            unresolved_note: any = empty_query_confidence(store, `root, pattern, target, None);
            if unresolved_note {
                unresolved["confidence"] = unresolved_note;
            }
            return unresolved;
        }

        qn: any = `node.qualified_name if `node else target;

        if pattern == "callers_of" {
            seen_sources: set[str] = set[any]();
            e: any;
            for e in store.iter_edges_by_target(qn) {
                if e.kind == "CALLS" {
                    caller: any = lookup_node(e.source_qualified);
                    if caller {
                        seen_sources.add(e.source_qualified);
                        add_call_site(e.source_qualified, node_to_dict(caller), e, certain=True);
                    }
                }
            }
            if `node {
                cpp_overload_count: any = store.count_nodes_by_name(
                    `node.name, language="cpp", kinds=("Function", "Test")
                )
                    if `node.language == "cpp"
                    else 0;
                for e in store.iter_edges_by_target_name(
                    `node.name, language=`node.language or None
                ) {
                    if "ambiguous_targets" in e.extra
                        or "unresolved_targets" in e.extra
                        or `node.language == "cpp" and e.extra.get("receiver")
                    {
                        continue;
                    }
                    if cpp_overload_count > 1 {
                        continue;
                    }
                    if not store.receiver_evidence_admits(e.extra, `node) {
                        continue;
                    }
                    if e.source_qualified in seen_sources {
                        continue;
                    }
                    caller = lookup_node(e.source_qualified);
                    if caller {
                        add_call_site(e.source_qualified, node_to_dict(caller), e, certain=False);
                    }
                }
            }
        } elif pattern == "references_to" {
            seen_reference_sources: set[str] = set[any]();
            for e in store.iter_edges_by_target(qn) {
                if e.kind != "REFERENCES" {
                    continue;
                }
                source: any = lookup_node(e.source_qualified);
                if source {
                    seen_reference_sources.add(e.source_qualified);
                    add_call_site(e.source_qualified, node_to_dict(source), e, certain=True);
                }
            }
            if `node and store.count_nodes_by_name(`node.name) == 1 {
                for e in store.iter_edges_by_target_name(
                    `node.name, kind="REFERENCES", language=`node.language or None
                ) {
                    if "ambiguous_targets" in e.extra
                        or e.source_qualified in seen_reference_sources
                        or not store.receiver_evidence_admits(e.extra, `node)
                    {
                        continue;
                    }
                    source = lookup_node(e.source_qualified);
                    if source {
                        add_call_site(e.source_qualified, node_to_dict(source), e, certain=False);
                    }
                }
            }
        } elif pattern == "callees_of" {
            described_targets: set[str] = set[any]();
            for e in store.iter_edges_by_source(qn) {
                if e.kind != "CALLS" {
                    continue;
                }
                callee: any = lookup_node(e.target_qualified);
                if callee {
                    add_call_site(e.target_qualified, node_to_dict(callee), e, certain=True);
                } elif isinstance(e.extra.get("ambiguous_targets"), `list)
                    or isinstance(e.extra.get("unresolved_targets"), `list)
                    or "::" not in e.target_qualified
                    or `node is not None and `node.language == "cpp"
                {
                    unresolved = e.extra.get("ambiguous_targets")
                        or e.extra.get("unresolved_targets");
                    result: dict[str, Any] = {
                        "kind": "Function",
                        "name": e.target_qualified,
                        "qualified_name": e.target_qualified,
                    };
                    first_sighting: any = e.target_qualified not in described_targets;
                    described_targets.add(e.target_qualified);
                    if isinstance(unresolved, `list) and first_sighting {
                        candidate_resolution: any = "ambiguous"
                            if e.extra.get("ambiguous_targets")
                            else "unresolved";
                        result["resolution"] = candidate_resolution;
                        result["candidates"] = [
                            _sanitize_name(candidate)
                            for candidate in unresolved[:20]
                            if isinstance(candidate, `str)
                        ];
                        candidate_count = e.extra.get(f"{candidate_resolution}_target_count");
                        if not isinstance(candidate_count, `int) {
                            candidate_count = len(unresolved);
                        }
                        result["candidate_count"] = candidate_count;
                        result["candidates_truncated"] = `bool(
                            e.extra.get(f"{candidate_resolution}_targets_truncated")
                                or operator.gt(candidate_count, len(result["candidates"])),
                        );
                    }
                    add_call_site(e.target_qualified, result, e, certain=False);
                }
            }
        } elif pattern == "imports_of" {
            for e in store.iter_edges_by_source(qn) {
                if e.kind == "IMPORTS_FROM" {
                    row = {"import_target": e.target_qualified};
                    scope: any = e.extra.get(IMPORT_SCOPE_KEY);
                    if scope {
                        row["import_target_kind"] = scope;
                    }
                    add_result(row, e);
                }
            }
        } elif pattern == "importers_of" {
            abs_target = `str((`root / target).resolve()) if `node is None else `node.file_path;
            seen_importers: set[str] = set[any]();
            for e in store.iter_edges_by_target(abs_target) {
                if e.kind == "IMPORTS_FROM" {
                    if e.source_qualified in seen_importers {
                        continue;
                    }
                    seen_importers.add(e.source_qualified);
                    add_result({"importer": e.source_qualified, "file": e.file_path}, e);
                }
            }
            for (directory, scopes) in import_scope_ancestors(abs_target) {
                for e in store.iter_edges_by_target(directory) {
                    if e.kind != "IMPORTS_FROM" {
                        continue;
                    }
                    if e.extra.get(IMPORT_SCOPE_KEY) not in scopes {
                        continue;
                    }
                    if e.source_qualified in seen_importers {
                        continue;
                    }
                    seen_importers.add(e.source_qualified);
                    add_result(
                        {
                            "importer": e.source_qualified,
                            "file": e.file_path,
                            "via_package": directory,
                        },
                        e,
                    );
                }
            }
            if `node is not None and `node.language == "csharp" {
                declared_ns: list[str] = [];
                n: any;
                for n in store.iter_nodes_by_file(`node.file_path) {
                    if n.kind == "File" {
                        declared_ns = `list(n.extra.get("csharp_namespaces", []) or []);
                        break;
                    }
                }
                for ns in declared_ns {
                    for e in store.iter_edges_by_target(ns) {
                        if e.kind != "IMPORTS_FROM" {
                            continue;
                        }
                        if e.source_qualified in seen_importers {
                            continue;
                        }
                        seen_importers.add(e.source_qualified);
                        add_result({"importer": e.source_qualified, "file": e.file_path}, e);
                    }
                }
            }
        } elif pattern == "children_of" {
            for e in store.iter_edges_by_source(qn) {
                if e.kind == "CONTAINS" {
                    child: any = store.get_node(e.target_qualified);
                    if child {
                        add_result(node_to_dict(child));
                    }
                }
            }
        } elif pattern == "tests_for" {
            seen: set[str] = set[any]();
            for `match in store.get_transitive_tests(qn) {
                test_qn: any = `match.get("qualified_name");
                if not isinstance(test_qn, `str) or test_qn in seen {
                    continue;
                }
                `test: any = store.get_node(test_qn);
                if `test {
                    result = node_to_dict(`test);
                    result["indirect"] = `bool(`match.get("indirect", False));
                    add_result(result);
                    seen.add(test_qn);
                }
            }
            for test_qn in store.get_ambiguous_call_tests(qn) {
                `test = store.get_node(test_qn);
                if `test is None or test_qn in seen or not `test.is_test {
                    continue;
                }
                result = node_to_dict(`test);
                result["indirect"] = False;
                result["inferred_by"] = "ambiguous_call";
                add_result(result);
                seen.add(test_qn);
            }
            name: any = `node.name if `node else target;
            cpp_overload_set: any = `bool(
                `node
                    and operator.eq(`node.language, "cpp")
                    and operator.gt(
                        store.count_nodes_by_name(
                            `node.name, language="cpp", kinds=("Function", "Test")
                        ),
                        1,
                    ),
            );
            test_nodes: any = [];
            if not cpp_overload_set {
                test_nodes = store.search_nodes(f"test_{name}", limit=10);
                test_nodes += store.search_nodes(f"Test{name}", limit=10);
                if `node and `node.kind == "Class" {
                    for suffix in ("Test", "Tests", "IT", "Spec") {
                        test_nodes += [
                            t
                            for t in store.search_nodes(f"{name}{suffix}", limit=10)
                            if t.name == f"{name}{suffix}" and t.kind == "Class"
                        ];
                    }
                }
            }
            for t in test_nodes {
                if t.qualified_name not in seen and t.is_test and _test_is_named_after(t, name) {
                    result = node_to_dict(t);
                    result["indirect"] = False;
                    result["inferred_by"] = "naming_convention";
                    add_result(result);
                    seen.add(t.qualified_name);
                }
            }
        } elif pattern == "inheritors_of" {
            for e in store.iter_edges_by_target(qn) {
                if e.kind in ("INHERITS", "IMPLEMENTS") {
                    child = store.get_node(e.source_qualified);
                    if child {
                        add_result(node_to_dict(child), e);
                    }
                }
            }
            if total_results == 0 and `node {
                languages: any = _compatible_edge_languages(`node.language)
                    if `node.language
                    else (None,);
                ambiguous_base: any = operator.gt(
                    sum(
                        store.count_nodes_by_name(
                            `node.name, language=language, kinds=("Class", "Type")
                        )
                        for language in languages,
                    ),
                    1,
                );
                for kind in ("INHERITS", "IMPLEMENTS") {
                    for e in store.iter_edges_by_target_name(
                        `node.name, kind=kind, language=`node.language or None
                    ) {
                        child = store.get_node(e.source_qualified);
                        if child {
                            child_result: any = node_to_dict(child);
                            if ambiguous_base {
                                child_result["inferred_by"] = "bare_name";
                            }
                            add_result(child_result, e);
                        }
                    }
                }
            }
        } elif pattern == "triggers_of" {
            `edge: any;
            for `edge in store.get_edges_by_source(qn) {
                if `edge.kind != "TRIGGERS" {
                    continue;
                }
                triggered: any = store.get_node(`edge.target_qualified);
                if triggered {
                    add_result(node_to_dict(triggered), `edge);
                } else {
                    edges_out.append(edge_to_dict(`edge));
                }
            }
        } elif pattern == "triggered_by" {
            for `edge in store.get_edges_by_target(qn) {
                if `edge.kind != "TRIGGERS" {
                    continue;
                }
                trigger: any = store.get_node(`edge.source_qualified);
                if trigger {
                    add_result(node_to_dict(trigger), `edge);
                } else {
                    edges_out.append(edge_to_dict(`edge));
                }
            }
        } elif pattern in ("publishers_of", "listeners_of") {
            edge_kind: any = "PUBLISHES" if pattern == "publishers_of" else "HANDLES";
            for `edge in store.get_edges_by_target(qn) {
                if `edge.kind != edge_kind {
                    continue;
                }
                source = store.get_node(`edge.source_qualified);
                if source {
                    add_result(node_to_dict(source), `edge);
                } else {
                    edges_out.append(edge_to_dict(`edge));
                }
            }
        } elif pattern == "advises" {
            for `edge in store.get_edges_by_source(qn) {
                if `edge.kind != "CALLS" or not `edge.extra.get("aop_resolved") {
                    continue;
                }
                target_node: any = store.get_node(`edge.target_qualified);
                if target_node {
                    add_result(node_to_dict(target_node), `edge);
                } else {
                    edges_out.append(edge_to_dict(`edge));
                }
            }
        } elif pattern == "advised_by" {
            for `edge in store.get_edges_by_target(qn) {
                if `edge.kind != "CALLS" or not `edge.extra.get("aop_resolved") {
                    continue;
                }
                advice_node: any = store.get_node(`edge.source_qualified);
                if advice_node {
                    add_result(node_to_dict(advice_node), `edge);
                } else {
                    edges_out.append(edge_to_dict(`edge));
                }
            }
        } elif pattern == "handlers_of" {
            for `edge in store.get_edges_by_target(qn) {
                if `edge.kind != "HANDLES" {
                    continue;
                }
                handler: any = store.get_node(`edge.source_qualified);
                if handler {
                    add_result(node_to_dict(handler), `edge);
                } else {
                    edges_out.append(edge_to_dict(`edge));
                }
            }
        } elif pattern == "endpoints_for" {
            for `edge in store.get_edges_by_source(qn) {
                if `edge.kind != "HANDLES" {
                    continue;
                }
                endpoint: any = store.get_node(`edge.target_qualified);
                if endpoint and endpoint.kind == "Endpoint" {
                    add_result(node_to_dict(endpoint), `edge);
                } elif endpoint is None {
                    edges_out.append(edge_to_dict(`edge));
                }
            }
        } elif pattern == "consumers_of" {
            raw_key: any = `node.name if `node else target.removeprefix("config:");
            raw_key = raw_key.removesuffix(".*");
            key = normalize_spring_config_key(raw_key);
            seen_config_sources: set[str] = set[any]();
            for `edge in store.get_config_consumers(key) {
                consumer: any = store.get_node(`edge.source_qualified);
                if consumer and consumer.qualified_name not in seen_config_sources {
                    add_result(node_to_dict(consumer), `edge);
                    seen_config_sources.add(consumer.qualified_name);
                } elif consumer is None {
                    edges_out.append(edge_to_dict(`edge));
                }
            }
        } elif pattern == "file_summary" {
            graph_paths: any = _resolve_graph_file_paths(store, `root, [target]);
            for graph_path in graph_paths {
                for n in store.iter_nodes_by_file(graph_path) {
                    add_result(node_to_dict(n));
                }
            }
        }

        resolution_split: dict[str, int] | None = None;
        distinct_nodes: any = 0;
        if pattern in _CALL_SITE_PATTERNS {
            resolution_split = {RESOLUTION_DIRECT: 0, RESOLUTION_UNRESOLVED: 0};
            distinct_keys: set[str] = set[any]();
            for (key, row, _edge) in call_sites {
                distinct_keys.add(key);
                bucket: any = RESOLUTION_UNRESOLVED
                    if row.get("target_resolution") == RESOLUTION_UNRESOLVED
                    else RESOLUTION_DIRECT;
                resolution_split[bucket] += 1;
            }
            distinct_nodes = len(distinct_keys);
            for (row, `edge) in _interleave_call_sites(call_sites) {
                add_result(row, `edge);
            }
        }

        results_omitted: any = max(0, total_results - len(results));
        if pattern in _CALL_SITE_PATTERNS {
            summary: any = f"Found {total_results} call site(s) across {distinct_nodes} node(s) for {pattern}('{target}')";
        } else {
            summary = f"Found {total_results} result(s) for {pattern}('{target}')";
        }
        if results_omitted {
            summary += f" — showing {len(results)}, {results_omitted} omitted";
        }
        if same_name_tests {
            summary += f" — skipped {same_name_tests} same-named test symbol(s)";
        }
        if pattern == "tests_for" and inferred_results {
            summary += f"; {inferred_results} of them guesses (see inferred_by)";
        }
        confidence: str | None = None;
        if total_results == 0 {
            confidence = empty_query_confidence(store, `root, pattern, target, `node);
        } elif resolution == RESOLUTION_ALL {
            confidence = guessed_calls_confidence(resolution_split);
        }

        if detail_level == "minimal" {
            result_fields: tuple[str, ...] = ("name", "kind", "file_path", "indirect");
            if pattern in ("inheritors_of", "tests_for") {
                result_fields += ("inferred_by",);
            }
            if pattern in _CALL_SITE_PATTERNS {
                result_fields += ("call_site", "target_resolution");
            }
            minimal_results: any = [{k: r[k] for k in result_fields if k in r} for r in results];
            minimal_response: dict[str, Any] = {
                "status": "ok",
                "pattern": pattern,
                "target": target,
                "description": _QUERY_PATTERNS[pattern],
                "summary": summary,
                "result_count": total_results,
                "results_omitted": results_omitted,
                "results": minimal_results,
            };
            if resolution_split is not None {
                minimal_response["distinct_nodes"] = distinct_nodes;
                minimal_response["resolution_split"] = resolution_split;
            }
            if confidence {
                minimal_response["confidence"] = confidence;
            }
            return minimal_response;
        }

        response: dict[str, Any] = {
            "status": "ok",
            "pattern": pattern,
            "target": target,
            "description": _QUERY_PATTERNS[pattern],
            "summary": summary,
            "result_count": total_results,
            "results_omitted": results_omitted,
            "results": results,
            "edges": edges_out,
        };
        if resolution_split is not None {
            response["distinct_nodes"] = distinct_nodes;
            response["resolution_split"] = resolution_split;
        }
        if confidence {
            response["confidence"] = confidence;
        }
        return response;
    } finally {
        store.close();
    }
}

obj _SourceBudget {
    has _root: any,
        _followed: any,
        _left: any,
        _chars_left: any,
        _per_node: any,
        _files: any,
        omitted: any;

    def init(`root: Path, total: int, per_node: int, followed: set[str] | None = None) {
        self._root = `root;
        self._followed = followed or set[any]();
        self._left = total;
        self._chars_left = _MAX_SEARCH_SOURCE_CHARS;
        self._per_node = per_node;
        self._files = {};
        self.omitted = 0;
    }

    has exhausted: bool {
        getter {
            return operator.le(self._left, 0) or operator.le(self._chars_left, 0);
        }
    }

    def _lines(raw_path: str) -> list[str] {
        lines: any = self._files.get(raw_path);
        if lines is not None {
            return lines;
        }
        path: any = Path(raw_path);
        if not path.is_absolute() {
            path = self._root / path;
        }
        try {
            if not path_within_repo(self._root, path, self._followed) {
                raise ValueError("outside the repository");
            }
            text: any = path.read_text(encoding="utf-8", errors="replace");
            if path.suffix.lower() == ".ipynb"
                or text.split("\n", 1)[0] == "# Databricks notebook source"
            {
                lines = [];
            } else {
                lines = text.split("\n");
            }
        } except (OSError, UnicodeDecodeError, ValueError) as exc {
            logger.warning("Could not read %s for a source snippet: %s", raw_path, exc);
            lines = [];
        }
        self._files[raw_path] = lines;
        return lines;
    }

    def attach(target: dict[str, Any], raw_path: Any, start: Any, end: Any) -> bool {
        if not raw_path or not start or not end or end < start {
            return False;
        }
        if self.exhausted {
            self.omitted += 1;
            return False;
        }
        lines: any = self._lines(raw_path);
        if not lines {
            return False;
        }
        span: any = min(end - start + 1, self._per_node, self._left);
        if span <= 0 {
            self.omitted += 1;
            return False;
        }
        snippet: any = lines[start - 1:start - 1 + span];
        if not snippet {
            return False;
        }
        text: any = "\n".join(snippet);
        char_cap: any = min(_MAX_SEARCH_SOURCE_CHARS_PER_NODE, self._chars_left);
        cut: any = operator.gt(len(text), char_cap);
        if cut {
            text = text[:char_cap];
        }
        target["source"] = text;
        target["source_lines"] = [start, start + text.count("\n")];
        if cut or end - start + 1 > len(snippet) {
            target["source_truncated"] = True;
        }
        self._left -= len(snippet);
        self._chars_left -= len(text);
        return True;
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

def _neighbor_entry(`node: GraphNode) -> dict[str, Any] {
    return {
        "name": _sanitize_name(`node.name),
        "qualified_name": _sanitize_name(`node.qualified_name),
        "kind": `node.kind,
        "file_path": `node.file_path,
        "line_start": `node.line_start,
        "line_end": `node.line_end,
    };
}

def _stored_qualified_name(store: GraphStore, hit: dict[str, Any]) -> str | None {
    qname: any = hit.get("qualified_name");
    if not qname or len(qname) < _SANITIZED_NAME_MAX {
        return qname;
    }
    for `node in store.get_nodes_by_file(hit.get("file_path") or "") {
        if `node.line_start == hit.get("line_start")
            and _sanitize_name(`node.qualified_name) == qname
        {
            return `node.qualified_name;
        }
    }
    return qname;
}

def _attach_neighbors(results: list[dict[str, Any]], store: GraphStore, budget: _SourceBudget) {
    for hit in results[:_MAX_EXPANDED_HITS] {
        qname: any = _stored_qualified_name(store, hit);
        if not qname {
            continue;
        }
        try {
            incoming: any = store.get_edges_by_target(qname);
            outgoing: any = store.get_edges_by_source(qname);
        } except Exception as exc {
            logger.warning("Neighbour lookup failed for %s: %s", qname, exc);
            continue;
        }

        for (key, edges, attr) in (
            ("callers", incoming, "source_qualified"),
            ("callees", outgoing, "target_qualified"),
        ) {
            seen: set[str] = set[any]();
            entries: list[dict[str, Any]] = [];
            for `edge in edges {
                if `edge.kind != "CALLS" {
                    continue;
                }
                if len(entries) >= _MAX_NEIGHBORS_PER_HIT {
                    break;
                }
                if budget.exhausted {
                    budget.omitted += 1;
                    break;
                }
                other: any = getattr(`edge, attr, None);
                if not other or other in seen or other == qname {
                    continue;
                }
                seen.add(other);
                `node: any = store.get_node(other);
                if `node is None {
                    continue;
                }
                `entry: any = _neighbor_entry(`node);
                if budget.attach(`entry, `node.file_path, `node.line_start, `node.line_end) {
                    entries.append(`entry);
                }
            }
            if entries {
                hit[key] = entries;
            }
        }
    }
}

glob max_source_lines_default_: any = _MAX_SEARCH_SOURCE_LINES_PER_NODE;

def semantic_search_nodes(
    query: str,
    kind: str | None = None,
    limit: int = 20,
    repo_root: str | None = None,
    context_files: list[str] | None = None,
    model: str | None = None,
    provider: str | None = None,
    detail_level: str = "standard",
    include_source: bool = False,
    expand_neighbors: bool = False,
    max_source_lines: int = max_source_lines_default_,
) -> dict[str, Any] {
    _validate_positive_int(limit, "limit");
    shown_limit: any = min(
        limit,
        _MAX_SEARCH_RESULTS_MINIMAL if detail_level == "minimal" else _MAX_SEARCH_RESULTS_STANDARD,
    );
    window: any = shown_limit * _SEARCH_WINDOW_FACTOR;

    store: any;
    `root: any;
    (store, `root) = _get_store(repo_root) as any;
    try {
        mode_out: list[str] = [];
        ranked: any = hybrid_search(
            store,
            query,
            kind=kind,
            limit=window,
            context_files=context_files,
            model=model,
            provider=provider,
            _out_mode=mode_out,
            repo_root=`root,
        );
        results: any;
        total: any;
        truncated: any;
        (results, total, truncated) = _bounded(ranked, shown_limit, shown_limit) as any;
        lower_bound: any = operator.ge(total, window);
        bounds: dict[str, Any] = {
            "result_count": total,
            "total": total,
            "truncated": truncated,
            "results_omitted": total - len(results),
        };
        if lower_bound {
            bounds["total_is_lower_bound"] = True;
        }

        search_mode: any = mode_out[0] if mode_out else "keyword";

        source_omitted: any = 0;
        if include_source and results and detail_level != "minimal" {
            per_node: any = min(max(`int(max_source_lines), 1), _MAX_SEARCH_SOURCE_LINES_PER_NODE);
            budget: any = _SourceBudget(
                `root,
                _MAX_EXPANDED_SOURCE_LINES if expand_neighbors else _MAX_SEARCH_SOURCE_LINES,
                per_node,
                followed_files(store),
            );
            top: any = results[:_MAX_EXPANDED_HITS] if expand_neighbors else results;
            hit: any;
            for hit in top {
                budget.attach(
                    hit, hit.get("file_path"), hit.get("line_start"), hit.get("line_end")
                );
            }
            if expand_neighbors {
                _attach_neighbors(results, store, budget);
            }
            for hit in results[len(top):] {
                budget.attach(
                    hit, hit.get("file_path"), hit.get("line_start"), hit.get("line_end")
                );
            }
            source_omitted = budget.omitted;
        }

        total_text: any = f"{total}+" if lower_bound else `str(total);
        summary: any = f"Found {total_text} node(s) matching '{query}'"
            + (f" (kind={kind})" if kind else "")
            + _shown_of(len(results), total);
        confidence: any = empty_search_confidence(store, `root, query) if not results else None;

        if detail_level == "minimal" {
            minimal_results: any = [
                {k: r[k] for k in ("name", "kind", "file_path", "score") if k in r}
                for r in results
            ];
            minimal_response: dict[str, Any] = {
                "status": "ok",
                "query": query,
                "search_mode": search_mode,
                "summary": summary,
                "results": minimal_results,
                **bounds,
            };
            if confidence {
                minimal_response["confidence"] = confidence;
            }
            return minimal_response;
        }

        result: dict[str, object] = {
            "status": "ok",
            "query": query,
            "search_mode": search_mode,
            "summary": summary,
            "results": results,
            **bounds,
        };
        if source_omitted {
            result["source_omitted"] = source_omitted;
        }
        if confidence {
            result["confidence"] = confidence;
        }
        result["_hints"] = generate_hints("semantic_search_nodes_tool", result, get_session());
        return result;
    } finally {
        store.close();
    }
}

def list_graph_stats(repo_root: str | None = None) -> dict[str, Any] {
    store: any;
    `root: any;
    (store, `root) = _get_store(repo_root) as any;
    try {
        stats: any = store.get_stats();

        summary_parts: any = [
            f"Graph statistics for {`root.name}:",
            f"  Files: {stats.files_count}",
            f"  Total nodes: {stats.total_nodes}",
            f"  Total edges: {stats.total_edges}",
            f"  Languages: {", ".join(stats.languages) if stats.languages else "none"}",
            f"  Last updated: {stats.last_updated or "never"}",
            "",
            "Nodes by kind:",
        ];
        kind: any;
        count: any;
        for (kind, count) in sorted(stats.nodes_by_kind.items()) {
            summary_parts.append(f"  {kind}: {count}");
        }
        summary_parts.append("");
        summary_parts.append("Edges by kind:");
        for (kind, count) in sorted(stats.edges_by_kind.items()) {
            summary_parts.append(f"  {kind}: {count}");
        }
        calls_by_resolution: any = store.count_edges_by_resolution("CALLS");
        summary_parts.append("");
        summary_parts.append(
            "CALLS by target resolution: "
                + format(calls_by_resolution["direct"], "")
                + " direct, "
                + format(calls_by_resolution["unresolved"], "")
                + " unresolved",
        );
        emb_store: any = EmbeddingStore(get_db_path(`root));
        try {
            emb_count: any = emb_store.count();
            summary_parts.append("");
            summary_parts.append(f"Embeddings: {emb_count} nodes embedded");
            if not emb_store.available {
                summary_parts.append("  (install sentence-transformers for semantic search)");
            }
        } finally {
            emb_store.close();
        }

        return {
            "status": "ok",
            "summary": "\n".join(summary_parts),
            "total_nodes": stats.total_nodes,
            "total_edges": stats.total_edges,
            "nodes_by_kind": stats.nodes_by_kind,
            "edges_by_kind": stats.edges_by_kind,
            "calls_by_resolution": calls_by_resolution,
            "languages": stats.languages,
            "files_count": stats.files_count,
            "last_updated": stats.last_updated,
            "embeddings_count": emb_count,
        };
    } finally {
        store.close();
    }
}

def find_large_functions(
    min_lines: int = 50,
    kind: str | None = None,
    file_path_pattern: str | None = None,
    limit: int = 50,
    repo_root: str | None = None,
    detail_level: str = "standard",
) -> dict[str, Any] {
    _validate_positive_int(limit, "limit");
    minimal: any = operator.eq(detail_level, "minimal");
    shown_limit: any = min(
        limit, _MAX_LARGE_FUNCTIONS_MINIMAL if minimal else _MAX_LARGE_FUNCTIONS_STANDARD
    );

    store: any;
    `root: any;
    (store, `root) = _get_store(repo_root) as any;
    try {
        total: any = store.count_nodes_by_size(
            min_lines=min_lines, kind=kind, file_path_pattern=file_path_pattern
        );
        nodes: any = store.get_nodes_by_size(
            min_lines=min_lines, kind=kind, file_path_pattern=file_path_pattern, limit=shown_limit
        );

        results: any = [];
        for n in nodes {
            d: any = node_to_dict(n);
            d["line_count"] = n.line_end - n.line_start + 1 if n.line_start and n.line_end else 0;
            try {
                d["relative_path"] = `str(Path(n.file_path).relative_to(`root));
            } except ValueError {
                d["relative_path"] = n.file_path;
            }
            results.append(d);
        }

        summary_parts: any = [
            f"Found {total} node(s) with >= {min_lines} lines"
                + (f" (kind={kind})" if kind else "")
                + (f" matching '{file_path_pattern}'" if file_path_pattern else "")
                + _shown_of(len(results), total)
                + ":",
        ];
        for r in results[:10] {
            summary_parts.append(
                "  "
                    + format(r["line_count"], ">4")
                    + " lines | "
                    + format(r["kind"], ">8")
                    + " | "
                    + format(r["name"], "")
                    + " ("
                    + format(r["relative_path"], "")
                    + ":"
                    + format(r["line_start"], "")
                    + ")",
            );
        }
        if len(results) > 10 {
            summary_parts.append(f"  ... and {len(results) - 10} more");
        }

        if minimal {
            results = [
                {
                    key: row[key]
                    for key in ("name", "kind", "relative_path", "line_start", "line_count")
                    if key in row
                }
                for row in results
            ];
        }

        return {
            "status": "ok",
            "summary": "\n".join(summary_parts),
            "total_found": total,
            "total": total,
            "result_count": total,
            "results_omitted": total - len(results),
            "truncated": operator.gt(total, len(results)),
            "min_lines": min_lines,
            "results": results,
        };
    } finally {
        store.close();
    }
}

def traverse_graph_func(
    query: str,
    mode: str = "bfs",
    depth: int = 3,
    token_budget: int = 2000,
    repo_root: str | None = None,
) -> dict[str, Any] {
    _validate_positive_int(token_budget, "token_budget");
    token_budget = min(token_budget, _MAX_TRAVERSAL_TOKEN_BUDGET);

    store: any;
    `root: any;
    (store, `root) = _get_store(repo_root) as any;
    try {
        result_ids: list[int] = [];
        results: any = hybrid_search(store, query, limit=1, _out_ids=result_ids);
        start: any = store.get_node_by_id(result_ids[0]) if result_ids else None;
        if not results or start is None {
            return {"error": f"No node matching '{query}'", "nodes": []};
        }

        start_qn: any = start.qualified_name;
        depth = max(1, min(depth, 6));
        visited: dict[str, int] = {};
        queue: list[tuple[str, int]] = [(start_qn, 0)];
        traversal: list[dict] = [];
        approx_tokens: any = 0;

        while queue {
            if mode == "bfs" {
                current_qn: any;
                cur_depth: any;
                (current_qn, cur_depth) = queue.pop(0) as any;
            } else {
                (current_qn, cur_depth) = queue.pop() as any;
            }
            seen_at: any = visited.get(current_qn);
            if seen_at is not None and seen_at <= cur_depth {
                continue;
            }
            if cur_depth > depth {
                continue;
            }

            visited[current_qn] = cur_depth;
            `node: any = store.get_node(current_qn);
            if not `node {
                continue;
            }

            if seen_at is None {
                `entry: any = {
                    "name": _sanitize_name(`node.name),
                    "qualified_name": `node.qualified_name,
                    "kind": `node.kind,
                    "file": `node.file_path,
                    "depth": cur_depth,
                };
                approx_tokens += len(`str(`entry)) // 4;
                if approx_tokens > token_budget {
                    break;
                }

                traversal.append(`entry);
            }
            out_edges: any = store.get_edges_by_source(current_qn);
            in_edges: any = store.get_edges_by_target(current_qn);
            next_depth: any = cur_depth + 1;
            e: any;
            for e in out_edges {
                tgt: any = e.target_qualified;
                if visited.get(tgt, next_depth + 1) > next_depth {
                    queue.append((tgt, next_depth));
                }
            }
            for e in in_edges {
                src: any = e.source_qualified;
                if visited.get(src, next_depth + 1) > next_depth {
                    queue.append((src, next_depth));
                }
            }
        }

        return {
            "start_node": _sanitize_name(start_qn),
            "mode": mode,
            "max_depth": depth,
            "token_budget": token_budget,
            "nodes_visited": len(traversal),
            "traversal": traversal,
            "truncated": operator.gt(approx_tokens, token_budget),
            "next_tool_suggestions": [
                "query_graph_tool callers_of -- focused relationship query",
                "get_impact_radius_tool -- blast radius analysis",
            ],
        };
    } finally {
        store.close();
    }
}
