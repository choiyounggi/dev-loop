# Knowledge flush — 7 insight(s)

## Verified best-practice

**1. Gate a warning-emitting tool on captured stderr, not the exit code** (`lnpl` compiler hook, linkly session)
- Claim: tools emit warnings on stderr while exiting 0, so a hook keyed on exit codes misses all warnings; capture with `OUT=$(tool "$F" 2>&1 >/dev/null)` (order matters) and feed back via exit 2.
- Verified: local reproduction this session — `2>&1 >/dev/null` inside `$(...)` captured exactly `warning: W1` while the reversed order captured nothing. Sources fetched live: POSIX 2.7 Redirection ("the order of evaluation is from beginning to end"), GNU bash manual Redirections ("processed in the order they appear, from left to right", with the `ls > dirlist 2>&1` example), and code.claude.com/docs/en/hooks (exit 2: "stderr text is fed back to Claude as an error message"; PostToolUse "Shows stderr to Claude; the tool already ran").
- Confidence: **verified**.

**2. Attribute leaked test artifacts by prefix counts, then enforce the convention statically** (linkly, 998 leftover temp entries)
- Claim: leak volume concentrates in a few producers; count leftovers by name prefix, match against creating call sites, fix those, then add a static check proved red first.
- Verified: measured field incident only (686+306 of 998 entries = exactly the two `mkdtemp` sites without cleanup; post-fix tmp delta 0, 72M → 3.3M). No external doc claims to check.
- Confidence: **field-tested**.

**3. Restoring after a red-run mutation when the fix is uncommitted: copy+hash, not `git checkout --`**
- Claim: `git checkout -- <path>` discards the unstaged fix along with the mutation.
- Verified: local git reproduction this session — uncommitted fix + mutation + `git checkout --` returned the file to the last commit (fix lost); a *staged* fix survived, confirming the restore source is the **index** (the harvested candidate said HEAD — corrected in the page); copy+hash restore round-tripped identically. Source fetched live: git-scm.com/docs/git-checkout ("Replace the specified files ... with the version from the index").
- Confidence: **verified**.

**4. Route token/auth requests through the client-side throttle** (`stock-trader` `kis_client.py`)
- Claim: token refresh inside the header-builder bypasses a wrapper-level throttle; token POST + first API call land in the same second, so the failure only fires on cold-token days and reads as intermittent.
- Verified: field incident with log timestamps (POST 00.354 → issue 00.495 → rejected call 00.543). The draft page's two source URLs did **not** state the claimed facts (Okta rl2-token-oauth is about per-token limit allocations), so they were replaced with pages that do: Okta rate-limits overview (OAuth2 endpoints sit in rate-limit buckets; only public metadata endpoints are exempt) and Auth0's Authentication API endpoint rate-limit policy. Both fetched live; supporting, not primary, evidence.
- Confidence: **field-tested**.

**5. Homebrew clang on macOS needs `-isysroot "$(xcrun --show-sdk-path)"`**
- Claim: Homebrew clang defaults to a baked-in CommandLineTools SDK path; when it vanishes, clang warns (`-Wmissing-sysroot`) and proceeds without system headers, failing one step downstream.
- Verified: clang DiagnosticsReference fetched live (`-Wmissing-sysroot` exists, enabled by default); LLVM Discourse #77604 (recommends `-isysroot $(xcrun -show-sdk-path)`); Homebrew/homebrew-core#45061 (Homebrew clang does not find the system headers Apple's driver finds); local `xcrun --show-sdk-path` resolves. Session evidence: 69 failing tests reduced to a one-file probe, fixed by the flag.
- Confidence: **verified**.

**6. Enumerate call sites by callee, not parameter name** — **dropped as a duplicate.** The page `backend/common/change-impact/call-site-enumeration.md` (merged to main 2026-08-04, PR #20) already carries this directive, the same linkly field incident, and the Python positional-or-keyword mechanism. The one novel fragment in the re-harvest — a test helper appearing once in the enumeration while feeding the old contract to N callers — was added as one edge-case row + one source line.

**7. `${VAR:-default}` treats empty as unset, defeating `VAR=` off-switches**
- Claim: to disable via env against a `:-` read, pass a value the script's own validation rejects (e.g. `WATCH_TMUX=/nonexistent`), or change the read to `${VAR-default}`.
- Verified: local reproduction in bash 3.2 **and** zsh 5.9 (colon form substituted on empty; colon-less form respected empty). GNU bash manual fetched live: "Omitting the colon results in a test only for a parameter that is unset."
- Confidence: **verified**.

## Existing-layer check

Read before writing: `INDEX.md`; domain indexes for testing, backend, platforms; pages `tests-that-cannot-fail`, `test-data-and-isolation`, `call-site-enumeration`, `portable-shell-scripts`; the three draft pages left untracked by an interrupted earlier flush run (adopted after independent re-verification, one with corrected sources).

- **Merged, not created** (same trigger, compatible directive): #3 → `testing/quality/tests-that-cannot-fail` (edge-case row + Instead-of row + 3 source lines); #2 → `testing/data/test-data-and-isolation` (edge-case row + Instead-of row + field-incident source); #7 → `platforms/shells/portable-shell-scripts` (edge-case row extending the existing `"${OPT:-}"` row, Instead-of row, GNU-manual source); #6 remainder → `backend/common/change-impact/call-site-enumeration` (one edge row).
- **No conflicts found**: no existing directive contradicts any candidate; #3 sharpens the harvested claim (index, not HEAD) rather than conflicting with a page.
- **Related links added both ways**: warnings page ↔ `portable-shell-scripts`, ↔ `command-text-inspected-before-execution`; `macos-sdk-sysroot` ↔ `path-resolution`, ↔ `version-management`; `client-side-rate-limiting` ↔ `timeouts-and-retries`; `call-site-enumeration` ↔ `test-data-and-isolation`.
- **Overlap with open PRs**: unmerged PRs #32 and #34 (earlier flushes of parallel sessions' re-harvests of the same incidents) cover much of the same ground. Dedup here is against merged `main` per the skill; reviewer should merge one flush and close the overlapping ones — flagged in `log.md` too.

## Routing decision

| # | Insight | Target | New/merge | Note |
|---|---------|--------|-----------|------|
| 1 | stderr-warnings gate | `platforms/shells/warnings-on-stderr-with-exit-zero` | new page | Harvest hinted `testing`, but the mechanics are shell redirection + hook contract → platforms/shells; testing owns none of it |
| 2 | artifact-leak attribution | `testing/data/test-data-and-isolation` | merge | Existing page already owns temp-file hygiene rows |
| 3 | mutation restore | `testing/quality/tests-that-cannot-fail` | merge | The red-run procedure this trap occurs in lives on this page |
| 4 | throttle bypassed by auth | `backend/common/reliability/client-side-rate-limiting` | new page | `timeouts-and-retries` covers outbound-call policy, not client-side throttle design; same category, new page |
| 5 | macOS SDK sysroot | `platforms/toolchains/macos-sdk-sysroot` | new page | `version-management` is about version drift, not SDK resolution; same category, new page |
| 6 | call-site enumeration | `backend/common/change-impact/call-site-enumeration` | drop (dup) + 1 edge row | Already merged to main 2026-08-04 |
| 7 | `${VAR:-}` off-switch | `platforms/shells/portable-shell-scripts` | merge | Page already documents `${OPT:-}` under `set -u`; this is its inverse trap |

No new categories were needed; `reliability`, `toolchains`, and `shells` all pre-exist. Index "load when" lines added/extended for every touched page; `log.md` ingest entry appended.
