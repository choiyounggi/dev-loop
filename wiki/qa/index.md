# qa — Domain Index

Route here for: release-quality process — acceptance criteria, gates,
regression scoping, test-environment parity, post-release verification, bug
reports, manual/exploratory testing, evidence for completion claims, acting on
code-review feedback, adversarial review of high-risk diffs, and automated
verification of document deliverables (specs/RFCs). Writing automated test code → wiki/testing/;
rollout/canary/rollback mechanics → wiki/infrastructure/.

Match your situation to a "load when" line; load only matching pages.

## process

| Page | Load when |
|------|-----------|
| [acceptance-criteria](process/acceptance-criteria.md) | Writing or reviewing a feature ticket/user story before development starts; "done" is disputed at QA time; a delivered feature technically works but misses the intent |
| [release-gates](process/release-gates.md) | Deciding whether a build/release is ready to ship; defining or reviewing the checklist that makes that decision |
| [regression-scope](process/regression-scope.md) | Choosing what to re-test for a release/change when full regression is too expensive; reviewing someone else's proposed regression scope |
| [severity-and-priority](process/severity-and-priority.md) | Triaging a bug — deciding how bad it is and when it gets fixed; a triage stalled on a severity debate |
| [post-release-verification](process/post-release-verification.md) | A release just deployed to production; defining what "released safely" means; an incident revealed a release was broken for hours before anyone noticed |
| [scope-purity-checks](process/scope-purity-checks.md) | Proving a change/session/agent run touched nothing outside an allowed path set by filtering `git status --porcelain` output; a purity gate flags `?? dir/` for a directory that is wholly in scope; writing such a gate for an orchestration/CI workflow; a purity check in a permanent test suite fails on unrelated uncommitted files |
| [defect-class-resweep-after-review](process/defect-class-resweep-after-review.md) | Addressing review findings when the remediation itself adds code (a new function, branch, call site, formatter); about to hand that diff to a verifier, an audit, or CI as "review comments addressed"; deciding whether a bot's acknowledged/resolved thread means the class is closed; reporting fix completeness as a class-with-method count rather than a per-finding list |
| [completion-claims](process/completion-claims.md) | About to report work as done, fixed, or passing — to a human, a coordinator, a PR, or a commit message; about to write "should work" or "tests pass" without a fresh run; deciding what evidence a completion claim requires; relaying a subagent's success report |
| [evaluating-review-feedback](process/evaluating-review-feedback.md) | Review findings arrived (human, bot, or reviewer agent) and you are deciding what to implement; a finding is unclear; a reviewer proposes robustness or features nothing uses; you disagree with a finding and are deciding how to respond |
| [adversarial-change-review](process/adversarial-change-review.md) | Reviewing a diff ≥50 changed lines or one touching auth/payments/migrations/external APIs; a checklist review found nothing on a high-blast-radius change; deciding review depth for a risky diff; constructing failure scenarios (assumption violation, composition, cascade, abuse); per-task lens reviews all passed on a diff that builds a command/query/path from user input through an allowlist |
| [llm-review-pipelines](process/llm-review-pipelines.md) | Building or configuring an automated LLM code-review pipeline (CI review bot, review skill, PR-reviewer agent); review token cost grows with changeset size; deciding which stages run as deterministic code vs model judgment; keeping review rules as matchable data not prompt prose; model-written comments land on wrong lines; measuring a precision-vs-recall threshold change |
| [fresh-context-code-review](process/fresh-context-code-review.md) | Reviewing code, a plan, or a document an LLM session just produced; deciding whether the producing session, a repeated same-session pass, or a context-sharing subagent may serve as reviewer; designing which session an automated review stage dispatches to |

## deliverables

| Page | Load when |
|------|-----------|
| [quantitative-claims-in-a-published-document](deliverables/quantitative-claims-in-a-published-document.md) | About to publish or hand out a hand-maintained document that states counts about the repository (README, landing page, launch post, architecture overview) — tests, rules, supported types, grammar productions, endpoints, documents in a given state; one number in such a document was reported wrong and you are deciding the scope of the fix; deciding how to publish a count that moves between runs, or which of two disagreeing sources (spec vs implementation) a sentence's number comes from |
| [generated-artifacts-as-deliverable-source](deliverables/generated-artifacts-as-deliverable-source.md) | Asked to produce a document (ERD, schema reference, API surface list, dependency inventory) for a hand-off, review, or external partner when the repo already generates that content from code; deciding whether to re-run a stale generator or hand-write the deliverable; a hand-written reference document disagrees with the live system (checks that gate a document → document-verification) |
| [command-transcripts-in-a-document](deliverables/command-transcripts-in-a-document.md) | Pasting a captured CLI run into an RFC, README, or design doc as a worked example; the transcript shows program output and diagnostics together; a reviewer re-running a documented example gets a different order or extra lines; a documented example is being used to argue that one line appears before another |
| [exclusivity-and-absence-claims](deliverables/exclusivity-and-absence-claims.md) | About to write or review a sentence claiming exclusivity or absence in a spec/RFC/README ("the only way is Y", "exactly two forms", "this cannot be expressed", "no path produces Z"); a reader reports a case the document calls impossible; deciding whether to enumerate forms or state the rule that generates them |

