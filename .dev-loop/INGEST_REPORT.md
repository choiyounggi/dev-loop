# Knowledge flush — 3 insight(s)

2 ingested here, 1 folded into open PR #52 (no sibling duplicate opened).

## Verified best-practice

### I1 — an adapter's required-field set comes from running the consumer, not from its docstring

**Claim.** When mapping one module's records into a second module's payload, call the
real consumer once with a mapped record before writing the rest of the adapter, then
split the fields it reads into *loud* (presence check / direct subscript → raises on
the first record) and *silent* (read with a default → no error, wrong value), and give
every silent field its own two-run assertion.

**Sources checked (opened this session).**

- https://docs.pact.io/ — "The contract is generated during the execution of the
  automated consumer tests"; contract tests "check that all the calls to your test
  doubles return the same results as a call to the real application would"; and
  "unlike a schema or specification (eg. OAS), which is a static artefact that
  describes all possible states of a resource, a Pact contract is enforced by
  executing a collection of test cases, each of which describes a single concrete
  request/response pair." This is the source for preferring an execution over the
  documented shape.
- https://json-schema.org/understanding-json-schema/reference/object — "By default,
  the properties defined by the `properties` keyword are not required." An example
  payload therefore carries no required/optional information at all.

**Verification.** Reproduced the loud/silent asymmetry locally (Python 3, 12-line
script): one consumer read `assignee_id` via `if "assignee_id" not in item: raise
ValueError` and `desc` via `item.get("desc", "")`. Dropping `assignee_id` raised on
the first record; dropping `desc` raised nothing and moved the returned score from
21.0 to 1.0. Field evidence from the harvest: the same mapping produced 100%
`ValueError` for the missing `assignee_id` and a silent 5.3x under-estimate
(1.63 → 0.31) for the missing `desc`.

**Not verified, and excluded from the page.** I attempted to cite the Python docs for
`dict.get` never raising `KeyError`; both fetches of
`docs.python.org/3/library/stdtypes.html` (with and without the `#dict.get` anchor)
returned content truncated before the Mapping Types section, so no quote was
available. The local reproduction stands in for it and no Python-docs URL is cited.

**Confidence: verified** (two official docs quoted + local reproduction).

### I2 — the cooldown mark belongs after a send that reported success

**Claim.** Write a notification-suppression mark only on a send whose status was
success; give the send its own exit status; make the send path injectable; assert the
succeeding-sender and failing-sender worlds as two separate tests.

**Sources checked (opened this session).**

- https://pkg.go.dev/github.com/prometheus/alertmanager/notify — the pipeline ordering
  is stated in the stage doc comments: `RetryStage` "notifies via passed integration
  with exponential backoff until it succeeds. It aborts if the context is canceled or
  timed out."; `SetNotifiesStage` "sets the notification information about passed
  alerts. **The passed alerts should have already been sent to the receivers.**";
  `DedupStage` "filters alerts. Filtering happens based on a notification log." So the
  log that suppression reads is written only after delivery — a production system
  stating exactly this ordering.
- https://runbooks.prometheus-operator.dev/runbooks/general/watchdog/ — the Watchdog is
  "an alert meant to ensure that the entire alerting pipeline is functional", "always
  firing", and "if not firing then it should alert external systems that this alerting
  system is no longer working." Supports the external-heartbeat step, not the ordering.
- https://prometheus.io/docs/alerting/latest/configuration/ — `repeat_interval` is
  keyed to a prior *notification*, not to a prior attempt.

**Not verified, and excluded from the page.** I tried to source the "the alerting
pipeline must not fail together with what it monitors" argument from
https://sre.google/sre-book/monitoring-distributed-systems/. The chapter does not say
it: it argues for monitoring being "kept simple and comprehensible" and for "distinct
systems with clear, simple, loosely coupled points of integration" between monitoring
and *other inspection tools*, which is a different claim. The correlated-failure point
is therefore stated in the page only as an Edge-cases row whose remedy is the Watchdog
heartbeat (which *is* sourced), and the SRE book is not cited for it.

