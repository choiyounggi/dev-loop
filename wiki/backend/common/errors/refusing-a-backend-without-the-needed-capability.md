---
id: backend-common-errors-refusing-a-backend-without-the-needed-capability
domain: backend
category: errors
applies_to: [general, python]
confidence: verified
sources:
  - https://docs.python.org/3/library/argparse.html#argparse.ArgumentParser.error
  - https://docs.python.org/3/library/argparse.html#argparse.ArgumentParser.exit
  - https://docs.python.org/3/library/sys.html#sys.exit
  - https://docs.python.org/3/c-api/interp-lifecycle.html#c.Py_RunMain
  - https://man.freebsd.org/cgi/man.cgi?query=sysexits&sektion=3
  - https://clig.dev/
  - https://cheatsheetseries.owasp.org/cheatsheets/Logging_Cheat_Sheet.html
  - https://www.postgresql.org/docs/current/libpq-connect.html#LIBPQ-CONNSTRING-URIS
  - https://www.postgresql.org/docs/current/libpq-connect.html#LIBPQ-CONNSTRING-KEYWORD-VALUE
  - https://docs.sqlalchemy.org/en/20/core/engines.html#sqlalchemy.engine.URL.render_as_string
  - https://docs.python.org/3/library/typing.html#typing.runtime_checkable
  - "Field case 2026-10-11 (anhinga t3-cli-outbox-drain-guard plan, decisions D4/D5; recorded by the originating planning session): three outbox subcommands take --backend <scheme>:<dsn>; the refusal names the scheme because a postgres DSN can carry a password, and exits 2, the code those commands already used for an unsupported test-double backend, keeping 1 for a driver error raised mid-run"
last_verified: 2026-10-11
related: [security-secrets-secrets-in-code, security-agent-exposure-capability-flag-across-adapters, backend-common-change-impact-inserting-a-guard-before-an-existing-side-effect, backend-common-errors-diagnostics-from-a-shared-code-path, platforms-processes-tool-diagnostics-without-a-failing-exit-code, infrastructure-observability-logs-metrics-signals]
---

# A Subcommand Refusal When the Selected Backend Lacks the Capability It Needs

## When this applies

A CLI selects one of several interchangeable backends from an operator-supplied
value (`--backend <scheme>:<dsn>`, `--store`, `DATABASE_URL`) — the backend is
the store or service, its in-process object is the driver — and a subcommand
needs an optional capability (a relay's drain/ack pair, an export hook, a
listing API) that only some drivers implement. You are deciding what the
refusal prints, on which stream, with which exit status, and where in the code
it runs; or writing the test that proves it. Also when such a command currently
dies with an `AttributeError` traceback on an unsupported backend.

## Do this

1. **Evaluate one capability predicate on entry — before any work and before
   the first byte of stdout.** `isinstance(driver, Supports<Capability>)` on a
   `@runtime_checkable` Protocol, or membership in a capability set the driver
   declares, run once at the top of the handler. A refusal that fires after a
   partial batch leaves half-written output in the pipe and half-done work in
   the store; a precondition is checked on entry, before the body runs
   ([backend-common-change-impact-inserting-a-guard-before-an-existing-side-effect]).
2. **Print one stderr line from one template shared by every subcommand**, of
   the shape `<command>: backend '<scheme>' does not support <capability>; see
   <doc>`, **naming the backend by its scheme only** — `value.partition(":")[0]`,
   the text before the first `:`. The full value is a connection string, and a
   connection string carries `user[:password]@` (PostgreSQL URI syntax); OWASP's
   logging guidance lists "Database connection strings" and "Authentication
   passwords" among the data to remove or mask before recording, and a CI log, a
   cron mail, or a pasted terminal captures stderr verbatim. SQLAlchemy applies
   the same rule to its own URL rendering — `render_as_string()` hides the
   password by default — but it masks the `user:password@` slot only and
   includes query options as they are — which is why this refusal prints the
   scheme and nothing else; a message that must show host or database renders a
   copy with its query string removed ([security-secrets-secrets-in-code]).
   Messaging belongs on stderr so a piped consumer receives only stdout.
