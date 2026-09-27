---
id: backend-common-llm-self-hosted-model-load-latency
domain: backend
category: llm
applies_to: [general]
confidence: verified
sources:
  - https://github.com/ollama/ollama/blob/main/docs/faq.mdx
  - https://github.com/ollama/ollama/blob/main/docs/api.md
last_verified: 2026-09-28
related: [backend-common-llm-context-window-budget, backend-common-reliability-timeouts-and-retries, backend-common-reliability-client-side-rate-limiting]
---

# First Request to a Self-Hosted Model Server After Idle

## When this applies

A client calls a locally hosted model server (Ollama or a server with the same
keep-alive model) that loads weights from disk on demand and unloads them after
an idle window, and the caller is intermittent — a hook, a cron job, an
evaluation script, a judge model — or the caller's SDK has a short default
timeout (10 s is common). Also when the first call of a run fails with a
timeout while later calls succeed in under a second.

## Do this

1. **Measure the load once and size the client timeout above load plus
   generation.** Time a first call after the model is unloaded (`ollama ps`
   shows what is loaded and until when); a multi-gigabyte GGUF takes tens of
   seconds from disk. Set the timeout to 60 s or more for such models — a
   timeout at 10 s returns an error while the load continues.
2. **Send a warm-up request before anything you measure or batch**, and report
   its latency separately from the steady-state numbers.
3. **Set `keep_alive` longer than the caller's idle interval.** Ollama keeps a
   model loaded "for 5 minutes before being unloaded" by default; the
   `OLLAMA_KEEP_ALIVE` environment variable changes it for all models, and the
   `keep_alive` parameter on `/api/generate` and `/api/chat` overrides it per
   request (duration string, seconds, a negative number to keep loaded, `0` to
   unload after the response).
4. **Treat a timeout on the first call as a load in progress, not a dead
   server:** check the server's loaded-model list before retrying — a retry
   inside the same short timeout pays the load again and records a second
   failure ([backend-common-reliability-timeouts-and-retries]).

| Caller pattern | keep_alive |
|----------------|------------|
| Interactive session, calls seconds apart | Default (5 m) |
| Hook or job firing every N minutes | Longer than N (`OLLAMA_KEEP_ALIVE=30m` or per-request `"30m"`) |
| Dedicated judge/eval box, memory to spare | Negative value (`-1`) — stays loaded |
| One-shot batch, then free the memory | `0` on the last request |

## Edge cases

| Case | Then |
|------|------|
| The SDK retries on timeout | The first result is recorded as a failure after `timeout × attempts` while the server was loading the whole time; disable retry for the warm-up call or raise the timeout first |
| Several models share one server | Each cold model pays its own load; warm up each one you will call |
| The env var and the request parameter disagree | The request parameter wins — the documented precedence |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Read the first-call timeout as "the server is broken" | Check `ollama ps` and re-send after the load | The model was loading; the error is the client's clock, not the server |
| Publish p50 latency from a run that includes the cold call | Warm up first and report the warm-up separately | One 30 s load skews every summary statistic |

## Sources

- https://github.com/ollama/ollama/blob/main/docs/faq.mdx — "By default models are kept in memory for 5 minutes before being unloaded"; `keep_alive` accepts "a duration string (such as "10m" or "24h")", "a number in seconds (such as 3600)", "any negative number which will keep the model loaded in memory (e.g. -1 or "-1m")", "'0' which will unload the model immediately after generating a response"; "The `keep_alive` API parameter with the `/api/generate` and `/api/chat` API endpoints will override the `OLLAMA_KEEP_ALIVE` setting"
- https://github.com/ollama/ollama/blob/main/docs/api.md — `keep_alive`: "controls how long the model will stay loaded into memory following the request (default: `5m`)"
- Field evidence 2026-09-27 (a local evaluation harness against an Ollama-compatible server hosting an 8 GB Q8 GGUF judge model; client SDK default timeout 10 s with retry): the first judgment was recorded as `31334 ms ERROR … Request timed out (timeout=10.0)`; with the timeout raised to 120 s and one warm-up call (`warmup 1588 ms`) the run scored 50/50 with p50 786 ms, and the server's process list showed the model unloading "4 minutes from now"
