import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:blur_check/blur_check.dart';
import 'package:blur_check/src/blur_analyzer.dart';
import 'package:blur_check/src/core/image_preprocessor.dart';
import 'package:blur_check/src/scoring/blur_score_normalizer.dart';

/// Benchmark harness for Phase 4 performance baselines.
///
/// ```bash
/// dart run benchmark/blur_detector_benchmark.dart
/// ```
///
/// Numbers are machine-specific. Treat them as a local baseline, not a
/// published guarantee.
Future<void> main() async {
  const dimensions = [480, 720, 960];
  const sourceSizes = [(1920, 1080), (1280, 720), (800, 600)];

  print('blur_check benchmark');
  print('=============================');
  print('Synthetic checkerboard fixtures (JPEG).\n');

  for (final source in sourceSizes) {
    final bytes = _encodeCheckerboardJpeg(source.$1, source.$2, cellSize: 8);
    print(
      'Source: ${source.$1}x${source.$2}  '
      '(${(bytes.lengthInBytes / 1024).toStringAsFixed(1)} KB)',
    );

    for (final maxDim in dimensions) {
      final report = _measureStages(bytes, maxAnalysisDimension: maxDim);
      print(
        '  maxDim=$maxDim  '
        'analysis=${report.analysisWidth}x${report.analysisHeight}  '
        'decode=${_ms(report.decodeUs)}  '
        'resize+gray=${_ms(report.preprocessUs)}  '
        'metrics=${_ms(report.metricsUs)}  '
        'e2e=${_ms(report.e2eUs)}  '
        'score=${report.score.toStringAsFixed(1)}',
      );
    }
    print('');
  }

  final large = _encodeCheckerboardJpeg(1920, 1080, cellSize: 8);
  final config = const BlurDetectorConfig(
    useIsolate: true,
    isolateMinBytes: 0,
    maxAnalysisDimension: 720,
    minImageDimension: 32,
  );
  final detector = BlurDetector(config: config);

  final syncSw = Stopwatch()..start();
  final syncResult = detector.analyzeBytesSync(large);
  syncSw.stop();

  final isolateSw = Stopwatch()..start();
  final isolateResult = await detector.analyzeBytes(large);
  isolateSw.stop();

  print('Sync vs isolate wall time (1920x1080 → 720):');
  print(
    '  sync:    ${syncSw.elapsedMilliseconds}ms  '
    'score=${syncResult.score.toStringAsFixed(1)}',
  );
  print(
    '  isolate: ${isolateSw.elapsedMilliseconds}ms  '
    'score=${isolateResult.score.toStringAsFixed(1)}',
  );
  print(
    '\nNote: isolate wall time includes spawn overhead; prefer sync for '
    'tiny images (see isolateMinBytes).',
  );
}

_StageReport _measureStages(
  Uint8List bytes, {
  required int maxAnalysisDimension,
}) {
  const preprocessor = ImagePreprocessor();
  const analyzer = BlurAnalyzer();
  const normalizer = DefaultBlurScoreNormalizer();
  final config = BlurDetectorConfig(
    maxAnalysisDimension: maxAnalysisDimension,
    minImageDimension: 32,
  );

  final decodeSw = Stopwatch()..start();
  final decoded = img.decodeImage(bytes);
  decodeSw.stop();
  if (decoded == null) {
    throw StateError('Failed to decode benchmark fixture');
  }

  final preprocessSw = Stopwatch()..start();
  final oriented = img.bakeOrientation(decoded);
  final longest = oriented.width > oriented.height
      ? oriented.width
      : oriented.height;
  final img.Image resized;
  if (longest <= maxAnalysisDimension) {
    resized = oriented;
  } else {
    final scale = maxAnalysisDimension / longest;
    resized = img.copyResize(
      oriented,
      width: (oriented.width * scale).round().clamp(1, maxAnalysisDimension),
      height: (oriented.height * scale).round().clamp(1, maxAnalysisDimension),
      interpolation: img.Interpolation.linear,
    );
  }
  final grayscale = preprocessor.toGrayscaleBuffer(resized);
  preprocessSw.stop();

  final metricsSw = Stopwatch()..start();
  final metrics = analyzer.analyze(grayscale);
  normalizer.normalize(metrics);
  metricsSw.stop();

  final e2eSw = Stopwatch()..start();
  final result = BlurDetector(config: config).analyzeBytesSync(bytes);
  e2eSw.stop();

  return _StageReport(
    analysisWidth: result.analysisWidth,
    analysisHeight: result.analysisHeight,
    decodeUs: decodeSw.elapsedMicroseconds,
    preprocessUs: preprocessSw.elapsedMicroseconds,
    metricsUs: metricsSw.elapsedMicroseconds,
    e2eUs: e2eSw.elapsedMicroseconds,
    score: result.score,
  );
}

class _StageReport {
  const _StageReport({
    required this.analysisWidth,
    required this.analysisHeight,
    required this.decodeUs,
    required this.preprocessUs,
    required this.metricsUs,
    required this.e2eUs,
    required this.score,
  });

  final int analysisWidth;
  final int analysisHeight;
  final int decodeUs;
  final int preprocessUs;
  final int metricsUs;
  final int e2eUs;
  final double score;
}

String _ms(int microseconds) =>
    '${(microseconds / 1000.0).toStringAsFixed(1)}ms';

Uint8List _encodeCheckerboardJpeg(
  int width,
  int height, {
  required int cellSize,
}) {
  final image = img.Image(width: width, height: height);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final cellX = x ~/ cellSize;
      final cellY = y ~/ cellSize;
      final value = (cellX + cellY).isEven ? 0 : 255;
      image.setPixelRgb(x, y, value, value, value);
    }
  }
  return Uint8List.fromList(img.encodeJpg(image, quality: 85));
}
