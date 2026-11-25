impl _resolve_attr(name: str) -> any {
    g: any = globals();
    if name in g {
        return g[name];
    }
    return __getattr__(name);
}

impl __getattr__(name: str) -> any {
    if name in _LAZY_TOOL_NAMES {
        _tools_mod: any = importlib.import_module("code_review_graph.tools");
        val: any = getattr(_tools_mod, name);
        globals()[name] = val;
        return val;
    }
    if name in _LAZY_PROMPT_NAMES {
        _prompts_mod: any = importlib.import_module("code_review_graph.prompts");
        val = getattr(_prompts_mod, name);
        globals()[name] = val;
        return val;
    }
    raise AttributeError(f"module {__name__!r} has no attribute {name!r}");
}

impl _resolve_repo_root(repo_root: Optional[str]) -> Optional[str] {
    if _multi_repo {
        return _registered_repo_root(repo_root);
    }
    return repo_root or _default_repo_root;
}

impl _registered_repo_root(repo_root: Optional[str]) -> str {
    if not repo_root {
        raise ToolError(
            "repo_root is required. This server serves several repositories (serve --multi-repo), so every call must name one: pass the absolute path of a registered repository. list_repos_tool lists them.",
        );
    }
    candidate: any = Path(repo_root);
    if not candidate.is_absolute() {
        raise ToolError(
            f"repo_root must be an absolute path on this server, got: {_sanitize_name(repo_root)}"
        );
    }
    try {
        wanted: any = candidate.resolve();
        registered: any = Registry().list_repos();
    } except (OSError, RuntimeError, ValueError) as exc {
        raise ToolError(f"repo_root cannot be checked: {exc}") from exc;
    }

    wanted_key: any = os.path.normcase(`str(wanted));
    for `entry in registered {
        path: any = `entry.get("path") if isinstance(`entry, `dict) else None;
        if not isinstance(path, `str) or not path {
            continue;
        }
        try {
            known: any = Path(path).resolve();
        } except (OSError, RuntimeError, ValueError) {
            continue;
        }
        if os.path.normcase(`str(known)) == wanted_key {
            return `str(known);
        }
    }
    raise ToolError(
        f"repo_root is not a registered repository: {_sanitize_name(`str(wanted))}. This server only serves registered repositories: run `code-review-graph register <path>` to add one, or call list_repos_tool to see them.",
    );
}

impl _run_off_loop(work: Callable[[], dict]) -> dict {
    return await anyio.to_thread.run_sync(work, abandon_on_cancel=True);
}

