---
id: security-incident-response-verifying-assumed-security-agents
domain: security
category: incident-response
applies_to: [macos, general]
confidence: verified
sources:
  - https://www.elastic.co/blog/mac-system-extensions-for-threat-detection-part-3
  - https://github.com/redcanaryco/mac-monitor/wiki/5.-Endpoint-Security-Overview
last_verified: 2026-08-13
related: [security-incident-response-process-identity-by-path-and-hash]
---

# A Documented Claim That a Host Runs an EDR or Security Agent

## When this applies

You are about to reason from a written claim (CLAUDE.md, runbook, team wiki,
onboarding doc) that a host runs an EDR/security agent — judging whether a
threat "would have been detected", triaging a suspected compromise, or applying
rules premised on the agent's presence.

## Do this

1. **Verify the agent is installed and running on the host before using the
   document as evidence.** On macOS, check all three together — each alone can
   miss:

| Check | Command | What it catches |
|-------|---------|-----------------|
| Vendor install directory | `ls -d /Library/Sentinel*` (adjust to the vendor's documented path) | Agent files present at all |
| Running processes | `ps aux \| grep -iE "sentinel\|crowdstrike\|falcon\|defender"` | Agent daemons actually executing |
| System extensions | `systemextensionsctl list` | Endpoint Security clients — since macOS 10.15 deprecated kexts, EDR vendors ship ES clients as system extensions, so a real EDR appears here even when its process names don't match your grep |

2. **When all three come back empty, conclude "not installed" — not "failed to
   detect".** The two conclusions produce opposite threat models: "installed but
   silent" reads as an agent-evading advanced threat; "absent" reads as an
   ordinary threat on an undefended host.

3. **Update the document that carried the stale claim** in the same session, so
   the next reader does not re-derive the wrong threat model from it.

## Edge cases

| Case | Then |
|------|------|
| The extension appears in `systemextensionsctl list` but its state is not `[activated enabled]` | The agent is installed but not intercepting — the user never approved it, or it was deactivated; treat detection coverage as absent until the state shows activated |
| The document's claim was true once (agent since removed or license lapsed) | This is the expected failure mode, not an exception — documents record install state at writing time and rot silently; that is why the host, not the document, is the source of truth |
| The host is not macOS | The principle holds; verify through the vendor's documented service mechanism for that OS (service units, installed packages) rather than a process grep alone |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Conclude "the EDR didn't flag it, so the binary is clean" from a doc that says an EDR is present | Run the three checks; only an agent proven present and activated can clear anything | On the incident that produced this page, docs claimed SentinelOne while all three checks were empty — a root XMRig miner had run 4 days 8 hours on a host with no EDR at all |
| Write a security rule justified by "the EDR will catch X" | Verify presence first, and cite the check output in the rule | A rule premised on an absent control enforces nothing and blocks the real question |

## Sources

- https://www.elastic.co/blog/mac-system-extensions-for-threat-detection-part-3 — macOS security vendors must use Endpoint Security via system extensions after kext deprecation; extensions are enumerable on the host
- https://github.com/redcanaryco/mac-monitor/wiki/5.-Endpoint-Security-Overview — Endpoint Security framework as the sanctioned interception point for EDR/antivirus on macOS
- Local verification 2026-08-13 (macOS, Darwin 25.1.0): `systemextensionsctl list` enumerated the machine's extensions (one DriverKit entry, no ES clients), `ls -d /Library/Sentinel*` → no matches, process grep → 0 — consistent with the incident finding that the documented SentinelOne was never installed
- Field incident 2026-08-13: global CLAUDE.md cited "SentinelOne EDR detects this" as a rule's rationale; the three checks returned empty on the machine and a root-privileged XMRig had run 4d8h undetected — the document's premise, not the miner's sophistication, was the gap
