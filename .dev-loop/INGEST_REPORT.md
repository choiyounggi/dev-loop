# Knowledge flush — 1 insight(s)

Claimed 5 candidates. 1 merged into an existing page, 3 released as pending duplicates of open PRs, 1 released unread (its queue file could not be located from this headless run).

## Verified best-practice

**148c87323cc771e9 — CSS `display` overrides the `hidden` attribute.** Claim: when a CSS rule sets `display: flex|grid|block` on an element toggled with `hidden`, the element stays visible; fix with `[hidden] { display: none !important; }`, a `:not([hidden])` selector, or a class toggle, and confirm with a rendered check.

- WHATWG HTML, Rendering §15.3.1 (https://html.spec.whatwg.org/multipage/rendering.html): the user-agent rule is `[hidden]:not([hidden=until-found i]):not(embed) { display: none; }` — a normal (not `!important`) UA declaration, so any author `display` wins.
- MDN `hidden` (https://developer.mozilla.org/en-US/docs/Web/HTML/Reference/Global_attributes/hidden): "changing the value of the CSS `display` property on a hidden element will override the hidden state".
- MDN Specificity (https://developer.mozilla.org/en-US/docs/Web/CSS/Guides/Cascade/Specificity): attribute selectors weigh 0-1-0, same as a class; on a tie the later declaration applies. So a reset's `[hidden] { display: none }` without `!important` still loses to a later `.empty { display: flex }`.
- Corroborating reports: twbs/bootstrap#38936 (https://github.com/twbs/bootstrap/issues/38936), govtech-bb/govbb-design-system#244 (https://github.com/govtech-bb/govbb-design-system/issues/244).
- Session evidence: Playwright `isVisible()` reproduced `.empty{display:flex}` + `hidden` rendering at 259 px height beside 3 member rows.

Confidence: verified for the mechanism. The page keeps its existing `confidence: field-tested` because its other rows (the gate script) rest on a trial.

## Existing-layer check

Pages read: frontend-design-rendered-ui-gate-for-agent-built-screens, frontend-data-fetching-async-ui-states

`wiki_search` top hits for the trigger: frontend-accessibility-interactive-elements, testing-quality-markup-contract-assertions, frontend-security-xss-safe-rendering, frontend-design-design-system-lint-gate-for-agents, frontend-design-ui-hardening-against-real-content. None covered this; the frontend `index.md` "load when" for `rendered-ui-gate-for-agent-built-screens` already names "a `display` rule overriding `hidden`".

Overlap: that page already carries the directive (fix row with `[hidden] { display: none !important; }` or a class toggle, MDN source, and the same 2026-11-12 trial as evidence). Merged, not created: the existing finding row gained the `:not([hidden])` option and the equal-specificity reset case; two sources added to frontmatter. The page body was at the 120-line cap, so the addition went into the existing row instead of a new edge row. No conflicts. No new `related:` links (the adjacent pages are already linked). `log.md` entry appended.

## Open-PR check

24 open `knowledge/*` PRs (#293–#335). This headless run cannot diff them, so overlap was judged from each PR's title and touched `wiki/` paths (`gh pr list --json number,title,files`).

| Candidate | Overlapping open PR | Verdict |
|-----------|---------------------|---------|
| 148c87323cc771e9 (CSS `hidden` vs `display`) | none — no open PR touches `wiki/frontend/` | new → merged |
| b5863e2d758c98fb (Claude Code gateway + leftover OAuth login) | #328 (`platforms/processes/spawning-an-agent-cli-from-a-server.md`, gateway env), #298 (`backend/common/llm/gateway-model-alias-resolution.md`) | pending duplicate → claim released |
| ea0395bace6acb63 (re-measure suite runtime before setting a gate timeout) | #330 (gate per-CHECK timeout, `infrastructure/agent-orchestration/gate-evidence-exit-code-class.md`) | pending duplicate → claim released |
| 3854abb03a001de5 (idle-after latency on Apple Silicon) | #335 (`backend/common/ml/inference-device-choice-on-apple-silicon.md`, `self-hosted-model-load-latency.md`) | pending duplicate → claim released |
| fc76dc4dfa08ecde | not assessed — row content unreadable in this run | claim released for the next run |

## Routing decision

148c87323cc771e9 → frontend / design / `rendered-ui-gate-for-agent-built-screens` (merge into the existing finding row). General web-platform behaviour, not project-specific. No new category.

## Local-layer candidates

none
