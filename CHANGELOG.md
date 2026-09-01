## 0.1.0

* Initial release as **blur_check** (offline blur/sharpness detection for Flutter).
* Classical pipeline: decode, EXIF orientation, resize, grayscale, Variance of Laplacian.
* Metrics: edge density, contrast, mean brightness; warnings `tooDark` / `tooBright` / `lowTexture`.
* Composite normalized score (Laplacian 75% / edge 15% / contrast 10%).
* Optional background isolate for async APIs; benchmark harness included.
* Example Flutter app, fixture regression tests, and CI workflow.
