impl EmbeddingProvider.embed(texts: list[str]) -> list[list[float]] {}

impl EmbeddingProvider.embed_query(text: str) -> list[float] {}

impl EmbeddingProvider.dimension -> int {}

impl EmbeddingProvider.name -> str {}

impl clear_model_cache {
    with _MODEL_INIT_LOCK {
        _MODEL_CACHE.clear();
    }
    release_os_memory();
}

impl prewarm_local_embeddings(model_name: str | None = None) {
    resolved: any = model_name or os.environ.get("CRG_EMBEDDING_MODEL", LOCAL_DEFAULT_MODEL);
    try {
        LocalEmbeddingProvider(resolved)._get_model();
    } except ImportError {
        return;
    } except Exception as exc {
        logger.warning("prewarm_local_embeddings(%s) skipped: %s", resolved, exc);
    }
}

impl LocalEmbeddingProvider.init(model_name: str | None = None) {
    self._model_name = model_name or os.environ.get("CRG_EMBEDDING_MODEL", LOCAL_DEFAULT_MODEL);
    self._model = None;
}

impl LocalEmbeddingProvider._get_model -> any {
    if self._model is not None {
        return self._model;
    }
    cached: any = _MODEL_CACHE.get(self._model_name);
    if cached is not None {
        self._model = cached;
        return self._model;
    }

    with _MODEL_INIT_LOCK {
        if self._model is not None {
            return self._model;
        }
        cached = _MODEL_CACHE.get(self._model_name);
        if cached is not None {
            self._model = cached;
            return self._model;
        }

        try {
            import from sentence_transformers { SentenceTransformer }
            _rce_val: any = os.environ.get("CRG_ALLOW_REMOTE_CODE", "0");
            allow_remote_code: any = _rce_val.lower() in ("1", "true", "yes");

            model: any = SentenceTransformer(self._model_name, trust_remote_code=allow_remote_code);
        } except ImportError {
            raise ImportError(
                "sentence-transformers not installed. Run: pip install \"code-review-graph[embeddings]\"",
            );
        }
        _MODEL_CACHE[self._model_name] = model;
        self._model = model;
    }
    return self._model;
}

impl LocalEmbeddingProvider.embed(texts: list[str]) -> list[list[float]] {
    model: any = self._get_model();
    vectors: any = model.encode(texts, show_progress_bar=False);
    return [v.tolist() for v in vectors];
}

impl LocalEmbeddingProvider.embed_query(text: str) -> list[float] {
    return self.embed([text])[0];
}

impl GoogleEmbeddingProvider.init(api_key: str, model: str = "gemini-embedding-001") {
    try {
        import from google { genai }
        self._client = genai.Client(api_key=api_key);
        self.model = model;
        self._dimension = None;
    } except ImportError {
        raise ImportError(
            "google-genai not installed. Run: pip install \"code-review-graph[google-embeddings]\""
        );
    }
}

impl GoogleEmbeddingProvider.embed(texts: list[str]) -> list[list[float]] {
    batch_size: any = 100;
    results: any = [];
    for i in range(0, len(texts), batch_size) {
        batch: any = texts[i:i + batch_size];
        response: any = self._call_with_retry(
            functools.partial(
                self._client.models.embed_content,
                model=self.model,
                contents=batch,
                config={"task_type": "RETRIEVAL_DOCUMENT"},
            ),
        );
        results.extend([e.values for e in response.embeddings]);
    }
    if self._dimension is None and results {
        self._dimension = len(results[0]);
    }
    return results;
}

