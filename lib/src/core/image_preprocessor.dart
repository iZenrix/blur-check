import 'dart:typed_data';

import 'package:image/image.dart' as img;

import '../blur_detection_exception.dart';
import '../blur_detector_config.dart';
import 'grayscale_buffer.dart';

/// Intermediate result after decode / orientation / resize.
class PreprocessedImage {
  const PreprocessedImage({
    required this.grayscale,
    required this.originalWidth,
    required this.originalHeight,
  });

  final GrayscaleBuffer grayscale;
  final int originalWidth;
  final int originalHeight;

  int get analysisWidth => grayscale.width;
  int get analysisHeight => grayscale.height;
}

/// Decodes, orients, resizes, and converts images for blur analysis.
class ImagePreprocessor {
  const ImagePreprocessor();

  /// Decodes [bytes] and prepares a grayscale buffer for analysis.
  PreprocessedImage processBytes(
    Uint8List bytes, {
    required BlurDetectorConfig config,
  }) {
    if (bytes.isEmpty) {
      throw BlurDetectionException.invalidImage('Image bytes are empty.');
    }

    final img.Image decoded;
    try {
      final result = img.decodeImage(bytes);
      if (result == null) {
        throw BlurDetectionException.decodeFailure();
      }
      decoded = result;
    } on BlurDetectionException {
      rethrow;
    } catch (error) {
      throw BlurDetectionException.decodeFailure(error);
    }

    return processDecoded(decoded, config: config);
  }

  /// Prepares an already-decoded [image] for analysis.
  PreprocessedImage processDecoded(
    img.Image image, {
    required BlurDetectorConfig config,
  }) {
    final originalWidth = image.width;
    final originalHeight = image.height;

    _ensureMinimumSize(
      width: originalWidth,
      height: originalHeight,
      minimum: config.minImageDimension,
    );

    // bakeOrientation is a no-op when EXIF orientation is missing/normal.
    // JPEG decode may already apply orientation; calling again is safe.
    var oriented = img.bakeOrientation(image);

    oriented = _resizeIfNeeded(
      oriented,
      maxAnalysisDimension: config.maxAnalysisDimension,
    );

    _ensureMinimumSize(
      width: oriented.width,
      height: oriented.height,
      minimum: 3, // Laplacian needs a 3x3 neighborhood.
    );

    final grayscale = toGrayscaleBuffer(oriented);

    return PreprocessedImage(
      grayscale: grayscale,
      originalWidth: originalWidth,
      originalHeight: originalHeight,
    );
  }

  /// Converts [image] to a luminance buffer using standard Rec. 601 weights.
  GrayscaleBuffer toGrayscaleBuffer(img.Image image) {
    final width = image.width;
    final height = image.height;
    final pixels = Float64List(width * height);

    var index = 0;
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final pixel = image.getPixel(x, y);
        // Y = 0.299R + 0.587G + 0.114B
        final luminance =
            0.299 * pixel.r.toDouble() +
            0.587 * pixel.g.toDouble() +
            0.114 * pixel.b.toDouble();
        pixels[index++] = luminance;
      }
    }

    return GrayscaleBuffer(width: width, height: height, pixels: pixels);
  }

  img.Image _resizeIfNeeded(
    img.Image image, {
    required int maxAnalysisDimension,
  }) {
    final longest = image.width > image.height ? image.width : image.height;
    if (longest <= maxAnalysisDimension) {
      return image;
    }

    final scale = maxAnalysisDimension / longest;
    final targetWidth = (image.width * scale).round().clamp(
      1,
      maxAnalysisDimension,
    );
    final targetHeight = (image.height * scale).round().clamp(
      1,
      maxAnalysisDimension,
    );

    return img.copyResize(
      image,
      width: targetWidth,
      height: targetHeight,
      interpolation: img.Interpolation.linear,
    );
  }

  void _ensureMinimumSize({
    required int width,
    required int height,
    required int minimum,
  }) {
    if (width < minimum || height < minimum) {
      throw BlurDetectionException.imageTooSmall(
        width: width,
        height: height,
        minimum: minimum,
      );
    }
  }
}
