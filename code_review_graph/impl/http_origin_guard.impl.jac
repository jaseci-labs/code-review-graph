impl is_loopback_host(host: str) -> bool {
    value: any = host.strip().lower();
    if value == "localhost" {
        return True;
    }
    if value.startswith("[") and value.endswith("]") {
        value = value[1:-1];
    }
    try {
        return ipaddress.ip_address(value).is_loopback;
    } except ValueError {
        return False;
    }
}

impl _normalize_port(value: str) -> str | None {
    if not value.isdigit() {
        return None;
    }
    port: any = `int(value);
    if not 0 <= port <= 65535 {
        return None;
    }
    return `str(port);
}

impl split_host_port(value: str) -> tuple[str, str | None] {
    value = value.strip();
    if not value
        or `any(char.isspace() for char in value)
        or `any(char in _FORBIDDEN_AUTHORITY_CHARS for char in value)
    {
        return ("", None);
    }

    if value.startswith("[") {
        closing: any = value.find("]");
        if closing <= 1 {
            return ("", None);
        }
        literal: any = value[1:closing];
        rest: any = value[closing + 1:];
        try {
            address: any = ipaddress.ip_address(literal);
        } except ValueError {
            return ("", None);
        }
        if address.version != 6 {
            return ("", None);
        }
        if not rest {
            port: any = None;
        } elif rest.startswith(":") {
            port = _normalize_port(rest[1:]);
            if port is None {
                return ("", None);
            }
        } else {
            return ("", None);
        }
        return (f"[{address.compressed}]", port);
    }

    if "[" in value or "]" in value or value.count(":") > 1 {
        return ("", None);
    }

    host: any;
    separator: any;
    raw_port: any;
    (host, separator, raw_port) = value.rpartition(":") as any;
    if separator {
        if not host {
            return ("", None);
        }
        port = _normalize_port(raw_port);
        if port is None {
            return ("", None);
        }
    } else {
        host = value;
        port = None;
    }

    try {
        host = ipaddress.ip_address(host).compressed;
    } except ValueError {
        host = host.lower();
    }
    return (host, port);
}

impl _forbid(send: Send, message: str) -> None {
    body: any = message.encode();
    await send({
        "type": "http.response.start",
        "status": 403,
        "headers": [
            (b"content-type", b"text/plain; charset=utf-8"),
            (b"content-length", `str(len(body)).encode()),
        ],
    });
    await send({"type": "http.response.body", "body": body});
}

impl _guard_call(guard, scope: Scope, receive: Receive, send: Send) -> None {
    if not guard.enabled or scope["type"] != "http" {
        await guard.app(scope, receive, send);
        return;
    }

    headers: any = {
        key.decode("latin-1").lower(): value.decode("latin-1")
        for (key, value) in scope["headers"]
    };
    if not guard._authority_allowed(headers.get("host")) {
        await _forbid(send, "Forbidden: unrecognized Host header");
        return;
    }
    origin: any = headers.get("origin");
    if origin is not None {
        scheme: any;
        separator: any;
        authority: any;
        (scheme, separator, authority) = origin.partition("://") as any;
        if not separator
            or scheme.lower() not in _ALLOWED_ORIGIN_SCHEMES
            or not guard._authority_allowed(
                authority, implicit_port="443" if scheme.lower() == "https" else "80"
            )
        {
            await _forbid(send, "Forbidden: cross-origin request");
            return;
        }
    }

    await guard.app(scope, receive, send);
}

impl LoopbackOriginGuard.init(app: ASGIApp, *, host: str, port: int) {
    self.app = app;
    self.enabled = is_loopback_host(host);
    self.port = `str(port);
}

impl LoopbackOriginGuard._authority_allowed(
    value: str | None, *, implicit_port: str | None = None
) -> bool {
    if not value {
        return False;
    }
    host: any;
    port: any;
    (host, port) = split_host_port(value) as any;
    effective_port: any = port if port is not None else implicit_port;
    if effective_port is not None and effective_port != self.port {
        return False;
    }
    return is_loopback_host(host);
}

impl LoopbackOriginGuard.__repr__ -> str {
    return (getattr(builtins.object, "__repr__") as any)(self);
}

impl LoopbackOriginGuard.__eq__(other: any) -> bool {
    return self is other;
}

impl LoopbackOriginGuard.__hash__ -> int {
    return id(self);
}

impl build_http_middleware(host: str, port: int) -> list[Middleware] {
    return [Middleware(LoopbackOriginGuard, host=host, port=port)];
}
