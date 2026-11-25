import from __future__ { annotations }

import logging, re, sqlite3, unicodedata;

import from collections { Counter }

import from pathlib { Path }

import from typing { Any }

glob logger: any = logging.getLogger(__name__);

def _md_cell(value: Any) -> str {
    text: any = _sanitize_name(`str(value));
    text = text.replace("&", "&amp;").replace("|", "&#124;");
    text = re.sub("\\s*[\\r\\n]+\\s*", " ", text);
    return text.strip() or "-";
}

def _slugify(name: str) -> str {
    normalized: any = unicodedata.normalize("NFKD", name);
    ascii_str: any = normalized.encode("ascii", "ignore").decode("ascii");
    slug: any = re.sub("[^a-z0-9]+", "-", ascii_str.lower()).strip("-");
    return slug[:80] or "unnamed";
}

def _generate_community_page(store: GraphStore, community: dict[str, Any]) -> str {
    name: any = community["name"];
    size: any = community["size"];
    cohesion: any = community.get("cohesion", 0.0);
    lang: any = community.get("dominant_language", "");
    description: any = community.get("description", "");

    lines: list[str] = [];
    lines.append(f"# {_md_cell(name)}");
    lines.append("");
    lines.append("## Overview");
    lines.append("");
    if description {
        lines.append(f"{description}");
        lines.append("");
    }
    lines.append(f"- **Size**: {size} nodes");
    lines.append(f"- **Cohesion**: {cohesion:.4f}");
    if lang {
        lines.append(f"- **Dominant Language**: {lang}");
    }
    lines.append("");
    member_qns: any = community.get("members", []);
    community_id: any = community.get("id");
    if community_id is not None {
        lookup_qns: any = store.get_community_member_qns(community_id);
    } else {
        lookup_qns = `list(member_qns);
    }
    lines.append("## Members");
    lines.append("");
    if member_qns {
        lines.append("| Name | Kind | File | Lines |");
        lines.append("|------|------|------|-------|");
        member_count: any = 0;
        for qn in lookup_qns[:50] {
            `node: any = store.get_node(qn);
            if `node and `node.kind != "File" {
                lines.append(
                    "| "
                        + format(_md_cell(`node.name), "")
                        + " | "
                        + format(_md_cell(`node.kind), "")
                        + " | "
                        + format(_md_cell(`node.file_path), "")
                        + " | "
                        + format(_md_cell(f"{`node.line_start}-{`node.line_end}"), "")
                        + " |",
                );
                member_count += 1;
            }
        }

        if not member_count {
            lines.pop();
            lines.pop();
            lines.append("No non-file members found.");
        }

        if len(member_qns) > 50 {
            lines.append("");
            lines.append(f"*... and {len(member_qns) - 50} more members.*");
        }
    } else {
        lines.append("No members found.");
    }
    lines.append("");
    lines.append("## Execution Flows");
    lines.append("");
    member_set: any = `set(member_qns);
    try {
        all_flows: any = get_flows(store, sort_by="criticality", limit=200);
        community_flows: list[dict] = [];
        `flow: any;
        for `flow in all_flows {
            flow_qns: any = store.get_flow_qualified_names(`flow["id"]);
            if flow_qns & member_set {
                community_flows.append(`flow);
            }
        }

        if community_flows {
            for `flow in community_flows[:10] {
                flow_name: any = _sanitize_name(`flow.get("name", "unnamed"));
                criticality: any = `flow.get("criticality", 0.0);
                depth: any = `flow.get("depth", 0);
                lines.append(f"- **{flow_name}** (criticality: {criticality:.2f}, depth: {depth})");
            }
            if len(community_flows) > 10 {
                lines.append(f"- *... and {len(community_flows) - 10} more flows.*");
            }
        } else {
            lines.append("No execution flows pass through this community.");
        }
    } except sqlite3.OperationalError as exc {
        logger.debug("wiki: flows table unavailable: %s", exc);
        lines.append("Execution flow data not available.");
    }
    lines.append("");
    lines.append("## Dependencies");
    lines.append("");
    try {
        outgoing_targets: Counter[str] = Counter();
        incoming_sources: Counter[str] = Counter();
        if member_qns {
            qns: any = `list(member_qns);
            for t in store.get_outgoing_targets(qns) {
                if t not in member_set {
                    outgoing_targets[t] += 1;
                }
            }
            for s in store.get_incoming_sources(qns) {
                if s not in member_set {
                    incoming_sources[s] += 1;
                }
            }
        }

        if outgoing_targets {
            lines.append("### Outgoing");
            lines.append("");
            count: any;
            for (target, count) in outgoing_targets.most_common(15) {
                lines.append(f"- `{_sanitize_name(target)}` ({count} edge(s))");
            }
            lines.append("");
        }

        if incoming_sources {
            lines.append("### Incoming");
            lines.append("");
            for (source, count) in incoming_sources.most_common(15) {
                lines.append(f"- `{_sanitize_name(source)}` ({count} edge(s))");
            }
            lines.append("");
        }

        if not outgoing_targets and not incoming_sources {
            lines.append("No cross-community dependencies detected.");
            lines.append("");
        }
    } except sqlite3.OperationalError as exc {
        logger.debug("wiki: dependency edges unavailable: %s", exc);
        lines.append("Dependency data not available.");
        lines.append("");
    }

    return "\n".join(lines);
}

def generate_wiki(store: GraphStore, wiki_dir: str | Path, force: bool = False) -> dict[str, Any] {
    wiki_path: any = Path(wiki_dir);
    wiki_path.mkdir(parents=True, exist_ok=True);

    communities: any = get_communities(store);

    pages_generated: any = 0;
    pages_updated: any = 0;
    pages_unchanged: any = 0;

    page_entries: list[tuple[str, str, int]] = [];
    used_slugs: set[str] = set[any]();

    for comm in communities {
        name: any = comm["name"];
        base_slug: any = _slugify(name);
        slug: any = base_slug;
        suffix: any = 2;
        while slug in used_slugs {
            slug = f"{base_slug}-{suffix}";
            suffix += 1;
        }
        used_slugs.add(slug);

        filename: any = f"{slug}.md";
        filepath: any = wiki_path / filename;

        content: any = _generate_community_page(store, comm);

        if filepath.exists() and not force {
            existing: any = filepath.read_text(encoding="utf-8", errors="replace");
            if existing == content {
                pages_unchanged += 1;
                page_entries.append((slug, name, comm["size"]));
                continue;
            }
        }

        already_existed: any = filepath.exists();
        filepath.write_text(content, encoding="utf-8");
        if already_existed {
            pages_updated += 1;
        } else {
            pages_generated += 1;
        }
        page_entries.append((slug, name, comm["size"]));
    }
    index_lines: list[str] = [];
    index_lines.append("# Code Wiki");
    index_lines.append("");
    index_lines.append(
        "Auto-generated documentation from the code knowledge graph community structure."
    );
    index_lines.append("");
    index_lines.append(f"**Total communities**: {len(communities)}");
    index_lines.append("");
    index_lines.append("## Communities");
    index_lines.append("");
    index_lines.append("| Community | Size | Link |");
    index_lines.append("|-----------|------|------|");
    for (slug, name, size) in sorted(page_entries, key=lambda (x) -> any { x[1] }) {
        index_lines.append(f"| {_md_cell(name)} | {size} | [{slug}.md]({slug}.md) |");
    }
    index_lines.append("");

    index_content: any = "\n".join(index_lines);
    index_path: any = wiki_path / "index.md";

    if index_path.exists() and not force {
        existing_index: any = index_path.read_text(encoding="utf-8", errors="replace");
        if existing_index == index_content {
            pages_unchanged += 1;
        } else {
            index_path.write_text(index_content, encoding="utf-8");
            pages_updated += 1;
        }
    } else {
        index_path.write_text(index_content, encoding="utf-8");
        pages_generated += 1;
    }

    return {
        "pages_generated": pages_generated,
        "pages_updated": pages_updated,
        "pages_unchanged": pages_unchanged,
    };
}

def get_wiki_page(wiki_dir: str | Path, page_name: str) -> str | None {
    wiki_path: any = Path(wiki_dir);
    slug: any = _slugify(page_name);
    filepath: any = wiki_path / f"{slug}.md";

    if filepath.is_file() {
        return filepath.read_text(encoding="utf-8", errors="replace");
    }
    exact_path: any = (wiki_path / page_name).resolve();
    if exact_path.is_file() and exact_path.is_relative_to(wiki_path.resolve()) {
        return exact_path.read_text(encoding="utf-8", errors="replace");
    }
    if wiki_path.is_dir() {
        for p in wiki_path.iterdir() {
            if p.suffix == ".md" and slug in p.stem {
                return p.read_text(encoding="utf-8", errors="replace");
            }
        }
    }

    return None;
}
