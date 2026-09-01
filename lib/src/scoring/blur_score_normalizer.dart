import '../blur_metrics.dart';

/// Converts raw [BlurMetrics] into a normalized sharpness score (`0..100`).
abstract interface class BlurScoreNormalizer {
  double normalize(BlurMetrics metrics);
}

/// Baseline composite normalizer.
///
/// ```text
/// score =
///     wL * normalizedLaplacian
///   + wE * normalizedEdgeDensity
///   + wC * normalizedContrast
/// ```
///
/// Default weights: Laplacian 75%, edge density 15%, contrast 10%.
/// Disabled components are omitted and remaining weights are renormalized.
///
/// These weights are a calibration starting point, not an optimal claim.
class DefaultBlurScoreNormalizer implements BlurScoreNormalizer {
  const DefaultBlurScoreNormalizer({
    this.laplacianK = 100.0,
    this.contrastK = 40.0,
    this.laplacianWeight = 0.75,
    this.edgeWeight = 0.15,
    this.contrastWeight = 0.10,
    this.useEdgeDensity = true,
    this.useContrastAdjustment = true,
  });

  /// Soft saturation constant for Laplacian variance → `0..100`.
  final double laplacianK;

  /// Soft saturation constant for grayscale contrast → `0..100`.
  final double contrastK;

  final double laplacianWeight;
  final double edgeWeight;
  final double contrastWeight;

  /// When false, edge density is excluded from the composite score.
  final bool useEdgeDensity;

  /// When false, contrast is excluded from the composite score.
  final bool useContrastAdjustment;

  @override
  double normalize(BlurMetrics metrics) {
    final laplacian = _normalizeLaplacian(metrics.laplacianVariance);
    final edge = _normalizeUnitInterval(metrics.edgeDensity);
    final contrast = _normalizeContrast(metrics.contrast);

    final weightL = laplacianWeight;
    final weightE = useEdgeDensity ? edgeWeight : 0.0;
    final weightC = useContrastAdjustment ? contrastWeight : 0.0;
    final totalWeight = weightL + weightE + weightC;

    if (totalWeight <= 0) {
      return _clamp01to100(laplacian);
    }

    final score =
        (weightL * laplacian + weightE * edge + weightC * contrast) /
        totalWeight;

    return _clamp01to100(score);
  }

  /// `100 * variance / (variance + K)`
  double _normalizeLaplacian(double variance) {
    if (variance <= 0) {
      return 0;
    }
    return 100.0 * variance / (variance + laplacianK);
  }

  /// Edge density is already `0..1`.
  double _normalizeUnitInterval(double value) {
    if (value <= 0) {
      return 0;
    }
    if (value >= 1) {
      return 100;
    }
    return 100.0 * value;
  }

  /// `100 * contrast / (contrast + K)` — contrast is grayscale stddev.
  double _normalizeContrast(double contrast) {
    if (contrast <= 0) {
      return 0;
    }
    return 100.0 * contrast / (contrast + contrastK);
  }

  double _clamp01to100(double score) {
    if (score < 0) {
      return 0;
    }
    if (score > 100) {
      return 100;
    }
    return score;
  }
}
