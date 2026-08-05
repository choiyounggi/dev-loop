# Knowledge flush — 5 insight(s)

Drained 5 pending rows from `~/.dev-loop/queue` in two rounds (session files: qa-t1-inventory-order ×1, qa-t4-rate-notify ×2, then qa-t2-payment-refund ×2 that were harvested while the first round was in flight). Result: **5 new pages (qa ×4, security ×1), 7 reverse related-links, 0 dropped, all `confidence: verified`.** One candidate's stated evidence wording was corrected during verification (I-3), and one queue domain hint was re-routed (I-5: `debugging` → `qa`).

| # | Insight | Target page | Confidence |
|---|---------|-------------|-----------|
| 1 | `git status --porcelain` needs `-uall` before path-filtering for scope purity | `wiki/qa/process/scope-purity-checks.md` (new) | verified |
| 2 | Run a control pair before trusting a name-based value-override matrix | `wiki/qa/exploratory/override-control-pairs.md` (new) | verified |
| 3 | Execute every guard-true path once when static stages don't resolve references | `wiki/qa/exploratory/guard-true-path-coverage.md` (new) | verified |
| 4 | Verify masking per output channel with a planted secret + unmasked control field | `wiki/security/data/masking-verification.md` (new) | verified |
| 5 | Count stacked declarations in the lowered IR before trusting runtime | `wiki/qa/exploratory/lowered-declaration-survival.md` (new) | verified |

## Verified best-practice

### 1 — Scope-purity checks over `git status` output need `-uall`

**Claim as queued:** default porcelain collapses an entirely-untracked directory to one `?? qa/` line, so a per-file path filter (`^?? qa/cases/...`) mis-matches and the purity gate reports a false violation; `-uall` expands to per-file lines.

