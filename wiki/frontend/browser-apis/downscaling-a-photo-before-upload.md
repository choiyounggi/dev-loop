---
id: frontend-browser-apis-downscaling-a-photo-before-upload
domain: frontend
category: browser-apis
applies_to: [general, javascript]
confidence: verified
sources:
  - https://html.spec.whatwg.org/multipage/imagebitmap-and-animations.html
  - https://html.spec.whatwg.org/multipage/canvas.html
  - https://developer.mozilla.org/en-US/docs/Web/API/Window/createImageBitmap
  - https://developer.mozilla.org/en-US/docs/Web/API/HTMLCanvasElement/toBlob
  - https://developer.mozilla.org/en-US/docs/Web/API/ImageBitmap/close
  - https://developer.mozilla.org/en-US/docs/Web/API/CanvasRenderingContext2D/imageSmoothingQuality
  - https://platform.claude.com/docs/en/build-with-claude/vision
  - https://platform.claude.com/docs/en/build-with-claude/vision-coordinates
  - https://raw.githubusercontent.com/WebKit/WebKit/main/Source/WebCore/html/CanvasBase.cpp
  - https://bugs.webkit.org/show_bug.cgi?id=271002
  - https://shkspr.mobi/blog/2020/12/coping-with-heic-in-the-browser/
  - "Local measurement 2026-10-11 (Playwright 1.64.0, Chromium 156)"
last_verified: 2026-10-11
verified_model: claude-opus-5-5
related: [frontend-forms-dropzone-copy-without-drop-handlers]
---

# Downscaling a Photo in the Browser Before Upload

## When this applies

A web page uploads phone photos (camera capture or library) and the server or a
vision model accepts at most a known size; resizing in the browser with
`createImageBitmap` and a canvas; choosing the target size for a Claude vision
request; handling decode or encode failures and iPhone HEIC files.

## Do this

1. **Decode with `createImageBitmap(file)`.** Its `imageOrientation` option
   defaults to `"from-image"`, so EXIF orientation is applied — on the engines
   that ship that value: Chrome 112, Firefox 111, Safari 16.
2. **Compute the target from the consumer's limits, and never upscale:**

| Consumer | Target |
|---|---|
| Claude vision | The largest aspect-preserving size inside both of the model tier's limits — edge and visual tokens, `⌈w/28⌉ × ⌈h/28⌉`: standard tier 1568 px and 1568 tokens; high-resolution tier ("Claude 4.7 and later models") 2576 px and 4784 tokens. Compute it with the reference implementation in the vision-coordinates doc |
| A server with a pixel cap only | The long edge at the cap, the other edge `Math.round` of the scaled value |

   With that reference implementation a 4032×3024 photo targets 1270×952 on the
   standard tier and 2212×1659 on the high-resolution tier. Sending the long edge
   at 1568 px (1568×1176) gets the image resized again to 1270×952 by standard-tier
   models and uses 2352 of a high-resolution model's 4784 tokens.
3. **Draw into a canvas of exactly the target size** with
   `imageSmoothingQuality = 'high'` (Firefox does not implement the property, and
   its default is `'low'`), then call `canvas.toBlob(cb, 'image/jpeg', quality)`.
4. **Accept the encode only when the blob is non-null and
   `blob.type === 'image/jpeg'`.** An unsupported type is encoded as PNG
   (measured in Chromium: `'image/heic'` gave `image/png`), Safari has no WebP
   encoder for `toBlob`, and a canvas with a zero dimension calls back `null`
   (measured).
5. **Call `bitmap.close()` after drawing**, which disposes of the bitmap's
   graphical resources.
6. **On a decode or encode failure, upload the original only when its type and
   size pass the server's own limits;** otherwise tell the user this photo cannot
   be used.

## Edge cases

| Case | Then |
|------|------|
| Safari 15.x | It has `createImageBitmap` and the `imageOrientation` option, but not the `"from-image"` value, so EXIF orientation by default is not established there; check rotated photos on that version before supporting it |
| A full-resolution intermediate canvas | WebKit caps canvas area at 8192×8192 device pixels on iOS (4096×4096 before 2024) and 16384×16384 elsewhere; draw straight to the target size |
| A HEIC photo from an iPhone | Secondary source only: iOS turns a photo picked through `accept="image/*"` into a JPEG; a HEIC file that still arrives in a browser without a HEIC decoder makes `createImageBitmap` reject, which is step 6 |
| Images under 200 px | The vision guide's Limitations list "very small images under 200 pixels" among the inputs Claude interprets with mistakes; send the original size instead of upscaling |
| Per-image request limits | Keep each image within 8000×8000 px (2000 px per side once a request carries more than 20 images) and under 10 MB base64-encoded on the Claude API or 5 MB on Amazon Bedrock and Google Cloud; when the encoded file is over the byte limit, lower the JPEG quality or the dimensions and encode again |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Resize to a long edge of 1568 px for Claude | Compute the tier's size with the reference implementation | The doc: "For nearly all photos and screenshots, the visual token limit is what determines the final size" |
| Trust the `type` argument of `toBlob` | Check `blob.type` | An unsupported type produces PNG without an error |

