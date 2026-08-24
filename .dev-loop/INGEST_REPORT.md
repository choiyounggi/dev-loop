# Ingest report — GitHub-trending agent-skill practices

Distilled from a session analyzing the week's GitHub-trending repos. Ten repos
were triaged; six carried transferable engineering practice, and five directive
units were ingested (4 new pages + 1 amend). Four repos (airllm, airi,
pascalorg/editor, microsoft/AI-For-Beginners) were out of domain or unverified
at code level and dropped.

## Verified best-practice

Every directive is cited to a source file confirmed live via `gh api` before
writing (all 9 cited repo paths returned their `.path` — none fabricated):

1. **Deterministic-preprocess × LLM-judgment review pipeline** — `alibaba/open-code-review`.
   README "Core Design" + `skills/open-code-review/SKILL.md` (rule.json layering).
   The ~1/9-token figure is the repo's own AACR-Bench measurement (50 repos /
   200 PRs / 1,505 labels) — recorded as vendor-self-measured, not independently
   reproduced. Corrects the source podcast's mis-stated "19%".
2. **Progressive-disclosure knowledge artifact** — `virgiliojr94/book-to-skill`.
   README "What it generates" + SKILL.md Step 7 (BOOK_TYPE × DEPTH budget
   matrix) and Step 2.6 (grep/sed slice access for ≥50K-token originals).
3. **Agent-skill/MCP supply-chain vetting** — `zhaoxuya520/reverse-skill`
   `skills/ops/skill-supply-chain.md` (OWASP-cited pre-install checklist) +
   `different-ai/openwork` `skills-lock.json` (source+hash pinning) +
   `virgiliojr94/book-to-skill` `SECURITY-NOTICE.md` (documented malicious
   re-upload: TLS bypass, wallet collection, C2).
4. **Authorization-scope persistence for dangerous capabilities** —
   `zhaoxuya520/reverse-skill` `skills/ops/scope-contract.md` (`scope.md` with
   `auth.status: granted` gate, force-flag non-bypass, `network_profile`) +
   `RULES.md`.
5. **Pre-send self-check (amend)** — `ayghri/i-have-adhd`
   `skills/i-have-adhd/SKILL.md` "Pre-send check" pairing each output rule with
   a pre-emit predicate.

## Existing-layer check

Read the adjacent pages before writing to merge-not-duplicate. The
progressive-disclosure and review-pipeline triggers were absent; the
i-have-adhd self-check was the only genuinely new element over
binding-instructions (its exception-hierarchy/precedence content is already
covered there and was NOT re-ingested). block/buzz's audit-log design and
openwork's 2-tool gateway were considered and rejected (off usage-context /
below directive bar; the gateway is also in tension with agent-tool-granularity).

Pages read: qa-process-evaluating-review-feedback, qa-process-adversarial-change-review, backend-common-llm-binding-instructions-for-agents, backend-common-llm-context-window-budget, backend-common-api-design-agent-tool-granularity, security-agent-exposure-in-session-tool-exposure, security-dependencies-supply-chain, infrastructure-agent-orchestration-autonomous-decision-rulings

## Open-PR check

`gh pr list --state open` returned zero rows — no in-flight knowledge PR to
deduplicate against. All five units routed as new/amend without conflict.

## Routing decision

- `qa/process/llm-review-pipelines` — NEW page. qa owns release-quality review
  process; no existing category page carried the automated-LLM-review-pipeline
  trigger.
- `backend/common/llm/progressive-disclosure-artifacts` — NEW page. backend/llm
  owns agent/LLM-artifact authoring; `context-window-budget` covers output-cap
  sizing only, a different trigger.
- `security/dependencies/agent-skill-supply-chain` — NEW page (not merged into
  `supply-chain.md`): distinct trigger (executable agent skills vs npm/pip
  packages), one-case-per-page. Cross-linked to `supply-chain` both ways.
- `security/agent-exposure/authorization-scope-persistence` — NEW page.
  agent-exposure owns what an agent is permitted to do; distinct from
  `in-session-tool-exposure` (WebMCP browser tools). Linked to it and to
  `autonomous-decision-rulings`.
- `backend/common/llm/binding-instructions-for-agents` — AMEND (+Do-this #6,
  +source). Same trigger, additive directive.

Lint: `wiki-lint-prohibitions.js` → directives 71 / violations 0 (count
unchanged, no bats bump needed). `wiki-structure-checks.js` → 265 pages, 0
findings. bats wiki-lint suite → 17/17 pass.
