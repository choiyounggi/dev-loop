---
id: infrastructure-ci-cd-review-bot-adopted-as-a-blocking-gate
domain: infrastructure
category: ci-cd
applies_to: [general]
confidence: verified
sources:
  - https://raw.githubusercontent.com/alibaba/open-code-review/main/action.yml
  - https://raw.githubusercontent.com/alibaba/open-code-review/main/cmd/opencodereview/review_cmd.go
  - https://raw.githubusercontent.com/alibaba/open-code-review/main/scripts/github-actions/post-review-comments.js
last_verified: 2026-09-08
related: [qa-process-llm-review-pipelines, infrastructure-ci-cd-pipeline-structure, infrastructure-ci-cd-secret-needing-gate-on-fork-prs]
---

# A Review-Bot CLI's Exit Code Trusted as a PR-Blocking CI Gate

## When this applies

Adopting a third-party AI/LLM code-review CLI (e.g. alibaba/open-code-review,
"OCR") or its official GitHub Action as a check meant to block a PR on
findings; the tool's own docs describe it as a "review" without stating
whether its exit code reflects findings versus a run failure; the shipped
Action already has a job-failure step and you must decide whether it gates
on severity.

## Do this

| Case | Do |
|------|----|
| Wiring a review CLI/Action into a check you want to block a PR | Read the tool's exit-code contract from its source before trusting it; "reports issues" and "exits non-zero" are separate facts. OCR's contract (`cmd/opencodereview/review_cmd.go`, `reviewResultError`): non-zero only for a run-level failure or when every selected item failed; any usable coverage, complete or partial, exits 0 regardless of how many findings it reported |
| The official Action already has a "fail the job" step (OCR's `action.yml` has "Fail job on OCR error", `if: env.OCR_EXIT_CODE != '0'`) | Confirm what feeds that condition before relying on it — it mirrors the CLI's own exit code, so it fails on a crash/incomplete-coverage run, not on findings or severity |
| Checking whether the Action's comment-posting logic can itself gate a review | Verify whether it ever submits a change-requesting review event, or only a comment event. OCR's poster (`scripts/github-actions/post-review-comments.js`) submits every review with `event: "COMMENT"` at every `createReview` call site; there is no request-changes or job-failing path in that script |
| The PR must actually block on findings above a severity threshold | Add your own CI step, after the official Action's steps and in the same job, that parses the tool's structured result and fails the job on the threshold you define. OCR's Action step writes its raw result to a fixed runner path (`ocr review --format json > /tmp/ocr-result.json`), so a follow-up step in the same job reads that file directly — no artifact download needed |
| Deciding which output format to parse | Use the JSON the shipped Action already produces (`--format json`) unless you call `ocr review` yourself with a SARIF flag; OCR implements SARIF v2.1.0 output (`cmd/opencodereview/sarif.go`) for tooling that consumes that format instead |

## Edge cases

| Case | Then |
|------|------|
| Calling `ocr review` yourself outside the shipped Action | The same exit contract applies — capture stdout to a file yourself and parse it for findings; `$?` reflects run health, not findings |
| The tool exposes routing inputs by severity/category (OCR has `route_severity_below`, `route_categories`) | These only move findings between inline comments and the PR summary; they do not fail the job — keep the severity-threshold step from Do this as the gate and use routing inputs only for comment placement |
| Your parsing step must tell "review crashed" apart from "review found nothing" | Check the upstream exit code first; a non-zero exit means the result file may be partial or absent, so run your severity parse only after confirming exit 0 |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Rely on a review CLI's exit code, or its official Action's default job outcome, to block a PR on findings | Add your own step that parses the JSON/SARIF result and fails on a severity threshold you define | Verified: OCR's exit code is a crash/incomplete-coverage signal only; every posted review uses `event: "COMMENT"`, never a change-requesting event |
| Assume a review-bot CLI that reports issues also fails its own process or job on them | Read the tool's exit-code contract in its source before wiring it into a gate | Reporting findings and gating a job are independent design choices a tool may or may not couple |

## Sources

- https://raw.githubusercontent.com/alibaba/open-code-review/main/action.yml — "Run OpenCodeReview" step (`ocr review "${ARGS[@]}" > /tmp/ocr-result.json`), "Fail job on OCR error" step (`if: env.OCR_EXIT_CODE != '0'`), "Post review comments" step (`if: env.OCR_EXIT_CODE == '0'`)
- https://raw.githubusercontent.com/alibaba/open-code-review/main/cmd/opencodereview/review_cmd.go — `reviewResultError`: "The exit contract is: non-zero only for a run-level failure, or when every selected item failed. Any usable coverage — even incomplete — exits 0"
- https://raw.githubusercontent.com/alibaba/open-code-review/main/scripts/github-actions/post-review-comments.js — every `createReview` call passes `event: "COMMENT"` (verified at three call sites); no request-changes or job-failing path found in the file
