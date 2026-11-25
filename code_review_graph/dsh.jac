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

def server_row(`entry: dict[str, Any]) -> dict[str, Any];

@dataclass(frozen=True)
class Tagged {
    has tag: str;

    has value: Any;
}

class _PatchLoader(yaml.SafeLoader) {}

def _construct_tagged(loader: _PatchLoader, _suffix: str, `node: yaml.Node) -> Tagged;

with entry {
    _PatchLoader.add_multi_constructor("", _construct_tagged);
}

class _Dumper(yaml.SafeDumper) {
    def increase_indent(`flow: bool = False, indentless: bool = False) -> Any;
}

def load(text: str) -> Any;

def _names_us(row: Any) -> bool;
def registrations(document: list[Any]) -> list[tuple[int, int]];
def is_generated_row(row: Any, entry_is_generated: Callable[[Any], bool]) -> bool;
def _owned_operation(document: list[Any], op_index: int) -> bool;
def render_operation(row: dict[str, Any], indent: int = 0) -> str;

obj PatchError(ValueError) {
    def __repr__ -> str;

    def __eq__(other: any) -> bool;

    def __hash__ -> int;
}

def _root(raw: str) -> yaml.Node | None;
def _operation_lines(raw: str, op_index: int) -> tuple[int, int, int];

def _list_indent(raw: str) -> int;

def _without_operation(document: list[Any], op_index: int) -> list[Any];
def _check(rewritten: str, expected: list[Any]);
def parse(raw: str) -> list[Any];
def with_row(raw: str, row: dict[str, Any], replace: int | None) -> str;
def without_row(raw: str, op_index: int) -> str;
def find_owned(raw: str) -> tuple[list[Any], list[tuple[int, int]]];
def removable(document: list[Any], found: list[tuple[int, int]]) -> int | None;
