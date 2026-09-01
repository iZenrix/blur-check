import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:blur_check/blur_check.dart';

void main() {
  final fixturesDir = Directory('test/fixtures');

  setUpAll(() {
    expect(
      fixturesDir.existsSync(),
      isTrue,
      reason: 'Run: dart run tool/generate_fixtures.dart',
    );
  });

  BlurDetectionResult analyze(String name) {
    final bytes = File('${fixturesDir.path}/$name').readAsBytesSync();
    return BlurDetector(
      config: const BlurDetectorConfig(
        threshold: 45,
        maxAnalysisDimension: 720,
        minImageDimension: 32,
        useIsolate: false,
      ),
    ).analyzeBytesSync(bytes);
  }

  group('Fixture regression', () {
    test('sharp scores higher than blur variants', () {
      final sharp = analyze('sharp.jpg');
      final light = analyze('blur-light.jpg');
      final heavy = analyze('blur-heavy.jpg');
      final motion = analyze('motion-blur.jpg');

      expect(sharp.score, greaterThan(light.score));
      expect(light.score, greaterThan(heavy.score));
      expect(sharp.score, greaterThan(motion.score));
      expect(sharp.score, greaterThan(65));
      expect(heavy.score, lessThan(45));
    });

    test('dark-sharp scores higher than dark-blur', () {
      final sharp = analyze('dark-sharp.jpg');
      final blurred = analyze('dark-blur.jpg');

      expect(sharp.score, greaterThan(blurred.score));
      expect(sharp.warnings, contains(ImageQualityWarning.tooDark));
      expect(blurred.warnings, contains(ImageQualityWarning.tooDark));
    });

    test('low-texture images warn lowTexture', () {
      final flat = analyze('low-texture-sharp.jpg');
      expect(flat.warnings, contains(ImageQualityWarning.lowTexture));
      expect(flat.metrics.edgeDensity, lessThan(0.02));
    });

    test('results are deterministic across runs', () {
      final a = analyze('sharp.jpg');
      final b = analyze('sharp.jpg');
      expect(a.score, b.score);
      expect(a.metrics, b.metrics);
      expect(a.isBlurred, b.isBlurred);
    });
  });
}
