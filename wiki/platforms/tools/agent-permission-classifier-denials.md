---
id: platforms-tools-agent-permission-classifier-denials
domain: platforms
category: tools
applies_to: [claude-code, agent-harness]
confidence: verified
sources:
  - https://code.claude.com/docs/en/auto-mode-config
  - https://github.com/anthropics/claude-code/issues/58222
  - https://github.com/anthropics/claude-code/issues/64128
last_verified: 2026-08-12
related: [platforms-tools-harness-mediated-tool-results, platforms-shells-command-text-inspected-before-execution, infrastructure-agent-orchestration-control-signals-vs-primary-artifacts, infrastructure-agent-orchestration-worktree-isolated-workers]
---

# A Classifier Denies a Tool Call the Agent Was Told to Make

## When this applies

An agent harness runs a second, model-based permission gate after its rule-based
one (Claude Code auto mode) and it denied an action that is correct for the task —
a push, a config write, a deploy command. Also when writing the permission or
`autoMode` config itself is denied as self-modification, or when you are designing
an automation whose steps a classifier will judge.

## Do this

1. **Read the denial as a tier, not as a verdict on the command.** Four tiers
   decide it, and each has a different unblocking move:

| Tier | Cleared by | Your move |
|------|-----------|-----------|
| `permissions.deny` (rule-based, runs first) | Nothing — not user intent, not the classifier | Change the rule, or do not do the action |
| `hard_deny` (classifier) | Nothing — `allow` and user intent do not apply | Change the action; the exfiltration boundary is the built-in entry |
| `soft_deny` (classifier) | An `allow` entry, or explicit user intent | Steps 2–3 |
| Everything else | Already allowed | — |

2. **When the block is a soft one, have the user name the exact action in their
   next message, then retry once.** The rule is specificity, not recency: "if the
   user's message directly and specifically describes the exact action Claude is
   about to take, the classifier allows it even when a `soft_deny` rule matches",
   and "general requests don't count as explicit intent" — "clean up the repo"
   does not authorize a force push; "force-push this branch" does.
3. **Design automations so the consent sentence is produced before the gated
   step**: detect the need, ask one question naming the exact action, act only on
   an explicit yes. A step whose authorization lives three turns back is judged
   without it.
4. **Make a repeated block durable instead of re-consenting each time.** Add the
   destination to `autoMode.environment`, or the pattern to `autoMode.allow`, and
   confirm with `claude auto-mode config`.
5. **Write permission and `autoMode` config at user scope, from outside the
   agent's own edit path.** The classifier reads `autoMode` from
   `~/.claude/settings.json`, managed settings, and `--settings`; it does **not**
   read `.claude/settings.json` or `.claude/settings.local.json`, because a
   checked-in repo or a build step could otherwise inject its own allow rules.
   A project-scoped write is therefore both denial-prone and inert.
6. **Recover a one-off denial through the harness's own retry path**: `/permissions`
   → **Recently denied** → `r` marks it for retry, and Claude Code resumes the
   conversation telling the model it may retry that call.

## Edge cases

| Case | Then |
|------|------|
| The user authorized it plainly last turn and it is still denied | Treat permission-config self-modification as a case explicit intent does not reliably clear: reported denials name "a permission widening the user did not explicitly request" for `.claude/settings.local.json` and "Writing to `.claude/settings.json` modifies the agent's own permissions configuration (Self-Modification)" even when a skill or the user prescribed the write. Have the user make the edit, or run the harness's own config command |
| An `allow` rule was added and the action is still blocked | An `allow` entry only overrides `soft_deny`; a `hard_deny` or a `permissions.deny` match is unaffected, and the classifier ignores `allow` written into project settings |
| The denial reason is the fixed string `Blocked by classifier` | v2.1.208+ scores severity instead of writing an explanation; infer the tier from the action and use `claude auto-mode defaults --label '<rule prefix>'` to read the matching rule's wording |
| You set `autoMode.allow`/`soft_deny`/`hard_deny` without `"$defaults"` | The whole built-in list for that section is discarded, including the force-push, `curl \| bash`, production-deploy, and auto-mode-bypass soft blocks — include the literal `"$defaults"` |
| The boundary was stated only in conversation ("don't push until I review") | Context compaction can remove the message that stated it; put a `permissions.ask` or `deny` rule in settings for a boundary that must survive the session |
| A narrow `Bash(...)` allow rule lets an unreviewed argument through | Set `autoMode.classifyAllShell: true` so every shell command reaches the classifier; auto mode otherwise suspends only broad rules like `Bash(*)` |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Rephrase and re-send a denied command until one wording passes | Get the exact action named by the user, retry once, then add an `environment` or `allow` entry | The gate judges the action, so re-rolling wordings burns turns without changing the tier |
| Widen your own permissions by editing `.claude/settings.local.json` | Have the user write `~/.claude/settings.json`, or use `claude auto-mode` subcommands | Self-modification of the permission config is what the block targets, and the classifier does not read project-scoped `autoMode` anyway |
| Ask for blanket approval up front ("you can run these commands") | Ask one question naming the specific action right before the step | Reported blocks cite blanket phrasing as not explicit authorization "for this specific push" |
| Treat a denial as proof the task is disallowed | Identify the tier, then pick the matching mechanism from the table | Only `permissions.deny` and `hard_deny` are unconditional; the rest have a stated escape hatch |

## Sources

- https://code.claude.com/docs/en/auto-mode-config — the four-tier precedence (`hard_deny` unconditional; `soft_deny` overridable; `allow` as exceptions to `soft_deny`; "Explicit user intent overrides the remaining soft blocks: if the user's message directly and specifically describes the exact action Claude is about to take"); "General requests don't count as explicit intent"; "The classifier doesn't read `autoMode` from project settings in `.claude/settings.json` or `.claude/settings.local.json`… Before v2.1.207, the classifier also read `.claude/settings.local.json`"; `"$defaults"` splicing and the danger of omitting it; `classifyAllShell` (v2.1.193+); the `Blocked by classifier` fixed reason (v2.1.208+) and `defaults --label`; the `/permissions` → Recently denied → `r` retry path; conversational boundaries lost to compaction
- https://github.com/anthropics/claude-code/issues/58222 — eight operations denied despite authorization in the immediately preceding turn, including "Writing to .claude/settings.json modifies the agent's own permissions configuration (Self-Modification)" for a write a skill itself recommended, and "Git Push to Default Branch without explicit user authorization for this specific push" after "you can run these commands". Closed as not planned
- https://github.com/anthropics/claude-code/issues/64128 — "Self-Modification: adding new Bash permission allow rules to .claude/settings.local.json … a permission widening the user did not explicitly request", and the subsequently added allow rules not clearing the block (CLI v2.1.121). Closed as not planned
- Field observation 2026-08-09 (Claude Code 2.1.220, auto mode): the same `permissions.allow` + `autoMode` edit was denied against a project `.claude/settings.local.json` with no preceding instruction, and succeeded against `~/.claude/settings.json` immediately after the user named the edit. Two variables differed (settings scope and consent), so this observation supports the documented precedence rather than isolating consent as the cause
