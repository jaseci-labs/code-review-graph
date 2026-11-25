"""Vector embedding support for semantic code search.

Supports multiple providers:
1. Local (sentence-transformers) - Private, fast, offline.
2. Google Gemini - High-quality, cloud-based. Requires explicit opt-in.
3. MiniMax (embo-01) - High-quality 1536-dim cloud embeddings. Requires MINIMAX_API_KEY.
4. OpenAI-compatible - Any endpoint speaking OpenAI /v1/embeddings (OpenAI,
   Azure OpenAI or one you run yourself).
5. Voyage AI - Code retrieval embeddings via the Voyage embeddings API.
"""

import builtins;

import operator;

import from __future__ { annotations }

import functools;

import hashlib;

import heapq;

import logging;

import os;

import re;

import sqlite3;

import struct;

import sys;

import threading;

import time;

import from abc { ABC, abstractmethod }

import from pathlib { Path }

import from typing { Any }

import from urllib.parse { urlparse }

glob logger: any;

glob _USER_AGENT: any;

glob LOCAL_DEFAULT_MODEL: any;

glob _MODEL_CACHE: dict[str, Any];

glob _MODEL_INIT_LOCK: any;

glob CLOUD_PROVIDERS: any;

glob _VALID_PROVIDERS: any;

glob _EMBEDDINGS_SCHEMA: any;

glob _SEARCH_CHUNK_ROWS: any;

glob _IDENTIFIER_SPLIT_RE: any;

glob _MAX_EMBEDDED_DOCSTRING_CHARS: any;

glob REFRESH_SKIPPED_WARNING: any;

with entry {
    logger = logging.getLogger(__name__);
    _USER_AGENT = f"code-review-graph/{_crg_version} (+https://github.com/tirth8205/code-review-graph)";
}

class EmbeddingProvider(ABC) {
    @abstractmethod
    def embed(texts: list[str]) -> list[list[float]];

    """Embed a search query (may use a different task type than indexing)."""
    @abstractmethod
    def embed_query(text: str) -> list[float];

    @builtins.property
    @abstractmethod
    def dimension -> int;

    @builtins.property
    @abstractmethod
    def name -> str;
}

with entry {
    LOCAL_DEFAULT_MODEL = "all-MiniLM-L6-v2";
    _MODEL_CACHE = {};
    _MODEL_INIT_LOCK = threading.RLock();
}

"""Release cached sentence-transformer models and return memory to OS."""
def clear_model_cache -> None;

"""Eagerly load the local sentence-transformer model on the calling thread.

    Call this from the **main thread** before entering an asyncio event loop
    (e.g. before ``mcp.run()``) on Windows to prevent a deadlock where lazy-
    loading ``sentence_transformers`` + ``torch`` inside a FastMCP executor
    worker thread blocks indefinitely on DLL init / OpenMP thread-pool
    registration.

    No-op when ``sentence-transformers`` is not installed (cloud-provider
    setups remain unaffected) or when the configured model is already cached.

    Args:
        model_name: Optional override; falls back to the ``CRG_EMBEDDING_MODEL``
            environment variable and then to ``LOCAL_DEFAULT_MODEL``.
    """
def prewarm_local_embeddings(model_name: str | None = None) -> None;

class LocalEmbeddingProvider(EmbeddingProvider) {
    def init(model_name: str | None = None);

    def _get_model -> any;

    def embed(texts: list[str]) -> list[list[float]];

    def embed_query(text: str) -> list[float];

    has dimension: int {
        getter {
            model: any = self._get_model();
            if hasattr(model, "get_embedding_dimension") {
                return model.get_embedding_dimension();
            }
            return model.get_sentence_embedding_dimension();
        }
    }

    has name: str {
        getter {
            return f"local:{self._model_name}";
        }
    }
}

class GoogleEmbeddingProvider(EmbeddingProvider) {
    def init(api_key: str, model: str = "gemini-embedding-001");

    def embed(texts: list[str]) -> list[list[float]];