3. **Exit with the class the CLI already uses for "the operator chose something
   this command cannot serve", and keep the mid-run failure code separate.**
   The sources define the codes; filing a capability refusal under the usage
   class is this page's field decision, a reading of `EX_USAGE`'s "the command
   was used incorrectly … or whatever":

| The CLI's existing convention | Refusal exits with | Driver raised mid-run |
|-------------------------------|--------------------|-----------------------|
| argparse-style: usage errors exit 2 (`ArgumentParser.error()` "terminates the program with a status code of 2"); `error()` also prints the usage block, so emit the one-line refusal with `parser.exit(2, line + "\n")` | 2 | 1 — also what CPython returns for an unhandled exception |
| The CLI documents only 0 and 1 and no usage code | 2, added to the CLI's documented exit codes in the same change (the `sys.exit` docs' Unix convention: 2 for command line syntax errors, 1 for all other errors) | 1 |
| sysexits(3), value came from the command line | `EX_USAGE` (64): "a bad flag, a bad syntax in a parameter, or whatever" | `EX_UNAVAILABLE` (69) when the backend could not do the work; `EX_SOFTWARE` (70) when the driver reports an internal fault |
| sysexits(3), value came from a config file or the environment | `EX_CONFIG` (78): "an unconfigured or misconfigured state" | same |
| The command already refuses another backend (a test double, an in-memory store) with a documented code | that same code | the code it documents for mid-run faults |

   The two outcomes call for different operator actions — change the command
   vs. inspect the backend — so they carry different codes, and when the CLI
   already documents such a code it is reused rather than minted: "Map the non-zero exit codes
   to the most important failure modes", and every wrapper, doc table, and test
   keyed on exit codes already knows the existing value.
4. **End the line with a pointer to the document that lists which backends
   implement the capability** (`see <backends doc> §<capability table>`), so
   the operator's next step is named without the message carrying the list.
5. **Prove the refusal with a fixture driver whose predicate is false, selected
   by a value with a tail** — `<scheme>:<dsn carrying an obviously fake
   password>`; with a bare name, echoing the whole value and printing the
   scheme look identical, so the test cannot fail on step 2. Assert four
   things: the exit code from step 3, stderr equal to exactly one line of the
   step-2 template with the scheme as the only part taken from the backend
   value (the tail absent), empty stdout, and no driver method called (a spy on the driver, or the store
   unchanged). An exit-code assertion alone passes for a refusal that already
   drained half the batch.

## Edge cases

| Case | Then |
|------|------|
| The backend value has no `:` | Print it as is only when it equals a registered backend name (`sqlite`); otherwise print a fixed placeholder (`<unrecognized>`) — a colon-free value such as a `key=value` connection string can carry a password |
| The driver defines the method but raises `NotImplementedError` from it | A runtime-checkable Protocol passes it ("check only the presence of the required methods or attributes"); make the predicate read a declared capability (class attribute, registry flag) so the refusal still happens on entry |
| Several subcommands need the same capability | One template and one exit code for all of them, and one test per subcommand asserting that line, so a drifted copy fails its own test |
| The command has a `--json` or other machine-readable mode | The refusal stays on stderr with empty stdout and the exit code carries the verdict, so a consumer parsing stdout as JSON sees an empty stream and a non-zero status, not a partial document — consumer side in [platforms-processes-tool-diagnostics-without-a-failing-exit-code] |
| The operator needs to know which value was used | Name where it came from (the flag or the variable) plus the scheme; the value stays where they set it |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Echo the whole `--backend` value in the refusal | Print the scheme only (step 2) | The value can be a DSN with `user:password@`; connection strings are on OWASP's exclude list for logs |
| Let the `AttributeError` traceback be the refusal | Predicate on entry, one stderr line, the usage-class code (steps 1–3) | A traceback exits with the runtime's crash status (1 in CPython, "for any other unhandled exception"), the code the argparse-style row documents for a mid-run failure, so a wrapper cannot separate "wrong backend" from "backend broke"; the batch may also be half-processed by then |
| Mint a new exit code for this one refusal | Reuse the code the CLI already documents for an unsupported backend | Every caller, doc table, and test keyed on exit codes learns a new value for a failure mode that already has one |
| Give the refusal the mid-run failure code | The usage or configuration class from step 3 | The operator's fix differs: change the command vs. inspect the backend |

