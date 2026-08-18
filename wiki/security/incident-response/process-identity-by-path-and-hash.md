---
id: security-incident-response-process-identity-by-path-and-hash
domain: security
category: incident-response
applies_to: [macos, general]
confidence: verified
sources:
  - https://attack.mitre.org/techniques/T1036/005/
last_verified: 2026-08-13
related: [security-incident-response-verifying-assumed-security-agents]
---

# A Suspicious Process Whose Name Matches a Legitimate System Daemon

## When this applies

You are triaging or cleaning up a host compromise (cryptominer, dropper) and a
process in `ps` output carries the name of a known system daemon — `sysmond`,
`kworker`, `svchost` — and you must decide whether to kill, quarantine, or
leave it.

## Do this

1. **Judge the process by its executable path and signature/hash, never by its
   name.** Malware deliberately adopts legitimate daemon names (MITRE ATT&CK
   T1036.005), so the name carries no identity information.
2. **Resolve the full executable path first**: `ps -axo pid,user,args` (the
   `args` column shows the invocation path) or `lsof -p <pid>` for the running
   image. Then classify:

| Executable path | Verdict |
|-----------------|---------|
| System-owned, root-only-writable location (`/usr/libexec/`, `/System/`) and the signature verifies | Legitimate — leave it |
| User-writable location (`~/.config/`, `~/Library/`, `/tmp`, a hidden dot-directory) under a system daemon's name | Malicious until proven otherwise — quarantine the file and capture it before killing |

3. **On macOS, confirm the system-path copy with the code signature**:
   `codesign -vv <path>` must report "valid on disk / satisfies its Designated
   Requirement", and `codesign -dv <path>` must show an `Authority=Software
   Signing` Apple chain with a `com.apple.*` identifier. A man page
   (`man -w <name>`) corroborates that the name belongs to a shipped daemon.
4. **Identify the malicious copy by its content, not its name**: hash it
   (`shasum -a 256`), and read embedded strings or its own log output — a miner
   typically names itself and its version in its log header.

## Edge cases

| Case | Then |
|------|------|
| Both a legitimate and a malicious process run under the same name simultaneously | Expected — that is the point of the masquerade; enumerate every PID for the name and classify each by its own path before killing any |
| The name matches nothing on the system (`man -w` empty, no binary at a system path) | The name itself is fabricated to look system-ish; classify by path and content as above — absence of a legitimate twin does not make it safe to name-match-kill either |
| The binary deletes itself after launch and only the process remains | `lsof -p <pid>` still shows the mapped executable (marked deleted on Linux); capture memory/strings before killing, since the file is unrecoverable after exit |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| `pkill sysmond` because a miner cleanup guide names that process | Enumerate PIDs, resolve each executable path, kill only the user-writable-path copy | macOS ships a genuine `/usr/libexec/sysmond`; a name-based kill takes down the Apple daemon, misses a renamed miner, or both |
| Trust a process because its name has a man page | Verify the running image's path is the system path that man page documents | The masquerade works precisely because the name checks out; only the path+signature pair is identity |

## Sources

- https://attack.mitre.org/techniques/T1036/005/ — Masquerading: Match Legitimate Resource Name or Location; adversaries give malware "the name of a legitimate, trusted program" while placing it in a different location
- Local verification 2026-08-13 (macOS, Darwin 25.1.0): `/usr/libexec/sysmond` exists (root:wheel), `man -w sysmond` → `/usr/share/man/man8/sysmond.8`, `codesign -vv` → valid on disk / satisfies its Designated Requirement, `codesign -dv` → `Identifier=com.apple.sysmond`, `Authority=Software Signing`
- Field incident 2026-08-13: during a cryptominer cleanup, root's `/usr/libexec/sysmond` (genuine) and a quarantined `~/.config/sysmond` (XMRig 6.26.0, self-identified in its log header) coexisted under one name; path-based classification separated them where a name-based kill could not
