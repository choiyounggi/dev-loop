# knowledge(design): product-surface vs brand-surface rules, UI hardening against real content, anti-slop craft-floor rows

Source: the Impeccable design skill (github.com/pbakaus/impeccable), read at commit
114ea1d3838fca73b253af45f873b9c4f5f213c8 (2026-09-29). Origin: the user asked whether
hgko-dev.tistory.com/551 (an Impeccable install guide) should steer design work. The
guide itself is stale (`/teach-impeccable`, `.impeccable.md` and the `dist/claude-code`
path no longer exist) and carries no design knowledge; the skill's reference files do.
This PR ingests the three areas where the wiki and the hallmark skill had no coverage.

## Verified best-practice

1. **Product (Operate) surfaces invert the brand-surface rules.** New page
   `frontend-design-product-ui-vs-brand-surface`: Persuade / Operate / Read /
   Experience modes chosen from the requested surface; on Operate surfaces one tuned
   sans, fixed rem scale (1.125–1.2), Restrained color floor with a second neutral,
   full state vocabulary, skeleton loading, structural responsiveness, 150–250 ms
   state motion and no page-load sequence, standard affordances permitted, overlays
   escape overflow ancestors, modal only for interruption or protected focus.
   Verified by reading `skill/reference/operate.md` and `skill/SKILL.src.md` at the
   pinned SHA; cross-checked against the Anthropic frontend-design post the anti-slop
   page already cites. `confidence: unverified` — the sources are a third-party skill
   file and a blog post, and no production use of this wiki's own is described; the
   page says what upgrades it.
2. **UI hardening against real content.** New page
   `frontend-design-ui-hardening-against-real-content`: extreme-input test set,
   translation-expansion budget by source length, truncate / clamp / wrap with
   `min-width: 0`, logical properties + RTL glyph flip, `Intl` formatting and
   `Intl.PluralRules`, interrupted-gesture handling (`touch-action`, `pointerId`
   pinning, cancel paths), error copy with recovery, pending-state submit guard,
   virtualization. Verified live: W3C article-text-size (IBM table ≤10 chars
   200–300% … >70 chars 130%; Korean 0.8×), W3C Pointer Events (`pointercancel`
   MUST fire on stream suppression; capture implicitly released), MDN logical
   properties, `Intl` / `Intl.PluralRules`, `overflow-wrap` (only `anywhere`
   counts toward min-content), `hyphens`, `-webkit-line-clamp`, `touch-action`
   (pointercancel on browser gesture take-over), `title` accessibility concerns,
   WCAG SC 1.4.4 — all HTTP 200. `confidence: verified`.
3. **Craft-floor rows for brand surfaces.** `frontend-design-anti-slop-visual-design`
   +2 directive rows (theme browser-default surfaces from the palette; shadows carry
   offset + soft blur), +2 edge cases (route task UIs and hostile content to the new
   pages), +6 Instead-of rows (eyebrow, decorative section numbers, geometric
   occlusion mask, mono as costume, glyph icons, image hover animation). Verified by
   reading `skill/reference/craft-floor.md` at the pinned SHA. Body 85 → 96 lines.

Gap evidence: `grep -rli dashboard wiki/frontend` → 0 files; hallmark v1.1.0 has 3
"product UI" mentions and 0 `pointercancel` / RTL rules; the wiki's only Impeccable
citation was README-level (log.md 2026-08-21) because the skill's paths churn — every
new citation here is a commit-pinned permalink.

## Existing-layer check

Pages read: frontend-design-anti-slop-visual-design, frontend-design-responsive-layout, frontend-data-fetching-async-ui-states, frontend-design-design-canvas-workflow, frontend-accessibility-interactive-elements

- `wiki_search` (dev-loop-wiki MCP) was down this session (CONNECTION_CLOSED); dedupe
  was done by reading the design category index and grepping the frontend domain for
  each candidate's trigger terms (`dashboard`, `product UI`, `::selection`,
  `pointercancel`, `inline-start`, `RTL`, `i18n`, `empty state`, `skeleton`).
- anti-slop-visual-design: same trigger for the craft-floor rows → merged as rows.
  Its motion row ("spend the motion budget on one page-load") conflicts with the
  Operate rule; resolved as a condition-dependent edge-case row that routes task UIs
  to the new page, not as an overwrite.
