# Knowledge flush — 2 insight(s) (+12 plan-gap rows retired as local-layer)

Run id `20260928-191816-52426` (inherited from the auto-flush parent). Claimed 14 rows: 2 general
candidates from sessions `56be2ab9…` (linkly t175) and `e5d33b40…` (linkly-crew t7), and 12
`plan-gaps` rows tagged `t175-find-by-lookup-key`.

## Verified best-practice

### 1. Threading a new parameter through a call chain that crosses an executor (hash `157f9966ef1bfebb`)

**Claim.** When a new argument is threaded through Python helpers and one hop is a
`ThreadPoolExecutor.submit()`, enumerate every function on the path with a scope scan (names
referenced but not bound as parameter/local/module) before running tests, and read "the parallel
block produced no results" as a possible exception stored on a future rather than a logic error.

**Sources checked.**
- https://docs.python.org/3/library/concurrent.futures.html — `Future.result()`: "If the call raised an
  exception, this method will raise the same exception"; `Future.exception()` returns the stored
  exception or `None`; `Executor.map()`: the exception "will be raised when its value is retrieved from
  the iterator". Nothing surfaces at `submit()` time.
- https://docs.python.org/3/library/symtable.html — `Function.get_parameters()`, `Function.get_locals()`,
  `Symbol.is_referenced()`, `Symbol.is_free()`, `SymbolTable.get_children()` — the primitives the scan uses.

**How verified.** Reproduction 2026-09-28 (CPython 3.14.4, macOS) in `.claude/tmp/flush-repro/`
(deleted after capture): a worker helper referencing an unbound `keys` under a
`ThreadPoolExecutor(max_workers=4)` whose caller appends `result()` only when `exception()` is `None`
printed `results: []` with exit code 0 and no traceback; calling `result()` on one future raised
`NameError: name 'keys' is not defined`. The symtable scan printed exactly one line naming the broken
helper on the original file (known-bad) and zero lines on the fixed copy (known-good), which then
returned three results.

**Confidence:** verified.

### 2. A capability-restriction flag in a shared config that only some adapters enforce (hash `2b935d298d7e036e`)

**Claim.** When a restriction flag (`tool_use`, write confinement) lives in a config struct shared
by several adapters and only one implements it: census which adapters read it, make every
non-enforcing adapter refuse the flag with an explicit error before spawning, gate the flag at the
caller on adapter id, pass each adapter's native lock-down switch unconditionally, and test the
true arm per adapter.

**Sources checked.**
- https://cwe.mitre.org/data/definitions/636.html — CWE-636 "Not Failing Securely ('Failing Open')":
  falling "back to a state that is less secure … such as using the most permissive access control
  restrictions"; "causes administrators to have a false sense of security".
- https://cheatsheetseries.owasp.org/cheatsheets/Secure_Product_Design_Cheat_Sheet.html — Least
  Privilege, Fail Securely, Secure by Default, Defense-in-Depth (quoted in the page).
- https://github.com/badlogic/pi-mono/issues/555 — the closed request that added `--no-tools` to pi;
  confirmed on the installed CLI 2026-09-28: `pi --help` line 31 `--no-tools, -nt  Disable all tools by
  default (built-in and extension)`; the package CHANGELOG (fetched via `gh api`) records "`--no-tools`
  now disables all tools by default rather than only built-ins" (#2835, #3452).

**How verified.** Directive matched against CWE-636 and the OWASP principles (fail closed, least
privilege, secure defaults); the adapter-native switch the directive names was confirmed on the
installed binary and in the upstream changelog; the field incident (crew-run `role_harness_cfg` set
`tool_use` for all harnesses, `pi.rs` ignored it, RED test showed pi spawned with `tool_use=true`) is
recorded as the field evidence row.

**Confidence:** verified.

## Existing-layer check

