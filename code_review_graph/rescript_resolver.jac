"""Post-build pass that resolves ReScript cross-module references.

The per-file parser emits CALLS/IMPORTS_FROM edges with bare targets like
``LogicUtils.safeParse`` because the parser only sees one file at a time.
This module runs after ``full_build`` / incremental updates and rewrites
those targets to canonical qualified names like
``<abs-path>/LogicUtils.res::safeParse`` so ``callers_of``,
``get_impact_radius`` and ``importers_of`` work correctly across files.

Resolutions performed:
    1. ``Module.fn`` / ``Module.Sub.fn`` CALLS edges → canonical node
       when a ``.res`` / ``.resi`` file with matching basename exists.
    2. Bare ``fn(...)`` CALLS edges in a file that ``open`` / ``include``\\s
       a module → canonical node in that module's file.
    3. IMPORTS_FROM edges targeting a module name (open / include / jsx /
       module_alias / external_module) → the target file path, so
       ``importers_of(<path>)`` finds every consuming file.

Only the ``target_qualified`` column is updated, except that a bare call bound
through an ``open`` / ``include`` also records that module in
``extra.rescript_open_module``: the source did not name it, so the edge is an
inference. Source and edge kind are preserved. Edges that cannot be resolved
are left unchanged.
"""

import from __future__ { annotations }

import json;

import logging;

import from pathlib { Path }

import from typing { TYPE_CHECKING }

glob logger: any;

with entry {
    logger = logging.getLogger(__name__);
}

"""Resolve ReScript cross-module targets in the graph store.

    Safe to call multiple times: already-resolved edges (targets containing
    ``::``) are skipped.

    Returns a dict with resolution counts for telemetry.
    """
def resolve_rescript_cross_module(store: GraphStore) -> dict;

"""Resolve a CALLS edge's ``target_qualified`` to a canonical qualified
    node name, plus the opened module that supplied it when the call named
    none. Returns ``(None, None)`` when no resolution is possible.
    """
def _resolve_call_target(
    target: str,
    file_path: str,
    basename_to_path: dict[str, str],
    opens_by_file: dict[str, list[str]],
    store: GraphStore,
) -> tuple[str | None, str | None];

"""Given ``LogicUtils.foo.bar``, try ``file::foo.bar`` then
    ``file::Foo.bar`` then ``file::foo``. Return the first one that
    corresponds to an existing node.
    """
def _pick_existing_qualified(target_file: str, rest: str, store: GraphStore) -> str | None;
