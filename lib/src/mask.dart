import 'dart:math' as math;
import 'dart:typed_data';

/// An axis-aligned bounding box in pixel coordinates, inclusive of both ends.
class BBox {
  const BBox(this.x0, this.y0, this.x1, this.y1);

  final int x0;
  final int y0;
  final int x1;
  final int y1;

  int get width => x1 - x0 + 1;
  int get height => y1 - y0 + 1;
  int get area => width * height;
}

/// A binary silhouette (or edge) mask over a `width` by `height` grid, one byte
/// per pixel (0 or 1).
class Mask {
  Mask(this.width, this.height) : bits = Uint8List(width * height);

  Mask.fromBits(this.width, this.height, this.bits)
      : assert(bits.length == width * height);

  final int width;
  final int height;
  final Uint8List bits;

  bool at(int x, int y) => bits[y * width + x] != 0;
  void setOn(int x, int y) => bits[y * width + x] = 1;

  int get area {
    var count = 0;
    for (final b in bits) {
      if (b != 0) count++;
    }
    return count;
  }

  /// The tight bounds of the set pixels, or null when the mask is empty.
  BBox? get bounds {
    var minX = width, minY = height, maxX = -1, maxY = -1;
    for (var y = 0; y < height; y++) {
      final row = y * width;
      for (var x = 0; x < width; x++) {
        if (bits[row + x] == 0) continue;
        if (x < minX) minX = x;
        if (x > maxX) maxX = x;
        if (y < minY) minY = y;
        if (y > maxY) maxY = y;
      }
    }
    if (maxX < 0) return null;
    return BBox(minX, minY, maxX, maxY);
  }

  /// The set-pixel count as a fraction of the whole frame, in `[0, 1]`.
  double get coverage => area / (width * height);

  /// The subject's linear size as a fraction of the frame, `sqrt(bboxArea) /
  /// sqrt(frameArea)`. Zero when empty. A position and content independent
  /// measure of how large the subject is drawn.
  double get linearSizeFraction {
    final b = bounds;
    if (b == null) return 0;
    return math.sqrt(b.area / (width * height));
  }

  /// Intersection over union with [other], which must share dimensions. Returns
  /// 1 when both are empty (vacuously identical).
  double iou(Mask other) {
    assert(other.width == width && other.height == height);
    var intersection = 0, union = 0;
    for (var i = 0; i < bits.length; i++) {
      final a = bits[i] != 0;
      final b = other.bits[i] != 0;
      if (a || b) union++;
      if (a && b) intersection++;
    }
    if (union == 0) return 1;
    return intersection / union;
  }

  /// Crops to the set-pixel bounds and resamples (nearest neighbor) to a
  /// `size` by `size` mask, so a later [iou] compares shape independent of the
  /// subject's position and scale in its source frame. An empty mask yields an
  /// empty result.
  Mask normalized(int size) => normalizedTo(bounds, size);

  /// Like [normalized], but crops to a caller-supplied [box] instead of this
  /// mask's own bounds. Used to align an edge mask to the subject silhouette's
  /// box so edge overlap measures the same region. A null box yields empty.
  Mask normalizedTo(BBox? box, int size) {
    final out = Mask(size, size);
    final b = box;
    if (b == null) return out;
    for (var oy = 0; oy < size; oy++) {
      final sy = b.y0 + (oy * b.height) ~/ size;
      for (var ox = 0; ox < size; ox++) {
        final sx = b.x0 + (ox * b.width) ~/ size;
        if (at(sx, sy)) out.setOn(ox, oy);
      }
    }
    return out;
  }
}
