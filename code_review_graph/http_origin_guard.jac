import from __future__ { annotations }

import builtins;

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

def is_loopback_host(host: str) -> bool;
def _normalize_port(value: str) -> str | None;
def split_host_port(value: str) -> tuple[str, str | None];

async def _forbid(send: Send, message: str);

async def _guard_call(guard, scope: Scope, receive: Receive, send: Send);

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

def build_http_middleware(host: str, port: int) -> list[Middleware];
