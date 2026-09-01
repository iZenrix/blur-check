import 'dart:typed_data';

/// Compact grayscale buffer used by the blur analyzer.
///
/// Stores luminance values in `0..255` as doubles for stable math in
/// Laplacian / variance loops without reallocating per pixel.
class GrayscaleBuffer {
  GrayscaleBuffer({
    required this.width,
    required this.height,
    required Float64List pixels,
  }) : assert(width > 0),
       assert(height > 0),
       assert(pixels.length == width * height),
       _pixels = pixels;

  final int width;
  final int height;
  final Float64List _pixels;

  Float64List get pixels => _pixels;

  int get length => _pixels.length;

  double operator [](int index) => _pixels[index];

  double get(int x, int y) => _pixels[y * width + x];

  void set(int x, int y, double value) {
    _pixels[y * width + x] = value;
  }
}
