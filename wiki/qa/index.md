# qa — Domain Index

Route here for: release-quality process — acceptance criteria, gates,
regression scoping, test-environment parity, post-release verification, bug
reports, manual/exploratory testing, and automated verification of document
deliverables (specs/RFCs). Writing automated test code → wiki/testing/;
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
| [scope-purity-checks](process/scope-purity-checks.md) | Proving a change/session/agent run touched nothing outside an allowed path set by filtering `git status --porcelain` output; a purity gate flags `?? dir/` for a directory that is wholly in scope; writing such a gate for an orchestration/CI workflow |

## deliverables

| Page | Load when |
|------|-----------|
| [generated-artifacts-as-deliverable-source](deliverables/generated-artifacts-as-deliverable-source.md) | Asked to produce a document (ERD, schema reference, API surface list, dependency inventory) for a hand-off, review, or external partner when the repo already generates that content from code; deciding whether to re-run a stale generator or hand-write the deliverable; a hand-written reference document disagrees with the live system (checks that gate a document → document-verification) |

## document-verification

| Page | Load when |
|------|-----------|
| [spec-document-gates](document-verification/spec-document-gates.md) | Deciding whether passing a doc gate is enough to accept the deliverable: a document passed its checklist but the requirement is still unmet; choosing what the gate must assert beyond keyword presence (table structure, MUST-vs-SHOULD demotion, closed-set completeness, cross-section consistency); setting the release policy a gate verdict feeds (authoring or validating the check code itself → wiki/testing/quality/spec-artifact-checks.md, wiki/testing/quality/checks-that-cannot-pass.md) |
| [editing-a-gated-document](document-verification/editing-a-gated-document.md) | Editing or rewording a document that grep/regex gates or a lint config check; a gate fails on wording whose meaning did not change; describing what an upstream spec says without tripping a "do not redefine it" gate; a check matches the pattern your own document quotes; recording an audit verdict inside the document that was audited; deciding which checks to re-run after editing a gated document |

## environments

| Page | Load when |
|------|-----------|
| [test-environment-parity](environments/test-environment-parity.md) | A bug reproduces only in production; planning what a staging environment must mirror; deciding whether a staging pass clears a release |

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
