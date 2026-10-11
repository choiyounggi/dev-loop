---
id: testing-quality-calls-inside-the-event-dispatch
domain: testing
category: quality
applies_to: [react, testing-library]
confidence: verified
sources:
  - https://react.dev/reference/react/act
  - https://legacy.reactjs.org/blog/2020/08/10/react-v17-rc.html
  - https://github.com/testing-library/react-testing-library/blob/main/src/pure.js
  - "Local reproduction 2026-10-11 (react/react-dom 19.3.0, @testing-library/react 16.3.3, @testing-library/dom 10.4.2, @testing-library/user-event 14.6.7, Vitest 5.0.3, jsdom 30.1.2): dispatch-time vs after-return counts for a handler call and its useEffect mutant"
  - "Field case 2026-10 (a copy-button test, linkly-invitation task t5b; recorded by the originating session)"
last_verified: 2026-10-11
related: [testing-quality-narration-based-ordering-assertions, testing-mocking-call-counts-under-render-retries]
---

# Proving a Handler Makes Its Call During the Event Dispatch

## When this applies

A test must prove that a React event handler makes a call while the event is
being dispatched — a browser API that needs the user's gesture
(`navigator.clipboard.writeText`, `window.open`), or any call a spec places
"inside the tap" — and the test fires the event with Testing Library's
`fireEvent` or `user-event`.

## Do this

1. **Read the spy's count from a bubble-phase `click` listener on `document`
   and assert on that reading.** Testing Library runs `fireEvent` inside React's
   `act()`, and `act()` applies pending renders and runs their effects before it
   returns. A version whose handler only sets state, with the call made in a
   `useEffect`, therefore reaches the same count as the correct one by the time
   `fireEvent` returns. React 17 and later handle events at the root container,
   so a `document` bubble listener runs after the React handler and before
   `act()` flushes:

```tsx
const writeText = vi.fn().mockResolvedValue(undefined)
Object.defineProperty(navigator, 'clipboard', { value: { writeText }, configurable: true })
render(<CopyButton text="hello" />)

const seen: number[] = []
const record = () => seen.push(writeText.mock.calls.length)
document.addEventListener('click', record) // bubble phase
try {
  fireEvent.click(screen.getByRole('button', { name: 'Copy' }))
} finally {
  document.removeEventListener('click', record)
}
expect(seen).toEqual([1]) // made during the click
```

2. **Prove the assertion with the effect mutant.** Move the call into a
   `useEffect` that runs on a state the handler sets, and require `seen` to read
   `[0]` (red) while the count read after `fireEvent` returns still reads 1.

| Reading | Correct handler | Effect mutant | Use it |
|---------|-----------------|---------------|--------|
| Spy count after `fireEvent` returns | 1 | 1 | No: both versions read 1 |
| `document` or `window` bubble `click` listener | `[1]` | `[0]` | Yes |
| `user-event` (`await user.click(el)`) with the `document` bubble listener | `[1]` | `[0]` | Yes |
| `document` capture listener (`addEventListener('click', fn, true)`) | `[0]` | `[0]` | No: it runs before React's handler |

## Edge cases

| Case | Then |
|------|------|
| The API the handler calls does not exist under jsdom (`navigator.clipboard` is undefined in jsdom 30.1.2) | Define it per test with `Object.defineProperty(navigator, 'clipboard', { value: { writeText }, configurable: true })`; `configurable: true` lets the next test replace it |
| The test also asserts what the click produced (confirmation text, the copied value) | Keep those assertions after `fireEvent` returns; only the timing claim needs the dispatch-time reading |
| The listener reads `[0]` for code you believe is correct | Check the listener phase first: a capture-phase listener on `document` runs before React's root handler and reads `[0]` for every version |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| `fireEvent.click(button)` then `expect(writeText).toHaveBeenCalledTimes(1)` to prove the call happens in the click | Assert the count a `document` bubble listener recorded during the dispatch | `act()` runs effects before `fireEvent` returns, so the `useEffect` mutant also reads 1 |
| Register the recording listener in the capture phase to see the click first | Register it in the bubble phase (the default) | A `document` capture listener runs before React's root handler, so it reads 0 for the correct code too |

## Sources

- https://react.dev/reference/react/act — "`act` is a test helper to apply pending React updates before making assertions"; dispatching an event inside `act()` "ensures that all updates from the event are applied before making assertions", and rendering inside it ensures "its effects are applied"
- https://legacy.reactjs.org/blog/2020/08/10/react-v17-rc.html — "In React 17, React will no longer attach event handlers at the `document` level. Instead, it will attach them to the root DOM container into which your React tree is rendered"; a `document` listener in the capture phase "receives \*all\* click events below"
- https://github.com/testing-library/react-testing-library/blob/main/src/pure.js — React Testing Library configures DOM Testing Library with `eventWrapper: cb => { … act(() => { result = cb() }) … }`; DOM Testing Library's `fireEvent` dispatches through `getConfig().eventWrapper(...)` (`@testing-library/dom` 10.4.2, `dist/events.js`)
- Local reproduction 2026-10-11 (react/react-dom 19.3.0, @testing-library/react 16.3.3, @testing-library/dom 10.4.2, @testing-library/user-event 14.6.7, Vitest 5.0.3, jsdom 30.1.2): a handler calling a spy and a mutant calling it from a `useEffect` keyed on a state the handler sets. After `fireEvent.click` returned, both read 1. A bubble listener on `document` read `[1]` vs `[0]`, on `window` `[1]` vs `[0]`, under `user-event` `[1]` vs `[0]`; a capture listener on `document` read `[0]` for both. The snippet above, with `navigator.clipboard.writeText` defined by `defineProperty` (absent in jsdom beforehand), passed for the correct button and failed for the mutant with `expected [ +0 ] to deeply equal [ 1 ]`
- Field case 2026-10 (linkly-invitation task t5b, `copy-button.test.tsx`; recorded by the originating session): an effect-based copy-status mutant passed the after-click count assertion and failed the dispatch-time `[1]` check
