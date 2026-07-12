---
id: frontend-rendering-long-lists
domain: frontend
category: rendering
applies_to: [react, general]
confidence: verified
sources:
  - https://tanstack.com/virtual/latest
  - https://react.dev/learn/rendering-lists
last_verified: 2026-07-10
related: [frontend-rendering-rerender-and-memoization, databases-query-optimization-keyset-pagination]
---

# Rendering Lists with Hundreds of Rows or More

## When this applies

Rendering a list that can reach hundreds+ rows (feed, data table, dropdown
options, log view), or an existing list scrolls with jank / is slow to mount.

## Do this

1. When the rendered row count can exceed a few hundred DOM nodes, virtualize:
   render only the rows in (and just around) the viewport and translate scroll
   position to a window over the data (react-window / TanStack Virtual pattern).
   Below that count, render directly — virtualization machinery costs more than
   it saves.
2. Key every row by item identity (`item.id`), never by array index, whenever the
   list can reorder, filter, insert, or delete. Index keys re-associate row state
   (inputs, selection, animation) with whatever item lands at that index — data
   silently corrupts on reorder.
3. Bound the data, not just the DOM: paginate or infinite-scroll the fetch as
   well. Loading 50k records to virtualize 20 visible rows moves the cost to
   network and memory. The API-side page/cursor contract is the backend domain's;
   for the SQL side use [databases-query-optimization-keyset-pagination].
4. Keep row components cheap and identity-stable: extract the row as its own
   component so a single-row update does not re-render every sibling
   ([frontend-rendering-rerender-and-memoization]).

## Edge cases

| Case | Then |
|------|------|
| Row heights vary with content (comments, wrapped text) | Use the virtualizer's dynamic measurement mode (rows report real size after render) instead of a fixed `itemSize` |
| Content must be findable by Ctrl+F / crawlable for SEO | Virtualized off-screen rows do not exist in the DOM — use paginated pages rendered in full instead of virtualization |
| List is static and append-only (no reorder/filter/delete ever) | Index keys are safe here; item ids remain the default choice |
| No natural id on items | Key by a stable unique field or an id assigned at data-load time; never `Math.random()` per render — that remounts every row on every render |
| Rows are focusable/accessible widgets | Virtualization removes off-screen rows from the accessibility tree; verify keyboard/screen-reader flows still work, and prefer pagination when they do not |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Render all N thousand rows and hide overflow with CSS | Virtualize the viewport window | Hidden DOM still costs layout, memory, and mount time |
| Use `key={index}` on a filterable/sortable list | `key={item.id}` | On reorder, React matches by index and row state sticks to the wrong item |
| Fetch the entire dataset so the client can scroll it | Paginate/infinite-scroll the API and append pages into the list | Bounds payload and memory; server stays the owner of ordering |

## Sources

- https://tanstack.com/virtual/latest — headless virtualization; fixed, variable, and dynamically measured row sizes
- https://react.dev/learn/rendering-lists — keys from item identity; index/random keys pitfall
