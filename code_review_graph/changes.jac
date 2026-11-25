import from __future__ { annotations }

import builtins, operator, logging, os, re, subprocess, threading;

import from collections { Counter }

import from dataclasses { dataclass, field, replace }

import from pathlib { Path }

import from typing { Any }

glob logger: any = logging.getLogger(__name__);

glob _OVERALL_RISK_LINE: any = "  - Overall risk score: {:.2f}";

glob _TEST_GAP_EXEMPT_NAMES: any = frozenset(
    ("setUp tearDown setUpBeforeClass tearDownAfterClass setup_method teardown_method setUpClass "
        "tearDownClass __construct __init__ __destruct").split(),
);

glob _MIGRATION_METHOD_NAMES: any = frozenset({"up", "down"});

glob _MIGRATION_DIRS: any = frozenset({"migrations", "migrate"});

def _is_migration_file(file_path: str, repo_root: str | Path | None) -> bool {
    relative: any = _repo_relative_path(normalize_file_path(file_path), repo_root);
    if relative is None {
        return False;
    }
    return `any(part in _MIGRATION_DIRS for part in relative.split("/")[:-1]);
}

def is_test_gap_exempt(`node: GraphNode, repo_root: str | Path | None = None) -> bool {
    if `node.kind != "Function" {
        return False;
    }
    if `node.name in _TEST_GAP_EXEMPT_NAMES {
        return True;
    }
    return `node.name in _MIGRATION_METHOD_NAMES and _is_migration_file(`node.file_path, repo_root);
}

def _is_test_lifecycle(`node: GraphNode, store: GraphStore) -> bool {
    return is_test_gap_exempt(`node)
        and (`node.is_test or is_test_file(`node.file_path, store.get_repo_root()));
}

glob _SAFE_GIT_REF: any = re.compile("^[A-Za-z0-9_.~^/@{}\\-]+$");

glob _SAFE_SVN_REV: any = re.compile("^r?\\d+(:r?\\d+|:HEAD|:BASE|:COMMITTED)?$", re.IGNORECASE);

def _vcs_unavailable(tool: str, exc: BaseException) -> ChangeDiscoveryError {
    if isinstance(exc, subprocess.TimeoutExpired) {
        return ChangeDiscoveryError(
            f"could not determine the changed lines: {tool} timed out after {_GIT_TIMEOUT}s. Raise CRG_GIT_TIMEOUT, or re-run when the repository is not busy.",
        );
    }
    return ChangeDiscoveryError(
        f"could not determine the changed lines: {tool} could not be run ({exc}). Install {tool} and make sure it is on PATH.",
    );
}

def parse_git_diff_ranges(
    repo_root: str, base: str = "HEAD~1", *, require_vcs: bool = False
) -> dict[str, list[tuple[int, int]]] {
    if not _SAFE_GIT_REF.match(base) {
        logger.warning("Invalid git ref rejected: %s", base);
        return {};
    }
    try {
        result: any = subprocess.run(
            ["git", "diff", "--unified=0", base, "--"],
            capture_output=True,
            stdin=subprocess.DEVNULL,
            text=True,
            encoding="utf-8",
            errors="replace",
            cwd=repo_root,
            timeout=_GIT_TIMEOUT,
        );
        if result.returncode != 0 {
            logger.warning("git diff failed (rc=%d): %s", result.returncode, result.stderr[:200]);
            return {};
        }
    } except (OSError, subprocess.SubprocessError) as exc {
        logger.warning("git diff error: %s", exc);
        if require_vcs {
            raise _vcs_unavailable("git", exc) from exc;
        }
        return {};
    }

    return _parse_unified_diff(result.stdout);
}

glob _LS_FILES_CHUNK: any = 200;

def _untracked_among(repo_root: str, rel_paths: list[str]) -> set[str] {
    if not rel_paths or (Path(repo_root) / ".svn").exists() {
        return set[any]();
    }
    tracked: set[str] = set[any]();
    for start in range(0, len(rel_paths), _LS_FILES_CHUNK) {
        chunk: any = rel_paths[start:start + _LS_FILES_CHUNK];
        try {
            result: any = subprocess.run(
                ["git", "--literal-pathspecs", "ls-files", "-z", "--", *chunk],
                capture_output=True,
                cwd=repo_root,
                timeout=_GIT_TIMEOUT,
                stdin=subprocess.DEVNULL,
            );
        } except (OSError, subprocess.SubprocessError) {
            logger.debug("git ls-files failed while looking for new files", exc_info=True);
            return set[any]();
        }
        if result.returncode != 0 {
            return set[any]();
        }
        tracked.update(os.fsdecode(path) for path in result.stdout.split(b"\x00") if path);
    }
    return {path for path in rel_paths if path not in tracked};
}

