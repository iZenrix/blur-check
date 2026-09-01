import '../blur_metrics.dart';
import '../image_quality_warning.dart';

/// Baseline heuristics for diagnostic warnings.
///
/// Thresholds are starting points and may change after calibration.
class ImageQualityWarningEvaluator {
  const ImageQualityWarningEvaluator({
    this.darkBrightnessThreshold = 0.08,
    this.brightPixelRatioThreshold = 0.40,
    this.lowTextureEdgeDensityThreshold = 0.02,
    this.lowTextureContrastThreshold = 12.0,
  });

  /// [BlurMetrics.meanBrightness] below this → [ImageQualityWarning.tooDark].
  final double darkBrightnessThreshold;

  /// Bright-pixel ratio above this → [ImageQualityWarning.tooBright].
  final double brightPixelRatioThreshold;

  /// Edge density below this (with low contrast) → lowTexture.
  final double lowTextureEdgeDensityThreshold;

  /// Contrast below this (with low edge density) → lowTexture.
  final double lowTextureContrastThreshold;

  /// Evaluates warnings from [metrics] and optional [brightPixelRatio].
  Set<ImageQualityWarning> evaluate(
    BlurMetrics metrics, {
    required double brightPixelRatio,
  }) {
    final warnings = <ImageQualityWarning>{};

    if (metrics.meanBrightness < darkBrightnessThreshold) {
      warnings.add(ImageQualityWarning.tooDark);
    }

    if (brightPixelRatio >= brightPixelRatioThreshold) {
      warnings.add(ImageQualityWarning.tooBright);
    }

    if (metrics.edgeDensity < lowTextureEdgeDensityThreshold &&
        metrics.contrast < lowTextureContrastThreshold) {
      warnings.add(ImageQualityWarning.lowTexture);
    }

    return Set<ImageQualityWarning>.unmodifiable(warnings);
  }
}
