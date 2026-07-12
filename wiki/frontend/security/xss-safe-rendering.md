---
id: frontend-security-xss-safe-rendering
domain: frontend
category: security
applies_to: [react, general]
confidence: verified
sources:
  - https://cheatsheetseries.owasp.org/cheatsheets/Cross_Site_Scripting_Prevention_Cheat_Sheet.html
  - https://react.dev/reference/react-dom/components/common
  - https://github.com/cure53/DOMPurify
last_verified: 2026-07-10
related: [frontend-forms-validation-timing]
---

# Rendering Data Not Authored by Your Team

## When this applies

Rendering any value your team did not author: user input, CMS/rich-text content,
URL/query params, or fields from a third-party API — anywhere it reaches the DOM
(text, HTML fragments, `href`/`src`, dynamically built elements).

## Do this

1. Keep the default rendering path: framework text interpolation (JSX `{value}`,
   template bindings) and `textContent` escape output — untrusted text rendered
   this way is safe. XSS enters through the explicit raw sinks below; route every
   untrusted value through this table:

| Sink you need | Do |
|---------------|-----|
| Plain text into the page | Default framework rendering / `textContent` — already escaped, add nothing |
| Rich text / CMS HTML must render as HTML | Sanitize with an allowlist sanitizer (DOMPurify: `DOMPurify.sanitize(html)`) at the render sink, then pass the sanitized string to the raw sink (`dangerouslySetInnerHTML` / `innerHTML`) |
| User-provided URL bound to `href`/`src` | Parse with `new URL(value)` and allow only `http:`, `https:`, `mailto:` protocols before binding; on any other protocol or parse failure, drop the link and render the text |
| Building DOM from data at runtime | Use the framework's element creation (JSX) or `document.createElement` + `textContent` — the API keeps data as data |
| Untrusted data needed by a script | Put it in a `data-*` attribute or JSON endpoint and read it from code — never splice it into inline script text |

2. Sanitize at the render sink, not only at input time: data is combined,
   transformed, and re-stored between input and render, and other writers (APIs,
   migrations, older code) bypass your input filter. Input-time validation is
   allowed as an extra layer, never as the only one.
3. Add CSP as defense-in-depth so a missed sink has a second gate — header
   configuration is the infrastructure domain (text pointer, no page link).

## Edge cases

| Case | Then |
|------|------|
| Markdown from users | Render markdown to HTML, then sanitize the produced HTML before the raw sink — markdown syntax admits raw HTML and `javascript:` link targets |
| Sanitized HTML later inserted with different needs (SVG, iframe embeds) | Re-run the sanitizer configured for that context at that sink; one stored "clean" copy does not fit every sink |
| URL check done with `startsWith('javascript:')` blocklist | Replace with `new URL` + protocol allowlist — encoding, whitespace, and mixed case defeat string blocklists |
| Value rendered into a CSS or attribute context (style, event-handler attribute) | Do not place untrusted data there; set styles via safe APIs with validated enumerated values |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Sanitize on input only and trust stored data at render | Sanitize at the render sink | Data merges/transforms between input and render; other writers bypass input filters |
| Build an HTML string by concatenating data, then assign `innerHTML` | Framework element creation / `createElement` + `textContent` | Concatenation turns data into markup; element APIs keep it inert |
| Bind a user URL straight to `href` | `new URL` + `http:`/`https:`/`mailto:` allowlist first | `javascript:` and `data:` URLs execute on click |
| Escape output by hand-rolled regex replace | Use the framework's escaping / a maintained sanitizer | Hand-rolled escaping misses contexts and encodings |

## Sources

- https://cheatsheetseries.owasp.org/cheatsheets/Cross_Site_Scripting_Prevention_Cheat_Sheet.html — safe sinks, output encoding, DOMPurify recommendation, http/https URL allowlisting
- https://react.dev/reference/react-dom/components/common — dangerouslySetInnerHTML: only trusted, sanitized data
- https://github.com/cure53/DOMPurify — allowlist HTML/SVG/MathML sanitizer