impl _offload(
    tool_name: str,
    work: Callable[[], dict],
    `root: str | None,
    *,
    provenance: bool = True,
    bounded: bool = True,
    timeout_hint: str = timeout_hint_default_,
) -> dict {
    error_response: any;
    def run_fn -> Any {
        for name in getattr(getattr(work, "__code__", None), "co_names", ()) {
            if name in _LAZY_TOOL_NAMES and name not in globals() {
                _resolve_attr(name);
            }
        }
        if provenance {
            return _resolve_attr("with_provenance")(work(), `root);
        }
        return work();
    }

    tool_timeout: any = env_int("CRG_TOOL_TIMEOUT", 0);
    if not bounded or tool_timeout <= 0 {
        return await _run_off_loop(run_fn);
    }

    try {
        return await asyncio.wait_for(_run_off_loop(run_fn), timeout=tool_timeout);
    } except asyncio.TimeoutError {
        message: any = f"{tool_name} timed out after {tool_timeout}s. {timeout_hint}";
        error_response = {"status": "error", "error": message, "summary": message};
        if not provenance {
            return error_response;
        }
        return await _run_off_loop(
            lambda -> any { _resolve_attr("with_provenance")(error_response, `root) }
        );
    }
}

impl build_or_update_graph_tool(
    full_rebuild: bool = False,
    repo_root: Optional[str] = None,
    base: Optional[str] = None,
    postprocess: str = "full",
    recurse_submodules: Optional[bool] = None,
    embedding_provider: Optional[str] = None,
    embedding_model: Optional[str] = None,
) -> dict {
    `root: any;
    `root = _resolve_repo_root(repo_root);
    return await _offload(
        "build_or_update_graph_tool",
        lambda -> any {
            _resolve_attr("build_or_update_graph")(
                full_rebuild=full_rebuild,
                repo_root=`root,
                base=base,
                postprocess=postprocess,
                recurse_submodules=recurse_submodules,
                embedding_provider=embedding_provider,
                embedding_model=embedding_model,
            )
        },
        `root,
        bounded=False,
    );
}

impl run_postprocess_tool(
    flows: bool = True,
    communities: bool = True,
    fts: bool = True,
    repo_root: Optional[str] = None,
    embedding_provider: Optional[str] = None,
    embedding_model: Optional[str] = None,
) -> dict {
    `root: any;
    `root = _resolve_repo_root(repo_root);
    return await _offload(
        "run_postprocess_tool",
        lambda -> any {
            _resolve_attr("run_postprocess")(
                flows=flows,
                communities=communities,
                fts=fts,
                repo_root=`root,
                embedding_provider=embedding_provider,
                embedding_model=embedding_model,
            )
        },
        `root,
        bounded=False,
    );
}

impl get_minimal_context_tool(
    task: str = "",
    changed_files: Optional[list[str]] = None,
    repo_root: Optional[str] = None,
    base: str = "HEAD~1",
) -> dict {
    `root: any;
    `root = _resolve_repo_root(repo_root);
    return await _offload(
        "get_minimal_context_tool",
        lambda -> any {
            _resolve_attr("get_minimal_context")(
                task=task, changed_files=changed_files, repo_root=`root, base=base
            )
        },
        `root,
    );
}

impl get_impact_radius_tool(
    changed_files: Optional[list[str]] = None,
    max_depth: int = 2,
    max_results: int = max_results_default_,
    repo_root: Optional[str] = None,
    base: str = "HEAD~1",
    detail_level: str = "standard",
    resolution: str = "all",
    max_files: int = 25,
) -> dict {
    `root: any;
    `root = _resolve_repo_root(repo_root);
    return await _offload(
        "get_impact_radius_tool",
        lambda -> any {
            _resolve_attr("get_impact_radius")(
                changed_files=changed_files,
                max_depth=max_depth,
                max_results=max_results,
                repo_root=`root,
                base=base,
                detail_level=detail_level,
                resolution=resolution,
                max_files=max_files,
            )
        },
        `root,
    );
}

impl query_graph_tool(
    pattern: str,
    target: str,
    repo_root: Optional[str] = None,
    detail_level: str = "standard",
    max_results: int = 100,
    resolution: str = "all",
    to: Optional[str] = None,
) -> dict {
    `root: any;
    `root = _resolve_repo_root(repo_root);
    return await _offload(
        "query_graph_tool",
        lambda -> any {
            _resolve_attr("query_graph")(
                pattern=pattern,
                target=target,
                repo_root=`root,
                detail_level=detail_level,
                max_results=max_results,
                resolution=resolution,
                to=to,
            )
        },
        `root,
    );
}

impl get_review_context_tool(
    changed_files: Optional[list[str]] = None,
    max_depth: int = 2,
    include_source: bool = True,
    max_lines_per_file: int = 200,
    repo_root: Optional[str] = None,
    base: str = "HEAD~1",
    detail_level: str = "standard",
    max_results: int = 100,
    max_files: int = 25,
) -> dict {
    `root: any;
    `root = _resolve_repo_root(repo_root);
    return await _offload(
        "get_review_context_tool",
        lambda -> any {
            _resolve_attr("get_review_context")(
                changed_files=changed_files,
                max_depth=max_depth,
                include_source=include_source,
                max_lines_per_file=max_lines_per_file,
                repo_root=`root,
                base=base,
                detail_level=detail_level,
                max_results=max_results,
                max_files=max_files,
            )
        },
        `root,
    );
}

impl semantic_search_nodes_tool(
    query: str,
    kind: Optional[str] = None,
    limit: int = 20,
    repo_root: Optional[str] = None,
    model: Optional[str] = None,
    provider: Optional[str] = None,
    detail_level: str = "standard",
    include_source: bool = False,
    expand_neighbors: bool = False,
    max_source_lines: int = 60,
) -> dict {
    `root: any;
    `root = _resolve_repo_root(repo_root);
    return await _offload(
        "semantic_search_nodes_tool",
        lambda -> any {
            _resolve_attr("semantic_search_nodes")(
                query=query,
                kind=kind,
                limit=limit,
                repo_root=`root,
                model=model,
                provider=provider,
                detail_level=detail_level,
                include_source=include_source,
                expand_neighbors=expand_neighbors,
                max_source_lines=max_source_lines,
            )
        },
        `root,
    );
}

impl embed_graph_tool(
    repo_root: Optional[str] = None, model: Optional[str] = None, provider: Optional[str] = None
) -> dict {
    `root: any;
    `root = _resolve_repo_root(repo_root);
    return await _offload(
        "embed_graph_tool",
        lambda -> any {
            _resolve_attr("embed_graph")(repo_root=`root, model=model, provider=provider)
        },
        `root,
        bounded=False,
    );
}

impl list_graph_stats_tool(repo_root: Optional[str] = None) -> dict {
    `root: any;
    `root = _resolve_repo_root(repo_root);
    return await _offload(
        "list_graph_stats_tool",
        lambda -> any { _resolve_attr("list_graph_stats")(repo_root=`root) },
        `root,
    );
}

impl get_docs_section_tool(section_name: str, repo_root: Optional[str] = None) -> dict {
    return _resolve_attr("get_docs_section")(
        section_name=section_name, repo_root=_resolve_repo_root(repo_root)
    );
}

impl find_large_functions_tool(
    min_lines: int = 50,
    kind: Optional[str] = None,
    file_path_pattern: Optional[str] = None,
    limit: int = 50,
    repo_root: Optional[str] = None,
    detail_level: str = "standard",
) -> dict {
    `root: any;
    `root = _resolve_repo_root(repo_root);
    return await _offload(
        "find_large_functions_tool",
        lambda -> any {
            _resolve_attr("find_large_functions")(
                min_lines=min_lines,
                kind=kind,
                file_path_pattern=file_path_pattern,
                limit=limit,
                repo_root=`root,
                detail_level=detail_level,
            )
        },
        `root,
    );
}

impl list_flows_tool(
    sort_by: str = "criticality",
    limit: int = 50,
    kind: Optional[str] = None,
    detail_level: str = "standard",
    repo_root: Optional[str] = None,
) -> dict {
    `root: any;
    `root = _resolve_repo_root(repo_root);
    return await _offload(
        "list_flows_tool",
        lambda -> any {
            _resolve_attr("list_flows")(
                repo_root=`root, sort_by=sort_by, limit=limit, kind=kind, detail_level=detail_level
            )
        },
        `root,
    );
}

impl get_flow_tool(
    flow_id: Optional[int] = None,
    flow_name: Optional[str] = None,
    include_source: bool = False,
    repo_root: Optional[str] = None,
    max_steps: int = 50,
    max_source_lines: int = 400,
) -> dict {
    `root: any;
    `root = _resolve_repo_root(repo_root);
    return await _offload(
        "get_flow_tool",
        lambda -> any {
            _resolve_attr("get_flow")(
                flow_id=flow_id,
                flow_name=flow_name,
                include_source=include_source,
                repo_root=`root,
                max_steps=max_steps,
                max_source_lines=max_source_lines,
            )
        },
        `root,
    );
}

impl get_affected_flows_tool(
    changed_files: Optional[list[str]] = None,
    base: str = "HEAD~1",
    repo_root: Optional[str] = None,
    detail_level: str = "standard",
    max_flows: int = 50,
) -> dict {
    `root: any;
    `root = _resolve_repo_root(repo_root);
    return await _offload(
        "get_affected_flows_tool",
        lambda -> any {
            _resolve_attr("get_affected_flows_func")(
                changed_files=changed_files,
                base=base,
                repo_root=`root,
                detail_level=detail_level,
                max_flows=max_flows,
            )
        },
        `root,
    );
}

impl list_communities_tool(
    sort_by: str = "size",
    min_size: int = 0,
    detail_level: str = "standard",
    repo_root: Optional[str] = None,
    max_results: int = 50,
    max_members: int = 10,
) -> dict {
    `root: any;
    `root = _resolve_repo_root(repo_root);
    return await _offload(
        "list_communities_tool",
        lambda -> any {
            _resolve_attr("list_communities_func")(
                repo_root=`root,
                sort_by=sort_by,
                min_size=min_size,
                detail_level=detail_level,
                max_results=max_results,
                max_members=max_members,
            )
        },
        `root,
    );
}

impl get_community_tool(
    community_name: Optional[str] = None,
    community_id: Optional[int] = None,
    include_members: bool = False,
    repo_root: Optional[str] = None,
    max_members: int = 25,
) -> dict {
    `root: any;
    `root = _resolve_repo_root(repo_root);
    return await _offload(
        "get_community_tool",
        lambda -> any {
            _resolve_attr("get_community_func")(
                community_name=community_name,
                community_id=community_id,
                include_members=include_members,
                repo_root=`root,
                max_members=max_members,
            )
        },
        `root,
    );
}

impl get_architecture_overview_tool(
    repo_root: Optional[str] = None,
    detail_level: str = "minimal",
    max_results: int = 100,
    max_members: int = 10,
) -> dict {
    `root: any;
    `root = _resolve_repo_root(repo_root);
    return await _offload(
        "get_architecture_overview_tool",
        lambda -> any {
            _resolve_attr("get_architecture_overview_func")(
                repo_root=`root,
                detail_level=detail_level,
                max_results=max_results,
                max_members=max_members,
            )
        },
        `root,
    );
}

impl detect_changes_tool(
    base: str = "HEAD~1",
    changed_files: Optional[list[str]] = None,
    include_source: bool = False,
    max_depth: int = 2,
    repo_root: Optional[str] = None,
    detail_level: str = "standard",
    max_results: int = 25,
    max_flows: int = 20,
) -> dict {
    `root: any;
    `root = _resolve_repo_root(repo_root);
    return await _offload(
        "detect_changes_tool",
        lambda -> any {
            _resolve_attr("detect_changes_func")(
                base=base,
                changed_files=changed_files,
                include_source=include_source,
                max_depth=max_depth,
                repo_root=`root,
                detail_level=detail_level,
                max_results=max_results,
                max_flows=max_flows,
            )
        },
        `root,
        timeout_hint=_DETECT_CHANGES_TIMEOUT_HINT,
    );
}

impl refactor_tool(
    mode: str = "rename",
    old_name: Optional[str] = None,
    new_name: Optional[str] = None,
    kind: Optional[str] = None,
    file_pattern: Optional[str] = None,
    repo_root: Optional[str] = None,
    max_results: int = 50,
    detail_level: str = "standard",
) -> dict {
    `root: any;
    `root = _resolve_repo_root(repo_root);
    return await _offload(
        "refactor_tool",
        lambda -> any {
            _resolve_attr("refactor_func")(
                mode=mode,
                old_name=old_name,
                new_name=new_name,
                kind=kind,
                file_pattern=file_pattern,
                repo_root=`root,
                max_results=max_results,
                detail_level=detail_level,
            )
        },
        `root,
    );
}

impl apply_refactor_tool(
    refactor_id: str,
    repo_root: Optional[str] = None,
    dry_run: bool = False,
    max_diff_files: int = 25,
) -> dict {
    `root: any;
    `root = _resolve_repo_root(repo_root);
    return await _offload(
        "apply_refactor_tool",
        lambda -> any {
            _resolve_attr("apply_refactor_func")(
                refactor_id=refactor_id,
                repo_root=`root,
                dry_run=dry_run,
                max_diff_files=max_diff_files,
            )
        },
        `root,
        bounded=False,
    );
}

impl generate_wiki_tool(repo_root: Optional[str] = None, force: bool = False) -> dict {
    `root: any;
    `root = _resolve_repo_root(repo_root);
    return await _offload(
        "generate_wiki_tool",
        lambda -> any { _resolve_attr("generate_wiki_func")(repo_root=`root, force=force) },
        `root,
        bounded=False,
    );
}

impl get_wiki_page_tool(
    community_name: str, repo_root: Optional[str] = None, max_chars: int = 20000
) -> dict {
    `root: any;
    `root = _resolve_repo_root(repo_root);
    return await _offload(
        "get_wiki_page_tool",
        lambda -> any {
            _resolve_attr("get_wiki_page_func")(
                community_name=community_name, repo_root=`root, max_chars=max_chars
            )
        },
        `root,
    );
}

impl get_hub_nodes_tool(
    top_n: int = 10, repo_root: Optional[str] = None, detail_level: str = "standard"
) -> dict {
    `root: any;
    `root = _resolve_repo_root(repo_root);
    return await _offload(
        "get_hub_nodes_tool",
        lambda -> any {
            _resolve_attr("get_hub_nodes_func")(
                repo_root=`root, top_n=top_n, detail_level=detail_level
            )
        },
        `root,
    );
}

impl get_bridge_nodes_tool(
    top_n: int = 10, repo_root: Optional[str] = None, detail_level: str = "standard"
) -> dict {
    `root: any;
    `root = _resolve_repo_root(repo_root);
    return await _offload(
        "get_bridge_nodes_tool",
        lambda -> any {
            _resolve_attr("get_bridge_nodes_func")(
                repo_root=`root, top_n=top_n, detail_level=detail_level
            )
        },
        `root,
    );
}

impl get_knowledge_gaps_tool(
    repo_root: Optional[str] = None, max_per_category: int = 15, detail_level: str = "standard"
) -> dict {
    `root: any;
    `root = _resolve_repo_root(repo_root);
    return await _offload(
        "get_knowledge_gaps_tool",
        lambda -> any {
            _resolve_attr("get_knowledge_gaps_func")(
                repo_root=`root, max_per_category=max_per_category, detail_level=detail_level
            )
        },
        `root,
    );
}

impl get_surprising_connections_tool(
    top_n: int = 15, repo_root: Optional[str] = None, detail_level: str = "standard"
) -> dict {
    `root: any;
    `root = _resolve_repo_root(repo_root);
    return await _offload(
        "get_surprising_connections_tool",
        lambda -> any {
            _resolve_attr("get_surprising_connections_func")(
                repo_root=`root, top_n=top_n, detail_level=detail_level
            )
        },
        `root,
    );
}

impl get_suggested_questions_tool(repo_root: Optional[str] = None) -> dict {
    `root: any;
    `root = _resolve_repo_root(repo_root);
    return await _offload(
        "get_suggested_questions_tool",
        lambda -> any { _resolve_attr("get_suggested_questions_func")(repo_root=`root) },
        `root,
    );
}

impl traverse_graph_tool(
    query: str,
    mode: str = "bfs",
    depth: int = 3,
    token_budget: int = 2000,
    repo_root: Optional[str] = None,
) -> dict {
    `root: any;
    `root = _resolve_repo_root(repo_root);
    return await _offload(
        "traverse_graph_tool",
        lambda -> any {
            _resolve_attr("traverse_graph_func")(
                query=query,
                mode=mode,
                depth=depth,
                token_budget=token_budget,
                repo_root=`root or "",
            )
        },
        `root,
    );
}

impl list_repos_tool -> dict {
    return _resolve_attr("list_repos_func")();
}

impl cross_repo_search_tool(
    query: str,
    kind: Optional[str] = None,
    limit: int = 20,
    max_results: int = 50,
    repos: Optional[list[str]] = None,
) -> dict {
    return await _offload(
        "cross_repo_search_tool",
        lambda -> any {
            _resolve_attr("cross_repo_search_func")(
                query=query, kind=kind, limit=limit, max_results=max_results, repos=repos
            )
        },
        None,
        provenance=False,
    );
}

impl review_changes(base: str = "HEAD~1") -> list[Message] {
    return _resolve_attr("review_changes_prompt")(base=base);
}

impl architecture_map -> list[Message] {
    return _resolve_attr("architecture_map_prompt")();
}

impl debug_issue(description: str = "") -> list[Message] {
    return _resolve_attr("debug_issue_prompt")(description=description);
}

impl onboard_developer -> list[Message] {
    return _resolve_attr("onboard_developer_prompt")();
}

impl pre_merge_check(base: str = "HEAD~1") -> list[Message] {
    return _resolve_attr("pre_merge_check_prompt")(base=base);
}

impl _apply_tool_filter(tools: str | None = None) -> None {
    import asyncio;

    raw: any = tools or os.environ.get("CRG_TOOLS");
    if not raw {
        return;
    }
    allowed: any = {t.strip() for t in raw.split(",") if t.strip()};
    if not allowed {
        return;
    }
    def _list_tool_names -> list[str] {
        coro_factory: any;
        coro_factory = mcp.list_tools;
        try {
            asyncio.get_running_loop();
        } except RuntimeError {
            return [t.name for t in asyncio.run(coro_factory())];
        }
        import concurrent.futures;

        def _runner -> list[str] {
            return [t.name for t in asyncio.run(coro_factory())];
        }

        pool: any;
        with concurrent.futures.ThreadPoolExecutor(max_workers=1) as pool {
            return pool.submit(_runner).result();
        }
    }

    for name in _list_tool_names() {
        if name not in allowed {
            mcp.local_provider.remove_tool(name);
        }
    }
}

impl main(
    repo_root: str | None = None,
    tools: str | None = None,
    auto_watch: bool = False,
    *,
    transport: str = "stdio",
    host: str | None = None,
    port: int | None = None,
    multi_repo: bool = False,
) -> None {
    `root: Path | None = None;
    if multi_repo {
        if transport != "streamable-http" {
            raise ValueError("multi_repo needs the HTTP transport (serve --http)");
        }
        if repo_root {
            raise ValueError(
                "multi_repo serves the repositories in the registry and takes no repo_root"
            );
        }
        if auto_watch {
            raise ValueError(
                "multi_repo cannot auto-watch; the daemon (code-review-graph daemon) watches several repositories",
            );
        }
        if os.environ.get("CRG_DATA_DIR", "").strip() {
            raise ValueError(
                "multi_repo cannot be combined with CRG_DATA_DIR, which would put every repository's graph in one database; use per-repository Registry data_dir entries instead",
            );
        }
        _default_repo_root = None;
        if not Registry().list_repos() {
            logger.warning(
                "No repositories are registered, so every call will be refused until one is: code-review-graph register <path>",
            );
        }
    } else {
        `root = Path(repo_root) if repo_root else find_project_root();
        _default_repo_root = `str(`root);
    }
    _apply_tool_filter(tools);

    previous_stdio_state: any = _incremental._MCP_STDIO_ACTIVE;
    _incremental._MCP_STDIO_ACTIVE = operator.eq(transport, "stdio");
    previous_instructions: any = mcp.instructions;
    _multi_repo = multi_repo;
    if multi_repo {
        mcp.instructions = SERVER_INSTRUCTIONS + MULTI_REPO_INSTRUCTIONS;
    }
    watch_store: GraphStore | None = None;
    watch_thread: threading.Thread | None = None;
    watch_stop: any = threading.Event();
    try {
        if auto_watch and `root is not None {
            run_post_processing = importlib.import_module("code_review_graph.postprocessing").run_post_processing;

            watch_store = GraphStore(get_db_path(`root));
            watch_thread = start_watch_thread(
                `root,
                watch_store,
                daemon=True,
                on_files_updated=run_post_processing,
                stop_event=watch_stop,
            );
            if watch_thread is None {
                logger.warning("Auto-watch was requested but could not be started");
            }
        }

        if operator.eq(sys.platform, "win32") {
            asyncio.set_event_loop_policy(asyncio.WindowsSelectorEventLoopPolicy());
            prewarm_local_embeddings = importlib.import_module("code_review_graph.embeddings").prewarm_local_embeddings;

            prewarm_local_embeddings();
        }

        if transport == "stdio" {
            mcp.run(transport="stdio", show_banner=False);
        } elif transport == "streamable-http" {
            if host is None or port is None {
                raise ValueError("streamable-http transport requires host and port");
            }
            build_http_middleware = importlib.import_module("code_review_graph.http_origin_guard").build_http_middleware;

            mcp.run(
                transport="streamable-http",
                host=host,
                port=port,
                middleware=build_http_middleware(host, port),
            );
        } else {
            raise ValueError(f"unsupported transport: {transport!r}");
        }
    } finally {
        try {
            if watch_thread is not None {
                watch_stop.set();
                watch_thread.join();
            }
            if watch_store is not None {
                watch_store.close();
            }
        } finally {
            _incremental._MCP_STDIO_ACTIVE = previous_stdio_state;
            _multi_repo = False;
            mcp.instructions = previous_instructions;
        }
    }
}
