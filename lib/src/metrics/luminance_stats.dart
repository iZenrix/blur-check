import 'dart:math' as math;

import '../core/grayscale_buffer.dart';

/// Luminance statistics over a grayscale buffer.
class LuminanceStats {
  const LuminanceStats({
    required this.meanBrightness,
    required this.contrast,
    required this.brightPixelRatio,
  });

  /// Mean grayscale / 255 (`0..1`).
  final double meanBrightness;

  /// Grayscale standard deviation (`0..~255`).
  final double contrast;

  /// Fraction of pixels with luminance `> 250` (`0..1`).
  final double brightPixelRatio;
}

/// Single pass: mean brightness, contrast (stddev), and overexposure ratio.
LuminanceStats computeLuminanceStats(GrayscaleBuffer image) {
  final pixels = image.pixels;
  final length = pixels.length;
  if (length == 0) {
    return const LuminanceStats(
      meanBrightness: 0,
      contrast: 0,
      brightPixelRatio: 0,
    );
  }

  var mean = 0.0;
  var m2 = 0.0;
  var brightCount = 0;

  for (var i = 0; i < length; i++) {
    final value = pixels[i];
    final count = i + 1;
    final delta = value - mean;
    mean += delta / count;
    final delta2 = value - mean;
    m2 += delta * delta2;

    if (value > 250) {
      brightCount++;
    }
  }

  final variance = m2 / length;

  return LuminanceStats(
    meanBrightness: mean / 255.0,
    contrast: variance > 0 ? math.sqrt(variance) : 0.0,
    brightPixelRatio: brightCount / length,
  );
}
