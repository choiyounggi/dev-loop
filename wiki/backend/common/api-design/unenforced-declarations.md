---
id: backend-common-api-design-unenforced-declarations
domain: backend
category: api-design
applies_to: [general]
confidence: verified
sources:
  - https://github.com/kubernetes/enhancements/blob/master/keps/sig-api-machinery/2885-server-side-unknown-field-validation/README.md
  - https://kubernetes.io/blog/2023/04/24/openapi-v3-field-validation-ga/
  - https://json-schema.org/draft/2020-12/json-schema-validation
last_verified: 2026-08-05
related: [security-input-validation-at-trust-boundaries, infrastructure-config-environment-config, backend-common-api-design-error-responses, qa-process-acceptance-criteria, backend-common-change-impact-widening-a-closed-value-table, platforms-processes-tool-diagnostics-without-a-failing-exit-code]
---

# Accepting a Declaration the System Does Not Enforce

## When this applies

Your system takes declarative input — a config file, a DSL or manifest, a policy
block, a schema annotation — and some of what a caller can write is not
implemented: an unknown key, a verb outside your vocabulary, or a knob that is
recorded but never acted on. Also when a user reports "I declared X and nothing
happened", or a feature was "configured" in an environment where it never ran.

## Do this

1. **Separate the two failure shapes and give each its own diagnostic**, because
   they read identically to the author — nothing happened:

| Shape | Meaning | Emit |
|-------|---------|------|
| Unrecognized | The name is not in your vocabulary at all | Reject, naming the unknown token and the accepted set |
| Recognized but unenforced | You parse and store it, but no code path acts on it | Accept and warn, naming the declaration and what it does *not* do |

2. **Resolve declarations by lookup in a closed, enumerable table, not by
   inference.** A lookup has a defined miss (the name is absent → diagnostic); an
   inference silently produces a plausible no-op for anything that looks close.
   Keep the table one artifact, so "what does this system accept" has a single
   answer.
3. **Offer the strictness as a caller-selected level rather than one global
   choice** — `Ignore` / `Warn` / `Strict` — so a caller can demand rejection in
   CI while a compatibility path keeps warning. Kubernetes made exactly this
   split a first-class request parameter.
4. **Default new surfaces to rejection.** Accept-and-ignore is a compatibility
   affordance for a surface that already shipped with it, not a starting point;
   once callers depend on silent acceptance, tightening it is a breaking change.
5. **Publish the enforcement status next to the vocabulary.** Every declaration a
   caller can write gets a row saying what the system actually does with it, and
   that table is derived from the code that implements it, not maintained beside
   it ([testing-quality-spec-artifact-checks]).
6. **Make deliberate use possible.** Declaring something you know is recorded but
   unenforced is legitimate — documenting intent, staging a rollout. The defect
   is doing it unknowingly, so the warning must be suppressible per declaration
   with an explicit acknowledgement, not by lowering the level globally.

## Edge cases

| Case | Then |
|------|------|
| A newer client sends a field this older server has not learned yet | Warn rather than reject on the server, and let the *client's* strict mode catch it at author time; rejecting forward-compatible traffic breaks rolling upgrades |
| The declaration is enforced on one execution path but not another | Report it as unenforced on the path that ignores it, keyed by path — a single global status makes one of the two paths lie |
| The vocabulary is generated (parsed from a schema or enum) | Assert the parsed table is non-empty before using it to validate; an empty table accepts everything and turns strict mode into a no-op |
| Enforcement is measured but not applied (a budget reported, never imposed) | Say so in the diagnostic's wording — "measured, not enforced" — so a reader does not infer a guarantee from the value appearing in output |
| Rejecting would break an existing deployment | Ship the warning first with the version that starts rejecting named in the message, then flip the default |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Ignore an unrecognized key so the parse "just works" | Reject it, naming the unknown token and the accepted set | Silent acceptance turns a typo into a feature that never ran, discovered in production instead of at parse time |
| Infer an action for a verb outside your vocabulary because it looks close | Look it up in the closed table and fail the miss | Inference has no defined miss, so an unsupported name produces a plausible no-op instead of a diagnostic |
| Record a policy/security declaration and treat its presence as the guarantee | Emit what is recorded-only, and keep the enforcement table alongside the vocabulary | A declaration that only annotates reads as protection to everyone downstream who sees it in the source |
| Add a global "strict mode" flag nobody turns on | Make the level a per-request/per-invocation parameter with rejection as the default for new surfaces | A global opt-in stays off, so the diagnostics exist without reaching anyone |

## Sources

- https://github.com/kubernetes/enhancements/blob/master/keps/sig-api-machinery/2885-server-side-unknown-field-validation/README.md — KEP-2885 defines three server-side validation levels selected per request via `?fieldValidation=`: `Strict` ("erroring on unknown fields"), `Warn` (errors returned as warnings in response headers), and `Ignore` (no validation); it moves the decision from each client to the server so unrecognized fields are not simply accepted
- https://kubernetes.io/blog/2023/04/24/openapi-v3-field-validation-ga/ — Server Side Field Validation reached GA in Kubernetes 1.27, validating create, update and patch requests at the apiserver
- https://json-schema.org/draft/2020-12/json-schema-validation — `additionalProperties` is the schema-level control over whether properties outside the declared set are permitted; strictness is an explicit schema decision rather than a parser default
- Field observation 2026-08-05: a declarative platform carried two issues with the same root — step verbs outside its closed lexicon compiled to silent no-ops, and `security`/`policy`/`performance` declarations were recorded without being enforced. Both were resolved by one enforcement matrix generated from the implementing constants plus a diagnostic channel that names the unenforced declaration
