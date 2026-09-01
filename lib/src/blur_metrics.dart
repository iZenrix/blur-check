/// Raw diagnostic metrics produced by the blur analyzer.
class BlurMetrics {
  const BlurMetrics({
    required this.laplacianVariance,
    required this.edgeDensity,
    required this.contrast,
    required this.meanBrightness,
  });

  /// Variance of the Laplacian response (primary sharpness signal).
  final double laplacianVariance;

  /// Fraction of analyzed pixels classified as edges (`0..1`).
  final double edgeDensity;

  /// Grayscale standard deviation (texture/contrast signal).
  final double contrast;

  /// Mean grayscale luminance normalized to `0..1`.
  final double meanBrightness;

  @override
  String toString() {
    return 'BlurMetrics('
        'laplacianVariance: $laplacianVariance, '
        'edgeDensity: $edgeDensity, '
        'contrast: $contrast, '
        'meanBrightness: $meanBrightness)';
  }

  @override
  bool operator ==(Object other) {
    return other is BlurMetrics &&
        other.laplacianVariance == laplacianVariance &&
        other.edgeDensity == edgeDensity &&
        other.contrast == contrast &&
        other.meanBrightness == meanBrightness;
  }

  @override
  int get hashCode =>
      Object.hash(laplacianVariance, edgeDensity, contrast, meanBrightness);
}
