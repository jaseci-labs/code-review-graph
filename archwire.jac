graph layers {
    layer all { *; }
}

graph spaces {
    space code_review_graph_vscode: node { "code-review-graph-vscode"; }
    space code_review_graph: cpython { "."; }
    package code_review_graph { ship code_review_graph; }
    space code_review_graph_dev: cpython { diagrams.* | scripts.* | tests | tests.*; }
}

graph import {
    "code-review-graph-vscode/src/backend/sqlite" --> "code-review-graph-vscode/test/sqlite.test" {
        GraphEdge,
        GraphNode,
        SqliteReader,
    }
    "code-review-graph-vscode/src/backend/sqlite" --> "code-review-graph-vscode/src/extension" {
        GraphNode,
        SqliteReader,
    }
    "code-review-graph-vscode/src/backend/cli" --> "code-review-graph-vscode/src/extension" {
        CliWrapper,
    }
    "code-review-graph-vscode/src/views/treeView" --> "code-review-graph-vscode/src/extension" {
        BlastRadiusTreeProvider,
        CodeGraphTreeProvider,
        StatsTreeProvider,
    }
    "code-review-graph-vscode/src/views/graphWebview" --> "code-review-graph-vscode/src/extension" {
        GraphWebviewPanel,
    }
    "code-review-graph-vscode/src/onboarding/installer" --> "code-review-graph-vscode/src/extension" {
        Installer,
    }
    "code-review-graph-vscode/src/onboarding/welcome" --> "code-review-graph-vscode/src/extension" {
        registerWalkthroughCommands,
        showWelcomeIfNeeded,
    }
    "code-review-graph-vscode/src/views/statusBar" --> "code-review-graph-vscode/src/extension" {
        StatusBar,
    }
    "code-review-graph-vscode/src/features/scmDecorations" --> "code-review-graph-vscode/src/extension" {
        ScmDecorationProvider,
    }
    "code-review-graph-vscode/src/backend/sqlite" --> "code-review-graph-vscode/src/views/treeView" {
        GraphEdge,
        GraphNode,
        SqliteReader,
    }
    "code-review-graph-vscode/src/views/treeItems" --> "code-review-graph-vscode/src/views/treeView" {
        BlastRadiusGroupItem,
        EdgeTreeItem,
        FileTreeItem,
        StatsItem,
        SymbolTreeItem,
    }
    "code-review-graph-vscode/src/backend/sqlite" --> "code-review-graph-vscode/src/views/graphWebview" {
        ImpactRadius,
        SqliteReader,
    }
    "code-review-graph-vscode/src/backend/cli" --> "code-review-graph-vscode/src/onboarding/installer" {
        CliWrapper,
    }
    "code-review-graph-vscode/src/onboarding/installer" --> "code-review-graph-vscode/src/onboarding/welcome" {
        Installer,
    }
    "code-review-graph-vscode/src/backend/cli" --> "code-review-graph-vscode/src/onboarding/welcome" {
        CliWrapper,
    }
    "code-review-graph-vscode/src/backend/sqlite" --> "code-review-graph-vscode/src/views/statusBar" {
        SqliteReader,
    }
    "code-review-graph-vscode/src/backend/sqlite" --> "code-review-graph-vscode/src/features/scmDecorations" {
        SqliteReader,
    }
    "code-review-graph-vscode/src/backend/sqlite" --> "code-review-graph-vscode/src/features/blastRadius" {
        SqliteReader,
    }
    "code-review-graph-vscode/src/views/treeView" --> "code-review-graph-vscode/src/features/blastRadius" {
        BlastRadiusTreeProvider,
    }
    "code-review-graph-vscode/src/features/cursorResolver" --> "code-review-graph-vscode/src/features/blastRadius" {
        resolveNodeAtCursor,
    }
    "code-review-graph-vscode/src/backend/sqlite" --> "code-review-graph-vscode/src/features/cursorResolver" {
        GraphNode,
        SqliteReader,
    }
    "code-review-graph-vscode/src/backend/sqlite" --> "code-review-graph-vscode/src/features/navigation" {
        GraphNode,
        SqliteReader,
    }
    "code-review-graph-vscode/src/features/cursorResolver" --> "code-review-graph-vscode/src/features/navigation" {
        navigateToNode,
        resolveNodeAtCursor,
    }
    "code-review-graph-vscode/src/backend/sqlite" --> "code-review-graph-vscode/src/features/reviewAssistant" {
        SqliteReader,
    }
    "code-review-graph-vscode/src/views/treeView" --> "code-review-graph-vscode/src/features/reviewAssistant" {
        BlastRadiusTreeProvider,
    }
    "code-review-graph-vscode/src/backend/sqlite" --> "code-review-graph-vscode/src/features/search" {
        GraphNode,
        SqliteReader,
    }
    code_review_graph.skills --> scripts.generate_documentary_skills {
        DOCUMENTARY_SKILLS,
        generate_documentary_skills,
        render_documentary_skill_markdown,
    }
    code_review_graph.embeddings --> scripts.smoke_google_embeddings { GoogleEmbeddingProvider }
    code_review_graph.tools --> tests.conftest;
    code_review_graph.incremental --> tests.determinism_build_runner;
    code_review_graph.tools.build --> tests.determinism_build_runner { build_or_update_graph }
    code_review_graph.embeddings --> tests.determinism_dump { EmbeddingStore, _node_to_text }
    code_review_graph.graph --> tests.determinism_dump { GraphNode, GraphStore }
    code_review_graph.migrations --> tests.determinism_dump {
        NODES_FTS_COLUMNS,
        NODES_FTS_STATE_TABLE,
    }
    code_review_graph.graph --> tests.real_repo_corpus { GraphStore }
    code_review_graph.incremental --> tests.real_repo_corpus { collect_all_files, full_build }
    code_review_graph.migrations --> tests.test_action_e2e { LATEST_VERSION }
    tests.test_action_render --> tests.test_action_e2e { report_rendering_to_exactly }
    code_review_graph.context_savings --> tests.test_action_e2e {
        estimate_file_tokens,
        estimate_tokens,
    }
    code_review_graph.change_details --> tests.test_action_render {
        DETAIL_SECTIONS,
        parse_detail_sections,
    }
    code_review_graph.graph --> tests.test_affected_flows_limits { EdgeInfo, GraphStore, NodeInfo }
    code_review_graph.tools.review --> tests.test_affected_flows_limits { get_affected_flows_func }
    code_review_graph.flows --> tests.test_affected_flows_limits { store_flows, trace_flows }
    code_review_graph.main --> tests.test_agent_transparency;
    code_review_graph.tools._common --> tests.test_agent_transparency;
    code_review_graph.tools.query --> tests.test_agent_transparency;
    code_review_graph.tools.query --> tests.test_agent_transparency {
        query_graph,
        semantic_search_nodes,
    }
    code_review_graph.graph --> tests.test_agent_transparency { GraphStore }
    code_review_graph.parser --> tests.test_agent_transparency { EdgeInfo, NodeInfo }
    code_review_graph.graph --> tests.test_ansible_parser { GraphStore }
    code_review_graph.parser --> tests.test_ansible_parser { CodeParser, NodeInfo }
    code_review_graph --> tests.test_aop_resolution_edge_cases;
    code_review_graph.aop_resolver --> tests.test_aop_resolution_edge_cases;
    code_review_graph.aop_resolver --> tests.test_aop_resolution_edge_cases {
        _DottedPattern,
        resolve_aop_advice,
    }
    code_review_graph.event_resolver --> tests.test_aop_resolution_edge_cases {
        resolve_spring_events,
    }
    code_review_graph.flows --> tests.test_aop_resolution_edge_cases { detect_entry_points }
    code_review_graph.graph --> tests.test_aop_resolution_edge_cases { GraphStore }
    code_review_graph.incremental --> tests.test_aop_resolution_edge_cases {
        full_build,
        incremental_update,
    }
    code_review_graph.parser --> tests.test_aop_resolution_edge_cases { CodeParser }
    code_review_graph.tools.query --> tests.test_aop_resolution_edge_cases { query_graph }
    code_review_graph.aop_resolver --> tests.test_aop_resolver {
        _DottedPattern,
        _parse_execution_expression,
        resolve_aop_advice,
    }
    code_review_graph.graph --> tests.test_aop_resolver { GraphStore }
    code_review_graph.incremental --> tests.test_aop_resolver { full_build, incremental_update }
    code_review_graph.parser --> tests.test_aop_resolver { CodeParser, EdgeInfo }
    code_review_graph.tools.query --> tests.test_aop_resolver { query_graph }
    code_review_graph.tools.build --> tests.test_build_tool_errors { build_or_update_graph }
    code_review_graph.cli --> tests.test_build_tool_errors;
    code_review_graph.graph --> tests.test_call_site_provenance { GraphStore }
    code_review_graph.migrations --> tests.test_call_site_provenance {
        LATEST_VERSION,
        get_schema_version,
    }
    code_review_graph.parser --> tests.test_call_site_provenance { EdgeInfo, NodeInfo }
    code_review_graph.tools --> tests.test_call_site_provenance {
        get_impact_radius,
        list_graph_stats,
        query_graph,
    }
    code_review_graph.incremental --> tests.test_call_site_provenance { full_build }
    code_review_graph.graph --> tests.test_callback_context_preservation { GraphStore }
    code_review_graph.incremental --> tests.test_callback_context_preservation { full_build }
    code_review_graph.parser --> tests.test_callback_context_preservation { CodeParser }
    code_review_graph.tools.query --> tests.test_callback_context_preservation { query_graph }
    code_review_graph.cli --> tests.test_change_details;
    code_review_graph.communities --> tests.test_change_details;
    code_review_graph.communities --> tests.test_change_details {
        detect_communities,
        store_communities,
    }
    code_review_graph.change_details --> tests.test_change_details {
        DETAIL_SECTIONS,
        MAX_ROWS,
        build_change_details,
        parse_detail_sections,
    }
    code_review_graph.changes --> tests.test_change_details {
        analyze_changes,
        compute_risk_score,
        risk_signals,
    }
    code_review_graph.graph --> tests.test_change_details { GraphStore }
    code_review_graph.parser --> tests.test_change_details { EdgeInfo, NodeInfo }
    code_review_graph.flows --> tests.test_change_details { store_flows }
    code_review_graph.incremental --> tests.test_change_details { full_build, get_db_path }
    code_review_graph.changes --> tests.test_changes {
        _parse_numstat,
        _parse_unified_diff,
        analyze_changes,
        compute_file_churn,
        compute_risk_score,
        map_changes_to_nodes,
        parse_git_diff_ranges,
    }
    code_review_graph.flows --> tests.test_changes { store_flows, trace_flows }
    code_review_graph.graph --> tests.test_changes { GraphStore }
    code_review_graph.parser --> tests.test_changes { EdgeInfo, NodeInfo }
    code_review_graph.tools --> tests.test_changes { detect_changes_func }
    code_review_graph.errors --> tests.test_changes { ChangeDiscoveryError }
    code_review_graph.changes --> tests.test_changes_path_normalization { analyze_changes }
    code_review_graph.flows --> tests.test_changes_path_normalization { store_flows, trace_flows }
    code_review_graph.graph --> tests.test_changes_path_normalization { GraphStore }
    code_review_graph.parser --> tests.test_changes_path_normalization { EdgeInfo, NodeInfo }
    code_review_graph.changes --> tests.test_churn_runtime;
    code_review_graph.changes --> tests.test_churn_runtime {
        clear_churn_cache,
        compute_file_churn,
        compute_file_churn_with_status,
    }
    code_review_graph.graph --> tests.test_churn_runtime { GraphStore, NodeInfo }
    code_review_graph.tools.context --> tests.test_churn_runtime { get_minimal_context }
    code_review_graph.tools.review --> tests.test_churn_runtime { detect_changes_func }
    code_review_graph.graph --> tests.test_cjs_and_kts_extensions { GraphStore }
    code_review_graph.incremental --> tests.test_cjs_and_kts_extensions { full_build, get_db_path }
    code_review_graph.parser --> tests.test_cjs_and_kts_extensions { CodeParser, is_test_file }
    code_review_graph.tools --> tests.test_cjs_and_kts_extensions { query_graph }
    code_review_graph.cli --> tests.test_cli;
    code_review_graph --> tests.test_cli;
    code_review_graph --> tests.test_cli { __version__ }
    code_review_graph.constants --> tests.test_cli { discovery_timeout }
    code_review_graph.graph --> tests.test_cli { GraphStore }
    code_review_graph.incremental --> tests.test_cli { full_build, get_db_path }
    code_review_graph.registry --> tests.test_cli;
    code_review_graph.search --> tests.test_cli { rebuild_fts_index }
    code_review_graph.cli --> tests.test_cli_help;
    code_review_graph.cli --> tests.test_cli_install;
    code_review_graph.cli --> tests.test_cli_install { _PLATFORM_CHOICES, _handle_init }
    code_review_graph.skills --> tests.test_cli_install;
    code_review_graph.skills --> tests.test_cli_install { _detect_serve_command }
    code_review_graph.uninstall --> tests.test_cli_install;
    code_review_graph.dsh --> tests.test_cli_install;
    code_review_graph.install_gitignore --> tests.test_cli_install;
    code_review_graph.tools --> tests.test_cli_query_accepts_every_pattern;
    code_review_graph.cli --> tests.test_cli_query_accepts_every_pattern;
    code_review_graph.tools.query --> tests.test_cli_query_accepts_every_pattern { _QUERY_PATTERNS }
    code_review_graph.graph --> tests.test_cli_reconciliation;
    code_review_graph.cli --> tests.test_cli_reconciliation;
    code_review_graph.cli --> tests.test_cli_stdio_encoding;
    code_review_graph.cli --> tests.test_cli_surface;
    code_review_graph.tools --> tests.test_cli_tool_commands;
    code_review_graph.cli --> tests.test_cli_tool_commands;
    code_review_graph.graph --> tests.test_cli_tool_commands { GraphStore }
    code_review_graph.parser --> tests.test_cli_tool_commands { NodeInfo }
    code_review_graph.registry --> tests.test_cli_tool_commands { Registry }
    code_review_graph.hook_update --> tests.test_codex_hook_never_builds_a_new_graph;
    code_review_graph.skills --> tests.test_codex_hook_never_builds_a_new_graph;
    code_review_graph.uninstall --> tests.test_codex_hook_never_builds_a_new_graph;
    code_review_graph.cli --> tests.test_codex_hook_never_builds_a_new_graph;
    code_review_graph.cli --> tests.test_codex_skill_wrapper;
    code_review_graph.graph --> tests.test_codex_skill_wrapper { GraphStore }
    code_review_graph.parser --> tests.test_codex_skill_wrapper { NodeInfo }
    code_review_graph.search --> tests.test_codex_skill_wrapper { rebuild_fts_index }
    code_review_graph.tools.query --> tests.test_codex_skill_wrapper { _QUERY_PATTERNS }
    code_review_graph.parser --> tests.test_commonjs_imports { CodeParser }
    code_review_graph.communities --> tests.test_communities;
    code_review_graph.communities --> tests.test_communities {
        IGRAPH_AVAILABLE,
        _build_adjacency,
        _compute_cohesion,
        _compute_cohesion_batch,
        _detect_file_based,
        _detect_leiden,
        _generate_community_name,
        _reassign_test_nodes,
        capture_community_assignments,
        detect_communities,
        get_architecture_overview,
        get_communities,
        incremental_detect_communities,
        remap_community_assignments,
        store_communities,
    }
    code_review_graph.graph --> tests.test_communities { GraphEdge, GraphNode, GraphStore }
    code_review_graph.parser --> tests.test_communities { EdgeInfo, NodeInfo }
    code_review_graph.cli --> tests.test_compact_impact;
    code_review_graph.main --> tests.test_compact_impact;
    code_review_graph.graph --> tests.test_compact_impact { GraphStore }
    code_review_graph.parser --> tests.test_compact_impact { EdgeInfo, NodeInfo }
    code_review_graph.tools.query --> tests.test_compact_impact;
    code_review_graph.graph --> tests.test_composer_vendor_ignore { GraphStore }
    code_review_graph.incremental --> tests.test_composer_vendor_ignore {
        _create_watch_handler,
        _load_ignore_patterns,
        _should_ignore,
        clear_nested_ignore_cache,
    }
    code_review_graph.parser --> tests.test_composer_vendor_ignore { CodeParser }
    code_review_graph.daemon --> tests.test_concurrency_and_daemon;
    code_review_graph.migrations --> tests.test_concurrency_and_daemon;
    code_review_graph.cli --> tests.test_concurrency_and_daemon { EXIT_TEMPFAIL }
    code_review_graph.graph --> tests.test_concurrency_and_daemon { GraphStore }
    code_review_graph.incremental --> tests.test_concurrency_and_daemon {
        _MAX_UNWATCHED_TRACKED,
        _WatchSupervisor,
    }
    code_review_graph.locking --> tests.test_concurrency_and_daemon { WriteLock, write_lock_path }
    code_review_graph.tools.build --> tests.test_concurrency_and_daemon {
        build_or_update_graph,
        is_lock_contention,
    }
    code_review_graph.parser --> tests.test_concurrency_and_daemon { NodeInfo }
    code_review_graph.cli --> tests.test_confirm_at_end_of_input_takes_default;
    code_review_graph.cli --> tests.test_context_history;
    code_review_graph.context_history --> tests.test_context_history;
    code_review_graph.context_history --> tests.test_context_history { CallInfo }
    code_review_graph.context_savings --> tests.test_context_history { attach_context_savings }
    code_review_graph.tools.build --> tests.test_context_history { build_or_update_graph }
    code_review_graph.tools --> tests.test_context_history {
        detect_changes_func,
        get_architecture_overview_func,
        get_impact_radius,
        get_review_context,
    }
    code_review_graph.context_savings --> tests.test_context_savings {
        estimate_context_savings,
        estimate_file_tokens,
        estimate_tokens,
        format_context_savings,
    }
    code_review_graph.parser --> tests.test_cpp_header_prefilter {
        CodeParser,
        _CPP_QT_STRUCTURAL_MACRO_REPLACEMENTS,
    }
    code_review_graph.graph --> tests.test_cpp_overload_identity { GraphStore }
    code_review_graph.incremental --> tests.test_cpp_overload_identity {
        CPP_IDENTITY_VERSION,
        incremental_update,
    }
    code_review_graph.parser --> tests.test_cpp_overload_identity { CodeParser, EdgeInfo, NodeInfo }
    code_review_graph.tools.query --> tests.test_cpp_overload_identity { query_graph }
    code_review_graph.parser --> tests.test_cpp_qt_headers;
    code_review_graph.parser --> tests.test_cpp_qt_headers { CodeParser }
    code_review_graph.graph --> tests.test_cpp_qt_headers { GraphStore }
    code_review_graph.incremental --> tests.test_cpp_qt_headers { full_build }
    code_review_graph.graph --> tests.test_csharp_dead_code_overrides { GraphStore }
    code_review_graph.incremental --> tests.test_csharp_dead_code_overrides { full_build }
    code_review_graph.refactor --> tests.test_csharp_dead_code_overrides { find_dead_code }
    code_review_graph.graph --> tests.test_csharp_dotted_query_targets { GraphStore }
    code_review_graph.incremental --> tests.test_csharp_dotted_query_targets { full_build }
    code_review_graph.tools.query --> tests.test_csharp_dotted_query_targets { query_graph }
    code_review_graph.graph --> tests.test_csharp_namespace_binding_edges { GraphStore }
    code_review_graph.incremental --> tests.test_csharp_namespace_binding_edges {
        _create_watch_handler,
        full_build,
        incremental_update,
    }
    code_review_graph.parser --> tests.test_csharp_namespace_binding_edges { CodeParser, EdgeInfo }
    code_review_graph.scoped_resolver --> tests.test_csharp_namespace_binding_edges {
        resolve_scoped_calls,
    }
    code_review_graph.tools.build --> tests.test_csharp_namespace_binding_edges { _run_postprocess }
    code_review_graph.flows --> tests.test_csharp_namespace_binding_edges { get_flows }
    code_review_graph.forget --> tests.test_csharp_namespace_binding_edges { forget_files }
    code_review_graph.postprocessing --> tests.test_csharp_namespace_binding_edges {
        run_post_processing,
    }
    code_review_graph.graph --> tests.test_csharp_namespaces { GraphStore }
    code_review_graph.incremental --> tests.test_csharp_namespaces;
    code_review_graph.incremental --> tests.test_csharp_namespaces {
        CPP_IDENTITY_VERSION,
        CSHARP_IDENTITY_VERSION,
        full_build,
        incremental_update,
    }
    code_review_graph.parser --> tests.test_csharp_namespaces { CodeParser }
    code_review_graph.scoped_resolver --> tests.test_csharp_namespaces { resolve_scoped_calls }
    code_review_graph.build_state --> tests.test_csharp_namespaces {
        BUILD_IN_PROGRESS,
        BUILD_STATE_KEY,
        POSTPROCESS_PENDING,
        advance_to_postprocess_pending,
    }
    code_review_graph.flows --> tests.test_csharp_namespaces { get_flows, store_flows, trace_flows }
    code_review_graph.tools.build --> tests.test_csharp_namespaces {
        _run_postprocess,
        build_or_update_graph,
    }
    code_review_graph.custom_languages --> tests.test_custom_languages;
    code_review_graph.custom_languages --> tests.test_custom_languages {
        CONFIG_RELATIVE_PATH,
        MAX_CUSTOM_LANGUAGES,
        _validate_entry,
        load_custom_languages,
    }
    code_review_graph.parser --> tests.test_custom_languages {
        CodeParser,
        EXTENSION_TO_LANGUAGE,
        _builtin_language_names,
    }
    code_review_graph.graph --> tests.test_custom_languages { GraphStore }
    code_review_graph.incremental --> tests.test_custom_languages { full_build }
    code_review_graph.visualization --> tests.test_d3_asset_line_endings;
    code_review_graph.daemon --> tests.test_daemon;
    code_review_graph.daemon --> tests.test_daemon {
        CONFIG_PATH,
        DaemonConfig,
        WatchDaemon,
        WatchRepo,
        _WindowsJob,
        _pid_alive_windows,
        _serialize_toml,
        add_repo_to_config,
        clear_pid,
        default_state_path,
        is_daemon_running,
        load_config,
        load_state,
        pid_alive,
        read_pid,
        remove_repo_from_config,
        save_config,
        tomllib,
        watch_health_path,
        write_pid,
    }
    code_review_graph.daemon_cli --> tests.test_daemon {
        _handle_add,
        _handle_logs,
        _handle_remove,
        _handle_restart,
        _handle_start,
        _handle_status,
        _handle_stop,
    }
    code_review_graph.daemon_cli --> tests.test_daemon_cli_followups;
    code_review_graph.daemon --> tests.test_daemon_stop_confirmation {
        default_pid_path,
        read_pid,
        write_pid,
    }
    code_review_graph.daemon_cli --> tests.test_daemon_stop_confirmation {
        _handle_restart,
        _handle_stop,
    }
    code_review_graph.daemon_cli --> tests.test_daemon_stop_escalation {
        _handle_restart,
        _handle_stop,
    }
    code_review_graph.daemon --> tests.test_daemon_stop_escalation { default_pid_path, write_pid }
    code_review_graph.graph --> tests.test_dbt_parser { GraphStore }
    code_review_graph.incremental --> tests.test_dbt_parser { full_build }
    code_review_graph.parser --> tests.test_dbt_parser { CodeParser }
    code_review_graph.graph --> tests.test_dead_code_edge_evidence { GraphStore }
    code_review_graph.parser --> tests.test_dead_code_edge_evidence {
        CodeParser,
        EdgeInfo,
        NodeInfo,
    }
    code_review_graph.refactor --> tests.test_dead_code_edge_evidence {
        find_dead_code,
        suggest_refactorings,
    }
    code_review_graph.graph --> tests.test_dead_code_query_scaling { GraphStore }
    code_review_graph.parser --> tests.test_dead_code_query_scaling { EdgeInfo, NodeInfo }
    code_review_graph.refactor --> tests.test_dead_code_query_scaling { find_dead_code }
    code_review_graph.communities --> tests.test_derived_data_fallbacks;
    code_review_graph.incremental --> tests.test_derived_data_fallbacks;
    code_review_graph.graph --> tests.test_derived_data_fallbacks;
    code_review_graph.graph --> tests.test_derived_data_fallbacks { GraphStore }
    code_review_graph.parser --> tests.test_derived_data_fallbacks { EdgeInfo, NodeInfo }
    code_review_graph.changes --> tests.test_detect_changes_brief_priorities {
        analyze_changes,
        format_brief,
        risk_label,
    }
    code_review_graph.graph --> tests.test_detect_changes_brief_priorities { GraphStore }
    code_review_graph.incremental --> tests.test_detect_changes_brief_priorities { full_build }
    tests.determinism_dump --> tests.test_determinism;
    code_review_graph.communities --> tests.test_determinism { IGRAPH_AVAILABLE }
    code_review_graph.incremental --> tests.test_determinism { collect_all_files }
    scripts.diagnose_pypi_connectivity --> tests.test_diagnose_pypi_connectivity;
    code_review_graph.embeddings --> tests.test_docstring_embeddings { _node_to_text }
    code_review_graph.graph --> tests.test_docstring_embeddings { GraphNode, GraphStore }
    code_review_graph.incremental --> tests.test_docstring_embeddings {
        full_build,
        incremental_update,
    }
    code_review_graph.parser --> tests.test_docstring_embeddings { CodeParser }
    code_review_graph --> tests.test_doctor { __version__ }
    code_review_graph.cli --> tests.test_doctor;
    code_review_graph.doctor --> tests.test_doctor;
    code_review_graph.graph --> tests.test_doctor { GraphStore }
    code_review_graph.migrations --> tests.test_doctor { LATEST_VERSION }
    code_review_graph.parser --> tests.test_doctor { NodeInfo }
    code_review_graph.skills --> tests.test_doctor;
    code_review_graph.skills --> tests.test_doctor { generate_hooks_config }
    code_review_graph.skills --> tests.test_document_skills;
    code_review_graph.skills --> tests.test_document_skills {
        DOCUMENTARY_SKILLS,
        generate_documentary_skills,
        render_documentary_skill_markdown,
    }
    code_review_graph.migrations --> tests.test_documentation { LATEST_VERSION }
    code_review_graph --> tests.test_documentation { __version__ }
    code_review_graph.dsh --> tests.test_dsh;
    code_review_graph.skills --> tests.test_dsh;
    code_review_graph.uninstall --> tests.test_dsh;
    tests.mcp_client_compat --> tests.test_e2e_mcp_client { McpError, read_timeout, wire }
    code_review_graph.communities --> tests.test_e2e_real_repo {
        detect_communities,
        store_communities,
    }
    code_review_graph.flows --> tests.test_e2e_real_repo { store_flows, trace_flows }
    code_review_graph.graph --> tests.test_e2e_real_repo { GraphStore }
    code_review_graph.incremental --> tests.test_e2e_real_repo {
        collect_all_files,
        full_build,
        incremental_update,
    }
    code_review_graph.search --> tests.test_e2e_real_repo { hybrid_search, rebuild_fts_index }
    code_review_graph.hook_update --> tests.test_edit_hook_follows_the_edited_file;
    code_review_graph.skills --> tests.test_edit_hook_follows_the_edited_file {
        generate_hooks_config,
    }
    code_review_graph.graph --> tests.test_edit_hook_follows_the_edited_file { GraphStore }
    code_review_graph.changes --> tests.test_elixir_multi_clause { map_changes_to_nodes }
    code_review_graph.graph --> tests.test_elixir_multi_clause { GraphStore }
    code_review_graph.parser --> tests.test_elixir_multi_clause { CodeParser }
    code_review_graph.embeddings --> tests.test_embedding_initialization;
    code_review_graph.main --> tests.test_embedding_initialization;
    code_review_graph.embeddings --> tests.test_embedding_refresh {
        EmbeddingStore,
        REFRESH_SKIPPED_WARNING,
        embed_all_nodes,
        refresh_embeddings,
    }
    code_review_graph.graph --> tests.test_embedding_refresh { GraphStore }
    code_review_graph.incremental --> tests.test_embedding_refresh { get_db_path }
    code_review_graph.parser --> tests.test_embedding_refresh { NodeInfo }
    code_review_graph.postprocessing --> tests.test_embedding_refresh { run_post_processing }
    code_review_graph.tools.build --> tests.test_embedding_refresh {
        _run_postprocess,
        build_or_update_graph,
        run_postprocess,
    }
    code_review_graph.tools.docs --> tests.test_embedding_refresh { embed_graph }
    code_review_graph.main --> tests.test_embedding_refresh;
    code_review_graph.cli --> tests.test_embedding_refresh;
    code_review_graph.incremental --> tests.test_embedding_refresh_skip_notice;
    code_review_graph.incremental --> tests.test_embedding_refresh_skip_notice {
        _create_watch_handler,
        _raise_watch_postprocess_warnings,
        get_db_path,
    }
    code_review_graph.build_state --> tests.test_embedding_refresh_skip_notice {
        BUILD_IN_PROGRESS,
        BUILD_STATE_KEY,
    }
    code_review_graph.embeddings --> tests.test_embedding_refresh_skip_notice {
        EmbeddingStore,
        REFRESH_SKIPPED_WARNING,
        embed_all_nodes,
        has_embeddings,
    }
    code_review_graph.graph --> tests.test_embedding_refresh_skip_notice { GraphStore }
    code_review_graph.postprocessing --> tests.test_embedding_refresh_skip_notice {
        run_post_processing,
    }
    code_review_graph.tools.build --> tests.test_embedding_refresh_skip_notice {
        build_or_update_graph,
        run_postprocess,
    }
    code_review_graph.main --> tests.test_embedding_refresh_skip_notice;
    code_review_graph.cli --> tests.test_embedding_refresh_skip_notice;
    code_review_graph.tools.query --> tests.test_embedding_refresh_skip_notice { list_graph_stats }
    code_review_graph.constants --> tests.test_embeddings { normalize_file_path, release_os_memory }
    code_review_graph.embeddings --> tests.test_embeddings {
        EmbeddingStore,
        GoogleEmbeddingProvider,
        LOCAL_DEFAULT_MODEL,
        LocalEmbeddingProvider,
        MiniMaxEmbeddingProvider,
        OpenAIEmbeddingProvider,
        VoyageEmbeddingProvider,
        _MODEL_CACHE,
        _cosine_similarity,
        _decode_vector,
        _encode_vector,
        _is_localhost_url,
        _node_to_text,
        clear_model_cache,
        get_provider,
    }
    code_review_graph.graph --> tests.test_embeddings { GraphNode }
    code_review_graph.enrich --> tests.test_enrich {
        enrich_file_read,
        enrich_search,
        extract_pattern,
    }
    code_review_graph.graph --> tests.test_enrich { GraphStore }
    code_review_graph.parser --> tests.test_enrich { EdgeInfo, NodeInfo }
    code_review_graph.search --> tests.test_enrich { rebuild_fts_index }
    code_review_graph.constants --> tests.test_env_config;
    code_review_graph.eval.reporter --> tests.test_eval {
        generate_full_report,
        generate_markdown_report,
        generate_readme_tables,
    }
    code_review_graph.eval.runner --> tests.test_eval;
    code_review_graph.eval.runner --> tests.test_eval {
        BENCHMARK_REGISTRY,
        _embedding_count,
        _warn_if_semantic_index_missing,
        clone_or_update,
        load_all_configs,
        load_config,
        write_csv,
    }
    code_review_graph.eval.scorer --> tests.test_eval {
        compute_mrr,
        compute_precision_recall,
        compute_token_efficiency,
    }
    code_review_graph.eval.benchmarks.token_efficiency --> tests.test_eval;
    code_review_graph.eval.benchmarks.impact_accuracy --> tests.test_eval;
    code_review_graph.eval.benchmarks.search_quality --> tests.test_eval;
    code_review_graph.eval.benchmarks.build_performance --> tests.test_eval;
    code_review_graph.eval.token_benchmark --> tests.test_eval {
        benchmark_review_workflow,
        estimate_tokens,
        run_all_benchmarks,
    }
    code_review_graph.graph --> tests.test_eval { GraphStore }
    code_review_graph.incremental --> tests.test_eval { full_build, get_db_path }
    code_review_graph.eval.benchmarks.agent_baseline --> tests.test_eval;
    code_review_graph.eval.benchmarks.agent_baseline --> tests.test_eval {
        derive_search_terms,
        grep_rank,
    }
    code_review_graph.registry --> tests.test_eval;
    code_review_graph.eval.benchmarks.multi_hop_retrieval --> tests.test_eval;
    code_review_graph.exports --> tests.test_export_formats {
        _cypher_escape,
        _cypher_props,
        export_graphml,
        export_json,
        export_neo4j_cypher,
        export_obsidian_vault,
        export_svg,
    }
    code_review_graph.graph --> tests.test_export_formats { GraphStore, _sanitize_name }
    code_review_graph.parser --> tests.test_export_formats { EdgeInfo, NodeInfo }
    code_review_graph.visualization --> tests.test_export_formats {
        D3_CDN_URL,
        D3_LOCAL_FILENAME,
        D3_SRI_HASH,
        export_graph_data,
        generate_html,
    }
    code_review_graph.wiki --> tests.test_export_formats {
        _generate_community_page,
        _md_cell,
        generate_wiki,
    }
    code_review_graph.incremental --> tests.test_export_formats { full_build }
    code_review_graph.postprocessing --> tests.test_export_formats { run_post_processing }
    code_review_graph.communities --> tests.test_export_formats { get_communities }
    code_review_graph.cli --> tests.test_failure_reporting;
    code_review_graph.errors --> tests.test_failure_reporting {
        ChangeDiscoveryError,
        CodeReviewGraphError,
        GraphRootMismatchError,
        GraphStoreError,
        is_lock_error,
    }
    code_review_graph.graph --> tests.test_failure_reporting {
        CorruptGraphDatabaseError,
        GraphStore,
    }
    code_review_graph.incremental --> tests.test_failure_reporting {
        assert_graph_serves_root,
        full_build,
        get_changed_files,
        get_db_path,
        get_staged_and_unstaged,
    }
    code_review_graph.migrations --> tests.test_failure_reporting { LATEST_VERSION }
    code_review_graph --> tests.test_failure_reporting;
    code_review_graph --> tests.test_failure_reporting { __version__ }
    code_review_graph.parser --> tests.test_failure_reporting { NodeInfo }
    code_review_graph.changes --> tests.test_failure_reporting { analyze_changes }
    code_review_graph.tools.flows_tools --> tests.test_flow_source_stays_in_repo { get_flow }
    code_review_graph.flows --> tests.test_flows {
        clear_flows_for_files,
        detect_entry_points,
        expand_changed_file_paths,
        get_affected_flows,
        get_flow_by_id,
        get_flows,
        incremental_trace_flows,
        purge_orphan_flow_data,
        store_flows,
        trace_flows,
    }
    code_review_graph.graph --> tests.test_flows { GraphStore }
    code_review_graph.parser --> tests.test_flows {
        CodeParser,
        EdgeInfo,
        NodeInfo,
        normalize_file_path,
    }
    code_review_graph.tools.build --> tests.test_flows { _run_postprocess }
    code_review_graph.cli --> tests.test_follow_symlinks;
    code_review_graph.cli --> tests.test_follow_symlinks { _match_files_to_forget }
    code_review_graph.graph --> tests.test_follow_symlinks { GraphStore }
    code_review_graph.incremental --> tests.test_follow_symlinks {
        FOLLOW_SYMLINKS_ENV,
        _WatchSupervisor,
        _create_watch_handler,
        collect_all_files,
        follow_symlinks_enabled,
        followed_files,
        full_build,
        incremental_update,
        path_within_repo,
    }
    code_review_graph.tools.build --> tests.test_follow_symlinks { build_or_update_graph }
    code_review_graph.tools.query --> tests.test_follow_symlinks {
        query_graph,
        semantic_search_nodes,
    }
    code_review_graph.tools.review --> tests.test_follow_symlinks { get_review_context }
    code_review_graph.forget --> tests.test_follow_symlinks { forget_files }
    code_review_graph.tools.refactor_tools --> tests.test_follow_symlinks {
        apply_refactor_func,
        refactor_func,
    }
    code_review_graph.cli --> tests.test_forget;
    code_review_graph.graph --> tests.test_forget { GraphStore }
    code_review_graph.incremental --> tests.test_forget { get_db_path }
    code_review_graph.parser --> tests.test_forget { NodeInfo }
    code_review_graph.search --> tests.test_forget { rebuild_fts_index }
    code_review_graph.graph --> tests.test_forget_legacy_db { GraphStore }
    code_review_graph.incremental --> tests.test_forget_legacy_db { full_build }
    code_review_graph.cli --> tests.test_forget_legacy_db;
    code_review_graph.forget --> tests.test_forget_parity { forget_files }
    code_review_graph.graph --> tests.test_forget_parity { GraphStore }
    code_review_graph.incremental --> tests.test_forget_parity { full_build, get_db_path }
    code_review_graph.postprocessing --> tests.test_forget_parity { run_post_processing }
    code_review_graph.graph --> tests.test_freshness_metadata { GraphStore }
    code_review_graph.incremental --> tests.test_freshness_metadata;
    code_review_graph.incremental --> tests.test_freshness_metadata {
        full_build,
        get_db_path,
        incremental_update,
    }
    code_review_graph.tools.build --> tests.test_freshness_metadata { build_or_update_graph }
    code_review_graph.parser --> tests.test_freshness_metadata { CodeParser }
    code_review_graph.build_state --> tests.test_freshness_metadata {
        BUILD_COMPLETE,
        BUILD_IN_PROGRESS,
        BUILD_STATE_KEY,
        POSTPROCESS_PENDING,
    }
    code_review_graph.cli --> tests.test_freshness_metadata;
    code_review_graph.embeddings --> tests.test_freshness_metadata;
    code_review_graph.embeddings --> tests.test_freshness_metadata { REFRESH_SKIPPED_WARNING }
    code_review_graph.graph --> tests.test_fts_delta { GraphStore }
    code_review_graph.parser --> tests.test_fts_delta { NodeInfo }
    code_review_graph.postprocessing --> tests.test_fts_delta { run_post_processing }
    code_review_graph.search --> tests.test_fts_delta {
        _fts_search,
        hybrid_search,
        rebuild_fts_index,
        update_fts_index,
    }
    code_review_graph.incremental --> tests.test_fts_delta { full_build }
    code_review_graph.tools.build --> tests.test_fts_delta { _fts_file_hint }
    code_review_graph.graph --> tests.test_fts_sync { GraphStore }
    code_review_graph.parser --> tests.test_fts_sync { NodeInfo }
    code_review_graph.search --> tests.test_fts_sync { rebuild_fts_index }
    code_review_graph.embeddings --> tests.test_genai_packaging { GoogleEmbeddingProvider }
    code_review_graph.parser --> tests.test_generic_yaml_edge_cases;
    code_review_graph.parser --> tests.test_generic_yaml_edge_cases { CodeParser }
    code_review_graph.changes --> tests.test_generic_yaml_edge_cases {
        analyze_changes,
        map_changes_to_nodes,
    }
    code_review_graph.cli --> tests.test_generic_yaml_edge_cases { build_parser }
    code_review_graph.graph --> tests.test_generic_yaml_edge_cases { GraphStore, node_to_dict }
    code_review_graph.incremental --> tests.test_generic_yaml_edge_cases {
        DEFAULT_IGNORE_PATTERNS,
        _should_ignore,
        full_build,
        get_db_path,
        incremental_update,
    }
    code_review_graph.tools.query --> tests.test_generic_yaml_edge_cases {
        query_graph,
        semantic_search_nodes,
    }
    code_review_graph.tools.review --> tests.test_generic_yaml_edge_cases { detect_changes_func }
    code_review_graph.skills --> tests.test_git_hook_block_helpers;
    code_review_graph.uninstall --> tests.test_git_hook_block_helpers;
    code_review_graph.skills --> tests.test_git_hook_block_runs_before_trailing_exit;
    code_review_graph.uninstall --> tests.test_git_hook_block_runs_before_trailing_exit;
    tests.test_git_sync_hooks --> tests.test_git_hook_block_runs_before_trailing_exit {
        calls,
        commit_file,
        git,
        sync_repo,
    }
    code_review_graph.skills --> tests.test_git_sync_hooks;
    code_review_graph.skills --> tests.test_git_sync_hooks { install_git_sync_hooks }
    code_review_graph.uninstall --> tests.test_git_sync_hooks;
    code_review_graph.skills --> tests.test_git_hook_worktree;
    code_review_graph.skills --> tests.test_git_hook_worktree { install_git_hook }
    code_review_graph.graph --> tests.test_go_embeddings { GraphStore }
    code_review_graph.parser --> tests.test_go_embeddings { CodeParser }
    code_review_graph.tools --> tests.test_go_embeddings { query_graph }
    code_review_graph.spring_resolver --> tests.test_go_embeddings { resolve_spring_di_calls }
    code_review_graph.temporal_resolver --> tests.test_go_embeddings { resolve_temporal_calls }
    code_review_graph.parser --> tests.test_go_imports { CodeParser, normalize_file_path }
    code_review_graph.parser --> tests.test_go_receiver_resolution { CodeParser }
    code_review_graph.constants --> tests.test_graph;
    code_review_graph.graph --> tests.test_graph;
    code_review_graph.graph --> tests.test_graph {
        CorruptGraphDatabaseError,
        GraphStore,
        _has_incompatible_schema,
        _is_unreadable_database,
        discard_corrupt_database,
    }
    code_review_graph.analysis --> tests.test_graph { find_bridge_nodes }
    code_review_graph.errors --> tests.test_graph { GraphStoreError }
    code_review_graph.incremental --> tests.test_graph { full_build }
    code_review_graph.parser --> tests.test_graph { CodeParser, EdgeInfo, NodeInfo }
    code_review_graph.refactor --> tests.test_graph { find_dead_code }
    code_review_graph.tools.query --> tests.test_graph { query_graph }
    code_review_graph.graph --> tests.test_graph_fresh_after_hooked_commit { GraphStore }
    code_review_graph.incremental --> tests.test_graph_fresh_after_hooked_commit {
        graph_holds_commits,
    }
    code_review_graph.tools.build --> tests.test_graph_fresh_after_hooked_commit {
        build_or_update_graph,
    }
    code_review_graph.tools.context --> tests.test_graph_fresh_after_hooked_commit {
        get_minimal_context,
    }
    code_review_graph.graph --> tests.test_graph_update_contracts { GraphStore }
    code_review_graph.parser --> tests.test_graph_update_contracts { EdgeInfo, NodeInfo }
    code_review_graph.tools.query --> tests.test_graph_update_contracts { query_graph }
    code_review_graph.graph --> tests.test_hcl_parser { GraphStore }
    code_review_graph.incremental --> tests.test_hcl_parser { full_build }
    code_review_graph.parser --> tests.test_hcl_parser { CodeParser }
    code_review_graph.graph --> tests.test_hcl_provider_aliases { GraphStore }
    code_review_graph.parser --> tests.test_hcl_provider_aliases { CodeParser }
    code_review_graph.parser --> tests.test_header_dead_branch_scan;
    code_review_graph.parser --> tests.test_header_dead_branch_scan {
        CodeParser,
        _is_in_static_dead_guard,
        _is_statically_false_condition,
        _node_is_in_child,
    }
    code_review_graph.graph --> tests.test_header_dead_branch_scan { GraphStore }
    code_review_graph.incremental --> tests.test_header_dead_branch_scan {
        full_build,
        incremental_update,
    }
    code_review_graph.skills --> tests.test_hermes_install;
    code_review_graph.skills --> tests.test_hermes_install {
        PLATFORMS,
        _detect_serve_command,
        _hermes_config_path,
        _hermes_home,
        install_platform_configs,
    }
    code_review_graph.uninstall --> tests.test_hermes_install;
    code_review_graph.skills --> tests.test_hermes_yaml_preservation;
    code_review_graph.uninstall --> tests.test_hermes_yaml_preservation;
    code_review_graph.hints --> tests.test_hints {
        SessionState,
        _MAX_PER_CATEGORY,
        generate_hints,
        get_session,
        infer_intent,
        reset_session,
    }
    code_review_graph.enrich --> tests.test_hook_payload_is_read_as_utf8;
    code_review_graph.hook_update --> tests.test_hook_payload_is_read_as_utf8;
    code_review_graph.hook_update --> tests.test_hook_update;
    code_review_graph.tools.build --> tests.test_hook_update;
    code_review_graph.skills --> tests.test_hook_update;
    code_review_graph.skills --> tests.test_hook_update { generate_codex_hooks_config }
    code_review_graph.graph --> tests.test_html_parser { GraphStore }
    code_review_graph.incremental --> tests.test_html_parser { full_build, get_db_path }
    code_review_graph.parser --> tests.test_html_parser { CodeParser, normalize_file_path }
    code_review_graph.postprocessing --> tests.test_html_parser { run_post_processing }
    code_review_graph.tools.query --> tests.test_html_parser { query_graph, semantic_search_nodes }
    code_review_graph.cli --> tests.test_html_parser { build_parser }
    code_review_graph.cli --> tests.test_http_multi_repo;
    code_review_graph.main --> tests.test_http_multi_repo;
    code_review_graph.registry --> tests.test_http_multi_repo { Registry }
    code_review_graph.http_origin_guard --> tests.test_http_origin_guard {
        LoopbackOriginGuard,
        build_http_middleware,
        is_loopback_host,
        split_host_port,
    }
    code_review_graph.graph --> tests.test_identity_pending_ignored { GraphStore }
    code_review_graph.incremental --> tests.test_identity_pending_ignored {
        CPP_IDENTITY_VERSION,
        full_build,
        incremental_update,
    }
    code_review_graph.parser --> tests.test_identity_pending_ignored { CodeParser }
    code_review_graph.graph --> tests.test_identity_retry { GraphStore }
    code_review_graph.incremental --> tests.test_identity_retry {
        CPP_IDENTITY_VERSION,
        incremental_update,
    }
    code_review_graph.parser --> tests.test_identity_retry { CodeParser, NodeInfo }
    code_review_graph.analysis --> tests.test_import_cycles {
        find_import_cycles,
        find_knowledge_gaps,
    }
    code_review_graph.constants --> tests.test_import_cycles {
        IMPORT_CONTEXT_DEFERRED,
        IMPORT_CONTEXT_KEY,
        IMPORT_CONTEXT_PARENT_PACKAGE,
        IMPORT_CONTEXT_TYPE_ONLY,
    }
    code_review_graph.graph --> tests.test_import_cycles { GraphStore }
    code_review_graph.incremental --> tests.test_import_cycles { full_build, get_db_path }
    code_review_graph.parser --> tests.test_import_cycles { CodeParser, EdgeInfo, NodeInfo }
    code_review_graph.tools --> tests.test_import_cycles { get_knowledge_gaps_func }
    code_review_graph.graph --> tests.test_import_scope {
        GraphStore,
        IMPACT_FRONTIER_DIRS_SQL,
        _impact_candidate_sql,
        import_scope_ancestors,
    }
    code_review_graph.incremental --> tests.test_import_scope { full_build, incremental_update }
    code_review_graph.tools.query --> tests.test_import_scope { get_impact_radius, query_graph }
    code_review_graph.graph --> tests.test_import_target_integrity { GraphStore }
    code_review_graph.incremental --> tests.test_import_target_integrity {
        _run_python_resolver,
        full_build,
    }
    tests.import_audit --> tests.test_import_target_integrity {
        audit_imports,
        exists_case_exact,
        looks_like_a_path,
        missing_path_targets,
    }
    code_review_graph.constants --> tests.test_incremental;
    code_review_graph.constants --> tests.test_incremental { discovery_timeout }
    code_review_graph.incremental --> tests.test_incremental;
    code_review_graph.incremental --> tests.test_incremental {
        DEFAULT_IGNORE_PATTERNS,
        _create_watch_handler,
        _decode_name_status_paths,
        _get_code_parser_cls,
        _is_binary,
        _load_ignore_patterns,
        _parse_single_file,
        _prewarm_parser_probes,
        _should_ignore,
        _single_hop_dependents,
        discover_review_changes,
        ensure_repo_gitignore_excludes_crg,
        find_dependents,
        find_project_root,
        find_repo_root,
        full_build,
        get_all_tracked_files,
        get_changed_files,
        get_data_dir,
        get_db_path,
        get_staged_and_unstaged,
        incremental_update,
        start_watch_thread,
        watch,
    }
    code_review_graph.tools --> tests.test_incremental;
    code_review_graph.daemon --> tests.test_incremental { DaemonConfig, WatchDaemon, WatchRepo }
    code_review_graph.errors --> tests.test_incremental { ChangeDiscoveryError }
    code_review_graph.event_resolver --> tests.test_incremental { _clear_derived_event_data }
    code_review_graph.graph --> tests.test_incremental { GraphStore }
    code_review_graph.python_resolver --> tests.test_incremental { resolve_python_imports }
    code_review_graph.spring_resolver --> tests.test_incremental { resolve_spring_di_calls }
    code_review_graph.temporal_resolver --> tests.test_incremental { resolve_temporal_calls }
    code_review_graph.registry --> tests.test_incremental { Registry }
    code_review_graph.parser --> tests.test_incremental { CodeParser, EdgeInfo, NodeInfo }
    code_review_graph.jedi_resolver --> tests.test_incremental { enrich_jedi_calls }
    code_review_graph.flows --> tests.test_incremental {
        get_flows,
        incremental_trace_flows,
        store_flows,
        trace_flows,
    }
    code_review_graph.tools.build --> tests.test_incremental { _run_postprocess }
    code_review_graph.communities --> tests.test_incremental {
        detect_communities,
        get_communities,
        store_communities,
    }
    code_review_graph.postprocessing --> tests.test_incremental { run_post_processing }
    code_review_graph.graph --> tests.test_incremental_dependent_derived_state { GraphStore }
    code_review_graph.incremental --> tests.test_incremental_dependent_derived_state {
        full_build,
        incremental_update,
    }
    code_review_graph.tools.build --> tests.test_incremental_dependent_derived_state {
        build_or_update_graph,
    }
    code_review_graph.tools.flows_tools --> tests.test_incremental_dependent_derived_state {
        get_flow,
    }
    code_review_graph.tools.review --> tests.test_incremental_dependent_derived_state {
        get_affected_flows_func,
    }
    code_review_graph.eval.benchmarks.incremental_fidelity --> tests.test_incremental_fidelity;
    code_review_graph.eval.runner --> tests.test_incremental_fidelity { BENCHMARK_REGISTRY }
    code_review_graph.eval.reporter --> tests.test_incremental_fidelity {
        generate_full_report,
        generate_readme_tables,
    }
    code_review_graph.graph --> tests.test_incremental_fidelity { GraphStore }
    code_review_graph.incremental --> tests.test_incremental_fidelity { get_db_path }
    code_review_graph.tools.build --> tests.test_incremental_fidelity { build_or_update_graph }
    code_review_graph.flows --> tests.test_incremental_flow_lifecycle {
        clear_flows_for_files,
        expand_changed_file_paths,
        get_flow_by_id,
        incremental_trace_flows,
        store_flows,
        trace_flows,
    }
    code_review_graph.graph --> tests.test_incremental_flow_lifecycle { GraphStore }
    code_review_graph.incremental --> tests.test_incremental_flow_lifecycle;
    code_review_graph.incremental --> tests.test_incremental_flow_lifecycle {
        full_build,
        get_db_path,
        incremental_update,
    }
    code_review_graph.parser --> tests.test_incremental_flow_lifecycle {
        CodeParser,
        EdgeInfo,
        NodeInfo,
    }
    code_review_graph.tools.build --> tests.test_incremental_flow_lifecycle {
        build_or_update_graph,
        run_postprocess,
    }
    code_review_graph.communities --> tests.test_incremental_flow_lifecycle {
        capture_community_assignments,
        incremental_detect_communities,
        purge_empty_communities,
        remap_community_assignments,
    }
    code_review_graph.incremental --> tests.test_incremental_reexport_regression;
    code_review_graph.incremental --> tests.test_incremental_reexport_regression {
        full_build,
        incremental_update,
    }
    code_review_graph.graph --> tests.test_incremental_reexport_regression { GraphStore }
    code_review_graph.parser --> tests.test_incremental_reexport_regression { CodeParser }
    code_review_graph.tools.build --> tests.test_incremental_reexport_regression {
        build_or_update_graph,
    }
    code_review_graph.tools.query --> tests.test_incremental_reexport_regression { query_graph }
    code_review_graph.graph --> tests.test_incremental_unindexed_change_memory { GraphStore }
    code_review_graph.incremental --> tests.test_incremental_unindexed_change_memory {
        full_build,
        incremental_update,
    }
    code_review_graph.graph --> tests.test_inherited_calls { GraphStore }
    code_review_graph.incremental --> tests.test_inherited_calls { get_db_path }
    code_review_graph.parser --> tests.test_inherited_calls { CodeParser }
    code_review_graph.postprocessing --> tests.test_inherited_calls { run_post_processing }
    code_review_graph.refactor --> tests.test_inherited_calls { find_dead_code }
    code_review_graph.tools --> tests.test_inherited_calls { query_graph }
    code_review_graph.tools.build --> tests.test_inherited_calls { build_or_update_graph }
    code_review_graph.cli --> tests.test_install_files_stay_out_of_graph;
    code_review_graph.install_manifest --> tests.test_install_files_stay_out_of_graph;
    code_review_graph.uninstall --> tests.test_install_files_stay_out_of_graph;
    code_review_graph.graph --> tests.test_install_files_stay_out_of_graph { GraphStore }
    code_review_graph.incremental --> tests.test_install_files_stay_out_of_graph {
        INSTALL_MANIFEST,
        collect_all_files,
        discover_review_changes,
        full_build,
        get_changed_files,
        get_staged_and_unstaged,
        install_manifest_paths,
    }
    code_review_graph.install_gitignore --> tests.test_install_gitignore_block;
    code_review_graph.skills --> tests.test_install_gitignore_block;
    code_review_graph.uninstall --> tests.test_install_gitignore_block;
    code_review_graph.cli --> tests.test_install_gitignore_block;
    code_review_graph.cli --> tests.test_install_gitignore_block { _handle_init }
    code_review_graph.cli --> tests.test_install_manifest;
    code_review_graph.install_manifest --> tests.test_install_manifest;
    code_review_graph.install_plan --> tests.test_install_manifest;
    code_review_graph.skills --> tests.test_install_manifest;
    code_review_graph.uninstall --> tests.test_install_manifest;
    code_review_graph.cli --> tests.test_install_outputs_are_ignored;
    code_review_graph.skills --> tests.test_install_outputs_are_ignored;
    code_review_graph.cli --> tests.test_install_preview;
    code_review_graph.install_plan --> tests.test_install_preview;
    code_review_graph.skills --> tests.test_install_preview;
    code_review_graph.errors --> tests.test_install_preview { CodeReviewGraphError }
    code_review_graph.install_gitignore --> tests.test_install_preview;
    code_review_graph.skills --> tests.test_installer_ownership;
    code_review_graph.uninstall --> tests.test_installer_ownership;
    code_review_graph.dsh --> tests.test_installer_ownership;
    code_review_graph.changes --> tests.test_integration_git { parse_git_diff_ranges }
    code_review_graph.errors --> tests.test_integration_git { ChangeDiscoveryError }
    code_review_graph.graph --> tests.test_integration_git { GraphStore }
    code_review_graph.incremental --> tests.test_integration_git {
        _commit_object_exists,
        collect_all_files,
        discover_review_changes,
        full_build,
        get_all_tracked_files,
        get_changed_files,
        get_db_path,
        get_staged_and_unstaged,
        incremental_update,
        resolve_incremental_base,
        resolve_review_base,
    }
    code_review_graph.tools._common --> tests.test_integration_git { graph_provenance }
    code_review_graph.tools.build --> tests.test_integration_git { build_or_update_graph }
    code_review_graph.tools.context --> tests.test_integration_git { get_minimal_context }
    code_review_graph.wiki --> tests.test_integration_git { get_wiki_page }
    code_review_graph.tools.query --> tests.test_integration_git { get_impact_radius, query_graph }
    code_review_graph.tools.review --> tests.test_integration_git {
        detect_changes_func,
        get_affected_flows_func,
        get_review_context,
    }
    code_review_graph.cli --> tests.test_integration_git;
    code_review_graph.main --> tests.test_integration_git { build_or_update_graph_tool }
    code_review_graph.changes --> tests.test_integration_v2 { analyze_changes }
    code_review_graph.communities --> tests.test_integration_v2 {
        detect_communities,
        get_architecture_overview,
        get_communities,
        store_communities,
    }
    code_review_graph.flows --> tests.test_integration_v2 {
        get_affected_flows,
        get_flow_by_id,
        get_flows,
        store_flows,
        trace_flows,
    }
    code_review_graph.graph --> tests.test_integration_v2 { GraphStore }
    code_review_graph.hints --> tests.test_integration_v2 {
        generate_hints,
        get_session,
        reset_session,
    }
    code_review_graph.parser --> tests.test_integration_v2 { EdgeInfo, NodeInfo }
    code_review_graph.prompts --> tests.test_integration_v2 { review_changes_prompt }
    code_review_graph.refactor --> tests.test_integration_v2 { find_dead_code, rename_preview }
    code_review_graph.registry --> tests.test_integration_v2 { Registry }
    code_review_graph.search --> tests.test_integration_v2 { hybrid_search, rebuild_fts_index }
    code_review_graph.wiki --> tests.test_integration_v2 { generate_wiki }
    code_review_graph.flows --> tests.test_java_call_references { detect_entry_points }
    code_review_graph.graph --> tests.test_java_call_references { GraphStore }
    code_review_graph.parser --> tests.test_java_call_references { CodeParser, EdgeInfo, NodeInfo }
    code_review_graph.parser --> tests.test_java_name_extraction { CodeParser }
    code_review_graph.parser --> tests.test_js_module_resolution { CodeParser }
    code_review_graph.graph --> tests.test_js_wrapped_functions { GraphStore }
    code_review_graph.incremental --> tests.test_js_wrapped_functions {
        full_build,
        incremental_update,
    }
    code_review_graph.parser --> tests.test_js_wrapped_functions { CodeParser }
    code_review_graph.tools.query --> tests.test_js_wrapped_functions { query_graph }
    code_review_graph.changes --> tests.test_json_parser { analyze_changes }
    code_review_graph.graph --> tests.test_json_parser { GraphStore }
    code_review_graph.incremental --> tests.test_json_parser {
        DEFAULT_IGNORE_PATTERNS,
        _should_ignore,
        full_build,
        get_db_path,
        incremental_update,
    }
    code_review_graph.parser --> tests.test_json_parser { CodeParser, normalize_file_path }
    code_review_graph.postprocessing --> tests.test_json_parser { run_post_processing }
    code_review_graph.search --> tests.test_json_parser { hybrid_search }
    code_review_graph.tools.query --> tests.test_json_parser { query_graph, semantic_search_nodes }
    code_review_graph.tools.review --> tests.test_json_parser { detect_changes_func }
    code_review_graph.cli --> tests.test_json_parser { build_parser }
    code_review_graph.jsonc --> tests.test_jsonc_removals;
    code_review_graph.jsonc --> tests.test_jsonc_removals { remove_paths }
    code_review_graph.skills --> tests.test_jsonc_removals;
    code_review_graph.skills --> tests.test_jsonc_removals { _strip_jsonc }
    code_review_graph.uninstall --> tests.test_jsonc_removals;
    code_review_graph.graph --> tests.test_julia_reconciliation { GraphStore }
    code_review_graph.incremental --> tests.test_julia_reconciliation { full_build }
    code_review_graph.parser --> tests.test_julia_reconciliation { CodeParser }
    code_review_graph.graph --> tests.test_jvm_implementors { GraphStore }
    code_review_graph.parser --> tests.test_jvm_implementors { CodeParser }
    code_review_graph.spring_resolver --> tests.test_jvm_implementors { resolve_spring_di_calls }
    code_review_graph.temporal_resolver --> tests.test_jvm_implementors { resolve_temporal_calls }
    code_review_graph.parser --> tests.test_keyword_argument_callbacks { CodeParser }
    code_review_graph.graph --> tests.test_keyword_argument_callbacks { GraphStore }
    code_review_graph.refactor --> tests.test_keyword_argument_callbacks { find_dead_code }
    code_review_graph.parser --> tests.test_kotlin_import_comments { CodeParser }
    code_review_graph.parser --> tests.test_kotlin_imports { CodeParser }
    code_review_graph.graph --> tests.test_language_reconciliation { GraphStore }
    code_review_graph.parser --> tests.test_language_reconciliation { CodeParser }
    code_review_graph.flows --> tests.test_language_reconciliation { detect_entry_points }
    code_review_graph.refactor --> tests.test_language_reconciliation { find_dead_code }
    code_review_graph.incremental --> tests.test_language_reconciliation {
        full_build,
        incremental_update,
    }
    code_review_graph.graph --> tests.test_legacy_graph_paths { GraphStore }
    code_review_graph.incremental --> tests.test_legacy_graph_paths {
        full_build,
        incremental_update,
    }
    code_review_graph.parser --> tests.test_legacy_graph_paths { NodeInfo }
    code_review_graph.graph --> tests.test_liquid { GraphStore }
    code_review_graph.incremental --> tests.test_liquid { full_build, get_db_path }
    code_review_graph.parser --> tests.test_liquid { CodeParser, normalize_file_path }
    code_review_graph.search --> tests.test_liquid { hybrid_search, rebuild_fts_index }
    code_review_graph.tools --> tests.test_liquid { get_impact_radius, query_graph }
    code_review_graph.incremental --> tests.test_main;
    code_review_graph.tools.docs --> tests.test_main;
    code_review_graph.main --> tests.test_main;
    code_review_graph.http_origin_guard --> tests.test_main { LoopbackOriginGuard }
    code_review_graph.main --> tests.test_main_lazy_tool_imports;
    code_review_graph.incremental --> tests.test_mcp_auto_watch;
    code_review_graph.main --> tests.test_mcp_auto_watch;
    code_review_graph.graph --> tests.test_mcp_auto_watch { GraphStore }
    code_review_graph.postprocessing --> tests.test_mcp_auto_watch { run_post_processing }
    tests.test_watch_robustness --> tests.test_mcp_auto_watch { FakeObserver }
    code_review_graph.daemon --> tests.test_watch_robustness {
        DaemonConfig,
        WatchDaemon,
        WatchRepo,
        read_watch_health,
        watch_health_path,
        watcher_status,
    }
    code_review_graph.graph --> tests.test_watch_robustness { GraphStore }
    code_review_graph.incremental --> tests.test_watch_robustness;
    code_review_graph.incremental --> tests.test_watch_robustness {
        _WATCH_SPLIT_MIN_DIRS,
        _WatchSupervisor,
        _create_watch_handler,
        _load_ignore_patterns,
        _plan_watch_paths,
        _should_ignore,
        _sync_watch_tree,
        clear_nested_ignore_cache,
        incremental_update,
        watch,
    }
    code_review_graph.parser --> tests.test_watch_robustness { NodeInfo }
    code_review_graph.cli --> tests.test_watch_robustness;
    code_review_graph.daemon_cli --> tests.test_watch_robustness { _handle_status }
    code_review_graph.incremental --> tests.test_mcp_auto_watch_startup_window;
    code_review_graph.postprocessing --> tests.test_mcp_auto_watch_startup_window;
    code_review_graph.main --> tests.test_mcp_auto_watch_startup_window;
    code_review_graph.graph --> tests.test_mcp_auto_watch_startup_window { GraphStore }
    tests.mcp_client_compat --> tests.test_mcp_surface { read_timeout, wire }
    tests.test_token_budget --> tests.test_mcp_surface { BUDGETS }
    code_review_graph.changes --> tests.test_token_budget;
    code_review_graph.main --> tests.test_token_budget;
    code_review_graph.graph --> tests.test_token_budget { GraphStore }
    code_review_graph.incremental --> tests.test_token_budget { full_build }
    code_review_graph.tools.analysis_tools --> tests.test_token_budget;
    code_review_graph.tools.community_tools --> tests.test_token_budget;
    code_review_graph.tools.query --> tests.test_token_budget;
    code_review_graph.tools.review --> tests.test_token_budget;
    code_review_graph.tools.refactor_tools --> tests.test_token_budget;
    code_review_graph.registry --> tests.test_token_budget { Registry }
    code_review_graph.search --> tests.test_token_budget;
    code_review_graph.incremental --> tests.test_mcp_watch_store_shutdown;
    code_review_graph.postprocessing --> tests.test_mcp_watch_store_shutdown;
    code_review_graph.main --> tests.test_mcp_watch_store_shutdown;
    code_review_graph.memory --> tests.test_memory { clear_memories, list_memories, save_result }
    code_review_graph.graph --> tests.test_migrations { GraphStore }
    code_review_graph.migrations --> tests.test_migrations;
    code_review_graph.migrations --> tests.test_migrations {
        LATEST_VERSION,
        MIGRATIONS,
        _migrate_v6,
        get_schema_version,
        run_migrations,
    }
    code_review_graph.incremental --> tests.test_missing_registered_data_dir { get_data_dir }
    code_review_graph.registry --> tests.test_missing_registered_data_dir { Registry }
    code_review_graph.cli --> tests.test_missing_registered_data_dir { main }
    code_review_graph.cli --> tests.test_missing_repo_path_is_one_error_line;
    code_review_graph.incremental --> tests.test_multi_worktree { get_db_path }
    code_review_graph.multi_worktree --> tests.test_multi_worktree {
        MultiWorktreeError,
        MultiWorktreeRouter,
        WorktreeAuthorizer,
        _Child,
        _MAX_INFLIGHT_REQUESTS,
        run_multi_worktree_server,
    }
    code_review_graph.registry --> tests.test_multi_worktree { Registry }
    code_review_graph.graph --> tests.test_multilang { GraphStore }
    code_review_graph.parser --> tests.test_multilang { CodeParser }
    code_review_graph.tools.query --> tests.test_multilang { get_impact_radius, query_graph }
    code_review_graph.incremental --> tests.test_multilang { full_build }
    code_review_graph.postprocessing --> tests.test_multilang { run_post_processing }
    code_review_graph.scoped_resolver --> tests.test_multilang { resolve_scoped_calls }
    code_review_graph.changes --> tests.test_multilang { analyze_changes }
    code_review_graph.rescript_resolver --> tests.test_multilang { resolve_rescript_cross_module }
    code_review_graph.refactor --> tests.test_multilang { find_dead_code }
    code_review_graph.graph --> tests.test_neighbourhood { GraphStore }
    code_review_graph.parser --> tests.test_neighbourhood { EdgeInfo, NodeInfo }
    code_review_graph.visualization --> tests.test_neighbourhood {
        export_graph_data,
        generate_html,
    }
    code_review_graph.neighbourhood --> tests.test_neighbourhood {
        NeighbourhoodSpec,
        PATH_EDGE_KINDS,
        SeedResolutionError,
        extract,
    }
    code_review_graph.flows --> tests.test_neighbourhood { store_flows }
    code_review_graph.cli --> tests.test_neighbourhood {
        _check_visualize_flags,
        _print_seed_budget,
        build_parser,
    }
    code_review_graph.visualization --> tests.test_neighbourhood_bounded_reads;
    code_review_graph.visualization --> tests.test_neighbourhood_bounded_reads {
        export_graph_data,
        generate_html,
    }
    code_review_graph.graph --> tests.test_neighbourhood_bounded_reads { GraphStore }
    code_review_graph.neighbourhood --> tests.test_neighbourhood_bounded_reads {
        NeighbourhoodSpec,
        SeedResolutionError,
        extract,
    }
    code_review_graph.parser --> tests.test_neighbourhood_bounded_reads { EdgeInfo, NodeInfo }
    code_review_graph.graph --> tests.test_neighbourhood_browser { GraphStore }
    code_review_graph.parser --> tests.test_neighbourhood_browser { EdgeInfo, NodeInfo }
    code_review_graph.visualization --> tests.test_neighbourhood_browser { generate_html }
    code_review_graph.graph --> tests.test_nested_method_identities { GraphStore }
    code_review_graph.incremental --> tests.test_nested_method_identities {
        full_build,
        incremental_update,
    }
    code_review_graph.parser --> tests.test_nested_method_identities { CodeParser }
    code_review_graph.postprocessing --> tests.test_nested_method_identities { run_post_processing }
    code_review_graph.graph --> tests.test_nested_scope_upgrade { GraphStore }
    code_review_graph.incremental --> tests.test_nested_scope_upgrade {
        NESTED_SCOPE_IDENTITY_VERSION,
        full_build,
        incremental_update,
    }
    code_review_graph.cli --> tests.test_no_savings_panel_without_changed_functions;
    code_review_graph.tools.build --> tests.test_no_savings_panel_without_changed_functions {
        build_or_update_graph,
    }
    code_review_graph.parser --> tests.test_notebook { CodeParser, _SQL_TABLE_RE }
    code_review_graph.graph --> tests.test_npm_alias_resolver { GraphStore }
    code_review_graph.incremental --> tests.test_npm_alias_resolver { full_build, get_db_path }
    code_review_graph.npm_alias_resolver --> tests.test_npm_alias_resolver { version_satisfies }
    code_review_graph.parser --> tests.test_npm_alias_resolver { CodeParser }
    code_review_graph.tools.query --> tests.test_npm_alias_resolver { query_graph }
    code_review_graph.skills --> tests.test_opencode_plugin_follows_xdg_config_home;
    code_review_graph.uninstall --> tests.test_opencode_plugin_follows_xdg_config_home;
    code_review_graph.skills --> tests.test_opencode_uninstall_cleans_both_configs;
    code_review_graph.uninstall --> tests.test_opencode_uninstall_cleans_both_configs;
    code_review_graph.skills --> tests.test_opencode_v1_plugin_contract { _opencode_plugin_content }
    code_review_graph.skills --> tests.test_opencode_v2_plugin_contract;
    code_review_graph.skills --> tests.test_opencode_v2_plugin_contract {
        _opencode_plugin_content,
        install_opencode_plugin,
    }
    code_review_graph.uninstall --> tests.test_opencode_v2_plugin_contract;
    code_review_graph.cli --> tests.test_opencode_v2_plugin_contract;
    code_review_graph.cli --> tests.test_optional_dependencies;
    code_review_graph.exports --> tests.test_optional_dependencies {
        MissingOptionalDependencyError,
        export_svg,
    }
    code_review_graph.embeddings --> tests.test_optional_dependencies;
    code_review_graph.tools.docs --> tests.test_optional_dependencies;
    code_review_graph.eval.runner --> tests.test_optional_dependencies;
    code_review_graph.skills --> tests.test_packaging { _SKILLS }
    code_review_graph.graph --> tests.test_parser { GraphStore }
    code_review_graph.incremental --> tests.test_parser { full_build }
    code_review_graph.parser --> tests.test_parser {
        CodeParser,
        _PythonUnreachableCallVisitor,
        _clear_parser_probe_cache,
        _is_in_rust_dead_guard,
        _is_in_static_dead_guard,
        _is_statically_false_condition,
        _is_test_file,
        _node_is_in_child,
        _python_type_checking_aliases,
    }
    code_review_graph.tools.query --> tests.test_parser { get_impact_radius, query_graph }
    code_review_graph.flows --> tests.test_parser { _has_framework_decorator }
    code_review_graph.refactor --> tests.test_parser { find_dead_code }
    code_review_graph.parser --> tests.test_parser_grammar_contract {
        CodeParser,
        EXTENSION_TO_LANGUAGE,
        SHEBANG_INTERPRETER_TO_LANGUAGE,
        _CALL_TYPES,
        _CLASS_TYPES,
        _FUNCTION_TYPES,
        _IMPORT_TYPES,
    }
    code_review_graph.parser --> tests.test_parser_load_probe;
    code_review_graph.parser --> tests.test_parser_load_probe { CodeParser }
    code_review_graph.changes --> tests.test_php_guessed_test_links { analyze_changes }
    code_review_graph.graph --> tests.test_php_guessed_test_links { GraphStore }
    code_review_graph.incremental --> tests.test_php_guessed_test_links { full_build }
    code_review_graph.parser --> tests.test_php_guessed_test_links { EdgeInfo, NodeInfo }
    code_review_graph.postprocessing --> tests.test_php_guessed_test_links { run_post_processing }
    code_review_graph.tools.query --> tests.test_php_guessed_test_links { query_graph }
    code_review_graph.parser --> tests.test_php_includes { CodeParser }
    code_review_graph.parser --> tests.test_php_laravel;
    code_review_graph.parser --> tests.test_php_laravel { CodeParser }
    code_review_graph.graph --> tests.test_php_laravel { GraphStore }
    code_review_graph.incremental --> tests.test_php_laravel { full_build }
    code_review_graph.graph --> tests.test_php_scoped_calls { GraphStore }
    code_review_graph.incremental --> tests.test_php_scoped_calls { full_build, incremental_update }
    code_review_graph.scoped_resolver --> tests.test_php_scoped_calls {
        _path_tokens,
        resolve_scoped_calls,
    }
    code_review_graph.tools.query --> tests.test_php_scoped_calls { get_impact_radius, query_graph }
    code_review_graph.cli --> tests.test_platform_lifecycle;
    code_review_graph.skills --> tests.test_platform_lifecycle;
    code_review_graph.uninstall --> tests.test_platform_lifecycle;
    code_review_graph.dsh --> tests.test_platform_lifecycle;
    code_review_graph.skills --> tests.test_plugin_hooks_check_for_git;
    code_review_graph.uninstall --> tests.test_plugin_hooks_check_for_git;
    code_review_graph.skills --> tests.test_post_rewrite_updates_after_amend;
    code_review_graph.uninstall --> tests.test_post_rewrite_updates_after_amend;
    tests.test_git_sync_hooks --> tests.test_post_rewrite_updates_after_amend {
        calls,
        commit_file,
        git,
        sync_repo,
    }
    code_review_graph.graph --> tests.test_postprocessing { GraphStore }
    code_review_graph.incremental --> tests.test_postprocessing {
        full_build,
        incremental_update,
        watch,
    }
    code_review_graph.parser --> tests.test_postprocessing { EdgeInfo, NodeInfo }
    code_review_graph.postprocessing --> tests.test_postprocessing { run_post_processing }
    code_review_graph.search --> tests.test_postprocessing { hybrid_search }
    code_review_graph.tools.query --> tests.test_postprocessing { query_graph }
    code_review_graph.parser --> tests.test_powershell_extraction { CodeParser }
    code_review_graph.cli --> tests.test_pr803_poisoned_graph_recovery;
    code_review_graph.build_state --> tests.test_pr803_poisoned_graph_recovery {
        BUILD_IN_PROGRESS,
        BUILD_STATE_KEY,
    }
    code_review_graph.errors --> tests.test_pr803_poisoned_graph_recovery { GraphRootMismatchError }
    code_review_graph.forget --> tests.test_pr803_poisoned_graph_recovery { forget_files }
    code_review_graph.graph --> tests.test_pr803_poisoned_graph_recovery { GraphStore }
    code_review_graph.incremental --> tests.test_pr803_poisoned_graph_recovery {
        full_build,
        get_db_path,
        incremental_update,
    }
    code_review_graph.parser --> tests.test_pr803_poisoned_graph_recovery { CodeParser, NodeInfo }
    code_review_graph.tools.build --> tests.test_pr803_poisoned_graph_recovery;
    code_review_graph.tools.build --> tests.test_pr803_poisoned_graph_recovery {
        _should_rebuild_partial_graph,
        build_or_update_graph,
    }
    code_review_graph.prompts --> tests.test_prompts {
        architecture_map_prompt,
        debug_issue_prompt,
        onboard_developer_prompt,
        pre_merge_check_prompt,
        review_changes_prompt,
    }
    code_review_graph.hints --> tests.test_public_tool_hints {
        SessionState,
        _INTENT_TOOLS,
        _WORKFLOW,
        generate_hints,
    }
    code_review_graph.changes --> tests.test_pure_deletion_review {
        DiffRanges,
        _parse_unified_diff,
        analyze_changes,
    }
    code_review_graph.graph --> tests.test_pure_deletion_review { GraphStore }
    code_review_graph.incremental --> tests.test_pure_deletion_review {
        full_build,
        incremental_update,
    }
    code_review_graph.postprocessing --> tests.test_pure_deletion_review { run_post_processing }
    code_review_graph.tools.review --> tests.test_pure_deletion_review { detect_changes_func }
    code_review_graph.graph --> tests.test_python_module_alias_shims { GraphStore }
    code_review_graph.incremental --> tests.test_python_module_alias_shims {
        full_build,
        incremental_update,
    }
    code_review_graph.parser --> tests.test_python_module_alias_shims { CodeParser }
    code_review_graph.postprocessing --> tests.test_python_module_alias_shims {
        run_post_processing,
    }
    code_review_graph.graph --> tests.test_python_property_reads { GraphStore }
    code_review_graph.parser --> tests.test_python_property_reads { CodeParser }
    code_review_graph.graph --> tests.test_python_reachability { GraphStore }
    code_review_graph.parser --> tests.test_python_reachability { CodeParser }
    code_review_graph.refactor --> tests.test_python_reachability { find_dead_code }
    code_review_graph.graph --> tests.test_python_receiver_evidence { GraphStore }
    code_review_graph.parser --> tests.test_python_receiver_evidence { CodeParser }
    code_review_graph.graph --> tests.test_python_receiver_shapes { GraphStore }
    code_review_graph.incremental --> tests.test_python_receiver_shapes { full_build }
    code_review_graph.parser --> tests.test_python_receiver_shapes { CodeParser }
    code_review_graph.postprocessing --> tests.test_python_receiver_shapes { run_post_processing }
    code_review_graph.tools --> tests.test_python_receiver_shapes { query_graph }
    code_review_graph.parser --> tests.test_python_relative_imports { CodeParser }
    tests.import_audit --> tests.test_python_relative_imports {
        exists_case_exact,
        looks_like_a_path,
    }
    code_review_graph.parser --> tests.test_python_star_imports { CodeParser }
    code_review_graph.incremental --> tests.test_python_star_imports { _parse_single_file }
    code_review_graph.skills --> tests.test_qoder_bundled_skills { install_qoder_skills }
    code_review_graph.graph --> tests.test_query_exact_name { GraphStore }
    code_review_graph.incremental --> tests.test_query_exact_name { get_db_path }
    code_review_graph.parser --> tests.test_query_exact_name { EdgeInfo, NodeInfo }
    code_review_graph.tools --> tests.test_query_exact_name { query_graph }
    code_review_graph.cli --> tests.test_query_path_to;
    code_review_graph.graph --> tests.test_query_path_to { GraphStore }
    code_review_graph.incremental --> tests.test_query_path_to { full_build, get_db_path }
    code_review_graph.parser --> tests.test_query_path_to { EdgeInfo, NodeInfo }
    code_review_graph.tools.query --> tests.test_query_path_to;
    code_review_graph.tools --> tests.test_query_path_to { query_graph }
    code_review_graph.communities --> tests.test_quiet_first_build;
    code_review_graph.event_resolver --> tests.test_quiet_first_build { resolve_spring_events }
    code_review_graph.graph --> tests.test_quiet_first_build { GraphStore }
    code_review_graph.migrations --> tests.test_quiet_first_build {
        LATEST_VERSION,
        _progress_level,
    }
    code_review_graph.parser --> tests.test_quiet_first_build { EdgeInfo, NodeInfo }
    code_review_graph.python_resolver --> tests.test_quiet_first_build { resolve_python_imports }
    code_review_graph.cli --> tests.test_read_only_data_dir;
    code_review_graph.graph --> tests.test_read_only_data_dir { GraphStore }
    tests.real_repo_corpus --> tests.test_real_repo_corpus {
        Bands,
        Measurement,
        PROPERTY_NAMES,
        compare,
        ensure_clone,
        failures,
        head_sha,
        load_baselines,
        measure,
        repo_specs,
        spec_by_name,
    }
    tests.real_repo_corpus --> tests.test_real_repo_corpus_guard {
        BASELINE_PATH,
        Bands,
        Measurement,
        PROPERTY_NAMES,
        _load_eval_pin,
        compare,
        corpus_selected,
        failures,
        load_baselines,
        repo_specs,
    }
    tests.test_real_repo_corpus --> tests.test_real_repo_corpus_guard { PERTURBATIONS }
    code_review_graph.graph --> tests.test_receiver_evidence_read_path { GraphStore }
    code_review_graph.incremental --> tests.test_receiver_evidence_read_path { full_build }
    code_review_graph.parser --> tests.test_receiver_evidence_read_path { EdgeInfo, NodeInfo }
    code_review_graph.postprocessing --> tests.test_receiver_evidence_read_path {
        run_post_processing,
    }
    code_review_graph.tools --> tests.test_receiver_evidence_read_path { query_graph }
    code_review_graph.graph --> tests.test_reconcile_orphan_purge { GraphStore }
    code_review_graph.incremental --> tests.test_reconcile_orphan_purge {
        _reconcile_stale_files,
        full_build,
    }
    code_review_graph.parser --> tests.test_reconcile_orphan_purge { EdgeInfo, NodeInfo }
    code_review_graph.graph --> tests.test_refactor { GraphStore }
    code_review_graph.incremental --> tests.test_refactor { full_build }
    code_review_graph.parser --> tests.test_refactor { CodeParser, EdgeInfo, NodeInfo }
    code_review_graph.refactor --> tests.test_refactor {
        REFACTOR_EXPIRY_SECONDS,
        _pending_refactors,
        _refactor_lock,
        apply_refactor,
        find_dead_code,
        rename_preview,
        suggest_refactorings,
    }
    code_review_graph.cli --> tests.test_registered_data_dir_recovery;
    code_review_graph.graph --> tests.test_registered_data_dir_recovery { GraphStore }
    code_review_graph.incremental --> tests.test_registered_data_dir_recovery {
        full_build,
        get_data_dir,
        get_db_path,
    }
    code_review_graph.registry --> tests.test_registered_data_dir_recovery {
        Registry,
        default_registry_path,
    }
    code_review_graph.tools.query --> tests.test_registered_data_dir_recovery { list_graph_stats }
    code_review_graph.tools.registry_tools --> tests.test_registered_data_dir_recovery {
        cross_repo_search_func,
    }
    code_review_graph.registry --> tests.test_registry {
        ConnectionPool,
        Registry,
        default_registry_path,
        resolve_repo,
    }
    code_review_graph.tools.registry_tools --> tests.test_registry { _echoed, _select_repos }
    code_review_graph.tools --> tests.test_registry { cross_repo_search_func }
    code_review_graph.main --> tests.test_registry;
    code_review_graph.main --> tests.test_registry { cross_repo_search_tool }
    code_review_graph.constants --> tests.test_registry { crg_home }
    code_review_graph.incremental --> tests.test_registry { get_data_dir }
    code_review_graph.graph --> tests.test_registry_search_integration { GraphStore }
    code_review_graph.parser --> tests.test_registry_search_integration { NodeInfo }
    code_review_graph.registry --> tests.test_registry_search_integration { Registry }
    code_review_graph.tools.registry_tools --> tests.test_registry_search_integration {
        cross_repo_search_func,
    }
    code_review_graph.skills --> tests.test_released_shapes;
    code_review_graph.uninstall --> tests.test_released_shapes;
    code_review_graph.dsh --> tests.test_released_shapes;
    code_review_graph.graph --> tests.test_rename_imports { GraphStore }
    code_review_graph.incremental --> tests.test_rename_imports { full_build }
    code_review_graph.refactor --> tests.test_rename_imports {
        _pending_refactors,
        _refactor_lock,
        apply_refactor,
    }
    code_review_graph.tools.refactor_tools --> tests.test_rename_imports {
        apply_refactor_func,
        refactor_func,
    }
    code_review_graph.cli --> tests.test_repo_root_identity;
    code_review_graph.graph --> tests.test_repo_root_identity { GraphStore }
    code_review_graph.incremental --> tests.test_repo_root_identity {
        full_build,
        incremental_update,
    }
    code_review_graph.registry --> tests.test_repos_unreachable_data_dir { Registry }
    code_review_graph.cli --> tests.test_repos_unreachable_data_dir { main }
    code_review_graph.graph --> tests.test_review_branch_scope { GraphStore }
    code_review_graph.tools.review --> tests.test_review_branch_scope { get_review_context }
    code_review_graph.changes --> tests.test_review_guidance_lifecycle { compute_risk_score }
    code_review_graph.graph --> tests.test_review_guidance_lifecycle { GraphStore }
    code_review_graph.parser --> tests.test_review_guidance_lifecycle {
        CodeParser,
        EdgeInfo,
        NodeInfo,
    }
    code_review_graph.tools.review --> tests.test_review_guidance_lifecycle;
    code_review_graph.tools.review --> tests.test_review_guidance_lifecycle {
        _generate_review_guidance,
    }
    code_review_graph.graph --> tests.test_review_risk_budget { GraphStore }
    code_review_graph.incremental --> tests.test_review_risk_budget { full_build }
    code_review_graph.tools.review --> tests.test_review_risk_budget;
    code_review_graph.tools.review --> tests.test_review_risk_budget { get_review_context }
    code_review_graph.tools.review --> tests.test_review_utf8_content { get_review_context }
    code_review_graph.graph --> tests.test_root_overlap { GraphStore }
    code_review_graph.incremental --> tests.test_root_overlap { full_build, incremental_update }
    code_review_graph.parser --> tests.test_ruby_imports { CodeParser, normalize_file_path }
    code_review_graph.graph --> tests.test_ruby_namespaced_query_targets { GraphStore }
    code_review_graph.incremental --> tests.test_ruby_namespaced_query_targets { full_build }
    code_review_graph.tools.query --> tests.test_ruby_namespaced_query_targets { query_graph }
    code_review_graph.graph --> tests.test_rust_scoped_calls { GraphStore }
    code_review_graph.incremental --> tests.test_rust_scoped_calls { full_build }
    code_review_graph.tools.query --> tests.test_rust_scoped_calls {
        get_impact_radius,
        query_graph,
    }
    code_review_graph.graph --> tests.test_scoped_calls_need_evidence { GraphStore }
    code_review_graph.incremental --> tests.test_scoped_calls_need_evidence { full_build }
    code_review_graph.graph --> tests.test_search { GraphStore }
    code_review_graph.parser --> tests.test_search { NodeInfo }
    code_review_graph.search --> tests.test_search;
    code_review_graph.search --> tests.test_search {
        detect_query_kind_boost,
        hybrid_search,
        rebuild_fts_index,
        rrf_merge,
    }
    code_review_graph.graph --> tests.test_search_quality { GraphStore }
    code_review_graph.migrations --> tests.test_search_quality {
        LATEST_VERSION,
        NODES_FTS_COLUMNS,
        get_schema_version,
    }
    code_review_graph.parser --> tests.test_search_quality { NodeInfo }
    code_review_graph.search --> tests.test_search_quality {
        _MAX_FTS_TERMS,
        build_fts_queries,
        hybrid_search,
        rebuild_fts_index,
        update_fts_index,
    }
    code_review_graph.main --> tests.test_server_instructions;
    code_review_graph.tools.query --> tests.test_server_instructions {
        _QUERY_PATTERNS,
        get_impact_radius,
        query_graph,
    }
    tests.mcp_client_compat --> tests.test_server_instructions { read_timeout }
    code_review_graph.tools.build --> tests.test_server_instructions { build_or_update_graph }
    code_review_graph.skills --> tests.test_settings_backup_keeps_the_users_copy;
    code_review_graph.uninstall --> tests.test_settings_backup_keeps_the_users_copy;
    code_review_graph.skills --> tests.test_skill_template_schema_sync { _SKILLS, generate_skills }
    code_review_graph.skills --> tests.test_skills;
    code_review_graph.skills --> tests.test_skills {
        PLATFORMS,
        _CLAUDE_MD_SECTION_MARKER,
        _copilot_vscode_detected,
        _cursor_hook_scripts,
        _detect_opencode_major_version,
        _detect_serve_command,
        _in_poetry_project,
        _in_uv_project,
        _opencode_plugin_content,
        _running_from_uv_tool,
        _strip_jsonc,
        generate_codex_hooks_config,
        generate_cursor_hooks_config,
        generate_hooks_config,
        generate_skills,
        inject_claude_md,
        inject_platform_instructions,
        install_codebuddy_hooks,
        install_codebuddy_skills,
        install_codex_hooks,
        install_cursor_hooks,
        install_gemini_cli_hooks,
        install_gemini_cli_skills,
        install_git_hook,
        install_hooks,
        install_opencode_plugin,
        install_platform_configs,
    }
    code_review_graph.codex_skill --> tests.test_skills;
    code_review_graph.codex_skill --> tests.test_skills { install_codex_skill }
    code_review_graph.cli --> tests.test_skills;
    code_review_graph.graph --> tests.test_spring_config { GraphStore }
    code_review_graph.parser --> tests.test_spring_config { CodeParser }
    code_review_graph.tools.query --> tests.test_spring_config { query_graph }
    code_review_graph.graph --> tests.test_spring_endpoints { GraphStore }
    code_review_graph.parser --> tests.test_spring_endpoints { CodeParser }
    code_review_graph.tools.query --> tests.test_spring_endpoints { query_graph }
    code_review_graph.graph --> tests.test_spring_events { GraphStore }
    code_review_graph.incremental --> tests.test_spring_events { full_build, incremental_update }
    code_review_graph.parser --> tests.test_spring_events { CodeParser }
    code_review_graph.tools.query --> tests.test_spring_events { query_graph }
    code_review_graph.parser --> tests.test_spring_java_reconciliation { CodeParser, EdgeInfo }
    code_review_graph.graph --> tests.test_spring_resolver { GraphStore }
    code_review_graph.incremental --> tests.test_spring_resolver { full_build, incremental_update }
    code_review_graph.parser --> tests.test_spring_resolver { CodeParser }
    code_review_graph.postprocessing --> tests.test_spring_resolver { run_post_processing }
    code_review_graph.spring_resolver --> tests.test_spring_resolver { resolve_spring_di_calls }
    code_review_graph.graph --> tests.test_spring_scheduling { GraphStore }
    code_review_graph.parser --> tests.test_spring_scheduling { CodeParser }
    code_review_graph.tools.query --> tests.test_spring_scheduling { query_graph }
    code_review_graph.graph --> tests.test_spring_webflux_endpoints { GraphStore }
    code_review_graph.parser --> tests.test_spring_webflux_endpoints { CodeParser }
    code_review_graph.tools.query --> tests.test_spring_webflux_endpoints { query_graph }
    code_review_graph.parser --> tests.test_sql_table_references {
        CodeParser,
        _SQL_KEYWORDS,
        _SQL_TABLE_RE,
    }
    code_review_graph.cli --> tests.test_status_stats;
    code_review_graph.graph --> tests.test_status_stats { GraphStore }
    code_review_graph.incremental --> tests.test_status_stats { full_build, incremental_update }
    code_review_graph.cli --> tests.test_steering_hook;
    code_review_graph.enrich --> tests.test_steering_hook;
    code_review_graph.skills --> tests.test_steering_hook;
    code_review_graph.uninstall --> tests.test_steering_hook;
    code_review_graph.changes --> tests.test_storybook_dead_code { analyze_changes }
    code_review_graph.graph --> tests.test_storybook_dead_code { GraphStore }
    code_review_graph.incremental --> tests.test_storybook_dead_code {
        full_build,
        incremental_update,
    }
    code_review_graph.parser --> tests.test_storybook_dead_code {
        CodeParser,
        EdgeInfo,
        NodeInfo,
        is_test_file,
    }
    code_review_graph.refactor --> tests.test_storybook_dead_code { find_dead_code }
    code_review_graph.skills --> tests.test_suite_home_is_temporary;
    code_review_graph.cli --> tests.test_swept_data_dir_entry_points;
    code_review_graph.graph --> tests.test_swept_data_dir_entry_points { GraphStore }
    code_review_graph.incremental --> tests.test_swept_data_dir_entry_points {
        full_build,
        get_data_dir,
    }
    code_review_graph.registry --> tests.test_swept_data_dir_entry_points { Registry }
    code_review_graph.search --> tests.test_swept_data_dir_entry_points { rebuild_fts_index }
    code_review_graph.enrich --> tests.test_swept_data_dir_entry_points { run_hook }
    code_review_graph.tools.context --> tests.test_swept_data_dir_entry_points {
        get_minimal_context,
    }
    code_review_graph.changes --> tests.test_test_file_detection { analyze_changes }
    code_review_graph.graph --> tests.test_test_file_detection { EdgeInfo, GraphNode, GraphStore }
    code_review_graph.parser --> tests.test_test_file_detection {
        CodeParser,
        NodeInfo,
        is_test_file,
    }
    code_review_graph.tools.review --> tests.test_test_file_detection { _generate_review_guidance }
    code_review_graph.flows --> tests.test_test_file_detection { detect_entry_points }
    code_review_graph.refactor --> tests.test_test_file_detection { find_dead_code }
    code_review_graph.changes --> tests.test_test_gap_exemptions {
        _TEST_GAP_EXEMPT_NAMES,
        analyze_changes,
    }
    code_review_graph.graph --> tests.test_test_gap_exemptions { GraphStore }
    code_review_graph.parser --> tests.test_test_gap_exemptions { EdgeInfo, NodeInfo }
    code_review_graph.changes --> tests.test_test_helper_routes {
        analyze_changes,
        compute_risk_score,
    }
    code_review_graph.graph --> tests.test_test_helper_routes { GraphStore }
    code_review_graph.incremental --> tests.test_test_helper_routes { full_build }
    code_review_graph.parser --> tests.test_test_helper_routes { EdgeInfo, NodeInfo }
    code_review_graph.flows --> tests.test_tests_for_java_ruby { detect_entry_points }
    code_review_graph.graph --> tests.test_tests_for_java_ruby { GraphStore }
    code_review_graph.incremental --> tests.test_tests_for_java_ruby { full_build }
    code_review_graph.parser --> tests.test_tests_for_java_ruby { CodeParser }
    code_review_graph.postprocessing --> tests.test_tests_for_java_ruby { run_post_processing }
    code_review_graph.tools.query --> tests.test_tests_for_java_ruby { query_graph }
    code_review_graph.graph --> tests.test_tests_for_stable_order { GraphStore }
    code_review_graph.parser --> tests.test_tests_for_stable_order { EdgeInfo, NodeInfo }
    code_review_graph.main --> tests.test_tool_annotations { mcp }
    tests.mcp_client_compat --> tests.test_tool_annotations { wire }
    code_review_graph.hints --> tests.test_tool_suggestion_names;
    code_review_graph.main --> tests.test_tool_suggestion_names;
    code_review_graph.tools.context --> tests.test_tool_suggestion_names { get_minimal_context }
    code_review_graph.graph --> tests.test_tool_suggestion_names { GraphStore }
    code_review_graph.incremental --> tests.test_tool_suggestion_names { full_build }
    code_review_graph.tools._common --> tests.test_tools;
    code_review_graph.tools.analysis_tools --> tests.test_tools;
    code_review_graph.tools.docs --> tests.test_tools;
    code_review_graph.tools.query --> tests.test_tools;
    code_review_graph.tools.query --> tests.test_tools {
        _MAX_SEARCH_SOURCE_CHARS_PER_NODE,
        semantic_search_nodes,
    }
    code_review_graph.graph --> tests.test_tools {
        EdgeInfo,
        GraphNode,
        GraphStore,
        _sanitize_name,
        node_to_dict,
    }
    code_review_graph.incremental --> tests.test_tools { full_build, get_db_path }
    code_review_graph.parser --> tests.test_tools { EdgeInfo, NodeInfo }
    code_review_graph.tools --> tests.test_tools {
        _validate_repo_root,
        get_affected_flows_func,
        get_architecture_overview_func,
        get_community_func,
        get_docs_section,
        get_flow,
        get_impact_radius,
        get_review_context,
        list_communities_func,
        list_flows,
        list_graph_stats,
        query_graph,
    }
    code_review_graph.search --> tests.test_tools { rebuild_fts_index }
    code_review_graph.flows --> tests.test_tools { store_flows, trace_flows }
    code_review_graph.communities --> tests.test_tools { detect_communities, store_communities }
    code_review_graph.tools.build --> tests.test_tools;
    code_review_graph.tools.build --> tests.test_tools {
        BUILD_COMPLETE,
        BUILD_IN_PROGRESS,
        BUILD_STATE_KEY,
        _run_postprocess,
        build_or_update_graph,
    }
    code_review_graph.build_state --> tests.test_tools { POSTPROCESS_PENDING }
    code_review_graph.tools.context --> tests.test_tools;
    code_review_graph.tools.context --> tests.test_tools { get_minimal_context }
    code_review_graph.errors --> tests.test_tools { ChangeDiscoveryError }
    code_review_graph.main --> tests.test_tools { get_minimal_context_tool, list_graph_stats_tool }
    code_review_graph.communities --> tests.test_transactions { store_communities }
    code_review_graph.flows --> tests.test_transactions { store_flows }
    code_review_graph.graph --> tests.test_transactions { GraphStore }
    code_review_graph.parser --> tests.test_transactions { NodeInfo }
    code_review_graph.changes --> tests.test_transitive_test_coverage { analyze_changes }
    code_review_graph.graph --> tests.test_transitive_test_coverage { GraphStore }
    code_review_graph.parser --> tests.test_transitive_test_coverage { EdgeInfo, NodeInfo }
    code_review_graph.tools.review --> tests.test_transitive_test_coverage {
        _generate_review_guidance,
    }
    code_review_graph.graph --> tests.test_traverse_long_node_names { GraphStore }
    code_review_graph.incremental --> tests.test_traverse_long_node_names { full_build }
    code_review_graph.tools.query --> tests.test_traverse_long_node_names;
    code_review_graph.graph --> tests.test_tsconfig_resolver { GraphStore }
    code_review_graph.incremental --> tests.test_tsconfig_resolver {
        full_build,
        incremental_update,
    }
    code_review_graph.parser --> tests.test_tsconfig_resolver { CodeParser }
    code_review_graph.tools.query --> tests.test_tsconfig_resolver { query_graph }
    code_review_graph.tsconfig_resolver --> tests.test_tsconfig_resolver { TsconfigResolver }
    code_review_graph.parser --> tests.test_typed_receiver_calls { CodeParser }
    code_review_graph.changes --> tests.test_typescript_declaration_gaps { analyze_changes }
    code_review_graph.graph --> tests.test_typescript_declaration_gaps { GraphStore }
    code_review_graph.incremental --> tests.test_typescript_declaration_gaps {
        full_build,
        get_db_path,
        incremental_update,
    }
    code_review_graph.parser --> tests.test_typescript_declaration_gaps { CodeParser, NodeInfo }
    code_review_graph.tools.review --> tests.test_typescript_declaration_gaps {
        detect_changes_func,
    }
    code_review_graph.graph --> tests.test_typescript_duplicate_method_identity { GraphStore }
    code_review_graph.parser --> tests.test_typescript_duplicate_method_identity {
        CodeParser,
        EdgeInfo,
        NodeInfo,
    }
    code_review_graph.graph --> tests.test_typescript_node_extensions { GraphStore }
    code_review_graph.incremental --> tests.test_typescript_node_extensions { full_build }
    code_review_graph.tools.query --> tests.test_typescript_node_extensions { query_graph }
    code_review_graph.tools.review --> tests.test_typescript_node_extensions { get_review_context }
    code_review_graph.graph --> tests.test_unbound_call_targets { GraphStore }
    code_review_graph.incremental --> tests.test_unbound_call_targets {
        full_build,
        get_db_path,
        incremental_update,
    }
    code_review_graph.parser --> tests.test_unbound_call_targets { EdgeInfo, NodeInfo }
    code_review_graph.refactor --> tests.test_unbound_call_targets {
        find_dead_code,
        rename_preview,
    }
    code_review_graph.tools --> tests.test_unbound_call_targets { query_graph }
    code_review_graph.tools.build --> tests.test_unbound_call_targets { build_or_update_graph }
    code_review_graph.uncertainty --> tests.test_unbound_call_targets { MAX_CONFIDENCE_CHARS }
    code_review_graph.uncertainty --> tests.test_uncertainty;
    code_review_graph.uncertainty --> tests.test_uncertainty {
        LANGUAGE_GAPS,
        MAX_CONFIDENCE_CHARS,
        empty_query_confidence,
        gap_note,
    }
    code_review_graph.graph --> tests.test_uncertainty { GraphStore }
    code_review_graph.parser --> tests.test_uncertainty { CodeParser, EdgeInfo, NodeInfo }
    code_review_graph.tools.query --> tests.test_uncertainty {
        get_impact_radius,
        query_graph,
        semantic_search_nodes,
    }
    code_review_graph.skills --> tests.test_uninstall;
    code_review_graph.uninstall --> tests.test_uninstall;
    code_review_graph.cli --> tests.test_uninstall;
    code_review_graph.codex_skill --> tests.test_uninstall;
    code_review_graph.codex_skill --> tests.test_uninstall { install_codex_skill }
    code_review_graph.skills --> tests.test_uninstall_strict_json;
    code_review_graph.uninstall --> tests.test_uninstall_strict_json;
    code_review_graph.cli --> tests.test_uninstall_strict_json;
    code_review_graph.jsonc --> tests.test_uninstall_strict_json;
    code_review_graph.errors --> tests.test_unknown_review_base { ChangeDiscoveryError }
    code_review_graph.graph --> tests.test_unknown_review_base { GraphStore }
    code_review_graph.incremental --> tests.test_unknown_review_base {
        NO_COMMIT_NOTE,
        ONE_COMMIT_NOTE,
        SHALLOW_CLONE_NOTE,
        discover_review_changes,
        full_build,
    }
    code_review_graph.tools.review --> tests.test_unknown_review_base { detect_changes_func }
    code_review_graph.cli --> tests.test_unmatched_risk;
    code_review_graph.graph --> tests.test_unmatched_risk { GraphStore }
    code_review_graph.incremental --> tests.test_unmatched_risk {
        full_build,
        get_db_path,
        incremental_update,
    }
    code_review_graph.parser --> tests.test_unmatched_risk { EdgeInfo, NodeInfo }
    code_review_graph.tools.query --> tests.test_unmatched_risk;
    code_review_graph.tools.review --> tests.test_unmatched_risk;
    code_review_graph.tools._common --> tests.test_unmatched_risk {
        _resolve_graph_file_paths,
        _unmatched_file_warning,
    }
    code_review_graph.migrations --> tests.test_unread_tables_removed;
    code_review_graph.migrations --> tests.test_unread_tables_removed {
        LATEST_VERSION,
        get_schema_version,
    }
    code_review_graph.graph --> tests.test_unread_tables_removed { GraphStore }
    code_review_graph.parser --> tests.test_unread_tables_removed { EdgeInfo, NodeInfo }
    code_review_graph.tools --> tests.test_unread_tables_removed { run_postprocess }
    code_review_graph.graph --> tests.test_untyped_receiver_method_calls { GraphStore }
    code_review_graph.incremental --> tests.test_untyped_receiver_method_calls { get_db_path }
    code_review_graph.tools.build --> tests.test_untyped_receiver_method_calls {
        build_or_update_graph,
    }
    code_review_graph.tools.build --> tests.test_update_brief_base { build_or_update_graph }
    code_review_graph.cli --> tests.test_update_brief_base;
    code_review_graph.skills --> tests.test_update_in_a_graph_only_project;
    code_review_graph.graph --> tests.test_update_io { GraphStore }
    code_review_graph.incremental --> tests.test_update_io {
        full_build,
        get_db_path,
        incremental_update,
    }
    code_review_graph.migrations --> tests.test_upgrade_path { LATEST_VERSION }
    code_review_graph.tools.community_tools --> tests.test_upgrade_path {
        get_architecture_overview_func,
        list_communities_func,
    }
    code_review_graph.tools.context --> tests.test_upgrade_path { get_minimal_context }
    code_review_graph.tools.query --> tests.test_upgrade_path {
        get_impact_radius,
        list_graph_stats,
        query_graph,
        semantic_search_nodes,
        traverse_graph_func,
    }
    code_review_graph.tools.refactor_tools --> tests.test_upgrade_path { refactor_func }
    code_review_graph.tools.review --> tests.test_upgrade_path {
        get_affected_flows_func,
        get_review_context,
    }
    code_review_graph.graph --> tests.test_upgrade_path { GraphStore }
    code_review_graph.incremental --> tests.test_upgrade_path { get_db_path }
    code_review_graph.tools.review --> tests.test_utf8_encoding;
    code_review_graph.tools.flows_tools --> tests.test_utf8_encoding;
    code_review_graph.eval.runner --> tests.test_utf8_encoding;
    code_review_graph.eval.reporter --> tests.test_utf8_encoding;
    code_review_graph.graph --> tests.test_visualization { GraphStore }
    code_review_graph.parser --> tests.test_visualization { EdgeInfo, NodeInfo }
    code_review_graph.visualization --> tests.test_visualization {
        DEFAULT_MAX_FULL_EDGES,
        DEFAULT_MAX_FULL_NODES,
        _aggregate_community,
        _aggregate_file,
        _resolve_auto_mode,
        export_graph_data,
        generate_html,
    }
    code_review_graph.exports --> tests.test_visualization;
    code_review_graph.exports --> tests.test_visualization {
        _obsidian_slug,
        _obsidian_slugs,
        export_json,
    }
    code_review_graph.graph --> tests.test_visualization_browser { GraphStore }
    code_review_graph.parser --> tests.test_visualization_browser { EdgeInfo, NodeInfo }
    code_review_graph.visualization --> tests.test_visualization_browser { generate_html }
    code_review_graph.incremental --> tests.test_watch_debouncer_wakeup;
    code_review_graph.graph --> tests.test_watch_ignore_refresh { GraphStore }
    code_review_graph.incremental --> tests.test_watch_ignore_refresh {
        _create_watch_handler,
        _load_ignore_patterns,
        _should_ignore,
        clear_nested_ignore_cache,
        incremental_update,
    }
    code_review_graph.parser --> tests.test_watch_ignore_refresh { CodeParser }
    code_review_graph.incremental --> tests.test_watch_promotion;
    code_review_graph.incremental --> tests.test_watch_promotion {
        _WatchSupervisor,
        _load_ignore_patterns,
    }
    tests.test_watch_robustness --> tests.test_watch_promotion { FakeObserver }
    code_review_graph.embeddings --> tests.test_watch_refresh_without_index {
        REFRESH_SKIPPED_WARNING,
    }
    code_review_graph.graph --> tests.test_watch_refresh_without_index { GraphStore }
    code_review_graph.incremental --> tests.test_watch_refresh_without_index {
        _create_watch_handler,
        _raise_watch_postprocess_warnings,
        incremental_update,
        watch,
    }
    code_review_graph.postprocessing --> tests.test_watch_refresh_without_index {
        run_post_processing,
    }
    code_review_graph.incremental --> tests.test_watch_replan_preservation;
    code_review_graph.incremental --> tests.test_watch_replan_preservation {
        _WatchSupervisor,
        _create_watch_handler,
        _load_ignore_patterns,
    }
    tests.test_watch_robustness --> tests.test_watch_replan_preservation { FakeObserver }
    code_review_graph.graph --> tests.test_watch_replan_preservation { GraphStore }
    code_review_graph.graph --> tests.test_watch_rule_coverage { GraphStore }
    code_review_graph.incremental --> tests.test_watch_rule_coverage {
        _WATCH_SPLIT_MIN_DIRS,
        _WatchSupervisor,
        _create_watch_handler,
        _load_ignore_patterns,
        _sync_watch_tree,
        clear_nested_ignore_cache,
    }
    tests.test_watch_robustness --> tests.test_watch_rule_coverage { FakeObserver }
    code_review_graph.incremental --> tests.test_watch_startup_serialization;
    code_review_graph.graph --> tests.test_watch_startup_serialization { GraphStore }
    code_review_graph.postprocessing --> tests.test_watch_startup_serialization {
        run_post_processing,
    }
    tests.test_watch_robustness --> tests.test_watch_startup_serialization { FakeObserver }
    code_review_graph.communities --> tests.test_wiki {
        detect_communities,
        get_communities,
        store_communities,
    }
    code_review_graph.graph --> tests.test_wiki { GraphStore }
    code_review_graph.parser --> tests.test_wiki { EdgeInfo, NodeInfo }
    code_review_graph.wiki --> tests.test_wiki;
    code_review_graph.wiki --> tests.test_wiki {
        _generate_community_page,
        _slugify,
        generate_wiki,
        get_wiki_page,
    }
    code_review_graph.graph --> tests.test_windows_path_identity { GraphStore }
    code_review_graph.incremental --> tests.test_windows_path_identity { _reconcile_stale_files }
    code_review_graph.parser --> tests.test_windows_path_identity {
        CodeParser,
        EdgeInfo,
        NodeInfo,
        normalize_file_path,
    }
    code_review_graph.graph --> tests.test_workspace_package_imports { GraphStore }
    code_review_graph.parser --> tests.test_workspace_package_imports { CodeParser }
    code_review_graph.incremental --> tests.test_workspace_package_imports { full_build }
    code_review_graph.tools.query --> tests.test_workspace_package_imports {
        get_impact_radius,
        query_graph,
    }
    code_review_graph.workspace_resolver --> tests.test_workspace_resolver;
    code_review_graph.workspace_resolver --> tests.test_workspace_resolver { WorkspaceResolver }
    code_review_graph.cli --> tests.test_write_lock;
    code_review_graph.graph --> tests.test_write_lock { CorruptGraphDatabaseError }
    code_review_graph.locking --> tests.test_write_lock { WriteLock }
    code_review_graph.tools.build --> tests.test_write_lock {
        build_or_update_graph,
        run_postprocess,
    }
    code_review_graph.cli --> tests.test_write_lock_all_writers;
    code_review_graph.incremental --> tests.test_write_lock_all_writers;
    code_review_graph.graph --> tests.test_write_lock_all_writers { GraphStore }
    code_review_graph.locking --> tests.test_write_lock_all_writers { WriteLock }
    code_review_graph.migrations --> tests.test_write_lock_all_writers { LATEST_VERSION }
    code_review_graph.tools.docs --> tests.test_write_lock_all_writers;
    tests.test_watch_robustness --> tests.test_write_lock_all_writers { FakeObserver }
    code_review_graph.locking --> tests.test_write_lock_failure_modes { WriteLock }
    code_review_graph.graph --> tests.test_xslt_parser { GraphStore }
    code_review_graph.incremental --> tests.test_xslt_parser { full_build, get_db_path }
    code_review_graph.parser --> tests.test_xslt_parser { CodeParser, normalize_file_path }
    code_review_graph.postprocessing --> tests.test_xslt_parser { run_post_processing }
    code_review_graph.refactor --> tests.test_xslt_parser { find_dead_code }
    code_review_graph.tools.query --> tests.test_xslt_parser { query_graph, semantic_search_nodes }
    code_review_graph.embeddings --> tests.test_yaml_locale_files;
    code_review_graph.graph --> tests.test_yaml_locale_files { GraphStore, node_to_dict }
    code_review_graph.incremental --> tests.test_yaml_locale_files {
        full_build,
        get_db_path,
        incremental_update,
    }
    code_review_graph.parser --> tests.test_yaml_locale_files { CodeParser, NodeInfo }
    code_review_graph.search --> tests.test_yaml_locale_files {
        _embedding_search,
        _fts_search,
        _keyword_search,
        hybrid_search,
        rebuild_fts_index,
    }
    code_review_graph.parser --> tests.test_yaml_parser;
    code_review_graph.parser --> tests.test_yaml_parser { CodeParser }
    code_review_graph.graph --> tests.test_yaml_parser { GraphStore }
    code_review_graph.incremental --> tests.test_yaml_parser { full_build }
    code_review_graph.tools.query --> tests.test_yaml_parser { query_graph }
    code_review_graph.install_plan as install_plan ++> code_review_graph.codex_skill;
    code_review_graph.install_plan as install_plan ++> code_review_graph.install_manifest;
    code_review_graph.constants ++> code_review_graph.context_history { read_only_requested }
    code_review_graph.context_history ++> code_review_graph.context_savings {
        CallInfo,
        record_call,
    }
    include code_review_graph.context_savings ++> code_review_graph {
        attach_context_savings,
        estimate_context_savings,
        estimate_file_tokens,
        estimate_tokens,
        format_context_savings,
    }
    code_review_graph.constants ++> code_review_graph.registry { crg_home }
    code_review_graph.codex_skill as codex_skill ++> code_review_graph.install_gitignore;
    code_review_graph.skills as skills ++> code_review_graph.install_gitignore;
    code_review_graph.install_plan as planned_files ++> code_review_graph.install_gitignore;
    code_review_graph.install_plan as install_plan ++> code_review_graph.skills;
    code_review_graph.jsonc as jsonc ++> code_review_graph.skills;
    code_review_graph._legacy_instructions ++> code_review_graph.skills {
        LEGACY_INSTRUCTION_SECTIONS,
    }
    code_review_graph.codex_skill ++> code_review_graph.skills {
        codex_home,
        install_codex_skill as _install,
    }
    code_review_graph.tsconfig_resolver ++> code_review_graph.workspace_resolver {
        _PROBE_EXTENSIONS,
    }
    code_review_graph.workspace_resolver ++> code_review_graph.npm_alias_resolver {
        WorkspaceResolver,
    }
    code_review_graph.stdio ++> code_review_graph.daemon_cli { configure_utf8_stdio }
    code_review_graph.daemon ++> code_review_graph.daemon_cli {
        DaemonAlreadyRunningError,
        WatchDaemon,
        claim_daemon_lock,
        is_daemon_running,
        load_config,
        reap_orphaned_watchers,
        write_pid,
        clear_pid,
        pid_alive,
        read_pid,
        find_orphaned_watchers,
        load_state,
        read_watch_health,
        watcher_status,
        add_repo_to_config,
        remove_repo_from_config,
    }
    code_review_graph.constants ++> code_review_graph.daemon {
        crg_home,
        env_float,
        release_os_memory,
    }
    code_review_graph.registry ++> code_review_graph.daemon { Registry }
    code_review_graph.parser ++> code_review_graph.aop_resolver { EdgeInfo }
    code_review_graph.constants ++> code_review_graph.communities { env_int }
    code_review_graph.graph ++> code_review_graph.communities {
        GraphEdge,
        GraphNode,
        GraphStore,
        _sanitize_name,
    }
    code_review_graph.flows ++> code_review_graph.communities { expand_changed_file_paths }
    code_review_graph ++> code_review_graph.embeddings { __version__ as _crg_version }
    code_review_graph.constants ++> code_review_graph.embeddings { release_os_memory }
    code_review_graph.graph ++> code_review_graph.embeddings { GraphNode, GraphStore, node_to_dict }
    code_review_graph.parser ++> code_review_graph.event_resolver { EdgeInfo, NodeInfo }
    code_review_graph.constants ++> code_review_graph.flows {
        SECURITY_KEYWORDS as _SECURITY_KEYWORDS,
    }
    code_review_graph.graph ++> code_review_graph.flows {
        FlowAdjacency,
        GraphNode,
        GraphStore,
        _sanitize_name,
    }
    code_review_graph.parser ++> code_review_graph.flows {
        is_test_file as _is_test_file,
        normalize_file_path,
    }
    code_review_graph.constants ++> code_review_graph.graph {
        BFS_ENGINE,
        CALLER_TEST_ROUTE_DEPTH,
        CALLER_TEST_ROUTE_MAX_CALLERS,
        CLAIMED_ENDPOINT_KEY,
        IMPACT_DEFAULT_EDGE_DIRECTION,
        IMPACT_DEFAULT_EDGE_WEIGHT,
        IMPACT_DEPTH_DECAY,
        IMPACT_DIRECTION_INCOMING,
        IMPACT_DIRECTION_NONE,
        IMPACT_DIRECTION_OUTGOING,
        IMPACT_EDGE_DIRECTIONS,
        IMPACT_EDGE_WEIGHTS,
        IMPACT_SCORE_FLOOR,
        IMPORT_SCOPE_KEY,
        IMPORT_SCOPE_PACKAGE,
        IMPORT_SCOPE_TREE,
        INHERITED_ENDPOINT_KEY,
        INHERITED_THROUGH_KEY,
        MAX_IMPACT_DEPTH,
        MAX_IMPACT_NODES,
        env_int,
        normalize_file_path,
        read_only_requested,
        release_os_memory,
    }
    code_review_graph.errors ++> code_review_graph.graph { GraphStoreError, is_lock_error }
    code_review_graph.inheritance ++> code_review_graph.graph { InheritanceIndex }
    code_review_graph.migrations ++> code_review_graph.graph {
        LATEST_VERSION,
        TARGET_RESOLUTION_EXPR,
        TARGET_RESOLUTION_KINDS,
        get_schema_version,
        run_migrations,
        target_resolution_expr,
    }
    code_review_graph ++> code_review_graph.graph { __version__ }
    code_review_graph.parser ++> code_review_graph.graph { EdgeInfo, is_test_file }
    code_review_graph.constants ++> code_review_graph.hcl_resolver { CLAIMED_ENDPOINT_KEY }
    code_review_graph.install_plan as install_plan ++> code_review_graph.incremental;
    code_review_graph.build_state ++> code_review_graph.incremental {
        advance_to_postprocess_pending,
    }
    code_review_graph.constants ++> code_review_graph.incremental {
        GIT_TIMEOUT as _GIT_TIMEOUT,
        discovery_timeout,
        env_float,
        env_int,
        normalize_file_path,
        read_only_requested,
    }
    code_review_graph.csharp_resolver ++> code_review_graph.incremental {
        restore_csharp_references,
    }
    code_review_graph.errors ++> code_review_graph.incremental {
        ChangeDiscoveryError,
        GraphRootMismatchError,
        GraphStoreError,
    }
    code_review_graph.graph ++> code_review_graph.incremental { GraphStore }
    code_review_graph.locking ++> code_review_graph.incremental { WriteLock, write_lock_path }
    code_review_graph.parser ++> code_review_graph.incremental { CodeParser }
    code_review_graph.python_resolver ++> code_review_graph.incremental { resolve_python_imports }
    code_review_graph.rescript_resolver ++> code_review_graph.incremental {
        resolve_rescript_cross_module,
    }
    code_review_graph.spring_resolver ++> code_review_graph.incremental { resolve_spring_di_calls }
    code_review_graph.aop_resolver ++> code_review_graph.incremental { resolve_aop_advice }
    code_review_graph.event_resolver ++> code_review_graph.incremental { resolve_spring_events }
    code_review_graph.temporal_resolver ++> code_review_graph.incremental { resolve_temporal_calls }
    code_review_graph.hcl_resolver ++> code_review_graph.incremental {
        resolve_hcl_module_references,
    }
    code_review_graph.scoped_resolver ++> code_review_graph.incremental { resolve_scoped_calls }
    code_review_graph.jedi_resolver ++> code_review_graph.incremental { enrich_jedi_calls }
    code_review_graph.registry ++> code_review_graph.incremental { Registry, default_registry_path }
    code_review_graph.communities ++> code_review_graph.incremental {
        capture_community_assignments,
        purge_empty_communities,
        remap_community_assignments,
    }
    code_review_graph.flows ++> code_review_graph.incremental {
        capture_affected_flow_entry_points,
        capture_flow_node_ids,
        clear_flows_for_files,
        expand_changed_file_paths,
        purge_orphan_flow_data,
        remap_flow_node_ids,
    }
    code_review_graph.embeddings ++> code_review_graph.incremental { REFRESH_SKIPPED_WARNING }
    code_review_graph.daemon ++> code_review_graph.incremental { watch_health_path }
    code_review_graph.parser ++> code_review_graph.jedi_resolver {
        CodeParser,
        EdgeInfo,
        normalize_file_path,
        _is_test_file as _parser_is_test_file,
    }
    code_review_graph.graph ++> code_review_graph.jedi_resolver { GraphEdge }
    code_review_graph.graph ++> code_review_graph.migrations { node_index_tokens }
    code_review_graph.config_keys ++> code_review_graph.parser {
        is_spring_config_path,
        normalize_spring_config_key,
    }
    code_review_graph.constants ++> code_review_graph.parser {
        IMPORT_CONTEXT_DEFERRED,
        IMPORT_CONTEXT_KEY,
        IMPORT_CONTEXT_PARENT_PACKAGE,
        IMPORT_CONTEXT_TYPE_ONLY,
        IMPORT_SCOPE_KEY,
        IMPORT_SCOPE_PACKAGE,
        IMPORT_SCOPE_TREE,
        normalize_file_path,
        release_os_memory,
    }
    code_review_graph.custom_languages ++> code_review_graph.parser { load_custom_languages }
    code_review_graph.npm_alias_resolver ++> code_review_graph.parser { NpmAliasResolver }
    code_review_graph.tsconfig_resolver ++> code_review_graph.parser { TsconfigResolver }
    code_review_graph.workspace_resolver ++> code_review_graph.parser { WorkspaceResolver }
    code_review_graph.incremental ++> code_review_graph.parser {
        _should_ignore,
        _load_ignore_patterns,
    }
    code_review_graph.csharp_resolver ++> code_review_graph.scoped_resolver { resolve_csharp_calls }
    code_review_graph.constants ++> code_review_graph.changes {
        GIT_TIMEOUT as _GIT_TIMEOUT,
        SECURITY_KEYWORDS as _SECURITY_KEYWORDS,
        env_float,
        env_int,
    }
    code_review_graph.errors ++> code_review_graph.changes { ChangeDiscoveryError }
    code_review_graph.flows ++> code_review_graph.changes {
        _trace_single_flow,
        detect_entry_points,
        get_affected_flows,
    }
    code_review_graph.graph ++> code_review_graph.changes {
        GraphEdge,
        GraphNode,
        GraphStore,
        _sanitize_name,
        node_to_dict,
        qualified_name_of,
    }
    code_review_graph.parser ++> code_review_graph.changes {
        CodeParser,
        NodeInfo,
        _repo_relative_path,
        is_test_file,
        normalize_file_path,
    }
    code_review_graph.communities as communities ++> code_review_graph.change_details;
    code_review_graph.changes ++> code_review_graph.change_details { risk_signals }
    code_review_graph.constants ++> code_review_graph.change_details { MAX_IMPACT_DEPTH }
    code_review_graph.graph ++> code_review_graph.change_details {
        GraphEdge,
        GraphNode,
        GraphStore,
        _sanitize_name,
    }
    code_review_graph ++> code_review_graph.change_details { __version__ }
    code_review_graph ++> code_review_graph.doctor { __version__ }
    code_review_graph.skills ++> code_review_graph.doctor { _strip_jsonc, PLATFORMS, _codex_home }
    code_review_graph.incremental ++> code_review_graph.doctor { files_hold_commits, get_db_path }
    code_review_graph.parser ++> code_review_graph.doctor { normalize_file_path }
    code_review_graph.build_state ++> code_review_graph.doctor {
        BUILD_STATE_KEY,
        INCOMPLETE_BUILD_STATES,
    }
    code_review_graph.migrations ++> code_review_graph.doctor { LATEST_VERSION, get_schema_version }
    code_review_graph.graph ++> code_review_graph.search {
        GraphStore,
        _sanitize_name,
        identifier_words,
    }
    code_review_graph.migrations ++> code_review_graph.search {
        FTS_STATE_METADATA_KEY,
        FTS_STATE_VERSION,
        NODES_FTS_COLUMNS,
        NODES_FTS_DDL,
        NODES_FTS_STATE_TABLE,
        ensure_nodes_fts_state,
    }
    code_review_graph.parser ++> code_review_graph.search { is_test_file, normalize_file_path }
    code_review_graph.embeddings ++> code_review_graph.search { EmbeddingStore }
    code_review_graph.errors ++> code_review_graph.enrich { GraphStoreError }
    code_review_graph.graph ++> code_review_graph.enrich { GraphNode, GraphStore }
    code_review_graph.search ++> code_review_graph.enrich { _fts_search }
    code_review_graph.incremental ++> code_review_graph.enrich { find_project_root, get_db_path }
    code_review_graph.graph ++> code_review_graph.token_benchmark { GraphStore }
    code_review_graph.search ++> code_review_graph.token_benchmark { hybrid_search }
    code_review_graph.parser ++> code_review_graph.eval.benchmarks.agent_baseline { is_test_file }
    code_review_graph.token_benchmark ++> code_review_graph.eval.benchmarks.agent_baseline {
        estimate_tokens,
    }
    code_review_graph.search ++> code_review_graph.eval.benchmarks.agent_baseline {
        extract_query_identifiers,
        hybrid_search,
    }
    code_review_graph.flows ++> code_review_graph.eval.benchmarks.build_performance {
        store_flows,
        trace_flows,
    }
    code_review_graph.communities ++> code_review_graph.eval.benchmarks.build_performance {
        detect_communities,
        store_communities,
    }
    code_review_graph.flows ++> code_review_graph.eval.benchmarks.flow_completeness {
        store_flows,
        trace_flows,
    }
    code_review_graph.parser ++> code_review_graph.eval.benchmarks.impact_accuracy {
        normalize_file_path,
    }
    code_review_graph.changes ++> code_review_graph.eval.benchmarks.impact_accuracy {
        analyze_changes,
    }
    code_review_graph.graph ++> code_review_graph.graph_diff { GraphStore }
    code_review_graph.graph ++> code_review_graph.tools._common {
        GraphStore,
        _sanitize_name,
        CorruptGraphDatabaseError,
        discard_corrupt_database,
    }
    code_review_graph.incremental ++> code_review_graph.tools._common {
        find_project_root,
        get_db_path,
        assert_graph_serves_root,
    }
    code_review_graph.parser ++> code_review_graph.tools._common { normalize_file_path }
    code_review_graph.build_state ++> code_review_graph.tools.build {
        BUILD_COMPLETE,
        BUILD_IN_PROGRESS,
        BUILD_STATE_KEY,
        INCOMPLETE_BUILD_STATES,
        POSTPROCESS_PENDING,
        advance_to_postprocess_pending,
        graph_contents_are_complete,
        read_build_state,
    }
    code_review_graph.constants ++> code_review_graph.tools.build { normalize_file_path }
    code_review_graph.incremental ++> code_review_graph.tools.build {
        VERIFIED_FILE_COUNT_KEY,
        _prepare_db_path,
        collect_all_files,
        detect_vcs,
        full_build,
        get_all_tracked_files,
        get_db_path,
        incremental_update,
        resolve_incremental_base,
    }
    code_review_graph.locking ++> code_review_graph.tools.build { WriteLock, write_lock_path }
    code_review_graph.tools._common ++> code_review_graph.tools.build { _get_store, _resolve_root }
    code_review_graph.embeddings ++> code_review_graph.tools.build {
        refresh_embeddings,
        REFRESH_SKIPPED_WARNING,
        has_embeddings,
    }
    code_review_graph.search ++> code_review_graph.tools.build {
        rebuild_fts_index,
        update_fts_index,
    }
    code_review_graph.flows ++> code_review_graph.tools.build {
        incremental_trace_flows,
        store_flows as _store_flows,
        trace_flows as _trace_flows,
    }
    code_review_graph.communities ++> code_review_graph.tools.build {
        incremental_detect_communities,
        detect_communities as _detect_communities,
        store_communities as _store_communities,
    }
    code_review_graph.graph ++> code_review_graph.eval.benchmarks.incremental_fidelity {
        GraphStore,
        _sanitize_name,
    }
    code_review_graph.incremental ++> code_review_graph.eval.benchmarks.incremental_fidelity {
        full_build,
        incremental_update,
    }
    code_review_graph.tools.build ++> code_review_graph.eval.benchmarks.incremental_fidelity {
        _run_postprocess,
    }
    code_review_graph.graph_diff ++> code_review_graph.eval.benchmarks.incremental_fidelity {
        diff_snapshots,
        take_snapshot,
    }
    code_review_graph.constants ++> code_review_graph.uncertainty { GIT_TIMEOUT }
    code_review_graph.graph ++> code_review_graph.uncertainty { _sanitize_name }
    code_review_graph.incremental ++> code_review_graph.uncertainty {
        _load_ignore_patterns,
        _should_ignore,
    }
    code_review_graph.parser ++> code_review_graph.uncertainty { normalize_file_path }
    code_review_graph.tools._common ++> code_review_graph.uncertainty { _read_live_git_head }
    code_review_graph.config_keys ++> code_review_graph.tools.query { normalize_spring_config_key }
    code_review_graph.constants ++> code_review_graph.tools.query {
        IMPORT_CONTEXT_KEY,
        IMPORT_CONTEXT_TYPE_ONLY,
        IMPORT_SCOPE_KEY,
        MAX_IMPACT_NODES,
        QUERY_PATTERNS,
    }
    code_review_graph.context_history ++> code_review_graph.tools.query { CallInfo }
    code_review_graph.context_savings ++> code_review_graph.tools.query {
        attach_context_savings,
        estimate_file_tokens,
    }
    code_review_graph.embeddings ++> code_review_graph.tools.query { EmbeddingStore }
    code_review_graph.errors ++> code_review_graph.tools.query { ChangeDiscoveryError }
    code_review_graph.graph ++> code_review_graph.tools.query {
        IMPACT_RESOLUTIONS,
        QUERY_RESOLUTIONS,
        RESOLUTION_ALL,
        RESOLUTION_DIRECT,
        RESOLUTION_UNRESOLVED,
        GraphEdge,
        GraphNode,
        GraphStore,
        _compatible_edge_languages,
        _sanitize_name,
        edge_to_dict,
        import_scope_ancestors,
        node_to_dict,
    }
    code_review_graph.hints ++> code_review_graph.tools.query { generate_hints, get_session }
    code_review_graph.incremental ++> code_review_graph.tools.query {
        discover_review_changes,
        followed_files,
        get_db_path,
        path_within_repo,
    }
    code_review_graph.parser ++> code_review_graph.tools.query {
        is_test_file,
        normalize_file_path,
        repo_relative_path,
    }
    code_review_graph.search ++> code_review_graph.tools.query { hybrid_search }
    code_review_graph.uncertainty ++> code_review_graph.tools.query {
        empty_impact_confidence,
        empty_query_confidence,
        empty_search_confidence,
        guessed_calls_confidence,
    }
    code_review_graph.tools._common ++> code_review_graph.tools.query {
        _BUILTIN_CALL_NAMES,
        _bounded,
        _error_response,
        _get_store,
        _resolve_graph_file_paths,
        _resolve_graph_file_paths_with_unmatched,
        _shown_of,
        _unmatched_file_warning,
        _validate_positive_int,
    }
    code_review_graph.search ++> code_review_graph.eval.benchmarks.multi_hop_retrieval {
        hybrid_search,
    }
    code_review_graph.tools.query ++> code_review_graph.eval.benchmarks.multi_hop_retrieval {
        query_graph,
    }
    code_review_graph.search ++> code_review_graph.eval.benchmarks.search_quality { hybrid_search }
    code_review_graph.changes ++> code_review_graph.tools.review {
        DiffRanges,
        analyze_changes,
        compute_risk_score,
        is_test_gap_exempt,
        parse_diff_ranges,
    }
    code_review_graph.context_history ++> code_review_graph.tools.review { CallInfo }
    code_review_graph.context_savings ++> code_review_graph.tools.review {
        attach_context_savings,
        estimate_file_tokens,
    }
    code_review_graph.errors ++> code_review_graph.tools.review { ChangeDiscoveryError }
    code_review_graph.flows ++> code_review_graph.tools.review {
        get_affected_flows as _get_affected_flows,
    }
    code_review_graph.graph ++> code_review_graph.tools.review {
        GraphNode,
        edge_to_dict,
        node_to_dict,
    }
    code_review_graph.hints ++> code_review_graph.tools.review { generate_hints, get_session }
    code_review_graph.incremental ++> code_review_graph.tools.review {
        discover_review_changes,
        followed_files,
        path_within_repo,
        resolve_review_base,
    }
    code_review_graph.parser ++> code_review_graph.tools.review {
        is_test_file,
        normalize_file_path,
    }
    code_review_graph.tools._common ++> code_review_graph.tools.review {
        _bounded,
        _error_response,
        _get_store,
        _resolve_graph_file_paths_with_unmatched,
        _shown_of,
        _unmatched_file_warning,
        _validate_positive_int,
    }
    code_review_graph.tools.review ++> code_review_graph.eval.benchmarks.token_efficiency {
        get_review_context,
    }
    code_review_graph.graph ++> code_review_graph.postprocessing { GraphStore }
    code_review_graph.search ++> code_review_graph.postprocessing { update_fts_index }
    code_review_graph.flows ++> code_review_graph.postprocessing { store_flows, trace_flows }
    code_review_graph.communities ++> code_review_graph.postprocessing {
        detect_communities,
        store_communities,
    }
    code_review_graph.embeddings ++> code_review_graph.postprocessing {
        REFRESH_SKIPPED_WARNING,
        refresh_embeddings,
    }
    code_review_graph.eval.benchmarks.agent_baseline as agent_baseline ++> code_review_graph.eval.runner;
    code_review_graph.eval.benchmarks.build_performance as build_performance ++> code_review_graph.eval.runner;
    code_review_graph.eval.benchmarks.flow_completeness as flow_completeness ++> code_review_graph.eval.runner;
    code_review_graph.eval.benchmarks.impact_accuracy as impact_accuracy ++> code_review_graph.eval.runner;
    code_review_graph.eval.benchmarks.incremental_fidelity as incremental_fidelity ++> code_review_graph.eval.runner;
    code_review_graph.eval.benchmarks.multi_hop_retrieval as multi_hop_retrieval ++> code_review_graph.eval.runner;
    code_review_graph.eval.benchmarks.search_quality as search_quality ++> code_review_graph.eval.runner;
    code_review_graph.eval.benchmarks.token_efficiency as token_efficiency ++> code_review_graph.eval.runner;
    code_review_graph.embeddings ++> code_review_graph.eval.runner {
        EmbeddingStore,
        embed_all_nodes,
    }
    code_review_graph.graph ++> code_review_graph.eval.runner { GraphStore }
    code_review_graph.incremental ++> code_review_graph.eval.runner { full_build, get_db_path }
    code_review_graph.postprocessing ++> code_review_graph.eval.runner { run_post_processing }
    code_review_graph.graph ++> code_review_graph.neighbourhood { _sanitize_name as _impl }
    code_review_graph.graph ++> code_review_graph.visualization {
        GraphNode,
        GraphStore,
        _sanitize_name,
        edge_to_dict,
        node_to_dict,
    }
    code_review_graph.neighbourhood ++> code_review_graph.visualization {
        DEFAULT_DEPTH,
        DEFAULT_MAX_NODES,
        STRUCTURAL_EDGE_KINDS,
        NeighbourhoodSpec,
        _parent_files,
        resolve_seeds,
        extract as extract_neighbourhood,
    }
    code_review_graph.parser ++> code_review_graph.visualization { normalize_file_path }
    code_review_graph.flows ++> code_review_graph.visualization { get_flows }
    code_review_graph.communities ++> code_review_graph.visualization { get_communities }
    code_review_graph.graph ++> code_review_graph.exports { GraphStore, _sanitize_name }
    code_review_graph.visualization ++> code_review_graph.exports { export_graph_data }
    code_review_graph.graph ++> code_review_graph.forget { GraphStore }
    code_review_graph.parser ++> code_review_graph.forget { CodeParser }
    code_review_graph.postprocessing ++> code_review_graph.forget { run_post_processing }
    code_review_graph.python_resolver ++> code_review_graph.forget { resolve_python_imports }
    code_review_graph.scoped_resolver ++> code_review_graph.forget { resolve_scoped_calls }
    code_review_graph.incremental ++> code_review_graph.forget {
        _load_followed_dirs,
        _relink_edges,
    }
    code_review_graph ++> code_review_graph.main { __version__ }
    code_review_graph.incremental as _incremental ++> code_review_graph.main;
    code_review_graph.constants ++> code_review_graph.main { MAX_IMPACT_NODES, env_int }
    code_review_graph.graph ++> code_review_graph.main { GraphStore, _sanitize_name }
    code_review_graph.incremental ++> code_review_graph.main {
        find_project_root,
        get_db_path,
        start_watch_thread,
    }
    code_review_graph.registry ++> code_review_graph.main { Registry }
    code_review_graph.postprocessing ++> code_review_graph.main { run_post_processing }
    code_review_graph.embeddings ++> code_review_graph.main { prewarm_local_embeddings }
    code_review_graph.http_origin_guard ++> code_review_graph.main { build_http_middleware }
    code_review_graph.incremental ++> code_review_graph.multi_worktree {
        find_project_root,
        get_db_path,
    }
    code_review_graph.constants ++> code_review_graph.refactor {
        CLAIMED_ENDPOINT_KEY,
        INHERITED_ENDPOINT_KEY,
        INHERITED_THROUGH_KEY,
    }
    code_review_graph.flows ++> code_review_graph.refactor {
        _has_framework_decorator,
        _has_override_decorator,
        _matches_entry_name,
    }
    code_review_graph.graph ++> code_review_graph.refactor {
        GraphNode,
        GraphStore,
        _compatible_edge_languages,
        _sanitize_name,
    }
    code_review_graph.parser ++> code_review_graph.refactor {
        _STORYBOOK_FILE_RE,
        CodeParser,
        normalize_file_path,
        is_test_file as _is_test_file,
        repo_relative_path as _repo_relative,
    }
    code_review_graph.incremental ++> code_review_graph.refactor {
        followed_files,
        path_within_repo,
    }
    code_review_graph.communities ++> code_review_graph.wiki { get_communities }
    code_review_graph.flows ++> code_review_graph.wiki { get_flows }
    code_review_graph.graph ++> code_review_graph.wiki { GraphStore, _sanitize_name }
    code_review_graph.constants ++> code_review_graph.tools.docs { read_only_requested }
    code_review_graph.embeddings ++> code_review_graph.tools.docs {
        EmbeddingStore,
        embed_all_nodes,
    }
    code_review_graph.incremental ++> code_review_graph.tools.docs {
        _prepare_db_path,
        find_project_root,
        get_db_path,
        get_data_dir,
    }
    code_review_graph.tools._common ++> code_review_graph.tools.docs {
        _get_store,
        _resolve_root,
        _validate_positive_int,
        _validate_repo_root,
    }
    code_review_graph.tools.build ++> code_review_graph.tools.docs { _lock_or_skip }
    code_review_graph.wiki ++> code_review_graph.tools.docs { generate_wiki, get_wiki_page }
    code_review_graph.install_gitignore as install_gitignore ++> code_review_graph.uninstall;
    code_review_graph.install_manifest as install_manifest ++> code_review_graph.uninstall;
    code_review_graph.install_plan as install_plan ++> code_review_graph.uninstall;
    code_review_graph.jsonc as jsonc ++> code_review_graph.uninstall;
    code_review_graph.skills as skills ++> code_review_graph.uninstall;
    code_review_graph.codex_skill ++> code_review_graph.uninstall {
        codex_home,
        codex_skill_dir,
        owned_skill_files,
    }
    code_review_graph.incremental ++> code_review_graph.uninstall { find_repo_root }
    code_review_graph.install_manifest as install_manifest ++> code_review_graph.cli;
    code_review_graph.install_plan as install_plan ++> code_review_graph.cli;
    code_review_graph.errors ++> code_review_graph.cli { CodeReviewGraphError, is_lock_error }
    code_review_graph.neighbourhood ++> code_review_graph.cli {
        DEFAULT_DEPTH as NB_DEFAULT_DEPTH,
        DEFAULT_MAX_NODES as NB_DEFAULT_MAX_NODES,
        SeedResolutionError,
    }
    code_review_graph.stdio ++> code_review_graph.cli {
        configure_utf8_stdio as _configure_utf8_stdio,
    }
    code_review_graph ++> code_review_graph.cli { __version__ as fallback_version }
    code_review_graph.skills ++> code_review_graph.cli {
        _CLAUDE_MD_SECTION,
        _CLAUDE_MD_SECTION_MARKER,
        _COPILOT_SECTION,
        _PLATFORM_INSTRUCTION_CUSTOM_SECTIONS,
        _PLATFORM_INSTRUCTION_FILES,
        _upgrade_managed_block,
        instruction_file_wanted,
        install_steering_hook,
        inject_instruction_files,
        selected_platforms,
        PLATFORMS,
        install_platform_configs,
        _git_hooks_dir,
        generate_skills,
        install_codebuddy_hooks,
        install_codebuddy_skills,
        install_codex_hooks,
        install_codex_skill,
        install_cursor_hooks,
        install_gemini_cli_hooks,
        install_gemini_cli_skills,
        install_git_hook,
        install_git_sync_hooks,
        install_hermes_skills,
        install_hooks,
        install_opencode_plugin,
        install_qoder_skills,
    }
    code_review_graph.uninstall ++> code_review_graph.cli {
        remove_steering_hook,
        UninstallReport,
        run as run_uninstall,
    }
    code_review_graph.incremental ++> code_review_graph.cli {
        find_repo_root,
        ensure_repo_gitignore_excludes_crg,
        find_project_root,
        get_data_dir,
        _create_data_dir,
        assert_graph_serves_root,
        get_db_path,
        discover_review_changes,
        _prepare_db_path,
        watch,
        _git_branch_info,
        detect_vcs,
        get_changed_files,
    }
    code_review_graph.install_gitignore ++> code_review_graph.cli { plan as _plan_gitignore }
    code_review_graph.registry ++> code_review_graph.cli { Registry }
    code_review_graph.change_details ++> code_review_graph.cli {
        parse_detail_sections,
        build_change_details,
    }
    code_review_graph.doctor ++> code_review_graph.cli { run_doctor }
    code_review_graph.tools._common ++> code_review_graph.cli { _open_graph_store as open_store }
    code_review_graph.tools.build ++> code_review_graph.cli {
        build_or_update_graph,
        _write_skipped_response,
        _lock_or_skip,
        run_postprocess,
        build_was_interrupted,
    }
    code_review_graph.changes ++> code_review_graph.cli {
        analyze_changes,
        review_churn_counts,
        format_brief,
    }
    code_review_graph.context_history ++> code_review_graph.cli { CallInfo, recorded_as }
    code_review_graph.context_savings ++> code_review_graph.cli {
        attach_context_savings,
        estimate_file_tokens,
        format_context_savings_panel,
        verify_with_tiktoken,
    }
    code_review_graph.locking ++> code_review_graph.cli { WriteLock }
    code_review_graph.graph ++> code_review_graph.cli { GraphStore }
    code_review_graph.forget ++> code_review_graph.cli { forget_files }
    code_review_graph.constants ++> code_review_graph.cli { QUERY_PATTERNS }
    code_review_graph.enrich ++> code_review_graph.cli { run_hook }
    code_review_graph.multi_worktree ++> code_review_graph.cli {
        MultiWorktreeError,
        run_multi_worktree_server,
    }
    code_review_graph.main ++> code_review_graph.cli { main as serve_main }
    code_review_graph.daemon_cli ++> code_review_graph.cli {
        _handle_add,
        _handle_logs,
        _handle_remove,
        _handle_restart,
        _handle_start,
        _handle_status,
        _handle_stop,
    }
    code_review_graph.eval.reporter ++> code_review_graph.cli {
        generate_full_report,
        generate_readme_tables,
    }
    code_review_graph.eval.runner ++> code_review_graph.cli { run_eval }
    code_review_graph.tools.docs ++> code_review_graph.cli { embed_graph }
    code_review_graph.refactor ++> code_review_graph.cli { find_dead_code }
    code_review_graph.build_state ++> code_review_graph.cli { BUILD_IN_PROGRESS, read_build_state }
    code_review_graph.postprocessing ++> code_review_graph.cli { run_post_processing }
    code_review_graph.exports ++> code_review_graph.cli {
        export_json,
        export_graphml,
        export_neo4j_cypher,
        export_obsidian_vault,
        MissingOptionalDependencyError,
        export_svg,
    }
    code_review_graph.visualization ++> code_review_graph.cli { generate_html }
    code_review_graph.wiki ++> code_review_graph.cli { generate_wiki }
    code_review_graph.parser ++> code_review_graph.cli { normalize_file_path }
    code_review_graph.cli ++> code_review_graph.__main__ { main }
    code_review_graph.constants ++> code_review_graph.analysis {
        IMPORT_CONTEXT_DEFERRED,
        IMPORT_CONTEXT_KEY,
        IMPORT_CONTEXT_PARENT_PACKAGE,
        IMPORT_CONTEXT_TYPE_ONLY,
    }
    code_review_graph.graph ++> code_review_graph.analysis { GraphEdge, GraphStore, _sanitize_name }
    code_review_graph.parser ++> code_review_graph.analysis { normalize_file_path }
    include code_review_graph.eval.reporter ++> code_review_graph.eval {
        generate_full_report,
        generate_markdown_report,
        generate_readme_tables,
    }
    include code_review_graph.eval.scorer ++> code_review_graph.eval {
        compute_mrr,
        compute_precision_recall,
        compute_token_efficiency,
    }
    code_review_graph.communities ++> code_review_graph.tools.community_tools {
        get_architecture_overview,
        get_communities,
    }
    code_review_graph.context_history ++> code_review_graph.tools.community_tools { CallInfo }
    code_review_graph.context_savings ++> code_review_graph.tools.community_tools {
        attach_context_savings,
    }
    code_review_graph.graph ++> code_review_graph.tools.community_tools { node_to_dict }
    code_review_graph.hints ++> code_review_graph.tools.community_tools {
        generate_hints,
        get_session,
    }
    code_review_graph.tools._common ++> code_review_graph.tools.community_tools {
        _bounded,
        _get_store,
        _shown_of,
        _validate_positive_int,
    }
    code_review_graph.errors ++> code_review_graph.tools.context { ChangeDiscoveryError }
    code_review_graph.incremental ++> code_review_graph.tools.context {
        discover_review_changes,
        get_db_path,
        graph_holds_commits,
        resolve_review_base,
    }
    code_review_graph.parser ++> code_review_graph.tools.context { normalize_file_path }
    code_review_graph.tools._common ++> code_review_graph.tools.context {
        _get_store,
        _resolve_root,
        compact_response,
        graph_provenance,
    }
    code_review_graph.changes ++> code_review_graph.tools.context { analyze_changes }
    code_review_graph.flows ++> code_review_graph.tools.flows_tools { get_flow_by_id, get_flows }
    code_review_graph.hints ++> code_review_graph.tools.flows_tools { generate_hints, get_session }
    code_review_graph.incremental ++> code_review_graph.tools.flows_tools {
        followed_files,
        path_within_repo,
    }
    code_review_graph.tools._common ++> code_review_graph.tools.flows_tools {
        _bounded,
        _get_store,
        _shown_of,
        _validate_positive_int,
    }
    code_review_graph.tools.context ++> code_review_graph.eval.token_benchmark {
        get_minimal_context,
    }
    code_review_graph.tools.review ++> code_review_graph.eval.token_benchmark {
        detect_changes_func,
    }
    code_review_graph.tools.community_tools ++> code_review_graph.eval.token_benchmark {
        list_communities_func,
    }
    code_review_graph.tools.flows_tools ++> code_review_graph.eval.token_benchmark { list_flows }
    code_review_graph.tools.query ++> code_review_graph.eval.token_benchmark {
        semantic_search_nodes,
        list_graph_stats,
    }
    code_review_graph.incremental ++> code_review_graph.hook_update { get_db_path }
    code_review_graph.tools.build ++> code_review_graph.hook_update { build_or_update_graph }
    code_review_graph.analysis ++> code_review_graph.tools.analysis_tools {
        find_bridge_nodes,
        find_hub_nodes,
        find_knowledge_gaps,
        find_surprising_connections,
        generate_suggested_questions,
    }
    code_review_graph.tools._common ++> code_review_graph.tools.analysis_tools {
        _bounded,
        _get_store,
        _shown_of,
        _validate_positive_int,
    }
    code_review_graph.hints ++> code_review_graph.tools.refactor_tools {
        generate_hints,
        get_session,
    }
    code_review_graph.incremental ++> code_review_graph.tools.refactor_tools { find_project_root }
    code_review_graph.refactor ++> code_review_graph.tools.refactor_tools {
        apply_refactor,
        find_dead_code,
        rename_preview,
        suggest_refactorings,
    }
    code_review_graph.tools._common ++> code_review_graph.tools.refactor_tools {
        _bounded,
        _get_store,
        _shown_of,
        _validate_positive_int,
        _validate_repo_root,
    }
    code_review_graph.graph ++> code_review_graph.tools.registry_tools {
        GraphStore,
        _sanitize_name,
    }
    code_review_graph.incremental ++> code_review_graph.tools.registry_tools { get_db_path }
    code_review_graph.search ++> code_review_graph.tools.registry_tools { hybrid_search }
    code_review_graph.tools._common ++> code_review_graph.tools.registry_tools {
        _bounded,
        _shown_of,
        _validate_positive_int,
    }
    code_review_graph.registry ++> code_review_graph.tools.registry_tools { Registry }
}