- responsive-layout: already owns overflow / `min-width: 0` / CJK wrapping / iOS
  16px; the hardening page links to it for those rows instead of repeating them.
- data-fetching/async-ui-states: owns empty / loading / error states; the hardening
  page's edge case defers to it. Back-links added on both.
- No local layer (`wiki-local/`) exists in this repo.

## Open-PR check

Open PRs #223, #225–#231 (listed 2026-09-29 with `gh pr list --state open`) are
knowledge-flush batches touching backend, infrastructure, testing, mobile and
platforms pages; none touch `wiki/frontend/design`, `wiki/frontend/index.md` or the
three source files. Two concurrent local sessions (dev-loop-doliolid-70, -f8) had
queued the identical ingest; both confirmed zero writes and stood down before this
branch was edited.

## Routing decision

- Layer: bundled `wiki/` (general knowledge, no repo-specific files named).
- Domain: frontend. Category: design — both new pages are design-time decisions
  about how a surface is styled and verified; the hardening page was considered for
  `forms` and `accessibility` and rejected because its trigger is content shape and
  locale, not a form lifecycle or an assistive-technology contract.
- Page ids: `frontend-design-product-ui-vs-brand-surface`,
  `frontend-design-ui-hardening-against-real-content`.

## Verification

- `node scripts/wiki-lint-prohibitions.js` → directives 79 / compliant 79 /
  violations 0 (unchanged from the pre-edit baseline; rows written positively, so
  `tests/wiki-lint-prohibitions.bats:25` keeps its pin).
- `PATH=/opt/homebrew/bin:$PATH bats tests/wiki-structure-checks.bats tests/wiki-index.bats tests/wiki-lint-prohibitions.bats tests/wiki-contradiction.bats tests/wiki-index-freshness.bats tests/wiki-lint-score.bats tests/wiki-agent-gate.bats` → `1..136`, 136 ok, 0 not ok.
- Inline `[page-id]` links and `related:` ids in the three touched pages all resolve
  (grep `^id:` per id).
- No banned qualifiers (`usually`, `consider`, `might`, `generally`, `as appropriate`,
  `often`, `should`) in the two new pages.

## Independent review (before commit)

Two fresh-context reviewers (`feature-dev:code-reviewer`, one general brief and one
adversarial brief; read-only, no Bash) on the 7-file diff. Findings applied:

- anti-slop: a source bullet had been appended after the last table on a page that
  keeps its sources in frontmatter → removed; the task-UI edge case named a
  "fluid-type" row this page does not have and missed the default-font-rejection and
  extreme-contrast rows → rewritten to name the exact rows and widened to Read /
  Experience surfaces (a docs site previously had no route to the Read guidance).
- responsive-layout: the `clamp()` row stated fluid type unconditionally → scoped to
  brand/content surfaces with the app-UI alternative and a `related:` link.
- product-ui-vs-brand-surface: `field-tested` over-claimed (no production context
  described) → `unverified` with the upgrade condition in the page; trigger lines
  now list mode choice, Read/Experience surfaces, overlay clipping, modal-first
  (index/trigger drift); 65–75ch attributed to operate.md in the source line.
- ui-hardening: `min-width: 0` rationale was wrong for `overflow-wrap: anywhere`
  (only `break-word` leaves min-content unchanged) → corrected with the MDN quote;
  `title` tooltip replaced by hover+focus tooltip (MDN accessibility concerns);
  `touch-action: none` added to the drag row (MDN: browser fires `pointercancel`
  when it takes a gesture); iOS 16px row now defers to responsive-layout instead of
  restating an unsourced mechanism; WCAG 1.4.4 source added; IBM 51–70 row
  anomaly noted as published.
- Not applied: "ui-hardening bundles four topics" (both reviewers rated it below
  their confidence bar; the page's one case is "data is present but hostile" and it
  routes empty/loading/error out to async-ui-states).

After the fixes: the same seven bats wiki suites re-run → `1..136`, 136 ok, 0 not ok;
prohibitions still directives 79 / violations 0; all inline links resolve.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
