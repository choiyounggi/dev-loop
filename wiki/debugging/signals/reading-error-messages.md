---
id: debugging-signals-reading-error-messages
domain: debugging
category: signals
applies_to: [general]
confidence: field-tested
sources:
  - https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Errors
  - https://gcc.gnu.org/onlinedocs/gcc/Warning-Options.html
last_verified: 2026-07-10
related: [debugging-signals-stack-traces, debugging-methodology-hypothesis-testing]
---

# Reading an Error Message Before Acting on It

## When this applies

Any error output you are about to act on: a compiler/build failure, a runtime
error without a stack trace, a config/startup error, or a wall of errors from
one run — or you are about to search for a fix for an error. When a stack
trace is attached, [debugging-signals-stack-traces] owns the trace reading.

## Do this

1. Read the entire message before acting, including notes, hints, candidate
   lists, and "did you mean" lines — compilers often print the fix. Error
   messages state what failed, where, and expected-vs-actual more often than
   the skim-and-guess reflex assumes; the read is cheaper than the wrong guess.
2. Parse the message's anatomy and use each part:

| Part | Use it by |
|------|-----------|
| Identifier/code (`TS2345`, `E0308`, `ENOENT`) | Looking it up in the tool's error reference (e.g. MDN's JavaScript error reference) |
| Location (`file:line:column`) | Opening that exact location before theorizing about the cause |
| Expected-vs-actual clause ("expected X, found Y") | Treating it as the hypothesis seed — carry it into [debugging-methodology-hypothesis-testing] |

3. Cascading errors (compilers, type checkers, template/config parsers): fix
   the FIRST error only, then re-run. Later errors are frequently consequences
   of the first — one missing brace births fifty phantom errors. A count of
   errors is not the amount of problems. (GCC ships `-Wfatal-errors` to abort
   on the first error for exactly this reason.)
4. When one run prints many errors, classify before fixing:

| Case | Do |
|------|----|
| Same error class repeated across many files | Suspect one root cause (bad import path, version mismatch, missing dependency); fix once, re-run |
| Mixed, apparently unrelated errors | Start at the first error chronologically/topmost; fix it, re-run, reclassify what remains |

5. When searching for the error:

| Case | Do |
|------|----|
| Building the query | Search the exact message in quotes, minus project-specific fragments (paths, variable names, ids) |
| Behavior is version-dependent | Include the tool/library name and version in the query |
| The message carries an error code | Search the code — it matches better than the prose around it |
| Zero results | Strip more specifics; when the message is generated dynamically, search its static prefix |

6. Before applying a found fix: explain it against YOUR error's mechanism.
   A fix you cannot explain is a guess with confidence — verify it addresses
   your cause, not just your symptom, per [debugging-methodology-hypothesis-testing].

## Edge cases

| Case | Then |
|------|------|
| A stack trace is attached to the error | Read the message per this page, read the trace per [debugging-signals-stack-traces] |
| Location points into generated or vendored code | The suspect is the input your project feeds it (template, schema, config, call site) — find and open that input, not the generated line |
| Build tool prints only a summary ("1 error", "task failed") | Re-run with the verbose/full-log flag and read the underlying tool's message; the summary is not the message |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Paste the last error of a cascade into a search | Fix the first error, re-run | Later errors are consequences; the last one describes a phantom |
| Act on the one-line summary | Read the full message including notes/hints | Compilers often print the fix (candidates, "did you mean", required flag) |
| Search the message with your paths and variable names in it | Strip project-specific fragments; keep static text and the error code | Others hit the same error with different names; your specifics match nothing |

## Sources

- https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Errors — error name + message as the lookup key toward understanding and resolving an error
- https://gcc.gnu.org/onlinedocs/gcc/Warning-Options.html — `-Wfatal-errors`: abort on the first error instead of printing further error messages
- Search strategy and multi-error triage: field-tested practice; no citable primary source
