---
id: frontend-design-rendered-ui-gate-for-agent-built-screens
domain: frontend
category: design
applies_to: [html, css, playwright, chrome]
confidence: field-tested
sources:
  - https://developer.mozilla.org/en-US/docs/Web/HTML/Reference/Global_attributes/hidden
  - https://html.spec.whatwg.org/multipage/rendering.html
  - https://developer.mozilla.org/en-US/docs/Web/CSS/Guides/Cascade/Specificity
  - https://www.w3.org/TR/WCAG22/#contrast-minimum
  - https://www.w3.org/TR/WCAG22/#reflow
  - https://www.w3.org/TR/WCAG22/#focus-visible
  - https://www.w3.org/TR/WCAG22/#target-size-minimum
  - https://www.w3.org/TR/WCAG22/#name-role-value
  - https://developer.mozilla.org/en-US/docs/Web/CSS/font-variant-numeric
  - https://github.com/jakubkrehel/skills/blob/8b254eb75dadf3615a6abce87aed28e1b6e4d77c/skills/better-typography/SKILL.md
last_verified: 2026-11-12
related: [frontend-design-slop-detector-gate, frontend-design-responsive-layout, frontend-design-ui-hardening-against-real-content, qa-process-completion-claims, qa-process-blind-llm-judgment-of-a-visual-rule, testing-quality-checks-that-cannot-pass, frontend-design-polish-values-for-product-ui]
---

# A Rendered Gate for a Screen an Agent Built or Redesigned

## When this applies

An agent built or redesigned a web screen (hallmark, a `better-*` skill, or none)
and reports done on its own checklist; you need rendered pass/fail evidence for UI
state visibility, contrast, reflow, focus, names, targets and input size. Source
tells: [frontend-design-slop-detector-gate]; taste: [qa-process-blind-llm-judgment-of-a-visual-rule].

## Do this

1. Give the screen stable hooks before it is built: a `data-testid` on each state
   element (empty, error, toast, dialog) and on the rows that exclude it, and
   `data-live` on every number that changes in place (counters, timers, prices).
2. Copy the script into the project's Playwright setup, set `EXCLUSIVE` to the
   screen's state pairs, and run `node ui-gate.mjs http://localhost:5173/settings`.
   It checks at 1280 px and 320 px and exits 1 on any finding.
3. Prove the gate first: run it on the screen as it was before the redesign (it must
   exit 1) and on one page you know is clean (it must exit 0), as
   [testing-quality-checks-that-cannot-pass] requires.
4. Call the screen done only when the script exits 0 and each state was driven once
   in the browser (submit an invalid value, confirm a delete, empty the list); a
   design skill's own score is a claim until then ([qa-process-completion-claims]).

| Finding | Fix |
|---------|-----|
| `state: … visible while … exists` | A rule like `.empty { display: flex }` overrides the `hidden` attribute (MDN); add `[hidden] { display: none !important; }`, write `.empty:not([hidden])`, or toggle a class. A reset's `[hidden] { display: none }` without `!important` still loses: `[hidden]` and `.empty` are both 0-1-0, so the later rule wins |
| `contrast r<4.5` (or `<3` for 24 px / 18.66 px bold) | Darken the text token, then rerun; WCAG 1.4.3 |
| `horizontal scroll at 320px` | Find the widest element at 320 px (in the trial, a table) and reflow it into stacked rows, or scroll it inside its own container; WCAG 1.4.10 |
| `no visible focus` | Add a `:focus-visible` outline of 2 px or more; WCAG 2.4.7 |
| `no name with letters` | Add a visible `<label>` for fields and an `aria-label` for icon-only buttons. WCAG 4.1.2 needs a name; this gate also fails a glyph-only name (`✕`, `⚙`), which a screen reader reads as the symbol |
| `target WxH` | Make the control at least 24×24 CSS px (WCAG 2.5.8); inline links are skipped |
| `live number without tabular-nums` | Set `font-variant-numeric: tabular-nums` so ticking digits keep one width |
| `form control text Npx < 16px` | Set 16 px or more: iOS Safari zooms the page when a focused field's text is smaller |

