# Knowledge flush — 1 insight (19 claimed rows: 1 ingested, 18 plan-gap rows retired as local-layer)

Run id `20260928-144949-57122` (inherited from the auto-flush parent via `DEV_LOOP_FLUSH_RUN_ID`; `flush-lock.sh acquire` answered `already-owned`). Claimed ids: `097a257377078016` (session row, ingested) plus 18 `plan-gaps.jsonl` rows listed under Local-layer candidates.

## Verified best-practice

**Claim (row `097a257377078016`, repo t6a-trip-ui / dace):** when a maps-compose `Marker`'s position comes from changing state, build it with `rememberUpdatedMarkerState(position)` inside `key(item.id) { … }`; keep the `rememberSaveable`-based constructor only for a marker whose start point never moves. Mechanism: `rememberMarkerState` is `rememberSaveable { MarkerState(position) }`, so the argument is only the initial value; remembered state is positional, so a changed list hands one item another item's state.

Sources checked and how:

- `maps-compose/src/main/java/com/google/maps/android/compose/Marker.kt` on `main` (raw fetch, 2026-09-28): `rememberMarkerState` = `rememberSaveable(key = key, saver = MarkerState.Saver) { MarkerState(position) }`, annotated `@Deprecated("Use 'rememberUpdatedMarkerState' instead - It may be confusing to think that the state is automatically updated as the position changes, so it will be changed or removed.")`; `rememberUpdatedMarkerState` = `remember { MarkerState(position = position) }.also { it.position = position }`; `MarkerState.position` is `mutableStateOf`. Also `dragState` is itself deprecated in favour of `isDragging` (line 108–113), so the page cites `isDragging`.
- Same file at tag `v6.6.0` (the version the session pinned), lines 195–225 re-read via `curl … | sed -n '195,225p'`: identical definitions and the same `@Deprecated`, confirming the row's `Marker.kt:203-221` citation.
- API reference pages (both fetched, both exist): `remember-updated-marker-state.html` — "updates the state value according to the update of the input parameter, like 'rememberUpdatedState'. This cannot be used to preserve state across configuration changes"; `remember-marker-state.html` — "this function does not automatically update the MarkerState when the input parameters change" plus the deprecation notice.
- Version boundary: PR #638 (merged 2025-01-29, merge commit `0d6f023`) introduced the deprecation and `rememberUpdatedMarkerState`. `gh api repos/googlemaps/android-maps-compose/compare/<tag>...0d6f023` gives `ahead` for v6.4.1/v6.4.2 and `behind` for v6.4.3/v6.4.4/v6.5.0, so **v6.4.3** is the first release containing it. PR #730 (merged 2025-08-06, "bring rememberMarkerState back … The function is still deprecated") is `behind` v6.7.1 and `ahead` of v6.7.0, so the function was absent in 6.7.0 and restored in 6.7.1.
- `https://developer.android.com/develop/ui/compose/lifecycle` (fetched): "When calling a composable multiple times from the same call site, Compose doesn't have any information to uniquely identify each call … the execution order is used in addition to the call site"; the `key` composable and `LazyColumn` `items(key = …)` are the documented remedy.
- Current README (`maps-compose:8.6.0`) uses `rememberUpdatedMarkerState` in its own MarkerState example.

Result: **confidence: verified** (official source + API docs + Android docs + reproducible compare-API check). One edge case (a draggable marker under a re-assigned position is reset on each composition) is derived from the `.also { it.position = position }` source line, not from an external doc, and the page says so by quoting the mechanism.

## Existing-layer check

Pages read: mobile-lifecycle-process-death-and-state, mobile-presentation-gating-nested-sheet-presentation

- `INDEX.md` → mobile domain (app-side Android). `wiki/mobile/index.md` read in full: categories lifecycle / offline / networking / release / performance / navigation / presentation / permissions / security; no "load when" line overlaps a Compose map marker or in-composition state identity.
- `grep -rli 'maps-compose|rememberMarkerState|google maps' wiki/` → 0 hits; `grep -rli 'rememberSaveable|positional memoization|stable key|key('` → only `mobile/lifecycle/process-death-and-state.md` (mentions `rememberSaveable` as a saved-state mechanism) plus two unrelated pages (suppression-key, spec-artifact-checks).
- `wiki_search` (k=5) on the trigger sentence returned qa-environments-element-crop-screenshots, platforms-processes-driving-a-tui-in-a-tmux-pane, infrastructure-agent-orchestration-pane-delivery-confirmation, frontend-design-responsive-layout, qa-document-verification-retiring-a-provisional-marker — all lexical "marker/position" matches, none the same situation. No merge target → **new page**.
- No conflict: process-death-and-state says "use `rememberSaveable` for transient UI state"; the new page's configuration-change edge case defers to it (hoist to `ViewModel`/`SavedStateHandle`, then pass in). Related link added **both ways** (process-death-and-state `related:` gained the new id; no open PR touches `wiki/mobile/`, so the back-link is safe).

## Open-PR check

