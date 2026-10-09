---
id: frontend-design-theme-swap-propagation-check
domain: frontend
category: design
applies_to: [tailwind, css, playwright, chrome]
confidence: field-tested
sources:
  - https://developer.mozilla.org/en-US/docs/Web/API/Window/getComputedStyle
  - https://developer.mozilla.org/en-US/docs/Web/CSS/Guides/Cascading_variables/Using_custom_properties
  - https://playwright.dev/docs/api/class-page#page-add-style-tag
  - https://playwright.dev/docs/api/class-page#page-emulate-media
  - https://tailwindcss.com/docs/theme
last_verified: 2026-10-06
related: [frontend-design-design-system-lint-gate-for-agents, frontend-design-custom-property-values-read-from-script]
---

# A Pass/Fail Theme-Swap Check Instead of Screenshot Eyeballing

## When this applies

A Tailwind/CSS design-system lint gate is clean
([frontend-design-design-system-lint-gate-for-agents] step 5) and you need to find
hardcoded copies of the accent color the linter cannot trace (plain CSS, inline
`style=`, SVG `fill`) without a screenshot an orchestration coordinator is
forbidden to `Read` (`skills/orchestrate/SKILL.md`).

## Do this

Copy the script into the project's Playwright setup (needs `playwright-core` and an
installed Chrome). It swaps the accent by value, reads computed styles before and
after, and reports every element whose color survived. Run it once per color scheme:

```js
// theme-swap.mjs <url> <--accent-var> [light|dark] [theme-class] — exit 0 clean, 1 findings, 2 setup error
// node theme-swap.mjs http://localhost:4173/ --primary light; then the same with dark
// node theme-swap.mjs http://localhost:4173/ --primary dark dark  (class-based dark, shadcn/ui .dark)
import { chromium } from 'playwright-core';
const [url, varName, scheme = 'light', themeClass] = process.argv.slice(2);
const PROPS = ['color', 'background-color', 'border-top-color', 'border-right-color',
  'border-bottom-color', 'border-left-color', 'outline-color', 'fill', 'stroke',
  'text-decoration-color', 'box-shadow'];
const SENTINEL = 'rgb(1, 2, 3)', SWAP = 'rgb(255, 0, 255)';
const COLOR_RE = /#[0-9a-fA-F]{3,8}\b|(?:rgba?|hsla?|oklch|oklab|lab|lch|color)\([^)]*\)/g;
let browser;
try {
  if (!url || !varName) throw new Error('usage: theme-swap.mjs <url> <--var> [light|dark] [class]');
  browser = await chromium.launch({ channel: 'chrome' });
  const page = await browser.newPage();
  await page.emulateMedia({ colorScheme: scheme });
  await page.goto(url);
  if (themeClass) await page.evaluate((c) => document.documentElement.classList.add(c), themeClass);
  // Chrome keeps oklch() and hex/rgb() in separate syntaxes even for one color: compare canvas pixels.
  const cache = new Map();
  const canon = async (v) => {
    if (!cache.has(v)) cache.set(v, await page.evaluate(({ v, re }) => v.replace(new RegExp(re, 'g'), (t) => {
      const c = document.createElement('canvas').getContext('2d'); c.fillStyle = t; c.fillRect(0, 0, 1, 1);
      return '[' + c.getImageData(0, 0, 1, 1).data.join(',') + ']';
    }), { v, re: COLOR_RE.source }));
    return cache.get(v);
  };
  const collect = async () => {
    const rows = await page.evaluate((props) => [...document.querySelectorAll('body *')].flatMap((el, i) => {
      const cs = getComputedStyle(el), text = el.textContent.trim().slice(0, 20);
      const cls = typeof el.className === 'string' && el.className.trim();
      const tag = el.tagName.toLowerCase() + (cls ? '.' + cls.split(/\s+/).join('.') : '') + (text ? ` "${text}"` : '');
      return props.map((p) => ({ i, tag, p, v: cs.getPropertyValue(p) }));
    }), PROPS);
    for (const r of rows) r.canon = await canon(r.v);
    return rows;
  };
  // The probe inherits SENTINEL, so an undefined or non-color variable reads as SENTINEL.
  const resolve = (v) => page.evaluate(({ v, s }) => {
    const o = document.createElement('div'), d = o.appendChild(document.createElement('div'));
    o.style.color = s; d.style.color = `var(${v})`; document.body.append(o);
    const c = getComputedStyle(d).color; o.remove(); return c;
  }, { v, s: SENTINEL });
  const raw = await resolve(varName);
  if (raw === SENTINEL) throw new Error(`${varName} is undefined or not a color`);
  const accent = await canon(raw);
  const before = await collect();
  // Swap by value: every :root property resolving to the accent, so aliases move with the base.
  const names = await page.evaluate(() => [...getComputedStyle(document.documentElement)].filter((n) => n.startsWith('--')));
  const same = [];
  for (const n of names) if ((await resolve(n)) === raw) same.push(n);
  // Freeze transitions: a same-tick read otherwise catches a mid-transition oklab() value.
  await page.addStyleTag({ content: `:root{${same.map((n) => `${n}: ${SWAP} !important`).join(';')}}` +
    '*{transition:none !important;animation:none !important}' });
  if ((await resolve(varName)) !== SWAP) throw new Error(`the swap did not reach ${varName}`);
  const after = await collect();
  if (after.length !== before.length) throw new Error('the DOM changed between reads; wait for it to settle');
  const was = before.map((b) => b.canon.includes(accent));
  const moved = before.filter((b, k) => was[k] && !after[k].canon.includes(accent));
  const stuck = [], seen = new Set(); // first stuck property per element
  before.forEach((b, k) => { if (was[k] && after[k].canon.includes(accent) && !seen.has(b.i)) { seen.add(b.i); stuck.push(b); } });
  console.log(`[${scheme}${themeClass ? '+' + themeClass : ''}] ${varName}=${raw}; swapped: ${same.join(', ')}`);
  console.log(`properties following the swap: ${moved.length}; elements keeping the old accent: ${stuck.length}`);
  stuck.forEach((s) => console.log(`  HARDCODED ${s.tag} ${s.p}: ${s.v}`));
  process.exitCode = stuck.length ? 1 : 0;
} catch (e) { console.error(`setup error: ${e.message}`); process.exitCode = 2; }
finally { await browser?.close(); }
```

