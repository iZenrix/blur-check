import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:blur_check/blur_check.dart';
import 'package:blur_check/src/blur_analyzer.dart';
import 'package:blur_check/src/core/grayscale_buffer.dart';
import 'package:blur_check/src/core/image_preprocessor.dart';
import 'package:blur_check/src/metrics/laplacian_variance.dart';
import 'package:blur_check/src/scoring/blur_score_normalizer.dart';

void main() {
  group('GrayscaleBuffer / laplacian', () {
    test('uniform image has near-zero laplacian variance', () {
      final buffer = _filledBuffer(32, 32, 128);
      final variance = computeLaplacianVariance(buffer);
      expect(variance, closeTo(0, 1e-9));
    });

    test('hard edge has higher laplacian variance than uniform', () {
      final uniform = _filledBuffer(64, 64, 128);
      final edged = _verticalEdgeBuffer(64, 64);

      expect(
        computeLaplacianVariance(edged),
        greaterThan(computeLaplacianVariance(uniform)),
      );
    });

    test('checkerboard has higher variance than blurred checkerboard', () {
      final sharp = _checkerboardBuffer(64, 64, cellSize: 4);
      final blurred = _blurredCheckerboardBuffer(64, 64, cellSize: 4);

      expect(
        computeLaplacianVariance(sharp),
        greaterThan(computeLaplacianVariance(blurred)),
      );
    });
  });

  group('ImagePreprocessor', () {
    const preprocessor = ImagePreprocessor();
    const config = BlurDetectorConfig(maxAnalysisDimension: 720);

    test('rejects empty bytes', () {
      expect(
        () => preprocessor.processBytes(Uint8List(0), config: config),
        throwsA(
          isA<BlurDetectionException>().having(
            (e) => e.code,
            'code',
            BlurDetectionErrorCode.invalidImage,
          ),
        ),
      );
    });

    test('rejects invalid bytes', () {
      expect(
        () => preprocessor.processBytes(
          Uint8List.fromList([1, 2, 3, 4]),
          config: config,
        ),
        throwsA(isA<BlurDetectionException>()),
      );
    });

    test('rejects tiny images', () {
      final tiny = img.Image(width: 16, height: 16);
      img.fill(tiny, color: img.ColorRgb8(128, 128, 128));
      final bytes = Uint8List.fromList(img.encodePng(tiny));

      expect(
        () => preprocessor.processBytes(bytes, config: config),
        throwsA(
          isA<BlurDetectionException>().having(
            (e) => e.code,
            'code',
            BlurDetectionErrorCode.imageTooSmall,
          ),
        ),
      );
    });

    test('resizes long side to maxAnalysisDimension', () {
      final large = img.Image(width: 1600, height: 1200);
      img.fill(large, color: img.ColorRgb8(40, 80, 120));
      // Add detail so resize path is exercised meaningfully.
      for (var y = 0; y < large.height; y += 8) {
        for (var x = 0; x < large.width; x++) {
          large.setPixelRgb(x, y, 255, 255, 255);
        }
      }

      final bytes = Uint8List.fromList(img.encodePng(large));
      final result = preprocessor.processBytes(
        bytes,
        config: const BlurDetectorConfig(maxAnalysisDimension: 720),
      );

      expect(result.originalWidth, 1600);
      expect(result.originalHeight, 1200);
      expect(result.analysisWidth, 720);
      expect(result.analysisHeight, 540);
    });

    test('grayscale uses Rec.601 luminance', () {
      final image = img.Image(width: 2, height: 1);
      image.setPixelRgb(0, 0, 255, 0, 0);
      image.setPixelRgb(1, 0, 0, 255, 0);

      final buffer = preprocessor.toGrayscaleBuffer(image);
      expect(buffer.get(0, 0), closeTo(0.299 * 255, 0.01));
      expect(buffer.get(1, 0), closeTo(0.587 * 255, 0.01));
    });
  });

  group('DefaultBlurScoreNormalizer', () {
    const normalizer = DefaultBlurScoreNormalizer(laplacianK: 100);

    test('maps zero metrics to zero score', () {
      expect(
        normalizer.normalize(
          const BlurMetrics(
            laplacianVariance: 0,
            edgeDensity: 0,
            contrast: 0,
            meanBrightness: 0,
          ),
        ),
        0,
      );
    });

    test('is monotonic with laplacian variance', () {
      final low = normalizer.normalize(
        const BlurMetrics(
          laplacianVariance: 20,
          edgeDensity: 0,
          contrast: 0,
          meanBrightness: 0,
        ),
      );
      final high = normalizer.normalize(
        const BlurMetrics(
          laplacianVariance: 200,
          edgeDensity: 0,
          contrast: 0,
          meanBrightness: 0,
        ),
      );
      expect(high, greaterThan(low));
      expect(low, inInclusiveRange(0, 100));
      expect(high, inInclusiveRange(0, 100));
    });

    test('composite score blends edge and contrast', () {
      const laplacianOnly = BlurMetrics(
        laplacianVariance: 100,
        edgeDensity: 0,
        contrast: 0,
        meanBrightness: 0.5,
      );
      const withExtras = BlurMetrics(
        laplacianVariance: 100,
        edgeDensity: 0.2,
        contrast: 40,
        meanBrightness: 0.5,
      );

      final base = normalizer.normalize(laplacianOnly);
      final boosted = normalizer.normalize(withExtras);
      expect(boosted, greaterThan(base));
      expect(boosted, lessThanOrEqualTo(100));
    });

    test('disabling edge/contrast falls back to laplacian weight', () {
      const metrics = BlurMetrics(
        laplacianVariance: 100,
        edgeDensity: 1.0,
        contrast: 80,
        meanBrightness: 0.5,
      );

      const full = DefaultBlurScoreNormalizer();
      const laplacianOnly = DefaultBlurScoreNormalizer(
        useEdgeDensity: false,
        useContrastAdjustment: false,
      );

      final fullScore = full.normalize(metrics);
      final laplacianScore = laplacianOnly.normalize(metrics);

      // Full composite includes strong edge/contrast → higher than L-only.
      expect(fullScore, greaterThan(laplacianScore));

      // Laplacian-only equals pure soft-normalized laplacian.
      final expectedLaplacian = 100.0 * 100 / (100 + 100);
      expect(laplacianScore, closeTo(expectedLaplacian, 1e-9));
    });

    test('score stays within 0..100', () {
      final score = normalizer.normalize(
        const BlurMetrics(
          laplacianVariance: 1e9,
          edgeDensity: 1,
          contrast: 1e9,
          meanBrightness: 1,
        ),
      );
      expect(score, inInclusiveRange(0, 100));
    });
  });

  group('Threshold decision', () {
    test('isBlurred equals score < threshold', () {
      final bytes = _encodeCheckerboardPng(96, 96, cellSize: 4);

      for (final threshold in [0.0, 25.0, 45.0, 65.0, 100.0]) {
        final result = BlurDetector(
          config: BlurDetectorConfig(
            threshold: threshold,
            maxAnalysisDimension: 256,
            minImageDimension: 32,
          ),
        ).analyzeBytesSync(bytes);

        expect(
          result.isBlurred,
          result.score < threshold,
          reason: 'threshold=$threshold score=${result.score}',
        );
      }
    });

    test('config flags change composite score', () {
      final bytes = _encodeCheckerboardPng(96, 96, cellSize: 4);

      final withExtras = BlurDetector(
        config: const BlurDetectorConfig(
          maxAnalysisDimension: 256,
          minImageDimension: 32,
        ),
      ).analyzeBytesSync(bytes);

      final laplacianOnly = BlurDetector(
        config: const BlurDetectorConfig(
          maxAnalysisDimension: 256,
          minImageDimension: 32,
          useEdgeDensity: false,
          useContrastAdjustment: false,
        ),
      ).analyzeBytesSync(bytes);

      expect(withExtras.metrics, laplacianOnly.metrics);
      expect(withExtras.score, isNot(laplacianOnly.score));
    });
  });

  group('BlurDetector', () {
    late BlurDetector detector;

    setUp(() {
      detector = BlurDetector(
        config: const BlurDetectorConfig(
          threshold: 45,
          maxAnalysisDimension: 256,
          minImageDimension: 32,
        ),
      );
    });

    test('sharp synthetic scores higher than blurred synthetic', () {
      final sharpBytes = _encodeCheckerboardPng(128, 128, cellSize: 4);
      final blurredBytes = _encodeBlurredCheckerboardPng(
        128,
        128,
        cellSize: 4,
        blurRadius: 4,
      );

      final sharp = detector.analyzeBytesSync(sharpBytes);
      final blurred = detector.analyzeBytesSync(blurredBytes);

      expect(
        sharp.metrics.laplacianVariance,
        greaterThan(blurred.metrics.laplacianVariance),
      );
      expect(sharp.score, greaterThan(blurred.score));
    });

    test('isBlurred follows threshold', () {
      final flatBytes = _encodeFlatPng(96, 96, value: 128);
      final result = detector.analyzeBytesSync(flatBytes);

      expect(result.score, lessThan(45));
      expect(result.isBlurred, isTrue);

      final strict = BlurDetector(
        config: const BlurDetectorConfig(
          threshold: 0,
          maxAnalysisDimension: 256,
          minImageDimension: 32,
        ),
      ).analyzeBytesSync(flatBytes);
      expect(strict.isBlurred, isFalse);
    });

    test('analyzeBytes matches analyzeBytesSync', () async {
      final bytes = _encodeCheckerboardPng(64, 64, cellSize: 4);
      final syncResult = detector.analyzeBytesSync(bytes);
      final asyncResult = await detector.analyzeBytes(bytes);

      expect(asyncResult.score, syncResult.score);
      expect(
        asyncResult.metrics.laplacianVariance,
        syncResult.metrics.laplacianVariance,
      );
      expect(asyncResult.isBlurred, syncResult.isBlurred);
    });

    test('analyzeFileSync reads png from disk', () async {
      final bytes = _encodeCheckerboardPng(80, 80, cellSize: 4);
      final file = await _tempPng(bytes);

      final result = detector.analyzeFileSync(file.path);
      expect(result.score, greaterThan(0));
      expect(result.originalWidth, 80);
      expect(result.originalHeight, 80);

      await file.delete();
    });

    test('analyzeFileSync throws when file is missing', () {
      expect(
        () => detector.analyzeFileSync('/tmp/does-not-exist-blur-detector.png'),
        throwsA(
          isA<BlurDetectionException>().having(
            (e) => e.code,
            'code',
            BlurDetectionErrorCode.fileNotFound,
          ),
        ),
      );
    });
  });

  group('BlurAnalyzer phase 2 metrics', () {
    test('fills edge density, contrast, and brightness', () {
      final metrics = const BlurAnalyzer().analyze(
        _checkerboardBuffer(48, 48, cellSize: 4),
      );
      expect(metrics.laplacianVariance, greaterThan(0));
      expect(metrics.edgeDensity, greaterThan(0));
      expect(metrics.contrast, greaterThan(0));
      expect(metrics.meanBrightness, closeTo(0.5, 0.05));
    });

    test('metrics are deterministic for the same input', () {
      final buffer = _checkerboardBuffer(64, 64, cellSize: 4);
      const analyzer = BlurAnalyzer();
      final a = analyzer.analyze(buffer);
      final b = analyzer.analyze(buffer);
      expect(a, b);
    });

    test('uniform image has zero edge density and contrast', () {
      final metrics = const BlurAnalyzer().analyze(_filledBuffer(48, 48, 128));
      expect(metrics.edgeDensity, 0);
      expect(metrics.contrast, 0);
      expect(metrics.meanBrightness, closeTo(128 / 255, 1e-9));
      expect(metrics.laplacianVariance, closeTo(0, 1e-9));
    });

    test('hard edge has higher edge density than uniform', () {
      const analyzer = BlurAnalyzer();
      final uniform = analyzer.analyze(_filledBuffer(64, 64, 128));
      final edged = analyzer.analyze(_verticalEdgeBuffer(64, 64));
      expect(edged.edgeDensity, greaterThan(uniform.edgeDensity));
      expect(edged.contrast, greaterThan(uniform.contrast));
    });
  });

  group('Image quality warnings', () {
    test('flat image warns lowTexture', () {
      final result = BlurDetector(
        config: const BlurDetectorConfig(
          maxAnalysisDimension: 256,
          minImageDimension: 32,
        ),
      ).analyzeBytesSync(_encodeFlatPng(96, 96, value: 128));

      expect(result.warnings, contains(ImageQualityWarning.lowTexture));
      expect(result.metrics.edgeDensity, 0);
      expect(result.metrics.contrast, 0);
    });

    test('dark image warns tooDark', () {
      final result = BlurDetector(
        config: const BlurDetectorConfig(
          maxAnalysisDimension: 256,
          minImageDimension: 32,
        ),
      ).analyzeBytesSync(_encodeFlatPng(96, 96, value: 5));

      expect(result.warnings, contains(ImageQualityWarning.tooDark));
      expect(result.metrics.meanBrightness, lessThan(0.08));
    });

    test('overexposed image warns tooBright', () {
      final result = BlurDetector(
        config: const BlurDetectorConfig(
          maxAnalysisDimension: 256,
          minImageDimension: 32,
        ),
      ).analyzeBytesSync(_encodeFlatPng(96, 96, value: 255));

      expect(result.warnings, contains(ImageQualityWarning.tooBright));
    });

    test('checkerboard does not warn lowTexture', () {
      final result = BlurDetector(
        config: const BlurDetectorConfig(
          maxAnalysisDimension: 256,
          minImageDimension: 32,
        ),
      ).analyzeBytesSync(_encodeCheckerboardPng(96, 96, cellSize: 4));

      expect(result.warnings, isNot(contains(ImageQualityWarning.lowTexture)));
      expect(result.metrics.edgeDensity, greaterThan(0.02));
    });

    test('rejectVeryDarkImages forces isBlurred', () {
      // High threshold so a dark flat image would otherwise not matter for
      // score alone — rejectVeryDarkImages should still mark blurred.
      final result = BlurDetector(
        config: const BlurDetectorConfig(
          threshold: 0,
          maxAnalysisDimension: 256,
          minImageDimension: 32,
          rejectVeryDarkImages: true,
        ),
      ).analyzeBytesSync(_encodeFlatPng(96, 96, value: 5));

      expect(result.warnings, contains(ImageQualityWarning.tooDark));
      expect(result.isBlurred, isTrue);
    });
  });

  group('Isolate / async path', () {
    test('isolate path matches sync result', () async {
      final bytes = _encodeCheckerboardPng(128, 128, cellSize: 4);
      final detector = BlurDetector(
        config: const BlurDetectorConfig(
          threshold: 45,
          maxAnalysisDimension: 256,
          minImageDimension: 32,
          useIsolate: true,
          isolateMinBytes: 0,
        ),
      );

      final syncResult = detector.analyzeBytesSync(bytes);
      final asyncResult = await detector.analyzeBytes(bytes);

      expect(asyncResult.score, syncResult.score);
      expect(
        asyncResult.metrics.laplacianVariance,
        syncResult.metrics.laplacianVariance,
      );
      expect(asyncResult.metrics.edgeDensity, syncResult.metrics.edgeDensity);
      expect(asyncResult.isBlurred, syncResult.isBlurred);
      expect(asyncResult.warnings, syncResult.warnings);
    });

    test('useIsolate false stays on calling isolate', () async {
      final bytes = _encodeCheckerboardPng(96, 96, cellSize: 4);
      final detector = BlurDetector(
        config: const BlurDetectorConfig(
          maxAnalysisDimension: 256,
          minImageDimension: 32,
          useIsolate: false,
          isolateMinBytes: 0,
        ),
      );

      final syncResult = detector.analyzeBytesSync(bytes);
      final asyncResult = await detector.analyzeBytes(bytes);
      expect(asyncResult.score, syncResult.score);
    });

    test('tiny payloads skip isolate via isolateMinBytes', () async {
      final bytes = _encodeCheckerboardPng(64, 64, cellSize: 4);
      expect(bytes.lengthInBytes, lessThan(64 * 1024));

      final detector = BlurDetector(
        config: const BlurDetectorConfig(
          maxAnalysisDimension: 256,
          minImageDimension: 32,
          useIsolate: true,
        ),
      );

      final syncResult = detector.analyzeBytesSync(bytes);
      final asyncResult = await detector.analyzeBytes(bytes);
      expect(asyncResult.score, syncResult.score);
    });
  });
}

