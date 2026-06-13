import os

// MARK: - Logging

/// Loggers used across the image viewer.
///
/// Filter in Console.app with the subsystem `com.shima11.ImageViewer`.
enum ImageViewerLog {
  private static let subsystem = "com.shima11.ImageViewer"

  /// Image loading lifecycle and failures.
  static let loading = Logger(subsystem: subsystem, category: "loading")

  /// Window / scene presentation.
  static let presentation = Logger(subsystem: subsystem, category: "presentation")
}
