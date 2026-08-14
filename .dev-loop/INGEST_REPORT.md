# Knowledge flush — 3 insight(s): 2 ingested, 1 folded into open PR #80

## Verified best-practice

**1. pytest caplog log-message assertions must use `record.getMessage()` / `caplog.messages`, never `record.message % record.args`** — INGESTED, confidence: **verified**.
- Claim: pytest's capture handler formats each record at capture time, so `record.message` is already `msg % args`; re-applying `% record.args` raises `TypeError: not all arguments converted during string formatting` on any parameterized log call, while argument-less calls make the faulty pattern a silent no-op (which is how it survives in suites).
- Sources checked:
  - https://docs.python.org/3/library/logging.html#logrecord-attributes — `message` "computed as msg % args … set when Formatter.format() is invoked"; `getMessage()` "merging any user-supplied arguments with the message".
  - https://docs.pytest.org/en/stable/reference/reference.html#pytest.LogCaptureFixture.messages — "A list of format-interpolated log messages … all interpolated", recommended for exact comparisons.
  - https://github.com/pytest-dev/pytest/blob/main/src/_pytest/logging.py — `LogCaptureHandler.emit` appends the record and calls `StreamHandler.emit` (which formats, setting `record.message`); verified against current source.
- How verified: fresh local reproduction (Python 3, stdlib logging with a formatting capture handler): parameterized record → `record.message` fully interpolated, `message % args` → the exact TypeError; argument-less record → silently passes. Matches the harvesting session's pytest run (`uv run --extra dev pytest tests/test_gh.py -q`, fail→pass flip after switching to `getMessage()`).

**2. A passing page-load login probe does not validate direct API auth under refresh-token cookie auth** — INGESTED, confidence: **verified**.
- Claim: browser navigation triggers the server's refresh middleware (short-lived access token rotated via Set-Cookie, persisted by the browser context), so a page-load "logged in" check passes while a script replaying a stored cookie jar sends the stale access token and fails; preflight the API's identity endpoint (GraphQL `currentUser`) with the operation's own client/cookie jar, and refresh + persist cookies on failure.
- Sources checked:
  - https://github.com/velopert/velog-server/blob/master/src/lib/token.ts — read the actual middleware: `setTokenCookie` sets `access_token` maxAge 1h beside `refresh_token` maxAge 30d; `consumeUser` refreshes on expired/near-expiry access tokens and returns rotated cookies via Set-Cookie.
- How verified: primary-source code read (above) + session reproduction: `check-login.mjs` → `STATUS:LOGGED_IN` immediately followed by publish failure "Not logged in"; direct `v3.velog.io/graphql` `currentUser` with the same stored cookies → null; re-running the login flow (rewriting the cookie store) made the same publish succeed. Page generalizes the directive; velog specifics kept as the worked example and edge cases.

**3. tmux prompt injection: "delivered" return with the prompt stuck as `[Pasted text #N]` — send Enter separately and re-verify** — NOT re-ingested (fold, see Open-PR check). The insight is real and was independently reproduced this time (pdfsum1 run, 3 sessions), but an open PR already carries it in equal-or-better form.

## Existing-layer check

Pages read: infrastructure-agent-orchestration-pane-delivery-confirmation, testing-quality-tests-that-cannot-fail, debugging-methodology-hypothesis-testing, infrastructure-agent-orchestration-control-signals-vs-primary-artifacts

- Routed via root `INDEX.md`, then read `wiki/infrastructure/index.md`, `wiki/testing/index.md`, `wiki/debugging/index.md` in full; grepped all of `wiki/` for `caplog|getMessage|LogRecord`, `refresh token|access token|cookie`, `pasted|send-keys|Enter`.
- **Candidate 1 (caplog):** no existing testing page covers log-content assertions (grep hit only backend/common/api-design/error-responses.md, unrelated). New trigger → new page `testing/quality/captured-log-message-assertions.md`. Related-link added both ways with `tests-that-cannot-fail` (the zero-arg latent-pass is exactly its "green history proves nothing" mechanism).
- **Candidate 2 (auth probe):** no debugging page covers a passing probe contradicting a failing operation; `hypothesis-testing`/`reproduce-first`/`verify-the-fix` own adjacent but distinct triggers. New trigger → new page `debugging/methodology/probe-path-vs-operation-path.md`. Related-links added both ways with `hypothesis-testing` and `control-signals-vs-primary-artifacts` (shared theme: a signal is evidence only about the path that produced it). No conflicts with existing directives found.
- **Candidate 3 (tmux):** `pane-delivery-confirmation` already owns the trigger (its multi-line-prompt edge row mandates separate body/submit sends); the specific `[Pasted text #N]` placeholder + separate-Enter recovery is carried by open PR #80's diff to that same page. Nothing to merge into the merged layer that #80 doesn't already add.
- Both domain `index.md` files gained accurate "load when" rows; `log.md` gained two ingest entries.

## Open-PR check

Listed 27 open `knowledge/*` heads (#47–#95) via `gh pr list --search "head:knowledge/"`, fetched all `origin/knowledge/*` refs, and grepped each `git diff origin/main...<head> -- wiki/` for overlap keywords (`pasted|send-keys|bracketed paste|caplog|getMessage|record.args|refresh token|access token|currentUser|login check|graphql`).

- **Candidate 1 (caplog): new.** No open head touches caplog/log-record assertion content (only incidental `send-keys`/rate-limit-token matches elsewhere).
- **Candidate 2 (auth probe): new.** Token-keyword hits in `dch0202-20260805-*` heads are GitHub OAuth rate-limit content, unrelated to probe-path divergence; no overlap.
- **Candidate 3 (tmux): fold into PR #80** (`knowledge/choiyounggi-20260812-234147`). Its diff adds to `pane-delivery-confirmation` the exact edge row — pane shows `❯ [Pasted text #3]` with no busy marker → "send `Enter` as its own `send-keys` call and re-read" — plus a 2026-08-12 field observation of the same rc=0/"delivered"-but-unsubmitted failure. My candidate's only unique contribution is a second independent reproduction (pdfsum1 run: 3 of 4 sessions stuck post-"delivered", one Enter each resolved), which I posted as a corroborating comment on #80 rather than opening a sibling duplicate. Candidate retired as folded.

## Routing decision

| Insight | Target | New page? |
|---------|--------|-----------|
| caplog `getMessage()` assertions | `testing/quality/captured-log-message-assertions.md` (id `testing-quality-captured-log-message-assertions`) | Yes — existing `quality` category fits (assertion-correctness cluster); no new category needed |
| login-probe vs API-auth divergence | `debugging/methodology/probe-path-vs-operation-path.md` (id `debugging-methodology-probe-path-vs-operation-path`) | Yes — `methodology` fits (diagnosing contradictory evidence); considered `signals` but the page prescribes an investigation/verification method, not signal reading; no new category needed |
| tmux pasted-text Enter recovery | fold → open PR #80 (`infrastructure/agent-orchestration/pane-delivery-confirmation.md`) | No — corroborating evidence noted on #80; not re-ingested here |
