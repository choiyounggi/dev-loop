# Gates: <task id — matches the plan's Task order entry>

Scope: <one sentence describing this task's complete deliverable>

- [ ] G1: <observable outcome measured directly from the artifact>
  CHECK: <shell command run from the worktree root>
  EXPECT: <substring that appears in the output ONLY when every assertion passed>
  EVIDENCE: pending

- [ ] G2: <manual outcome that no command can decide>
  EVIDENCE: pending

<!--
Authoring rules (enforced by gate-check.sh):
- One file per task at .dev-loop/gates/<task-id>.md, written at step 0
  (Define done) BEFORE any implementation.
- Unique id per gate. A runnable gate has BOTH CHECK and EXPECT; a manual
  gate has NEITHER. One without the other is a parse error.
- EXPECT must be a success-only token (e.g. a final "ALL PASS" marker), not
  text that also appears on failure. Success requires exit 0 AND the token.
- Never edit EVIDENCE by hand on a runnable gate — run:
    sh ${CLAUDE_PLUGIN_ROOT}/skills/loop-implement/scripts/gate-check.sh --run <file>
  The checker executes CHECK, flips the box, and records the evidence.
  A checked box whose EVIDENCE still reads "pending" counts as CLAIMED —
  worse than unchecked, because it is a done-claim without proof.
- For a manual gate, record the exact observation as EVIDENCE and tick the
  box yourself; keep these rare and try to make risky outcomes runnable.
- If a gate becomes genuinely impossible, do NOT delete it. Add a line:
    ABANDON: G<n> <non-empty reason and handoff>
  and surface every abandonment in the task report's GATES: line.
-->
