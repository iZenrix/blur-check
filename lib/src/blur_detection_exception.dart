/// Thrown when blur detection cannot process the given input.
class BlurDetectionException implements Exception {
  const BlurDetectionException(
    this.message, {
    this.cause,
    this.code = BlurDetectionErrorCode.unknown,
  });

  factory BlurDetectionException.invalidImage([
    String message = 'Invalid or unsupported image data.',
    Object? cause,
  ]) {
    return BlurDetectionException(
      message,
      cause: cause,
      code: BlurDetectionErrorCode.invalidImage,
    );
  }

  factory BlurDetectionException.fileNotFound(String path) {
    return BlurDetectionException(
      'Image file not found: $path',
      code: BlurDetectionErrorCode.fileNotFound,
    );
  }

  factory BlurDetectionException.imageTooSmall({
    required int width,
    required int height,
    required int minimum,
  }) {
    return BlurDetectionException(
      'Image is too small for blur analysis '
      '(${width}x$height; minimum ${minimum}x$minimum).',
      code: BlurDetectionErrorCode.imageTooSmall,
    );
  }

  factory BlurDetectionException.decodeFailure([Object? cause]) {
    return BlurDetectionException(
      'Failed to decode image.',
      cause: cause,
      code: BlurDetectionErrorCode.decodeFailure,
    );
  }

  final String message;
  final Object? cause;
  final BlurDetectionErrorCode code;

  @override
  String toString() {
    if (cause == null) {
      return 'BlurDetectionException($code): $message';
    }
    return 'BlurDetectionException($code): $message (cause: $cause)';
  }
}

/// Typed error categories for [BlurDetectionException].
enum BlurDetectionErrorCode {
  unknown,
  invalidImage,
  unsupportedImage,
  fileNotFound,
  imageTooSmall,
  decodeFailure,
}