    """Call fn with exponential backoff on transient API errors."""
    static def _call_with_retry(fn, max_retries: int = 3) -> any;

    def embed_query(text: str) -> list[float];

    has dimension: int {
        getter {
            if self._dimension is not None {
                return self._dimension;
            }
            return 768;
        }
    }

    has name: str {
        getter {
            return f"google:{self.model}";
        }
    }
}

"""MiniMax embo-01 embedding provider (1536 dimensions).

    Uses the MiniMax Embeddings API (https://api.minimax.io/v1/embeddings)
    with the embo-01 model. Requires the MINIMAX_API_KEY environment variable.
    """
class MiniMaxEmbeddingProvider(EmbeddingProvider) {
    static has _ENDPOINT: any = "https://api.minimax.io/v1/embeddings";

    static has _MODEL: any = "embo-01";

    static has _DIMENSION: any = 1536;

    def init(api_key: str);

    def _call_api(texts: list[str], task_type: str) -> list[list[float]];

    def embed(texts: list[str]) -> list[list[float]];

    def embed_query(text: str) -> list[float];

    has dimension: int {
        getter {
            return self._DIMENSION;
        }
    }

    has name: str {
        getter {
            return f"minimax:{self._MODEL}";
        }
    }
}

"""OpenAI-compatible embedding provider.

    Works with any endpoint that speaks the OpenAI ``/v1/embeddings`` schema:
    - Real OpenAI API (``https://api.openai.com/v1``)
    - Azure OpenAI
    - Any endpoint you run yourself that speaks the same schema

    Provider identity in ``name`` includes both the model and the endpoint
    host (``openai:{model}@{host}``), so switching base URL while keeping the
    same model ID re-partitions the embeddings table and forces a clean
    re-embed. This is the only defense against silently mixing vector spaces
    from different backends (e.g. real OpenAI vs. an OpenAI-compatible
    gateway that ships different weights under the same model name).

    When no dimension is explicitly requested, it is detected from the first
    response and retained as local metadata. Switching the ``model`` in the
    environment also changes ``provider.name`` and triggers re-embed via the
    same isolation key.
    """
class OpenAIEmbeddingProvider(EmbeddingProvider) {
    static has _DEFAULT_BATCH_SIZE: any = 100;

    static has _DEFAULT_PORTS: any = {"http": 80, "https": 443};

    def init(
        api_key: str,
        base_url: str,
        model: str,
        dimension: int | None = None,
        timeout: int = 120,
        batch_size: int | None = None,
    );

    """Normalize the identity key used in ``provider.name``.

        Codex review pushed this well past naive ``netloc`` because that
        alone has three leaks:

        1. ``netloc`` preserves ``userinfo`` (``user:pass@host``) — we'd
           persist credentials into the DB's ``embeddings.provider`` column.
           Use ``hostname`` instead.
        2. Default ports (``:80`` for http, ``:443`` for https) are
           semantically identical to omitting the port; keeping them would
           cause spurious re-embeds when the user just spelled the URL
           differently.
        3. Path is part of the backend identity for path-routed gateways:
           ``https://gw/openai/v1`` and ``https://gw/vendor-b/v1`` front
           different models and must not share cached vectors.
        """
    class def _make_host_key(base_url: str) -> str;

    def _call_api(texts: list[str]) -> list[list[float]];

    def embed(texts: list[str]) -> list[list[float]];

    def embed_query(text: str) -> list[float];

    has dimension: int {
        getter {
            if self._dimension is not None {
                return self._dimension;
            }
            return 1536;
        }
    }

    has name: str {
        getter {
            return f"openai:{self._model}@{self._host_key}";
        }
    }
}

"""Voyage AI embedding provider.

    Uses Voyage's embeddings API with document/query input types so indexed
    source-derived node text and search queries are embedded with the task hint
    Voyage expects. Provider identity includes model, dimension, dtype, and
    endpoint to avoid mixing incompatible vector spaces.
    """
class VoyageEmbeddingProvider(EmbeddingProvider) {
    static has _DEFAULT_BASE_URL: any = "https://api.voyageai.com/v1";

