# Findings — Tasks 04+05: harvest filtering & flush-gate audit

## Axis 4 — harvest (오토 플러시 수집단) admission filtering

What the Stop-hook harvester admits into `~/.dev-loop/queue/` (hooks/harvest.js):

| Filter | Evidence (line) | Verdict |
|--------|----------------|---------|
| Block must carry `trigger` AND `directive` | `if (!fields.trigger \|\| !fields.directive) continue` | good — unroutable/unactionable content never enters |
| Body ≥ 30 chars | `if (body.length < 30) continue` | good — rejects stubs |
| Template echo rejected | `/<[^>]+>/` test on trigger/directive | good — the instruction's own placeholders can't queue |
| Content-hash dedup, intra-session | `seen` from session queue file | good |
| Content-hash dedup vs already-flushed rows | **was missing — FIXED this run**: `seen` now also seeds from `.processed.jsonl` (read-only), regression-tested (tests/harvest.bats, red→green) | fixed |
| Recursion guard (flush checkout not harvested) | `startsWith(flushRepo)` | good, tested |
| Source-side quality bar | SessionStart instruction: "verified best-practice or real edge case… 0–3 per session… a guess is worse than nothing" | good — filtering starts at generation, not only collection |

Design judgment: harvest is deliberately a **cheap offline collector**; the
*quality* bar is enforced downstream (flush research/verify/dedup) and at the
source (instruction). That split is sound — a Stop hook must never do network
research. 재료 필터링은 "수집은 관대하게, 승격은 엄격하게" 구조로 동작하며,
승격 단계가 게이트로 강제되므로 "아무 내용이나 PR로 가는" 경로는 없다.

Residual (→ issue, low severity):
- harvest.js enforces no per-session block cap (instruction says 0–3); a
  runaway session could queue dozens. Flush verification would drop junk, but
  auto-flush would still spend a headless run on it.
- ~35 empty per-session queue files accumulate (cosmetic).

## Axis 5 — knowledge-flush refinement / dedup / PR gates

| Control | Enforcement level | Verdict |
|---------|-------------------|---------|
| Research+verify, existing-layer dedup check, routing decision before PR | **Hard gate**: hooks/pre-flush-pr-gate.sh denies `gh pr create` without an INGEST_REPORT containing the 3 filled sections — now covered by 13 bats tests | strong |
| Confidence honesty (never upgrade unverifiable to verified) | Prose (SKILL guardrails) + owner PR review | acceptable |
| Merge-before-create / related-links (dedup with existing pages) | Prose (wiki-ingest steps 4, 7) + INGEST_REPORT "Existing-layer check" section + owner PR review | acceptable — defense in depth; the gate can prove the section exists, not that pages were read. Final arbiter is the human PR review, by design |
| No auto-merge / PR-only | Prose + repo perms; auto-flush prompt repeats it | acceptable |
| Auto-flush guards (kill switch, recursion, threshold ≥3, 1h rate limit, TTL lock) | Shell, reviewed line-by-line | solid |

### Defects found and FIXED this run
1. **Gate could not parse a quoted `--body-file` path** (`"[^ '\"\`]+"` stops at
   the quote) — yet the skill's own example quotes the path → a correct flush
   command was denied with a misleading "no --body-file found". Fixed +
   regression test (`pre-flush-pr-gate.bats` test 12, red→green).
2. **Gate could not resolve `$HOME`-prefixed paths** (only `~`), while the
   command text reaches PreToolUse unexpanded. Gate now expands `~`, `$HOME`,
   `${HOME}`; test 13 added. SKILL example also switched `$REPO` → `$HOME` with
   an explicit literal-path note citing
   wiki/platforms/shells/command-text-inspected-before-execution.md (the wiki
   already documented this exact failure class — the pipeline just wasn't
   following its own page).
3. **Dropped candidates were never retired** — SKILL step 5 said to retire "the
   flushed rows"; a candidate dropped as unverifiable stayed `pending`, kept the
   queue over the auto-flush threshold, and would re-trigger a headless flush
   every hour forever. SKILL step 5 rewritten: retire every handled row
   (ingested, merged, or dropped).

### Residual (→ issue)
- **Gate bypass window**: flush detection is command-marker-only (head
  `knowledge/`, label, INGEST_REPORT). A `gh pr create --body inline` with no
  label, head inferred from the current branch, engages nothing. Documented
  tradeoff (global-install safety); tightening option: also match
  `--title "knowledge:"` and/or have the flush prompt forbid `--body`.
- Existing-layer check verifiability: consider requiring the report to list the
  page ids read (machine-checkable against `wiki/**`), giving the gate a
  cross-reference to verify instead of free prose.
