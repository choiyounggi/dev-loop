# Knowledge flush — 5 insight(s)

All five were harvested from real sessions. Three merged into
`testing/quality/tests-that-cannot-fail`, one into `testing/data/test-data-and-isolation`,
one into `backend/common/reliability/timeouts-and-retries`. **No new page and no new
category** — every case had an existing home whose "load when" already overlapped.

## Verified best-practice

### 1. A runner that invokes the subject differently than production → `verified`

**Claim.** A bats suite that calls `bash "$script"` on a `#!/bin/sh` file cannot detect
bashisms, because the shebang is bypassed; a green run is evidence about bash only.

**How verified.** Reproduced locally rather than argued. A one-line `#!/bin/sh` script
containing `[[ ... ]]`:

| Invocation | Result |
|---|---|
| `./s.sh` (direct — shebang honoured; macOS `sh` is bash in POSIX mode) | ran the bashism |
| `bash s.sh` | ran the bashism |
| `dash s.sh` (true POSIX) | `s.sh: 2: [[: not found` |

The mechanism is documented: the `#!` interpreter directive is applied by the kernel
when a file is *executed*; passing the file as an argument to an interpreter means the
interpreter reads it and the directive never participates
(<https://man7.org/linux/man-pages/man2/execve.2.html>).

**Confidence: verified** (reproduced + documented mechanism).

### 2. A scripted mutation that never applied ≠ a blind test → `verified`

**Claim.** When a mutation run drives edits with `sed`/`awk`, a pattern that matches
nothing exits 0 and changes nothing, so the suite stays green for the trivial reason
that the code is unchanged — indistinguishable from "the tests cannot fail".

**How verified.** Reproduced: `sed -i '' 's/NEVER_MATCHES/x/' f.txt` → exit status **0**,
file byte-identical. POSIX and GNU both define sed's exit 0 as "completed without error",
not "substituted something"
(<https://www.gnu.org/software/sed/manual/html_node/Exit-status.html>,
<https://man7.org/linux/man-pages/man1/sed.1p.html>).

**Confidence: verified.**

### 3. Mutate an error-code guard toward *unreachable*, not *always-firing* → `field-tested`

**Claim.** Mutating `if [ "$x" != "ok" ]; then exit 6; fi` so the guard fires *more*
leaves the exit-code test green — it asserts "exits 6", and the mutant produces more
6s. Only making the guard unreachable answers "does this test go red without the guard".

**How verified.** No external source states this direction rule; it follows from the
mutation-testing notion that a mutant which cannot change observable behavior is not a
useful mutant (<https://stryker-mutator.io/docs/mutation-testing-elements/equivalent-mutants/>,
already cited by the sibling page `harness-reverse-controls`). The session evidence is
concrete: five exit-6 tests stayed green under an always-firing mutation, and all five
went red under the never-firing one.

**Confidence: field-tested** — the reasoning is sound and the observation reproducible in
that repo, but the rule itself is not stated in a primary source.

### 4. `env VAR=x cmd` inherits the caller's environment → `verified`

**Claim.** A test case that assumes a variable is *absent* silently flips when the suite
runs from a session that exports it, because `env` merges rather than replaces.

**How verified.** POSIX is explicit: `name=value` arguments "shall be placed into the
**inherited** environment", and only `-i` makes `env` ignore the inherited environment
completely (<https://pubs.opengroup.org/onlinepubs/9699919799/utilities/env.html>,
<https://www.man7.org/linux/man-pages/man1/env.1p.html>). Reproduced locally:
`env OTHER=1 sh -c 'echo $LEAKED'` printed the caller's value; `env -i` printed nothing.

**Confidence: verified.**

### 5. A client-side throttle that the auth path bypasses → `field-tested`

**Claim.** Token/auth refresh usually happens inside a header builder or interceptor,
below the throttle layer, so the token POST and the real call land in the same second and
deterministically breach a 2-per-second cap — but only on days the token cache is cold,
which makes it read as intermittent.

**How verified.** This is an architectural observation about where a refresh sits
relative to a rate limiter, not a claim any vendor doc makes; searching for a primary
source that states it turned up none. The session evidence is a specific timeline
(token POST 00.354 → issued 00.495 → balance call failed 00.543, on the two days the
token was newly issued; identical code fine on cache-valid days).

**Confidence: field-tested** — recorded as such on the page, not upgraded.

## Existing-layer check

**Pages read before deciding:** `INDEX.md`; `wiki/testing/index.md`;
`testing/quality/tests-that-cannot-fail`, `testing/quality/harness-reverse-controls`,
`testing/data/test-data-and-isolation`; `wiki/platforms/index.md` and
`platforms/shells/portable-shell-scripts`; `wiki/backend/index.md`,
`backend/common/reliability/timeouts-and-retries`; `wiki/debugging/index.md`.

**Overlaps found, and what they changed:**

- `platforms/shells/portable-shell-scripts` **already** carries the platform half of
  insight 1 — "`#!/bin/sh` script passes on macOS, fails on Debian/Ubuntu … test under
  dash". Duplicating it there would have added nothing. What is *not* covered anywhere is
  that a test suite invoking `bash "$script"` is structurally incapable of catching it,
  which is a "can this test detect a defect" question. Merged into
  `tests-that-cannot-fail`'s never-fails table and cross-linked to the platforms page
  (added to its `related:`).
- `tests-that-cannot-fail` step 1 already prescribes manual mutation testing, and its
  edge-case table already routes self-built mutation harnesses to
  `harness-reverse-controls`. Insights 2 and 3 are failure modes *of that step*, so they
  became two `Edge cases` rows there rather than a new page — `harness-reverse-controls`
  answers a different question (whether to cite a harness's score).
- `test-data-and-isolation` already has "environment variables **mutated by** a test →
  set in setup, restore in teardown". Insight 4 is the opposite direction: a test that
  never touches the variable and depends on its absence. Added as its own row beside it.
- `timeouts-and-retries` covers outbound-call governance including capping concurrency.
  No rate-limiting page exists anywhere under `backend/`, and insight 5 is one edge case
  rather than a page's worth, so it merged there and links to
  `debugging/concurrency/intermittent-failures` (the "reads as intermittent" half).

**Conflicts flagged:** none. No new directive contradicts an existing one.

**Related-links added:** `tests-that-cannot-fail` → `platforms-shells-portable-shell-scripts`;
`timeouts-and-retries` → `debugging-concurrency-intermittent-failures`.

## Routing decision

| # | Insight | Domain / category | Page | New page? |
|---|---------|-------------------|------|-----------|
| 1 | Runner invokes the subject differently than production | testing / quality | `tests-that-cannot-fail` (never-fails table) | merged |
| 2 | Assert the scripted mutation actually landed | testing / quality | `tests-that-cannot-fail` (edge cases) | merged |
| 3 | Mutate a guard toward unreachable, not always-firing | testing / quality | `tests-that-cannot-fail` (edge cases) | merged |
| 4 | `env VAR=x` inherits; `unset` in setup | testing / data | `test-data-and-isolation` (isolation table) | merged |
| 5 | Auth refresh bypasses the client-side throttle | backend / reliability | `timeouts-and-retries` (edge cases) | merged |

**No new category.** Insight 1 was the only real routing question — testing vs platforms.
It went to testing because the directive is about what a suite can prove, and the
platforms page already owns the portability fact it would otherwise duplicate.

Plumbing: `wiki/testing/index.md` and `wiki/backend/index.md` "load when" lines widened
so the new triggers actually route; three `log.md` entries added. All three edited pages
remain well under the 120-body-line limit (61 / 59 / 68).