`gh pr list --repo choiyounggi/dev-loop --state open --search "head:knowledge/"` → #223 (`knowledge/choiyounggi-20260927-220735`), #225 (`…-20260928-082803`), #226 (`…-092831`), #227 (`…-103056`), #228 (`…-134840`). Each head fetched; `git diff --name-only origin/main origin/<head> -- wiki/ INDEX.md` and a grep of each diff for `maps-compose|MarkerState|jetpack compose|remember(|rememberSaveable|key(` → 0 hits in all five. None touches `wiki/mobile/**`; #223/#225/#227 edit `INDEX.md` but not the `[mobile]` row (checked per PR with `grep '^[-+].*\[mobile\]'` → no lines).

Verdict per candidate: `097a257377078016` → **new**. The 18 plan-gap rows are local-layer drops (below), so no open-PR overlap applies to them.

## Routing decision

- `097a257377078016` → `wiki/mobile/state/map-marker-state-from-changing-position.md` (id `mobile-state-map-marker-state-from-changing-position`, `applies_to: [android, jetpack-compose]`, 67 body lines).
- **New category `mobile/state`** — "in-composition UI state identity". Why the existing ones don't fit: `lifecycle` is state *survival* across process death/config change (where each kind of state lives); this page is about which remembered instance a running composition binds to and whether a parameter is read once or on every composition. `presentation` is modal hosting. `frontend/state` is web UI. The new category's index row and the mobile "Route here for" paragraph name it, and the root `INDEX.md` mobile route line was widened with "a Compose map marker whose position comes from changing state".
- Plumbing: `wiki/mobile/index.md` (+`## state` section), `INDEX.md` (mobile row), `log.md` (ingest entry), `wiki/mobile/lifecycle/process-death-and-state.md` (reciprocal `related:`).

## Local-layer candidates

All 18 `plan-gaps.jsonl` rows are wiki-plan "no owning wiki page" design records whose directives name one repository's own files, RFC numbers, test lines or signatures; each would be wrong in another codebase. Retired as handled; run `wiki-ingest` inside the owning project if any is wanted there.

seagrass (linkly), task t172-money-set-and-guards — target `wiki-local/backend/python/<slug>.md` in that repo:
- `f8274e8a574a39af` `_check_dimensions` message names RFC-0051 only when `"money"` participates → `money-mismatch-message-cites-rfc-0051`
- `ff968018e51af793` `interp.eval_value` `Ref` branch gains a Money dict case (shape dispatch) → `money-runtime-shape-dispatch`
- `f541156192eeee35` `money.py` `sub`/`mul_int` pure, import-free, own ±INT64 check → `money-sub-mul-int-domain-check`
- `4bac29ffc7930e3c` `_condition_holds` spec-only Money order comparison opened → `money-order-comparison-in-spec`
- `72355943be4f08f4` RFC-0051 status Draft + Updates chain per RFC-0007 §2.2 → `wiki-local/qa/document-verification/rfc-0051-updates-chain`
- `4d2a12cfb4602426` and `1958e49958fa5319` (identical text, two harvests) t177 declared-field rule reaches `_dimension_of` through the generic reference loop → `numeric-predicate-declared-field-rule`
- `cae239f03ddab2cd` `RFC_ROUTES["0051"]`, generated grammar prose, README/CHANGELOG/ENFORCEMENT rows → `rfc-0051-registry-rows`

dace (linkly-calendar), task t6a-trip-ui — target `wiki-local/mobile/<category>/<slug>.md` in `apps/android`:
- `7068f2146ea1e6b9` `GoogleMapsKeyResolver.isValidKey`/`readManifestKey` empty-key gate → `maps/google-maps-key-gate`
- `3042cba1f8844f84` `TripTabRoot` receives a constructed `TripViewModel` → `navigation/trip-tab-root-viewmodel-injection`
- `d771e774c84744e2` `OPTIMIZE_APPLY_FAILED_MESSAGE` constant and local message state → `presentation/optimize-apply-failed-message`
- `c3868b8e8b2fab3b` `moveItem`/`deleteItem` pure list functions in `TripItineraryEdit.kt` → `state/itinerary-move-delete-pure-functions`
- `772f3a2a727f3cfe` `tripDatesInRange`/`tripShortDisplay` on `java.time.LocalDate` → `state/trip-date-chip-pure-functions`
- `07729881a03fce5f` category markers via `MarkerComposable` badge (6.6.0) → `maps/category-marker-composable`
- `25c323dfe8e9f66c` hand-rolled `decodePolyline` in `TripMap.kt` → `maps/encoded-polyline-decoder`
- `8979225a66711966` pinned maps-compose 6.6.0 / play-services-maps 20.0.0 verified from Gradle module metadata → `maps/pinned-maps-versions`
- `eef21f20e6149557` `MapStyle` object loading `res/raw/map_style_light.json` and parse-failure behaviour → `maps/map-style-json-loading`
- `081eb80b1695e007` `.orchestration-notes/t6a-trip-ui.md` public-signature record → `wiki-local/infrastructure/agent-orchestration/t6a-orchestration-notes`
