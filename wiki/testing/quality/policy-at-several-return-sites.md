---
id: testing-quality-policy-at-several-return-sites
domain: testing
category: quality
applies_to: [general]
confidence: verified
sources:
  - https://raw.githubusercontent.com/nedbat/coveragepy/master/doc/branch.rst
  - https://pitest.org/quickstart/basic_concepts/
  - https://stryker-mutator.io/docs/mutation-testing-elements/supported-mutators/
last_verified: 2026-08-06
related: [testing-quality-tests-that-cannot-fail, testing-quality-minimum-case-set, testing-quality-harness-reverse-controls, backend-common-change-impact-call-site-enumeration]
---

# Covering a Policy Applied at Several Return Sites of One Handler

## When this applies

One function applies the same policy at more than one of its own success
returns — a CLI handler that computes an exit code (`--strict`, `--check`) and
returns it from three branches, a controller that stamps the same header on
several 200s, a resolver that tags each of its result shapes. Also when you are
judging whether an existing suite covers such a flag, or a reviewer asks "is the
flag tested?" and the answer so far is one green test.

## Do this

1. **Enumerate the handler's success-return sites before writing any test**,
   reading them out of the function body rather than from the flag's
   documentation. One site per `return` that can carry the policy, including the
   early ones. The list is the page's working output — write it down, because
   the case count comes from it, not from the input space.
2. **Write one test per site, each driving the argument combination that reaches
   that site and only that site.** Case selection here is by *exit path*, not by
   input boundary — the normal/error/boundary set of
   [testing-quality-minimum-case-set] still applies per behavior and does not
   replace this axis, because two sites can share every input class and differ
   only in which branch ran.
3. **Prove each test by reverting its own site and requiring exactly that test to
   redden.** Replace that one call with the bare pre-policy value
   (`return _strict_rc(...)` → `return 0`); leave the other sites intact. Read
   the result per site:

| Mutation outcome | Read it as | Do |
|------------------|------------|-----|
| Exactly that site's test reddens, others stay green | That site is covered and the test discriminates | Record the pair (site → test) and move to the next site |
| The suite stays fully green | No test exercises that return — the untested-line case, not a weak assertion | Add the test for that site, then re-run the same mutation |
| A different site's test reddens | Your case does not reach the site you meant | Fix the argument combination until the intended test is the one that fails |
| Every test reddens | The mutation hit shared code, not one site | Narrow the edit to the single call and re-run |

4. **Restore from a pre-mutation copy and compare hashes, then confirm the suite
   total rose by the number of tests you added** — a restore that dropped an
   import reads as a green run with a smaller total
   ([testing-quality-tests-that-cannot-fail], steps 3–4).
5. **Cite the coverage as sites, not as a percentage** — "3/3 return sites of
   `cmd_spec`, each proven by its own reversion" — so the claim states what was
   measured and a reviewer can re-run any one of them.

## Edge cases

| Case | Then |
|------|------|
| Two sites are genuinely the same path (one is a `goto`-style fallthrough) | Merge them into one site in the list and say so in the test name; do not write a duplicate case that re-proves the same fact |
| A site is unreachable through the public interface | Do not force it — either delete the dead return or move the test to the level that can reach it ([testing-quality-behavior-not-implementation]); an unreachable site's mutation survives forever and reads as a permanent gap |
| The handler is refactored so all sites funnel through one wrapper | Re-run the per-site mutations once after the refactor: the sites collapsed, so the site list — and the case count it justified — changed |
| A new branch adds a fourth return during review | Treat the missing per-site test as the review finding; the existing three staying green is exactly the signal that does not fire |
| The policy is applied at error returns too | Enumerate those as sites as well; an error path that skips the policy fails the same way and is usually the one CI actually hits |
| You can only mutate via a script | Assert the edit landed before reading the verdict — a pattern that matches nothing still exits 0 ([testing-quality-tests-that-cannot-fail]) |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Write one test for the flag and call the flag tested | Enumerate the return sites and write one test per site | The other sites are gated but unverified: deleting the policy from them keeps the suite fully green, so the gate silently stops firing on the paths CI uses |
| Read 100% statement coverage of the handler as proof every return is exercised | Read branch/exit coverage, or run the per-site mutation | Statement coverage counts lines executed, not jumps taken — coverage.py's own example reaches every line while one branch is never taken |
| Seed one mutation for the whole handler and watch the file go red | Revert one site at a time and require its owning test | A file-level red is produced by whichever site is already covered; the silent ones stay silent |
| Treat a surviving mutation at an uncovered site as a weak assertion | Treat it as no covering test at all and add the case | PIT keeps these as different states: "No coverage" means no test exercised that line, which is a missing case rather than a defective assertion |

## Sources

- https://raw.githubusercontent.com/nedbat/coveragepy/master/doc/branch.rst — the statement-vs-branch example: "Statement coverage would show all lines of the function as executed. But the `if` was never evaluated as false, so line 2 never jumps to line 4"; branch coverage "will flag this code as not fully covered because of the missing jump … This is known as a partial branch"
- https://pitest.org/quickstart/basic_concepts/ — "'Survived' means the mutation was not detected by the covering test"; "'No coverage' is the same as **Survived** except there were no tests that exercised the line of code where the mutation was created" — the two verdicts a per-site reversion distinguishes
- https://stryker-mutator.io/docs/mutation-testing-elements/supported-mutators/ — the Block Statement mutator "removes the content of every block statement", i.e. deleting the statement at one site is a standard mutation operator rather than an ad-hoc edit
- Field measurement 2026-08-06 (linkly `impl/lnpl/cli.py`, `cmd_spec` returning 0 from three branches: `-o` without `--run`, stdout dump, and `--run` with all cases passing): reverting the two no-run `_strict_rc(...)` calls to bare `return 0` left 10 tests passing and reddened exactly the 2 new path-specific tests; before those tests existed the same reversion reddened nothing. The file was restored from a pre-mutation copy with an identical `sha256`, and the suite total rose 1272 → 1275 rather than dropping
