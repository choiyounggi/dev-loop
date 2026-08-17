---
id: backend-common-realtime-websocket-sse-lifecycle
domain: backend
category: realtime
applies_to: [general]
confidence: verified
sources:
  - https://datatracker.ietf.org/doc/html/rfc6455
  - https://html.spec.whatwg.org/multipage/server-sent-events.html
last_verified: 2026-08-17
related: [backend-common-reliability-timeouts-and-retries]
---

# Managing a Long-Lived WebSocket or SSE Connection

## When this applies

Building or reviewing a server-pushed realtime channel — WebSocket (bidirectional)
or Server-Sent Events (server-to-client only) — and deciding how the connection
authenticates, detects a dead peer, reconnects after a drop, and shuts down
without losing in-flight messages. A long-lived connection has a lifecycle a
normal request/response endpoint doesn't: it can silently die without either
side calling close, and it must survive a server restart.

## Do this

| Decision | Do |
|----------|----|
| Authenticating the connection | Authenticate once at connection/handshake time (WebSocket: during the HTTP upgrade; SSE: on the initial GET) — there is no per-message request to reattach auth to afterward, so a token that expires mid-connection needs an explicit re-auth or forced-reconnect path, not a check that silently stops enforcing |
| Detecting a dead peer (WebSocket) | Send ping control frames on an interval and require a matching pong within a timeout; a peer that stops responding to pings is dead even though the underlying TCP connection may still look open (common through NATs/load balancers that hold connections open past actual liveness) |
| Reconnecting after a drop (SSE) | Rely on the browser's built-in auto-reconnect, but set the server's `retry` field to control the delay, and always send an `id` field per event; the client automatically replays its last id via the `Last-Event-ID` request header on reconnect so the server can resume the stream instead of restarting it |
| Reconnecting after a drop (WebSocket) | Implement client-side reconnect with backoff explicitly — WebSocket has no built-in reconnect or resume, so the client must track its own last-known state and either replay a resume token or accept a fresh snapshot on reconnect |
| Backpressure (server sending faster than the client/network can drain) | Bound the per-connection outbound buffer; when it's full, drop or coalesce non-critical messages (e.g. keep only the latest of a repeated state update) rather than growing the buffer unboundedly, which turns a slow client into a server memory leak |
| Shutdown draining | On server shutdown/deploy, stop accepting new connections, send a close frame (WebSocket) or end the event stream (SSE) with enough lead time for clients to reconnect elsewhere, instead of dropping every open connection at once when the process exits |

## Edge cases

| Case | Then |
|------|------|
| A load balancer or proxy sits in front of the server | Confirm it forwards `Connection: Upgrade` for WebSocket and does not buffer the response for SSE (some proxies buffer by default, which delays every event until the buffer fills) |
| Client reconnects rapidly in a loop (e.g. auth keeps failing) | Apply exponential backoff with a cap and jitter on the client, and rate-limit reconnect attempts per client on the server, so a broken client cannot reconnect-storm the server |
| Ping/pong keepalive traffic itself becomes significant load at scale | Increase the interval rather than removing the check — the goal is bounded detection latency, not the shortest possible interval |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Assume a WebSocket connection is alive because the socket hasn't errored | Send ping/pong on an interval and treat a missed pong as dead | Intermediate proxies/NATs can hold a TCP connection open long after the actual peer has gone away, with no error surfaced to either side |
| Let the outbound buffer to a slow client grow to keep every message | Bound the buffer and drop/coalesce when full | An unbounded per-connection buffer against a slow or stalled client is a server-side memory leak that scales with the number of slow clients |

## Sources

- https://datatracker.ietf.org/doc/html/rfc6455 — ping/pong control frames, close handshake (close frame, status codes)
- https://html.spec.whatwg.org/multipage/server-sent-events.html — `retry` field, `id` field, `Last-Event-ID` reconnection header
