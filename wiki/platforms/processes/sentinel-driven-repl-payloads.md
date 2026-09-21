---
id: platforms-processes-sentinel-driven-repl-payloads
domain: platforms
category: processes
applies_to: [node, general]
confidence: verified
sources:
  - https://nodejs.org/api/repl.html
last_verified: 2026-09-04
related: [platforms-processes-driving-a-tui-in-a-tmux-pane, platforms-processes-non-interactive-cli-invocation, testing-async-async-testing, testing-quality-tests-that-cannot-fail]
---

# Driving an External REPL by Piped Payload Lines and a Completion Sentinel

## When this applies

Automating an external REPL or CLI (a browser-automation REPL channel,
`node -i` fed via stdin, any tool that evaluates one line and prints its own
ok/error marker) by writing JavaScript statements to its stdin and waiting for
that marker before treating a step as done. Also when every step reports
success with empty or wrong stdout, or a fake-REPL unit test cannot catch a
failure the real REPL exhibits.

## Do this

1. **Send the payload with a top-level `await` on the outermost expression**:
   `await (async () => { ... })();`, rather than a bare async IIFE. A REPL with
   top-level-await support suspends the whole line's evaluation on that
   `await`, so the sentinel prints only once the awaited work finishes.
2. **After the sentinel, assert on the payload's own stdout or return value,
   not only the ok/error marker.** The marker proves the REPL finished
   evaluating the line, not that the async work inside it ran to completion.
3. **Choose the check by what the REPL exposes:**

| REPL behavior | Do |
|---------------|----|
| Prints the expression's result on the same line as the sentinel | Assert that result is not an unresolved `Promise { <pending> }` |
| Only prints stdout/console output, no expression value | `console.log` an explicit marker inside the awaited path and require that exact string in captured stdout |
| Exposes a way to query real state (a `listTabs()`-style introspection call) | After the sentinel, make a separate call reading the state the payload was supposed to create, and assert on that |

4. **When unit-testing the driving code itself, replay real REPL transcripts**
   (both the unawaited-IIFE failure shape and the awaited success shape)
   rather than canned stdout — a fake that always returns scripted "ok" output
   can never exercise the fast-sentinel, no-output failure mode this page
   describes ([testing-quality-tests-that-cannot-fail]).

## Edge cases

| Case | Then |
|------|------|
| The async work must run several dependent steps | Chain them with `await` inside one payload, or send one line per step and wait for each line's own sentinel — one awaited unit at a time, rather than several un-awaited calls fired at once |
| The target REPL has no top-level `await` | Wrap the payload as `void (async()=>{...})().then(()=>console.log(SENTINEL))` and gate on that printed sentinel instead of the REPL's own marker, since the marker still fires early |
| The payload's `await` throws | Node's REPL surfaces it as `Uncaught <Error>` on the same line — treat that as the step's own failure, distinct from "no output" |
| Payload sent over `tmux send-keys` rather than piped stdin | Same consumption-vs-echo risk in a different shape → [platforms-processes-driving-a-tui-in-a-tmux-pane] |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Send `(async () => { await doThing(); console.log("done") })();` and wait for the sentinel | Send `await (async () => { await doThing(); console.log("done") })();` | The bare IIFE returns an unawaited promise; the REPL evaluates the call expression synchronously and prints its ok sentinel in milliseconds while the async body is still pending |
| Treat the ok/error sentinel as proof the step's side effect happened | Assert on the payload's own stdout or a follow-up state query | The sentinel reports the line finished evaluating, which for an unawaited promise happens before the async work completes |
| Unit-test the driver with a fake REPL replaying scripted stdout for each command | Replay real transcripts including the fast-empty-output failure shape | A canned-stdout fake cannot produce the exact failure this page exists to catch |

## Sources

- https://nodejs.org/api/repl.html — "Support for the `await` keyword is enabled at the top level" in the Node.js REPL; disabled via `--no-experimental-repl-await`
- Local reproduction 2026-09-04 (Node.js v26.7.0, macOS, `node -i` fed via piped stdin): `(async()=>{await new Promise(r=>setTimeout(r,300));console.log("done-unawaited")})();` followed by `.exit` printed only `Promise { <pending> }` — the 300 ms `console.log` never appeared; the same work as `await new Promise(r=>setTimeout(r,300)); console.log("done-awaited");` printed `done-awaited` before the REPL returned control
- Field evidence 2026-08-25 (measured in a linkly-crew orchestration run, browser-automation REPL channel): `(async () => { await openTab(url); console.log(...) })();` → ok sentinel in ~10 ms, no output, no tab in a follow-up tab-listing query; the same call with a leading `await` → output printed, ok sentinel in ~800 ms, tab present in the follow-up query
