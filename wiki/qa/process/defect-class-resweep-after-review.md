---
id: qa-process-defect-class-resweep-after-review
domain: qa
category: process
applies_to: [general]
confidence: verified
sources:
  - https://www.eecg.utoronto.ca/~yuan/papers/incorrect_fix_abstract.html
  - https://dl.acm.org/doi/10.1145/2025113.2025121
last_verified: 2026-08-11
related: [qa-process-regression-scope, backend-common-change-impact-call-site-enumeration, testing-quality-tests-that-cannot-fail]
---

# Re-Sweeping the Reviewed Defect Class Across Your Own Remediation Diff

## When this applies

You are addressing review findings and the remediation itself adds code — a new
function, a new branch, a new call site, a new formatter. Also when you are about
to hand that diff to a verifier, an audit, or CI as "review comments addressed".

Choosing what to *re-test* for the release around it →
[qa-process-regression-scope].

## Do this

1. **Name the class each finding belongs to, in the finding's own words** —
   "raw external string reaches the error message", "list call with no bound",
   "await missing on the returned promise". The finding cites instances; the class
   is what the reviewer was actually objecting to, and it is the searchable unit.

2. **Re-run each class's search over the whole file after the edit, including the
   lines you just wrote.** The review indexed the code as it stood when it was
   read, so anything the remediation added is outside its index — closing the
   class in one function while opening it in a sibling function happens inside a
   single round.

3. **Report the class, not the line**: "class X occurs at N sites in this module;
   all N carry the fix; method: `grep <pattern>` over `<paths>`". A per-finding
   "fixed" list cannot be checked against the class
   ([backend-common-change-impact-call-site-enumeration] for stating the
   enumeration method next to the count).

4. **Turn a class with two or more sites into one shared helper plus one test that
   asserts the property at every site**, so the next round's new site inherits the
   fix instead of needing to be found again
   ([testing-quality-tests-that-cannot-fail] for making that assertion able to
   fail).

5. **Read the remediation diff as unreviewed code.** It was written under time
   pressure, has no review history, and — measured across large OS code bases —
   "at least 14.8% to 24.4% of sampled fixes for post-release bugs … are
   incorrect", with 27% of the incorrect fixes made by developers who "have never
   touched the source code files associated with the fix".

6. **Sweep the classes the remediation's *own* shape opens**, which the review
   never named because the code did not exist when it was read. Match the edit
   against its shape and run that class's check before handing the diff on:

| The remediation… | Opens the class | Check before handing it on |
|------------------|-----------------|----------------------------|
| Widens a fetch (adds a child/related lookup, drops a filter) | Unbounded result set | The new call paginates or caps, on the path that returns many |
| Adds an output line (log, stderr warning, message) | Unguarded path | Every branch reaching it has the values it formats, including the early-return one |
| Persists something new (id, marker, join row) | Orphaned record | The delete/rollback path clears it too |
| Replaces a literal with a parameter or placeholder | Unvalidated assembly | The assembled string is syntax-checked, not only the substitution |

## Edge cases

| Case | Then |
|------|------|
| The class has no textual signature (semantic, e.g. "value used before validation") | Write the throwaway predicate — an AST pass or a 30-line script over the module — and report its verdict list; the sweep is the artifact, the tool is disposable |
| The finding is a false positive you intend to rebut | Run the class sweep anyway and put its result in the rebuttal — a bounded class list is what makes "this instance is intentional" reviewable |
| Two findings in the round share one class | Remediate once through a shared path, then let the sweep count adoption per site rather than tracking the two findings separately |
| The remediation is a revert | Sweep the class after reverting too: a revert can restore a pre-existing instance that the forward change had removed |
| The reviewer is a bot that marks the thread acknowledged/resolved | Judge closure by grepping the file, not by thread state — an acknowledgement records a reply, not a diff |
| The class spans files you do not own in this task | Sweep them read-only, report the out-of-scope instances with paths, and open a follow-up task naming them |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Send the diff onward as soon as each cited line is fixed | Run each finding's class search over the post-edit file first | The citation is a sample of the class taken before your new code existed |
| Treat the previous round's approval as covering the fix | Read the remediation as unreviewed code and sweep it | Approval covered the code that was read; the fix is newer than the review |
| Fix exactly the lines the reviewer quoted | Fix the class in that module and report the count | A reviewer quotes what they happened to read; sibling sites keep the defect and reappear in the next round |
| Count "N findings resolved" as the completion metric | Count "class X: N sites, N remediated, method stated" | Finding counts measure the review's reach; class counts measure the code |

## Sources

- https://www.eecg.utoronto.ca/~yuan/papers/incorrect_fix_abstract.html — "at least 14.8% to 24.4% of sampled fixes for post-release bugs in these large OSes are incorrect" (Linux, OpenSolaris, FreeBSD, and a 12-year-old commercial OS); "Developers and reviewers for incorrect fixes usually do not have enough knowledge about the involved code. For example, 27% of the incorrect fixes are made by developers who have never touched the source code files associated with the fix"
- https://dl.acm.org/doi/10.1145/2025113.2025121 — Yin et al., "How do fixes become bugs?", ESEC/FSE 2011: the published record for the study above
- Field observation 2026-08-12 (PR #327, bot review rounds 13→14): 4 of round 14's 7 warnings were defects in round 13's remediation itself, one per shape in the step-6 table — a widened child re-query with no pagination, an added stderr warning on an unguarded path, a newly recorded `comment_id` that the delete path left orphaned, and a placeholderized JQL string whose assembly was never syntax-checked
- Field incident 2026-08-11 (Python validation engine, review round 1 → remediation): the finding was that a checker echoed a raw external string into its error message. The remediation closed that checker and, in the same round, added a sibling checker that echoed the same untrusted field. An independent audit reproduced it by passing a key containing a carriage return and reading the leaked original in the message; a grep for the class over the module after the edit would have listed both sites
