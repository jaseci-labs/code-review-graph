"""Where tests find the package's files now that its source is Jac.

``neojac test`` runs the suite from a copy of the repository that holds no
``code_review_graph/`` directory, against the package as neojac builds it.
Tests that read the package's files get them here:

- ``package_dir()``: the installed package, for the data files the wheel ships.
- ``python_source(module)``: the Python neojac emits for a module, the code
  that actually runs, for tests that inspect a module's source.
"""

from __future__ import annotations

import ast
import functools
import importlib
import shutil
import subprocess
import tempfile
from pathlib import Path


def package_dir() -> Path:
    import code_review_graph

    return Path(code_review_graph.__file__).resolve().parent


def project_root() -> Path:
    """The neojac project this suite belongs to: the nearest directory above
    the tests that holds both ``jac.toml`` and the package's sources."""
    here = Path(__file__).resolve().parent
    for candidate in (here, *here.parents):
        if (candidate / "jac.toml").is_file() and (candidate / "code_review_graph").is_dir():
            return candidate
    raise RuntimeError(f"no neojac project with code_review_graph/ above {here}")


@functools.lru_cache(maxsize=None)
def emitted_package() -> Path:
    """The package's Python as ``neojac emit-py`` writes it, once a session."""
    neojac = shutil.which("neojac")
    if neojac is None:
        raise RuntimeError("neojac is not on PATH")
    out = Path(tempfile.mkdtemp(prefix="crg-emit-"))
    subprocess.run(
        [neojac, "emit-py", "code_review_graph", "-o", str(out)],
        cwd=project_root(), check=True, capture_output=True, text=True,
    )
    return out / "py" / "code_review_graph"


def python_source(module: str | object) -> str:
    """The emitted Python of ``module`` (a dotted name or the module itself)."""
    name = module if isinstance(module, str) else module.__name__
    parts = name.split(".")[1:]
    base = emitted_package().joinpath(*parts) if parts else emitted_package()
    path = base / "__init__.py" if base.is_dir() else base.with_suffix(".py")
    return path.read_text(encoding="utf-8")


def function_source(func: object) -> str:
    """The emitted Python of one function, found by name in its module."""
    target = getattr(func, "__wrapped__", func)
    name = target.__name__
    source = python_source(importlib.import_module(target.__module__))
    for node in ast.walk(ast.parse(source)):
        if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef)) and node.name == name:
            return ast.get_source_segment(source, node, padded=True) or ""
    raise LookupError(f"{name} is not in the emitted {target.__module__}")
