"""Shared, value-free handling for Spring configuration property keys."""

import from __future__ { annotations }

import re;

import from pathlib { Path }

glob _SPRING_CONFIG_NAME: any;

with entry {
    _SPRING_CONFIG_NAME = re.compile(
        "^application(?:-[A-Za-z0-9_.-]+)?\\.(?:properties|ya?ml)$", re.IGNORECASE
    );
}

"""Return whether *path* uses Spring Boot's application-file convention."""
def is_spring_config_path(path: Path) -> bool;

"""Canonicalize relaxed-binding spellings without inspecting their values."""
def normalize_spring_config_key(key: str) -> str;
