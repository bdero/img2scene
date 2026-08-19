# img2scene

A deterministic image comparator for judging a rendered candidate against a reference image. Pure Dart, no engine dependency, so it runs as a `dart run` step and shares code with a headless render harness.

This is the first, standalone piece of the img2scene plan (see `notes/architecture/agent_tooling_strategy.md`, Part 4). The comparator is independently useful two ways: as a visual-regression check, and as a non-drifting critic (a model's self-score drifts upward, a deterministic image comparison does not).

## What it computes

Four metrics, with hard gates on shape and size and advisory flags on appearance:

- **Silhouette IoU** (hard gate, default 0.85). Both silhouettes are cropped to their subject and resampled to a common square, so this measures shape agreement independent of position and scale.
- **Scale delta** (hard gate, default 0.15). The difference in how large the subject is drawn (linear-size fraction of the frame).
- **Perceptual hash distance** (advisory). DCT pHash Hamming distance (0..64); flags tone, color, and coarse-structure drift.
- **Edge overlap** (advisory). Sobel edges aligned to the subject box; flags contour and internal-detail mismatch.

A comparison fails when any blocking (shape or scale) defect fires. Failures come back as tagged defects (`silhouette_mismatch`, `scale_too_small`, `scale_too_large`, `appearance_far`, `low_edge_overlap`) so a correction loop knows what to fix.

The silhouette is read from the alpha channel when the image has real transparency, otherwise from the difference against a background color estimated from the border. It assumes an isolated subject on a clean background.

## Use

```sh
dart pub get
dart run img2scene:compare candidate.png reference.png          # human summary, exit 0 pass / 1 fail
dart run img2scene:compare candidate.png reference.png --json   # machine-readable verdict
dart run img2scene:compare candidate.png reference.png --silhouette-gate 0.9 --scale-gate 0.1
```

As a library:

```dart
import 'package:image/image.dart' as img;
import 'package:img2scene/img2scene.dart';

final result = compare(img.decodePng(candidateBytes)!, img.decodePng(referenceBytes)!);
if (!result.passed) {
  for (final d in result.defects.where((d) => d.blocking)) print('${d.tag}: ${d.detail}');
}
```

## Not yet built

The plan's later pieces: the reference-generation prompt template (text to an admissible reference image), and the Dart Node-tree emitter that authors flutter_scene geometry to satisfy the comparator in a correction loop. The comparator lands first because it is the acceptance criteria everything else is scored against.