def _new_files_without_ranges(
    repo_root: str, changed_files: list[str], changed_ranges: dict[str, list[tuple[int, int]]]
) -> list[str] {
    deletions: any = getattr(changed_ranges, "deletions", {});
    `root: any = Path(repo_root);
    by_rel: dict[str, str] = {};
    for path in changed_files {
        if path in changed_ranges or path in deletions {
            continue;
        }
        try {
            by_rel[Path(path).relative_to(`root).as_posix()] = path;
        } except ValueError {
            continue;
        }
    }
    untracked: any = _untracked_among(repo_root, `list(by_rel));
    return [by_rel[rel] for rel in by_rel if rel in untracked];
}

def parse_svn_diff_ranges(
    repo_root: str, rev_range: str | None = None, *, require_vcs: bool = False
) -> dict[str, list[tuple[int, int]]] {
    cmd: any = ["svn", "diff", "--non-interactive"];
    if rev_range {
        if not _SAFE_SVN_REV.match(rev_range) {
            logger.warning("Invalid SVN revision range rejected: %s", rev_range);
            return {};
        }
        cmd.extend(["-r", rev_range]);
    }
    try {
        result: any = subprocess.run(
            cmd,
            capture_output=True,
            stdin=subprocess.DEVNULL,
            text=True,
            encoding="utf-8",
            errors="replace",
            cwd=repo_root,
            timeout=_GIT_TIMEOUT,
        );
        if result.returncode != 0 {
            logger.warning("svn diff failed (rc=%d): %s", result.returncode, result.stderr[:200]);
            return {};
        }
    } except (OSError, subprocess.SubprocessError) as exc {
        logger.warning("svn diff error: %s", exc);
        if require_vcs {
            raise _vcs_unavailable("svn", exc) from exc;
        }
        return {};
    }

    return _parse_unified_diff(result.stdout);
}

def parse_diff_ranges(
    repo_root: str, base: str = "HEAD~1", *, require_vcs: bool = False
) -> dict[str, list[tuple[int, int]]] {
    root_path: any = Path(repo_root);
    if (root_path / ".svn").exists() {
        rev_range: any = base if _SAFE_SVN_REV.match(base) else None;
        return parse_svn_diff_ranges(repo_root, rev_range, require_vcs=require_vcs);
    }
    return parse_git_diff_ranges(repo_root, base, require_vcs=require_vcs);
}

glob _C_QUOTE_ESCAPES: any = {
    "a": "\x07",
    "b": "\x08",
    "f": "\x0c",
    "n": "\n",
    "r": "\r",
    "t": "\t",
    "v": "\x0b",
    "\\": "\\",
    "\"": "\"",
};

def _unquote_c_path(quoted: str) -> str {
    raw: any = bytearray();
    index: any;
    end: any;
    (index, end) = (1, len(quoted) - 1);
    while index < end {
        char: any = quoted[index];
        if char != "\\" {
            raw.extend(char.encode("utf-8"));
            index += 1;
            continue;
        }
        nxt: any = quoted[index + 1] if index + 1 < end else "";
        if nxt in _C_QUOTE_ESCAPES {
            raw.extend(_C_QUOTE_ESCAPES[nxt].encode("utf-8"));
            index += 2;
            continue;
        }
        octal: any = "";
        while len(octal) < 3 and index + 1 + len(octal) < end {
            digit: any = quoted[index + 1 + len(octal)];
            if digit not in "01234567" {
                break;
            }
            octal += digit;
        }
        if octal {
            raw.append(`int(octal, 8) & 255);
            index += 1 + len(octal);
            continue;
        }
        raw.extend(b"\\");
        index += 1;
    }
    return raw.decode("utf-8", "replace");
}

def _diff_header_path(rest: str, prefix: str = "b/") -> str | None {
    rest = rest.rstrip("\r");
    if rest.startswith("\"") {
        closing: any = rest.rfind("\"");
        path: any = _unquote_c_path(rest[:closing + 1]);
    } else {
        path = rest.split("\t", 1)[0];
    }
    if path.startswith(prefix) {
        path = path[len(prefix):];
        return path or None;
    }
    return None;
}

glob _POST_IMAGE_HEADER: any = re.compile(
    "^\\+\\+\\+ (/dev/null|\"b/(?:[^\"\\\\]|\\\\.)*\"|b/.*)$"
);

glob _PRE_IMAGE_HEADER: any = re.compile("^--- (/dev/null|\"a/(?:[^\"\\\\]|\\\\.)*\"|a/.*)$");

glob _HUNK_HEADER: any = re.compile("^@@ -(\\d+)(?:,(\\d+))? \\+(\\d+)(?:,(\\d+))? @@");

@dataclass(frozen=True)
class PureDeletion {
    has old_start: int;

    has old_end: int;

    has anchor: int;
}

@dataclass
class FileDeletions {
    has old_path: str;

    has hunks: list[PureDeletion] = field(default_factory=list[any]);
}

class DiffRanges(builtins.dict) {
    def init(
        ranges: dict[str, list[tuple[int, int]]] | None = None,
        deletions: dict[str, FileDeletions] | None = None,
    ) {
        super.__init__(ranges or {});
        self.deletions = deletions or {};
    }

