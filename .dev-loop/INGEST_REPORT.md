# Knowledge flush — 9 insight(s), two passes on one branch

Queue drained: 8 pending rows across 4 session files (pass 1) plus 3 further rows
(pass 2). Outcome: **3 new pages, 3 merges into existing pages, 3 drops**
(2 already-merged duplicates, 1 out of scope).

**Why one branch carries two passes.** Pass 1 (2026-08-06 18:30) completed its
ingest and pushed this branch, but `gh` could not open the PR — the stored token
was invalid at the time (`gh api user` → 401), so the branch was left on the
remote with no PR. Pass 2 (2026-08-06 20:45) found the token working again and
found that 2 of its 3 queued candidates were **already carried by this branch**
(as C6 and C7 below). Per the flush skill's open-PR rule, an overlapping
in-flight head is folded into rather than duplicated — so pass 2 added its one
unique insight (C9) to this branch instead of opening a second PR against the
same pages. One PR, one review pass, no duplicate ingestion.

Pass 2 independently re-verified C6 and C7 before folding rather than trusting
the earlier pass — see their sections.

## Verified best-practice

### C1 — an explicit error refutes a silent-suppression hypothesis → `verified`
**Claim.** When one suspect is a mechanism designed to be invisible to the affected
party (silent moderation, shadowban, silent drop), receiving an explicit refusal
falsifies it; and a query returning zero results cannot separate "removed" from
"never accepted".
**Checked.** https://news.ycombinator.com/newsfaq.html — a killed post is `[dead]` and
"aren't displayed by default"; the FAQ documents **no** notification to the author,
which is the property the directive rests on. The generalized form (evidence must be
diagnostic between competing hypotheses; run a positive control to prove the query
path works) is already the frame of the page it was merged into, whose own sources are
debuggingbook and the Google SRE troubleshooting chapter.
**Confidence: verified** — sourced for the mechanism, plus a field application
(control query returning 8,462 hits proved the endpoint healthy, so the zero-hit
result carried no information).

### C2 — outline instead of draft when a community forbids generated text → dropped
Substantiated (the platform's guideline is explicit, and the field evidence is a
comment marked `dead=true` while a sibling item from the same account survived, i.e.
per-item filtering rather than an account ban). Dropped for **scope**, not for truth —
see Routing decision.

### C3 — recompute every quantitative claim before publishing a document → `verified`
**Claim.** Enumerate all counts in a hand-maintained document about to be published and
recompute each from source; treat a reported-wrong number as a sample, not the defect.
**Checked.** https://google.github.io/styleguide/docguide/best_practices.html — "Dead
docs are bad. They misinform, they slow down…"; "Change your documentation in the same
CL as the code change." https://www.writethedocs.org/guide/writing/docs-principles/ —
sources of truth must be "clearly defined and disjoint".
**Reproduced.** In the originating repo, 5 of 9 claims were stale (tests 386→1209,
mutations 53→77, node kinds 20→21, EBNF productions 51→58, "Twelve Accepted"→13); only
one had been noticed. Re-checked today: `grep -on '[0-9]\+ tests\|[0-9]\+ node
kinds\|[0-9]\+ productions' README.md` → `1209 / 21 / 58`, the corrected values.
A second observation (back-to-back suite runs on one commit reporting 1195 then 1209)
became the non-determinism edge case.
**Confidence: verified.**

### C4 — enumerate call sites by callee, not parameter name → dropped (duplicate)
Already on `main` in `backend-common-change-impact-call-site-enumeration`, **including
the same field incident** the candidate cites: "a `rows_for()` test helper kept
reproducing a removed rule for five call sites while appearing as a single hit". No
unique content. Retired.

### C5 — `${VAR:-default}` discards an empty off-switch → dropped (duplicate)
Already on `main` in `platforms-shells-env-var-off-switches` (and cross-linked from
`platforms-shells-unset-versus-empty-parameters`), including the same
`WATCH_TMUX=/nonexistent-tmux-disable` sentinel resolution. No unique content. Retired.

