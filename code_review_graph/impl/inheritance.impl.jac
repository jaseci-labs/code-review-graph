impl _load_extra(raw: Optional[str]) -> dict {
    try {
        payload: any = json.loads(raw or "{}");
    } except (TypeError, json.JSONDecodeError) {
        return {};
    }
    return payload if isinstance(payload, `dict) else {};
}

impl _is_interface(language: str, extra: dict) -> bool {
    if language == "java" {
        return operator.eq(extra.get("java_kind"), "interface");
    }
    if language in ("typescript", "tsx") {
        return extra.get("typescript_kind") in ("interface_declaration", "type_alias_declaration");
    }
    if language == "php" {
        return extra.get("php_kind") in ("interface", "trait");
    }
    return False;
}

impl _strip_type(raw: str) -> str {
    text: any = raw.strip();
    for stop in ("<", "(", "[") {
        text = text.split(stop, 1)[0];
    }
    return text.strip();
}

impl InheritanceIndex.init(
    conn: sqlite3.Connection,
    import_targets: dict[str, set[str]],
    raw_imports: dict[str, dict[str, str]],
) {
    self._imports = import_targets;
    self._raw_imports = raw_imports;
    self._classes = {};
    self._by_name = {};
    self._java_fqcn = {};
    self._java_package = {};
    row: any;
    for row in conn.execute(
        "SELECT qualified_name, name, file_path, parent_name, language, extra FROM nodes WHERE kind = 'Class'",
    ) {
        qualified: any = row["qualified_name"];
        language: any = row["language"] or "";
        extra: any = _load_extra(row["extra"]);
        self._classes[qualified] = (
            row["name"],
            row["file_path"],
            language,
            _is_interface(language, extra),
        );
        self._by_name.setdefault(row["name"], []).append(qualified);
        package: any = extra.get("java_package");
        if language == "java" and isinstance(package, `str) and package {
            self._java_package.setdefault(row["file_path"], package);
            outer: any = format(row["parent_name"], "") + "." if row["parent_name"] else "";
            fqcn: any = format(package, "") + "." + format(outer, "") + format(row["name"], "");
            self._java_fqcn[fqcn] = qualified if fqcn not in self._java_fqcn else None;
        }
    }

    self._php_namespaces = {};
    for row in conn.execute(
        "SELECT file_path, extra FROM nodes WHERE kind = 'File' AND extra LIKE '%\"php_namespaces\"%'",
    ) {
        declared: any = _load_extra(row["extra"]).get("php_namespaces");
        if isinstance(declared, `list) {
            self._php_namespaces[row["file_path"]] = {
                ns
                for ns in declared
                if isinstance(ns, `str) and ns
            };
        }
    }
    self._php_fqn = {};
    for (qualified, (name, file_path, language, _)) in self._classes.items() {
        if language != "php" {
            continue;
        }
        for namespace in self._php_namespaces.get(file_path, ()) {
            fqn: any = f"{namespace}\\{name}";
            self._php_fqn[fqn] = qualified if fqn not in self._php_fqn else None;
        }
    }
    self._methods = {};
    for row in conn.execute(
        "SELECT qualified_name, name FROM nodes WHERE kind IN ('Function', 'Test') AND parent_name IS NOT NULL",
    ) {
        owner: any = row["qualified_name"].rpartition(".")[0];
        if owner in self._classes {
            self._methods.setdefault((owner, row["name"]), row["qualified_name"]);
        }
    }

    self._raw_parents = {};
    for row in conn.execute(
        "SELECT source_qualified, target_qualified, extra FROM edges WHERE kind = 'INHERITS'"
    ) {
        if row["source_qualified"] in self._classes {
            self._raw_parents.setdefault(row["source_qualified"], []).append((
                row["target_qualified"],
                _load_extra(row["extra"]),
            ));
        }
    }

    self._parents = {};
    self._inherited = {};
}

impl InheritanceIndex.is_class(qualified_name: str) -> bool {
    return qualified_name in self._classes;
}

impl InheritanceIndex.has_parents(qualified_name: str) -> bool {
    return qualified_name in self._raw_parents;
}

impl InheritanceIndex.java_package(file_path: str) -> Optional[str] {
    return self._java_package.get(file_path);
}

impl InheritanceIndex.method_of(class_name: str, method: str) -> Optional[str] {
    return self._methods.get((class_name, method));
}

