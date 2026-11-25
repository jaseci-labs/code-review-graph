impl _cleanup_expired -> int {
    rid: any;
    now: any = time.time();
    expired: any = [
        rid
        for (rid, r) in _pending_refactors.items()
        if now - r["created_at"] > REFACTOR_EXPIRY_SECONDS
    ];
    for rid in expired {
        del _pending_refactors[rid];
    }
    for rid in [rid for rid in _followed_edit_files if rid not in _pending_refactors] {
        del _followed_edit_files[rid];
    }
    return len(expired);
}

impl _ident_pattern(name: str) -> re.Pattern[str] {
    left: any = "(?<![\\w$])" if re.match("[\\w$]", name[:1]) else "";
    right: any = "(?![\\w$])" if re.match("[\\w$]", name[-1:]) else "";
    return re.compile(left + re.escape(name) + right);
}

impl _decode_source(data: bytes) -> Optional[tuple[str, bool]] {
    try {
        text: any = data.decode("utf-8");
    } except UnicodeDecodeError {
        return None;
    }
    if text.startswith("﻿") {
        return (text[1:], True);
    }
    return (text, False);
}

impl _Source.init(path: str, text: str) {
    self.path = path;
    self.text = text;
    self.lines = text.split("\n");
    self.data = text.encode("utf-8");
    self._py_tree = None;
    self._py_parsed = False;
    self._py_tokens = None;
    self._py_tokens_for = None;
    self._py_calls = {};
    self._py_calls_for = None;
}

impl _Source.line(lineno: int) -> str {
    if 1 <= lineno <= len(self.lines) {
        return self.lines[lineno - 1];
    }
    return "";
}

impl _Source.char_col(lineno: int, byte_col: int) -> int {
    raw: any = self.line(lineno).encode("utf-8")[:byte_col];
    return len(raw.decode("utf-8", errors="replace"));
}

impl _Source.python_tree -> Optional[ast.Module] {
    if not self._py_parsed {
        self._py_parsed = True;
        if "\r" not in self.text.replace("\r\n", "") {
            try {
                with warnings.catch_warnings() {
                    warnings.simplefilter("ignore");
                    self._py_tree = ast.parse(self.text, filename=self.path);
                }
            } except (SyntaxError, ValueError, RecursionError, MemoryError) {
                self._py_tree = None;
            }
        }
    }
    return self._py_tree;
}

impl _Source.python_name_tokens(name: str) -> Optional[list[tuple[int, int, bool]]] {
    if self._py_tokens_for != name {
        self._py_tokens_for = name;
        found: list[tuple[int, int, bool]] = [];
        prev: any = "";
        `skip: any = {
            tokenize.NL,
            tokenize.NEWLINE,
            tokenize.COMMENT,
            tokenize.INDENT,
            tokenize.DEDENT,
        };
        try {
            for tok in tokenize.generate_tokens(io.StringIO(self.text).readline) {
                if tok.type == tokenize.NAME and tok.string == name {
                    found.append((tok.start[0], tok.start[1], operator.eq(prev, ".")));
                }
                if tok.type not in `skip {
                    prev = tok.string;
                }
            }
            if sys.version_info < (3, 12) {
                found.extend(self._python_fstring_names(name));
            }
            self._py_tokens = found;
        } except (tokenize.TokenError, SyntaxError) {
            self._py_tokens = None;
        }
    }
    return self._py_tokens;
}

impl _Source._python_name_at(`node: ast.AST, name: str) -> Optional[tuple[int, int, bool]] {
    if isinstance(`node, ast.Name) and `node.id == name {
        return (`node.lineno, self.char_col(`node.lineno, `node.col_offset), False);
    }
    if isinstance(`node, ast.Attribute)
        and `node.attr == name
        and `node.end_lineno is not None
        and `node.end_col_offset is not None
    {
        start: any = `node.end_col_offset - len(name.encode("utf-8"));
        return (`node.end_lineno, self.char_col(`node.end_lineno, start), True);
    }
    return None;
}

impl _Source._python_fstring_names(name: str) -> list[tuple[int, int, bool]] {
    tree: any = self.python_tree();
    found: set[tuple[int, int, bool]] = set[any]();
    for `node in ast.walk(tree) if tree is not None else () {
        if isinstance(`node, ast.JoinedStr) {
            for inner in ast.walk(`node) {
                site: any = self._python_name_at(inner, name);
                if site is not None {
                    found.add(site);
                }
            }
        }
    }
    return sorted(found);
}

impl _Source.python_call_names(name: str) -> dict[int, list[tuple[int, int, bool]]] {
    if self._py_calls_for != name {
        self._py_calls_for = name;
        calls: dict[int, list[tuple[int, int, bool]]] = {};
        tree: any = self.python_tree();
        for `node in ast.walk(tree) if tree is not None else () {
            if isinstance(`node, ast.Call) {
                site: any = self._python_name_at(`node.func, name);
                if site is not None {
                    calls.setdefault(`node.lineno, []).append(site);
                }
            }
        }
        self._py_calls = calls;
    }
    return self._py_calls;
}

impl _Source.__repr__ -> str {
    return (getattr(builtins.object, "__repr__") as any)(self);
}

impl _Source.__eq__(other: any) -> bool {
    return self is other;
}

impl _Source.__hash__ -> int {
    return id(self);
}

impl _Sources.init(repo_root: Optional[str]) {
    self._root = repo_root;
    self._files = {};
    self._trees = {};
    self._parser = None;
}

impl _Sources.get(path: str) -> Optional[_Source] {
    if path not in self._files {
        source: Optional[_Source] = None;
        try {
            decoded: any = _decode_source(Path(path).read_bytes());
        } except OSError {
            decoded = None;
        }
        if decoded is not None {
            source = _Source(path, decoded[0]);
        }
        self._files[path] = source;
    }
    return self._files[path];
}

impl _Sources.language(path: str) -> Optional[str] {
    try {
        return self.parser.detect_language(Path(path));
    } except (OSError, ValueError) {
        return None;
    }
}

impl _Sources.tree(path: str) -> Any {
    if path not in self._trees {
        tree: any = None;
        source: any = self.get(path);
        language: any = self.language(path);
        if source is not None and language {
            ts_parser: any = self.parser._get_parser(language);
            if ts_parser is not None {
                try {
                    tree = ts_parser.parse(source.data);
                } except (ValueError, TypeError, RuntimeError) {
                    tree = None;
                }
            }
        }
        self._trees[path] = tree;
    }
    return self._trees[path];
}

impl _Sources.resolve_js_module(spec: str, from_file: str) -> Optional[str] {
    language: any = self.language(from_file) or "typescript";
    try {
        return self.parser._resolve_module_to_file(spec, from_file, language);
    } except (OSError, ValueError) {
        return None;
    }
}

impl _Sources.__repr__ -> str {
    return (getattr(builtins.object, "__repr__") as any)(self);
}

impl _Sources.__eq__(other: any) -> bool {
    return self is other;
}

impl _Sources.__hash__ -> int {
    return id(self);
}

impl _import_targets_by_line(store: GraphStore, file_path: str) -> dict[int, set[str]] {
    by_line: dict[int, set[str]] = {};
    for `edge in store.get_edges_by_source(file_path) {
        if `edge.kind == "IMPORTS_FROM" {
            by_line.setdefault(`edge.line, set[any]()).add(`edge.target_qualified);
        }
    }
    return by_line;
}

