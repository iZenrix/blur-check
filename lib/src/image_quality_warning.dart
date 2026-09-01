/// Diagnostic warnings that may explain a low sharpness score.
enum ImageQualityWarning {
  /// Mean brightness is very low.
  tooDark,

  /// Image appears heavily overexposed.
  tooBright,

  /// Low edge density and contrast (e.g. plain wall / sky).
  lowTexture,
}
