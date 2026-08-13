# Knowledge flush — 4 insight(s)

Queue contained 5 pending rows across 4 session files; two rows (hashes
`e44b870e42ca9d9a` / `f5bba19794bcdae8`) were English/Korean duplicates of the
same insight harvested in one session, folded into one candidate. Net: 4 unique
insights, all processed.

## Verified best-practice

**1. Gitignored coordinator-state dirs are absent from git worktrees — hand
workers absolute paths.**
Claim: a repo-relative path under a gitignored directory (`.orchestration/`)
resolves in the coordinator's main checkout but silently misses in every
worker's worktree, because `git worktree add` checks out tracked files only.
Verified by local reproduction this session (git, macOS): repo with
`.gitignore: .orchestration/` + populated `.orchestration/status/`;
`git worktree add ../wt1 -b wt1` → `ls ../wt1/.orchestration` = "No such file
or directory", `cat .orchestration/status/run.json` from the worktree cwd
failed, `git ls-files .orchestration` = 0. Consistent with
https://git-scm.com/docs/git-worktree (linked worktrees are separate checkouts
of the branch). **Confidence: verified.**

**2. Verify a documented EDR claim on the host before reasoning from it.**
Claim: docs asserting "this host runs SentinelOne/EDR" must be checked against
the host (vendor dir + process grep + `systemextensionsctl list` together);
all-empty means "not installed", not "failed to detect". Mechanism verified
against https://www.elastic.co/blog/mac-system-extensions-for-threat-detection-part-3
and https://github.com/redcanaryco/mac-monitor/wiki/5.-Endpoint-Security-Overview
(post-kext-deprecation, macOS EDRs ship Endpoint Security clients as system
extensions, enumerable via `systemextensionsctl list`); all three commands
re-run this session on this macOS host (Darwin 25.1.0) reproducing the
incident's empty results. Field incident: root XMRig ran 4d8h on a host whose
global CLAUDE.md claimed SentinelOne. **Confidence: verified.**

**3. Judge a miner-suspect process by executable path + signature, never by
name.**
Claim: malware adopts legitimate daemon names; macOS ships a genuine
`/usr/libexec/sysmond`, so name-based kills hit the Apple daemon or miss the
miner. Verified this session: `ls -l /usr/libexec/sysmond` (root:wheel),
`man -w sysmond` → man8 page, `codesign -vv` → valid / satisfies Designated
Requirement, `codesign -dv` → `Identifier=com.apple.sysmond`,
`Authority=Software Signing`. Technique documented at
https://attack.mitre.org/techniques/T1036/005/ ("giving it the name of a
legitimate, trusted program", fetched and confirmed this session). Field
incident: quarantined `~/.config/sysmond` was XMRig 6.26.0 by its own log
header. **Confidence: verified.**

**4. For prod-only failures the client swallows, grep the service logs for the
endpoint path before reading more code.**
Claim: when the frontend `.catch()`-swallows errors, a 500 and a no-op are
indistinguishable from the UI; one server-side exception line kills hypothesis
families. Field evidence: chungyak-alimi bookmark bug — backend/proxy/browser
all verified normal, then one `journalctl | grep bookmark` surfaced
PostgreSQL's "no unique or exclusion constraint matching the ON CONFLICT
specification" → deployed DB on an old schema. The PostgreSQL mechanism
(ON CONFLICT arbiter inference raises an error without a matching unique
index) confirmed against https://www.postgresql.org/docs/current/sql-insert.html.
The directive itself is production experience aligned with
https://sre.google/sre-book/effective-troubleshooting/ (already a page source).
**Confidence: field-tested** (marked as such in the added source line).

## Existing-layer check

Pages read: infrastructure-agent-orchestration-worktree-isolated-workers, infrastructure-agent-orchestration-shared-run-state, debugging-methodology-reproduce-first, debugging-signals-logs-and-correlation

Also read: root `INDEX.md`, `wiki/infrastructure/index.md`,
`wiki/security/index.md`, `wiki/debugging/index.md` (routing), and
`skills/wiki-ingest/SKILL.md` + `templates/page.md` + `AGENTS.md` format rules.

- Insight 1 overlaps `worktree-isolated-workers` (same trigger family, new
  failure mode) → **merged** there: +1 edge case, +1 instead-of row, +1
  reproduction source. No conflict: the page's "write produced paths
  worktree-relative" directive concerns worker *output*; this case concerns
  coordinator-state paths workers must *read*, and reads of absolute main-root
  paths pass the guardrail per the page's own table. Related link added
  worktree-isolated-workers → shared-run-state (reverse link already existed).
- Insight 4 overlaps `reproduce-first`'s prod-only evidence row → **merged**
  there: +1 edge case (silent-swallow), +1 field source. Related links now
  bidirectional with `logs-and-correlation` (that page already pointed at
  reproduce-first in an edge-case row).
- Insights 2–3: read every security category in `wiki/security/index.md`
  (input, api-exposure, authn, authz, secrets, dependencies, data) — all cover
  designing trust boundaries in code; none covers live host-compromise triage.
  No duplicate, no conflicting directive. → **new pages** (see Routing).

## Open-PR check

Listed 25 open `knowledge/*` heads (#47–#91). Same-branch heads fetched
directly; fork PRs (#49, #52, #72, #73, #74, #76, #78, #86, #91) fetched via
`pull/<n>/head`. All 25 diffs against `origin/main -- wiki/` were concatenated
and keyword-swept (gitignore, EDR, sentinel, sysmond, xmrig, miner, incident,
systemextensionsctl, swallow, `.catch(`, server/production log, prod-only).

- Insight 1: #47 and #51 also edit `worktree-isolated-workers.md`, but both add
  guardrail read-escalation version behavior — no overlap with the
  gitignored-dir-absent-in-worktree case (their hunks inspected in full).
  Verdict: **new** (file-level merge conflict possible with #47/#51; content
  disjoint — flagged here for the owner's merge ordering).
- Insight 2: EDR/SentinelOne keyword hits were pre-existing removed lines in
  #47/#51's `permissions-and-exec-bits` context, unrelated. Verdict: **new**.
- Insight 3: no hit for sysmond/miner/masquerade in any open head. Verdict:
  **new**.
- Insight 4: no open head touches `reproduce-first.md` or
  `logs-and-correlation.md`; silent-failure hits were unrelated env-var pages.
  Verdict: **new**.

No candidate was folded into an in-flight branch; none dropped as a pending
duplicate.

## Routing decision

- Insight 1 → `infrastructure/agent-orchestration/worktree-isolated-workers`
  (merge; harvested domain hint "infrastructure" confirmed).
- Insight 2 → `security/incident-response/verifying-assumed-security-agents`
  (**new category** `incident-response`): existing security categories all
  govern designing/reviewing trust boundaries in code (input, api-exposure,
  authn, authz, secrets, dependencies, data); responding to a live host
  compromise fits none of them, and debugging/platforms were rejected
  (debugging owns diagnosing code failures; platforms owns cross-OS code
  breakage, not threat triage). Domain index + root INDEX.md security row
  updated.
- Insight 3 → `security/incident-response/process-identity-by-path-and-hash`
  (same new category; the two pages cross-reference via `related:`).
- Insight 4 → `debugging/methodology/reproduce-first` (merge; harvested domain
  hint "debugging" confirmed).

Queue retirement: all 5 rows (4 insights + 1 language duplicate) appended to
`~/.dev-loop/queue/.processed.jsonl` and their session files rewritten/deleted
after PR creation.