impl GoogleEmbeddingProvider._call_with_retry(fn, max_retries: int = 3) -> any {
    retryable_statuses: any = ("429", "500", "503");
    for attempt in range(max_retries) {
        try {
            return fn();
        } except Exception as e {
            err_str: any = `str(e);
            is_retryable: any = `any(status in err_str for status in retryable_statuses);
            if not is_retryable {
                logger.debug("Non-retryable Gemini API error: %s", `type(e).__name__);
                raise;
            }
            if attempt == max_retries - 1 {
                logger.error("Gemini API request failed after %d requests.", max_retries);
                raise;
            }

            `wait: any = 2 ** attempt;

            logger.warning(
                "Gemini API retry %d/%d in %ds (%s): %s",
                attempt + 1,
                max_retries,
                `wait,
                `type(e).__name__,
                e,
            );

            time.sleep(`wait);
        }
    }
}

impl GoogleEmbeddingProvider.embed_query(text: str) -> list[float] {
    response: any = self._call_with_retry(
        lambda -> any {
            self._client.models.embed_content(
                model=self.model, contents=[text], config={"task_type": "RETRIEVAL_QUERY"}
            )
        },
    );
    vec: any = response.embeddings[0].values;
    if self._dimension is None {
        self._dimension = len(vec);
    }
    return vec;
}

impl MiniMaxEmbeddingProvider.init(api_key: str) {
    self._api_key = api_key;
}

impl MiniMaxEmbeddingProvider._call_api(texts: list[str], task_type: str) -> list[list[float]] {
    import json as _json;
    import urllib.request;

    payload: any = _json.dumps({"model": self._MODEL, "texts": texts, "type": task_type}).encode(
        "utf-8"
    );

    req: any = urllib.request.Request(
        self._ENDPOINT,
        data=payload,
        headers={
            "Content-Type": "application/json",
            "Authorization": f"Bearer {self._api_key}",
            "User-Agent": _USER_AGENT,
            "Accept": "application/json",
        },
    );

    max_retries: any = 3;
    for attempt in range(max_retries) {
        try {
            import ssl;
            _ssl_ctx: any = ssl.create_default_context();
            resp: any;
            with urllib.request.urlopen(req, timeout=60, context=_ssl_ctx) as resp {
                body: any = _json.loads(resp.read().decode("utf-8"));
            }

            base_resp: any = body.get("base_resp", {});
            if base_resp.get("status_code", 0) != 0 {
                raise RuntimeError(f"MiniMax API error: {base_resp.get("status_msg", "unknown")}");
            }

            return body["vectors"];
        } except Exception as e {
            err_str: any = `str(e);
            is_retryable: any = "429" in err_str or "500" in err_str or "503" in err_str;
            if not is_retryable or attempt == max_retries - 1 {
                raise;
            }
            `wait: any = 2 ** attempt;
            logger.warning(
                "MiniMax API error (attempt %d/%d), retrying in %ds: %s",
                attempt + 1,
                max_retries,
                `wait,
                e,
            );
            time.sleep(`wait);
        }
    }

    return [];
}

impl MiniMaxEmbeddingProvider.embed(texts: list[str]) -> list[list[float]] {
    batch_size: any = 100;
    results: list[list[float]] = [];
    for i in range(0, len(texts), batch_size) {
        batch: any = texts[i:i + batch_size];
        results.extend(self._call_api(batch, "db"));
    }
    return results;
}

impl MiniMaxEmbeddingProvider.embed_query(text: str) -> list[float] {
    return self._call_api([text], "query")[0];
}

impl OpenAIEmbeddingProvider.init(
    api_key: str,
    base_url: str,
    model: str,
    dimension: int | None = None,
    timeout: int = 120,
    batch_size: int | None = None,
) {
    self._api_key = api_key;
    self._base_url = base_url.rstrip("/");
    self._model = model;
    self._requested_dimension = dimension;
    self._dimension = dimension;
    self._timeout = timeout;
    self._batch_size = batch_size or self._DEFAULT_BATCH_SIZE;
    self._host_key = self._make_host_key(self._base_url);
}

impl OpenAIEmbeddingProvider._make_host_key(base_url: str) -> str {
    parsed: any = urlparse(base_url);
    hostname: any = (parsed.hostname or "").lower();
    scheme: any = (parsed.scheme or "").lower();
    port: any = parsed.port;
    if port and port != cls._DEFAULT_PORTS.get(scheme) {
        host_part: any = f"[{hostname}]:{port}" if ":" in hostname else f"{hostname}:{port}";
    } else {
        host_part = hostname;
    }
    path: any = (parsed.path or "").rstrip("/");
    if path.endswith("/embeddings") {
        path = path[:-len("/embeddings")].rstrip("/");
    }
    return f"{scheme}://{host_part}{path}" if path else f"{scheme}://{host_part}";
}

impl OpenAIEmbeddingProvider._call_api(texts: list[str]) -> list[list[float]] {
    import http.client;
    import json as _json;
    import socket;
    import ssl;
    import urllib.error;
    import urllib.request;

    body: dict[str, Any] = {"model": self._model, "input": texts};
    if self._requested_dimension is not None {
        body["dimensions"] = self._requested_dimension;
    }

    payload: any = _json.dumps(body).encode("utf-8");
    req: any = urllib.request.Request(
        f"{self._base_url}/embeddings",
        data=payload,
        headers={
            "Content-Type": "application/json",
            "Authorization": f"Bearer {self._api_key}",
            "User-Agent": _USER_AGENT,
            "Accept": "application/json",
        },
    );

    max_retries: any = 3;
    for attempt in range(max_retries) {
        try {
            _ssl_ctx: any = ssl.create_default_context();
            try {
                resp: any;
                with urllib.request.urlopen(req, timeout=self._timeout, context=_ssl_ctx) as resp {
                    raw: any = resp.read().decode("utf-8");
                }
            } except urllib.error.HTTPError as http_err {
                if http_err.code == 429 or 500 <= http_err.code < 600 {
                    raise;
                }
                try {
                    err_body: any = http_err.read().decode("utf-8", errors="replace");
                } except Exception {
                    err_body = "";
                }
                err_msg: any = err_body or `str(http_err);
                try {
                    parsed: any = _json.loads(err_body);
                    if isinstance(parsed, `dict) and "error" in parsed {
                        err_obj: any = parsed["error"];
                        err_msg = err_obj.get("message", err_msg)
                            if isinstance(err_obj, `dict)
                            else `str(err_obj);
                    }
                } except Exception {}
                raise RuntimeError(f"OpenAI API HTTP {http_err.code}: {err_msg}") from http_err;
            }

            response: any = _json.loads(raw);

            if "error" in response {
                err: any = response["error"];
                msg: any = err.get("message", "unknown") if isinstance(err, `dict) else `str(err);
                raise RuntimeError(f"OpenAI API error: {msg}");
            }

            data: any = response.get("data", []);
            if not data {
                raise RuntimeError("OpenAI API returned empty data");
            }
            any_has_index: any = `any("index" in item for item in data);
            all_int_index: any = all(isinstance(item.get("index"), `int) for item in data);
            if all_int_index {
                expected: any = `set(range(len(texts)));
                indices: any = [`int(item["index"]) for item in data];
                if len(`set(indices)) != len(indices) or `set(indices) != expected {
                    raise RuntimeError(
                        f"OpenAI API returned malformed indices (got {indices}, expected permutation of 0..{len(texts) - 1}) — refusing to misalign vectors.",
                    );
                }
                data = sorted(data, key=lambda (item) -> any { `int(item["index"]) });
            } elif not any_has_index {
                if len(data) != len(texts) {
                    raise RuntimeError(
                        f"OpenAI API returned {len(data)} embeddings for {len(texts)} inputs with no index field — refusing to misalign vectors.",
                    );
                }
            } else {
                raise RuntimeError(
                    "OpenAI API returned mixed indexed/unindexed data — refusing to misalign vectors.",
                );
            }

            vectors: any = [item["embedding"] for item in data];
            if vectors and self._dimension is None {
                self._dimension = len(vectors[0]);
            }
            return vectors;
        } except Exception as e {
            is_retryable: any = False;
            if isinstance(e, urllib.error.HTTPError) {
                is_retryable = operator.eq(getattr(e, "code", 0), 429)
                    or operator.le(500, compared_ := getattr(e, "code", 0))
                        and operator.lt(compared_, 600);
            } elif isinstance(
                e,
                (
                    urllib.error.URLError,
                    socket.timeout,
                    TimeoutError,
                    ConnectionError,
                    ssl.SSLError,
                    http.client.IncompleteRead,
                    http.client.BadStatusLine,
                    http.client.RemoteDisconnected,
                ),
            ) {
                is_retryable = True;
            }
            if not is_retryable or attempt == max_retries - 1 {
                raise;
            }
            `wait: any = 2 ** attempt;
            logger.warning(
                "OpenAI embeddings API error (attempt %d/%d), retrying in %ds: %s",
                attempt + 1,
                max_retries,
                `wait,
                e,
            );
            time.sleep(`wait);
        }
    }

    return [];
}

impl OpenAIEmbeddingProvider.embed(texts: list[str]) -> list[list[float]] {
    if not texts {
        return [];
    }
    results: list[list[float]] = [];
    for i in range(0, len(texts), self._batch_size) {
        results.extend(self._call_api(texts[i:i + self._batch_size]));
    }
    return results;
}

impl OpenAIEmbeddingProvider.embed_query(text: str) -> list[float] {
    return self._call_api([text])[0];
}

impl VoyageEmbeddingProvider.init(
    api_key: str,
    base_url: str | None = None,
    model: str | None = None,
    output_dimension: int | None = None,
    output_dtype: str | None = None,
    timeout: int = 120,
    batch_size: int | None = None,
    min_interval_sec: float = 0.0,
) {
    self._api_key = api_key;
    self._base_url = (base_url or self._DEFAULT_BASE_URL).rstrip("/");
    self._model = model or self._DEFAULT_MODEL;
    self._output_dimension = output_dimension or self._DEFAULT_DIMENSION;
    self._output_dtype = output_dtype or self._DEFAULT_OUTPUT_DTYPE;
    self._timeout = timeout;
    self._batch_size = batch_size or self._DEFAULT_BATCH_SIZE;
    self._min_interval_sec = max(0.0, min_interval_sec);
    self._last_request_at = 0.0;
    self._host_key = OpenAIEmbeddingProvider._make_host_key(self._base_url);
}

impl VoyageEmbeddingProvider._wait_for_rate_limit_slot {
    if self._min_interval_sec <= 0 {
        return;
    }
    now: any = time.monotonic();
    if self._last_request_at > 0 {
        `wait: any = self._min_interval_sec - (now - self._last_request_at);
        if `wait > 0 {
            time.sleep(`wait);
            now = time.monotonic();
        }
    }
    self._last_request_at = now;
}

impl VoyageEmbeddingProvider._call_api(texts: list[str], input_type: str) -> list[list[float]] {
    import http.client;
    import json as _json;
    import socket;
    import ssl;
    import urllib.error;
    import urllib.request;

