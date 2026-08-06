# Knowledge flush — 8 insight(s)

Queue drained: 8 pending rows across 4 session files. Outcome: **2 new pages,
3 merges into existing pages, 3 drops** (2 already-merged duplicates, 1 out of scope).

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

## Existing-layer check

Routed via `INDEX.md` → domain `index.md` → every page whose "load when" overlapped.

Pages read: backend-common-change-impact-call-site-enumeration, platforms-shells-env-var-off-switches, platforms-shells-unset-versus-empty-parameters, infrastructure-agent-orchestration-worktree-isolated-workers, infrastructure-agent-orchestration-pane-delivery-confirmation, debugging-methodology-hypothesis-testing, qa-deliverables-generated-artifacts-as-deliverable-source, security-secrets-secrets-in-code

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
