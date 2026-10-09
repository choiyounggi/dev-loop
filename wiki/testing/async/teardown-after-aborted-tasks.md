---
id: testing-async-teardown-after-aborted-tasks
domain: testing
category: async
applies_to: [rust, general]
confidence: verified
sources:
  - https://docs.rs/tokio/latest/tokio/task/index.html#cancellation
  - https://docs.rs/tokio/latest/tokio/task/struct.JoinHandle.html
  - https://docs.rs/tokio/latest/tokio/runtime/struct.Runtime.html#shutdown
  - https://doc.rust-lang.org/book/ch11-01-writing-tests.html#using-resultt-e-in-tests
last_verified: 2026-09-28
related: [testing-async-async-testing, testing-data-artifact-leakage-from-a-suite, testing-data-test-data-and-isolation, testing-quality-tests-that-cannot-fail]
---

# Deleting a Resource That Spawned Async Tasks Still Use

## When this applies

A test (or a shutdown path) spawned tasks on an async runtime — tokio or a
similar executor — and is about to delete or close what those tasks use: a temp
directory, a socket, a spool a spawned server writes to. You are reaching for a
`Drop` guard or a cleanup call placed after the assertions. Also when leftover
test directories concentrate in runs that failed.

## Do this

1. **Put teardown on the one path every outcome takes.** Run the body so that
   it *records* what happened instead of asserting midway (`let outcome =
   body().await;`), tear down, then assert on the recorded outcome or return it
   with `?` — a test may return `Result` in Rust. Assertions that panic before
   the teardown line skip it, so a test that is failing is the one that leaks.
2. **Inside teardown, abort and then await every `JoinHandle` before deleting
   anything.** `abort()` only schedules the cancellation; a task that is running
   keeps going until its next `.await`, so it can recreate the path a
   synchronous delete just removed. Awaiting the handle is the ordering point:

| Call | What tokio guarantees |
|------|-----------------------|
| `h.abort()` | "schedule[s] the task for cancellation, and will return before the cancellation has completed"; the task stops "next time it yields at an `.await` point" |
| `h.await` after `abort()` | "the destructor of the spawned task has finished before task completion is observed via `JoinHandle` await" — delete after this line |
| Dropping `h` | "detaches the associated task"; nothing can join it any more |
| Dropping the `Runtime` (end of `#[tokio::test]`) | spawned tasks "keep running until they yield. Then they are dropped" — the test's locals, including a `Drop` guard, are dropped *before* the runtime is |
| `abort()` on a `spawn_blocking` task | "will not have any effect, and the task will continue running normally" once it has started |

3. **Keep the handles reachable from the owner of the resource.** Store each
   `JoinHandle` in the struct that owns the directory or server and give it an
   async `shutdown()` that aborts, awaits, then deletes; a handle dropped at the
   spawn site cannot be joined later.
4. **Keep `Drop` as the net, not the mechanism.** `Drop` cannot await, so it
   covers only failures that happen before the runtime or the handles exist
   (a fixture that fails half-built). A `Drop` that deletes while tasks are
   alive is the race, not the fix.
5. **Prove it by counting leftovers on both paths.** Run the test N times
   normally and N times with a forced failure in the body, and require zero
   leftovers under the scratch root both times ([testing-data-artifact-leakage-from-a-suite]
   step 7). A pass-path count alone hides the panic path, which is where the
   trailing-cleanup shape fails.

## Edge cases

| Case | Then |
|------|------|
| The body calls something that can panic outside your assertions (an `unwrap` inside a helper) | Convert it to `?` on the recorded `Result`, or wrap the body future in `catch_unwind` (`futures::FutureExt`) and resume the panic after teardown |
| A task never reaches an `.await` (a busy loop, a blocking read) | `abort()` never lands and `h.await` hangs: add a shutdown signal the task polls, and bound the await with `tokio::time::timeout` so the test fails instead of hanging |
| The task is `spawn_blocking` | Signal it (flag, channel, closed socket) and await the handle; `abort()` is documented as a no-op once it runs |
| The resource is a bound socket/port reused by the next test | Await the handle before the next test binds — an aborted-but-running accept loop still holds the port ("address in use") |
| The runtime is `current_thread` | The window narrows but stays: locals drop before the runtime, and at runtime drop the task runs to its next yield. Keep the same order |
| Cleanup is a `Drop` on a fixture, and the fixture is dropped inside a `spawn`ed task or across threads | The delete runs on whichever thread drops last; make the join explicit in an async `shutdown()` and call it on every exit |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Delete the directory in a `Drop` guard | An async `shutdown()` that aborts, awaits each handle, then deletes; keep `Drop` as the net | `Drop` cannot await; an aborted task keeps running until its next `.await` and recreates the path |
| Call `cleanup()` after the assertions | Record the outcome, tear down, then assert | A failing assertion unwinds past the cleanup line — the leak appears exactly when the test fails |
| `h.abort()` and immediately delete | `h.abort(); let _ = h.await;` then delete | `abort` returns before cancellation completes; only the await orders the destructor before the delete |
| Rely on the runtime being dropped at the end of `#[tokio::test]` | Join explicitly in teardown | Runtime drop lets tasks run to their next yield, and the test's `Drop` guards have already run by then |
| Count leftovers after passing runs only | Count after forced-failure runs too | The pass path exercises the trailing cleanup; the panic path exercises only the `Drop` net |

## Sources

- https://docs.rs/tokio/latest/tokio/task/index.html#cancellation — "the task is signalled to shut down next time it yields at an `.await` point"; "calls to `JoinHandle::abort` just schedule the task for cancellation, and will return before the cancellation has completed"; a task that does not yield between `abort` and its end "exited normally"
- https://docs.rs/tokio/latest/tokio/task/struct.JoinHandle.html — "It is guaranteed that the destructor of the spawned task has finished before task completion is observed via `JoinHandle` await"; dropping a `JoinHandle` "detaches the associated task"; `abort` on a started `spawn_blocking` task "will not have any effect"
- https://docs.rs/tokio/latest/tokio/runtime/struct.Runtime.html#shutdown — on drop, spawned tasks "keep running until they yield. Then they are dropped. They are not guaranteed to run to completion"; blocking functions "keep running until they return"
- https://doc.rust-lang.org/book/ch11-01-writing-tests.html#using-resultt-e-in-tests — a `#[test]` may return `Result<(), E>` so the body can propagate a recorded failure with `?` after teardown
- Local reproduction 2026-09-28 (tokio 1.53.1, cargo 1.98.0, macOS, `multi_thread` runtime with 4 workers): a spawned task loops `create_dir_all` → `write` → `yield_now` with 400 µs of non-yielding work per iteration. `abort()` followed directly by `remove_dir_all`: directory left behind in 148 of 200 runs; `abort()`, `await` the handle, then `remove_dir_all`: 0 of 200
- Field evidence 2026-09-28 (a Rust `tokio` orchestrator, crew-run task t3-swap-flake; recorded by the originating session): a `RunHandle::shutdown` that aborted every task but awaited only the bus left `.crew-test/<uuid>` directories in 1 of 3 passing runs and 2 of 3 / 3 of 3 failing runs; joining every reachable handle inside a single-exit-path teardown left 0 of 12 across both mutation forms