impl InheritanceIndex.resolve_type(raw: str, context_file: str, language: str) -> Optional[str] {
    text: any = _strip_type(raw);
    if language == "php" {
        absolute: any = text.startswith("\\");
        namespace: any;
        _: any;
        name: any;
        (namespace, _, name) = text.strip("\\").rpartition("\\") as any;
    } else {
        absolute = False;
        (namespace, name) = ("", text.rpartition(".")[2]);
    }
    candidates: any = self._by_name.get(name, []);
    if not candidates {
        return None;
    }
    if namespace {
        wanted: any = {namespace};
        if not absolute {
            head: any;
            rest: any;
            (head, _, rest) = namespace.partition("\\") as any;
            wanted = {f"{ns}\\{namespace}" for ns in self._php_namespaces.get(context_file, ())};
            for target in self._imports.get(context_file, ()) {
                if target.rpartition("\\")[2] == head and "\\" in target {
                    wanted.add(f"{target}\\{rest}" if rest else target);
                }
            }
        }
        return self._only([
            c
            for c in candidates
            if self._php_namespaces.get(self._classes[c][1], set[any]()) & wanted
        ]);
    }
    same_file: any = [c for c in candidates if self._classes[c][1] == context_file];
    if same_file {
        return self._only(same_file);
    }
    full_name: any = self._raw_imports.get(context_file, {}).get(name);
    if full_name is not None and language == "java" {
        return self._java_fqcn.get(full_name);
    }
    if full_name is not None and language == "php" {
        return self._php_fqn.get(full_name.strip("\\"));
    }
    imported_files: any = self._imports.get(context_file, set[any]());
    imported: any = [c for c in candidates if self._classes[c][1] in imported_files];
    if imported {
        return self._only(imported);
    }
    if language == "java" {
        package: any = self._java_package.get(context_file);
        if package {
            return self._only([
                c
                for c in candidates
                if self._java_package.get(self._classes[c][1]) == package
            ]);
        }
    }
    if language == "php" {
        namespaces: any = self._php_namespaces.get(context_file, set[any]());
        if namespaces {
            return self._only([
                c
                for c in candidates
                if self._php_namespaces.get(self._classes[c][1], set[any]()) & namespaces
            ]);
        }
    }
    return None;
}

impl InheritanceIndex.inherited_method(class_name: str, method: str) -> Optional[str] {
    key: any = (class_name, method);
    if key not in self._inherited {
        self._inherited[key] = self._walk(class_name, method);
    }
    return self._inherited[key];
}

impl InheritanceIndex._only(candidates: list[str]) -> Optional[str] {
    unique: any = `set(candidates);
    return next(iter(unique)) if len(unique) == 1 else None;
}

impl InheritanceIndex._resolve_parent(child: str, raw: str, extra: dict) -> Optional[str] {
    if raw in self._classes {
        return raw;
    }
    _: any;
    child_file: any;
    language: any;
    (_, child_file, language, _) = self._classes[child] as any;
    if language == "java" {
        java_type: any = extra.get("java_type");
        if isinstance(java_type, `str) and "." in _strip_type(java_type) {
            return self._java_fqcn.get(_strip_type(java_type));
        }
    }
    return self.resolve_type(raw, child_file, language);
}

impl InheritanceIndex._parents_of(class_name: str) -> tuple[list[str], bool] {
    if class_name not in self._parents {
        child_is_interface: any = self._classes[class_name][3];
        known: list[str] = [];
        unknown: any = False;
        for (raw, extra) in self._raw_parents.get(class_name, ()) {
            parent: any = self._resolve_parent(class_name, raw, extra);
            if parent is None {
                unknown = True;
            } elif parent == class_name {
                continue;
            } elif self._classes[parent][3] and not child_is_interface {
                continue;
            } elif parent not in known {
                known.append(parent);
            }
        }
        self._parents[class_name] = (known, unknown);
    }
    return self._parents[class_name];
}

impl InheritanceIndex._walk(class_name: str, method: str) -> Optional[str] {
    current: any = class_name;
    seen: any = {current};
    for _ in range(_MAX_DEPTH) {
        parents: any;
        unknown: any;
        (parents, unknown) = self._parents_of(current) as any;
        if len(parents) > 1 {
            return self._only_declaration(current, method);
        }
        if not parents {
            return None;
        }
        if unknown and self._classes[current][2] not in _SINGLE_SUPERCLASS {
            return None;
        }
        parent: any = parents[0];
        if parent in seen {
            return None;
        }
        seen.add(parent);
        found: any = self._methods.get((parent, method));
        if found {
            return found;
        }
        current = parent;
    }
    return None;
}

impl InheritanceIndex._only_declaration(class_name: str, method: str) -> Optional[str] {
    found: set[str] = set[any]();
    seen: any = {class_name};
    frontier: any = [class_name];
    for _ in range(_MAX_DEPTH) {
        if not frontier {
            break;
        }
        next_frontier: list[str] = [];
        for current in frontier {
            parents: any;
            unknown: any;
            (parents, unknown) = self._parents_of(current) as any;
            if unknown {
                return None;
            }
            for parent in parents {
                if parent in seen {
                    continue;
                }
                seen.add(parent);
                declared: any = self._methods.get((parent, method));
                if declared {
                    found.add(declared);
                }
                next_frontier.append(parent);
            }
        }
        frontier = next_frontier;
    } else {
        return None;
    }
    return next(iter(found)) if len(found) == 1 else None;
}

impl InheritanceIndex.__repr__ -> str {
    return (getattr(builtins.object, "__repr__") as any)(self);
}

impl InheritanceIndex.__eq__(other: any) -> bool {
    return self is other;
}

impl InheritanceIndex.__hash__ -> int {
    return id(self);
}
