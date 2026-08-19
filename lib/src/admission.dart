import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import 'features.dart';
import 'mask.dart';

/// Thresholds for the reference-admission gate. Defaults reject images too
/// small to render against, too empty or too full to isolate a subject, or
/// scattered across several disconnected pieces.
class AdmissionConfig {
  const AdmissionConfig({
    this.minShortSide = 64,
    this.minCoverage = 0.05,
    this.maxCoverage = 0.97,
    this.minLargestBlobFraction = 0.6,
  });

  /// The shorter of width and height must be at least this many pixels.
  final int minShortSide;

  /// Foreground coverage below this means no subject.
  final double minCoverage;

  /// Foreground coverage above this means the subject bleeds to the frame with
  /// no clean background.
  final double maxCoverage;

  /// The largest connected foreground blob must be at least this fraction of
  /// the total foreground area, rejecting scattered or multi-subject images.
  final double minLargestBlobFraction;
}

/// The verdict of gating a candidate reference image. [reasons] names the
/// failing checks and is empty when [admitted] is true.
class AdmissionResult {
  const AdmissionResult({
    required this.admitted,
    required this.reasons,
    required this.metrics,
  });

  final bool admitted;
  final List<String> reasons;
  final Map<String, Object?> metrics;

  Map<String, Object?> toJson() => {
        'admitted': admitted,
        'reasons': reasons,
        'metrics': metrics,
      };
}

/// Gates whether [image] is usable as a reference. Runs the short-side,
/// coverage, and largest-blob checks and returns a reason per failing check.
AdmissionResult admitReference(
  img.Image image, {
  AdmissionConfig config = const AdmissionConfig(),
}) {
  final sil = silhouette(image);
  final shortSide = math.min(image.width, image.height);
  final coverage = sil.coverage;
  final totalArea = sil.area;
  final largestBlob = _largestBlobArea(sil);
  final largestBlobFraction = totalArea == 0 ? 0.0 : largestBlob / totalArea;

  final reasons = <String>[];
  if (shortSide < config.minShortSide) {
    reasons.add(
      'short side $shortSide below ${config.minShortSide}; too small to render '
      'against',
    );
  }
  if (coverage < config.minCoverage) {
    reasons.add(
      'foreground coverage ${_round(coverage)} below ${config.minCoverage}; '
      'no subject',
    );
  } else if (coverage > config.maxCoverage) {
    reasons.add(
      'foreground coverage ${_round(coverage)} above ${config.maxCoverage}; '
      'the subject bleeds to the frame with no clean background',
    );
  }
  if (totalArea > 0 && largestBlobFraction < config.minLargestBlobFraction) {
    reasons.add(
      'largest foreground blob ${_round(largestBlobFraction)} of the subject '
      'is below ${config.minLargestBlobFraction}; scattered or multi-subject',
    );
  }

  return AdmissionResult(
    admitted: reasons.isEmpty,
    reasons: reasons,
    metrics: {
      'shortSide': shortSide,
      'coverage': _round(coverage),
      'largestBlobFraction': _round(largestBlobFraction),
    },
  );
}

/// Area of the largest 4-connected component of set pixels in [mask], via an
/// iterative flood fill with an explicit stack (no recursion, so a large image
/// cannot overflow the call stack).
int _largestBlobArea(Mask mask) {
  final w = mask.width, h = mask.height;
  final visited = Uint8List(w * h);
  final stack = <int>[];
  var largest = 0;

  for (var start = 0; start < mask.bits.length; start++) {
    if (mask.bits[start] == 0 || visited[start] != 0) continue;
    visited[start] = 1;
    stack.add(start);
    var area = 0;
    while (stack.isNotEmpty) {
      final i = stack.removeLast();
      area++;
      final x = i % w, y = i ~/ w;
      if (x > 0) _push(mask, visited, stack, i - 1);
      if (x < w - 1) _push(mask, visited, stack, i + 1);
      if (y > 0) _push(mask, visited, stack, i - w);
      if (y < h - 1) _push(mask, visited, stack, i + w);
    }
    if (area > largest) largest = area;
  }
  return largest;
}

void _push(Mask mask, Uint8List visited, List<int> stack, int i) {
  if (mask.bits[i] == 0 || visited[i] != 0) return;
  visited[i] = 1;
  stack.add(i);
}

double _round(double v) => (v * 1000).roundToDouble() / 1000;