## Sources

- https://html.spec.whatwg.org/multipage/imagebitmap-and-animations.html — `enum ImageOrientation { "from-image", "flipY" };`, `ImageOrientation imageOrientation = "from-image";`, "There used to be a "none" enum value. It was renamed to "from-image"."
- https://html.spec.whatwg.org/multipage/canvas.html — "If the user agent does not support the requested type, then it must create the file using the PNG format."; `toBlob()`: "Let result be null. If this canvas element's bitmap has pixels (i.e., neither its horizontal dimension nor its vertical dimension is zero), then set result to a copy of this canvas element's bitmap."
- https://developer.mozilla.org/en-US/docs/Web/API/Window/createImageBitmap — "from-image Image oriented according to EXIF orientation metadata, if present (default)."; BCD `api.createImageBitmap` (https://bcd.developer.mozilla.org/bcd/api/v0/current/api.createImageBitmap.json): `imageOrientation` option Chrome 52, Firefox 93, Safari 15; its `from-image` value Chrome 112, Firefox 111, Safari 16
- https://developer.mozilla.org/en-US/docs/Web/API/HTMLCanvasElement/toBlob — "if the given format is not supported, then the data will be exported as image/png"; "null may be passed if the image cannot be created for any reason"; BCD (https://bcd.developer.mozilla.org/bcd/api/v0/current/api.HTMLCanvasElement.toBlob.json): `type` `image/webp` Chrome 50, Firefox 96, Safari not supported; `image/jpeg` Safari 11
- https://developer.mozilla.org/en-US/docs/Web/API/ImageBitmap/close — "disposes of all graphical resources associated with an ImageBitmap"
- https://developer.mozilla.org/en-US/docs/Web/API/CanvasRenderingContext2D/imageSmoothingQuality — "The default value is "low"."; "For this property to have an effect, imageSmoothingEnabled must be true."; BCD (https://bcd.developer.mozilla.org/bcd/api/v0/current/api.CanvasRenderingContext2D.imageSmoothingQuality.json): Chrome 54, Safari 9.1, Firefox not supported
- https://platform.claude.com/docs/en/build-with-claude/vision (fetched 2026-10-11) — tier table "High-resolution | Claude 4.7 and later models | 2576 px | 4784" and "Standard | All other models | 1568 px | 1568"; "costs ⌈width / 28⌉ × ⌈height / 28⌉ visual tokens"; "The maximum dimensions per image are 8000x8000 px."; 10 MB / 5 MB per image; the Limitations entry "Claude might hallucinate or make mistakes when interpreting low-quality, rotated, or very small images under 200 pixels"
- https://platform.claude.com/docs/en/build-with-claude/vision-coordinates — "Claude finds the largest aspect-preserving size that satisfies both of the model's image limits"; "For nearly all photos and screenshots, the visual token limit is what determines the final size."; "a 1920×1080 screenshot resizes to 1456×819, not 1568×882"; the `resized_size` reference implementation, which reproduces those examples and gives the 4032×3024 and 1568×1176 numbers above
- https://raw.githubusercontent.com/WebKit/WebKit/main/Source/WebCore/html/CanvasBase.cpp — `#if PLATFORM(IOS_FAMILY)` `return 8192 * 8192;` `#else` `return 16384 * 16384;`; https://bugs.webkit.org/show_bug.cgi?id=271002 — "The maximum size of the canvas on iOS has been 4096x4096" (raised to 8192×8192 in 2024)
- https://shkspr.mobi/blog/2020/12/coping-with-heic-in-the-browser/ — secondary: Heicdrop "just makes use of the fact that iOS makes a JPEG out of a selected photo automatically", with `accept="image/*"` on the input
- Local measurement 2026-10-11 (Playwright 1.64.0, Chromium 156): `toBlob(cb, 'image/heic')` → `image/png`; `toBlob(cb, 'image/jpeg', 0.85)` → `image/jpeg`; a 0×0 canvas → `null`
- Field origin 2026-10-10 (linkly-invitation t7 plan, the client-downscale decision; recorded by the planning session)
