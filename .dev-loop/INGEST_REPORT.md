# Knowledge flush — 1 insight

Headless auto-flush. 4 candidates were claimed: 1 ingested, 3 released back to the
queue as pending duplicates of open knowledge PRs (see Open-PR check).

## Verified best-practice

**fc76dc4dfa08ecde — tests that call an external validator (Docker/CLI) that may be absent.**
Claim: guard on `shutil.which("docker")` plus `docker info` with a timeout; skip
with a reason naming the pinned image; an env var (`…_REQUIRE_…=1`) turns the skip
into a failure; pair the valid case with a known-bad document asserted rejected;
prove the absent branch by running with `PATH=/usr/bin:/bin`.

Sources checked:
- https://github.com/pytest-dev/pytest/issues/1364 — pytest maintainer (nicoddemus):
  "If you want the test to fail if a dependency is not installed then you shouldn't
  be using skip"; suggests a mark handled in `conftest.py` that "would skip the test
  locally, but fail when running in the CI". Supports the skip-locally / fail-in-CI switch.
- https://docs.python.org/3/library/unittest.html#skipping-tests-and-expected-failures —
  `skipTest(reason)` skips and records the reason; `fail(msg)` "Signals a test failure
  unconditionally"; skips appear as `OK (skipped=N)`. Supports the unittest mechanics.
- https://github.com/yannh/kubeconform — `-summary` line format
  (`Valid: N, Invalid: N, Errors: N Skipped: N`), README examples show exit 1 for an
  invalid file and 0 for a valid one, images at `ghcr.io/yannh/kubeconform`. Supports
  the known-bad assertion (rc 1, `Invalid: 1`).
- `docker info` returning non-zero when the daemon is unreachable: confirmed by several
  troubleshooting references found in search (not an official Docker doc page), so the
  page states it as the guard and adds the permission-denied edge case rather than
  quoting a specific error text.
- Field evidence from the originating session (pinned kubeconform v0.6.7): valid stream
  `Valid: 19, Invalid: 0`; known-bad HPA rc 1 `missing properties: 'maxReplicas'`;
  `PATH=/usr/bin:/bin` → `OK (skipped=2)`; strict env var set → 2 FAIL.

Confidence: **verified** (primary sources for each mechanism + reproduced field run).

## Existing-layer check

Pages read: debugging-methodology-hiding-a-tool-to-reproduce-its-absent-branch, testing-quality-tests-that-cannot-fail, testing-quality-history-dependent-checks-on-shallow-clones, qa-process-release-gates, testing-strategy-test-level-choice, testing-quality-checks-that-cannot-pass, testing-data-installed-extensions-discovered-at-test-time

wiki_search top hits considered (two queries): databases-schema-design-migration-sql-without-a-database,
testing-quality-schema-rejection-key-coverage, testing-mocking-captured-call-arguments,
backend-python-boundaries-runtime-validation, testing-flaky-docker-vm-oversubscription-under-parallel-containers;
debugging-methodology-hiding-a-tool-to-reproduce-its-absent-branch, platforms-tools-version-keyed-artifact-cache,
infrastructure-ci-cd-changed-files-only-gates, testing-strategy-test-level-choice,
testing-strategy-import-time-side-effects.

Overlaps:
- hiding-a-tool-to-reproduce-its-absent-branch covers *reproducing* a CI-only
  tool-absent failure locally; it does not cover how to write the skip guard, the
  strict switch, or the known-bad pairing. Linked, not merged.
- history-dependent-checks-on-shallow-clones has an "honest skip" for shallow
  clones and asks to print the skip in CI — a different trigger (git history), no
  strict switch. Linked.
- release-gates says a skipped test is an unevaluated gate (release level). Linked.
- tests-that-cannot-fail is the general "can this test fail?" page; it is 138 lines
  (over the 120-line cap) and is also edited by open PR #300, so it was not touched.

Result: **new page** `wiki/testing/quality/tests-gated-on-an-external-validator.md`.
Related link added both ways with debugging-methodology-hiding-a-tool-to-reproduce-its-absent-branch.
No conflicting directive found.

## Open-PR check

Open `knowledge/*` heads at run time (25): #340, #335, #334, #332, #331, #330, #329,
#328, #324, #319, #318, #317, #315, #310, #309, #308, #307, #306, #305, #304, #301,
#300, #299, #298, #293. This headless run read each PR's title and touched files
(`gh pr list --json files`) and grepped the diffs of #300, #306 and #317
(`gh pr diff`) for skip/docker/validator content; it did not git-diff them.

| Candidate | Overlapping open PR | Verdict |
|-----------|--------------------|---------|
| fc76dc4dfa08ecde — Docker-gated validator skip vs fail | #300 and #317 edit tests-that-cannot-fail / checks-that-cannot-pass, but their diffs contain no skip-guard, Docker, or validator content; #306 is a pip `--require-hashes` known-bad test | **new** |
| ea0395bace6acb63 — re-measure suite runtime before setting a gate timeout | #330 "size a gate's per-CHECK timeout when one CHECK runs the suite N times" | **pending duplicate** → claim released, not ingested |
| 3854abb03a001de5 — measure idle-gap latency for interactive inference on Apple Silicon | #335 "measure CPU vs MPS (fp32/fp16) p95 before choosing an Apple Silicon inference device" | **pending duplicate** → claim released, not ingested |
| b5863e2d758c98fb — Claude Code behind a gateway still sends bootstrap calls with a leftover claude.ai login | #328 (child claude env, gateway proxy), #298 (gateway alias resolution) | **pending duplicate** → claim released, not ingested |

## Routing decision

- fc76dc4dfa08ecde → `testing/quality/tests-gated-on-an-external-validator.md` (new
  page in the existing `quality` category, which holds the "can this test detect a
  defect / is this green real" pages). `wiki/testing/index.md` row added; `log.md`
  ingest line added. No new category.

## Local-layer candidates

none
