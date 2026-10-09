---
id: debugging-network-epipe-write-ordering
domain: debugging
category: network
applies_to: [general]
confidence: verified
sources:
  - https://datatracker.ietf.org/doc/html/rfc9293
  - https://man7.org/linux/man-pages/man2/write.2.html
  - https://man7.org/linux/man-pages/man2/send.2.html
last_verified: 2026-09-27
related: [testing-mocking-fake-server-forward-before-reply, backend-common-realtime-websocket-sse-lifecycle, debugging-methodology-reproduce-first]
---

# Forcing a Deterministic EPIPE on a Closed TCP Peer

## When this applies

A test or reproduction must make a write to a TCP socket fail with EPIPE
(`BrokenPipeError`, `ECONNRESET`) after the peer has closed, and a single
write issued after the close keeps succeeding; you are deciding how many
writes to issue and what to assert on.

## Do this

| Step | Do |
|------|----|
| Produce a closed peer | Have the peer `accept()` (or receive) and then `close()` |
| Force the failure | Issue **at least two writes** after the close, a few tens of milliseconds apart. The first write copies its bytes into the local send buffer and returns success; the peer answers that segment with RST; only a write issued after the RST has been processed locally fails with EPIPE |
| Keep the process alive | Ignore or block `SIGPIPE` (`signal.signal(SIGPIPE, SIG_IGN)` in Python; `MSG_NOSIGNAL` per call or `SO_NOSIGPIPE` on macOS/BSD in C) so the failing write returns EPIPE instead of killing the process — write(2): "the write return value is seen only if the program catches, blocks or ignores this signal" |
| Assert on the right write | Assert that the second (or a later) write raises; a test asserting only that "some write eventually fails" passes for the wrong reason on hosts where the RST happens to arrive before the first write |

## Edge cases

| Case | Then |
|------|------|
| Only one write is issued after the close, however long the pause before it | It still succeeds: a pending RST does not fail a write that only needs room in the local send buffer. Add the second write; a longer sleep does not replace it |
| The peer closes while it still holds unread data you sent | The close is abortive: the peer sends RST at once, so the **first** post-close write fails (reproduced 20/20). A fixture that depends on "first write succeeds" must drain what it received before closing |
| The reproduction runs on a loopback interface | The RST arrives within milliseconds; the tens-of-milliseconds pause between writes is enough, and the same ordering holds on a real network with a longer pause |
| The failing call reports `ECONNRESET` instead of `EPIPE` | Both name the same event on different platforms and timings; accept either in the assertion |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Write once after the close and assert EPIPE | Write at least twice and assert on the second | RFC 9293 guarantees a reset in response to a segment on a closed connection; it says nothing about which local write call surfaces it, and the first write returns before the reset exists |
| Let the failing write kill the test process | Ignore or suppress `SIGPIPE` first | write(2)/send(2) deliver `SIGPIPE` by default; the EPIPE return value is only visible when the signal is handled |

## Sources

- https://datatracker.ietf.org/doc/html/rfc9293 — "If the connection does not exist (CLOSED), then a reset is sent in response to any incoming segment except another reset"; on a half-open connection an attempt to send data "will result in the site B TCP endpoint receiving a reset control message"
- https://man7.org/linux/man-pages/man2/write.2.html — EPIPE: "fd is connected to a pipe or socket whose reading end is closed. When this happens the writing process will also receive a SIGPIPE signal. (Thus, the write return value is seen only if the program catches, blocks or ignores this signal.)"
- https://man7.org/linux/man-pages/man2/send.2.html — EPIPE and `MSG_NOSIGNAL`
- Local reproduction 2026-09-27 (macOS, Python 3.14.6, `SIGPIPE` ignored, loopback): one write after the peer's close → 0/20 failures; five writes 50 ms apart → 20/20 failures, first failure at write #2 with errno `EPIPE` in every trial; peer closing with unread data → first write failed 20/20
- Field evidence 2026-09 (a Rust `tokio` runner test, crew-agent): writing only the last envelope after the peer closed failed 0/30; writing every envelope after the close failed 29/30 with `BrokenPipe`
