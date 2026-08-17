---
id: testing-quality-value-preserving-refactor-assertions
domain: testing
category: quality
applies_to: [general]
confidence: field-tested
sources:
  - https://docs.pytest.org/en/stable/how-to/monkeypatch.html
  - https://docs.python.org/3/library/unittest.mock.html
  - https://stryker-mutator.io/docs/mutation-testing-elements/equivalent-mutants/
  - https://pitest.org/quickstart/basic_concepts/
last_verified: 2026-08-06
related: [testing-quality-tests-that-cannot-fail, testing-quality-harness-reverse-controls, testing-quality-behavior-not-implementation, testing-quality-minimum-case-set, testing-quality-unasserted-return-fields, testing-quality-checks-that-cannot-pass, backend-common-change-impact-call-site-enumeration]
---

# Regression Tests for a Value-Preserving Refactor

## When this applies

You replaced a hardcoded literal with a read from config, a constants module, or
another single source of truth (`"DB ×1.3"` → `"DB ×%s" % E.DB_MULT`), the
current config holds the same value the literal did, and you are adding the test
that stops the literal from coming back. Also when reviewing such a test.

## Do this

1. **Render the output under the current config and compare it byte-for-byte
   with the literal you removed, before writing any assertion.** When the two
   strings are equal, the refactored and the reverted-literal versions produce
   identical output *for that config value*, so every assertion that holds the
   config fixed passes on both. The separating input exists — it is the config
   value itself — and the test's job is to vary it.

2. **Choose the assertion target from that comparison:**

| Byte comparison of output vs. removed literal | Assert |
|---|---|
| Differs (the refactor changed the rendering) | The new output directly; the natural assertion already discriminates |
| Identical, and the value is settable through an interface a caller or operator reaches without editing source | The *dependency*: substitute the source value with a sentinel no literal would produce, then require the output to carry the sentinel |
| Identical, and the value is only reachable by editing source (module-local constant, build-time inlining) | Nothing at unit level — the reversion is invisible to any test that respects the public interface; put the guard in a static check (item 7) |

3. **Pick the sentinel so that the reverted code fails loudly.** Use a value
   outside the plausible range and distinct in rendering (`DB_MULT = 9.9` when
   production is `1.3`), then assert the rendered sentinel (`"DB ×9.9"`) is
   present. On the reverted version the output still reads `DB ×1.3`, so the
   presence assertion is what fails — it is the discriminator. Add "the
   production literal is absent" as a second assertion when the renderer could
   emit both values; it is a supplement, not the detector.

4. **Substitute through the seam the caller or operator uses**, not a private
   field: the config object, the environment variable, the injected parameter,
   the CLI flag. That keeps the assertion a behavior claim — *the output follows
   the configured value* — which is why it does not conflict with
   [testing-quality-behavior-not-implementation]; see its own edge row for the
   boundary.

5. **Restore the value with the runner's scoped patcher rather than a
   hand-rolled `try/finally`.** pytest's `monkeypatch` states that "All
   modifications will be undone after the requesting test function or fixture
   has finished", and `monkeypatch.context()` applies a patch "only in a
   specific scope". Both forms restore on assertion failure, so pick the fixture
   for the reasons that do differ: there is no restore code to review, it undoes
   patches applied in a *fixture* whose test body never runs, and it composes
   with fixture teardown ordering instead of competing with it.

6. **Patch the name the renderer looks up, not the name where the value is
   defined.** `patch()` "works by (temporarily) changing the object that a
   *name* points to", so "you must ensure that you patch the name used by the
   system under test". When a module copied the constant into a local at import
   time it never reads the substitution, and the sentinel assertion then fails
   *on correct code* — read that red as a wrong patch site, not as a caught
   regression, and move the patch to the name the renderer reads.

7. **Know all three detectors and pick by reachability of the value:**