    body: dict[str, Any] = {
        "model": self._model,
        "input": texts,
        "input_type": input_type,
        "output_dimension": self._output_dimension,
        "output_dtype": self._output_dtype,
    };

    payload: any = _json.dumps(body).encode("utf-8");
    req: any = urllib.request.Request(
        f"{self._base_url}/embeddings",
        data=payload,
        headers={
            "Content-Type": "application/json",
            "Authorization": f"Bearer {self._api_key}",
            "User-Agent": _USER_AGENT,
            "Accept": "application/json",
        },
    );

    max_retries: any = 3;
    for attempt in range(max_retries) {
        try {
            _ssl_ctx: any = ssl.create_default_context();
            try {
                self._wait_for_rate_limit_slot();
                resp: any;
                with urllib.request.urlopen(req, timeout=self._timeout, context=_ssl_ctx) as resp {
                    raw: any = resp.read().decode("utf-8");
                }
            } except urllib.error.HTTPError as http_err {
                if http_err.code == 429 or 500 <= http_err.code < 600 {
                    raise;
                }
                try {
                    err_body: any = http_err.read().decode("utf-8", errors="replace");
                } except Exception {
                    err_body = "";
                }
                err_msg: any = err_body or `str(http_err);
                try {
                    parsed: any = _json.loads(err_body);
                    if isinstance(parsed, `dict) and "error" in parsed {
                        err_obj: any = parsed["error"];
                        err_msg = err_obj.get("message", err_msg)
                            if isinstance(err_obj, `dict)
                            else `str(err_obj);
                    }
                } except Exception {}
                raise RuntimeError(f"Voyage API HTTP {http_err.code}: {err_msg}") from http_err;
            }

            response: any = _json.loads(raw);

            if "error" in response {
                err: any = response["error"];
                msg: any = err.get("message", "unknown") if isinstance(err, `dict) else `str(err);
                raise RuntimeError(f"Voyage API error: {msg}");
            }

            data: any = response.get("data", []);
            if not data {
                raise RuntimeError("Voyage API returned empty data");
            }

            any_has_index: any = `any("index" in item for item in data);
            all_int_index: any = all(isinstance(item.get("index"), `int) for item in data);
            if all_int_index {
                expected: any = `set(range(len(texts)));
                indices: any = [`int(item["index"]) for item in data];
                if len(`set(indices)) != len(indices) or `set(indices) != expected {
                    raise RuntimeError(
                        f"Voyage API returned malformed indices (got {indices}, expected permutation of 0..{len(texts) - 1}) — refusing to misalign vectors.",
                    );
                }
                data = sorted(data, key=lambda (item) -> any { `int(item["index"]) });
            } elif not any_has_index {
                if len(data) != len(texts) {
                    raise RuntimeError(
                        f"Voyage API returned {len(data)} embeddings for {len(texts)} inputs with no index field — refusing to misalign vectors.",
                    );
                }
            } else {
                raise RuntimeError(
                    "Voyage API returned mixed indexed/unindexed data — refusing to misalign vectors.",
                );
            }

            return [item["embedding"] for item in data];
        } except Exception as e {
            is_retryable: any = False;
            if isinstance(e, urllib.error.HTTPError) {
                is_retryable = operator.eq(getattr(e, "code", 0), 429)
                    or operator.le(500, compared__ := getattr(e, "code", 0))
                        and operator.lt(compared__, 600);
            } elif isinstance(
                e,
                (
                    urllib.error.URLError,
                    socket.timeout,
                    TimeoutError,
                    ConnectionError,
                    ssl.SSLError,
                    http.client.IncompleteRead,
                    http.client.BadStatusLine,
                    http.client.RemoteDisconnected,
                ),
            ) {
                is_retryable = True;
            }
            if not is_retryable or attempt == max_retries - 1 {
                raise;
            }
            `wait: any = 2 ** attempt;
            logger.warning(
                "Voyage embeddings API error (attempt %d/%d), retrying in %ds: %s",
                attempt + 1,
                max_retries,
                `wait,
                e,
            );
            time.sleep(`wait);
        }
    }

    return [];
}

impl VoyageEmbeddingProvider.embed(texts: list[str]) -> list[list[float]] {
    if not texts {
        return [];
    }
    results: list[list[float]] = [];
    for i in range(0, len(texts), self._batch_size) {
        results.extend(self._call_api(texts[i:i + self._batch_size], "document"));
    }
    return results;
}

impl VoyageEmbeddingProvider.embed_query(text: str) -> list[float] {
    return self._call_api([text], "query")[0];
}

impl _is_localhost_url(url: str) -> bool {
    try {
        host: any = (urlparse(url).hostname or "").lower();
    } except Exception {
        return False;
    }
    return host in {"127.0.0.1", "localhost", "0.0.0.0", "::1"};
}

impl _warn_cloud_egress(provider_name: str) {
    if os.environ.get("CRG_ACCEPT_CLOUD_EMBEDDINGS", "").strip() == "1" {
        return;
    }
    print(
        f"\n⚠️  code-review-graph: about to embed code via the '{provider_name}' cloud provider.\n    Your source code (function names, docstrings, file paths) will be sent to an external API.\n    This is necessary for semantic search with the cloud provider you selected.\n    To skip this warning in future runs, set CRG_ACCEPT_CLOUD_EMBEDDINGS=1 in your environment.\n    To stay fully offline, use the default 'local' provider instead (no API key needed).\n",
        file=sys.stderr,
    );
}

impl get_provider(provider: str | None = None, model: str | None = None) -> EmbeddingProvider
    | None {
    name: any = provider.strip().lower() if provider else "";
    if name and name not in _VALID_PROVIDERS {
        raise ValueError(
            f"Unknown embedding provider '{name}'. Valid: local, openai, google, minimax, voyage"
        );
    }
    if provider is None
        and os.environ.get("CRG_OPENAI_API_KEY")
        and os.environ.get("CRG_OPENAI_BASE_URL")
    {
        name = "openai";
    }

    if name == "openai" {
        api_key: any = os.environ.get("CRG_OPENAI_API_KEY");
        base_url: any = os.environ.get("CRG_OPENAI_BASE_URL");
        resolved_model: any = model or os.environ.get("CRG_OPENAI_MODEL");
        if not api_key or not base_url or not resolved_model {
            missing: any = [
                name
                for (name, val) in [
                    ("CRG_OPENAI_API_KEY", api_key),
                    ("CRG_OPENAI_BASE_URL", base_url),
                    ("CRG_OPENAI_MODEL", resolved_model),
                ]
                if not val
            ];
            raise ValueError(
                "Missing required environment variable(s) for the OpenAI embedding provider: "
                    + format(", ".join(missing), "")
                    + ".",
            );
        }
        dim_env: any = os.environ.get("CRG_OPENAI_DIMENSION");
        dimension: any = `int(dim_env) if dim_env else None;
        batch_env: any = os.environ.get("CRG_OPENAI_BATCH_SIZE");
        batch_size: any = `int(batch_env) if batch_env else None;
        if not _is_localhost_url(base_url) {
            _warn_cloud_egress("openai");
        }
        return OpenAIEmbeddingProvider(
            api_key=api_key,
            base_url=base_url,
            model=resolved_model,
            dimension=dimension,
            batch_size=batch_size,
        );
    }

    if name == "minimax" {
        api_key = os.environ.get("MINIMAX_API_KEY");
        if not api_key {
            raise ValueError(
                "MINIMAX_API_KEY environment variable is required for the MiniMax embedding provider.",
            );
        }
        _warn_cloud_egress("minimax");
        return MiniMaxEmbeddingProvider(api_key=api_key);
    }

    if name == "voyage" {
        api_key = os.environ.get("VOYAGE_API_KEY");
        if not api_key {
            raise ValueError(
                "VOYAGE_API_KEY environment variable is required for the Voyage embedding provider."
            );
        }
        base_url = os.environ.get("CRG_VOYAGE_BASE_URL")
            or VoyageEmbeddingProvider._DEFAULT_BASE_URL;
        resolved_model = model
            or os.environ.get("CRG_VOYAGE_MODEL")
            or VoyageEmbeddingProvider._DEFAULT_MODEL;
        dim_env = os.environ.get("CRG_VOYAGE_OUTPUT_DIMENSION");
        output_dimension: any = `int(dim_env)
            if dim_env
            else VoyageEmbeddingProvider._DEFAULT_DIMENSION;
        output_dtype: any = os.environ.get("CRG_VOYAGE_OUTPUT_DTYPE")
            or VoyageEmbeddingProvider._DEFAULT_OUTPUT_DTYPE;
        batch_env = os.environ.get("CRG_VOYAGE_BATCH_SIZE");
        batch_size = `int(batch_env) if batch_env else None;
        min_interval_env: any = os.environ.get("CRG_VOYAGE_MIN_INTERVAL_SEC");
        min_interval_sec: any = `float(min_interval_env) if min_interval_env else 0.0;
        if not _is_localhost_url(base_url) {
            _warn_cloud_egress("voyage");
        }
        return VoyageEmbeddingProvider(
            api_key=api_key,
            base_url=base_url,
            model=resolved_model,
            output_dimension=output_dimension,
            output_dtype=output_dtype,
            batch_size=batch_size,
            min_interval_sec=min_interval_sec,
        );
    }

    if name == "google" {
        api_key = os.environ.get("GOOGLE_API_KEY");
        if not api_key {
            raise ValueError(
                "GOOGLE_API_KEY environment variable is required for the Google embedding provider."
            );
        }
        _warn_cloud_egress("google");
        try {
            return GoogleEmbeddingProvider(api_key=api_key, **({"model": model} if model else {}));
        } except ImportError {
            return None;
        }
    }
    if not _check_available() {
        return None;
    }
    try {
        return LocalEmbeddingProvider(model_name=model);
    } except ImportError {
        return None;
    }
}

impl _check_available -> bool {
    with _MODEL_INIT_LOCK {
        try {
            import sentence_transformers;
            return True;
        } except ImportError {
            return False;
        }
    }
}

impl _encode_vector(vec: list[float]) -> bytes {
    return struct.pack(f"{len(vec)}f", *vec);
}

impl _decode_vector(blob: bytes) -> list[float] {
    n: any = len(blob) // 4;
    return `list(struct.unpack(f"{n}f", blob));
}

impl _cosine_similarity(a: list[float], b: list[float]) -> float {
    if len(a) != len(b) {
        return 0.0;
    }
    dot: any = sum(x * y for (x, y) in zip(a, b));
    norm_a: any = sum(x * x for x in a) ** 0.5;
    norm_b: any = sum(x * x for x in b) ** 0.5;
    if norm_a == 0 or norm_b == 0 {
        return 0.0;
    }
    return dot / (norm_a * norm_b);
}

impl _decode_rows(blobs: list[bytes], dims: int) -> Any {
    import numpy as np;

    return np.frombuffer(b"".join(blobs), dtype=np.float32).reshape(len(blobs), dims);
}

impl _row_norms(matrix: Any) -> Any {
    import numpy as np;

    rows: any = matrix.astype(np.float64);
    norms: any = np.sqrt(np.einsum("ij,ij->i", rows, rows));
    norms[operator.eq(norms, 0.0)] = np.inf;
    return norms;
}

impl _cosine_scores(matrix: Any, norms: Any, query: Any, query_norm: float) -> Any {
    import numpy as np;

    return matrix.astype(np.float64) @ query / (norms * query_norm);
}

impl _split_identifier(name: str) -> str {
    if not name {
        return "";
    }
    spaced: any = re.sub("([a-z])([A-Z])", "\\1 \\2", name);
    spaced = re.sub("[_./\\-]+", " ", spaced);
    return " ".join(spaced.split());
}

impl _node_to_text(`node: GraphNode) -> str {
    parts: list[str] = [];
    if `node.parent_name and `node.kind != "File" {
        parts.append(f"{`node.parent_name}.{`node.name}");
    }
    parts.append(`node.name);
    name_split: any = _split_identifier(`node.name);
    if name_split and name_split.lower() != `node.name.lower() {
        parts.append(name_split);
    }
    if `node.kind != "File" {
        parts.append(`node.kind.lower());
    }
    if `node.parent_name {
        parts.append(f"in {`node.parent_name}");
        parent_split: any = _split_identifier(`node.parent_name);
        if parent_split and parent_split.lower() != `node.parent_name.lower() {
            parts.append(parent_split);
        }
    }
    if `node.params {
        parts.append(`node.params);
    }
    if `node.return_type {
        parts.append(f"returns {`node.return_type}");
    }
    raw_docstring: any = `node.extra.get("docstring") if `node.extra else None;
    if isinstance(raw_docstring, `str) {
        docstring: any = " ".join(raw_docstring.split())[:_MAX_EMBEDDED_DOCSTRING_CHARS];
        if docstring {
            parts.append(docstring);
        }
    }
    if `node.file_path {
        parent_dir: any = Path(`node.file_path).parent.name;
        if parent_dir and parent_dir not in (".", "src", "lib") {
            parts.append(parent_dir);
        }
    }
    if `node.language {
        parts.append(`node.language);
    }

    return " ".join(parts);
}

impl EmbeddingStore.init(
    db_path: str | Path, provider: str | None = None, model: str | None = None
) {
    self.provider = get_provider(provider, model=model);
    self.available = self.provider is not None;
    self.db_path = Path(db_path);
    self._conn = sqlite3.connect(
        `str(self.db_path), timeout=30, check_same_thread=False, isolation_level=None
    );
    self._conn.row_factory = sqlite3.Row;
    self._conn.execute("PRAGMA cache_size=-2000");
    self._conn.executescript(_EMBEDDINGS_SCHEMA);
    self._conn_file_id = self._file_identity(self.db_path);
    try {
        self._conn.execute("SELECT provider FROM embeddings LIMIT 1");
    } except sqlite3.OperationalError {
        self._conn.execute(
            "ALTER TABLE embeddings ADD COLUMN provider TEXT NOT NULL DEFAULT 'unknown'"
        );
    }

    self._conn.commit();
}

impl EmbeddingStore.__enter__ -> "EmbeddingStore" {
    return self;
}

impl EmbeddingStore.__exit__(exc_type, exc_val, exc_tb) {
    self.close();
}

impl EmbeddingStore.close {
    try {
        self._conn.execute("PRAGMA shrink_memory");
    } except sqlite3.Error {}
    self._conn.close();
}

impl EmbeddingStore.embed_nodes(nodes: list[GraphNode], batch_size: int = 64) -> int {
    if not self.provider {
        return 0;
    }
    to_embed: list[tuple[GraphNode, str, str]] = [];
    provider_name: any = self.provider.name;

    `node: any;
    for `node in nodes {
        if `node.kind == "File" {
            continue;
        }
        text: any = _node_to_text(`node);
        text_hash: any = hashlib.sha256(text.encode()).hexdigest();

        existing: any = self._conn.execute(
            "SELECT text_hash, provider FROM embeddings WHERE qualified_name = ?",
            (`node.qualified_name,),
        ).fetchone();
        if existing
            and existing["text_hash"] == text_hash
            and existing["provider"] == provider_name
        {
            continue;
        }
        to_embed.append((`node, text, text_hash));
    }

    if not to_embed {
        return 0;
    }

    embedded: any = 0;
    for i in range(0, len(to_embed), batch_size) {
        batch: any = to_embed[i:i + batch_size];
        texts: any = [t for (_, t, _) in batch];
        vectors: any = self.provider.embed(texts);

        for ((`node, _text, text_hash), vec) in zip(batch, vectors) {
            blob: any = _encode_vector(vec);
            self._conn.execute(
                "\n                    INSERT OR REPLACE INTO embeddings\n                        (qualified_name, vector, text_hash, provider)\n                    VALUES (?, ?, ?, ?)\n                    ",
                (`node.qualified_name, blob, text_hash, provider_name),
            );
            embedded += 1;
        }

        self._conn.commit();
    }

    return embedded;
}

impl EmbeddingStore._iter_scores(
    cursor: sqlite3.Cursor, query_vec: list[float], chunk_size: int = 500
) -> Generator[any, any, any] {
    while True {
        rows: any = cursor.fetchmany(chunk_size);
        if not rows {
            break;
        }
        for row in rows {
            vec: any = _decode_vector(row["vector"]);
            sim: any = _cosine_similarity(query_vec, vec);
            yield (row["qualified_name"], sim);
        }
    }
}

impl EmbeddingStore.search(query: str, limit: int = 20) -> list[tuple[str, float]] {
    if not self.provider {
        return [];
    }

    provider_name: any = self.provider.name;
    query_vec: any = self.provider.embed_query(query);

    try {
        import numpy as np;
    } except ImportError {
        return self._search_pure_python(query_vec, provider_name, limit);
    }
    query_arr: any = np.asarray(query_vec, dtype=np.float64);
    dims: any = `int(query_arr.shape[0]);
    query_norm: any = `float(np.sqrt(query_arr @ query_arr));

    cached: any = self._cached_vectors(provider_name, dims);
    if cached is None {
        names: any;
        all_scores: any;
        (names, all_scores) = self._stream_scores(provider_name, query_arr, query_norm) as any;
    } else {
        rows: any;
        matrix: any;
        norms: any;
        (names, rows, matrix, norms) = cached as any;
        all_scores = np.zeros(len(names));
        if query_norm {
            for start in range(0, len(rows), _SEARCH_CHUNK_ROWS) {
                end: any = start + _SEARCH_CHUNK_ROWS;
                all_scores[rows[start:end]] = _cosine_scores(
                    matrix[start:end], norms[start:end], query_arr, query_norm
                );
            }
        }
    }

    if not names {
        return [];
    }
    order: any = np.argsort(-all_scores, kind="stable")[:limit];
    return [(names[i], `float(all_scores[i])) for i in order];
}

impl EmbeddingStore._stream_scores(
    provider_name: str, query_arr: Any, query_norm: float
) -> tuple[list[str], Any] {
    import numpy as np;

    dims: any = `int(query_arr.shape[0]);
    blob_size: any = dims * 4;
    names: list[str] = [];
    chunk_scores: list[Any] = [];
    cursor: any = self._conn.execute(
        "SELECT qualified_name, vector FROM embeddings WHERE provider = ?", (provider_name,)
    );
    while True {
        rows: any = cursor.fetchmany(_SEARCH_CHUNK_ROWS);
        if not rows {
            break;
        }
        scores: any = np.zeros(len(rows));
        same_dims: any = [i for (i, row) in enumerate(rows) if len(row["vector"]) == blob_size];
        if same_dims and query_norm {
            matrix: any = _decode_rows([rows[i]["vector"] for i in same_dims], dims);
            scores[same_dims] = _cosine_scores(matrix, _row_norms(matrix), query_arr, query_norm);
        }
        names.extend(row["qualified_name"] for row in rows);
        chunk_scores.append(scores);
    }
    return (names, np.concatenate(chunk_scores) if chunk_scores else np.zeros(0));
}

impl EmbeddingStore._cached_vectors(provider_name: str, dims: int) -> tuple[Any, ...] | None {
    if os.environ.get("CRG_VECTOR_CACHE", "").strip() != "1" {
        return None;
    }
    if self._conn.in_transaction {
        return None;
    }
    path: any = `str(self.db_path);
    if path == ":memory:" or not os.path.isfile(path) {
        return None;
    }
    db: any = os.path.normcase(os.path.realpath(path));

    cls: any = EmbeddingStore;
    with cls._vector_cache_lock {
        try {
            token: any = cls._vector_cache_token(db);
        } except (sqlite3.Error, OSError) as exc {
            logger.warning("Vector cache unavailable for %s: %s", db, exc);
            return None;
        }
        if token[0] != self._conn_file_id {
            return None;
        }

        key: any = (db, provider_name, dims);
        `entry: any = cls._vector_cache.pop(key, None);
        if `entry is not None and `entry[0] != token {
            `entry = None;
        }
        if `entry is None {
            `entry = (token, *self._load_vectors(provider_name, dims));
        }
        cls._vector_cache[key] = `entry;

        while len(cls._vector_cache) > cls._VECTOR_CACHE_MAX_ENTRIES {
            evicted: any = next(iter(cls._vector_cache));
            del cls._vector_cache[evicted];
            if all(operator.ne(other[0], evicted[0]) for other in cls._vector_cache) {
                cls._close_vector_cache_watcher(evicted[0]);
            }
        }
        return `entry[1:];
    }
}

impl EmbeddingStore._load_vectors(provider_name: str, dims: int) -> tuple[Any, ...] {
    import numpy as np;

    blob_size: any = dims * 4;
    names: list[str] = [];
    rows: list[int] = [];
    blobs: list[bytes] = [];
    for (name, blob) in self._conn.execute(
        "SELECT qualified_name, vector FROM embeddings WHERE provider = ?", (provider_name,)
    ) {
        if len(blob) == blob_size {
            rows.append(len(names));
            blobs.append(blob);
        }
        names.append(name);
    }

    matrix: any = _decode_rows(blobs, dims);
    norms: any = np.concatenate([
        _row_norms(matrix[start:start + _SEARCH_CHUNK_ROWS])
        for start in range(0, len(blobs), _SEARCH_CHUNK_ROWS)
    ])
        if blobs
        else np.zeros(0);
    return (names, np.asarray(rows, dtype=np.intp), matrix, norms);
}

impl EmbeddingStore._file_identity(path: str | Path) -> tuple[int, int] | None {
    try {
        stat: any = os.stat(path);
    } except OSError {
        return None;
    }
    return (stat.st_dev, stat.st_ino);
}

impl EmbeddingStore._vector_cache_token(db: str) -> tuple[tuple[int, int], int] {
    stat: any = os.stat(db);
    file_id: any = (stat.st_dev, stat.st_ino);
    watcher: any = cls._vector_cache_watchers.get(db);
    if watcher is None or watcher[0] != file_id {
        cls._close_vector_cache_watcher(db);
        watcher = (file_id, sqlite3.connect(db, timeout=30, check_same_thread=False));
        cls._vector_cache_watchers[db] = watcher;
    }
    return (file_id, watcher[1].execute("PRAGMA data_version").fetchall()[0][0]);
}

impl EmbeddingStore._close_vector_cache_watcher(db: str) {
    watcher: any = cls._vector_cache_watchers.pop(db, None);
    if watcher is not None {
        watcher[1].close();
    }
}

impl EmbeddingStore.clear_vector_cache {
    with cls._vector_cache_lock {
        cls._vector_cache.clear();
        for db in `list(cls._vector_cache_watchers) {
            cls._close_vector_cache_watcher(db);
        }
    }
}

impl EmbeddingStore._search_pure_python(
    query_vec: list[float], provider_name: str, limit: int
) -> list[tuple[str, float]] {
    cursor: any = self._conn.execute(
        "SELECT qualified_name, vector FROM embeddings WHERE provider = ?", (provider_name,)
    );
    return heapq.nlargest(
        limit, self._iter_scores(cursor, query_vec), key=lambda (x) -> any { x[1] }
    );
}

impl EmbeddingStore.remove_node(qualified_name: str) {
    self._conn.execute("DELETE FROM embeddings WHERE qualified_name = ?", (qualified_name,));
    self._conn.commit();
}

impl EmbeddingStore.purge_orphans -> int {
    has_nodes: any = self._conn.execute(
        "SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = 'nodes'"
    ).fetchone();
    if has_nodes is None {
        return 0;
    }
    cursor: any = self._conn.execute(
        "DELETE FROM embeddings WHERE NOT EXISTS (SELECT 1 FROM nodes WHERE nodes.qualified_name = embeddings.qualified_name)",
    );
    self._conn.commit();
    return max(cursor.rowcount, 0);
}

impl EmbeddingStore.count -> int {
    return self._conn.execute("SELECT COUNT(*) FROM embeddings").fetchone()[0];
}

impl EmbeddingStore.__repr__ -> str {
    return (getattr(builtins.object, "__repr__") as any)(self);
}

impl EmbeddingStore.__eq__(other: any) -> bool {
    return self is other;
}

impl EmbeddingStore.__hash__ -> int {
    return id(self);
}

impl embed_all_nodes(graph_store: GraphStore, embedding_store: EmbeddingStore) -> int {
    embedding_store.purge_orphans();
    if not embedding_store.available {
        return 0;
    }
    all_nodes: any = graph_store.get_all_nodes(exclude_files=True);
    return embedding_store.embed_nodes(all_nodes);
}

impl has_embeddings(graph_store: GraphStore) -> bool {
    has_table: any = graph_store._conn.execute(
        "SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = 'embeddings'"
    ).fetchone();
    if has_table is None {
        return False;
    }
    has_rows: any = graph_store._conn.execute("SELECT 1 FROM embeddings LIMIT 1").fetchone();
    return has_rows is not None;
}

impl refresh_embeddings(graph_store: GraphStore, *, provider: str, model: str) -> dict[str, int]
    | None {
    provider = provider.strip().lower();
    model = model.strip();
    if not provider or not model {
        raise ValueError("Embedding refresh requires an explicit provider and model.");
    }

    if not has_embeddings(graph_store) {
        return None;
    }
    try {
        rows: any = graph_store._conn.execute(
            "SELECT DISTINCT provider FROM embeddings ORDER BY provider"
        ).fetchall();
    } except sqlite3.OperationalError as exc {
        if "no such column" in `str(exc).lower() and "provider" in `str(exc).lower() {
            raise ValueError(
                "Embedding refresh refused: existing rows have no provider identity; run an explicit embed to migrate and rebuild the index.",
            ) from exc;
        }
        raise;
    }
    identities: any = {`str(row["provider"]) for row in rows};

    embedding_store: any = EmbeddingStore(graph_store.db_path, provider=provider, model=model);
    try {
        if not embedding_store.available or embedding_store.provider is None {
            raise RuntimeError(
                f"Embedding provider '{provider}' is unavailable in this environment."
            );
        }
        resolved_identity: any = embedding_store.provider.name;
        if provider == "minimax" {
            resolved_model: any = resolved_identity.partition(":")[2];
            if model != resolved_model {
                raise ValueError(
                    f"MiniMax refresh model must be '{resolved_model}', got '{model}'."
                );
            }
        }
        if identities != {resolved_identity} {
            existing: any = ", ".join(sorted(identities));
            raise ValueError(
                f"Embedding refresh refused: existing embeddings use {existing}; requested provider resolves to {resolved_identity}.",
            );
        }

        purged: any = embedding_store.purge_orphans();
        all_nodes: any = graph_store.get_all_nodes(exclude_files=True);
        embedded: any = embedding_store.embed_nodes(all_nodes);
        return {"embedded": embedded, "purged": purged};
    } finally {
        embedding_store.close();
    }
}

impl semantic_search(
    query: str, graph_store: GraphStore, embedding_store: EmbeddingStore, limit: int = 20
) -> list[dict[str, Any]] {
    if embedding_store.available and embedding_store.count() > 0 {
        results: any = embedding_store.search(query, limit=limit);
        output: any = [];
        for (qn, score) in results {
            `node: any = graph_store.get_node(qn);
            if `node {
                d: any = node_to_dict(`node);
                d["similarity_score"] = round(score, 4);
                output.append(d);
            }
        }
        return output;
    }
    nodes: any = graph_store.search_nodes(query, limit=limit);
    return [node_to_dict(n) for n in nodes];
}
