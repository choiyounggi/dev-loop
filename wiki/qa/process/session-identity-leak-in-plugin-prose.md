---
id: qa-process-session-identity-leak-in-plugin-prose
domain: qa
category: process
applies_to: [general]
confidence: field-tested
sources:
  - "Field incident (a marketplace-distributed plugin repo, task t3-skill review round 1): a skill's SKILL.md line 9 hard-coded the session's injected user name; caught in a four-lens review, fixed in rework, confirmed absent by a recursive grep returning 0 matches; re-checked 2026-09-08 against the installed marketplace copy and two cached versions — none contain the name"
  - https://12factor.net/config
last_verified: 2026-09-08
related: [security-data-commit-identity-in-public-repos, qa-process-adversarial-change-review, qa-process-defect-class-resweep-after-review, security-dependencies-agent-skill-supply-chain]
---

# Session-Injected Personal Identity Leaking Into Distributed Plugin Prose

## When this applies

Reviewing a diff that adds or edits prose meant for redistribution — `SKILL.md`,
`README`, a template, an example, or a doc comment — inside a marketplace-distributed
plugin or skill repo, authored in a session whose identity-injection layer set the
user's personal name (or another session-local identifier) into context.

## Do this

1. **Run this as the first check on a plugin-authoring diff**, before structural or
   correctness review: grep the diff for the session's injected personal name and
   any other session-local identifiers. The code works locally with the name
   hardcoded, so nothing else in a normal review catches it.
2. **Route by what the diff touches:**

| Case | Do |
|------|----|
| Diff touches prose meant for redistribution (SKILL.md, README, template, example, doc comment) | Grep for the injected name/identifiers before approving; generalize any hit |
| The name also appears in a code comment or a hardcoded string in the plugin's source (not only docs) | Same check, same fix — the file ships as source; a comment distributes identically to prose |
| Diff touches internal-only files never distributed (a private CLAUDE.md, a local scratch note, a personal habit log) | Leave personal names in place — they are expected content here |
| The injected name is also a common word/token with a legitimate generic meaning | grep still finds every occurrence — read each hit's context before flagging; a bare hit count without inspection over- or under-reports |

3. When a hit lands in redistributed content, replace it with a generic
   role/placeholder ("the user", `{{name}}`, a config key) and confirm the plugin's
   identity-aware behavior comes from the runtime identity-injection layer, not from
   the authored file.
4. **Re-grep the whole plugin tree for the same token after the fix**, not just the
   flagged line — the review sampled one file; a sibling file (another skill's prose,
   a shared template) can carry the same session-local value untouched.

## Edge cases

| Case | Then |
|------|------|
| The leaked value is a different session-local identifier (work email, absolute home directory path, a machine hostname) rather than a name | Same grep-before-approve check extends to it — the mechanism (session context bleeding into generic output) is identical, only the token type differs |
| grep returns zero hits but the diff includes a screenshot or a paraphrase of session output | A screenshot or reworded sentence can still carry the name where a text grep misses it — read the rendered diff, not only the grep result |
| The plugin is private and never published to a marketplace | The check does not apply — personalization is fine when the only consumer is the session that authored it |
| A structural/adversarial review already passed on this diff | Run the grep anyway — a general review is not looking for this token class and routinely misses it ([qa-process-adversarial-change-review]) |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Approve a plugin-authoring diff after a general code-quality checklist with no identity-specific check | Grep the diff for the session's injected personal name/identifiers before approving | The code works locally with the name hardcoded — a general checklist review has nothing to trigger on this class |
| Hardcode a friendly per-user greeting or example directly into a skill's distributed prose | Keep the prose generic and let the runtime identity-injection layer supply the name at session start | A worker session inherits the coordinator's identity context and writes it into deliverables by default; every other install then misnames its user |
| Treat fixing the one flagged line as closing the defect | Re-grep the whole plugin tree for the same token after the fix | The reviewed line is a sample; a sibling file can carry the same session-local value untouched |

## Sources

- Field incident (a marketplace-distributed plugin repo, task t3-skill review round 1): a skill's SKILL.md line 9 hard-coded the session's injected user name; caught in a four-lens review, fixed in rework, confirmed absent by a recursive grep returning 0 matches. Re-checked 2026-09-08 against the installed marketplace copy and both cached versions — none contain the name.
- https://12factor.net/config — supports the general principle by analogy only: "Apps sometimes store config as constants in the code. This is a violation of twelve-factor, which requires strict separation of config from code"; "A litmus test for whether an app has all config correctly factored out of the code is whether the codebase could be made open source at any moment, without compromising any credentials." Scoped to runtime config and credentials, not authored prose — which is why confidence stays field-tested.
