import from __future__ { annotations }

import operator;

import json;

import os;

import from contextlib { contextmanager }

import from functools { lru_cache }

import from pathlib { Path }

import from typing { TYPE_CHECKING, Iterator }
@contextmanager
def _binding_transaction(store: GraphStore) -> Generator[any, any, any];

def _extra(raw: str | None) -> dict;

def _parents(name: str) -> Generator[any, any, any];

def _join(parent: str, name: str) -> str;

glob _CLOSING: any = {"<": ">", "(": ")", "[": "]"};
def _split(text: str, separator: str) -> list[str] | None;
def _arity(arguments: str) -> int | None;
def _type_key(reference: str) -> str | None;

def resolve_csharp_calls(store: GraphStore, repo_root: Path | None = None) -> dict;

def _set_call(store: GraphStore, row, target: str, extra: dict) -> bool;
def restore_csharp_references(store: GraphStore, deleted_files: list[str]);
