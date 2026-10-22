# Knowledge flush — 3 insight(s) (headless auto-flush run 20261022-134153-21632)

18 queue rows were claimed this run: 3 ingested, 1 dropped as a duplicate of the
merged wiki, 13 dropped as project-specific plan-gap rows, 1 released because it
plausibly overlaps open PR #291. Nothing was folded into another branch.

| Candidate | Domain | Disposition |
|-----------|--------|-------------|
| `f7273179a74dcb80` — secret in an HTTP header leaks through `http.client`'s `ValueError` | security | **ingested** — edge row in `security-secrets-secrets-in-code` (verified) |
| `3d610c1206e1bdd6` — text nobody sent in an agent CLI's input box is the grey prompt suggestion | infrastructure | **ingested** — edge row in `infrastructure-agent-orchestration-pane-delivery-confirmation` (verified docs + field observation) |
| `0a0ccc4ca0904514` — e2e failure moving between tests under host CPU contention | testing | **ingested** — new page `testing-flaky-e2e-failures-moving-under-host-cpu-contention` (field-tested) |
| `97c37473b53e63c2` — string-pattern `replace`: `$n` stays literal, `$$`/`$&`/`` $` ``/`$'` expand | backend (queued as frontend) | dropped — duplicate of merged page |
| `446c58c78d5e467f` — `git diff --numstat` count depends on the diff algorithm | testing | released — plausible overlap with open PR #291 |
| 13 plan-gap rows (see Local-layer candidates) | — | dropped — project-specific |

## Verified best-practice