Evidence (playwright-core 1.63.0, Chrome, 2026-10-06; "followed" counts properties, "stuck" counts elements):

| Run | Result |
|-----|--------|
| Fixture `good.html`, `--primary`, then alias `--color-primary` | 13 followed, 0 stuck, exit 0 both times (swap-by-value moves the alias too) |
| Fixture `bad.html`, `--color-primary` | 3 stuck: `span "Promo"` color, `.card` border-top-color, `path` fill — exit 1 |
| Fixture `good.html`, `--nope`; Chrome or server missing | "setup error", exit 2 |
| Real project (Vite + React 19 + Tailwind v4 + shadcn/ui, `--primary: oklch(0.205 0 0)`), known-good | 3 followed, 0 stuck, exit 0 in light and with `.dark` |
| Same project, known-bad: `bg-[#171717]` + inline `style={{color:'#171717'}}` (`#171717` = the accent in sRGB) | 2 stuck, both named, exit 1. Without the canvas compare and the transition freeze: 0 stuck, a false pass |

## Edge cases

| Case | Then |
|------|------|
| A token is redefined on an element below `<html>` (a themed section, `[data-theme]` on `body`) | The `:root` override loses to the closer declaration and that section reads as hardcoded. Add the same declarations under that selector to the swap stylesheet. A class on `<html>` itself (shadcn/ui `.dark`) needs nothing extra: `!important` on `:root` wins on the same element |
| Hover, focus, or an open state | A resting-state read does not reach them. Drive the state first (`page.hover()`, `page.focus()`, open the menu) on the touched components, or list them as out of scope in the report |
| Images, `<canvas>`, `background-image`, shadow DOM | `getComputedStyle` does not read their pixels. List them as out of scope; for a pixel check, have a subagent diff screenshots and return text to the coordinator |
| A browser other than Chrome/Chromium | Run it on Chrome (`channel: 'chrome'`): enumerating `:root` custom properties through `getComputedStyle(documentElement)` was verified only there |
| The accent is declared in `oklch()` or another non-sRGB function | Keep the canvas compare: a hex copy of the same color reads back as `rgb()`, never as `oklch()`, so a string compare misses it. Keep the `[` `]` around each tuple too: undelimited, `123,23,23,255` (`#7b1717`) contains `23,23,23,255` (`#171717`), so a substring match reports a different color as a hardcoded accent copy (seen as 2 stuck instead of 1 in the real-project run; reproduced with `String.prototype.includes` in node) |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Screenshot every touched screen and eyeball the accent before/after a swap | Run this script and read its exit code | A screenshot compare is a judgment call, and a coordinator may not `Read` images (`skills/orchestrate/SKILL.md`) |
| Swap the custom property by name (always `--primary`) | Swap every `:root` property whose value equals the accent | A name-only swap leaves an alias a component reads directly, giving a false "hardcoded" report |

## Sources

- https://developer.mozilla.org/en-US/docs/Web/API/Window/getComputedStyle — an animating property returns its value at the current point in the animation (the transition freeze); sRGB at full opacity serializes as `rgb()`, other color spaces keep their own function (the canvas compare)
- https://developer.mozilla.org/en-US/docs/Web/CSS/Guides/Cascading_variables/Using_custom_properties — a custom property reaches every `var()` reference and can be overridden at any cascade level (swap by value; the descendant-override edge case)
- https://playwright.dev/docs/api/class-page#page-add-style-tag and https://playwright.dev/docs/api/class-page#page-emulate-media — the swap stylesheet; `colorScheme` emulates `prefers-color-scheme` only, so a class-based theme needs the class argument (observed on shadcn/ui)
- https://tailwindcss.com/docs/theme — `@theme inline` makes the utility use the theme variable's value instead of a `var()` reference to it; `--color-primary: var(--primary)` compiled `bg-primary` to `var(--primary)` in the real project's build output
