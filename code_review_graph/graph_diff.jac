import from __future__ { annotations }

import json, logging;

import from pathlib { Path }

import from typing { Any }

glob logger: any = logging.getLogger(__name__);

def take_snapshot(store: GraphStore) -> dict[str, Any] {
    stats: any = store.get_stats();
    nodes: any = store.get_all_nodes(exclude_files=False);
    community_map: any = store.get_all_community_ids();

    return {
        "node_count": stats.total_nodes,
        "edge_count": stats.total_edges,
        "nodes": {
            n.qualified_name: {
                "kind": n.kind,
                "file": n.file_path,
                "community_id": community_map.get(n.qualified_name),
            }
            for n in nodes
        },
        "edges": {
            f"{e.source_qualified}->{e.target_qualified}:{e.kind}"
            for e in store.get_all_edges()
        },
    };
}

def save_snapshot(snapshot: dict, path: Path) {
    data: any = `dict(snapshot);
    if isinstance(data.get("edges"), `set) {
        data["edges"] = sorted(data["edges"]);
    }
    path.write_text(json.dumps(data, indent=2), encoding="utf-8");
}

def load_snapshot(path: Path) -> dict {
    data: any = json.loads(path.read_text(encoding="utf-8"));
    if isinstance(data.get("edges"), `list) {
        data["edges"] = `set(data["edges"]);
    }
    return data;
}

def diff_snapshots(before: dict, after: dict) -> dict[str, Any] {
    before_nodes: any = `set(before.get("nodes", {}).keys());
    after_nodes: any = `set(after.get("nodes", {}).keys());
    before_edges: any = before.get("edges", set[any]());
    after_edges: any = after.get("edges", set[any]());

    new_nodes: any = after_nodes - before_nodes;
    removed_nodes: any = before_nodes - after_nodes;
    new_edges: any = after_edges - before_edges;
    removed_edges: any = before_edges - after_edges;
    community_changes: any = [];
    for qn in before_nodes & after_nodes {
        before_cid: any = before["nodes"][qn].get("community_id");
        after_cid: any = after["nodes"][qn].get("community_id");
        if before_cid != after_cid {
            community_changes.append({
                "node": qn,
                "before_community": before_cid,
                "after_community": after_cid,
            });
        }
    }

    return {
        "new_nodes": [
            {"qualified_name": qn, **after["nodes"][qn]}
            for qn in sorted(new_nodes)
        ][:100],
        "removed_nodes": sorted(removed_nodes)[:100],
        "new_edges": sorted(new_edges)[:100],
        "removed_edges": sorted(removed_edges)[:100],
        "community_changes": community_changes[:50],
        "summary": {
            "nodes_added": len(new_nodes),
            "nodes_removed": len(removed_nodes),
            "edges_added": len(new_edges),
            "edges_removed": len(removed_edges),
            "community_moves": len(community_changes),
            "before_total": before.get("node_count", 0),
            "after_total": after.get("node_count", 0),
        },
    };
}
