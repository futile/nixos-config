# Headroom Pipeline And Runtime Knobs

This note describes Headroom as packaged in this repo at `headroom-ai` 0.22.3,
with the local Nix patches currently applied. It combines the hosted docs at
<https://headroom-docs.vercel.app/docs>, DeepWiki's repository overview, and
the upstream source fetched by the Nix package.

The docs sometimes describe older SDK concepts such as `optimize`, `audit`, and
`passthrough`. The current proxy CLI in 0.22.3 uses `token` and `cache` as the
main optimization modes, with `--no-optimize` for passthrough.

## Request Flow

At a high level, Headroom is a local proxy that accepts provider-shaped API
traffic, mutates eligible request content, forwards the request upstream, and
records metrics/savings.

The usual documented transform shape is:

```text
client
  -> Headroom proxy provider handler
  -> CacheAligner / cache-mode policy
  -> ContentRouter
  -> specialized compressor
  -> context budget manager
  -> upstream provider
```

Important implementation detail: not every request goes through every stage.
OpenAI/Codex websocket traffic has its own path in
`headroom/proxy/handlers/openai.py`; Anthropic `/v1/messages` has separate
pre-upstream gating; SDK/direct compression APIs have a different entry point
than the proxy.

## Proxy Routing

The proxy exposes provider-compatible routes and dispatches them to provider
handlers. Relevant examples:

```text
/v1/messages                      -> Anthropic-compatible traffic
/v1/chat/completions              -> OpenAI chat completions
/v1/responses                     -> OpenAI Responses, including websocket
/v1internal:streamGenerateContent -> Cloud Code / Gemini-style traffic
```

`headroom proxy --help` is the source of truth for the runtime CLI. The key
server-shape knobs are:

| Knob | Default | Effect |
| --- | ---: | --- |
| `--host` / `HEADROOM_HOST` | `127.0.0.1` | Bind address. |
| `--port` / `HEADROOM_PORT` | `8787` | Bind port. |
| `--workers` / `HEADROOM_WORKERS` | `1` | Uvicorn worker process count. Increasing this multiplies memory and possible CPU fanout. |
| `--limit-concurrency` / `HEADROOM_LIMIT_CONCURRENCY` | `1000` | Caps accepted concurrent connections before Uvicorn returns 503. |
| `--max-connections` / `HEADROOM_MAX_CONNECTIONS` | `500` | Upstream HTTP connection pool cap. |
| `--max-keepalive` / `HEADROOM_MAX_KEEPALIVE` | `100` | Upstream keepalive pool cap. |
| `--retry-max-attempts` | `3` | Upstream retry attempts for connect/read/5xx failures. |
| `--connect-timeout-seconds` | `10` | Upstream connect timeout. |

For Codex on this host, more workers are not desirable. One worker plus bounded
compression worker/thread pools keeps the failure mode easier to reason about.

## Modes

The current proxy accepts:

| Mode | Meaning |
| --- | --- |
| `--mode token` | Prioritize token reduction. Prior context may be rewritten more aggressively. This can reduce input tokens but can also destabilize provider prefix caches. |
| `--mode cache` | Prioritize provider prefix-cache stability. Prior turns are frozen more aggressively; Headroom tries to keep the reusable prefix byte-stable. |
| `--no-optimize` | Passthrough mode. Useful for proving whether a problem is in Headroom's transform path or upstream/client behavior. |
| `--no-cache` | Disable Headroom semantic cache. This is separate from provider prefix caching. |
| `--no-rate-limit` | Disable proxy rate limiting. Useful only if the local token bucket is the bottleneck. |
| `--stateless` / `HEADROOM_STATELESS=true` | Disable filesystem writes. In code this also sets `HEADROOM_TOIN_BACKEND=none`. |

For long Codex sessions, `--mode cache` is the conservative default because
OpenAI prefix caching depends on a byte-identical prompt prefix.

## Compression Pipeline

The hosted docs describe three conceptual stages.

### CacheAligner

CacheAligner tries to keep the request prefix stable by moving dynamic context
such as dates, timestamps, session identifiers, and volatile user context away
from the front of the prompt. For OpenAI, prefix caching is automatic; no API
marker is sent. The provider only needs a matching prefix of sufficient length.

### ContentRouter

ContentRouter inspects content and routes it to a specialized compressor.
Common paths include:

| Content shape | Typical compressor |
| --- | --- |
| JSON arrays / tabular-ish tool output | SmartCrusher |
| Source code | Code-aware compressor, disabled by default in the proxy unless `--code-aware` is used |
| Logs / terminal output | Log/text compressors |
| Plain natural language text | Kompress/text path |
| Images | Image optimization path when enabled |

