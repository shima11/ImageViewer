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

  /// The interactive-dismiss frame: `finalFrame` shrunk toward its own center
  /// by `progress`, then translated by the drag `translation`.
  ///
  /// The image stays anchored under the finger (translation moves the center)
  /// while shrinking as the drag progresses, instead of interpolating toward
  /// the source frame. Source-frame convergence is left to the release
  /// animation, so the two are not applied at once.
  ///
  /// - Parameters:
  ///   - finalFrame: The fullscreen aspect-fit frame (progress `0`).
  ///   - translation: The drag translation from the gesture's start.
  ///   - progress: The dismiss progress, `0...1`.
  ///   - minScale: The scale reached at `progress == 1`. Default `0.5`.
  static func interactiveFrame(
    finalFrame: CGRect,
    translation: CGPoint,
    progress: CGFloat,
    minScale: CGFloat = 0.5
  ) -> CGRect {
    let scale = 1 - progress * (1 - minScale)
    let width = finalFrame.width * scale
    let height = finalFrame.height * scale
    let centerX = finalFrame.midX + translation.x
    let centerY = finalFrame.midY + translation.y

    return CGRect(
      x: centerX - width / 2,
      y: centerY - height / 2,
      width: width,
      height: height
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