```js
// ui-gate.mjs <url> — exit 0 clean, 1 findings. Edit EXCLUSIVE for your screen.
import { chromium } from 'playwright';
const EXCLUSIVE = [['[data-testid="empty"]', '[data-testid="member-row"]']]; // [state element, must be hidden while this exists]
const LIVE = process.env.UI_GATE_LIVE || '[data-live]'; // numbers that change in place
const url = process.argv[2]; const out = [];
const browser = await chromium.launch();
async function at(width, fn) {
  const page = await browser.newPage({ viewport: { width, height: 900 } });
  await page.goto(url, { waitUntil: 'load' }); await page.waitForTimeout(800); await fn(page); // never networkidle: a polling screen never idles await page.close();
}
await at(1280, async page => {
  out.push(...await page.evaluate(([ex, live]) => {
    const f = [], cv = document.createElement('canvas').getContext('2d', { willReadFrequently: true });
    const rgba = c => { cv.clearRect(0, 0, 1, 1); cv.fillStyle = '#000'; cv.fillStyle = c; cv.fillRect(0, 0, 1, 1); const d = cv.getImageData(0, 0, 1, 1).data; return [d[0], d[1], d[2], d[3] / 255]; };
    const lum = c => c.slice(0, 3).map(v => (v /= 255) <= 0.03928 ? v / 12.92 : ((v + 0.055) / 1.055) ** 2.4).reduce((s, v, i) => s + v * [0.2126, 0.7152, 0.0722][i], 0);
    const shown = e => { const r = e.getBoundingClientRect(), s = getComputedStyle(e); return r.width > 1 && r.height > 1 && s.visibility !== 'hidden' && +s.opacity > 0; };
    const label = e => e.outerHTML.slice(0, 50);
    for (const [state, others] of ex) for (const e of document.querySelectorAll(state)) if (shown(e) && document.querySelector(others)) f.push(`state: ${state} visible while ${others} exists`);
    for (const e of document.querySelectorAll('body *')) {
      if (!shown(e) || ![...e.childNodes].some(n => n.nodeType === 3 && n.textContent.trim())) continue;
      let bg = null; for (let a = e; a && !bg; a = a.parentElement) { const s = getComputedStyle(a); if (s.backgroundImage !== 'none') bg = 'img'; else if (rgba(s.backgroundColor)[3] >= 1) bg = rgba(s.backgroundColor); }
      if (bg === 'img') { f.push(`note: contrast unmeasured over a gradient/image: ${label(e)}`); continue; }
      bg ||= [255, 255, 255, 1]; const s = getComputedStyle(e), fg = rgba(s.color);
      for (let a = e; a; a = a.parentElement) fg[3] *= +getComputedStyle(a).opacity; // faded ancestors fade the text
      const mix = fg.map((v, i) => i < 3 ? v * fg[3] + bg[i] * (1 - fg[3]) : 1);
      const [hi, lo] = [lum(mix), lum(bg)].sort((a, b) => b - a), ratio = (hi + 0.05) / (lo + 0.05), px = parseFloat(s.fontSize);
      const need = px >= 24 || (+s.fontWeight >= 700 && px >= 18.66) ? 3 : 4.5;
      if (ratio < need) f.push(`contrast ${ratio.toFixed(2)}<${need}: ${label(e)}`);
    }
    for (const e of document.querySelectorAll('button, input, select, textarea, a[href]')) {
      if (!shown(e)) continue; const r = e.getBoundingClientRect();
      const ids = (e.getAttribute('aria-labelledby') || '').split(/\s+/).map(i => document.getElementById(i)?.textContent || '');
      const name = [e.getAttribute('aria-label'), ...ids, ...[...(e.labels || [])].map(l => l.textContent), /^(INPUT|SELECT|TEXTAREA)$/.test(e.tagName) ? '' : e.textContent, e.title].join(' ');
      if (!/\p{L}/u.test(name)) f.push(`no name with letters: ${label(e)}`);
      if ((r.width < 24 || r.height < 24) && !(e.tagName === 'A' && getComputedStyle(e).display === 'inline')) f.push(`target ${Math.round(r.width)}x${Math.round(r.height)}: ${label(e)}`);
    }
    for (const e of document.querySelectorAll(live)) if (!/tabular-nums/.test(getComputedStyle(e).fontVariantNumeric)) f.push(`live number without tabular-nums: ${label(e)}`);
    return f;
  }, [EXCLUSIVE, LIVE]));
  for (let i = 0; i < 15; i++) {
    await page.keyboard.press('Tab');
    const miss = await page.evaluate(() => { const e = document.activeElement, s = getComputedStyle(e); return e === document.body || (s.outlineStyle !== 'none' && parseFloat(s.outlineWidth) > 0) || s.boxShadow !== 'none' ? null : e.outerHTML.slice(0, 50); });
    if (miss) out.push(`no visible focus: ${miss}`);
  }
});
await at(320, async page => {
  const over = await page.evaluate(() => document.documentElement.scrollWidth - document.documentElement.clientWidth);
  if (over > 0) out.push(`horizontal scroll at 320px: ${over}px`);
  for (const px of await page.$$eval('input, select, textarea', es => es.filter(e => e.getClientRects().length && getComputedStyle(e).visibility !== 'hidden').map(e => parseFloat(getComputedStyle(e).fontSize)))) if (px < 16) out.push(`form control text ${px}px < 16px`);
});
await browser.close();
const all = [...new Set(out)], findings = all.filter(x => !x.startsWith('note:')); all.forEach(x => console.log(x));
console.log(`findings: ${findings.length}`); process.exit(findings.length ? 1 : 0);
```

