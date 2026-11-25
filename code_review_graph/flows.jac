import from __future__ { annotations }

import json, logging, re;

import from collections { deque }

import from pathlib { Path }

import from typing { Iterable, Optional }

glob logger: any = logging.getLogger(__name__);

glob _SQL_BATCH: any = 450;

def _escape_like_literal(value: str) -> str;
def expand_changed_file_paths(
    store: GraphStore, changed_files: Iterable[str], repo_root: str | Path | None = None
) -> list[str];
def _flows_touching_files(
    store: GraphStore, file_paths: list[str]
) -> tuple[list[int], list[int], set[str]];
def _flow_node_qns(store: GraphStore, flow_ids: list[int]) -> set[str];
def capture_affected_flow_entry_points(store: GraphStore, file_paths: list[str]) -> set[str];
def capture_flow_node_ids(store: GraphStore, file_paths: list[str]) -> dict[int, str];
def remap_flow_node_ids(store: GraphStore, old_ids: dict[int, str]) -> int;
def clear_flows_for_files(store: GraphStore, file_paths: list[str]) -> set[str];
def purge_orphan_flow_data(store: GraphStore) -> int;

glob _FRAMEWORK_DECORATOR_PATTERNS: list[re.Pattern[str]] = [
    re.compile("app\\.(get|post|put|delete|patch|route|websocket|on_event)", re.IGNORECASE),
    re.compile("router\\.(get|post|put|delete|patch|route)", re.IGNORECASE),
    re.compile("blueprint\\.(route|before_request|after_request)", re.IGNORECASE),
    re.compile("(before|after)_(request|response)", re.IGNORECASE),
    re.compile("click\\.(command|group)", re.IGNORECASE),
    re.compile("\\w+\\.(command|group)\\b", re.IGNORECASE),
    re.compile("(field|model)_(serializer|validator)", re.IGNORECASE),
    re.compile("(celery\\.)?(task|shared_task|periodic_task)", re.IGNORECASE),
    re.compile("receiver", re.IGNORECASE),
    re.compile("api_view", re.IGNORECASE),
    re.compile("\\baction\\b", re.IGNORECASE),
    re.compile("pytest\\.(fixture|mark)"),
    re.compile(
        "^(?:[\\w.]+\\.)?(?:Test|TestFactory|TestTemplate|ParameterizedTest|RepeatedTest|BeforeEach|AfterEach|BeforeAll|AfterAll|Before|After|BeforeClass|AfterClass|BeforeMethod|AfterMethod|BeforeSuite|AfterSuite|BeforeTest|AfterTest|BeforeGroups|AfterGroups|DataProvider)(?:\\s*\\(.*)?$",
        re.DOTALL,
    ),
    re.compile("(override_settings|modify_settings)", re.IGNORECASE),
    re.compile("(event\\.)?listens_for", re.IGNORECASE),
    re.compile("(Get|Post|Put|Delete|Patch|RequestMapping)Mapping", re.IGNORECASE),
    re.compile("(Scheduled|EventListener|Bean|Configuration)", re.IGNORECASE),
    re.compile("KafkaListener", re.IGNORECASE),
    re.compile("(WorkflowMethod|ActivityMethod)", re.IGNORECASE),
    re.compile("(Component|Injectable|Controller|Module|Guard|Pipe)", re.IGNORECASE),
    re.compile("(Subscribe|Mutation|Query|Resolver)", re.IGNORECASE),
    re.compile("(app|router)\\.(get|post|put|delete|patch|use|all)\\b"),
    re.compile("(HiltViewModel|AndroidEntryPoint|Inject)", re.IGNORECASE),
    re.compile("\\w+\\.(tool|tool_plain|system_prompt|result_validator)\\b", re.IGNORECASE),
    re.compile("^tool\\b"),
    re.compile("\\w+\\.(middleware|exception_handler|on_exception)\\b", re.IGNORECASE),
    re.compile("\\w+\\.route\\b", re.IGNORECASE),
];

glob _OVERRIDE_DECORATOR: any = re.compile("^(?:java\\.lang\\.)?Override$");

glob _ENTRY_NAME_PATTERNS: list[re.Pattern[str]] = [
    re.compile("^main$"),
    re.compile("^__main__$"),
    re.compile("^test_"),
    re.compile("^Test[A-Z]"),
    re.compile("^on_"),
    re.compile("^handle_"),
    re.compile("^handler$"),
    re.compile("^handle$"),
    re.compile("^lambda_handler$"),
    re.compile("^upgrade$"),
    re.compile("^downgrade$"),
    re.compile("^lifespan$"),
    re.compile("^get_db$"),
    re.compile("^on(Create|Start|Resume|Pause|Stop|Destroy|Bind|Receive)"),
    re.compile("^do(Get|Post|Put|Delete)$"),
    re.compile("^do_(GET|POST|PUT|DELETE|PATCH|HEAD|OPTIONS)$"),
    re.compile("^log_message$"),
    re.compile("^(middleware|errorHandler)$"),
    re.compile(
        "^ng(OnInit|OnChanges|OnDestroy|DoCheck|AfterContentInit|AfterContentChecked|AfterViewInit|AfterViewChecked)$",
    ),
    re.compile("^(transform|writeValue|registerOnChange|registerOnTouched|setDisabledState)$"),
    re.compile("^(canActivate|canDeactivate|canActivateChild|canLoad|canMatch|resolve)$"),
    re.compile(
        "^(componentDidMount|componentDidUpdate|componentWillUnmount|shouldComponentUpdate|render)$"
    ),
];

glob _LANGUAGE_ENTRY_NAME_PATTERNS: dict[str, tuple[re.Pattern[str], ...]] = {
    "php": (re.compile("^(boot|register)$"), re.compile("^__invoke$")),
};

def _has_framework_decorator(`node: GraphNode) -> bool;
def _has_override_decorator(`node: GraphNode) -> bool;
def _matches_entry_name(`node: GraphNode) -> bool;
def detect_entry_points(store: GraphStore, include_tests: bool = False) -> list[GraphNode];
def _trace_single_flow(adj: FlowAdjacency, ep: GraphNode, max_depth: int = 15) -> Optional[dict];
def trace_flows(store: GraphStore, max_depth: int = 15, include_tests: bool = False) -> list[dict];
def compute_criticality(`flow: dict, adj: FlowAdjacency) -> float;
def store_flows(store: GraphStore, flows: list[dict]) -> int;
def incremental_trace_flows(
    store: GraphStore,
    changed_files: list[str],
    max_depth: int = 15,
    repo_root: str | Path | None = None,
    entry_point_qns: Iterable[str] | None = None,
) -> int;
def get_flows(store: GraphStore, sort_by: str = "criticality", limit: int = 50) -> list[dict];
def get_flow_by_id(store: GraphStore, flow_id: int) -> Optional[dict];
def get_affected_flows(store: GraphStore, changed_files: list[str]) -> dict;
