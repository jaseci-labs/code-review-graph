import from __future__ { annotations }

import re;

import from pathlib { Path }

glob _SPRING_CONFIG_NAME: any = re.compile(
    "^application(?:-[A-Za-z0-9_.-]+)?\\.(?:properties|ya?ml)$", re.IGNORECASE
);

def is_spring_config_path(path: Path) -> bool {
    return `bool(_SPRING_CONFIG_NAME.fullmatch(path.name));
}

def normalize_spring_config_key(key: str) -> str {
    normalized: list[str] = [];
    for segment in key.strip().split(".") {
        `match: any = re.fullmatch("(.*?)(\\[[0-9]+\\])?", segment);
        base: any = `match.group(1) if `match else segment;
        index: any = `match.group(2) or "" if `match else "";
        tokens: any = [token for token in re.split("[-_]+", base) if token];
        if not tokens {
            normalized.append(index);
            continue;
        }
        head: any = tokens[0].lower() if base.isupper() or len(tokens) > 1 else tokens[0];
        tail: any = "".join(token[:1].upper() + token[1:].lower() for token in tokens[1:]);
        normalized.append(f"{head}{tail}{index}");
    }
    return ".".join(normalized);
}
