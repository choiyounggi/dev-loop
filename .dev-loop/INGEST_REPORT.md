# Knowledge flush — 6 insight(s)

Claimed for run `flush-20261024-032221-81480`: 77 claimable rows (26 insights + 51 plan-gaps). Six general insights were kept for this batch; the other 71 were released unread for later flushes, so this PR stays one reviewable batch. It follows the still-open #298 and #299, which come from the same contributor and cover different topics.

## Verified best-practice

1. **A new test class outside a Gradle `includeTestsMatching` list never runs** (`c35500007da7629b`). Claim: when the `test` task lists its tests in `filter { includeTestsMatching … }`, an unregistered class is silently excluded from the full run. Running it with `--tests` fails "No tests found for given includes", because the build-script inclusions still apply.
   - Sources: https://docs.gradle.org/current/userguide/java_testing.html ("When you use `--tests`, be aware that the inclusions declared in the build script are still honored") and https://docs.gradle.org/current/javadoc/org/gradle/api/tasks/testing/TestFilter.html (`failOnNoMatchingTests` "The default is true").
   - Field reproduction: 3 new classes → "No tests found"; after registering them, 16 tests ran.
   - Confidence: **verified**.
2. **Count an HMAC key literal's bytes before trusting its stated size** (`429f570c59b15c8b`). Claim: an HMAC key must be at least the hash output size. Prose sizes for base64 literals are unreliable. jjwt picks or rejects the algorithm by key length.
   - Sources: https://www.rfc-editor.org/rfc/rfc7518#section-3.2 ("A key of the same size as the hash output … or larger MUST be used") and https://raw.githubusercontent.com/jwtk/jjwt/0.11.5/README.md (HS256/384/512 need ≥ 32/48/64 bytes; `signWith(key)` auto-selects a weaker HMAC). For `signWith(key, HS512)`, https://javadoc.io/static/io.jsonwebtoken/jjwt-api/0.11.5/io/jsonwebtoken/JwtBuilder.html documents an `InvalidKeyException` "if the Key is insufficient … for the specified algorithm", and `WeakKeyException` is its subclass. The README's own `WeakKeyException` sentence is about RSA keys, so it is not cited.
   - Field reproduction: a key described as 72 bytes decoded to 62 bytes, and 4/4 tests failed until a 70-byte key replaced it.
   - Confidence: **verified**.
3. **Probe a leaked Slack webhook with a body Slack rejects at parse time** (`0f1cad864ed980fb`).
   - Sources: https://docs.slack.dev/messaging/sending-messages-using-incoming-webhooks/ (`invalid_payload` = malformed request; `no_service` = "disabled, removed, or invalid"; "Slack actively searches out and revokes leaked secrets") and https://docs.slack.dev/changelog/2016-05-17-changes-to-errors-for-incoming-webhooks (HTTP 400 `invalid_payload`).
   - **Caveat:** no official page maps a status code to `no_service`. That is why the page row keys the decision on the error *string*, and the "404" in the original insight is not repeated as fact.
   - Field observation: `400 invalid_payload`, zero posts to the channel.
   - Confidence: **verified** for the error-string meanings. **Field-tested only** for "`invalid_payload` ⇒ live, nothing posted": Slack documents neither its check order nor a no-post guarantee, and the page row says so ("In observed behavior …").
4. **Keep secrets out of agent command text** (`1cf3eef32b301aef`). Claim: in Claude Code, "Yes, and don't ask again" persists the approved Bash rule to `.claude/settings.local.json` at the repository root. The saved rule holds the command text (an exact string or a prefix; one rule per subcommand of a compound command), so an inline secret is stored verbatim.
   - Source: https://code.claude.com/docs/en/permissions (table row "Permanently per repository and command"; the save location, resolved to the main checkout through worktrees; "a rule you save from a prompt covers only what its option named").
   - Field observation: two allow rules held a `python -c` one-liner with a TOTP seed.
   - Confidence: **verified** (location and matching from the docs; verbatim storage of that specific one-liner is field evidence).
