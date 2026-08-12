---
id: security-authn-retiring-a-replaced-auth-gate
domain: security
category: authn
applies_to: [general]
confidence: verified
sources:
  - https://github.com/OWASP/ASVS/blob/master/4.0/en/0x12-V4-Access-Control.md
  - https://cwe.mitre.org/data/definitions/561.html
  - https://cwe.mitre.org/data/definitions/1188.html
  - https://cheatsheetseries.owasp.org/cheatsheets/Session_Management_Cheat_Sheet.html
last_verified: 2026-08-12
related: [security-authn-session-vs-token, security-authz-resource-level-checks, infrastructure-config-environment-config]
---

# Retiring the Old Gate After an Authentication Mechanism Changes

## When this applies

You replaced one authentication mechanism with another — basic-auth to member
accounts, session key A to session key B, a shared password to per-user login —
and authentication now fails or passes on only some routes or some users. Also
when you are reviewing such a cutover before it ships, or a route behaves
differently in production than in local development.

## Do this

1. **Census the old gate's state key across the whole codebase** before trusting
   the cutover — search for every read and every write of the retired key
   (`session["authed"]`, a cookie name, a request attribute):

   ```sh
   grep -rn 'session\["authed"\]' --include='*.py' .   # readers and writers together
   ```

2. **Classify each key by its read/write counts.** The ratio names the defect:

| Readers | Writers | Meaning |
|---------|---------|---------|
| ≥1 | ≥1 | Still live — decide whether this route is in scope for the cutover |
| ≥1 | 0 | The migration missed this route: it gates on a value nothing sets any more |
| 0 | ≥1 | The new gate reads something else — the write is dead and can go with the old gate |
| 0 | 0 | Fully retired |

3. **Delete the old gate and its key in the same change that adds the new one**,
   so no route is left reading a value with no writer — CWE-561 dead code
   survives precisely because it looks like a working check.
4. **Give the new gate a deny default.** Missing configuration, an absent
   session value, and an exception all resolve to "not authenticated" — ASVS
   4.1.5 requires access controls to fail securely including when an exception
   occurs.
5. **Run the regression test in the configuration production uses.** Parameterize
   the test over the environment variable that decides the old gate's fallback
   and assert the authenticated outcome in both arms.

## Edge cases

| Case | Then |
|------|------|
| The old gate reads "config empty → allow" | This is why the bug is invisible locally: development leaves the setting unset and every request passes, while production sets it and every request is refused. Cover both arms in tests before removing the fallback (CWE-1188, an insecure default) |
| The key is written by a template, middleware, or a framework hook rather than a route | Widen the census to templates and config before declaring zero writers; `grep` the bare key name, not only the code expression |
| The old and new mechanism must run side by side during a rollout | Give each its own key and make the composite decision explicit in one place; leaving one key readable by both gates makes the retirement untestable |
| The retired mechanism gated a route you did not know existed | The zero-writer readers are the inventory — treat each hit as a route to re-gate, not as noise to clean up |
| Sessions issued under the old mechanism are still in the store | Invalidate them at cutover; a session minted under the old gate carries the old claim shape |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Declare the cutover done because login and the routes you touched work | Run the read/write census on the old key and re-gate every zero-writer reader | The routes you did not touch are exactly the ones that kept the old gate, and they pass locally |
| Leave the old key's check in place "in case something still sets it" | Remove the check with the mechanism, or point it at the new key | A check on a value with no writer is not a fallback — it is a gate whose outcome is decided entirely by its own default |
| Keep an "unset config means allow" fallback so local development stays convenient | Default to deny and supply a development credential through the same configuration path | The convenience default is the production behavior when the config load fails, which is when you need the gate most |
| Test only the environment your machine is in | Parameterize the test on the setting that changes the fallback, asserting both arms | A single-arm test proves the arm production does not run |

## Sources

- https://github.com/OWASP/ASVS/blob/master/4.0/en/0x12-V4-Access-Control.md — V4.1.5: "Verify that access controls fail securely including when an exception occurs"; V4.1.3 states the least-privilege requirement the retired gate stops enforcing
- https://cwe.mitre.org/data/definitions/561.html — CWE-561 Dead Code: "The product contains dead code, which can never be executed … The surrounding code makes it impossible for a section of code to ever be executed"; a gate whose key no writer sets can only take its default branch
- https://cwe.mitre.org/data/definitions/1188.html — CWE-1188, insecure default initialization: a default chosen for convenience becomes the security decision when the intended value is never supplied
- https://cheatsheetseries.owasp.org/cheatsheets/Session_Management_Cheat_Sheet.html — session state is server-authoritative; a claim in the session is trustworthy only where the application still writes it
- Field incident 2026-08-12 (`chungyak-alimi`, FastAPI/Starlette sessions): after a basic-auth → member-account cutover, `/notice/{no}` still gated on `session["authed"]` while no code set it any more. With `WEB_USER` unset (local) the old gate's empty-config fallback allowed every request and the suite was green; with `WEB_USER` set (deployed) logged-in members were redirected 303 instead of served 200. The reproduction test failed only when parameterized with `WEB_USER=admin`
