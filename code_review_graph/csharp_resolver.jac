"""Bind C# calls using declaration identity and lexical namespace evidence.

Raw references survive binding: every pass can revoke a previously inferred
edge when declarations or usings change. This is a structural binder, not a
C# compiler; unsupported type expressions and ambiguous declarations stay raw.
"""

import operator;

import from __future__ { annotations }

import json;

import os;

import from contextlib { contextmanager }

import from functools { lru_cache }

import from pathlib { Path }

import from typing { TYPE_CHECKING, Iterator }

"""Commit a pass's CALLS, TESTED_BY and flow-marker writes together.

    The connection autocommits, so without this an interrupted pass could
    leave a rebound call with a stale mirror or no flow marker, and the next
    pass would see the call already rebound and skip the rest.
    """
@contextmanager
def _binding_transaction(store: GraphStore) -> Generator[any, any, any];

def _extra(raw: str | None) -> dict;

def _parents(name: str) -> Generator[any, any, any];

def _join(parent: str, name: str) -> str;

glob _CLOSING: any = {"<": ">", "(": ")", "[": "]"};

"""Split on *separator* at nesting depth zero, or ``None`` if unbalanced."""
def _split(text: str, separator: str) -> list[str] | None;

"""Return how many type arguments *arguments* supplies, ``<`` excluded."""
def _arity(arguments: str) -> int | None;

"""Return the declaration key a type reference names, or ``None``.

    Generic declarations are keyed by arity — ``App.Box`1`` — because that is
    what distinguishes ``Box`` from ``Box<T>``. Erasing the arguments instead
    would let a reference select a declaration it does not name.
    """
def _type_key(reference: str) -> str | None;

def resolve_csharp_calls(store: GraphStore, repo_root: Path | None = None) -> dict;

def _set_call(store: GraphStore, row, target: str, extra: dict) -> bool;

"""Restore raw incoming calls before permanent deletion removes their targets."""
def restore_csharp_references(store: GraphStore, deleted_files: list[str]) -> None;