### C6 — the worktree guardrail on read-only access → `verified`, and the candidate's stated mechanism was **corrected** before ingest
**Candidate claimed.** `worktree_escape` fires `ask` on read-only access.
**Existing page said** (verified against guardrails 1.0.0) reads pass. Rather than
overwrite a conflicting directive, I read the shipped rule and reproduced it.
**Reproduced** (groundwork guardrails 1.2.0 `hooks/bash-guard.sh`, macOS, run from a
linked worktree against a sibling worktree path):

| Command | Verdict |
|---|---|
| `grep -n foo <main>/<other>/FINDINGS.md` | pass |
| `awk 'NR<5' <main>/<other>/FINDINGS.md` | pass |
| `cat <main>/README.md` | pass |
| `git -C <main>/<other> status --short` | pass |
| `mkdir -p .claude/tmp && grep -n foo <main>/<other>/FINDINGS.md` | **ask** |
| `cp <main>/README.md ./x` | **ask** |
| `grep -n foo <main>/<other>/FINDINGS.md > /tmp/out` | **ask** |

**Mechanism** (read from the rule source): it fires when a main-root mention survives
the strip **and** `(rm|mv|cp|tee|mkdir|touch|install|dd)` or a redirect to an absolute
path matches *anywhere* in the command — the two tests are independent, not correlated.
And the strip removes only the worker's **own** worktree path, so a sibling worktree's
path survives. So the read never fires on its own; it fires when it shares a command
line with any write verb. The existing page's directive stands; this sharpens it.
**Confidence: verified** (reproduction + rule source). The candidate's own wording is
**not** what was ingested.

### C7 — bind a dispatch only to an idle pane; branch recovery on the failure stage → `field-tested`
**Claim.** A worker's "done" is a report emitted from inside its turn, not its end, so
completion hooks keep the pane busy; binding into a busy pane spends the unit. An
occupied-runtime failure wants wait-and-rebind; a dead-agent failure wants a new agent.
**Checked.** Partially corroborated in the shipped source:
`skills/orchestrate/scripts/orca-worker-start.sh` carries "rejects the pair with
`terminal_worktree_mismatch` (verified live)", and `skills/orchestrate/SKILL.md`
documents that a failed unit is replaced with a fresh one rather than retried in place
(naming `runtime_unavailable`). No external/official source exists for a tool-internal
lifecycle.
**Confidence: field-tested** — three same-session observations plus the two
shipped-source corroborations. Written into the page without confidence inflation; the
page's own `confidence: verified` is carried by its termios/tmux sources and the
2026-08-05 reproduction, and the new rows are attributed to a dated field-observation
source line.

### C8 — the author identity a commit publishes → `verified`
**Claim.** Compare `git config user.email` against `git log -1 --format=%ae` before
committing to public history; override per commit with `git -c`, never globally.
**Checked.** https://git-scm.com/docs/git-commit — "the information is taken from the
configuration items `user.name` and `user.email`, or, if not present, the environment
variable `EMAIL`, or, if that is not set, system user name and the hostname used for
outgoing mail", with `GIT_AUTHOR_*`/`GIT_COMMITTER_*` taking precedence.
https://docs.github.com/en/account-and-profile/setting-up-and-managing-your-personal-account-on-github/managing-email-preferences/setting-your-commit-email-address
— "GitHub uses the email address set in your local Git configuration to associate
commits pushed from the command line with your account"; a per-repository address "will
override your global Git configuration settings in this one repository, but will not
affect any other repositories."
**Note on one sub-claim.** The candidate asserted a pushed email is "effectively
unrecallable". GitHub's page does not state that, so the page does not claim it as
sourced — it is expressed as an edge-case action (treat as disclosed; rewrite and
force-push before the first fork or archive) rather than as a documented fact.
**Reproduced today, in this very flush:** the checkout's `git config user.email` was an
employer address while `git log -1 --format=%ae` showed a GitHub no-reply address — the
mismatch is silent, exactly as the page says. This PR is committed under the per-repo
identity, not the ambient one.
**Confidence: verified.**

