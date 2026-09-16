# Analysis — nowiki

## Requirements
| Rule | Concrete example | Open question |
|------|------------------|---------------|
| R1: emitter records every no-wiki row | given a design.md with [no-wiki] rows, when emit-gaps.sh runs, then log.md and the queue each get one entry per row | |

## Ground truth
- Baseline: true -> rc=0, HEAD abc1234, git status clean

### Affected files
- skills/wiki-plan/scripts/emit-gaps.sh — evidence: grep -rln emit-gaps.sh tests -> 1 hits

## Constraints
- none — checked: grep -rn 'PIN:' templates/session-prompt.md

## Spikes

## Research
| Query | Source | Applied |
|-------|--------|---------|
| jsonl dedupe | https://example.invalid/dedupe | key before write |