GrayscaleBuffer _filledBuffer(int width, int height, double value) {
  final pixels = Float64List(width * height);
  for (var i = 0; i < pixels.length; i++) {
    pixels[i] = value;
  }
  return GrayscaleBuffer(width: width, height: height, pixels: pixels);
}

GrayscaleBuffer _verticalEdgeBuffer(int width, int height) {
  final pixels = Float64List(width * height);
  final mid = width ~/ 2;
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      pixels[y * width + x] = x < mid ? 0 : 255;
    }
  }
  return GrayscaleBuffer(width: width, height: height, pixels: pixels);
}

GrayscaleBuffer _checkerboardBuffer(
  int width,
  int height, {
  required int cellSize,
}) {
  final pixels = Float64List(width * height);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final cellX = x ~/ cellSize;
      final cellY = y ~/ cellSize;
      pixels[y * width + x] = ((cellX + cellY).isEven) ? 0 : 255;
    }
  }
  return GrayscaleBuffer(width: width, height: height, pixels: pixels);
}

GrayscaleBuffer _blurredCheckerboardBuffer(
  int width,
  int height, {
  required int cellSize,
}) {
  final sharp = img.Image(width: width, height: height);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final cellX = x ~/ cellSize;
      final cellY = y ~/ cellSize;
      final value = ((cellX + cellY).isEven) ? 0 : 255;
      sharp.setPixelRgb(x, y, value, value, value);
    }
  }

  final blurred = img.gaussianBlur(sharp, radius: 3);
  return const ImagePreprocessor().toGrayscaleBuffer(blurred);
}

