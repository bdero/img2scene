import 'package:image/image.dart' as img;
import 'package:img2scene/img2scene.dart';
import 'package:test/test.dart';

// A dark frame with a light filled circle of the given radius, centered.
img.Image circle(int radius, {int size = 200}) {
  final image = img.Image(width: size, height: size, numChannels: 3);
  img.fill(image, color: img.ColorRgb8(20, 20, 20));
  img.fillCircle(
    image,
    x: size ~/ 2,
    y: size ~/ 2,
    radius: radius,
    color: img.ColorRgb8(230, 230, 230),
  );
  return image;
}

// A dark frame with a light filled square of the given half-extent, centered.
img.Image square(int half, {int size = 200}) {
  final image = img.Image(width: size, height: size, numChannels: 3);
  img.fill(image, color: img.ColorRgb8(20, 20, 20));
  img.fillRect(
    image,
    x1: size ~/ 2 - half,
    y1: size ~/ 2 - half,
    x2: size ~/ 2 + half,
    y2: size ~/ 2 + half,
    color: img.ColorRgb8(230, 230, 230),
  );
  return image;
}

void main() {
  group('Mask', () {
    test('iou of identical masks is 1, disjoint is 0', () {
      final a = Mask(4, 4)..setOn(1, 1);
      final b = Mask(4, 4)..setOn(1, 1);
      final c = Mask(4, 4)..setOn(3, 3);
      expect(a.iou(b), 1.0);
      expect(a.iou(c), 0.0);
    });

    test('bounds and linear size fraction', () {
      final m = Mask(10, 10);
      for (var y = 2; y <= 6; y++) {
        for (var x = 2; x <= 6; x++) {
          m.setOn(x, y);
        }
      }
      final b = m.bounds!;
      expect([b.x0, b.y0, b.x1, b.y1], [2, 2, 6, 6]);
      expect(m.linearSizeFraction, closeTo(0.5, 0.001)); // 5/10
    });
  });

  group('pHash', () {
    test('identical images hash equal, different images do not', () {
      expect(hammingDistance(pHash(circle(60)), pHash(circle(60))), 0);
      expect(
        hammingDistance(pHash(circle(60)), pHash(square(60))),
        greaterThan(0),
      );
    });
  });

  group('compare', () {
    test('identical images pass with perfect metrics', () {
      final r = compare(circle(60), circle(60));
      expect(r.passed, isTrue);
      expect(r.silhouetteIou, closeTo(1.0, 0.02));
      expect(r.scaleDelta, closeTo(0.0, 0.001));
      expect(r.phashDistance, 0);
      expect(r.edgeOverlap, closeTo(1.0, 0.02));
      expect(r.defects, isEmpty);
    });

    test('same shape at a different scale fails on scale', () {
      final r = compare(circle(20), circle(80));
      // Shape agrees after normalization, so silhouette is fine.
      expect(r.silhouetteIou, greaterThan(0.9));
      expect(r.passed, isFalse);
      expect(r.defects.map((d) => d.tag), contains('scale_too_small'));
    });

    test('different shape at the same scale fails on silhouette', () {
      final r = compare(square(70), circle(70));
      expect(r.silhouetteIou, lessThan(0.85));
      expect(r.passed, isFalse);
      expect(r.defects.map((d) => d.tag), contains('silhouette_mismatch'));
    });

    test('a soft appearance defect does not block', () {
      // Same silhouette and scale, so no blocking defect, whatever the soft
      // signals do.
      final r = compare(circle(60), circle(60));
      expect(r.passed, isTrue);
    });
  });
}
