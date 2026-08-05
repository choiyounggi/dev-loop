# qa — Domain Index

Route here for: release-quality process — acceptance criteria, gates,
regression scoping, enumerating what a signature/contract change touches,
test-environment parity, post-release verification, bug
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
| [enumerating-call-sites-of-a-changed-signature](process/enumerating-call-sites-of-a-changed-signature.md) | Changing a function/constructor signature or the shape of a structure it receives and migrating every caller; sizing that change from a text search; a migration looked complete but broke tests in files the search never surfaced; deciding between grep, compiler/type-checker errors, and an AST codemod to build the call-site census; sweeping test helpers and factories that reproduce the old shape |
| [severity-and-priority](process/severity-and-priority.md) | Triaging a bug — deciding how bad it is and when it gets fixed; a triage stalled on a severity debate |
| [post-release-verification](process/post-release-verification.md) | A release just deployed to production; defining what "released safely" means; an incident revealed a release was broken for hours before anyone noticed |

## document-verification

| Page | Load when |
|------|-----------|
| [spec-document-gates](document-verification/spec-document-gates.md) | Writing or reviewing automated checks (grep/script) that decide whether a spec/RFC/schema document meets its requirements; a document passed its checklist but the requirement is still unmet; choosing what a doc gate must assert beyond keyword presence (table structure, MUST-vs-SHOULD demotion, closed-set completeness, cross-section consistency); validating a gate pattern for a document that does not exist yet |
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
