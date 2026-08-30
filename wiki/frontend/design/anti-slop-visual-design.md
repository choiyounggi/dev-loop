---
id: frontend-design-anti-slop-visual-design
domain: frontend
category: design
applies_to: [css, general]
confidence: field-tested
sources:
  - "hallmark skill v1.1.0 (anti-AI-slop design skill; distills Anthropic's frontend-design skill, the Claude cookbook on frontend aesthetics, and the 2026 tactile-rebellion consensus)"
  - "https://claude.com/blog/improving-frontend-design-through-skills — Anthropic Engineering, 2025-11-12 (distributional-convergence mechanism, font avoid-list + taxonomy, extreme-contrast thresholds, domain-derived aesthetic direction, second-order convergence warning; Korean translation: velog.io/@xxziiko)"
  - "https://github.com/pbakaus/impeccable — README (gray-text-on-colored-background and bounce/elastic-easing anti-patterns; command list unstable across versions, cited for README-level rules only)"
last_verified: 2026-08-21
related: [frontend-design-html-in-canvas, frontend-accessibility-interactive-elements, frontend-design-responsive-layout, frontend-design-design-canvas-workflow]
---

# Making Web UI Look Designed, Not Generated

## When this applies

Building or restyling web UI without a designer's spec; a page or component reads
as "AI-generated"; choosing colors, fonts, layout structure, or motion for new UI;
reviewing a UI diff for template tells.

## Do this

Work in this order — structure decisions precede visual ones:

1. Read the project's existing fonts, palette tokens, spacing scale, and motion
   libraries before restyling anything; preserve them unless asked otherwise.
2. Settle three inputs before code: the audience, the single action the page
   drives, and a tone extreme (editorial / brutalist / soft / utilitarian /
   luxury / playful / technical). "Clean and modern" is not a tone. Derive the
   direction from the app's subject matter (an RPG tool gets dramatic palettes
   and ornament; a trading tool gets terminal density) — the default output of
   an unsteered generation is the generic theme, so committing to a
   domain-derived direction IS the default here, not an upgrade.
3. Pick the page's structure (heading placement, section rhythm, divider
   language) before any visual styling, and vary it between pages — two pages
   sharing the hero → 3-feature-grid → CTA rhythm read as one template no matter
   the colors. The AI tell is structural repetition, not color choice.
4. Declare every color and font as a CSS custom property once, then reference
   only `var(--token)`. A value that does not exist as a token gets added to the
   token block first — inline hex/oklch mid-file is how a 3-color system becomes
   an 8-color freestyle.
5. Audit the result against the tells table below. One tell is a problem; two in
   the same view is a confirmation.

Color:

| Rule | Detail |
|------|--------|
| Use OKLCH for every color | Perceptually uniform, so lightness is predictable; hsl/rgb lie about brightness |
| One accent (two max), ≤3% of any viewport | Accent is a highlighter: active nav item, focus ring, link-hover underline, CTA border — not section backgrounds or giant button fills |
| No pure `#000`/`#fff` | Tint paper and ink toward the anchor hue: light paper `oklch(96–98% 0.005–0.015 H)`, dark paper `oklch(12–16% 0.008–0.015 H)` |
| Tint the grays toward the anchor hue | A warm accent with cool-gray body copy reads wrong even to viewers who can't name why; on colored surfaces, tint the text toward the surface hue too — neutral gray text on a colored background is a recognized generated-design tell |
| One dominant color field, sharp minority accent | "Dominant colors with sharp accents outperform timid, evenly-distributed palettes" (Anthropic); draw palette direction from IDE themes and cultural aesthetics rather than generic web-palette generators |
| Dark mode: elevation is lightness, not shadow | Higher surface ≈ +3% lightness per level; keep the hue fixed across modes; reduce body font-weight by ~50 to offset light-on-dark optical bolding |

Typography, layout, motion, states:

