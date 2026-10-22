# Knowledge flush — 3 insight(s)

Run id `20261011-223512-82499` (auto-flush child; lock inherited from `hooks/auto-flush.sh`). Branch `knowledge/choiyounggi-20261011-223623`. Claimed queue rows: `810ec34bbd09d936`, `391c39d1757da4ce`, `f1035fb812caa17f` — all three are `plan-gaps` rows from the anhinga `t3-cli-outbox-drain-guard` plan (wiki-plan Phase B decisions D4, D5, D11 that had no owning wiki page).

Outcome: **1 new bundled page** carrying the general kernel shared by rows 1 and 2; the project-specific residue of all three rows is excluded from this PR and listed under *Local-layer candidates*. No merge into an existing page; no conflicts. The change set passed an independent adversarial review before commit (section at the end).

## Verified best-practice

**Page:** `wiki/backend/common/errors/refusing-a-backend-without-the-needed-capability.md` (id `backend-common-errors-refusing-a-backend-without-the-needed-capability`), `confidence: verified`, 101 body lines.

**Claim (general kernel):** when a CLI subcommand must refuse because the operator-selected backend (`--backend <scheme>:<dsn>`, `--store`, `DATABASE_URL`) lacks an optional capability the command calls: (1) evaluate one capability predicate on entry, before any work and before any stdout; (2) print one stderr line from one shared template, naming the backend by its scheme only (`value.partition(":")[0]`) — the full value is a connection string that can carry `user:password@` or a `password=` option; (3) exit with the usage/configuration class the CLI already uses for "operator chose something this command cannot serve" and keep the mid-run failure code separate, reusing a documented code rather than minting one; (4) end the line with a pointer to the doc that lists capable backends; (5) prove it with a fixture driver whose predicate is false, selected by a value with a DSN tail carrying an obviously fake password, asserting exit code, one stderr line without the tail, empty stdout, and no driver call.

**Stated limit of the sources (written into step 3 of the page):** the man page and the Python docs define the exit-code classes; filing a capability refusal under the *usage* class is this page's field decision — a reading of `EX_USAGE`'s "the command was used incorrectly … or whatever" — not a sentence any cited document states.

**Sources checked (all fetched with curl on 2026-10-11; quoted sentence located in the page text, anchor id confirmed present in the raw HTML):**

