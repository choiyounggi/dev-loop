---
id: mobile-state-map-marker-state-from-changing-position
domain: mobile
category: state
applies_to: [android, jetpack-compose]
confidence: verified
sources:
  - https://github.com/googlemaps/android-maps-compose/blob/main/maps-compose/src/main/java/com/google/maps/android/compose/Marker.kt
  - https://googlemaps.github.io/android-maps-compose/maps-compose/com.google.maps.android.compose/remember-updated-marker-state.html
  - https://googlemaps.github.io/android-maps-compose/maps-compose/com.google.maps.android.compose/remember-marker-state.html
  - https://github.com/googlemaps/android-maps-compose/pull/638
  - https://github.com/googlemaps/android-maps-compose/pull/730
  - https://developer.android.com/develop/ui/compose/lifecycle
last_verified: 2026-09-28
related: [mobile-lifecycle-process-death-and-state]
---

# A Compose Map Marker Whose Position Comes From Changing State

## When this applies

A `Marker` (maps-compose, Jetpack Compose on Google Maps) takes its position
from state that changes after first composition: a draft pin that follows map
taps, a marker that tracks a moving entity, or a list of places that reloads
or reorders. The marker stays where it was first drawn, or one place shows up
at another place's coordinates after the list changes.

## Do this

1. **Read what the two constructors do.** `rememberMarkerState(position)` is
   `rememberSaveable { MarkerState(position) }`: the argument is only the
   starting point and every later value is ignored. Since v6.4.3 it is
   `@Deprecated` with the message "It may be confusing to think that the state
   is automatically updated as the position changes". `rememberUpdatedMarkerState(position)`
   is `remember { MarkerState(position) }.also { it.position = position }`: it
   re-assigns the position on every composition.
2. **Choose the constructor by whether the position can change:**

| Case | Do |
|------|----|
| Position is derived from state that changes (draft pin, tracked entity, reloaded list) | `rememberUpdatedMarkerState(position = item.position)` |
| Position never changes after first draw and only the marker's own drag/info-window state matters | `rememberSaveable(saver = MarkerState.Saver) { MarkerState(position) }` (the deprecation's own `ReplaceWith`) |
| The marker is user-draggable and its position is the source of truth | Hoist the position: keep it in your own state, feed it to `rememberUpdatedMarkerState`, and write it back when `MarkerState.isDragging` turns false (read `position` then) — see Edge cases |

3. **Wrap each marker of a list in `key(item.id) { … }`.** Remembered state is
   bound to its call site plus execution order; when a list adds, removes or
   reorders items, the state remembered in slot N stays in slot N and a
   different place inherits it. `key` tells the runtime which values identify
   the instance so the state follows the item. (`LazyColumn`'s `items(key = …)`
   is the same mechanism; `GoogleMap` content has no built-in list key, so wrap
   the loop body yourself.)
4. **Assert the behaviour, not the API name.** Change the state that feeds the
   position and assert the marker's `position` equals the new value; reload the
   list with an item removed from the front and assert each remaining marker's
   position still matches its own item.

## Edge cases

| Case | Then |
|------|------|
| Draggable marker built with `rememberUpdatedMarkerState(position = fixed)` | Every recomposition re-assigns `position = fixed`, so a drag is undone on the next composition of that scope. Hoist the position into caller state and update it from the drag result, so the value passed in is the dragged one |
| State must survive configuration change or process death | `rememberUpdatedMarkerState` uses `remember`, not `rememberSaveable`; its API doc says it "cannot be used to preserve state across configuration changes". Keep the position in a `ViewModel` / `SavedStateHandle` and pass it in — the marker then re-reads it after recreation ([mobile-lifecycle-process-death-and-state]) |
| Library pinned to a version before v6.4.3 | `rememberUpdatedMarkerState` does not exist; write the same two-liner yourself: `remember { MarkerState(position) }.also { it.position = position }` |
| Version 6.7.0 | `rememberMarkerState` was removed from the artifact and restored (still deprecated) in v6.7.1 (PR #730); a build that stopped compiling on 6.7.0 needs 6.7.1+ or the `rememberSaveable` replacement |
| Marker's other state (info window shown, drag state) must survive a list reorder | `key(item.id)` keeps it with the item; without the key the info window opens on whichever item now occupies that slot |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Pass a changing value to `rememberMarkerState(position = …)` and expect the marker to move | `rememberUpdatedMarkerState(position = …)` | The argument is only the initial value inside `rememberSaveable`; later values are ignored |
| Loop over a reloaded list and call `rememberUpdatedMarkerState` per item with no `key` | Wrap each item in `key(item.id) { … }` | Remembered state is positional; a shifted list gives one item another item's state |
| Set `markerState.position` from a `LaunchedEffect` to mirror a state value | Pass the value to `rememberUpdatedMarkerState` | That is exactly what the function does, on every composition, with no effect ordering to reason about |

## Sources

- https://github.com/googlemaps/android-maps-compose/blob/main/maps-compose/src/main/java/com/google/maps/android/compose/Marker.kt — `rememberMarkerState` = `rememberSaveable(key, MarkerState.Saver) { MarkerState(position) }` with the `@Deprecated` message quoted above; `rememberUpdatedMarkerState` = `remember { MarkerState(position) }.also { it.position = position }`; `MarkerState.position` is `mutableStateOf`
- https://googlemaps.github.io/android-maps-compose/maps-compose/com.google.maps.android.compose/remember-updated-marker-state.html — "updates the state value according to the update of the input parameter, like rememberUpdatedState. This cannot be used to preserve state across configuration changes"
- https://googlemaps.github.io/android-maps-compose/maps-compose/com.google.maps.android.compose/remember-marker-state.html — "this function does not automatically update the MarkerState when the input parameters change"; deprecation notice
- https://github.com/googlemaps/android-maps-compose/pull/638 — the deprecation and `rememberUpdatedMarkerState` (merge commit 0d6f023, first contained in tag v6.4.3, 2025-01-29; confirmed with the GitHub compare API)
- https://github.com/googlemaps/android-maps-compose/pull/730 — "bring rememberMarkerState back … The function is still deprecated" (v6.7.1)
- https://developer.android.com/develop/ui/compose/lifecycle — "When calling a composable multiple times from the same call site … the execution order is used in addition to the call site"; `key` composable and `LazyColumn` `items(key = …)`
- Field evidence 2026-09-28 (Android trip UI pinned to maps-compose 6.6.0): the two definitions were read in `maps-compose-6.6.0-sources.jar`, `Marker.kt:203-221` (same text as `main` today, re-fetched at tag v6.6.0), and the draft-pin and reloaded-place-list markers were built with `rememberUpdatedMarkerState` inside `key(item.id)`
