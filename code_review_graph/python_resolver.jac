import from __future__ { annotations }

import operator, json, logging, sys;

import from typing { TYPE_CHECKING }

glob logger: any = logging.getLogger(__name__);

def _shadows_stdlib_from_a_package(module: str, candidate: str, python_files: set[str]) -> bool;
def resolve_python_imports(store: GraphStore) -> dict[str, int];
