---
id: backend-node-async-request-body-reader-cancel
domain: backend
category: async
applies_to: [nodejs, typescript, nextjs]
confidence: verified
sources:
  - https://streams.spec.whatwg.org/#readable-stream-cancel
  - https://streams.spec.whatwg.org/#readable-stream-from-iterable
  - https://github.com/nodejs/undici/blob/main/lib/web/fetch/body.js
  - https://github.com/nodejs/node/blob/main/lib/internal/streams/readable.js
  - https://nodejs.org/api/http.html#serverrequesttimeout
last_verified: 2026-10-10
related: [backend-node-async-promise-error-handling, backend-common-reliability-timeouts-and-retries, testing-async-teardown-after-aborted-tasks]
---

# Cancelling a Request Body Reader When a Deadline Wins

## When this applies

A Node server handler reads `request.body` through `getReader()` and races
`reader.read()` against a deadline (slow-upload guard, in-flight cap, body
time limit), then cancels the reader when the deadline wins. The body is a web
`Request` built from a Node stream — a Next.js route handler in the Node
runtime, or any `new Request(url, { body: nodeReadable, duplex: 'half' })`.

## Do this

1. **On deadline, start the cancel and do not await it:**
   `reader.cancel(reason).catch(() => {})`, then return the timeout response and
   run cleanup (release the slot, clear timers) right away. The pending
   `read()` already resolves `{ done: true }`; only the `cancel()` promise can
   hang.
2. **Test with a body whose cancel never settles.** Use
   `new Request('http://x/', { method: 'POST', body: new PassThrough(), duplex: 'half' }).body`
   and write nothing to the `PassThrough`. Assert the handler returns and the
   cleanup ran before a short bound (for example 1 s).
3. **Verify once on the built server** with a stalled upload: send headers and a
   `Content-Length`, then no bytes. The response must come at your deadline, not
   at Node's `requestTimeout`.

Why `cancel()` hangs: undici turns an async-iterable body into a stream whose
cancel calls the iterator's `return()` and waits for it. Node's readable stream
iterator queues `return()` behind the outstanding `next()`, and that `next()`
waits for bytes the client never sends. The cancel promise settles only when
the socket ends — at the latest when `server.requestTimeout` (default
300000 ms) fires. Code after `await reader.cancel()`, including a `finally`,
waits that long.

## Edge cases

| Case | Then |
|------|------|
| Cleanup lives in a `finally` around `await reader.cancel()` | Move the cancel out of the awaited path; the `finally` must not depend on it |
| Body is a plain `ReadableStream` or `Readable.toWeb(stream)` | Measured: `cancel()` settles in 1 ms. Keep the fire-and-forget form anyway — the handler should not depend on which wrapper the framework uses |
| A unit test uses `new ReadableStream({})` as the body | This fake cancels at once and hides the hang; add the `PassThrough` case from step 2 |
| The client disconnects later | The socket ends, the queued `return()` runs, the ignored cancel promise settles; nothing leaks past the connection |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| `await reader.cancel()` before returning a 408/413 | `reader.cancel().catch(() => {})` and return | The await can last until `requestTimeout` (300 s) on a silent client |
| Prove deadline handling with a WHATWG fake body only | Add a Node-stream-backed `Request` body | Only that body type reproduces the never-settling cancel |

## Sources

- https://streams.spec.whatwg.org/#readable-stream-cancel — `ReadableStreamCancel` closes the stream (pending reads resolve done) and returns a promise that waits on the source's cancel algorithm
- https://streams.spec.whatwg.org/#readable-stream-from-iterable — `ReadableStream.from` cancel calls the iterator's `return()` and waits for its promise
- https://github.com/nodejs/undici/blob/main/lib/web/fetch/body.js — an async-iterable `Request` body becomes `ReadableStream.from(object)`
- https://github.com/nodejs/node/blob/main/lib/internal/streams/readable.js — the readable async iterator queues requests that arrive while another is outstanding
- https://nodejs.org/api/http.html#serverrequesttimeout — `server.requestTimeout` default `300000`
- Reproduction, Node v26.7.0: `Request(body: PassThrough)` → `cancel` still pending after 3000 ms, pending `read` resolved `done=true`; `Readable.toWeb(PassThrough)` and `new ReadableStream({})` → `cancel` resolved in 1 ms
- Field case: Next.js 16 route handler with an in-flight cap; 4 stalled POSTs held the cap until 311 s (Node 408) while the handler awaited `cancel()`
