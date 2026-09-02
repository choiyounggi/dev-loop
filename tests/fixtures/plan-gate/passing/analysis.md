# Analysis — fixture

## Requirements
| Rule | Concrete example | Open question |
|------|------------------|---------------|
| R1: emit writes a ledger | given a plan-dir, when emit A runs, then out-file has 5 gates | |

## Ground truth
- Baseline: true -> rc=0, HEAD abc1234, git status clean

### Affected files
- skills/wiki-plan/scripts/plan-gate.sh — evidence: grep -rln plan-gate.sh tests -> 1 hits

## Constraints
- none — checked: grep -rn 'PIN:' templates/session-prompt.md

## Spikes

## Research
| Query | Source | Applied |
|-------|--------|---------|
| gates ledger CHECK/EXPECT convention | templates/gates.md | reused CHECK:/EXPECT:/EVIDENCE: syntax unmodified |
