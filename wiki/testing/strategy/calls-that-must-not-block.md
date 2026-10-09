---
id: testing-strategy-calls-that-must-not-block
domain: testing
category: strategy
applies_to: [python, posix]
confidence: verified
sources:
  - https://docs.python.org/3/library/threading.html
  - https://github.com/python/cpython/blob/main/Lib/test/support/threading_helper.py
  - https://pubs.opengroup.org/onlinepubs/9699919799/functions/open.html
  - https://man7.org/linux/man-pages/man7/fifo.7.html
  - https://github.com/torvalds/linux/blob/master/fs/pipe.c
  - https://docs.python.org/3/library/subprocess.html
  - "Local reproduction 2026-10-07 (CPython 3.14.6, macOS Darwin 25.1.0): blocked FIFO open, lock, queue and socket calls each released from the test thread; daemon vs non-daemon exit measured"
last_verified: 2026-10-07
related: [testing-strategy-signal-delivery-to-a-process-under-test, testing-strategy-failing-test-first, testing-quality-gate-parsing-vs-command-execution, testing-quality-tests-that-cannot-fail, testing-async-async-testing, backend-python-concurrency-gil-and-concurrency-model]
---

# Testing That a Call Returns Instead of Blocking

## When this applies

A test must prove that a call returns rather than waits forever — opening a FIFO
or device path the code should refuse, acquiring a lock, reading a pipe or socket
with no data, waiting on a queue — so the regression it guards would hang the
test instead of returning a wrong value. Also when a suite run stalls on one test
with no failure output.

## Do this

1. **Give the call a deadline the test owns.** Run it in a thread, call
   `join(timeout)`, then check `is_alive()`: `join()` always returns `None`, so
   `is_alive()` is the only signal that the deadline passed. CPython's own helper
   `test.support.threading_helper.join_thread` is this pattern — join with a
   timeout, raise `AssertionError` while the thread is still alive.
2. **Start that thread with `daemon=True`.** Python exits "when only daemon
   threads are left", so a daemon thread stuck in `open()` cannot hold the run
   open, while a non-daemon one does (measured: the daemon case exited in 0.55 s,
   the non-daemon case was still running at 5 s).
3. **Release the blocked call, join again, then fail.** A stuck daemon thread
   stays blocked until the process exits, sharing the process with every later
   test. Undo the wait from the test thread:

| Blocked call | Release from the test thread |
|--------------|------------------------------|
| `os.open(fifo, os.O_RDONLY)` with no writer | `os.open(fifo, os.O_WRONLY \| os.O_NONBLOCK)`, then close it. The waiting reader already counts as a reader (Linux `fs/pipe.c`; macOS measured), so this open succeeds instead of failing with `ENXIO`, and it wakes the reader |
| `os.open(fifo, os.O_WRONLY)` with no reader | `os.open(fifo, os.O_RDONLY \| os.O_NONBLOCK)` — returns at once and completes the writer's open |
| `lock.acquire()` on a `threading.Lock` the test holds | `lock.release()` — a `Lock` release "can be called from any thread, not only the thread which has acquired the lock" |
| `q.get()` on an empty `queue.Queue` | `q.put(sentinel)` |
| `sock.recv(n)` with no data | Close the peer socket; `recv` returns `b''` |

   Then fail with the call's name in the message
   (`self.fail("open() on a FIFO did not return within 5 s")`).
4. **Prove the deadline on the regression.** Remove the guard that prevents the
   block (the regular-file check, the timeout argument) and require the test to
   fail at its deadline while the run goes on to the next test; restore the guard
   and require a pass ([testing-strategy-failing-test-first]).
5. **Set the deadline between the passing time and the runner's limit.** Put it
   above the slowest passing run you measured and below the runner's per-test or
   job timeout, so this test, not the runner, reports the hang. Reference points:
   the field case passed in 0.15 s and caught each regression with a
   5 s deadline; CPython's suite defaults these joins to `support.SHORT_TIMEOUT`
   (30 s).

## Edge cases