Pages read: backend-python-concurrency-gil-and-concurrency-model, testing-quality-sequential-dispatch-assumption-under-concurrency, debugging-signals-stack-traces, debugging-concurrency-intermittent-failures, backend-common-change-impact-call-site-enumeration, backend-common-errors-async-failure-handling, backend-common-errors-exception-handling, testing-mocking-captured-call-arguments, security-authn-retiring-a-replaced-auth-gate, security-agent-exposure-authorization-scope-persistence, testing-quality-default-values-under-test, backend-common-integrations-consumer-required-fields, backend-common-api-design-unenforced-declarations

Also read: `INDEX.md`, `wiki/debugging/index.md`, `wiki/security/index.md`, `wiki/backend/index.md`,
`wiki/backend/python/index.md`, the agent-orchestration section of `wiki/infrastructure/index.md`.

`wiki_search` top-5 for candidate 1: testing-quality-sequential-dispatch-assumption-under-concurrency
(0.751), backend-python-concurrency-gil-and-concurrency-model (0.748),
backend-common-errors-async-failure-handling (0.738), backend-java-kotlin-coroutines-dispatchers-and-blocking
(×2, 0.738/0.735). For candidate 2: infrastructure-deploy-rollout-and-rollback (0.748),
platforms-filesystems-paths-case-and-line-endings (0.726), testing-mocking-captured-call-arguments (0.723),
infrastructure-agent-orchestration-semantic-conflicts-after-parallel-merge (0.722),
platforms-toolchains-compiler-sysroot-on-macos (0.721). Repo-wide grep for the candidates' keywords
(`ThreadPoolExecutor|NameError|as_completed|future.result`; `capability flag|least.privilege|deny.by.default|silently ignor|adapter`)
ran with a positive control (`asyncio` → 3 files) and every hit was opened.

**Overlaps and verdicts.**
- Candidate 1 — no page has the trigger. `backend-common-change-impact-call-site-enumeration` enumerates
  *callers* of a changed callee; this case is the *intermediate* hop that is a caller of nothing new, so
  it is adjacent, not a duplicate. `backend-common-errors-async-failure-handling` has the edge row
  "Future stored but never consumed"; the new case (a collection loop that records only OK futures) is
  a sibling shape — added as a new edge row there pointing at the new page, not merged, because the
  new page's directive (the pre-test scope scan) is a change-impact step that page does not own.
  `testing-quality-sequential-dispatch-assumption-under-concurrency` covers exact-count assertions
  under a parallelized loop — linked as related. No conflicting directive found.
- Candidate 2 — no page has the trigger. `backend-common-api-design-unenforced-declarations` is the
  nearest principle (recognized-but-unenforced declaration → accept-and-warn); the new page sharpens it
  for a security restriction shared across adapters (refuse, not warn) and is linked both ways with an
  edge row. `security-agent-exposure-authorization-scope-persistence` (force flag must not bypass the
  gate) and `security-authn-retiring-a-replaced-auth-gate` (deny default) are adjacent principles, not
  duplicates. `testing-mocking-captured-call-arguments` owns the "assert the spawn carries the
  confinement argument" test shape — linked one-way from the new page only, because open PR #223
  rewrites that file.

**Created:** `wiki/backend/common/change-impact/threading-a-parameter-through-executor-hops.md`,
`wiki/security/agent-exposure/capability-flag-across-adapters.md`.
**Amended (related link + one edge row each):** call-site-enumeration, async-failure-handling,
authorization-scope-persistence, unenforced-declarations. **Index rows:** `wiki/backend/index.md`
(change-impact), `wiki/security/index.md` (agent-exposure), `INDEX.md` security route line (the
backend route line is left untouched because open PR #225 rewrites it; the domain index row carries the
route). **Conflicts flagged:** none.

## Open-PR check

Open `knowledge/*` heads listed 2026-09-28 19:19 KST: #223 (`knowledge/choiyounggi-20260927-220735`),
#225 (`…-20260928-082803`), #226 (`…-092831`), #227 (`…-103056`), #228 (`…-134840`),
#229 (`…-145025`), #230 (`…-155239`). Each head fetched; `git diff origin/main origin/<head> -- wiki/`
grepped for both candidates' keywords (positive control: `gitignore` in #223 → 13 hits) and each
head's added/modified page list read.