Uint8List _encodeFlatPng(int width, int height, {required int value}) {
  final image = img.Image(width: width, height: height);
  img.fill(image, color: img.ColorRgb8(value, value, value));
  return Uint8List.fromList(img.encodePng(image));
}

Uint8List _encodeCheckerboardPng(
  int width,
  int height, {
  required int cellSize,
}) {
  final image = img.Image(width: width, height: height);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final cellX = x ~/ cellSize;
      final cellY = y ~/ cellSize;
      final value = ((cellX + cellY).isEven) ? 0 : 255;
      image.setPixelRgb(x, y, value, value, value);
    }
  }
  return Uint8List.fromList(img.encodePng(image));
}

Uint8List _encodeBlurredCheckerboardPng(
  int width,
  int height, {
  required int cellSize,
  required int blurRadius,
}) {
  final image = img.Image(width: width, height: height);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final cellX = x ~/ cellSize;
      final cellY = y ~/ cellSize;
      final value = ((cellX + cellY).isEven) ? 0 : 255;
      image.setPixelRgb(x, y, value, value, value);
    }
  }
  final blurred = img.gaussianBlur(image, radius: blurRadius);
  return Uint8List.fromList(img.encodePng(blurred));
}

Future<File> _tempPng(Uint8List bytes) async {
  final dir = await Directory.systemTemp.createTemp('blur_detector_');
  final file = File('${dir.path}/sample.png');
  await file.writeAsBytes(bytes);
  return file;
}
