import CoreGraphics

// MARK: - Image Viewer Geometry

/// Pure geometry helpers for the image viewer. Kept free of UIKit/actor
/// isolation so they can be unit-tested directly.
enum ImageViewerGeometry {
  /// The aspect-fit frame for an image of `imageSize` centered within `bounds`.
  ///
  /// Returns `bounds` unchanged when the image has no area.
  static func aspectFitFrame(imageSize: CGSize, in bounds: CGRect) -> CGRect {
    guard imageSize.width > 0, imageSize.height > 0 else {
      return bounds
    }

    let imageAspect = imageSize.width / imageSize.height
    let boundsAspect = bounds.width / bounds.height

    let finalSize: CGSize
    if imageAspect > boundsAspect {
      finalSize = CGSize(width: bounds.width, height: bounds.width / imageAspect)
    } else {
      finalSize = CGSize(width: bounds.height * imageAspect, height: bounds.height)
    }

    return CGRect(
      x: bounds.minX + (bounds.width - finalSize.width) / 2,
      y: bounds.minY + (bounds.height - finalSize.height) / 2,
      width: finalSize.width,
      height: finalSize.height
    )
  }

  /// The inclusive range of page indices to keep cached around `currentIndex`.
  static func keepRange(around currentIndex: Int, radius: Int = 2) -> ClosedRange<Int> {
    (currentIndex - radius)...(currentIndex + radius)
  }

  /// The source frame to animate to/from for `index`.
  ///
  /// Returns `nil` after rotation (the captured frames are stale, so dismissal
  /// should fall back to a slide-down) or when the index has no frame.
  static func sourceFrame(from frames: [CGRect]?, at index: Int, hasRotated: Bool) -> CGRect? {
    guard !hasRotated else { return nil }
    return frames.flatMap { $0.indices.contains(index) ? $0[index] : nil }
  }
}
