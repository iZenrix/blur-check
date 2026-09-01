import 'dart:io';
import 'dart:math' as math;

import 'package:image/image.dart' as img;

/// Generates deterministic fixture images under test/fixtures/.
///
/// ```bash
/// dart run tool/generate_fixtures.dart
/// ```
void main() {
  final outDir = Directory('test/fixtures');
  if (!outDir.existsSync()) {
    outDir.createSync(recursive: true);
  }

  _writeJpeg(outDir, 'sharp.jpg', _documentLike(width: 640, height: 480));
  _writeJpeg(
    outDir,
    'blur-light.jpg',
    img.gaussianBlur(_documentLike(width: 640, height: 480), radius: 2),
  );
  _writeJpeg(
    outDir,
    'blur-heavy.jpg',
    img.gaussianBlur(_documentLike(width: 640, height: 480), radius: 6),
  );
  _writeJpeg(
    outDir,
    'motion-blur.jpg',
    _motionBlur(_documentLike(width: 640, height: 480), radius: 8),
  );
  _writeJpeg(
    outDir,
    'dark-sharp.jpg',
    _darken(_checkerboard(320, 240, 4), 0.15),
  );
  _writeJpeg(
    outDir,
    'dark-blur.jpg',
    _darken(img.gaussianBlur(_checkerboard(320, 240, 4), radius: 4), 0.15),
  );
  _writeJpeg(outDir, 'low-texture-sharp.jpg', _flat(320, 240, 180));
  _writeJpeg(
    outDir,
    'low-texture-blur.jpg',
    img.gaussianBlur(_flat(320, 240, 180), radius: 4),
  );

  stdout.writeln('Wrote fixtures to ${outDir.path}');
}

void _writeJpeg(Directory dir, String name, img.Image image) {
  final file = File('${dir.path}/$name');
  file.writeAsBytesSync(img.encodeJpg(image, quality: 90));
  stdout.writeln('  ${file.path} (${file.lengthSync()} bytes)');
}

img.Image _documentLike({required int width, required int height}) {
  final image = img.Image(width: width, height: height);
  img.fill(image, color: img.ColorRgb8(245, 245, 240));

  // Simulated text lines / form fields.
  for (var row = 0; row < 12; row++) {
    final y = 40 + row * 32;
    for (var x = 40; x < width - 40; x++) {
      final on = ((x + row * 3) % 7) < 4;
      if (on && y < height - 20) {
        image.setPixelRgb(x, y, 20, 20, 20);
        if (y + 1 < height) {
          image.setPixelRgb(x, y + 1, 20, 20, 20);
        }
      }
    }
  }

  // Border
  for (var x = 20; x < width - 20; x++) {
    image.setPixelRgb(x, 20, 30, 30, 30);
    image.setPixelRgb(x, height - 21, 30, 30, 30);
  }
  for (var y = 20; y < height - 20; y++) {
    image.setPixelRgb(20, y, 30, 30, 30);
    image.setPixelRgb(width - 21, y, 30, 30, 30);
  }

  return image;
}

img.Image _checkerboard(int width, int height, int cell) {
  final image = img.Image(width: width, height: height);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final value = ((x ~/ cell) + (y ~/ cell)).isEven ? 30 : 220;
      image.setPixelRgb(x, y, value, value, value);
    }
  }
  return image;
}

img.Image _flat(int width, int height, int value) {
  final image = img.Image(width: width, height: height);
  img.fill(image, color: img.ColorRgb8(value, value, value));
  return image;
}

img.Image _darken(img.Image source, double factor) {
  final out = img.Image.from(source);
  for (final pixel in out) {
    pixel
      ..r = (pixel.r * factor).round().clamp(0, 255)
      ..g = (pixel.g * factor).round().clamp(0, 255)
      ..b = (pixel.b * factor).round().clamp(0, 255);
  }
  return out;
}

/// Simple horizontal box blur approximating motion blur.
img.Image _motionBlur(img.Image source, {required int radius}) {
  final width = source.width;
  final height = source.height;
  final out = img.Image(width: width, height: height);
  final diameter = radius * 2 + 1;

  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      var r = 0, g = 0, b = 0, count = 0;
      for (var k = -radius; k <= radius; k++) {
        final xx = (x + k).clamp(0, width - 1);
        final p = source.getPixel(xx, y);
        r += p.r.toInt();
        g += p.g.toInt();
        b += p.b.toInt();
        count++;
      }
      // count should equal diameter except near edges with clamp — still ok
      out.setPixelRgb(
        x,
        y,
        (r / math.max(count, diameter)).round(),
        (g / math.max(count, diameter)).round(),
        (b / math.max(count, diameter)).round(),
      );
    }
  }
  return out;
}