## Edge cases

| Case | Then |
|------|------|
| Text sits on a gradient or an image | The script prints a `note:` instead of a finding; check that text by eye or sample pixels from a screenshot |
| The success path waits on a simulated request (a 350 ms spinner) | Wait for the resulting row or toast; a fixed 200 ms wait reported a working invite as broken in the trial |
| The redesign swapped `window.confirm` for its own dialog | Drive the dialog's confirm button by its test id; a `dialog` handler alone sees nothing |
| Prose line length is checked with a `ch` cap | `max-width: 65ch` measures about 90 real characters of prose in a proportional face; state which unit a rule uses before failing a page on it |
| A small control meets 2.5.8 through its Spacing exception (a 24 px circle around it touches no other target) | The gate still reports it; measure the spacing in the screenshot and record the waiver |
| The page polls (`setInterval` + `fetch`) | Expected: the script waits for `load` plus 800 ms, because `networkidle` never arrives on a polling page and timed out after 30 s in review |

## Sources

- MDN `hidden`: "changing the value of the CSS `display` property on a hidden element
  will override the hidden state"; MDN `font-variant-numeric`.
- WCAG 2.2: 1.4.3, 1.4.10 (320 CSS px), 2.4.7, 2.5.8 (with its Spacing and Inline
  exceptions), 4.1.2. Ancestor `opacity` is folded into the text alpha, an approximation.
- jakubkrehel/skills `better-typography` at 8b254eb: "iOS Safari zooms the whole page
  when an input's text is smaller than `16px`."
- Trial, 2026-11-12: one screen with 13 planted defects, redesigned three ways (the
  hallmark skill, the jakubkrehel `better-*` skills, no skill). The gate exited 1 on
  the original (22 findings) and 0 on a hand-written clean page. It caught what each
  redesign's own review missed: the hallmark output passed its self-check yet showed
  "No members yet" under three member rows (`.empty { display: flex }` over
  `hidden`); the `better-*` output overflowed 66 px at 320 px although its layout
  skill rates clipping at 320 px as HIGH; the no-skill output had 4.19:1 labels and a
  14 px input.
