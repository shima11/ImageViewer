import Foundation

// MARK: - Image Viewer Index

/// Index helpers for the image viewer.
enum ImageViewerIndex {
  /// Clamps an index into the valid range for a collection of the given count.
  ///
  /// Returns 0 when the collection is empty, otherwise the index constrained to
  /// `0...(count - 1)`.
  static func clamp(_ index: Int, count: Int) -> Int {
    max(0, min(index, max(0, count - 1)))
  }
}
