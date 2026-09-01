import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'blur_analyzer.dart';
import 'blur_detection_exception.dart';
import 'blur_detection_result.dart';
import 'blur_detector_config.dart';
import 'core/image_preprocessor.dart';
import 'image_quality_warning.dart';
import 'platform/is_web.dart';
import 'scoring/blur_score_normalizer.dart';

/// Estimates image sharpness using classical image processing.
///
/// The returned [BlurDetectionResult.score] ranges from 0 to 100, where
/// higher values represent stronger high-frequency image detail.
///
/// This is an estimate, not a semantic image-quality classifier.
/// Applications should calibrate [BlurDetectorConfig.threshold] using
/// representative images.
///
/// Async methods may offload work to a background isolate when
/// [BlurDetectorConfig.useIsolate] is enabled. Prefer [analyzeBytesSync] /
/// [analyzeFileSync] in unit tests.
class BlurDetector {
  BlurDetector({
    this.config = const BlurDetectorConfig(),
    ImagePreprocessor? preprocessor,
    BlurAnalyzer? analyzer,
    BlurScoreNormalizer? normalizer,
  }) : _preprocessor = preprocessor ?? const ImagePreprocessor(),
       _analyzer = analyzer ?? const BlurAnalyzer(),
       _normalizer =
           normalizer ??
           DefaultBlurScoreNormalizer(
             useEdgeDensity: config.useEdgeDensity,
             useContrastAdjustment: config.useContrastAdjustment,
           ),
       _hasCustomPipeline =
           preprocessor != null || analyzer != null || normalizer != null;

  final BlurDetectorConfig config;
  final ImagePreprocessor _preprocessor;
  final BlurAnalyzer _analyzer;
  final BlurScoreNormalizer _normalizer;
  final bool _hasCustomPipeline;

  /// Analyzes encoded image [bytes] (JPEG/PNG/WebP when supported).
  ///
  /// May run on a background isolate depending on [BlurDetectorConfig].
  Future<BlurDetectionResult> analyzeBytes(Uint8List bytes) async {
    if (_shouldUseIsolate(byteLength: bytes.lengthInBytes)) {
      return Isolate.run(() => analyzeBytesInIsolate(bytes, config));
    }
    return analyzeBytesSync(bytes);
  }

  /// Synchronous core path — preferred for unit tests.
  BlurDetectionResult analyzeBytesSync(Uint8List bytes) {
    final preprocessed = _preprocessor.processBytes(bytes, config: config);
    return _analyzePreprocessed(preprocessed);
  }

  /// Analyzes an image file at [path].
  ///
  /// May run on a background isolate depending on [BlurDetectorConfig].
  Future<BlurDetectionResult> analyzeFile(String path) async {
    if (_shouldUseIsolateForFile(path)) {
      return Isolate.run(() => analyzeFileInIsolate(path, config));
    }
    return analyzeFileSync(path);
  }

  /// Synchronous file path analysis.
  BlurDetectionResult analyzeFileSync(String path) {
    final file = File(path);
    if (!file.existsSync()) {
      throw BlurDetectionException.fileNotFound(path);
    }

    late final Uint8List bytes;
    try {
      bytes = file.readAsBytesSync();
    } catch (error) {
      throw BlurDetectionException(
        'Failed to read image file: $path',
        cause: error,
        code: BlurDetectionErrorCode.invalidImage,
      );
    }

    return analyzeBytesSync(bytes);
  }

  bool _shouldUseIsolate({required int byteLength}) {
    if (!config.useIsolate || isRunningOnWeb || _hasCustomPipeline) {
      return false;
    }
    return byteLength >= config.isolateMinBytes;
  }

  bool _shouldUseIsolateForFile(String path) {
    if (!config.useIsolate || isRunningOnWeb || _hasCustomPipeline) {
      return false;
    }
    try {
      final length = File(path).lengthSync();
      return length >= config.isolateMinBytes;
    } catch (_) {
      // Let sync path surface the real file error.
      return false;
    }
  }

  BlurDetectionResult _analyzePreprocessed(PreprocessedImage preprocessed) {
    final analysis = _analyzer.analyzeWithWarnings(preprocessed.grayscale);
    final score = _normalizer.normalize(analysis.metrics);

    var isBlurred = score < config.threshold;
    if (config.rejectVeryDarkImages &&
        analysis.warnings.contains(ImageQualityWarning.tooDark)) {
      isBlurred = true;
    }

    return BlurDetectionResult(
      isBlurred: isBlurred,
      score: score,
      metrics: analysis.metrics,
      originalWidth: preprocessed.originalWidth,
      originalHeight: preprocessed.originalHeight,
      analysisWidth: preprocessed.analysisWidth,
      analysisHeight: preprocessed.analysisHeight,
      warnings: analysis.warnings,
    );
  }
}

/// Top-level entry used by [Isolate.run] for byte analysis.
BlurDetectionResult analyzeBytesInIsolate(
  Uint8List bytes,
  BlurDetectorConfig config,
) {
  return BlurDetector(config: config).analyzeBytesSync(bytes);
}

/// Top-level entry used by [Isolate.run] for file analysis.
BlurDetectionResult analyzeFileInIsolate(
  String path,
  BlurDetectorConfig config,
) {
  return BlurDetector(config: config).analyzeFileSync(path);
}