    def edit_ranges -> dict[str, list[tuple[int, int]]] {
        edits: dict[str, list[tuple[int, int]]] = {};
        for (path, ranges) in self.items() {
            kept: any = `list(ranges);
            held: any = self.deletions.get(path);
            for hunk in held.hunks if held else () {
                position: any = (hunk.anchor, hunk.anchor);
                if position in kept {
                    kept.remove(position);
                }
            }
            if kept {
                edits[path] = kept;
            }
        }
        return edits;
    }

    def remapped(`root: str | Path) -> DiffRanges {
        root_path: any = Path(`root);
        return DiffRanges(
            {normalize_file_path(root_path / k): v for (k, v) in self.items()},
            {normalize_file_path(root_path / k): v for (k, v) in self.deletions.items()},
        );
    }
}

def _parse_unified_diff(diff_text: str) -> DiffRanges {
    ranges: dict[str, list[tuple[int, int]]] = {};
    deletions: dict[str, FileDeletions] = {};
    current_file: str | None = None;
    old_file: str | None = None;

    lines: any = diff_text.splitlines();
    for (index, line) in enumerate(lines) {
        file_match: any = _POST_IMAGE_HEADER.match(line);
        if file_match {
            current_file = _diff_header_path(file_match.group(1));
            if index == 0 or not _PRE_IMAGE_HEADER.match(lines[index - 1]) {
                old_file = current_file;
            }
            continue;
        }
        pre_match: any = _PRE_IMAGE_HEADER.match(line);
        if pre_match and index + 1 < len(lines) and _POST_IMAGE_HEADER.match(lines[index + 1]) {
            old_file = _diff_header_path(pre_match.group(1), "a/");
            continue;
        }

        hunk_match: any = _HUNK_HEADER.match(line);
        if not hunk_match or current_file is None {
            continue;
        }
        old_start: any = `int(hunk_match.group(1));
        old_count: any = `int(hunk_match.group(2)) if hunk_match.group(2) else 1;
        start: any = `int(hunk_match.group(3));
        count: any = `int(hunk_match.group(4)) if hunk_match.group(4) else 1;
        if count == 0 {
            end: any = start;
            held: any = deletions.get(current_file);
            if held is None {
                value_: any = FileDeletions(old_path=old_file or current_file);
                held = value_;
                deletions[current_file] = value_;
            }
            held.hunks.append(PureDeletion(old_start, old_start + old_count - 1, start));
        } else {
            end = start + count - 1;
        }
        ranges.setdefault(current_file, []).append((start, end));
    }

    return DiffRanges(ranges, deletions);
}

glob _CHURN_SATURATION: any = 10.0;

glob _CHURN_WEIGHT: any = 0.15;

glob _NUMSTAT_COUNT: any = re.compile("^(?:\\d+|-)$");

glob _CHURN_TIMEOUT: any = env_float("CRG_CHURN_TIMEOUT", 5.0);

glob _CHURN_MAX_COMMITS: any = env_int("CRG_CHURN_MAX_COMMITS", 2000);

glob _CHURN_CACHE_MAX_ENTRIES: any = 32;

glob _CHURN_CACHE_LOCK: any = threading.Lock();

glob _CHURN_CACHE: dict[tuple[str, str, int], dict[str, int]] = {};

glob _CHURN_UNAVAILABLE: any = set[any]();

glob CHURN_OK: any = "ok";

glob CHURN_UNAVAILABLE: any = "unavailable";

glob CHURN_OFF: any = "off";

def clear_churn_cache {
    with _CHURN_CACHE_LOCK {
        _CHURN_CACHE.clear();
        _CHURN_UNAVAILABLE.clear();
    }
}

def _churn_is_unavailable(fail_key: tuple[str, int]) -> bool {
    with _CHURN_CACHE_LOCK {
        return fail_key in _CHURN_UNAVAILABLE;
    }
}

def _mark_churn_unavailable(fail_key: tuple[str, int]) {
    with _CHURN_CACHE_LOCK {
        if len(_CHURN_UNAVAILABLE) >= _CHURN_CACHE_MAX_ENTRIES {
            _CHURN_UNAVAILABLE.clear();
        }
        _CHURN_UNAVAILABLE.add(fail_key);
    }
    logger.warning(
        "Change-frequency risk disabled for %s: git history could not be read within %.3gs. Risk scores exclude the churn term.",
        fail_key[0],
        _CHURN_TIMEOUT,
    );
}

def _churn_cache_key(repo_root: str, window_days: int) -> tuple[str, str, int] | None {
    try {
        result: any = subprocess.run(
            ["git", "rev-parse", "--verify", "HEAD"],
            capture_output=True,
            stdin=subprocess.DEVNULL,
            text=True,
            encoding="utf-8",
            errors="replace",
            cwd=repo_root,
            timeout=_CHURN_TIMEOUT,
            check=False,
        );
    } except (OSError, subprocess.SubprocessError) {
        return None;
    }
    if result.returncode != 0 {
        return None;
    }
    head: any = result.stdout.strip();
    return (repo_root, head, window_days) if head else None;
}

def _parse_numstat(log_text: str) -> dict[str, int] {
    counts: dict[str, int] = {};
    for record in log_text.split("\x00") {
        if not record {
            continue;
        }
        fields: any = record.split("\t", 2);
        if len(fields) != 3 {
            continue;
        }
        added: any;
        deleted: any;
        path: any;
        (added, deleted, path) = fields as any;
        if not path
            or _NUMSTAT_COUNT.fullmatch(added) is None
            or _NUMSTAT_COUNT.fullmatch(deleted) is None
        {
            continue;
        }
        counts[path] = counts.get(path, 0) + 1;
    }
    return counts;
}

def compute_file_churn(repo_root: str, window_days: int | None = None) -> dict[str, int] {
    return compute_file_churn_with_status(repo_root, window_days)[0];
}

def compute_file_churn_with_status(
    repo_root: str, window_days: int | None = None
) -> tuple[dict[str, int], str] {
    if window_days is None {
        raw_window: any = os.environ.get("CRG_CHURN_WINDOW_DAYS", "90");
        try {
            window_days = `int(raw_window);
        } except ValueError {
            logger.warning("Invalid CRG_CHURN_WINDOW_DAYS value %r; churn disabled", raw_window);
            return ({}, CHURN_OFF);
        }
    }
    if window_days <= 0 {
        return ({}, CHURN_OFF);
    }
    fail_key: any = (repo_root, window_days);
    if _churn_is_unavailable(fail_key) {
        return ({}, CHURN_UNAVAILABLE);
    }

    cache_key: any = _churn_cache_key(repo_root, window_days);
    if cache_key is None {
        _mark_churn_unavailable(fail_key);
        return ({}, CHURN_UNAVAILABLE);
    }
    with _CHURN_CACHE_LOCK {
        cached: any = _CHURN_CACHE.get(cache_key);
    }
    if cached is not None {
        return (`dict(cached), CHURN_OK);
    }

    try {
        result: any = subprocess.run(
            [
                "git",
                "-c",
                "core.quotepath=off",
                "log",
                f"--since={window_days}.days.ago",
                f"--max-count={_CHURN_MAX_COMMITS}",
                "--numstat",
                "--no-renames",
                "--format=",
                "-z",
                "--",
            ],
            capture_output=True,
            stdin=subprocess.DEVNULL,
            text=True,
            encoding="utf-8",
            errors="replace",
            cwd=repo_root,
            timeout=_CHURN_TIMEOUT,
        );
        if result.returncode != 0 {
            logger.warning("git log failed (rc=%d): %s", result.returncode, result.stderr[:200]);
            _mark_churn_unavailable(fail_key);
            return ({}, CHURN_UNAVAILABLE);
        }
        counts: any = _parse_numstat(result.stdout);
    } except (OSError, subprocess.SubprocessError) as exc {
        logger.warning("git log error: %s", exc);
        _mark_churn_unavailable(fail_key);
        return ({}, CHURN_UNAVAILABLE);
    }

    with _CHURN_CACHE_LOCK {
        if len(_CHURN_CACHE) >= _CHURN_CACHE_MAX_ENTRIES {
            _CHURN_CACHE.clear();
        }
        _CHURN_CACHE[cache_key] = `dict(counts);
    }
    return (counts, CHURN_OK);
}

def map_changes_to_nodes(
    store: GraphStore, changed_ranges: dict[str, list[tuple[int, int]]]
) -> list[GraphNode] {
    ranges: any;
    start: any;
    end: any;
    seen: set[str] = set[any]();
    result: list[GraphNode] = [];

    file_path: any;
    for item_ in changed_ranges.items() {
        (file_path, ranges) = item_;
        nodes: any = store.get_nodes_by_file(file_path);
        if not nodes {
            matched_paths: any = store.get_files_matching(file_path);
            for mp in matched_paths {
                nodes.extend(store.get_nodes_by_file(mp));
            }
        }

        for `node in nodes {
            if `node.qualified_name in seen {
                continue;
            }
            if `node.line_start is None or `node.line_end is None {
                continue;
            }
            yaml_ranges: any = `node.extra.get("range_samples");
            if `node.kind in ("YamlPath", "JsonPath")
                and isinstance(yaml_ranges, `list)
                and not `node.extra.get("lines_truncated")
            {
                overlaps: any = `any(
                    isinstance(sample, `list)
                        and operator.eq(len(sample), 2)
                        and isinstance(sample[0], `int)
                        and isinstance(sample[1], `int)
                        and operator.le(sample[0], end)
                        and operator.ge(sample[1], start)
                    for sample in yaml_ranges
                    for (start, end) in ranges,
                );
                if overlaps {
                    result.append(`node);
                    seen.add(`node.qualified_name);
                }
                continue;
            }
            for (start, end) in ranges {
                if `node.line_start <= end and `node.line_end >= start {
                    result.append(`node);
                    seen.add(`node.qualified_name);
                    break;
                }
            }
        }
    }

