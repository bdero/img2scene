import 'dart:math' as math;
import 'dart:typed_data';

import 'mask.dart';

/// A Sobel edge mask from a luminance buffer: a pixel is an edge where the
/// gradient magnitude exceeds [threshold]. Border pixels are never edges.
Mask sobelEdges(
  Uint8List luminance,
  int width,
  int height, {
  double threshold = 72,
}) {
  final mask = Mask(width, height);
  int at(int x, int y) => luminance[y * width + x];
  for (var y = 1; y < height - 1; y++) {
    for (var x = 1; x < width - 1; x++) {
      final tl = at(x - 1, y - 1), t = at(x, y - 1), tr = at(x + 1, y - 1);
      final l = at(x - 1, y), r = at(x + 1, y);
      final bl = at(x - 1, y + 1), b = at(x, y + 1), br = at(x + 1, y + 1);
      final gx = (tr + 2 * r + br) - (tl + 2 * l + bl);
      final gy = (bl + 2 * b + br) - (tl + 2 * t + tr);
      if (math.sqrt((gx * gx + gy * gy).toDouble()) > threshold) {
        mask.setOn(x, y);
      }
    }
  }
  return mask;
}
