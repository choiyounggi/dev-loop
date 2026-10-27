# Knowledge flush — 1 insight(s)

Headless auto-flush run (claimed by run `20261027-153900-24217`): 26 rows claimed —
1 ingested, 21 dropped as project-specific plan-gaps, 4 released as plausible
duplicates of open knowledge PRs.

## Verified best-practice

**3cadd01011d4cb6e — the known-bad test for `pip install --require-hashes`.**
Claim: to prove a hash-pinned lockfile rejects tampering, replace every `--hash`
of the chosen package (wheel and sdist) and install into a fresh venv
(`python -m venv --clear`); require rc 1 plus `THESE PACKAGES DO NOT MATCH THE HASHES`.

- "Any one listed hash is enough" — pip's secure-installs docs, section
  "Multiple hashes per package" (https://pip.pypa.io/en/stable/topics/secure-installs/):
  a requirement may carry several `--hash` values, one per alternative archive, and
  pip's original hash-checking change states at least one hash must match per
  requirement. So tampering one hash leaves a matching one and the install passes.
- "An already-installed package is not hash-checked" — pypa/pip#7172
  (https://github.com/pypa/pip/issues/7172) documents that `--require-hashes` does
  not re-verify what is already in the environment. No official docs page states the
  "Requirement already satisfied" skip in those words; this half rests on the
  issue plus the session's reproduction.
- Session reproduction (linkly t243, 2026-10-27): one-hash tamper → rc 0; all-hash
  tamper in the reused venv → rc 0 with "Requirement already satisfied: attrs==26.1.0";
  all-hash tamper in a `--clear` venv → rc 1 with the hash-mismatch error.

Confidence: verified for the any-one-hash rule (docs); field-tested for the
reused-venv skip (issue + reproduction). Written into the page as an edge row
that names the field case; the page's own `confidence: verified` and
`last_verified` are unchanged.

## Existing-layer check

wiki_search for the trigger ("pip require-hashes lockfile tamper negative control
hash-checking mode", k=5) returned: security-dependencies-supply-chain (0.758),
platforms-toolchains-version-management (0.738),
backend-python-language-bytecode-cache-staleness (0.737),
platforms-processes-lock-owner-pid-from-the-holding-process (0.727), and a
second section of platforms-toolchains-version-management (0.720). Only the first covers hash-pinned
installs; the others are toolchain pinning, `.pyc` staleness and lock ownership.

security-dependencies-supply-chain already says "install with hash-pinned
requirements" (Do this #1) but has nothing on how to test that the pinning works.
Same trigger area, same directive direction, new edge → merged as one edge-case
row plus one new source (pypa/pip#7172); no new page. No conflict with an existing
directive. The security index "load when" line for supply-chain was extended.

Pages read: security-dependencies-supply-chain

## Open-PR check

Open `knowledge/*` heads (from `gh pr list`, file lists via `--json files`):
#305 (qa/document-verification/superseding-a-knowledge-record),
#304 (qa/process/completion-claims), #301 (security/input, testing/quality/ci-workflow-step-behavior-tests,
backend idempotency), #300 (testing/quality/checks-that-cannot-pass, tests-that-cannot-fail,
new-test-outside-a-runner-include-filter, security/secrets, …), #299 (platforms/tools/search-evidence-from-a-wrapped-grep,
command-guard exemptions, …), #298 (backend/infrastructure/platforms config pages),
#293 (testing/quality/diff-algorithm-dependent-line-counts, json-manifest-edit-gates).
This headless run cannot diff PR content, so plausible overlap counts as a pending duplicate.

| Row | Candidate | Overlapping open PR | Verdict |
|-----|-----------|--------------------|---------|
| 3cadd01011d4cb6e | pip `--require-hashes` known-bad test | none touches security/dependencies or pip | new |
| f332524447ff2105 | grep self-match of a gates ledger; `grep` shell function hides it | #299 search-evidence-from-a-wrapped-grep | released (pending duplicate) |
| c9e00eb2a93a55e3 | checker and composer sharing hand-typed source ranges | #300 tests-that-cannot-fail / checks-that-cannot-pass; #305 document consolidation | released (pending duplicate) |
| b3a7b01998f7d6aa | whole-line "history" exemption hides a citation in a checker | #300 tests-that-cannot-fail; #305 citation handling in a superseding document | released (pending duplicate) |
| bdb042f44f413d06 | mutation harness copied-tree list missing a new root file | #300 checks-that-cannot-pass / new-test-outside-a-runner-include-filter | released (pending duplicate) |

No fold into another branch in this headless run.

## Routing decision

- 3cadd01011d4cb6e → `security/dependencies/supply-chain.md`, new edge row. The
  existing dependencies category owns lockfile/hash-pinning; no new category needed.
  The directive is general (any project using `pip --require-hashes`), so it
  belongs to the bundled wiki.

## Local-layer candidates

21 claimed rows are wiki-plan "no owning wiki page" plan-gap records whose
directives name one project's files and RFC line numbers. Dropped from this PR and
retired in place (full rows stay in `~/.dev-loop/queue/plan-gaps.jsonl`):

- linkly (scoter) t73 — 7cb165ad3739c095, d1d7462e0ef491d3, 553658745f645d1d,
  751ec8f2d58a6489, fa32d25f64f17866, 319c80e5750f7148, 5ded3966bee42a08 →
  `wiki-local/qa/document-verification/<slug>.md` in linkly if wanted; run wiki-ingest inside that project
- linkly (scoter) t74 — 5910c088745be2f9, bbd0f966ca9a8a84, 58bacc64c53f5682,
  3e330837af36af36, bc39bf5b6cfdf803, 523a2b2f3a4033af, c0fe7ec7917c4b6f → same target; run wiki-ingest inside that project
- linkly (scoter) t75 — 236b8407f47d44c8, 1c042f50b8e3e1d7, bd77532c3ccfd467,
  79f7c16283a2effa, 3ae2c8870f461135, e2e2bf774be3fb69 → same target; run wiki-ingest inside that project
- claude-account-rotator t1 — 5828fec18f1b5d3d (lazy `readStdin()` in a CLI
  command context) → `wiki-local/backend/node/<slug>.md` in claude-account-rotator; run wiki-ingest inside that project
