# img2scene

Reference-image-driven procedural 3D for flutter_scene. Give it a picture of a hard-surface or stylized object and it drives a loop that authors a scene of primitives, renders it, scores the render against the picture, and corrects until it matches, then emits editable flutter_scene Dart.

The idea it is built on: **the reference image is not a description, it is the acceptance criteria.** A deterministic image comparison can be scored against, and unlike a model grading its own work it does not drift. img2scene leans into what flutter_scene has that a browser engine does not, a render loop that actually closes headless, a built-in primitive vocabulary, a deep look stack, and code as output.

## The loop

```
reference.png ── admit ──> SceneSpec (the model authors it)
                              │
                    emit + render (flutter_scene, headless)
                              │
                         candidate.png
                              │
                        compare vs reference ──> tagged defects
                              │
                     correct one defect, re-score ── until it passes
                              │
                        emit flutter_scene Dart
```

The model spends its tokens on visual judgment (the spec), never on the mechanical build. Everything else is deterministic.

## Commands

```sh
dart run img2scene:admit <reference.png>          # is this reference usable? (isolated subject, clean bg)
dart run img2scene <spec.json> <reference.png>    # render the spec and score it, exit 0 pass / 1 fail
dart run img2scene:compare <candidate.png> <reference.png>   # score two images directly
dart run img2scene:emit <spec.json> [-o out.dart]           # spec to copy-paste flutter_scene Dart
```

`dart run img2scene <spec> <ref> --json` prints the verdict as JSON, `-o keep.png` keeps the render.

## The spec

A `SceneSpec` (JSON) is a small tree of primitive parts, a camera, and a named look:

```json
{
  "camera": { "position": [2.2, 1.6, -3.2], "target": [0, 0.3, 0], "fovDegrees": 40 },
  "look": "showcase",
  "parts": [
    { "name": "body", "primitive": { "kind": "sphere", "params": { "radius": 0.7 } },
      "position": [0, 0.5, 0],
      "material": { "baseColor": [0.85, 0.2, 0.15, 1], "roughness": 0.35 } }
  ]
}
```

Primitive kinds map one to one onto the engine vocabulary: cuboid, sphere, icosphere, cylinder, cone, capsule, torus, plane, disc, ring, wedge. Looks are showcase, stylized, moody, clean. Rotations are Euler degrees. See `skills/img2scene/references/example.md` for a worked spec.

## Metrics and gates

The comparator returns four metrics and tagged defects. Shape and size are hard gates, appearance is advisory.

- **Silhouette IoU** (gate 0.85). Both silhouettes are cropped to their subject and resampled to a common square, so this is shape agreement independent of position and scale.
- **Scale delta** (gate 0.15). How much larger or smaller the subject is drawn.
- **Perceptual hash distance** and **edge overlap** (advisory). Tone, color, and contour drift.

Defects come back tagged (`silhouette_mismatch`, `scale_too_small`, `scale_too_large`, `appearance_far`, `low_edge_overlap`) so a correction loop knows what to fix. A comparison fails only on a blocking shape or scale defect.

## Layout

- `lib/` pure Dart core: the comparator (silhouette, scale, pHash, edges), the `SceneSpec` model, the admission gate, the Dart codegen. No engine dependency, so it runs anywhere and is fully unit tested.
- `render_harness/` a Flutter app that emits a `SceneSpec` to a flutter_scene node tree and captures a candidate PNG headless (a macOS integration test, the render authority). The orchestrator shells out to it.
- `skills/img2scene/` the agent skill teaching the loop. `prompts/reference.md` a prompt template for generating an admissible reference from text.

## Requirements

The render step needs Flutter with flutter_scene on macOS (it renders with Metal). The comparator, admission gate, and codegen are pure Dart and need only the Dart SDK. `cd render_harness && flutter pub get && dart run flutter_scene:init` once to set up the render harness.

## Scope

In: hard-surface and stylized props from the primitive vocabulary. Out (by design): organic likeness, characters, rigging, and photographic fidelity. Primitive assembly is good at boxy and stylized objects and weak at anything organic, so the tool aims a competing model like a mesh generator does not, at editable, diffable, tiny, hand-authored props.
