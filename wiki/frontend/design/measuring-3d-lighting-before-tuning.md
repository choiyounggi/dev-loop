---
id: frontend-design-measuring-3d-lighting-before-tuning
domain: frontend
category: design
applies_to: [threejs, webgl]
confidence: field-tested
sources:
  - https://discourse.threejs.org/t/meshphongmaterial-emissive-not-working/45543
  - https://developer.apple.com/documentation/scenekit/scnmaterial/emission
  - https://docs.unity3d.com/550/Documentation/Manual/StandardShaderMaterialParameterEmission.html
  - https://threejs.org/manual/zh/shadows.html
last_verified: 2026-10-19
related: [frontend-design-html-in-canvas]
---

# Measuring a three.js Lighting Complaint Before Tuning It

## When this applies

A screenshot review of a three.js (or other WebGL) scene says an object "looks
like a flat polygon", "has no depth", or "casts no shadow", and the next idea is
to change a colour, a material value, or a light setting and look again. Most
often seen with a lamp shade or fixture placed above its own light, and with
shadows under an overhead light in headless or software GL (SwiftShader).

## Do this

Measure which render term actually changes the reported pixels, then fix that
term. Each step is one toggle and one number, read from a decoded screenshot
(mean RGB over the object's screen region) or from the scene graph.

1. **Freeze the frame.** Render a deterministic frame: reduced-motion mode (or
   a paused clock), film grain, flicker and other noise passes off. Pixel
   comparisons drown in noise otherwise.
2. **Isolate each term for a "flat" object.** Record the region's mean RGB, then
   set each light's intensity to 0 in turn, then the material's `emissive` to
   black. Read the table below.
3. **Compute where a "missing" shadow should land.** Project a ray from the light
   through the caster's top edge onto the receiving surface. With the edge at
   height `h` above the floor and a point/spot light at height `H` and horizontal
   distance `d` from that edge, the shadow edge sits `d · h / (H − h)` beyond the
   caster's footprint. A light almost straight overhead (`d` near 0) gives a
   small number: the shadow is hidden under the caster itself.
4. **Toggle `castShadow` and diff.** On the frozen frame, render once with
   `castShadow = true` and once with `false` on the caster, and count changed
   pixels in the area from step 3. Also read the receiving surface's lit value:
   a floor at 13–16/255 leaves almost no room for a darker shadow.
5. **Fix the term the numbers point at**, then re-run the same measurement as
   the regression check.

| Measurement result | Cause | Fix |
|--------------------|-------|-----|
| Only `emissive` → black changes the region; every light at 0 leaves it unchanged | No light reaches the surface; emissive adds one uniform colour to every face | Give the object real shading (a light that reaches it, for example a weak fill from below a shade) or drop the glow; no emissive or albedo value adds form |
| A light at 0 changes the region | The object is lit; the problem is the light's direction or strength | Tune that light |
| Changing albedo (`color`) leaves the numbers identical | Same as row 1: no diffuse light reaches the surface | Same as row 1 |
| `castShadow` toggle changes pixels, but only inside the caster's footprint | Shadow renders correctly; the light angle hides it | Move or angle the light, or accept it — not a shadow-map bug |
| `castShadow` toggle changes pixels outside the footprint, but the floor is near black | Too little contrast on the receiving surface | Light the receiving surface more |
| `castShadow` toggle changes nothing | Real shadow setup fault | Check `renderer.shadowMap.enabled`, the light's `castShadow`, the receiver's `receiveShadow`, a lit receiver material, and the shadow camera bounds (`CameraHelper` on `light.shadow.camera`) |

## Edge cases

| Case | Then |
|------|------|
| The lamp is also the light source (a spot light inside the shade) | The light points away from the shade's outer faces, so the shade only gets emissive and hemisphere/ambient fill; measure with the spot at 0 to see that |
| Measurement must run in headless Chromium | Use the same frozen frame and decode the PNG; compare region means, not single pixels |
| A reviewer (human or LLM judge) still reports "flat" after a fix | Re-run step 2 and quote the numbers in the reply; the numbers settle whether the term changed |

## Instead of

| If you are about to | Do this instead | Why |
|---------------------|-----------------|-----|
| Try another colour or emissive value and re-screenshot | Toggle each light and the emissive term and read the region's numbers | When no light reaches the surface, colour and albedo have no effect, so each "tweak the material" round changes nothing |
| Raise shadow-map resolution or bias for an "invisible" shadow | Project the light ray and toggle `castShadow` on a frozen frame | A shadow that renders but falls under its caster, or on a near-black floor, looks missing |

## Sources

- https://discourse.threejs.org/t/meshphongmaterial-emissive-not-working/45543 — three.js forum: with no lights in the scene, a mesh renders black once its emissive colour is removed (emissive is the only term that reaches the screen)
- https://developer.apple.com/documentation/scenekit/scnmaterial/emission — SceneKit: setting emission to a solid colour adds a uniform colour to the material independent of lighting (same mechanism as three.js `emissive`)
- https://docs.unity3d.com/550/Documentation/Manual/StandardShaderMaterialParameterEmission.html — Unity Standard Shader: emissive surfaces appear self-illuminated and stay bright in dark areas
- https://threejs.org/manual/zh/shadows.html — three.js manual (shadows): the light's shadow camera box is the only region that casts shadows; visualise it with a `CameraHelper` on `light.shadow.camera`
- Field evidence 2026-10-19 (linkly-halli-galli t7-polish3d, live preview): lamp shade region mean RGB 77/74/67 with spot intensity 0 and hemisphere 0 (unchanged), 0/1/0 with emissive 0, identical numbers with a lighter albedo → fixed by real shading instead of colour rounds
- Field evidence 2026-10-18 (linkly-halli-galli t3-scene3d, SwiftShader): overhead lamp put the bell's shadow only 5 units outside its footprint; `castShadow` toggle on a reduced-motion frame changed the shadow spot 30→12; the lit felt measured 13–16/255
