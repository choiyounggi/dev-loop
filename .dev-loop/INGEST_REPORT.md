# Knowledge flush — 10 candidate(s) → 6 new pages, 1 revise, 2 dropped

10 candidates entered the pipeline: 4 drained from `~/.dev-loop/queue/*.jsonl`,
and 6 derived in-session from work on an LLM-native compiler/runtime platform.
Two of them covered the same case and were merged into one page. Project-specific
names were generalized out of every page body.

## Verified best-practice

### 1. A non-Xcode compiler resolving the macOS SDK → `confidence: verified`

**Claim.** On macOS a compiler installed outside Xcode selects no default sysroot;
supply it with `-isysroot "$(xcrun --show-sdk-path)"` when you own the command
line, `SDKROOT` when you only own the environment, and `CPATH` / `LIBRARY_PATH`
when the driver still resolves the wrong root.

**Checked.**
- https://github.com/llvm/llvm-project/issues/137352 — confirms the driver selects
  no default sysroot on macOS as of LLVM/Clang 20.1.2, that the symptoms are
  `'stdio.h' file not found` and `ld: library 'System' not found`, and that the
  documented workaround is `export SDKROOT="$(xcrun --sdk macosx --show-sdk-path)"`
  or passing `-isysroot`.
- https://github.com/Homebrew/homebrew-core/issues/197277 — **corrected the
  candidate.** The queued insight named `-isysroot` as the single fix. This
  upstream issue states Homebrew clang "always passes the same value to `ld`'s
  `-syslibroot`" — the SDK it was built with — and ignores `SDKROOT`/`-isysroot`
  for the link step. The page therefore splits compile-time from link-time and
  routes the link case to `LIBRARY_PATH`/`-L` instead of presenting one flag as
  the answer.
- https://clang.llvm.org/docs/UsersManual.html — `SDKROOT` is honored as the
  default `isysroot`, with an explicit `-isysroot` taking precedence.
- Local reproduction 2026-08-05 (Homebrew LLVM, macOS): bare `clang probe.c`
  produced `warning: no such sysroot directory: '…/CommandLineTools/SDKs/MacOSX26.sdk'
  [-Wmissing-sysroot]` then `fatal error: 'stdio.h' file not found`; the same
  command with `-isysroot "$(xcrun --show-sdk-path)"` compiled and linked.

### 2. Feeding a tool's warnings back when it exits 0 → `confidence: verified`

**Claim.** Warnings are non-failures, so a wrapper branching only on the exit code
loses them; capture the diagnostic stream with `2>&1 >/dev/null` — in that order —
or promote warnings with the tool's own switch.

**Checked.**
- https://clang.llvm.org/docs/UsersManual.html — diagnostics carry levels
  (ignored / warning / error / fatal); warnings do not produce a non-zero exit
  status unless promoted with `-Werror`.
- https://www.gnu.org/software/bash/manual/bash.html#Redirections — "Redirections
  are processed in the order they appear, from left to right", which is exactly
  why the two spellings capture different streams. The candidate's claim about
  redirection order is correct as stated.
- https://pubs.opengroup.org/onlinepubs/9699919799/utilities/V3_chap02.html — a
  pipeline's exit status is that of its last command, supporting the "read the
  code before piping" directive.
- Local reproduction 2026-08-05: the same CLI produced rc=0 with three `warning:`
  lines, rc=0 with empty stderr, and rc=2 with an error — three outcomes
  distinguishable only by reading both the code and the stream.

### 3. Differential testing of two implementations → `confidence: verified`

**Claim.** When two paths implement one spec, fix which observable classes must
agree and which the contract permits to differ *before* writing the comparison,
and compare only the former.

**Checked.**
- https://arxiv.org/pdf/2102.07498 — differential testing "has been widely used
  for checking the consistency of two (or more) alternative implementations of a
  common specification".
- https://handwiki.org/wiki/Differential_testing — also called back-to-back
  testing; a second implementation is a stronger oracle than a crash check.
- https://arxiv.org/pdf/2212.01748 — experience report applying it where a
  reference implementation supplies the oracle a single implementation lacks.
- The *declare-permitted-differences-first* half is not in the literature under
  that name; it is carried as a dated field observation in Sources (four classes
  required to agree, five permitted to differ, timing deliberately excluded
  because comparing it would fail for contract-permitted reasons).

### 4. Artifact leakage from a suite → `confidence: verified`

**Claim.** Diagnose by counting leftovers per name prefix and matching the
distribution to call sites; fix with the runner's owned-temp API; then enforce the
convention with a static rule, watching it fail first.

