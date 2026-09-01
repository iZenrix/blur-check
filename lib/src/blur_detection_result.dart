import 'blur_metrics.dart';
import 'image_quality_warning.dart';

/// Result of a blur/sharpness analysis.
class BlurDetectionResult {
  const BlurDetectionResult({
    required this.isBlurred,
    required this.score,
    required this.metrics,
    required this.originalWidth,
    required this.originalHeight,
    required this.analysisWidth,
    required this.analysisHeight,
    this.warnings = const {},
  });

  /// `true` when [score] is below the configured threshold.
  final bool isBlurred;

  /// Estimated sharpness in `0..100` (higher = sharper).
  ///
  /// This is an estimate from classical image processing, not a calibrated
  /// probability.
  final double score;

  /// Raw metrics used to derive [score].
  final BlurMetrics metrics;

  /// Width of the source image before resize.
  final int originalWidth;

  /// Height of the source image before resize.
  final int originalHeight;

  /// Width of the image actually analyzed.
  final int analysisWidth;

  /// Height of the image actually analyzed.
  final int analysisHeight;

  /// Diagnostic warnings (e.g. too dark / low texture).
  final Set<ImageQualityWarning> warnings;

  @override
  String toString() {
    return 'BlurDetectionResult('
        'isBlurred: $isBlurred, '
        'score: $score, '
        'metrics: $metrics, '
        'originalWidth: $originalWidth, '
        'originalHeight: $originalHeight, '
        'analysisWidth: $analysisWidth, '
        'analysisHeight: $analysisHeight, '
        'warnings: $warnings)';
  }
}
