import 'package:image/image.dart' as img;

import 'edges.dart';
import 'features.dart';
import 'phash.dart';

/// Thresholds for the comparison gates. Defaults follow the reference-critic
/// convention: silhouette shape is the hard gate, appearance is advisory.
class ComparatorConfig {
  const ComparatorConfig({
    this.normalizeSize = 256,
    this.silhouetteIouGate = 0.85,
    this.scaleDeltaGate = 0.15,
    this.phashWarn = 24,
    this.edgeOverlapFloor = 0.10,
    this.backgroundTolerance = 28,
    this.edgeThreshold = 72,
  });

  /// The square resolution both silhouettes are resampled to before shape IoU,
  /// so the metric is independent of source resolution.
  final int normalizeSize;

  /// Silhouette IoU below this rejects the candidate (a blocking defect).
  final double silhouetteIouGate;

  /// Absolute difference in linear-size fraction above which the subject is
  /// drawn too large or too small (a blocking defect).
  final double scaleDeltaGate;

  /// Perceptual-hash Hamming distance above which appearance is flagged (soft).
  final int phashWarn;

  /// Edge overlap below which structure is flagged as thin (soft).
  final double edgeOverlapFloor;

  /// Silhouette background-difference tolerance (see [silhouette]).
  final int backgroundTolerance;

  /// Sobel edge threshold (see [sobelEdges]).
  final double edgeThreshold;
}

/// A tagged discrepancy. [blocking] defects fail the comparison; soft ones are
/// advisory hints for a correction loop.
class Defect {
  const Defect(this.tag, this.detail, {this.blocking = false});

  final String tag;
  final String detail;
  final bool blocking;

  Map<String, Object?> toJson() => {
        'tag': tag,
        'detail': detail,
        'blocking': blocking,
      };
}

/// The deterministic verdict of comparing a candidate render against a
/// reference. All metrics are in `[0, 1]` except [phashDistance] (0..64).
class ComparisonResult {
  const ComparisonResult({
    required this.silhouetteIou,
    required this.scaleDelta,
    required this.scaleRatio,
    required this.phashDistance,
    required this.edgeOverlap,
    required this.defects,
  });

  final double silhouetteIou;
  final double scaleDelta;
  final double scaleRatio;
  final int phashDistance;
  final double edgeOverlap;
  final List<Defect> defects;

  /// True when no blocking defect fired.
  bool get passed => !defects.any((d) => d.blocking);

  Map<String, Object?> toJson() => {
        'passed': passed,
        'metrics': {
          'silhouetteIou': _round(silhouetteIou),
          'scaleDelta': _round(scaleDelta),
          'scaleRatio': _round(scaleRatio),
          'phashDistance': phashDistance,
          'edgeOverlap': _round(edgeOverlap),
        },
        'defects': [for (final d in defects) d.toJson()],
      };
}

/// Compares a [candidate] render against a [reference] image and returns a
/// deterministic verdict. Pure function of its inputs, so it never drifts the
/// way a model's self-score does.
ComparisonResult compare(
  img.Image candidate,
  img.Image reference, {
  ComparatorConfig config = const ComparatorConfig(),
}) {
  final size = config.normalizeSize;

  final candSil = silhouette(
    candidate,
    backgroundTolerance: config.backgroundTolerance,
  );
  final refSil = silhouette(
    reference,
    backgroundTolerance: config.backgroundTolerance,
  );
  final silhouetteIou = candSil.normalized(size).iou(refSil.normalized(size));

  final candSize = candSil.linearSizeFraction;
  final refSize = refSil.linearSizeFraction;
  final scaleDelta = (candSize - refSize).abs();
  final scaleRatio = refSize == 0 ? 0.0 : candSize / refSize;

  final phashDistance = hammingDistance(pHash(candidate), pHash(reference));

  final candEdges = sobelEdges(
    luminance(candidate),
    candidate.width,
    candidate.height,
    threshold: config.edgeThreshold,
  );
  final refEdges = sobelEdges(
    luminance(reference),
    reference.width,
    reference.height,
    threshold: config.edgeThreshold,
  );
  final edgeOverlap = candEdges
      .normalizedTo(candSil.bounds, size)
      .iou(refEdges.normalizedTo(refSil.bounds, size));

  final defects = <Defect>[];
  if (silhouetteIou < config.silhouetteIouGate) {
    defects.add(
      Defect(
        'silhouette_mismatch',
        'silhouette IoU ${_round(silhouetteIou)} below '
            '${config.silhouetteIouGate}; the shape does not match',
        blocking: true,
      ),
    );
  }
  if (scaleDelta > config.scaleDeltaGate) {
    final tooSmall = candSize < refSize;
    defects.add(
      Defect(
        tooSmall ? 'scale_too_small' : 'scale_too_large',
        'subject size fraction ${_round(candSize)} vs reference '
        '${_round(refSize)}; ${tooSmall ? 'grow' : 'shrink'} it',
        blocking: true,
      ),
    );
  }
  if (phashDistance > config.phashWarn) {
    defects.add(
      Defect(
        'appearance_far',
        'perceptual-hash distance $phashDistance is large; tone, color, or '
            'coarse structure differ',
      ),
    );
  }
  if (edgeOverlap < config.edgeOverlapFloor) {
    defects.add(
      Defect(
        'low_edge_overlap',
        'edge overlap ${_round(edgeOverlap)} is low; internal detail or '
            'contours do not line up',
      ),
    );
  }

  return ComparisonResult(
    silhouetteIou: silhouetteIou,
    scaleDelta: scaleDelta,
    scaleRatio: scaleRatio,
    phashDistance: phashDistance,
    edgeOverlap: edgeOverlap,
    defects: defects,
  );
}

double _round(double v) => (v * 1000).roundToDouble() / 1000;
