---
name: img2scene
version: 1
description: Use this when building a 3D object or scene from a reference image with img2scene, turning a reference into scored flutter_scene Dart source through a deterministic critic loop.
---

# img2scene

Build a 3D object as a small tree of primitive parts that matches a reference image, scored by a deterministic critic until it passes, then emitted as flutter_scene Dart source.

The reference image is the acceptance criteria, not just inspiration. A deterministic comparator scores your render against it and returns tagged defects. Trust that verdict over your own impression, a model's self-score drifts upward while the comparator does not.

## When this fits

Good for hard-surface and stylized props, boxy or geometric objects assembled from a handful of primitives (a mug, a crate, a little robot, a lamp, a mailbox, a game item). Weak at organic likeness, faces, characters, plants, cloth, anything that does not decompose into a few clean primitives. If the subject is organic, say so rather than forcing it.

## The loop

### 1. Get an admissible reference

Either the user supplies a reference, or generate one from a text description using `prompts/reference.md`. An admissible reference is an isolated single subject on a clean flat background, roughly filling the frame, three-quarter front view, even lighting, no cast shadows on the background, square.

Gate it before using it.

```sh
dart run img2scene:admit <ref.png>
```

Fix or regenerate until it passes. A busy background, a cropped subject, or a dead-on/profile view all defeat the silhouette and scale metrics later, so a clean reference is worth the round trip.

### 2. Author a SceneSpec

Write a `SceneSpec` as JSON, a small tree of primitive parts. See `references/example.md` for a full worked spec and the field reference. In short, each part has a `name`, a `primitive` from the allowed kinds only, optional `position`/`rotation`(Euler degrees)/`scale`, an optional `material` (`baseColor` RGBA, `metallic`, `roughness`, `emissive`), and optional `children`. Set the `camera` (`position`, `target`, `fovDegrees`) to frame the subject the way the reference frames it.

Allowed primitive kinds, use these and nothing else:
`cuboid`, `sphere`, `icosphere`, `cylinder`, `cone`, `capsule`, `torus`, `plane`, `disc`, `ring`, `wedge`.

Spend your effort on visual judgment, proportions, placement, color, and camera framing. Keep it a real decomposition. Every visible part of the reference should map to a part in the tree. A one-box spec for a detailed subject fails the shape gate.

### 3. Score it

```sh
dart run img2scene <spec.json> <ref.png>
```

The orchestrator renders the spec (through a headless flutter_scene integration test) and compares the render to the reference in one step. Read the verdict and the tagged defects.

### 4. Correct one thing at a time

Drive each edit from a defect, then re-score. Fix the blocking gates first, shape and scale, before the soft flags.

- `scale_too_small` grow the subject or move the camera in.
- `scale_too_large` shrink the subject or move the camera out.
- `silhouette_mismatch` the shape is wrong. Fix proportions, or add/remove parts.
- `appearance_far` (soft) tone, color, or coarse structure differ. Adjust materials and colors after shape and scale pass.
- `low_edge_overlap` (soft) internal detail or contours do not line up. Add or reposition detail parts after the gates pass.

A comparison passes when no blocking defect fires. Loop until it passes.

### 5. Emit the source

```sh
dart run img2scene:emit <spec.json>
```

This produces the flutter_scene Dart source for the passing spec. That source is the deliverable.

## Reference commands

- `dart run img2scene:admit <ref.png>` gate a reference image.
- `dart run img2scene <spec.json> <ref.png>` render the spec and score it against the reference.
- `dart run img2scene:compare <candidate.png> <ref.png> [--json]` compare two images directly (lower-level, the orchestrator uses this internally).
- `dart run img2scene:emit <spec.json>` emit flutter_scene Dart source from a passing spec.