**Verification.** Field measurement from the harvest, re-read against the code:
`rtb-mac-server-k8s bin/gitops-deploy.sh` wrote the `alert-main-fetch` marker after a
send whose webhook lookup had failed, so the next invocation suppressed the alert as
"in cooldown". Applying `notify "$@" || return 1` before the marker, in a copy outside
the repo, turned three existing tests red — the always-failing stub had fixed the
pre-send ordering as the expected contract.

**Confidence: verified** (Alertmanager stage contracts quoted from the package docs +
reproduced field measurement).

### I3 — source-text assertions must be made against code with comments removed (folded, see below)

**Claim as queued.** Strip comments from the source before asserting on it, using
`src.replace(/\/\*[\s\S]*?\*\//g,'').replace(/\/\/.*$/gm,'')`.

**Sources checked (opened this session).**

- https://eslint.org/docs/latest/extend/custom-rules — "While comments are not
  technically part of the AST, ESLint provides the `sourceCode.getAllComments()`..."
  and rules visit "nodes while traversing the abstract syntax tree (AST as defined by
  ESTree)". This is the mechanism: a structural check runs over a tree comments do not
  appear in, a text check runs over the file where they do.
- https://docs.semgrep.dev/writing-rules/pattern-syntax — "Semgrep automatically
  searches for code that is semantically equivalent" (constant propagation, AC
  matching). Supports "match the structure, not the characters"; it does **not** state
  anything explicit about comments, and the page does not claim it does.

**Verification — and a correction to the queued directive.** Measured 2026-08-10 in
Node against a fixture containing a JSDoc block, a line comment, and a URL string:

| Assertion | Raw source | After the queued strip regex |
|---|---|---|
| `<BlockDetailPanel` occurrence count (true value 1) | 2 | 1 |
| `/Number\.isFinite/` present (true value false) | true | false |

So the queued insight's premise reproduces exactly. But the same run showed the
queued regex is itself defective: it truncated
`const endpoint = "https://api.example.com//v2/items"` to `const endpoint = "https:`,
because `//` inside a string literal is consumed as a comment start. A string-aware
alternation variant fixed the URL and still truncated a regex literal containing `//`
(`const re = /a//b/` → `const re = /a`). The page therefore takes comment removal from
the language's own tokenizer/parser plus a control run, and records the regex form only
as an `Instead of` row with this measurement as the reason — shipping the queued
one-liner would have replaced a false-positive class with a silent-corruption class.

**Confidence: verified** (official ESLint docs quoted + reproducible Node measurement,
including the counter-measurement against the queued directive).

## Existing-layer check

Routed via `INDEX.md` → domain `index.md` for backend, infrastructure and testing, then
read every page whose "load when" line overlapped.

Pages read: backend-common-change-impact-call-site-enumeration,
backend-common-integrations-externally-owned-defaults,
backend-common-api-design-unenforced-declarations,
infrastructure-observability-alerting,
infrastructure-observability-logs-metrics-signals,
testing-quality-tests-that-cannot-fail, testing-quality-harness-reverse-controls,
testing-quality-guard-shape-vs-consequence, testing-quality-spec-artifact-checks,
testing-quality-behavior-not-implementation, testing-quality-minimum-case-set

Findings:

