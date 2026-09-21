---
id: qa-environments-offscreen-render-capture-without-screen-recording
domain: qa
category: environments
applies_to: [macos, spritekit, appkit]
confidence: verified
sources:
  - https://developer.apple.com/documentation/spritekit/skview/texture(from:)
  - https://developer.apple.com/documentation/spritekit/sktexture/cgimage()
  - https://developer.apple.com/documentation/spritekit/skrenderer
  - https://developer.apple.com/documentation/imageio/cgimagedestinationcreatewithurl(_:_:_:_:)
  - https://developer.apple.com/documentation/imageio/kcgimagepropertygifdelaytime
  - https://developer.apple.com/documentation/appkit/nsview/cachedisplay(in:to:)
  - https://developer.apple.com/videos/play/wwdc2019/701/
  - https://support.apple.com/guide/security/protecting-app-access-to-user-data-secc01781f46/web
  - https://developer.apple.com/documentation/macos-release-notes/macos-15_1-release-notes
last_verified: 2026-09-06
related: [qa-environments-browser-console-capture-gaps, qa-process-completion-claims, qa-bug-reports-reproducible-reports, mobile-security-sensitive-data-on-device]
---

# Screenshots and Play Reels of a macOS App Without Screen Recording Permission

## When this applies

A screenshot or a short interaction reel of a macOS AppKit/SpriteKit app is
needed for a README, a bug report, or a CI artifact, and the capturing process
has no Screen Recording permission — `screencapture` fails, or the host is
headless/CI with nobody to click the grant. Also when choosing how to build an
animated GIF from frames without adding a tool dependency.

## Do this

1. **Render the app's own content off-screen instead of reading the screen.**
   Screen Recording (TCC) gates reading the screen buffer — since macOS
   Catalina "the user must use the security and privacy preference pane to
   preapprove apps to record the entire screen or the contents of windows other
   than their own", while "Apps can freely record the contents of their own
   windows". An app drawing itself into an in-memory image needs no grant.

| Case | Do |
|------|----|
| Still image of a SpriteKit scene | `SKView.texture(from: node)` (or `texture(from:crop:)`), then `SKTexture.cgImage()`, then write it with `CGImageDestinationCreateWithURL` + `CGImageDestinationAddImage` as PNG. The node "does not need to appear in the view's presented scene", so a staged arrangement can be composed off to the side |
| Animated reel | Capture frames on a fixed cadence into one `CGImageDestination` of type `UTType.gif`; pass each frame a `kCGImagePropertyGIFDictionary` with `kCGImagePropertyGIFDelayTime` (seconds) and set `kCGImagePropertyGIFLoopCount` on the destination — ImageIO ships with the SDK |
| Choosing the cadence | Capture at 10 fps (0.1 s delay): the delay time is "clamped to a minimum of 100 milliseconds", so a 15 fps capture plays back at 10 fps, 1.5× slower than real time |
| Deterministic staged scene (feature showcase) | Build the exact node arrangement in code, step the scene yourself, capture — the same frame every run |
| Real play reel | Poll the scene tree each tick, drive the same input handlers a user would (a bot), and capture one frame per tick |
| AppKit view with no SpriteKit | `bitmapImageRepForCachingDisplay(in:)` then `cacheDisplay(in:to:)` — it "draws the specified area of the view, and its descendants, into a provided bitmap-representation object" — then encode via ImageIO as above |
| The deliverable must show the whole screen or another app's window | That is screen capture: grant Screen Recording in System Settings › Privacy & Security, relaunch the capturing process, and use ScreenCaptureKit (`CGWindowListCreateImage` is deprecated, and macOS 15.1 adds "enhanced user awareness" dialogs for the deprecated capture APIs) |

2. **Prove one frame before batching.** Write the first frame, check its pixel
   size against the expected scene size and that it is not blank, then run the
   loop — a wrong view size or an unattached view produces a full set of empty
   frames that looks like a success at the file-count level
   ([qa-process-completion-claims]).

