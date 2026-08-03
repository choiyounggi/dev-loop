# Consolidated review — knowledge PRs #6–#13

Eight fork PRs (`dch0202-rsquare`, 2026-07-28 → 2026-08-02) were reviewed together
against `AGENTS.md`. Each PR was audited by an independent reviewer (format rules,
sources, vague-qualifier ban, ≤120 body lines, index/log invariants), then
cross-compared to catch duplication the per-PR flushes could not see — they branched
independently off the same main and rewrote the same shared index/log files. Fork
branches can't be edited from here and several PRs needed content changes (drop a
duplicate, merge a colliding page), so this branch carries the reconciled end-state
rather than merging each PR as-is (which would import the duplicates).

## Verified best-practice

Sources are per-page and were live-verified in each originating PR's flush; the
independent re-reviews re-checked them. Landed pages and their evidence base:

| Page | Confidence | Source basis |
|------|-----------|--------------|
| backend/common/llm/completion-response-validation | verified | OpenAI reasoning guide + chat `object` spec (5 `finish_reason` values), vLLM/LiteLLM reasoning fields; field incident (200/`length`/empty content/8,173-char reasoning) |
| backend/common/llm/context-window-budget | verified | Claude context-window docs, LiteLLM exception mapping, vLLM/Claude Code env-var docs |
| backend/common/integrations/externally-owned-defaults | verified | OpenAI deprecations (notice windows) + models `list`, LiteLLM model_discovery; field incident (alias removed between PR verify and review → 400) |
| backend/common/storage/object-key-persistence | verified | AWS S3 CompleteMultipartUpload + managed-upload API/source, aws-sdk-js issues #1158/#5656 |
| infrastructure/containers/host-cgroup-visibility | field-tested | cgroup_namespaces(7), Docker `--cgroupns=host`, nsenter, k8s #103363; OrbStack repro |
| infrastructure/observability/missing-container-metrics | verified/field-tested | k8s resource-metrics-pipeline docs, kube-prometheus-stack values, kubernetes-mixin; OrbStack #2217 repro |
| platforms/environment/unicode-text-matching | verified | UAX #15, Unicode core §3.12, APFS FAQ, POSIX grep; local repro (macOS 15/APFS, grep 2.6.0-FreeBSD, Python 3.13) |
| platforms/shells/command-text-inspected-before-execution | verified | Claude Code hooks docs, POSIX shell §2.6; local reproduction |
| platforms/processes/non-interactive-cli-invocation | verified | GNU nohup, OpenBSD ssh/ssh_config, git, timeout man pages; no-request-in-gateway-log field incident |
| qa/document-verification/spec-document-gates | field-tested | ESLint, Google mutation testing, RFC 2119, Vale, markdownlint; 32/32 mutant / 62/62 intact RFC sessions |
| qa/document-verification/editing-a-gated-document | field-tested | pgrep, Vale, markdownlint; in-house editing methodology |
| testing/quality/checks-that-cannot-pass | verified | James Shore AoAD2, POSIX grep exit status, Semgrep rule-testing, pytest exit codes; BSD/ugrep measurement |
| testing/quality/spec-artifact-checks | verified | JSON Schema, ESLint RuleTester, pitest, GFM table spec; local cell-count repro + GitHub renderer cross-check |
| testing/quality/harness-reverse-controls | verified | mutation-testing + CI-control sources; field repro (re-fetched all cited URLs, PASS) |

Three pages were reconciled from two overlapping PR versions each, keeping the more
complete/better-sourced body and folding in the other's unique cases:
- **completion-response-validation** — #12 body (all five `finish_reason` values,
  `tool_calls`/`function_call` carve-out, streaming, Responses API, "reasoning is
  scratch, not deliverable") kept in `llm/` (coherent with #6/#13); folded in #6's
  DeepSeek first-party edge + the field incident.
- **externally-owned-defaults** — #12 generalized body (any repo-external resource)
  in `integrations/`; folded in #6's alias-removed field incident + the
  gateway-config-vs-live-upstream nuance.
- **non-interactive-cli-invocation** — #12 body (GNU-nohup extension precision,
  ssh -n stdin-detach vs BatchMode, pre-log DNS/TLS/proxy + `curl -v`) kept; folded
  in #11's DEBIAN_FRONTEND, pager/color TTY case, wrapper-CLI case, field incident.

## Existing-layer check

Cross-PR and against-main duplication was the focus. Findings and resolutions:

- **spec-artifact-checks (#8) ≡ document-conformance-checks (#9)** — same case
  (coverage-vs-validity split, per-check negative controls, GFM pipe parsing,
  ESLint/Semgrep/mutation examples). #9's report predated awareness of #8. →
  **#8 kept canonical; #9's page dropped, `testing/docs-as-spec` category not created.**
- **completion-response-validation (#6) ≈ llm-response-completeness (#12)** — ~95%
  same case (HTTP 200 ≠ usable output; `length`/blank/reasoning-budget). →
  **merged into one `llm/` page; #12's `integrations/` copy dropped.**
- **gateway-model-alias-defaults (#6) ≈ externally-owned-defaults (#12)** — ~80%;
  #12 generalizes the model-alias case to any external resource. →
  **kept the general `integrations/` page; #6's LLM-only page dropped.**
- **non-interactive-cli-invocation** — created by BOTH #11 and #12 (file collision).
  → **single reconciled page.**
- Distinct (no overlap, all landed): checks-that-cannot-pass, harness-reverse-controls,
  spec-document-gates, editing-a-gated-document, unicode-text-matching,
  command-text-inspected-before-execution, object-key-persistence, context-window-budget,
  host-cgroup-visibility, missing-container-metrics.
- Reciprocal `related:` links added on existing pages (tests-that-cannot-fail,
  timeouts-and-retries, environment-config, release-gates, background-services,
  portable-shell-scripts, timezone-and-locale, paths-case-and-line-endings,
  acceptance-criteria, resource-limits-and-probes, logs-metrics-signals,
  minimum-case-set). A dropped-page backlink (#6 → gateway-model-alias-defaults on
  environment-config and release-gates) was retargeted to externally-owned-defaults.
- Invariants verified programmatically: all `related:`/inline `[id]` references
  resolve, every page listed in its domain index, no duplicate ids, no page >120
  body lines.

## Routing decision

- `backend/common/llm/` (new) — LLM-specific server concerns: completion-response-validation,
  context-window-budget. Coherent home shared by #6 and #13.
- `backend/common/integrations/` (new) — general repo-external-dependency concern:
  externally-owned-defaults. Kept separate from `llm/` because its scope is any
  external resource (bucket/queue/index), not LLM-only.
- `backend/common/storage/` (new) — object-key-persistence.
- `qa/document-verification/` (new) — spec-document-gates, editing-a-gated-document.
  Introduced by both #10 and #11; unified into one index section.
- `testing/quality/` (existing) — checks-that-cannot-pass, spec-artifact-checks,
  harness-reverse-controls (test/check-authoring discipline, distinct from
  qa/document-verification which is release-process gate design).
- `platforms/{environment,shells,processes}/` (existing) — unicode-text-matching,
  command-text-inspected-before-execution, non-interactive-cli-invocation.
- `infrastructure/{containers,observability}/` (existing) — host-cgroup-visibility,
  missing-container-metrics.

Source PRs #6–#13 are closed with a disposition comment crediting the author.
