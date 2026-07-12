---
id: backend-node-async-promise-error-handling
domain: backend
category: async
applies_to: [nodejs, typescript]
confidence: verified
sources:
  - https://nodejs.org/api/process.html
  - https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Promise/allSettled
  - https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Promise/all
  - https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Promise/any
  - https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Operators/await
  - https://developer.mozilla.org/en-US/docs/Web/API/AbortController
last_verified: 2026-07-10
related: [backend-common-errors-async-failure-handling, backend-common-errors-exception-handling, backend-common-reliability-timeouts-and-retries]
---

# Promise Rejections That Escape Their Consumers

## When this applies

An `unhandledRejection` warning or crash appears in logs, errors from async flows
vanish without a trace, an async function is called without `await`, or you are
choosing how to run multiple promises in parallel.

## Do this

1. **Give every promise chain an eventual consumer** — an `await`, a `.catch`, or a
   combinator that feeds one. A rejection with no handler attached within a turn of
   the event loop emits `unhandledRejection`; unhandled, modern Node raises it as an
   uncaught exception and terminates the process with a non-zero exit code.
2. **Calling an async function without `await` inside a handler is fire-and-forget**:
   its rejection is lost and its work dies on crash/deploy. Route by how much the
   work matters using [backend-common-errors-async-failure-handling] — must-happen
   work goes to a durable job, not an unawaited call.
3. Pick the parallel combinator by what a failure means:

| Case | Do |
|------|----|
| All results required; one failure fails the operation | `Promise.all` — rejects on the first rejection (fail-fast). The losing promises keep running; their results are discarded, so follow-up effects of the losers still happen |
| Independent tasks; each result or failure handled on its own | `Promise.allSettled`, then branch per entry on `status === "fulfilled"` (`value`) vs `"rejected"` (`reason`) — nothing is masked, nothing aborts the batch |
| Any one success suffices | `Promise.any` — first fulfillment wins; rejects with `AggregateError` only when all reject |
| Result needed before a deadline | `Promise.race([task, timeout])` + pass an `AbortController` signal into the task and call `.abort()` when the timeout wins — `race` only ignores the loser, it does not cancel it ([backend-common-reliability-timeouts-and-retries] for the timeout budget) |

4. **Inside a `try` block, `return await promise`, not `return promise`.** `try/catch`
   catches only what throws inside the block, and only `await` turns a rejection into
   a throw — `return promise` hands the rejection to the caller uncaught-here, and
   skipping `await` also drops this frame from the stack trace. `return await` costs
   nothing extra on native promises.
5. **Install a top-level `process.on('unhandledRejection')` handler that logs with
   context and exits non-zero** so the supervisor restarts a clean process. An
   unhandled rejection means state is unknown — crash-and-restart beats continuing.

## Edge cases

| Case | Then |
|------|------|
| Rejection handler attached late (after the event-loop turn ends) | Node emits `unhandledRejection` then `rejectionHandled` — attach `.catch` in the same turn the promise is created |
| Promise stored in a variable, awaited on a later line | Any rejection before the `await` line is already unhandled if no `.catch` is attached — attach the consumer at creation |
| Deliberate fire-and-forget (metrics, cache warm) | Append `.catch(err => log(err, context))` at the call site — visible-failure fire-and-forget per [backend-common-errors-async-failure-handling] |
| `Promise.race` where the timeout loses | The timeout promise still resolves later; keep the timer cancellable (`clearTimeout`) so it cannot hold the process open |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Call `doWork()` (async) without `await` in a handler | `await` it, or route it via [backend-common-errors-async-failure-handling] | Its rejection becomes a process-level `unhandledRejection`, not a handled error |
| Swallow in `process.on('unhandledRejection', () => {})` | Log with context, then exit non-zero | Swallowing leaves the process running in unknown state with the failure invisible ([backend-common-errors-exception-handling] log-once rule) |
| `return promise` inside a `try` block | `return await promise` | Without `await`, the rejection bypasses this `catch` and the frame is missing from the stack trace |
| `Promise.all` over independent per-item tasks | `Promise.allSettled` + per-entry handling | `all` discards every other result on the first failure; independent items each deserve their own outcome |

## Sources

- https://nodejs.org/api/process.html — `unhandledRejection` raised as uncaught exception terminating the process; `rejectionHandled`
- https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Promise/all — fail-fast rejection on first failure
- https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Promise/allSettled — per-entry `{status, value|reason}`; use when tasks are independent
- https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Promise/any — first fulfillment; `AggregateError` when all reject
- https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Operators/await — `await` throws rejections into the surrounding `try`; `return await` preferable, improves stack traces
- https://developer.mozilla.org/en-US/docs/Web/API/AbortController — signal-based cancellation of async operations