| Rule | Detail |
|------|--------|
| Pair a distinctive display face with a refined body face | A single-font Inter/Roboto page is a template signal — the exception is a deliberate mono-only aesthetic |
| Reject the training-data default fonts by name | Inter, Roboto, Open Sans, Lato, and system defaults are the distributional center an unsteered model converges on; replace from a feel category — code: JetBrains Mono/Space Grotesk, editorial: Playfair Display/Crimson Pro, technical: IBM Plex/Source Sans 3 — then use the pick decisively |
| Vary the escape choice per project | Escaping one default only to converge on a new one (Space Grotesk as "the new Inter") is the documented second-order failure — treat any font you've reached twice in a row as the next default to reject |
| Contrast by extremes, not moderate steps | Weight pairs from the ends (100–200 against 800–900, not 400 against 600); heading-to-body size jumps of 3×+, not 1.5×; display+mono or serif+geometric-sans pairings — moderate variation still reads generic |
| Headings stay roman (`font-style: normal`) | An italicized emphasis word inside a heading is among the most reliable AI tells; carry emphasis with weight, accent color, or a drawn underline |
| Bias the layout; vary section padding | Wall-to-wall centered columns and identical padding on every section read as template; breaking symmetry once is enough. Use a 4pt spacing scale with semantic tokens |
| `font-variant-numeric: tabular-nums` on number columns | Proportional figures make prices/dates/metrics misalign vertically |
| Animate `transform`/`opacity` only, with named easing tokens | Support `prefers-reduced-motion`; cut motion before adding it — spend the whole motion budget on one orchestrated page-load with staggered reveals (`animation-delay`), then content is just there; scattered per-element micro-interactions read as noise. Ease/cubic-bezier tokens only — bounce/elastic easing reads as dated |
| Ship all 8 states per interactive element | default · hover · focus-visible · active · disabled · loading · error · success — see [frontend-accessibility-interactive-elements] for the focus rules; the focus ring appears instantly, ≥3:1 contrast |
| Prefer silent success and optimistic update + Undo | Toasts are for failures and non-visible async effects; confirmation modals are for irreversible actions only. Tooltip delay: hover ~800ms, focus 0ms |

## Edge cases

| Case | Then |
|------|------|
| No real metrics, testimonials, or logos were supplied | Render `—` with a labeled "metric to confirm" block, ask for the real number, or drop the stat slot — an invented "10× faster" is read as fabricated instantly |
| Restyling an existing app | Replace only the visual layer inside existing boundaries — keep routes, component ownership, copy intent, and information architecture; deleting production files needs explicit approval |
| The brief genuinely needs icons | One icon library per project; emoji (✨ 🚀 ⚡) standing in for feature icons is the recognized AI default |
| The base design passes and an effect layer is wanted | Canvas/shader effects go on top of a passing base, not instead of one — see [frontend-design-html-in-canvas] |
| Writing reusable design guidance (a prompt, skill, or wiki page) rather than styling directly | Pitch it at the "right altitude": name the design axes and their decision logic (pairing categories, contrast thresholds), never exact hex/pixel values (over-constrains) and never "make it look good" (assumes context the model lacks) |
| Narrow viewports (verify 320/375/414/768px) | Root `overflow-x: clip` on both `html` and `body`; clickable text stays on one line (shorten the label, then `white-space: nowrap`, then drop the item); image-bearing grid tracks use `minmax(0, 1fr)` |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Purple→blue gradient hero, or a `background-clip: text` gradient headline | One anchor hue; solid ink headline; carry warmth by tinting the neutrals | The two most-recognized AI aesthetics |
| Three equal columns of icon-above-heading-above-body feature cards | Vary column widths and card heights, pull icons inline, or use typographic rhythm with no cards | Every LLM emits this grid |
| `min-height: 100vh` centered hero with one sentence and a big CTA | Content-height hero, biased left or right, with more than a sentence | The default LLM landing page |
| Wordmark-left + inline links + CTA-right sticky nav, and a 4-column link footer | Shape nav and footer to the site's genre; the footer closes the page rather than cataloguing a sitemap | Both shapes are genre-blind template fingerprints |
| Aurora blobs, floating 3D orbs, or decorative glassmorphism behind the hero | Solid surface, a subtle two-stop gradient with faint grain, or a layered atmospheric background (gradients/geometry/texture) that belongs to the committed aesthetic | The tell is the ungrounded decoration pasted on a neutral page, not depth itself — atmosphere earned by the theme passes, the 2022 default doesn't |
| `transition-all`, `hover:scale-105` on every card, scroll-triggered fade-up on every section | Specify transitioned properties; one hover signal per element; one entrance for the page | The page never settles; motion reads as templated |
| Hand-building fake browser bars, phone frames, or IDE chrome around screenshots | A real screenshot in a `<figure>` with at most a hairline border | Redrawn chrome is always wrong in detail and reads as invented UI |
| Lottie or Three.js for a simple or non-interactive visual | Hand-built CSS/SVG; 3D must be user-manipulable to earn its bundle | Runtime plus hundreds of KB for what CSS does in zero bytes |
| `loading="lazy"` on the hero (LCP) image or video | `fetchpriority="high"` on the LCP element; lazy-load only below the fold | Lazy LCP roughly doubles p75 paint time |
| An uppercase eyebrow label (`01 / FEATURES`) on every section | Zero eyebrows by default; only for genuinely ordinal content, 1–2 per page, stacked above the heading in the same column | Decorative numbering erases the hierarchy it claims to create |
| Straight quotes, `--`, `...`, "Jane Doe", "Acme" | Curly quotes, `—`, `…`, plausible domain-specific names | Unproofread details mark generated copy |
