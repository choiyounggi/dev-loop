---
id: security-dependencies-agent-skill-supply-chain
domain: security
category: dependencies
applies_to: [general]
confidence: field-tested
sources:
  - https://github.com/zhaoxuya520/reverse-skill/blob/main/skills/ops/skill-supply-chain.md
  - https://github.com/virgiliojr94/book-to-skill/blob/9c207f870adebe20ade4f7d2f11bc3d759c2fd88/SECURITY-NOTICE.md
  - https://github.com/different-ai/openwork/blob/fda0babb6c7600ed044757515beb374a3f4dc827/skills-lock.json
last_verified: 2026-08-29
related: [security-dependencies-supply-chain, security-agent-exposure-in-session-tool-exposure]
---

# Trusting Third-Party Agent Skills, Plugins, and MCP Servers

## When this applies

Installing or importing a third-party agent skill, plugin, or MCP server into
an agent environment (Claude Code, opencode, a team skill marketplace); vetting
an external SKILL.md before an agent can execute it; publishing skills for a
team to consume.

## Do this

1. **Treat a skill as arbitrary code plus standing prompt input.** It runs with
   the agent's shell and tool permissions. Before installing, read the full
   SKILL.md and every bundled script, and grep for exfiltration patterns:
   network calls to unlisted hosts, credential/wallet storage paths, disabled
   TLS verification. This is not hypothetical — `Leutenegger/book-to-skill`, a
   malicious re-upload of the trending book-to-skill project, shipped TLS
   verification bypass, crypto-wallet storage collection, and C2 upload
   (documented in the original project's SECURITY-NOTICE.md).
2. **Resolve the canonical owner before installing.** Malicious re-uploads sit
   under lookalike owners of trending skill repos, the same way typosquats
   shadow package names — install from the owner named in the project's own
   docs/README, not from the top search result.
3. **Pin installed skills by source and hash.** Record repo, file path, and a
   computed content hash in a lockfile (openwork's `skills-lock.json` does
   exactly this per skill), so re-installs are reproducible and a silent
   upstream content swap fails the install instead of running.
4. **Register MCP servers only after the same review.** When a skill's
   instructions ask the agent to auto-register an MCP server, stop and route it
   through the same human-reviewed vetting as step 1 — reverse-skill's
   supply-chain checklist (citing OWASP's agentic-skills risks) makes
   unreviewed MCP auto-registration a hard MUST-NOT with review as the
   replacement path.

## Edge cases

| Case | Then |
|------|------|
| A pinned skill has an upstream update | Diff old vs new content, re-run the step 1 review on the diff, then bump the pinned hash |
| A team marketplace assigns skills org-wide | Gate at publication, not installation — the publisher runs the vet once; an unvetted published skill fans out to every assigned member |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Install a trending skill from a search-result repo | Resolve the canonical owner via the project's docs (step 2) | The book-to-skill malicious re-upload was exactly this path |
| Trust a skill because its README asserts safety | Read the scripts and grep for exfil patterns yourself (step 1) | The README of a malicious re-upload is written by the attacker |
| Let a skill auto-add an MCP server mid-run | Pause and vet the server like any new skill (step 4) | An MCP server extends the agent's tool surface permanently |

## Sources

- https://github.com/zhaoxuya520/reverse-skill/blob/main/skills/ops/skill-supply-chain.md — pre-install MUST checklist (read SKILL.md + scripts, grep exfil patterns, no unreviewed MCP registration), OWASP agentic-skills citation
- https://github.com/virgiliojr94/book-to-skill/blob/9c207f870adebe20ade4f7d2f11bc3d759c2fd88/SECURITY-NOTICE.md — documented malicious re-upload incident (TLS bypass, wallet collection, C2)
- https://github.com/different-ai/openwork/blob/fda0babb6c7600ed044757515beb374a3f4dc827/skills-lock.json — source+hash lockfile for imported skills