**Checked.**
- https://pkg.go.dev/testing#T.TempDir — the directory "is automatically removed
  when the test and all its subtests complete", tying removal to test lifetime
  including failures.
- https://docs.pytest.org/en/stable/how-to/tmp_path.html — `tmp_path` plus
  `tmp_path_retention_count` / `tmp_path_retention_policy`. This **refined the
  candidate**: "keep nothing" is wrong when failures need inspecting, so the page
  routes that case to a retention policy the runner owns.
- https://eslint.org/docs/latest/extend/custom-rule-tutorial — AST-rule authoring,
  the mechanism behind "encode the convention as a static check".
- Field measurement carried in Sources: 998 leftovers under two prefixes
  (686 + 306), matching exactly the two of six `mkdtemp` call sites with no
  cleanup; post-fix full-suite delta 0, scratch area 72M → 3.3M.

### 5. Accepting a declaration the system does not enforce → `confidence: verified`

**Claim.** Split "unrecognized" from "recognized but unenforced" and diagnose each;
resolve declarations by closed-table lookup rather than inference; expose
strictness as a caller-selected level.

**Checked.**
- https://github.com/kubernetes/enhancements/blob/master/keps/sig-api-machinery/2885-server-side-unknown-field-validation/README.md
  — KEP-2885 defines exactly the three levels the page prescribes, selected per
  request via `?fieldValidation=`: `Strict` ("erroring on unknown fields"), `Warn`
  (returned as warnings in response headers), `Ignore`.
- https://kubernetes.io/blog/2023/04/24/openapi-v3-field-validation-ga/ — Server
  Side Field Validation reached GA in Kubernetes 1.27 for create/update/patch.
- https://json-schema.org/draft/2020-12/json-schema-validation —
  `additionalProperties` is the schema-level strictness control, an explicit
  decision rather than a parser default.
- The rolling-upgrade edge case (warn on the server, be strict in the client) is
  reasoned from the same KEP's client/server split and is stated as guidance, not
  attributed to a quotation.

### 6. Client-side rate limiting → `confidence: field-tested`

**Claim.** Throttle at the transport layer every request passes; count auth/token
issuance; stamp the clock immediately before the send; give the process's first
call a defined starting state; prefer the provider's headers to a modelled window.

**Checked.**
- https://docs.github.com/en/rest/using-the-rest-api/rate-limits-for-the-rest-api
  — exemptions are enumerated individually (`GET /rate_limit` "does not count
  against your primary rate limit"), so exemption is a named property rather than
  a default for meta requests.
- https://developer.okta.com/docs/reference/rate-limits/ — only specific public
  metadata endpoints (`/oauth2/v1/keys`, `/.well-known/*`) are listed as exempt,
  while `/oauth2/v1/authorize` is given as rate limited. This supports "a token
  endpoint is normally not exempt" **by absence from an exemption list**, which is
  weaker than a positive statement — hence `field-tested`, not `verified`.
- https://developers.openai.com/api/docs/guides/rate-limits — remaining/reset are
  returned as response headers for the client to consume.
- https://www.rfc-editor.org/rfc/rfc6585 — 429 and `Retry-After`.
- The originating incident is carried as a dated field observation with its log
  timeline (token POST 00.354 → issued 00.495 → rejected call 00.543 against a
  2/second limit, reproducing only on cache-cold days).

### 7. Doc table that is a projection of a code constant → merged, `verified`

**Claim.** When a document restates a code constant, declare the code canonical
*in the document* and assert the document against the imported constant.

**Checked.** No external source asserts this as a named practice. It is supported
by the host page's already-cited premise (JSON Schema `required` vs `enum`; ESLint
`RuleTester` must-fail inputs) plus a dated field observation. It was merged into
an already-`verified` page rather than published as a new page on a thin source
list.

No candidate was upgraded to `verified` without a citation or a reproduction. The
two dropped candidates were dropped as duplicates, not for lack of evidence.

## Existing-layer check

Routed via `INDEX.md`, then read each domain index and every page whose "load
when" line overlapped.

**Pages read:** `testing/index.md`, `testing/quality/harness-reverse-controls.md`,
`testing/quality/spec-artifact-checks.md`,
`testing/quality/behavior-not-implementation.md`,
`testing/data/test-data-and-isolation.md`, `platforms/index.md`,
`platforms/processes/non-interactive-cli-invocation.md`,
`platforms/toolchains/version-management.md`, `backend/index.md`,
`backend/common/reliability/timeouts-and-retries.md`,
`backend/common/integrations/externally-owned-defaults.md`,
`infrastructure/config/environment-config.md`,
`security/input/validation-at-trust-boundaries.md`.

