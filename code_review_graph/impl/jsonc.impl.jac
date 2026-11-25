impl has_comments(raw: str) -> bool {
    index: any = 0;
    length: any = len(raw);
    while index < length {
        char: any = raw[index];
        if char == "\"" {
            index += 1;
            while index < length {
                if raw[index] == "\\" {
                    index += 2;
                    continue;
                }
                if raw[index] == "\"" {
                    index += 1;
                    break;
                }
                index += 1;
            }
            continue;
        }
        if char == "/" and index + 1 < length and raw[index + 1] in "/*" {
            return True;
        }
        index += 1;
    }
    return False;
}

impl has_unclosed_comment(raw: str) -> bool {
    index: any = 0;
    length: any = len(raw);
    while index < length {
        char: any = raw[index];
        if char == "\"" {
            index += 1;
            while index < length {
                if raw[index] == "\\" {
                    index += 2;
                    continue;
                }
                if raw[index] == "\"" {
                    index += 1;
                    break;
                }
                index += 1;
            }
            continue;
        }
        if char == "/" and index + 1 < length and raw[index + 1] == "/" {
            newline: any = raw.find("\n", index + 2);
            if newline < 0 {
                return False;
            }
            index = newline;
            continue;
        }
        if char == "/" and index + 1 < length and raw[index + 1] == "*" {
            end: any = raw.find("*/", index + 2);
            if end < 0 {
                return True;
            }
            index = end + 2;
            continue;
        }
        index += 1;
    }
    return False;
}

impl tokenize(raw: str) -> list[Token] {
    tokens: list[Token] = [];
    i: any = 0;
    while i < len(raw) {
        char: any = raw[i];
        if char.isspace() {
            i += 1;
            continue;
        }
        if char == "/" and i + 1 < len(raw) {
            if raw[i + 1] == "/" {
                newline: any = raw.find("\n", i + 2);
                i = len(raw) if newline < 0 else newline;
                continue;
            }
            if raw[i + 1] == "*" {
                end: any = raw.find("*/", i + 2);
                i = len(raw) if end < 0 else end + 2;
                continue;
            }
        }
        if char == "\"" {
            start: any = i;
            i += 1;
            while i < len(raw) {
                if raw[i] == "\\" {
                    i += 2;
                    continue;
                }
                if raw[i] == "\"" {
                    i += 1;
                    break;
                }
                i += 1;
            } else {
                raise ValueError("unterminated JSON string");
            }
            try {
                value: any = json.loads(raw[start:i]);
            } except json.JSONDecodeError as exc {
                raise ValueError(f"invalid JSON string: {exc}") from exc;
            }
            tokens.append(Token("string", start, i, value));
            continue;
        }
        if char in "{}[]:," {
            tokens.append(Token(char, i, i + 1));
            i += 1;
            continue;
        }
        start = i;
        while i < len(raw) {
            if raw[i].isspace() or raw[i] in "{}[]:," {
                break;
            }
            if raw[i] == "/" and i + 1 < len(raw) and raw[i + 1] in "/*" {
                break;
            }
            i += 1;
        }
        if i == start {
            raise ValueError(f"unexpected JSONC character at offset {i}");
        }
        tokens.append(Token("literal", start, i, raw[start:i]));
    }
    return tokens;
}

impl skip_value(tokens: Sequence[Token], index: int) -> int {
    if index >= len(tokens) {
        raise ValueError("missing JSON value");
    }
    token: any = tokens[index];
    if token.kind not in ("{", "[") {
        return index + 1;
    }
    closing: any = "}" if token.kind == "{" else "]";
    depth: any = 1;
    index += 1;
    while index < len(tokens) {
        kind: any = tokens[index].kind;
        if kind == token.kind {
            depth += 1;
        } elif kind == closing {
            depth -= 1;
            if depth == 0 {
                return index + 1;
            }
        } elif kind in ("{", "[") {
            index = skip_value(tokens, index);
            continue;
        }
        index += 1;
    }
    raise ValueError("unterminated JSON container");
}

