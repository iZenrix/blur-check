import '../core/grayscale_buffer.dart';

/// Laplacian variance and edge density from one pixel pass.
class LaplacianEdgeMetrics {
  const LaplacianEdgeMetrics({
    required this.variance,
    required this.edgeDensity,
  });

  final double variance;

  /// Fraction of analyzed interior pixels with `|L| >= edgeThreshold`.
  final double edgeDensity;
}

/// Computes variance of Laplacian using a 4-neighbor kernel:
///
/// ```text
///  0  1  0
///  1 -4  1
///  0  1  0
/// ```
///
/// Border pixels are skipped (`x = 1..width-2`, `y = 1..height-2`).
/// Variance uses Welford's online algorithm; edge density is counted in the
/// same loop so a full Laplacian matrix is never stored.
///
/// [edgeThreshold] is an internal calibration knob (not public API).
LaplacianEdgeMetrics computeLaplacianEdgeMetrics(
  GrayscaleBuffer image, {
  double edgeThreshold = 15.0,
}) {
  final width = image.width;
  final height = image.height;

  if (width < 3 || height < 3) {
    return const LaplacianEdgeMetrics(variance: 0, edgeDensity: 0);
  }

  var mean = 0.0;
  var m2 = 0.0;
  var count = 0;
  var edgeCount = 0;

  for (var y = 1; y < height - 1; y++) {
    for (var x = 1; x < width - 1; x++) {
      final center = image.get(x, y);
      final laplacian =
          image.get(x, y - 1) +
          image.get(x - 1, y) -
          4 * center +
          image.get(x + 1, y) +
          image.get(x, y + 1);

      count++;
      final delta = laplacian - mean;
      mean += delta / count;
      final delta2 = laplacian - mean;
      m2 += delta * delta2;

      if (laplacian.abs() >= edgeThreshold) {
        edgeCount++;
      }
    }
  }

  if (count == 0) {
    return const LaplacianEdgeMetrics(variance: 0, edgeDensity: 0);
  }

  return LaplacianEdgeMetrics(
    variance: m2 / count,
    edgeDensity: edgeCount / count,
  );
}

/// Convenience wrapper returning only Laplacian variance.
double computeLaplacianVariance(GrayscaleBuffer image) {
  return computeLaplacianEdgeMetrics(image).variance;
}