    static has _DEFAULT_MODEL: any = "voyage-code-3";

    static has _DEFAULT_DIMENSION: any = 1024;

    static has _DEFAULT_OUTPUT_DTYPE: any = "float";

    static has _DEFAULT_BATCH_SIZE: any = 100;

    def init(
        api_key: str,
        base_url: str | None = None,
        model: str | None = None,
        output_dimension: int | None = None,
        output_dtype: str | None = None,
        timeout: int = 120,
        batch_size: int | None = None,
        min_interval_sec: float = 0.0,
    );

    def _wait_for_rate_limit_slot -> None;

    def _call_api(texts: list[str], input_type: str) -> list[list[float]];

    def embed(texts: list[str]) -> list[list[float]];

    def embed_query(text: str) -> list[float];

    has dimension: int {
        getter {
            return self._output_dimension;
        }
    }

    has name: str {
        getter {
            return f"voyage:{self._model}:dim{self._output_dimension}:{self._output_dtype}@{self._host_key}";
        }
    }
}

with entry {
    CLOUD_PROVIDERS = {"google", "minimax", "openai", "voyage"};
}

"""Return True if url points to a localhost host (never treat as cloud egress).

    Uses urlparse.hostname so we compare the actual host, not a substring
    match that could be fooled by e.g. ``https://my-openai.127.0.0.1.nip.io``.
    """
def _is_localhost_url(url: str) -> bool;

"""Print a stderr warning before a cloud embedding provider is used.

    The warning is suppressed when ``CRG_ACCEPT_CLOUD_EMBEDDINGS=1`` is
    set in the environment, so scripted / CI workloads can acknowledge
    once and move on. Use stderr (never stdin/input) to stay compatible
    with the MCP stdio transport — anything we write to stdout would
    corrupt the JSON-RPC stream. See: #174
    """
def _warn_cloud_egress(provider_name: str) -> None;

with entry {
    _VALID_PROVIDERS = {"local", "openai", "google", "minimax", "voyage"};
}

"""Get an embedding provider by name.

    Args:
        provider: Provider name. One of "local", "google", "minimax",
                  "openai", "voyage", or None. When omitted, configured
                  OpenAI-compatible credentials select OpenAI; otherwise the
                  local provider is used. Names are case-insensitive and
                  surrounding whitespace is ignored; unknown names raise
                  ValueError instead of silently falling back to the local
                  provider. Google requires GOOGLE_API_KEY env var and explicit
                  opt-in. MiniMax requires MINIMAX_API_KEY env var and explicit
                  opt-in. Voyage requires VOYAGE_API_KEY. OpenAI requires
                  CRG_OPENAI_API_KEY + CRG_OPENAI_BASE_URL + CRG_OPENAI_MODEL
                  env vars (or the ``model`` arg). The egress warning is
                  skipped when the base URL points to localhost.
                  Cloud providers emit a one-time stderr warning before use
                  unless ``CRG_ACCEPT_CLOUD_EMBEDDINGS=1`` is set. See: #174
        model: Model name/path to use. For local provider this is any
               sentence-transformers compatible model. Falls back to
               CRG_EMBEDDING_MODEL env var, then to all-MiniLM-L6-v2.
               For Google provider this is a Gemini model ID.
               For OpenAI provider this overrides CRG_OPENAI_MODEL.
               For Voyage provider this overrides CRG_VOYAGE_MODEL.

    Raises:
        ValueError: If the provider name is not one of the known providers,
                    or if required environment variables are missing.
    """
def get_provider(provider: str | None = None, model: str | None = None) -> EmbeddingProvider | None;

"""Check whether local embedding support is available."""
def _check_available -> bool;

with entry {
    _EMBEDDINGS_SCHEMA = "\nCREATE TABLE IF NOT EXISTS embeddings (\n    qualified_name TEXT PRIMARY KEY,\n    vector BLOB NOT NULL,\n    text_hash TEXT NOT NULL,\n    provider TEXT NOT NULL DEFAULT 'unknown'\n);\n";
}

