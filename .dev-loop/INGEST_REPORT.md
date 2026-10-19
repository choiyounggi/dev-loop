# Knowledge flush — 2 insight(s)

Headless autoflush run. 8 rows claimed; 2 ingested (merged into one new page), 6 released back to pending (5 overlap an open `knowledge/*` PR, 1 could not be read in this run).

## Verified best-practice

**Insight A — `3ccda4118b5d0dd4`** (three.js object lit only by `emissive` reads as a flat polygon)
- Claim: when no light reaches a surface, `emissive` adds one uniform colour to every face, so changing colour or albedo has no effect; toggle each light and the emissive term and measure the region's pixels before tuning; fix by giving the object real shading or removing the glow.
- Sources checked:
  - https://discourse.threejs.org/t/meshphongmaterial-emissive-not-working/45543 — with no lights, a mesh renders black once its emissive is removed (emissive is the only term reaching the screen).
  - https://developer.apple.com/documentation/scenekit/scnmaterial/emission — emission adds a uniform colour independent of lighting.
  - https://docs.unity3d.com/550/Documentation/Manual/StandardShaderMaterialParameterEmission.html — emissive surfaces are self-illuminated and stay bright in dark areas.
  - Not confirmed: the exact wording of the three.js `MeshStandardMaterial.emissive` doc entry (searches did not surface it; no claim on the page quotes it).
- Field evidence: session region stats — spot 0 + hemisphere 0 left the lamp at mean RGB 77/74/67, emissive 0 made it 0/1/0, a lighter albedo gave identical numbers.
- Confidence: **field-tested** (mechanism backed by cross-engine docs and a three.js forum thread; the measurement method is from the session).

**Insight B — `0358d858600ee3e0`** (three.js shadow judged "not visible" under headless/software GL)
- Claim: before changing settings, project the light ray to see how far the shadow falls outside the caster's footprint, and toggle `castShadow` on a deterministic (reduced-motion) frame and diff the decoded pixels; a correct shadow can be hidden under the caster or on a near-black receiver.
- Sources checked:
  - https://threejs.org/manual/zh/shadows.html — the shadow camera box is the region that casts shadows; visualise it with `CameraHelper` on `light.shadow.camera` (used for the "toggle changes nothing" row).
  - Forum threads found in search list the standard setup checklist (shadowMap enabled, `castShadow`/`receiveShadow`, lit receiver material); not cited per-thread because the search summary did not tie each point to one URL.
- Field evidence: bell shadow only 5 units outside its footprint under an overhead lamp; toggle changed the shadow spot 30→12; lit felt 13–16/255.
- Confidence: **field-tested**. The projection is plain similar-triangle geometry (`d · h / (H − h)`), stated on the page.

## Existing-layer check

- Route: `INDEX.md` → frontend (visual design, canvas effect layers) → `wiki/frontend/index.md` → `design` category.
- `wiki_search` (k=6) for both triggers: top hits were frontend-design-theme-swap-propagation-check, testing-quality-value-preserving-refactor-assertions, frontend-design-design-system-lint-gate-for-agents, frontend-design-anti-slop-visual-design, frontend-design-html-in-canvas, qa-environments-element-crop-screenshots, frontend-design-multi-shape-canvas-mask. None covers 3D lighting, emissive, or shadow diagnosis; the closest (theme-swap pixel checks, html-in-canvas) cover different triggers.
- Merge decision: no existing page has the trigger → **created one new page** that holds both candidates, since they share one trigger family (a screenshot complaint about 3D lighting → measure each render term before tuning).
- Conflicts: none.
- Related links: frontend-design-html-in-canvas ↔ frontend-design-measuring-3d-lighting-before-tuning (both ways).
- Pages read: frontend-design-multi-shape-canvas-mask, frontend-design-html-in-canvas

## Open-PR check

Open `knowledge/*` heads listed (17): #286, #285, #284, #283, #282, #280, #279, #275, #274, #273, #272, #271, #270, #269, #268, #266, #265. This headless run cannot diff their content, so any plausible overlap (by changed file paths and title) is treated as a pending duplicate and the claim is released.

| Candidate | Overlapping open PR | Verdict |
|-----------|---------------------|---------|
| `3ccda4118b5d0dd4` three.js emissive-only lighting | none (no open PR touches 3D lighting; #285 is WebGL stall timing, #270 touches anti-slop design only) | **new** — ingested |
| `0358d858600ee3e0` three.js shadow "not visible" | none (#285 is shader warm-up/stalls, not shadows) | **new** — ingested |
| `1107bc36bfcbfe79` e2e polling one axis of an animated element | #279 and #270 edit `wiki/testing/e2e/e2e-stability.md`; #270 adds qa reduced-motion capture pages | pending duplicate — claim released |
| `12aa086463fd4e2a` BSD grep `$` in BRE with `\|` alternation | #273 edits `wiki/platforms/tools/bsd-vs-gnu-cli.md` and shell pages | pending duplicate — claim released |
| `d631595a0e889652` colour-role rule judged from screenshots | #265 adds `wiki/qa/process/blind-llm-judgment-of-a-visual-rule.md` | pending duplicate — claim released |
| `0480b14856db7f7c` exact mid-window values for tuned constants | #268 (`tests-that-cannot-fail.md`), #279 (`expectation-sets-with-one-distinct-value.md`), #269/#270 (`surviving-mutant-equivalence-triage.md`) | pending duplicate — claim released |
| `0a0ccc4ca0904514` e2e failure that moves between tests under CPU contention | #275 edits `wiki/testing/flaky/diagnosing-flaky-tests.md` | pending duplicate — claim released |
| `97c37473b53e63c2` (content unknown) | n/a — its queue file could not be located with this run's tools | not handled — claim released for the next run |

## Routing decision

- Both ingested insights → `frontend/design/measuring-3d-lighting-before-tuning.md` (id `frontend-design-measuring-3d-lighting-before-tuning`). `design` already holds the canvas/WebGL pages (html-in-canvas, multi-shape-canvas-mask, pointer-attracted-particle-fields), so no new category.
- Plumbing: row added to `wiki/frontend/index.md` (design table) and its route header; `INDEX.md` frontend route line extended; `log.md` ingest entry; `related:` added on html-in-canvas.

## Local-layer candidates

none