## document-verification

| Page | Load when |
|------|-----------|
| [spec-document-gates](document-verification/spec-document-gates.md) | Deciding whether passing a doc gate is enough to accept the deliverable: a document passed its checklist but the requirement is still unmet; choosing what the gate must assert beyond keyword presence (table structure, MUST-vs-SHOULD demotion, closed-set completeness, cross-section consistency, agreement with a code constant the document copies); a gate over a table asserts the property the table itself claims; setting the release policy a gate verdict feeds (authoring or validating the check code itself → wiki/testing/quality/spec-artifact-checks.md, wiki/testing/quality/checks-that-cannot-pass.md) |
| [generated-reference-drift-gates](document-verification/generated-reference-drift-gates.md) | Writing or reviewing the reference material that enumerates a closed vocabulary an agent will emit tokens from (DSL verbs, config keys, diagnostic codes, enum members) in a plugin/skill/SDK; deciding whether to hand-write that list or generate it from the owning constant; choosing what gates a generated document beyond a `--check` diff; a documented token compiles to a silent no-op instead of an error |
| [retiring-a-provisional-marker](document-verification/retiring-a-provisional-marker.md) | Turning provisional markers (`[추정]`, TBD, "assumed", DRAFT) into settled statements in an ADR/RFC/spec that has been through review rounds, so the document also carries a review checklist and a round history referring to those markers; a checklist row stayed `[x]` on evidence you just deleted; a coordinator's marker count and yours disagree while you read the same file |
| [editing-a-gated-document](document-verification/editing-a-gated-document.md) | Editing or rewording a document that grep/regex gates or a lint config check; a gate fails on wording whose meaning did not change; reflowing prose a test asserts as a verbatim phrase (CI red on one platform only); describing what an upstream spec says without tripping a "do not redefine it" gate; a check matches the pattern your own document quotes; recording an audit verdict inside the document that was audited; deciding which checks to re-run after editing a gated document |

## environments

| Page | Load when |
|------|-----------|
| [test-environment-parity](environments/test-environment-parity.md) | A bug reproduces only in production; planning what a staging environment must mirror; deciding whether a staging pass clears a release |
| [headless-browser-bot-blocking](environments/headless-browser-bot-blocking.md) | QA/dogfooding an external production site through a headless browser shows an intact page shell but empty lists/data with generic "temporary delay" toasts; deciding between "their server is down" and "our client is classified as a bot"; data APIs alone return 4xx while static assets load |
| [browser-console-capture-gaps](environments/browser-console-capture-gaps.md) | About to read a browser-automation tool's console output as a QA verdict ("no errors", "the script never ran"); the collected list is empty for a page known to log on load; deciding when the collector attaches and whether to clear+reload; judging whether a browser extension's content script executed when its logs never appear |


## bug-reports

| Page | Load when |
|------|-----------|
| [reproducible-reports](bug-reports/reproducible-reports.md) | Writing a bug report; triaging incoming reports that can't be acted on as written |

## exploratory

| Page | Load when |
|------|-----------|
| [exploratory-sessions](exploratory/exploratory-sessions.md) | A new feature needs testing beyond its scripted checks; you have test time available and want maximum new information per hour |
| [guard-true-path-coverage](exploratory/guard-true-path-coverage.md) | QA-ing a program whose steps hide behind `when`/`until` guards in a pipeline whose compile/validation stages do not resolve cross-node references; a guarded step has never executed in any green run being cited |
| [lowered-declaration-survival](exploratory/lowered-declaration-survival.md) | A compiler/DSL accepted stacked declarations (consecutive guards, policies, annotations) with exit 0 and no diagnostic; about to trust runtime behavior that depends on all of them; a run honored only one of several declared rules |
| [override-control-pairs](exploratory/override-control-pairs.md) | Measuring branch/guard behavior through a matrix of name-based runtime value overrides (`--field k=v`, env overlays) into a consumer that ignores unknown keys; every variant in the matrix returns identical observations |