## Edge cases

| Case | Then |
|------|------|
| `screencapture` prints `could not create image` | The missing Screen Recording grant, not a display fault (field evidence, desk-bat 2026-08-19); switch to the off-screen path when the grant cannot be given, and report the permission state beside the capture in a bug report ([qa-bug-reports-reproducible-reports]) |
| Retina output size | The texture size follows the node's accumulated frame in scene points; set the `SKView` frame and the scene size explicitly before capturing and read the written image's pixel dimensions back in step 2 |
| The view was never attached to a window | Apple documents only that the *node* need not be in the presented scene; the field run rendered from the live app's `SKView`. Run step 2 first and fall back to `SKRenderer` (Metal, "renders a scene into a custom Metal rendering pipeline") when the frame is blank |
| The reel must show sensitive data (balances, tokens) | Stage the scene with fixture values; a committed GIF is a published artifact ([mobile-security-sensitive-data-on-device]) |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Run `screencapture` or `CGWindowListCreateImage` on a host without Screen Recording permission | Render off-screen (`SKView.texture(from:)`, `SKRenderer`, `NSView.cacheDisplay`) and encode with ImageIO | The grant needs a user in System Settings and a process relaunch (field evidence); the app's own content was never gated |
| Install ffmpeg to assemble the GIF | `CGImageDestination` with `UTType.gif`, per-frame `kCGImagePropertyGIFDelayTime`, `kCGImagePropertyGIFLoopCount` | ImageIO is in the SDK and supports per-frame delay and loop count directly |
| Capture at 15–30 fps for a smoother GIF | 10 fps, 0.1 s per frame | Delays under 100 ms are clamped up, so higher capture rates only slow playback |

## Sources

- https://developer.apple.com/documentation/spritekit/skview/texture(from:) — "Renders the contents of a node tree and returns the rendered image as a texture"; "The node being rendered does not need to appear in the view's presented scene"
- https://developer.apple.com/documentation/spritekit/sktexture/cgimage() — "Returns the texture's image data as a Quartz 2D image"
- https://developer.apple.com/documentation/spritekit/skrenderer — "An object that renders a scene into a custom Metal rendering pipeline and drives the scene update cycle"
- https://developer.apple.com/documentation/imageio/cgimagedestinationcreatewithurl(_:_:_:_:) — "Creates an image destination that writes image data to the specified URL"; `CGImageDestinationAddImage` "Adds an image to an image destination"
- https://developer.apple.com/documentation/imageio/kcgimagepropertygifdelaytime — "The number of seconds to wait before displaying the next image in an animated sequence, clamped to a minimum of 100 milliseconds"; `kCGImagePropertyGIFLoopCount` — "The number of times to repeat an animated sequence"
- https://developer.apple.com/documentation/appkit/nsview/cachedisplay(in:to:) — "Draws the specified area of the view, and its descendants, into a provided bitmap-representation object"
- https://developer.apple.com/videos/play/wwdc2019/701/ — WWDC19 "Advances in macOS Security": Catalina gates recording "the entire screen or the contents of windows other than their own" behind a user pre-approval; "Apps can freely record the contents of their own windows"
- https://support.apple.com/guide/security/protecting-app-access-to-user-data-secc01781f46/web — "Screen recording (for example, static screen shots and video)" is a TCC-protected category configured in System Settings
- https://developer.apple.com/documentation/macos-release-notes/macos-15_1-release-notes — "Applications using our deprecated content capture technologies now have enhanced user awareness policies"; `CGWindowListCreateImage` is marked deprecated in Apple's documentation
- Field evidence 2026-08-19 (desk-bat, SpriteKit macOS app, commit d0da30d): `screencapture` failed with `could not create image` under a missing Screen Recording grant; `SKView.texture(from:)` frames plus an ImageIO GIF destination produced 3 screenshots and a 203-frame, 15 fps, 124 KB GIF committed to the README, with gameplay driven by a scene-tree-polling bot