**`f7273179a74dcb80` — confidence: verified.** Claim: when a script puts a secret
from an env var into an HTTP header via Python `http.client`/`urllib`, a value
with a bare CR/LF (a pasted key ending in `\n`) makes `putheader` raise a
`ValueError` whose message contains the whole header value, so a traceback that
escapes the script's own redaction prints the key.
- CPython `Lib/http/client.py` (https://github.com/python/cpython/blob/main/Lib/http/client.py):
  read in the local CPython 3.9 source — l.138
  `_is_illegal_header_value = re.compile(rb'\n(?![ \t])|\r(?![ \t\n])').search`;
  l.1234-1235 `if _is_illegal_header_value(values[i]): raise ValueError('Invalid header value %r' % (values[i],))`.
  A trailing `\n` matches `\n(?![ \t])`, and `%r` repeats the full encoded value.
  Web search confirmed the check came from the CVE-2016-5699 header-injection fix.
  The `main`-branch file was not fetched in this run (WebFetch is not allowed here);
  the cited line numbers are from 3.9.
- Field reproduction (session evidence): on Python 3.13 and 3.11 the key appeared
  in the traceback; after the pre-request check plus catch-all redaction, 0 key hits
  and the mutation checks went red.

**`3d610c1206e1bdd6` — confidence: verified (docs) + field observation.** Claim:
in a Claude Code pane read through `tmux capture-pane`, grey text in the input box
that nobody sent is the CLI's prompt suggestion. Plain capture drops styling, so the
suggestion looks like an unsubmitted prompt.
- https://code.claude.com/docs/en/interactive-mode (fetched 2026-10-22), "Prompt
  suggestions": "shows a grayed-out example command in the prompt input"; after a
  response it "can suggest your next prompt"; "Press `Tab` or `Right arrow` to place
  the suggestion in the prompt input, then `Enter` to submit"; "Start typing to dismiss it".
- tmux man page (https://man7.org/linux/man-pages/man1/tmux.1.html; same wording read
  from the local tmux 3.7b `tmux.1`, l.2693-2696): "If -e is given, the output includes
  escape sequences for text and background attributes."
- Field observation (run i41): the box showed "승인됐습니다. 계획대로 구현하세요."
  after `plan_ready`; `send-prompt.sh state lo-1-i41` → `ready` rc 0; the next real send
  reported `delivered`.
- Not claimed: which escape code (dim SGR 2 vs a grey colour) the CLI uses. The page
  says "grey/dim" to match the docs' "grayed-out".

**`0a0ccc4ca0904514` — confidence: field-tested.** Claim: on a shared host, a
browser e2e failure that moves to a different timing-dependent test on each re-run
is CPU contention until shown otherwise. Measure load and foreign headless browsers,
re-run once after 60 s quiet, and report every run line.
- https://playwright.dev/docs/test-cli — `--workers` defaults to 50% of logical CPU
  cores (already cited on the wiki; it sizes to the host's cores, not to free capacity).
- https://playwright.dev/docs/ci — recommends `workers: 1` in CI "to prioritize
  stability and reproducibility", so each test gets the full system resources. This was
  confirmed only through a web-search summary of the official page; the page was not
  fetched in this run.
- Field observation (2026-10-18, 36-test Playwright suite): load avg 19 with a foreign
  `chrome-headless-shell` at 110% CPU → "1 failed" at `leave.spec.ts:37`, then at
  `game-bell.spec.ts:33`; after 60 s with no headless browser → "36 passed (50.9s)".
  This is a single host, so the page is field-tested, not verified.

**`97c37473b53e63c2`** — the claim is correct (MDN replacement-pattern table; the node
evidence in the row), but it is already on the merged wiki. See Existing-layer check.

## Existing-layer check

Pages read: security-secrets-secrets-in-code, infrastructure-ci-cd-secrets-handling, infrastructure-agent-orchestration-pane-delivery-confirmation, testing-flaky-diagnosing-flaky-tests, testing-flaky-docker-vm-oversubscription-under-parallel-containers, testing-e2e-e2e-stability, backend-node-language-string-replace-replacement-patterns

- **security-secrets-secrets-in-code** — merge target for `f727`. Its edge table
  already has two "a library echoes the secret" rows: a URL-query key logged by HTTP
  clients, and a DSN echoed in an error. The header-value `ValueError` is a third path
  of the same kind, so it was added as one edge row, not a new page. One source line
  and one field-evidence line were added. `last_verified` was left at 2026-07-12
  because the other rows were not re-checked.
- **infrastructure-ci-cd-secrets-handling** — read as a possible target (job-log
  masking). Not chosen: it covers how the pipeline handles secrets, and this is a
  script's own exception text. No edit.
- **infrastructure-agent-orchestration-pane-delivery-confirmation** — merge target for
  `3d61`. It already owns the input-box rows for this CLI (the `[Pasted text` placeholder,
  where the input box sits). The suggestion case is a sibling edge row. Added the
  interactive-mode doc to frontmatter sources, plus three Sources lines (tmux `-e`
  quote, docs quote, field observation).
- **testing-flaky-diagnosing-flaky-tests** — closest owner for `0a0c`. It is
  `confidence: verified`. The 2026-10-22 log shows that the Wiki agent gate blocked
  merging a single-field-reproduction mechanism into this page (the PR #275 split).
  Following that precedent, the mechanism went to its own field-tested page. This page
  gets one pointer edge row and a `related:` id; its confidence and date are unchanged.
- **testing-flaky-docker-vm-oversubscription-under-parallel-containers** — the nearest
  sibling: resource ceiling, different subset failing each run. It is a different case
  (container memory, `409` errors, its own trigger), so the new page was not merged into
  it. The two are cross-linked from the new page's `related:` and an edge row.
- **testing-e2e-e2e-stability** — read for e2e overlap. It covers selectors, waits,
  and data, not host contention. Linked from the new page's `related:`; no edit.
- **backend-node-language-string-replace-replacement-patterns** — already says
  `$n` / `$<name>` work for "regex patterns only; otherwise left literal", and has the
  edge row "A string `from` (no captures) → `$1` stays literal, but `$$`, `$&`, `` $` ``,
  `$'` still expand". That is exactly what `97c3` asks for, so it was dropped as a duplicate.

No conflicting directive was found and no page was superseded.

## Open-PR check

Open `knowledge/*` heads at flush time (`gh pr list --repo choiyounggi/dev-loop
--state open --json number,headRefName --search "head:knowledge/"`):
**#291** (`knowledge/autoflush-20261022-124048-18072`).

This headless run cannot `git diff` that branch, and `gh pr view` / the GitHub MCP
file list were not allowed. Overlap was judged from the queue rows that #291's run
retired, using their `outcome` fields. #291 touches
`testing-quality-anchor-cases-for-allowlist-regexes`,
`testing-quality-checks-that-cannot-pass`,
`qa-process-blind-llm-judgment-of-a-visual-rule`, and a new page
`platforms-shells-non-ascii-text-after-an-unbraced-parameter`.

- `f727` (security, secret in an HTTP header) — **new**: #291 touches no security page.
- `3d61` (agent pane input box) — **new**: #291's only platforms/infrastructure page is
  a bash parameter-expansion page, which is a different trigger.
- `0a0c` (e2e flakiness under CPU contention) — **new**: #291 touches no `testing/flaky`
  or e2e page.
- `97c3` — not compared against #291: it was dropped against the merged layer.
- `446c58c78d5e467f` (exact `git diff --numstat` count as a gate's expected value) —
  **drop (plausible overlap)**, so its claim was **released**, not retired. It is a
  gate-design lesson in `testing/quality`, and #291 is editing two `testing/quality`
  gate pages (`checks-that-cannot-pass`, `anchor-cases-for-allowlist-regexes`). This run
  cannot diff #291, so the manual flush should decide whether to fold it in or ingest it
  as new.

## Routing decision

- `f7273179a74dcb80` → `security` / `secrets` → edge row in
  `wiki/security/secrets/secrets-in-code.md`; security index "load when" extended.
- `3d610c1206e1bdd6` → `infrastructure` / `agent-orchestration` → edge row in
  `wiki/infrastructure/agent-orchestration/pane-delivery-confirmation.md`; infrastructure
  index "load when" extended. Written generally (any helper that classifies the box, or
  `capture-pane -e`); the dev-loop helper `send-prompt.sh` appears only in the evidence line.
- `0a0ccc4ca0904514` → `testing` / `flaky` → new page
  `wiki/testing/flaky/e2e-failures-moving-under-host-cpu-contention.md` (field-tested).
  There is no new category: `flaky` already holds the sibling resource-ceiling page.
  A pointer edge row and a `related:` id were added in `diagnosing-flaky-tests`, and a
  testing index row was added. The INDEX.md testing line already covers "flaky tests".
- `log.md` has one entry appended for this run.

## Local-layer candidates

These 13 plan-gap rows are excluded from this PR. Each records a design decision for
the `emperor` (linkly) repository's own files, so each would be wrong in another
codebase. Run wiki-ingest inside that project to keep any of them:

| Row | Decision | Target |
|-----|----------|--------|
| `3632d0989f629104`, `7bfb7541e4e4bd8c` | t242 SECURITY.md sections and policy values | `wiki-local/security/disclosure/security-policy-file.md` |
| `9700770d7c05b820` | t242 `.github/CODEOWNERS` layout | `wiki-local/infrastructure/repo-governance/codeowners-layout.md` |
| `3d578bcfcbcc6b97`, `410400eb22f77f77` | t242 CODE_OF_CONDUCT.md source and contact | `wiki-local/infrastructure/repo-governance/code-of-conduct-source.md` |
| `54aeaa8fdee5e0e7` | t242 mutation harness `TREE_CONTENTS` for new root files | `wiki-local/testing/quality/mutation-tree-contents.md` |
| `0e0e7c7c4cef34c3` | t252 per-runner concurrency group for `_ai-gate.yml` | `wiki-local/infrastructure/ci-cd/ai-gate-concurrency-groups.md` |
| `05df421bf905f5ce` | t252 `response_format: json_object` for the HTTP gate runner | `wiki-local/backend/llm/ai-gate-structured-output-mode.md` |
| `1670e43e60cb7fe3`, `2df80edab8d41dfb` | t252 / t257 CHANGELOG bullet placement | `wiki-local/qa/release/changelog-bullet-placement.md` |
| `1666b8cf32e274ea` | t257 `_relay_batch` calls begin/commit/rollback directly | `wiki-local/backend/outbox/relay-transaction-calls.md` |
| `5ee53f499cc8d657`, `744090ce219677c0` | t249a1 RFC-0007 Review stage and §2.2 rule-5 chain notes | `wiki-local/qa/spec-process/rfc-promotion-checks.md` |
