#!/bin/sh
# contract: t1-plan-gate owns the implementation
# plan-gate.sh — mechanical judge for Phase A/B plan gates (cycle-hardening design §3)
#
# Usage:
#   plan-gate.sh check <gate-id> <plan-dir> [<wiki-root>]   one gate -> stdout "ok"|"fail"
#   plan-gate.sh emit  <A|B> <plan-dir> <out-file>          write gates ledger from templates/plan-gates.md
#
# Gate ids (A): baseline-tests-ran affected-files-evidenced open-questions-resolved
#               constraints-surveyed research-evidenced
# Gate ids (B): groundings-exist decision-rows-complete reviewer-verdict
#
# Exit codes: 0 ok | 2 usage | 3 check failed (content defect, stderr itemizes)
#             4 target file/section missing (distinct from content missing)
echo "usage: plan-gate.sh check|emit ..." >&2
exit 2
