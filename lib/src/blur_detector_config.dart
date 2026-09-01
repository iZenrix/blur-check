/// Immutable configuration for [BlurDetector].
///
/// [threshold] is a starting point and should be calibrated per use case.
class BlurDetectorConfig {
  const BlurDetectorConfig({
    this.threshold = 45.0,
    this.maxAnalysisDimension = 720,
    this.minImageDimension = 64,
    this.useEdgeDensity = true,
    this.useContrastAdjustment = true,
    this.rejectVeryDarkImages = false,
    this.useIsolate = true,
    this.isolateMinBytes = 64 * 1024,
  }) : assert(threshold >= 0 && threshold <= 100),
       assert(maxAnalysisDimension >= 64),
       assert(minImageDimension >= 1),
       assert(isolateMinBytes >= 0);

  /// Scores below this value are considered blurred.
  ///
  /// Default `45` is a baseline, not a universal truth. Calibrate using
  /// representative photos from your application.
  final double threshold;

  /// Longest side of the image used for analysis, in pixels.
  ///
  /// Full-resolution images are resized while preserving aspect ratio.
  final int maxAnalysisDimension;

  /// Minimum width/height accepted before analysis.
  final int minImageDimension;

  /// When true, edge density contributes to the composite score.
  final bool useEdgeDensity;

  /// When true, contrast contributes to the composite score.
  final bool useContrastAdjustment;

  /// When true, very dark images are treated as blurred regardless of score.
  final bool rejectVeryDarkImages;

  /// When true, async APIs may run on a background isolate to avoid UI jank.
  ///
  /// Sync APIs never spawn an isolate. Web falls back to the calling isolate.
  /// Custom preprocessor/analyzer/normalizer injectors also force a same-
  /// isolate sync path because those objects are not sent across isolates.
  final bool useIsolate;

  /// Minimum encoded payload size before async APIs spawn an isolate.
  ///
  /// Smaller inputs run synchronously to avoid isolate spawn overhead.
  final int isolateMinBytes;

  @override
  String toString() {
    return 'BlurDetectorConfig('
        'threshold: $threshold, '
        'maxAnalysisDimension: $maxAnalysisDimension, '
        'minImageDimension: $minImageDimension, '
        'useEdgeDensity: $useEdgeDensity, '
        'useContrastAdjustment: $useContrastAdjustment, '
        'rejectVeryDarkImages: $rejectVeryDarkImages, '
        'useIsolate: $useIsolate, '
        'isolateMinBytes: $isolateMinBytes)';
  }
}
