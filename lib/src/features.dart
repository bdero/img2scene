import 'dart:typed_data';

import 'package:image/image.dart' as img;

import 'mask.dart';

/// Per-pixel luminance (0..255), row-major.
Uint8List luminance(img.Image image) {
  final w = image.width, h = image.height;
  final out = Uint8List(w * h);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final p = image.getPixel(x, y);
      out[y * w + x] =
          (0.299 * p.r + 0.587 * p.g + 0.114 * p.b).round().clamp(0, 255);
    }
  }
  return out;
}

/// Extracts a foreground silhouette. When the image has real transparency the
/// alpha channel decides; otherwise the background is estimated from the border
/// and pixels far from it are foreground. Assumes an isolated subject on a
/// clean background, the shape the reference-admission gate expects.
Mask silhouette(
  img.Image image, {
  double alphaThreshold = 0.5,
  int backgroundTolerance = 28,
}) {
  final w = image.width, h = image.height;
  final mask = Mask(w, h);

  if (_hasRealAlpha(image)) {
    final cut = alphaThreshold * 255;
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        if (image.getPixel(x, y).a > cut) mask.setOn(x, y);
      }
    }
    return mask;
  }

  final bg = _borderColor(image);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final p = image.getPixel(x, y);
      final d =
          ((p.r - bg[0]).abs() + (p.g - bg[1]).abs() + (p.b - bg[2]).abs()) / 3;
      if (d > backgroundTolerance) mask.setOn(x, y);
    }
  }
  return mask;
}

bool _hasRealAlpha(img.Image image) {
  if (!image.hasAlpha) return false;
  // A fully opaque alpha channel is not a silhouette signal.
  final w = image.width, h = image.height;
  final stepX = (w ~/ 64).clamp(1, w);
  final stepY = (h ~/ 64).clamp(1, h);
  for (var y = 0; y < h; y += stepY) {
    for (var x = 0; x < w; x += stepX) {
      if (image.getPixel(x, y).a < 250) return true;
    }
  }
  return false;
}

// Average color of the one-pixel border, the presumed background.
List<double> _borderColor(img.Image image) {
  final w = image.width, h = image.height;
  var r = 0.0, g = 0.0, b = 0.0, n = 0;
  void add(int x, int y) {
    final p = image.getPixel(x, y);
    r += p.r;
    g += p.g;
    b += p.b;
    n++;
  }

  for (var x = 0; x < w; x++) {
    add(x, 0);
    add(x, h - 1);
  }
  for (var y = 0; y < h; y++) {
    add(0, y);
    add(w - 1, y);
  }
  return [r / n, g / n, b / n];
}
