# Knowledge flush — 2 insight(s) (headless auto-flush run 20261029-160814-38451)

9 queue rows were claimed this run: 2 ingested, 4 released because they plausibly
overlap open knowledge PRs, and 3 released unread because this headless run could
not find their queue files. Nothing was dropped or folded into another branch.

## Verified best-practice

| Row | Claim | Verification | Confidence |
|-----|-------|--------------|------------|
| `ca76a971902a3eea` | In Jackson 3, `JsonNode.asString()` / `asDouble()` with no default throw `JsonNodeException` on object/array nodes, where Jackson 2's `asText()` returned `""`. For nodes that can hold a container, use the default-taking form (`asString("")`, `asDouble(0.0)`) or `asStringOpt()`, and test with a container value | jackson-databind 3.0.0 Javadoc (https://javadoc.io/static/tools.jackson.core/jackson-databind/3.0.0/tools.jackson.databind/tools/jackson/databind/JsonNode.html): `asString(String defaultValue)` returns the default "instead of throwing an exception for non-coercible values or coercing null (or missing value)"; `stringValue()` throws `JsonNodeException` on non-string nodes; `asStringOpt()` exists. Read through a WebSearch summary: WebFetch of javadoc.io was not permitted in this run. The OpenRewrite 2→3 recipe page (https://docs.openrewrite.org/recipes/java/jackson/upgradejackson_2_3_jsonnodemethodrenames) lists `asText(..)` → `asString`. The session reproduced it on a jackson-databind 3.1.7 jar: `ObjectNode.asString()` and `ObjectNode.asDouble()` threw, `asString("")` returned `""`, Missing/Null `asString()` returned `""`, and the reverted fix failed at `BaseJsonNode.asString(BaseJsonNode.java:393)` | verified |
| `e9443b0f4120f8ae` | A test floor that picks the framework from the file name sends `*.test.mjs` to a Jest analyzer that counts only `expect(`, so every `node:test` + `node:assert` case reads `no-assertion`. Treat it as a false negative and pass the case on as `floor=unknown` instead of adding a fake `expect(` | https://nodejs.org/api/test.html (fetched): a test "is considered failing if it throws an exception, and is considered passing otherwise", its examples assert with `assert.strictEqual`, and `node --test` runs `**/*.test.{cjs,mjs,js}` by default. A local read of `skills/orchestrate/scripts/test-floor.sh` (dev-loop 1.34.2) shows that `framework_of()` maps `*.test.mjs` to `jest` and `analyze_jest` sets `has_expect` only on `expect\(`. Its case regex `^[ \t]*(it\|test)\(` also matches `node:test`'s `test(`, so cases are counted but never satisfied. The session evidence was exit 3 on a file with 1,1,1,1,3 asserts per case, plus an `ERR_ASSERTION` red run | verified |

## Existing-layer check

Pages read: testing-quality-assertion-scanner-false-positive-on-unittest-convention, backend-java-spring-proxy-pitfalls, backend-common-errors-exception-handling

Indexes read: `INDEX.md` routing via `wiki/backend/index.md`, `wiki/backend/java/index.md`, `wiki/testing/index.md`.

- `e9443b0f4120f8ae`: `wiki_search` on the trigger ranked `testing-quality-assertion-scanner-false-positive-on-unittest-convention` first. That page already owns "a floor classifier has no pattern for this convention" (step 6, `floor=unknown`) and lists the Rust inline-test variant as an edge row. The trigger matches and the directive agrees, so the candidate was **merged** as one new Edge-cases row plus three Sources lines. The frontmatter gained the Node docs source, `javascript` in `applies_to`, and `last_verified` 2026-10-29. The testing index "load when" line for the page was extended. No conflict.
- `ca76a971902a3eea`: `wiki_search` for Jackson / `JsonNode` / migration returned no Jackson page; the top hits were JPA, JSONC gates and zod pages, none about the same trigger. **New page** `backend-java-spring-jackson-3-jsonnode-coercion`. `related:` lists `backend-common-errors-exception-handling` (the catch-all narrowing step; a back-link was added there), `backend-common-change-impact-call-site-enumeration`, and `testing-quality-minimum-case-set`. No conflict.

## Open-PR check

Open `knowledge/*` heads (12): #310, #309, #308, #307, #306, #305, #304, #301, #300, #299, #298, #293. This headless run cannot run git, so it could not diff those heads. It compared candidates against each PR's changed-file list and the Routing section of its body (read through `gh pr list --json files,body`).

| Row | Overlapping open PR | Verdict |
|-----|---------------------|---------|
| `ca76a971902a3eea` | none: #298 and #299 touch `backend/java/index.md` only for Spring env-var names and ktlint, not Jackson | new |
| `e9443b0f4120f8ae` | none: no open PR touches `assertion-scanner-false-positive-on-unittest-convention.md`. #310, #309, #300 and #293 edit other rows of `wiki/testing/index.md` only | new |
| `8a67a97c4afd204c` (`grep -q` SIGPIPE leaves the runner's temp dir) | #299 (grep pitfalls: `search-evidence-from-a-wrapped-grep`, `parsing-cli-structured-output`), #300 (`checks-that-cannot-pass`). #307 released this row for the same reason | released (pending duplicate) |
| `f332524447ff2105` (gate ledger grep finds its own CHECK line; `grep` as a shell function) | #299 (`platforms/tools/search-evidence-from-a-wrapped-grep`), #300 (`checks-that-cannot-pass`). #305 and #307 released this row for the same reason | released (pending duplicate) |
| `baac78b023efce53` (id-only allowlist of expected failures needs cause-text match + planted negatives) | #300 edits `infrastructure/agent-orchestration/verify-command-in-a-worker-brief.md`, whose edge row "list baseline failures by test id" is this candidate's natural merge target. It also edits `testing/quality/checks-that-cannot-pass` and `tests-that-cannot-fail` | released (pending duplicate) |
| `4067cf60d5d486f5` (done-gate counting an append-only log the worker also writes) | #304 adds a done-gate counting edge row to `qa/process/completion-claims.md`, this candidate's domain and tag (`completion-claims`) | released (pending duplicate) |

## Routing decision

- `ca76a971902a3eea` → `backend/java/spring/jackson-3-jsonnode-coercion.md` (new page) with a `backend/java/index.md` spring row, and the `backend/index.md` java line extended with "Jackson 2→3 tree-model migration". No new category. `backend/java` has `jpa`, `spring`, `runtime` and `kotlin`, and none covers JSON libraries. `spring` is the closest fit because Spring Boot 4 brings Jackson 3 as its default, and the page notes that it applies to direct Jackson use too. A separate `serialization` category for one page did not seem justified.
- `e9443b0f4120f8ae` → edge row on `testing/quality/assertion-scanner-false-positive-on-unittest-convention.md`. The domain hint `testing` was followed, with no new category. The directive is general: any floor that classifies by file name. The dev-loop script and the run appear only in Sources lines.
- Released without routing: `8a67a97c4afd204c`, `f332524447ff2105`, `baac78b023efce53`, `4067cf60d5d486f5` (open-PR overlap, above). Also `317f31de7391fb88`, `0e06c969dce06eea` and `b84f3ab68e8acb52`: this run's sandbox blocks listing `~/.dev-loop/queue/`, and these rows sit in session files whose names could not be found, so they were released unread for a later flush.

## Local-layer candidates

none
