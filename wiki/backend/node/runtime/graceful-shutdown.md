---
id: backend-node-runtime-graceful-shutdown
domain: backend
category: runtime
applies_to: [nodejs, typescript]
confidence: verified
sources:
  - https://nodejs.org/api/process.html
  - https://nodejs.org/api/http.html
  - https://expressjs.com/en/advanced/healthcheck-graceful-shutdown.html
last_verified: 2026-07-10
related: [backend-common-errors-exception-handling, backend-common-jobs-idempotent-handlers, backend-common-errors-async-failure-handling]
---

# Shutting Down a Node Service Without Dropping Work

## When this applies

Deploys or scale-downs drop in-flight requests, clients see connection resets on
restart, or you are writing/reviewing SIGTERM/signal handling in a Node service run
under an orchestrator or process manager (Kubernetes, ECS, systemd, pm2).

## Do this

1. **Handle SIGTERM explicitly.** Orchestrators send SIGTERM, wait a grace period,
   then SIGKILL. Node's default on SIGTERM is to exit immediately — in-flight
   requests, open sockets, and queued work are dropped. Installing a listener removes
   the default exit; from that point your handler owns the shutdown.
2. Run this sequence in the SIGTERM handler, in order:

| Step | Action |
|------|--------|
| 1. Stop intake | `server.close(cb)` — stops accepting new connections, lets active requests finish; on Node ≥19 it also closes idle keep-alive connections (older Node: call `server.closeIdleConnections()` too) |
| 2. Drain the LB | Fail the readiness probe immediately so the load balancer stops routing here; keep liveness passing so the orchestrator does not kill the pod mid-drain |
| 3. Settle background work | Finish short in-flight jobs; checkpoint long ones so a successor resumes them ([backend-common-jobs-idempotent-handlers]) |
| 4. Release dependencies | Stop queue consumers first, then close DB/redis pools — consumers still handling messages need the pools; close in dependency order |
| 5. Exit | `process.exit(0)` after all closes resolve |

3. **Bound the whole sequence with a force-exit timer** shorter than the
   orchestrator's grace period (e.g. 20s timer against a 30s grace): when the timer
   fires first, log what was still open and `process.exit(1)`. A hung `server.close`
   (long-polling client, stuck query) must not ride into SIGKILL, which leaves no log
   at all. Call `.unref()` on the timer so it cannot itself hold the process open.
4. **`uncaughtException` / final `unhandledRejection` handler**: log the error,
   attempt fast cleanup of the same resources (best effort, bounded by the same
   timer), exit non-zero. Process state after an uncaught exception is undefined —
   resuming normal operation is not safe; restart beats limping
   ([backend-common-errors-exception-handling]).
5. **Design background work as resumable regardless**: SIGKILL (OOM, node failure,
   grace expiry) can always arrive with no handler run. Checkpointing and idempotent
   handlers ([backend-common-jobs-idempotent-handlers]) are the floor; graceful
   shutdown is the optimization on top.

| Signal / event | Action |
|----------------|--------|
| SIGTERM | Full drain sequence above, exit 0; force-exit 1 on timer |
| SIGINT | Same handler as SIGTERM (local dev Ctrl-C exercises the same path) |
| uncaughtException / unhandledRejection | Log, fast bounded cleanup, exit 1 — never continue serving |
| SIGKILL | Cannot be handled — this is why step 3 checkpointing and idempotency must already exist |

## Edge cases

| Case | Then |
|------|------|
| Active request outlives the force-exit timer | Force-exit wins: log the abandoned request and exit 1 — the client retries against a healthy instance; requests needing longer than the grace period belong in a job, not a request |
| Multiple SIGTERMs arrive (orchestrator resend, operator Ctrl-C) | Make the handler idempotent: first signal starts the sequence, repeats are logged and ignored |
| WebSocket / SSE connections held open | `server.close` never finishes while they live — send a close/reconnect frame to clients in step 1, then end their sockets before the timer expires |
| Service is a queue worker with no HTTP server | Same shape: stop polling/claiming new messages, finish or checkpoint the current one, close connections, exit 0 |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Ship with no SIGTERM listener | Install the drain sequence above | Default SIGTERM behavior is immediate exit — every deploy drops whatever was in flight |
| `process.exit(0)` directly in the SIGTERM handler | `server.close` + dependency closes first, then exit | Immediate exit is the same drop as the default, now with a false sense of handling |
| Wait indefinitely for `server.close` to complete | Race it against a force-exit timer under the grace period | One stuck connection turns your graceful path into an unlogged SIGKILL |
| Keep serving after `uncaughtException` "since we logged it" | Cleanup fast, exit non-zero, let the supervisor restart | Process state is undefined; the docs are explicit that resuming is not safe |

## Sources

- https://nodejs.org/api/process.html — SIGTERM default exit and listener semantics; `uncaughtException` "not safe to resume normal operation"; exit codes
- https://nodejs.org/api/http.html — `server.close` stops new connections and waits for active ones; idle keep-alive close behavior (Node ≥19), `closeIdleConnections`
- https://expressjs.com/en/advanced/healthcheck-graceful-shutdown.html — SIGTERM → `server.close` pattern; readiness vs liveness during shutdown