    return result;
}

glob _CODE_KINDS: any = ("Function", "Test", "Class");

glob _MAX_DELETION_FILES: any = env_int("CRG_MAX_DELETION_FILES", 100);

glob _MAX_REMOVED_SYMBOLS: any = 200;

glob _MAX_REMOVED_USERS_SHOWN: any = 3;

glob _SELF_RECEIVERS: any = frozenset({"self", "this", "cls"});

@dataclass
class _DeletionReview {
    has changed: list[GraphNode] = field(default_factory=list[any]);

    has removed: list[dict[str, Any]] = field(default_factory=list[any]);

    has removed_total: int = 0;

    has files_not_read: int = 0;
}

def _nodes_in_file(store: GraphStore, file_path: str) -> list[GraphNode] {
    nodes: any = store.get_nodes_by_file(file_path);
    if not nodes {
        for matched in store.get_files_matching(file_path) {
            nodes.extend(store.get_nodes_by_file(matched));
        }
    }
    return nodes;
}

@dataclass
class _OldSide {
    has nodes: list[tuple[str, NodeInfo]];

    has calls: dict[str, list[str]];
}

def _old_side_nodes(
    parser: CodeParser, repo_root: str, base: str, old_path: str, parse_path: str
) -> _OldSide | None {
    if not _SAFE_GIT_REF.match(base) {
        return None;
    }
    try {
        shown: any = subprocess.run(
            ["git", "show", f"{base}:{old_path}"],
            capture_output=True,
            stdin=subprocess.DEVNULL,
            cwd=repo_root,
            timeout=_GIT_TIMEOUT,
        );
    } except (OSError, subprocess.SubprocessError) as exc {
        logger.warning("git show failed for %s: %s", old_path, exc);
        return None;
    }
    if shown.returncode != 0 {
        return None;
    }
    try {
        nodes: any;
        edges: any;
        (nodes, edges) = parser.parse_bytes(Path(parse_path), shown.stdout) as any;
    } except Exception as exc {
        logger.warning("Could not parse the old side of %s: %s", old_path, exc);
        return None;
    }
    if not nodes {
        return None;
    }
    calls: dict[str, list[str]] = {};
    for `edge in edges {
        if `edge.kind == "CALLS" {
            calls.setdefault(`edge.source, []).append(`edge.target);
        }
    }
    return _OldSide(
        nodes=[
            (qualified_name_of(`node), `node)
            for `node in nodes
            if `node.kind in _CODE_KINDS
                and not `node.extra.get("verilog_kind")
                and `node.line_start
                and `node.line_end
        ],
        calls=calls,
    );
}

def _bare_call_reaches(`edge: GraphEdge, removed: GraphNode) -> bool {
    extra: any = `edge.extra or {};
    if "ambiguous_targets" in extra or "unresolved_targets" in extra {
        return False;
    }
    if "receiver_binding" in extra {
        return GraphStore.receiver_evidence_admits(extra, removed);
    }
    if normalize_file_path(`edge.file_path) != removed.file_path {
        return False;
    }
    if not removed.parent_name {
        return "receiver" not in extra;
    }
    own_class: any = f"{removed.file_path}::{removed.parent_name}.";
    return (extra.get("receiver") in _SELF_RECEIVERS or "receiver" not in extra)
        and `edge.source_qualified.startswith(own_class);
}

@dataclass
class _RemovedUsers {
    has users: list[dict[str, Any]];

    has call_sources: list[str];

    has caller_ids: set[int];
}

def _as_graph_node(qualified_name: str, info: NodeInfo) -> GraphNode {
    return GraphNode(
        id=0,
        kind=info.kind,
        name=info.name,
        qualified_name=qualified_name,
        file_path=info.file_path,
        line_start=info.line_start,
        line_end=info.line_end,
        language=info.language,
        parent_name=info.parent_name,
        params=info.params,
        return_type=info.return_type,
        is_test=info.is_test,
        file_hash=None,
        extra=info.extra,
    );
}

def _removed_symbol_users(store: GraphStore, removed: GraphNode) -> _RemovedUsers {
    users: dict[str, dict[str, Any]];
    qualified_name: any = removed.qualified_name;
    users = {};
    found: any = _RemovedUsers(users=[], call_sources=[], caller_ids=set[any]());

    def add(source: str, relation: str, line: int) {
        `node: any = store.get_node(source) if source != qualified_name else None;
        if `node is None {
            return;
        }
        if relation == "CALLS" {
            found.call_sources.append(source);
            found.caller_ids.add(`node.id);
        }
        if source in users {
            return;
        }
        users[source] = {
            "name": _sanitize_name(`node.name),
            "qualified_name": _sanitize_name(`node.qualified_name),
            "line": line,
            "relation": relation,
        };
    }

    `edge: any;
    for `edge in store.get_edges_by_target(qualified_name) {
        if `edge.kind != "CONTAINS" {
            add(`edge.source_qualified, `edge.kind, `edge.line);
        }
    }
    for `edge in store.get_edges_by_source(qualified_name) {
        if `edge.kind == "TESTED_BY" {
            add(`edge.target_qualified, `edge.kind, `edge.line);
        }
    }
    bare_reached: set[int] = set[any]();
    for `edge in store.search_edges_by_target_name(removed.name, kind="CALLS") {
        if _bare_call_reaches(`edge, removed) {
            bare_reached.add(`edge.id);
            add(`edge.source_qualified, `edge.kind, `edge.line);
        }
    }
    for `edge in store.get_edges_claiming(qualified_name) {
        if `edge.id in bare_reached {
            continue;
        }
        if `edge.kind == "TESTED_BY" {
            add(`edge.target_qualified, `edge.kind, `edge.line);
        } elif `edge.kind != "CONTAINS" {
            add(`edge.source_qualified, `edge.kind, `edge.line);
        }
    }
    found.users = sorted(
        users.values(), key=lambda (u) -> any { (u["qualified_name"], u["line"] or 0) }
    );
    return found;
}

@dataclass
class _RemovedSymbol {
    has `node: GraphNode;

    has old_calls: list[str];

    has file_community: int | None;

    has found: _RemovedUsers = field(
        default_factory=lambda -> any {
            _RemovedUsers(users=[], call_sources=[], caller_ids=set[any]())
        },
    );
}

def _removed_flow_criticalities(
    store: GraphStore, removed: list[_RemovedSymbol]
) -> dict[str, list[float]] {
    qn: any;
    adj: any = store.load_flow_adjacency();
    by_qn: dict[str, int] = {};
    item: any;
    for (index, item) in enumerate(removed) {
        `node: any = replace(item.node, id=-(index + 1));
        by_qn[`node.qualified_name] = `node.id;
        adj.nodes_by_qn[`node.qualified_name] = `node;
        adj.nodes_by_id[`node.id] = `node;
    }
    for item in removed {
        `node = item.node;
        own_file: any = f"{`node.file_path}::";
        targets: any = adj.calls_out.setdefault(`node.qualified_name, []);
        target: any;
        for target in item.old_calls {
            if target not in adj.nodes_by_qn and "::" not in target {
                target = own_file + target;
            }
            targets.append(target);
        }
        for source in `set(item.found.call_sources) {
            callees: any = adj.calls_out.setdefault(source, []);
            if `node.qualified_name not in callees {
                callees.append(`node.qualified_name);
            }
        }
    }

    caller_ids: any = set[any]().union(*(item.found.caller_ids for item in removed));
    starts: any = store.get_flow_entry_point_ids(caller_ids);
    entry_ids: any = {ep.id for ep in detect_entry_points(store)};
    starts |= caller_ids & entry_ids;
    criticalities: dict[str, list[float]] = {qn: [] for qn in by_qn};
    for node_id in starts {
        `entry: any = adj.nodes_by_id.get(node_id);
        `flow: any = _trace_single_flow(adj, `entry) if `entry is not None else None;
        if `flow is None {
            continue;
        }
        on_path: any = `set(`flow["path"]);
        for (qn, removed_id) in by_qn.items() {
            if removed_id in on_path {
                criticalities[qn].append(`flow["criticality"]);
            }
        }
    }
    return criticalities;
}

def _score_removed(
    store: GraphStore, removed: list[_RemovedSymbol], churn_counts: dict[str, int] | None
) -> dict[str, float] {
    item: any;
    used: any = [item for item in removed if item.found.users];
    scores: any = {item.node.qualified_name: 0.0 for item in removed};
    if not used {
        return scores;
    }
    flows: any = _removed_flow_criticalities(store, used);
    for item in used {
        qn: any = item.node.qualified_name;
        scores[qn] = _score_risk(
            store,
            item.node,
            churn_counts,
            flow_criticalities=flows[qn],
            flow_count=0,
            caller_qns=item.found.call_sources,
            cross_community=_cross_community(
                store, item.found.call_sources, item.file_community, own_group=True
            ),
        );
    }
    return scores;
}

def _file_community(store: GraphStore, nodes: list[GraphNode]) -> int | None {
    cids: any = store.get_community_ids_by_qualified_names([
        `node.qualified_name
        for `node in nodes
        if `node.kind != "File"
    ]);
    counts: any = Counter(cid for cid in cids.values() if cid is not None);
    return counts.most_common(1)[0][0] if counts else None;
}

def _review_pure_deletions(
    store: GraphStore,
    deletions: dict[str, FileDeletions],
    repo_root: str | None,
    base: str,
    churn_counts: dict[str, int] | None = None,
) -> _DeletionReview {
    held: any;
    info: any;
    `node: any;
    review: any = _DeletionReview();
    parser: CodeParser | None = None;
    files_read: any = 0;
    candidates: list[_RemovedSymbol] = [];
    file_path: any;
    for item__ in deletions.items() {
        (file_path, held) = item__;
        current: any = _nodes_in_file(store, file_path);
        if not current {
            continue;
        }
        old_side: _OldSide | None = None;
        if repo_root is not None and files_read < _MAX_DELETION_FILES {
            files_read += 1;
            if parser is None {
                parser = CodeParser(Path(repo_root));
            }
            old_side = _old_side_nodes(parser, repo_root, base, held.old_path, file_path);
        }
        if old_side is None {
            review.files_not_read += 1;
            review.changed.extend(
                `node
                for `node in current
                if `node.kind in _CODE_KINDS
                    and `node.line_start is not None
                    and `node.line_end is not None
                    and `any(
                        operator.le(`node.line_start, compared_ := hunk.anchor)
                            and operator.lt(compared_, `node.line_end)
                        for hunk in held.hunks,
                    ),
            );
            continue;
        }
        survivors: any = {`node.qualified_name: `node for `node in current};
        community: int | None = None;
        community_known: any = False;
        qualified_name: any;
        for item___ in old_side.nodes {
            (qualified_name, info) = item___;
            hit: any = [
                hunk
                for hunk in held.hunks
                if info.line_start <= hunk.old_end and info.line_end >= hunk.old_start
            ];
            if not hit {
                continue;
            }
            survivor: any = survivors.get(qualified_name);
            if survivor is None {
                if not community_known {
                    community = _file_community(store, current);
                    community_known = True;
                }
                candidates.append(
                    _RemovedSymbol(
                        node=_as_graph_node(qualified_name, info),
                        old_calls=old_side.calls.get(qualified_name, []),
                        file_community=community,
                    ),
                );
            } elif not `any(
                operator.le(hunk.old_start, info.line_start)
                    and operator.le(info.line_end, hunk.old_end)
                for hunk in hit,
            ) {
                review.changed.append(survivor);
            }
        }
    }

    review.removed_total = len(candidates);
    looked_up: any = candidates[:_MAX_REMOVED_SYMBOLS];
    item: any;
    for item in looked_up {
        item.found = _removed_symbol_users(store, item.node);
    }
    scores: any = _score_removed(store, looked_up, churn_counts);
    for item in looked_up {
        `node = item.node;
        review.removed.append({
            "name": _sanitize_name(`node.name),
            "qualified_name": _sanitize_name(`node.qualified_name),
            "kind": `node.kind,
            "file": `node.file_path,
            "old_line_start": `node.line_start,
            "old_line_end": `node.line_end,
            "risk_score": scores[`node.qualified_name],
            "used_by": item.found.users[:_MAX_REMOVED_USERS_SHOWN],
            "used_by_total": len(item.found.users),
        });
    }
    review.removed.sort(
        key=lambda (r) -> any {
            (-r["risk_score"], -r["used_by_total"], r["file"], r["old_line_start"])
        },
    );
    return review;
}

def _removed_summary_lines(review: _DeletionReview) -> list[str] {
    if not review.removed_total {
        return [];
    }
    lines: any = [f"  - {review.removed_total} removed function(s)/class(es)"];
    still_used: any = [r for r in review.removed if r["used_by_total"]];
    if still_used {
        named: any = [];
        for `entry in still_used[:5] {
            users: any = ", ".join(_symbol_part(u["qualified_name"]) for u in `entry["used_by"]);
            more: any = `entry["used_by_total"] - len(`entry["used_by"]);
            named.append(
                format(_symbol_part(`entry["qualified_name"]), "")
                    + " (risk "
                    + format(`entry["risk_score"], ".2f")
                    + ", by "
                    + format(users, "")
                    + format(f" +{more} more" if more else "", "")
                    + ")",
            );
        }
        lines.append(f"  - Removed but still used: {"; ".join(named)}");
    }
    return lines;
}

