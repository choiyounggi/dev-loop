---
id: testing-mocking-pull-probe-for-an-unread-request-body
domain: testing
category: mocking
applies_to: [nodejs, typescript]
confidence: verified
sources:
  - https://streams.spec.whatwg.org/
  - https://fetch.spec.whatwg.org/
  - "Local reproduction 2026-10-11 (Node 26.7.0, global ReadableStream and Request)"
last_verified: 2026-10-11
related: [testing-quality-tests-that-cannot-fail, testing-mocking-what-to-mock]
---

# A Pull-Callback Probe for a Request Body That Must Stay Unread

## When this applies

A test proves a handler did or did not read a request body (a size cap, an auth
or rate-limit check before the read) by setting a flag in the `pull` callback of
a `ReadableStream` passed as `new Request(url, { body, duplex: 'half' })`; or
you are choosing between that flag and `request.bodyUsed`.

## Do this

1. **Build the probe with a high-water mark of 0:**
   `new ReadableStream({ pull(c) { pulled = true; c.enqueue(chunk); c.close(); } }, { highWaterMark: 0 })`,
   or a byte stream (`type: 'bytes'`), whose default high-water mark is already 0.
   A stream built with no strategy gets a high-water mark of 1, and once `start`
   settles the controller calls `pull` to fill that queue with no reader attached,
   so the flag turns true on a handler that never touched the body.
2. **Pair the "never read" assertion with a positive control.** Run the same probe
   through a handler mutant that reads one chunk
   (`await request.body.getReader().read()`) or calls `request.arrayBuffer()`,
   and require the flag to turn true. A probe that stays false under that mutant
   cannot detect a read.
3. **Pick the assertion by what "unread" has to mean:**

| You must prove | Assert | Why |
|---|---|---|
| No byte was requested from the source | `pulled === false` on the step-1 probe | At a high-water mark of 0 only a pending read request — from a reader, a tee branch or a pipe — calls `pull` |
| The handler neither read nor cancelled the body | `request.bodyUsed === false` | `bodyUsed` turns true once the stream is disturbed, which is read from or cancelled |
| Both | Both assertions | `cancel()` disturbs the stream without calling `pull`: measured `bodyUsed=true`, `pulled=false` |

Measured on Node 26.7.0, each body wrapped in a `Request` and left unread for
50 ms unless the row says otherwise:

| Probe | `pulled` |
|---|---|
| `new ReadableStream({ pull })`, no strategy | true |
| `{ highWaterMark: 0 }` | false |
| `{ type: 'bytes', pull }` | false |
| `{ highWaterMark: 0 }`, handler reads one chunk / calls `arrayBuffer()` | true / true |

## Edge cases

| Case | Then |
|------|------|
| The handler or a middleware calls `request.clone()` | Each tee branch is created with a high-water mark of 1, so the source is pulled while neither copy is read (measured `pulled=true`, both `bodyUsed=false`); assert on the rejection the handler returns, or keep the clone out of the code path under test |
| Only the clone is read | The original's `bodyUsed` stays false while the source was drained through the clone, and `pulled` is true (both measured); after a clone neither flag shows whether the handler read the body, so assert on the handler's response and side effects, as in the row above |
| The handler pipes the body (`pipeThrough`, `pipeTo`) | The pipe reads the source to fill the destination's queue with nothing reading the output (measured `pulled=true`); assert on the handler's response and side effects instead |
| The body is `ReadableStream.from(iterable)` | The spec creates it with a high-water mark of 0, so it works as a probe as is (measured: the iterator's `next()` was not called before a read) |
| A framework wrapper sits between the test's `Request` and the handler | Re-run the step-2 positive control through that wrapper; the measured table holds for a bare `Request` |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Build the probe as `new ReadableStream({ pull })` and assert the flag stayed false | Add `{ highWaterMark: 0 }` (or `type: 'bytes'`) | The default stream pulls once right after construction, so the flag reads true on correct code |
| Swap the pull flag for `bodyUsed`, or back, as if they were one check | Choose with the step-3 table | They diverge on `cancel()` and on `clone()` (measured) |

## Sources

- https://streams.spec.whatwg.org/ — the `ReadableStream` constructor takes `ExtractHighWaterMark(strategy, 0)` for byte streams and `ExtractHighWaterMark(strategy, 1)` otherwise, and `ExtractHighWaterMark` returns that default "If strategy["highWaterMark"] does not exist"; `SetUpReadableStreamDefaultController`: "Upon fulfillment of startPromise, … Perform ! ReadableStreamDefaultControllerCallPullIfNeeded(controller)"; `ReadableStreamDefaultControllerShouldCallPull` returns true for a locked stream with pending read requests, else "If desiredSize > 0, return true"; `ReadableStreamFromIterable`: "Set stream to ! CreateReadableStream(startAlgorithm, pullAlgorithm, cancelAlgorithm, 0)"; `ReadableStreamDefaultTee` creates both branches with `CreateReadableStream` and no high-water mark, which then defaults to 1; the `[[disturbed]]` slot is "A boolean flag set to true when the stream has been read from or canceled"
- https://fetch.spec.whatwg.org/ — `bodyUsed` getter: "return true if this's body is non-null and this's body's stream is disturbed; otherwise false"
- Local reproduction 2026-10-11 (Node 26.7.0, built-ins only): no strategy and no reader, `pullCount=1` after 50 ms; `highWaterMark: 0` and `type: 'bytes'`, `pullCount=0`, then 1 after one `read()`; wrapped in an unread `Request`: no strategy `pulled=true`, `highWaterMark: 0` `pulled=false`, bytes `pulled=false`; positive controls `getReader().read()` and `arrayBuffer()` both `pulled=true`; `bodyUsed`/`pulled` — no read false/false, one read true/true, `body.cancel()` true/false, `clone()` with no copy read false (both copies)/true, only the clone read: original false, clone true, `pulled=true`; `tee()` with no branch read `pulled=true`; `pipeThrough()` with the output unread `pulled=true`; `ReadableStream.from(asyncIterable)` `nextCalled=0` before a read and 1 after
- Field origin 2026-10-10 (linkly-invitation task t2b, a route-handler test; recorded by the originating session, not re-run in this flush): the no-strategy probe read `pulled = true` on a handler that never touched the body, and `{ highWaterMark: 0 }` read `pulled = false`
