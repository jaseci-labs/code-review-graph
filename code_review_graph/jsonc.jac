import operator;

import json;

import from dataclasses { dataclass }

import from typing { Any, Iterable, Sequence }

glob __all__: any = [
    "Element",
    "Member",
    "Token",
    "array_elements",
    "find_value",
    "has_comments",
    "has_unclosed_comment",
    "object_members",
    "remove_paths",
    "removal_ranges",
    "set_member",
    "skip_value",
    "tokenize",
    "value_has_comments",
];

@dataclass(frozen=True)
class Token {
    has kind: str;

    has start: int;

    has end: int;

    has value: str | None = None;
}

@dataclass(frozen=True)
class Member {
    has key: str;

    has key_index: int;

    has value_index: int;

    has value_end: int;

    has comma_index: int | None;
}

@dataclass(frozen=True)
class Element {
    has value_index: int;

    has value_end: int;

    has comma_index: int | None;
}

def has_comments(raw: str) -> bool;
def has_unclosed_comment(raw: str) -> bool;
def tokenize(raw: str) -> list[Token];
def skip_value(tokens: Sequence[Token], index: int) -> int;
def object_members(tokens: Sequence[Token], index: int) -> list[Member];
def array_elements(tokens: Sequence[Token], index: int) -> list[Element];
def find_value(tokens: Sequence[Token], path: Sequence[str | int]) -> int;
def removal_ranges(tokens: Sequence[Token], path: Sequence[str | int]) -> list[tuple[int, int]];
def _in_ranges(position: int, ranges: list[tuple[int, int]]) -> bool;

def remove_paths(raw: str, paths: Iterable[Sequence[str | int]]) -> str;
def _column_of(raw: str, offset: int) -> int;
def _line_indent(raw: str, offset: int) -> int;
def _render(value: Any, column: int) -> str;
def _past_trailing_comment(raw: str, offset: int) -> int;
def value_has_comments(raw: str, path: Sequence[str | int]) -> bool;
def set_member(raw: str, path: Sequence[str], value: Any) -> str;
