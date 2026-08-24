---
id: security-agent-exposure-authorization-scope-persistence
domain: security
category: agent-exposure
applies_to: [general]
confidence: field-tested
sources:
  - https://github.com/zhaoxuya520/reverse-skill/blob/main/skills/ops/scope-contract.md
  - https://github.com/zhaoxuya520/reverse-skill/blob/main/RULES.md
last_verified: 2026-08-24
related: [security-agent-exposure-in-session-tool-exposure, infrastructure-agent-orchestration-autonomous-decision-rulings]
---

# Gating a Dangerous Agent Capability on Persisted Authorization

## When this applies

Authoring a skill or agent that can take consequential, hard-to-reverse actions
against a target — active security scanning, exploitation, destructive
operations, spending — where whether the action is permitted depends on the
specific target and must be established before the agent acts.

## Do this

1. **Persist authorization to a file, not to conversation context.** Write the
   grant to a per-target artifact (reverse-skill creates `work/<case>/scope.md`
   via a `case-init` step) with an explicit status field. Conversation memory is
   not durable authorization: it is lost on context compaction and cannot be
   audited after the run.
2. **Default-deny on a status predicate.** The dangerous action proceeds only
   when the persisted status reads `granted`; any other value (absent, pending,
   revoked) blocks it. reverse-skill's scope-contract: "MUST NOT proceed if
   status != granted."
3. **Make override flags unable to bypass the gate.** State in the skill that
   `--force`/`-Force` skips confirmations but never the authorization check —
   otherwise the escape hatch for tedium becomes the escape hatch for the
   guardrail.
4. **Scope the network blast radius as its own field.** Record an explicit
   network profile (reverse-skill: `offline` / `lab_only` /
   `authorized_target_only` / `unrestricted_lab`) so "authorized to test host X"
   does not silently authorize scanning everything routable from the agent.
5. **Re-read the gate at each dangerous step, not once at startup.** The status
   file is the single source of truth; an agent that caches "authorized" from
   turn one keeps acting after a revocation.

## Edge cases

| Case | Then |
|------|------|
| Read-only reconnaissance (passive lookups, public data) | Allowed before a grant; gate only the active/mutating actions in step 2 |
| Authorization covers one target but the agent discovers an adjacent one | The new target is out of scope until its own grant is written — discovery does not extend authorization |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Ask "is this authorized?" once in chat and proceed | Write a scope file and gate every action on its status (steps 1–2, 5) | Chat consent is unauditable and lost on compaction |
| Let `--force` run the whole flow unattended | Scope force to confirmations; keep the auth check mandatory (step 3) | A force flag that skips authorization turns a convenience into a footgun |

## Sources

- https://github.com/zhaoxuya520/reverse-skill/blob/main/skills/ops/scope-contract.md — `scope.md` with `auth.status: granted` gate, "MUST NOT proceed if status != granted", `network_profile` values, force-flag non-bypass
- https://github.com/zhaoxuya520/reverse-skill/blob/main/RULES.md — hot-path enforcement that a case be initialized before scoped actions run
