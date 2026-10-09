---
id: security-agent-exposure-capability-flag-across-adapters
domain: security
category: agent-exposure
applies_to: [general]
confidence: verified
sources:
  - https://cwe.mitre.org/data/definitions/636.html
  - https://cheatsheetseries.owasp.org/cheatsheets/Secure_Product_Design_Cheat_Sheet.html
  - https://github.com/badlogic/pi-mono/issues/555
last_verified: 2026-09-28
related: [security-agent-exposure-authorization-scope-persistence, backend-common-api-design-unenforced-declarations, testing-mocking-captured-call-arguments, security-authn-retiring-a-replaced-auth-gate]
---

# A Capability-Restriction Flag in a Shared Config That Only Some Adapters Enforce

## When this applies

A spawner drives several interchangeable backends through one config struct —
agent-harness adapters (claude / codex / pi), CI runners, sandbox providers,
storage drivers — and the struct carries a restriction flag (`tool_use: false`,
write confinement, network off, read-only) that one adapter implements and the
others never read. Also when a caller sets that flag for every backend and
downstream automation (auto-commit, merge, push, deploy) treats the flag as the
guarantee that the backend ran confined; and when reviewing a new adapter added
to such a struct.

## Do this

1. **Census which adapters read the flag.** Grep the field name across every
   adapter implementation; each adapter with zero reads runs at its own default
   permissions whatever the caller set. That is CWE-636 "Not Failing Securely":
   the product falls "back to a state that is less secure than other options
   that are available, such as … using the most permissive access control
   restrictions".
2. **Make every non-enforcing adapter refuse the flag with an explicit error
   before spawning.** Refusal at spawn time is the fail-closed arm; a silently
   ignored restriction is a recorded-but-unenforced declaration that reads as
   protection to everyone downstream
   ([backend-common-api-design-unenforced-declarations]).
3. **Gate the flag at the caller on the adapter id** — set it only for adapters
   whose enforcement exists — so the caller's promise and the adapter's behaviour
   agree in code. Step 2's refusal then runs as defence in depth, not as the
   normal path.
4. **Pass each adapter's own lock-down switch unconditionally.** Least privilege
   is "the minimum amount of access necessary to perform their job"; pi ships
   `--no-tools` ("Disable all tools by default (built-in and extension)"). With
   the adapter-native switch always present, the shared flag selects among
   already-confined invocations instead of being the only thing standing between
   the agent and its default permissions.
5. **Test the true arm per adapter.** For each non-enforcing adapter, a test
   that sets the flag and asserts the spawn is refused — red before the fix. For
   the enforcing adapter, assert the spawn command carries its confinement
   argument ([testing-mocking-captured-call-arguments]). Per-adapter reviews
   miss this class because the flag was false everywhere when the adapter was
   written.

| Adapter | Caller | Adapter |
|---------|--------|---------|
| Implements the restriction | Sets the flag | Passes its own confinement args; a test asserts them |
| Does not implement it | Leaves the flag unset (gate on adapter id) | Refuses with an explicit error naming the flag and the adapter if reached anyway |
| Added after the flag existed | Inherits the gate's default: unset | Exhaustive dispatch (a `match` with no wildcard arm, a `supports(flag)` method defaulting to `false`) forces the decision at compile or review time |

## Edge cases

| Case | Then |
|------|------|
| The adapter enforces part of the restriction (read-only tools yes, network off no) | Refuse the sub-capability it cannot enforce; partial enforcement reported as full is the same weakness |
| Downstream automation already trusted the flag for past runs | Treat every earlier run under a non-enforcing adapter as unconfined and audit its outputs (commits, pushes, writes) before trusting the flag going forward |
| Existing tests exercise only the false arm | Add the true arm per adapter — a review that sees the flag false everywhere approves an adapter that never reads it |
| The adapter's CLI has no lock-down switch at all | Refuse the flag for that adapter and record it in the adapter table; the spawner emulating confinement around an unconfined process is not enforcement |
| The flag is read but only to write a log line or a status field | Count that as zero enforcement in step 1 — the read is cosmetic, the permissions are unchanged |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Set a restriction flag for all backends in one shared config | Gate it on the adapter id and refuse it in every adapter that cannot enforce it | Field incident 2026-09-28: the pi adapter never read the flag; a RED test showed pi spawned with the restriction set and no confinement argument |
| Ignore an unsupported config field in an adapter so the spawn "just works" | Return an explicit error naming the flag and the adapter | CWE-636: failing functional instead of failing safe "causes administrators to have a false sense of security" |
| Rely on the shared flag alone for confinement | Pass the adapter's native lock-down flag on every spawn | Secure by default: the confined invocation stops depending on the shared struct being interpreted |

## Sources

- https://cwe.mitre.org/data/definitions/636.html — CWE-636 "Not Failing Securely ('Failing Open')": "When the product encounters an error condition or failure, its design requires it to fall back to a state that is less secure than other options that are available, such as … using the most permissive access control restrictions"; "At the least, it causes administrators to have a false sense of security. This weakness typically occurs as a result of wanting to 'fail functional' to minimize administration and support costs, instead of 'failing safe.'"
- https://cheatsheetseries.owasp.org/cheatsheets/Secure_Product_Design_Cheat_Sheet.html — Principle of Least Privilege: "users should only be given the minimum amount of access necessary to perform their job"; Fail Securely: "Design systems to fail in a secure state, rather than exposing vulnerabilities when they malfunction"; Secure by Default: "Configure systems and software to be secure by default, with minimal manual setup or configuration required"; Defense-in-Depth: "multiple layers of security controls"
- https://github.com/badlogic/pi-mono/issues/555 — the request that added `--no-tools` to the pi coding agent (closed); `pi --help` on 2026-09-28 lists `--no-tools, -nt  Disable all tools by default (built-in and extension)`, and the package CHANGELOG records that "`--no-tools` now disables all tools by default rather than only built-ins" (#2835, #3452) — the adapter-native lock-down switch step 4 passes unconditionally
- Field incident 2026-09-28 (a Rust multi-agent runner, `crew-run`, task t7): `role_harness_cfg` set `tool_use` for every harness; `pi.rs` never read the field, so pi ran with default tool access while the run's commit/merge/push automation trusted the flag. A RED test asserting refusal showed the pi spawn attempted with `tool_use=true`; the fix gated the flag on the adapter id at the caller, made each non-supporting adapter return an explicit error before spawning, and passed `--no-tools` unconditionally