"""Encode a float vector as a compact binary blob."""
def _encode_vector(vec: list[float]) -> bytes;

"""Decode a binary blob back to a float vector."""
def _decode_vector(blob: bytes) -> list[float];

"""Compute cosine similarity between two vectors."""
def _cosine_similarity(a: list[float], b: list[float]) -> float;

with entry {
    _SEARCH_CHUNK_ROWS = 500;
}

"""Stack vector blobs of *dims* components into a float32 matrix (needs numpy)."""
def _decode_rows(blobs: list[bytes], dims: int) -> Any;

"""Each row's norm in float64, with ``inf`` for a zero row (needs numpy).

    ``inf`` turns the division in :func:`_cosine_scores` into 0.0 for a zero
    vector, which is what :func:`_cosine_similarity` returns for it.
    """
def _row_norms(matrix: Any) -> Any;

"""Cosine of each float32 row of *matrix* with *query*, in float64."""
def _cosine_scores(matrix: Any, norms: Any, query: Any, query_norm: float) -> Any;

with entry {
    _IDENTIFIER_SPLIT_RE = re.compile("([a-z])([A-Z])|[_./\\-]+");
    _MAX_EMBEDDED_DOCSTRING_CHARS = 400;
}

"""Split snake_case / camelCase / PascalCase / dotted into space-separated words.

    Examples:
        get_route_handler -> "get route handler"
        APIRoute          -> "API Route"
        dispatch_request  -> "dispatch request"
        full_dispatch_request -> "full dispatch request"
    """
def _split_identifier(name: str) -> str;

"""Convert a node to a searchable text representation.

    Designed so natural-language queries land on the right node, not just on
    the enclosing class. We include the dotted ``Parent.name`` form, the
    identifier split into words, an explicit ``"in <Parent>"`` phrase, the
    enclosing module directory, and the language. Tested by the
    ``multi_hop_retrieval`` benchmark — see ``docs/REPRODUCING.md``.
    """