### C9 — enumerate a closed value table by its values, not its name → `verified` (pass 2)
**Claim.** When widening a closed table that maps names to magnitudes or codes and
that lives as a named constant, grep the table's *values* and member strings — not
only the constant's name — and reconcile every inlined copy to read the single table
before adding the new entry.
**Checked.** https://refactoring.com/catalog/replaceMagicLiteral.html — *Replace Magic
Literal*, alias "Replace Magic Number with Symbolic Constant": the refactoring exists
because the inlined literal is the default state of such a value, which is precisely
what makes the value (not the name) the reliable search handle.
https://pragprog.com/tips/ — Tip 15, DRY: "Every piece of knowledge must have a
single, unambiguous, authoritative representation within a system." A copied table is
a second representation, and widening one representation is what produces the split.
**Reproduced today** (`linkly`, Python, macOS): `grep -rn "DURATION_UNITS"
impl/lnpl/*.py` → **1** hit (the definition alone); `grep -rn "60000" impl/lnpl/*.py`
→ **7** across four files — a second named table (`DURATION_UNIT_MS`, `lexer.py:23`),
three independently inlined `(("ms",1),("s",1000),("m",60000))` tuples
(`condition.py:353`, `interp.py:1020`, `backend.py:446`) and two bare-literal
arithmetic sites (`condition.py:269-270`). The failure the directive predicts was
already live: the canonical map carries `h` and `d` while all three inlined copies
stop at `m`, so those paths cannot convert a unit the lexer already accepts.
**Confidence: verified** — the mechanism is sourced to two primary references and the
enumeration gap is a reproducible check (1 name hit vs 7 value hits, commands above).
The harvested candidate said "2 name hits / 5 value hits"; the re-run on the current
worktree gives 1 and 7, and the page states the re-measured numbers.

### C6 and C7 re-verification (pass 2)
Both were re-checked from source before folding, not accepted on the earlier pass's word.

- **C6 (worktree guardrail).** Read the rule in
  `guardrails/1.2.0/hooks/bash-guard.sh` and re-ran a live probe from a linked
  worktree against the main root: `grep`, `awk`, `cat` and `git -C <main> status
  --short` each returned **no** decision; the same `grep` redirected to an absolute
  path under the main root returned `ask`; redirected to `./probe.log` it returned
  none; `cp ./a <main_root>/b` returned `ask`. This reproduces the merged page
  exactly — reads pass, and it is the write verb or the absolute redirect that fires.
  The pass-2 queue row asserted the opposite ("read-only access fires `ask`"); it is
  refuted as stated, and the true mechanism it was reaching for (a read *captured*
  into an absolute path is a write to the rule) is already the merged edge case.
- **C7 (dispatch binding).** `runtime_unavailable` and `terminal_worktree_mismatch`
  are present in the shipped repo (`skills/orchestrate/SKILL.md:186,224`;
  `skills/orchestrate/scripts/orca-worker-start.sh:88,252`, the latter carrying the
  "verified live" comment the page cites). `agent_unconfigured` is **not** a dev-loop
  constant — it comes from the harness — which is why the page names it descriptively
  ("a stage naming the agent as unconfigured") rather than as a repo symbol.

## Existing-layer check

Routed via `INDEX.md` → domain `index.md` → every page whose "load when" overlapped.

Pages read: backend-common-change-impact-call-site-enumeration, backend-common-api-design-unenforced-declarations, platforms-shells-env-var-off-switches, platforms-shells-unset-versus-empty-parameters, infrastructure-agent-orchestration-worktree-isolated-workers, infrastructure-agent-orchestration-pane-delivery-confirmation, debugging-methodology-hypothesis-testing, qa-deliverables-generated-artifacts-as-deliverable-source, security-secrets-secrets-in-code

Also read at index level (not opened as pages): the `agent-orchestration`,
`document-verification`, `process`, `data` and `secrets` sections of the
infrastructure / qa / security indexes, plus `AGENTS.md` and `templates/page.md`.

**Overlaps found and what was done:**

