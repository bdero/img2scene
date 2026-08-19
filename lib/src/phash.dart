import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

const int _n = 32;

/// A 64-bit DCT perceptual hash: the sign of the low-frequency 8x8 DCT
/// coefficients (minus the DC term) of a 32x32 grayscale, relative to their
/// median. Robust to scale, blur, and small tone shifts.
int pHash(img.Image image) {
  final small = img.copyResize(
    img.grayscale(image),
    width: _n,
    height: _n,
    interpolation: img.Interpolation.average,
  );
  final f = Float64List(_n * _n);
  for (var y = 0; y < _n; y++) {
    for (var x = 0; x < _n; x++) {
      f[y * _n + x] = small.getPixel(x, y).r.toDouble();
    }
  }
  final dct = _dct2d(f);

  final low = Float64List(64);
  for (var y = 0; y < 8; y++) {
    for (var x = 0; x < 8; x++) {
      low[y * 8 + x] = dct[y * _n + x];
    }
  }
  // Median of the 63 AC terms (skip the DC term at index 0).
  final ac = low.sublist(1)..sort();
  final median = ac[ac.length ~/ 2];

  var hash = 0;
  for (var i = 0; i < 64; i++) {
    hash = (hash << 1) | (low[i] > median ? 1 : 0);
  }
  return hash;
}

/// Number of differing bits between two 64-bit hashes (0..64).
int hammingDistance(int a, int b) {
  var x = a ^ b;
  var count = 0;
  while (x != 0) {
    count += x & 1;
    x >>>= 1;
  }
  return count;
}

// Separable 2D DCT-II over an _n by _n buffer.
Float64List _dct2d(Float64List input) {
  final cos = _cosTable();
  final rows = Float64List(_n * _n);
  for (var y = 0; y < _n; y++) {
    for (var k = 0; k < _n; k++) {
      var sum = 0.0;
      for (var x = 0; x < _n; x++) {
        sum += input[y * _n + x] * cos[k * _n + x];
      }
      rows[y * _n + k] = sum;
    }
  }
  final out = Float64List(_n * _n);
  for (var x = 0; x < _n; x++) {
    for (var k = 0; k < _n; k++) {
      var sum = 0.0;
      for (var y = 0; y < _n; y++) {
        sum += rows[y * _n + x] * cos[k * _n + y];
      }
      out[k * _n + x] = sum;
    }
  }
  return out;
}

Float64List? _cosCache;
Float64List _cosTable() {
  final cached = _cosCache;
  if (cached != null) return cached;
  final table = Float64List(_n * _n);
  for (var k = 0; k < _n; k++) {
    for (var i = 0; i < _n; i++) {
      table[k * _n + i] = math.cos((math.pi / _n) * (i + 0.5) * k);
    }
  }
  return _cosCache = table;
}