impl object_members(tokens: Sequence[Token], index: int) -> list[Member] {
    if index >= len(tokens) or tokens[index].kind != "{" {
        raise ValueError("expected JSON object");
    }
    members: list[Member] = [];
    cursor: any = index + 1;
    while cursor < len(tokens) and tokens[cursor].kind != "}" {
        if tokens[cursor].kind == "," {
            cursor += 1;
            continue;
        }
        key_token: any = tokens[cursor];
        if key_token.kind != "string" or not isinstance(key_token.value, `str) {
            raise ValueError("expected JSON object key");
        }
        if cursor + 1 >= len(tokens) or tokens[cursor + 1].kind != ":" {
            raise ValueError("expected colon after JSON object key");
        }
        value_index: any = cursor + 2;
        value_end: any = skip_value(tokens, value_index);
        comma_index: any = value_end
            if value_end < len(tokens) and tokens[value_end].kind == ","
            else None;
        members.append(Member(key_token.value, cursor, value_index, value_end, comma_index));
        cursor = value_end + 1 if comma_index is not None else value_end;
    }
    return members;
}

impl array_elements(tokens: Sequence[Token], index: int) -> list[Element] {
    if index >= len(tokens) or tokens[index].kind != "[" {
        raise ValueError("expected JSON array");
    }
    elements: list[Element] = [];
    cursor: any = index + 1;
    while cursor < len(tokens) and tokens[cursor].kind != "]" {
        if tokens[cursor].kind == "," {
            cursor += 1;
            continue;
        }
        value_end: any = skip_value(tokens, cursor);
        comma_index: any = value_end
            if value_end < len(tokens) and tokens[value_end].kind == ","
            else None;
        elements.append(Element(cursor, value_end, comma_index));
        cursor = value_end + 1 if comma_index is not None else value_end;
    }
    return elements;
}

impl find_value(tokens: Sequence[Token], path: Sequence[str | int]) -> int {
    if not tokens {
        raise ValueError("empty JSON document");
    }
    current: any = 0;
    for component_ in path {
        component: any = component_;
        if isinstance(component, `str) {
            member: any = next(
                (item for item in object_members(tokens, current) if item.key == component), None
            );
            if member is None {
                raise KeyError(component);
            }
            current = member.value_index;
        } else {
            elements: any = array_elements(tokens, current);
            if component < 0 or component >= len(elements) {
                raise IndexError(component);
            }
            current = elements[component].value_index;
        }
    }
    return current;
}