| Candidate | Overlap | Action |
|---|---|---|
| C4 | `backend-common-change-impact-call-site-enumeration` covers it, same incident text | **Drop** — nothing unique |
| C5 | `platforms-shells-env-var-off-switches` covers it, same sentinel | **Drop** — nothing unique |
| C1 | `debugging-methodology-hypothesis-testing` owns "several suspects compete, pick what to test next" | **Merge** — 2 edge-case rows + 2 source lines |
| C6 | `infrastructure-agent-orchestration-worktree-isolated-workers` owns guardrail direction | **Merge** — 4 edge cases + a 1.2.0 reproduction source |
| C7 | `infrastructure-agent-orchestration-pane-delivery-confirmation` owns pane consumption | **Merge** — 4 edge cases + 1 Instead-of + 1 source |
| C3 | `qa-deliverables-generated-artifacts-as-deliverable-source` is adjacent (choose-your-source) | **New page** — different decision (verify-before-publish); cross-linked via `related:` |
| C8 | `security-secrets-secrets-in-code` (leak response) and `security-data-pii-handling` (PII) are adjacent | **New page** — an author email is neither a rotatable secret nor feature-held PII; `related:` to both |
| C9 | `backend-common-change-impact-call-site-enumeration` (same category, adjacent) and `backend-common-api-design-unenforced-declarations` (closed vocabulary, runtime side) | **New page** — different trigger and a different enumeration handle; `related:` added in both directions |

**Pass 2 (C9) — why not a merge.** `call-site-enumeration` triggers on *changing a
callee's contract* and enumerates by the callee's name; C9 triggers on *widening a
value table* and enumerates by the table's literals, because the sites that break are
copies that never mention the constant. Its closest existing row ("the change reshapes
a data structure … enumerate the structure's producers by its field names") is about
producers of a shape, not inlined copies of a value set. `unenforced-declarations`
owns the *runtime* side of a closed vocabulary (what to do with a name outside the
table); C9 owns the *change-impact* side (widening the table across an implementation).
Distinct triggers → new page under the existing `change-impact` category
(`wiki-ingest` step 4), cross-linked both ways rather than folded. The receiving page
was also already at 94 body lines, leaving no room for the case at full fidelity.

**Conflict flagged, not overwritten.** C6 as harvested contradicts the merged page
("reads fire" vs "reads pass"). I reproduced the rule instead of trusting either: the
page was right, the candidate's mechanism was wrong, and the real finding (independent
AND of write-verb and main-root mention; sibling worktrees not stripped) was written as
a refinement. The 1.0.0 source line is kept alongside the new 1.2.0 one.

**Related-links added:** the two new pages link to
`qa-deliverables-generated-artifacts-as-deliverable-source`,
`qa-document-verification-spec-document-gates`, `testing-quality-spec-artifact-checks`,
`security-secrets-secrets-in-code`, `security-data-pii-handling`. All five ids were
resolved against `wiki/` before commit.

## Open-PR check

**The `gh` API was unavailable for this flush** — the stored token is expired
(`gh auth status`: "The token in default is invalid", `gh api user` → 401), so
`gh pr list --search "head:knowledge/"` could not be run. SSH to the remote works, so
the check was done over remote refs instead: `git ls-remote --heads origin
'refs/heads/knowledge/*'` → **24 heads**, of which **23 still carry wiki diffs against
`origin/main`** (`git diff --name-only origin/main...<head> -- wiki/`) and are therefore
in flight. This substitutes for open/closed state; a closed-but-undeleted branch would
be counted as in-flight here, which errs toward more dedup, not less.

**Per-candidate verdicts:**

