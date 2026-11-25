import from __future__ { annotations }

import importlib;

import from typing { Any }

glob _LAZY_EXPORTS: dict[str, tuple[str, str]] = {
    "parse_diff_ranges": ("..changes", "parse_diff_ranges"),
    "parse_git_diff_ranges": ("..changes", "parse_git_diff_ranges"),
    "parse_svn_diff_ranges": ("..changes", "parse_svn_diff_ranges"),
    "get_changed_files": ("..incremental", "get_changed_files"),
    "get_staged_and_unstaged": ("..incremental", "get_staged_and_unstaged"),
    "_BUILTIN_CALL_NAMES": ("._common", "_BUILTIN_CALL_NAMES"),
    "_get_store": ("._common", "_get_store"),
    "_validate_repo_root": ("._common", "_validate_repo_root"),
    "with_provenance": ("._common", "with_provenance"),
    "get_bridge_nodes_func": (".analysis_tools", "get_bridge_nodes_func"),
    "get_hub_nodes_func": (".analysis_tools", "get_hub_nodes_func"),
    "get_knowledge_gaps_func": (".analysis_tools", "get_knowledge_gaps_func"),
    "get_suggested_questions_func": (".analysis_tools", "get_suggested_questions_func"),
    "get_surprising_connections_func": (".analysis_tools", "get_surprising_connections_func"),
    "build_or_update_graph": (".build", "build_or_update_graph"),
    "run_postprocess": (".build", "run_postprocess"),
    "get_architecture_overview_func": (".community_tools", "get_architecture_overview_func"),
    "get_community_func": (".community_tools", "get_community_func"),
    "list_communities_func": (".community_tools", "list_communities_func"),
    "get_minimal_context": (".context", "get_minimal_context"),
    "embed_graph": (".docs", "embed_graph"),
    "generate_wiki_func": (".docs", "generate_wiki_func"),
    "get_docs_section": (".docs", "get_docs_section"),
    "get_wiki_page_func": (".docs", "get_wiki_page_func"),
    "get_flow": (".flows_tools", "get_flow"),
    "list_flows": (".flows_tools", "list_flows"),
    "find_large_functions": (".query", "find_large_functions"),
    "get_impact_radius": (".query", "get_impact_radius"),
    "list_graph_stats": (".query", "list_graph_stats"),
    "query_graph": (".query", "query_graph"),
    "semantic_search_nodes": (".query", "semantic_search_nodes"),
    "traverse_graph_func": (".query", "traverse_graph_func"),
    "apply_refactor_func": (".refactor_tools", "apply_refactor_func"),
    "refactor_func": (".refactor_tools", "refactor_func"),
    "cross_repo_search_func": (".registry_tools", "cross_repo_search_func"),
    "list_repos_func": (".registry_tools", "list_repos_func"),
    "detect_changes_func": (".review", "detect_changes_func"),
    "get_affected_flows_func": (".review", "get_affected_flows_func"),
    "get_review_context": (".review", "get_review_context"),
};

glob __all__: any = ("_BUILTIN_CALL_NAMES _get_store _validate_repo_root with_provenance build_or_update_graph "
    "run_postprocess get_minimal_context get_architecture_overview_func get_community_func "
    "list_communities_func embed_graph generate_wiki_func get_docs_section get_wiki_page_func "
    "get_flow list_flows find_large_functions get_impact_radius list_graph_stats query_graph "
    "semantic_search_nodes traverse_graph_func apply_refactor_func refactor_func "
    "cross_repo_search_func list_repos_func detect_changes_func get_affected_flows_func "
    "get_review_context get_bridge_nodes_func get_hub_nodes_func get_knowledge_gaps_func "
    "get_suggested_questions_func get_surprising_connections_func parse_diff_ranges "
    "parse_git_diff_ranges parse_svn_diff_ranges get_changed_files get_staged_and_unstaged").split();

def __getattr__(name: str) -> Any {
    target: any = _LAZY_EXPORTS.get(name);
    if target is not None {
        mod_path: any;
        attr: any;
        (mod_path, attr) = target as any;
        mod: any = importlib.import_module(mod_path, __name__);
        val: any = getattr(mod, attr);
        globals()[name] = val;
        return val;
    }
    raise AttributeError(f"module {__name__!r} has no attribute {name!r}");
}
