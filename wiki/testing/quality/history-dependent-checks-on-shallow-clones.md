---
id: testing-quality-history-dependent-checks-on-shallow-clones
domain: testing
category: quality
applies_to: [general]
confidence: verified
sources:
  - https://github.com/actions/checkout
  - https://git-scm.com/docs/git-rev-parse
  - "Local reproduction, git 2.50.1 (Apple Git-155), 2026-08-14: --depth 1 clone of a 306-file repo — the boundary commit reported all 306 tracked files as added"
last_verified: 2026-08-14
related: [qa-process-scope-purity-checks, testing-quality-checks-that-cannot-pass]
---

# History-Dependent Checks Under a Shallow CI Checkout

## When this applies

A test or gate resolves git history — `git log --diff-filter`, `merge-base`,
`rev-list`, "which files did this commit add" — and can run where the checkout
is shallow. GitHub Actions is the common case: `actions/checkout` fetches only
a single commit by default (`fetch-depth: 1`).

## Do this

1. **Guard before querying:** `git rev-parse --is-shallow-repository` — on
   `true`, skip with an explicit message naming the missing capability, or
   degrade to a check that needs no history. An honest skip is recoverable; a
   false answer is not.
2. **Know the failure shape: shallow history answers falsely, it does not
   error.** The depth-1 boundary commit is grafted parentless, so
   diff-vs-parent queries attribute the entire tree to it. Reproduction
   (git 2.50.1, 2026-08-14): fresh `--depth 1` clone of a 306-file repo;
   `git log -1 --diff-filter=A --name-only` on the boundary commit listed all
   306 tracked files as "added".
3. **When the check must run in CI, deepen the fetch in the workflow** instead
   of guarding: `fetch-depth: 0` for anything needing full history
   (merge-base, tags, blame); `fetch-depth: 2` when only "this commit vs its
   parent" is needed.
4. **Validate both branches before trusting the guard**: run the check once on
   a full clone (must execute) and once on a `--depth 1` clone (must skip, not
   pass) — a guard only ever observed on full clones has not demonstrated it
   fires ([testing-quality-checks-that-cannot-pass]).

## Edge cases

| Case | Then |
|------|------|
| The check needs `merge-base` between PR head and base | On a shallow clone this can fail loudly or return a graft-truncated wrong answer — run the shallow guard first; do not rely on the command erroring |
| The gate runs locally and in CI, and only CI is shallow | The CI-side skip means CI never exercises the check — print the skip (reason included) in CI output so a permanently-skipped check stays visible, and decide whether that job should deepen its fetch instead |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Assert scope or authorship from `git log --diff-filter` output in a suite that may run shallow | Guard with `--is-shallow-repository` and skip, or deepen the fetch for that job | The boundary commit reports every tracked file as added — the assertion passes or fails on fiction either way |
| Set `fetch-depth: 0` on every job to make the problem go away | Deepen only the jobs whose checks need history | Full-history fetch cost scales with the repo's history and is paid on every run of every job |

## Sources

- https://github.com/actions/checkout — README: "Only a single commit is fetched by default, for the ref/SHA that triggered the workflow"; `fetch-depth: 0` documented as "all history for all branches and tags"
- https://git-scm.com/docs/git-rev-parse — `--is-shallow-repository`: "True if this is a shallow repository, otherwise false"
- Local reproduction (git 2.50.1, Apple Git-155, 2026-08-14): `git clone --depth 1 file://…` of a 306-file repo → `git rev-parse --is-shallow-repository` = true; `git log -1 --diff-filter=A --name-only` listed 306/306 tracked files as added by the boundary commit
