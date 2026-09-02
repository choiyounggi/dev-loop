<!-- contract: t1-plan-gate owns the implementation -->
# Plan gates ledger template — same CHECK:/EXPECT:/EVIDENCE: syntax as templates/gates.md
<!--
plan-gate.sh emit <A|B> <plan-dir> <out-file> reads this file, keeps only the
block for the requested phase (marked by the PHASE: A / PHASE: B HTML
comments below — comments are ignored by gate-check.sh's parser, so they are
safe section markers), substitutes the `{PLAN_DIR}` token
with the real plan directory and (phase A only) the `{BASELINE_CMD}` token
with the Baseline command recorded in <plan-dir>/analysis.md, and writes the
result to <out-file>. `${CLAUDE_PLUGIN_ROOT}` is left as a live shell
variable — gate-check.sh runs CHECK via `bash -c`, which expands it at
execution time, exactly like templates/gates.md's own CHECK lines do.

gate-check.sh --run then judges every gate here exactly like any other
.dev-loop/gates/*.md ledger (see hooks/loop-gate.sh Gate 2) — no changes to
either script were needed or made.
-->

<!-- PHASE: A -->
- [ ] baseline-tests-ran: the Baseline command recorded in analysis.md still reproduces cleanly
  CHECK: {BASELINE_CMD} && echo GATE_OK
  EXPECT: GATE_OK
  EVIDENCE: pending

- [ ] affected-files-evidenced: every `### Affected files` bullet in analysis.md carries an `evidence:` token
  CHECK: sh ${CLAUDE_PLUGIN_ROOT}/skills/wiki-plan/scripts/plan-gate.sh check affected-files-evidenced {PLAN_DIR}
  EXPECT: ok
  EVIDENCE: pending

- [ ] open-questions-resolved: no unresolved `OPEN:` question remains in analysis.md's `## Requirements`
  CHECK: sh ${CLAUDE_PLUGIN_ROOT}/skills/wiki-plan/scripts/plan-gate.sh check open-questions-resolved {PLAN_DIR}
  EXPECT: ok
  EVIDENCE: pending

- [ ] constraints-surveyed: analysis.md's `## Constraints` lists at least one surveyed constraint (or an explicit none-checked line)
  CHECK: sh ${CLAUDE_PLUGIN_ROOT}/skills/wiki-plan/scripts/plan-gate.sh check constraints-surveyed {PLAN_DIR}
  EXPECT: ok
  EVIDENCE: pending

- [ ] research-evidenced: analysis.md's `## Research` has at least one query/source row or an explicit no-useful-results line
  CHECK: sh ${CLAUDE_PLUGIN_ROOT}/skills/wiki-plan/scripts/plan-gate.sh check research-evidenced {PLAN_DIR}
  EXPECT: ok
  EVIDENCE: pending

<!-- PHASE: B -->
- [ ] groundings-exist: every `Wiki basis` cell in design.md's `## Decisions` (other than `[no-wiki]`) names a page that exists under the wiki root
  CHECK: sh ${CLAUDE_PLUGIN_ROOT}/skills/wiki-plan/scripts/plan-gate.sh check groundings-exist {PLAN_DIR}
  EXPECT: ok
  EVIDENCE: pending

- [ ] decision-rows-complete: every data row in design.md's `## Decisions` has all six cells filled in
  CHECK: sh ${CLAUDE_PLUGIN_ROOT}/skills/wiki-plan/scripts/plan-gate.sh check decision-rows-complete {PLAN_DIR}
  EXPECT: ok
  EVIDENCE: pending

- [ ] reviewer-verdict: <plan-dir>/review-verdict.md records a `VERDICT: PASS` line
  CHECK: sh ${CLAUDE_PLUGIN_ROOT}/skills/wiki-plan/scripts/plan-gate.sh check reviewer-verdict {PLAN_DIR}
  EXPECT: ok
  EVIDENCE: pending
