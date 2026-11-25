"""DeepSeek Harness (DSH): the MCP server row in its home patch layer.

DSH builds its plugin tree from YAML patch layers. Every profile, the Desktop
one included, applies the home-level layer ``$DSH_HOME/cordis.patch.yml`` (by
default ``~/.dsh/cordis.patch.yml``) after its own. That file is a top-level
YAML list of patch operations; an ``insert`` operation adds plugin rows, and a
row for DSH's own ``@deepseek-ai/dsh-mcp-client`` plugin starts a stdio MCP
server. See the DSH repository: ``apps/cli/README.md`` ("Profiles"),
``packages/mcp/mcp-client/README.md`` and ``docs/user/guide/mcp-memory.md``.

``skills._dsh_config_path`` finds the file; this module only reads and edits
its text. The file is written by hand and uses DSH's ``!!js`` tag, so it is
never re-serialised: the one ``insert`` operation this project owns is added,
replaced or cut out as a block of lines, and the result is parsed again before
anything is written.
"""

import builtins;

import operator;

import from __future__ { annotations }

import from collections.abc { Callable }

import from dataclasses { dataclass }

import from typing { Any }

import yaml;

glob ENTRY_ID: any = "mcp-code-review-graph";

glob PLUGIN: any = "@deepseek-ai/dsh-mcp-client";

glob SERVER_NAME: any = "code-review-graph";

glob _ROW_FIELDS: any;

glob _CONFIG_FIELDS: any;

with entry {
    _ROW_FIELDS = frozenset({"id", "name", "config"});
    _CONFIG_FIELDS = frozenset({"serverName", "transport", "command", "args"});
}

"""Wrap a ``{"command", "args"}`` server entry as a DSH MCP client row."""
def server_row(`entry: dict[str, Any]) -> dict[str, Any];

"""A value under a tag this module does not interpret, such as ``!!js``."""
@dataclass(frozen=True)
class Tagged {
    has tag: str;

    has value: Any;
}

"""Safe loader that keeps unknown tags as opaque :class:`Tagged` values.

    DSH evaluates ``!!js`` values itself; here they only have to be told apart
    from plain strings. Nothing is executed.
    """
class _PatchLoader(yaml.SafeLoader) {}

def _construct_tagged(loader: _PatchLoader, _suffix: str, `node: yaml.Node) -> Tagged;

with entry {
    _PatchLoader.add_multi_constructor("", _construct_tagged);
}

"""Indent nested lists, as the examples in DSH's documentation do."""
class _Dumper(yaml.SafeDumper) {
    def increase_indent(`flow: bool = False, indentless: bool = False) -> Any;
}

"""Parse a patch layer. Raises :class:`yaml.YAMLError` when it is not YAML."""
def load(text: str) -> Any;

def _names_us(row: Any) -> bool;

"""Return ``(operation, row)`` indexes of every row registering this server."""
def registrations(document: list[Any]) -> list[tuple[int, int]];

"""Whether *row* has exactly the shape this project writes.

    *entry_is_generated* judges the command line, so every serve command a
    release has written is recognised the same way as on other platforms.
    """
def is_generated_row(row: Any, entry_is_generated: Callable[[Any], bool]) -> bool;

"""Whether the operation holds nothing but one row (so it can be cut out whole)."""
def _owned_operation(document: list[Any], op_index: int) -> bool;

"""Render the ``insert`` operation for *row* as YAML lines."""
def render_operation(row: dict[str, Any], indent: int = 0) -> str;

"""The layer cannot be edited without risking what is already in it."""
obj PatchError(ValueError) {
    def __repr__ -> str;

    def __eq__(other: any) -> bool;

    def __hash__ -> int;
}

def _root(raw: str) -> yaml.Node | None;

"""Return ``(first, end, indent)``: the lines of one top-level operation.

    Comments and blank lines after the operation belong to what follows and
    are left outside the span.
    """
def _operation_lines(raw: str, op_index: int) -> tuple[int, int, int];

def _list_indent(raw: str) -> int;

def _without_operation(document: list[Any], op_index: int) -> list[Any];

"""Refuse an edit whose result does not parse to exactly *expected*."""
def _check(rewritten: str, expected: list[Any]) -> None;

"""Parse a layer into its operations, treating an empty file as none."""
def parse(raw: str) -> list[Any];

"""Return *raw* with the operation for *row* added, or put at *replace*.

    *replace* is the index of an operation that holds only this project's row.
    """
def with_row(raw: str, row: dict[str, Any], replace: int | None) -> str;

"""Return *raw* without the operation at *op_index*.

    An emptied layer becomes ``[]``: DSH refuses a layer that is not a list.
    """
def without_row(raw: str, op_index: int) -> str;

"""Parse *raw* and return the document with every row registering this server."""
def find_owned(raw: str) -> tuple[list[Any], list[tuple[int, int]]];

"""Return the operation uninstall can cut out whole, or None."""
def removable(document: list[Any], found: list[tuple[int, int]]) -> int | None;
