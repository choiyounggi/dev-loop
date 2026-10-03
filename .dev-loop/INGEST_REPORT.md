# Knowledge flush — 1 insight (1 new page, 4 back-links, 7 plan-gaps retired as local-layer)

## Verified best-practice

**Insight `e752ed422e090759`** — when rebuilding a dict that serializes into a committed golden file (JSON/OpenAPI), assign keys in the order the old literal used, then regenerate and byte-compare every golden, not only the ones a test pins.

Sources checked (each quote extracted from the fetched page on 2026-10-04):

- https://docs.python.org/3/library/stdtypes.html#mapping-types-dict — "Dictionaries compare equal if and only if they have the same (key, value) pairs (regardless of ordering)"; "Dictionaries preserve insertion order"; "Changed in version 3.7: Dictionary order is guaranteed to be insertion order".
- https://docs.python.org/3/library/json.html — "This module's encoders and decoders preserve input and output order by default"; `sort_keys` "is useful for regression tests to ensure that JSON serializations can be compared on a day-to-day basis".
- https://www.rfc-editor.org/rfc/rfc8259#section-4 — "An object is an unordered collection"; §9 says parsers differ on whether they expose member order.
- https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/JSON/stringify — properties are visited "using the same algorithm as Object.keys()".

Reproduction (Python 3 + Node, 2026-10-04): the same keys assigned with `additionalProperties` before `required` gave `old == new` True, `json.dumps` bytes equal **False**, and bytes equal True with `sort_keys=True`. Node gave `JSON.stringify` bytes equal false. `JSON.stringify({b:1,"2":1,a:1,"1":1})` printed `{"1":1,"2":1,"b":1,"a":1}`, which backs the integer-like-key edge row.

Confidence: **verified**.

Review round (fresh-context adversarial reviewer, verdict CHANGES, no blockers): I re-checked each finding before applying it.
- First-insertion position under reassign and `{**a, **b}` merge: reproduced, edge row added.
- `asdict` field order: reproduced, edge row added.
- `OrderedDict` equality is order-sensitive: quoted from collections docs, source added.
- JS array-index rule: the ECMAScript 10.1.11.1 OrdinaryOwnPropertyKeys text was extracted from https://tc39.es/ecma262/. `"4294967295"` / `"01"` / `"-1"` / `"1.5"` keeping insertion order was reproduced in Node. Item 1 and the edge row were rewritten to match.
- The equal-parsed-objects row now names formatting as a second cause.
- `git status --porcelain` was added to catch a new untracked golden.
- RFC §9 and `json.JSONEncoder` anchors were split into their own sources.
- The trigger was widened to match the index row's sorted-keys clause.
- The reviewer's PyYAML-sorts-by-default claim could **not** be verified here (PyYAML not installed, no doc fetched). The YAML/TOML row therefore says to read the writer's docs and byte-compare, and states no default.

After the fixes: body 73 lines, structure checks 0 findings, prohibition lint 0 violations.

## Existing-layer check

Pages read: testing-quality-value-preserving-refactor-assertions, testing-quality-schema-additions-under-a-golden-gate, qa-document-verification-generated-reference-drift-gates, testing-quality-stale-artifact-baselines, testing-quality-behavior-not-implementation

- `wiki_search` top-5 for the trigger: `backend-python-language-dict-subclass-attribute-loss-on-copy` (4 chunks) and `backend-python-language-mutable-state-traps`. Neither covers this situation: one is about attribute loss when copying a dict subclass, the other about module-global state.
- `generated-reference-drift-gates` has one edge row on *unstable* ordering: "churn on every run (timestamps, dict ordering)". This insight is different. The order here is deterministic, but a refactor changed it. The page also covers byte-comparing all outputs vs. only pinned ones. No conflict.
- `value-preserving-refactor-assertions` covers a literal→config refactor whose rendered output stays byte-identical. Adjacent, but its directive is about choosing a sentinel assertion, not about serialization order. No conflict.
- `behavior-not-implementation` (snapshot section) and `schema-additions-under-a-golden-gate` / `stale-artifact-baselines` are adjacent golden-file pages. No overlap.
- Decision: **new page** `testing-quality-key-order-in-serialized-goldens`. Back-links added on value-preserving-refactor-assertions, schema-additions-under-a-golden-gate, stale-artifact-baselines, generated-reference-drift-gates. The behavior-not-implementation back-link is **deferred**, because open PR #223 rewrites that file.
- Lint: `node scripts/wiki-structure-checks.js wiki/` → `pages: 356, indexes: 13, findings: 0` (355 on origin/main + 1 new). `node scripts/wiki-lint-prohibitions.js wiki/` → `violations: 0`.

## Open-PR check

Open `knowledge/*` heads listed: #235 (20261003-220951), #234 (20261002-160836), #233 (20261001-150222), #231 (20260928-191901), #230 (20260928-155239), #229 (20260928-145025), #228 (20260928-134840), #227 (20260928-103056), #226 (20260928-092831), #225 (20260928-082803), #223 (20260927-220735).

Each head's `git diff origin/main origin/<head> -- wiki/` added lines were grepped for `golden|insertion order|sort_keys|key order|json.dumps|byte-identical|byte-compare`. Only #225 and #223 matched, one line each, and both matches are `related:` lists that mention `testing-quality-schema-additions-under-a-golden-gate`. Neither adds content about key order or golden regeneration.

Verdict for `e752ed422e090759`: **new**.

The 7 plan-gap rows are project-specific (see Local-layer candidates), so no open-PR check applies to them.

## Routing decision

- `e752ed422e090759` → `wiki/testing/quality/key-order-in-serialized-goldens.md` (domain testing, category quality — the category that already holds the golden/snapshot assertion pages). No new category. The row is added to the `quality` table in `wiki/testing/index.md`, and a `log.md` entry is appended.

## Local-layer candidates

All 7 rows come from `plan-gaps.jsonl` and are linkly planning decisions (t201, t205). Each names linkly's own files and conventions, so it would be wrong in another codebase. They are excluded from this PR and retired. To keep any of them, run wiki-ingest inside that project.

| Hash | Decision | Target |
|------|----------|--------|
| 1dbdd7273430a837 | t201 `policy retry` effect on a write-conflict | linkly-vendace `wiki-local/backend/reliability/retry-on-write-conflict.md` |
| 97b558dfdc04da2d | t201 `openapi.py` 409 description + 6 example goldens | linkly-vendace `wiki-local/backend/api-design/openapi-409-description.md` |
| 4d49fc2224f86910 | t201 deterministic two-run interleaving test via `_OnceStolenDriver` | linkly-vendace `wiki-local/testing/strategy/once-stolen-driver-interleaving.md` |
| 28ae85b20be137ec | t205 `doctor.sh` digest-mismatch check | linkly-vendace `wiki-local/platforms/tools/doctor-digest-mismatch.md` |
| d198c2fbe1b3a24d | t205 MCP launcher startup stderr line | linkly-vendace `wiki-local/platforms/tools/mcp-launcher-stderr-line.md` |
| 6a7226ec3bf50dc0 | t205 `docs/RELEASING.md` post-release dev-version paragraph | linkly-vendace `wiki-local/infrastructure/release/post-release-dev-version.md` |
| fa92bb280ede406b | t205 `cli-surface.md` capabilities doc update | linkly-vendace `wiki-local/platforms/tools/cli-surface-capabilities-doc.md` |