def _symbol_part(qualified_name: str) -> str {
    if "::" in qualified_name {
        return qualified_name.split("::", 1)[1];
    }
    return qualified_name.rsplit("/", 1)[-1];
}

def compute_risk_score(
    store: GraphStore, `node: GraphNode, churn_counts: dict[str, int] | None = None
) -> float {
    return _sum_signals(risk_signals(store, `node, churn_counts));
}

def risk_signals(
    store: GraphStore, `node: GraphNode, churn_counts: dict[str, int] | None = None
) -> dict[str, dict[str, float]] {
    flow_criticalities: any = store.get_flow_criticalities_for_node(`node.id);
    callers: any = store.get_edges_by_target(`node.qualified_name);
    caller_qns: any = [e.source_qualified for e in callers if e.kind == "CALLS"];
    return _risk_signals_from(
        store,
        `node,
        churn_counts,
        flow_criticalities=flow_criticalities,
        flow_count=0 if flow_criticalities else store.count_flow_memberships(`node.id),
        caller_qns=caller_qns,
        cross_community=_cross_community(store, caller_qns, store.get_node_community_id(`node.id)),
    );
}

def _cross_community(
    store: GraphStore, caller_qns: list[str], node_cid: int | None, *, own_group: bool = False
) -> int {
    if not caller_qns or node_cid is None and not own_group {
        return 0;
    }
    cid_map: any = store.get_community_ids_by_qualified_names(caller_qns);
    return sum(1 for cid in cid_map.values() if cid is not None and cid != node_cid);
}