The docs and `headroom perf` both indicate that routing and text compression can
dominate latency. On this machine, prior perf output showed many requests over
500 ms and a worst observed optimization overhead of about 7 seconds, while the
problematic Codex websocket frame used to spend about 30 seconds in compression
before our preflight guard.

### Context Management

The docs describe IntelligentContext as scoring messages by recency, semantic
similarity, TOIN-derived importance, error indicators, forward references, and
token density. If disabled or unavailable, Headroom can fall back to rolling
window behavior: keep the system prompt, keep the last turns, and drop older
messages/tool pairs first.

Proxy CLI options documented for this layer include:

| Knob | Effect |
| --- | --- |
| `--no-intelligent-context` | Fall back to rolling window. |
| `--no-intelligent-scoring` | Keep context management but use simpler scoring. |
| `--no-compress-first` | Do not attempt deeper compression before dropping messages. |
| `--no-read-lifecycle` | Disable stale/superseded Read compression. |

Not every option appears in the short docs pages, so `headroom proxy --help`
should be checked before relying on a knob.

## SmartCrusher

SmartCrusher is the structured-data compressor. The docs describe it as
preserving schema shape, representative rows, outliers, errors, and trend/change
points while dropping redundant rows. In source, SmartCrusher has many internal
configuration fields: target item count, variance/uniqueness thresholds,
relevance scoring, deduplication, change-point preservation, and CCR marker
behavior.

Important practical point: SmartCrusher and related Rust/ONNX paths can use
native thread pools. Limiting Python executor workers is not sufficient by
itself; use native thread env vars too.

## Kompress / Text Compression

Headroom uses a text compression path backed by model/tokenizer assets. Startup
can make Hugging Face `HEAD`/metadata requests for assets such as ModernBERT and
Kompress ONNX files. Without `HF_TOKEN`, Hugging Face logs a warning about
unauthenticated requests and lower rate limits. That warning is about download
rate limits and startup/cache behavior, not by itself a compression failure.

Text compression is one of the high-latency stages in the hosted benchmarks and
our observed logs. It is valuable for large plain text, but it is also the path
most likely to make huge websocket frames expensive if they are not gated.

## Code-Aware Compression

The proxy has `--code-aware` / `--no-code-aware` and
`HEADROOM_CODE_AWARE_ENABLED=1`. Code-aware compression is off by default in our
current proxy. The CLI help says it requires the optional tree-sitter dependency.

The source comments also recommend code graph tooling over broad code-aware
compression by default. Treat this as an explicit experiment, not a baseline
setting.

## CCR: Compress-Cache-Retrieve

CCR is Headroom's reversible compression story. When content is heavily
compressed, Headroom can store the original in a local compression store and
emit a marker or inject a retrieval tool so the model can ask for the original
content later.

Docs describe three phases:

1. Store the original content and produce a hash key.
2. Inject `headroom_retrieve` so the model can retrieve the original by hash.
3. Handle retrieval calls and optionally continue the conversation.

Relevant config fields in source include:

| Field | Default in `ProxyConfig` | Effect |
| --- | ---: | --- |
| `ccr_inject_tool` | `true` | Add retrieval tool when needed. |
| `ccr_inject_system_instructions` | `false` | Add explicit system instructions for CCR. |
| `ccr_handle_responses` | `true` | Handle CCR tool calls in responses. |
| `ccr_max_retrieval_rounds` | `3` | Max retrieval continuation rounds. |
| `ccr_context_tracking` | `true` | Track compressed context for possible expansion. |
| `ccr_proactive_expansion` | `true` | Attempt proactive expansions. |

In our live stats, CCR entries existed but retrievals were zero, which means the
store was being populated but not paying off through actual retrieve calls.

## TOIN And Recommendations

TOIN stands for Tool Output Intelligence Network. In 0.22.3 it is explicitly
observation-only:

```text
request path records compression events
  -> ~/.headroom/toin.json
  -> optional offline publish to recommendations.toml
  -> Rust recommendation loader can read it at startup
```

The important caveat from source:

```text
dispatch_compressor does not consume this surface yet; PR-F3 is responsible for wiring it
```

So TOIN can learn and `headroom perf` can report "patterns with
recommendations", but those recommendations do not appear to affect the current
request-time compression dispatcher.

Observed local facts:

