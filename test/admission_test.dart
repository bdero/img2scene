import 'package:image/image.dart' as img;
import 'package:img2scene/img2scene.dart';
import 'package:test/test.dart';

// A dark frame with a light filled circle at the given center and radius.
img.Image frame(int size, void Function(img.Image) draw) {
  final image = img.Image(width: size, height: size, numChannels: 3);
  img.fill(image, color: img.ColorRgb8(20, 20, 20));
  draw(image);
  return image;
}

void circleOn(img.Image image, int x, int y, int radius) {
  img.fillCircle(
    image,
    x: x,
    y: y,
    radius: radius,
    color: img.ColorRgb8(230, 230, 230),
  );
}

void main() {
  group('admitReference', () {
    test('a single centered blob of reasonable size is admitted', () {
      final image = frame(200, (i) => circleOn(i, 100, 100, 50));
      final r = admitReference(image);
      expect(r.admitted, isTrue);
      expect(r.reasons, isEmpty);
      expect(r.metrics['shortSide'], 200);
    });

    test('a tiny image is rejected on short side', () {
      final image = frame(40, (i) => circleOn(i, 20, 20, 12));
      final r = admitReference(image);
      expect(r.admitted, isFalse);
      expect(r.reasons.join(' '), contains('short side'));
    });

    test('an almost-empty frame is rejected on low coverage', () {
      final image = frame(200, (i) => circleOn(i, 100, 100, 5));
      final r = admitReference(image);
      expect(r.admitted, isFalse);
      expect(r.reasons.join(' '), contains('below'));
      expect(r.reasons.join(' '), contains('no subject'));
    });

    test('a nearly all-foreground frame is rejected on high coverage', () {
      final image = frame(200, (i) {
        img.fillRect(
          i,
          x1: 1,
          y1: 1,
          x2: 198,
          y2: 198,
          color: img.ColorRgb8(230, 230, 230),
        );
      });
      final r = admitReference(image);
      expect(r.admitted, isFalse);
      expect(r.reasons.join(' '), contains('bleeds to the frame'));
    });

    test('two equal separate blobs are rejected on largest blob', () {
      final image = frame(200, (i) {
        circleOn(i, 60, 100, 30);
        circleOn(i, 140, 100, 30);
      });
      final r = admitReference(image);
      expect(r.admitted, isFalse);
      expect(r.reasons.join(' '), contains('scattered or multi-subject'));
      expect(r.metrics['largestBlobFraction'], lessThan(0.6));
    });
  });
}
