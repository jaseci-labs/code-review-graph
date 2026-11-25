import from __future__ { annotations }

import from pathlib { Path }

import from typing { Any }

glob _FETCH_ALL: any;

glob _MAX_FLOWS: any;

glob _MAX_FLOW_STEPS: any;

glob _MAX_FLOW_SOURCE_LINES: any;

with entry {
    _FETCH_ALL = 10 ** 9;
    _MAX_FLOWS = 200;
    _MAX_FLOW_STEPS = 200;
    _MAX_FLOW_SOURCE_LINES = 2000;
}

def list_flows(
    repo_root: str | None = None,
    sort_by: str = "criticality",
    limit: int = 50,
    kind: str | None = None,
    detail_level: str = "standard",
) -> dict[str, Any];
def get_flow(
    flow_id: int | None = None,
    flow_name: str | None = None,
    include_source: bool = False,
    repo_root: str | None = None,
    max_steps: int = 50,
    max_source_lines: int = 400,
) -> dict[str, Any];
