# SceneSpec reference and worked example

## Shape

A `SceneSpec` is JSON with a `camera`, a list of `parts`, and optional `look` and `background`.

- `camera`
  - `position` `[x, y, z]`, where the camera sits.
  - `target` `[x, y, z]`, what it looks at (default origin).
  - `fovDegrees`, vertical field of view (default 45).
- `look`, a named preset, one of `showcase` (default), `stylized`, `moody`, `clean`.
- `background`, clear color RGB in `[0, 1]`, omit for the look's default.
- `parts`, the tree. Each part has
  - `name`, a label.
  - `primitive`, `{ "kind": ..., "params": { ... } }`. `kind` is one of `cuboid`, `sphere`, `icosphere`, `cylinder`, `cone`, `capsule`, `torus`, `plane`, `disc`, `ring`, `wedge`. `params` are optional per-kind size numbers.
  - `position` `[x, y, z]`, local translation, default origin.
  - `rotation` `[x, y, z]`, local rotation as Euler degrees, default none.
  - `scale` `[x, y, z]`, local scale, default one.
  - `material`, optional, `{ "baseColor": [r, g, b, a], "metallic": ..., "roughness": ..., "emissive": [r, g, b] }`, all channels in `[0, 1]`.
  - `children`, nested parts whose transforms are relative to this part.

Keep it a real decomposition. Every visible part of the reference maps to a part here. Nest parts that move together (a handle on a body, a lid on a jar) so one transform on the parent repositions the whole group.

## Worked example, a little robot

A blocky mascot robot, a boxy body, a rounded head, two eyes, two arms, two feet. Every visible feature maps to a part. The head group carries the eyes as children so moving the head moves the eyes with it.

```json
{
  "camera": { "position": [2.6, 1.4, -3.4], "target": [0, 0.2, 0], "fovDegrees": 40 },
  "look": "showcase",
  "background": [0.82, 0.82, 0.82],
  "parts": [
    {
      "name": "body",
      "primitive": { "kind": "cuboid", "params": { "width": 1.1, "height": 1.2, "depth": 0.8 } },
      "position": [0, 0, 0],
      "material": { "baseColor": [0.85, 0.28, 0.24, 1], "metallic": 0.1, "roughness": 0.5 }
    },
    {
      "name": "head",
      "primitive": { "kind": "cuboid", "params": { "width": 0.9, "height": 0.7, "depth": 0.7 } },
      "position": [0, 1.05, 0],
      "material": { "baseColor": [0.9, 0.9, 0.92, 1], "metallic": 0.1, "roughness": 0.4 },
      "children": [
        {
          "name": "eye_left",
          "primitive": { "kind": "sphere", "params": { "radius": 0.12 } },
          "position": [-0.22, 0.05, -0.36],
          "material": { "baseColor": [0.1, 0.1, 0.12, 1], "roughness": 0.2, "emissive": [0.0, 0.6, 0.9] }
        },
        {
          "name": "eye_right",
          "primitive": { "kind": "sphere", "params": { "radius": 0.12 } },
          "position": [0.22, 0.05, -0.36],
          "material": { "baseColor": [0.1, 0.1, 0.12, 1], "roughness": 0.2, "emissive": [0.0, 0.6, 0.9] }
        }
      ]
    },
    {
      "name": "arm_left",
      "primitive": { "kind": "capsule", "params": { "radius": 0.13, "height": 0.7 } },
      "position": [-0.72, 0.1, 0],
      "rotation": [0, 0, 12],
      "material": { "baseColor": [0.75, 0.75, 0.78, 1], "metallic": 0.2, "roughness": 0.5 }
    },
    {
      "name": "arm_right",
      "primitive": { "kind": "capsule", "params": { "radius": 0.13, "height": 0.7 } },
      "position": [0.72, 0.1, 0],
      "rotation": [0, 0, -12],
      "material": { "baseColor": [0.75, 0.75, 0.78, 1], "metallic": 0.2, "roughness": 0.5 }
    },
    {
      "name": "foot_left",
      "primitive": { "kind": "cuboid", "params": { "width": 0.4, "height": 0.25, "depth": 0.5 } },
      "position": [-0.32, -0.85, 0],
      "material": { "baseColor": [0.2, 0.2, 0.22, 1], "roughness": 0.6 }
    },
    {
      "name": "foot_right",
      "primitive": { "kind": "cuboid", "params": { "width": 0.4, "height": 0.25, "depth": 0.5 } },
      "position": [0.32, -0.85, 0],
      "material": { "baseColor": [0.2, 0.2, 0.22, 1], "roughness": 0.6 }
    }
  ]
}
```

## Reading a defect on this spec

Say the first score comes back `scale_too_small`. The subject is drawn too small in frame, so pull the camera in (shorten its `position` vector toward the target) or scale the whole robot up, then re-score. Once the shape and scale gates pass, a lingering `appearance_far` means the colors or tone are off, tune the materials. Change one thing per iteration so each score tells you whether that edit helped.
