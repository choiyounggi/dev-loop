---
id: testing-async-transient-state-behind-a-controlled-gate
domain: testing
category: async
applies_to: [general]
confidence: verified
sources:
  - https://martinfowler.com/articles/nonDeterminism.html
  - https://testing.googleblog.com/2021/03/test-flakiness-one-of-main-challenges.html
  - https://tokio.rs/tokio/topics/testing
  - https://docs.rs/tokio/latest/tokio/task/struct.JoinHandle.html
last_verified: 2026-09-28
related: [testing-async-async-testing, testing-flaky-diagnosing-flaky-tests, testing-quality-tests-that-cannot-fail, testing-quality-narration-based-ordering-assertions, testing-quality-proving-a-critical-section-is-lock-protected]
---

# Asserting on a Mid-Run State That a Background Finisher Will Wipe

## When this applies

A test must observe a transient mid-run state of an async orchestrator or state
machine — an entry in a shared controls map, an in-flight handshake, a pending
approval — and a background task spawned by the same startup (a reaper,
finisher, teardown, cleanup timer) clears that state as soon as it runs. A
condition wait does not fit because the state is not a final state: the wait can
observe "present" or "already gone", and both are legal outcomes of the code.
Sleeping is ruled out, and so is racing the read against the finisher.

## Do this

1. **Park the system in a state whose only exit is a decision the test
   controls.** Find the point where the code under test blocks on external input
   — an unresolved approval gate, an un-acknowledged handshake, an unanswered
   prompt — and drive the test into it without supplying that input. While
   parked, the code path that reaches the finisher has not been taken, so
   "state present when read" holds by construction, with no timing primitive
   involved.

| Shape of the code under test | Park point |
|------------------------------|------------|
| Approval / human-in-the-loop gate | Leave the gate unresolved; resolve it after the assertion |
| Request/acknowledge handshake | Withhold the ack; send it after the assertion |
| Prompt or question to an external actor | Leave it unanswered; answer after the assertion |
| No external decision point exists (a purely timer- or completion-driven finisher) | Hold the finisher's completion handle and use it as the ordering point instead ([testing-flaky-diagnosing-flaky-tests] handle row), or make its timer test-controlled (paused time, [testing-async-async-testing]) |

2. **Assert inside the park, then release.** Read the transient state and run
   the assertion that discriminates the intended mechanism from the teardown
   path (one key removed vs the whole map cleared; one entry vs zero). Then
   supply the decision and await the finisher's handle so teardown still runs
   and the same test proves the release path.
3. **Reach the park through an existing fixture first.** The tests of the gate
   itself need a helper that plants a run and stops at the gate; find that
   helper and build on it before writing a new one.
4. **Turn off every other exit from the park.** A tick-driven escalation, a
   watchdog, or a retry budget leaves the park on its own; set each to the value
   that disables it for this test (`escalation_timeout = 0`, a `never`
   variant) so the test's decision stays the only exit.
5. **Prove the test discriminates by mutation, at every finisher spawn site.**
   Enumerate every place the finisher is spawned (normal completion and the
   error path are two); mutate each so the finisher never runs and require red — a
   parked test that stays green with no finisher asserts nothing about
   teardown. Restore, then run the test in a loop (20 or more iterations) and
   require a clean streak ([testing-quality-tests-that-cannot-fail]).

## Edge cases

| Case | Then |
|------|------|
| The state is wiped by a task other than the one the gate blocks | The gate is not a park for that state: find the decision point upstream of the wiping task, or fall back to its completion handle |
| The runtime offers paused/virtual time (tokio `start_paused`, fake timers) | Paused time removes timer races, not task-scheduling races; a finisher triggered by another task's completion still needs the park |
| The runtime guarantees ordering on the handle (tokio: the task's destructor has finished before `JoinHandle` `await` returns) | Awaiting the handle is a real ordering point for the *after*-wipe state; the park is for the *before*-wipe state — use both when one test asserts both |
| The discriminating assertion is "one key removed" vs "map cleared" | Assert the count and the specific key, not emptiness alone — emptiness is true on both paths |
| The naive read has passed for months | Its margin is scheduling luck, not construction; convert it to a park before it flips under load on the exact assertion that matters |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Read the shared state right after startup because it "always wins in practice" | Park behind a decision the test controls | The read wins by scheduling margin; the margin closes under load, and the failure lands on the one assertion that distinguishes mechanism from teardown |
| Add a `sleep` or a retry loop before the read | Park | Fowler: "Never use bare sleeps to wait for asynchronous responses"; Google: "Wait() is as good as Hope()" — a sleep changes the odds, not the ordering |
| Poll the state with a `waitFor` until it appears | Park | The state is transient: a poll that sees "gone" cannot tell "never present" from "already wiped" |
| Call the test deterministic after one green run | Mutate every finisher spawn site and require red, then loop it | One green run is consistent with a test that cannot fail |

## Sources

- https://martinfowler.com/articles/nonDeterminism.html — "Never use bare sleeps to wait for asynchonous responses: use a callback or polling"; Humble Object: isolate the logic from the asynchronous environment so most of it "can be tested synchronously" — a park is that isolation applied to one ordering
- https://testing.googleblog.com/2021/03/test-flakiness-one-of-main-challenges.html — "You should never need any type of sleep or wait in your test automation ... Wait() is as good as Hope() when determining how long is long enough to pause for something to happen"
- https://tokio.rs/tokio/topics/testing — paused time: "any time-related future may become ready early" so timer-driven ordering becomes deterministic; it does not order tasks against each other, which is the case this page covers
- https://docs.rs/tokio/latest/tokio/task/struct.JoinHandle.html — "It is guaranteed that the destructor of the spawned task has finished before task completion is observed via JoinHandle await": the handle is the ordering point for the post-wipe state
- Local reproduction 2026-09-28 (Node v26.7.0; a startup that seeds a `Map` and spawns a finisher that clears it on the next timer turn): reading right after startup → 0/200 failures; the same read after one scheduler turn of pressure → 200/200 failures; the finisher parked behind a promise the test resolves after the read, same pressure → 0/200 failures, and the map is empty after release every time
- Field evidence 2026-09 (a Rust `tokio` orchestrator, crew-run task t3-swap-flake; recorded by the originating session, not re-run in this flush): `escalation_timeout_ms = 0` disabled the lead's tick branch, so a planted violation with `max_rework = 0` held the lead task open until `resolve_gate`; the test asserted inside that park. Mutating both `tokio::spawn(reap_controls_entry(...))` sites → `FAILED ... Elapsed(())` after 30 s; restored → `ok. 4 passed`; 20/20 stable