| Claim | Source | Verification |
|-------|--------|--------------|
| Usage errors exit 2 in argparse | https://docs.python.org/3/library/argparse.html#argparse.ArgumentParser.error | `error(message)` "prints a usage message, including the message, to sys.stderr and terminates the program with a status code of 2"; anchor present |
| One-line refusal without the usage block | https://docs.python.org/3/library/argparse.html#argparse.ArgumentParser.exit | `exit(status=0, message=None)` "terminates the program, exiting with the specified status and, if given, it prints a message to sys.stderr before that"; anchor present |
| 2 for command-line errors, 1 for all other errors | https://docs.python.org/3/library/sys.html#sys.exit | "Unix programs generally use 2 for command line syntax errors and 1 for all other kinds of errors."; anchor present |
| An unhandled exception exits 1 in CPython | https://docs.python.org/3/c-api/interp-lifecycle.html#c.Py_RunMain | return value "0 if the interpreter exits normally (that is, without raising an exception), the exit status of an unhandled SystemExit, or 1 for any other unhandled exception"; anchor present |
| sysexits classes for the table | https://man.freebsd.org/cgi/man.cgi?query=sysexits&sektion=3 | EX_USAGE (64) "The command was used incorrectly, e.g., with the wrong number of arguments, a bad flag, a bad syntax in a parameter, or whatever."; EX_CONFIG (78) "Something was found in an unconfigured or misconfigured state."; EX_UNAVAILABLE (69) "A service is unavailable. This can occur if a support program or file does not exist. This can also be used as a catchall message when something you wanted to do does not work, but you do not know why."; EX_SOFTWARE (70) "An internal software error has been detected." |
| Exit codes map to failure modes; messaging to stderr; machine-readable output to stdout | https://clig.dev/ | lines 284–292 of the stripped page: "Return zero exit code on success, non-zero on failure."; "Map the non-zero exit codes to the most important failure modes."; "Send messaging to stderr."; "Anything that is machine readable should also go to stdout" |
| Connection strings and passwords are excluded from logs | https://cheatsheetseries.owasp.org/cheatsheets/Logging_Cheat_Sheet.html | "Data to exclude" list contains "Authentication passwords" and "Database connection strings", introduced by "should usually not be recorded directly in the logs, but instead should be removed, masked, sanitized, hashed, or encrypted" |
| A DSN carries `user[:password]@`; a `?password=` option is a second place | https://www.postgresql.org/docs/current/libpq-connect.html#LIBPQ-CONNSTRING-URIS | `postgresql://[userspec@][hostspec][/dbname][?paramspec]`, "where userspec is: user[:password]"; "Values that would normally appear in the hierarchical part of the URI can alternatively be given as named parameters."; anchor present |
| A colon-free connection string can carry a password | https://www.postgresql.org/docs/current/libpq-connect.html#LIBPQ-CONNSTRING-KEYWORD-VALUE | "In the keyword/value format, each parameter setting is in the form keyword = value, with space(s) between settings."; anchors `LIBPQ-CONNSTRING-KEYWORD-VALUE` and `LIBPQ-CONNECT-PASSWORD` present |
| Library precedent for hiding the password; query options printed as-is | https://docs.sqlalchemy.org/en/20/core/engines.html#sqlalchemy.engine.URL.render_as_string | `render_as_string(hide_password: bool = True)`, "hide_password – Defaults to True. The password is not shown in the string unless this is set to False."; "The method directly includes additional options."; anchor present |
| A runtime-checkable Protocol checks only attribute presence (edge case: stub method) | https://docs.python.org/3/library/typing.html#typing.runtime_checkable | the decorator's note: "@runtime_checkable will check only the presence of the required methods or attributes, not their type signatures or types."; anchor present |
| Field case | anhinga `t3-cli-outbox-drain-guard` plan D4/D5 (the queue rows' own `evidence` fields) | recorded as a field case in the page's Sources with generic wording; the project-specific values stay out of the bundled page |

**Not cited:** the harvested rows also cited https://microservices.io/patterns/data/transactional-outbox.html — it supports the outbox pattern itself, not the refusal contract, so it was left out.

**Confidence:** `verified` — every directive is backed by one of the official sources above, with the one interpretive step (usage class for a capability refusal) labelled as the field decision inside the page.

**Lint evidence (run in the checkout, `node scripts/…`):**

```
# untouched tree (baseline)
wiki-lint-prohibitions.js      → directives: 84, compliant: 84, violations: 0, info: 1
wiki-structure-checks.js wiki  → pages: 426, indexes: 13, findings: 0
# after the first draft
wiki-lint-prohibitions.js      → directives: 84, compliant: 84, violations: 0, info: 1
wiki-structure-checks.js wiki  → pages: 427, indexes: 13, findings: 0
# after the review fixes (final)
wiki-lint-prohibitions.js      → directives: 84, compliant: 84, violations: 0, info: 1
wiki-structure-checks.js wiki  → pages: 427, indexes: 13, findings: 0
```

Banned qualifiers (`usually|consider|might want to|generally|as appropriate`) outside `## Sources`: none; prohibition words outside `## Sources`: none; project literals (`docs/backends.md`, `cli.py`, `DriverError`, `SupportsDrain`, the `fake` backend name): none.

## Existing-layer check

Pages read: platforms-processes-tool-diagnostics-without-a-failing-exit-code, infrastructure-agent-orchestration-gate-evidence-exit-code-class, security-secrets-secrets-in-code, infrastructure-observability-logs-metrics-signals, databases-schema-design-migration-sql-without-a-database, platforms-processes-non-interactive-cli-invocation, security-agent-exposure-capability-flag-across-adapters, backend-common-change-impact-inserting-a-guard-before-an-existing-side-effect, backend-common-errors-diagnostics-from-a-shared-code-path, backend-common-errors-exception-handling, security-data-masking-verification, debugging-signals-reading-error-messages, backend-common-api-design-unenforced-declarations, backend-common-errors-async-failure-handling

**How the set was chosen:** `INDEX.md` → backend (errors), platforms (processes), security (secrets, data); then every page in `wiki/` matching `DSN|connection string` (1 file), `exit code|exit status|argparse|sysexits` (62 files, triaged by path), `stderr` (18), `capabilit|precondition|fail closed|unsupported backend` (41) — the pages above are the ones whose "When this applies" was opened after triage.

**Semantic dedupe (`wiki_search`, k=5, three queries):**
- trigger sentence → `platforms-toolchains-flag-availability-at-the-execution-site`, `infrastructure-ci-cd-review-bot-adopted-as-a-blocking-gate`, `infrastructure-agent-orchestration-gate-evidence-exit-code-class`, `testing-mocking-captured-call-arguments` (×2 chunks) — none describes a CLI refusing an incapable backend.
- DSN/scheme redaction → `platforms-tools-bsd-vs-gnu-cli`, `infrastructure-config-config-values-emitted-as-source-text`, `backend-common-integrations-robots-txt-and-source-selection`, `testing-quality-captured-log-message-assertions`, `infrastructure-containers-published-ports-bind-all-interfaces` — no match.
- exit-code class for a pre-work refusal → `infrastructure-agent-orchestration-gate-evidence-exit-code-class` (reading a runner's recorded codes, not choosing a CLI's own), `infrastructure-agent-orchestration-dispatching-after-a-completion-report`, `backend-common-change-impact-inserting-a-guard-before-an-existing-side-effect` (guard placement — adjacent, linked), `testing-mocking-captured-call-arguments`, `infrastructure-ci-cd-review-bot-adopted-as-a-blocking-gate` — no match.

**Overlaps and what was done:**

| Existing page | Relation | Action |
|---------------|----------|--------|
| `security-secrets-secrets-in-code` | Owns leak response and secret hygiene; has an edge case for an API key in a logged URL | **Linked both ways**, **one edge-case row added** ("an error message is about to echo a connection string the operator passed → scheme only; when host/db must appear, render a copy with the query string removed and the password hidden") with **three sources** appended to that page's frontmatter `sources:` and `## Sources` (OWASP Logging Cheat Sheet, SQLAlchemy `render_as_string`, libpq URI syntax — the last one sources the `user[:password]@` claim on that page). Its `last_verified` stays 2026-07-12: only the new row was verified. Its load-when row in `wiki/security/index.md` gained the new use case |
| `infrastructure-observability-logs-metrics-signals` | "Never log secrets… mask at the logger" | Linked both ways |
| `security-agent-exposure-capability-flag-across-adapters` | Refuse at spawn time when an adapter does not enforce a flag — same fail-closed arm, opposite direction (restriction vs capability) | Linked both ways |
| `backend-common-change-impact-inserting-a-guard-before-an-existing-side-effect` | Precondition guard must sit before the first mutation; test the negative path against the side effect | Linked both ways; cited inline in step 1 |
| `backend-common-errors-diagnostics-from-a-shared-code-path` | Sibling in the same category: wording of a rejection message reached from several callers | Linked both ways |
| `platforms-processes-tool-diagnostics-without-a-failing-exit-code` | Consumer side of exit code + stderr contracts | Linked both ways; cited inline in the `--json` edge case |
| `infrastructure-agent-orchestration-gate-evidence-exit-code-class` | Classifying a runner's recorded exit codes (127/126/124) | Read; not linked — different direction (reading codes vs. choosing them) |
| others read (`non-interactive-cli-invocation`, `exception-handling`, `masking-verification`, `reading-error-messages`, `unenforced-declarations`, `async-failure-handling`, `migration-sql-without-a-database`) | Triggers do not overlap | Read only |

**Conflicts:** none — no existing page prescribes echoing the full backend value or a different exit-code class.

## Open-PR check

`gh pr list --repo choiyounggi/dev-loop --state open --search "head:knowledge/"` → 6 heads: #265 `knowledge/choiyounggi-20261009-222812`, #266 `…-20261010-021455`, #268 `…-20261011-002014`, #269 `…-20261011-022522`, #270 `…-20261011-193253`, #271 `…-20261011-213648` (plus non-knowledge #267 `fix/autoflush-opt-in`, which touches no wiki page of this case). Each head was fetched and diffed: `git diff origin/main origin/<head> -- wiki/ INDEX.md`, then the added lines were grepped for `DSN|connection string|exit code|exit status|argparse|sysexits|password|redact|capabilit|precondition|unsupported backend|does not implement|scheme`.

| Head | Overlapping added lines | Overlap with this case? |
|------|-------------------------|-------------------------|
| #265 | grep / `git merge-tree` exit-status quotes (search-evidence page, gate page) | No — reading another tool's exit status, not designing a CLI's refusal |
| #266 | none | No |
| #268 | "check the exit code and stderr before…" in the fs-mock page | No — a test-side note |
| #269 | "Firefox does not implement the property" (canvas) | No |
| #270 | URL scheme/host allowlist fixtures (`host-disguise-fixtures-for-url-allowlists`) | No — "scheme" of an allowlisted URL, not a backend selector |
| #271 | none | No |

None of the six heads touches `wiki/backend/common/errors/`, `wiki/backend/index.md` (errors section), `wiki/security/secrets/secrets-in-code.md`, or the `secrets-in-code` row of `wiki/security/index.md`.

**Per-candidate verdict:**
- `810ec34bbd09d936` (refusal text / scheme derivation) — **new** (general kernel ingested into the new page; project residue → local layer)
- `391c39d1757da4ce` (exit code class) — **new** (general kernel ingested into the new page; project residue → local layer)
- `f1035fb812caa17f` (which project docs to edit) — **not ingested here**: no general kernel beyond "document the refusal where the command's existing refusals are documented"; local layer only (see below). Not a duplicate of any open PR.

## Routing decision

**Target:** `backend / errors` → new page `wiki/backend/common/errors/refusing-a-backend-without-the-needed-capability.md`; row added to `wiki/backend/index.md` under `### errors`; `log.md` entry appended. No new category, no `INDEX.md` change (the backend row already routes "errors").

**Why this category:** the decision is an error-contract decision in application code — what a rejection prints, where, with which status, and when — and the category already owns the sibling case "writing a rejection/validation message" (`diagnostics-from-a-shared-code-path`). Alternatives considered: `platforms/processes` owns *invoking and consuming* CLIs (non-interactive invocation, parsing `--json`, reading a tool's diagnostics), not authoring a CLI's own refusal; `security/secrets` owns the redaction aspect, which is one directive here rather than the trigger — handled by the both-ways link plus the one edge-case row.

**Layer test (wiki-ingest step 3):** after the review fixes the bundled page names no anhinga file, module, or convention; every example is a placeholder (`--backend <scheme>:<dsn>`, `Supports<Capability>`, `see <backends doc> §<capability table>`, "a test double, an in-memory store"). Everything that names anhinga's own files or rules is below.

## Local-layer candidates

All three claimed rows carry project-specific residue that would be wrong in another codebase. Target for all three (one task, one local page): project **anhinga** (`/Users/choeyeong-gi/Desktop/workspace/linkly/anhinga`, which has no `wiki-local/` yet) → `wiki-local/backend/errors/outbox-drain-guard-refusal.md` (id `local-backend-errors-outbox-drain-guard-refusal`, `reference_impl: [cli.py, docs/backends.md]`) — run wiki-ingest inside that project.

| Row | Project-specific content excluded from this PR |
|-----|-----------------------------------------------|
| `810ec34bbd09d936` | The exact literal `error: backend <scheme> does not implement the outbox drain contract (drain_outbox/ack_outbox) — see docs/backends.md §3` (U+2014), `<scheme>` via the `cli.py:876` idiom `args.backend.split(":", 1)[0]`, and the literal written inline in each of the three command bodies because rule R6 / the brief forbid a hunk outside those bodies |
| `391c39d1757da4ce` | rc 2 shared with the existing `fake` refusal and `_REJECTED`; rc 1 reserved for a run-time `DriverError`; rc 4 (`cli-surface.md` 종료 코드 "백엔드/차등 검사 에러") rejected because the outbox commands never used it and `docs/backends.md §8` (t1) already contracts rc 2 |
| `f1035fb812caa17f` | No edit to `docs/compatibility.md §5` (no rc table there; success rc 0 and unchanged subcommands/flags still hold) nor to the `## 종료 코드` table (its rc 2 row lists examples and omits the existing `fake` refusal too) |

## Independent review before commit

The change set touches 10 files, so it went through a read-only adversarial review (`feature-dev:code-reviewer`, no shell or write tools; it fetched all cited URLs itself) before any commit. First verdict: CHANGES REQUIRED, 12 findings; all applied, then lints re-run (table above) and the reviewer re-checked the result: **VERDICT: APPROVE** — all 12 resolved, no new blocker or should-fix, 7 wording nits (scheme-only consistency in step 2, the assertion's wording, the libpq named-parameter rule quoted, "or log line" in secrets-in-code and its trigger, "when the CLI documents one", a connector in the secrets-in-code OWASP source line, "no driver call" in the index row) — folded in before the final lint run and the commit.

| # | Finding | Applied as |
|---|---------|-----------|
| 1 | "A traceback's status is not a code the CLI documents" was unsafe — CPython exits 1 on an unhandled exception, the same code the argparse row documents for a mid-run failure | Instead-of row reworded; `Py_RunMain` cited |
| 2 | `render_as_string()` masks only `user:password@`; a `?password=` named parameter prints as-is | Step 2 and the secrets-in-code row now say "masks the `user:password@` slot only, includes query options as they are — render a copy with the query string removed"; libpq named-parameter sentence cited; libpq URI source added to secrets-in-code |
| 3 | `see docs/backends.md §3`, `fake`, `memory`, `SupportsDrain` leaked the originating repo | Replaced with placeholders (`see <backends doc> §<capability table>`, "a test double, an in-memory store", `Supports<Capability>`) |
| 4 | "the literal" had no referent; a bare-name fixture cannot distinguish echo-the-value from print-the-scheme | Step 2 defines one shared template; step 5 selects the fixture by `<scheme>:<dsn with an obviously fake password>` and asserts the tail is absent |
| 5 | Bare "`EX_SOFTWARE` or `EX_UNAVAILABLE`" left the reader to pick; `EX_USAGE` quote omitted "or whatever"; the usage-class mapping is a field decision | Deciding condition written into the cell; quotes completed; step 3 states that the sources define the codes and the mapping is the field decision |
| 6 | `parser.error()` prints the usage block too, breaking "exactly one line" | Row now says emit the one-line refusal with `parser.exit(2, line + "\n")`; `ArgumentParser.exit` cited |
| 7 | "machine-readable output goes to stdout only on success" was unsourced | Replaced by the consequence: a JSON consumer sees an empty stream and a non-zero status, not a partial document |
| 8 | Quote fidelity: OWASP "usually" elided, sys.exit "generally" dropped, typing quote under the wrong anchor | Quotes restored whole in `## Sources` (outside the directive-only qualifier check); the decorator's own note is quoted under `#typing.runtime_checkable` |
| 9 | "text before the first `:`" and `urlsplit().scheme` differ (`my_store:foo` → `''`); a colon-free `key=value` string can carry a password | Single rule `value.partition(":")[0]`; edge case prints a bare value only when it equals a registered name, else a fixed placeholder; libpq keyword/value format cited |
| 10 | No row for a CLI documenting only 0 and 1; "(1)" assumed the argparse row | Row added (2, documented in the same change); Instead-of row says "the mid-run code from step 3" |
| 11 | "It is in their own shell history" is false for a CI secret store | Edge case now: name where the value came from plus the scheme |
| 12 | Index row missing `--store` and the test use case; link style `→ [id]`; log line silent on `last_verified`; driver/backend terms undefined; secrets-in-code load-when row | All applied, including the optional `wiki/security/index.md` load-when extension |