def _sum_signals(signals: dict[str, dict[str, float]]) -> float {
    score: any = 0.0;
    for signal in signals.values() {
        score += signal["score"];
    }
    return round(min(max(score, 0.0), 1.0), 4);
}

def _score_risk(
    store: GraphStore,
    `node: GraphNode,
    churn_counts: dict[str, int] | None,
    *,
    flow_criticalities: list[float],
    flow_count: int,
    caller_qns: list[str],
    cross_community: int,
) -> float {
    return _sum_signals(
        _risk_signals_from(
            store,
            `node,
            churn_counts,
            flow_criticalities=flow_criticalities,
            flow_count=flow_count,
            caller_qns=caller_qns,
            cross_community=cross_community,
        ),
    );
}

def _risk_signals_from(
    store: GraphStore,
    `node: GraphNode,
    churn_counts: dict[str, int] | None,
    *,
    flow_criticalities: list[float],
    flow_count: int,
    caller_qns: list[str],
    cross_community: int,
) -> dict[str, dict[str, float]] {
    signals: dict[str, dict[str, float]] = {};
    if flow_criticalities {
        signals["flows"] = {
            "score": min(sum(flow_criticalities), 0.25),
            "count": len(flow_criticalities),
        };
    } else {
        signals["flows"] = {"score": min(flow_count * 0.05, 0.25), "count": flow_count};
    }
    signals["cross_community"] = {
        "score": min(cross_community * 0.05, 0.15),
        "count": cross_community,
    };
    signals["tests"] = {"score": 0.0, "count": 0};
    if not _is_test_lifecycle(`node, store) {
        transitive_tests: any = store.get_transitive_tests(
            `node.qualified_name, include_helper_routes=False
        );
        test_count: any = len(transitive_tests);
        signals["tests"] = {"score": 0.3 - min(test_count / 5.0, 1.0) * 0.25, "count": test_count};
    }
    name_lower: any = `node.name.lower();
    qn_lower: any = `node.qualified_name.lower();
    sensitive: any = `any(kw in name_lower or kw in qn_lower for kw in _SECURITY_KEYWORDS);
    signals["security"] = {"score": 0.2 if sensitive else 0.0, "count": `int(sensitive)};
    caller_count: any = len(caller_qns);
    signals["callers"] = {"score": min(caller_count / 20.0, 0.1), "count": caller_count};
    signals["churn"] = {"score": 0.0, "count": 0};
    if churn_counts and `node.file_path {
        commit_count: any = churn_counts.get(`node.file_path, 0);
        signals["churn"] = {
            "score": min(commit_count / _CHURN_SATURATION, 1.0) * _CHURN_WEIGHT,
            "count": commit_count,
        };
    }

    return signals;
}

def review_churn_counts(repo_root: str | None, include_churn: bool) -> tuple[dict[str, int]
    | None, str] {
    if not include_churn or repo_root is None {
        return (None, CHURN_OFF);
    }
    raw_churn: any;
    churn_status: any;
    (raw_churn, churn_status) = compute_file_churn_with_status(repo_root) as any;
    churn_counts: dict[str, int] = {};
    root_path: any = Path(repo_root);
    for (key, count) in raw_churn.items() {
        churn_counts[key] = count;
        churn_counts[normalize_file_path(root_path / key)] = count;
    }
    return (churn_counts, churn_status);
}

def analyze_changes(
    store: GraphStore,
    changed_files: list[str],
    changed_ranges: dict[str, list[tuple[int, int]]] | None = None,
    repo_root: str | None = None,
    base: str = "HEAD~1",
    include_churn: bool = False,
    require_vcs: bool = False,
) -> dict[str, Any] {
    `node: any;
    fp: any;
    ranges_unavailable: any = "";
    if changed_ranges is None and repo_root is not None {
        root_path: any = Path(repo_root);
        try {
            raw_ranges: any = parse_diff_ranges(repo_root, base, require_vcs=require_vcs);
        } except ChangeDiscoveryError as exc {
            if not changed_files {
                raise;
            }
            logger.warning("%s; scoring whole files instead", exc);
            ranges_unavailable = `str(exc);
            raw_ranges = {};
        }
        if not isinstance(raw_ranges, DiffRanges) {
            raw_ranges = DiffRanges(raw_ranges);
        }
        changed_ranges = raw_ranges.remapped(root_path);
    }
    if repo_root is not None {
        _root: any = Path(repo_root);
        changed_files = [normalize_file_path(_root / fp) for fp in changed_files];
    }
    churn_counts: any;
    churn_status: any;
    (churn_counts, churn_status) = review_churn_counts(repo_root, include_churn) as any;
    deletions: dict[str, FileDeletions] = changed_ranges.deletions
        if isinstance(changed_ranges, DiffRanges)
        else {};
    deletion_review: any = _DeletionReview();
    if deletions and isinstance(changed_ranges, DiffRanges) {
        changed_nodes: any = map_changes_to_nodes(store, changed_ranges.edit_ranges());
        seen_qns: any = {`node.qualified_name for `node in changed_nodes};
        deletion_review = _review_pure_deletions(store, deletions, repo_root, base, churn_counts);
        positions: any = {
            path: [(hunk.anchor, hunk.anchor) for hunk in held.hunks]
            for (path, held) in deletions.items()
        };
        positional: any = [
            `node
            for `node in map_changes_to_nodes(store, positions)
            if `node.kind not in _CODE_KINDS
        ];
        for `node in [*positional, *deletion_review.changed] {
            if `node.qualified_name not in seen_qns {
                seen_qns.add(`node.qualified_name);
                changed_nodes.append(`node);
            }
        }
    } elif changed_ranges {
        changed_nodes = map_changes_to_nodes(store, changed_ranges);
    } else {
        changed_nodes = [];
        for fp in changed_files {
            changed_nodes.extend(store.get_nodes_by_file(fp));
        }
    }

    if changed_ranges and repo_root is not None {
        seen_new: any = {`node.qualified_name for `node in changed_nodes};
        for fp in _new_files_without_ranges(repo_root, changed_files, changed_ranges) {
            for `node in store.get_nodes_by_file(fp) {
                if `node.qualified_name not in seen_new {
                    seen_new.add(`node.qualified_name);
                    changed_nodes.append(`node);
                }
            }
        }
    }
    changed_funcs: any = [
        n
        for n in changed_nodes
        if n.kind in ("Function", "Test", "Class") and not n.extra.get("verilog_kind")
    ];
    changed_yaml_paths: any = [n for n in changed_nodes if n.kind == "YamlPath"];
    changed_json_paths: any = [n for n in changed_nodes if n.kind == "JsonPath"];
    _max_funcs: any = env_int("CRG_MAX_CHANGED_FUNCS", 500);
    funcs_truncated: any = operator.gt(len(changed_funcs), _max_funcs);
    if funcs_truncated {
        changed_funcs = changed_funcs[:_max_funcs];
    }

    _max_yaml_paths: any = env_int("CRG_MAX_CHANGED_YAML_PATHS", 200);
    yaml_paths_truncated: any = operator.gt(len(changed_yaml_paths), _max_yaml_paths);
    if yaml_paths_truncated {
        changed_yaml_paths = changed_yaml_paths[:_max_yaml_paths];
    }
    json_paths_truncated: any = operator.gt(len(changed_json_paths), _max_yaml_paths);
    if json_paths_truncated {
        changed_json_paths = changed_json_paths[:_max_yaml_paths];
    }
    yaml_path_results: any = [node_to_dict(`node) for `node in changed_yaml_paths];
    json_path_results: any = [node_to_dict(`node) for `node in changed_json_paths];
    gap_root: any = repo_root or store.get_repo_root();
    gap_candidates: any = [
        `node
        for `node in changed_funcs
        if not (`node.is_test or is_test_file(`node.file_path, gap_root))
            and not is_test_gap_exempt(`node, gap_root)
            and not `node.extra.get("typescript_kind")
    ];
    directly_tested: any = store.get_directly_tested(
        `node.qualified_name for `node in gap_candidates
    );
    caller_routes: any = store.get_caller_test_routes(
        (`node.qualified_name
        for `node in gap_candidates
        if `node.qualified_name not in directly_tested),
        repo_root=gap_root,
    );
    node_risks: list[dict[str, Any]] = [];
    for `node in changed_funcs {
        risk: any = compute_risk_score(store, `node, churn_counts);
        node_risks.append({**node_to_dict(`node), "risk_score": risk});
    }
    overall_risk: any = max(
        (
            *(nr["risk_score"] for nr in node_risks),
            *(r["risk_score"] for r in deletion_review.removed),
        ),
        default=0.0,
    );
    affected: any = get_affected_flows(store, changed_files);
    test_gaps: list[dict[str, Any]] = [];
    indirect_gaps: list[dict[str, Any]] = [];
    for `node in gap_candidates {
        if `node.qualified_name in directly_tested {
            continue;
        }
        `entry: dict[str, Any] = {
            "name": _sanitize_name(`node.name),
            "qualified_name": _sanitize_name(`node.qualified_name),
            "file": `node.file_path,
            "line_start": `node.line_start,
            "line_end": `node.line_end,
        };
        route: any = caller_routes.get(`node.qualified_name);
        if route is None {
            `entry["coverage"] = "none";
        } else {
            `entry["coverage"] = "indirect";
            `entry["covered_via"] = _sanitize_name(`str(route["via"]));
            `entry["covered_depth"] = route["depth"];
            `entry["covered_by"] = [_sanitize_name(`str(t)) for t in route["tests"][:1]];
            indirect_gaps.append(`entry);
        }
        test_gaps.append(`entry);
    }
    indirect_count: any = len(indirect_gaps);
    uncovered_count: any = len(test_gaps) - indirect_count;
    review_priorities: any = sorted(
        node_risks, key=lambda (x) -> any { x["risk_score"] }, reverse=True
    )[:10];
    gap_line: any = f"  - {len(test_gaps)} test gap(s)";
    if indirect_count {
        gap_line += f" ({uncovered_count} with no tested caller found, {indirect_count} reached only through a caller)";
    }
    summary_parts: any = [
        f"Analyzed {len(changed_files)} changed file(s):",
        f"  - {len(changed_funcs)} changed function(s)/class(es)",
        *([f"  - {len(changed_yaml_paths)} changed YAML path(s)"] if changed_yaml_paths else []),
        *([f"  - {len(changed_json_paths)} changed JSON path(s)"] if changed_json_paths else []),
        *_removed_summary_lines(deletion_review),
        f"  - {affected["total"]} affected flow(s)",
        gap_line,
        _OVERALL_RISK_LINE.format(overall_risk),
    ];
    def _gap_names(entries: list[dict[str, Any]], limit: int = 5) -> list[str] {
        seen_names: set[str] = set[any]();
        names: list[str] = [];
        for g in entries {
            n: any = g["name"];
            if n in seen_names {
                continue;
            }
            seen_names.add(n);
            names.append(n);
            if len(names) >= limit {
                break;
            }
        }
        return names;
    }

    if uncovered_count {
        unreached_gaps: any = [g for g in test_gaps if g["coverage"] != "indirect"];
        summary_parts.append(f"  - Untested: {", ".join(_gap_names(unreached_gaps))}");
    }
    if indirect_count {
        summary_parts.append(
            f"  - Reached only through a caller: {", ".join(_gap_names(indirect_gaps))}"
        );
    }
    if `any(
        operator.eq(`node.language, "php") and `node.qualified_name not in directly_tested
        for `node in gap_candidates,
    ) {
        summary_parts.append(
            "  - PHP gaps are a guess: tests that reach code through the container or an HTTP call are not traced (tests_for names likely ones)",
        );
    }
    if funcs_truncated {
        summary_parts.append(
            f"  - Warning: analysis capped at {_max_funcs} functions (set CRG_MAX_CHANGED_FUNCS to adjust)",
        );
    }
    if yaml_paths_truncated {
        summary_parts.append(
            f"  - Warning: analysis capped at {_max_yaml_paths} YAML paths (set CRG_MAX_CHANGED_YAML_PATHS to adjust)",
        );
    }
    if json_paths_truncated {
        summary_parts.append(
            f"  - Warning: analysis capped at {_max_yaml_paths} JSON paths (set CRG_MAX_CHANGED_YAML_PATHS to adjust)",
        );
    }
    if ranges_unavailable {
        summary_parts.append(
            f"  - Warning: line-level diff unavailable, whole files scored ({ranges_unavailable})"
        );
    }
    if deletion_review.files_not_read {
        summary_parts.append(
            f"  - Note: the old version of {deletion_review.files_not_read} file(s) could not be read, so code deleted there is not listed as removed (CRG_MAX_DELETION_FILES sets how many files are read)",
        );
    }
    if churn_status == CHURN_UNAVAILABLE {
        summary_parts.append(
            f"  - Degraded: change-frequency risk unavailable (git history did not answer within {_CHURN_TIMEOUT:.3g}s; set CRG_CHURN_TIMEOUT to raise the budget). Risk scores exclude the churn term.",
        );
    }

    return {
        "summary": "\n".join(summary_parts),
        "risk_score": overall_risk,
        "changed_functions": node_risks,
        "changed_yaml_paths": yaml_path_results,
        "changed_json_paths": json_path_results,
        "affected_flows": affected["affected_flows"],
        "test_gaps": test_gaps,
        "test_gaps_total": len(test_gaps),
        "test_gaps_uncovered": uncovered_count,
        "test_gaps_indirect": indirect_count,
        "removed_symbols": deletion_review.removed,
        "removed_symbols_total": deletion_review.removed_total,
        "review_priorities": review_priorities,
        "functions_truncated": funcs_truncated,
        "yaml_paths_truncated": yaml_paths_truncated,
        "json_paths_truncated": json_paths_truncated,
        "diff_ranges_unavailable": ranges_unavailable,
        "churn_status": churn_status,
    };
}