| Observation | Meaning |
| --- | --- |
| `headroom perf` reported 62 patterns with at least 10 samples | There is learned structure in `~/.headroom/toin.json`. |
| `python -m headroom.cli.toin_publish` default threshold is 50 | With defaults, our store emitted only 1 recommendation row. |
| `--min-observations 10` emitted 62 rows | This matches the perf headline. |
| `HEADROOM_RECOMMENDATIONS_PATH` exists in Rust | The loader can find a TOML file. |
| Source says dispatcher is not wired yet | Publishing is probably not useful for this workload today. |

TOIN storage knobs:

| Knob | Effect |
| --- | --- |
| `HEADROOM_TOIN_PATH` | Override `toin.json` path. |
| `HEADROOM_TOIN_BACKEND=none` | In-memory-only TOIN backend. `--stateless` sets this. |
| `HEADROOM_RECOMMENDATIONS_PATH` | Path to offline `recommendations.toml` for the Rust loader. |

## Memory And Failure Learning

These are separate from the compression path.

| Knob | Effect |
| --- | --- |
| `--memory` | Enable persistent memory and memory tool injection. |
| `--memory-storage project|user|global` | Select memory partitioning. Project mode is default. |
| `--memory-db-path` | Legacy/global DB path and seed for project storage. |
| `--memory-project-root` | Force a project root for project-mode memory. |
| `--no-memory-tools` | Disable memory tool injection. |
| `--no-memory-context` | Disable automatic memory context injection. |
| `--memory-top-k` | Number of memories injected as context. |
| `--learn` | Enable traffic learning; implies memory. |
| `--no-learn` | Explicitly disable traffic learning. |
| `--min-evidence` | Minimum observations before learning writes patterns. |

These can add state and request work. For a minimal Codex optimization proxy,
leave memory and learning off unless specifically testing them.

## Observability

Useful endpoints:

| Endpoint | Use |
| --- | --- |
| `/livez` | Process liveness. |
| `/readyz` | Startup/readiness plus runtime executor stats. |
| `/stats` | Human/debug JSON with savings, pipeline timing, websocket counters, TOIN/CCR stats, cache stats. |
| `/stats-history` | Durable compression history. |
| `/metrics` | Prometheus metrics. |

Useful CLI:

| Command | Use |
| --- | --- |
| `headroom perf` | Parse `~/.headroom/logs` and summarize savings, cache behavior, overhead, TOIN highlights, and recommendations. |
| `headroom proxy --help` | Current CLI truth. |

Sensitive/debug-only knobs:

| Knob | Effect |
| --- | --- |
| `--log-messages` | Stores request/response content in logs/live feed. Treat as sensitive. |
| `--codex-wire-debug` | Enables Codex wire snapshots. Treat as sensitive. |
| `--codex-wire-debug-dir` | Where wire snapshots go. |
| `--log-file` | Explicit JSONL log file path. |

## Codex/OpenAI Websocket Path

Codex uses `/v1/responses` over websocket. The Python handler reads the first
client frame, usually `response.create`, tries to compress eligible content, and
then connects upstream. It records stage timings and websocket termination
causes such as `response_completed`, `compression_refused`, or
`upstream_disconnect`.

Compression failure behavior matters:

| Setting | Behavior |
| --- | --- |
| default fail-closed | Compression failure can close the client websocket with code 1009 and status `ws:compression_refused`. |
| `HEADROOM_WS_FAIL_OPEN_ON_COMPRESSION_FAILURE=1` | Compression failure logs `frame passthrough` and forwards the original frame upstream. |

Our local Nix package also adds:

| Local knob | Behavior |
| --- | --- |
| `HEADROOM_WS_COMPRESSION_FAIL_THRESHOLD_BYTES` | Preflight JSON-serialize the websocket payload and raise `TimeoutError` before expensive compression when it is over the threshold. |

The current service sets the threshold to `1048576` bytes. The problematic
Codex `/compact` frame was about 1.25 MiB (`bytes=1298719`, serialized
preflight `bytes=1308667`). Before the guard, Headroom spent about 30 seconds
in compression and then refused the websocket. With the guard plus fail-open,
Headroom skips compression in about 7-11 ms and forwards the frame upstream.

The remaining `/compact` failure we observed after fail-open was upstream
`response.incomplete` / `upstream_disconnect`, not local `compression_refused`.

## CPU And Concurrency Guardrails

For Codex on this host, the current Nix service is:

```text
headroom proxy --port 8787 --mode cache --limit-concurrency 4 --retry-max-attempts 1 --no-telemetry
```

with:

