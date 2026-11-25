"""Host/Origin validation for the opt-in ``serve --http`` MCP endpoint.

``code-review-graph serve --http`` starts a FastMCP streamable-http server bound
to loopback (127.0.0.1:5555 by default). A loopback bind is not by itself an
access control for a browser: a page the user visits can point a hostname it
controls at 127.0.0.1 (DNS rebinding) and then drive the MCP tools, which read
the user's source tree.

The defense is to check the two headers the browser controls but cannot forge
away:

* ``Host`` — a rebound request arrives with the attacker's hostname, not
  ``127.0.0.1``/``localhost``, so an allow-list on ``Host`` rejects it.
* ``Origin`` — cross-site requests carry the initiating site's origin. Ordinary
  MCP clients are not browsers and send no ``Origin`` at all, so requiring the
  origin (when present) to be the loopback endpoint costs them nothing.

The guard is a **pure ASGI** middleware rather than a
``starlette.middleware.base.BaseHTTPMiddleware`` subclass: streamable-http keeps
long-lived streaming/SSE responses open, and ``BaseHTTPMiddleware`` buffers
through an anyio task pair that interferes with them.

It is applied only when the server is bound to a loopback address — the default.
Binding elsewhere (``--host 0.0.0.0``) is an explicit decision to expose the
endpoint, where the operator's own hostnames are legitimate, so the guard steps
aside rather than second-guessing that choice.
"""

import builtins;

import from __future__ { annotations }

import ipaddress;

import from starlette.middleware { Middleware }

import from starlette.types { ASGIApp, Receive, Scope, Send }

glob LOOPBACK_HOSTS: any;

glob _ALLOWED_ORIGIN_SCHEMES: any;

glob _FORBIDDEN_AUTHORITY_CHARS: any;

with entry {
    LOOPBACK_HOSTS = frozenset({"127.0.0.1", "localhost", "::1", "[::1]"});

    _ALLOWED_ORIGIN_SCHEMES = frozenset({"http", "https"});
    _FORBIDDEN_AUTHORITY_CHARS = frozenset("/\\?#@");
}

"""Return ``True`` when ``host`` is a loopback bind address."""
def is_loopback_host(host: str) -> bool;

"""Return a canonical valid TCP port, or ``None`` when invalid."""
def _normalize_port(value: str) -> str | None;

"""Split a ``Host``/authority value into a lowercased host and optional port.

    Handles bracketed IPv6 literals (``[::1]:5555``) as well as the usual
    ``127.0.0.1:5555`` and bare ``localhost`` forms.

    Invalid authorities return ``("", None)``. In particular, bracketed IPv6
    must end after ``]`` or continue with exactly ``:<numeric-port>``.
    """
def split_host_port(value: str) -> tuple[str, str | None];

async def _forbid(send: Send, message: str) -> None;

async def _guard_call(guard, scope: Scope, receive: Receive, send: Send) -> None;

"""Reject cross-origin and rebound-``Host`` requests to a loopback server.

    Args:
        app: The wrapped ASGI application.
        host: The address the server is bound to.
        port: The port the server is bound to.
    """
obj LoopbackOriginGuard {
    has app: any,
        enabled: any,
        port: any;

    def init(app: ASGIApp, *, host: str, port: int);

    def _authority_allowed(value: str | None, *, implicit_port: str | None = None) -> bool;

    static has __call__: any = _guard_call;

    def __repr__ -> str;

    def __eq__(other: any) -> bool;

    def __hash__ -> int;
}

"""Return the ASGI middleware stack for the ``serve --http`` transport.

    Shared by the server entry point and the tests so both exercise the same
    configuration.
    """
def build_http_middleware(host: str, port: int) -> list[Middleware];
