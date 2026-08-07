# Brief template — XML task brief

The orchestrator fills this in per task and writes it to
`.orchestration/briefs/{TASK}.md`. Structure follows the delegation 4-part
contract (objective / output / tools / boundaries) plus done + effort, in XML
tags so the session can re-recognize each section. Heavy context goes near the
top (long-context guidance); the session prompt's one-line trigger cites the
specific tags below as authority.

```xml
<task_brief task="{TASK}" wave="{W}">

  <!-- big context first (long-context tips) -->
  <context>
    <main_goal>{the overall goal this task is part of}</main_goal>
    <architecture>{shared components / data flow the task must respect}</architecture>
    <this_task_role>{this task's role among the N tasks}</this_task_role>
    <surrounding_code>{affected files: reuse / extend / new}</surrounding_code>
    <!-- UI-facing tasks only: the visual contract pulled via the `design` role
         (e.g. Figma spec links / tokens / dev-ready state). Omit for backend-only
         tasks or when no design role is configured. Implement against this, not the raw link. -->
    <design_spec>{resolved visual spec for a UI task — source figma link + pulled spec/tokens; omit if N/A}</design_spec>
  </context>

  <!-- consume upstream outputs, never re-create them (avoid compounding errors).
       for a Wave 2+ task the orchestrator pastes the APPROVED preceding Wave's REAL
       signatures here (Phase 3 step 0) — exact, not paraphrased; treat as a contract -->
  <dependencies>
    <upstream task="{UPSTREAM}">consume only: `{exact signature — verbatim from the approved upstream}` (do not re-create)</upstream>
    <i_produce>you own: `{output}` — expose a stable interface for others</i_produce>
  </dependencies>

  <objective>{one-line goal}</objective>

  <!-- explicit boundaries + forbidden list — this is what prevents duplicate work -->
  <scope_boundaries>
    <in_scope>{what this session may change}</in_scope>
    <out_of_scope>
      - {shared file X}: do not change its signature/large structure — another session owns it
      - {output Y}: do not produce — {OWNER} is the single producer; you consume only
    </out_of_scope>
  </scope_boundaries>

  <!-- which tools/sources to use; subagent usage is in the session prompt protocol.
       fill the resolved tool-profile roles here (resolve-tools.sh) so the session
       inherits them: knowledge=<tool|default>, tacit=<tool|default>, plan=<tool|default> -->
  <tools_guidance>{e.g. docs/specs to read, how to explore; DB read-only if any; resolved roles — knowledge/tacit/plan}</tools_guidance>

  <constraints>{local rules; surgical changes only on shared files}</constraints>

  <!-- "what done looks like" — verifiable -->
  <definition_of_done>
    - [ ] {acceptance criterion 1}
    - [ ] unit tests (>=1 normal + 1 error + 1 boundary, assertions required)
    - [ ] build / type-check passes
  </definition_of_done>

  <!-- scale effort to complexity; bound the retries -->
  <effort_level>complexity={simple|medium|complex}; loop-implement max 3 retries; stop exploring once DoD is met</effort_level>

  <!-- the plan is an INPUT, not an output: the coordinator ran `wiki-plan` on the
       planning model and wrote it before this session launched. Adopt it; report a
       gap rather than re-planning (re-planning would move the decisions onto the
       worker's tier). -->
  <plan>.orchestration/plans/{TASK}.md — written by the coordinator; adopt, verify against this brief, do not re-author</plan>

  <!-- output contract: how to signal completion -->
  <output_contract>
    signal -> STATUS_DIR={STATUS_DIR} sh {SKILL}/scripts/status-update.sh {TASK} <phase> worktree=$PWD
  </output_contract>

  <!-- If this task turns out to be much larger than the brief assumed, you may
       propose splitting it instead of silently running long. A split proposal
       MUST carry, for each proposed piece, the files it would touch and the
       outputs it would newly produce — the coordinator decides by testing those
       files for overlap against every other running task, and a proposal
       without them cannot be judged at all. Name the parent as `split_of`.
       Propose once, then wait: the coordinator replies either way, and a
       rejection is an answer, not silence. A piece that came from a split can
       never itself be split. -->
  <split_proposal_rule>propose a split with per-piece `files`, `outputs`, and `split_of`; wait for the reply</split_proposal_rule>

</task_brief>
```