| Detector | Use when |
|---|---|
| Sentinel substitution asserted in a test | The value is settable through a caller- or operator-reachable interface |
| A red control run against a copy with the literal restored | Once, to prove whichever assertion you wrote can fail at all ([testing-quality-tests-that-cannot-fail] for the restore mechanics) |
| A static check that greps for the literal outside the SSOT | The value is module-local or inlined at build time, so no test can observe the difference ([testing-quality-checks-that-cannot-pass] for authoring that gate) |

## Edge cases

| Case | Then |
|------|------|
| The constant is one of several the output renders | Substitute one constant per test so a red run names which read regressed; a single test substituting all of them cannot localize the reversion |
| The value is a float and the rendering rounds it | Pick a sentinel that survives the rounding (differs in a kept digit), and assert the rendered form rather than the raw value |
| The refactor moved the literal into the same module's own constant, no operator can set it | Take the static-check row of item 7 — asserting a substitution of a module-local private is an implementation-detail assertion, and re-inlining removes no capability a caller can observe |
| The config value legitimately equals a magic number the output already contains for another reason | Assert the sentinel-substituted output only, and drop the "production literal absent" supplement — it would match the unrelated occurrence and redden on correct code |
| Several call sites were meant to switch to the SSOT and you tested one | Enumerate the call sites and give each its own substitution assertion — a passing test on one site says nothing about the others ([backend-common-change-impact-call-site-enumeration]) |
| The sentinel assertion is red on code you believe is correct | Check the patch site first (item 6) — a name the renderer never reads produces exactly this red |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Assert the rendered text (`assert "DB ×1.3" in out`) as the refactor's regression test | Substitute the value with a sentinel through its public seam and assert the output follows | The rendered text is identical for the shipped config value, so the assertion passes on the reverted literal too — it guards nothing it was written to guard |
| Read a green run plus coverage of the changed line as proof the SSOT read is enforced | Require a red run against a copy that has the literal restored | Holding the config fixed makes the two versions indistinguishable by construction; only varying it, or a red control, discriminates |
| Wrap the substitution in `try/finally` to restore the value | Use the runner's scoped patch fixture (`monkeypatch`, `patch` as a context manager) | Both restore on failure, but the fixture leaves no restore code to review and also covers a patch applied in a fixture whose test never runs |
| Assert a substitution of a module-local constant to guard re-inlining | Put that guard in a static check for the literal outside the SSOT | A value no caller or operator can set is an implementation detail; a test asserting it fails refactors and detects no behavior change |
| Skip the byte comparison and write whichever assertion looks natural | Compute the comparison first and let its result choose the assertion target | The comparison is what tells you whether the natural assertion can fail at all |

## Sources

- https://docs.pytest.org/en/stable/how-to/monkeypatch.html — "All modifications will be undone after the requesting test function or fixture has finished"; `monkeypatch.context()` applies patches "only in a specific scope"
- https://docs.python.org/3/library/unittest.mock.html — "Where to patch": `patch()` "works by (temporarily) changing the object that a *name* points to with another one … you must ensure that you patch the name used by the system under test"
- https://stryker-mutator.io/docs/mutation-testing-elements/equivalent-mutants/ — cited as the near analogy, not as this page's mechanism: for a mutant that leaves output identical, "There is no definitive way for Stryker to find and ignore them" and "the only solution is by finding these by hand". A value-preserving refactor differs in one decisive way — the config value is an input that *does* separate the two versions, which is what makes a test possible here
- https://pitest.org/quickstart/basic_concepts/ — the same analogy from PIT: an equivalent mutation is one whose result "behaves in exactly the same way as the original"
- Field reproduction 2026-08-05 (manday report renderer): the removed literal `DB ×1.3` and `"DB ×%s" % E.DB_MULT` under the shipped config rendered byte-identical, computed before writing the test — so `assert "DB ×1.3" in out` passed on both the SSOT version and the restored-literal version. Substituting `E.DB_MULT` with a sentinel and asserting the rendered sentinel was the form that reddened on the literal version