- **I1 vs `backend-common-change-impact-call-site-enumeration`** — adjacent but
  reversed. That page enumerates the call sites of a callee *you own and are changing*;
  I1 is about discovering the required inputs of a consumer *you do not own and are
  feeding*. Different trigger, so a new page, with a forward link from I1 and a
  "when you own the callee" pointer in its `When this applies`. I deliberately did not
  add the reciprocal `related:` id to that page: five open PRs (#68, #58, #52, #51,
  #50) already edit it, and a one-line frontmatter change there would be a pure
  conflict for the owner. The link is one-way by choice.
- **I1 vs `backend-common-integrations-externally-owned-defaults`** — same family
  (a name/shape the repo does not own), different failure. Cross-linked both ways;
  I1's step 5 hands off to it for the version-upgrade case.
- **I1 vs `testing-quality-unasserted-return-fields` (open PR #49)** — same mechanism
  on the opposite side of the call: #49 is about returned fields no assertion reads,
  I1 about input fields the consumer silently defaults. Kept distinct; see Open-PR
  check.
- **I2 vs `infrastructure-observability-alerting`** — no overlap in directive. That
  page decides *whether* a condition pages, tickets, or stays on a dashboard; it says
  nothing about where suppression state is written. New page in the same category,
  cross-linked both ways (`alerting`'s `related:` extended).
- **I2 vs `backend-common-jobs-idempotent-handlers`** — related mechanism
  (at-least-once + dedupe), different artifact; forward link only.
- **I3 vs `testing-quality-source-text-wiring-assertions` (open PR #52)** — direct
  overlap. See Open-PR check; folded, not duplicated.
- **Conflicts flagged: none.** No existing directive contradicts either new page.
  The one contradiction found this session was internal to the queue: candidate I3's
  own directive is falsified by its verification (above), so the folded text carries
  the corrected form and the reason.

New categories: none. Both pages land in existing categories
(`backend/common/integrations`, `infrastructure/observability`).

## Open-PR check

Listed via `gh pr list --repo choiyounggi/dev-loop --state open --search "head:knowledge/"`
— 15 open heads: #69, #68, #66, #64, #62, #61, #58, #57, #56, #55, #52, #51, #50, #49, #47.
Diffed each head's `wiki/` changes against `origin/main`; for the
two fork-hosted heads that `git fetch` could not resolve (#52, #49) I listed and read
the files through the GitHub API at each PR's head SHA instead.

| Candidate | Overlapping open head | Verdict |
|---|---|---|
| I1 — consumer required fields | #49 `testing/quality/unasserted-return-fields.md` (nearest); no open head touches `backend/common/integrations/` | **new** — #49 governs *returned* fields the suite never asserts; I1 governs *input* fields the consumer silently defaults. Different artifact, different trigger, and I1's primary directive (execute the consumer to learn its required set) has no counterpart in #49 |
| I2 — suppression mark after a successful send | none — no open head touches `infrastructure/observability/` | **new** |
| I3 — comments contaminate source-text assertions | #52 `testing/quality/source-text-wiring-assertions.md` | **fold** — pushed to that branch; not ingested here |

Fold detail for I3: #52's page already owns the trigger "a test reads a source file as
a string and asserts by regex". Its step 5 even prescribes the control that *detects*
this defect ("change a comment ... require green") but does not say what to do when
that control goes red, and its step 2 ("count the anchor's occurrences before using
it") is the step comments break — my fixture's JSDoc line took an anchor count from 1
to 2. The additions therefore belong on that page, not on a sibling. Because I own the
head repository (`dch0202-rsquare/dev-loop`), the commit went onto #52's branch and a
comment on #52 records what changed and why, so the owner reviews it in one pass.

## Routing decision

| Insight | Target | New category? |
|---|---|---|
| I1 | `backend` / `common/integrations` / `consumer-required-fields.md` (id `backend-common-integrations-consumer-required-fields`) | No. `integrations` is described in the domain index as consuming external-API responses and externally-owned defaults; an adapter feeding a module the repo does not own is the same boundary seen from the producing side. `change-impact` was rejected because its trigger is a callee you own and are changing; `api-design` was rejected because its pages are HTTP contract design |
| I2 | `infrastructure` / `observability` / `suppression-state-and-delivery-failure.md` (id `infrastructure-observability-suppression-state-and-delivery-failure`) | No. Sits beside `alerting` (which decides routing, not delivery bookkeeping). `backend/common/jobs` was rejected: the artifact is a notifier's suppression state, not a queue consumer |
| I3 | `testing` / `quality` / `source-text-wiring-assertions.md` **on open PR #52's branch** | No — fold, no new page |

Plumbing updated: `wiki/backend/index.md` (+1 row), `wiki/infrastructure/index.md`
(+1 row), reciprocal `related:` on `infrastructure/observability/alerting.md` and
`backend/common/integrations/externally-owned-defaults.md`, `log.md` (+1 entry).
Checked before commit: both new pages are under the 120-line body limit (76 and 78),
carry no banned vague qualifiers, and every `related:` id and inline `[page-id]`
reference resolves to a file in `wiki/`.
