---
id: testing-quality-captured-log-message-assertions
domain: testing
category: quality
applies_to: [python, pytest]
confidence: verified
sources:
  - https://docs.python.org/3/library/logging.html#logrecord-attributes
  - https://docs.pytest.org/en/stable/reference/reference.html#pytest.LogCaptureFixture.messages
  - https://github.com/pytest-dev/pytest/blob/main/src/_pytest/logging.py
last_verified: 2026-08-14
related: [testing-quality-tests-that-cannot-fail]
---

# Asserting on Captured Log Messages

## When this applies

A test asserts on the content of log messages captured by pytest's `caplog`
(or any handler that stores `LogRecord`s), and the logging call under test
passes format arguments — `logger.warning("failed: %s", err)`. Also applies
when an existing suite's log-assertion helper re-interpolates
`record.message % record.args` and a new test suddenly raises
`TypeError: not all arguments converted during string formatting`.

## Do this

1. **Assert against the interpolated message the API already provides** —
   `record.getMessage()` per record, or `caplog.messages` for the list.
   `getMessage()` merges `args` into `msg` exactly once, guarded by
   `if self.args:`, so it is correct for every call shape.
2. **Pick the accessor by what the assertion needs:**

| You want to check | Use | Not |
|-------------------|-----|-----|
| Final message text, exact comparison | `record.getMessage()` or `caplog.messages` | `record.message % record.args` |
| Message plus level/logger name | `caplog.record_tuples` (uses `getMessage()`) | string-building from record fields |
| Formatted output as the handler emitted it (substring) | `caplog.text` | reformatting records yourself |
| That a call site uses lazy `%s` args (the template itself) | `record.msg` and `record.args` separately | parsing the final text |

3. **When you find `record.message % record.args` in an existing helper, sweep
   the suite for the pattern and replace every site** — it survives only while
   all asserted log calls happen to be argument-less (`args == ()` makes the
   re-interpolation a no-op), so the first test covering a parameterized call
   breaks, and the error points at the new test rather than the helper.

## Edge cases

| Case | Then |
|------|------|
| Argument-less call whose message contains a literal `%` (`logger.info("50% done")`) | `record.message % ()` raises `ValueError` on the bare `%`; `getMessage()` skips merging when `args` is empty and returns the text unchanged |
| The log call passes a non-string object as the message | `getMessage()` applies `str()` to it; `record.message` holds the same result only after a formatter ran |
| Asserting a record captured by a bare list-appending handler (no `format()` call) | `record.message` does not exist yet — it is set only when `Formatter.format()` runs; `getMessage()` works regardless |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Re-interpolate with `record.message % record.args` | Use `record.getMessage()` | pytest's capture handler inherits `StreamHandler.emit`, which formats the record — `record.message` is already `msg % args`, and applying `% args` again raises `TypeError` whenever `args` is non-empty |
| Assert final text against `record.msg` | Assert against `getMessage()` | `msg` is the raw format template (`"failed: %s"`), not the logged message |
| Trust the helper because every existing log test passes | Add one test over a parameterized log call (or run a break-the-code check) | Zero-arg calls make the faulty re-interpolation a silent no-op, so a green history proves nothing ([testing-quality-tests-that-cannot-fail]) |

## Sources

- https://docs.python.org/3/library/logging.html#logrecord-attributes — `message`: "The logged message, computed as `msg % args`. This is set when `Formatter.format()` is invoked"; `getMessage()`: "Returns the message for this LogRecord instance after merging any user-supplied arguments with the message"
- https://docs.pytest.org/en/stable/reference/reference.html#pytest.LogCaptureFixture.messages — "A list of format-interpolated log messages … log messages in this list are all interpolated", recommended for exact comparisons
- https://github.com/pytest-dev/pytest/blob/main/src/_pytest/logging.py — `LogCaptureHandler.emit` stores the record and calls `StreamHandler.emit`, which formats it (setting `record.message`) at capture time
- Field reproduction 2026-08-14 (Python 3.x): a captured `logger.warning("detail(pbancNo=%s) failed: %s", "1234", "boom")` record has `message` fully interpolated; `record.message % record.args` raises `TypeError: not all arguments converted during string formatting`, while the same expression on an argument-less record silently returns the text — the mechanism that lets the faulty pattern persist in a suite