| Candidate | Overlapping in-flight heads | Verdict |
|---|---|---|
| C4 call-site enumeration | 11 heads carry a call-site page at 8 different paths (`backend/common/change-impact/`, `backend/common/refactoring/`, `qa/process/`, `testing/quality/`, `testing/migration/`) — `dch0202-20260804-141726`, `-151729`, `-174423`, `-191843`, `20260805-095530`, `-105839`, `-144711`, `-155452`, `-164544`, `-175537`, `20260806-172420` | **drop** — pending duplicate; also already merged on `main` |
| C5 env-var off switch | 4 heads (`20260805-095530`, `-144711`, `-164544`, `-175537`) at 4 path variants | **drop** — pending duplicate; also already merged on `main` |
| C6 worktree guardrail | 2 heads touch `agent-orchestration/worktree-isolated-workers.md` (`20260805-164544`, `20260806-130040`) | **new** — diffed both; neither carries the read-vs-write-verb AND mechanism or sibling-worktree stripping. Ingested here |
| C7 pane binding | 1 head touches `pane-delivery-confirmation.md` (`20260805-164544`); `20260805-130054` and `-155452` carry adjacent tmux pages | **new** — none carries the pre-bind idle gate or the failure-stage branch |
| C3 published-document counts | none — no in-flight head touches `qa/deliverables/` beyond the already-merged page | **new** |
| C8 commit identity | none — closest is `20260806-115351` (`infrastructure/ci-cd/secrets-handling.md`, credential channels), a different concern | **new** |
| C1 hypothesis diagnosticity | none — no in-flight head touches `debugging/methodology/` | **new** |
| C2 generated-text policy | none | **drop** (scope, see below) |

### Pass 2 (2026-08-06 20:45) — `gh` working, re-run properly

`gh pr list --repo choiyounggi/dev-loop --state open --search "head:knowledge/"` →
**3 open PRs**: #50 (`knowledge/dch0202-20260806-172420`), #49
(`knowledge/dch0202-rsquare-20260806-142309`), #47
(`knowledge/dch0202-20260806-130040`). The pass-1 backlog has since been merged down
from 23 in-flight heads to these 3. `git branch -r --list 'origin/knowledge/*'` also
shows **this branch (`…-183029`) with no PR at all** — the token failure above — which
is what pass 2 diffed its candidates against first.

All three open heads were fetched and diffed (`git diff --name-only origin/main
<head> -- wiki/`), plus this branch:

- **#50** → `backend/common/change-impact/call-site-enumeration.md`, `testing/index.md`,
  `testing/quality/policy-at-several-return-sites.md`
