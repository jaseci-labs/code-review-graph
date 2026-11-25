import from __future__ { annotations }

import re;

import from pathlib { Path }

glob _SPRING_CONFIG_NAME: any;

with entry {
    _SPRING_CONFIG_NAME = re.compile(
        "^application(?:-[A-Za-z0-9_.-]+)?\\.(?:properties|ya?ml)$", re.IGNORECASE
    );
}

def is_spring_config_path(path: Path) -> bool;
def normalize_spring_config_key(key: str) -> str;