impl _importer_files(store: GraphStore, module_file: str) -> list[str] {
    return sorted({
        `edge.file_path
        for `edge in store.get_edges_by_target(module_file)
        if `edge.kind == "IMPORTS_FROM"
    });
}

impl _PyScope.init(kind: str, parent: Optional[_PyScope]) {
    self.kind = kind;
    self.parent = parent;
    self.binds = False;
    self.bound_yet = False;
    self.declared = "";
    self.target = False;
    self.star = False;
}

impl _PyScope.bind(target: bool = False) -> None {
    value_: any = True;
    self.binds = value_;
    self.bound_yet = value_;
    if target {
        self.target = True;
    }
}

impl _PyScope.outside_class -> _PyScope {
    scope: any = self.parent or self;
    while scope.kind == "class" and scope.parent is not None {
        scope = scope.parent;
    }
    return scope;
}

impl _PyScope.__repr__ -> str {
    return (getattr(builtins.object, "__repr__") as any)(self);
}

impl _PyScope.__eq__(other: any) -> bool {
    return self is other;
}

impl _PyScope.__hash__ -> int {
    return id(self);
}

impl _py_module_matches(target: str, module_path: str, exact: bool) -> bool {
    for ending in _PY_MODULE_ENDINGS {
        candidate: any = module_path + ending;
        if target == candidate or not exact and target.endswith("/" + candidate) {
            return True;
        }
    }
    return False;
}

impl _py_module_base(dotted: str, targets: set[str]) -> Optional[str] {
    rel: any = "/" + dotted.replace(".", "/");
    for target in sorted(targets) {
        for ending in ("/__init__.py", "/__init__.pyi", ".py", ".pyi", ".pyw") {
            if target.endswith(ending) {
                module: any = target[:-len(ending)];
                if module.endswith(rel) {
                    return module[:-len(rel)];
                }
                break;
            }
        }
    }
    return None;
}

impl _dotted(expr: ast.expr) -> Optional[str] {
    parts: list[str] = [];
    while isinstance(expr, ast.Attribute) {
        parts.append(expr.attr);
        expr = expr.value;
    }
    if not isinstance(expr, ast.Name) {
        return None;
    }
    parts.append(expr.id);
    return ".".join(reversed(parts));
}

impl _PyRenameScan.init(
    source: _Source,
    name: str,
    *,
    target_def: Optional[ast.AST],
    import_targets: dict[int, set[str]],
    exporters: set[str],
) {
    self.src = source;
    self.name = name;
    self.name_bytes = len(name.encode("utf-8"));
    self.word = _ident_pattern(name);
    self.target_def = target_def;
    self.import_targets = import_targets;
    self.exporters = exporters;
    self.root = _PyScope("module", None);
    self.uses = [];
    self.fixed = [];
    self.attributes = [];
    self.module_prefixes = set[any]();
    self.module_paths = {};
    self.all_entries = [];
    self.called = set[any]();
}

impl _PyRenameScan.run(tree: ast.Module) -> tuple[list[_Occurrence], bool] {
    for stmt in tree.body {
        self._collect_all(stmt);
        self._visit(stmt, self.root);
    }
    `root: any = self.root;
    if `root.star and not `root.binds {
        `root.bind(target=True);
    }
    found: any = `list(self.fixed);
    line: any;
    col: any;
    for (scope, line, col, site) in self.uses {
        if self._owner(scope).target {
            found.append((line, col, site, None));
        }
    }
    if `root.target {
        for const in self.all_entries {
            col = self._string_entry_col(const);
            if col is not None {
                found.append((const.lineno, col, "__all__", None));
            }
        }
    }
    for attr in self.attributes {
        if self._names_exporter(_dotted(attr.value)) and attr.end_lineno is not None {
            line = attr.end_lineno;
            end: any = attr.end_col_offset or 0;
            found.append((line, self.src.char_col(line, end - self.name_bytes), "attribute", None));
        }
    }
    return (found, `root.target);
}

impl _PyRenameScan._names_exporter(dotted: Optional[str]) -> bool {
    path: any;
    if dotted is None {
        return False;
    }
    if dotted in self.module_prefixes {
        return True;
    }
    `root: any;
    _: any;
    rest: any;
    (`root, _, rest) = dotted.partition(".") as any;
    path = self.module_paths.get(`root);
    if path is None {
        return False;
    }
    if rest {
        path = format(path, "") + "/" + format(rest.replace(".", "/"), "");
    }
    return `any(_py_module_matches(e, path, True) for e in self.exporters);
}

impl _PyRenameScan._owner(scope: _PyScope) -> _PyScope {
    current: any = scope;
    while True {
        if current.declared == "global" {
            return self.root;
        }
        if current.parent is None or current.binds and current.declared != "nonlocal" {
            return current;
        }
        current = current.parent;
        while current.kind == "class" and current.parent is not None {
            current = current.parent;
        }
    }
}

impl _PyRenameScan._use(
    scope: _PyScope, line: int, byte_col: int, site: str = "reference"
) -> None {
    self.uses.append((scope, line, self.src.char_col(line, byte_col), site));
}

impl _PyRenameScan._use_after(scope: _PyScope, line: int, byte_col: int, prefix: str = "") -> None {
    text: any = self.src.line(line);
    start: any = self.src.char_col(line, byte_col);
    pattern: any = re.compile(prefix + self.word.pattern) if prefix else self.word;
    `match: any = pattern.search(text, start);
    if `match {
        col: any = `match.end() - len(self.name);
        self.uses.append((scope, line, col, "reference"));
    }
}

impl _PyRenameScan._def_name_col(
    `node: Union[ast.FunctionDef, ast.AsyncFunctionDef, ast.ClassDef]
) -> Optional[int] {
    text: any = self.src.line(`node.lineno);
    `match: any = _DEF_KEYWORD_RE.match(text, self.src.char_col(`node.lineno, `node.col_offset));
    if `match and text.startswith(self.name, `match.end()) {
        return `match.end();
    }
    return None;
}

impl _PyRenameScan._string_entry_col(const: ast.Constant) -> Optional[int] {
    if const.end_lineno != const.lineno or const.end_col_offset is None {
        return None;
    }
    raw: any = self.src.line(const.lineno).encode("utf-8")[const.col_offset:const.end_col_offset];
    `match: any = re.fullmatch(
        "([rRuU]?)('''|\\\"\\\"\\\"|'|\\\")(.*)\\2", raw.decode("utf-8", "replace")
    );
    if not `match or `match.group(3) != self.name {
        return None;
    }
    start: any = self.src.char_col(const.lineno, const.col_offset);
    return start + len(`match.group(1)) + len(`match.group(2));
}

impl _PyRenameScan._collect_all(stmt: ast.stmt) -> None {
    values: list[ast.AST] = [];
    if isinstance(stmt, (ast.Assign, ast.AnnAssign, ast.AugAssign)) {
        targets: any = stmt.targets if isinstance(stmt, ast.Assign) else [stmt.target];
        if `any(isinstance(t, ast.Name) and operator.eq(t.id, "__all__") for t in targets) {
            if stmt.value is not None {
                values.append(stmt.value);
            }
        }
    } elif isinstance(stmt, ast.Expr) and isinstance(stmt.value, ast.Call) {
        func: any = stmt.value.func;
        if isinstance(func, ast.Attribute)
            and isinstance(func.value, ast.Name)
            and func.value.id == "__all__"
        {
            values.extend(stmt.value.args);
        }
    } elif isinstance(stmt, (ast.If, ast.Try)) {
        for child in ast.iter_child_nodes(stmt) {
            if isinstance(child, ast.stmt) {
                self._collect_all(child);
            } elif isinstance(child, ast.ExceptHandler) {
                for inner in child.body {
                    self._collect_all(inner);
                }
            }
        }
    }
    for value in values {
        for `node in ast.walk(value) {
            if isinstance(`node, ast.Constant) and `node.value == self.name {
                self.all_entries.append(`node);
            }
        }
    }
}

impl _PyRenameScan._visit(`node: ast.AST, scope: _PyScope) -> None {
    if isinstance(`node, (ast.FunctionDef, ast.AsyncFunctionDef)) {
        self._visit_function(`node, scope);
    } elif isinstance(`node, ast.ClassDef) {
        self._visit_class(`node, scope);
    } elif isinstance(`node, ast.Lambda) {
        self._visit_arguments(`node.args, scope);
        inner: any = _PyScope("function", scope);
        self._bind_arguments(`node.args, inner);
        self._visit(`node.body, inner);
    } elif isinstance(`node, (ast.ListComp, ast.SetComp, ast.GeneratorExp, ast.DictComp)) {
        self._visit_comprehension(`node, scope);
    } elif isinstance(`node, ast.Name) {
        if `node.id == self.name {
            site: any = "call" if id(`node) in self.called else "reference";
            if not isinstance(`node.ctx, ast.Load) {
                scope.bind();
            } elif scope.kind == "class" and not scope.bound_yet {
                scope = scope.outside_class();
            }
            self._use(scope, `node.lineno, `node.col_offset, site);
        }
    } elif isinstance(`node, (ast.Assign, ast.AugAssign, ast.AnnAssign)) {
        if isinstance(`node, ast.Assign) {
            self._bind_import_module(`node);
        }
        if isinstance(`node, ast.AnnAssign) {
            self._visit(`node.annotation, scope);
        }
        if `node.value is not None {
            self._visit(`node.value, scope);
        }
        for target in `node.targets if isinstance(`node, ast.Assign) else [`node.target] {
            self._visit(target, scope);
        }
    } elif isinstance(`node, (ast.For, ast.AsyncFor)) {
        self._visit(`node.iter, scope);
        self._visit(`node.target, scope);
        stmt: any;
        for stmt in (*`node.body, *`node.orelse) {
            self._visit(stmt, scope);
        }
    } elif isinstance(`node, ast.NamedExpr) {
        self._visit(`node.value, scope);
        owner: any = scope;
        while owner.kind == "comprehension" and owner.parent is not None {
            owner = owner.parent;
        }
        self._visit(`node.target, owner);
    } elif isinstance(`node, (ast.Global, ast.Nonlocal)) {
        if self.name in `node.names {
            keyword: any = "global" if isinstance(`node, ast.Global) else "nonlocal";
            scope.declared = keyword;
            self._use_after(scope, `node.lineno, `node.col_offset + len(keyword));
        }
    } elif isinstance(`node, ast.Import) {
        self._visit_import(`node, scope);
    } elif isinstance(`node, ast.ImportFrom) {
        self._visit_import_from(`node, scope);
    } elif isinstance(`node, ast.ExceptHandler) {
        if `node.type is not None {
            self._visit(`node.type, scope);
        }
        if `node.name == self.name {
            scope.bind();
            anchor: any = `node.type if `node.type is not None else `node;
            line: any = anchor.end_lineno or anchor.lineno;
            self._use_after(scope, line, anchor.end_col_offset or 0, prefix="\\bas\\s+");
        }
        for stmt in `node.body {
            self._visit(stmt, scope);
        }
    } elif isinstance(`node, ast.Attribute) {
        self._visit(`node.value, scope);
        if `node.attr == self.name {
            self.attributes.append(`node);
        }
    } elif isinstance(`node, ast.Call) {
        if isinstance(`node.func, ast.Name) {
            self.called.add(id(`node.func));
        }
        child: any;
        for child in ast.iter_child_nodes(`node) {
            self._visit(child, scope);
        }
    } else {
        if getattr(`node, "name", None) == self.name or getattr(`node, "rest", None) == self.name {
            if isinstance(`node, (ast.MatchAs, ast.MatchStar, ast.MatchMapping)) {
                scope.bind();
            }
        }
        for child in ast.iter_child_nodes(`node) {
            self._visit(child, scope);
        }
    }
}

impl _PyRenameScan._bind_import_module(`node: ast.Assign) -> None {
    module_path: any;
    call: any = `node.value;
    if not (
        len(`node.targets) == 1
        and isinstance(`node.targets[0], ast.Name)
        and isinstance(call, ast.Call)
        and len(call.args) == 1
        and not call.keywords
        and isinstance(call.args[0], ast.Constant)
        and isinstance(call.args[0].value, `str)
        and _dotted(call.func) in ("importlib.import_module", "import_module")
    ) {
        return;
    }
    module_path = call.args[0].value.replace(".", "/");
    if not module_path.startswith("/")
        and `any(_py_module_matches(e, module_path, False) for e in self.exporters)
    {
        self.module_prefixes.add(`node.targets[0].id);
    }
}

impl _PyRenameScan._visit_function(
    `node: Union[ast.FunctionDef, ast.AsyncFunctionDef], scope: _PyScope
) -> None {
    for decorator in `node.decorator_list {
        self._visit(decorator, scope);
    }
    self._visit_arguments(`node.args, scope);
    if `node.returns is not None {
        self._visit(`node.returns, scope);
    }
    self._bind_definition(`node, scope);
    inner: any = _PyScope("function", scope);
    self._bind_arguments(`node.args, inner);
    for stmt in `node.body {
        self._visit(stmt, inner);
    }
}

impl _PyRenameScan._visit_class(`node: ast.ClassDef, scope: _PyScope) -> None {
    for decorator in `node.decorator_list {
        self._visit(decorator, scope);
    }
    for base in `node.bases {
        self._visit(base, scope);
    }
    for keyword in `node.keywords {
        self._visit(keyword.value, scope);
    }
    self._bind_definition(`node, scope);
    inner: any = _PyScope("class", scope);
    for stmt in `node.body {
        self._visit(stmt, inner);
    }
}

impl _PyRenameScan._bind_definition(
    `node: Union[ast.FunctionDef, ast.AsyncFunctionDef, ast.ClassDef], scope: _PyScope
) -> None {
    if `node.name != self.name {
        return;
    }
    is_target: any = `node is self.target_def;
    scope.bind(target=is_target);
    col: any = self._def_name_col(`node);
    if col is not None {
        site: any = "definition" if is_target else "reference";
        self.uses.append((scope, `node.lineno, col, site));
    }
}

impl _PyRenameScan._visit_arguments(args: ast.arguments, scope: _PyScope) -> None {
    for arg in (*args.posonlyargs, *args.args, *args.kwonlyargs, args.vararg, args.kwarg) {
        if arg is not None and arg.annotation is not None {
            self._visit(arg.annotation, scope);
        }
    }
    for `default in (*args.defaults, *args.kw_defaults) {
        if `default is not None {
            self._visit(`default, scope);
        }
    }
}

impl _PyRenameScan._bind_arguments(args: ast.arguments, inner: _PyScope) -> None {
    for arg in (*args.posonlyargs, *args.args, *args.kwonlyargs, args.vararg, args.kwarg) {
        if arg is not None and arg.arg == self.name {
            inner.bind();
            self._use(inner, arg.lineno, arg.col_offset);
        }
    }
}

impl _PyRenameScan._visit_comprehension(
    `node: Union[ast.ListComp, ast.SetComp, ast.GeneratorExp, ast.DictComp], scope: _PyScope
) -> None {
    generators: any = `node.generators;
    self._visit(generators[0].iter, scope);
    inner: any = _PyScope("comprehension", scope);
    for (index, generator) in enumerate(generators) {
        if index {
            self._visit(generator.iter, inner);
        }
        self._visit(generator.target, inner);
        for condition in generator.ifs {
            self._visit(condition, inner);
        }
    }
    if isinstance(`node, ast.DictComp) {
        self._visit(`node.key, inner);
        self._visit(`node.value, inner);
    } else {
        self._visit(`node.elt, inner);
    }
}

impl _PyRenameScan._alias_name_col(alias: ast.alias) -> int {
    return self.src.char_col(alias.lineno, alias.col_offset);
}

impl _PyRenameScan._alias_asname_col(alias: ast.alias) -> tuple[int, int] {
    line: any = alias.end_lineno or alias.lineno;
    end: any = alias.end_col_offset or 0;
    return (line, self.src.char_col(line, end - self.name_bytes));
}

impl _PyRenameScan._visit_import(`node: ast.Import, scope: _PyScope) -> None {
    module_path: any;
    targets: any = self.import_targets.get(`node.lineno, set[any]());
    exporting: any = targets & self.exporters;
    for alias in `node.names {
        module_path = alias.name.replace(".", "/");
        if `any(_py_module_matches(t, module_path, False) for t in exporting)
            or exporting and len(`node.names) == 1
        {
            self.module_prefixes.add(alias.asname or alias.name);
        }
        bound: any = alias.asname or alias.name.split(".", 1)[0];
        base: any = _py_module_base(alias.name, targets);
        if base is not None {
            module: any = alias.name if alias.asname else bound;
            self.module_paths[bound] = format(base, "")
                + "/"
                + format(module.replace(".", "/"), "");
        }
        if bound == self.name {
            scope.bind();
            if alias.asname is not None {
                line: any;
                col: any;
                (line, col) = self._alias_asname_col(alias) as any;
                self.uses.append((scope, line, col, "import"));
            }
        }
    }
}

impl _PyRenameScan._visit_import_from(`node: ast.ImportFrom, scope: _PyScope) -> None {
    module_path: any;
    exact: any;
    alias: any;
    targets: any = self.import_targets.get(`node.lineno, set[any]());
    module_path = (`node.module or "").replace(".", "/");
    exact = operator.gt(`node.level, 0);
    if exact {
        base: any = PurePosixPath(self.src.path).parent;
        for _ in range(`node.level - 1) {
            base = base.parent;
        }
        module_path = `str(base / module_path) if module_path else `str(base);
    }

    def submodule_of(target: str, imported: str) -> bool {
        prefix: any = f"{module_path}/{imported}" if module_path else imported;
        return _py_module_matches(target, prefix, exact);
    }

    module_targets: any = {t for t in targets if _py_module_matches(t, module_path, exact)};
    if not module_targets {
        module_targets = {
            t
            for t in targets
            if not `any(submodule_of(t, alias.name) for alias in `node.names)
        };
    }
    from_exporter: any = `bool(module_targets & self.exporters);
    absolute: Optional[str] = module_path if exact else None;
    if not exact and `node.module {
        for dotted in [`node.module, *(f"{`node.module}.{a.name}" for a in `node.names)] {
            top: any = _py_module_base(dotted, targets);
            if top is not None {
                absolute = f"{top}/{module_path}";
                break;
            }
        }
    }

    for alias_ in `node.names {
        alias = alias_;
        if alias.name == "*" {
            if from_exporter and scope is self.root {
                scope.star = True;
            }
            continue;
        }
        bound: any = alias.asname or alias.name;
        if absolute is not None {
            self.module_paths[bound] = f"{absolute}/{alias.name}";
        }
        if `any(submodule_of(t, alias.name) for t in targets & self.exporters) {
            self.module_prefixes.add(bound);
        } elif alias.name == self.name and from_exporter {
            self.fixed.append((alias.lineno, self._alias_name_col(alias), "import", None));
            if bound == self.name {
                scope.bind(target=True);
                if alias.asname is not None {
                    line: any;
                    col: any;
                    (line, col) = self._alias_asname_col(alias) as any;
                    self.uses.append((scope, line, col, "import"));
                }
            }
            continue;
        }
        if bound == self.name {
            scope.bind();
            if alias.asname is not None {
                (line, col) = self._alias_asname_col(alias) as any;
                self.uses.append((scope, line, col, "import"));
            }
        }
    }
}

impl _PyRenameScan.__repr__ -> str {
    return (getattr(builtins.object, "__repr__") as any)(self);
}

impl _PyRenameScan.__eq__(other: any) -> bool {
    return self is other;
}

impl _PyRenameScan.__hash__ -> int {
    return id(self);
}

impl _py_find_definition(tree: ast.Module, name: str, line: int) -> tuple[Optional[ast.AST], str] {
    stack: list[tuple[ast.AST, str]] = [(tree, "module")];
    while stack {
        current: any;
        place: any;
        (current, place) = stack.pop() as any;
        for child in ast.iter_child_nodes(current) {
            if isinstance(child, (ast.FunctionDef, ast.AsyncFunctionDef, ast.ClassDef)) {
                first: any = min([d.lineno for d in child.decorator_list] + [child.lineno]);
                if child.name == name and first <= line and line <= child.lineno {
                    return (child, place);
                }
                inner: any = "class" if isinstance(child, ast.ClassDef) else "function";
                stack.append((child, inner));
            } elif isinstance(child, (ast.stmt, ast.ExceptHandler, ast.match_case)) {
                stack.append((child, place));
            }
        }
    }
    return (None, "");
}

impl _python_rename_sites(
    store: GraphStore, `node: GraphNode, sources: _Sources, call_files: set[str]
) -> Optional[dict[str, list[_Occurrence]]] {
    name: any;
    home: any;
    target_def: any;
    results: dict[str, list[_Occurrence]];
    exporters: any;
    name = `node.name;
    home = `node.file_path;
    if not home.endswith(_PY_SUFFIXES) {
        return None;
    }
    source: any = sources.get(home);
    tree: any = source.python_tree() if source is not None else None;
    if source is None or tree is None {
        return None;
    }
    place: any;
    (target_def, place) = _py_find_definition(tree, name, `node.line_start) as any;
    if target_def is None or place == "class" {
        return None;
    }

    results = {};
    exporters = {home};
    marker: any = name.encode("utf-8");

    def scan(path: str) -> Optional[bool] {
        src: any = sources.get(path);
        parsed: any = src.python_tree() if src is not None else None;
        if src is None or parsed is None {
            return None;
        }
        scanner: any = _PyRenameScan(
            src,
            name,
            target_def=target_def if path == home else None,
            import_targets=_import_targets_by_line(store, path) if path != home else {},
            exporters=exporters,
        );
        try {
            found: any;
            exports: any;
            (found, exports) = scanner.run(parsed) as any;
        } except RecursionError {
            return None;
        }
        results[path] = found;
        return exports;
    }

    if not scan(home) or place != "module" {
        return results if home in results else None;
    }

    pending: deque[str] = deque();
    queued: set[str] = set[any]();
    path: any;
    for path in [
        *_importer_files(store, home),
        *(`edge.file_path
        for `edge in store.get_edges_by_target(`node.qualified_name)
        if `edge.kind == "IMPORTS_FROM"),
        *sorted(call_files),
    ] {
        if path not in queued {
            queued.add(path);
            pending.append(path);
        }
    }
    while pending {
        path = pending.popleft();
        queued.discard(path);
        if path == home or not path.endswith(_PY_SUFFIXES) {
            continue;
        }
        src: any = sources.get(path);
        if src is None {
            continue;
        }
        if marker not in src.data and not _STAR_IMPORT_RE.search(src.data) {
            results.setdefault(path, []);
            continue;
        }
        exports: any = scan(path);
        if exports and path not in exporters {
            exporters.add(path);
            for importer in _importer_files(store, path) {
                if importer not in queued {
                    queued.add(importer);
                    pending.append(importer);
                }
            }
        }
    }
    return results;
}

impl _ts_text(`node: Any) -> str {
    return `node.text.decode("utf-8", errors="replace") if `node is not None else "";
}

impl _ts_same(a: Any, b: Any) -> bool {
    return a is not None
        and b is not None
        and operator.eq((a.start_byte, a.end_byte), (b.start_byte, b.end_byte));
}

impl _ts_string_value(`node: Any) -> str {
    text: any = _ts_text(`node);
    return text[1:-1] if len(text) >= 2 and text[0] in "'\"`" else text;
}

impl _js_module_call_spec(`node: Any) -> Any {
    if `node is None or `node.type != "call_expression" {
        return None;
    }
    func: any = `node.child_by_field_name("function");
    if func is None
        or not (func.type == "import" or func.type == "identifier" and _ts_text(func) == "require")
    {
        return None;
    }
    args: any = `node.child_by_field_name("arguments");
    first: any = args.named_children[0] if args is not None and args.named_children else None;
    return first if first is not None and first.type == "string" else None;
}

impl _js_is_declaration(leaf: Any) -> bool {
    parent: any;
    if leaf.type == "shorthand_property_identifier_pattern" {
        return True;
    }
    parent = leaf.parent;
    if parent is None {
        return False;
    }
    if parent.type in _JS_DECLARATION_PARENTS {
        return True;
    }
    return `any(
        _ts_same(parent.child_by_field_name(field), leaf)
        for field in _JS_DECLARATION_FIELDS.get(parent.type, ()),
    );
}

impl _ts_ancestor(`node: Any, kinds: frozenset[str]) -> Any {
    current: any = `node.parent;
    last: any = `node;
    while current is not None {
        if current.type in kinds {
            return current;
        }
        (last, current) = (current, current.parent);
    }
    return last;
}

impl _js_declaration_scope(leaf: Any) -> Any {
    child: any;
    current: any;
    (child, current) = (leaf, leaf.parent);
    while current is not None {
        kind: any = current.type;
        if kind == "formal_parameters"
            or kind == "arrow_function"
                and _ts_same(current.child_by_field_name("parameter"), child)
        {
            return current if kind == "arrow_function" else current.parent;
        }
        if kind in ("catch_clause", "for_in_statement") {
            return current;
        }
        if kind == "variable_declarator" {
            declaration: any = current.parent;
            if declaration is not None and declaration.type == "variable_declaration" {
                return _ts_ancestor(declaration, _JS_FUNCTION_SCOPES);
            }
            return _ts_ancestor(current, _JS_BLOCK_SCOPES);
        }
        if kind in _JS_NAMED_EXPRESSIONS and _ts_same(current.child_by_field_name("name"), child) {
            return current;
        }
        if kind in _JS_DECLARATION_FIELDS and _ts_same(current.child_by_field_name("name"), child) {
            return _ts_ancestor(current, _JS_BLOCK_SCOPES);
        }
        if kind in ("import_statement", "program") {
            return _ts_ancestor(current, frozenset({"program"}));
        }
        (child, current) = (current, current.parent);
    }
    return child;
}

impl _JsScan.init(
    source: _Source,
    name: str,
    new_name: str,
    *,
    def_lines: Optional[range],
    import_targets: dict[int, set[str]],
    exporters: set[str],
    resolve: Any,
) {
    self.src = source;
    self.name = name;
    self.new_name = new_name;
    self.def_lines = def_lines;
    self.import_targets = import_targets;
    self.exporters = exporters;
    self.resolve = resolve;
    self.renames = [];
    self.plain = [];
    self.kept = set[any]();
    self.scopes = [];
    self.members = [];
    self.prefixes = {};
    self.barrels = set[any]();
    self.reexports = False;
    self.local_export = False;
    self.found_definition = False;
    self.exported_definition = False;
    self.commonjs = False;
    self.root = None;
}

impl _JsScan.occurrence(leaf: Any, site: str, new: Optional[str] = None) -> _Occurrence {
    line: any = leaf.start_point[0] + 1;
    return (line, self.src.char_col(line, leaf.start_point[1]), site, new);
}

impl _JsScan.declare(`node: Any, target: bool) -> None {
    self.scopes.append((`node.start_byte, `node.end_byte, target));
}

impl _JsScan.statement_targets(statement: Any) -> set[str] {
    line: any = statement.start_point[0] + 1;
    targets: any = `set(self.import_targets.get(line, set[any]()));
    source: any = statement.child_by_field_name("source");
    if not targets and source is not None {
        resolved: any = self.resolve(_ts_string_value(source));
        if resolved {
            targets.add(resolved);
        }
    }
    return targets;
}

impl _JsScan.run(`root: Any) -> None {
    obj_start: any;
    self.root = `root;
    stack: any = [`root];
    while stack {
        current: any = stack.pop();
        kind: any = current.type;
        if kind == "import_statement" {
            self.visit_import(current);
            continue;
        }
        if kind == "export_statement" and current.child_by_field_name("source") is not None {
            self.visit_reexport(current);
            continue;
        }
        if kind == "variable_declarator" {
            self.visit_module_value(current);
        } elif kind == "call_expression" {
            self.visit_import_then(current);
        }
        if kind in ("member_expression", "nested_identifier") {
            `obj: any = current.child_by_field_name("object");
            prop: any = current.child_by_field_name("property");
            if `obj is None and current.named_child_count == 2 {
                (`obj, prop) = current.named_children as any;
            }
            if prop is not None and `obj is not None {
                if `obj.type == "identifier" and _ts_text(prop) == self.name {
                    self.members.append((_ts_text(`obj), `obj.start_byte, prop));
                }
                if `obj.type == "identifier"
                    and (
                        _ts_text(`obj) == "exports"
                        or _ts_text(`obj) == "module" and _ts_text(prop) == "exports"
                    )
                {
                    self.commonjs = True;
                }
                stack.append(`obj);
                continue;
            }
        }
        if current.child_count == 0 {
            if kind in _JS_NAME_LEAVES and _ts_text(current) == self.name {
                self.visit_name(current);
            }
            continue;
        }
        stack.extend(reversed(current.children));
    }

    obj_name: any;
    for item_ in self.members {
        (obj_name, obj_start, prop) = item_;
        if `any(
            operator.le(s, obj_start) and operator.lt(obj_start, e)
            for (s, e) in self.prefixes.get(obj_name, ()),
        ) {
            self.renames.append(self.occurrence(prop, "attribute"));
        }
    }
    for (occurrence, start, end, exported) in self.plain {
        resolved: any = self.resolves_to_symbol(start, end);
        if resolved {
            self.renames.append(occurrence);
            self.local_export = self.local_export or exported;
        } elif resolved is False {
            self.kept.add((occurrence[0], occurrence[1]));
        }
    }
}

impl _JsScan.resolves_to_symbol(start: int, end: int) -> Optional[bool] {
    best: Optional[tuple[int, bool]] = None;
    for (scope_start, scope_end, target) in self.scopes {
        if scope_start <= start and end <= scope_end {
            size: any = scope_end - scope_start;
            if best is None or size < best[0] or size == best[0] and not target {
                best = (size, target);
            }
        }
    }
    return None if best is None else best[1];
}

impl _JsScan.visit_name(leaf: Any) -> None {
    if _js_is_declaration(leaf) {
        line: any = leaf.start_point[0] + 1;
        is_target: any = self.def_lines is not None
            and line in self.def_lines
            and not self.found_definition;
        if is_target {
            self.found_definition = True;
            export: any = _ts_ancestor(leaf, frozenset({"export_statement"}));
            self.exported_definition = operator.eq(export.type, "export_statement")
                and not `any(operator.eq(c.type, "default") for c in export.children);
            self.renames.append(self.occurrence(leaf, "definition"));
        }
        self.declare(_js_declaration_scope(leaf), is_target);
        return;
    }
    replacement: any = None;
    site: any = "reference";
    exported: any = False;
    parent: any = leaf.parent;
    if leaf.type == "shorthand_property_identifier" {
        replacement = f"{self.name}: {self.new_name}";
    } elif parent is not None and parent.type == "export_specifier" {
        name: any = parent.child_by_field_name("name");
        alias: any = parent.child_by_field_name("alias");
        if not _ts_same(name, leaf) and _ts_text(name) != self.name {
            return;
        }
        site = "export";
        exported = alias is None or operator.eq(_ts_text(alias), self.name);
    }
    self.plain.append((
        self.occurrence(leaf, site, replacement),
        leaf.start_byte,
        leaf.end_byte,
        exported,
    ));
}

impl _JsScan.namespace(ident: Any, targets: set[str], scope: Any) -> None {
    if targets & self.exporters {
        self.prefixes.setdefault(_ts_text(ident), []).append((scope.start_byte, scope.end_byte));
    } else {
        self.barrels.update(targets);
    }
}

impl _JsScan.module_targets(spec: Any) -> set[str] {
    if spec is None {
        return set[any]();
    }
    resolved: any = self.resolve(_ts_string_value(spec));
    if resolved {
        return {resolved};
    }
    return `set(self.import_targets.get(spec.start_point[0] + 1, set[any]()));
}

impl _JsScan.visit_module_value(declarator: Any) -> None {
    ident: any = declarator.child_by_field_name("name");
    value: any = declarator.child_by_field_name("value");
    if ident is None or ident.type != "identifier" or value is None {
        return;
    }
    if value.type == "await_expression" and value.named_child_count == 1 {
        value = value.named_children[0];
    }
    spec: any = _js_module_call_spec(value);
    if spec is not None {
        self.namespace(ident, self.module_targets(spec), _js_declaration_scope(ident));
    }
}

impl _JsScan.visit_import_then(call: Any) -> None {
    func: any = call.child_by_field_name("function");
    if func is None or func.type != "member_expression" {
        return;
    }
    prop: any = func.child_by_field_name("property");
    spec: any = _js_module_call_spec(func.child_by_field_name("object"));
    args: any = call.child_by_field_name("arguments");
    if spec is None or _ts_text(prop) != "then" or args is None or not args.named_children {
        return;
    }
    callback: any = args.named_children[0];
    if callback.type not in ("arrow_function", "function_expression", "function") {
        return;
    }
    param: any = callback.child_by_field_name("parameter");
    if param is None {
        params: any = callback.child_by_field_name("parameters");
        first: any = params.named_children[0]
            if params is not None and params.named_children
            else None;
        if first is not None and first.type in ("required_parameter", "optional_parameter") {
            first = first.child_by_field_name("pattern");
        }
        param = first;
    }
    if param is not None and param.type == "identifier" {
        self.namespace(param, self.module_targets(spec), callback);
    }
}

impl _JsScan.visit_import(statement: Any) -> None {
    targets: any = self.statement_targets(statement);
    from_exporter: any = `bool(targets & self.exporters);
    require: any = next((c for c in statement.children if c.type == "import_require_clause"), None);
    if require is not None {
        ident: any = next((c for c in require.children if c.type == "identifier"), None);
        if ident is not None {
            spec: any = require.child_by_field_name("source");
            self.namespace(ident, targets or self.module_targets(spec), self.root);
            if _ts_text(ident) == self.name {
                self.declare(self.root, False);
            }
        }
        return;
    }
    clause: any = next((c for c in statement.children if c.type == "import_clause"), None);
    if clause is None {
        return;
    }
    for part in clause.children {
        if part.type == "identifier" {
            if _ts_text(part) == self.name {
                self.declare(self.root, False);
            }
        } elif part.type == "namespace_import" {
            ident = next((c for c in part.children if c.type == "identifier"), None);
            if ident is not None {
                self.namespace(ident, targets, self.root);
                if _ts_text(ident) == self.name {
                    self.declare(self.root, False);
                }
            }
        } elif part.type == "named_imports" {
            for spec in part.children {
                if spec.type == "import_specifier" {
                    self.visit_import_specifier(spec, targets, from_exporter);
                }
            }
        }
    }
}

impl _JsScan.visit_import_specifier(spec: Any, targets: set[str], from_exporter: bool) -> None {
    name: any = spec.child_by_field_name("name");
    alias: any = spec.child_by_field_name("alias");
    alias_is_name: any = alias is not None and operator.eq(_ts_text(alias), self.name);
    if _ts_text(name) != self.name {
        if alias_is_name {
            self.declare(self.root, False);
        }
        return;
    }
    if not from_exporter {
        if alias is None or alias_is_name {
            self.declare(self.root, False);
        }
        self.barrels.update(targets);
        return;
    }
    self.renames.append(self.occurrence(name, "import"));
    if alias is None or alias_is_name {
        self.declare(self.root, True);
        if alias_is_name {
            self.renames.append(self.occurrence(alias, "import"));
        }
    }
}

impl _JsScan.visit_reexport(statement: Any) -> None {
    spec: any;
    targets: any = self.statement_targets(statement);
    clause: any = next((c for c in statement.children if c.type == "export_clause"), None);
    if not targets & self.exporters {
        if clause is None
            or `any(
                operator.eq(_ts_text(spec.child_by_field_name("name")), self.name)
                for spec in clause.children
                if spec.type == "export_specifier",
            )
        {
            self.barrels.update(targets);
        }
        return;
    }
    if clause is None {
        if `any(operator.eq(c.type, "*") for c in statement.children)
            and not `any(operator.eq(c.type, "namespace_export") for c in statement.children)
        {
            self.reexports = True;
        }
        return;
    }
    for spec in clause.children {
        if spec.type != "export_specifier" {
            continue;
        }
        name: any = spec.child_by_field_name("name");
        alias: any = spec.child_by_field_name("alias");
        if _ts_text(name) != self.name {
            continue;
        }
        self.renames.append(self.occurrence(name, "export"));
        if alias is None {
            self.reexports = True;
        } elif _ts_text(alias) == self.name {
            self.reexports = True;
            self.renames.append(self.occurrence(alias, "export"));
        }
    }
}

impl _JsScan.__repr__ -> str {
    return (getattr(builtins.object, "__repr__") as any)(self);
}

impl _JsScan.__eq__(other: any) -> bool {
    return self is other;
}

impl _JsScan.__hash__ -> int {
    return id(self);
}

impl _js_reexport_files(store: GraphStore, sources: _Sources, name: str, home: str) -> list[str] {
    marker: any = name.encode("utf-8");
    pattern: any = re.compile(
        b"\\bexport\\s+(?:type\\s+)?\\{[^}]*?(?<![\\w$])"
            + re.escape(marker)
            + b"(?![\\w$])[^}]*\\}\\s*from\\b",
    );
    found: any = [];
    for path in store.get_all_files() {
        if path == home or sources.language(path) not in _JS_FAMILY {
            continue;
        }
        try {
            data: any = Path(path).read_bytes();
        } except OSError {
            continue;
        }
        if marker in data and pattern.search(data) {
            found.append(path);
        }
    }
    return sorted(found);
}

impl _js_rename_sites(
    store: GraphStore, `node: GraphNode, new_name: str, sources: _Sources, graph_files: set[str]
) -> Optional[dict[str, _JsScan]] {
    exporters: set[str];
    results: dict[str, _JsScan];
    pending: deque[str];
    queued: any;
    path: any;
    home: any = `node.file_path;
    if sources.tree(home) is None or sources.get(home) is None {
        return None;
    }
    window: any = range(
        `node.line_start, min(`node.line_end, `node.line_start + _DEF_SEARCH_LINES) + 1
    );
    exporters = set[any]();
    results = {};
    pending = deque([home]);
    queued = {home};

    def enqueue(paths: Any) -> None {
        for path in paths {
            if path not in queued {
                queued.add(path);
                pending.append(path);
            }
        }
    }

    enqueue(_importer_files(store, home));
    enqueue(sorted(graph_files));
    while pending {
        path = pending.popleft();
        queued.discard(path);
        if sources.language(path) not in _JS_FAMILY {
            continue;
        }
        src: any = sources.get(path);
        tree: any = sources.tree(path);
        if src is None or tree is None {
            continue;
        }
        scan: any = _JsScan(
            src,
            `node.name,
            new_name,
            def_lines=window if path == home else None,
            import_targets=_import_targets_by_line(store, path),
            exporters=exporters,
            resolve=functools.partial(sources.resolve_js_module, from_file=path),
        );
        scan.run(tree.root_node);
        results[path] = scan;
        if path == home {
            if not scan.found_definition {
                return None;
            }
            if scan.exports_by_name {
                enqueue(_js_reexport_files(store, sources, `node.name, home));
            }
        }
        if scan.exports and path not in exporters {
            exporters.add(path);
            enqueue(_importer_files(store, path));
            enqueue(p for (p, other) in results.items() if path in other.barrels);
        }
        enqueue(sorted(b for b in scan.barrels if b not in exporters and b not in results));
    }
    return results;
}

impl _ts_is_name_leaf(kind: str) -> bool {
    return "identifier" in kind or kind in ("name", "constant");
}

impl _ts_call_row(leaf: Any) -> Optional[int] {
    current: any = leaf.parent;
    while current is not None {
        kind: any = current.type;
        if "argument" in kind {
            return None;
        }
        if "call" in kind or "invocation" in kind {
            return `int(current.start_point[0]);
        }
        if kind.endswith(("statement", "declaration", "declarator")) or kind == "program" {
            return None;
        }
        current = current.parent;
    }
    return None;
}

impl _ts_in_comment_or_string(tree: Any, row: int, start: int, end: int) -> bool {
    current: any = tree.root_node.descendant_for_point_range((row, start), (row, end));
    while current is not None {
        kind: any = current.type;
        if "substitution" in kind or "interpolation" in kind {
            return False;
        }
        if "comment" in kind or "string" in kind {
            return True;
        }
        current = current.parent;
    }
    return False;
}

impl _lexical_sites(
    sources: _Sources,
    source: _Source,
    lines: dict[int, str],
    name: str,
    new_name: str,
    mode: str = "any",
) -> list[_Occurrence] {
    start: any;
    line: any;
    col: any;
    found: list[_Occurrence] = [];
    tokened: set[int] = set[any]();
    path: any = source.path;
    if path.endswith(_PY_SUFFIXES) {
        tokens: any = source.python_name_tokens(name);
        if tokens is not None {
            tokened.update(lines);
            hits: any = [
                (line, col, attr, lines[line])
                for (line, col, attr) in tokens
                if line in lines
            ];
            calls: any = source.python_call_names(name);
            for start_ in lines {
                start = start_;
                hits.extend(
                    (line, col, attr, lines[start]) for (line, col, attr) in calls.get(start, ())
                );
            }
            site: any;
            for (line, col, is_attribute, site) in hits {
                if mode == "any" or operator.eq(mode, "attribute") == is_attribute {
                    found.append((line, col, site, None));
                }
            }
        }
    } else {
        tree: any = sources.tree(path);
        if tree is not None and lines {
            wanted: any = name.encode("utf-8");
            stack: any = [tree.root_node];
            while stack {
                current: any = stack.pop();
                if current.child_count {
                    stack.extend(current.children);
                    continue;
                }
                kind: any = current.type;
                if current.text != wanted or not _ts_is_name_leaf(kind) {
                    continue;
                }
                line = current.start_point[0] + 1;
                site_line: Optional[int] = line;
                if line not in lines {
                    row: any = _ts_call_row(current);
                    site_line = row + 1 if row is not None and row + 1 in lines else None;
                }
                if site_line is None {
                    continue;
                }
                tokened.add(site_line);
                if mode == "bare" and kind == "property_identifier" {
                    continue;
                }
                replacement: any = f"{name}: {new_name}"
                    if kind == "shorthand_property_identifier"
                    else None;
                col = source.char_col(line, current.start_point[1]);
                found.append((line, col, lines[site_line], replacement));
            }
        }
    }
    word: any = _ident_pattern(name);
    fallback_tree: any = None;
    for (line, site) in lines.items() {
        if line in tokened {
            continue;
        }
        text: any = source.line(line);
        for `match in word.finditer(text) {
            if fallback_tree is None {
                fallback_tree = sources.tree(path) or False;
            }
            if fallback_tree {
                start = len(text[:`match.start()].encode("utf-8"));
                end: any = start + len(name.encode("utf-8"));
                if _ts_in_comment_or_string(fallback_tree, line - 1, start, end) {
                    continue;
                }
            }
            found.append((line, `match.start(), site, None));
            break;
        }
    }
    return found;
}

impl _locate_definition(
    sources: _Sources, source: _Source, `node: GraphNode, new_name: str
) -> Optional[_Occurrence] {
    last: any = max(
        `node.line_start,
        min(`node.line_end or `node.line_start, `node.line_start + _DEF_SEARCH_LINES),
    );
    lines: any = {line: "definition" for line in range(`node.line_start, last + 1)};
    hits: any = _lexical_sites(sources, source, lines, `node.name, new_name);
    return min(hits, key=lambda (hit) -> any { (hit[0], hit[1]) }) if hits else None;
}

impl _rename_target(store: GraphStore, old_name: str) -> Optional[GraphNode] {
    `node: any = store.get_node(old_name);
    if `node is None and "::" in old_name {
        `root: any = store.get_repo_root();
        if `root {
            `node = store.get_node(normalize_file_path(Path(`root) / old_name));
        }
    }
    if `node is not None or "::" in old_name {
        return `node if `node is not None and `node.kind != "File" else None;
    }
    candidates: any = [
        n
        for n in store.search_nodes_by_qualified_tail(old_name, limit=500)
        if n.kind != "File"
    ] or [
        n
        for n in store.search_nodes(old_name, limit=500)
        if n.name == old_name and n.kind != "File"
    ];
    if not candidates {
        return None;
    }
    if len(candidates) > 1 {
        logger.info(
            "rename_preview: %r names %d symbols; pass a qualified name to pick another",
            old_name,
            len(candidates),
        );
    }
    return min(candidates, key=lambda (n) -> any { (n.file_path, n.line_start) });
}

impl rename_preview(store: GraphStore, old_name: str, new_name: str) -> Optional[dict[str, Any]] {
    followed: any;
    `node: any = _rename_target(store, old_name);
    if `node is None {
        logger.warning("rename_preview: node %r not found", old_name);
        return None;
    }

    edits: any = _rename_edits(store, `node, new_name);
    if edits is None {
        logger.warning(
            "rename_preview: %s is not at %s:%d any more; the graph is stale",
            `node.name,
            `node.file_path,
            `node.line_start,
        );
        return None;
    }

    stats: any = {"high": 0, "medium": 0, "low": 0};
    for e in edits {
        stats[e["confidence"]] += 1;
    }

    refactor_id: any = uuid.uuid4().hex[:8];
    preview: dict[str, Any] = {
        "refactor_id": refactor_id,
        "type": "rename",
        "old_name": _sanitize_name(old_name),
        "new_name": _sanitize_name(new_name),
        "qualified_name": _sanitize_name(`node.qualified_name),
        "edits": edits,
        "stats": stats,
        "created_at": time.time(),
    };

    followed_files = importlib.import_module("code_review_graph.incremental").followed_files;

    followed = followed_files(store);
    with _refactor_lock {
        _cleanup_expired();
        _pending_refactors[refactor_id] = preview;
        if followed {
            _followed_edit_files[refactor_id] = frozenset(
                normalize_file_path(edit["file"])
                for edit in edits
                if normalize_file_path(edit["file"]) in followed,
            );
        }
    }

    logger.info(
        "rename_preview: created refactor %s (%s -> %s, %d edits)",
        refactor_id,
        old_name,
        new_name,
        len(edits),
    );
    return preview;
}

impl _rename_edits(
    store: GraphStore, `node: GraphNode, new_name: str
) -> Optional[list[dict[str, Any]]] {
    graph_lines: dict[str, dict[int, str]];
    `skip: any;
    ln: any;
    kind: any;
    name: any = `node.name;
    sources: any = _Sources(store.get_repo_root());
    graph_lines = {};

    def note(path: str, line: int, site: str) -> None {
        graph_lines.setdefault(path, {}).setdefault(line, site);
    }

    note(`node.file_path, `node.line_start, "definition");
    resolved_files: set[str] = set[any]();
    `edge: any;
    for `edge in store.get_edges_by_target(`node.qualified_name) {
        site: any = {"CALLS": "call", "REFERENCES": "reference", "IMPORTS_FROM": "import"}.get(
            `edge.kind
        );
        if site {
            note(`edge.file_path, `edge.line, site);
            resolved_files.add(`edge.file_path);
        }
    }

    language: any = `node.language or "";
    exact: dict[str, list[_Occurrence]] = {};
    authoritative: set[str] = set[any]();
    kept: dict[str, set[tuple[int, int]]] = {};
    member: any = `bool(`node.parent_name);
    js_module_symbol: any = False;
    bare_edges: any = [
        `edge
        for `edge in store.search_edges_by_target_name(
            name, kind="CALLS", language=language or None
        )
        if CLAIMED_ENDPOINT_KEY not in `edge.extra
            or store.receiver_evidence_admits(`edge.extra, `node)
    ];
    bare_files: any = {`edge.file_path for `edge in bare_edges};
    python_sites: any = _python_rename_sites(store, `node, sources, bare_files)
        if language == "python"
        else None;

    if python_sites is not None {
        exact.update(python_sites);
        authoritative.update(python_sites);
    } else {
        for `edge in bare_edges {
            note(`edge.file_path, `edge.line, "call");
        }
        if language in _JS_FAMILY and not member {
            scans: any = _js_rename_sites(
                store, `node, new_name, sources, resolved_files | bare_files
            );
            if scans is not None {
                js_module_symbol = True;
                path: any;
                for (path, scan) in scans.items() {
                    exact[path] = scan.renames;
                    kept[path] = scan.kept;
                    if scan.authoritative {
                        authoritative.add(path);
                    }
                }
            }
        }
    }
    mode: any = "any";
    if language == "python" and member {
        mode = "attribute";
    } elif js_module_symbol {
        mode = "bare";
    }

    occurrences: dict[str, list[_Occurrence]] = {
        path: `list(found)
        for (path, found) in exact.items()
    };
    unreadable: dict[str, dict[int, str]] = {};
    sites: any;
    for (path, sites) in graph_lines.items() {
        if path in authoritative {
            continue;
        }
        source: any = sources.get(path);
        if source is None {
            unreadable[path] = sites;
            continue;
        }
        file_occurrences: any = occurrences.setdefault(path, []);
        if path == `node.file_path
            and not `any(operator.eq(occ[2], "definition") for occ in file_occurrences)
        {
            definition: any = _locate_definition(sources, source, `node, new_name);
            if definition is None {
                return None;
            }
            file_occurrences.append(definition);
            sites = {ln: kind for (ln, kind) in sites.items() if ln != `node.line_start};
        }
        `skip = kept.get(path, set[any]());
        file_occurrences.extend(
            occ
            for occ in _lexical_sites(sources, source, sites, name, new_name, mode)
            if (occ[0], occ[1]) not in `skip,
        );
    }

    if `node.file_path not in unreadable
        and not `any(
            operator.eq(occ[2], "definition") for occ in occurrences.get(`node.file_path, [])
        )
    {
        return None;
    }

    edits: list[dict[str, Any]] = [];
    for (path, file_occurrences) in occurrences.items() {
        placed: set[tuple[int, int]] = set[any]();
        for (line, col, site, replacement) in sorted(
            file_occurrences, key=lambda (o) -> any { (o[0], o[1]) }
        ) {
            if (line, col) in placed {
                continue;
            }
            placed.add((line, col));
            edits.append({
                "file": path,
                "line": line,
                "column": col + 1,
                "old": name,
                "new": replacement or new_name,
                "site": site,
                "confidence": "high",
            });
        }
    }
    for (path, sites) in unreadable.items() {
        for (ln, kind) in sorted(sites.items()) {
            edits.append({
                "file": path,
                "line": ln,
                "old": name,
                "new": new_name,
                "site": kind,
                "confidence": "high",
            });
        }
    }
    edits.sort(key=lambda (e) -> any { (e["file"], e["line"], e.get("column", 0)) });
    return edits;
}

impl _is_entry_point(`node: Any) -> bool {
    if _has_framework_decorator(`node) or _has_override_decorator(`node) {
        return True;
    }
    if _matches_entry_name(`node) {
        return True;
    }
    return False;
}

impl _path_segments(file_path: str) -> tuple[str, ...] {
    parts: any = file_path.replace("\\", "/").split("/");
    return `tuple(
        p
        for p in parts[:-1]
        if len(p) >= _MIN_PKG_SEGMENT_LEN and p not in ("home", "src", "lib", "app"),
    );
}

impl _collect_type_referenced_names(store: GraphStore) -> set[str] {
    funcs: any = store.get_nodes_by_kind(kinds=["Function", "Test"]);
    names: set[str] = set[any]();
    for f in funcs {
        for text in (f.params, f.return_type) {
            if text {
                names.update(_TYPE_IDENT_RE.findall(text));
            }
        }
    }
    return names;
}

impl _ascii_fold(text: str) -> str {
    return text.lower() if text.isascii() else text.translate(_ASCII_FOLD);
}

impl _csharp_member_scopes(conn: Any) -> dict[str, set[str]] {
    scopes: dict[str, set[str]] = {};
    for (parent,) in conn.execute(
        "SELECT DISTINCT parent_name FROM nodes WHERE language = 'csharp' AND parent_name IS NOT NULL AND kind IN ('Function', 'Test')",
    ) {
        scopes.setdefault(parent.rpartition(".")[2], set[any]()).add(parent);
    }
    return scopes;
}

impl find_dead_code(
    store: GraphStore,
    kind: Optional[str] = None,
    file_pattern: Optional[str] = None,
    `root: Optional[Union[str, Path]] = None,
) -> list[dict[str, Any]] {
    test_root: any;
    bare_files_by_language: dict[tuple[str, str, str | None], set[str]];
    bare_files_all: dict[tuple[str, str], set[str]];
    class_names: any;
    importer_files: dict[str, set[str]];
    lowered_target: any;
    end: any;
    name_counts: dict[str, int];
    `node: any;
    candidates: any = store.get_nodes_by_kind(
        kinds=[kind] if kind else ["Function", "Class"], file_pattern=file_pattern
    );
    test_root = `root or store.get_repo_root();

    """Directory segments of *file_path* that could name a package.

        Only the part inside the repository counts. The directories above a
        checkout belong to whoever cloned it, so matching them against an
        import specifier makes the answer depend on where the repository
        happens to live: a job directory named "test" or "common" would
        accept callers that a checkout elsewhere rejects (#1023). When the
        root is unknown there is nothing better than the whole path, which is
        what this did before roots were recorded.
        """
    def _package_segments(file_path: str) -> tuple[str, ...] {
        return _path_segments(_repo_relative(file_path, test_root) or file_path);
    }

    """Whether *file_path* is test code, for dead-code purposes.

        Dead-code detection opts into the ambiguous ``test-utils/`` and
        ``test_utils/`` directories, which the shared default leaves out
        because shared libraries are published from them. Here the trade is
        the other way round: a wrong "this is dead" report sends a reviewer
        to delete working code, while over-suppressing only costs a hint.
        """
    def _in_test_file(file_path: str) -> bool {
        return _is_test_file(file_path, test_root, include_helper_dirs=True);
    }
    type_ref_names: any = _collect_type_referenced_names(store);
    incoming_kinds: dict[str, set[str]] = {};
    bare_files_by_language = {};
    bare_files_all = {};
    suffix_call_files: dict[str, set[str]] = {};
    tested_files: dict[str, set[str]] = {};
    member_call_names: set[str] = set[any]();
    class_names = {_ascii_fold(`node.name) for `node in candidates if `node.kind == "Class"};
    max_class_name_length: any = max((len(class_name) for class_name in class_names), default=0);
    class_bases: dict[str, list[str]] = {};
    base_targets: dict[str, set[str]] = {};
    importer_files = {};
    csharp_member_scopes: dict[str, set[str]] | None = None;
    conn: any = store._conn;
    row: any;
    for row in conn.execute(
        f"SELECT e.kind, e.source_qualified, e.target_qualified, e.file_path, n.language, CASE WHEN instr(e.extra, '\"{CLAIMED_ENDPOINT_KEY}\"') AND json_valid(e.extra) THEN json_extract(e.extra, '$.{CLAIMED_ENDPOINT_KEY}') WHEN instr(e.extra, '\"{INHERITED_ENDPOINT_KEY}\"') AND json_valid(e.extra) THEN json_extract(e.extra, '$.{INHERITED_ENDPOINT_KEY}') END, CASE WHEN instr(e.extra, '\"{INHERITED_THROUGH_KEY}\"') AND json_valid(e.extra) THEN json_extract(e.extra, '$.{INHERITED_THROUGH_KEY}') END FROM edges e LEFT JOIN nodes n ON n.qualified_name = e.source_qualified WHERE e.kind IN ('CALLS', 'TESTED_BY', 'IMPORTS_FROM', 'INHERITS', 'REFERENCES')",
    ) {
        edge_kind: any;
        source: any;
        target: any;
        file_path: any;
        language: any;
        claimed: any;
        through: any;
        (edge_kind, source, target, file_path, language, claimed, through) = row as any;
        if edge_kind == "INHERITS" {
            class_bases.setdefault(source, []).append(target.rsplit("::", 1)[-1]);
            base_targets.setdefault(source, set[any]()).add(target);
        } elif edge_kind == "IMPORTS_FROM" {
            importer_files.setdefault(file_path, set[any]()).add(target);
        }
        if _STORYBOOK_FILE_RE.search(file_path) {
            continue;
        }
        incoming_kinds.setdefault(target, set[any]()).add(edge_kind);
        if edge_kind in ("CALLS", "INHERITS") {
            bare_files_by_language.setdefault((edge_kind, target, language), set[any]()).add(
                file_path
            );
            bare_files_all.setdefault((edge_kind, target), set[any]()).add(file_path);
        }
        if edge_kind == "CALLS" {
            named: any = {target};
            if isinstance(claimed, `str) {
                named.add(claimed);
            }
            if isinstance(through, `str) {
                named.add(format(through, "") + "." + format(target.rsplit(".", 1)[-1], ""));
            }
            for written_target in named {
                if "::" in written_target {
                    suffix_call_files.setdefault(
                        _ascii_fold(written_target.rsplit("::", 1)[-1]), set[any]()
                    ).add(file_path);
                }
                lowered_target = _ascii_fold(written_target);
                character: any;
                for item__ in enumerate(lowered_target) {
                    (end, character) = item__;
                    if character == "." {
                        member_call_names.update(
                            lowered_target[start:end]
                            for start in range(max(0, end - max_class_name_length), end)
                            if lowered_target[start:end] in class_names,
                        );
                    }
                }
            }
        } elif edge_kind == "TESTED_BY" {
            tested_files.setdefault(source, set[any]()).add(file_path);
        }
    }

    def _bare_files(name: str, language: str, edge_kind: str = "CALLS") -> set[str] {
        languages: any = _compatible_edge_languages(language) if language else None;
        if languages is None {
            return bare_files_all.get((edge_kind, name), set[any]());
        }
        return set[any]().union(
            *(bare_files_by_language.get((edge_kind, name, lang), set[any]()) for lang in languages)
        );
    }
    name_counts = {};
    for row in conn.execute(
        "SELECT name, COUNT(*) FROM nodes WHERE kind IN ('Function', 'Class') AND is_test = 0 GROUP BY name",
    ).fetchall() {
        name_counts[row[0]] = row[1];
    }

    """A bare-name edge is plausible if it comes from the same file,
        from a file that has an IMPORTS_FROM edge whose target matches
        the node's file path, or the name is globally unique (no ambiguity)."""
    def _is_plausible_caller(edge_file: str, node_file: str, node_name: str = "") -> bool {
        if edge_file == node_file {
            return True;
        }
        if node_name and name_counts.get(node_name, 0) == 1 {
            return True;
        }
        for imp_target in importer_files.get(edge_file, ()) {
            imp_path: any = imp_target.split("::")[0] if "::" in imp_target else imp_target;
            if imp_path.endswith("/__init__.py") {
                imp_dir: any = imp_path[:-12];
                if node_file.startswith(imp_dir + "/") {
                    return True;
                }
            }
            if imp_path.startswith(node_file) or node_file.startswith(imp_path + "/") {
                return True;
            }
            for imp2 in importer_files.get(imp_target, ()) {
                imp2_path: any = imp2.split("::")[0] if "::" in imp2 else imp2;
                if imp2_path.endswith("/__init__.py") {
                    imp2_dir: any = imp2_path[:-12];
                    if node_file.startswith(imp2_dir + "/") {
                        return True;
                    }
                }
                if imp2_path.startswith(node_file) or node_file.startswith(imp2_path + "/") {
                    return True;
                }
            }
            if not imp_target.startswith("/") {
                for seg in _package_segments(node_file) {
                    if seg in imp_target {
                        return True;
                    }
                }
            }
        }
        return False;
    }

    dead: list[dict[str, Any]] = [];

    for node_ in candidates {
        `node = node_;
        if `node.is_test or _in_test_file(`node.file_path) {
            continue;
        }
        if `node.file_path.endswith(".d.ts") {
            continue;
        }
        if `node.name.startswith("__") and `node.name.endswith("__") {
            continue;
        }
        if `node.name == "constructor" and `node.parent_name {
            continue;
        }
        if `node.is_test or _in_test_file(`node.file_path) {
            if _MOCK_NAME_RE.search(`node.name) {
                continue;
            }
        }

        if `node.extra.get("verilog_kind") {
            continue;
        }
        if `node.extra.get("xslt_kind") in ("match_template", "named_template")
            and `node.extra.get("match")
        {
            continue;
        }
        if `node.extra.get("abstract") {
            continue;
        }
        if _is_entry_point(`node) {
            continue;
        }
        if `node.kind == "Class" and `node.name in type_ref_names {
            continue;
        }
        if `node.kind == "Class" and _has_framework_decorator(`node) {
            continue;
        }
        _is_framework_class: any = False;
        _check_qn: any = `node.qualified_name
            if `node.kind == "Class"
            else `node.qualified_name.rsplit(".", 1)[0] if `node.parent_name else None;
        if _check_qn {
            base_names: any = {
                target.rsplit("::", 1)[-1]
                for target in base_targets.get(_check_qn, ())
            };
            if base_names & _FRAMEWORK_BASE_CLASSES {
                _is_framework_class = True;
            }
        }
        if `node.kind == "Class" {
            if _is_framework_class {
                continue;
            }
            if `any(`node.name.endswith(s) for s in _CDK_CLASS_SUFFIXES) {
                continue;
            }
        }
        if `node.kind == "Function" and _is_framework_class {
            continue;
        }
        if `node.kind == "Function"
            and `node.parent_name
            and `any(`node.parent_name.endswith(s) for s in _CDK_CLASS_SUFFIXES)
        {
            continue;
        }
        decorators: any = `node.extra.get("decorators", ());
        if isinstance(decorators, (`list, `tuple)) and decorators {
            if `node.kind in ("Function", "Test") {
                if `any(
                    d in ("property", "abstractmethod", "classmethod", "staticmethod")
                        or d.endswith(".abstractmethod")
                        or d.startswith("HostListener")
                    for d in decorators,
                ) {
                    continue;
                }
            }
            if `node.kind == "Class" {
                if `any("dataclass" in d for d in decorators) {
                    continue;
                }
            }
        }
        if `node.kind == "Function" and `node.parent_name {
            parent_qn: any = `node.qualified_name.rsplit(".", 1)[0];
            base_class_names: any = `list(base_targets.get(parent_qn, ()));
            base_name: any;
            for base_name in base_class_names {
                base_method_qn: any = f"{base_name}.{`node.name}";
                base_nodes: any = store.get_node(base_method_qn);
                if base_nodes is None {
                    base_method_qn2: any = `node.file_path + "::" + base_name + "." + `node.name;
                    base_nodes = store.get_node(base_method_qn2);
                }
                if base_nodes is not None {
                    base_decos: any = base_nodes.extra.get("decorators", ());
                    if isinstance(base_decos, (`list, `tuple))
                        and `any("abstractmethod" in d for d in base_decos)
                    {
                        break;
                    }
                }
            } else {
                base_name = None;
            }
            if base_name is not None {
                continue;
            }
        }

        incoming: any = `set(incoming_kinds.get(`node.qualified_name, ()));
        if "CALLS" not in incoming and `node.parent_name {
            class_qn: any = f"{`node.parent_name}::{`node.name}";
            incoming.update(incoming_kinds.get(class_qn, ()));
        }
        if "CALLS" not in incoming {
            bare_files: any = _bare_files(`node.name, `node.language or "");
            suffix_files: any = suffix_call_files.get(_ascii_fold(`node.name), set[any]());
            if `any(
                _is_plausible_caller(file, `node.file_path, `node.name)
                for file in bare_files | suffix_files,
            ) {
                incoming.add("CALLS");
            }
        }
        outgoing_tb: any = `bool(tested_files.get(`node.qualified_name));
        if not outgoing_tb and `node.parent_name {
            class_qn = f"{`node.parent_name}::{`node.name}";
            outgoing_tb = `bool(tested_files.get(class_qn));
        }
        if not outgoing_tb {
            outgoing_tb = `any(
                _is_plausible_caller(file, `node.file_path, `node.name)
                for file in tested_files.get(`node.name, ()),
            );
        }
        if `node.kind == "Class" and "INHERITS" not in incoming {
            if "INHERITS" in incoming_kinds.get(`node.name, ())
                and _bare_files(`node.name, `node.language or "", "INHERITS")
            {
                incoming.add("INHERITS");
            }
        }
        has_callers: any = "CALLS" in incoming;
        has_test_refs: any = `bool(outgoing_tb);
        has_importers: any = "IMPORTS_FROM" in incoming;
        has_references: any = "REFERENCES" in incoming;
        has_subclasses: any = "INHERITS" in incoming;
        no_refs: any = not (
            has_callers or has_test_refs or has_importers or has_references or has_subclasses
        );
        if `node.kind == "Class" and no_refs {
            if _ascii_fold(`node.name) in member_call_names {
                has_callers = True;
            }
        }

        if not (has_callers or has_test_refs or has_importers or has_references or has_subclasses) {
            if `node.kind == "Function" and `node.parent_name and not has_callers {
                method_suffix: any = "." + `node.name;
                if `node.qualified_name.endswith(method_suffix) {
                    class_qn = `node.qualified_name[:-len(method_suffix)];
                    for base_name in class_bases.get(class_qn, []) {
                        base_parents: any = [base_name];
                        if `node.language == "csharp" {
                            if csharp_member_scopes is None {
                                csharp_member_scopes = _csharp_member_scopes(conn);
                            }
                            base_parents += [
                                scope
                                for scope in csharp_member_scopes.get(
                                    base_name.rpartition(".")[2], ()
                                )
                                if scope != base_name and scope.endswith("." + base_name)
                            ];
                        }
                        rows: any = [
                            row
                            for parent in base_parents
                            for row in conn.execute(
                                "SELECT n.qualified_name FROM nodes n WHERE n.parent_name = ? AND n.name = ? AND n.kind IN ('Function', 'Test')",
                                (parent, `node.name),
                            ).fetchall()
                        ];
                        for (base_method_qn,) in rows {
                            if "CALLS" in incoming_kinds.get(base_method_qn, ()) {
                                has_callers = True;
                                break;
                            }
                        }
                        if has_callers {
                            break;
                        }
                    }
                }
            }

            if not has_callers {
                if `root {
                    try {
                        rel: any = `str(Path(`node.file_path).relative_to(`root));
                    } except ValueError {
                        rel = `node.file_path;
                    }
                } else {
                    rel = `node.file_path;
                }
                dead.append({
                    "name": _sanitize_name(`node.name),
                    "qualified_name": _sanitize_name(`node.qualified_name),
                    "kind": `node.kind,
                    "file": `node.file_path,
                    "file_path": `node.file_path,
                    "relative_path": rel,
                    "line": `node.line_start,
                    "language": `node.language,
                });
            }
        }
    }

    logger.info("find_dead_code: found %d dead symbols", len(dead));
    return dead;
}

impl suggest_refactorings(store: GraphStore) -> list[dict[str, Any]] {
    suggestions: list[dict[str, Any]] = [];
    dead: any = find_dead_code(store);
    for d in dead {
        suggestions.append({
            "type": "remove",
            "description": "Remove unused "
                + format(d["kind"].lower(), "")
                + " '"
                + format(d["name"], "")
                + "'",
            "symbols": [d["qualified_name"]],
            "rationale": "No callers, no test references, no importers, not an entry point.",
        });
    }
    community_rows: any = store.get_communities_list();

    if community_rows {
        node_community: dict[str, int] = {};
        for crow in community_rows {
            cid: any = crow["id"];
            member_qns: any = store.get_community_member_qns(cid);
            for qn in member_qns {
                node_community[qn] = cid;
            }
        }

        community_names: dict[int, str] = {r["id"]: r["name"] for r in community_rows};
        all_funcs: any = [
            `node
            for `node in store.get_nodes_by_kind(["Function"])
            if not `node.extra.get("verilog_kind")
        ];

        for fnode in all_funcs {
            f_community: any = node_community.get(fnode.qualified_name);
            if f_community is None {
                continue;
            }

            incoming_calls: any = [
                e
                for e in store.get_edges_by_target(fnode.qualified_name)
                if e.kind == "CALLS"
            ];
            if not incoming_calls {
                continue;
            }

            caller_communities: any = set[any]();
            for `edge in incoming_calls {
                c_community: any = node_community.get(`edge.source_qualified);
                if c_community is not None {
                    caller_communities.add(c_community);
                }
            }
            if len(caller_communities) == 1 {
                target_community: any = next(iter(caller_communities));
                if target_community != f_community {
                    src_name: any = community_names.get(f_community, f"community-{f_community}");
                    tgt_name: any = community_names.get(
                        target_community, f"community-{target_community}"
                    );
                    suggestions.append({
                        "type": "move",
                        "description": f"Move '{_sanitize_name(fnode.name)}' from '{src_name}' to '{tgt_name}'",
                        "symbols": [_sanitize_name(fnode.qualified_name)],
                        "rationale": f"Function is in community '{src_name}' but only called by members of community '{tgt_name}'.",
                    });
                }
            }
        }
    }

    logger.info("suggest_refactorings: produced %d suggestions", len(suggestions));
    return suggestions;
}

impl _apply_file_edits(text: str, file_edits: list[dict[str, Any]]) -> tuple[str, int, int] {
    claimed: dict[tuple[int, int], tuple[str, str]];
    index: any;
    lines: any = text.split("\n");
    claimed = {};
    value__: any = 0;
    applied: any = value__;
    skipped: any = value__;
    ordered: any = sorted(file_edits, key=lambda (e) -> any { e.get("column") is None });
    for edit in ordered {
        old_text: any = `str(edit.get("old", ""));
        new_text: any = `str(edit.get("new", ""));
        index = `int(edit.get("line") or 0) - 1;
        if not old_text or not 0 <= index < len(lines) {
            skipped += 1;
            continue;
        }
        line: any = lines[index];
        word: any = _ident_pattern(old_text);
        column: any = edit.get("column");
        start: Optional[int] = None;
        if column is not None {
            candidate: any = `int(column) - 1;
            `match: any = word.match(line, candidate) if candidate >= 0 else None;
            if `match is not None and `match.start() == candidate {
                start = candidate;
            }
        } else {
            start = next(
                (m.start() for m in word.finditer(line) if (index, m.start()) not in claimed), None
            );
        }
        if start is None {
            skipped += 1;
            continue;
        }
        if (index, start) in claimed {
            continue;
        }
        claimed[index, start] = (old_text, new_text);
        applied += 1;
    }

    by_line: dict[int, list[tuple[int, str, str]]] = {};
    for item___ in claimed.items() {
        ((index, start), (old_text, new_text)) = item___;
        by_line.setdefault(index, []).append((start, old_text, new_text));
    }
    replacements: any;
    for item____ in by_line.items() {
        (index, replacements) = item____;
        line = lines[index];
        for (start, old_text, new_text) in sorted(replacements, reverse=True) {
            line = line[:start] + new_text + line[start + len(old_text):];
        }
        lines[index] = line;
    }
    return ("\n".join(lines), applied, skipped);
}

impl apply_refactor(refactor_id: str, repo_root: Path, dry_run: bool = False) -> dict[str, Any] {
    count: any;
    repo_root = repo_root.resolve();

    with _refactor_lock {
        _cleanup_expired();
        preview: any = _pending_refactors.get(refactor_id);
    }

    if preview is None {
        logger.warning("apply_refactor: unknown or expired refactor_id %s", refactor_id);
        return {"status": "error", "error": f"Refactor '{refactor_id}' not found or expired."};
    }
    age: any = time.time() - preview["created_at"];
    if age > REFACTOR_EXPIRY_SECONDS {
        with _refactor_lock {
            _pending_refactors.pop(refactor_id, None);
        }
        logger.warning("apply_refactor: refactor %s expired (%.0fs old)", refactor_id, age);
        return {"status": "error", "error": f"Refactor '{refactor_id}' has expired."};
    }

    edits: any = preview.get("edits", []);
    if not edits {
        if dry_run {
            return {
                "status": "ok",
                "dry_run": True,
                "applied": 0,
                "files_modified": [],
                "edits_applied": 0,
                "would_modify": [],
                "diffs": {},
            };
        }
        return {"status": "ok", "applied": 0, "files_modified": [], "edits_applied": 0};
    }
    path_within_repo = importlib.import_module("code_review_graph.incremental").path_within_repo;

    with _refactor_lock {
        followed: any = _followed_edit_files.get(refactor_id, frozenset());
    }
    edit: any;
    for edit in edits {
        edit_path: any = Path(edit["file"]).resolve();
        try {
            edit_path.relative_to(repo_root);
        } except ValueError {
            if followed and path_within_repo(repo_root, edit["file"], followed) {
                continue;
            }
            logger.error(
                "apply_refactor: path traversal blocked for %s (repo_root=%s)", edit_path, repo_root
            );
            return {
                "status": "error",
                "error": "Edit path '" + format(edit["file"], "") + "' is outside repo root.",
            };
        }
    }
    import from collections { defaultdict }
    edits_by_file: dict[str, list[dict]] = defaultdict(list[any]);
    for edit in edits {
        edits_by_file[edit["file"]].append(edit);
    }
    planned: dict[str, tuple[str, str, int, bool]] = {};
    edits_skipped: any = 0;
    file_str: any;
    for (file_str, file_edits) in edits_by_file.items() {
        file_path: any = Path(file_str);
        if not file_path.is_file() {
            logger.warning("apply_refactor: file not found: %s", file_path);
            edits_skipped += len(file_edits);
            continue;
        }
        try {
            decoded: any = _decode_source(file_path.read_bytes());
        } except OSError as exc {
            logger.warning("apply_refactor: could not read %s: %s", file_path, exc);
            edits_skipped += len(file_edits);
            continue;
        }
        if decoded is None {
            logger.warning("apply_refactor: %s is not UTF-8; not rewritten", file_path);
            edits_skipped += len(file_edits);
            continue;
        }
        original: any;
        had_bom: any;
        (original, had_bom) = decoded as any;
        content: any;
        applied: any;
        skipped: any;
        (content, applied, skipped) = _apply_file_edits(original, file_edits) as any;
        edits_skipped += skipped;
        if skipped {
            logger.warning(
                "apply_refactor: %d edit(s) in %s no longer match the file", skipped, file_path
            );
        }
        if applied > 0 {
            planned[file_str] = (original, content, applied, had_bom);
        }
    }
    if dry_run {
        import difflib;
        diffs: dict[str, str] = {};
        new_content: any;
        for (file_str, (original, new_content, _count, _bom)) in planned.items() {
            diff_lines: any = `list(
                difflib.unified_diff(
                    original.splitlines(keepends=True),
                    new_content.splitlines(keepends=True),
                    fromfile=f"a/{file_str}",
                    tofile=f"b/{file_str}",
                    n=3,
                ),
            );
            diffs[file_str] = "".join(diff_lines);
        }
        total_edits: any = sum(count for (_o, _n, count, _b) in planned.values());
        result: any = {
            "status": "ok",
            "dry_run": True,
            "applied": 0,
            "edits_applied": total_edits,
            "would_modify": sorted(planned.keys()),
            "files_modified": [],
            "diffs": diffs,
        };
        if edits_skipped {
            result["edits_skipped"] = edits_skipped;
        }
        logger.info(
            "apply_refactor: dry-run %s — %d edits would be applied to %d files",
            refactor_id,
            total_edits,
            len(planned),
        );
        return result;
    }
    files_modified: set[str] = set[any]();
    edits_applied: any = 0;
    for (file_str, (_original, new_content, count, had_bom)) in planned.items() {
        file_path = Path(file_str);
        try {
            prefix: any = "﻿" if had_bom else "";
            file_path.write_bytes((prefix + new_content).encode("utf-8"));
            edits_applied += count;
            files_modified.add(`str(file_path));
            logger.info("apply_refactor: applied %d edit(s) to %s", count, file_path);
        } except OSError as exc {
            logger.error("apply_refactor: could not write %s: %s", file_path, exc);
        }
    }
    with _refactor_lock {
        _pending_refactors.pop(refactor_id, None);
    }

    result = {
        "status": "ok",
        "applied": edits_applied,
        "files_modified": sorted(files_modified),
        "edits_applied": edits_applied,
    };
    if edits_skipped {
        result["edits_skipped"] = edits_skipped;
    }
    logger.info("apply_refactor: completed %s — %d edits applied", refactor_id, edits_applied);
    return result;
}