| Candidate | Overlapping page | Resolution |
|---|---|---|
| Golden fixtures should be generated, not hand-maintained | `testing/quality/spec-artifact-checks` edge case "The artifact is generated rather than hand-written"; `behavior-not-implementation` #4 (when a snapshot is appropriate at all) | **Dropped** — both halves already present; no new directive |
| Harness needs a surviving no-op control; a partial working tree kills every case before the rule runs | `testing/quality/harness-reverse-controls` directives 1 and 4 — directive 4 already prescribes copying "the whole repository rather than the directory under test", the candidate's exact failure | **Dropped** — fully covered, including the mechanism |
| Doc table restating a code constant | `testing/quality/spec-artifact-checks` — same frame, and an adjacent edge case covers a canonical set living in *another document* | **Merged** as one edge-case row, one Instead-of row, and a Sources line; `last_verified` bumped, `related` extended |
| Temp/build artifacts left behind (2 candidates, same case) | `testing/data/test-data-and-isolation` row "Filesystem / temp files → create a fresh per-test temp directory and remove it in teardown" | **New page** — the existing row is the per-test instruction; the new page owns cross-suite diagnosis, the runner-API table, static enforcement, and the zero-delta assertion. Cross-linked |
| Tool warnings with exit 0 | `platforms/processes/non-interactive-cli-invocation` (stdin/prompt/timeout) | **New page** — no overlap on stream-vs-exit-code semantics; sibling in the same category, cross-linked |
| macOS SDK/sysroot | `platforms/toolchains/version-management` (pinning versions) | **New page** — pinning does not cover SDK resolution; the new page defers the pinning half to it |
| Unenforced declarations | `security/input/validation-at-trust-boundaries`; `infrastructure/config/environment-config` #4 | **New page** — both existing pages handle input that is *wrong*; this one handles input that is well-formed, accepted, then not acted on. Cross-linked to both |
| Client-side rate limiting | `backend/common/reliability/timeouts-and-retries`; `integrations/externally-owned-defaults` | **New page** — neither covers throttling one's own outbound rate or which of a client's requests count. Cross-linked to both |

**Conflicts flagged:** one. The queued LLVM candidate's directive named `-isysroot`
as *the* fix; upstream evidence shows it does not apply to the link step under
Homebrew LLVM. The page states both channels with the condition selecting each,
rather than propagating the candidate as written.

**Related-links added:** the new pages link to `version-management`,
`path-resolution`, `reading-error-messages`, `non-interactive-cli-invocation`,
`command-text-inspected-before-execution`, `test-data-and-isolation`,
`checks-that-cannot-pass`, `isolate-by-bisection`, `test-level-choice`,
`behavior-not-implementation`, `minimum-case-set`, `regression-scope`,
`validation-at-trust-boundaries`, `environment-config`, `error-responses`,
`acceptance-criteria`, `timeouts-and-retries`, `externally-owned-defaults`,
`intermittent-failures`, and `jwt-server-side`. `spec-artifact-checks` gained a
link to the new `unenforced-declarations`.

## Routing decision

| # | Target | New category? |
|---|--------|---------------|
| 1 | `platforms/toolchains/compiler-sysroot-on-macos.md` | No — `toolchains` exists |
| 2 | `platforms/processes/tool-diagnostics-without-a-failing-exit-code.md` | No — `processes` exists; `non-interactive-cli-invocation` owns invoking such a tool, this owns reading what it emitted |
| 3 | `testing/strategy/differential-testing.md` | No — `strategy` owns how to verify a change; this is a verification strategy for a migration/reimplementation rather than a level choice |
| 4 | `testing/data/artifact-leakage-from-a-suite.md` | No — `data` owns what a suite creates and must clean up; placed beside `test-data-and-isolation` |
| 5 | `backend/common/api-design/unenforced-declarations.md` | No — `api-design` owns the contract between a caller and the system; a config/DSL/manifest surface is such a contract even when it is not HTTP |
| 6 | `backend/common/integrations/client-side-rate-limiting.md` | No — `integrations` owns behavior toward a provider the repo does not control |
| 7 | `testing/quality/spec-artifact-checks.md` (revise) | No — merged into the existing page |

No new category was created. `api-design` was the closest fit for #5 rather than
opening a `declarative-input` category for a single page; if a second page on
declarative-surface design lands, revisit that decision.

Domain indexes updated: `wiki/platforms/index.md`, `wiki/testing/index.md`,
`wiki/backend/index.md`. Root `INDEX.md` route lines extended for backend, testing,
and platforms. `log.md` carries one `ingest`, one `revise`, and one `dedup` entry.
