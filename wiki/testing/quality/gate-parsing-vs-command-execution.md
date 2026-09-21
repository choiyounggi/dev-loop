---
id: testing-quality-gate-parsing-vs-command-execution
domain: testing
category: quality
applies_to: [general]
confidence: verified
sources:
  - https://cwe.mitre.org/data/definitions/78.html
  - https://man7.org/linux/man-pages/man1/timeout.1.html
last_verified: 2026-09-04
related: [testing-quality-checks-that-cannot-pass, qa-document-verification-spec-document-gates, platforms-shells-command-text-inspected-before-execution, security-agent-exposure-in-session-tool-exposure]
---

# Separating a Document/Plan Parser From the Command Executor It Feeds

## When this applies

Writing or reviewing a gate script that reads a document or plan file
containing command strings (a plan's verification command, a runbook's repro
command, a spec's example invocation), and deciding whether the parser may
run those strings directly (`sh -c "$cmd"`) or must hand them to a separate
executor.

## Do this

1. **Keep the parser's job to two questions**: does the target exist, and
   can it be parsed. A parser that also runs `sh -c` on a string it just
   extracted doubles as an untrusted-command executor — any document author
   (including an LLM producing the plan) gains a code-execution surface the
   moment their prose is treated this way (CWE-78: "constructing operating
   system commands using externally-controlled input without properly
   neutralizing special characters").
2. **Route every command that must actually run through one dedicated
   executor**, bounded by a timeout and required to record its evidence
   (exit code plus matched output) in a durable ledger line — one executor,
   rather than `sh -c` calls scattered across parsing code. `timeout(1)`'s
   contract is the shape to copy: run the command, kill it when it outruns
   its budget, and surface a distinct status (124) for "timed out" versus the
   command's own exit code; a bare `sh -c "$cmd"` with no timeout hangs the
   whole gate on one bad line.
3. **Prove the non-execution property with a fixture, not a code read.**
   Write a fixture document whose embedded command would fail loudly if run
   (`CHECK: false`, or a command naming a path that does not exist), feed it
   to the parser-only path, and require it to still report `ok`. A fixture
   whose "would-fail" command changes the parser's own verdict proves the
   parser executed it.
4. **When parser and executor are one binary in two modes**
   (`--status` / `--run`), state the mode boundary in the usage banner and
   put the timeout only inside the executing mode, so a future edit cannot
   move execution into the read-only mode without showing up as a one-line
   diff of that path.

## Edge cases

| Case | Then |
|------|------|
| The document embeds a command as prose or example, not as a thing to run | Keep it out of any field the parser scans for `CHECK`/executable markers — [platforms-shells-command-text-inspected-before-execution] covers passing such text through a non-executing channel |
| The same script must support both a fast pre-flight parse and a full execution pass | Split into two invocation modes on one binary (`--status` vs `--run`), not two conditionals inside one code path — a caller that only wants existence/parseability should never be one flag away from executing |
| A gate has never been observed passing (unwritten target) | Validate the check's own correctness per [testing-quality-checks-that-cannot-pass] as well — that page's known-good/mutated-input proof and this page's non-execution proof are different properties of the same script |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Call `sh -c "$cmd"` inside code that parses a plan or document for existence and structure | Extract the command into a ledger line and hand it to a dedicated executor with its own timeout | Parsing and executing are different trust levels; merging them turns every document the parser reads into a command-execution surface (CWE-78) |
| Trust a code read ("the parser has no `sh -c`, so it is safe") as proof of non-execution | Add a fixture with a deliberately failing command and require the parser-only path to return ok on it | A read can miss a call buried behind a helper; the fixture is evidence, the read is a hypothesis |
| Let a slow or hanging embedded command stall the whole gate | Bound every executed command with a timeout and a distinct timed-out exit status | An unbounded `sh -c` on a bad line blocks the harness indefinitely, indistinguishable from a hang elsewhere in the pipeline |

## Sources

- https://cwe.mitre.org/data/definitions/78.html — CWE-78, "Improper Neutralization of Special Elements used in an OS Command ('OS Command Injection')": constructing OS commands from externally-controlled input without neutralizing special elements
- https://man7.org/linux/man-pages/man1/timeout.1.html — "run a command with a time limit"; exit status 124 "if COMMAND times out", distinct from the command's own exit status
- Local reproduction 2026-09-04 (this repo, `skills/loop-implement/scripts/gate-check.sh`): the usage banner documents `--status` as "parse + report; never executes CHECK" versus `--run`, which executes runnable gates' CHECK bounded by `GATE_CHECK_TIMEOUT` seconds (default 120) via a perl alarm and records EVIDENCE per gate — a production instance of the split this page recommends
- Field evidence 2026-09-02 (measured in a linkly-crew orchestration run, review t1-plan-gate-r1): a plan-gate script's direct `sh -c` execution of a document-embedded command was flagged in review; the repair commit removed the `sh -c` call and added a non-execution test (a fixture whose command would fail, returning `ok` from the parser), re-reviewed at 87/87 green
