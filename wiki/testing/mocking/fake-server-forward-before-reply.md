---
id: testing-mocking-fake-server-forward-before-reply
domain: testing
category: mocking
applies_to: [general]
confidence: verified
sources:
  - https://docs.rs/tokio/latest/tokio/sync/mpsc/struct.Receiver.html
  - https://doc.rust-lang.org/std/io/enum.ErrorKind.html
last_verified: 2026-09-27
related: [testing-mocking-what-to-mock, testing-flaky-diagnosing-flaky-tests, testing-quality-tests-that-cannot-fail, debugging-network-epipe-write-ordering]
---

# A Fake Server That Both Replies to the Client and Feeds the Test

## When this applies

A test's fake server (TCP, Unix socket, HTTP stub) receives messages from the
code under test, writes replies back to that client, and also forwards what it
received into a channel or queue the test asserts on; the client may close its
connection before the reply is written; the test intermittently fails with a
closed-channel or `None`-unwrap error rather than the behaviour it was written
to check.

## Do this

1. **Forward to the test's channel before writing any reply.** The forward is
   the observation the test needs; the reply is protocol courtesy. A reply
   write that fails (EPIPE, `BrokenPipe`, `ConnectionReset`) after the forward
   costs nothing; before the forward it takes the observation with it.
2. **Reply only where the real protocol replies** — ack-required message
   types, requests with a response — and send nothing for fire-and-forget
   messages. Every unrequired reply is another write that can fail against a
   client that has already gone.
3. **Treat a failed reply write as a normal outcome, not a panic.** Match on
   the error and continue the accept loop; a panic (`unwrap`/`expect` on the
   write) unwinds the server task, drops its channel sender, and every later
   `recv()` on the test side returns "closed".
4. **When the test sees a closed channel, read it as "the server task died
   before forwarding"** and look at the server task's own result (join handle,
   captured panic) before attributing the failure to the race under test.

| Server loop step | Order |
|------------------|-------|
| Read a message from the client | 1 |
| Forward it to the test channel | 2 |
| Write a reply, only if the message type requires one, ignoring a write error | 3 |

## Edge cases

| Case | Then |
|------|------|
| The client disconnects with unread data on the server side | The server's next write fails on its first attempt ([debugging-network-epipe-write-ordering]); the forward-first order still delivers the observation |
| The forward itself fails (the test dropped the receiver) | The test is over; end the server loop quietly rather than panicking, so a second test sharing the process is not affected |
| The protocol has no replies at all | Steps 2–3 are empty; the remaining hazard is the panic-on-write, which cannot occur — keep the forward-first shape anyway so a later reply feature does not reintroduce it |
| The test needs to assert that a reply was sent | Record the reply attempt and its result on the channel too (`Forwarded(msg)`, `Replied(result)`); the test then distinguishes "not attempted" from "attempted and failed" |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Write the reply, then forward to the channel | Forward first, reply second | A failing reply write before the forward kills the task and the observation |
| `unwrap()` the reply write in the fake server | Match the error and continue | The panic drops the sender; the test then reports a closed channel instead of the real race |
| Reply to every message to "keep the client happy" | Reply only where the protocol requires it | Each extra write is another chance to fail against a departed client |

## Sources

- https://docs.rs/tokio/latest/tokio/sync/mpsc/struct.Receiver.html — `recv` returns `None` when "the channel has been closed and there are no remaining messages in the channel's buffer … The channel is closed when all senders have been dropped"
- https://doc.rust-lang.org/std/io/enum.ErrorKind.html — `BrokenPipe`: "The operation failed because a pipe was closed"
- Local reproduction 2026-09-27 (Rust 1.98, `tokio` 1.x fake TCP server; std client sets `SO_LINGER(0)`, sends one line, and drops the stream so the close is an RST): reply-then-forward lost the message in 60/60 trials — the reply write failed with `BrokenPipe` (errno 32), the `expect` panicked the server task 60/60, and the test's `recv()` saw a closed channel; forward-then-reply delivered 60/60 with 0 panics
- Field evidence 2026-09 (crew-agent runner test, task t1-flaky-18): 9/20 failures before the change (`BrokenPipe` then `None`-unwrap), 0/20, 0/10 single-threaded, and 0/10 under CPU stress after; the old loop reinstated failed 29/30
