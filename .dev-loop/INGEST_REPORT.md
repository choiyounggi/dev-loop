# Consolidated review — knowledge PRs #6–#13

Eight fork PRs (`dch0202-rsquare`, 2026-07-28 → 2026-08-02) were reviewed together
against `AGENTS.md`. Each PR was audited by an independent reviewer (format rules,
sources, vague-qualifier ban, ≤120 body lines, index/log invariants) and then
cross-compared to catch duplication the per-PR flushes could not see (they branched
independently and rewrote the same shared files).

## Landed (12 pages)

| Page | From | Note |
|------|------|------|
| infrastructure/containers/host-cgroup-visibility | #6 | as-is |
| infrastructure/observability/missing-container-metrics | #6 | as-is |
| testing/quality/checks-that-cannot-pass | #7 | as-is |
| testing/quality/spec-artifact-checks | #8 | as-is; canonical for spec/doc conformance-checks |
| backend/common/storage/object-key-persistence | #9 | as-is |
| platforms/environment/unicode-text-matching | #10 | as-is |
| qa/document-verification/spec-document-gates | #10 | as-is |
| platforms/shells/command-text-inspected-before-execution | #11 | as-is |
| qa/document-verification/editing-a-gated-document | #11 | as-is |
| backend/common/llm/context-window-budget | #13 | as-is |
| testing/quality/harness-reverse-controls | #13 | as-is |
| backend/common/llm/completion-response-validation | #6+#12 | reconciled |
| backend/common/integrations/externally-owned-defaults | #6+#12 | reconciled |
| platforms/processes/non-interactive-cli-invocation | #11+#12 | reconciled |

## Reconciled (best-of-two, folded)

- **completion-response-validation** — #12's body (all five `finish_reason` values,
  `tool_calls`/`function_call` carve-out, streaming, Responses API, "reasoning is
  scratch") kept in `llm/` (coherent with #6/#13); folded in #6's DeepSeek
  first-party edge and the 8,173-char reasoning_content field incident.
- **externally-owned-defaults** — #12's generalized body (any repo-external
  resource) kept in `integrations/`; folded in #6's field incident and the
  gateway-config-vs-live-upstream nuance.
- **non-interactive-cli-invocation** — #12's body (GNU-nohup extension precision,
  ssh -n vs BatchMode, pre-log DNS/TLS/proxy + curl -v) kept; folded in #11's
  DEBIAN_FRONTEND, pager/color TTY case, wrapper-CLI case, and no-request-logged
  field incident.

## Dropped (duplicate / superseded)

- **document-conformance-checks** (#9) — same case as spec-artifact-checks (#8);
  #8 kept as canonical, `testing/docs-as-spec` category not created.
- **gateway-model-alias-defaults** (#6) — subsumed by the generalized
  externally-owned-defaults; the model-alias case is one instance.
- **llm-response-completeness** (#12) — folded into llm/completion-response-validation.

## Collisions resolved

- `non-interactive-cli-invocation.md` was created by both #11 and #12 → single
  reconciled page.
- `qa/document-verification/` and `backend/common/llm/` categories were each
  introduced by two PRs → unified index sections, one row per surviving page.

Source PRs #6–#13 are closed with a disposition comment crediting the author.
