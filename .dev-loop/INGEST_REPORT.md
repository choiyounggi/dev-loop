# Knowledge flush — 1 insight(s)

Headless autoflush run, 2026-11-04 (claims by run `20261104-133008-18720`). Claimed 4 candidates: ingested 1, released 3 (2 pending duplicates of open PRs, 1 unreadable in this run).

## Verified best-practice

**63c0a85e1e6199a2 — real environment values in a README's pasted CLI output** (ingested)

- Claim: before committing a document that contains a real command run, replace addresses, hostnames and account names with documentation values, then `git grep -F` each real value to zero hits. Reason: npm always packs README, and a published version cannot be changed.
- Sources checked (via WebSearch; this run has no WebFetch):
  - https://github.com/npm/cli/blob/latest/docs/lib/content/configuring-npm/package-json.md — `files`: "Certain files are always included, regardless of settings" (package.json, README, LICENSE/LICENCE, `main`, `bin`).
  - https://docs.npmjs.com/policies/unpublish — "Registry data is immutable, meaning once published, a package cannot change"; a name@version cannot be reused even after unpublishing.
  - https://www.rfc-editor.org/rfc/rfc5737.txt — 192.0.2.0/24, 198.51.100.0/24, 203.0.113.0/24 are reserved for documentation.
  - https://tailscale.com/docs/reference/ip-pool — Tailscale assigns device addresses from all of 100.64.0.0/10 (RFC 6598).
  - Field evidence from the source session: the real router address was on 3 README lines, found by `git log -G` and a per-tag `git grep` in tags v0.2.0–v0.4.1 and in the npm 0.4.0/0.4.1 tarballs. The current tree had 0 hits.
- **Changed from the candidate:** the candidate suggested the Tailscale-looking example `100.64.0.10`. That is an address a real tailnet device can hold (Tailscale IP pool docs), so the page recommends RFC 5737 documentation addresses instead and lists the CGNAT shape as an edge row.
- Confidence: **verified** (the npm packing and immutability rules and RFC 5737 come from official docs; the grep step follows from them and was carried out in the field).

**b5863e2d758c98fb — Claude Code behind a gateway still sends bootstrap requests while a claude.ai OAuth login remains** (released, not verified in this run)

**126503dbe78559da — claude-code-action: `--allowedTools` does not remove `Agent`; deny it with `--disallowedTools`** (released, not verified in this run)

**fc76dc4dfa08ecde** (released): this headless run cannot list `~/.dev-loop/queue`. Queue files can only be opened by guessing session ids from `~/.claude/history.jsonl`, and this row's file was not found that way. Left for the manual skill.

## Existing-layer check

Pages read: qa-deliverables-command-transcripts-in-a-document, qa-process-session-identity-leak-in-plugin-prose, security-data-commit-identity-in-public-repos

- `wiki_search` ("real IP addresses or account names in README example output published to npm…" and "pasting real terminal output into documentation…") returned `qa-deliverables-command-transcripts-in-a-document`, `security-data-commit-identity-in-public-repos`, `security-secrets-secrets-in-code` and `security-data-masking-verification`.
- `qa-deliverables-command-transcripts-in-a-document` already owns "pasting a captured CLI run into a README". Its edge table replaced per-run values (timings, temp paths) with placeholders, but it said nothing about environment values or published copies. **Merged** there: Do-this step 6, 3 edge rows, 1 Instead-of row, 5 source bullets, and a wider "When this applies". Body is 83 lines.
- `security-data-commit-identity-in-public-repos` covers an author address already pushed ("treat it as disclosed"). The new edge row for an already-published value links to it and does not repeat it. No conflict.
- `qa-process-session-identity-leak-in-plugin-prose` covers session-injected names in plugin prose. Its edge row already extends to hostnames. This is a sibling check with a different trigger (a review diff vs a pasted transcript), so it is linked, not merged.
- `security-secrets-secrets-in-code` (from search snippets only) is about credentials and leak response. An address or account name is not a credential, so it is not the right home. Not modified.
- Also read `wiki/qa/index.md` and `wiki/security/index.md` for routing; the qa index load-when line was extended.
- related += `security-data-commit-identity-in-public-repos`, `qa-process-session-identity-leak-in-plugin-prose`. `last_verified` set to 2026-11-04. `log.md` revise entry appended.

## Open-PR check

20 open `knowledge/*` PRs: #330, #329, #328, #324, #319, #318, #317, #315, #310, #309, #308, #307, #306, #305, #304, #301, #300, #299, #298, #293. Changed-file lists and PR bodies came from `gh pr list --json files,body`. This headless run cannot fetch or diff branch content.

- **63c0a85e1e6199a2 → new.** No open PR touches `wiki/qa/deliverables/` or `wiki/security/data/`. #300 edits `security/secrets/secrets-in-code.md` with Slack-webhook and approved-command-secret rows (per its body), which is a different trigger and a page this candidate does not touch. #308/#305 edit `qa/document-verification/` pages on Korean particles and superseding records, which is unrelated.
- **b5863e2d758c98fb → released as a pending duplicate.** #328 edits `platforms/processes/spawning-an-agent-cli-from-a-server.md` with `ANTHROPIC_BASE_URL`/`ANTHROPIC_AUTH_TOKEN` gateway rows, and #298 adds `backend/common/llm/gateway-model-alias-resolution.md`. Same domain and trigger (Claude Code behind a gateway). This matches the verdict in #330's run, and both PRs are still open.
- **126503dbe78559da → released as a pending duplicate.** #300 edits `platforms/tools/deny-rules-under-bypassed-permissions.md` (Claude Code allow/deny rule semantics), and #328 edits `platforms/tools/per-call-subagent-effort.md`. Both plausibly overlap `--allowedTools`/`--disallowedTools` and `Agent`. Same verdict as #330's run.
- **fc76dc4dfa08ecde → released.** Its row could not be read, so overlap could not be judged. #328's report describes it as a Docker-gated schema validator candidate, released then for plausible overlap with #300/#317, and both are still open.

## Routing decision

- 63c0a85e1e6199a2 → `qa/deliverables/command-transcripts-in-a-document.md` (merge). The candidate's domain hint was `security`, but the artifact being produced is a document containing a pasted transcript, and that page owns it. The security pages own credentials (`secrets-in-code`) and commit identity, not example values in docs. The directive is general (any published README or doc), not specific to one project.
- No new category.

## Local-layer candidates

none

## Queue bookkeeping

- Retired in place (`status: retired`, `retiredBy`, `outcome`), the same way earlier headless runs retired rows in that session file: 63c0a85e1e6199a2.
- Released back to pending: b5863e2d758c98fb, 126503dbe78559da, fc76dc4dfa08ecde. Confirmed with `queue-claim.js list`, which printed exactly those three ids.