5. **Read the dotenv load point and the active line before trusting `DATABASE_URL`** (`815e8cb9ee66f6e3`).
   - Sources: https://github.com/motdotla/dotenv (`#` lines are comments; default path `path.resolve(process.cwd(), '.env')`; `override` default `false`) and https://raw.githubusercontent.com/motdotla/dotenv/master/lib/main.js (per-line `obj[key] = value`, so the last duplicate in a file wins; read at v18.0.9).
   - Confidence: **verified**.
6. **A "no local verification" push from a fresh worktree still runs the shared pre-push hook** (`72f4e660aeb8fc8b`).
   - Sources: https://git-scm.com/docs/githooks (non-zero pre-push "will abort without pushing anything") and https://git-scm.com/docs/gitrepository-layout (the `hooks` dir is "ignored if $GIT_COMMON_DIR is set and \"$GIT_COMMON_DIR/hooks\" will be used instead"). The pipeline exit-status rule is already sourced on testing-quality-checks-that-cannot-pass (GNU Bash manual).
   - Field observation: a push was rejected while a piped `$?` showed 0; after `pnpm install --frozen-lockfile` the push succeeded.
   - Confidence: **verified**.

## Existing-layer check

Pages read: backend-common-auth-jwt-server-side, security-secrets-secrets-in-code, infrastructure-ci-cd-secrets-handling, infrastructure-config-environment-config, databases-data-survey-surveying-live-data-for-a-rule, infrastructure-agent-orchestration-verify-command-in-a-worker-brief, infrastructure-agent-orchestration-worktree-isolated-workers, testing-quality-tests-that-cannot-fail, testing-quality-checks-that-cannot-pass, platforms-shells-portable-shell-scripts, platforms-tools-deny-rules-under-bypassed-permissions, platforms-tools-agent-permission-classifier-denials

`wiki_search` top hits considered (k=5 per candidate):
- Gradle: compiler-as-call-site-inventory, assertion-scanner-false-positive-on-unittest-convention, compiler-sysroot-on-macos.
- HMAC: jwt-server-side, validation-at-trust-boundaries, signed-link-verification-assertions, object-key-persistence.
- Slack: signed-link-verification-assertions, secrets-handling, validation-at-trust-boundaries, suppression-state-and-delivery-failure.
- `.env`: streaming-large-result-sets, surveying-live-data-for-a-rule, verify-command-in-a-worker-brief, path-valued-config.
- Permission rules: secrets-handling, portable-shell-scripts, agent-permission-classifier-denials, deny-rules-under-bypassed-permissions.
- pre-push: control-signals-vs-primary-artifacts, workflow-authored-pull-requests, worktree-isolated-workers, code-graph-as-orientation-layer.

