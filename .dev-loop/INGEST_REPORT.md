# Knowledge flush — 12 insight(s)

Run `20260906-013758-50852` (headless auto-flush), claimed 12 of 41 pending rows via `queue-claim.js claim --max 12`. Outcome: 5 new pages, 3 merges into existing pages, 3 folds pushed onto open PR #181, 1 pending-duplicate drop (PR #185). Lint on this branch: `wiki-structure-checks` findings 0 (281 pages), `wiki-lint-prohibitions` violations 0, `wiki-lint-model-era` 22 coupled / 21 candidates (the new model-era page carries `verified_model`).

## Verified best-practice

1. **SwiftPM: test an executable target directly** (`8cfed7ce6d1fb5dc`) — claim: since tools-version 5.5 a test target may depend on an `.executableTarget` and `@testable import` it. Sources fetched and quote-checked by curl: swift-package-manager CHANGELOG (`#3316` "Test targets can now link against executable targets as if they were libraries … tools version of `5.5` or newer"; `#4119` `--disable-testable-imports`), SE-0294 (Implemented Swift 5.4), TSPL AccessControl.md (`@testable` needs "compiled with testing enabled"), SPMBuildCore `BuildParameters+Testing.swift` (`explicitlyEnabledTestability ?? (configuration == .debug)`), swift-package-manager#6367 (works on macOS/Linux; Windows `duplicate symbol: main`), Swift Forums 52351. Field: desk-bat 49/49. **verified**.
2. **macOS off-screen capture without Screen Recording** (`49e0bd8194f59531`) — claim: render the app's own content (`SKView.texture(from:)`, `NSView.cacheDisplay`) and assemble GIFs with ImageIO instead of `screencapture` when the TCC grant is unavailable. Apple doc JSON endpoints quote-checked: `texture(from:)` ("does not need to appear in the view's presented scene"), `SKRenderer`, `cacheDisplay(in:to:)`, `kCGImagePropertyGIFDelayTime` ("clamped to a minimum of 100 milliseconds" — this corrected the candidate's 15 fps cadence to 10 fps), macOS 15.1 release notes ("deprecated content capture technologies now have enhanced user awareness policies"), WWDC19 701 transcript ("preapprove apps to record the entire screen or the contents of windows other than their own"), Apple Platform Security guide (Screen recording is TCC-gated). The literal `could not create image` text and the relaunch-after-grant step are field evidence only and labelled so. **verified**.
3. **Testcontainers reaper on Docker Desktop macOS** (`2bea722bd3446ce7`) — candidate said "disable Ryuk". Research (testcontainers-python README, java/go configuration docs, Rancher Desktop + Colima guides, docs.docker.com Advanced settings, testcontainers-java#8170/#7678, testcontainers-go#399, all quote-checked) shows the documented fixes are the Desktop "Allow the default Docker socket to be used" setting or `TESTCONTAINERS_DOCKER_SOCKET_OVERRIDE=/var/run/docker.sock` with Ryuk kept on; disabling Ryuk is the last resort and "will prevent testcontainers from automatically cleaning up resources". Page orders the rows accordingly; the candidate's 0 tests → 27/27 measurement is kept as field evidence. **verified**.
4. **Ciphertext orphaned by a regenerated key** (`83a8c321f97b084c`) — sources quote-checked: OWASP Cryptographic Storage Cheat Sheet (key-id-with-ciphertext, retain old keys, rotation procedures in place beforehand), Node crypto docs (`decipher.final()` throws on failed authentication — a wrong key is indistinguishable from tampering), Rails ActiveRecord Encryption `previous:`, Tink 5-byte key-id prefix. OWASP Key Management sheet and NIST SP 800-57 were fetched but yielded no quotable rotation text and are not cited. Field: 124/124 unrecoverable. **verified**.
5. **Model-coupled guidance aging detector** (`75447f854be33d2d`) — sources: Anthropic prompting best practices (guidance ages per generation: "Tools that undertriggered in previous models are likely to trigger appropriately now"), dev-loop `scripts/wiki-lint-model-era.js` (merged PR #178, whose body records 3/271 phrase hits vs ~27/271 subject hits). Reproduced on this checkout: `pages: 276, model-coupled: 21, candidates: 21`, exit 3; whole-file grep 32 vs scoped 21 (supports the prose-only scoping directive). **verified**.
6. **CORS preflight silently drops an injected probe's JSON POST** (`bac1bbff54ea37c6`) — mechanism already sourced on the existing page (MDN CORS, Fetch spec: `application/json` is not safelisted → `OPTIONS` preflight); added the diagnostic rows and the field reproduction (0 → 6 reports after handling `OPTIONS`). Page stays **verified**.
7. **Queued candidate already landed in the store** (`694be184a03a9676`) — evidence checked in `~/.dev-loop/queue/.processed.jsonl` (row `f1ba9bf617fbd101` status `dropped-already-merged`), `code-graph-as-orientation-layer.md` line 102 on `main`, PR #184 merged 2026-09-04. Generalised as a control-signal-vs-primary-artifact row. **field-tested** row on a verified page.
8. **Literal re-assertion of a layout constant** (`ea0d83f672d08fa2`) — the never-fails pattern is an instance of tests-that-cannot-fail's thesis; field evidence (LinklyTabBar 96 vs 80 pt, fix 4e584cc) added as a row + Sources bullet. **field-tested** row on a verified page.
9. **Grep both ends of a threaded value** (`9a3ec3b23171ebdd`) and 10. **enumerate contract-test contrast pairs** (`204952e682bc7e76`) — plan-authoring lenses; folded as author-side rows into #181's checkable-claims page whose WCAG source already covers the ratio arithmetic. **field-tested** rows.
11. **CJK label + pill wraps after padding change** (`418bcb06dbb3562e`) — CSS Text 3 ("line breaking conventions allow the line to break anywhere except between certain character combinations"), MDN word-break `keep-all` contrast, MDN flex-shrink, quote-checked. **verified** rows, folded into #181's responsive-layout.
12. **Prisma `CREATE INDEX CONCURRENTLY` in a multi-statement migration** (`11c6ad7b2166e611`) — not re-researched: open PR #185 already carries the same directive and the same 2026-08-31 field evidence in `online-schema-changes.md`. Dropped.

## Existing-layer check

Pages read: infrastructure-agent-orchestration-control-signals-vs-primary-artifacts, backend-common-api-design-cors-and-preflight, qa-environments-browser-console-capture-gaps, debugging-methodology-probe-path-vs-operation-path, frontend-design-responsive-layout, backend-common-change-impact-call-site-enumeration, testing-quality-tests-that-cannot-fail, testing-quality-value-preserving-refactor-assertions, security-secrets-secrets-in-code, databases-schema-design-online-schema-changes, qa-document-verification-editing-a-gated-document, testing-quality-guard-shape-vs-consequence, qa-environments-test-environment-parity, mobile-security-sensitive-data-on-device

Also read on open-PR branches only (not on this checkout's `main`): `checkable-claims-in-an-adopted-plan` (#181), `element-crop-screenshots` (#182), `online-schema-changes` as changed by #185. All ten domain `index.md` files and `INDEX.md` were read for routing.

Overlaps and decisions:
- CORS: `cors-and-preflight` already states the `application/json` → preflight mechanism; merged the diagnostic angle (probe silence) as an edge-case row + Instead-of row + field source, and linked `debugging-methodology-probe-path-vs-operation-path` and `qa-environments-browser-console-capture-gaps` from its `related:`. Back-links onto those two pages skipped because #180 and #182 rewrite their frontmatter.
- Queue lag: `control-signals-vs-primary-artifacts` item 1 ("confirm the claim against the primary artifact") is the exact frame; added a Confirm-with row, an edge-case row and an Instead-of row. Body-only — #179 rewrites this page's `related:`.
- Literal constant: `tests-that-cannot-fail` never-fails table is the home; `value-preserving-refactor-assertions` covers the adjacent (literal moved to config) case and was read to confirm no overlap. Body-only — #179/#180 rewrite the frontmatter.
- SwiftPM: no page mentions SwiftPM/`@testable`/executable targets (grep). New page under testing/strategy; related to `test-level-choice` (subprocess vs import level).
- Off-screen capture: no page mentions TCC/screencapture/SpriteKit (grep; `sensitive-data-on-device` mentions app-switcher screenshots only). New page under qa/environments beside the console-capture and element-crop pages; back-link added on `sensitive-data-on-device`.
- Testcontainers: no page mentions testcontainers/ryuk (grep); `test-data-and-isolation` covers fixtures/isolation, not the container runtime. New page under testing/data (no new category — re-checked qa/environments `test-environment-parity`, which is about staging parity, and linked it both ways).
- Key mismatch: security/secrets has only `secrets-in-code` (leak/storage); no encryption-at-rest page. New page; back-link added on `secrets-in-code`; `related:` to hypothesis-testing and probe-path (back-links skipped: #179/#180 touch those frontmatters).
- Model-era detector: no page on `main` covers it (grep for model-era/model-coupled: 0). New page under qa/document-verification; back-links added on `editing-a-gated-document` and `guard-shape-vs-consequence`.
- Conflicts flagged: none. No existing directive is contradicted; the testcontainers page demotes the candidate's own directive (disable Ryuk) to the last row, recorded in `log.md`.

## Open-PR check

Open `knowledge/*` heads listed with `gh pr list --search "head:knowledge/"`: #185 `knowledge/choiyounggi-20260906-003745`, #183 `…20260904-133717`, #182 `…20260903-214027`, #181 `…20260903-203836`, #180 `…20260903-184706`, #179 `…20260903-172728`. Each head was fetched and `git diff origin/main origin/<head> -- wiki/` inspected.

| Candidate | Overlapping open head | Verdict |
|-----------|-----------------------|---------|
| `11c6ad7b2166e611` Prisma CONCURRENTLY | #185 rewrites `online-schema-changes.md` with the same two rows and the same 2026-08-31 field evidence | **drop** (pending duplicate) |
| `9a3ec3b23171ebdd` grep both ends | #181 adds `checkable-claims-in-an-adopted-plan.md` (plan claims to check) | **fold** — rows pushed to #181 (commit on that branch + PR comment) |
| `204952e682bc7e76` contrast pairs | #181 same page (WCAG recomputation item 1) | **fold** — row pushed to #181 |
| `418bcb06dbb3562e` CJK pill | #181 rewrites `responsive-layout.md` frontmatter + rows | **fold** — rows pushed to #181 to avoid a sibling conflict; #181 did not previously carry the insight |
| `694be184a03a9676` queue lag | #179 rewrites `control-signals-vs-primary-artifacts` `related:` only | **new** (body-only merge here) |
| `ea0d83f672d08fa2` literal constant | #179/#180 rewrite `tests-that-cannot-fail` `related:` only | **new** (body-only merge here) |
| `bac1bbff54ea37c6` CORS probe | none touch `cors-and-preflight.md` | **new** |
| `8cfed7ce6d1fb5dc`, `49e0bd8194f59531`, `2bea722bd3446ce7`, `83a8c321f97b084c`, `75447f854be33d2d` | none (grep of every open head's wiki diff for swiftpm/testable, TCC/screencapture/SpriteKit, ryuk/testcontainers, AES/decrypt/ciphertext, model-era/verified_model: 0 hits) | **new** |

Index files (`wiki/*/index.md`, `INDEX.md`) are also touched by every open PR; those are additive-row conflicts for the owner to resolve at merge, as in the previous flushes.

## Routing decision

| Candidate | Target |
|-----------|--------|
| `8cfed7ce6d1fb5dc` | testing/strategy — new `executable-target-tests-in-swiftpm` (level/structure decision: import vs subprocess) |
| `49e0bd8194f59531` | qa/environments — new `offscreen-render-capture-without-screen-recording` (evidence capture environment, beside console-capture and element-crop pages; platforms rejected because the directive is about producing QA/doc evidence, not OS portability) |
| `2bea722bd3446ce7` | testing/data — new `testcontainers-reaper-on-docker-desktop-macos` (test-infrastructure containers; no new `testing/environments` category — qa/environments `test-environment-parity` linked instead) |
| `83a8c321f97b084c` | security/secrets — new `ciphertext-orphaned-by-a-regenerated-key` (key lifecycle; debugging linked via `related:`) |
| `75447f854be33d2d` | qa/document-verification — new `model-coupled-guidance-aging-detector` (a gate over documents; `verified_model: claude-fable-5-1` set because the page is itself model-coupled) |
| `bac1bbff54ea37c6` | backend/common/api-design — merged into `cors-and-preflight` |
| `694be184a03a9676` | infrastructure/agent-orchestration — merged into `control-signals-vs-primary-artifacts` |
| `ea0d83f672d08fa2` | testing/quality — merged into `tests-that-cannot-fail` |
| `9a3ec3b23171ebdd`, `204952e682bc7e76` | infrastructure/agent-orchestration — folded into #181's `checkable-claims-in-an-adopted-plan` |
| `418bcb06dbb3562e` | frontend/design — folded into #181's `responsive-layout` |
| `11c6ad7b2166e611` | dropped (pending duplicate of #185) |

No new category was added. `INDEX.md` route-here lines for qa, testing and security were extended by one clause each; domain `index.md` rows added for the five new pages and load-when lines extended for the three merged pages. `log.md` carries one entry per page plus the fold and drop entries.