def _node_to_text(`node: GraphNode) -> str;

"""Manages vector embeddings for graph nodes in SQLite."""
obj EmbeddingStore {
    has provider: any,
        available: any,
        db_path: any,
        _conn: any,
        _conn_file_id: any;

    def init(db_path: str | Path, provider: str | None = None, model: str | None = None);

    def __enter__ -> "EmbeddingStore";

    def __exit__(exc_type, exc_val, exc_tb) -> None;

    def close -> None;

    """Compute and store embeddings for a list of nodes."""
    def embed_nodes(nodes: list[GraphNode], batch_size: int = 64) -> int;

    """Stream (qualified_name, similarity) pairs from a cursor in chunks."""
    static def _iter_scores(
        cursor: sqlite3.Cursor, query_vec: list[float], chunk_size: int = 500
    ) -> Generator[any, any, any];

    """Search for nodes by semantic similarity.

        Every stored vector of the current provider is scored against the
        query. With numpy installed (the ``embeddings`` extra pulls it in),
        each chunk of rows is scored with one matrix-vector product instead of
        a Python loop over every component of every row, which took tens of
        seconds per search over tens of thousands of high-dimensional vectors.
        Without numpy, :meth:`_search_pure_python` runs that loop instead.

        Both return the same ranking: a vector whose dimensionality differs
        from the query's, or whose norm is zero, scores 0.0, and equal scores
        keep the order the rows were read in.

        With ``CRG_VECTOR_CACHE=1`` the decoded vectors stay in memory between
        searches instead of being read back from SQLite every time; see
        :meth:`_cached_vectors`. The ranking is the same either way.
        """
    def search(query: str, limit: int = 20) -> list[tuple[str, float]];

    """Score the stored vectors chunk by chunk, keeping none of them."""
    def _stream_scores(
        provider_name: str, query_arr: Any, query_norm: float
    ) -> tuple[list[str], Any];

    static has _vector_cache: any = {};

    static has _vector_cache_watchers: any = {};

    static has _vector_cache_lock: any = threading.Lock();

    static has _VECTOR_CACHE_MAX_ENTRIES: any = 4;

    """``(names, rows, matrix, norms)`` from the process-wide cache, or None.

        *names* lists every stored vector of *provider_name* in read order,
        *rows* the positions in *names* of those with *dims* components,
        *matrix* their float32 components and *norms* their norms (``inf`` for
        a zero vector).

        None, and the caller reads SQLite instead, unless ``CRG_VECTOR_CACHE``
        is ``1``. Also None for a database that is not a file, while this
        connection holds an uncommitted transaction whose rows only it can
        see, and when the file at this path is no longer the one this
        connection has open, since its rows would then be cached as the new
        file's.

        An entry is valid while ``PRAGMA data_version`` on a long-lived
        watcher connection stays put. That value moves whenever any other
        connection commits, this store's included. It is read before the rows,
        so a commit that races the load costs one extra reload, never a stale
        answer. The watcher stays open while its database has a cached entry.
        On Windows that means ``graph.db`` cannot be deleted or replaced
        while it is open; :meth:`clear_vector_cache` releases it.
        """
    def _cached_vectors(provider_name: str, dims: int) -> tuple[Any, ...] | None;

    """Decode every stored vector of *provider_name* for the cache."""
    def _load_vectors(provider_name: str, dims: int) -> tuple[Any, ...];

    """(device, inode) of *path*, or None if it cannot be read."""
    static def _file_identity(path: str | Path) -> tuple[int, int] | None;

    """(file identity, data_version) of *db*. The caller holds the lock."""
    class def _vector_cache_token(db: str) -> tuple[tuple[int, int], int];

    class def _close_vector_cache_watcher(db: str) -> None;

    """Drop every cached matrix and close the connections that watch them."""
    class def clear_vector_cache -> None;

    """Score every stored vector one component at a time (no numpy)."""
    def _search_pure_python(
        query_vec: list[float], provider_name: str, limit: int
    ) -> list[tuple[str, float]];

    def remove_node(qualified_name: str) -> None;

    """Delete vectors whose graph node no longer exists.

        Embeddings and graph nodes normally share a SQLite file.  Standalone
        embedding databases remain supported, so a missing ``nodes`` table is
        an intentional no-op rather than an error.
        """
    def purge_orphans -> int;

    def count -> int;

    def __repr__ -> str;

    def __eq__(other: any) -> bool;

    def __hash__ -> int;
}

"""Purge deleted nodes, then embed all current non-file nodes."""
def embed_all_nodes(graph_store: GraphStore, embedding_store: EmbeddingStore) -> int;

with entry {
    REFRESH_SKIPPED_WARNING = "Embedding refresh skipped: this graph has no embeddings yet. Run `code-review-graph embed` (MCP: embed_graph_tool) once with the same provider and model to create them.";
}

"""True when the graph database holds at least one stored vector.

    Reads the schema first, so the check never creates the ``embeddings``
    table and never resolves a provider.
    """
def has_embeddings(graph_store: GraphStore) -> bool;

"""Refresh a previously embedded graph under one exact provider identity.

    This function is deliberately not called by default build paths.  Callers
    must supply both provider and model explicitly.  A graph with no existing
    vectors returns ``None`` before provider resolution, so routine builds
    cannot load a local model, contact a cloud service, or incur API cost;
    the build paths report that case with ``REFRESH_SKIPPED_WARNING``.

    Existing vectors must all use the identity resolved from the requested
    provider/model (including the endpoint for OpenAI-compatible providers).
    Refresh never silently migrates an index to another model or endpoint.
    """
def refresh_embeddings(graph_store: GraphStore, *, provider: str, model: str) -> dict[str, int]
    | None;

"""Search nodes using vector similarity, falling back to keyword search."""
def semantic_search(
    query: str, graph_store: GraphStore, embedding_store: EmbeddingStore, limit: int = 20
) -> list[dict[str, Any]];
