# Design — fixture

## Decisions
| # | Decision | Choice | Wiki basis | Rejected alternative | Testability |
|---|----------|--------|------------|----------------------|-------------|
| 1 | Script language | POSIX sh | wiki/platforms/shells/portable-shell-scripts.md | bash arrays | plan-gate.bats checks the shebang; covers R1 |

## Review
VERDICT: PASS (see review-verdict.md)