**Verified two ways:**
- **Official docs** — [git-status](https://git-scm.com/docs/git-status): mode `normal` "Show untracked files and directories", mode `all` "Also show individual files in untracked directories"; the default equals `normal` and is user-configurable via `status.showUntrackedFiles`. The config point yields an addition the candidate lacked: a checkout with `showUntrackedFiles=no` hides untracked files entirely, turning the same gate into a **false pass** — so scripts must pass `-uall` explicitly, never rely on the ambient default. Also doc-verified for the page's edge cases: porcelain v1 rename lines are `R <orig-path> -> <path>` (two paths, one line), special-character paths are C-string-quoted unless `-z`, and ignored files are omitted unless `--ignored=matching`.
- **Local reproduction** (git 2.50.1 Apple Git-155, scratch repo, 2026-08-05): default porcelain printed exactly `?? qa/` and the per-file filter left it as a "violation" line (grep exit 0); `-uall` printed the three real file paths and the filter passed (grep exit 1). Matches the t1 session evidence (14 files proven in scope only after `-uall`).

### 2 — A control pair before trusting a value-override matrix

**Claim as queued:** when a CLI takes name-based runtime value injection (`--field key=value`) and ignores unknown keys, run a control pair that flips an observable before trusting any value matrix; uniform output across variants means "key silently ignored", not "behavior stable".

**Verified:**
- **Session reproduction with archived raw output** (lnpl 0.2.0, qa-t4-rate-notify, `qa/cases/rate-notify/evidence/05-modeB.md` + `evidence/raw/modeB-b*.txt`): five runs with bare names (`--field value=150/50/100...`) produced effectively identical step traces — guarded create step never fired, until-loop always hit its 16-round cap — with **exit 0 and zero warnings**. The tool's own help documents the policy: "Fields the workflow does not compare on are ignored; omitted ones default to 0." Switching to the canonical dotted name (`--field measurement.value=150`) flipped the guarded step, proving the lever, after which the matrix produced differentiated, meaningful rows.
- **Mechanism prevalence** — [pydantic models docs](https://pydantic.dev/docs/validation/latest/concepts/models/): "By default, Pydantic models won't error when you provide extra data, and these values will simply be ignored"; `ConfigDict(extra=...)` = `ignore` (default) / `allow` / `forbid`. This grounds the page's directive to prefer strict/forbid modes for measurement runs.
- **Citation dropped, not approximated:** I attempted to add Kohavi's A/A-test literature as a third source; the candidate URL (kdd.org PDF) could not be content-verified by fetch, so it is **not cited**. The in-repo page [testing-quality-harness-reverse-controls] (mutation-testing-sourced) carries the same "prove the instrument discriminates" principle and is linked instead.

### 3 — Guard-true path coverage when static stages skip reference resolution

**Claim as queued:** steps behind guards must be executed with the guard true at least once, because a pipeline whose compile/validation doesn't resolve cross-node references defers those errors to runtime, and guard-false runs return rc=0 forever.

**Verified:**
- **Session reproduction** (qa-t4-rate-notify, `qa/cases/rate-notify/evidence/04-modeA.md`): an `emit` referencing an undeclared event passed compile (0 errors) and IR validation (PASS); 6 of 7 runtime runs failed at the emit step with "EventEmit references undeclared event 'event.notification'"; the single run where a presence guard skipped emit exited 0. **Correction to the queue row:** the failure text is the above, not "RunError" — the page and this report quote the actual error. The same evidence file's bidirectional guard table (guard.1/2/3, true and false runs each, all three discriminating) is the template for the page's contrast-table directive, and its guard.3 zero-round observation (0-iteration `until` absent from the skipped list) became the "assert on executed steps, not skip markers" directive.
- **External grounding** — [ISTQB glossary, branch coverage](https://istqb-glossary.page/branch-coverage/): "The percentage of branches that have been exercised by a test suite. 100% branch coverage implies both 100% decision coverage and 100% statement coverage." The page applies this at whole-program QA level: a guard is a branch; N green runs down one side accumulate no evidence about the other.

### 4 — Masking verified per output channel, with a negative control

**Claim as queued:** masking is implemented per-channel, so a check that passes on one channel proves presence, not enforcement — enumerate every output channel, grep the raw secret in each, and pair with a control field that must appear unmasked.

**Verified by my own fresh reproduction** (the t2 worktree that produced the candidate was blocked by the session-isolation guardrail, so I rebuilt the case from scratch in my own worktree, lnpl 0.2.0, 2026-08-05): a `Password`-typed field fed the planted value `4111111111111111` through a run with `--json`. One output document contained **the raw card number at `.result.bindings.account.cardSecret` and `***` at `.trace.logs[0].payload.cardSecret`**; the unmasked control field `label` appeared in both channels (proving both channels were captured). This independently confirms the queued evidence, including its sharpest claim — the platform's own differential check reported "PASS 4/4 masking" because it compares only the masked-clean channels.

- **External grounding** — [OWASP Logging Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Logging_Cheat_Sheet.html): "Authentication passwords" and "Bank account or payment card holder data" are data to be "removed, masked, sanitized, hashed, or encrypted" rather than logged — masking framed as a *logging-layer* responsibility, which is exactly why the result-payload channel stays uncovered.

### 5 — Stacked declarations counted in the lowered artifact

**Claim as queued:** a compiler/DSL can silently keep only the last of consecutive declarations with exit 0 and no diagnostic — inspect the lowered IR/AST and count that every declared item survived before trusting runtime.

**Verified by my own fresh reproduction** (same guardrail note as I-4; rebuilt from scratch, lnpl 0.2.0, 2026-08-05): a workflow with `when approval.amount > 100` directly followed by `when approval.amount < 0` compiled with **rc=0 and zero diagnostics**; both the Semantic IR JSON (`lnpl compile`) and the lowered MLIR contained **exactly one Guard node — `wf.approve.refund.guard.1`, carrying the second guard's condition under the first guard's id**. That id-reuse detail (absent from the queue row) became page directive 3: count by condition content, not by node-id presence. The runtime consequence (amounts `0` and `-1` approved past the dropped guard) is carried from the originating session as described context.

## Existing-layer check

**Read:** root `INDEX.md`; `wiki/qa/index.md` (all categories); `wiki/qa/exploratory/exploratory-sessions.md` (full); `wiki/testing/index.md`; `wiki/testing/quality/harness-reverse-controls.md`; `wiki/testing/quality/minimum-case-set.md` (full); `wiki/testing/quality/checks-that-cannot-pass.md` (trigger sections); `wiki/security/index.md`; `wiki/security/data/pii-handling.md`; `wiki/debugging/index.md`; plus repo-wide greps for `porcelain|untracked|-uall`, `control`, `branch coverage|guard|unknown key`, `mask`.

**Overlaps found, all resolved as adjacency (cross-link), not duplication:**
- I-1 vs [testing-quality-checks-that-cannot-pass] — that page validates a check against known-good input; I-1 is a specific gate whose false verdict comes from git's output mode, and its directive 3 routes to that page for the both-ways control. Linked both ways. No existing page mentions porcelain/untracked mechanics (grep confirmed).
- I-2 vs [testing-quality-harness-reverse-controls] — same principle ("uniform verdict is a property of the instrument; run a control"), different situation: that page is about citing a *scoring harness's* verdict, I-2 about a *measurement matrix* through value injection. Kept separate, linked both ways.
- I-3 vs [testing-quality-minimum-case-set] — that page selects cases for automated tests of a function; I-3 covers runtime QA of guarded whole-program paths. Linked both ways.
- I-4 vs [security-data-pii-handling] — that page *designs* PII handling (mask at the logger layer, one central filter); I-4 *verifies* that such masking actually holds per channel. Complementary, linked both ways; I-4's error-report edge row routes to pii-handling's scrub-hook row.
- I-5 vs I-3 — siblings: I-5 counts declarations that survived lowering; I-3 executes the survivors. Cross-linked; also linked to I-2 (all three are probing techniques from the same QA campaign family).

**Open-PR overlap scan (13 open `dev-loop:knowledge` PRs by title, closest by body: #32, #34, #24, #23):** none covers these five. Flagged as *cousins, not duplicates*: PR #32 `infrastructure/config/keys-ahead-of-their-consumer` and PR #34 `backend/common/api-design/unenforced-declarations` share the "accepted but not acted on" mechanism family — #34's page is the *designer's* side (closed-table lookup, strictness levels, K8s KEP-2885) while I-2/I-5 are the *consumer/QA* side (prove your lever connects; count survivors); no content conflict, and a follow-up `related:` link between them is worth adding after whichever merges second. PR #34's `testing/strategy/differential-testing` is adjacent to I-4's "ask which channels the differential check compares". PR #24/#22 completion-predicate pages share I-2's control-run spirit; PR #23 `guard-shape-vs-consequence` concerns test-artifact guards, unrelated to runtime `when`/`until` guards.

**Conflicts flagged:** none — no existing directive contradicts any of the five.

## Routing decision

- **I-1 → `qa/process/scope-purity-checks`.** Queue hint `qa` confirmed: the artifact is a release/session gate ("did this run stay in its lane"), owned by qa/process alongside release-gates. Not `platforms` (no OS variance) and not `testing` (nothing here writes test code); the git mechanics are the page's evidence, not its owner.
- **I-2 → `qa/exploratory/override-control-pairs`.** Queue hint `qa` confirmed: probing a live system during exploratory QA. The alternative home — `testing/quality` next to harness-reverse-controls — was rejected because that category governs authoring/citing automated checks, while this governs how to *measure* a system by hand; the shared principle is carried by the two-way `related:` link.
- **I-3 → `qa/exploratory/guard-true-path-coverage`.** Same category as I-2 (same probing activity, sibling pages).
- **I-4 → `security/data/masking-verification`.** Queue hint `security` confirmed: the subject is a security control's enforcement, placed beside `pii-handling` (which owns the design side). `qa` was rejected — the channel table and planted-secret method are specific to sensitive-data controls, and security/data readers are the ones about to claim "masking works".
- **I-5 → `qa/exploratory/lowered-declaration-survival`.** **Queue hint `debugging` overridden**: debugging's charter is "diagnosing a failure — finding what is wrong and why", but this directive fires *before* any failure is observed (pre-trust verification during QA); its natural siblings are I-2/I-3 in `qa/exploratory`. If it had been filed as "why did runtime approve amount 0?", the debugging methodology pages would route the investigation — the lesson worth persisting is the preventive count.
- **No new categories.** `qa/exploratory` grows 1→4 pages (its charter — manual/exploratory probing techniques — covers all three newcomers); `security/data` grows 1→2.
- **Plumbing:** `wiki/qa/index.md` +4 rows, `wiki/security/index.md` +1 row; reverse `related:` on `checks-that-cannot-pass`, `harness-reverse-controls`, `minimum-case-set`, `exploratory-sessions`, `pii-handling`, plus cross-links among the three exploratory siblings; `log.md` +2 ingest entries.

**Invariants (checked mechanically):** body lines 53/53/56/56/52 (≤120) · id matches path 5/5 · all `related:` ids resolve · 0 banned vague qualifiers (one "usually" inside an OWASP quotation was caught and the quote tightened) · every Instead-of row pairs prohibition with replacement · new pages listed in domain index 5/5.
