import from __future__ { annotations }

import builtins, operator;

import from collections.abc { Callable }

import from dataclasses { dataclass }

import from typing { Any }

import yaml;

glob ENTRY_ID: any = "mcp-code-review-graph";

glob PLUGIN: any = "@deepseek-ai/dsh-mcp-client";

glob SERVER_NAME: any = "code-review-graph";

glob _ROW_FIELDS: any = frozenset({"id", "name", "config"});

glob _CONFIG_FIELDS: any = frozenset({"serverName", "transport", "command", "args"});

def server_row(`entry: dict[str, Any]) -> dict[str, Any] {
    return {
        "id": ENTRY_ID,
        "name": PLUGIN,
        "config": {
            "serverName": SERVER_NAME,
            "transport": "stdio",
            "command": `entry["command"],
            "args": `list(`entry["args"]),
        },
    };
}

@dataclass(frozen=True)
class Tagged {
    has tag: str;

    has value: Any;
}

class _PatchLoader(yaml.SafeLoader) {}

def _construct_tagged(loader: _PatchLoader, _suffix: str, `node: yaml.Node) -> Tagged {
    if isinstance(`node, yaml.ScalarNode) {
        value: Any = loader.construct_scalar(`node);
    } elif isinstance(`node, yaml.SequenceNode) {
        value = loader.construct_sequence(`node, deep=True);
    } else {
        value = loader.construct_mapping(`node, deep=True);
    }
    return Tagged(`node.tag, value);
}

with entry {
    _PatchLoader.add_multi_constructor("", _construct_tagged);
}

class _Dumper(yaml.SafeDumper) {
    def increase_indent(`flow: bool = False, indentless: bool = False) -> Any {
        return super.increase_indent(`flow, False);
    }
}

def load(text: str) -> Any {
    loader: any = _PatchLoader(text);
    try {
        return loader.get_single_data();
    } finally {
        loader.dispose();
    }
}

def _names_us(row: Any) -> bool {
    if not isinstance(row, `dict) {
        return False;
    }
    if row.get("id") == ENTRY_ID {
        return True;
    }
    config: any = row.get("config");
    return operator.eq(row.get("name"), PLUGIN)
        and isinstance(config, `dict)
        and operator.eq(config.get("serverName"), SERVER_NAME);
}

def registrations(document: list[Any]) -> list[tuple[int, int]] {
    op_index: any;
    found: list[tuple[int, int]] = [];
    operation: any;
    for item_ in enumerate(document) {
        (op_index, operation) = item_;
        rows: any = operation.get("insert") if isinstance(operation, `dict) else None;
        if not isinstance(rows, `list) {
            continue;
        }
        found.extend(
            (op_index, row_index) for (row_index, row) in enumerate(rows) if _names_us(row)
        );
    }
    return found;
}

def is_generated_row(row: Any, entry_is_generated: Callable[[Any], bool]) -> bool {
    if not isinstance(row, `dict) or `set(row) != _ROW_FIELDS {
        return False;
    }
    config: any = row["config"];
    if row["id"] != ENTRY_ID or row["name"] != PLUGIN or not isinstance(config, `dict) {
        return False;
    }
    if not `set(config) <= _CONFIG_FIELDS {
        return False;
    }
    if config.get("serverName") != SERVER_NAME or config.get("transport") != "stdio" {
        return False;
    }
    return entry_is_generated({key: config[key] for key in ("command", "args") if key in config});
}

def _owned_operation(document: list[Any], op_index: int) -> bool {
    operation: any = document[op_index];
    return isinstance(operation, `dict)
        and operator.eq(`set(operation), {"insert"})
        and isinstance(operation["insert"], `list)
        and operator.eq(len(operation["insert"]), 1);
}

def render_operation(row: dict[str, Any], indent: int = 0) -> str {
    text: any = yaml.dump(
        [{"insert": [row]}],
        Dumper=_Dumper,
        default_flow_style=False,
        sort_keys=False,
        allow_unicode=True,
    );
    pad: any = " " * indent;
    return "".join(f"{pad}{line}" for line in text.splitlines(keepends=True));
}

obj PatchError(ValueError) {
    def __repr__ -> str {
        return (getattr(builtins.super(PatchError, self), "__repr__") as any)();
    }

    def __eq__(other: any) -> bool {
        return self is other;
    }

    def __hash__ -> int {
        return id(self);
    }
}

def _root(raw: str) -> yaml.Node | None {
    return yaml.compose(raw, Loader=_PatchLoader);
}

