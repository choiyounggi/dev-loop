# Design — nowiki

## Decisions
| # | Decision | Choice | Wiki basis | Rejected alternative | Testability |
|---|----------|--------|------------|----------------------|-------------|
| D1 | Script language | POSIX sh | wiki/platforms/shells/portable-shell-scripts.md | bash arrays | shebang check |
| D2 | Queue write path | direct JSONL append | [no-wiki] | Stop-hook block format | emit-gaps.bats |
| D4 | Gap line key | date-free prefix | [no-wiki] | full-line match | idempotency case |

## Review
VERDICT: PASS