```text
HEADROOM_COMPRESSION_MAX_WORKERS=1
HEADROOM_COMPRESS_WORKERS=1
HEADROOM_KOMPRESS_MAX_CONCURRENT=1
HEADROOM_WS_COMPRESSION_FAIL_THRESHOLD_BYTES=1048576
HEADROOM_WS_FAIL_OPEN_ON_COMPRESSION_FAILURE=1
OMP_NUM_THREADS=1
ORT_NUM_THREADS=1
RAYON_NUM_THREADS=1
CPUQuota=200%
```

What each guard does:

| Guard | Layer | Why it exists |
| --- | --- | --- |
| `--limit-concurrency 4` | Uvicorn/proxy | Prevents too many simultaneous accepted connections. |
| `--retry-max-attempts 1` | Upstream HTTP | Avoids retry amplification. |
| `HEADROOM_COMPRESSION_MAX_WORKERS=1` | Python compression executor | Serializes Python compression jobs. This is enabled by our Nix patch. |
| `HEADROOM_COMPRESS_WORKERS=1` | Headroom/related compression code | Defensive limit for compression workers if honored by code paths. |
| `HEADROOM_KOMPRESS_MAX_CONCURRENT=1` | Kompress/text path | Defensive limit for concurrent Kompress work if honored. |
| `OMP_NUM_THREADS=1` | Native OpenMP users | Prevents native code from using all cores. |
| `ORT_NUM_THREADS=1` | ONNX Runtime-ish users | Prevents ONNX inference from using all cores. |
| `RAYON_NUM_THREADS=1` | Rust Rayon users | Prevents Rust compression from using all cores. |
| `CPUQuota=200%` | systemd | Final process-level cap at roughly two cores. |

Do not raise `--workers` while debugging CPU pressure. It creates additional
processes and can multiply the number of active native thread pools.

## Which Knobs To Try First

For "is Headroom involved at all?":

```text
--no-optimize
```

For "large Codex frame should not burn CPU or fail locally":

```text
HEADROOM_WS_COMPRESSION_FAIL_THRESHOLD_BYTES=1048576
HEADROOM_WS_FAIL_OPEN_ON_COMPRESSION_FAILURE=1
```

For "reduce stateful background learning/storage":

```text
--stateless
```

or, more narrowly:

```text
HEADROOM_TOIN_BACKEND=none
```

For "preserve provider prefix cache over token shaving":

```text
--mode cache
```

For "investigate exact websocket contents":

```text
--codex-wire-debug
```

Use this only briefly; it can write sensitive request material.

## Source Map

Useful files in upstream Headroom 0.22.3:

| File | Why it matters |
| --- | --- |
| `headroom/cli/proxy.py` | CLI options, mode/env resolution, stateless behavior, telemetry flag. |
| `headroom/proxy/models.py` | `ProxyConfig`, compression worker setting, CCR/memory defaults. |
| `headroom/proxy/handlers/openai.py` | OpenAI and Codex websocket flow, compression failure behavior, stage timings. |
| `headroom/transforms/content_router.py` | Main routing logic for content compression. |
| `headroom/transforms/smart_crusher.py` | Python bridge around structured compression and TOIN recording. |
| `headroom/transforms/kompress_compressor.py` | Text/Kompress compression and CCR integration. |
| `headroom/telemetry/toin.py` | Observation-only TOIN store and `HEADROOM_TOIN_PATH` / backend behavior. |
| `headroom/cli/toin_publish.py` | Offline `recommendations.toml` publisher. |
| `crates/headroom-core/src/transforms/recommendations.rs` | Rust recommendation loader; source comments say dispatch does not consume it yet. |

Local Nix integration:

| File | Why it matters |
| --- | --- |
| `custom-packages/headroom.nix` | Builds Headroom and applies local patches. |
| `custom-packages/patches/headroom-codex-ws-oversize-preflight.patch` | Adds websocket oversize preflight guard. |
| `home-modules/codex-token-optimization.nix` | Defines the user `headroom.service` and runtime env. |

## Open Questions

1. Whether upstream Headroom has newer code after 0.22.3 that wires
   `RecommendationStore` into the Rust dispatcher.
2. Whether `HEADROOM_COMPRESS_WORKERS` and `HEADROOM_KOMPRESS_MAX_CONCURRENT`
   are honored by all relevant code paths in 0.22.3; they are defensively set
   but the confirmed local patch is `HEADROOM_COMPRESSION_MAX_WORKERS`.
3. Whether Codex `/compact` with a 1.25 MiB websocket frame fails upstream due
   to model/context limits, client timeout, or the specific session payload.

