"""Post-build resolution for repository-local Python imports."""

import operator;

import from __future__ { annotations }

import json;

import logging;

import sys;

import from typing { TYPE_CHECKING }

glob logger: any;

with entry {
    logger = logging.getLogger(__name__);
}

"""Whether *candidate* only looks like the standard library's *module*.

    ``src/flask/typing.py`` ends in ``typing``, but to be what ``import typing``
    loads, ``src/flask`` would have to be on ``sys.path``, and a package's own
    folder is not.
    """
def _shadows_stdlib_from_a_package(module: str, candidate: str, python_files: set[str]) -> bool;

"""Resolve raw Python modules by unique repository-wide path suffix."""
def resolve_python_imports(store: GraphStore) -> dict[str, int];