glob BRIEF_PRIORITIES: any = 3;

def risk_label(score: float) -> str {
    return "high" if score > 0.7 else "medium" if score > 0.4 else "low";
}

def _short_name(qualified_name: str) -> str {
    return _sanitize_name(qualified_name.rsplit("::", 1)[-1]);
}

def _name_list(names: list[str], limit: int = 2) -> str {
    unique: any = `list(dict.fromkeys(name for name in names if name));
    shown: any = ", ".join(unique[:limit]);
    extra: any = len(unique) - limit;
    return f"{shown} and {extra} more" if extra > 0 else shown;
}

def _brief_priority_line(
    store: GraphStore, priority: dict[str, Any], repo_root: str | None
) -> str {
    name: any = _sanitize_name(`str(priority.get("name") or priority.get("qualified_name", "")));
    file_path: any = `str(priority.get("file_path") or "");
    if repo_root and file_path {
        try {
            file_path = Path(file_path).relative_to(Path(repo_root)).as_posix();
        } except ValueError {}
    }
    where: any = f"{file_path}:{priority["line_start"]}"
        if priority.get("line_start")
        else file_path;
    score: any = `float(priority.get("risk_score") or 0.0);
    parts: any = [name, where, f"risk {score:.2f} ({risk_label(score)})"];

    qualified_name: any = `str(priority.get("qualified_name") or "");
    callers: list[str] = [];
    tests: list[str] = [];
    if qualified_name {
        found_tests: any = store.get_transitive_tests(qualified_name, include_helper_routes=False);
        tests = [_sanitize_name(`str(`test.get("name", ""))) for `test in found_tests];
        test_qns: any = {`str(`test.get("qualified_name", "")) for `test in found_tests};
        callers = [
            _short_name(`edge.source_qualified)
            for `edge in store.get_edges_by_target(qualified_name)
            if `edge.kind == "CALLS" and `edge.source_qualified not in test_qns
        ];
    }
    parts.append(f"called by {_name_list(callers)}" if callers else "no callers found");
    parts.append(f"tested by {_name_list(tests)}" if tests else "no tests found");
    return "  ".join(parts);
}

glob limit_default_: any = BRIEF_PRIORITIES;

def format_brief(
    store: GraphStore,
    analysis: dict[str, Any],
    repo_root: str | Path | None = None,
    limit: int = limit_default_,
) -> str {
    summary: any = `str(analysis.get("summary") or "No summary available.");
    score: any = analysis.get("risk_score");
    if isinstance(score, (`int, `float)) {
        overall: any = _OVERALL_RISK_LINE.format(score);
        summary = summary.replace(overall, f"{overall} of 1.00 ({risk_label(score)})", 1);
    }
    priorities: any = [
        p
        for p in analysis.get("review_priorities") or []
        if isinstance(p, `dict)
    ][:limit];
    if not priorities {
        return summary;
    }
    `root: any = `str(repo_root) if repo_root is not None else None;
    lines: any = [summary, "", "Review first (risk out of 1.00):"];
    for (index, priority) in enumerate(priorities, 1) {
        lines.append(f"  {index}. {_brief_priority_line(store, priority, `root)}");
    }
    return "\n".join(lines);
}