| Case | Then |
|------|------|
| The blocking call runs on a thread owned by the code under test | Release the resource it waits on (open the FIFO's other end, close the peer, put the sentinel) — the test cannot reach the thread itself |
| Nothing in the test process can release the call | Run it in a child process with `subprocess.run(..., timeout=...)`: on expiry "the child process will be killed and waited for" and `TimeoutExpired` is raised |
| Teardown deletes the temp directory holding the FIFO | Release before teardown: after `unlink`, the release by path fails with `ENOENT` and the reader stays blocked on an inode nothing can open again (measured) |
| A non-daemon thread is already stuck from an earlier test | The interpreter waits for it at exit; release its call (table above) so the run can finish |
| A runner-wide timeout plugin is configured | Keep the per-call deadline as well: it names the blocked call in one red test, and the remaining tests still run |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Call the possibly-blocking function directly in the test body | Run it in a daemon thread with `join(timeout)` and an `is_alive()` check | A regression then hangs the whole run instead of producing one red test |
| Rely on the CI job timeout to catch the hang | Add the per-call deadline | The job timeout reports a stalled run, not the call that blocked |
| Fail the test and leave the thread blocked | Release the blocked call, join, then fail | The blocked thread outlives the test; a non-daemon one keeps the process from exiting |

## Sources

- https://docs.python.org/3/library/threading.html — "As `join()` always returns `None`, you must call `is_alive()` after `join()` to decide whether a timeout happened"; "The entire Python program exits when only daemon threads are left"; daemon threads "are abruptly stopped at shutdown"; `Lock.release()`: "This can be called from any thread, not only the thread which has acquired the lock."
- https://github.com/python/cpython/blob/main/Lib/test/support/threading_helper.py — `join_thread(thread, timeout=None)`: `thread.join(timeout)`, then `AssertionError` when `thread.is_alive()`; the default is `support.SHORT_TIMEOUT` (30.0 on CPython 3.14.6)
- https://pubs.opengroup.org/onlinepubs/9699919799/functions/open.html — with `O_NONBLOCK` clear, "An open() for reading-only shall block the calling thread until a thread opens the file for writing"; with it set, "An open() for writing-only shall return an error if no process currently has the file open for reading" (`ENXIO`)
- https://man7.org/linux/man-pages/man7/fifo.7.html — "Normally, opening the FIFO blocks until the other end is opened also"; a non-blocking write-only open "fails with ENXIO … unless the other end has already been opened"
- https://github.com/torvalds/linux/blob/master/fs/pipe.c — `fifo_open`: a reader increments `pipe->readers` before `wait_for_partner`; an `O_NONBLOCK` writer gets `-ENXIO` only when `!pipe->readers`, and its open calls `wake_up_partner` — so on Linux a reader blocked in `open()` is released by a non-blocking writer
- https://docs.python.org/3/library/subprocess.html — `run()`: "If the timeout expires, the child process will be killed and waited for. The TimeoutExpired exception will be re-raised after the child process has terminated."
- Local reproduction 2026-10-07 (CPython 3.14.6, macOS Darwin 25.1.0): a reader thread blocked in `open(fifo, O_RDONLY)` was alive after `join(1.0)`; `os.open(fifo, O_WRONLY|O_NONBLOCK)` succeeded and the reader returned; with no reader the same open failed with errno 6 (`ENXIO`); a writer blocked in `open(O_WRONLY)` was released by `open(O_RDONLY|O_NONBLOCK)`; `Lock.release()` from the test thread, `Queue.put()`, and closing a `socketpair` peer each released their blocked call (`recv` returned `b''`); after `unlink` of a FIFO with a blocked reader, the release by path failed with errno 2 and the reader stayed blocked; a child process whose only extra thread was a daemon stuck in FIFO `open()` exited in 0.55 s, and the same child with a non-daemon thread was still running at 5 s. Re-run 2026-10-07 on CPython 3.13.1: no-reader `O_WRONLY|O_NONBLOCK` open → `ENXIO`; a reader blocked after `join(1.0)` was released by that open once the reader existed; `Lock.release()` from the test thread released a blocked `acquire`; the daemon child exited in 0.04 s, the non-daemon child was still running at 5 s
- Field evidence 2026-10-06 (a Python CLI's unittest suite, FIFO-rejection tests): with the regular-file check removed, the FIFO tests each failed at the 5 s deadline (`FAILED (failures=5)`, 20.2 s) and the run finished; with the check restored they passed in 0.15 s
