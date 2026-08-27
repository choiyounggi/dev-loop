# Knowledge flush — 13 insight(s) ingested (21 claimed, 2 dropped, 6 released)

Queue drained under run id `20260827-125731-38371` (this session is the detached
`hooks/auto-flush.sh` run; its step-0 acquire resolved re-entrantly to
`already-owned`, not to a competing holder). 21 rows were claimed; 13 are
ingested below, 2 are retired as out-of-layer, and 6 are released back to
`pending` for a later flush because each needs its own page rather than a row,
and rushing six more pages in one pass would have lowered the bar on all of them.

## Verified best-practice

Every external claim below was live-fetched this session and quoted in the page's
`Sources` block. Field evidence carries the repo, date, and the measured numbers.

| # | Claim | Sources checked | How verified | Confidence |
|---|-------|-----------------|--------------|------------|
| 1 | `now()` is `transaction_timestamp()` (fixed at transaction start) while `clock_timestamp()` "changes even within a single SQL statement"; `RETURNING` yields computed defaults "without needing a separate database query" | postgresql.org `functions-datetime`, `dml-returning`, `transaction-iso` | Fetched; both key sentences quoted verbatim into the page | verified |
| 2 | A boundary recomputed in a follow-up step is a *second, later* `now`, widening a `<= boundary` set | Field: `rtb-unified` `packages/orpc/src/routers/batch.ts` — codifies "one `now` per decision" and passes `now` into the boundary helper; its result type omits the boundary, which is the shape that invites recomputation | Read the invariant and the signature in the cited file | field-tested |
| 3 | Prettier `--check` prints "All matched files use Prettier code style!" and exits 0 **even when the match set is empty**; `--ignore-unknown` skips unknown files; `--no-error-on-unmatched-pattern` suppresses the unmatched error | prettier.io CLI docs | Fetched; confirms exit 0 + the success sentence, and that the unmatched-pattern error is the only signal and is suppressible | verified |
| 4 | zsh does not word-split unquoted parameter expansions by default, so `cmd $FILES` arrives as **one** operand | zsh FAQ ch. 3 (`SH_WORD_SPLIT`) | Fetched; quoted ("By default, zsh does not have that behaviour: the variable remains intact") | verified |
| 5 | Reproduction of 3+4 together: the gate is green while examining nothing | Field 2026-08-24 (`rtb-unified`, zsh): `npx prettier --check $FILES` emitted `[error] No files matching the pattern were found: …` **together with** the success sentence; a probe under `.claude/tmp/` passed because Prettier's default ignores include `.gitignore`, while the same probe at `packages/orpc/src/zz-fmt-probe.ts` produced `[warn]` | Both directions observed | verified |
| 6 | TypeScript applies excess-property/contextual typing to fresh object literals, so a value of a type can be constructed with the type's name absent from the text | typescriptlang.org handbook, *Object Types* | Fetched; confirmed the check follows from the contextual type, not from a written annotation | verified |
| 7 | `tsc`'s program is `files` ∪ `include` ∪ transitive imports; `exclude` "only changes which files are included as a result of the `include` setting" and does not stop an imported file entering the program | typescriptlang.org TSConfig `#include`, `#exclude` | Fetched; the `exclude` sentence quoted (it sharpens the rule to "in the program", not "in `include`") | verified |
| 8 | Consequence of 6+7 measured | Field 2026-08-24/25 (`rtb-unified`): `grep "DealViewer"` reported 3 construction sites, actual 8 — the missed set included production wiring `routers/deal.ts:38`; `ContractScopeActor` 7→~22. Separately, `packages/orpc/tsconfig.json` `include: ["src/**/*"]` produced 3 production + 13 api-test errors and **zero** for `__tests__/routers/deal.test.ts`, whose 6 sites appeared only as 6 failing tests | Counts recorded from the cited runs | verified |
| 9 | cgroup v2: `memory.peak` is max usage since creation/reset; at `memory.max` "the OOM killer is invoked in the cgroup"; in `memory.events`, `max` counts times usage "was about to go over the max boundary" — **distinct** from `oom_kill` | docs.kernel.org cgroup-v2 admin guide | Fetched; all four quoted. This corrected the candidate, which had read a non-zero `max` as a kill; the page now states the distinction explicitly | verified |
| 10 | An `exec`'d process joins the container's cgroup and is invisible to the application's own semaphore | kubernetes.io `manage-resources-containers`, `assign-memory-resource`, `kubectl exec` reference + field 2026-08-26 (review-bot pod, `limits.memory: 3Gi`): `memory.current` 2.54 GiB, `memory.peak` 3.0 GiB (at the limit), `memory.events: max 5`, while `maxConcurrentAgents: 20` reported free slots | Docs fetched; pod numbers from the cited measurement | verified |
| 11 | Basename-keyed mutation backups collide across directories and restore cross-writes; an untracked file's `git diff` is empty whether restored or destroyed | Field 2026-08-21 (`rtb-unified`, NEWRTB-2936): restore wrote `schemas/deal.ts` into `routers/deal.ts` → `Cannot find module './common.js'`, `grep -c dealRouter` = 0; **both files were 154 lines**, so a line-count check passed; after re-keying, M9/M10 flipped SURVIVED→KILLED. Plus stryker mutant-states / pitest for the verdict vocabulary | Reproduced end to end in the cited run | field-tested |
| 12 | A negative assertion is vacuous when the fixture never supplies the triggering input | Field 2026-08-25 (`rtb-unified`): with `staleQueuedJobIds: []` the code early-returned; the widening the assertion claimed to catch survived 116/116 green | Mutation applied and observed | field-tested |
| 13 | A body-level (non-inline) review finding cites no file, so rebutting from an assumed file rejects real defects | Field 2026-08-19 (PR #327 r16): quote matched `report.py:393/416/425`, not the assumed `fill_plan.py:307` — sibling modules, one already fixed | Grep resolved the quote to the real site | field-tested |
| 14 | Unifying two duplicate allowlists defaults to the union and silently widens each side | Field 2026-08-25 (`rtb-unified` PR #965): folding `DISPLAYABLE_ERROR_CODES` into `USER_FACING_ERROR_CODES` would have added `UNAUTHORIZED` + `VALIDATION_ERROR`, exposing raw server messages as inline UI errors; caught only by computing the difference first | Difference computed before the merge | field-tested |

Not upgraded: nothing was marked `verified` on field evidence alone. Two pages
carry `confidence: field-tested` (`mutation-harness-file-custody`,
plus the pre-existing `evaluating-review-feedback`), and no candidate was
recorded as `verified` without a fetched primary source.

## Existing-layer check

Method: routed via `INDEX.md` → domain `index.md`; then built a full id+title
index of all 265 pre-existing pages and probed it with concept greps
(`clock_timestamp|clock skew`, `changed[- ]files|--ignore-unknown`, `tsconfig`,
`contextual typ|excess property`, `set difference|allowlist`, `cgroup`,
`basename|backup.*restore`, `2>&1`, `delta|baseline`) before deciding new vs merge.

Pages read: testing-quality-source-text-wiring-assertions, testing-quality-tests-that-cannot-fail, backend-common-change-impact-call-site-enumeration, backend-common-change-impact-widening-a-closed-value-table, qa-process-evaluating-review-feedback, infrastructure-containers-host-cgroup-visibility, testing-quality-behavior-not-implementation

Findings:

- **Zero coverage** (→ new pages): changed-files-only gates, tsconfig/contextual
  typing, allowlist set-difference, app-clock-vs-DB-timestamp, exec-into-a-running-container.
  The concept greps returned no hits for these; the clock hits were incidental
  (offline sync, token handling) and none compared an app clock to a DB column.
- **Already covered — one candidate all but retired.** The comment-stripping
  insight is `source-text-wiring-assertions` step 2 verbatim ("Make the
  assertion's subject the file with comments removed"), and its false-RED and
  negative/count false-GREEN shapes are already edge rows. Only the *empty-slice*
  consequence was new, so that alone was merged.
- **Line-cap conflict handled without breaking the invariant.**
  `source-text-wiring-assertions` sits at exactly **120** body lines (the
  documented cap). Rather than add a row and violate maintenance invariant 5, the
  new nuance and the new field evidence were merged **in place** into an existing
  edge row and an existing source bullet. Body count re-measured after editing:
  still 120.
- **No conflicts found.** Nothing ingested contradicts an existing directive.
  The one correction made was to a *candidate*, not to the wiki (item 9: the
  `memory.events` `max` counter is approaches-to-limit, not kills).
- **Related links added both ways**: `tests-that-cannot-fail` ↔
  `mutation-harness-file-custody`; `widening-a-closed-value-table` ↔
  `compiler-as-call-site-inventory` (+ `errors-diagnostics-from-a-shared-code-path`);
  `host-cgroup-visibility` → `exec-added-processes-and-the-memory-budget`
  (from its existing self-monitoring row).
- **Indexes/log updated**: 4 domain indexes (+5 "load when" rows), `log.md`
  appended. Root `INDEX.md` unchanged — no new domain.

Gates run (the exact CI commands from `.github/workflows/test.yml`):
`node scripts/wiki-structure-checks.js wiki` → **pages: 270, indexes: 13,
findings: 0**; `node scripts/wiki-lint-prohibitions.js wiki` → **directives 72,
compliant 72, violations 0** (the 1 `info` is pre-existing in
`config/keys-ahead-of-their-consumer.md`, untouched); `bash scripts/check-versions.sh`
→ `ok: dev-loop 1.11.2`. The `bats tests/` job was **not** run — bats is not
installed on this machine, and this change touches only wiki markdown (no
scripts or hooks), so that suite's subject is unchanged.

## Open-PR check

`gh pr list --repo choiyounggi/dev-loop --state open --search "head:knowledge/"`
returned **no open PRs**, and a second unfiltered `gh pr list --state open`
returned none either — the repository has zero open PRs at flush time. There
were therefore no in-flight sibling branches to diff against, and no
`git fetch origin <head>` / `git diff origin/main origin/<head> -- wiki/`
comparisons to run.

Per-candidate verdict: **all 21 = `new`.** No `fold`, no `drop-as-pending-duplicate`.
(The 2 drops recorded below are out-of-layer drops, not pending-duplicate drops.)

## Routing decision

**New pages (5)**

| Page | Domain/category | From | Why not an existing page |
|------|-----------------|------|--------------------------|
| `application-clock-vs-database-timestamps` | databases / transactions | `2b27d15d` + `bea92fdd` | No page compares an app clock to a DB column. `transactions` chosen over `schema-design` because the decisive content is transaction-time semantics (`now()` = transaction start ⇒ stamp order ≠ commit order) and the fix is a lock/isolation choice |
| `changed-files-only-gates` | infrastructure / ci-cd | `ff041061` + `4b9af3a0` | Zero grep hits. Both candidates are the same defect (a gate green with an empty subject) from two directions, so they became one page rather than two |
| `compiler-as-call-site-inventory` | backend / common / change-impact | `702dcf4e` + `94d55f2f` | `call-site-enumeration` is the sibling case (callers of a changed signature, Python positional-vs-keyword) and is at 80 body lines; the TS mechanism is *constructors of a type* with its own workflow, so per "one case per page" it is a separate page, cross-linked |
| `mutation-harness-file-custody` | testing / quality | `6a9de235` + `41fa1c87` | `harness-reverse-controls` covers scoring a harness; nothing covers the harness's custody of the tree. Both candidates are that one case (keying, and the read window) |
| `exec-added-processes-and-the-memory-budget` | infrastructure / containers | `7b9e8788` | `host-cgroup-visibility` is cross-pod read mechanics and explicitly routes self-monitoring elsewhere; `resource-limits-and-probes` is manifest authoring. This is a runtime preflight before adding load |

No new category was created — all five landed in existing categories.

**Merged into existing pages (5 candidates)**

| Candidate | Merged into | Shape |
|-----------|-------------|-------|
| `91ef5d53` | `testing-quality-tests-that-cannot-fail` | +1 never-fails row, +1 Instead-of row, +1 source |
| `f189f423` | `testing-quality-source-text-wiring-assertions` | In-place extension of 1 edge row + 1 source bullet (page at the 120-line cap) |
| `bb6d8539` | `backend-common-change-impact-widening-a-closed-value-table` | +Do-this 6 & 7 (incl. a set-difference ruling table), +1 Instead-of row, +1 source |
| `60a817ee` | `qa-process-evaluating-review-feedback` | +2 edge rows, +1 Instead-of row, +1 source |
| `7b9e8788` | `infrastructure-containers-host-cgroup-visibility` | Cross-link from its self-monitoring row to the new page |

**Dropped — out of layer (2, retired)**

- `094dedf3` — a Figma MCP `inspect_node` → `get_dev_ready` children-fetch
  workaround. The server is a private, org-internal MCP plugin; the behavior is
  not publicly verifiable and the directive does not transfer to any other reader.
- `e165a365` — an `/rtb:review` remote-fallback runbook naming
  `~/.claude/tools/rtb-remote-review.sh` and an internal pod. The transferable
  kernel ("a two-provider review gate degraded to one provider is not a passed
  gate") is already the subject of `qa-process-llm-review-pipelines`; what remains
  is machine-specific paths.

**Released back to `pending` (6)** — each needs its own page, not a row, and is
better served by a dedicated pass than by being appended here:
`81dc1f98` (naming the carrier field/type when a plan says "wire A to B"),
`b9ae304a` (`VAR="$(cmd 2>&1)"` mixing stderr into a value used as a path),
`fdd0b3c6` (monitor markers anchored at line start; delta rather than absolute
state; first cycle records a baseline),
`c2adb2be` (positional-order assertions on rendered SQL predicates),
`815e8cb9` (grep only *active* `DATABASE_URL` assignments, and confirm which
dotenv file the tool loads, before a destructive DB command),
`f1146adb` (CI ticket-key extraction scoped by changed-file intersection rather
than by mention).

## Review notes

- PR-only, as required: no merge, no push to `main`.
- Commit is under the contributor's own ambient git identity
  (`최영기 <dch0202@rsquare.co.kr>`, gh `dch0202-rsquare`); no assistant identity
  and no `Co-Authored-By` trailer. The branch uses the gh login because
  sanitizing the Korean `user.name` to ASCII yields an empty string, which the
  skill's snippet would have turned into `anon` — that would have defeated the
  attribution the branch name exists for.
- Scope purity: only `wiki/**`, four domain indexes, `log.md`, and this report.
  Two untracked leftovers from earlier flushes
  (`.dev-loop/CROSSCHECK_FINDINGS.md`, `.dev-loop/fold-note-73.md`) were left
  untouched and unstaged.