- **#49** (fork `dch0202-rsquare`) → 7 pages, all under `testing/quality/`
- **#47** → `infrastructure/agent-orchestration/{control-signals-vs-primary-artifacts,
  worktree-isolated-workers}.md`, `platforms/filesystems/permissions-and-exec-bits.md`,
  `testing/quality/{guard-shape-vs-consequence,tests-that-cannot-fail}.md`, 2 indexes

| Pass-2 candidate | Overlapping head | Verdict |
|---|---|---|
| worktree guardrail read-vs-write (queue hash `28fd6dfe`) | **this branch** already carries it as C6 in corrected form; **#47 also carries it**, on the premise this pass refuted | **fold** into C6 — re-verified by live probe today, nothing unique to add; row retired. Conflict with #47 flagged below |
| dispatch/terminal binding (queue hash `ba3b56ad`) | **this branch** already carries it as C7 (4 edge cases + 1 Instead-of + a field-observations source) | **fold** — stage names re-checked against the shipped scripts; row retired |
| closed value table widening (queue hash `64bb3517`) | none on content. #50 touches the same *directory* (`change-impact/`) but only edits `call-site-enumeration.md`'s `related:` frontmatter line, adding `testing-quality-policy-at-several-return-sites` | **new** — ingested here as C9 |

**Conflict flagged for the owner — #47 vs this branch, same page.** Both edit
`worktree-isolated-workers.md`. #47 adds an edge case asserting that "a conservative
rule treats any cross-worktree path reference in command text as a potential write,
reads included", hedged as version-dependent. This pass probed the rule live on the
installed **guardrails 1.2.0**: a bare `grep` / `awk` / `cat` / `git -C <main> status`
naming the main root produced **no** decision, while the same `grep` redirected to an
absolute path returned `ask` and to `./probe.log` returned none. Reading the rule
source shows why — it requires a surviving main-root mention **and** a write verb or an
absolute redirect. So the read-only premise does not hold for 1.0.0 (already sourced on
`main`) or 1.2.0 (probed today), and #47's prescribed escalation round-trip rests on it.
Not overwritten here: this branch's C6 states the mechanism and the redirect case
positively. **Suggested merge order: this branch first, then re-review #47's row
against it** — the two rows will otherwise sit on one page giving opposite answers.

**Textual conflict to expect (not a disagreement).** #50 and this branch each append a
different id to the same `related:` line of `call-site-enumeration.md` (#50 adds
`testing-quality-policy-at-several-return-sites`, this branch adds
`backend-common-change-impact-widening-a-closed-value-table`). Whichever merges second
needs both ids kept on that line.

**Backlog note for the owner:** 23 unmerged `knowledge/*` heads is the same pile-up
pattern recorded in #39. The call-site-enumeration insight alone exists at 8 paths
across 11 branches while the canonical page is already on `main`; the env-var off-switch
at 4 paths across 4 branches, likewise already on `main`. Those branches are largely
re-litigating merged content. This PR deliberately adds nothing to either cluster.

## Routing decision

| Insight | Target | New category? |
|---|---|---|
| C1 | `debugging` / `methodology` / `hypothesis-testing` (merge: 2 edge cases + 2 sources) | no |
| C2 | **none — dropped as out of scope** | — |
| C3 | `qa` / `deliverables` / **new page** `quantitative-claims-in-a-published-document` | no — `deliverables` fits |
| C4 | none — dropped (merged duplicate) | — |
| C5 | none — dropped (merged duplicate) | — |
| C6 | `infrastructure` / `agent-orchestration` / `worktree-isolated-workers` (merge) | no |
| C7 | `infrastructure` / `agent-orchestration` / `pane-delivery-confirmation` (merge) | no |
| C8 | `security` / `data` / **new page** `commit-identity-in-public-repos` | no |
| C9 | `backend` / `common/change-impact` / **new page** `widening-a-closed-value-table` | no — `change-impact` fits |

**Why C3 is a new page rather than a merge.** `generated-artifacts-as-deliverable-source`
answers *where a deliverable's body should come from*; C3 answers *what to verify in a
hand-maintained document before it goes out*, and its trigger (about to publish; one
number reported wrong) does not match that page's "When this applies". One case per
page (`AGENTS.md` rule 1). Cross-linked rather than folded.

**Why C8 is a new page rather than a merge.** `secrets-in-code` is scoped to values that
can be rotated after a leak; `pii-handling` is scoped to personal data a *feature*
stores. A commit author address is neither — it is published by the VCS itself, cannot
be rotated, and the decision is which identity to bind at commit time. Placed under the
existing `data` category (personal data being published) with `related:` to both.

**Why C2 was dropped.** Its directive — when a community forbids generated text, give
the user the argument structure and let them write the prose — is true and evidenced,
but this wiki's ten domains cover software-engineering practice, and none covers
content-provenance policy for community posting. Inventing an eleventh domain for one
insight over-fits the routing layer, and filing it under `platforms` would contradict
that domain's stated scope ("OS-level differences that break code and scripts"). It
belongs in the operator's own working-practice notes (`HABITS.md`), not the shared
wiki. Retired from the queue rather than left pending, so the auto-flush threshold does
not re-raise a candidate that can never be promoted.

**No new categories were created.**

## Indexes and log

`wiki/qa/index.md` and `wiki/security/index.md` each gained one "load when" row; both
domains' header lines and the matching `INDEX.md` rows were widened to name the new
concerns. `log.md` has the appended `## [2026-08-06] ingest` entry. All five touched
pages are ≤ 120 body lines (76 / 83 / 77 / 82 / 73). Banned vague qualifiers: none in
the new pages.

**Pass 2.** `wiki/backend/index.md` gained one "load when" row under `change-impact`
for `widening-a-closed-value-table` (79 body lines). `related:` links added in both
directions — the new page ↔ `call-site-enumeration`, and the new page ↔
`unenforced-declarations`. `log.md` has a second appended `## [2026-08-06] ingest`
entry covering this pass. `INDEX.md` needed no change: the backend row already routes
"call-site enumeration before a contract change" to this domain.

## Queue disposition

All 11 handled rows were moved to `~/.dev-loop/queue/.processed.jsonl` — the 8 from
pass 1 (including the 3 drops) and the 3 from pass 2 (1 ingested, 2 folded). Nothing
handled was left `pending`; a dropped or folded row left pending would re-cross the
auto-flush threshold indefinitely.
