impl _extract_annotation_string_arg(deco_text: str) -> Optional[str] {
    `match: any = re.search("(?:pointcut|value)\\s*=\\s*\"((?:[^\"\\\\]|\\\\.)*)\"", deco_text);
    if not `match {
        `match = re.search("\"((?:[^\"\\\\]|\\\\.)*)\"", deco_text);
    }
    if not `match {
        return None;
    }
    if deco_text[:`match.start()].rstrip().endswith("+")
        or deco_text[`match.end():].lstrip().startswith("+")
    {
        return None;
    }
    return `match.group(1);
}

impl _annotation_head(deco_text: str) -> str {
    head: any = deco_text.split("(", 1)[0].strip().lstrip("@").strip();
    return head.rsplit(".", 1)[-1].strip();
}

impl _glob_matches(pattern: str, text: str) -> bool {
    value_: any = 0;
    p: any = value_;
    t: any = value_;
    mark: any = value_;
    star: any = -1;
    while t < len(text) {
        if p < len(pattern) and pattern[p] == "*" {
            (star, mark) = (p, t);
            p += 1;
        } elif p < len(pattern) and pattern[p] == text[t] {
            p += 1;
            t += 1;
        } elif star >= 0 {
            mark += 1;
            (p, t) = (star + 1, mark);
        } else {
            return False;
        }
    }
    return not pattern[p:].strip("*");
}

impl _DottedPattern.init(pattern: str, any_package_prefix: bool = False) {
    self._parts = [None] if any_package_prefix else [];
    for (index, run) in enumerate(pattern.split("..")) {
        if index {
            self._parts.append(None);
        }
        if run {
            self._parts.extend(run.split("."));
        }
    }
}

impl _DottedPattern.`match(subject: str) -> bool {
    segments: any = subject.split(".");
    if "" in segments {
        return False;
    }
    reachable: any = {0};
    for part in self._parts {
        if part is None {
            reachable = `set(range(min(reachable), len(segments) + 1));
        } else {
            reachable = {
                position + 1
                for position in reachable
                if position < len(segments) and _glob_matches(part, segments[position])
            };
        }
        if not reachable {
            return False;
        }
    }
    return len(segments) in reachable;
}

impl _DottedPattern.__repr__ -> str {
    return (getattr(builtins.object, "__repr__") as any)(self);
}

impl _DottedPattern.__eq__(other: any) -> bool {
    return self is other;
}

impl _DottedPattern.__hash__ -> int {
    return id(self);
}

impl _parse_execution_expression(expr: str) -> Optional[tuple[_DottedPattern, bool]] {
    m: any = _EXECUTION_POINTCUT.match(expr);
    if not m {
        return None;
    }
    inner: any = m.group(1).strip();
    m2: any = re.match("^(.*)\\((.*)\\)\\s*$", inner, re.DOTALL);
    if not m2 {
        return None;
    }
    before_params: any = m2.group(1).strip();
    tokens: any = before_params.split();
    if not tokens {
        return None;
    }
    if `any(token.startswith(("@", "!")) for token in tokens) {
        return None;
    }
    method_class_pattern: any = tokens[-1];
    if not method_class_pattern or method_class_pattern.endswith(".") {
        return None;
    }

    needs_class: any = "." in method_class_pattern;
    universal_type: any = operator.eq(method_class_pattern.split(".")[0], "*")
        and operator.eq(method_class_pattern.count("."), 1);
    return (_DottedPattern(method_class_pattern, universal_type), needs_class);
}

impl _resolve_pointcut_expr(expr: str, pointcuts: dict[str, str]) -> Optional[str] {
    if `any(op in expr for op in _COMPOUND_OPERATORS) {
        return None;
    }

    ref: any = _NAMED_POINTCUT_REF.match(expr);
    if ref {
        name: any = ref.group(1);
        resolved: any = pointcuts.get(name);
        if resolved is None or `any(op in resolved for op in _COMPOUND_OPERATORS) {
            return None;
        }
        return resolved;
    }

    if "." in expr and "(" in expr and not _DESIGNATOR_PREFIX.match(expr) {
        return None;
    }

    return expr;
}

impl _load_extra(raw: Optional[str]) -> dict {
    try {
        return json.loads(raw or "{}");
    } except (json.JSONDecodeError, TypeError) {
        return {};
    }
}

impl resolve_aop_advice(store: "GraphStore") -> dict {
    row: any;
    aspect: any;
    candidate: any;
    conn: any = store._conn;

    java_files: set[str] = {
        row["file_path"]
        for row in conn.execute(
            "SELECT DISTINCT file_path FROM nodes WHERE language = 'java'"
        ).fetchall()
    };
    if not java_files {
        return {
            "aspects_indexed": 0,
            "advice_resolved": 0,
            "calls_created": 0,
            "stale_calls_removed": 0,
        };
    }
    stale_ids: list[tuple[int]] = [];
    for row in conn.execute("SELECT id, extra FROM edges WHERE kind = 'CALLS'").fetchall() {
        if _load_extra(row["extra"]).get(_DERIVED_FLAG) {
            stale_ids.append((row["id"],));
        }
    }
    if stale_ids {
        conn.executemany("DELETE FROM edges WHERE id = ?", stale_ids);
    }
    aspect_classes: list[dict] = [];
    class_package_by_name_file: dict[tuple[str, str], str] = {};
    for row in conn.execute(
        "SELECT name, qualified_name, file_path, extra FROM nodes WHERE kind = 'Class' AND language = 'java'",
    ).fetchall() {
        extra: any = _load_extra(row["extra"]);
        class_package_by_name_file[row["name"], row["file_path"]] = extra.get("java_package") or "";
        if "Aspect" in (extra.get("spring_annotations") or []) {
            aspect_classes.append({
                "name": row["name"],
                "qualified_name": row["qualified_name"],
                "file_path": row["file_path"],
            });
        }
    }

    if not aspect_classes {
        logger.info("AOP resolver: no @Aspect classes found, skipping");
        return {
            "aspects_indexed": 0,
            "advice_resolved": 0,
            "calls_created": 0,
            "stale_calls_removed": len(stale_ids),
        };
    }
    aspect_keys: any = {(aspect["name"], aspect["file_path"]) for aspect in aspect_classes};
    all_methods: list[dict] = [];
    methods_by_class_file: dict[tuple[str, str], list[dict]] = {};
    for row in conn.execute(
        "SELECT kind, name, qualified_name, parent_name, file_path, extra FROM nodes WHERE kind IN ('Function', 'Test') AND language = 'java' AND parent_name IS NOT NULL",
    ).fetchall() {
        extra = _load_extra(row["extra"]);
        `entry: any = {
            "name": row["name"],
            "qualified_name": row["qualified_name"],
            "parent_name": row["parent_name"],
            "file_path": row["file_path"],
            "decorators": extra.get("decorators") or [],
            "java_package": class_package_by_name_file.get(
                (row["parent_name"], row["file_path"]), ""
            ),
        };
        key: any = (row["parent_name"], row["file_path"]);
        if row["kind"] == "Function"
            and key not in aspect_keys
            and not extra.get("java_constructor")
        {
            all_methods.append(`entry);
        }
        methods_by_class_file.setdefault((row["parent_name"], row["file_path"]), []).append(`entry);
    }

    advice_resolved: any = 0;
    calls_created: any = 0;

    for aspect in aspect_classes {
        methods: any = methods_by_class_file.get((aspect["name"], aspect["file_path"]), []);

        pointcuts: dict[str, str] = {};
        advices: list[tuple[dict, str, str]] = [];
        for method in methods {
            for deco in method["decorators"] {
                head: any = _annotation_head(deco);
                if head == "Pointcut" {
                    pc_expr: any = _extract_annotation_string_arg(deco);
                    if pc_expr {
                        pointcuts[method["name"]] = pc_expr;
                    }
                } elif head in _ADVICE_ANNOTATIONS {
                    adv_expr: any = _extract_annotation_string_arg(deco);
                    if adv_expr {
                        advices.append((method, head, adv_expr));
                    }
                }
            }
        }

        for (advice_method, advice_kind, raw_expr) in advices {
            expr: any = _resolve_pointcut_expr(raw_expr, pointcuts);
            if not expr {
                continue;
            }

            ann_match: any = _ANNOTATION_POINTCUT.match(expr);
            if ann_match {
                fqcn: any = ann_match.group(1).strip();
                bare_name: any = fqcn.rsplit(".", 1)[-1].strip();
                if not bare_name {
                    continue;
                }
                pointcut_kind: any = "@annotation";
                targets: any = [
                    candidate
                    for candidate in all_methods
                    if `any(
                        operator.eq(_annotation_head(d), bare_name) for d in candidate["decorators"]
                    )
                ];
            } else {
                parsed: any = _parse_execution_expression(expr);
                if not parsed {
                    continue;
                }
                pattern: any;
                needs_class: any;
                (pattern, needs_class) = parsed as any;
                pointcut_kind = "execution";
                targets = [];
                for candidate in all_methods {
                    if needs_class {
                        if not candidate["parent_name"] {
                            continue;
                        }
                        class_part: any = f"{candidate["java_package"]}.{candidate["parent_name"]}"
                            if candidate["java_package"]
                            else candidate["parent_name"];
                        subject: any = f"{class_part}.{candidate["name"]}";
                    } else {
                        subject = candidate["name"];
                    }
                    if pattern.match(subject) {
                        targets.append(candidate);
                    }
                }
            }

            if not targets {
                continue;
            }

            advice_resolved += 1;
            for target in targets {
                if target["qualified_name"] == advice_method["qualified_name"] {
                    continue;
                }
                store.upsert_edge(
                    EdgeInfo(
                        kind="CALLS",
                        source=advice_method["qualified_name"],
                        target=target["qualified_name"],
                        file_path=advice_method["file_path"],
                        line=0,
                        extra={
                            _DERIVED_FLAG: True,
                            "pointcut_kind": pointcut_kind,
                            "pointcut_expr": expr,
                            "advice_kind": advice_kind,
                            "confidence": 0.7,
                            "confidence_tier": "INFERRED",
                        },
                    ),
                );
                calls_created += 1;
            }
        }
    }

    store.commit();
    logger.info(
        "AOP resolver: %d @Aspect classes, %d advice resolved, %d CALLS edges created",
        len(aspect_classes),
        advice_resolved,
        calls_created,
    );
    return {
        "aspects_indexed": len(aspect_classes),
        "advice_resolved": advice_resolved,
        "calls_created": calls_created,
        "stale_calls_removed": len(stale_ids),
    };
}