Per candidate:
- **Gradle filter:** no page covers runner include lists. tests-that-cannot-fail is about assertions that cannot fail and is already over 120 body lines, so this becomes a **new** page. It is linked from tests-that-cannot-fail.
- **HMAC key:** jwt-server-side already says "HS256 with a ≥256-bit random key" — same trigger, compatible directive. **Merged** as one edge row plus sources.
- **Slack webhook:** secrets-in-code's leak response says "rotate first". The probe does not conflict: it decides whether a live credential exists to rotate, and a `no_service` hook has already been revoked. **Merged** as an edge row. No contradiction flagged.
- **Permission rule:** infrastructure-ci-cd-secrets-handling already says "pass secrets via env var or file, not argv" for CI process listings. The new part is the agent approval prompt persisting command text. **Merged** as an edge row in secrets-in-code, linked to deny-rules-under-bypassed-permissions. The two platforms/tools permission pages cover deny/classifier semantics, not what an allow approval stores, so there is no overlap.
- **`.env` target host:** surveying-live-data-for-a-rule has "confirm the target before concluding" (live connection) but not how to read a `.env` correctly. **Merged** into environment-config as an edge row, with links both ways.
- **pre-push:** pipefail and `| tail` exit masking are already on checks-that-cannot-pass, changed-files-only-gates and portable-shell-scripts. Only a cross-reference is added for that part. The new part — a fresh worktree shares hooks but has no installed dependencies, and skipping verification does not exempt the hook — is **merged** into verify-command-in-a-worker-brief. worktree-isolated-workers is at the 120-line cap.
- Independent fact-check: a fresh-context subagent compared every added claim against the cited sources. Corrections applied: the Slack row is softened to observed behavior; the Claude Code rule wording now says exact string or prefix; the dotenv grep also matches `KEY: value`; the jjwt Sources line quotes "the most secure algorithm allowed"; the Gradle error text is marked as coming from the field run; and three prohibition phrasings outside an Instead-of table are rewritten as positive directives.
- Lints: `node scripts/wiki-structure-checks.js wiki` → 469 pages, findings 0. `node scripts/wiki-lint-prohibitions.js` → 0 violations.

## Open-PR check

Open `knowledge/*` heads listed with `gh pr list --repo choiyounggi/dev-loop --state open --search "head:knowledge/"`:
- **#299** `dch0202-rsquare:knowledge/dch0202-rsquare-20261023-143208` — touches command-guard-exemption-matching, command-text-inspected-before-execution, ktlint-final-newline-from-editorconfig, gh-api-paginate-with-jq, search-evidence-from-a-wrapped-grep and others. The diff mentions "Gradle" only in the ktlint/editorconfig page, which is a different trigger.
- **#298** `dch0202-rsquare:knowledge/dch0202-rsquare-20261023-140311` — gateway alias resolution, Spring env-var names, CDN traffic path, stderr in captures, tool diagnostics without a failing exit code. Its diff has no keyword hits on pipefail, pre-push, webhook, dotenv, DATABASE_URL, HMAC or permission rules.
- **#293** `knowledge/autoflush-20261022-163155-79805` — diff-algorithm-dependent line counts. No overlap.

Verdict for all six candidates: **new**. No fold, no drop.

## Routing decision

| Insight | Target |
|---------|--------|
| Gradle include filter | testing/quality → new `new-test-outside-a-runner-include-filter` (+ testing index row) |
| HMAC key length | backend/common/auth → `jwt-server-side` edge row |
| Slack webhook liveness | security/secrets → `secrets-in-code` edge row (+ security index "load when") |
| Secret in approved command text | security/secrets → `secrets-in-code` edge row (+ security index "load when") |
| `.env` target host | infrastructure/config → `environment-config` edge row (+ infrastructure index "load when") |
| pre-push from a fresh worktree | infrastructure/agent-orchestration → `verify-command-in-a-worker-brief` edge row (+ infrastructure index "load when") |

No new category was needed.

## Local-layer candidates

none — all six are general. The repository names in the field evidence were generalized out of the directives.

## Decision Log

- **Intent:** land six candidates as one reviewable batch. Five merge into existing pages as edge rows; one becomes a new page (Gradle include filters), because tests-that-cannot-fail is already over the 120-line cap and covers a different trigger.
- **Excluded alternatives:**
  - Draining all 77 claimed rows into one PR — released 71 instead, following the batch size of #298/#299.
  - A new security page for agent approval prompts — merged into secrets-in-code, whose trigger already covers "a secret was just pasted/logged".
  - Repeating the insight's "`no_service` = 404" — Slack documents no status code for it.
- **Where to look:** the Slack row's "In observed behavior" wording (an undocumented no-post guarantee), and the Claude Code saved-rule wording ("exact string or a prefix").
- Cross-Check: a fresh-context subagent fact-checked every added claim against the cited sources. It returned 2 overclaims and 5 prohibition phrasings outside an Instead-of table; all were corrected before this PR.
