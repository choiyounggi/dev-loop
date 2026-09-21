---
id: testing-mocking-autouse-fixture-shadows-function-under-test
domain: testing
category: mocking
applies_to: [python]
confidence: verified
sources:
  - https://docs.pytest.org/en/stable/how-to/monkeypatch.html
  - https://docs.pytest.org/en/stable/how-to/fixtures.html#autouse-fixtures-fixtures-you-don-t-have-to-request
last_verified: 2026-09-08
related: [testing-mocking-what-to-mock, testing-data-test-data-and-isolation, testing-quality-tests-that-cannot-fail]
---

# A Test Asserting a Function's Own Properties While an Autouse Fixture Replaces It

## When this applies

A test calls `module.func(...)` directly to assert that function's own
behavior or properties, and a pytest `autouse=True` fixture in the same
conftest replaces `module.func` with `monkeypatch.setattr` for the whole
suite or file.

## Do this

1. **Determine which implementation the test's call site actually reaches
   before trusting the assertion.** `monkeypatch.setattr` runs as fixture
   setup, which completes before the test body executes, and it replaces the
   name in the target's own namespace — so `module.func` inside the test body
   resolves to whatever was set last: the fixture's stub, not the source
   definition.
2. **Confirm by breaking the real function and requiring the test to go
   red** ([testing-quality-tests-that-cannot-fail]). If the test stays green
   while the real implementation is provably broken, the assertion is
   exercising the stub, not the function.
3. **When the assertion must run against the real function, capture the
   original reference before the fixture applies** — at module import time, in
   a name the fixture does not target (`_REAL_FUNC = module.func` at the top
   of the test file, executed during collection, before any fixture's setup
   phase runs) — and assert against that captured reference instead of
   `module.func`.

| Case | Do |
|------|----|
| The test needs the real function's behavior and a co-located autouse fixture patches the same name | Capture the original at import time in a separate name; assert against the capture |
| The test's own purpose is to verify the fixture's isolation (that other code calls through the patched seam) | Assert via `module.func` as usual — this is the fixture's intended effect, not a defect |
| Unsure whether an existing test asserts the real function or the stub | Break the real function and rerun; green means the assertion never reached it |

## Edge cases

| Case | Then |
|------|------|
| The fixture patches at a different name than the test imports (`import module` vs `from module import func`) | `monkeypatch.setattr` must target the same binding the test reads; check both import forms — patching `module.func` does not affect a name already bound via `from module import func` in another file |
| The capture (`_REAL_FUNC`) is itself later monkeypatched by a different fixture | Capture at collection time is only safe from fixtures that run at test setup; a fixture that patches at collection/import time would still shadow it — verify by breaking the real function once more after adding the capture |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Assert on `module.func(...)` in a file where a co-located autouse fixture already `monkeypatch.setattr`s that name | Capture the original at import time and assert against the capture | `monkeypatch.setattr` finishes before the test body runs and replaces the name in its own namespace, so the two tests silently disagree about which implementation "the function" means |
| Trust that a green suite proves the real function is covered | Break the real function and confirm the specific test goes red | An isolation fixture and a test that verifies the function itself can coexist in one green suite while the second one asserts nothing |

## Sources

- https://docs.pytest.org/en/stable/how-to/monkeypatch.html — "monkeypatch.setattr must be called before the function which will use the patched function is called"; "All modifications will be undone after the requesting test function or fixture has finished"
- https://docs.pytest.org/en/stable/how-to/fixtures.html#autouse-fixtures-fixtures-you-don-t-have-to-request — autouse fixtures are requested automatically for every applicable test and run as setup "even though neither test requested it"
- Field evidence (a Python trading-bot repo, review finding F1 on a shared-throttle task, fix introducing `_REAL_THROTTLE_PATH`): a test asserting the throttle function's own property called it through the module attribute a co-located autouse fixture monkeypatched; capturing the reference before the fixture applied and asserting against that reference was confirmed by breaking the real function and observing the test go red
