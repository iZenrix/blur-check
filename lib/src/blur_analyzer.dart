import 'blur_metrics.dart';
import 'core/grayscale_buffer.dart';
import 'image_quality_warning.dart';
import 'metrics/image_quality_warning_evaluator.dart';
import 'metrics/laplacian_variance.dart';
import 'metrics/luminance_stats.dart';

/// Full metric bundle returned by [BlurAnalyzer].
class BlurAnalysisOutput {
  const BlurAnalysisOutput({
    required this.metrics,
    required this.warnings,
    required this.brightPixelRatio,
  });

  final BlurMetrics metrics;
  final Set<ImageQualityWarning> warnings;

  /// Internal overexposure signal used for [ImageQualityWarning.tooBright].
  final double brightPixelRatio;
}

/// Computes blur-related metrics from a grayscale buffer.
///
/// Uses two main passes:
/// 1. luminance stats (brightness, contrast, bright-pixel ratio)
/// 2. Laplacian variance + edge density
class BlurAnalyzer {
  const BlurAnalyzer({
    this.edgeThreshold = 15.0,
    this.warningEvaluator = const ImageQualityWarningEvaluator(),
  });

  /// Internal `|Laplacian|` threshold for edge pixels.
  final double edgeThreshold;

  final ImageQualityWarningEvaluator warningEvaluator;

  BlurMetrics analyze(GrayscaleBuffer image) {
    return analyzeWithWarnings(image).metrics;
  }

  BlurAnalysisOutput analyzeWithWarnings(GrayscaleBuffer image) {
    final luminance = computeLuminanceStats(image);
    final laplacian = computeLaplacianEdgeMetrics(
      image,
      edgeThreshold: edgeThreshold,
    );

    final metrics = BlurMetrics(
      laplacianVariance: laplacian.variance,
      edgeDensity: laplacian.edgeDensity,
      contrast: luminance.contrast,
      meanBrightness: luminance.meanBrightness,
    );

    final warnings = warningEvaluator.evaluate(
      metrics,
      brightPixelRatio: luminance.brightPixelRatio,
    );

    return BlurAnalysisOutput(
      metrics: metrics,
      warnings: warnings,
      brightPixelRatio: luminance.brightPixelRatio,
    );
  }
}