## Sources

- https://docs.python.org/3/library/argparse.html#argparse.ArgumentParser.error — `error(message)` "prints a usage message, including the message, to sys.stderr and terminates the program with a status code of 2" (fetched 2026-10-11)
- https://docs.python.org/3/library/argparse.html#argparse.ArgumentParser.exit — `exit(status=0, message=None)` "terminates the program, exiting with the specified status and, if given, it prints a message to sys.stderr before that" (fetched 2026-10-11)
- https://docs.python.org/3/library/sys.html#sys.exit — "Unix programs generally use 2 for command line syntax errors and 1 for all other kinds of errors." (fetched 2026-10-11)
- https://docs.python.org/3/c-api/interp-lifecycle.html#c.Py_RunMain — the return value is "0 if the interpreter exits normally (that is, without raising an exception), the exit status of an unhandled SystemExit, or 1 for any other unhandled exception" (fetched 2026-10-11)
- https://man.freebsd.org/cgi/man.cgi?query=sysexits&sektion=3 — `EX_USAGE` (64) "The command was used incorrectly, e.g., with the wrong number of arguments, a bad flag, a bad syntax in a parameter, or whatever."; `EX_CONFIG` (78) "Something was found in an unconfigured or misconfigured state."; `EX_UNAVAILABLE` (69) "A service is unavailable. This can occur if a support program or file does not exist. This can also be used as a catchall message when something you wanted to do does not work, but you do not know why."; `EX_SOFTWARE` (70) "An internal software error has been detected." (fetched 2026-10-11)
- https://clig.dev/ — "Return zero exit code on success, non-zero on failure."; "Map the non-zero exit codes to the most important failure modes."; "Send messaging to stderr. Log messages, errors, and so on should all be sent to stderr."; "Anything that is machine readable should also go to stdout" (fetched 2026-10-11)
- https://cheatsheetseries.owasp.org/cheatsheets/Logging_Cheat_Sheet.html — Data to exclude: "Database connection strings" and "Authentication passwords" are among the data that "should usually not be recorded directly in the logs, but instead should be removed, masked, sanitized, hashed, or encrypted" (fetched 2026-10-11)
- https://www.postgresql.org/docs/current/libpq-connect.html#LIBPQ-CONNSTRING-URIS — `postgresql://[userspec@][hostspec][/dbname][?paramspec]` where userspec is `user[:password]`; "Values that would normally appear in the hierarchical part of the URI can alternatively be given as named parameters."; "All named parameters must match key words listed in Section 32.1.2" (`password` is one of them) — so a `?password=` query option is a second place the password rides (fetched 2026-10-11)
- https://www.postgresql.org/docs/current/libpq-connect.html#LIBPQ-CONNSTRING-KEYWORD-VALUE — "In the keyword/value format, each parameter setting is in the form keyword = value, with space(s) between settings." — a colon-free connection string whose settings include `password` (`#LIBPQ-CONNECT-PASSWORD`) (fetched 2026-10-11)
- https://docs.sqlalchemy.org/en/20/core/engines.html#sqlalchemy.engine.URL.render_as_string — `hide_password` "Defaults to True. The password is not shown in the string unless this is set to False."; "The method directly includes additional options." (fetched 2026-10-11)
- https://docs.python.org/3/library/typing.html#typing.runtime_checkable — the decorator's note: `@runtime_checkable` "will check only the presence of the required methods or attributes, not their type signatures or types" (fetched 2026-10-11)
- Field case 2026-10-11 (anhinga `t3-cli-outbox-drain-guard` plan, decisions D4/D5; recorded by the originating planning session): three outbox subcommands take `--backend <scheme>:<dsn>`; the refusal names the scheme because a postgres DSN can carry a password, and exits 2 — the code those commands already used for an unsupported test-double backend — keeping 1 for a driver error raised mid-run