| Candidate | Overlapping open head | Verdict |
|-----------|----------------------|---------|
| 1 (`157f9966ef1bfebb`) executor-hop parameter threading | none — no open head adds or edits a page about executors, futures, or parameter threading | **new** |
| 2 (`2b935d298d7e036e`) capability flag across adapters | none — #223 edits `security/agent-exposure/in-session-tool-exposure.md` and `testing/mocking/captured-call-arguments.md` (WebMCP tool surfaces), which is why those two files receive no back-link edit here | **new** |
| 12 `plan-gaps` rows (t175-find-by-lookup-key) | #230 retired 8 t175 plan-gaps as local-layer; these 12 are a different hash set and were still `pending` | **drop** (local-layer, see below) |

## Routing decision

| Insight | Layer | Target | Why this category |
|---------|-------|--------|-------------------|
| 1 | bundled wiki | `backend/common/change-impact/threading-a-parameter-through-executor-hops` | The directive is a pre-edit enumeration step for a parameter change (change-impact's remit, sibling of call-site-enumeration); the harvested `debugging` hint is served by the edge row and related link from `async-failure-handling`, the page an agent debugging "side effects silently never happen" already loads |
| 2 | bundled wiki | `security/agent-exposure/capability-flag-across-adapters` | The flag confines an LLM agent harness's executable tools — the agent-exposure category's subject (in-session-tool-exposure, authorization-scope-persistence); no new category needed |

No new category was created.

## Local-layer candidates

All 12 `plan-gaps` rows belong to the linkly compiler repository (`seagrass`); each directive names
`lower.py` line numbers, `RepositoryCall` nodes, `RFC-0052`, `RFC_ROUTES`, `LOOKUP_SUBJECT`, and
`_resolve_lookup_key`, and would be wrong in any other codebase. Excluded from this PR; run
`wiki-ingest` inside that project.

| Hash | Decision | wiki-local target (project: linkly / seagrass) |
|------|----------|-----------------------------------------------|
| `3d731255ec8e39e0` | Grammar surface for `by <ref>` on read/update/delete | `wiki-local/backend/compiler/by-ref-trailing-clause-grammar.md` |
| `d5c058373a04ea49` | Static ref-category split + order-blind admission rule | `wiki-local/backend/compiler/lookup-ref-category-admission.md` |
| `fc8c4977a204266d` | Derived/Password refusal wording for a `binding.field` lookup key | `wiki-local/backend/compiler/lookup-key-derived-password-refusal.md` |
| `e4ea213f6d9df04f` | Runtime key derivation | `wiki-local/backend/runtime/lookup-key-derivation.md` |
| `be4216dd01e49bae` | Runtime key derivation + trace/collector attrs (re-plan) | same target as `e4ea213f6d9df04f` (revision of the same decision) |
| `c207e65da923f1a0` | Persisting a `set` under the lookup key | `wiki-local/backend/runtime/persist-set-under-lookup-key.md` |
| `672134c2e2a71817` | `update`/`delete … by <ref>` execute key | `wiki-local/backend/runtime/update-delete-by-lookup-key.md` |
| `f5ba6ac93a2aedca` | Seed-key rule for `input.<field>` first reads | `wiki-local/backend/runtime/seed-key-rule-input-field.md` |
| `caf95ea8520a2931` | Seed-key rule + missing-field handling (re-plan) | same target as `f5ba6ac93a2aedca` (revision of the same decision) |
| `4bf5070e2b5086fd` | Bare-ref and bound-ref seeding scope (documented limitation) | `wiki-local/backend/runtime/bound-ref-seeding-scope.md` |
| `d4fa24759b67ba37` | RFC-0052 authoring shape and Updates chain | `wiki-local/qa/rfc-process/rfc-0052-updates-chain.md` |
| `4d689bc1190fc357` | Registries + docs: RFC_ROUTES, generated references, enforcement matrix | `wiki-local/qa/registries/rfc-registry-and-generated-reference-gates.md` |
