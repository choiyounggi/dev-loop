# qa — Domain Index

Route here for: release-quality process — acceptance criteria, gates,
regression scoping, test-environment parity, post-release verification, bug
reports, manual/exploratory testing. Writing automated test code → wiki/testing/;
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