impl removal_ranges(tokens: Sequence[Token], path: Sequence[str | int]) -> list[tuple[int, int]] {
    if not path {
        raise ValueError("refusing to remove the JSON document root");
    }
    parent_index: any = find_value(tokens, path[:-1]);
    component: any = path[-1];
    if isinstance(component, `str) {
        members: any = object_members(tokens, parent_index);
        sibling_index: any = next(
            (index for (index, member) in enumerate(members) if member.key == component), None
        );
        if sibling_index is None {
            raise KeyError(component);
        }
        item: any = members[sibling_index];
        start: any = tokens[item.key_index].start;
        end: any = tokens[item.value_end - 1].end;
        if item.comma_index is not None {
            return [(start, tokens[item.comma_index].end)];
        }
        if sibling_index > 0 {
            previous: any = members[sibling_index - 1];
            if previous.comma_index is not None {
                return [
                    (tokens[previous.comma_index].start, tokens[previous.comma_index].end),
                    (start, end),
                ];
            }
        }
        return [(start, end)];
    }

    elements: any = array_elements(tokens, parent_index);
    if component < 0 or component >= len(elements) {
        raise IndexError(component);
    }
    element: any = elements[component];
    start = tokens[element.value_index].start;
    end = tokens[element.value_end - 1].end;
    if element.comma_index is not None {
        return [(start, tokens[element.comma_index].end)];
    }
    if component > 0 {
        previous_element: any = elements[component - 1];
        if previous_element.comma_index is not None {
            return [
                (
                    tokens[previous_element.comma_index].start,
                    tokens[previous_element.comma_index].end,
                ),
                (start, end),
            ];
        }
    }
    return [(start, end)];
}

impl _in_ranges(position: int, ranges: list[tuple[int, int]]) -> bool {
    for (lo, hi) in ranges {
        if lo <= position and position < hi {
            return True;
        }
    }
    return False;
}

impl remove_paths(raw: str, paths: Iterable[Sequence[str | int]]) -> str {
    tokens: any = tokenize(raw);
    ranges: any = [
        source_range
        for path in paths
        for source_range in removal_ranges(tokens, `tuple(path))
    ];
    merged: list[tuple[int, int]] = [];
    start: any;
    end: any;
    for (start, end) in sorted(`set(ranges)) {
        if merged and start <= merged[-1][1] {
            merged[-1] = (merged[-1][0], max(end, merged[-1][1]));
        } else {
            merged.append((start, end));
        }
    }
    for (start, end) in reversed(merged) {
        raw = raw[:start] + raw[end:];
    }
    original_trailing: any = {
        token.start
        for (index, token) in enumerate(tokens[:-1])
        if token.kind == "," and tokens[index + 1].kind in ("}", "]")
    };
    surviving: any = [token for token in tokens if not _in_ranges(token.start, merged)];
    exposed: any = [
        token.start
        for (index, token) in enumerate(surviving[:-1])
        if token.kind == ","
            and surviving[index + 1].kind in ("}", "]")
            and token.start not in original_trailing
    ];
    for offset_ in reversed(exposed) {
        offset: any = offset_;
        rewritten_offset: any = offset
            - sum(end - start for (start, end) in merged if end <= offset);
        raw = raw[:rewritten_offset] + raw[rewritten_offset + 1:];
    }
    return raw;
}

impl _column_of(raw: str, offset: int) -> int {
    line_start: any = raw.rfind("\n", 0, offset) + 1;
    return max(offset - line_start, 0);
}

impl _line_indent(raw: str, offset: int) -> int {
    line_start: any = raw.rfind("\n", 0, offset) + 1;
    cursor: any = line_start;
    while cursor < len(raw) and raw[cursor] in " \t" {
        cursor += 1;
    }
    return cursor - line_start;
}

impl _render(value: Any, column: int) -> str {
    text: any = json.dumps(value, indent=2, ensure_ascii=False);
    return text.replace("\n", "\n" + " " * column);
}

impl _past_trailing_comment(raw: str, offset: int) -> int {
    cursor: any = offset;
    while cursor < len(raw) and raw[cursor] in " \t" {
        cursor += 1;
    }
    if raw.startswith("//", cursor) {
        newline: any = raw.find("\n", cursor);
        end: any = len(raw) if newline < 0 else newline;
        return end - 1 if end > cursor and raw[end - 1] == "\r" else end;
    }
    if raw.startswith("/*", cursor) {
        close: any = raw.find("*/", cursor + 2);
        if close >= 0 and "\n" not in raw[cursor:close] {
            return close + 2;
        }
    }
    return offset;
}

impl value_has_comments(raw: str, path: Sequence[str | int]) -> bool {
    tokens: any = tokenize(raw);
    index: any = find_value(tokens, path);
    end: any = skip_value(tokens, index);
    return has_comments(raw[tokens[index].start:tokens[end - 1].end]);
}

impl set_member(raw: str, path: Sequence[str], value: Any) -> str {
    if not path {
        raise ValueError("refusing to replace the JSON document root");
    }
    tokens: any = tokenize(raw);
    parent_index: any = find_value(tokens, path[:-1]);
    if tokens[parent_index].kind != "{" {
        raise ValueError("parent of the target member is not a JSON object");
    }
    key: any = path[-1];
    members: any = object_members(tokens, parent_index);
    existing: any = next((item for item in members if item.key == key), None);
    if existing is not None {
        start: any = tokens[existing.value_index].start;
        end: any = tokens[existing.value_end - 1].end;
        column: any = _column_of(raw, tokens[existing.key_index].start);
        return raw[:start] + _render(value, column) + raw[end:];
    }

    if members {
        last: any = members[-1];
        column = _column_of(raw, tokens[last.key_index].start);
        member_text: any = f"{json.dumps(key)}: {_render(value, column)}";
        if last.comma_index is not None {
            anchor: any = _past_trailing_comment(raw, tokens[last.comma_index].end);
            return raw[:anchor] + "\n" + " " * column + member_text + raw[anchor:];
        }
        value_end: any = tokens[last.value_end - 1].end;
        anchor = _past_trailing_comment(raw, value_end);
        return raw[:value_end]
            + ","
            + raw[value_end:anchor]
            + "\n"
            + " " * column
            + member_text
            + raw[anchor:];
    }
    open_end: any = tokens[parent_index].end;
    close_index: any = skip_value(tokens, parent_index) - 1;
    close_start: any = tokens[close_index].start;
    outer: any = _line_indent(raw, tokens[parent_index].start);
    column = outer + 2;
    member_text = f"{json.dumps(key)}: {_render(value, column)}";
    inner: any = raw[open_end:close_start];
    return raw[:open_end]
        + (inner.rstrip() if has_comments(inner) else "")
        + "\n"
        + " " * column
        + member_text
        + "\n"
        + " " * outer
        + raw[close_start:];
}