def _operation_lines(raw: str, op_index: int) -> tuple[int, int, int] {
    `root: any = _root(raw);
    if not isinstance(`root, yaml.SequenceNode) or `root.flow_style {
        raise PatchError("the patch list is not a block list");
    }
    lines: any = raw.splitlines(keepends=True);
    items: any = `root.value;
    first: any = items[op_index].start_mark.line;
    if not lines[first].lstrip().startswith("-") {
        raise PatchError("the operation does not start its own line");
    }
    indent: any = len(lines[first]) - len(lines[first].lstrip());
    end: any = items[op_index + 1].start_mark.line if op_index + 1 < len(items) else len(lines);
    while end > first + 1 {
        line: any = lines[end - 1];
        stripped: any = line.strip();
        if stripped
            and not (stripped.startswith("#") and len(line) - len(line.lstrip()) <= indent)
        {
            break;
        }
        end -= 1;
    }
    return (first, end, indent);
}

def _list_indent(raw: str) -> int {
    `root: any = _root(raw);
    if isinstance(`root, yaml.SequenceNode) and `root.value and not `root.flow_style {
        line: any = raw.splitlines()[`root.value[0].start_mark.line];
        return len(line) - len(line.lstrip());
    }
    return 0;
}

def _without_operation(document: list[Any], op_index: int) -> list[Any] {
    return [operation for (index, operation) in enumerate(document) if index != op_index];
}

def _check(rewritten: str, expected: list[Any]) {
    try {
        parsed: any = load(rewritten);
    } except yaml.YAMLError as exc {
        raise PatchError(f"the edit would not parse ({exc.__class__.__name__})") from exc;
    }
    if parsed != expected {
        raise PatchError("the edit would change more than this project's row");
    }
}

def parse(raw: str) -> list[Any] {
    try {
        document: any = load(raw);
    } except yaml.YAMLError as exc {
        raise PatchError(f"it is not valid YAML ({exc.__class__.__name__})") from exc;
    }
    if document is None {
        return [];
    }
    if not isinstance(document, `list) {
        raise PatchError(
            f"it is a {`type(document).__name__}, not the list of patch operations DSH reads"
        );
    }
    return document;
}

def with_row(raw: str, row: dict[str, Any], replace: int | None) -> str {
    document: any = parse(raw);
    if replace is not None {
        first: any;
        end: any;
        indent: any;
        (first, end, indent) = _operation_lines(raw, replace) as any;
        lines: any = raw.splitlines(keepends=True);
        rewritten: any = "".join(lines[:first] + [render_operation(row, indent)] + lines[end:]);
        expected: any = `list(document);
        expected[replace] = {"insert": [row]};
        _check(rewritten, expected);
        return rewritten;
    }

    `root: any = _root(raw);
    if isinstance(`root, yaml.SequenceNode) and `root.flow_style {
        if `root.value {
            raise PatchError("the patch list is written in flow style ([...])");
        }
        start: any;
        (start, end) = (`root.start_mark.index, `root.end_mark.index);
        line_start: any = raw.rfind("\n", 0, start) + 1;
        line_end: any = raw.find("\n", end);
        line_end = len(raw) if line_end == -1 else line_end;
        if raw[line_start:start].strip() or raw[end:line_end].strip() {
            raise PatchError("the empty list [] shares its line with other text");
        }
        rewritten = raw[:line_start] + render_operation(row) + raw[line_end + 1:];
    } else {
        prefix: any = raw if not raw or raw.endswith("\n") else raw + "\n";
        rewritten = prefix + render_operation(row, _list_indent(raw));
    }
    _check(rewritten, [*document, {"insert": [row]}]);
    return rewritten;
}

def without_row(raw: str, op_index: int) -> str {
    document: any = parse(raw);
    first: any;
    end: any;
    _indent: any;
    (first, end, _indent) = _operation_lines(raw, op_index) as any;
    lines: any = raw.splitlines(keepends=True);
    rewritten: any = "".join(lines[:first] + lines[end:]);
    remaining: any = _without_operation(document, op_index);
    if not remaining {
        try {
            emptied: any = load(rewritten);
        } except yaml.YAMLError as exc {
            raise PatchError(f"the edit would not parse ({exc.__class__.__name__})") from exc;
        }
        if emptied is None {
            if rewritten and not rewritten.endswith("\n") {
                rewritten += "\n";
            }
            rewritten += "[]\n";
        }
    }
    _check(rewritten, remaining);
    return rewritten;
}

def find_owned(raw: str) -> tuple[list[Any], list[tuple[int, int]]] {
    document: any = parse(raw);
    return (document, registrations(document));
}

def removable(document: list[Any], found: list[tuple[int, int]]) -> int | None {
    if len(found) != 1 {
        return None;
    }
    op_index: any;
    _row_index: any;
    (op_index, _row_index) = found[0] as any;
    return op_index if _owned_operation(document, op_index) else None;
}
